local typedefs = require "kong.db.schema.typedefs"


return {
  name = "concurrent-connections-quota",
  fields = {
    { protocols = typedefs.protocols_http },
    { config = {
      type = "record",
      fields = {
        { limit = {
          type = "number",
          default = 10,
          required = true,
          gt = 0
        }, },
        { limit_by = {
          type = "string",
          default = "consumer",
          one_of = { "consumer", "credential" },
        }, },
        { policy = {
          type = "string",
          default = "redis",
          len_min = 0,
          one_of = { "local", "redis" },
        }, },
        { fault_tolerant = { type = "boolean", default = true }, },
        { redis_host = typedefs.host },
        { redis_port = typedefs.port({ default = 6379 }), },
        { redis_password = { type = "string", len_min = 0 }, },
        { redis_timeout = { type = "number", default = 2000, }, },
        { redis_database = { type = "integer", default = 0 }, },
        { hide_client_headers = { type = "boolean", default = false }, },
      }
    },
  },
},
entity_checks = {
  { at_least_one_of = { "config.limit" } },
  { conditional = {
    if_field = "config.policy", if_match = { eq = "redis" },
    then_field = "config.redis_host", then_match = { required = true },
  } },
  { conditional = {
    if_field = "config.policy", if_match = { eq = "redis" },
    then_field = "config.redis_port", then_match = { required = true },
  } },
  { conditional = {
    if_field = "config.policy", if_match = { eq = "redis" },
    then_field = "config.redis_timeout", then_match = { required = true },
  } },
},
}
