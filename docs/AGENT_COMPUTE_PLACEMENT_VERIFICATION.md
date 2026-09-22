# 计算任务调度诊断验收记录（2026-09-16）

功能及边界见 [使用说明](AGENT_COMPUTE_PLACEMENT.md)。本次仅修改 Agent API、
共享 Flutter 界面、对应翻译、测试和文档；没有修改 Forge、原生平台或依赖文件。

## 来源与环境

- 隔离基线：`454fb56c9728ba6a9055de1e1586aff63fe525a7`。
- 核心完整回归来源：`493a031a3a238529dd17c3c4637153c1c233569a`。
- 最终代码验证来源：`808b6e6d10c742e4d2cd111e642502998d42c9c7`。
- 核心回归后补充可读本地观察时间、日期超范围提示，以及进入页面时固定身份快照，
  防止打开弹窗前已经换号或退出时使用旧 token。另补 5 个回归测试，并修正浏览器
  测试卸载后的异步响应清理。最终来源复验新增套件、相关旧测试、分析和 Web 构建。
- Flutter 实际为 `3.48.0-0.5.pre`，framework
  `2d06a6e304257f09894d62d7f5adb3b306b71834`，engine content
  `460e8e85b1945c78f9430c7f3a6d3756474d0230`，Dart
  `3.12.0-168.0.dev`；使用 `/home/u1/workspace/source/flutter`。
- CI 声明的 Flutter `3.47.4` 未在本机运行，不声称验证了该版本。
- `flutter pub get --enforce-lockfile` 通过，`pubspec.yaml` 和 `pubspec.lock`
  与基线逐字节一致；锁文件 SHA-256 为
  `30a3b499687d1dd9188b5e77bf78d140a7600160259fcc755916171e5dad8ce3`。

## 检查结果

日志及逐命令 argv、cwd、退出码、来源提交、日志 SHA-256 位于
`/tmp/hub-placement-20260916-uct6alx4/console-validation.json`；日志同目录保存。
表内“最终”均指上述最终代码来源；本验收文档在代码检查后添加。

| 检查 | 来源 | 结果 |
|---|---|---|
| `flutter test -r expanded` 全仓 VM | 核心 | 1568 passed，3 skipped，无失败 |
| `agent_placement_{test,state_test,widget_test}.dart` VM | 最终 | 69 passed |
| 同一新增套件 `--platform chrome` | 最终 | 69 passed，真实 Chrome |
| 旧 Hub API、计算/GPU、会话创建/关闭/请求历史相关 8 文件 VM | 最终 | 59 passed |
| `flutter analyze` | 最终 | 退出 0，无问题 |
| `make build-prod` | 最终 | 退出 0，release Web `/app/` 构建成功 |
| `make release-artifact-check` | 最终 | 退出 0 |
| `python3 cli.py harness` | 最终 | 退出 1，仅下列两处既有文件超长；其他门禁通过 |
| Python 单测 | `b280a56` | 24 passed |
| `make guard-count-pin` | `b280a56` | 精确 83 passed |
| `make test-browser` 既有浏览器套件 | `b280a56` | 60 passed |
| `make k8s-render` | `b280a56` | minimal / full 均成功，仅渲染 |
| 工作区、暂存区及最终提交差异检查 | 最终文档提交 | `git diff --check` 均通过 |

本次完整 VM 运行已没有前轮记录的 Forge 分页组件失败。全仓检查仍有两处既有
文件超长，已在独立基线工作树运行 `python3 cli.py check-filesize` 复现：

- `lib/api/forge_conversations_models.dart`：948 行，上限 400。
- `lib/screens/forge/forge_sessions_screen.dart`：937 行，上限 400。

以上两文件与基线逐字节一致，证据在 `console-baseline-proof.json` 和
`console-baseline-filesize.log`。没有增加豁免或改动无关代码使门禁变绿。
最终 harness 的安全不变量 12 项和产物门禁 25 项均通过。

## 覆盖与限制

新增套件验证精确字段、重复 JSON 键、任务/游标绑定、Unicode 码点排序、合法
标识符、固定状态/原因、大小上限（有声明长度及流式响应）、非法 UTF-8、403 / 401
清空当前页、旧版 Hub 提示、显式分页、忙碌互斥，以及迟到响应、换号、退出、
重新选择会话、关闭弹窗的隔离。真实组件入口只发 GET；英文和中文 320 px 页面
无溢出，日期过大仍保留原始合法 DTO 并显示可理解的提示。

完整 VM 使用核心代码来源；之后的有限增量由最终 69 项 VM / Chrome 和 59 项旧
回归验证，不把未重跑的完整套件归到最终来源。首轮 Chrome 的测试清理计时器失败
保留为开发记录，由修复后的真实 Chrome 69 项通过结果取代。

HTTP 为可控响应 fixture，Chrome 为实际浏览器运行；没有把这些检查称为真实 Hub、
真实多设备或真实 OAuth 联调。Web 产物保留在隔离工作树 `console/build/web`，
未部署；未构建或安装 Android、iOS、桌面原生包，未执行依赖在线后端的集成套件。
