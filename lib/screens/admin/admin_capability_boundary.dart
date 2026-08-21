import 'package:flutter/material.dart';
import 'package:sso_admin/i18n/app_strings.dart';
import 'package:sso_admin/api/snaplink_admin_api.dart';
import 'package:sso_admin/widgets/async_view.dart';
import 'package:sso_admin/widgets/empty_state.dart';

/// Shared boundary for optional admin screens.
///
/// A capability request has three materially different outcomes: the route is
/// advertised, the route is known to be absent, or the inventory could not be
/// read yet. Keeping those states here prevents pages from treating an empty
/// or stale inventory as a safe signal to issue reads or writes.
class AdminCapabilityBoundary extends StatelessWidget {
  final SnaplinkAdminCapabilitySnapshot? snapshot;
  final String pathPrefix;
  final VoidCallback? onRetry;
  final WidgetBuilder builder;

  const AdminCapabilityBoundary({
    super.key,
    required this.snapshot,
    required this.pathPrefix,
    required this.builder,
    this.onRetry,
  });

  @override
  Widget build(BuildContext context) {
    final current = snapshot;
    if (current == null ||
        current.stateForAnyPathPrefix(pathPrefix) ==
            SnaplinkAdminCapabilityState.available) {
      return builder(context);
    }

    if (current.runtimeInventoryLoading) {
      return AsyncView<void>(
        loading: true,
        dataBuilder: (_) => const SizedBox.shrink(),
      );
    }

    if (!current.runtimeInventoryAvailable) {
      return ErrorStateView(
        title: 'Capability inventory is unavailable',
        message: context.strings.networkErrorRetry,
        onRetry: onRetry,
      );
    }

    return const EmptyState(variant: EmptyStateVariant.notEnabled);
  }
}
