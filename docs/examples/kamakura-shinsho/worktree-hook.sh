#!/bin/bash
set -euo pipefail

# ============================================================
# 鎌倉新書向け worktree hook
#
# Docker compose（web/api/misc構成）+ vendor/node_modules コピー
# + Makefile生成 + volume override を処理する。
#
# 使い方:
#   .engineer/config.yml の adapters.worktree_hook にこのファイルのパスを設定
#
# 前提:
#   - docker-compose-for-web.yml / docker-compose-for-api.yml / docker-compose-for-misc.yml
#   - src/web/, src/api/ ディレクトリ構成
#   - Makefile によるDocker管理
# ============================================================

ACTION="${1:?}"
REPO_PATH="${2:?}"
WT_DIR="${3:-}"
BRANCH="${4:-}"

REPO_NAME="$(basename "$REPO_PATH")"
WT_NAME="$(basename "$WT_DIR")"

# ---------- ヘルパー ----------

detect_compose_file() {
    local dir="${1}"
    local base="${2}"
    if [[ -f "$dir/docker-compose-for-${base}-arm.yml" ]]; then
        echo "docker-compose-for-${base}-arm.yml"
    else
        echo "docker-compose-for-${base}.yml"
    fi
}

stop_main() {
    local web_compose api_compose
    web_compose=$(detect_compose_file "$REPO_PATH" "web")
    api_compose=$(detect_compose_file "$REPO_PATH" "api")
    echo "  本体を停止中..."
    docker compose -f "$REPO_PATH/${web_compose}" -p "${REPO_NAME}-front" down 2>/dev/null || true
    docker compose -f "$REPO_PATH/${api_compose}" -p "${REPO_NAME}-back" down 2>/dev/null || true
    docker compose -f "$REPO_PATH/docker-compose-for-misc.yml" -p "${REPO_NAME}-misc" down 2>/dev/null || true
}

# ---------- アクション ----------

case "$ACTION" in
    post-create)
        # .env コピー
        echo "=== .env コピー ==="
        if [[ -f "$REPO_PATH/.env" ]]; then
            cp "$REPO_PATH/.env" "$WT_DIR/.env"
            echo "  .env"
        fi
        for subdir in web api; do
            if [[ -f "$REPO_PATH/src/${subdir}/.env" ]]; then
                [[ -d "$WT_DIR/src/${subdir}" ]] || mkdir -p "$WT_DIR/src/${subdir}"
                cp "$REPO_PATH/src/${subdir}/.env" "$WT_DIR/src/${subdir}/.env"
                echo "  src/${subdir}/.env"
            fi
        done

        # vendor + composer.lock + node_modules コピー
        echo ""
        echo "=== 依存ファイルコピー ==="
        for subdir in web api; do
            if [[ -d "$REPO_PATH/src/${subdir}/vendor" ]]; then
                echo "  src/${subdir}/vendor/ をコピー中..."
                rm -rf "$WT_DIR/src/${subdir}/vendor"
                cp -a "$REPO_PATH/src/${subdir}/vendor" "$WT_DIR/src/${subdir}/vendor"
                [[ -f "$REPO_PATH/src/${subdir}/composer.lock" ]] && \
                    cp "$REPO_PATH/src/${subdir}/composer.lock" "$WT_DIR/src/${subdir}/composer.lock"
            fi
            if [[ -d "$REPO_PATH/src/${subdir}/node_modules" ]]; then
                echo "  src/${subdir}/node_modules/ をコピー中..."
                rm -rf "$WT_DIR/src/${subdir}/node_modules"
                cp -a "$REPO_PATH/src/${subdir}/node_modules" "$WT_DIR/src/${subdir}/node_modules"
            fi
        done

        # 生成済みファイルコピー
        echo ""
        echo "=== 生成済みファイルコピー ==="
        local generated_files
        generated_files=$(cd "$REPO_PATH" && git ls-files --others --ignored --exclude-standard src/web/resources/ 2>/dev/null | grep -v node_modules || true)
        if [[ -n "$generated_files" ]]; then
            echo "$generated_files" | rsync -a --files-from=- "$REPO_PATH/" "$WT_DIR/"
            echo "  src/web/resources/ の生成ファイルを同期完了"
        else
            echo "  生成ファイルなし（スキップ）"
        fi

        # misc volume override
        if [[ -f "$REPO_PATH/docker-compose-for-misc.yml" ]]; then
            echo ""
            echo "=== volume override 生成 ==="
            local main_misc_prefix="${REPO_NAME}-misc"
            cat > "$WT_DIR/docker-compose-for-misc.override.yml" <<YAML
