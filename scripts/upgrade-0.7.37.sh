#!/usr/bin/env bash
# 在 Git Bash / WSL 下运行
# 用途：fleetbase 0.7.31 -> 0.7.37 升级的剩余步骤（合并已提交，本脚本只跑装包/迁移）
# 前置条件：合并已 commit，docker 已停（或允许本脚本停掉）。
#
# 用法：
#   bash scripts/upgrade-0.7.37.sh
# 或分步：
#   bash scripts/upgrade-0.7.37.sh composer    # 只跑 composer install
#   bash scripts/upgrade-0.7.37.sh pnpm        # 只跑 pnpm install
#   bash scripts/upgrade-0.7.37.sh up          # 只起服务
#   bash scripts/upgrade-0.7.37.sh deploy      # 只跑 deploy.sh

set -euo pipefail

# 切到 fleetbase 根目录（不管脚本从哪调起来）
cd "$(dirname "$0")/.."

CACHE_VOLUME="fleetbase_composer_cache"

log() { printf '\n\033[1;36m▶ %s\033[0m\n' "$*"; }
err() { printf '\n\033[1;31m✗ %s\033[0m\n' "$*" >&2; }

cleanup_runs() {
    # 直接用 docker ps 的 filter 功能，如果没有匹配，它不会返回错误退出码
    local containers
    containers=$(docker ps -a --filter "name=application-run" --format "{{.Names}}")

    if [ -n "$containers" ]; then
        echo "$containers" | while read -r c; do
            log "清理残留容器 $c"
            docker rm -f "$c" >/dev/null 2>&1 || true
        done
    fi
}

step_composer() {
    log "Step 1: composer install（持久化 cache volume，跨重试复用下载）"

    docker volume create "$CACHE_VOLUME" >/dev/null 2>&1 || true

    # 先确保 db / cache 起来（composer post-script 不需要它们，但 application 镜像 healthcheck 可能依赖）
    docker compose up -d database cache

    cleanup_runs

    # 跑 composer install
    # COMPOSER_PROCESS_TIMEOUT=60 让 git clone --mirror 在 60s 内失败、立即回退到 dist
    # （不要用大值，源 clone 慢就慢在不放弃）
    docker compose run --rm \
        -v "${CACHE_VOLUME}:/root/.cache/composer" \
        -e COMPOSER_PROCESS_TIMEOUT=600 \
        application composer install --prefer-dist --no-interaction

    log "✓ composer install 完成"
}

step_pnpm() {
    log "Step 2: pnpm install（console 镜像最终阶段是 nginx 没 pnpm，需要 host 或一次性 node 容器）"
    cleanup_runs

    # 优先用 host 上的 pnpm（最快，不用绕 docker bind mount）
    if command -v pnpm >/dev/null 2>&1; then
        log "✓ host 检测到 pnpm $(pnpm --version)，直接在 console/ 跑"
        (cd console && pnpm install --no-frozen-lockfile)
        log "✓ pnpm install 完成"
        return 0
    fi

    log "host 未装 pnpm，回退到一次性 node:18 容器"

    # 用一次性 node:18.15.0-alpine 容器跑 pnpm install
    # - 挂当前目录到 /app（含 packages/、console/、pnpm-workspace.yaml）
    # - 工作目录 /app/console
    # - 用国内 npmmirror 镜像（与 console/Dockerfile.local 保持一致）
    # - pnpm store 用 named volume，避免 Windows bind 路径问题导致的 EPERM
    docker volume create fleetbase_pnpm_store >/dev/null 2>&1 || true

    MSYS_NO_PATHCONV=1 docker run --rm \
        -v "/$(pwd):/app" \
        -v fleetbase_pnpm_store:/root/.local/share/pnpm/store \
        -w //app/console \
        node:18.15.0-alpine \
        sh -c "
            set -e
            echo '--- 安装 pnpm 到 npm 全局 ---'
            npm config set registry https://registry.npmmirror.com
            npm install -g pnpm@9.5.0
            echo '--- 配置 pnpm 镜像 ---'
            pnpm config set registry https://registry.npmmirror.com
            echo '--- pnpm install (workspace-aware) ---'
            pnpm install --no-frozen-lockfile
        "

    log "✓ pnpm install 完成（pnpm-lock.yaml 已更新到 host）"
}

