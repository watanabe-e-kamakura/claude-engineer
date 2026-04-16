# claude-engineer

エンジニア向け Claude Code プラグイン。

## プロジェクト構成

```
claude-engineer/
├── .claude-plugin/marketplace.json    ← プラグインレジストリ
├── plugins/engineer/
│   ├── .claude-plugin/plugin.json     ← プラグインメタデータ
│   ├── agents/                        ← サブエージェント定義（6種）
│   ├── commands/                      ← コマンド定義（autodev, review, worktree）
│   ├── skills/engineer/               ← /engineer メインスキル
│   │   ├── SKILL.md
│   │   └── references/                ← テンプレート・デフォルト設定
│   └── scripts/                       ← ユーティリティスクリプト
└── docs/
```

## 開発ルール

- `.engineer/` はユーザーのプロジェクト側に生成されるフォルダ。このリポジトリには含めない
- エージェント・コマンドは言語/フレームワーク非依存に書く。固有ルールは `config.yml` と `.engineer/review/` で吸収
- `.company/` への参照を絶対に入れない（cc-company とは独立）
- テンプレートのプレースホルダ: `{{VARIABLE_NAME}}` 形式
- ディレクトリ名は `reviews/` ではなく `review/`（単数形）
