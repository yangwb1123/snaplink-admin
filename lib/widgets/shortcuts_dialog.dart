import 'package:flutter/material.dart';
import 'package:sso_admin/i18n/localized_text.dart';

/// Keyboard shortcuts reference dialog.
/// Shows all available shortcuts grouped by category.
///
/// 用法：`ShortcutsDialog.show(context)`（静态入口，由 Ctrl+? 触发）；
/// 内容为静态目录，无需构造参数。
class ShortcutsDialog extends StatelessWidget {
  const ShortcutsDialog({super.key});

  static const _shortcuts = [
    _ShortcutGroup('Navigation', [
      ('Ctrl+K', 'Command palette'),
      ('Ctrl+1-9', 'Switch to tab'),
      ('Ctrl+?', 'Show keyboard shortcuts'),
      ('Escape', 'Close dialog / go back'),
    ]),
    _ShortcutGroup('Actions', [
      ('Ctrl+N', 'Create new resource'),
      ('Ctrl+F', 'Focus search'),
      ('Ctrl+R', 'Refresh current view'),
    ]),
  ];

  static void show(BuildContext context) {
    showDialog(context: context, builder: (_) => const ShortcutsDialog());
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: const LocalizedText('Keyboard Shortcuts'),
    content: SingleChildScrollView(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: _shortcutRows(context),
      ),
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(context),
        child: const LocalizedText('Close'),
      ),
    ],
  );

  /// 静态快捷键目录（固定 2 组 7 条，非数据驱动）：独立构建，
  /// 保持 build 精简、内容可滚动（P1 懒构建门禁兼容）。
  static List<Widget> _shortcutRows(BuildContext context) => [
    for (final group in _shortcuts) ...[
      LocalizedText(
        group.name,
        style: Theme.of(context).textTheme.titleSmall,
      ),
      const SizedBox(height: 8),
      for (final (key, desc) in group.items)
        Padding(
          padding: const EdgeInsets.only(left: 16, bottom: 8),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 8,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: Theme.of(
                    context,
                  ).colorScheme.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  key,
                  style: const TextStyle(
                    fontFamily: 'monospace',
                    fontSize: 12,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              LocalizedText(desc, style: const TextStyle(fontSize: 13)),
            ],
          ),
        ),
      const SizedBox(height: 12),
    ],
  ];
}

class _ShortcutGroup {
  final String name;
  final List<(String, String)> items;
  const _ShortcutGroup(this.name, this.items);
}
