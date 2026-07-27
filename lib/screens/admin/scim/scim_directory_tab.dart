import 'package:flutter/material.dart';
import 'package:sso_admin/api/snaplink_admin_api.dart';
import 'package:sso_admin/widgets/admin_breadcrumb.dart';

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
      return const Center(
        child: Text('SCIM 2.0 is not advertised by this deployment.'),
      );
    }
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
                  child: const Icon(Icons.account_tree_outlined),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'SCIM 2.0 Directory',
                        style: Theme.of(context).textTheme.headlineSmall,
                      ),
                      const SizedBox(height: 2),
                      const Text(
                        'Discover provider capabilities, reconcile users and '
                        'groups, and run bounded provisioning batches.',
                      ),
                    ],
                  ),
                ),
                const Chip(
                  avatar: Icon(Icons.admin_panel_settings_outlined, size: 16),
                  label: Text('admin:read / admin:write'),
                ),
              ],
            ),
          ),
          const TabBar(
            isScrollable: true,
            tabs: [
              Tab(icon: Icon(Icons.info_outline), text: 'Overview'),
              Tab(icon: Icon(Icons.people_outline), text: 'Users'),
              Tab(icon: Icon(Icons.groups_outlined), text: 'Groups'),
              Tab(icon: Icon(Icons.layers_outlined), text: 'Bulk'),
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
