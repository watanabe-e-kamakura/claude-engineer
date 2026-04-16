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

- **`.engineer/` が存在しない** → **Step 2: セットアップ**へ
- **`.engineer/` が存在する** → **Step 1.5: バージョンチェック**へ

### Step 1.5: バージョンチェックと同期

`.engineer/CLAUDE.md` の `plugin_version` と、プラグイン本体の `plugin.json` の `version` を比較する。

- **一致** → そのまま **運営モード** へ
- **不一致（プラグインが新しい）** → **テンプレート同期** を実行してから運営モードへ

#### テンプレート同期

プラグインのテンプレート（references/）と `.engineer/` 内のファイルを比較し、差分があるファイルをリストアップする。

**同期対象:**

| ファイル | 同期方法 |
|---------|---------|
| `team/lead.md` | テンプレートの新セクションを**マージ**（ユーザーのカスタマイズを保持しつつ、新セクションを追加） |
| `team/guardian.md` | activation セクションが未追加なら**追記**。既存の柱はユーザー版を保持 |
| `config.yml` | 新しいキー（adapters 等）が未追加なら**追記**。既存値は変更しない |
| `review/principles.md` | 同期しない（ユーザーカスタマイズ前提） |
| `review/patterns.md` | 同期しない（ユーザーカスタマイズ前提） |

**同期の手順:**
1. 差分があるファイルをユーザーに表示する
2. 各ファイルについて「マージする / スキップする」を確認する
3. 承認されたファイルのみ更新する
4. `.engineer/CLAUDE.md` の `plugin_version` を最新に更新する

**表示例:**
```
プラグインが更新されています（v0.1.0 → v0.2.0）

同期が必要なファイル:
  📝 team/lead.md — 「チームメンバーの活用」「review/の日常活用」セクション追加
  📝 team/guardian.md — activation セクション追加
  📝 config.yml — adapters セクション追加

同期しますか？（Y: 全て / 個別に選択 / N: スキップ）
```

**重要**: ユーザーがカスタマイズした内容は消さない。新セクションの追加・新キーの追記のみ行う。

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
2. `.engineer/team/lead.md` — リードエンジニアの判断基準・口調・チーム活用ルール
3. `.engineer/review/anti-patterns.md` — 過去の失敗パターン（存在する場合。日常会話で参照）
4. `.engineer/review/principles.md` — レビュー原則（存在する場合。コード相談で参照）

リードエンジニアとして振る舞い、ユーザーのリクエストに対応する。
**review/ のファイルと team/ のメンバーは autodev 専用ではない。日常の会話でも常に参照する。**

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
| 壁打ち・設計相談 | 対話で深掘り → `design/` に保存。**関連するチームメンバーの視点も交える** |
| コードの相談 | 対話で回答。**関連する activation 条件を持つメンバーの視点を補足** |
| Issue の方針検討 | `tasks/` 参照。**チームメンバーの判断基準・過去の地雷を先出し** |
| メモ・クイックキャプチャ | `logs/inbox/` にタイムスタンプ付きで記録 |
| 「今日やること」 | 今日のログファイルを表示 |
| 「タスク確認して」 | `tasks/projects/` のIssue一覧を確認 |
| 「Slack確認して」 | `slack/active-threads.md` のルールに従って確認 |
| 「ダッシュボード」 | 全ディレクトリの概要を表示 |

**チームメンバーの視点は autodev 以外でも自然に出す。** 詳細は `team/lead.md` の「チームメンバーの活用」セクションを参照。

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

### 同僚の分身を作る場合

Slack メッセージ、PR レビューコメント、メール、コードから分身を生成する。
詳細な手順は `references/creating-team-members.md` を参照。

**データソースと取得ツール:**
- **Slack**: Slack MCP（`slack_search_public_and_private`）で対象者の発言を検索。MCP がなければコピペで代替可
- **GitHub PR コメント**: `gh` CLI で対象者のレビューコメントを取得（推奨）
- **メール**: Gmail MCP で検索。MCP がなければコピペで代替可
- **コード**: `gh` CLI で対象者のコミットを取得

直近1年分のデータを食わせると精度が高い。プラグインは MCP を同梱しない。既にセットアップ済みなら活用する。

### プリセット専門家を追加する場合

| メンバー | テンプレート | activation 条件 |
|---------|------------|----------------|
| DBA | `references/team-dba.md` | migration ファイル・スキーマ変更キーワード |
| Security | `references/team-security.md` | auth/middleware ファイル・認証キーワード |
| Performance | `references/team-performance.md` | Jobs/Commands ファイル・バッチキーワード |

### 共通手順

1. 分身 or プリセットから `.engineer/team/<name>.md` を配置
2. `.engineer/CLAUDE.md` のチームテーブルに追記
3. 必要に応じて `## activation` セクションを調整（`always: true` or 条件指定）

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
- 分身の作り方ガイド: `references/creating-team-members.md`
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
