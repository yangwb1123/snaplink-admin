import 'package:flutter/material.dart';

/// Result of a confirm dialog.
enum ConfirmResult { confirmed, cancelled }

/// Shared confirmation dialog used across admin tabs.
/// Replaces the duplicated `_confirm()` pattern in multiple tabs.
class ConfirmDialog extends StatelessWidget {
  final String title;
  final String message;
  final String confirmLabel;
  final String cancelLabel;
  final bool destructive;
  final bool isLoading;

  const ConfirmDialog({
    super.key,
    required this.title,
    required this.message,
    this.confirmLabel = 'Confirm',
    this.cancelLabel = 'Cancel',
    this.destructive = false,
    this.isLoading = false,
  });

  /// Show the dialog and return true if confirmed, false otherwise.
  static Future<bool> show(
    BuildContext context, {
    required String title,
    required String message,
    String confirmLabel = 'Confirm',
    String cancelLabel = 'Cancel',
    bool destructive = false,
  }) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (_) => ConfirmDialog(
        title: title,
        message: message,
        confirmLabel: confirmLabel,
        cancelLabel: cancelLabel,
        destructive: destructive,
      ),
    );
    return result ?? false;
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(title),
      content: Text(message),
      actions: [
        TextButton(
          onPressed: isLoading ? null : () => Navigator.pop(context, false),
          child: Text(cancelLabel),
        ),
        FilledButton(
          onPressed: isLoading ? null : () => Navigator.pop(context, true),
          style: destructive
              ? FilledButton.styleFrom(backgroundColor: Colors.red)
              : null,
          child: isLoading
              ? const SizedBox(
                  height: 18,
                  width: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : Text(confirmLabel),
        ),
      ],
    );
  }
}

/// Action item for a list of danger operations with confirmation.
/// Used in user_support_tab and similar screens.
class DangerActionTile extends StatelessWidget {
  final String label;
  final String confirmTitle;
  final String confirmMessage;
  final IconData icon;
  final bool isLoading;
  final VoidCallback onConfirmed;

  const DangerActionTile({
    super.key,
    required this.label,
    required this.confirmTitle,
    required this.confirmMessage,
    this.icon = Icons.warning_amber_outlined,
    this.isLoading = false,
    required this.onConfirmed,
  });

  @override
  Widget build(BuildContext context) {
    return OutlinedButton.icon(
      onPressed: isLoading
          ? null
          : () async {
              final confirmed = await ConfirmDialog.show(
                context,
                title: confirmTitle,
                message: confirmMessage,
                confirmLabel: label,
                destructive: true,
              );
              if (confirmed) onConfirmed();
            },
      icon: Icon(icon),
      label: Text(label),
      style: OutlinedButton.styleFrom(
        foregroundColor: Colors.redAccent,
        side: const BorderSide(color: Colors.redAccent),
      ),
    );
  }
}
