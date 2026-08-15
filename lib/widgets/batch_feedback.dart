import 'package:flutter/material.dart';
import 'package:sso_admin/i18n/app_strings.dart';
import 'package:sso_admin/i18n/localized_text.dart';
import 'package:sso_admin/widgets/app_snackbar.dart';

/// 批量操作结果反馈：汇总 SnackBar + 失败明细入口。
///
/// 汇总文案由页面按各自 i18n key 构造（保持既有语义与测试断言），本组件
/// 只负责呈现（经 [showAppSnackBar] 统一样式与防堆积）：
/// - 全成功：成功样式（4s）；
/// - 部分失败：错误样式 + "View details" 动作（8s），点击展开全部失败
///   明细（multi-status 失败项展开查看），不再截断到前 3 条。
void showBatchResultSnackBar(
  BuildContext context, {
  required String message,
  required List<String> failures,
}) {
  showAppSnackBar(
    context,
    content: Text(message),
    kind: failures.isEmpty ? AppSnackBarKind.success : AppSnackBarKind.error,
    duration: failures.isEmpty
        ? const Duration(seconds: 4)
        : const Duration(seconds: 8),
    action: failures.isEmpty
        ? null
        : SnackBarAction(
            label: 'View details'.localized,
            onPressed: () =>
                showBatchFailureDialog(context, failures: failures),
          ),
  );
}

/// 失败明细对话框：可滚动逐项列出（id + 错误），供批量部分失败展开查看。
Future<void> showBatchFailureDialog(
  BuildContext context, {
  required List<String> failures,
}) => showDialog<void>(
  context: context,
  builder: (dialogContext) {
    final theme = Theme.of(dialogContext);
    return AlertDialog(
      title: Text(
        dialogContext.tr('Failed items ({count})', {'count': failures.length}),
      ),
      content: SizedBox(
        width: 520,
        child: ListView.builder(
          shrinkWrap: true,
          itemCount: failures.length,
          itemBuilder: (context, index) {
            final failure = failures[index];
            return Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Icon(
                      Icons.error_outline,
                      size: 16,
                      color: theme.colorScheme.error,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      failure,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ),
                ],
              ),
            );
          },
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(dialogContext),
          child: const LocalizedText('Close'),
        ),
      ],
    );
  },
);
