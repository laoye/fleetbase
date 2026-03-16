# CLAUDE.md

本文件为 Claude Code（claude.ai/code）在此仓库中工作时提供指导。

> **建议：** 与本仓库相关的所有对话、代码注释、提交信息和文档说明，建议优先使用**中文**进行交流，以确保一致性与可读性。

## 仓库概览

Fleetbase 是一个模块化物流与供应链操作系统。本 monorepo 包含：

- **`api/`** — Laravel 10 PHP 后端（主应用外壳）
- **`console/`** — Ember.js 5 前端应用
- **`packages/`** — 扩展包（同时包含 PHP 和 Ember 组件）
- **`docker/`** — Docker 基础设施文件
- **`docker-compose.yml`** — 主编排文件

## Docker 服务

整个技术栈通过 Docker Compose 运行，包含以下服务：

| 服务 | 说明 | 端口 |
|---|---|---|
| `application` | Laravel API（镜像：`fleetbase/fleetbase-api:latest`） | — |
| `httpd` | API 的 Apache 反向代理 | 8000 |
| `console` | Ember.js 构建并由 nginx 提供服务 | 4200 |
| `database` | MySQL 8.0 | 3306 |
| `cache` | Redis | — |
| `socket` | SocketCluster v17 | 38000 |
| `queue` | Laravel 队列 worker | — |
| `scheduler` | go-crond 定时任务调度器 | — |

本地覆盖配置写入 `docker-compose.override.yml`，示例文件为 `docker-compose.override.yml.example`。

## 开发常用命令

### Docker（主要工作流）

```bash
# 启动所有服务
docker compose up -d

# 拉取最新代码后执行部署脚本（运行迁移、种子、权限、缓存）
docker compose exec application bash -c "./deploy.sh"

# 若缺少 APP_KEY，生成一个
docker compose exec application bash -c "php artisan key:generate --show"
```

### API（Laravel — `api/` 目录）

```bash
# 运行全部测试（PHPUnit）
php artisan test

# 运行单个测试文件
php artisan test tests/Feature/SomeTest.php

# 运行单个测试方法
php artisan test --filter testMethodName

# 清除缓存
php artisan cache:clear && php artisan route:clear && php artisan config:cache && php artisan route:cache

# 清除日志并重置权限
composer clear-logs
```

### Core API 包（`packages/core-api/`）

```bash
composer lint         # 代码格式化（PHP CS Fixer）
composer test:types   # 静态分析（PHPStan）
composer test:unit    # 单元测试（Pest）
composer test         # 完整测试套件
```

### FleetOps 扩展（`packages/fleetops/`）

后端（在 `packages/fleetops/` 目录下）：
```bash
composer lint         # PHP CS Fixer
composer test:types   # PHPStan
composer test:unit    # Pest
composer test         # 完整套件
```

前端（在 `packages/fleetops/` 目录下）：
```bash
pnpm lint             # ESLint + 模板 lint + 国际化 lint
pnpm test:ember       # QUnit 测试
pnpm start            # 开发服务器
pnpm build            # 生产构建
```

### 控制台前端（`console/`）

```bash
pnpm start            # ember serve（开发模式）
pnpm start:dev        # ember serve --environment development
pnpm build            # ember build
pnpm lint             # 全部 lint（js、hbs、css、intl）
pnpm lint:js:fix      # 自动修复 JS
pnpm test:ember       # QUnit 测试
```

包管理器为 **pnpm**（`pnpm@9.5.0`）。需要 Node ≥ 18，PHP 8.0–8.2。

## 架构

### 后端扩展体系

API 是一个 Laravel 应用。核心抽象位于 `packages/core-api/`（Composer 包名：`fleetbase/core-api`）。FleetOps、Storefront、IAM、Registry Bridge 等扩展均遵循相同结构：

