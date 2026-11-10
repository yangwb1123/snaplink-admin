# sso-console 集成测试

用户实际 A/B 的入口、现有注册/callback/tenant/策略、专用凭据访问及认证许可仍缺失，
**实际 A→B：`not_run`**。先按[双应用接入清单](../../docs/BROWSER_SSO.md#双应用接入清单)
核实；下述临时 RP、管理测试默认值及已知 `sso-admin-console` 均不补齐这些输入。
此前 target-helper 独立审查被拒绝、未批准，普通功能证据不解除其阻塞。

**入口结论：**generic RP 跟随 advertised `authorization_endpoint`（`/auth/login`），
未选 provider 时看到 HTTP 200 provider JSON，没有登录 UI；已有 OP Cookie 也不会自动
进入授权。password-once A→B 来自显式配置的托管 `/login/` 入口，不是 discovery 自动
handoff；实际托管 origin/完整入口仍须所有者确认，不从 fixture 拼接生产 URL。

**English — entry contract.** A generic discovery RP follows the advertised endpoint unchanged
and, with no provider selected, receives provider JSON rather than a login UI, with or without an
OP session. Only the explicitly owner-configured hosted `/login/` integration proves password-once
A→B in these disposable fixtures. It does not establish the actual applications' entry or acceptance.

## 测试环境要求

本节仅适用于既有部署集成脚本，不是离线诊断或后述自建 stock fixture 的要求：

- 专用 Snaplink 测试后端；默认地址为 `http://localhost:8080`
- 已构建的控制台与同源代理；默认地址为 `http://localhost:4444`
- 具有 `admin:read`、`admin:write` 的专用测试账户

这些脚本从环境变量读取配置，不包含默认登录凭据；独立离线诊断与 stock SSO fixture
不读取这些账号变量，不能把本节作为实际 A/B 登录授权：

| 变量 | 必需 | 默认值 | 用途 |
|---|---|---|---|
| `SNAPLINK_API_URL` | 否 | `http://localhost:8080` | 后端绝对地址 |
| `SNAPLINK_PROXY_URL` | 否 | `http://localhost:4444` | 控制台/代理绝对地址 |
| `SNAPLINK_TEST_USERNAME` | 认证测试必需 | 无 | 测试账户 |
| `SNAPLINK_TEST_PASSWORD` | 认证测试必需 | 无 | 测试账户密码 |
| `SNAPLINK_TEST_CLIENT_ID` | 否 | `sso-admin-console` | 登录使用的客户端 |
| `SNAPLINK_TEST_USER_ID` | 否 | 与用户名相同 | 测试账户的后端资源 ID |
| `SNAPLINK_MANAGE_PROXY` | 否 | 本地地址为 `true` | 是否由脚本启动/停止本地代理 |

## 运行测试

```bash
export SNAPLINK_TEST_USERNAME='test-admin'
export SNAPLINK_TEST_PASSWORD='从测试环境的密钥存储读取'

# 本地后端和代理
python3 tests/integration/run_all.py

# 已部署的专用测试环境；脚本不会管理远端代理进程
SNAPLINK_API_URL='https://api.test.example' \
SNAPLINK_PROXY_URL='https://console.test.example' \
SNAPLINK_MANAGE_PROXY=false \
python3 tests/integration/full_integration_test.py
```

## 隔离的跨应用浏览器 SSO（不使用上述部署或凭据）

现有 `browser_sso_fixture.py` / `browser_sso_test.py` / `browser_sso_rp.py` 构建 stock OP，
用全新临时用户、SQLite、证书及两个不同 loopback 主机（127.0.0.2/127.0.0.3）的 RP
驱动 release Flutter 密码/consent UI。默认串行验证 Python 代理和 Nginx 双网关；需要
已有 Go、OpenSSL、Playwright/Chrome、release CanvasKit 和 Linux Docker。Nginx 使用
host network；`live-replicas` 另需本机 daemon 缓存的 `redis:7-alpine`，只发布 loopback
端口。两个新 case 的 supervisor 需要 Linux pidfd/subreaper；不支持则失败。缺依赖/
源码/产物或不支持配置均失败，不静默 skip，不拉取镜像/升级工具；只清理自有资源，
端口冲突失败、不杀占用者，不接触生产账号/库/密钥或全局 TLS/proxy。

字体检查按构建 SDK 的真实产物执行：CI 固定的 Flutter 3.47.4 在
`--no-web-resources-cdn` 下将 SDK Roboto TTF 写入 `FontManifest.json`，检查其本地
产物与 SDK 原文件逐字节一致，并校验实际浏览器响应的格式和 SHA-256；没有该声明的
SDK 仍须使用其原始 URL 对应的已固定 WOFF2。中文 Noto WOFF2、零外网请求、零匿名
认证断言不变，不额外请求一个页面未使用的字体来满足测试。

构建及完整双网关复现入口如下（使用已准备的 Python 3.12.3 环境，不升级依赖）：

```bash
export PATH="/home/u1/.cache/console-browser-acceptance/py312/bin:$PATH"
make build-prod
make test-browser-sso 'BROWSER_SSO_ARGS=--browser-channel chrome --backend-repo /home/u1/.cache/console-browser-acceptance/target-recovery/backend-source'
```

**现有 Makefile wiring（无需新增目标）：**

| Make 目标 | 实际 recipe / 默认选择 |
|---|---|
| `test-browser-sso` | `python3 tests/integration/browser_sso_test.py $(BROWSER_SSO_ARGS)`；默认 `--case all --gateway both`，包含两个新 case |
| `test-app-sso-browser` | `python3 tests/integration/browser_sso_test.py --case normal $(APP_SSO_ARGS)`；默认只选四个正常补充例，不含两个新 case 或 baseline |
| `test-app-sso` | `python3 -m unittest discover -s tests/unit -p 'test_app_sso*.py' -v`；离线诊断/fixture 单测，不启动 OP/Chrome |

单独复现新例使用 `test-browser-sso` 的 `BROWSER_SSO_ARGS` 传 `--case rp-entry` 或
`--case live-replicas`，命令见下节；没有同名专用 Make 目标。SIGTERM 脚本需显式运行，
不在默认 `test-browser-sso` 内。构建、网关和 case 均串行，不能并行跑多个 writer。

**English — wiring.** Both new cases are included by default in `make test-browser-sso`.
Pass `--case rp-entry` or `--case live-replicas` via `BROWSER_SSO_ARGS`; complete commands follow.
`test-app-sso-browser` defaults to `normal`, not the new cases; the real-Chrome SIGTERM regression
is a separate opt-in command.

该冻结后端输入只读；不要整理相邻仓库或缓存源码。CLI 默认 backend 是 `../snaplink`、
Web 是 `build/web`，实际证据显式指定了上述冻结输入。`--web-build` 可指定已有产物；
`--gateway python` / `nginx` 单路径不能替代默认双路径证据。浏览器经 `/login/` 托管页
恢复 canonical OP 身份，各 RP 在服务端完成自己的 code/S256 exchange、JWKS
签名/issuer/audience/nonce 与 `/userinfo` 校验；不把 Token 放进页面或跨 RP 搬用。
普通 fixture 不证明 discovery 已为实际应用接好 UI handoff；新增 `rp-entry` 明确复现
advertised endpoint 的 JSON/no-UI 阻塞，见下节，不能将其 PASS 当作 generic RP 登录成功。

默认 `--case all` 每网关运行以下七例；`--case normal` 仍只选四个 consent/持久化补充例，
不含 `baseline` / `rp-entry` / `live-replicas`。策略只设置在本次
新建临时客户端，不更改实际注册或 consent/tenant/风险/强制认证边界：

| `--case` | 首次 consent | 正常流程证据 | 每网关完成的 grant |
|---|---|---|---:|
| `baseline` | A skip / B required | A 密码一次→B 恢复+独立 consent；保留原闭环 | 2 |
| `inverse` | A required / B skip | A 密码+consent；B 免密码；A/B repeat 记忆 consent | 4 |
| `both-required` | A/B required | 各自首次 consent/repeat；独立 jar 的 B 另输密码，但记忆该用户/客户端 consent | 5 |
| `both-skipped` | A/B skip | 无 consent continuation；初次/repeat grant 仍独立 | 4 |
| `shared-store` | A/B required | A 后停自有 OP，第二 stock 进程共享临时 SQLite/key/origin；B 恢复及 A/B repeat | 4 |
| `rp-entry` | A/B required | generic discovery 新/已认证 jar 均停在 JSON；另用显式托管入口完成 A/B | 2 |
| `live-replicas` | A/B required | R1/R2 并发、共享 Redis/key；A 在 R1，B/repeat 在 R2，双向 Token/JWKS 校验 | 4 |

最初 Cookie 与同 jar access/ID-token `auth_time` **严格一致，无时间容差**；补充四例
及 `live-replicas` 还要求 B/repeat 签发秒晚于原认证秒。每请求独立 S256/state/nonce、code、Token/SID，
保留各 RP 的 scope/resource；AMR/ACR 不变，Cookie 不滚动，旧 grant 仍过真实 `/userinfo`。
独立 jar 完成的 B 登录
有自己的新 Cookie/SID/认证时刻，不改变原 jar。Cookie 只在内存断言，不注入或输出。
原闭环仍验证 Cookie 属性、强制认证/选账号/max_age 下只呈现表单且不自动 resume、
隔离 jar、合法登出、独立服务双向 Cookie 隔离、EN/ZH 本地字体及公开预检。
不导出/留存 HAR、trace、截图或 storage-state；临时 Chrome profile/artifacts 放在
owned 目录并随清理删除。只输出固定状态/计数，不输出授权秘密/原始异常。

```bash
# 只运行补充四例；单例请用 test-browser-sso 的 BROWSER_SSO_ARGS 传 --case：
make test-app-sso-browser APP_SSO_ARGS='--browser-channel chrome --backend-repo /home/u1/.cache/console-browser-acceptance/target-recovery/backend-source'
python3 -m unittest discover -s tests/unit -p 'test_app_sso*fixture*.py' -v
```

共享用例仅用发布的 `identity.session_backend: sqlite`、`oauth.backend: sqlite`、
`self_service.consent.backend: sqlite`/各 `.sqlite.dsn` 与 `keys.signing.key_file`，只由 stock
写全新临时存储/密钥，不直接写 SQL 或改后端。两个进程**先停后启**、无在途写重放，
须以 B 实际 UI resume、独立 consent/code/token、repeat 和 A 原 grant `/userinfo`
通过为证据，不能只看就绪/JWKS。仅证明本机持久化恢复，不是并发副本、轮换、HA 或目标 failover。

最近已审阅的完整 wrapper 日志（2026-10-18 UTC，**本次文档修改前**）为 **14 个
用例/网关组合、50 次 code grant、0 browser skip**，已包含 `rp-entry` 与 `live-replicas`，
不要再叠加 focused 结果。全量 Python **261 tests，OK**；Flutter VM **2,274 passed /
172 skipped**，skips 不算已验证行为。仓库五门禁及 harness、Python、stock Chrome
共 8/8 退出 0；本次文档修改后的完整 wrapper 由 stage command 另行串行执行，本任务
不运行或预报其结果。日志出处、历史边界与现有工具链 pin 漂移见
[执行记录](../../docs/BROWSER_SSO.md#最近已审阅的执行记录文档修改前)。
**真实 App A→B 仍 `not_run`；native/WebView、HA、目标 failover/rotation 仍
`not_verified`；旧 helper 独立审查仍未批准。**

### 标准 RP entry 复现（不修改产品入口）

```sh
export PATH="/home/u1/.cache/console-browser-acceptance/py312/bin:$PATH"
python3 -m unittest discover -s tests/unit -p 'test_app_sso*fixture*.py' -v
make test-browser-sso 'BROWSER_SSO_ARGS=--browser-channel chrome --backend-repo /home/u1/.cache/console-browser-acceptance/target-recovery/backend-source --case rp-entry'
```

`app_sso_entry.py::run_entry_case` / `app_sso_entry_fixture.py::EntryRP` 的
`/start-discovery` 读取真实 metadata，仅接受 owned HTTPS origin 上原样的 `/auth/login`，
不修正/替换 endpoint，不跟随错误 origin。Chrome 真正以 HTML-capable document 导航，
未选 provider 的完整 code/S256 请求在新 jar 返回 provider JSON；托管 A 登录后 B 的
同类新请求仍是 JSON，只是 `op_session_available` 变为 true。均没有 UI/callback/grant/
认证 POST，未完成的 RP state 在本地丢弃一次、从不改为另一条授权请求重放。
显式 `/start` → `/login/` 是独立的新请求：A 密码一次，A/B 各自首次 consent，B 恢复
自己的 code/S256 grant、scope/resource/Token/SID，保留精确原始 `auth_time` 和 Cookie。

先记录原网关结果（Python 的 scheme 为 http；Nginx 丢失非默认端口），不导航该 origin。
再由 `IdentityIngress` **仅在 fixture 内**转发已知 owned TLS scheme/完整 authority；
stock 的 discovery 正文不改，真实 advertised endpoint 必须精确匹配。原 issuer 正确及
预检成功不能替代此检查；此 plumbing 不修复/部署原网关，不证明任意公网 origin。
client-only JSON discovery 在 direct/raw/canonical 三处逐字节比较；HTML Accept 后端
控制、no-store/no-cache/no Location/no Set-Cookie 和原 preflight 工具均检查。

每网关最多一个 OP 进程、一个 Chrome 实例、两个 RP、一个有界 identity ingress 和原独立 sink；
Nginx 仅用缓存 image ID，新容器带唯一 owner label、128 MiB/1 CPU/64 PIDs、只读根、
有界 tmpfs、无日志/重启。十分钟 case 上限及独立 supervisor 的 SIGTERM/deadline
清理见下节；不向 sync Playwright 抛 signal exception。无代理环境继承或 HTTP 自动跳转/写重试；
连接/响应/worker 有界。按 exact name/label/ID 清理并确认移除；
创建/移除超时先核对、从不重放激活，未知清理或外来 owner 冲突均失败。
只有进程、worker/listener、容器和临时文件清理验证后才输出该 case 的 PASS。

该用例已在文档修改前完整 wrapper 中通过：**2 个网关组合、4 次托管 code grant、
0 skip**，generic 两种 jar 状态每网关各一次；不是 actual-app A→B，也不是 generic RP
授权成功。中间 Docker 超时（已精确核对移除）与一次未归因的 UI timeout 保留在批次
evidence，不因后续通过抹去。本节不声称文档修改后已重跑门禁。入口源证据、后端
backlog 与操作员待办见
[标准 RP 授权入口](../../docs/BROWSER_SSO.md#标准-rp-授权入口已复现的契约阻塞)。
此 entry 用例本身无生产认证/部署变更、并发副本、轮换、HA、native/WebView
或旧 helper 审查批准证据；独立的本机并发用例见下节。

### 本机 live-replicas（并发共享 canonical session，不是 failover）

```sh
export PATH="/home/u1/.cache/console-browser-acceptance/py312/bin:$PATH"
python3 -m unittest discover -s tests/unit -p 'test_app_sso*fixture*.py' -v
make test-browser-sso 'BROWSER_SSO_ARGS=--browser-channel chrome --backend-repo /home/u1/.cache/console-browser-acceptance/target-recovery/backend-source --case live-replicas'
```

沿用 `browser_sso_fixture.py::launch_backend` / `browser_sso_rp.py::run_normal_case`
的窄接缝，`app_sso_entry_fixture.py::LiveReplicaFixture` 先启动 R1，等就绪及 stock
生成共享 `keys.signing.key_file`，**不停止 R1** 再启动不同 PID/端口的 R2；两者在 A
开始前及 B/repeat/交叉校验后均须仍是原来的 live processes。`shared-store` 的先停后启
语义不变，绝不作为该并发用例的替代证据。

两份配置只在 listener/config path 不同：`identity.session_backend: redis`、
`oauth.backend: redis` 与同一新建 Redis；identity/用户/客户端及 consent 分别共享临时
SQLite（有界 busy timeout），固定 signing key、rotation/registry 关闭。均为 stock 发布
配置，不直接写库/会话/Token、不改后端。`IdentityIngress::select` 只在完成事务、无
pending RP state/在途 HTTP 请求时切换，仅转发真实请求，不重试、fallback 或合成响应。
已知 owned TLS origin 的规范转发仅属 fixture；不修改产品网关、discovery 或生产入口。

A 的密码/consent/code exchange 全在 R1；B 在 R2 实际 UI identity-only resume 后
仍需自己的首次 consent，批准前没有 B grant。A/B repeat 在 R2 使用记忆的各自 consent。
一次密码、三次 resume、两次 consent continuation；独立 code/state/S256、nonce、
access/refresh/ID-token、client-bound SID、scope/resource，AMR/ACR 与精确原始
`auth_time` 保持。Cookie 值/到期不变，ingress 仅观察到 R1 一次签发、R2 零次重签。
路径 POST 计数包括每页 `OidcLoginApi.probeProviders` 的 discovery POST：R1 为 3，
R2 为 7，不能把它们误计成密码/consent。

A 原 access token 在 R2 `/userinfo` 校验，B 原 token 在 R1 校验；各 ID token 使用
**对端 live 进程新读取的 JWKS** 验签/issuer/audience/nonce，实际转发计数逐次核对，
不能只比就绪或公钥相同。所有原 grant 仍可用；OP Cookie 不进入 RP；独立服务双向
隔离仍由 baseline 检查。focused 双网关 Chrome 已完成 **2 个组合、8 次 code grant、0 skip**，外部请求为零。

Redis 只用缓存 `redis:7-alpine` 的不可变 image ID，无拉取；新 case 固定本机 Docker
`unix:///var/run/docker.sock`，不继承远端 `DOCKER_*` context；唯一 owner label，
128 MiB/1 CPU/64 PIDs、只读根、有界 tmpfs、64 MiB/noeviction、无持久化/日志/重启。
Docker 原子分配并仅发布 `127.0.0.1` 端口（容器内 Redis 监听其私有接口）；不探测/
复用现有 Redis。每 case 最多两 OP 进程、一 Chrome 实例、一 Redis、可选一 Nginx；所有构建/
浏览器 case 串行，无 HAR/trace/截图/storage-state 或秘密日志。

`rp-entry` / `live-replicas` 由 `app_sso_supervisor.py::run_owned_case` 启动独立真实
Playwright worker。CLI supervisor 在此期间没有 sync Playwright context；SIGTERM 只
记录取消状态，不抛异常、不忽略后续信号。十分钟 deadline 在父进程检查；中断后用
共享二十秒 teardown 预算，先终止并核验 owned descendants，再清理容器/存储。Docker
create/start 单命令上限五秒，命令之间检查取消，未知写结果只核对、从不重放。

Linux subreaper 收养 detached Chrome 子孙；以 parent/start-ticks 验证后打开 pidfd，
仅用这些 pidfd 终止/reap，即使 worker SIGSTOP/卡住也不依赖其 finally/ExitStack。
拒绝有既有子进程的 supervisor，不按端口杀进程。父进程在创建前登记容器回调，并独占
Docker 生命周期；清理仍要求 exact label/name/image/ID。私有目录按 uid/device/inode
核验；worker 的 TMPDIR/TMP/TEMP、Chrome profile/artifacts 和 browser config 均在该
目录内，异常路径也纳入删除。正常退出还要求 worker 关闭线程/socket/listener、实际
Chrome/driver 退出、容器/目录消失；父进程最终核验后才发布 case PASS/Evidence。
部分启动、外来 owner、端口冲突、未知/超时清理均非通过。此边界需要 Linux pidfd 与
subreaper；不声称可清理 supervisor 自身被 SIGKILL、主机崩溃或不可用 Docker daemon。

独立的真实 Chrome 生命周期中断回归（不是 grant/HA 用例，需显式运行）：

```sh
python3 tests/integration/app_sso_termination_test.py --browser-channel chrome --backend-repo /home/u1/.cache/console-browser-acceptance/target-recovery/backend-source
```

外部 OS observer 启动实际 `test-browser-sso` recipe（`BROWSER_SSO_ARGS` 传
`--case live-replicas`）；在 Chrome 进程已出现、launch 尚未返回时发送真实 SIGTERM；
另在真实 hosted navigation 期间先
SIGSTOP 私有 worker，再 SIGTERM supervisor，强制独立 fallback。Python/Nginx 各两例，
要求两原 stock 进程/Chrome/profile/新 Redis（及 Nginx）可归属、CLI 非零、无最终 grant
PASS/Evidence，并核对 descendants/listeners/containers/temp/profile 全消失、既有容器不变。
回归自身若需 emergency cleanup 仍算失败；不使用 transport/browser mocks，不持久化
浏览器输出或制品。该 shipped 脚本的退出 watchdog 是 **25 秒**，不同于 supervisor 的
**20 秒总 teardown 预算**，不能仅凭脚本 PASS 就宣称严格满足 20 秒。

2026-10-18 独立复核另外对 Python/Nginx 各执行 launch 返回前、active-stopped、B grant
后三种真实 SIGTERM：**六次外部最终 census 均零残留，0.991–3.734 秒/20 秒预算**，
无 emergency cleanup。原 reviewer 未改的 SIGTERM probe、65 个 focused fixture 单测、
四个 shipped Chrome 中断 case 及正常双网关八 grant 也通过。当前源码的已测试取消轴已
闭环；旧源码异步 SIGTERM 失败、人工清理及中间失败仍保留在批次 evidence，不抹去。
这些是文档修改前已审阅的证据，本次文档任务未重跑 Chrome 或完整 wrapper。

**仅证明同机两个原始 stock 进程始终并发 live、共享 canonical store/固定 key 的普通
resolve、独立 RP 授权、双向验证及已测试 SIGTERM 阶段的有界 owned cleanup**，不证明实际
A→B（仍 `not_run`）、部署的三副本集群、failover、rotation、HA、跨节点存储/Redis
Sentinel/Cluster、崩溃/分区、事务中途切副本、跨进程 code consumption、native/WebView
或完整 MFA/ACR/PAR/JAR。rotation registry 仅有 memory/etcd（也可关闭），非 Redis；源证据
与后续实验边界见[浏览器 SSO](../../docs/BROWSER_SSO.md#本机并发双进程-canonical-session非-failoverha)。

**English — live-replicas scope.** Two original stock processes run concurrently on one host with
shared canonical Redis sessions and a fixed shared signing key. A authenticates on R1; B and A/B
repeats authorize on R2, with independent consent/grants/tokens/client-bound SIDs, exact original
`auth_time`, unchanged cookie value/expiry and zero reissues. Opposite live processes verify each
original access token via userinfo; fresh opposite-process JWKS verify ID-token signatures/claims.
Owned cleanup covers normal completion and the tested real-SIGTERM phases, including a stopped
worker; six independent final censuses found no survivors within 20 seconds. This is not actual-app
A→B, the deployed three-replica cluster, rotation, HA/failover, cross-node storage, mid-transaction
switching, cross-process code consumption or native/WebView. Supervisor SIGKILL, host loss and an
unavailable Docker daemon are not covered. The separate shipped probe has a 25-second watchdog,
not a strict 20-second acceptance check.

## 独立 App A/B 离线诊断（不执行集成测试）

```sh
python3 tools/check_app_sso.py --input /operator/app-sso-declarations.json
make test-app-sso
```

CLI 只读取显式绝对规范路径的 ≤16 KiB 枚举/config 声明文件，要求 uid/root 所有、
不可 group/others 写入、regular file/单 hardlink/无 symlink 路径。不接受 URL、client/
账号标识、凭据或引用文件；不读上述环境变量，不访问网络、Cookie、浏览器、认证或
账号 API，无执行/自动修复模式。schema、固定 reason/provenance 与退出码见
[离线诊断](../../docs/BROWSER_SSO.md#离线诊断为什么-b-仍要求密码)。

它区分 missing/unconfirmed/different OP 或 jar、canonical code/S256 与本地 direct、
B 的显式强制认证/选账号/max_age=0、consent 及 opaque/step-up 不确定性，不取消策略。
退出 0 仅表示完成离线解释；`compatible_static_declarations` **不是成功登录、已验证
共享 jar、有效注册或 redirect**。真实 A→B 仍 `not_run`，运行事实 `not_verified`。

当前 `make test-app-sso` 的覆盖为 **109 个测试：44 个离线诊断 + 65 个 fixture 单测**
（入口/资源/导入隔离及并发/共享存储/验证/supervisor 清理回归）；后者含自有
loopback RP/HTTP，但不启动 OP/Chrome、不导入旧 helper。不是 109 次浏览器验收，
也不能把历史两次执行同一测试相加。正常 `make test` 会发现同一批测试。

## 此前 target helper：独立审查未批准

`tools/browser_sso_acceptance.py` 与配套模块**不是上述普通 fixture 或离线诊断**。
此前独立 review 收到 provider 安全拒绝；保留 **`provider_denied_no_valid_verdict`、
无有效 PASS、未获批准且未豁免** 的原处置与证据，gate 继续阻塞此 helper 的发布/使用。
旧计划/执行步骤不再作为可运行接入说明；不重试或重建该 review，不运行历史 reviewer
或 `tests/integration/owned/` 探针，相关源码/证据保持不变。
普通功能审查、这些 fixture/诊断结果及正常 discovery 中未改的单测均不能完成或替代
该独立安全审查；实际 A/B 与完整生产就绪也没有因此获批。

## 测试场景

| 测试文件 | 覆盖范围 |
|---------|---------|
| `api_login_e2e.py` | 登录、Token 获取与认证错误 |
| `full_integration_test.py` | 管理 API 合约和核心资源流程 |
| `admin_flow_e2e.py` | 管理员跨模块业务流程 |
| `detail_api_test.py` | 详情和子资源 API |
| `cache_validation_test.py` | 代理及前端缓存行为 |
| `adversarial_test.py` | 非法输入和安全边界 |
| `health_e2e_test.py` | 健康及运行状态 |
| `browser_login_test.py` | 浏览器登录体验 |
| `browser_sso_test.py` | 隔离 stock OP、双网关、双 RP；含 `rp-entry` / `live-replicas` 分派 |
| `app_sso_entry.py` / `app_sso_entry_fixture.py` | generic JSON/no-UI 与显式托管入口对照、并发 canonical session/对端验证 |
| `app_sso_termination_test.py` | 显式 real-Chrome SIGTERM 生命周期/owned cleanup 回归，不是授权或 HA 用例 |
| `browser_test.py` | 浏览器端到端流程 |
| `browser_interaction_test.py` | 交互、导航和危险操作确认 |
| `full_stack_verify.py` | 后端、代理、静态产物的全栈冒烟 |
| `perf_benchmark.py` | 性能基准 |

除上述自建隔离 fixture 外，这些脚本会创建或修改测试数据，只应对专用测试部署运行。不要把生产凭据写入
shell history、仓库或 CI YAML；CI 中的明文 `admin/admin` 仅属于随作业销毁的
fixture 服务。后端 feature gate 和可选存储不同会改变可执行场景，失败报告
应区分“未启用”与契约回归。
