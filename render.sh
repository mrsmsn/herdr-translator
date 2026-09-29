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
# shellcheck source=view.sh
source "$SCRIPT_DIR/view.sh"

# Defaults, overridable from the plugin's config file (the path matches what
# `herdr plugin config-dir mrsmsn.translator` prints), then frozen.
ENGINES="trans google"
SOURCE_LANG="auto"
TARGET_LANG="ja"
TARGET_LANG_ALT="en"
USE_CACHE="on"
VIEWER="builtin"          # builtin = herdr-style popup view, pager = $PAGER_CMD
PAGER_CMD="less -R"

CONFIG_FILE="${XDG_CONFIG_HOME:-$HOME/.config}/herdr/plugins/config/mrsmsn.translator/config.sh"
if [ -f "$CONFIG_FILE" ]; then
  # shellcheck source=/dev/null
  source "$CONFIG_FILE"
fi
readonly ENGINES SOURCE_LANG TARGET_LANG TARGET_LANG_ALT USE_CACHE VIEWER PAGER_CMD

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

# produce_result <text> <content-file> <subtitle-file> <width>
# Writes the scrollable view content and its subtitle. Always exits 0 so a
# backgrounded call never trips the parent's set -e.
produce_result() {
  local text="$1" content_file="$2" subtitle_file="$3" width="$4"

  local key resolved_target translated ok=0 cached=0 err=""
  key="$(cache_key "$text" "$ENGINES" "$SOURCE_LANG" "$TARGET_LANG|$TARGET_LANG_ALT")"
  resolved_target="$TARGET_LANG"

  if [ "$USE_CACHE" = on ]; then
    local record
    if record="$(cache_get "$key")"; then
      resolved_target="${record%%$'\n'*}"
      translated="${record#*$'\n'}"
      ok=1
      cached=1
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
    printf '%s → %s%s' "$SOURCE_LANG" "$resolved_target" \
      "$([ "$cached" -eq 1 ] && printf ' · cached')" > "$subtitle_file"
    view_content "$text" "$translated" "$width" > "$content_file"
  else
    printf 'translation failed' > "$subtitle_file"
    view_error_content "${err:-Translation failed.}" "$width" > "$content_file"
  fi
  return 0
}

# term_size -> "<rows> <cols>" of the controlling terminal. tput would trust the
# inherited $LINES/$COLUMNS, which describe the pane that opened the popup.
term_size() {
  local size
  size="$(stty size 2>/dev/null)" || size=""
  case "$size" in
    [0-9]*' '[0-9]*) printf '%s' "$size" ;;
    *) printf '24 80' ;;
  esac
}

# spinner <pid> <message> : animate until <pid> exits, then clear the line.
spinner() {
  local pid="$1" msg="$2" i=0 accent dim reset
  local frames=(⠋ ⠙ ⠹ ⠸ ⠼ ⠴ ⠦ ⠧ ⠇ ⠏)
  accent="$(_view_fg "$VIEW_ACCENT")"; dim="$(_view_fg "$VIEW_DIM")"; reset="$(_view_reset)"
  tput civis 2>/dev/null || true
  while kill -0 "$pid" 2>/dev/null; do
    printf '\r %s%s%s %s%s%s' "$accent" "${frames[i % ${#frames[@]}]}" "$reset" "$dim" "$msg" "$reset"
    i=$(( i + 1 ))
    sleep 0.1 2>/dev/null || true
  done
  printf '\r\033[K'
  tput cnorm 2>/dev/null || true
}

# view_loop <content-file> <subtitle> : interactive popup view. Redraws on
# resize and returns when the reader closes it (esc / q / enter), which exits
# the process and lets herdr tear the popup down.
view_loop() {
  local file="$1" subtitle="$2" offset=0 total resized="" key seq c
  total="$(wc -l < "$file")"

  local saved_tty
  saved_tty="$(stty -g 2>/dev/null || true)"
  # shellcheck disable=SC2064
  trap "stty '$saved_tty' 2>/dev/null; printf '\033[?25h\033[0m\033[2J\033[H'" EXIT
  trap 'resized=1' WINCH
  stty -echo -icanon min 1 time 0 2>/dev/null || true
  printf '\033[?25l'

  while :; do
    local rows cols step frame
    read -r rows cols <<< "$(term_size)"
    step=$(( rows - 4 ))
    (( step < 1 )) && step=1

    # Command substitution drops the trailing newline, which would otherwise
    # scroll the popup by one row and push the subtitle out of view.
    frame="$(view_render "$file" "$subtitle" "$offset" "$cols" "$rows")"
    printf '\033[H\033[2J%s' "$frame"

    if ! IFS= read -rsn1 key; then
      [ -n "$resized" ] || break
      resized=""
      continue
    fi

    case "$key" in
      q|$'\n'|$'\r') break ;;
      j) offset=$(( offset + 1 )) ;;
      k) offset=$(( offset - 1 )) ;;
      $'\033')
        seq=""
        while IFS= read -rsn1 -t 0.02 c; do
          seq+="$c"
          [[ "$c" =~ [A-Za-z~] ]] && break
        done
        case "$seq" in
          "") break ;;
          "[A") offset=$(( offset - 1 )) ;;
          "[B") offset=$(( offset + 1 )) ;;
          "[5~") offset=$(( offset - step )) ;;
          "[6~") offset=$(( offset + step )) ;;
        esac
        ;;
    esac

    local max
    max="$(view_max_offset "$total" "$rows")"
    (( offset > max )) && offset="$max"
    (( offset < 0 )) && offset=0
  done
}

main() {
  local srcfile text
  srcfile="$(cache_dir)/src.txt"
  [ -s "$srcfile" ] || { echo "herdr-translator: nothing to translate"; exit 0; }
  text="$(cat -- "$srcfile")"
  rm -f -- "$srcfile"

  load_engines "$ENGINES"

  local rows cols
  read -r rows cols <<< "$(term_size)"

  local contentfile subtitlefile pid
  contentfile="$(mktemp "${TMPDIR:-/tmp}/herdr-translate.XXXXXX")"
  subtitlefile="$contentfile.subtitle"
  # cols - 2 leaves room for the one-column indent and the scrollbar gutter.
  produce_result "$text" "$contentfile" "$subtitlefile" "$(( cols - 2 ))" &
  pid=$!
  spinner "$pid" "translating…"
  wait "$pid" 2>/dev/null || true

  local subtitle
  subtitle="$(cat -- "$subtitlefile")"

  if [ "$VIEWER" = pager ]; then
    local pager_arr
    read -r -a pager_arr <<< "$PAGER_CMD"
    "${pager_arr[@]}" "$contentfile"
  elif [ -t 0 ] && [ -t 1 ]; then
    view_loop "$contentfile" "$subtitle"
  else
    # No terminal to drive (tests, pipes): paint the frame once.
    view_render "$contentfile" "$subtitle" 0 "$cols" "$(( $(wc -l < "$contentfile") + 4 ))"
  fi

  rm -f -- "$contentfile" "$subtitlefile"
}

if [ "${BASH_SOURCE[0]}" = "${0}" ]; then
  main "$@"
fi