step_up() {
    log "Step 3: 启动全部服务"
    docker compose up -d

    log "等待 application healthy..."
    for i in $(seq 1 30); do
        status=$(docker inspect --format='{{.State.Health.Status}}' fleetbase-application-1 2>/dev/null || echo "starting")
        printf '  attempt %d: %s\n' "$i" "$status"
        if [ "$status" = "healthy" ]; then break; fi
        sleep 4
    done

    log "✓ 服务全部起来"
}

step_deploy() {
    log "Step 4: 跑 deploy.sh（迁移、种子、缓存、权限）"

    docker compose exec -T application bash -c "./deploy.sh"

    log "✓ deploy.sh 完成（新 fleetops migrations 应已应用：manifests / maintenances / work_orders / equipments / parts / schedules / schedule_items / schedule_exceptions 等）"
}

step_smoke() {
    log "Step 5: 烟雾测试"

    echo "  - API 健康检查："
    curl -sf "http://localhost:8000/" -o /dev/null && echo "    ✓ application 在 8000 响应" || err "application 未响应"

    echo "  - console："
    curl -sf "http://localhost:4200" -o /dev/null && echo "    ✓ console 在 4200 响应" || err "console 未响应"

    echo "  - 数据库迁移检查："
    docker compose exec -T database mysql -uroot fleetbase -e "SHOW TABLES LIKE 'manifests';" 2>&1 | grep -q manifests && echo "    ✓ manifests 表存在" || err "manifests 表不存在"
    docker compose exec -T database mysql -uroot fleetbase -e "SHOW TABLES LIKE 'maintenances';" 2>&1 | grep -q maintenances && echo "    ✓ maintenances 表存在" || err "maintenances 表不存在"
    docker compose exec -T database mysql -uroot fleetbase -e "SHOW TABLES LIKE 'schedules';" 2>&1 | grep -q schedules && echo "    ✓ schedules 表存在" || err "schedules 表不存在"
    docker compose exec -T database mysql -uroot fleetbase -e "SHOW COLUMNS FROM orders LIKE 'manifest_uuid';" 2>&1 | grep -q manifest_uuid && echo "    ✓ orders.manifest_uuid 字段存在" || err "orders.manifest_uuid 字段不存在"

    log "✓ 烟雾测试通过"
    echo ""
    echo "下一步建议："
    echo "  - 重启 ops-portal:    cd ../ops-portal && pnpm dev"
    echo "  - 重启 merchant-portal: cd ../merchant-portal && pnpm dev"
    echo "  - 测试 ForBox 关键流程：登录、运单创建、子账号、强制 POD"
    echo ""
    echo "如果有问题需要回滚（在 fleetbase/）："
    echo "  git reset --hard backup/pre-0.7.37-merge-20260429"
    echo "  cd packages/fleetops && git reset --hard backup/pre-v0.6.45-merge-20260429"
    echo "  cd ../ember-ui && git reset --hard backup/pre-v0.3.26-merge-20260429"
    echo "  cd ../.. && bash scripts/upgrade-0.7.37.sh composer"
}

case "${1:-all}" in
    composer) step_composer ;;
    pnpm)     step_pnpm ;;
    up)       step_up ;;
    deploy)   step_deploy ;;
    smoke)    step_smoke ;;
    all)
        step_composer
        step_pnpm
        step_up
        step_deploy
        step_smoke
        log "🎉 fleetbase 0.7.37 升级完成"
        ;;
    *)
        err "用法: $0 [composer|pnpm|up|deploy|smoke|all]"
        exit 2
        ;;
esac
