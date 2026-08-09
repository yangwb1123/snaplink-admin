import 'package:flutter/material.dart';
import 'package:sso_admin/i18n/app_strings.dart';
import 'package:sso_admin/widgets/data_emphasis.dart';

/// Section title row with an optional count pill and trailing action.
class SectionHeader extends StatelessWidget {
  final String title; // i18n key
  final int? count; // null => no badge
  final Widget? action; // trailing action
  final DataEmphasisLevel level; // default secondary

  const SectionHeader(
    this.title, {
    super.key,
    this.count,
    this.action,
    this.level = DataEmphasisLevel.secondary,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Row(
      children: [
        Text(
          context.tr(title),
          style: dataEmphasisStyle(level, Theme.of(context)),
        ),
        if (count != null) ...[
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(
              color: scheme.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(999),
            ),
            child: Text(
              '$count',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: scheme.onSurfaceVariant,
              ),
            ),
          ),
        ],
        const Spacer(),
        ?action,
      ],
    );
  }
}
