# 结构门禁修复：已完成

原有 **25 个非豁免超长 Dart 文件全部完成职责拆分**。
`engineering.yaml` 的 400 行预算、豁免、忽略规则和架构方向均不变。
没有新增依赖、删除安全检查、改变公开参数或默认启用候选接口。

## 两批拆分

| 批次 | 范围 | 新增 part |
|---|---|---:|
| 第一批 | 18 个 Forge API／契约 owner、AppSettings、Android instrumentation、Agent Compute、Forge device observation，共 22 个文件 | 46 |
| 第二批 | Forge Sessions Screen、View、Gate，属于原来的两个 library | 77 |

所有 owner 和实现 part 均不超过 400 行；原导入路径保留，私有作用域仍属于原 library。
只在完整声明、完整方法、完整语句／组件集合元素边界拆分，不按任意行号截断逻辑。

### API、设置与原生 helper

- Forge 模型、fixture、纯投影、严格解码和校验器保持原语义。
- `ForgeConversationsApi` 保留公共构造器、方法和常量；私有 HTTP／JSON 处理搬移。
  认证刷新、原请求与幂等键、GET 重试、重定向拒绝及候选 opt-in 不改变。
- AppSettings 保留 singleton、公共 getter/setter、存储与远程同步顺序；仅搬移
  locale/theme 解析及纯 origin 校验。没有新增设置键或存储位置。
- Android instrumentation 保留原入口及 `@pragma('vm:entry-point')`；仅分离
  Coordinator 配置／HTTP fixture helper，没有改变生产路由或原生宿主。
- Agent Compute 的分页／刷新／请求代次与操作职责分离；未知结果的原幂等键仍保留。
- Forge device observation 的纯模型与 Flutter panel 分开，保留原导入入口。

### Forge Sessions

| 原超长文件 | 原行数 | 当前行数 | 职责分离 |
|---|---:|---:|---|
| `lib/screens/forge/forge_sessions_screen.dart` | 9571 | 183 | library 入口；Widget、类型化存储、生命周期、会话／Run 读取、候选 loader、写操作恢复、鉴权、资源收敛守卫独立 |
| `lib/screens/forge/forge_sessions_screen_view.dart` | 2859 | 101 | Scaffold 壳；输入、可见性、Runner、receipt 使用四级类型化 record 投影；领域组件和状态提示独立 |
| `lib/screens/forge/forge_sessions_gate.dart` | 2488 | 57 | library 入口；OAuth 恢复、显式候选 reader 组装、Widget 参数和展示转发独立 |

- 公开 Widget 的 `const` 构造器、全部命名参数、参数次序和默认值保留。
  身份／transport、显式候选开关与 origin、caller-supplied display inputs 使用
  私有不可变 Widget 基类；通过 `super` 转发同类型的参数，不能改为无类型 map。
- 原字段的安全说明保存在类型化 getter contract 中；实际字段保留注解及存储语义。
- 266 个 Screen 实例状态字段仍属于同一个 State、保持原类型与初始化器；
  四个轮询常量移至原 library，值和私有边界不变。
  `setState` 在 private extension 中仅通过 State 的 `_update(VoidCallback)` 转发，
  不忽略 protected-member lint，不引入第二套状态或异步调度。
- `didUpdateWidget` 先捕获原比较，再按原次序执行来源／Runner／receipt／本地导入更新。
  请求代次、失效、清理、幂等键、凭据隔离与资源收敛条件全部保留。
- render 投影仍在原条件下解析、匹配 owner／Conversation／Run／Attempt 与客户端实例。
  组件集合保留原顺序、惰性条件、Key 与 callback，不把候选或预览作为执行授权。
- Gate 仍只在原明确开关和 origin 条件下组装 memoized reader。默认构造保持 request-free
  候选边界，普通 owner Conversation 读取及恢复顺序不变。

## 等价证据与回归

临时 AST 工具和拆分前副本仅在 `/tmp`，未将工具依赖或运行器 vendored 到仓库。
`pubspec.yaml`、`pubspec.lock`、工程阈值和豁免未改变。

- 第一批：17 个纯模型／契约 library 的 **491 个完整声明 AST 源表示一致**，
  包括 factory、schema、authority 位、重复 JSON key 拒绝和 uint64 边界。
  其他 API／设置／原生 helper 的私有方法搬移由分析与既有行为回归验证。
- 第二批：两个公开构造器仅发生字段参数 `this`→`super` 的转发；
  **279 个完整方法体、626 个存储字段、31 个 Widget 比较、42 个更新块、
  85 个 render 投影语句和 142 个组件集合元素**完成拆分前后 AST 对账。
  Private extension 的 `setState`→`_update` 转发及字段新增的 `@override` 为明确的检查差异，
  不把 AST 对账冒称为数学形式的全部运行行为证明。
- `test/structure_part_libraries_test.dart` 覆盖两批全部 library 的预算、part 存在、
  唯一注册、正确 owner、无嵌套 part 与无私自 import/export。
- `test/forge_sessions_constructor_contract_test.dart` 验证常量构造、全部 33 个关闭默认值、
  29 个独立 candidate origin、显式开关转发，以及 client／store／route／Key 保持原对象；
  构造选项不产生 HTTP／OAuth 请求。
- 既有 Forge 回归继续验证 owner 隔离、实例过滤、资源收敛、lease／receipt 绑定、
  生命周期暂停与退避、迟到响应、403／401、未知写结果和原幂等键。

## 仓内验收

- `python3 cli.py check`：filesize、complexity/analyze 全绿。
- `python3 cli.py test`：**2239 passed、172 skipped**；跳过项不算部署验收。
- `make analyze`：No issues found。
- `make build-prod`、`make release-artifact-check`：通过。
- `python3 cli.py harness`：架构、directory-fanout、root-policy、invariants、B6-1b 也通过。
- Python unit：37 passed；`git diff --check` 通过。

上述代码与仓内结构计划已完成，但不代表运行态部署恢复。没有切换身份上游、重启长期
代理、使用真实管理员凭据联调或向生产发送写请求；正确 origins、独立服务 ingress 和
专用管理员账户仍须由部署方确认。现网验收见 [管理端请求复核](ADMIN_DATA_REQUEST_REVIEW.md)。