```
packages/<extension>/
├── composer.json           # PHP 包（服务端）
├── server/
│   ├── src/
│   │   ├── Http/
│   │   │   ├── Controllers/
│   │   │   │   ├── Api/v1/        # 公开 API（API Key 认证，fleetbase.api 中间件）
│   │   │   │   └── Internal/v1/  # 内部控制台 API（Sanctum 认证，fleetbase.protected 中间件）
│   │   │   ├── Resources/v1/      # JSON API 资源
│   │   │   └── Requests/          # 表单请求验证
│   │   ├── Models/                # Eloquent 模型
│   │   ├── Providers/             # 服务提供者（继承 CoreServiceProvider）
│   │   └── routes.php
│   └── migrations/
```

每个扩展的服务提供者都继承 `Fleetbase\Providers\CoreServiceProvider`。基础控制器 `FleetbaseController` 通过 `HasApiControllerBehavior` trait 提供标准 CRUD（index、show、create、update、destroy），由 `$model`、`$resource`、`$filter` 属性驱动。

所有 Eloquent 模型以 `uuid` 作为主键（非自增、字符串类型），同时有 `public_id` 列（如 `order_abc123`）用于对外暴露的 API。

### 前端扩展体系

控制台（`console/`）是 Ember Octane 应用。扩展以**懒加载 Ember Engine** 的形式接入。每个扩展包包含：

```
packages/<extension>/
├── package.json            # Ember addon/engine
├── addon/
│   ├── engine.js           # Engine 类（继承 @ember/engine）
│   ├── extension.js        # 扩展注册入口（setupExtension）
│   ├── routes.js
│   ├── components/
│   ├── controllers/
│   ├── routes/
│   └── services/
└── app/                    # 宿主应用解析的再导出
```

扩展通过 `extension.js` → `setupExtension(app, universe)` 完成自我注册。`universe` 服务（位于 `@fleetbase/ember-core`）是中央注册表/事件总线，其子服务包括：

- `universe/menu-service` — 顶部导航、管理面板、侧边栏
- `universe/registry-service` — 具名组件/插槽注册表
- `universe/widget-service` — 仪表盘小部件
- `universe/hook-service` — 生命周期钩子
- `universe/extension-manager` — 懒加载 Engine

核心共享包：

| 包名 | 职责 |
|---|---|
| `@fleetbase/ember-core` | 服务层（`universe`、`fetch`、`crud`、`session`、`socket`、`current-user` 等）、适配器、认证器 |
| `@fleetbase/ember-ui` | UI 组件库（按钮、表格、弹窗、覆盖层、过滤器、地图等） |
| `@fleetbase/fleetops-data` | FleetOps 资源的 Ember Data 模型与适配器 |

### 控制台运行时配置

`console/fleetbase.config.json` 提供运行时配置，无需重新构建即可覆盖：

```json
{
  "API_HOST": "http://localhost:8000",
  "SOCKETCLUSTER_HOST": "localhost",
  "SOCKETCLUSTER_PORT": "38000",
  "SOCKETCLUSTER_SECURE": "false"
}
```

构建时环境变量位于 `console/environments/.env.development` 和 `.env.production`。

### API 路由约定

路由分为两个前缀：
- `/v1/…` — 公开/可消费 API（中间件 `fleetbase.api`，API Key 认证）
- `/int/v1/…` — 内部控制台 API（中间件 `fleetbase.protected`，Sanctum Session 认证）

### 扩展元数据

每个扩展包根目录有 `extension.json`，指定 `"engine"`（指向 `package.json`）和 `"api"`（指向 `composer.json`），供 Fleetbase 注册中心消费。

## 关键配置文件

- `docker-compose.override.yml` — 本地环境覆盖（APP_KEY、CONSOLE_HOST、第三方密钥）
- `api/.env` — 挂载到应用容器
- `console/fleetbase.config.json` — 运行时挂载到控制台容器
- `api/deploy.sh` — 部署后脚本（迁移、种子数据、权限、缓存预热）
