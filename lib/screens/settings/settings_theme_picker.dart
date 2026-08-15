import 'package:flutter/material.dart';
import 'package:sso_admin/app_settings.dart';
import 'package:sso_admin/i18n/app_strings.dart';
import 'package:sso_admin/widgets/theme_selector.dart';

/// 主题选择：三枚紧凑瓦片（彩色图标 + 短 caption），选中态 primaryContainer
/// 填充 + primary 边框 + 对勾徽标，键盘焦点由 InkWell.onFocusChange 驱动。
/// 图标色沿用登录头主题菜单的亮度感知强调色（theme_selector）。
class SettingsThemePicker extends StatelessWidget {
  final AppStrings strings;
  const SettingsThemePicker({super.key, required this.strings});

  @override
  Widget build(BuildContext context) {
    final current = AppSettings.instance.themeMode;
    final brightness = Theme.of(context).brightness;
    final modes = [
      (ThemeMode.system, Icons.brightness_auto, strings.themeSystem),
      (ThemeMode.light, Icons.light_mode, strings.themeLight),
      (ThemeMode.dark, Icons.dark_mode, strings.themeDark),
    ];
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (final (index, mode) in modes.indexed) ...[
          SettingsThemeOptionTile(
            mode: mode.$1,
            icon: mode.$2,
            caption: mode.$3,
            iconColor: ThemeDropdown.themeModeAccentColor(mode.$1, brightness),
            selected: current == mode.$1,
            onTap: () => AppSettings.instance.themeMode = mode.$1,
          ),
          if (index < modes.length - 1) const SizedBox(width: 8),
        ],
      ],
    );
  }
}

class SettingsThemeOptionTile extends StatefulWidget {
  final ThemeMode mode;
  final IconData icon;
  final String caption;
  final Color iconColor;
  final bool selected;
  final VoidCallback onTap;

  const SettingsThemeOptionTile({
    super.key,
    required this.mode,
    required this.icon,
    required this.caption,
    required this.iconColor,
    required this.selected,
    required this.onTap,
  });

  @override
  State<SettingsThemeOptionTile> createState() =>
      _SettingsThemeOptionTileState();
}

class _SettingsThemeOptionTileState extends State<SettingsThemeOptionTile> {
  bool _focused = false;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Tooltip(
      message: widget.caption,
      // 本 SDK（Flutter 3.47 master）无 hover/never 模式：manual = 触屏永不
      // 触发，鼠标 hover 仍显示——web 悬停专属、触屏禁用的设计意图。
      triggerMode: TooltipTriggerMode.manual,
      child: Semantics(
        selected: widget.selected,
        child: InkWell(
          onTap: widget.onTap,
          onFocusChange: (focused) => setState(() => _focused = focused),
          borderRadius: BorderRadius.circular(8),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 150),
            curve: Curves.easeOut,
            padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
            decoration: BoxDecoration(
              color: widget.selected
                  ? colorScheme.primaryContainer
                  : colorScheme.surfaceContainerHighest.withValues(alpha: 0.4),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: widget.selected || _focused
                    ? colorScheme.primary
                    : colorScheme.outlineVariant.withValues(alpha: 0.5),
                width: 2,
              ),
            ),
            child: Stack(
              children: [
                Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(widget.icon, size: 20, color: widget.iconColor),
                    const SizedBox(height: 4),
                    Text(
                      widget.caption,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: widget.selected
                            ? colorScheme.primary
                            : colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
                if (widget.selected)
                  Positioned(
                    right: 0,
                    top: 0,
                    child: Icon(
                      Icons.check_circle,
                      size: 14,
                      color: colorScheme.primary,
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
