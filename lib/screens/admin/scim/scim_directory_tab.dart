import 'package:flutter/material.dart';
import 'package:sso_admin/i18n/localized_text.dart';
import 'package:sso_admin/i18n/app_strings.dart';
import 'package:sso_admin/api/snaplink_admin_api.dart';
import 'package:sso_admin/widgets/admin_breadcrumb.dart';
import 'package:sso_admin/widgets/empty_state.dart';

import '../admin_module_groups.dart';
import 'scim_bulk_panel.dart';
import 'scim_discovery_panel.dart';
import 'scim_models.dart';
import 'scim_resource_browser.dart';

/// Contract-first SCIM 2.0 directory operations.
///
/// Snaplink mounts this surface behind the admin middleware: reads require
/// `admin:read`, while provisioning mutations require `admin:write`.
class ScimDirectoryTab extends StatelessWidget {
  final SnaplinkAdminApi api;
  final SnaplinkAdminCapabilities capabilities;

  const ScimDirectoryTab({
    super.key,
    required this.api,
    required this.capabilities,
  });

  bool get _advertised =>
      capabilities.hasAnyPathPrefix(scimBasePath) ||
      SnaplinkAdminOperationCatalog.hasDocumentedPathPrefix(scimBasePath);

  @override
  Widget build(BuildContext context) {
    if (!_advertised) {
      return const EmptyState(
        variant: EmptyStateVariant.notEnabled,
        title: 'SCIM 2.0 is not advertised by this deployment.',
      );
    }
    final accent = adminModuleIconColor('scim-directory');
    return DefaultTabController(
      length: 4,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const AdminBreadcrumb(overrideModule: 'SCIM Directory'),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                CircleAvatar(
                  backgroundColor: Theme.of(
                    context,
                  ).colorScheme.primaryContainer,
                  child: Icon(Icons.account_tree_outlined, color: accent),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Semantics(
                        container: true,
                        header: true,
                        child: LocalizedText(
                          'SCIM 2.0 Directory',
                          style: Theme.of(context).textTheme.headlineSmall,
                        ),
                      ),
                      const SizedBox(height: 4),
                      const LocalizedText(
                        'Discover provider capabilities, reconcile users and '
                        'groups, and run bounded provisioning batches.',
                      ),
                    ],
                  ),
                ),
                const Chip(
                  avatar: Icon(Icons.admin_panel_settings_outlined, size: 16),
                  label: LocalizedText('admin:read / admin:write'),
                ),
              ],
            ),
          ),
          TabBar(
            isScrollable: true,
            tabs: [
              Tab(
                icon: Icon(Icons.info_outline, color: accent),
                text: context.tr('Overview'),
              ),
              Tab(
                icon: Icon(Icons.people_outline, color: accent),
                text: context.tr('Users'),
              ),
              Tab(
                icon: Icon(Icons.groups_outlined, color: accent),
                text: context.tr('Groups'),
              ),
              Tab(
                icon: Icon(Icons.layers_outlined, color: accent),
                text: context.tr('Bulk'),
              ),
            ],
          ),
          Expanded(
            child: TabBarView(
              children: [
                ScimDiscoveryPanel(api: api),
                ScimResourceBrowser(api: api, kind: ScimResourceKind.users),
                ScimResourceBrowser(api: api, kind: ScimResourceKind.groups),
                ScimBulkPanel(api: api),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
