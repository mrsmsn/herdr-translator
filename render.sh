#!/usr/bin/env bash
# herdr-translator popup stage.
# Runs inside the herdr plugin pane (placement=popup). Shows a spinner while
# the translation runs in the background, then displays the result in a pager.
# The text to translate is read from src.txt, written by translate.sh into
# cache_dir.
set -euo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=helpers.sh
source "$SCRIPT_DIR/helpers.sh"

# Defaults, overridable from the plugin's config file (the path matches what
# `herdr plugin config-dir mrsmsn.translator` prints), then frozen.
ENGINES="trans google"
SOURCE_LANG="auto"
TARGET_LANG="ja"
TARGET_LANG_ALT="en"
USE_CACHE="on"
PAGER_CMD="less -R"

CONFIG_FILE="${XDG_CONFIG_HOME:-$HOME/.config}/herdr/plugins/config/mrsmsn.translator/config.sh"
if [ -f "$CONFIG_FILE" ]; then
  # shellcheck source=/dev/null
  source "$CONFIG_FILE"
fi
readonly ENGINES SOURCE_LANG TARGET_LANG TARGET_LANG_ALT USE_CACHE PAGER_CMD

# load_engines <engines> -> sources each engine file that exists.
load_engines() {
  local eng
  for eng in $1; do
    if [ -f "$SCRIPT_DIR/engines/$eng.sh" ]; then
      # shellcheck source=/dev/null
      source "$SCRIPT_DIR/engines/$eng.sh"
    fi
  done
}

# detect_lang <text> <engines> -> first available engine's detected code.
detect_lang() {
  local text="$1" engines="$2" eng code
  for eng in $engines; do
    if declare -F "detect_$eng" >/dev/null; then
      if code="$("detect_$eng" "$text")" && [ -n "$code" ]; then
        printf '%s' "$code"
        return 0
      fi
    fi
  done
  return 1
}

# do_translate <text> <source> <target> <engines>
# Tries each engine in order; prints the first success, else fails with a
# summary on stderr (engine-level diagnostics are also forwarded to stderr).
do_translate() {
  local text="$1" source="$2" target="$3" engines="$4" eng out
  for eng in $engines; do
    if declare -F "translate_$eng" >/dev/null; then
      if out="$("translate_$eng" "$text" "$source" "$target")"; then
        printf '%s' "$out"
        return 0
      fi
    else
      echo "engine '$eng' is not defined" >&2
    fi
  done
  echo "All configured engines failed to translate." >&2
  return 1
}

# produce_result <text> -> formatted result (or error) on stdout.
# Always exits 0 so a backgrounded call never trips the parent's set -e.
produce_result() {
  local text="$1"

  local key resolved_target translated ok=0 err=""
  key="$(cache_key "$text" "$ENGINES" "$SOURCE_LANG" "$TARGET_LANG|$TARGET_LANG_ALT")"
  resolved_target="$TARGET_LANG"

  if [ "$USE_CACHE" = on ]; then
    local record
    if record="$(cache_get "$key")"; then
      resolved_target="${record%%$'\n'*}"
      translated="${record#*$'\n'}"
      ok=1
    fi
  fi

  if [ "$ok" -ne 1 ]; then
    # Language reversal: if auto-detected source equals target, flip to alt.
    if [ "$SOURCE_LANG" = auto ]; then
      local detected
      if detected="$(detect_lang "$text" "$ENGINES")" && [ "$detected" = "$TARGET_LANG" ]; then
        resolved_target="$TARGET_LANG_ALT"
      fi
    fi

    local errfile
    errfile="$(mktemp "${TMPDIR:-/tmp}/herdr-translate-err.XXXXXX")"
    if translated="$(do_translate "$text" "$SOURCE_LANG" "$resolved_target" "$ENGINES" 2>"$errfile")"; then
      ok=1
      [ "$USE_CACHE" = on ] && printf '%s\n%s' "$resolved_target" "$translated" | cache_set "$key"
    fi
    err="$(cat -- "$errfile")"
    rm -f -- "$errfile"
  fi

  if [ "$ok" -eq 1 ]; then
    format_result "$text" "$translated" "$SOURCE_LANG" "$resolved_target"
  else
    format_error "${err:-Translation failed.}"
  fi
  return 0
}

# spinner <pid> <message> : animate until <pid> exits, then clear the line.
spinner() {
  local pid="$1" msg="$2" i=0 cyan reset
  local frames=(⠋ ⠙ ⠹ ⠸ ⠼ ⠴ ⠦ ⠧ ⠇ ⠏)
  cyan=$'\033[1;36m'; reset=$'\033[0m'
  tput civis 2>/dev/null || true
  printf '%s%s%s %s' "$cyan" "${frames[0]}" "$reset" "$msg"
  while kill -0 "$pid" 2>/dev/null; do
    printf '\r%s%s%s %s' "$cyan" "${frames[i % ${#frames[@]}]}" "$reset" "$msg"
    i=$(( i + 1 ))
    sleep 0.1 2>/dev/null || true
  done
  printf '\r\033[K'
  tput cnorm 2>/dev/null || true
}

main() {
  local srcfile text
  srcfile="$(cache_dir)/src.txt"
  [ -s "$srcfile" ] || { echo "herdr-translator: nothing to translate"; exit 0; }
  text="$(cat -- "$srcfile")"
  rm -f -- "$srcfile"

  load_engines "$ENGINES"

  local resultfile pid
  resultfile="$(mktemp "${TMPDIR:-/tmp}/herdr-translate.XXXXXX")"
  produce_result "$text" > "$resultfile" &
  pid=$!
  spinner "$pid" "Translating…"
  wait "$pid" 2>/dev/null || true

  local pager_arr
  read -r -a pager_arr <<< "$PAGER_CMD"
  "${pager_arr[@]}" "$resultfile"
  rm -f -- "$resultfile"
}

if [ "${BASH_SOURCE[0]}" = "${0}" ]; then
  main "$@"
fi
