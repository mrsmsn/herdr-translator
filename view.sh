#!/usr/bin/env bash
# Popup view for herdr-translator: draws the result the way herdr's own
# overlays (prefix+? keybinds, settings) look, since the plugin popup only
# supplies the border and title and leaves the interior to us.
# This file only defines functions; it has no side effects when sourced.

# Palette. Defaults match herdr's tokyo-night overlay chrome; override any of
# them from the plugin config file.
: "${VIEW_ACCENT:=7fc8ff}"   # section headers (herdr [ui].accent)
: "${VIEW_TEXT:=c0caf5}"     # body text
: "${VIEW_DIM:=565f89}"      # subtitle, footer labels, scrollbar track
: "${VIEW_THUMB:=697196}"    # scrollbar thumb
: "${VIEW_ERROR:=f7768e}"    # error heading

_view_fg() {
  local h="$1"
  printf '\033[38;2;%d;%d;%dm' "$((16#${h:0:2}))" "$((16#${h:2:2}))" "$((16#${h:4:2}))"
}

_view_reset() { printf '\033[0m'; }

# _view_plain <text> -> the text with SGR sequences removed.
_view_plain() {
  local s="$1"
  while [[ "$s" =~ $'\033'\[[0-9\;]*m ]]; do
    s="${s/"${BASH_REMATCH[0]}"/}"
  done
  printf '%s' "$s"
}

# _view_wide <codepoint> -> 0 when the character occupies two columns.
_view_wide() {
  local c="$1"
  (( (c >= 0x1100 && c <= 0x115F) ||
     (c >= 0x2E80 && c <= 0x303E) ||
     (c >= 0x3041 && c <= 0x33FF) ||
     (c >= 0x3400 && c <= 0x4DBF) ||
     (c >= 0x4E00 && c <= 0x9FFF) ||
     (c >= 0xA000 && c <= 0xA4CF) ||
     (c >= 0xAC00 && c <= 0xD7A3) ||
     (c >= 0xF900 && c <= 0xFAFF) ||
     (c >= 0xFE30 && c <= 0xFE6F) ||
     (c >= 0xFF00 && c <= 0xFF60) ||
     (c >= 0xFFE0 && c <= 0xFFE6) ||
     (c >= 0x1F300 && c <= 0x1F64F) ||
     (c >= 0x1F900 && c <= 0x1F9FF) ||
     (c >= 0x20000 && c <= 0x3FFFD) ))
}

# view_display_width <text> -> terminal columns the text occupies.
view_display_width() {
  local s ch cp w=0 i n
  s="$(_view_plain "$1")"
  n=${#s}
  for (( i = 0; i < n; i++ )); do
    ch="${s:i:1}"
    printf -v cp '%d' "'$ch"
    if (( cp >= 0x0300 && cp <= 0x036F )); then
      continue
    elif _view_wide "$cp"; then
      w=$(( w + 2 ))
    else
      w=$(( w + 1 ))
    fi
  done
  printf '%d' "$w"
}

# view_wrap <width>  (text on stdin) -> lines that each fit <width> columns.
# Breaks on the last space, but only once past the halfway mark: CJK text often
# carries a single early space, and breaking there would leave a near-empty line.
view_wrap() {
  local width="$1" line
  while IFS= read -r line || [ -n "$line" ]; do
    if [ -z "$line" ]; then
      printf '\n'
      continue
    fi
    local cur="" curw=0 space_at=-1 space_w=0 i n ch cp cw
    n=${#line}
    for (( i = 0; i < n; i++ )); do
      ch="${line:i:1}"
      printf -v cp '%d' "'$ch"
      if _view_wide "$cp"; then cw=2; else cw=1; fi
      if (( curw + cw > width )); then
        if (( space_at >= 0 && space_w * 2 >= width )); then
          printf '%s\n' "${cur:0:space_at}"
          cur="${cur:space_at+1}"
        else
          printf '%s\n' "$cur"
          cur=""
        fi
        curw="$(view_display_width "$cur")"
        space_at=-1
        space_w=0
      fi
      cur+="$ch"
      curw=$(( curw + cw ))
      if [ "$ch" = " " ]; then
        space_at=$(( ${#cur} - 1 ))
        space_w=$(( curw - 1 ))
      fi
    done
    printf '%s\n' "$cur"
  done
}

# _view_section <title> -> an accent-coloured section header line.
_view_section() {
  printf '%s %s%s\n' "$(_view_fg "$VIEW_ACCENT")" "$1" "$(_view_reset)"
}

# _view_body <width>  (text on stdin) -> indented body lines.
_view_body() {
  local text_fg reset line
  text_fg="$(_view_fg "$VIEW_TEXT")"
  reset="$(_view_reset)"
  while IFS= read -r line; do
    printf '%s %s%s\n' "$text_fg" "$line" "$reset"
  done < <(view_wrap "$(( $1 - 1 ))")
}

# view_content <source-text> <translation> <width> -> scrollable content lines.
view_content() {
  _view_section "source"
  printf '%s' "$1" | _view_body "$3"
  printf '\n'
  _view_section "translation"
  printf '%s' "$2" | _view_body "$3"
}

# _view_dim_body <width>  (text on stdin) -> indented, dimmed body lines.
_view_dim_body() {
  local dim reset line
  dim="$(_view_fg "$VIEW_DIM")"
  reset="$(_view_reset)"
  while IFS= read -r line; do
    printf '%s %s%s\n' "$dim" "$line" "$reset"
  done < <(view_wrap "$(( $1 - 1 ))")
}

# view_error_content <message> <width> -> scrollable content lines for a failure.
view_error_content() {
  printf '%s %s%s\n' "$(_view_fg "$VIEW_ERROR")" "translation error" "$(_view_reset)"
  printf '%s' "$1" | _view_body "$2"
  printf '\n'
  printf '%s' "check the backends (translate-shell / curl / jq) and the network connection." \
    | _view_dim_body "$2"
}

# view_max_offset <line-count> <height> -> largest scroll offset that still
# fills the content region.
view_max_offset() {
  local rows=$(( $2 - 4 ))
  (( rows < 1 )) && rows=1
  local max=$(( $1 - rows ))
  (( max < 0 )) && max=0
  printf '%d' "$max"
}

# _view_footer <width> -> the key-hint line.
_view_footer() {
  local dim key reset
  dim="$(_view_fg "$VIEW_DIM")"
  key="$(_view_fg "$VIEW_TEXT")"
  reset="$(_view_reset)"
  printf '%s scroll %sj/k/↑↓/pgup/pgdn%s · close %sesc/q%s\n' \
    "$dim" "$key" "$dim" "$key" "$reset"
}

# view_render <content-file> <subtitle> <offset> <width> <height>
# Paints one full frame: subtitle, blank, scrollable region with a scrollbar,
# blank, footer. Always emits exactly <height> lines.
view_render() {
  local file="$1" subtitle="$2" offset="$3" width="$4" height="$5"
  local rows=$(( height - 4 ))
  (( rows < 1 )) && rows=1

  local -a content=()
  mapfile -t content < "$file"
  local total=${#content[@]}

  local max thumb_len thumb_start=0 bar=0
  max="$(view_max_offset "$total" "$height")"
  (( offset > max )) && offset="$max"
  (( offset < 0 )) && offset=0
  if (( total > rows )); then
    bar=1
    thumb_len=$(( rows * rows / total ))
    (( thumb_len < 1 )) && thumb_len=1
    (( max > 0 )) && thumb_start=$(( offset * (rows - thumb_len) / max ))
  fi

  printf '%s %s%s\n' "$(_view_fg "$VIEW_DIM")" "$subtitle" "$(_view_reset)"
  printf '\n'

  local i line plain pad
  for (( i = 0; i < rows; i++ )); do
    line="${content[offset + i]:-}"
    if (( bar )); then
      plain="$(_view_plain "$line")"
      pad=$(( width - 1 - $(view_display_width "$plain") ))
      (( pad < 0 )) && pad=0
      if (( i >= thumb_start && i < thumb_start + thumb_len )); then
        printf '%s%*s%s▐%s\n' "$line" "$pad" "" "$(_view_fg "$VIEW_THUMB")" "$(_view_reset)"
      else
        printf '%s%*s%s▕%s\n' "$line" "$pad" "" "$(_view_fg "$VIEW_DIM")" "$(_view_reset)"
      fi
    else
      printf '%s\n' "$line"
    fi
  done

  printf '\n'
  _view_footer "$width"
}
