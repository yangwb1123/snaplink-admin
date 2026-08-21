# 导航架构重组方案（Tabs 分组整理）

> 状态：**已实施**——分组导航、深链兼容和能力裁剪已落地；本文档保留为
> 结构契约与验收基线。

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

## 7. 实施状态（已完成）

| 阶段 | 状态 |
|---|---|
| 1. groups 元数据（admin_module_groups.dart：6 组 + module→group 映射） | ✅ |
| 2. dashboard：rail 6 组 + 壳层 SectionSelector（组内模块 chips） | ✅ |
| 3. 组标签 i18n（Overview/Identity/Security/Tenants/Developers/System） | ✅ |
| 4. 面包屑 group 前缀（Identity › Clients） | ✅ |
| 5. 命令面板按组标题分节（非 admin 命令归 Overview） | ✅ |
| 6. portal 3 组（Account/Connections/Data）+ 壳层 SectionSelector | ✅ |
| 7. 测试适配（窄 rail label Offstage → 组图标交互） | ✅ |
| 8. 全局分组契约守护（每个 AdminModuleId 恰好归属一个组） | ✅ |

**架构决策**（按推荐方案落地）：
- 一级点击 → 直接进组内默认模块（Supabase 式）
- Security 组 14 项 → 直接横滚 chips（克制，不分子群）
- Portal 本轮一起完成
- 路由零破坏：module id/URL 不变，group 纯导航层派生

分组契约由 `test/admin_navigation_test.dart` 的全局断言守护：六个组必须覆盖全部
`AdminModuleId`，不得重复或遗漏；未知模块仍回退到 Overview。

## 8. 验收标准

- NavigationRail ≤8 项（admin）
- 每模块可从 ≤2 次点击到达（一级 + 二级 chip）
- 全量测试 + spec-check 绿；旧深链路由不变
