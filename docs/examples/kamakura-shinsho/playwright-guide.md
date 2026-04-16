# Playwright UI検証ガイド（鎌倉新書向け）

## 概要

Playwright MCPを使い、実装後のUIを目視検証し、スクリーンショットをPRに添付する。

## 前提条件

- Playwright MCPプラグインが有効であること（`@playwright/mcp@latest`）
- 対象リポジトリのDockerコンテナが起動していること（`make up` or worktree の場合は `worktree up`）

## 初回セットアップ（1回のみ）

### 1. SSL証明書エラー回避

ローカル環境は自己署名証明書のため、Playwright MCPに `--ignore-https-errors` を追加する:

```json
// ~/.claude/plugins/marketplaces/claude-plugins-official/external_plugins/playwright/.mcp.json
{
  "playwright": {
    "command": "npx",
    "args": ["@playwright/mcp@latest", "--ignore-https-errors"]
  }
}
```

### 2. ブラウザのインストール

```bash
npx playwright install chromium
```

## リポジトリ別アクセス情報

ポート番号はリポジトリごとに異なる。`.env` ファイルから取得する。

```bash
grep 'APP_URL' {リポジトリ}/src/web/.env
grep 'NPM_PORT' {リポジトリ}/.env
```

## スクリーンショット取得フロー

### Step 1: 変更対象の画面を特定

```bash
docker compose -f docker-compose-for-web-arm.yml -p {PROJECT}-front exec web-phpfpm php artisan route:list --path={keyword}
```

### Step 2: ブラウザでログイン

テストユーザー情報: `src/web/database/seeders/` を確認。

### Step 3: スクリーンショット取得

Playwright MCPの `browser_navigate` → `browser_screenshot` で取得。

**命名規則:** `{repo}-{page}-{state}.png`

### Step 4: 目視確認

- レイアウト崩れ
- テキストの切れ・はみ出し
- 設計通りの反映
- リグレッション

## PRへのスクリーンショット添付

```bash
# Gistにアップロード（upload-screenshots.sh を .engineer/scripts/ に配置）
.engineer/scripts/upload-screenshots.sh .playwright-mcp/screenshots/
```

## トラブルシューティング

- **ブラウザが起動しない**: `npx playwright install chromium`
- **SSL証明書エラー**: `--ignore-https-errors` を確認
- **ログインできない**: Seeder確認 → `make tinker` → `User::first()`
- **ページが表示されない**: `make ps` でコンテナ確認、`make npm-watch` でVite確認
