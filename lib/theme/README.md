# lib/theme — 设计令牌与主题

- `app_colors.dart`：**唯一色源**（语义 token：primary/success/warning/danger/
  muted…）——禁止在业务代码散落 Color 字面量（spec-check 门禁守护）
- `app_theme.dart`：Material 3 主题构建（浅/深双模式、圆角体系、
  输入框/按钮/卡片/导航全局样式）

规范：`ui-specs` 的 color-intelligence——颜色是产品认知系统的一部分；
语义色必须双编码（色+图标/文字）。
