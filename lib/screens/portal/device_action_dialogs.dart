import 'package:flutter/material.dart';
import 'package:sso_admin/widgets/confirm_dialog.dart';

class DeviceMetadataUpdate {
  final String name;
  final String notes;

  const DeviceMetadataUpdate({required this.name, required this.notes});
}

Future<DeviceMetadataUpdate?> showDeviceEditDialog(
  BuildContext context,
  Map<String, dynamic> device,
) async {
  final name = TextEditingController(
    text: device['device_name']?.toString() ?? '',
  );
  final notes = TextEditingController(text: device['notes']?.toString() ?? '');
  try {
    return await showDialog<DeviceMetadataUpdate>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Edit device'),
        content: SizedBox(
          width: 440,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: name,
                maxLength: 120,
                decoration: const InputDecoration(labelText: 'Device name'),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: notes,
                maxLength: 500,
                maxLines: 3,
                decoration: const InputDecoration(
                  labelText: 'Private notes',
                  hintText: 'For example: work laptop',
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(
              DeviceMetadataUpdate(
                name: name.text.trim(),
                notes: notes.text.trim(),
              ),
            ),
            child: const Text('Save'),
          ),
        ],
      ),
    );
  } finally {
    name.dispose();
    notes.dispose();
  }
}

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
