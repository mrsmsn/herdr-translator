# herdr-translator

[日本語](README.ja.md)

A [herdr](https://herdr.dev) plugin that translates the selected text (or the
clipboard) and shows the result in a popup pane. Keyless by default: it uses
[translate-shell](https://github.com/soimort/translate-shell) and Google's
free endpoint, with engine fallback and a small on-disk cache.

## Requirements

- herdr >= 0.7.5
- bash, jq
- At least one engine backend:
  - `trans` (translate-shell) for the `trans` engine
  - `curl` for the `google` engine
- A clipboard tool for the fallback path: `pbpaste` (macOS), `wl-paste`
  (Wayland), or `xclip` (X11)

## Install

```sh
herdr plugin install mrsmsn/herdr-translator
```

Then bind the action in your herdr `config.toml`:

```toml
[[keys.command]]
key = "prefix+t"
type = "plugin_action"
command = "mrsmsn.translator.translate"
description = "translate selection/clipboard"
```

Reload with `herdr server reload-config` (or restart herdr).

## Usage

Select text in a pane (or copy it), then press `prefix+t`. The plugin looks for
the pane selection first and falls back to the OS clipboard. In copy mode you
can press the binding directly on a live selection — no yank needed — because
the action declares the `selection` context and receives the selection as
`selected_text`. The yank-based "select → `y` → `prefix+t`" flow also works
through the clipboard fallback.

When the detected source language equals the target language, the translation
direction is reversed to `target_lang_alt` (e.g. ja→en instead of en→ja).

### The popup view

The popup draws the result in herdr's own overlay style (the one `prefix+?`
uses): a dimmed subtitle with the translation direction, accent-coloured
`source` and `translation` sections, a scrollbar in the right gutter, and a
key-hint footer. Scroll with `j`/`k`, the arrow keys or `PageUp`/`PageDown`;
close with `esc`, `q` or `Enter`.

## Configuration

The plugin reads an optional shell config file from its herdr config
directory. Find the path with:

```sh
herdr plugin config-dir mrsmsn.translator
# ${XDG_CONFIG_HOME:-~/.config}/herdr/plugins/config/mrsmsn.translator
```

Create `config.sh` in that directory containing plain variable assignments.
All variables are optional; the defaults are:

```sh
ENGINES="trans google"    # engines tried in order: trans, google
SOURCE_LANG="auto"        # source language (auto = detect)
TARGET_LANG="ja"          # translation target
TARGET_LANG_ALT="en"      # target when the source already is TARGET_LANG
USE_CACHE="on"            # cache results under ~/.cache/herdr-translate
VIEWER="builtin"          # builtin = herdr-style view, pager = $PAGER_CMD
PAGER_CMD="less -R"       # pager used when VIEWER="pager"
VIEW_ACCENT="7fc8ff"      # section headers (defaults match herdr's tokyo-night)
VIEW_TEXT="c0caf5"        # body text
VIEW_DIM="565f89"         # subtitle, footer labels, scrollbar track
VIEW_THUMB="697196"       # scrollbar thumb
VIEW_ERROR="f7768e"       # error heading
```

The file is sourced on every invocation, so changes take effect immediately —
no re-install or reload needed.

## Development

Lint and tests run in a container; only `just` and `podman` are needed on the
host:

```sh
just check   # shellcheck + bats
```

## Known limitations

- The cache directory is fixed to `${XDG_CACHE_HOME:-~/.cache}/herdr-translate`
  (it doubles as the hand-off channel between the action and the popup stage).
- No "copy translation to clipboard" action yet (the tmux ancestor's
  `@translate_clipboard` was not ported).

## License

[MIT](LICENSE)
