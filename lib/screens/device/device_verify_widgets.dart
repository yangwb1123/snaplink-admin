import 'package:flutter/material.dart';
import '../../i18n/app_strings.dart';

class DeviceRequestPreview extends StatelessWidget {
  final Map<String, dynamic> preview;

  const DeviceRequestPreview({super.key, required this.preview});

  @override
  Widget build(BuildContext context) => Card(
    color: Theme.of(context).colorScheme.surfaceContainerHighest,
    child: ListTile(
      leading: const Icon(Icons.devices_other),
      title: Text(
        preview['client_name']?.toString() ??
            preview['client_id']?.toString() ??
            '',
      ),
      subtitle: Text(
        AppStrings.of(
          context,
        ).requestedScopes((preview['scopes'] as List).join(', ')),
      ),
    ),
  );
}

class DeviceDecisionButtons extends StatelessWidget {
  final bool busy;
  final bool checking;
  final VoidCallback? onDeny;
  final VoidCallback? onApprove;

  const DeviceDecisionButtons({
    super.key,
    required this.busy,
    required this.checking,
    required this.onDeny,
    required this.onApprove,
  });

  @override
  Widget build(BuildContext context) => Row(
    children: [
      Expanded(
        child: OutlinedButton(
          onPressed: onDeny,
          style: OutlinedButton.styleFrom(
            foregroundColor: Theme.of(context).colorScheme.error,
          ),
          child: Text(AppStrings.of(context).deny),
        ),
      ),
      const SizedBox(width: 12),
      Expanded(
        child: FilledButton(
          onPressed: onApprove,
          child: busy && !checking
              ? const SizedBox(
                  height: 18,
                  width: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : Text(AppStrings.of(context).approve),
        ),
      ),
    ],
  );
}
