# 模块决策记录（ADR）

> 维护智能第 4 条：架构知识不写成文档就会衰减。每条 = 决策 + 理由 + 反转条件。

| ADR | 决策 | 理由 | 反转条件 |
|---|---|---|---|
| ADR-001 导航两级化 | admin 32 模块分 6 组、portal 10 tab 分 3 组；组是纯导航层派生（module id/URL 不变） | 一级导航 ≤8（Supabase/Stripe 两级 IA）；35 项平铺不可扫读 | 模块 <15 时可回平铺 |
| ADR-002 表格化 | 高频列表页（audit/clients/tenants/users）用 AdminDataTable（排序/斑马纹/hover/复制） | 桌面管理后台需要真实表格（信息密度/列对齐）而非手机列表 | 移动端优先场景回 ListTile |
| ADR-003 状态集中 | 业务状态（ChangeStatus 等）集中为常量集 | 散落字符串无编译期保护（检查器抓到的债） | — |
| ADR-004 组件化 KPI | 指标用 StatCard/CountUp（大数字+趋势） | 信息优先级：重要数据占大空间 | — |
| ADR-005 徽章双编码 | StatusChip 色+图标+文字；文字色按渲染底色亮度 | WCAG 对比度（浅底白字 1.18:1 是真实 bug） | — |
| ADR-006 god-file 保留 | sso_client 607/dashboard 597 判定内聚保留；AsyncView 推广回滚 | 三次原则/克制：内聚 API 客户端与导航注册表不硬拆 | 出现第二使用方再提取 |
| ADR-007 i18n 模板 | 动态消息 `{name}` 模板 + args；纯数据用 Text | 值==key 占位污染 pattern 匹配（实测） | — |
| ADR-008 深色点缀 | 语义色点缀 dark 对比 2.26-2.83 维持（StatusChip 内已提亮） | 75 处直引改造成本 > 收益 | AppColors 主题化后 |
