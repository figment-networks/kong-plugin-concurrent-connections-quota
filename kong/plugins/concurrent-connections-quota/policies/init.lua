local reports = require "kong.reports"
local redis = require "resty.redis"


local kong = kong
local null = ngx.null
local shm = ngx.shared.kong_rate_limiting_counters
local fmt = string.format

local EMPTY_UUID = "00000000-0000-0000-0000-000000000000"

local function is_present(str)
  return str and str ~= "" and str ~= null
end

local function get_service_and_route_ids(conf)
  conf = conf or {}

  local service_id = conf.service_id
  local route_id   = conf.route_id

  if not service_id or service_id == null then
    service_id = EMPTY_UUID
  end

  if not route_id or route_id == null then
    route_id = EMPTY_UUID
  end

  return service_id, route_id
end

local get_local_key = function(conf, identifier, period, period_date)
  local service_id, route_id = get_service_and_route_ids(conf)

  return fmt("concurrent-connections-quota:%s:%s:%s", route_id, service_id, identifier)
end

local sock_opts = {}

local function get_redis_connection(conf)
  local red = redis:new()
  red:set_timeout(conf.redis_timeout)
  -- use a special pool name only if redis_database is set to non-zero
  -- otherwise use the default pool name host:port
  sock_opts.pool = conf.redis_database and
                    conf.redis_host .. ":" .. conf.redis_port ..
                    ":" .. conf.redis_database
  local ok, err = red:connect(conf.redis_host, conf.redis_port,
                              sock_opts)
  if not ok then
    kong.log.err("failed to connect to Redis: ", err)
    return nil, err
  end

  local times, err = red:get_reused_times()
  if err then
    kong.log.err("failed to get connect reused times: ", err)
    return nil, err
  end

  if times == 0 then
    if is_present(conf.redis_password) then
      local ok, err = red:auth(conf.redis_password)
      if not ok then
        kong.log.err("failed to auth Redis: ", err)
        return nil, err
      end
    end

    if conf.redis_database ~= 0 then
      -- Only call select first time, since we know the connection is shared
      -- between instances that use the same redis database

      local ok, err = red:select(conf.redis_database)
      if not ok then
        kong.log.err("failed to change Redis database: ", err)
        return nil, err
      end
    end
  end

  reports.retrieve_redis_version(red)

  return red
end

return {
  ["local"] = {
    increment = function(conf, identifier, value)
      local cache_key = get_local_key(conf, identifier)
      local newval, err = shm:incr(cache_key, value, 0)
      if not newval then
        kong.log.err("could not increment counter: ", err)
        return nil, err
      end

      return true
    end,
    decrement = function(conf, identifier, value)
      local cache_key = get_local_key(conf, identifier)
      local newval, err = shm:incr(cache_key, -1*value, 0) -- no shm:decr sadly
      if not newval then
        kong.log.err("could not increment counter: ", err)
        return nil, err
      end

      return true
    end,
    usage = function(conf, identifier)
      local cache_key = get_local_key(conf, identifier)

      local current_metric, err = shm:get(cache_key)
      if err then
        return nil, err
      end

      if current_metric == nil or current_metric < 0 then
        current_metric = 0
        shm:set(cache_key, 0)
      end

      return current_metric or 0
    end
  },
  ["redis"] = {
    increment = function(conf, identifier, value)
      local red, err = get_redis_connection(conf)
      if not red then
        kong.log.err("failed to connect to Redis: ", err)
        return nil, err
      end

      local cache_key = get_local_key(conf, identifier)

      red:init_pipeline()
      red:incrby(cache_key, value)

      local _, err = red:commit_pipeline()
      if err then
        kong.log.err("failed to commit pipeline in Redis: ", err)
        return nil, err
      end

      local ok, err = red:set_keepalive(10000, 100)
      if not ok then
        kong.log.err("failed to set Redis keepalive: ", err)
        return nil, err
      end

      return true
    end,
    decrement = function(conf, identifier, value)
      local red, err = get_redis_connection(conf)
      if not red then
        kong.log.err("failed to connect to Redis: ", err)
        return nil, err
      end

      local cache_key = get_local_key(conf, identifier)

      red:init_pipeline()
      red:decrby(cache_key, value)

      local _, err = red:commit_pipeline()
      if err then
        kong.log.err("failed to commit pipeline in Redis: ", err)
        return nil, err
      end

      local ok, err = red:set_keepalive(10000, 100)
      if not ok then
        kong.log.err("failed to set Redis keepalive: ", err)
        return nil, err
      end

      return true
    end,
    usage = function(conf, identifier)
      local red, err = get_redis_connection(conf)
      if not red then
        kong.log.err("failed to connect to Redis: ", err)
        return nil, err
      end

      local cache_key = get_local_key(conf, identifier)

      local current_metric, err = red:get(cache_key)
      if err then
        return nil, err
      end

      if current_metric == null or current_metric == nil or tonumber(current_metric) < 0 then
        current_metric = 0
        red:init_pipeline()
        red:set(cache_key, 0)
        local _, err = red:commit_pipeline()
        if err then
          kong.log.err("failed to commit pipeline in Redis: ", err)
        end
      end


      local ok, err = red:set_keepalive(10000, 100)
      if not ok then
        kong.log.err("failed to set Redis keepalive: ", err)
      end

      return current_metric or 0
    end
  }
}
