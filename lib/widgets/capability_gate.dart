import 'package:flutter/material.dart';
import 'package:sso_admin/api/snaplink_admin_api.dart';

/// Conditionally shows content based on backend capability availability.
///
/// If the current Snaplink backend supports the given API path,
/// the child widget is shown. Otherwise, a fallback or nothing is shown.
///
/// This prevents showing UI elements for features that the connected
/// backend doesn't support.
class CapabilityGate extends StatelessWidget {
  /// 后端能力快照（探测结果）。
  final SnaplinkAdminCapabilities capabilities;

  /// 目标 API 路径前缀（hasAnyPathPrefix 匹配）。
  final String path;

  /// 能力可用时渲染的内容。
  final Widget child;

  /// 能力不可用时渲染的兜底；null = 不渲染任何内容。
  final Widget? fallback;

  const CapabilityGate({
    super.key,
    required this.capabilities,
    required this.path,
    required this.child,
    this.fallback,
  });

  @override
  Widget build(BuildContext context) {
    final available =
        capabilities.hasAnyPathPrefix(path) ||
        SnaplinkAdminOperationCatalog.hasDocumentedPathPrefix(path);

    if (available) return child;
    return fallback ?? const SizedBox.shrink();
  }
}

/// Shows a feature that requires a specific HTTP method + path capability.
class MethodGate extends StatelessWidget {
  /// 后端能力快照（探测结果）。
  final SnaplinkAdminCapabilities capabilities;

  /// 要求的具体 HTTP 方法（GET/POST/...）。
  final String method;

  /// 要求的具体 API 路径。
  final String path;

  /// 能力可用时渲染的内容。
  final Widget child;

  /// 能力不可用时渲染的兜底；null = 不渲染任何内容。
  final Widget? fallback;

  const MethodGate({
    super.key,
    required this.capabilities,
    required this.method,
    required this.path,
    required this.child,
    this.fallback,
  });

  @override
  Widget build(BuildContext context) {
    final available = capabilities.has(method, path);
    if (available) return child;
    return fallback ?? const SizedBox.shrink();
  }
}
