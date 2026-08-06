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
    child: ListView(
      scrollDirection: Axis.horizontal,
      children: [
        for (final s in sections)
          Padding(
            padding: const EdgeInsets.only(right: 8),
            child: ChoiceChip(
              label: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(s.icon, size: 16),
                  const SizedBox(width: 4),
                  // 长 label（如 'Subscriptions & Billing'）限制宽度 + 省略号，
                  // 避免文字超出 chip/容器（横向子菜单溢出修复）。
                  ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 160),
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
      ],
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
