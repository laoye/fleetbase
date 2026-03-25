# Fleetbase 国际化 (i18n) 变更说明

## 概述

本次变更为 Fleetbase 控制台全面实施了国际化（i18n）支持，涵盖主仓库、`packages/ember-ui` 和 `packages/fleetops` 三个仓库，共计修改 **129 个文件**（主仓库 22 个、ember-ui 33 个、fleetops 74 个），新增约 **600+ 条翻译键**（中英双语）。

---

## 一、主仓库 (`fleetbase`)

**变更文件数：22 个** | **净增：+438 / -76 行**

### 1.1 翻译文件

| 文件 | 说明 |
|------|------|
| `console/translations/en-us.yaml` | 新增 ~174 条英文翻译键 |
| `console/translations/zh-cn.yaml` | 新增 ~172 条中文翻译键 |

**新增翻译命名空间：**

- `console.account.organizations.*` — 组织管理页面（创建、编辑、退出、删除组织）
- `console.account.auth.*` — 账户认证与安全设置
- `console.settings.index.*` — 组织设置页面
- `layout.header.menus.organization.*` — 顶部右侧组织下拉菜单
- `layout.header.menus.user.*` — 顶部右侧用户下拉菜单
- `component.create-or-join-org.*` — 创建/加入组织弹窗
- `component.install-prompt.*` — 扩展安装提示
- `component.verify-email.*` — 邮箱验证弹窗
- `component.verify-by-sms.*` — 短信验证弹窗
- `component.click-to-copy.*` / `component.click-to-reveal.*` — 复制/显示组件
- `component.activity-log.*` — 活动日志组件
- `component.create-dashboard.*` — 创建仪表盘弹窗
- `component.export.*` — 导出功能
- `component.save-report.*` — 保存报告弹窗
- `component.tip-tap.*` — 富文本编辑器（YouTube、表格插入）
- `component.coordinates.*` — 坐标输入组件
- `component.bulk-search.*` — 批量搜索组件
- `component.custom-field.*` — 自定义字段管理器

### 1.2 模板文件（HBS）

| 文件 | 变更内容 |
|------|---------|
| `console/app/templates/console/account.hbs` | 账户页面侧边栏菜单项国际化 |
| `console/app/templates/console/account/auth.hbs` | 安全认证页面标题、按钮国际化 |
| `console/app/templates/console/account/organizations.hbs` | 组织列表页面（标题、按钮、"Member Since"等） |
| `console/app/components/modals/edit-organization.hbs` | 编辑组织弹窗字段名国际化 |
| `console/app/components/modals/leave-organization.hbs` | 退出组织弹窗全部文本国际化（含参数化翻译） |
| `console/app/components/modals/validate-password.hbs` | 密码验证弹窗国际化 |
| `console/app/components/modals/create-dashboard.hbs` | 创建仪表盘弹窗国际化 |
| `console/app/components/two-fa-settings.hbs` | 双因素认证设置国际化 |

### 1.3 控制器文件（JS）

| 文件 | 变更内容 |
|------|---------|
| `console/app/controllers/console/account/auth.js` | 添加 `intl` 服务，通知消息国际化 |
| `console/app/controllers/console/account/organizations.js` | 添加 `intl` 服务，~10 条通知/弹窗消息国际化 |
| `console/app/controllers/console/settings/index.js` | 添加 `intl` 服务，设置保存通知国际化 |

### 1.4 配置与基础设施文件

| 文件 | 变更内容 |
|------|---------|
| `.dockerignore` | 添加 `api/storage/app/public/uploads` 排除规则（修复构建权限错误） |
| `.gitmodules` | `ember-ui` 子模块 URL 更改为 fork 仓库 |
| `console/package.json` | `@fleetbase/ember-ui` 改为 `workspace:*`（使用本地 workspace 链接） |
| `console/fleetbase.config.json` | 添加 SocketCluster 运行时配置参数 |
| `console/nginx.conf` | 添加 JS/CSS 缓存控制策略（禁用非指纹文件缓存，允许 chunk 长期缓存） |
| `console/environments/.env.development` | 末尾换行修复 |
| `console/environments/.env.production` | 填充 API_HOST 和 SOCKETCLUSTER_HOST 默认值 |

---

## 二、ember-ui 子模块 (`packages/ember-ui`)

**变更文件数：33 个** | **净增：+160 / -147 行**

### 2.1 核心修复：语言切换响应性

**`addon/components/layout/header.js`**（关键修复）

