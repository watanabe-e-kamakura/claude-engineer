#!/bin/bash
set -euo pipefail

# ============================================================
# git worktree 汎用コアスクリプト
#
# 使い方:
#   worktree-core.sh create <リポジトリ名> <ブランチ名>
#   worktree-core.sh up <リポジトリ名> <issue番号>
#   worktree-core.sh down <リポジトリ名> <issue番号>
#   worktree-core.sh remove <リポジトリ名> <issue番号>
#   worktree-core.sh list <リポジトリ名>
#
# 設計:
#   - WORKSPACE 環境変数でワークスペースを指定（デフォルト: ~/workspace）
#   - git worktree の操作のみを行う（汎用）
#   - プロジェクト固有の処理（Docker起動、依存コピー等）は hook に委譲
#   - hook: WORKTREE_HOOK 環境変数 or .engineer/config.yml の adapters.worktree_hook
#
# Hook インターフェース:
#   hook.sh post-create <repo_path> <wt_dir> <branch>
#   hook.sh up <repo_path> <wt_dir>
#   hook.sh down <repo_path> <wt_dir>
#   hook.sh pre-remove <repo_path> <wt_dir>
# ============================================================

WORKSPACE="${WORKSPACE:-$HOME/workspace}"

# ---------- ヘルパー ----------

usage() {
    cat <<'USAGE'
Usage: worktree-core.sh <command> <リポジトリ名> [args]

Commands:
  create <repo> <branch>       worktree作成
  up <repo> <issue番号>         worktree環境を起動（hookで処理）
  down <repo> <issue番号>       worktree環境を停止（hookで処理）
  remove <repo> <issue番号>     worktree削除
  list <repo>                   worktree一覧

Environment:
  WORKSPACE        ワークスペースのルートパス（デフォルト: ~/workspace）
  WORKTREE_HOOK    プロジェクト固有のhookスクリプトパス（任意）
USAGE
    exit 1
}

resolve_repo() {
    local repo_name="${1:?リポジトリ名を指定してください}"
    local repo_path="${WORKSPACE}/${repo_name}"
    if [[ ! -d "$repo_path" ]]; then
        echo "エラー: ${repo_path} が見つかりません" >&2
        exit 1
    fi
    echo "$repo_path"
}

resolve_wt_dir() {
    local repo_name="${1}"
    local issue_num="${2}"
    echo "${WORKSPACE}/${repo_name}-wt-${issue_num}"
}

get_suffix() {
    local branch="$1"
    local num
    num=$(echo "$branch" | grep -oE '[0-9]+$' || true)
    if [[ -n "$num" ]]; then
        echo "$num"
    else
        echo "$branch" | md5sum 2>/dev/null | cut -c1-6 || echo "$branch" | md5 -q 2>/dev/null | cut -c1-6
    fi
}

# hookスクリプトを検出して実行
run_hook() {
    local action="$1"
    shift

    local hook=""

    # 1. 環境変数から
    if [[ -n "${WORKTREE_HOOK:-}" && -f "$WORKTREE_HOOK" ]]; then
        hook="$WORKTREE_HOOK"
    fi

    # 2. .engineer/config.yml から（yq がなければスキップ）
    if [[ -z "$hook" ]]; then
        local config_path
        for candidate in ".engineer/config.yml" "${WORKSPACE}/.engineer/config.yml"; do
            if [[ -f "$candidate" ]]; then
                config_path="$candidate"
                break
            fi
        done
        if [[ -n "${config_path:-}" ]] && command -v yq &>/dev/null; then
            local hook_path
            hook_path=$(yq -r '.adapters.worktree_hook // ""' "$config_path" 2>/dev/null || true)
            if [[ -n "$hook_path" && -f "$hook_path" ]]; then
                hook="$hook_path"
            fi
        fi
    fi

    if [[ -n "$hook" ]]; then
        echo "  hook: ${action} ($(basename "$hook"))"
        bash "$hook" "$action" "$@"
    fi
}

# ---------- create ----------

