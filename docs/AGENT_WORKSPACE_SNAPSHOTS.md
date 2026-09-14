# Agent 工作区快照与计算输出

Console 的 Agent Operations → 会话 → Compute tasks 可启用工作区快照。
可选择此会话已有的就绪快照，也可粘贴 JSON 上传；Web 与支持文件通道的原生宿主
提供 JSON 文件选择。
选择快照后，任务在快照根目录 `.` 运行，目标设备仅提供
`workspace_supported: true` 的在线可调度设备。该能力缺省为 false，旧设备响应仍可
用于原有计算任务。未启用快照时不增加 `workspace` 请求字段。

输出路径每行一个明确的相对文件名，允许为空，最多 128 个。任务详情显示输入基线
SHA-256、输出 SHA-256 和产物状态；只有 `ready` 状态才提供获取操作。
下载先验证服务器返回的输入摘要与任务基线一致，再验证输出摘要、任务输出摘要和
返回文件包的 canonical SHA-256 全部一致。验证成功后 Web 下载 JSON 文件；
App/Mobile/桌面原生端在宿主声明能力后提供系统保存对话框，收到成功回执才显示
已保存；取消会单独提示。JSON 查看和复制仍可使用，缺少宿主支持时保持文本操作。
保存对象是 JSON 文件包，不会自动把包内文件覆盖到本地项目。原生实现和本轮验证
范围见 [原生文件操作](AGENT_NATIVE_WORKSPACE_FILES.md)。

## JSON 文件包与边界

```json
{"schema":"pbatch.workspace.v1","files":[{"path":"a.txt","content_b64":"YQ=="}]}
```

文件最多 128 个，每个解码后最多 64 KiB，全部解码后最多 256 KiB；JSON 最多
512 KiB，上传 HTTP 包装最多 576 KiB。计算任务最终 JSON 还受 64 KiB 总上限约束，
各字段上限与总请求上限同时生效。内容必须为规范的标准 base64，包括正确填充。
Canonical JSON 按文件路径的 Unicode code point 排序，所有对象键排序、无额外空格、
UTF-8 编码。摘要和 metadata.size 对应整个 canonical bundle。

客户端校验相对 POSIX 路径、512 字节路径和 255 字节单段上限、有效 Unicode、
控制字符、空/`.`/`..` 段、反斜杠、Windows 禁用字符和保留名、结尾点/空格、重复路径
及文件/父目录冲突。`[]` 是字面文件名，不展开 glob。服务端仍是 NFC 与完整
Unicode casefold 校验的权威；Dart SDK 没有这两种规范化工具，本轮不增加依赖。
客户端不擅自规范化文件名，服务端拒绝会显示为上传失败。

跨语言样例：`a.txt=YQ==` 与 `z/é.txt=AAE=` 对应 SHA-256
`a388cd8e87940f10987df742843a470dfbdb1b3735fd30e377d2b4b6cf174202`。
另有 BMP 私用字符和非 BMP 文件名回归，防止 Dart 的 UTF-16 默认排序与 Python
code point 排序产生摘要分歧。

## API 与状态

| 操作 | 接口 | 权限 |
|---|---|---|
| 列表 | `GET /api/v1/agent/sessions/{session_id}/snapshots`，after/limit 分页 | `agent.tasks:read` |
| 上传 | `POST /api/v1/agent/sessions/{session_id}/snapshots`，`{bundle: ...}` 与 Idempotency-Key | `agent.tasks:write` |
| 绑定 | 原 task POST 的可选 `workspace: {snapshot_id, outputs}` | `agent.tasks:write` |
| 获取输出 | `GET /api/v1/agent/tasks/{task_id}/workspace` | `agent.tasks:read` |

所有操作复用 Agent Hub bearer 头、超时、拒绝重定向与有界响应读取；仍受源会话、
实例和项目授权约束。没有新增 scope。上传响应还验证会话绑定、摘要、大小和文件数；
界面再次确认实例和项目。未确认上传按 session + canonical digest 保留有界请求键，
相同内容重试复用同一个键。上传新内容时先清除旧快照选择，防止误提交旧输入。
切换会话、模式、API 或任务产物版本后，迟到的读取/上传/下载不会覆盖当前选择。

workspace_result 的 `pending / ready / failed / unavailable` 与 execution-evidence
的 Vault archive 单独显示。列表轮询即使 task.state 和 updated_at 未变，也会按
工作区结果状态/摘要使旧详情缓存失效。`workspace.ready` 会话事件保留既有未知事件
兼容行为，不改变轮次状态，也不展示文件正文。

## 上一阶段验证记录（Vault 工作区快照）

以下记录保留快照阶段的实际验收范围；本次原生文件操作的新增验证单独记录。

开发基线：`5f2bf03796aab825b294a9196b35db1c928e1db1`，独立 worktree
`/home/u1/.cache/pbatch-worktrees/hub-workspace-console`。没有修改主目录或依赖锁文件。
本机 Flutter `3.48.0-0.5.pre` / Dart `3.12.0-168.0.dev` 在初次解析时调整了 5 个
SDK 绑定版本；已恢复原始 pubspec.lock，后续所有 Flutter 命令使用 `--no-pub`。

| 验证 | 结果 |
|---|---|
| `flutter analyze --no-pub` | 通过，无问题 |
| `flutter test --no-pub` | 1,315 项通过 |
| Chrome 工作区模型/API/文件选择 + 既有 7 文件 browser 契约 | 60 项通过 |
| 4 文件 B6-1 guard suite 与精确 count pin | 83 项通过，精确计数 |
| `python3 -m unittest discover -s tests/unit -p 'test_*.py'` | 24 项通过 |
| `make k8s-render` | 通过，无 Kubernetes API 请求 |
| Web release、artifact check、完整 harness | 全部通过，Wasm dry run 同时通过 |

初次全量运行有 1,311 项通过、3 项审计扫描失败：高代理项上界字面量中恰好包含
受限模块名子串。将等价区间改为 `< 0xdc00` 后重跑全量与 guard suite 全部通过；
未修改门禁、阈值或豁免。首次真实失败保留在
`/tmp/hub-workspace-console-initial-all-tests.log`。

日志统一保留为 `/tmp/hub-workspace-console-*.log`：最终静态分析 `analyze`、VM
`all-tests`、Chrome `browser-tests`、guard `guard-tests` / `guard-pin`、Python
`python-tests`、Kubernetes `k8s-render`、构建 `build`、产物 `artifact`、工程门禁 `harness`。
构建命令为 `flutter build web --release --base-href=/app/ --no-pub
--dart-define=SNAPLINK_ADMIN_OAUTH_RESOURCES=billing-api,stripe-adapter-api,audit-governance
--dart-define=SNAPLINK_AGENT_HUB_RESOURCE=agent-hub`。所有新增/修改生产文件均在
400 行预算内，API transport 为 367 行，operations view 为 385 行。
完整 harness 包括 12 项 invariants 和 25 项产物检查。Web 产物留在隔离 worktree
的 `build/web`，交由根代理比对补丁与主目录后同步。
测试使用本地 HTTP mock 和 Chrome DOM，未调用真实 Hub/Vault 或部署服务。
本轮不构建 Android/iOS/桌面原生安装包；原生交互通过 Flutter widget 与平台通道 mock
覆盖，不代表已完成真机验证。
