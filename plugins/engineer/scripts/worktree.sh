#!/bin/bash
# ============================================================
# engineer プラグイン: worktree 管理エントリポイント
#
# 使い方:
#   worktree.sh create <repo> <branch>     # 新規ブランチなら base_branch から自動作成
#   worktree.sh up <repo> <issue番号>       # hook 経由で環境起動
#   worktree.sh down <repo> <issue番号>     # hook 経由で環境停止
#   worktree.sh remove <repo> <issue番号>   # worktree 削除
#   worktree.sh list <repo>                 # 一覧
#
# 環境変数:
#   WORKSPACE       ワークスペースのルートパス（未指定時は config.yml の workspace_path）
#   WORKTREE_HOOK   hook スクリプトのパス（未指定時は config.yml の adapters.worktree_hook）
#   CONFIG_YML      config.yml のパス（未指定時は下記 config.yml 探索ロジック）
#
# config.yml 探索順:
#   1. $CONFIG_YML 環境変数
#   2. $(pwd)/.engineer/config.yml
#   3. $(pwd)/config.yml
#   4. $WORKSPACE/.engineer/config.yml
#   5. yq があれば yq でパース、なければ awk フォールバック
#
# Hook インターフェース（run_hook 経由で呼び出し）:
#   hook.sh post-create <repo_path> <wt_dir> <branch>
#   hook.sh up <repo_path> <wt_dir>
#   hook.sh down <repo_path> <wt_dir>
#   hook.sh pre-remove <repo_path> <wt_dir>
# ============================================================
set -euo pipefail

log() { echo "[worktree] $*"; }
warn() { echo "[worktree][warn] $*" >&2; }
err() { echo "[worktree][err] $*" >&2; exit 1; }

# ---------- config.yml の発見 ----------

find_config() {
    if [[ -n "${CONFIG_YML:-}" && -f "$CONFIG_YML" ]]; then
        echo "$CONFIG_YML"
        return 0
    fi
    for candidate in \
        "$(pwd)/.engineer/config.yml" \
        "$(pwd)/config.yml" \
        "${WORKSPACE:-}/.engineer/config.yml"
    do
        if [[ -n "$candidate" && -f "$candidate" ]]; then
            echo "$candidate"
            return 0
        fi
    done
    return 1
}

# ---------- yaml 値取得（yq あり/なし両対応） ----------

cfg_get_scalar() {
    # スカラー値取得: workspace_path, adapters.worktree_hook
    local path="$1"
    local config="$2"
    if command -v yq &>/dev/null; then
        yq -r "${path} // \"\"" "$config" 2>/dev/null
        return 0
    fi
    case "$path" in
        .workspace_path)
            grep -E '^workspace_path:' "$config" \
                | sed -E 's/^workspace_path:[[:space:]]*//;s/^"//;s/"$//'
            ;;
        .adapters.worktree_hook)
            # adapters: の配下の worktree_hook: を探す
            awk '
                /^adapters:/ { in_adapters=1; next }
                /^[^[:space:]]/ { in_adapters=0 }
                in_adapters && /^[[:space:]]+worktree_hook:/ {
                    sub(/^[[:space:]]+worktree_hook:[[:space:]]*/, "")
                    gsub(/^"|"$/, "")
                    print
                    exit
                }
            ' "$config"
            ;;
        *)
            err "cfg_get_scalar: yq 不在時は .workspace_path / .adapters.worktree_hook のみ対応"
            ;;
    esac
}

cfg_get_base_branch() {
    local repo="$1"
    local config="$2"
    if command -v yq &>/dev/null; then
        yq -r ".repositories[] | select(.name == \"${repo}\") | .base_branch // \"\"" "$config" 2>/dev/null
        return 0
    fi
    # awk フォールバック: name マッチ時の base_branch を返す
    awk -v name="$repo" '
        /^[[:space:]]*- name:/ {
            sub(/^[[:space:]]*- name:[[:space:]]*/, "")
            gsub(/^"|"$/, "")
            current = $0
        }
        /^[[:space:]]+base_branch:/ && current == name {
            sub(/^[[:space:]]+base_branch:[[:space:]]*/, "")
            gsub(/^"|"$/, "")
            print
            exit
        }
    ' "$config"
}

# ---------- hook パスの解決 ----------

