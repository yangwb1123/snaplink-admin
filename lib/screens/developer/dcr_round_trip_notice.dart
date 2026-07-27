import 'package:flutter/material.dart';

import 'dcr_models.dart';

class DcrRoundTripNotice extends StatelessWidget {
  final DcrRoundTripSafety safety;

  const DcrRoundTripNotice({super.key, required this.safety});

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: safety.canSafelyUpdate
            ? colors.secondaryContainer
            : colors.errorContainer,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            safety.canSafelyUpdate
                ? 'Round-trip limitations'
                : 'Saving disabled: incomplete RFC 7592 representation',
            style: Theme.of(context).textTheme.titleSmall,
          ),
          const SizedBox(height: 6),
          for (final warning in safety.warnings)
            Padding(
              padding: const EdgeInsets.only(bottom: 3),
              child: Text('• $warning'),
            ),
        ],
      ),
    );
  }
}
