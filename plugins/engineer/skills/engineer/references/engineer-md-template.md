# Engineer Workspace

## プロジェクト情報

- **技術スタック**: {{TECH_STACK}}
- **リポジトリ構成**: {{REPO_STRUCTURE}}
- **作成日**: {{CREATED_DATE}}
- **plugin_version**: {{PLUGIN_VERSION}}

## ディレクトリ構成

```
.engineer/
├── CLAUDE.md          ← この文書
├── config.yml         ← プロジェクト設定
├── design/            ← 設計ドキュメント・ADR
├── review/            ← レビュー原則・パターン・レビュー結果
├── team/              ← 仮想チームメンバー
│   ├── lead.md        ← リードエンジニア（窓口・統括）
│   └── guardian.md    ← ガーディアン（品質チェック）
├── tasks/             ← Issue・タスク管理
│   ├── projects/
│   └── notes/
├── slack/             ← Slack連携
│   └── active-threads.md
└── logs/              ← 作業ログ
    ├── daily/
    ├── decisions/
    └── inbox/
```

## チーム

| メンバー | 役割 | 定義 |
|---------|------|------|
| リードエンジニア | 窓口・判断・振り分け | `team/lead.md` |
| ガーディアン | 品質チェック・独立レビュー | `team/guardian.md` |

## 行動原則

### リードエンジニアが窓口
- ユーザーからのリクエストはリードエンジニアが受け取る
- `team/lead.md` の判断基準に従って対応・振り分けする
- チームメンバーの意見が必要な場面では委譲する

### 自動記録
- 意思決定 → `logs/decisions/YYYY-MM-DD-decisions.md`
- 学び → `logs/decisions/YYYY-MM-DD-learnings.md`
- アイデア → `logs/inbox/YYYY-MM-DD.md`

### ファイル運用
- 同じ日付のファイルがすでにある場合は追記する（新規作成しない）
- ファイル操作の前に必ず今日の日付を確認する
- 日次ファイル: `YYYY-MM-DD.md` / トピックファイル: `kebab-case.md`
- 迷ったら `logs/inbox/` に入れる。既存ファイルは上書きしない（追記のみ）

### コミット・ブランチ
- ユーザーが明示的に指示するまでコミットしない
- ブランチ命名規約: config.yml の repositories[].branch_prefix を参照

## 業務フロー（トリガー → 参照先）

| トリガー | 対応 |
|---------|------|
| 「タスク確認して」 | tasks/ のプロジェクト・Issue一覧を確認 |
| 「Slack確認して」 | slack/ のルールに従って確認 |
| Issue壁打ち・設計相談 | 対話 → design/ に記録 |
| PR作成 | config.yml のブランチ規約に従う |
| PRレビュー・設計判断 | review/ の原則に基づく + Guardian チェック |
| 「#{番号}やりたい」 | `/engineer:worktree` → worktree自動セットアップ |

## ルール追加時の方針

行動原則とディスパッチテーブルのみ記載。詳細手順 → 各ディレクトリの専用ファイル。
**60行超えたら詳細手順が混入していないか見直す。**
