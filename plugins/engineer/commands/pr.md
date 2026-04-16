---
description: "PR作成（テンプレート準拠・スクリーンショット自動添付・config.yml連携）"
argument-hint: "[ベースブランチ]"
allowed-tools: ["Bash", "Glob", "Grep", "Read", "Write", "Edit"]
---

# PR作成

autodev 完了後またはコミット済みの変更から、config.yml に準拠した PR を作成する。

**入力:** "$ARGUMENTS"

---

## ワークフロー

### 1. 状態確認

```bash
git status
git log --oneline $(git merge-base HEAD develop)..HEAD
git diff --name-only $(git merge-base HEAD develop)..HEAD
```

- 未コミットの変更がある場合はユーザーに確認
- コミットが0件の場合はエラー

### 2. ベースブランチの決定

- 引数で指定された場合: そのブランチを使用
- 未指定の場合: config.yml の `repositories[].base_branch` を参照
- config.yml がない場合: `develop` をデフォルト

### 3. PR タイトルの生成

コミットメッセージと変更内容から自動生成する。

**ルール:**
- 70文字以内
- Issue番号がブランチ名に含まれていれば `#{番号}` を接頭辞に付ける
- 例: `#170 請求タグ登録画面にSP名を表示`

### 4. PR 本文の生成

config.yml の `pr.template` が設定されている場合はテンプレートに従う。
未設定の場合はデフォルトフォーマットを使用する。

**デフォルトフォーマット:**

```markdown
## Summary
- [変更の概要を1〜3行で]

## Changes
- [変更ファイルと変更内容の一覧]

## Screenshots
[Phase 2.5 のスクリーンショットがあれば自動挿入]

## Test plan
- [ ] [テスト手順]

## Related
- Issue: #{番号}
- [関連PRがあればリンク]
```

### 5. スクリーンショットの添付

`.playwright-mcp/screenshots/` にファイルが存在する場合:

1. `config.yml` の `adapters` にアップロードスクリプトがあれば使用
2. なければ `gh gist create` で直接アップロード
3. Markdown 画像タグを PR 本文の Screenshots セクションに挿入

スクリーンショットがない場合は Screenshots セクションを省略する。

### 6. PR 作成

```bash
gh pr create \
  --base "{ベースブランチ}" \
  --title "{タイトル}" \
  --body "{本文}" \
  --assignee "{config.yml の pr.assignee}"
```

- `pr.assignee` が未設定の場合は `--assignee` を省略
- PR作成後、URLをユーザーに報告する

### 7. GitHub Issue へのリンク

PR 本文に `#{Issue番号}` が含まれていれば、GitHub が自動でリンクする。
autodev で Issue に追記済みの場合、Issue 側にも PR リンクが表示される。

---

## 使用例

```
# デフォルト（develop ベース）
/engineer:pr

# main ベースで作成
/engineer:pr main

# autodev 完了後の典型的なフロー
/engineer:autodev #170
→ (設計→実装→テスト完了)
→ コミットして
→ /engineer:pr
```

---

## 注意事項

- PR 作成前に必ずユーザーにタイトル・本文をプレビュー表示して確認を取る
- ユーザーが「OK」と言ってから `gh pr create` を実行する
- force push はしない
- config.yml がなくても動作する（デフォルト値を使用）
