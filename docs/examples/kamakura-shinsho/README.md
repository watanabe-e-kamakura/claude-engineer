# 鎌倉新書メンバー向けセットアップガイド

## 前提

- 鎌倉新書の開発リポジトリ構成（Laravel + Docker compose + Makefile）を使用している
- GitHub org: `kamakurashinsho`
- itns-documents リポジトリへのアクセス権がある

## インストール

```bash
# マーケットプレース登録 + プラグインインストール
claude plugin marketplace add watanabe-e-kamakura/claude-engineer
claude plugin install engineer@claude-engineer
```

## セットアップ

```bash
# 対象リポジトリに移動して Claude Code を起動
cd ~/itns-workspace/itns-admin-e-sogi  # 例
claude
```

Claude Code 内で:
```
/engineer
```

ヒアリングに以下のように回答する:
- **技術スタック**: `PHP/Laravel`
- **リポジトリ構成**: `複数リポ（GitHub org: kamakurashinsho）`

## セットアップ後に必ず読むドキュメント

`.engineer/` が生成されたら、**まず以下のドキュメントを確認してください。**
リポジトリ横断の構成・ドメイン知識・ガーディアン情報が記載されています。

> https://github.com/kamakurashinsho/itns-documents/tree/main/tasks-division-cross-dev/overview

| ファイル | 内容 | 重要度 |
|---------|------|--------|
| `CLAUDE.md.example` | コマンド実行ルール・Git規約・機密情報取り扱いルール | **必須** |
| `business-domain.md` | 事業ライン・ビジネスドメイン・主要エンティティ | **必須** |
| `system-architecture.md` | システム構成・アーキテクチャ・データフロー | **必須** |
| `guardians/` | メンバーごとのガーディアン定義（品質チェック観点） | **必須** |
| `current-challenges.md` | 現在の課題・進行中の取り組み | 任意 |

### ガーディアン定義の活用

`guardians/` 配下に自分のガーディアン定義（`watanabe-e.md` 等）がある場合、その内容を `.engineer/team/guardian.md` に反映すると、autodev の品質チェックが自分のチームの観点に合わせて動作します。

```bash
# 例: 自分のガーディアン定義を確認
cat ~/itns-workspace/itns-documents/tasks-division-cross-dev/overview/guardians/watanabe-e.md

# .engineer/team/guardian.md にマージ or 置き換え
```

## プロジェクト固有スクリプトの配置

```bash
# worktree hook と Playwright ガイドをコピー
mkdir -p .engineer/scripts .engineer/guides
cp ~/.claude/plugins/cache/claude-engineer/engineer/*/docs/examples/kamakura-shinsho/worktree-hook.sh .engineer/scripts/
cp ~/.claude/plugins/cache/claude-engineer/engineer/*/docs/examples/kamakura-shinsho/playwright-guide.md .engineer/guides/
```

`.engineer/config.yml` の adapters を設定:

```yaml
workspace_path: ~/itns-workspace

stack:
  language: php
  framework: laravel
  test_command: php artisan test
  lint_command: vendor/bin/phpstan analyse

repositories:
  - name: itns-admin
    type: common
    branch_prefix: "feature/"
    base_branch: develop
    description: 共通管理画面
  - name: itns-admin-e-sogi
    type: project
    branch_prefix: "feature/"
    base_branch: develop
    description: 葬祭事業部
  # 他の事業部リポジトリも追加

adapters:
  worktree_hook: .engineer/scripts/worktree-hook.sh
  ui_test_guide: .engineer/guides/playwright-guide.md

pr:
  assignee: ""  # 自分のGitHubユーザー名
```

## 動作確認

Claude Code 内で以下を試す:

```
# 1. ダッシュボード表示
ダッシュボード

# 2. タスク確認（GitHub Issue連携）
タスク確認して

# 3. 小さいタスクで autodev を試す
/engineer:autodev READMEの修正
```

## 注意事項

- `.engineer/` は **各リポジトリごと** に作成する（共有ではない）
- `review/principles.md` と `review/patterns.md` はデフォルトが入っている。チームの規約に合わせてカスタマイズ推奨
- コミット・push・PR作成はユーザーが明示的に指示するまで実行されない
