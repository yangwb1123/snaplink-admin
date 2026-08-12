import 'package:flutter/material.dart';
import 'package:sso_admin/i18n/localized_text.dart';

/// 工作台内联错误区：错误容器 + 可选中文本 + 重试（X4 模式）。
class ConnectionErrorCard extends StatelessWidget {
  final String error;
  final VoidCallback? onRetry;

  const ConnectionErrorCard({super.key, required this.error, this.onRetry});

  @override
  Widget build(BuildContext context) => Card(
    color: Theme.of(context).colorScheme.errorContainer,
    margin: const EdgeInsets.only(top: 16),
    child: Padding(
      padding: const EdgeInsets.all(12),
      child: Row(
        children: [
          Icon(
            Icons.error_outline,
            size: 18,
            color: Theme.of(context).colorScheme.onErrorContainer,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: SelectableText(
              error,
              style: TextStyle(
                color: Theme.of(context).colorScheme.onErrorContainer,
              ),
            ),
          ),
          if (onRetry != null)
            TextButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh, size: 18),
              label: const LocalizedText('Retry'),
            ),
        ],
      ),
    ),
  );
}
