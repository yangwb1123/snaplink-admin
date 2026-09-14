# Agent GPU 计算

Agent Operations 的设备目录和计算任务支持 NVIDIA CUDA 物理整卡需求。
Web 与原生 App/Mobile 使用同一套 Flutter 模型和界面。设备是否可执行、显卡选择、
任务授权与资源预留均由 Agent Hub/Fabric 决定；Console 展示 Hub 返回的事实并提交需求。

## 使用

1. 进入 `/agent/`，在计算设备页查看 GPU 状态、型号、UUID、可用/总显存和上报时间。
2. 选择实例会话，打开计算任务，填写直接执行的参数、相对工作目录和 CPU/内存要求。
3. GPU 数量默认 `0`。运行 GPU 任务时填写 `1..16` 张卡及每卡最低空闲显存（MiB）。
4. 提交后展开任务，查看申请数量、显存要求及 Hub 实际分配的显卡 UUID、分配时间和探测时间。

显存是选卡的最低空闲容量条件，不是运行时显存限额。物理整卡调度也不代表 GPU
设备已获得系统级强隔离。CUDA 驱动、设备接入和任务工作区需要由执行端配置。
本轮未引入 MIG、显存分片、AMD/Apple GPU 或原生平台打包流程。

## 数据契约

沿用 `/api/v1/agent/devices`、会话任务提交和任务详情接口及其现有权限。
CPU 请求保持原有 JSON，不新增零值 GPU 字段。

| 对象 | 字段 | 行为 |
|---|---|---|
| `resources` | `gpu_count` | 整数 `0..16`，缺省为 `0` |
| `resources` | `gpu_memory_bytes` | 每张卡的最低空闲显存，整数 `0..1 TiB`；数量为 `0` 时必须为 `0` |
| 设备 | `gpu_status` | `unsupported/unavailable/stale/available/busy`；旧响应缺失时显示“不可用或未上报” |
| 设备 | `gpus` | 每卡 `uuid/name/vendor/total_memory_bytes/available_memory_bytes/schedulable/reserved/observed_at`，旧响应为 `[]` |
| 任务 | `gpu_assignment` | `vendor: nvidia`、`mode: physical`、UUID 数组、每卡显存要求、`assigned_at/observed_at`；未分配和 CPU 任务可省略 |

时间字段使用 Unix 秒，支持有限小数。GPU 计数与容量拒绝小数、负值和字符串，
显卡清单最多 16 张，物理 UUID 必须是完整的 `GPU-xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx`
形式，十六进制大小写均支持，去重忽略大小写；总显存必须大于 0 且不超过 1 TiB。
清单拒绝无效预留标志和超过总量的可用显存。GPU 时间必须满足 `0 < t <= 1e12`，
探测时间不得晚于分配时间；先后关系按原始数值检查，避免毫秒截断掩盖非法顺序。
显存输入先检查 MiB 范围，
再转字节，避免大数转换绕过请求限制。数量或显存改变会改变请求指纹；相同请求在网络
结果不明确时继续复用原幂等键。

任务轮询带来新状态或 GPU 分配时，已展开的旧详情缓存会失效；较旧的详情响应不会
覆盖轮询所得的新快照。时间戳保留毫秒，避免同一秒内的分配更新被旧缓存遮蔽。

## 验证

本轮基线为 `3d019e10`。本地 SDK 为 Flutter `3.48.0-0.5.pre` / Dart
`3.12.0-168.0.dev`。SDK 自动解析时会调整 5 个 SDK 绑定依赖；提交保持原
`pubspec.lock` 不变，后续检查使用隔离 worktree 已解析依赖与 `--no-pub`。

基础实现 `2fcb130` 使用以下命令验证（日志保留在 `/tmp/hub-gpu-console-*.log`）：

