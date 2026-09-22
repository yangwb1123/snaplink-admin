# Agent 会话请求记录验证

日期：2026-09-15。隔离基线为
`000677f3ea14da87c17b9c16f99867489adc582a`，包含用户本轮新的 Forge 修改。
增量只涉及 Agent API/共享 Flutter UI/i18n、测试及本文档，不修改 Forge、原生平台、
`pubspec.yaml` 或 `pubspec.lock`。主工作区未由本实现代理写入或合并。
最终提交、实际 argv、cwd、退出码、日志及 SHA-256 见
`/tmp/hub-session-history-20260915/console-validation.json`。

## 行为证据

新增 API/controller/widget 共 61 项，在 VM 和 Chrome 平台执行：

- 单次只读 GET、默认 20 条/最大 50 条、256 KiB 响应限制、精确信封和九字段 DTO。
  校验操作/状态/错误码、空/超长/重复游标、重复请求、实例绑定及有限非负时间戳。
- 标识符按 Hub 的首尾无空白、256 Unicode 字符、C0/DEL 边界校验，允许有效 C1。
  创建名称独立遵循 UTF-8 字节数及 Cc/Cf 规则；拒绝额外私有字段。
- 创建和关闭详情均使用既有 GET 路由，并绑定不可变请求/实例/名称或目标。
  较晚详情不能覆盖已改选记录；已关闭控制器不接纳迟到页。
- 离线、零会话实例仍有记录入口；最新/更早分页只保留当前页，失败重试保留原游标。
  新记录不自动打开会话；打开操作核对会话和实例。
- 关闭弹窗后迟到 Open 不导航、不覆盖改选的会话；新凭据阻止旧响应继续使用。
  迟到列表/详情在身份变化后清空旧账号页，后续点击不再用旧 API 请求。
- 迟到 401 不清除后来保存的默认及分客户端凭据。所有错误文案不渲染原始响应。
- 浏览记录不替换本地未知创建/关闭请求，二者重试仍使用原目标、内容和 key。
- 404/405/501 清晰提示旧 Hub 不支持；403 提示权限不足；空、等待和失败状态可辨。
- 320px 中英文弹窗/详情无布局溢出；列表使用懒构建并通过既有 P1 门禁。

## 工程门禁

本轮新基线和增量均用 `flutter pub get --enforce-lockfile` 检查当前 SDK 兼容性。
实际工具链 Flutter `3.48.0-0.5.pre`（framework `2d06a6e304`）、Dart
`3.12.0-168.0.dev`。仓库 CI 固定 Flutter `3.47.4`；本文只声明上述实际 SDK 的结果。

| 检查 | 结果 |
| --- | --- |
| 新基线完整 VM suite | 1441 通过，3 跳过，1 失败（下述 Forge 测试） |
| 最终完整 VM suite | 1502 通过，3 跳过，同一条 Forge 失败 |
| Agent 创建/关闭/请求记录/API/Operations + P1 目标回归 | 120 通过 |
| 最终 `flutter analyze --no-pub` | 无问题，退出 0 |
| 既有 `make test-browser` | 60 通过 |
| 新增请求记录 Chrome suite | 61 通过 |
| Python unit suite | 24 通过 |
| `make guard-count-pin` | 精确 83 通过 |
| Web release build、`make release-artifact-check` | 通过 |
| `make k8s-render` | minimal/full 渲染通过 |
| 仓库 harness | 仅下述两项既有 Forge 文件大小违规；复杂度、架构、目录、根策略、安全及产物检查通过 |

## 本轮独立复现的基线问题

`test/forge_sessions_widget_test.dart` 的
`keeps the conversation page cursor after load more fails` 在独立基线全量和单例命令
均失败：`StateError: No element`，`ensureVisible` 位于第 322 行。
增量全量失败的路径、名称和异常一致，相关 Forge 源码和测试均未修改。

独立基线 `python3 cli.py check-filesize` 只有两处超出 400 行门限：
`lib/api/forge_conversations_models.dart` 为 948 行，
`lib/screens/forge/forge_sessions_screen.dart` 为 937 行。
本轮 Forge API 已不超限，不能沿用上一轮三处超限的结论。

全部中间失败及修复后的复验日志保留在隔离证据目录；全量 VM 和全局 harness
均不声称全绿，不沿用前一轮的失败豁免。

## 边界

测试使用 MockClient，并在真实 Chrome 平台运行共享代码，不等同于 live Hub 的
跨租户认证、持久化或新设备端到端验收。未执行原生打包、设备安装、线上部署或
运行时 provider 操作。请求记录只恢复已被 Hub 受理的业务记录；本地从未确认的
输入仍遵循原有内存恢复边界。

## 当前共享工作树复验（2026-09-16）

上述隔离验证保留了当时的基线和失败证据。共享工作树随后修复了
`forge_sessions_widget_test.dart` 中的分页滚动查找，并补上了首屏确定性错误清理、
change-feed 鉴权竞态和分页版本合并保护，然后重新执行：

- `flutter test --no-pub`：1509 通过，3 跳过；
- `flutter analyze --no-pub`：无问题。

因此，隔离记录中的“最终 1502 通过、同一条 Forge 失败”只描述当时的临时工作树，
不代表当前实现的结果。当前复验仍是 Mock/本地测试，不替代真实 Hub、浏览器部署或
物理设备验证。
