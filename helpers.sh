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

# format_result <src-text> <translated> <source-lang> <target-lang>
# Emits an ANSI-coloured "original / translation" view for the pager.
format_result() {
  local src="$1" dst="$2" slang="$3" tlang="$4"
  local cyan green reset
  cyan=$'\033[1;36m'; green=$'\033[1;32m'; reset=$'\033[0m'
  printf '%s── Source (%s) ──%s\n' "$cyan" "$slang" "$reset"
  printf '%s\n\n' "$src"
  printf '%s── Translation (%s) ──%s\n' "$green" "$tlang" "$reset"
  printf '%s\n' "$dst"
}

# format_error <message>
format_error() {
  local red bold reset
  red=$'\033[1;31m'; bold=$'\033[1m'; reset=$'\033[0m'
  printf '%s── Translation error ──%s\n\n' "$red" "$reset"
  printf '%s\n\n' "$1"
  printf '%sHint:%s check the backends (translate-shell / curl / jq) and your\n' "$bold" "$reset"
  printf '      network connection.\n'
}
