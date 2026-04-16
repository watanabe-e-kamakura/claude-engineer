---
description: "Worktree作成・起動・停止・削除（全リポジトリ共通）"
argument-hint: "<create|up|down|remove|list> <リポジトリ名> [ブランチ名|issue番号]"
allowed-tools: ["Bash", "Read", "Glob", "Grep"]
---

# worktree: 並列開発環境管理

git worktree を使った並列開発環境の作成・起動・停止・削除を行う。
コアスクリプトが git worktree 操作を担当し、プロジェクト固有の処理（Docker起動、依存コピー等）は hook スクリプトに委譲する。

**入力:** "$ARGUMENTS"

---

## アーキテクチャ

```
worktree-core.sh              ← 汎用（git worktree 操作のみ）
  ↓ hook呼び出し
worktree-hook.sh（任意）       ← プロジェクト固有（Docker, 依存コピー等）
```

- hook は `config.yml` の `adapters.worktree_hook` で指定する
- hook がなくても `create` / `list` / `remove` は動作する（git操作のみ）
- hook がない場合、`up` / `down` は何もしない

---

## スクリプトの場所

プラグイン内の `scripts/worktree-core.sh`

`WORKSPACE` 環境変数が未設定の場合は config.yml の workspace_path をデフォルトとする。

---

## コマンド一覧

### create: worktree作成

```bash
WORKSPACE="{workspace_path}" bash "$SCRIPT_PATH" create <リポジトリ名> <ブランチ名>
```

**ブランチ名の決定:**
- config.yml の repositories[].branch_prefix を参照
- ブランチが存在しない場合、スクリプトが base_branch の最新から作成する

**実行後:**
- git worktree が作成される
- hook の `post-create` が呼ばれる（依存コピー、Docker設定等）
- worktreeパスをユーザーに報告する

### up: worktree起動

```bash
WORKSPACE="{workspace_path}" bash "$SCRIPT_PATH" up <リポジトリ名> <issue番号>
```

hook の `up` を呼ぶ。hook がなければ何もしない。

### down: worktree停止

```bash
WORKSPACE="{workspace_path}" bash "$SCRIPT_PATH" down <リポジトリ名> <issue番号>
```

hook の `down` を呼ぶ。hook がなければ何もしない。

### remove: worktree削除

```bash
WORKSPACE="{workspace_path}" bash "$SCRIPT_PATH" remove <リポジトリ名> <issue番号>
```

hook の `pre-remove` を呼んでから git worktree remove を実行する。

### list: worktree一覧

```bash
WORKSPACE="{workspace_path}" bash "$SCRIPT_PATH" list <リポジトリ名>
```

---

## 実行方法

入力を解析し、適切なサブコマンドを実行する。

### Step 1: スクリプトパスの解決

```bash
SCRIPT_PATH="$(dirname "$0")/../scripts/worktree-core.sh"
```

### Step 2: WORKSPACE の解決

config.yml の `workspace_path` を `WORKSPACE` 環境変数として渡す。

### Step 3: 入力の解析

入力パターン:
- `create <repo> <branch>` → そのまま実行
- `create <repo> <issue番号>` → config.yml の branch_prefix からブランチ名を生成
- `up/down/remove <repo> <issue番号>` → そのまま実行
- `list <repo>` → そのまま実行
- `<repo> <issue番号>` → create として扱う（省略形）

### Step 4: 実行

```bash
WORKSPACE="{workspace_path}" bash "$SCRIPT_PATH" <サブコマンド> <引数...>
```

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

**サンプル:** `docs/examples/kamakura-shinsho/worktree-hook.sh` を参照。

---

## 注意事項

- hook がなくても git worktree 操作は正常に動作する
- Docker操作は hook に委譲されるため、プロジェクトごとに自由にカスタマイズ可能
- 同時にブラウザ確認できるのは1環境のみ（ポート共有のため）の制約は hook 側の設計による