| 验证 | 结果 |
|---|---|
| `flutter analyze --no-pub` | 通过，无问题 |
| `flutter test --no-pub` | 1,285 项通过 |
| `python3 -m unittest discover -s tests/unit -p 'test_*.py'` | 24 项通过 |
| 新 GPU、计算模型/界面及翻译定向测试 | 26 项通过；缓存刷新回归另 2 项通过 |
| Chrome GPU + 既有 7 组 browser 契约测试 | 58 项通过 |
| 4 文件 B6-1 Guard count pin | 83 项通过，精确计数 |
| Web release 构建、`make release-artifact-check` | 通过，Wasm dry run 同时通过 |
| `make k8s-render` | 通过，无 Kubernetes API 请求 |
| `python cli.py harness` | 基线未通过，2 项问题已在后续收尾关闭（见下） |

构建命令为 `flutter build web --release --base-href=/app/ --no-pub
--dart-define=SNAPLINK_ADMIN_OAUTH_RESOURCES=billing-api,stripe-adapter-api,audit-governance
--dart-define=SNAPLINK_AGENT_HUB_RESOURCE=agent-hub`。Chrome 命令使用
`flutter test --no-pub --platform chrome`，文件包含 `agent_gpu_models_test.dart`、
`agent_gpu_widget_test.dart`、`agent_compute_widget_test.dart`、
`agent_compute_refresh_test.dart` 和 Makefile
`test-browser` 中的 7 个文件。

缓存回归同时覆盖已缓存旧详情与迟到旧响应：将计算状态实现临时还原到基线时，两项
均无法显示新的 GPU UUID；恢复修复后通过。复现日志为
`/tmp/hub-gpu-console-refresh-before-fix.log`，最终 GPU 模型与缓存专项 7 项通过，
日志为 `/tmp/hub-gpu-console-refresh-tests.log`。

基线 harness 的 `agent_compute_models.dart`（508 行）已按设备/资源职责拆分至
397 行。初始 `agent_hub_api.dart`（433 行）超预算，invariant 也把两个测试中的
Python 输出示例计作“生产 print”。当时的真实失败记录保留在
`/tmp/hub-gpu-console-baseline-harness.log` 和
`/tmp/hub-gpu-console-final-harness.log`；后续收尾按下面的记录关闭了两项问题。
初始隔离 worktree 没有构建产物时的产物门失败，也已在 Web release 构建后复验通过。

随后对齐服务器 GPU DTO 边界，仅修改读取校验与回归：`flutter analyze --no-pub`
通过；GPU、计算模型/界面、缓存刷新与翻译 6 文件共 **32 项**通过；Chrome GPU
模型/界面 **16 项**通过。日志分别为 `/tmp/hub-gpu-console-dto-analyze.log`、
`/tmp/hub-gpu-console-dto-tests.log`、`/tmp/hub-gpu-console-dto-browser-tests.log`。
该补丁没有重复未受影响的全量、产物、Python 和 Kubernetes 门禁，未修改依赖锁文件。

最后收尾基于 `932df7dc`：沿用仓库既有 `part` 模式，把响应封装、分页和安全错误
解析提取到 `agent_hub_api_response.dart`（78 行），API 主文件降至 359 行；两个
测试的输出示例换为等价 `sys.stdout.write`，保留换行、参数边界、请求体及 evidence
断言。未修改检查器、全局阈值或依赖锁文件。受影响 API/OAuth/模型/界面 8 文件
**41 项**通过，Chrome API/模型 **19 项**通过，analyze 通过；重新构建 Web 后，
`make release-artifact-check` 和 **完整 harness 均通过**，含文件预算、复杂度、架构、
目录、根目录、12 项 invariants 和 25 项产物检查。日志为
`/tmp/hub-gpu-console-gates-{analyze,tests,browser-tests,build,artifact,harness}.log`。
最终 Web 产物保留在隔离 worktree 的 `build/web`，未在本轮自行同步主目录。

测试使用本地 HTTP mock，不调用已部署 Hub、真实 GPU、CUDA 内核或外部账号。320px 的英中文组件测试覆盖设备、资源表单和展开任务，
本轮未完成 Android/iOS/macOS/Windows 原生包构建或真机 GPU 验证。