- **问题**：顶部右侧下拉菜单（组织菜单、用户菜单）在切换语言后不会更新
- **原因**：菜单项在 constructor 中一次性构建，不具备 Glimmer 响应性
- **修复**：
  - 注入 `intl` 服务
  - 将 `organizationMenuItems` 和 `userMenuItems` 从 `@tracked` 属性改为 getter
  - 在 getter 中访问 `this.intl.locale` 建立响应性依赖
  - 菜单文本从硬编码英文改为 `this.intl.t(...)` 调用
  - 影响 12 个菜单项（主页、设置、创建/加入组织、探索扩展、管理、登出、查看资料、键盘快捷键、更新日志、开发者、Discord、帮助、文档）

### 2.2 组件模板国际化（30+ HBS 文件）

| 组件 | 国际化字符串数 |
|------|--------------|
| `modals/create-or-join-org.hbs` | 7 个 |
| `modals/install-prompt.hbs` | 2 个 |
| `modals/verify-email.hbs` | 6 个 |
| `modals/resend-verification-email.hbs` | 4 个 |
| `modals/verify-by-sms.hbs` | 4 个 |
| `modals/export-form.hbs` | 2 个 |
| `modals/export-report.hbs` | 10 个 |
| `modals/save-report.hbs` | 7 个 |
| `modals/custom-field-group-form.hbs` | 1 个 |
| `modals/import-form.hbs` | 1 个 |
| `modals/tip-tap-editor-insert-youtube.hbs` | 6 个 |
| `modals/tip-tap-editor-insert-table.hbs` | 4 个 |
| `modals/edit-chat-name.hbs` | 1 个 |
| `modal/default.hbs` + `modal/footer.hbs` | 2 个 |
| `pagination.hbs` | 5 个 |
| `click-to-copy.hbs` | 2 个 |
| `click-to-reveal.hbs` | 3 个 |
| `activity-log.hbs` | 6 个 |
| `coordinates-input.hbs` | 6 个 |
| `bulk-search-dropdown.hbs` | 4 个 |
| `custom-fields-manager.hbs` | 6 个 |
| `custom-field/form.hbs` | 12 个 |
| `custom-field/options-input.hbs` | 2 个 |
| `model-multi-file-upload.hbs` | 1 个 |
| `notification-tray.hbs` | 4 个 |
| `chat-tray.hbs` + `chat-window.hbs` | 若干 |
| `layout/resource/panel/header-actions.hbs` | 2 个 |

### 2.3 JS 文件变更

| 文件 | 变更内容 |
|------|---------|
| `layout/header.js` | 响应性修复 + 菜单文本国际化（见 2.1） |
| `layout/resource/panel.js` | 面板操作文本国际化 |
| `chat-tray.js` / `chat-window.js` | 聊天组件文本国际化 |

---

## 三、fleetops 子模块 (`packages/fleetops`)

**变更文件数：74 个** | **净增：+1083 / -516 行**

### 3.1 翻译文件

| 文件 | 说明 |
|------|------|
| `translations/en-us.yaml` | 新增 251 条英文翻译键 |
| `translations/zh-cn.yaml` | 新增 251 条中文翻译键 |

**新增翻译命名空间：**

- `common.*` — 通用词汇扩展（事件、设备、遥测、协议、序列号、坐标、速度等 70+ 个）
- `vehicle.form.*` — 车辆表单字段（Trim、Color、Serial Number、Call Sign 等）
- `vehicle.sections.*` — 车辆表单分区标题（识别信息、状态、位置、测量单位、保险、容量等）
- `vehicle.details.*` — 车辆详情面板
- `management.*` — 管理模块（车队、司机、车辆、燃油报告、问题、联系人等）
- `connectivity.*` — 连接性模块（设备、传感器、遥测、事件）
- `operations.*` — 运营模块（订单、服务费率、调度器）
- `analytics.*` — 分析模块（报告）
- `settings.*` — 设置模块（自定义字段、通知、路由）
- `positions-replay.*` — 轨迹回放组件
- `map.*` — 地图相关（设备事件列表、位置列表）

### 3.2 组件模板国际化（HBS）

