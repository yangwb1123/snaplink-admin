import 'package:flutter/material.dart';
import 'package:sso_admin/i18n/app_strings.dart';
import 'package:sso_admin/widgets/admin_breadcrumb.dart';
import 'package:sso_admin/widgets/admin_list_header.dart';
import '../admin_module_groups.dart';

/// 工作台页头：面包屑 + 标题/副标题（组件库 AdminListHeader 组装），
/// 刷新按钮按模块组色（connections → security 组 rose）上色。
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
  Widget build(BuildContext context) {
    final accent = adminModuleIconColor('connections');
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const AdminBreadcrumb(),
        AdminListHeader(
          title: title,
          subtitle:
              'Configure a tenant\'s OIDC or SAML upstream and verify its email-domain routing.',
          onRefresh: onRefresh,
          actions: [
            IconButton(
              onPressed: refreshEnabled ? onRefresh : null,
              tooltip: context.strings.refresh,
              icon: Icon(Icons.refresh, color: accent),
            ),
          ],
        ),
      ],
    );
  }
}
