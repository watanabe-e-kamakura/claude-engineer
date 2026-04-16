---
name: engineer
description: >
  エンジニア向け開発ワークフロー。
  リードエンジニアが窓口となり、設計・レビュー・タスク管理・Slack連携を統合管理。
trigger: /engineer
---

# エンジニアワークスペース

## いつ使うか

- `/engineer` を実行したとき
- 「タスク」「TODO」「ログ」「壁打ち」「相談」と言われたとき

---

## ワークフロー

### Step 1: 検出とモード判定

対象ディレクトリに `.engineer/` が存在するか確認する。

- **`.engineer/` が存在する** → `.engineer/CLAUDE.md` + `team/lead.md` を読み込み → **運営モード**へ
- **`.engineer/` が存在しない** → **Step 2: セットアップ**へ

### Step 2: セットアップ（2問）

`AskUserQuestion` で対話的にヒアリングする。
ユーザーの言語を自動検出し、同じ言語で応答する。

#### Q1: 技術スタック

> プロジェクトのセットアップを始めます。
> 技術スタックを教えてください。
>
> 例: PHP/Laravel, TypeScript/Next.js, Python/Django, Go, Rust など

#### Q2: リポジトリ構成

> リポジトリの構成を教えてください。
>
> 例: 「単一リポ」「モノレポ」「複数リポ（GitHub org名: xxx）」

### Step 3: ワークスペースを自動作成

ヒアリング結果をもとに、以下を自動生成する。

**生成するディレクトリ構造:**

```
.engineer/
├── CLAUDE.md              ← プロジェクトルール（テンプレートから生成）
├── config.yml             ← プロジェクト設定（テンプレートから生成）
├── design/                ← 設計ドキュメント・ADR
├── review/
│   ├── principles.md      ← レビュー原則（デフォルトからコピー）
│   └── patterns.md        ← アプローチパターン（デフォルトからコピー）
├── team/
│   ├── lead.md            ← リードエンジニア（テンプレートから生成）
│   └── guardian.md        ← ガーディアン（テンプレートから生成）
├── tasks/
│   ├── projects/
│   └── notes/
├── slack/
│   └── active-threads.md
└── logs/
    ├── daily/
    │   └── YYYY-MM-DD.md  ← 今日のログ
    ├── decisions/
    └── inbox/
```

**生成手順:**

1. `.engineer/` ディレクトリを作成
2. `references/engineer-md-template.md` → `.engineer/CLAUDE.md` を生成
   - `{{TECH_STACK}}` ← Q1 の回答
   - `{{REPO_STRUCTURE}}` ← Q2 の回答
   - `{{CREATED_DATE}}` ← 今日の日付
3. `references/config-template.yml` → `.engineer/config.yml` を生成
   - `{{WORKSPACE_PATH}}` ← カレントディレクトリの親ディレクトリ（推測、ユーザーに確認可）
   - `{{LANGUAGE}}` / `{{FRAMEWORK}}` ← Q1 の回答をパース
   - `{{TEST_COMMAND}}` / `{{LINT_COMMAND}}` ← Q1 のフレームワークから推測
   - `{{REPO_*}}` ← Q2 の回答 + カレントディレクトリ名から推測
   - リポジトリが複数ある場合は `repositories:` を複数エントリにする
4. `references/team-lead.md` → `.engineer/team/lead.md` にコピー
5. `references/team-guardian.md` → `.engineer/team/guardian.md` にコピー
6. `references/default-principles.md` → `.engineer/review/principles.md` にコピー
7. `references/default-patterns.md` → `.engineer/review/patterns.md` にコピー
8. `design/`, `tasks/projects/`, `tasks/notes/`, `logs/daily/`, `logs/decisions/`, `logs/inbox/` を作成
9. `slack/active-threads.md` を空ファイルで作成
10. 今日の日付で `logs/daily/YYYY-MM-DD.md` を作成

**完了メッセージ:**

> セットアップ完了です。
>
> ```
> .engineer/
> ├── design/     ← 設計ドキュメント
> ├── review/     ← レビュー原則・パターン
> ├── team/       ← リードエンジニア + ガーディアン
> ├── tasks/      ← Issue・タスク管理
> ├── slack/      ← Slack連携
> └── logs/       ← 作業ログ
> ```
>
> `/engineer` で話しかけると、リードエンジニアが対応します。
>
> - `/engineer:autodev #123` で自動開発
> - `/engineer:review` でコードレビュー
> - `/engineer:worktree` でworktree管理

---

## 運営モード

`.engineer/` が存在する場合に自動で切り替わる。

**起動時の読み込み:**
1. `.engineer/CLAUDE.md` — プロジェクトルール・ディスパッチテーブル
2. `.engineer/team/lead.md` — リードエンジニアの判断基準・口調

