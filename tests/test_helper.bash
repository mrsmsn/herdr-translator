# Shared setup for bats tests. Source from each .bats file's setup().

setup_sandbox() {
  PROJECT_ROOT="$(cd -- "$BATS_TEST_DIRNAME/.." && pwd)"
  STUBS="$BATS_TEST_DIRNAME/stubs"
  FIXTURES="$BATS_TEST_DIRNAME/fixtures"

  # Prepend stubs so herdr/trans/curl/pbpaste/less are mocked.
  PATH="$STUBS:$PATH"
  export PATH

  SANDBOX="$(mktemp -d)"
  export HOME="$SANDBOX"
  export XDG_CONFIG_HOME="$SANDBOX/.config"
  export XDG_CACHE_HOME="$SANDBOX/.cache"
  export TMPDIR="$SANDBOX"
  export STUB_HERDR_LOG="$SANDBOX/herdr.log"
  : > "$STUB_HERDR_LOG"
  unset HERDR_PLUGIN_CONTEXT_JSON HERDR_BIN_PATH STUB_PBPASTE_OUT
}

teardown_sandbox() {
  [ -n "${SANDBOX:-}" ] && rm -rf -- "$SANDBOX"
}

# write_config <line>... -> creates the plugin's config.sh in the sandbox,
# at the same path `herdr plugin config-dir mrsmsn.translator` would print.
write_config() {
  local dir="$XDG_CONFIG_HOME/herdr/plugins/config/mrsmsn.translator"
  mkdir -p -- "$dir"
  printf '%s\n' "$@" > "$dir/config.sh"
}

# seed_src <text> -> stages src.txt the way translate.sh hands it to render.sh.
seed_src() {
  mkdir -p -- "$XDG_CACHE_HOME/herdr-translate"
  printf '%s' "$1" > "$XDG_CACHE_HOME/herdr-translate/src.txt"
}

# Run the entry stage (plugin action).
run_translate() {
  run bash "$PROJECT_ROOT/translate.sh"
}

# Run the popup (render) stage on the given text.
run_render() {
  seed_src "$1"
  run bash "$PROJECT_ROOT/render.sh"
}

# strip_ansi -> removes SGR escape sequences from stdin, so view tests can
# assert on plain text.
strip_ansi() {
  sed -E $'s/\033\\[[0-9;]*m//g'
}