cmd_create() {
    local repo_name="${1:?リポジトリ名を指定してください}"
    local branch="${2:?ブランチ名を指定してください}"
    local repo_path
    repo_path=$(resolve_repo "$repo_name")

    local suffix
    suffix=$(get_suffix "$branch")
    local wt_dir="${WORKSPACE}/${repo_name}-wt-${suffix}"

    if [[ -d "$wt_dir" ]]; then
        echo "エラー: $wt_dir は既に存在します"
        exit 1
    fi

    echo "=== worktree 作成 ==="
    echo "  リポジトリ: $repo_name"
    echo "  ブランチ: $branch"
    echo "  ディレクトリ: $wt_dir"
    echo ""

    git -C "$repo_path" worktree add "$wt_dir" "$branch"

    # プロジェクト固有の後処理（依存コピー、Docker設定等）
    run_hook "post-create" "$repo_path" "$wt_dir" "$branch"

    echo ""
    echo "=== 作成完了 ==="
    echo "  ディレクトリ: $wt_dir"
    echo ""
    echo "  使い方:"
    echo "    起動:  worktree-core.sh up ${repo_name} ${suffix}"
    echo "    停止:  worktree-core.sh down ${repo_name} ${suffix}"
    echo "    削除:  worktree-core.sh remove ${repo_name} ${suffix}"
}

# ---------- up ----------

cmd_up() {
    local repo_name="${1:?リポジトリ名を指定してください}"
    local issue_num="${2:?issue番号を指定してください}"
    local repo_path
    repo_path=$(resolve_repo "$repo_name")
    local wt_dir
    wt_dir=$(resolve_wt_dir "$repo_name" "$issue_num")

    if [[ ! -d "$wt_dir" ]]; then
        echo "エラー: $wt_dir が見つかりません"
        exit 1
    fi

    echo "=== worktree 起動: $(basename "$wt_dir") ==="
    run_hook "up" "$repo_path" "$wt_dir"
    echo "  完了"
}

# ---------- down ----------

cmd_down() {
    local repo_name="${1:?リポジトリ名を指定してください}"
    local issue_num="${2:?issue番号を指定してください}"
    local repo_path
    repo_path=$(resolve_repo "$repo_name")
    local wt_dir
    wt_dir=$(resolve_wt_dir "$repo_name" "$issue_num")

    if [[ ! -d "$wt_dir" ]]; then
        echo "エラー: $wt_dir が見つかりません"
        exit 1
    fi

    echo "=== worktree 停止: $(basename "$wt_dir") ==="
    run_hook "down" "$repo_path" "$wt_dir"
    echo "  完了"
}

# ---------- remove ----------

cmd_remove() {
    local repo_name="${1:?リポジトリ名を指定してください}"
    local issue_num="${2:?issue番号を指定してください}"
    local repo_path
    repo_path=$(resolve_repo "$repo_name")
    local wt_dir
    wt_dir=$(resolve_wt_dir "$repo_name" "$issue_num")

    if [[ ! -d "$wt_dir" ]]; then
        echo "エラー: $wt_dir が見つかりません"
        exit 1
    fi

    echo "=== worktree 削除: $(basename "$wt_dir") ==="

    # プロジェクト固有の前処理（コンテナ停止等）
    run_hook "pre-remove" "$repo_path" "$wt_dir"

    git -C "$repo_path" worktree remove "$wt_dir" --force
    echo "  削除完了"
}

# ---------- list ----------

cmd_list() {
    local repo_name="${1:?リポジトリ名を指定してください}"
    local repo_path
    repo_path=$(resolve_repo "$repo_name")

    echo "=== worktree 一覧: ${repo_name} ==="
    git -C "$repo_path" worktree list
}

# ---------- メイン ----------

cmd="${1:-}"
shift || true

case "$cmd" in
    create)  cmd_create "$@" ;;
    up)      cmd_up "$@" ;;
    down)    cmd_down "$@" ;;
    remove)  cmd_remove "$@" ;;
    list)    cmd_list "$@" ;;
    *)       usage ;;
esac
