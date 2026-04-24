---
description: "Worktree作成・起動・停止・削除（全リポジトリ共通）"
argument-hint: "<create|up|down|remove|list> <リポジトリ名> [ブランチ名|issue番号]"
allowed-tools: ["Bash", "Read", "Glob", "Grep"]
---

# worktree: 並列開発環境管理

git worktree を使った並列開発環境の作成・起動・停止・削除を行う。
`worktree.sh` がエントリポイントで、git worktree 操作 + 新規ブランチ作成 + hook 呼び出しを担当する。プロジェクト固有の処理（Docker起動、依存コピー等）は hook スクリプトに委譲する。

**入力:** "$ARGUMENTS"

---

## アーキテクチャ

```
worktree.sh                    ← エントリポイント（ブランチ作成 + hook 呼び出し）
  ↓ hook呼び出し
worktree-hook.sh（プロジェクト固有） ← Docker, 依存コピー, .env 整備等
```

- hook は `config.yml` の `adapters.worktree_hook` で指定する
- hook がなくても `create` / `list` / `remove` は動作する（git操作のみ）
- hook がない場合、`up` / `down` は何もしない
- 新規ブランチ（まだ存在しないブランチ名）を create に渡すと、config.yml の `base_branch` から自動で切る

---

## スクリプトの場所

プラグイン内の `scripts/worktree.sh`（主エントリポイント）
`scripts/worktree-core.sh` は後方互換のため残置（非推奨）

---

## コマンド一覧

### create: worktree作成

```bash
bash "$SCRIPT_PATH" create <リポジトリ名> <ブランチ名>
```

**ブランチの扱い:**
- ローカルに該当ブランチが存在 → そのブランチで worktree 作成
- リモート `origin/<branch>` が存在 → それを元に worktree 作成
- どちらも存在しない → config.yml の `repositories[].base_branch` から自動で新規作成

**実行後:**
- git worktree が作成される
- hook の `post-create` が呼ばれる（依存コピー、Docker設定等）
- worktreeパスをユーザーに報告する

### up: worktree起動

```bash
bash "$SCRIPT_PATH" up <リポジトリ名> <issue番号>
```

hook の `up` を呼ぶ。hook がなければ何もしない。

### down: worktree停止

```bash
bash "$SCRIPT_PATH" down <リポジトリ名> <issue番号>
```

hook の `down` を呼ぶ。hook がなければ何もしない。

### remove: worktree削除

```bash
bash "$SCRIPT_PATH" remove <リポジトリ名> <issue番号>
```

hook の `pre-remove` を呼んでから git worktree remove を実行する。

### list: worktree一覧

```bash
bash "$SCRIPT_PATH" list <リポジトリ名>
```

---

## 実行方法

入力を解析し、適切なサブコマンドを実行する。

### Step 1: スクリプトパスの解決

```bash
SCRIPT_PATH="$(dirname "$0")/../scripts/worktree.sh"
```

### Step 2: config.yml の探索

`worktree.sh` は以下の順で config.yml を探す（自動）:
1. `$CONFIG_YML` 環境変数
2. `$(pwd)/.engineer/config.yml`
3. `$(pwd)/config.yml`
4. `$WORKSPACE/.engineer/config.yml`

`yq` があれば使い、なければ awk フォールバックで必要箇所だけパースする。

### Step 3: 入力の解析

入力パターン:
- `create <repo> <branch>` → そのまま実行
- `create <repo> <issue番号>` → config.yml の branch_prefix からブランチ名を生成
- `up/down/remove <repo> <issue番号>` → そのまま実行
- `list <repo>` → そのまま実行
- `<repo> <issue番号>` → create として扱う（省略形）

### Step 4: 実行

```bash
bash "$SCRIPT_PATH" <サブコマンド> <引数...>
```

必要に応じて `WORKSPACE` / `WORKTREE_HOOK` / `CONFIG_YML` 環境変数で上書き可能。

---

## Hook の書き方

プロジェクト固有の worktree 処理が必要な場合、hook スクリプトを作成する。

**インターフェース:**
```bash
hook.sh post-create <repo_path> <wt_dir> <branch>   # worktree作成後
hook.sh up <repo_path> <wt_dir>                       # 環境起動
hook.sh down <repo_path> <wt_dir>                     # 環境停止
hook.sh pre-remove <repo_path> <wt_dir>               # worktree削除前
```

**設定方法:**
```yaml
# .engineer/config.yml
adapters:
  worktree_hook: .engineer/scripts/worktree-hook.sh
```

パスは config.yml のあるディレクトリからの相対、もしくは絶対パスで指定する。
worktree.sh は config.yml 基準で hook を解決するので、他ディレクトリから呼んでも動く。

**サンプル:** `docs/examples/kamakura-shinsho/worktree-hook.sh` を参照。

---

## 依存ツール

- **git**（必須）
- **yq**（任意）: あれば YAML パース効率化。なければ awk フォールバック
- **rsync**（任意、hook 側の設計次第）

`yq` インストール（Mac）: `brew install yq`

---

## 注意事項

- hook がなくても git worktree 操作は正常に動作する
- Docker操作は hook に委譲されるため、プロジェクトごとに自由にカスタマイズ可能
- 同時にブラウザ確認できるのは1環境のみ（ポート共有のため）の制約は hook 側の設計による
- プロジェクトによってはメインリポと wt を同時起動しない運用を推奨（hook 側でポート固定にしている場合）
