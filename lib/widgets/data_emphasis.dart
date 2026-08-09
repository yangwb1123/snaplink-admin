import 'package:flutter/material.dart';
import 'package:sso_admin/i18n/app_strings.dart';

/// Data-emphasis levels for data-dense admin surfaces.
///
/// Theme-derived only (onSurface / onSurfaceVariant), so contrast stays
/// WCAG-safe in both brightness modes.
enum DataEmphasisLevel { primary, secondary, tertiary }

/// Pure style derivation for a [DataEmphasisLevel].
TextStyle dataEmphasisStyle(DataEmphasisLevel level, ThemeData theme) =>
    switch (level) {
      DataEmphasisLevel.primary => theme.textTheme.titleMedium!.copyWith(
        fontWeight: FontWeight.w700,
        color: theme.colorScheme.onSurface,
      ),
      DataEmphasisLevel.secondary => theme.textTheme.bodyMedium!.copyWith(
        fontWeight: FontWeight.w600,
        color: theme.colorScheme.onSurface,
      ),
      DataEmphasisLevel.tertiary => theme.textTheme.bodySmall!.copyWith(
        color: theme.colorScheme.onSurfaceVariant,
      ),
    };

/// Emphasis-aware data label (i18n key text).
class DataEmphasis extends StatelessWidget {
  final DataEmphasisLevel level;
  final String text;
  final int maxLines;

  const DataEmphasis({
    super.key,
    this.level = DataEmphasisLevel.tertiary,
    required this.text,
    this.maxLines = 1,
  });

  @override
  Widget build(BuildContext context) => Text(
    context.tr(text),
    maxLines: maxLines,
    overflow: maxLines > 1 ? TextOverflow.ellipsis : null,
    style: dataEmphasisStyle(level, Theme.of(context)),
  );
}
