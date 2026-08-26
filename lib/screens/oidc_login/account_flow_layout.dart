part of 'account_flow_views.dart';

/// 账户流共用骨架：标题 + 描述 + 字段 + 提示/错误 + 主操作 + 返回。
class _AccountFlowLayout extends StatelessWidget {
  final String title;
  final String description;
  final List<Widget> fields;
  final String? message;
  final String? error;
  final bool loading;
  final bool primaryEnabled;
  final String primaryLabel;
  final VoidCallback onPrimary;
  final VoidCallback onBack;

  const _AccountFlowLayout({
    required this.title,
    required this.description,
    required this.fields,
    this.message,
    this.error,
    required this.loading,
    this.primaryEnabled = true,
    required this.primaryLabel,
    required this.onPrimary,
    required this.onBack,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    // 错误优先于消息（flow 中二者互斥，防御性取错误样式）。
    final notice = error ?? message;
    return AutofillGroup(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Semantics(
            container: true,
            header: true,
            child: Text(
              context.tr(title),
              style: Theme.of(context).textTheme.titleLarge,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            context.tr(description),
            style: Theme.of(
              context,
            ).textTheme.bodyMedium?.copyWith(color: scheme.onSurfaceVariant),
          ),
          if (fields.isNotEmpty) ...[const SizedBox(height: 20), ...fields],
          if (notice != null) ...[
            const SizedBox(height: 16),
            _notice(
              context,
              context.tr(notice),
              error != null ? Icons.error_outline : Icons.info_outline,
              contained: error != null,
              live: true,
            ),
          ],
          const SizedBox(height: 20),
          PressableScale(
            child: FilledButton(
              onPressed: loading || !primaryEnabled ? null : onPrimary,
              child: loading
                  ? const SizedBox(
                      height: 18,
                      width: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : Text(context.tr(primaryLabel)),
            ),
          ),
          TextButton(
            onPressed: loading ? null : onBack,
            child: Text(AppStrings.of(context).back),
          ),
        ],
      ),
    );
  }

  /// 内联提示条：图标 + 文案；`contained` 变体 = errorContainer 底（错误）。
  Widget _notice(
    BuildContext context,
    String text,
    IconData icon, {
    bool contained = false,
    bool live = false,
  }) {
    final scheme = Theme.of(context).colorScheme;
    final color = contained ? scheme.onErrorContainer : scheme.primary;
    final row = Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 18, color: color),
        const SizedBox(width: 8),
        Expanded(
          child: Text(text, style: TextStyle(color: color)),
        ),
      ],
    );
    final wrapped = contained
        ? Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: scheme.errorContainer,
              borderRadius: BorderRadius.circular(8),
            ),
            child: row,
          )
        : row;
    return live ? Semantics(liveRegion: true, child: wrapped) : wrapped;
  }
}

/// 账户流字段：autofillHints/键盘/提交语义集中一处，loading 时禁用。
Widget _field({
  required TextEditingController controller,
  required String label,
  required bool enabled,
  List<String>? hints,
  TextInputType? keyboard,
  bool obscure = false,
  bool next = false,
  VoidCallback? onSubmit,
}) => TextField(
  controller: controller,
  enabled: enabled,
  obscureText: obscure,
  autocorrect: false,
  enableSuggestions: false,
  textCapitalization: TextCapitalization.none,
  keyboardType: keyboard,
  autofillHints: hints,
  textInputAction: next ? TextInputAction.next : TextInputAction.done,
  decoration: InputDecoration(labelText: label),
  onSubmitted: onSubmit == null ? null : (_) => onSubmit(),
);
