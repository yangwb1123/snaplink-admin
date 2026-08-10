import 'package:flutter/material.dart';
import '../app_settings.dart';
import '../services/language_catalog.dart';
import 'select_style.dart';

/// 语言下拉选择器（登录头右侧 / 设置页共用）。
///
/// 基于 Material 3 [DropdownMenu]：菜单固定从控件下方弹出（不再有
/// DropdownButton 的"选中项对齐按钮"导致的上下不一致）。菜单为圆角
/// surface 卡片，条目带圆角选中高亮与国旗图标，宽度随最宽菜单项自适应，
/// 与主题下拉（[ThemeDropdown]）共用 [appHeaderMenuStyle]。
class LanguageDropdown extends StatefulWidget {
  /// 登录头紧凑样式（无边框、小字号）；false 为设置页表单样式。
  final bool compact;

  /// 是否可交互（登录请求进行中时由登录头禁用，避免与加载态不一致）。
  final bool enabled;

  const LanguageDropdown({super.key, this.compact = false, this.enabled = true});

  @override
  State<LanguageDropdown> createState() => _LanguageDropdownState();
}

class _LanguageDropdownState extends State<LanguageDropdown> {
  late final TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(
      text: languageOptionLabel(AppSettings.instance.locale),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final current = AppSettings.instance.locale;
    final options = languageOptionsIncludingCurrent(
      AppSettings.instance.languageOptions,
      current,
    );
    final textStyle = widget.compact
        ? theme.textTheme.bodySmall
        : theme.textTheme.bodyMedium;
    return DropdownMenu<Locale>(
      // locale 变化时重建，initialSelection 与勾选态跟随当前语言。
      key: ValueKey('language-${current.languageCode}'),
      controller: _controller,
      initialSelection: current,
      enabled: widget.enabled,
      requestFocusOnTap: false,
      enableFilter: false,
      // 宽度贴合最长菜单项文字（无界布局下 intrinsic 计算不可靠）。
      width: appHeaderDropdownWidth(
        context: context,
        labels: [for (final locale in options) languageOptionLabel(locale)],
        textStyle: textStyle!,
        leadingWidth: 24, // 国旗 16 + 间距 8
        compact: widget.compact,
      ),
      // 收起态前导国旗仅装饰：字段值（如 "English"）已由输入框朗读，
      // 这里把 emoji 排除出语义树，避免屏幕阅读器朗读原始表情符号。
      leadingIcon: ExcludeSemantics(
        child: Text(
          flagEmojiForLocale(current),
          style: const TextStyle(fontSize: 16),
        ),
      ),
      // 箭头显式指定尺寸（默认 24px 在紧凑 18px 约束下会被压到不可见）。
      trailingIcon: Icon(
        headerDropdownArrowIcon,
        size: widget.compact
            ? headerDropdownCompactArrowSize
            : headerDropdownFormArrowSize,
      ),
      selectedTrailingIcon: Icon(
        headerDropdownArrowUpIcon,
        size: widget.compact
            ? headerDropdownCompactArrowSize
            : headerDropdownFormArrowSize,
      ),
      textStyle: textStyle,
      inputDecorationTheme: widget.compact
          ? compactHeaderDecoration(theme)
          : formHeaderDecoration(theme),
      menuStyle: appHeaderMenuStyle(theme),
      dropdownMenuEntries: [
        for (final locale in options)
          DropdownMenuEntry<Locale>(
            value: locale,
            label: languageOptionLabel(locale),
            // 圆角 hover/focus 背景（MenuItemButton 默认近矩形）。
            style: appDropdownEntryStyle(theme),
            labelWidget: appDropdownEntryContent(
              selected: locale.languageCode == current.languageCode,
              theme: theme,
              content: Semantics(
                // 菜单项：国旗与文字合并为一个带文本标签的语义节点
                // （languageOptionLabel），原始 emoji 不进语义树。
                label: languageOptionLabel(locale),
                excludeSemantics: true,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    menuFlagEmoji(flagEmojiForLocale(locale)),
                    const SizedBox(width: 8),
                    Text(languageOptionLabel(locale)),
                  ],
                ),
              ),
            ),
          ),
      ],
      onSelected: (locale) {
        if (locale == null) return;
        _controller.text = languageOptionLabel(locale);
        AppSettings.instance.locale = locale;
      },
    );
  }
}
