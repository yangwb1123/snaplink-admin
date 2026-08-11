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

/// 菜单项自身的 ButtonStyle：圆角 8 的 hover/focus 背景（覆盖 MenuItemButton
/// 默认近矩形的圆角 4 overlay），hover 色与登录头 [_HoverTint] 一致。
/// DropdownMenuEntry 不暴露 item style 时 hover 背景无法圆角化。
ButtonStyle appDropdownEntryStyle(ThemeData theme) => ButtonStyle(
  shape: WidgetStatePropertyAll(
    RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
  ),
  overlayColor: WidgetStatePropertyAll(
    theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.6),
  ),
  // 与 MenuItemButton 默认水平 padding 一致（entry.style 会整体替换默认
  // styleFrom，需要自带 padding）。
  padding: const WidgetStatePropertyAll(
    EdgeInsetsDirectional.only(start: 12, end: 12),
  ),
);

/// 圆角选中态条目：当前值高亮（primaryContainer 圆角背景 + 主色边框 +
/// 勾选徽标），其余项透明。`content` 由调用方提供（国旗/彩色图标 + 文本）。
///
/// 高亮背景占满整个菜单项宽度（active 框 100%）；水平方向内容不加 padding：
/// DropdownMenu 已把 labelWidget 起点与输入框内容起点对齐，再叠加水平
/// padding 会把菜单项文字推出对齐线。
Widget appDropdownEntryContent({
  required bool selected,
  required Widget content,
  required ThemeData theme,
}) {
  return AnimatedContainer(
    duration: const Duration(milliseconds: 120),
    width: double.infinity,
    padding: const EdgeInsets.symmetric(vertical: 8),
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
      mainAxisSize: MainAxisSize.max,
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

/// 菜单项内国旗的垂直居中容器：emoji 字形在文本行内按 baseline 绘制，
/// 视觉中心偏上；固定行高 + Center 后字形与相邻语言名居中对齐。
Widget menuFlagEmoji(String flag) => SizedBox(
  height: 16,
  child: Center(
    child: Text(flag, style: const TextStyle(fontSize: 16, height: 1.0)),
  ),
);

/// 与控件尺寸匹配的下拉箭头：DropdownMenu 默认箭头是 24px 的
/// [Icons.arrow_drop_down]，在紧凑模式 18px 的 suffixIcon 约束下会被压成
/// 不可见的 2x2；显式指定 size 与约束一致，保证可见且居中。
IconData get headerDropdownArrowIcon => Icons.arrow_drop_down;
IconData get headerDropdownArrowUpIcon => Icons.arrow_drop_up;

/// compact 模式箭头尺寸（与 [compactHeaderDecoration] 的
/// suffixIconConstraints 一致）。
const headerDropdownCompactArrowSize = 20.0;

/// form 模式箭头尺寸（InputDecorator 默认 suffix 区域，居中于输入框）。
const headerDropdownFormArrowSize = 20.0;

/// 登录头紧凑输入装饰（无边框，紧凑高度）。prefix/suffix 图标约束收紧到
/// 20px（与设置页表单版同一视觉），否则 InputDecorator 的 icon 默认
/// 48px 高会把控件撑高。
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
      prefixIconConstraints: const BoxConstraints.tightFor(width: 20, height: 20),
      suffixIconConstraints: const BoxConstraints.tightFor(width: 20, height: 20),
    );

/// 设置页表单输入装饰（圆角边框，与设置页其他控件一致）。
/// prefix/suffix 图标约束与登录头紧凑版同一视觉：icon 区域 20x20，
/// 避免 InputDecorator 默认 48x48 图标区把国旗/箭头撑大。
InputDecorationTheme formHeaderDecoration(ThemeData theme) =>
    InputDecorationTheme(
      isDense: true,
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      prefixIconConstraints: const BoxConstraints.tightFor(width: 20, height: 20),
      suffixIconConstraints: const BoxConstraints.tightFor(width: 20, height: 20),
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
