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

  const LanguageDropdown({super.key, this.compact = false});

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
      requestFocusOnTap: false,
      enableFilter: false,
      // 宽度贴合最长菜单项文字（无界布局下 intrinsic 计算不可靠）。
      width: appHeaderDropdownWidth(
        context: context,
        labels: [for (final locale in options) languageOptionLabel(locale)],
        textStyle: textStyle!,
        leadingWidth: 26, // 国旗 16 + 间距 10
        compact: widget.compact,
      ),
      leadingIcon: Text(
        flagEmojiForLocale(current),
        style: const TextStyle(fontSize: 16),
      ),
      textStyle: textStyle,
      inputDecorationTheme:
          widget.compact ? compactHeaderDecoration : formHeaderDecoration(theme),
      menuStyle: appHeaderMenuStyle(theme),
      dropdownMenuEntries: [
        for (final locale in options)
          DropdownMenuEntry<Locale>(
            value: locale,
            label: languageOptionLabel(locale),
            labelWidget: appDropdownEntryContent(
              selected: locale.languageCode == current.languageCode,
              theme: theme,
              content: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    flagEmojiForLocale(locale),
                    style: const TextStyle(fontSize: 16),
                  ),
                  const SizedBox(width: 10),
                  Text(languageOptionLabel(locale)),
                ],
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