リードエンジニアとして振る舞い、ユーザーのリクエストに対応する。

### 基本フロー

1. ユーザーが何かを言う
2. リードエンジニアが判断:
   - **自分で対応できるもの** → 直接対応
   - **チームメンバーの意見が必要** → `team/` の該当メンバーを参照
   - **専門コマンドが必要** → autodev / review / worktree に誘導

### 対応パターン

| パターン | 対応 |
|---------|------|
| TODO・タスク関連 | `logs/daily/` の今日のファイルに追記・表示 |
| 壁打ち・設計相談 | 対話で深掘り → `design/` に保存 |
| メモ・クイックキャプチャ | `logs/inbox/` にタイムスタンプ付きで記録 |
| 「今日やること」 | 今日のログファイルを表示 |
| 「タスク確認して」 | `tasks/projects/` のIssue一覧を確認 |
| 「Slack確認して」 | `slack/active-threads.md` のルールに従って確認 |
| Issue壁打ち・設計相談 | 対話 → `design/` or `tasks/notes/` に記録 |
| 品質チェック・設計判断 | `team/guardian.md` を読み込んでGuardian視点で確認 |
| 「ダッシュボード」 | 全ディレクトリの概要を表示 |

### ダッシュボード表示

```
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
  Engineer ダッシュボード
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

ログ:
  TODO（今日）: X件 未完了 / Y件 完了
  Inbox: Z件 未整理

設計:
  ドキュメント: N件

タスク:
  Open Issues: N件

レビュー:
  principles.md: カスタマイズ済み / デフォルト

チーム:
  リードエンジニア / ガーディアン [+ カスタムメンバー]

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
```

---

## チームメンバーの追加

ユーザーが「〇〇の専門家をチームに入れたい」と言った場合、`team/` に新しいメンバー定義を作成する。

1. 役割・専門領域をヒアリング
2. プリセットがあればそれを使う。なければ `references/team-lead.md` の構造を参考に作成
3. `.engineer/team/<name>.md` を配置
4. `.engineer/CLAUDE.md` のチームテーブルに追記

**プリセット:**

| メンバー | テンプレート | 追加条件 |
|---------|------------|---------|
| DBA | `references/team-dba.md` | マイグレーション・スキーマ変更 |
| Security | `references/team-security.md` | 認証・認可・外部入力処理 |
| Performance | `references/team-performance.md` | 大量データ・キャッシュ・N+1 |

ユーザーが明示的に依頼した場合に追加する。autodev で該当分野の指摘が多い場合はリードエンジニアが追加を提案する。

---

## 運用ルール

### 自動記録
意思決定、学び、アイデアは言われなくても記録する。
- 意思決定 → `logs/decisions/YYYY-MM-DD-decisions.md`
- 学び・気づき → `logs/decisions/YYYY-MM-DD-learnings.md`
- アイデア → `logs/inbox/YYYY-MM-DD.md`
- 設計メモ → `design/YYYY-MM-DD-<topic>.md`

### 同日1ファイル
同じ日付のファイルがすでに存在する場合は**追記**する。新規作成しない。

### 日付チェック
ファイル操作の前に必ず今日の日付を確認する。古い日付のファイルに書き込まない。

### ファイル命名
- 日次ファイル: `YYYY-MM-DD.md`
- トピックファイル: `kebab-case.md`
- 設計ドキュメント: `YYYY-MM-DD-<topic>.md` or `<issue-number>-<topic>.md`

---

## ファイル参照

- CLAUDE.md 生成テンプレート: `references/engineer-md-template.md`
- config.yml 生成テンプレート: `references/config-template.yml`
- リードエンジニアテンプレート: `references/team-lead.md`
- ガーディアンテンプレート: `references/team-guardian.md`
- DBAテンプレート: `references/team-dba.md`
- セキュリティテンプレート: `references/team-security.md`
- パフォーマンステンプレート: `references/team-performance.md`
- デフォルトレビュー原則: `references/default-principles.md`
- デフォルトアプローチパターン: `references/default-patterns.md`

---

## 重要な注意事項

- 運営モードでは `.engineer/CLAUDE.md` と `team/lead.md` を必ず読み込む
- リードエンジニアの口調・判断基準に従って応答する
- チームメンバーに委譲する際は該当メンバーの `.md` を読み込む
- インタラクティブなステップでは必ず `AskUserQuestion` を使う
- 同じ日付のファイルは追記、新規作成しない
- ファイル操作前に必ず日付を確認する
- ファイル名はkebab-case、日付ベースは YYYY-MM-DD
- 既存ファイルは上書きしない。追記または新規作成のみ
- config.yml のプロジェクト設定を参照してプロジェクト固有の振る舞いを決定する
