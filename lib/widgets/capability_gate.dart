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
  final SnaplinkAdminCapabilities capabilities;
  final String path;
  final Widget child;
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
  final SnaplinkAdminCapabilities capabilities;
  final String method;
  final String path;
  final Widget child;
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