volumes:
  mysql-data:
    external: true
    name: ${main_misc_prefix}_mysql-data
  web-redis-data:
    external: true
    name: ${main_misc_prefix}_web-redis-data
  api-redis-data:
    external: true
    name: ${main_misc_prefix}_api-redis-data
  minio-data:
    external: true
    name: ${main_misc_prefix}_minio-data
YAML
            echo "  本体のDB/Redis/Minioデータを共有"
        fi

        # Makefile 生成
        if [[ -f "$REPO_PATH/Makefile" ]]; then
            local suffix
            suffix=$(basename "$WT_DIR" | sed "s/^${REPO_NAME}-wt-//")
            local wt_name="${REPO_NAME}-wt-${suffix}"
            echo ""
            echo "=== Makefile 生成 ==="
            sed \
                -e "s|-p ${REPO_NAME}-|-p ${wt_name}-|g" \
                -e "s|${REPO_NAME}-network|${wt_name}-network|g" \
                -e "s|-f docker-compose-for-misc.yml|-f docker-compose-for-misc.yml -f docker-compose-for-misc.override.yml|g" \
                "$REPO_PATH/Makefile" > "$WT_DIR/Makefile"
            echo "  プロジェクト名: ${wt_name}-{front,back,misc}"
        fi

        # logs ディレクトリ
        mkdir -p "$WT_DIR/logs/web/nginx" "$WT_DIR/logs/web/phpfpm" \
                 "$WT_DIR/logs/api/nginx" "$WT_DIR/logs/api/phpfpm" \
                 "$WT_DIR/logs/misc/web-nginx" "$WT_DIR/logs/misc/api-nginx" "$WT_DIR/logs/misc/mysql" \
                 2>/dev/null || true
        ;;

    up)
        local web_compose api_compose
        web_compose=$(detect_compose_file "$WT_DIR" "web")
        api_compose=$(detect_compose_file "$WT_DIR" "api")

        stop_main

        echo "  worktreeを起動中..."
        local misc_compose=(-f docker-compose-for-misc.yml)
        [[ -f "$WT_DIR/docker-compose-for-misc.override.yml" ]] && misc_compose+=(-f docker-compose-for-misc.override.yml)
        (cd "$WT_DIR" && docker compose "${misc_compose[@]}" -p "${WT_NAME}-misc" up -d --wait)
        (cd "$WT_DIR" && docker compose "${misc_compose[@]}" -p "${WT_NAME}-misc" exec minio bash -c "/scripts/create-buckets.sh") 2>/dev/null || true
        (cd "$WT_DIR" && docker compose -f "${web_compose}" -p "${WT_NAME}-front" up -d)
        (cd "$WT_DIR" && docker compose -f "${api_compose}" -p "${WT_NAME}-back" up -d)

        if [[ -f "$WT_DIR/.env" ]]; then
            local web_port
            web_port=$(grep '^WEB_PORT=' "$WT_DIR/.env" | cut -d= -f2)
            echo "  アクセス: https://localhost:${web_port}"
        fi
        ;;

    down)
        local web_compose api_compose
        web_compose=$(detect_compose_file "$WT_DIR" "web")
        api_compose=$(detect_compose_file "$WT_DIR" "api")
        local misc_compose=(-f docker-compose-for-misc.yml)
        [[ -f "$WT_DIR/docker-compose-for-misc.override.yml" ]] && misc_compose+=(-f docker-compose-for-misc.override.yml)
        (cd "$WT_DIR" && docker compose -f "${web_compose}" -p "${WT_NAME}-front" down) 2>/dev/null || true
        (cd "$WT_DIR" && docker compose -f "${api_compose}" -p "${WT_NAME}-back" down) 2>/dev/null || true
        (cd "$WT_DIR" && docker compose "${misc_compose[@]}" -p "${WT_NAME}-misc" down) 2>/dev/null || true

        echo "  本体に戻す場合: cd ${REPO_PATH} && make up"
        ;;

    pre-remove)
        local web_compose api_compose
        web_compose=$(detect_compose_file "$WT_DIR" "web")
        api_compose=$(detect_compose_file "$WT_DIR" "api")
        local misc_compose=(-f docker-compose-for-misc.yml)
        [[ -f "$WT_DIR/docker-compose-for-misc.override.yml" ]] && misc_compose+=(-f docker-compose-for-misc.override.yml)
        (cd "$WT_DIR" && docker compose -f "${web_compose}" -p "${WT_NAME}-front" down) 2>/dev/null || true
        (cd "$WT_DIR" && docker compose -f "${api_compose}" -p "${WT_NAME}-back" down) 2>/dev/null || true
        (cd "$WT_DIR" && docker compose "${misc_compose[@]}" -p "${WT_NAME}-misc" down) 2>/dev/null || true
        ;;

    *)
        echo "Unknown action: $ACTION" >&2
        exit 1
        ;;
esac
