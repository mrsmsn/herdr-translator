#!/usr/bin/env bats

setup() {
  load test_helper
  setup_sandbox
}

teardown() {
  teardown_sandbox
}

@test "empty selection and clipboard is a no-op" {
  export STUB_PBPASTE_OUT="   "
  run_translate
  [ "$status" -eq 0 ]
  [ ! -s "$STUB_HERDR_LOG" ]
  [ ! -e "$XDG_CACHE_HOME/herdr-translate/src.txt" ]
}

@test "prefers the selected text from the plugin context" {
  export HERDR_PLUGIN_CONTEXT_JSON='{"selected_text":"from context"}'
  export STUB_PBPASTE_OUT="from clipboard"
  run_translate
  [ "$status" -eq 0 ]
  [ "$(cat "$XDG_CACHE_HOME/herdr-translate/src.txt")" = "from context" ]
}

@test "falls back to the clipboard when no selection" {
  export STUB_PBPASTE_OUT="from clipboard"
  run_translate
  [ "$status" -eq 0 ]
  [ "$(cat "$XDG_CACHE_HOME/herdr-translate/src.txt")" = "from clipboard" ]
}

@test "trims surrounding whitespace" {
  export STUB_PBPASTE_OUT=$'  hello \n'
  run_translate
  [ "$status" -eq 0 ]
  [ "$(cat "$XDG_CACHE_HOME/herdr-translate/src.txt")" = "hello" ]
}

@test "opens the popup pane via herdr" {
  export STUB_PBPASTE_OUT="Hello, world"
  run_translate
  [ "$status" -eq 0 ]
  grep -q -- 'plugin pane open --plugin mrsmsn.translator --entrypoint popup' \
    "$STUB_HERDR_LOG"
}
