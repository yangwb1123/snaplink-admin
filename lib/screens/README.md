# lib/screens — 页面层

- `admin/`：管理端 34 模块（Overview/Identity/Security/Tenants/Operations/System；
  入口覆盖从实际导航定义派生，见 `docs/ADMIN_DATA_REQUEST_REVIEW.md`）
- `portal/`：用户门户 10 tab（3 组：Account/Connections/Data）
- `oidc_login/`：托管登录全流程（MFA/WebAuthn/Consent/联邦）
- `agent/`：独立 Agent Hub 会话、工作区与 Compute 操作
- `forge/`：Forge Sessions 的身份 gate、会话与显式候选预览；
  `forge_sessions_screen.dart` 和 `forge_sessions_gate.dart` 是稳定 library 入口。
  生命周期、类型化状态、候选读取、恢复与领域展示分为同一 library 的 part；
  公共 const 构造器与默认关闭边界不变，见 `docs/STRUCTURE_REFACTOR.md`。
- 页面模式：列表页（AdminListHeader + AdminDataTable）、详情页、
  表单页（分组卡片）、工作台（hero + StatCard）

规则：页内子 tabs 用 SectionSelector；混合状态页用子组件自管三态。
