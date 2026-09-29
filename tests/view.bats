#!/usr/bin/env bats

setup() {
  load test_helper
  setup_sandbox
  source "$PROJECT_ROOT/view.sh"
}

teardown() {
  teardown_sandbox
}

@test "display width counts East Asian characters as two columns" {
  [ "$(view_display_width 'abc')" -eq 3 ]
  [ "$(view_display_width 'こんにちは')" -eq 10 ]
  [ "$(view_display_width 'a日')" -eq 3 ]
  [ "$(view_display_width '')" -eq 0 ]
}

@test "wrapping keeps every line within the given width" {
  local out
  out="$(printf 'the quick brown fox jumps over the lazy dog\n' | view_wrap 12)"
  [ "$(printf '%s\n' "$out" | wc -l)" -gt 1 ]
  while IFS= read -r line; do
    [ "$(view_display_width "$line")" -le 12 ]
  done <<< "$out"
}

@test "wrapping breaks East Asian text by display width" {
  local out
  out="$(printf 'あいうえおかきくけこ\n' | view_wrap 10)"
  [ "$(printf '%s\n' "$out" | sed -n 1p)" = "あいうえお" ]
  [ "$(printf '%s\n' "$out" | sed -n 2p)" = "かきくけこ" ]
}

@test "wrapping preserves blank lines and hard breaks" {
  local out
  out="$(printf 'one\n\ntwo\n' | view_wrap 20)"
  [ "$(printf '%s\n' "$out" | wc -l)" -eq 3 ]
  [ "$(printf '%s\n' "$out" | sed -n 2p)" = "" ]
}

@test "content shows source and translation sections" {
  local out
  out="$(view_content 'Hello' 'こんにちは' 40 | strip_ansi)"
  [[ "$out" == *"source"* ]]
  [[ "$out" == *"Hello"* ]]
  [[ "$out" == *"translation"* ]]
  [[ "$out" == *"こんにちは"* ]]
}

@test "error content carries the message" {
  local out
  out="$(view_error_content 'boom' 40 | strip_ansi)"
  [[ "$out" == *"error"* ]]
  [[ "$out" == *"boom"* ]]
}

@test "render emits exactly <height> lines with subtitle and footer" {
  local file out
  file="$SANDBOX/content"
  seq 1 30 > "$file"
  out="$(view_render "$file" 'en → ja' 0 40 12 | strip_ansi)"
  [ "$(printf '%s\n' "$out" | wc -l)" -eq 12 ]
  [[ "$(printf '%s\n' "$out" | sed -n 1p)" == *"en → ja"* ]]
  [[ "$(printf '%s\n' "$out" | sed -n 12p)" == *"close esc/q"* ]]
  [[ "$(printf '%s\n' "$out" | sed -n 12p)" == *"scroll"* ]]
}

@test "render scrolls the content region by the offset" {
  local file first
  file="$SANDBOX/content"
  seq 1 30 > "$file"
  first="$(view_render "$file" sub 0 40 12 | strip_ansi | sed -n 3p)"
  [ "$(printf '%s' "$first" | tr -d ' ▐▕')" = "1" ]
  first="$(view_render "$file" sub 5 40 12 | strip_ansi | sed -n 3p)"
  [ "$(printf '%s' "$first" | tr -d ' ▐▕')" = "6" ]
}

@test "render draws a scrollbar only when the content overflows" {
  local file out
  file="$SANDBOX/content"
  seq 1 30 > "$file"
  out="$(view_render "$file" sub 0 40 12 | strip_ansi)"
  [[ "$out" == *"▐"* ]]
  [[ "$out" == *"▕"* ]]

  seq 1 3 > "$file"
  out="$(view_render "$file" sub 0 40 12 | strip_ansi)"
  [[ "$out" != *"▐"* ]]
  [[ "$out" != *"▕"* ]]
}

@test "max offset stops at the last screenful" {
  [ "$(view_max_offset 30 12)" -eq 22 ]
  [ "$(view_max_offset 3 12)" -eq 0 ]
}

@test "wrapping ignores an early space that would leave a near-empty line" {
  local first
  first="$(printf 'ab あいうえおかきくけこさしすせそ\n' | view_wrap 20 | sed -n 1p)"
  [ "$(view_display_width "$first")" -ge 16 ]
}
