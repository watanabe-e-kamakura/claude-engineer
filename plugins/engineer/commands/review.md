---
description: "実装コードを第三者目線でレビュー（仕様整合性・コード品質・テスト）"
argument-hint: "[all|spec|code|tests] [parallel]"
allowed-tools: ["Bash", "Glob", "Grep", "Read", "Agent", "Task"]
---

# コードレビュー

実装完了後に、独立したエージェントが第三者目線でレビューを行う。
各エージェントは実装時のコンテキストを持たず、コードと仕様だけを見て判断する。

**レビュー観点（オプション）:** "$ARGUMENTS"

## ワークフロー

### 1. レビュースコープの特定

```bash
# 変更ファイルを特定
git diff --name-only
git diff --staged --name-only
```

- 変更がない場合: ユーザーに確認（ブランチ比較が必要か？）
- PRが存在する場合: `gh pr diff` も参照

### 2. レビュー観点の決定

引数で指定可能。デフォルトは `all`。

| 引数 | エージェント | 内容 |
|------|------------|------|
| `spec` | spec-reviewer | PMチケット仕様との整合性 |
| `code` | code-reviewer | コード品質・バグ・セキュリティ |
| `tests` | test-reviewer | テスト網羅性・品質 |
| `all` | 全エージェント | 全観点（デフォルト） |

### 3. 関連情報の収集（レビュー前に実施）

エージェント起動前に以下を収集し、各エージェントに渡す:

- **ブランチ名**: `git branch --show-current`
- **変更ファイル一覧**: `git diff --name-only`
- **関連チケット**: `.engineer/tasks/projects/` から該当チケットを特定
- **CLAUDE.md**: リポジトリルートおよび `.engineer/CLAUDE.md` の規約
- **Review Principles**: `.engineer/review/principles.md`（存在する場合）
- **Guardian Patterns**: `.engineer/review/patterns.md`（存在する場合）

### 4. エージェント起動

**デフォルト: 順次実行**（結果を見ながら対応しやすい）

```
spec-reviewer → code-reviewer → test-reviewer
```

**`parallel` 指定時: 並列実行**（高速だが結果が一括で返る）

```
spec-reviewer ┐
code-reviewer ├→ 集約
test-reviewer ┘
```

各エージェントには以下を渡す:
- レビュー対象の変更内容（git diff）
- 関連チケットの内容（spec-reviewer のみ）
- CLAUDE.md の規約
- ブランチ名と変更ファイル一覧
- Review Principles / Guardian Patterns（存在する場合）

### 5. 結果の集約

全エージェントの結果を以下の形式で統合:

```markdown
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
  レビュー結果サマリー
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

ブランチ: [branch-name]
変更ファイル: X件
関連チケット: [ticket-name]

## 総合判定: [PASS / WARN / FAIL]

### Critical（修正必須）
1. [spec] file:line - 説明
2. [code] file:line - 説明

### Important（修正推奨）
1. [code] file:line - 説明
2. [tests] file:line - 説明

### Info（確認推奨）
1. [spec] 説明

### 良い実装
- [具体的な良い点]

## 推奨アクション
1. Critical を修正
2. Important を検討
3. 修正後に再レビュー: /engineer:review [観点]

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
```

### 6. .engineer への記録

レビュー結果を `.engineer/review/YYYY-MM-DD-review.md` に保存する。
同日に複数回レビューした場合は追記する。

## 使用例

```
# 全観点でレビュー（順次）
/engineer:review

# 全観点で並列レビュー
/engineer:review all parallel

# 仕様整合性だけ確認
/engineer:review spec

# コード品質とテストを確認
/engineer:review code tests
```

## 注意事項

- レビューは読み取り専用。コードの修正は行わない
- 修正はレビュー結果を確認した後、ユーザーの指示で行う
- 各エージェントは独立して動作し、実装時のコンテキストを持たない（これが第三者目線の核心）
- レビュー結果に基づく修正後は、該当観点だけ再レビューできる
