#!/usr/bin/env bash

set -euo pipefail
${TRACE:+set -x}

VERSION="${VERSION:-latest}"
HANDLER_FILE=./kong/plugins/concurrent-connections-quota/handler.lua
ROCKSPEC=$(find . -type f -name '*.rockspec')
LUAROCKS_API_KEY="${LUAROCKS_API_KEY}"

_red='' _blue='' _white='' _normal=''
if [[ -t 1 ]]; then
  _red='\033[1;31m'
  _blue='\033[1;34m'
  _white='\033[1;37m'
  _normal='\033[0m'
fi

info() {
  printf "${_blue}==> ${_white}%s${_normal}\\n" "$*" >&2
}

error() {
  printf "${_red}[ERROR]${_normal} %s\\n" "$*" >&2
}

fatal() {
  error "$*"
  exit 1
}

branch=$(git rev-parse --symbolic-full-name --abbrev-ref HEAD)

[[ "$VERSION" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]]     || fatal 'VERSION must be SemVer-formatted (X.Y.Z)!'
test "$branch" = main                            || fatal 'Can only release from "main" branch'
git diff-index --quiet HEAD                      || fatal 'Can not release because there are uncommitted changes!'
git rev-parse "$VERSION" >/dev/null 2>&1         && fatal "Version '$VERSION' already exists!"
test "$(git rev-parse --show-toplevel)" = "$PWD" || fatal "You must be in the root directory of this repository!"
sed --version | grep GNU >/dev/null 2>&1         || fatal "You must use GNU sed (brew install gnu-sed)"

info "Bumping version"
#use gnused
sed -i -e 's/\(\s*VERSION\s*=\s*"\)[^"]*/\1'$VERSION'/' $HANDLER_FILE
OLD_VERSION=$(echo $ROCKSPEC | sed -e 's/\([^0-9]*\)\([^\-]*\)\(.*\)/\2/')
sed -i -e 's/'$OLD_VERSION'/'$VERSION'/' $ROCKSPEC

info "Renaming rockspec"
NEW_ROCKSPEC=$(echo $ROCKSPEC | sed -e 's/'$OLD_VERSION'/'$VERSION'/')
git mv $ROCKSPEC "$NEW_ROCKSPEC"

if [ -n "${DRY:-}" ]; then
  info "Dry-run mode enabled (skipping git commit and luarocks upload)"
else
  info "Commit and tag version bump"
  git commit -m "Bump version to ${VERSION}" $HANDLER_FILE $NEW_ROCKSPEC $ROCKSPEC
  git tag -am "Auto-tagged version '$VERSION'" "$VERSION"
  git push origin "$branch" "$VERSION"
  info "Packing and uploading to luarocks"
  luarocks upload --api-key $LUAROCKS_API_KEY $NEW_ROCKSPEC
fi

info "Done!"
