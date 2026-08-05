import 'package:flutter/material.dart';
import 'package:sso_admin/i18n/app_strings.dart';
import 'package:sso_admin/widgets/confirm_dialog.dart';

class DeviceMetadataUpdate {
  final String name;
  final String notes;

  const DeviceMetadataUpdate({required this.name, required this.notes});
}

/// The dialog owns its [TextEditingController]s so they are disposed only
/// when the route is actually removed from the tree. Disposing them in a
/// `finally` right after `showDialog` completes would destroy them while the
/// exit animation still references the TextFields ("used after being
/// disposed").
class _DeviceEditDialog extends StatefulWidget {
  final Map<String, dynamic> device;

  const _DeviceEditDialog({required this.device});

  @override
  State<_DeviceEditDialog> createState() => _DeviceEditDialogState();
}

class _DeviceEditDialogState extends State<_DeviceEditDialog> {
  late final TextEditingController _name = TextEditingController(
    text: widget.device['device_name']?.toString() ?? '',
  );
  late final TextEditingController _notes = TextEditingController(
    text: widget.device['notes']?.toString() ?? '',
  );

  @override
  void dispose() {
    _name.dispose();
    _notes.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: Text(context.tr('Edit device')),
    content: SizedBox(
      width: 440,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(
            controller: _name,
            maxLength: 120,
            decoration: InputDecoration(labelText: context.tr('Device name')),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _notes,
            maxLength: 500,
            maxLines: 3,
            decoration: InputDecoration(
              labelText: context.tr('Private notes'),
              hintText: context.tr('For example: work laptop'),
            ),
          ),
        ],
      ),
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.of(context).pop(),
        child: Text(context.strings.cancel),
      ),
      FilledButton(
        onPressed: () => Navigator.of(context).pop(
          DeviceMetadataUpdate(
            name: _name.text.trim(),
            notes: _notes.text.trim(),
          ),
        ),
        child: Text(context.strings.save),
      ),
    ],
  );
}

Future<DeviceMetadataUpdate?> showDeviceEditDialog(
  BuildContext context,
  Map<String, dynamic> device,
) => showDialog<DeviceMetadataUpdate>(
  context: context,
  builder: (_) => _DeviceEditDialog(device: device),
);

Future<bool> confirmDeviceAction(
  BuildContext context, {
  required String title,
  required String message,
  required String confirmLabel,
  bool destructive = true,
  String? confirmText,
}) async {
  return ConfirmDialog.show(
    context,
    title: title,
    message: message,
    confirmLabel: confirmLabel,
    destructive: destructive,
    confirmText: confirmText,
  );
}
