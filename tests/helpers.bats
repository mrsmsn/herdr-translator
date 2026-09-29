#!/usr/bin/env bats

setup() {
  load test_helper
  setup_sandbox
  source "$PROJECT_ROOT/helpers.sh"
}

teardown() {
  teardown_sandbox
}

@test "cache_dir honours XDG_CACHE_HOME" {
  run cache_dir
  [ "$output" = "$XDG_CACHE_HOME/herdr-translate" ]
}

@test "cache_key is stable and input-sensitive" {
  k1="$(cache_key "hello" "google" en ja)"
  k2="$(cache_key "hello" "google" en ja)"
  k3="$(cache_key "world" "google" en ja)"
  [ -n "$k1" ]
  [ "$k1" = "$k2" ]
  [ "$k1" != "$k3" ]
}

@test "cache_set then cache_get round-trips; miss returns non-zero" {
  printf 'cached-body' | cache_set abc123
  run cache_get abc123
  [ "$status" -eq 0 ]
  [ "$output" = "cached-body" ]

  run cache_get does-not-exist
  [ "$status" -ne 0 ]
}
