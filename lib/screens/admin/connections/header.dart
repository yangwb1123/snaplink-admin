import 'package:flutter/material.dart';
import 'package:sso_admin/i18n/localized_text.dart';
import 'package:sso_admin/widgets/admin_breadcrumb.dart';

class ConnectionWorkspaceHeader extends StatelessWidget {
  final String title;
  final bool refreshEnabled;
  final VoidCallback onRefresh;

  const ConnectionWorkspaceHeader({
    super.key,
    required this.title,
    required this.refreshEnabled,
    required this.onRefresh,
  });

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Row(
        children: [
          AdminBreadcrumb(),
          LocalizedText(
            title,
            style: Theme.of(context).textTheme.headlineSmall,
          ),
          const Spacer(),
          IconButton(
            onPressed: refreshEnabled ? onRefresh : null,
            tooltip: 'Refresh connection list'.localized,
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      const SizedBox(height: 4),
      const LocalizedText(
        'Configure a tenant\'s OIDC or SAML upstream and verify its email-domain routing.',
      ),
    ],
  );
}
