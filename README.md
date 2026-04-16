# claude-engineer

エンジニア向け Claude Code プラグイン。

## 機能

- `/engineer` — リードエンジニアが窓口。タスク・設計・ログ・Slack連携を統合管理
- `/engineer:autodev` — 設計→レビュー→実装→テストの自動開発
- `/engineer:review` — 第三者コードレビュー
- `/engineer:worktree` — git worktree 並列開発管理

## インストール

```bash
# 1. マーケットプレースとして登録
claude plugin marketplace add watanabe-e-kamakura/claude-engineer

# 2. プラグインをインストール
claude plugin install engineer@claude-engineer
```

## セットアップ

```bash
# 3. プロジェクトディレクトリに移動して Claude Code を起動
cd ~/your-project
claude
```

Claude Code 内で `/engineer` を実行すると、技術スタックとリポジトリ構成をヒアリングした後、`.engineer/` フォルダが自動生成されます。

```
.engineer/
├── CLAUDE.md       ← プロジェクトルール
├── config.yml      ← 技術スタック・リポジトリ設定
├── design/         ← 設計ドキュメント・ADR
├── review/         ← レビュー原則・パターン
├── team/           ← 仮想チームメンバー（リードエンジニア + ガーディアン）
├── tasks/          ← Issue・タスク管理
├── slack/          ← Slack連携
└── logs/           ← 作業ログ・inbox
```

## チーム

| メンバー | 役割 |
|---------|------|
| リードエンジニア | 窓口・判断・振り分け |
| ガーディアン | 品質チェック・独立レビュー |

プロジェクトに合わせてチームメンバーを追加できます。

## カスタマイズ

- `.engineer/config.yml` — リポジトリ・ブランチ規約・技術スタック設定
- `.engineer/review/principles.md` — レビュー原則（プロジェクト固有にカスタマイズ）
- `.engineer/review/patterns.md` — アプローチパターン（プロジェクト固有にカスタマイズ）
- `.engineer/team/` — チームメンバーの追加・カスタマイズ

---

## アーキテクチャ: 2層構造

claude-engineer は **プラグイン本体（汎用）** と **プロジェクト固有の設定** を分離した2層構造です。

```
claude-engineer（プラグイン）          ユーザーのプロジェクト
┌──────────────────────┐      ┌──────────────────────┐
│ autodev フェーズ管理   │      │ .engineer/            │
│ レビューエージェント    │      │   config.yml          │
│ worktree-core.sh     │ ───→ │   scripts/             │
│ チーム管理            │      │     worktree-hook.sh  │
│ SKILL.md             │      │   guides/              │
└──────────────────────┘      │     playwright.md     │
  言語・FW 非依存              └──────────────────────┘
                                プロジェクト固有
```

### プラグイン本体が提供するもの
- autodev の設計→実装→テストのフェーズ管理
- レビューエージェント（code-reviewer, spec-reviewer, test-reviewer）
- git worktree のコア操作（create / remove / list）
- リードエンジニア + ガーディアンのチーム構成
- レビュー原則・アプローチパターンのデフォルト

### プロジェクト側で用意するもの（任意）
- **worktree hook** — Docker 起動/停止、依存ファイルコピー等のプロジェクト固有処理
- **UI テストガイド** — Playwright MCP 等を使った UI 検証手順
- **レビュー原則のカスタマイズ** — プロジェクト固有のレビュー観点

### config.yml の adapters セクション

```yaml
adapters:
  worktree_hook: .engineer/scripts/worktree-hook.sh
  ui_test_guide: .engineer/guides/playwright.md
```

hook やガイドが未設定の場合、該当機能はスキップされます（エラーにはなりません）。

---

## Worktree Hook の書き方

worktree hook は以下のインターフェースを実装するシェルスクリプトです:

```bash
hook.sh post-create <repo_path> <wt_dir> <branch>   # worktree作成後
hook.sh up <repo_path> <wt_dir>                       # 環境起動
hook.sh down <repo_path> <wt_dir>                     # 環境停止
hook.sh pre-remove <repo_path> <wt_dir>               # worktree削除前
```

典型的な用途:
- `post-create`: 依存ファイル（vendor, node_modules）のコピー、Docker 設定の生成
- `up`: 本体コンテナを停止し worktree コンテナを起動
- `down`: worktree コンテナを停止
- `pre-remove`: コンテナの停止とクリーンアップ

サンプル: [`docs/examples/kamakura-shinsho/worktree-hook.sh`](docs/examples/kamakura-shinsho/worktree-hook.sh)

---

## 鎌倉新書メンバー向けクイックスタート

鎌倉新書のリポジトリ構成（Laravel + Docker compose + Makefile）を使っている場合:

1. `/engineer` でセットアップ（技術スタック: `PHP/Laravel`、リポジトリ構成: `複数リポ`）
2. サンプルの hook をコピー:
   ```bash
   cp docs/examples/kamakura-shinsho/worktree-hook.sh .engineer/scripts/
   cp docs/examples/kamakura-shinsho/playwright-guide.md .engineer/guides/
   ```
3. `.engineer/config.yml` の adapters を設定:
   ```yaml
   adapters:
     worktree_hook: .engineer/scripts/worktree-hook.sh
     ui_test_guide: .engineer/guides/playwright-guide.md
   ```

---

## ライセンス

MIT
