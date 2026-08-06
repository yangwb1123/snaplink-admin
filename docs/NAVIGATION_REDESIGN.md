# 导航架构重组方案（Tabs 分组整理）

> 状态：**提案待确认**——本文档列出分析与方案，确认后实施。

## 1. 现状问题

| 侧 | 当前 | 问题 |
|---|---|---|
| Admin | **35 项平铺** NavigationRail（32 唯一模块） | 一级导航承载了全部二级内容；用户需扫读 35 项找目标；导航不可扩展（每加功能 +1 项） |
| Portal | 10 项平铺 | 同为一级，但语义可归 3 组 |

参考产品的一级导航容量：Supabase 8 项、Stripe 6 项、Vercel Dashboard 7 项、GitHub Settings 分组折叠。**一级导航应 ≤8 项**，二级用页面内 tabs。

## 2. 目标架构（两级）

```
一级：NavigationRail（≤8 组，折叠后干净）
  └─ 二级：页面内 SectionSelector（水平 ChoiceChip，项目已有组件）
       └─ 三级：详情/表单（现有 detail screens，不变）
```

## 3. Admin 分组方案（35 → 6 组）

| 一级组 | 图标 | 组内模块（二级 tabs） | 对应参考 |
|---|---|---|---|
| **Overview** | dashboard | 总览工作台、健康 | Linear Home |
| **Identity** | people | Clients、Users、Local Users、SCIM Directory、Permissions、Authz Checks | Supabase Auth |
| **Security** | shield | Connections、Domains、Device Security、Token Security、Token Policies、Token Exchange、Network Policies、Access Policies、Threat Policies、DR Mode、Crypto Keys、Credentials、Emergency Access、Change Approvals | Stripe Risk |
| **Tenants** | business | Tenants、Organizations、Subscriptions & Billing、Usage Analytics、Privacy & Retention | Stripe Billing |
| **Developers** | code | Webhooks、Live Activity、Operations、Recovery & Releases | Vercel Developers |
| **System** | settings | Governance、Audit Log、User Support | Supabase Settings |

**注**：Security 组 14 项仍偏多——二级 tabs 再分"子群"用 SectionSelector 分组头（选做，见 §6 选项 B）。

## 4. Portal 分组方案（10 → 3 组）

| 一级组 | 组内 tabs | 参考 |
|---|---|---|
| **Account** | Overview、Security、Devices、Sessions、Activity | GitHub Settings |
| **Connections** | Identities、Consents、Notifications | Stripe 账户 |
| **Data** | Organizations、Privacy | Supabase 账户 |

Portal 分组后一级 NavigationRail 3 项 + 页内 tabs（当前 10 项 Rail 已能容纳，此项为可选项）。

## 5. 路由设计（低风险关键）

```
现状：AdminRoute(module: 'clients')，URL /admin/clients（32 模块平铺）
方案：
  - module 全部保留（deep link /admin/clients 兼容，零破坏）
  - 新增 AdminModuleGroup 元数据：module → group 映射（新文件 groups.dart）
  - NavigationRail 渲染 6 个 group；选中 group → 打开组内默认模块
    + 该模块页内 SectionSelector 渲染组内全部模块 tabs
  - AdminRoute 增加 section 概念？——不需要：module 即 section，
    group 是纯导航层派生属性，不进入路由状态
```

**兼容性**：
- 旧 URL / 深链 → 不变
- 命令面板（command palette 32 项）→ 按 group 分组展示（可选）
- 面包屑 → group 前缀显示（如 Identity › Clients）
- 能力裁剪（capability gate）→ 按 module 不变，group 空时整组隐藏

## 6. 视觉参考

- **一级**：NavigationRail 品牌选中态（已有），group 无子导航展开（点击即进入组内首个模块）
- **二级**：SectionSelector 水平 chips（已有组件），当前模块高亮
- **层级感**：面包屑升级为 `Overview › Identity › Clients`（管理员知道身处何处）

## 7. 实施计划（确认后）

| 阶段 | 内容 | 风险 |
|---|---|---|
| 1 | 新增 `groups.dart`（module→group 映射 + 组定义：图标/标签/顺序） | 零（纯数据） |
| 2 | dashboard_screen 渲染改为 group 级 NavigationRail + 组内模块页承接 SectionSelector | 中（导航状态机） |
| 3 | 各 tab 页嵌入 SectionSelector（35 页中 30 页需加，工作量集中在壳层） | 中 |
| 4 | 命令面板分组、面包屑升级、能力裁剪适配 | 低 |
| 5 | portal 3 组（可选项） | 低 |

**关键设计决策（待确认）**：
- A. 一级点击 → 直接进组内模块（推荐，Supabase 式）；还是点击展开子列表（GitHub 式折叠）？
- B. Security 组 14 项：直接用 14 chips（横向滚动）；还是 chip 分组头再分 3 子群（Policies / Keys / Access）？
- C. Portal 侧是否本轮一起分组（可后续单独做）？

## 8. 验收标准

- NavigationRail ≤8 项（admin）
- 每模块可从 ≤2 次点击到达（一级 + 二级 chip）
- 全量测试 + spec-check 绿；旧深链路由不变
