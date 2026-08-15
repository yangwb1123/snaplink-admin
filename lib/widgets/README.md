# lib/widgets — 组件库（43 组件 · 4 分组）

> 全站 UI 从组件库组装（不重复造轮子）；组件遵守 8pt 间距 token（4-64 集，
> 由 `test/spacing_tokens_gate_test.dart` 门禁守护）与 colorScheme 派生色
> （双模式对比安全）。新页面优先复用下表组件；扩展现有组件而不是新增。
> 文档完整性门禁：本清单与 `docs/ui/pages-per-page/polish-docs.md` 同步。

## 数据/列表（20）

| 组件 | 职责一句话 | 关键参数 | 使用入口页面 |
|---|---|---|---|
| `admin_data_table.dart` | 桌面数据表格：列对齐/点击排序/斑马纹/hover/窄视口自动降级卡片 | `columns`、`itemCount`、`rowBuilder`、`onSort`、`onRowTap`、`density` | clients_tab、users_tab、audit_log_tab、webhooks_tab、tenants_table 等 28 页 |
| `admin_list_header.dart` | 列表页响应式标题 + 主操作（创建/刷新，窄视口换行） | `title`、`subtitle`、`onCreate`、`onRefresh`、`actions` | clients_tab、users_tab、tenants_tab、domains_tab 等 20 页 |
| `paginated_list.dart` | 游标分页控件 + 分页状态 mixin（`PaginationControls`/`PaginatedListMixin`） | `page`、`total`、`canGoBack/canGoNext`、`onPrevious/onNext` | clients_tab、users_tab、local_users_tab、tenants_tab、scim_resource_browser |
| `skeleton_list.dart` | 列表/网格骨架屏（主题化底色，深浅色自适应） | `itemCount`、`crossAxis` | 全站列表页共 52 处（async 加载区占位） |
| `search_filter_bar.dart` | 搜索框 + 筛选 chips + 刷新（防抖，支持全局 Ctrl+F 聚焦） | `debounce`、`controller`、`filterOptions`、`onSearchChanged`、`onFilterChanged` | clients_tab、users_tab、audit_log_tab、domains_tab、tenants_filter_bar |
| `status_filter_dropdown.dart` | 状态筛选下拉（options 值 → i18n 文案自动翻译） | `value`、`options`、`onChanged` | clients_tab、audit_log_tab、webhooks_tab、tenants_filter_bar |
| `section_selector.dart` | 横向区块选择 chip 栏（可滚动，宽 200 截断） | `sections`、`current`、`onSelected` | permissions_tab、governance_tab、token_security_tab、dashboard_screen、portal_screen |
| `batch_selection.dart` | 列表批量选择逻辑 mixin（长按进入 → 点击切换 → 批量栏） | `toggleSelect`、`clearSelection`、`rowTap` | clients_tab、tenants_tab、local_users_tab、users_tab |
| `batch_action_bar.dart` | 批量操作浮动栏（已选数 + 动作列表 + 退出） | `selectedCount`、`actions`、`onClearSelection`、`accent` | clients_tab、local_users_tab、users_tab、tenants_batch_bar |
| `empty_state.dart` | 空状态（empty/noMatch/notEnabled/error 四变体，可带动作） | `variant`、`title`、`subtitle`、`actionLabel/onAction`、`compact` | 全站 60 处（最广泛复用） |
| `timeline_list.dart` | 时间线列表（圆点 + 竖线连接 + 内容，语义色状态） | `items`（`icon`/`color`/`title`/`subtitle`） | governance_widgets、portal/security_activity_tab |
| `info_row.dart` | 详情页 label + value 信息行（可图标/强调级/危险色/复制） | `label`、`value`、`labelWidth`、`icon`、`level`、`danger`、`copyValue` | client_detail、break_glass_detail、connection_detail、webhook_detail_widgets |
| `key_metric_card.dart` | 指标卡（图标圆底 + CountUp 数值 + 真实 delta/趋势/说明），`MetricStrip` 流式排布 | `label`、`value`、`delta`、`sparkline`、`icon`、`color` | admin_overview_metrics、device_security_dashboard、usage_analytics_tab、tenant_detail、portal_widgets |
| `distribution_bar.dart` | 比例分布条 + 图例（诚实规则：非正总数渲染占位轨道） | `segments`、`total`、`showLegend`、`emphasizedLabel` | admin_overview_tab、list_metrics、usage_analytics_tab、webhooks_tab、connections/list_card |
| `sparkline.dart` | 迷你趋势图（自绘折线 + 渐变面积，500ms 生长） | `data`、`color`、`height`、`strokeWidth` | usage_analytics_tab、key_metric_card（间接） |
| `progress_ring.dart` | 圆形进度环（0-100，按阈值换色） | `value`、`size`、`strokeWidth`、`label` | admin_overview_tab |
| `count_up.dart` | 数字滚动动画（600ms，整数/一位小数） | `value`、`fractionDigits`、`style` | key_metric_card（间接） |
| `metric_delta.dart` | 环比百分比纯函数（无真实趋势返回 null） | `series`（List<num>） | 工具函数（metric_delta_test 锁定） |
| `data_emphasis.dart` | 数据强调级别文本（primary/secondary/tertiary，主题派生） | `level`、`text`、`maxLines` | client_detail、network_policies、credentials、crypto_keys 等 12 页 |
| `user_avatar.dart` | 首字母头像（名字 hash 稳定取色，无需头像 URL） | `name`、`radius` | users_tab、local_users_tab、portal/member_row_tile |

## 状态/反馈（7）

