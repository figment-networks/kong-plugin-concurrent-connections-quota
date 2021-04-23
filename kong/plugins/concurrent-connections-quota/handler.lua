local policies = require "kong.plugins.concurrent-connections-quota.policies"
local kong = kong
local max = math.max
local timer_at = ngx.timer.at


local ConcurrentConnectionsQuotaHandler = {
   PRIORITY = 901,
   VERSION = "0.1.0",
}

local EMPTY = {}
local RATELIMIT_LIMIT     = "Quota-Limit"
local RATELIMIT_REMAINING = "Quota-Remaining"

local function get_identifier(conf)
  local identifier= (kong.client.get_consumer() or
                    kong.client.get_credential() or
                    EMPTY).id
  return identifier or kong.client.get_forwarded_ip()
end

local function get_usage(conf, identifier)
  local stop = false
  local limit = conf.limit

  local current_usage, err = policies[conf.policy].usage(conf, identifier)
  if err then
    return nil, nil, err
  end

  -- What is the current usage for the configured limit name?
  local remaining = limit - current_usage

  -- Recording usage
  local usage = {
    remaining = remaining,
  }

  if remaining <= 0 then
    stop = true
  end

  return usage, stop
end

local function increment(premature, conf, identifier, value)
  if premature then
    return
  end

  policies[conf.policy].increment(conf, identifier, value)
  get_usage(conf, identifier)
end

local function decrement(premature, conf, identifier, value)
  if premature then
    return
  end

  policies[conf.policy].decrement(conf, identifier, value)
  get_usage(conf, identifier)
end

function ConcurrentConnectionsQuotaHandler:access(conf)
  local identifier = get_identifier(conf)
  kong.ctx.plugin.identifier = identifier
  local fault_tolerant = conf.fault_tolerant

  local limit = conf.limit

  local usage, stop, err = get_usage(conf, identifier)
  if err then
    if not fault_tolerant then
      return error(err)
    end

    kong.log.err("failed to get usage: ", tostring(err))
  end

  if usage then
    -- Adding headers
    if not conf.hide_client_headers then
      local headers = {}
      local current_remaining = usage.remaining
      if not stop then
        current_remaining = current_remaining - 1
      end
      current_remaining = max(0, current_remaining)

      headers[RATELIMIT_LIMIT] = limit
      headers[RATELIMIT_REMAINING] = current_remaining

      kong.ctx.plugin.headers = headers
    end

    -- If limit is exceeded, terminate the request
    if stop then
      return kong.response.error(429, "API rate limit exceeded")
    end
  end

  local ok, err = timer_at(0, increment, conf, identifier, 1)
  if not ok then
    kong.log.err("failed to create increment timer: ", err)
  end
end

function ConcurrentConnectionsQuotaHandler:header_filter(_)
  local headers = kong.ctx.plugin.headers
  if headers then
    kong.response.set_headers(headers)
  end
end

function ConcurrentConnectionsQuotaHandler:log(conf)
  local identifier = kong.ctx.plugin.identifier
  local ok, err = timer_at(0, decrement, conf, identifier, 1)
  if not ok then
    kong.log.err("failed to create decrement timer: ", err)
  end
end

return ConcurrentConnectionsQuotaHandler
