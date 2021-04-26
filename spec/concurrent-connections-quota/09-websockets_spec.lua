local client = require "resty.websocket.client"
local helpers = require "spec.helpers"
local cjson = require "cjson"

local PLUGIN_NAME = "concurrent-connections-quota"
local auth_key    = "kong"
local auth_key2   = "godzilla"
local redis_host  = helpers.redis_host
local redis_port  = 6379
local strategy    = "postgres"

describe("Websockets [#" .. strategy .. "]", function()
  lazy_setup(function()
    local bp = helpers.get_db_utils(strategy, {
      "routes",
      "services",
      "plugins",
      "consumers",
      "keyauth_credentials",
    }, { PLUGIN_NAME })

    local service = bp.services:insert {
      name = "ws",
      path = "/ws",
    }

    local route = bp.routes:insert {
      protocols   = { "http" },
      paths       = { "/up-ws" },
      service     = service,
      strip_path  = true,
    }

    local consumer = bp.consumers:insert {
      username = "bob"
    }

    bp.keyauth_credentials:insert {
      key      = auth_key,
      consumer = { id = consumer.id },
    }

    local consumer2 = bp.consumers:insert {
      username = "go"
    }

    bp.keyauth_credentials:insert {
      key      = auth_key2,
      consumer = { id = consumer2.id },
    }

    bp.plugins:insert {
      name = PLUGIN_NAME,
      consumer = { id = consumer.id },
      config = {
        limit = 1,
        policy = "redis",
        redis_host = redis_host,
        redis_port = redis_port
      }
    }

    bp.plugins:insert {
      name = PLUGIN_NAME,
      consumer = { id = consumer2.id },
      config = {
        limit = 1,
        policy = "redis",
        redis_host = redis_host,
        redis_port = redis_port
      }
    }

    bp.plugins:insert {
      name = "key-auth",
      service = { id = service.id },
      config = {
        key_names =  { "apikey", "Authorization", "X-Api-Key" },
        hide_credentials = false,
      }
    }

    assert(helpers.start_kong({
      database   = strategy,
      nginx_conf = "spec/fixtures/custom_nginx.template",
      plugins = "bundled," .. PLUGIN_NAME,
    }))
  end)

  lazy_teardown(function()
    helpers.stop_kong(nil, true)
  end)

  local function open_socket(uri, auth_key)
    local wc = assert(client:new())
    assert(wc:connect(uri, {
      headers = { "apikey:" .. auth_key }
    }))
    return wc
  end

  describe("text", function()
    local function send_text_and_get_echo(uri)
      local payload = { message = "hello websocket" }
      local wc      = open_socket(uri, auth_key)

      assert(wc:send_text(cjson.encode(payload)))
      local frame, typ, err = wc:recv_frame()
      assert.is_nil(wc.fatal)
      assert(frame, err)
      assert.equal("text", typ)
      assert.same(payload, cjson.decode(frame))

      assert(wc:send_close())
    end

    it("sends and gets text without Kong", function()
      send_text_and_get_echo("ws://127.0.0.1:15555/ws")
    end)

    it("sends and gets text with Kong", function()
      send_text_and_get_echo("ws://" .. helpers.get_proxy_ip(false) ..
      ":" .. helpers.get_proxy_port(false) .. "/up-ws")
    end)

    it("sends and gets text with kong under HTTPS", function()
      send_text_and_get_echo("wss://" .. helpers.get_proxy_ip(true) ..
      ":" .. helpers.get_proxy_port(true) .. "/up-ws")
    end)
  end)

  describe("ping pong", function()
    local function send_ping_and_get_pong(uri)
      local payload = { message = "give me a pong" }
      local wc      = open_socket(uri, auth_key)

      assert(wc:send_ping(cjson.encode(payload)))
      local frame, typ, err = wc:recv_frame()
      assert.is_nil(wc.fatal)
      assert(frame, err)
      assert.equal("pong", typ)
      assert.same(payload, cjson.decode(frame))

      assert(wc:send_close())
    end

    it("plays ping-pong without Kong", function()
      send_ping_and_get_pong("ws://127.0.0.1:15555/ws")
    end)

    it("plays ping-pong with Kong", function()
      send_ping_and_get_pong("ws://" .. helpers.get_proxy_ip(false) ..
      ":" .. helpers.get_proxy_port(false) .. "/up-ws")
    end)

    it("plays ping-pong with kong under HTTPS", function()
      send_ping_and_get_pong("wss://" .. helpers.get_proxy_ip(true) ..
      ":" .. helpers.get_proxy_port(true) .. "/up-ws")
    end)
  end)

  describe("multiple users", function()
    it("has own quota", function()
      local payload = { message = "give me a pong" }
      local uri = "ws://" .. helpers.get_proxy_ip(false) ..  ":" .. helpers.get_proxy_port(false) .. "/up-ws"
      local wc1      = open_socket(uri, auth_key)
      local wc2      = open_socket(uri, auth_key2)

      assert(wc1:send_ping(cjson.encode(payload)))
      local frame, typ, err = wc1:recv_frame()
      assert.is_nil(wc1.fatal)
      assert(frame, err)
      assert.equal("pong", typ)

      assert(wc2:send_ping(cjson.encode(payload)))
      local frame, typ, err = wc2:recv_frame()
      assert.is_nil(wc1.fatal)
      assert(frame, err)
      assert.equal("pong", typ)

      wc1:close()
      wc2:close()
    end)
  end)

  describe("quota used", function()
    it("send 429 error code", function()
      local payload = { message = "give me a pong" }
      local uri = "ws://" .. helpers.get_proxy_ip(false) ..  ":" .. helpers.get_proxy_port(false) .. "/up-ws"
      local wc1      = open_socket(uri, auth_key)
      local wc2      = open_socket(uri, auth_key)

      assert(wc1:send_ping(cjson.encode(payload)))
      local frame, typ, err = wc1:recv_frame()
      assert.is_nil(wc1.fatal)
      assert(frame, err)
      assert.equal("pong", typ)

      assert(wc2:send_ping(cjson.encode(payload)))
      wc2:recv_frame()
      assert.is_not_nil(wc2.fatal)

      wc1:close()
      wc2:close()
    end)

    it("send 429 error code under HTTPS", function()
      local payload = { message = "give me a pong" }
      local uri = "wss://" .. helpers.get_proxy_ip(true) ..  ":" .. helpers.get_proxy_port(true) .. "/up-ws"
      local wc1      = open_socket(uri, auth_key)
      local wc2      = open_socket(uri, auth_key)

      assert(wc1:send_ping(cjson.encode(payload)))
      local frame, typ, err = wc1:recv_frame()
      assert.is_nil(wc1.fatal)
      assert(frame, err)
      assert.equal("pong", typ)

      assert(wc2:send_ping(cjson.encode(payload)))
      wc2:recv_frame()
      assert.is_not_nil(wc2.fatal)

      wc1:close()
      wc2:close()
    end)
  end)
end)
