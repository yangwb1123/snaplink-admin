import 'package:flutter/material.dart';
import 'package:sso_admin/i18n/app_strings.dart';
import 'package:sso_admin/widgets/empty_state.dart';
import 'package:sso_admin/widgets/skeleton_list.dart';

import 'dcr_form_controller.dart';
import 'dcr_metadata_form.dart';
import 'dcr_models.dart';

/// RFC 7592 manage-surface presentation for the Developer Manage tab.
///
/// Hosts the lossless round-trip banner ([DcrRoundTripNotice]) plus the
/// shared chrome of the manage flow: branded intro ([ManageIntro]),
/// load-failure banner ([ManageErrorBanner]), in-button progress
/// ([ManageInlineSpinner]), the loading/empty/error three-state view
/// ([ManageStatusArea]) and the editable management card
/// ([ManageFormCard]).
class DcrRoundTripNotice extends StatelessWidget {
  final DcrRoundTripSafety safety;

  const DcrRoundTripNotice({super.key, required this.safety});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final safe = safety.canSafelyUpdate;
    final foreground = safe
        ? scheme.onSecondaryContainer
        : scheme.onErrorContainer;
    final background = safe ? scheme.secondaryContainer : scheme.errorContainer;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: foreground.withValues(alpha: 0.25)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: foreground.withValues(alpha: 0.14),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(
              safe ? Icons.verified_outlined : Icons.warning_amber_outlined,
              color: foreground,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  context.tr(
                    safe
                        ? 'Lossless RFC 7592 representation'
                        : 'Saving disabled: incomplete RFC 7592 representation',
                  ),
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                    color: foreground,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 8),
                if (safe)
                  Text(
                    context.tr(
                      'Every typed field round-trips through the RFC 7592 PUT.',
                    ),
                    style: Theme.of(
                      context,
                    ).textTheme.bodySmall?.copyWith(color: foreground),
                  )
                else
                  ..._roundTripWarnings(context, safety.warnings, foreground),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

List<Widget> _roundTripWarnings(
  BuildContext context,
  List<String> warnings,
  Color foreground,
) => [
  for (final warning in warnings)
    Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.info_outline, size: 14, color: foreground),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              context.tr(warning),
              style: TextStyle(color: foreground),
            ),
          ),
        ],
      ),
    ),
];

/// Branded banner for the manage tab: icon tile + RFC 7592 management
/// posture (RAT-authenticated read/update/delete of a registered client).
class ManageIntro extends StatelessWidget {
  const ManageIntro({super.key});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            scheme.primary.withValues(alpha: 0.12),
            scheme.primary.withValues(alpha: 0.03),
          ],
        ),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: scheme.primary.withValues(alpha: 0.25)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: scheme.primary.withValues(alpha: 0.14),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(Icons.manage_accounts_outlined, color: scheme.primary),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  context.tr('Manage an existing OAuth 2.0 / OIDC client'),
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                    color: scheme.onSurface,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  context.tr(
                    'Load a registered client with the registration access '
                    'token issued during registration, then read, update, or '
                    'delete it through RFC 7592.',
                  ),
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: scheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Load-failure banner: error container + severity icon; credential errors
/// get a key-off icon, transport/retryable failures a cloud-off icon.
class ManageErrorBanner extends StatelessWidget {
  final String message;
  final bool credential;

  const ManageErrorBanner({
    super.key,
    required this.message,
    required this.credential,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: scheme.errorContainer,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Semantics(
        liveRegion: true,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(
              credential ? Icons.key_off_outlined : Icons.cloud_off_outlined,
              size: 20,
              color: scheme.onErrorContainer,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                context.tr(message),
                style: TextStyle(color: scheme.onErrorContainer),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Compact in-button progress indicator shared by load/save/delete.
class ManageInlineSpinner extends StatelessWidget {
  const ManageInlineSpinner({super.key});

  @override
  Widget build(BuildContext context) {
    return const SizedBox(
      height: 18,
      width: 18,
      child: CircularProgressIndicator(strokeWidth: 2),
    );
  }
}

/// Editable RFC 7592 management card: metadata form with the lossless
/// round-trip gate, then save (PUT) and delete (DELETE) actions.
class ManageFormCard extends StatelessWidget {
  final DcrFormController controller;
  final DcrDiscovery? discovery;
  final DcrRoundTripSafety safety;
  final bool saving;
  final bool deleting;
  final VoidCallback onSave;
  final VoidCallback onDelete;
  final VoidCallback onChanged;

  const ManageFormCard({
    super.key,
    required this.controller,
    this.discovery,
    required this.safety,
    required this.saving,
    required this.deleting,
    required this.onSave,
    required this.onDelete,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            DcrMetadataForm(
              controller: controller,
              discovery: discovery,
              managementMode: true,
              roundTripSafety: safety,
              onChanged: onChanged,
            ),
            const SizedBox(height: 20),
            FilledButton(
              onPressed: saving || deleting || !safety.canSafelyUpdate
                  ? null
                  : onSave,
              child: saving
                  ? const ManageInlineSpinner()
                  : Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.save_outlined, size: 18),
                        const SizedBox(width: 8),
                        Text(context.tr('Save Changes')),
                      ],
                    ),
            ),
            const SizedBox(height: 12),
            OutlinedButton(
              onPressed: saving || deleting ? null : onDelete,
              style: OutlinedButton.styleFrom(foregroundColor: scheme.error),
              child: deleting
                  ? const ManageInlineSpinner()
                  : Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.delete_outline, size: 18),
                        const SizedBox(width: 8),
                        Text(context.tr(deleting ? 'Deleting…' : 'Delete App')),
                      ],
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Loading / empty / error states shown while no app is loaded yet.
class ManageStatusArea extends StatelessWidget {
  final bool loading;
  final String? loadError;
  final bool credentialError;

  const ManageStatusArea({
    super.key,
    required this.loading,
    this.loadError,
    this.credentialError = false,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    if (loading) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 32),
        child: Column(
          children: [
            // R38：数据加载统一骨架（与列表页一致），保留 loading 文案语义。
            const SkeletonListTile(itemCount: 2),
            const SizedBox(height: 12),
            Text(
              context.tr('Loading app…'),
              style: Theme.of(
                context,
              ).textTheme.bodySmall?.copyWith(color: scheme.onSurfaceVariant),
            ),
          ],
        ),
      );
    }
    if (loadError != null) {
      return ManageErrorBanner(
        message: loadError!,
        credential: credentialError,
      );
    }
    return const EmptyState(
      compact: true,
      icon: Icons.manage_search_outlined,
      title: 'No app loaded',
      subtitle:
          'Enter the client ID and registration access token issued at '
          'registration to load the app for management.',
    );
  }
}
