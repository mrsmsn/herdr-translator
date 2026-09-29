#!/usr/bin/env bash
# Shared helpers for herdr-translator.
# This file only defines functions; it has no side effects when sourced.

# cache_dir -> prints the cache directory (honours $XDG_CACHE_HOME).
cache_dir() {
  printf '%s/herdr-translate' "${XDG_CACHE_HOME:-$HOME/.cache}"
}

# _hash  (data on stdin) -> a hex digest, using whatever hasher is available
# (shasum on macOS, sha1sum on Linux, cksum as a last resort).
_hash() {
  if command -v shasum >/dev/null 2>&1; then
    shasum | awk '{print $1}'
  elif command -v sha1sum >/dev/null 2>&1; then
    sha1sum | awk '{print $1}'
  else
    cksum | awk '{print $1 "_" $2}'
  fi
}

# cache_key <text> <engines> <source> <target> -> stable hash for a request.
cache_key() {
  printf '%s\037%s\037%s\037%s' "$1" "$2" "$3" "$4" | _hash
}

# cache_get <key> -> prints cached body, exit 0 on hit / non-zero on miss.
cache_get() {
  local f
  f="$(cache_dir)/$1"
  [ -s "$f" ] || return 1
  cat -- "$f"
}

# cache_set <key>  (body read from stdin)
cache_set() {
  local dir
  dir="$(cache_dir)"
  mkdir -p -- "$dir"
  cat > "$dir/$1"
}
