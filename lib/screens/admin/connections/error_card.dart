import 'package:flutter/material.dart';
import 'package:sso_admin/widgets/async_view.dart';

/// 工作台内联错误区：统一 ErrorStateCard（图标 + 可选中文本 + 重试，X4 模式）。
class ConnectionErrorCard extends StatelessWidget {
  final String error;
  final VoidCallback? onRetry;

  const ConnectionErrorCard({super.key, required this.error, this.onRetry});

  @override
  Widget build(BuildContext context) => ErrorStateCard(
    message: error,
    onRetry: onRetry,
    selectable: true,
    margin: const EdgeInsets.only(top: 16),
  );
}
