import 'package:flutter/material.dart';

/// 登录头下拉（主题/语言）的共享菜单与条目样式，保证两个选择器视觉一致。
///
/// - 菜单容器：圆角 12 surface 卡片 + 阴影，弹出方向由 DropdownMenu 固定
///   为向下。
/// - 菜单项：选中项带圆角高亮背景（primaryContainer + 主色边框）与勾选
///   徽标；悬浮高亮由 MenuItemButton 默认圆角 overlay 提供。
/// - 组件宽度自适应：不传 `width`/`expandedInsets` 时 DropdownMenu 按最宽
///   菜单项 + 图标计算 intrinsic 宽度（与文字宽度匹配）。
MenuStyle appHeaderMenuStyle(ThemeData theme) => MenuStyle(
  elevation: const WidgetStatePropertyAll(3),
  backgroundColor: WidgetStatePropertyAll(
    theme.colorScheme.surfaceContainerHigh,
  ),
  shape: WidgetStatePropertyAll(
    RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
  ),
  padding: const WidgetStatePropertyAll(
    EdgeInsets.symmetric(vertical: 8, horizontal: 8),
  ),
);

/// 圆角选中态条目：当前值高亮（primaryContainer 圆角背景 + 主色边框 +
/// 勾选徽标），其余项透明。`content` 由调用方提供（国旗/彩色图标 + 文本）。
Widget appDropdownEntryContent({
  required bool selected,
  required Widget content,
  required ThemeData theme,
}) {
  return AnimatedContainer(
    duration: const Duration(milliseconds: 120),
    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
    decoration: BoxDecoration(
      color: selected
          ? theme.colorScheme.primaryContainer.withValues(alpha: 0.45)
          : Colors.transparent,
      borderRadius: BorderRadius.circular(8),
      border: selected
          ? Border.all(color: theme.colorScheme.primary, width: 1)
          : null,
    ),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        content,
        if (selected) ...[
          const SizedBox(width: 8),
          Icon(Icons.check, size: 16, color: theme.colorScheme.primary),
        ],
      ],
    ),
  );
}

/// 登录头紧凑输入装饰（无边框，紧凑高度）。prefix/suffix 图标约束收紧到
/// 18px，否则 InputDecorator 的 icon 默认 48px 高会把控件撑高。
///
/// 触摸目标：字段高度 = 正文 16 + 上下 contentPadding 16×2 = 48px
/// （Material 最小交互尺寸），与旁边 48px 的设置 IconButton 对齐。
/// 键盘焦点：enabled 态无边框，聚焦时绘制 primary 圆角描边
/// （WCAG 2.4.7 Focus Visible）。
InputDecorationTheme compactHeaderDecoration(ThemeData theme) =>
    InputDecorationTheme(
      isDense: true,
      border: InputBorder.none,
      enabledBorder: InputBorder.none,
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: BorderSide(color: theme.colorScheme.primary, width: 1.5),
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 16),
      prefixIconConstraints: const BoxConstraints.tightFor(width: 18, height: 18),
      suffixIconConstraints: const BoxConstraints.tightFor(width: 18, height: 18),
    );

/// 设置页表单输入装饰（圆角边框，与设置页其他控件一致）。
InputDecorationTheme formHeaderDecoration(ThemeData theme) =>
    InputDecorationTheme(
      isDense: true,
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
      contentPadding: const EdgeInsets.symmetric(horizontal: 12),
    );

/// 测量下拉内容的自然宽度：最长文字 + leading 图标 + 箭头 + 留白。
/// DropdownMenu 在无界约束（Row/Column 内）下 intrinsic 宽度不可靠
/// （实测 270-315px，远超文字内容），显式传 `width` 使输入框与菜单都
/// 贴合文字宽度。
double appHeaderDropdownWidth({
  required BuildContext context,
  required List<String> labels,
  required TextStyle textStyle,
  required double leadingWidth,
  bool compact = false,
}) {
  var longest = labels.first;
  for (final label in labels) {
    if (label.length > longest.length) longest = label;
  }
  final painter = TextPainter(
    text: TextSpan(text: longest, style: textStyle),
    textDirection: Directionality.of(context),
  )..layout();
  // 菜单项超出文字部分：勾选徽标 22 + MenuItemButton 水平 padding 28 +
  // 菜单容器 padding 16 = 66，另加下拉箭头 18 与输入/菜单间隙 8（合计
  // 92）；再留 22 保险（字体回退/emoji 宽度波动，Ahem 等宽测试字体下
  // 菜单项仍不溢出）：92 + 22 = 114。form 模式另有输入框水平 padding 24
  // → 114 + 24 = 138。
  final chrome = compact ? 114.0 : 138.0;
  return painter.width + leadingWidth + chrome;
}
