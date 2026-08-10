import 'package:flutter/material.dart';
import '../app_settings.dart';
import '../i18n/app_strings.dart';
import 'select_style.dart';

/// 主题模式下拉（登录头左侧）：与语言下拉同一 DropdownMenu 风格——圆角
/// 菜单卡片、圆角选中高亮、彩色图标、宽度随文字自适应、菜单向下弹出。
class ThemeDropdown extends StatelessWidget {
  final bool compact;

  const ThemeDropdown({super.key, this.compact = false});

  static const _modeStyles = <ThemeMode, (IconData, Color)>{
    ThemeMode.system: (Icons.brightness_auto, Color(0xFF7C6FF0)),
    ThemeMode.light: (Icons.light_mode, Color(0xFFF59E0B)),
    ThemeMode.dark: (Icons.dark_mode, Color(0xFF4F46E5)),
  };

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final strings = AppStrings.of(context);
    final current = AppSettings.instance.themeMode;
    final (currentIcon, currentColor) = _modeStyles[current]!;
    final labels = [strings.themeSystem, strings.themeLight, strings.themeDark];
    final textStyle = compact
        ? theme.textTheme.bodySmall
        : theme.textTheme.bodyMedium;
    return DropdownMenu<ThemeMode>(
      key: ValueKey('theme-${current.name}'),
      controller: null,
      initialSelection: current,
      requestFocusOnTap: false,
      enableFilter: false,
      // 宽度贴合最长菜单项文字（无界布局下 intrinsic 计算不可靠）。
      width: appHeaderDropdownWidth(
        context: context,
        labels: labels,
        textStyle: textStyle!,
        leadingWidth: 28, // 彩色图标 18 + 间距 10
        compact: compact,
      ),
      leadingIcon: Icon(
        currentIcon,
        size: compact ? 18 : 20,
        color: currentColor,
      ),
      textStyle: textStyle,
      inputDecorationTheme:
          compact ? compactHeaderDecoration : formHeaderDecoration(theme),
      menuStyle: appHeaderMenuStyle(theme),
      dropdownMenuEntries: [
        for (final mode in ThemeMode.values)
          DropdownMenuEntry<ThemeMode>(
            value: mode,
            label: switch (mode) {
              ThemeMode.system => strings.themeSystem,
              ThemeMode.light => strings.themeLight,
              ThemeMode.dark => strings.themeDark,
            },
            labelWidget: appDropdownEntryContent(
              selected: mode == current,
              theme: theme,
              content: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(_modeStyles[mode]!.$1, size: 18, color: _modeStyles[mode]!.$2),
                  const SizedBox(width: 10),
                  Text(
                    switch (mode) {
                      ThemeMode.system => strings.themeSystem,
                      ThemeMode.light => strings.themeLight,
                      ThemeMode.dark => strings.themeDark,
                    },
                  ),
                ],
              ),
            ),
          ),
      ],
      onSelected: (mode) {
        if (mode != null) AppSettings.instance.themeMode = mode;
      },
    );
  }
}
