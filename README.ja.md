# herdr-translator

[English](README.md)

選択テキスト (またはクリップボード) を翻訳してポップアップペインに表示する
[herdr](https://herdr.dev) プラグイン。デフォルトで API キー不要:
[translate-shell](https://github.com/soimort/translate-shell) と Google の
無料エンドポイントを使い、エンジンのフォールバックとディスクキャッシュを持つ。

## 必要なもの

- herdr >= 0.7.5
- bash, jq
- エンジンバックエンドのいずれか:
  - `trans` (translate-shell) — `trans` エンジン用
  - `curl` — `google` エンジン用
- クリップボードフォールバック用ツール: `pbpaste` (macOS) / `wl-paste`
  (Wayland) / `xclip` (X11)

## インストール

```sh
herdr plugin install mrsmsn/herdr-translator
```

herdr の `config.toml` にアクションのキーバインドを追加:

```toml
[[keys.command]]
key = "prefix+t"
type = "plugin_action"
command = "mrsmsn.translator.translate"
description = "translate selection/clipboard"
```

`herdr server reload-config` (または herdr 再起動) で反映。

## 使い方

ペインでテキストを選択 (またはコピー) して `prefix+t`。選択テキストを優先し、
無ければ OS クリップボードにフォールバックする。アクションが `selection`
context を宣言しているため、コピーモード中の選択に対して yank せずそのまま
バインドを押せば `selected_text` として渡る。yank してからの
「選択 → `y` → `prefix+t`」もクリップボード経由で使える。

検出した原文の言語が翻訳先と同じ場合は、翻訳方向を `TARGET_LANG_ALT` に
反転する (例: en→ja の設定なら ja のテキストは ja→en になる)。

## 設定

herdr のプラグイン設定ディレクトリに置いた shell 設定ファイルを読む (任意)。
パスは次で確認できる:

```sh
herdr plugin config-dir mrsmsn.translator
# ${XDG_CONFIG_HOME:-~/.config}/herdr/plugins/config/mrsmsn.translator
```

そのディレクトリに変数代入だけを書いた `config.sh` を作る。すべて省略可能で、
デフォルトは:

```sh
ENGINES="trans google"    # この順で試すエンジン: trans, google
SOURCE_LANG="auto"        # 原文の言語 (auto = 自動検出)
TARGET_LANG="ja"          # 翻訳先
TARGET_LANG_ALT="en"      # 原文が TARGET_LANG と同じときの翻訳先
USE_CACHE="on"            # ~/.cache/herdr-translate に結果をキャッシュ
PAGER_CMD="less -R"       # 結果表示に使う pager
```

このファイルは実行のたびに source されるので、変更は即座に反映される
(再インストールや reload は不要)。

## 開発

lint とテストはコンテナ内で実行される。ホストに必要なのは `just` と
`podman` だけ:

```sh
just check   # shellcheck + bats
```

## 既知の制限

- キャッシュディレクトリは `${XDG_CACHE_HOME:-~/.cache}/herdr-translate`
  固定 (アクション → ポップアップ間のデータ受け渡しにも使っている)。
- 「翻訳結果をクリップボードへコピー」は未実装 (tmux 版の
  `@translate_clipboard` 相当は未移植)。

## ライセンス

[MIT](LICENSE)