| 文件 | 变更内容 |
|------|---------|
| `vehicle/form.hbs` | 车辆表单 ~30 个硬编码字符串国际化 |
| `vehicle/details.hbs` | 车辆详情页面 ~25 个字符串国际化 |
| `vehicle/card.hbs` / `vehicle/pill.hbs` / `vehicle/panel-header.hbs` | 车辆卡片/标签组件 |
| `positions-replay.hbs` | 轨迹回放播放器完整国际化 |
| `map/drawer/device-event-listing.hbs` | 设备事件列表国际化 |
| `map/drawer/position-listing.hbs` | 位置数据列表国际化 |
| `map/leaflet-live-map.hbs` | 实时地图组件 |
| `modals/vehicle-details.hbs` / `modals/vehicle-form.hbs` | 车辆弹窗 |
| `templates/management/index.hbs` | 管理模块首页 |
| `templates/management/vehicles/index/new.hbs` | 新建车辆页面 |

### 3.3 控制器国际化（JS） — 38 个文件

所有控制器统一注入 `intl` 服务，将硬编码的列标题、按钮文本、通知消息、弹窗确认文本替换为 `this.intl.t(...)` 调用。

**按模块分组：**

| 模块 | 涉及控制器 |
|------|-----------|
| **管理 (management)** | contacts, customers/details, contacts/details, drivers/index, drivers/details, fleets/index, fleets/details, fuel-reports/index, fuel-reports/details, issues/index, issues/details, places/details, vehicles/index, vehicles/details, vendors/details |
| **运营 (operations)** | orders/index, orders/details, scheduler/index, service-rates/index, service-rates/details |
| **连接性 (connectivity)** | devices/index, devices/details, devices/new, events/index, sensors/index, sensors/details, sensors/new, telematics/index, telematics/details, telematics/new |
| **分析 (analytics)** | reports/details, reports/edit, reports/new |
| **设置 (settings)** | custom-fields, notifications, routing |

### 3.4 组件 JS 文件 — 13 个

| 文件 | 变更内容 |
|------|---------|
| `contact/form.js`, `customer/form.js`, `driver/form.js`, `entity/form.js`, `sensor/form.js`, `telematic/form.js`, `vehicle/form.js`, `vehicle/details.js` | 表单组件注入 intl，通知/弹窗国际化 |
| `customer/admin-settings.js`, `customer/create-order-form.js`, `customer/orders.js` | 客户模块组件国际化 |
| `device/manager.js`, `order/details/route.js` | 设备管理、订单路由组件国际化 |
| `map/drawer.js`, `map/drawer/device-event-listing.js`, `map/drawer/position-listing.js` | 地图组件国际化 |
| `positions-replay.js` | 轨迹回放控制逻辑国际化 |
| `modals/reset-customer-credentials.js` | 重置客户凭证弹窗国际化 |

### 3.5 服务文件 — 4 个

| 文件 | 变更内容 |
|------|---------|
| `services/driver-scheduling.js` | 司机排班服务通知文本国际化 |
| `services/order-import.js` | 订单导入服务弹窗/通知国际化 |
| `services/service-areas.js` | 服务区域管理通知国际化 |
| `services/vendor-actions.js` | 供应商操作通知国际化 |

### 3.6 路由文件 — 1 个

| 文件 | 变更内容 |
|------|---------|
| `routes/settings/payments/onboard.js` | 支付入驻路由通知国际化 |

---

## 四、技术要点总结

### 4.1 国际化模式

- **HBS 模板**：`{{t "namespace.key"}}` 语法
- **JS 文件**：`@service intl;` + `this.intl.t('namespace.key')` 调用
- **参数化翻译**：`{{t "key" param=value}}` / `this.intl.t('key', { param: value })`
- **Glimmer 响应性**：通过在 getter 中访问 `this.intl.locale` 实现语言切换时自动重新计算

### 4.2 重要修复

1. **语言切换响应性**：`layout/header.js` 菜单项从 constructor 初始化改为 getter 模式
2. **YAML 重复键**：修复 en-us.yaml 和 zh-cn.yaml 中 `component:` 顶级键重复导致构建失败的问题
3. **Docker 构建**：`.dockerignore` 排除上传目录解决权限报错
4. **Nginx 缓存策略**：添加 JS/CSS 缓存控制规则，确保非指纹文件不缓存
5. **Workspace 链接**：`package.json` 中 `ember-ui` 使用 `workspace:*` 确保本地修改生效

### 4.3 语言支持

| 语言 | 标识 | 状态 |
|------|------|------|
| 英文 | `en-us` | 完整支持（默认回退语言） |
| 中文 | `zh-cn` | 完整支持 |

### 4.4 未完成项

- `packages/ember-ui` 中 query-builder 相关组件（6 个文件，约 50+ 字符串）尚未国际化
- `packages/ember-ui` 中 report-builder 组件尚未国际化
