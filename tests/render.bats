#!/usr/bin/env bats

setup() {
  load test_helper
  setup_sandbox
}

teardown() {
  teardown_sandbox
}

@test "runs with built-in defaults when no config file exists" {
  # Default ENGINES tries trans first (stubbed).
  run_render "Hello, world"
  [ "$status" -eq 0 ]
  [[ "$output" == *"こんにちは世界"* ]]
  [[ "$output" == *"translation"* ]]
}

@test "config file overrides engines and target language" {
  write_config 'ENGINES="google"' 'TARGET_LANG="fr"'
  export STUB_CURL_FIXTURE="$FIXTURES/google.json"
  export STUB_TRANS_EXIT=1   # would fail if trans were still consulted
  run_render "Bonjour"
  [ "$status" -eq 0 ]
  [[ "$output" == *"Hello, world"* ]]
  [[ "$output" == *"auto → fr"* ]]
}

@test "VIEWER=pager hands the content to PAGER_CMD" {
  write_config 'ENGINES="google"' 'VIEWER="pager"' 'PAGER_CMD="cat"'
  export STUB_CURL_FIXTURE="$FIXTURES/google.json"
  run_render "Bonjour"
  [ "$status" -eq 0 ]
  [[ "$output" == *"Hello, world"* ]]
  [[ "$output" != *"close esc/q"* ]]   # the frame belongs to the builtin view
}

@test "shows a loading spinner before the result" {
  write_config 'ENGINES="google"'
  export STUB_CURL_FIXTURE="$FIXTURES/google.json"
  run_render "Hello, world"
  [ "$status" -eq 0 ]
  [[ "$output" == *"translating"* ]]
}

@test "result is cached and served when the backend later fails" {
  write_config 'ENGINES="google"'
  export STUB_CURL_FIXTURE="$FIXTURES/google.json"
  run_render "Hello, world"
  [ "$status" -eq 0 ]
  [ -n "$(ls -A "$XDG_CACHE_HOME/herdr-translate" 2>/dev/null)" ]

  export STUB_CURL_EXIT=1
  run_render "Hello, world"
  [ "$status" -eq 0 ]
  [[ "$output" == *"Hello, world"* ]]
  [[ "$output" == *"cached"* ]]
}

@test "falls back to the next engine when the first fails" {
  write_config 'ENGINES="trans google"'
  export STUB_TRANS_EXIT=1
  export STUB_CURL_FIXTURE="$FIXTURES/google.json"
  run_render "Hello, world"
  [ "$status" -eq 0 ]
  [[ "$output" == *"Hello, world"* ]]
}

@test "reverses target language when the source already equals the target" {
  write_config 'ENGINES="google"' 'TARGET_LANG="ja"' 'TARGET_LANG_ALT="en"'
  export STUB_CURL_FIXTURE="$FIXTURES/google.json"   # detected lang = ja
  run_render "こんにちは世界"
  [ "$status" -eq 0 ]
  [[ "$output" == *"auto → en"* ]]
}

@test "renders an error when all engines fail" {
  write_config 'ENGINES="trans google"'
  export STUB_TRANS_EXIT=1
  export STUB_CURL_EXIT=1
  run_render "Hello, world"
  [ "$status" -eq 0 ]
  [[ "$output" == *"translation error"* ]]
}

@test "the view carries the herdr-style subtitle and key hints" {
  write_config 'ENGINES="google"' 'TARGET_LANG="fr"'
  export STUB_CURL_FIXTURE="$FIXTURES/google.json"
  run_render "Hello, world"
  [ "$status" -eq 0 ]
  local plain
  plain="$(printf '%s' "$output" | strip_ansi)"
  [[ "$plain" == *"auto → fr"* ]]
  [[ "$plain" == *"scroll j/k/↑↓/pgup/pgdn · close esc/q"* ]]
  [[ "$plain" == *" source"* ]]
}

@test "empty src file is a no-op" {
  run_render ""
  [ "$status" -eq 0 ]
  [[ "$output" == *"nothing to translate"* ]]
}
