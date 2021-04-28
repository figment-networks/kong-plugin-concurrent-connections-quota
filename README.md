# kong-plugin-concurrent-connections-quota

Kong plugin to make sure user can have a limited number of WebSocket connections at a time.

## Testing

To run lint and tests install
[kong-pongo](https://github.com/Kong/kong-pongo#installation)
(tooling to run kong plugin tests)

```sh
$ pongo lint
```

```sh
$ KONG_VERSION=nightly pongo run
```

## Releasing
Plugin versions are uploaded to
[luarocks.org](https://luarocks.org/modules/figment/kong-plugin-concurrent-connections-quota)

To release a new plugin version (run from main branch):
```sh
# Install lua-cjson if missing
$ luarocks remove lua-cjson
$ luarocks install lua-cjson 2.1.0-1 #https://github.com/mpx/lua-cjson/issues/56#issuecomment-394764240

# Bump version, rename rockspec but DO NOT create a Git tag and DO NOT publish to github and luarocks.org
$ make release VERSION=X.Y.Z DRY=1

# Bump version, rename rockspec, create a Git tag, and publish to luarocks.org
$ make release VERSION=X.Y.Z
```
