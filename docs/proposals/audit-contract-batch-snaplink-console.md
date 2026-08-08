提案已完成并通过校验（`REFUSAL-CHECK: OK`）。产出：`docs/proposals/audit-contract-batch-snaplink-console.md`（未修改任何代码）。

## 核验关键发现（不冒充 Verified）

**B6-1 读路径接入（F-06）**
- ✅ 清单路径实测：`lib/services/audit_log_service.dart`（localStorage ring，唯一写方 `snaplink_admin_api.dart:82`）、`lib/api/portal_api.dart`（路径存在，但作用域存疑 `[PROPOSED]`——它是门户客户端，管理端审计页实际走 `SnaplinkAdminApi`，已在 `governance_tab.dart:166` 用 `GET /api/v1/audit/events` 实测）
- ✅ 清单未列的审计页 UI 补全为 `lib/screens/admin/audit_log_tab.dart`（226 行）+ 接线点 `dashboard_screen.dart:530`（当前无条件注册、无 api 参数）
- ✅ documented 目录已含 3 条 audit 读路由（`snaplink_admin_types.dart:310-312`），能力门禁可用
- `[PROPOSED]`：tenant_id（token claim 解析，依赖 B4-1）、trace_id（BFF 注入机制本仓无）、full 部署 sink 独立上游的 nginx 分流配置本仓不存在

**B6-2 边缘生成验证**
- `[RESOLVED]`（B6-2, 2026-08-07）：**Branch B**（contract exception）chosen per code reality + drill evidence（`docs/proposals/b6-2-lib-screens-device-client-id-alignment-spec.md` REQ-0/REQ-3）——代码实况 `sso-admin-console` 为权威值（`app_router.dart:35`、`sso_client.dart:86`、`sso_client_test.dart:18`，citation 已从陈旧的 `:55` 修正为 `:35`）；sibling 机制落地后统一对齐 `SSOAdminClient.firstPartyClientId`。Device-leg evidence：登录经设备重定向腿（`redirect=/device/verify`，REQ-1 已 pin）wire 携带 client_id=`sso-admin-console`；sink 查询 `GET /api/v1/audit/events?event_types=auth.login.success&tenant_id=<t>` 返回恰好一行（无重复）——未部署栈/未观测到发射时该腿标记 `[proposed]`，deviation 记录于 drill 输出（`tests/integration/audit_login_drill.py`），无 false PASS。实施门禁行同步修正：`implementation-gate.md:57` 行 2
- `[PROPOSED]`：console 无原生事件生成能力，本项实为验证 drill + 回归测试，无生产代码改动

**其余部分**：逐项改动设计（客户端类型化查询 → 面板拆分 → 三态 UI → 接线，含 400 行预算拆分预案）、T-12/G7 断言映射、单元+集成+回归测试计划、跨批次依赖链（B1-5/B1-8/B4-1/B4-5）、G0–G6 前置门禁核对表、每项风险与回滚方案（均纯前端可 revert，无数据迁移）。