| 组件 | 职责一句话 | 关键参数 | 使用入口页面 |
|---|---|---|---|
| `status_chip.dart` | 状态徽章（颜色 + 文字双编码，10 个工厂：active/inactive/suspended/healthy/…） | `label`、`color`、`icon` | 全站 38 处（状态列/摘要） |
| `async_view.dart` | 统一三态视图（loading / error / empty / data），含 `ErrorStateView` 整页错误与 `ErrorStateCard` 内联错误条 | `loading`、`error`、`data`、`onRetry`、`errorTitle`、`emptyTitle`、`dataBuilder` | 全站 38 处列表/详情加载 |
| `error_boundary.dart` | 子树错误边界（构建异常 → 兜底 UI + 重试，链式 restore 全局 handler） | `child`、`label` | admin/dashboard_page_resolution |
| `offline_banner.dart` | 离线横幅（ConnectivityService 订阅，警告色 tint 叠表面） | `child` | admin/dashboard_screen |
| `confirm_dialog.dart` | 确认对话框（破坏性红色、键入确认 `confirmText`、加载态），`DangerActionTile` 危险操作列表项 | `title`、`message`、`confirmText`、`destructive`、`isLoading` | 全站 46 处危险操作 |
| `hover_card.dart` | 卡片 hover 提升（阴影加深 + 上浮 2dp + 180ms 动画） | `child`、`hoverElevation`、`restingElevation` | admin_overview_tab、portal_widgets |
| `pressable_scale.dart` | 按压缩放反馈（0.98，90ms 回弹） | `child` | device_verify、oidc_login 各视图、setup |

## 布局/交互（12）

| 组件 | 职责一句话 | 关键参数 | 使用入口页面 |
|---|---|---|---|
| `responsive_navigation_scaffold.dart` | 响应式应用壳（<720 抽屉 / 中 rail / ≥1180 全标签 rail） | `appBar`、`destinations`、`selectedIndex`、`onDestinationSelected`、`drawerHeader` | admin/dashboard_screen、portal_screen |
| `responsive_entry_card.dart` | 响应式键盘安全入口卡片壳（窄屏紧凑、滚动防裁剪、300ms 入场） | `child`、`maxWidth` | device_verify_screen、oidc_login_screen、setup_screen |
| `page_transition.dart` | 页面切换过渡（fade + 8dp 上滑，key 区分页面） | `pageKey`、`child` | admin/dashboard_screen、portal_screen |
| `staggered_fade_in.dart` | 列表项交错入场（每项延迟 30ms，总时长 ≤490ms） | `index`、`child` | 预留装饰组件（无页面直连） |
| `section_header.dart` | 区块标题行 + 可选计数胶囊 + 尾随动作 | `title`、`count`、`action`、`level` | 全站 31 处区块标题 |
| `admin_breadcrumb.dart` | 管理页面包屑（URL 自动推导分组 → 模块 → 资源层级） | `trailing`、`overrideModule` | 全站 40 处详情/列表页 |
| `brand_logo.dart` | 品牌 logo（渐变圆角块 + 盾牌，可点开抽屉） | `onTap`、`size` | admin/dashboard_screen、portal_screen |
| `command_palette.dart` | 命令面板（Ctrl+K 搜索导航全部模块/详情/动作，纯前端） | `currentModule`、`allModules`、静态 `show` | admin/dashboard_screen |
| `command_palette_commands.dart` | 命令目录数据（`CommandPaletteItem` + 模块过滤/分组函数） | `title`、`path`、`icon`、`description` | command_palette（间接） |
| `shortcuts_dialog.dart` | 快捷键参考弹窗（按类别分组，Ctrl+? 触发） | 静态 `show(context)` | admin/dashboard_screen |
| `deferred_entry_screen.dart` | 代码分割入口占位（加载中 / 失败重试） | `load`、`build` | app_router |
| `capability_gate.dart` | 后端能力门控（`CapabilityGate` 路径前缀 / `MethodGate` 方法+路径） | `capabilities`、`path`、`child`、`fallback` | 预留（按能力裁剪 UI） |

## 输入/选择（4）

| 组件 | 职责一句话 | 关键参数 | 使用入口页面 |
|---|---|---|---|
| `form_validators.dart` | 表单校验函数集（required/hostname/url/email/minLength/alphanumeric）+ `ValidatedTextField` 标准校验输入框 | `controller`、`label`、`validator`、`obscureText` | 工具库（form_validators_test 锁定） |
| `language_selector.dart` | 语言下拉（DropdownMenu 风格，登录头/设置页共用，国旗图标） | `compact`、`enabled` | oidc_login_screen、settings_screen |
| `theme_selector.dart` | 主题模式下拉（system/light/dark，彩色图标，对比度安全） | `compact`、`enabled` | settings_theme_picker、oidc_login_screen |
| `select_style.dart` | 登录头下拉共享样式与几何工具（菜单卡片/选中高亮/宽度测量/箭头按钮） | `appHeaderMenuStyle`、`appDropdownEntryStyle`、`appHeaderDropdownWidth` 等 | language_selector、theme_selector（间接） |

## 使用规则

1. **组装优先**：新页面从上表选取组件组合，禁止复制粘贴私有实现。
2. **间距 token**：间距只用 {4, 8, 12, 16, 20, 24, 32, 40, 48, 64}（门禁守护）。
3. **颜色**：优先 `colorScheme` 派生；语义色走 `AppColors` 常量；组件内不出现
   硬编码 grey。
4. **i18n**：所有用户可见文案为 i18n 键（`context.tr` / `LocalizedText`），
   组件不新增未本地化文案。
5. **有限动画**：入场/反馈动画均有限时长（≤600ms），测试 settle 安全。
6. **行为不可改**：组件文档注释与本清单同步更新；改行为需专项测试锁定。
