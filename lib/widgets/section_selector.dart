import 'package:flutter/material.dart';
import 'package:sso_admin/i18n/app_strings.dart';

/// Reusable horizontal section selector chip bar.
class SectionSelector extends StatelessWidget {
  final List<SectionDef> sections;
  final String current;
  final void Function(String section) onSelected;

  const SectionSelector({
    super.key,
    required this.sections,
    required this.current,
    required this.onSelected,
  });

  @override
  Widget build(BuildContext context) => SizedBox(
    height: 40,
    // SingleChildScrollView（非懒构建）：所有 chips 始终在树中，
    // 视口外可横向滚动到达（AppBar title 等窄容器中不被懒构建裁剪）。
    child: SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
        for (final s in sections)
          Padding(
            padding: const EdgeInsets.only(right: 8),
            // 约束 chip 外层宽度：chip 自身的 Material padding 也会占宽，
            // 只约束 label 里的 Text 不够——chip 整体不得超过 maxWidth，
            // 文字在 chip 内用 Flexible + ellipsis 截断（不超出 chip）。
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 200),
              child: ChoiceChip(
                label: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(s.icon, size: 16),
                    const SizedBox(width: 4),
                    Flexible(
                      child: Text(
                        context.tr(s.label),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
                selected: current == s.id,
                onSelected: (_) => onSelected(s.id),
              ),
            ),
          ),
        ],
      ),
    ),
  );
}

/// Definition for a section in [SectionSelector].
class SectionDef {
  final String id;
  final String label;
  final IconData icon;

  const SectionDef(this.id, this.label, this.icon);

  // destructure for convenience
  String get $1 => id;
  String get $2 => label;
  IconData get $3 => icon;
}
