import 'package:flutter/material.dart';
import '../app_settings.dart';
import '../i18n/app_strings.dart';
import 'select_style.dart';

/// 主题模式下拉（登录头左侧）：与语言下拉同一 DropdownMenu 风格——圆角
/// 菜单卡片、圆角选中高亮、彩色图标、宽度随文字自适应、菜单向下弹出。
class ThemeDropdown extends StatelessWidget {
  final bool compact;

  /// 是否可交互（登录请求进行中时由登录头禁用，避免与加载态不一致）。
  final bool enabled;

  const ThemeDropdown({super.key, this.compact = false, this.enabled = true});

  /// 主题模式图标（品牌强调色，刻意不随 colorScheme 派生）。
  static const _modeIcons = <ThemeMode, IconData>{
    ThemeMode.system: Icons.brightness_auto,
    ThemeMode.light: Icons.light_mode,
    ThemeMode.dark: Icons.dark_mode,
  };

  /// 浅色界面上的图标色：system indigo 淡紫 / light amber-700（提深保证
  /// 对浅色菜单卡片 ≥3:1）/ dark indigo-600。
  static const _modeAccents = <ThemeMode, Color>{
    ThemeMode.system: Color(0xFF7C6FF0),
    ThemeMode.light: Color(0xFFB45309),
    ThemeMode.dark: Color(0xFF4F46E5),
  };

  /// 深色界面上的提亮变体：light 保持 amber-500，dark 提亮到 indigo-400，
  /// 保证对 M3 深色 surfaceContainerHigh ≥3:1（浅色变体仅 ~2.3:1）。
  static const _darkBrightnessAccents = <ThemeMode, Color>{
    ThemeMode.light: Color(0xFFF59E0B),
    ThemeMode.dark: Color(0xFF818CF8),
  };

  /// 当前界面亮度下的主题模式图标色。
  static Color themeModeAccentColor(ThemeMode mode, Brightness brightness) =>
      brightness == Brightness.dark
          ? (_darkBrightnessAccents[mode] ?? _modeAccents[mode]!)
          : _modeAccents[mode]!;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final strings = AppStrings.of(context);
    final current = AppSettings.instance.themeMode;
    final currentColor = themeModeAccentColor(current, theme.brightness);
    final labels = [strings.themeSystem, strings.themeLight, strings.themeDark];
    final textStyle = compact
        ? theme.textTheme.bodySmall
        : theme.textTheme.bodyMedium;
    return DropdownMenu<ThemeMode>(
      key: ValueKey('theme-${current.name}'),
      controller: null,
      initialSelection: current,
      enabled: enabled,
      requestFocusOnTap: false,
      enableFilter: false,
      // 宽度贴合最长菜单项文字（无界布局下 intrinsic 计算不可靠）。
      width: appHeaderDropdownWidth(
        context: context,
        labels: labels,
        textStyle: textStyle!,
        leadingWidth: 26, // 彩色图标 18 + 间距 8
        compact: compact,
      ),
      // 装饰经 SDK 原生参数提供（审计 F1，Flutter 3.38 兼容）：prefixIcon
      // 承载当前主题模式图标；箭头方向随展开/收起自动切换
      // （selectedTrailingIcon）。其余字段由 inputDecorationTheme 经
      // applyDefaults 合并。
      leadingIcon: Icon(
        _modeIcons[current]!,
        size: 20,
        color: currentColor,
      ),
      trailingIcon: const Icon(
        Icons.arrow_drop_down,
        size: headerDropdownArrowSize,
        color: Color(0xFF616161),
      ),
      selectedTrailingIcon: const Icon(
        Icons.arrow_drop_up,
        size: headerDropdownArrowSize,
        color: Color(0xFF616161),
      ),
      textStyle: textStyle,
      inputDecorationTheme:
          compact ? compactHeaderDecoration(theme) : formHeaderDecoration(theme),
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
            // 圆角 hover/focus 背景（MenuItemButton 默认近矩形）。
            style: appDropdownEntryStyle(theme),
            labelWidget: appDropdownEntryContent(
              selected: mode == current,
              theme: theme,
              content: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    _modeIcons[mode]!,
                    size: 18,
                    color: themeModeAccentColor(mode, theme.brightness),
                  ),
                  const SizedBox(width: 8),
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
