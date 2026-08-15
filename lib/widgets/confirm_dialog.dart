import 'package:flutter/material.dart';
import 'package:sso_admin/theme/app_colors.dart';
import 'package:sso_admin/i18n/app_strings.dart';

/// Shared confirmation dialog used across admin tabs.
/// Supports destructive actions with optional type-to-confirm.
class ConfirmDialog extends StatelessWidget {
  final String title;
  final String message;
  final String confirmLabel;
  final String cancelLabel;
  final bool destructive;
  final bool isLoading;
  final String? confirmText; // If set, user must type this to enable confirm

  const ConfirmDialog({
    super.key,
    required this.title,
    required this.message,
    this.confirmLabel = 'Confirm',
    this.cancelLabel = 'Cancel',
    this.destructive = false,
    this.isLoading = false,
    this.confirmText,
  });

  /// Show the dialog and return true if confirmed, false otherwise.
  static Future<bool> show(
    BuildContext context, {
    required String title,
    required String message,
    String confirmLabel = 'Confirm',
    String cancelLabel = 'Cancel',
    bool destructive = false,
    String? confirmText,
  }) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (_) => ConfirmDialog(
        title: title,
        message: message,
        confirmLabel: confirmLabel,
        cancelLabel: cancelLabel,
        destructive: destructive,
        confirmText: confirmText,
      ),
    );
    return result ?? false;
  }

  @override
  Widget build(BuildContext context) {
    if (confirmText != null && destructive) {
      return _TypeToConfirmDialog(
        title: title,
        message: message,
        confirmLabel: confirmLabel,
        cancelLabel: cancelLabel,
        confirmText: confirmText!,
        isLoading: isLoading,
      );
    }
    return AlertDialog(
      title: Text(context.tr(title)),
      content: Text(context.tr(message)),
      actions: [
        TextButton(
          onPressed: isLoading ? null : () => Navigator.pop(context, false),
          child: Text(context.tr(cancelLabel)),
        ),
        FilledButton(
          onPressed: isLoading ? null : () => Navigator.pop(context, true),
          style: destructive
              ? FilledButton.styleFrom(backgroundColor: AppColors.danger)
              : null,
          child: isLoading
              ? const SizedBox(
                  height: 18,
                  width: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : Text(context.tr(confirmLabel)),
        ),
      ],
    );
  }
}

/// Confirm dialog that requires typing a specific text to enable the confirm button.
/// Used for destructive operations like deleting resources.
class _TypeToConfirmDialog extends StatefulWidget {
  final String title;
  final String message;
  final String confirmLabel;
  final String cancelLabel;
  final String confirmText;
  final bool isLoading;

  const _TypeToConfirmDialog({
    required this.title,
    required this.message,
    required this.confirmLabel,
    required this.cancelLabel,
    required this.confirmText,
    this.isLoading = false,
  });

  @override
  State<_TypeToConfirmDialog> createState() => _TypeToConfirmDialogState();
}

class _TypeToConfirmDialogState extends State<_TypeToConfirmDialog> {
  final _ctrl = TextEditingController();
  bool _match = false;

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(context.tr(widget.title)),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(context.tr(widget.message)),
          const SizedBox(height: 16),
          Text(
            context.tr('Type "{value}" to confirm:', {
              'value': widget.confirmText,
            }),
            style: Theme.of(context).textTheme.bodySmall,
          ),
          const SizedBox(height: 8),
          // 语义标签与上方可见提示一致（不重复渲染文本，只命名字段）。
          Semantics(
            label: context.tr('Type "{value}" to confirm:', {
              'value': widget.confirmText,
            }),
            child: TextField(
              controller: _ctrl,
              // 类型确认是对话框唯一的输入目的：打开即聚焦，键盘用户无需先 Tab。
              autofocus: true,
              onChanged: (v) => setState(() => _match = v == widget.confirmText),
              decoration: const InputDecoration(
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.all(Radius.circular(8)),
                ),
                isDense: true,
              ),
            ),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: widget.isLoading
              ? null
              : () => Navigator.pop(context, false),
          child: Text(context.tr(widget.cancelLabel)),
        ),
        FilledButton(
          onPressed: (!_match || widget.isLoading)
              ? null
              : () => Navigator.pop(context, true),
          style: FilledButton.styleFrom(backgroundColor: AppColors.danger),
          child: widget.isLoading
              ? const SizedBox(
                  height: 18,
                  width: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : Text(context.tr(widget.confirmLabel)),
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
  final String? confirmText;
  final VoidCallback onConfirmed;

  const DangerActionTile({
    super.key,
    required this.label,
    required this.confirmTitle,
    required this.confirmMessage,
    this.icon = Icons.warning_amber_outlined,
    this.isLoading = false,
    this.confirmText,
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
                confirmText: confirmText,
              );
              if (confirmed) onConfirmed();
            },
      icon: Icon(icon),
      label: Text(context.tr(label)),
      style: OutlinedButton.styleFrom(
        foregroundColor: AppColors.danger,
        side: const BorderSide(color: AppColors.danger),
      ),
    );
  }
}
