---
description: "レビュー結果を分析し、レビュー原則・パターンを自動更新（autodev精度向上ループ）"
argument-hint: "[期間: 1w|2w|1m|all]"
allowed-tools: ["Bash", "Glob", "Grep", "Read", "Write", "Edit", "Agent"]
---

# review-retrospective: レビューフィードバックループ

過去のレビュー結果を分析し、頻出パターンを `review/principles.md` と `review/patterns.md` に昇格させる。
これにより autodev の各エージェント（designer, implementer, code-reviewer）が過去の学びを活用できるようになり、同じ指摘が繰り返されなくなる。

**入力:** "$ARGUMENTS"（期間指定。デフォルト: 2w）

---

## フィードバックループの全体像

```
autodev 実行
  ↓
code-review / spec-review / test-review / Guardian チェック
  ↓
レビュー結果が review/YYYY-MM-DD-review.md に蓄積
  ↓
/engineer:review-retrospective（定期 or 手動）
  ↓
頻出パターンを分析
  ↓
review/principles.md に新ルール追加      ← code-reviewer が参照
review/patterns.md に新パターン追加      ← designer / implementer が参照
review/anti-patterns.md に失敗例追加     ← 全エージェントが参照
  ↓
次回の autodev でエージェントの精度が向上
```

---

## ワークフロー

### 1. レビュー結果の収集

指定期間のレビューファイルを収集する:

```bash
# review/ 配下の日付付きファイルを収集
ls .engineer/review/YYYY-MM-DD-*.md
```

対象ファイル:
- `review/YYYY-MM-DD-review.md` — /engineer:review の結果
- `logs/decisions/YYYY-MM-DD-decisions.md` — 意思決定ログ（レビュー起因の判断を含む）

GitHub の PR レビューコメントも収集する（リポジトリが config.yml にある場合）:

```bash
# 対象期間の PR を取得
gh pr list --state merged --search "merged:>YYYY-MM-DD" --json number,title,mergedAt
# 各 PR のレビューコメントを取得
gh api repos/{owner}/{repo}/pulls/{number}/comments
```

### 2. パターン分析

収集したレビュー結果から以下を抽出する:

**頻出指摘（同じ種類の指摘が2回以上）:**
- Critical が繰り返されている → **principles.md に昇格必須**
- Important が繰り返されている → **principles.md に昇格推奨**
- Guardian SHOULD が繰り返されている → **patterns.md に昇格推奨**

**新しいアンチパターン（初めて見つかった重大な問題）:**
- 本番障害に繋がった、または繋がりかけた指摘
- 複数ファイルにまたがる構造的な問題

**解決済みパターン（指摘が減った分野）:**
- 過去に頻出だったが最近は出なくなった指摘 → 学習済みとしてマーク

### 3. 分析レポート

```markdown
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
  レビュー振り返りレポート
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

期間: YYYY-MM-DD 〜 YYYY-MM-DD
レビュー件数: N件
PR件数: M件

## 頻出指摘（principles.md への昇格候補）

### 1. [指摘カテゴリ] — N回検出
- 具体例: [file:line] [説明]
- 具体例: [file:line] [説明]
- **提案ルール**: [principles.md に追加する1文]

### 2. [指摘カテゴリ] — N回検出
...

## 新規アンチパターン（anti-patterns.md への追加候補）

### 1. [パターン名]
- 発生箇所: [file:line]
- 問題: [何が起きたか/起きかけたか]
- **正しいアプローチ**: [どうすべきか]

## 解決済みパターン（学習完了）

- [パターン名] — 最後の検出: YYYY-MM-DD（N回目以降検出なし）

## 改善提案

### patterns.md への追加
- [新しいアプローチパターン]

### team/ メンバー追加の推奨
- [特定分野の指摘が多い場合、専門チームメンバーの追加を提案]

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
```

### 4. ユーザー確認

分析レポートをユーザーに提示し、以下を確認する:

- 昇格候補のうちどれを採用するか
- アンチパターンの追加に同意するか
- 表現の修正があれば

**全件自動で追加しない。** ユーザーが「全部入れて」と言った場合のみ一括適用する。

### 5. ファイル更新

ユーザーが承認した項目を各ファイルに追記する:

**review/principles.md:**
```markdown
## N+1. [新しい原則タイトル]
- [具体的なルール]
- 根拠: [どのレビューで何回指摘されたか]
- 追加日: YYYY-MM-DD
```

**review/patterns.md:**
```markdown
## X. [新しいパターン名]
[具体的なアプローチ]
- 根拠: [どのレビューから導出されたか]
- 追加日: YYYY-MM-DD
```

**review/anti-patterns.md（新規作成 or 追記）:**
```markdown
## [アンチパターン名]
**やってはいけないこと**: [具体的な禁止事項]
**なぜダメか**: [問題の説明]
**代わりにやること**: [正しいアプローチ]
- 初回検出: YYYY-MM-DD
- 検出回数: N回
```

### 6. autodev への反映確認

更新されたファイルが autodev で正しく参照されるか確認する:

- `review/principles.md` → code-reviewer エージェントが参照
- `review/patterns.md` → designer / implementer エージェントが参照
- `review/anti-patterns.md` → 全エージェントが参照（0-3 コンテキスト取得で読み込み）

---

## autodev との連携

### autodev 側の変更（0-3 コンテキスト取得に追加）

autodev の Step 0-3 で以下のファイルも読み込む:

- `.engineer/review/anti-patterns.md` — 過去の失敗パターン（全エージェントに渡す）

これにより:
- **designer**: 設計時にアンチパターンを避ける
- **implementer**: 実装時にアンチパターンを避ける
- **code-reviewer**: レビュー時にアンチパターンを重点チェック
- **Guardian**: 独立チェック時にアンチパターンを確認

### フィードバックの流れ

```
1回目の autodev → レビューで N+1 指摘
2回目の autodev → また N+1 指摘
review-retrospective → 「N+1 チェック」を principles.md に昇格
3回目の autodev → code-reviewer が N+1 を重点チェック
                → implementer が設計段階で eager loading を適用
                → 指摘が出なくなる
```

---

## 使用例

```
# 直近2週間のレビューを分析（デフォルト）
/engineer:review-retrospective

# 直近1ヶ月
/engineer:review-retrospective 1m

# 全期間
/engineer:review-retrospective all
```

---

## 注意事項

- ファイルの更新は必ずユーザーの承認を得てから行う
- principles.md の項目数が多くなりすぎないよう、20項目を超えたら統合・整理を提案する
- anti-patterns.md は「やってはいけないこと」に特化する。「やるべきこと」は principles.md に書く
- 解決済みパターンは削除せずマークする（再発検知のため）
