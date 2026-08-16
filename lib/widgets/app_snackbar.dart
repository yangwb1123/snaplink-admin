import 'package:flutter/material.dart';
import 'package:sso_admin/theme/app_colors.dart';

/// 全站 SnackBar 统一反馈入口（R26 约定）。
///
/// 写操作/复制/导出的 toast 一律经本函数发出，保证：
/// - 样式统一：成功 = check 图标 + emerald 系；错误 = error 图标 + red 系；
///   图标色按主题亮度取同族变体（浅色模式 snackbar 底为深色
///   inverseSurface，深色模式底为浅色 → 反相选择亮/暗变体，非文本
///   对比 ≥3:1，见 app_colors.dart 注释）；
/// - 防堆积：显示前先 [ScaffoldMessengerState.hideCurrentSnackBar]，
///   快速连续操作只呈现最新一条，不排队堆积；
/// - 时长：默认 4s；复制类轻提示由调用方显式传 1s；批量失败明细 8s。
/// 图标不设语义标签：SnackBar 文案本身由读屏播报，图标不产生额外噪声。
void showAppSnackBar(
  BuildContext context, {
  required Widget content,
  AppSnackBarKind kind = AppSnackBarKind.success,
  Duration? duration,
  SnackBarAction? action,
}) {
  final messenger = ScaffoldMessenger.of(context);
  messenger.hideCurrentSnackBar();
  messenger.showSnackBar(
    SnackBar(
      content: _AppSnackBarContent(kind: kind, child: content),
      duration: duration ?? const Duration(seconds: 4),
      action: action,
    ),
  );
}

/// 复制类轻提示统一入口（R63）：与 [showAppSnackBar] 同款成功样式，
/// 固定 1s 轻提示时长（R26 约定：复制反馈不排队、不常驻）。
/// 全站复制反馈（CopyableCell / InfoRow / 凭据与密钥复制 / JSON 复制）
/// 一律走本函数，保证时长与样式一致。
void showCopySnackBar(BuildContext context, {required Widget content}) {
  showAppSnackBar(
    context,
    content: content,
    duration: const Duration(seconds: 1),
  );
}

/// 反馈语义：成功（写操作完成/复制/导出）与错误（写操作失败/未确认）。
enum AppSnackBarKind { success, error }

class _AppSnackBarContent extends StatelessWidget {
  const _AppSnackBarContent({required this.kind, required this.child});

  final AppSnackBarKind kind;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final (icon, color) = switch (kind) {
      AppSnackBarKind.success => (
        Icons.check_circle_outline,
        isDark ? AppColors.successDark : AppColors.success,
      ),
      AppSnackBarKind.error => (
        Icons.error_outline,
        isDark ? AppColors.dangerDark : AppColors.dangerOnInverse,
      ),
    };
    return Row(
      children: [
        Icon(icon, size: 20, color: color),
        const SizedBox(width: 8),
        Expanded(child: child),
      ],
    );
  }
}
