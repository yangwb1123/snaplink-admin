# Agent 会话关闭验证

验证日期：2026-09-15。隔离基线为 `d2c98b03769116a8e8d6143a70a44ee72dcb3e1c`。
本次只增加 Agent API、共享 Flutter 页面、文案和回归测试，不包含主工作区随后
发生的并行 Forge/native 修改。最终提交、完整 argv、退出码和日志路径记录在
`/tmp/hub-session-close-20260915/console-validation.json`。

## 已验证的行为

- 明确确认目标；取消不发送请求；实例关闭能力默认不支持，独立于创建容量。
- DTO 严格核对字段、状态/固定错误码、有限时间戳、32 KiB 响应上限和请求身份。
  ID 使用既有 Hub 的 256 字符及 C0/DEL 边界，与名称 UTF-8 字节限制区分。
- 未知 POST 及后续 403 保留原目标、空 body 和 key，不自动重发；受理后只 GET。
- 当前活动 turn、计算任务和未确认的新工作阻止 UI 关闭，服务端仍负责最终准入。
- 已受理或结果未知的目标禁用新工作；成功、失败、丢失均保留历史，不提供重开。
- 迟到结果不切换所选会话或清空消息；迟到 401 保留后来保存的默认及分 client 凭据。
- 共享页面的中英文 320px 确认框不溢出。VM 和 Chrome 各执行新增 23 项测试。

## 工程验证

使用当前 Flutter `3.48.0-0.5.pre`（framework `2d06a6e304`，engine `460e8e85b1945c78f9430c7f3a6d3756474d0230`），
Dart `3.12.0-168.0.dev`。`flutter pub get --enforce-lockfile` 通过；本增量未修改
`pubspec.yaml` 或 `pubspec.lock`，不沿用上一轮不同基线的 SDK 失败结论。

| 检查 | 结果 |
| --- | --- |
| 新基线全量 `flutter test --no-pub -r expanded` | 1412 通过，3 跳过，0 失败 |
| 增量全量同命令 | 1435 通过，3 跳过，0 失败 |
| 关闭/创建/API/Operations 目标回归 | 53 通过 |
| `flutter analyze --no-pub` | 通过，无问题 |
| `make test-browser` | 60 通过 |
| 新关闭 API/controller/widget Chrome 回归 | 23 通过 |
| Python unit suite | 24 通过 |
| `make guard-count-pin` | 精确 83 通过 |
| Web release build，`--base-href=/app/` 与既有 OAuth resource 配置 | 通过 |
| `make release-artifact-check` | 通过 |
| `make k8s-render` | minimal/full 渲染通过 |
| `python3 cli.py harness` | 退出 1，仅以下三处既有文件大小违规；其他检查通过 |

新基线独立工作树执行 `python3 cli.py check-filesize`，复现完全相同的三处违规：
`lib/api/forge_conversations_api.dart` 454 行、`lib/api/forge_conversations_models.dart`
948 行、`lib/screens/forge/forge_sessions_screen.dart` 935 行，门限均为 400。
本次未修改这些文件。上一轮 Forge route 测试失败在本基线已消失，不能当成本轮豁免。

## 验证边界

HTTP、状态控制器与页面测试使用 MockClient，在 VM 和真实 Chrome 平台执行，
不等同于 live Hub/Gateway 身份认证、运行时关闭或容量释放的端到端证明。
未执行原生应用打包、设备安装、线上部署或实机 provider 关闭。本地恢复状态仅
在当前 Agent Operations 页面生命周期内保留，离页、刷新及重新登录后不保留。
所有中间失败和修复后复验记录留在独立日志中；不将全局 harness 报成全绿。
