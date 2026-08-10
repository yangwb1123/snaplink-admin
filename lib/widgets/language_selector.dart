import 'package:flutter/material.dart';
import '../app_settings.dart';
import '../services/language_catalog.dart';

/// 语言下拉选择器（登录头紧凑版 / 设置页表单版共用）。
///
/// 用 Material 3 [DropdownMenu] 取代 [DropdownButton]：DropdownButton 的
/// 弹出菜单会把**选中项垂直对齐到按钮位置**（dropdown.dart 的
/// `getMenuLimits`），导致顶部（登录头）的菜单向上弹出、页面中部的菜单
/// 向下弹出；DropdownMenu 的菜单固定从控件下方展开，两个入口弹出方向
/// 一致。菜单样式统一：圆角卡片、surface 背景、勾选高亮当前语言。
class LanguageDropdown extends StatefulWidget {
  /// 登录头紧凑样式（无边框、小字号、固定菜单宽度）。
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
    return DropdownMenu<Locale>(
      // locale 变化时重建，initialSelection 与勾选态跟随当前语言。
      key: ValueKey('language-${current.languageCode}'),
      controller: _controller,
      initialSelection: current,
      requestFocusOnTap: false,
      enableFilter: false,
      expandedInsets: EdgeInsets.zero,
      width: widget.compact ? 190 : null,
      leadingIcon: Icon(
        Icons.translate,
        size: widget.compact ? 18 : 20,
        color: theme.colorScheme.onSurfaceVariant,
      ),
      textStyle: widget.compact
          ? theme.textTheme.bodySmall
          : theme.textTheme.bodyMedium,
      inputDecorationTheme: widget.compact
          ? const InputDecorationTheme(
              isDense: true,
              // isCollapsed 去掉 TextField 的最小交互高度：登录头空间紧凑，
              // 默认高度会把登录卡片撑高、小视口下按钮被推出屏幕。
              isCollapsed: true,
              border: InputBorder.none,
              contentPadding: EdgeInsets.zero,
            )
          : InputDecorationTheme(
              isDense: true,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
              ),
              contentPadding: const EdgeInsets.symmetric(horizontal: 12),
            ),
      menuStyle: MenuStyle(
        elevation: const WidgetStatePropertyAll(3),
        backgroundColor: WidgetStatePropertyAll(
          theme.colorScheme.surfaceContainerHigh,
        ),
        shape: WidgetStatePropertyAll(
          RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
        padding: const WidgetStatePropertyAll(
          EdgeInsets.symmetric(vertical: 6),
        ),
      ),
      dropdownMenuEntries: [
        for (final locale in options)
          DropdownMenuEntry<Locale>(
            value: locale,
            label: languageOptionLabel(locale),
            leadingIcon: locale.languageCode == current.languageCode
                ? Icon(
                    Icons.check,
                    size: 18,
                    color: theme.colorScheme.primary,
                  )
                : const SizedBox(width: 18),
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
