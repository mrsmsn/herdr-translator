#!/usr/bin/env bats

setup() {
  load test_helper
  setup_sandbox
  MANIFEST="$PROJECT_ROOT/herdr-plugin.toml"
}

teardown() {
  teardown_sandbox
}

@test "pane placement is popup" {
  # Since herdr 0.7.5, width/height are only valid with placement = "popup";
  # any other combination invalidates the whole manifest.
  grep -q '^placement = "popup"$' "$MANIFEST"
  ! grep -q '^placement = "overlay"$' "$MANIFEST"
}

@test "manifest commands point at existing executable scripts" {
  local count=0 script
  while read -r script; do
    [ -x "$PROJECT_ROOT/$script" ]
    count=$((count + 1))
  done < <(sed -n 's|^command = \["\./\(.*\)"\]|\1|p' "$MANIFEST")
  [ "$count" -eq 2 ]
}

@test "translate action is available in pane and selection contexts" {
  # "selection" lets the action fire on a live copy-mode selection (no yank),
  # passing it to the plugin as selected_text.
  grep -q '^contexts = \["pane", "selection"\]$' "$MANIFEST"
}

@test "plugin id matches the pane-open call in translate.sh" {
  grep -q '^id = "mrsmsn.translator"$' "$MANIFEST"
  grep -q -- '--plugin mrsmsn.translator' "$PROJECT_ROOT/translate.sh"
}
