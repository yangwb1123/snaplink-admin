提案文档已完成并通过校验。输出文件：`docs/proposals/compose-2026-017-console.md`

## 交付摘要

**基于仓库实况的调研结论**
- 全仓库无任何 vault/file 契约（`backend-contracts.json` 22 条、内置路由目录均无），因此提案将文件管理定义为**条件能力**并 fail closed，符合"不猜接口"原则
- 复用既有双层能力清单（`GET /api/v1/admin/endpoints` 运行时 + `SnaplinkAdminOperationCatalog` 发布目录）与 `CapabilityGate`/`supportsX` 导航裁剪机制

**文档覆盖（按任务要求）**
1. **UI 变更**：新模块 `files`（`/admin/files`）→ `FilesTab`（三态 + 降级态）；`FileDeleteDialog`（必填删除原因 + 去向确认 + 类型确认短语）；状态模型含 `idle/submitting/success/failed/outcomeUnknown`（网络歧义不重放写操作）
2. **结果反馈**：成功（SnackBar 含回收站路径/保留期 `retention_until`）、失败（内联错误 + 404/501 降级）、未知（引导审计时间线核实）
3. **API 契约引用**：既有引用点逐一标注代码位置；新增所需契约（`DELETE /api/v1/vault/files/{file_id}` 等）标记"待后端审核"，缺失即隐藏入口
4. **审计展示字段**：`vault.file.deleted` 的 14 项字段表（事件类型/时间/操作者/文件标识/原因/去向/保留期/结果/来源），含本地审计 `AuditEntry` 向后兼容扩展与 SSE 实时流集成
5. **门禁自检清单**：uispacing（8pt token 集合 + 机械命令）、uicolor（`AppColors` 语义色）、uistyle（无内联样式 + format）、uicheck（`check-frontend-quality.py --strict` 预算 + engineering.yaml + i18n 覆盖 + 能力门禁测试）共 18 项，均绑定实际工具命令

校验器 `check-no-refusal.py` 输出 `REFUSAL-CHECK: OK`，未修改任何代码。
