# lib/screens — 页面层（admin / portal / oidc / setup / developer / device）

- `admin/`：管理端 32 模块（导航分组 6 组：Overview/Identity/Security/
  Tenants/Developers/System——`admin_module_groups.dart` 纯导航层派生）
- `portal/`：用户门户 10 tab（3 组：Account/Connections/Data）
- `oidc_login/`：托管登录全流程（MFA/WebAuthn/Consent/联邦）
- 页面模式：列表页（AdminListHeader + AdminDataTable）、详情页、
  表单页（分组卡片）、工作台（hero + StatCard）

规则：页内子 tabs 用 SectionSelector；混合状态页用子组件自管三态。