resolve_hook() {
    local config="$1"
    local hook=""

    # 1. 環境変数
    if [[ -n "${WORKTREE_HOOK:-}" ]]; then
        hook="$WORKTREE_HOOK"
    fi

    # 2. config.yml
    if [[ -z "$hook" && -n "$config" ]]; then
        hook="$(cfg_get_scalar .adapters.worktree_hook "$config")"
    fi

    [[ -z "$hook" ]] && { echo ""; return 0; }

    # 絶対パスならそのまま
    if [[ "$hook" = /* ]]; then
        echo "$hook"
        return 0
    fi

    # 相対パスの解決候補（config.yml のあるディレクトリ基準、その親、cwd）
    local config_dir
    config_dir="$(dirname "$config")"
    for candidate in \
        "${config_dir}/${hook}" \
        "${config_dir}/../${hook}" \
        "$(pwd)/${hook}"
    do
        if [[ -f "$candidate" ]]; then
            # 正規化
            echo "$(cd "$(dirname "$candidate")" && pwd)/$(basename "$candidate")"
            return 0
        fi
    done

    # 見つからない場合は相対パスをそのまま返す（実行時に再判定）
    echo "$hook"
}

# ---------- 本体 ----------

CONFIG="$(find_config || true)"
if [[ -z "$CONFIG" ]]; then
    warn "config.yml が見つかりません（CONFIG_YML 環境変数か cwd/.engineer/config.yml を配置）"
fi

# WORKSPACE の決定
if [[ -z "${WORKSPACE:-}" ]]; then
    if [[ -n "$CONFIG" ]]; then
        WORKSPACE="$(cfg_get_scalar .workspace_path "$CONFIG")"
    fi
    WORKSPACE="${WORKSPACE:-$HOME/workspace}"
fi

HOOK=""
if [[ -n "$CONFIG" ]]; then
    HOOK="$(resolve_hook "$CONFIG")"
fi

# ---------- コマンド処理 ----------

CMD="${1:-}"
shift || true

case "$CMD" in
    create)
        REPO="${1:?repo required}"
        BRANCH="${2:?branch required}"
        REPO_PATH="${WORKSPACE}/${REPO}"
        [[ -d "$REPO_PATH" ]] || err "${REPO_PATH} が見つかりません"

        # wt ディレクトリ名の suffix（ブランチ名末尾の数字 or md5）
        SUFFIX="$(echo "$BRANCH" | grep -oE '[0-9]+$' || true)"
        if [[ -z "$SUFFIX" ]]; then
            SUFFIX="$(echo "$BRANCH" | md5sum 2>/dev/null | cut -c1-6 \
                || echo "$BRANCH" | md5 -q 2>/dev/null | cut -c1-6)"
        fi
        WT_DIR="${WORKSPACE}/${REPO}-wt-${SUFFIX}"

        [[ ! -d "$WT_DIR" ]] || err "${WT_DIR} は既に存在します"

        log "=== worktree 作成 ==="
        log "  repo:    ${REPO}"
        log "  branch:  ${BRANCH}"
        log "  wt_dir:  ${WT_DIR}"

        # ローカルブランチ存在チェック
        if git -C "$REPO_PATH" show-ref --verify --quiet "refs/heads/${BRANCH}"; then
            log "  既存ブランチから worktree 作成"
            git -C "$REPO_PATH" worktree add "$WT_DIR" "$BRANCH"
        elif git -C "$REPO_PATH" show-ref --verify --quiet "refs/remotes/origin/${BRANCH}"; then
            log "  リモートブランチから worktree 作成"
            git -C "$REPO_PATH" worktree add "$WT_DIR" "origin/${BRANCH}"
        else
            # 新規ブランチ: config.yml の base_branch から作成
            BASE_BRANCH=""
            if [[ -n "$CONFIG" ]]; then
                BASE_BRANCH="$(cfg_get_base_branch "$REPO" "$CONFIG")"
            fi
            [[ -n "$BASE_BRANCH" ]] || err "${REPO} の base_branch が config.yml で未定義。既存ブランチも存在しません"
            log "  新規ブランチを ${BASE_BRANCH} から作成"
            git -C "$REPO_PATH" fetch origin "$BASE_BRANCH"
            git -C "$REPO_PATH" worktree add -b "$BRANCH" "$WT_DIR" "origin/${BASE_BRANCH}"
        fi

        # hook の post-create
        if [[ -n "$HOOK" && -f "$HOOK" ]]; then
            log "  hook post-create 実行: $(basename "$HOOK")"
            bash "$HOOK" post-create "$REPO_PATH" "$WT_DIR" "$BRANCH"
        else
            log "  hook 未設定 or 未検出、スキップ"
        fi

        log "=== 作成完了 ==="
        log "  dir:     ${WT_DIR}"
        log "  次:      worktree.sh up ${REPO} ${SUFFIX}"
        ;;

    up|down)
        REPO="${1:?repo required}"
        ISSUE_NUM="${2:?issue番号 required}"
        REPO_PATH="${WORKSPACE}/${REPO}"
        WT_DIR="${WORKSPACE}/${REPO}-wt-${ISSUE_NUM}"
        [[ -d "$WT_DIR" ]] || err "${WT_DIR} が見つかりません"
        if [[ -n "$HOOK" && -f "$HOOK" ]]; then
            log "hook ${CMD}: $(basename "$HOOK")"
            bash "$HOOK" "$CMD" "$REPO_PATH" "$WT_DIR"
        else
            log "hook 未設定のため ${CMD} は何もしません"
        fi
        ;;

    remove)
        REPO="${1:?repo required}"
        ISSUE_NUM="${2:?issue番号 required}"
        REPO_PATH="${WORKSPACE}/${REPO}"
        WT_DIR="${WORKSPACE}/${REPO}-wt-${ISSUE_NUM}"
        [[ -d "$WT_DIR" ]] || err "${WT_DIR} が見つかりません"
        if [[ -n "$HOOK" && -f "$HOOK" ]]; then
            log "hook pre-remove: $(basename "$HOOK")"
            bash "$HOOK" pre-remove "$REPO_PATH" "$WT_DIR" || warn "pre-remove で失敗（継続）"
        fi
        git -C "$REPO_PATH" worktree remove "$WT_DIR" --force
        log "削除完了: $WT_DIR"
        ;;

    list)
        REPO="${1:?repo required}"
        REPO_PATH="${WORKSPACE}/${REPO}"
        git -C "$REPO_PATH" worktree list
        ;;

    *)
        cat <<USAGE
Usage: $(basename "$0") <command> <args>

Commands:
  create <repo> <branch>    worktree 作成（新規ブランチなら base_branch から自動作成）
  up <repo> <issue番号>      hook 経由で起動
  down <repo> <issue番号>    hook 経由で停止
  remove <repo> <issue番号>  worktree 削除（pre-remove hook 実行後）
  list <repo>               worktree 一覧

Env:
  WORKSPACE       workspace ルートパス
  WORKTREE_HOOK   hook スクリプトパス（config.yml より優先）
  CONFIG_YML     config.yml のパス（未指定時は cwd/.engineer/config.yml 等を探索）
USAGE
        exit 1
        ;;
esac
