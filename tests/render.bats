#!/usr/bin/env bats

setup() {
  load test_helper
  setup_sandbox
}

teardown() {
  teardown_sandbox
}

@test "runs with built-in defaults when no config file exists" {
  # Default ENGINES tries trans first (stubbed); default pager is the less stub.
  run_render "Hello, world"
  [ "$status" -eq 0 ]
  [[ "$output" == *"こんにちは世界"* ]]
  [[ "$output" == *"Translation ("* ]]
}

@test "config file overrides engines, target language and pager" {
  write_config 'ENGINES="google"' 'TARGET_LANG="fr"' 'PAGER_CMD="cat"'
  export STUB_CURL_FIXTURE="$FIXTURES/google.json"
  export STUB_TRANS_EXIT=1   # would fail if trans were still consulted
  run_render "Bonjour"
  [ "$status" -eq 0 ]
  [[ "$output" == *"Hello, world"* ]]
}

@test "shows a loading spinner before the result" {
  write_config 'ENGINES="google"' 'PAGER_CMD="cat"'
  export STUB_CURL_FIXTURE="$FIXTURES/google.json"
  run_render "Hello, world"
  [ "$status" -eq 0 ]
  [[ "$output" == *"Translating"* ]]
}

@test "result is cached and served when the backend later fails" {
  write_config 'ENGINES="google"' 'PAGER_CMD="cat"'
  export STUB_CURL_FIXTURE="$FIXTURES/google.json"
  run_render "Hello, world"
  [ "$status" -eq 0 ]
  [ -n "$(ls -A "$XDG_CACHE_HOME/herdr-translate" 2>/dev/null)" ]

  export STUB_CURL_EXIT=1
  run_render "Hello, world"
  [ "$status" -eq 0 ]
  [[ "$output" == *"Hello, world"* ]]
}

@test "falls back to the next engine when the first fails" {
  write_config 'ENGINES="trans google"' 'PAGER_CMD="cat"'
  export STUB_TRANS_EXIT=1
  export STUB_CURL_FIXTURE="$FIXTURES/google.json"
  run_render "Hello, world"
  [ "$status" -eq 0 ]
  [[ "$output" == *"Hello, world"* ]]
}

@test "reverses target language when the source already equals the target" {
  write_config 'ENGINES="google"' 'TARGET_LANG="ja"' 'TARGET_LANG_ALT="en"' \
    'PAGER_CMD="cat"'
  export STUB_CURL_FIXTURE="$FIXTURES/google.json"   # detected lang = ja
  run_render "こんにちは世界"
  [ "$status" -eq 0 ]
  [[ "$output" == *"Translation (en)"* ]]
}

@test "renders an error when all engines fail" {
  write_config 'ENGINES="trans google"' 'PAGER_CMD="cat"'
  export STUB_TRANS_EXIT=1
  export STUB_CURL_EXIT=1
  run_render "Hello, world"
  [ "$status" -eq 0 ]
  [[ "$output" == *"Translation error"* ]]
}

@test "empty src file is a no-op" {
  run_render ""
  [ "$status" -eq 0 ]
  [[ "$output" == *"nothing to translate"* ]]
}
