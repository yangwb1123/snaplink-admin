import 'package:flutter/material.dart';
import 'package:sso_admin/screens/admin/admin_route.dart';

/// Command palette for quick resource search and navigation.
///
/// Triggered by Ctrl+K (or Cmd+K on Mac). Shows a search dialog
/// where the admin can type to find and navigate to any module,
/// detail page, or action.
///
/// This is a client-side only feature — no API call needed.
class CommandPalette extends StatefulWidget {
  final String currentModule;
  final List<String> allModules;

  const CommandPalette({
    super.key,
    required this.currentModule,
    required this.allModules,
  });

  /// Show the command palette as a dialog.
  static Future<void> show(BuildContext context, {
    required String currentModule,
    required List<String> allModules,
  }) {
    return showDialog(
      context: context,
      builder: (_) => CommandPalette(
        currentModule: currentModule,
        allModules: allModules,
      ),
    );
  }

  @override
  State<CommandPalette> createState() => _CommandPaletteState();
}

class _CommandPaletteState extends State<CommandPalette> {
  final _searchCtrl = TextEditingController();
  final _focusNode = FocusNode();
  List<_CommandItem> _results = [];

  static final List<_CommandItem> _allCommands = [
    _CommandItem('Go to Clients', '/admin/clients', Icons.apps, 'Navigate to client management'),
    _CommandItem('Go to Users', '/admin/users', Icons.person, 'Navigate to user management'),
    _CommandItem('Go to Tenants', '/admin/tenants', Icons.business, 'Navigate to tenant management'),
    _CommandItem('Go to Permissions', '/admin/permissions', Icons.shield, 'Navigate to permission management'),
    _CommandItem('Go to Connections', '/admin/connections', Icons.link, 'Navigate to connection management'),
    _CommandItem('Go to Token Security', '/admin/token-security', Icons.security, 'Token and session security'),
    _CommandItem('Go to Governance', '/admin/governance', Icons.verified_user, 'Governance and compliance'),
    _CommandItem('Go to Webhooks', '/admin/webhooks', Icons.webhook, 'Webhook management'),
    _CommandItem('Go to Emergency Access', '/admin/emergency-access', Icons.warning_amber, 'Break-glass access'),
    _CommandItem('Go to Crypto Keys', '/admin/crypto-keys', Icons.vpn_key, 'Crypto key management'),
    _CommandItem('Go to Credentials', '/admin/credentials', Icons.badge, 'Credential management'),
    _CommandItem('Go to Domains', '/admin/domains', Icons.language, 'Domain management'),
    _CommandItem('Go to Audit Log', '/admin/audit-log', Icons.receipt_long, 'Operation audit log'),
    _CommandItem('Go to Settings', '/settings', Icons.settings, 'Application settings'),
    _CommandItem('Create New Client', '/admin/clients/new', Icons.add_circle, 'Register a new OIDC client'),
    _CommandItem('Add Domain', '/admin/domains/new', Icons.add, 'Register a new email domain'),
    _CommandItem('Report Credential Compromise', '/admin/credentials/report', Icons.warning, 'Report compromised credentials'),
    _CommandItem('Rotate Crypto Keys', '/admin/crypto-keys/rotate', Icons.refresh, 'Rotate all crypto keys'),
  ];

  @override
  void initState() {
    super.initState();
    _results = _allCommands;
    _focusNode.requestFocus();
    _searchCtrl.addListener(_onSearchChanged);
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  void _onSearchChanged() {
    final query = _searchCtrl.text.trim().toLowerCase();
    setState(() {
      if (query.isEmpty) {
        _results = _allCommands;
      } else {
        _results = _allCommands.where((cmd) =>
          cmd.title.toLowerCase().contains(query) ||
          cmd.description.toLowerCase().contains(query) ||
          cmd.path.toLowerCase().contains(query)
        ).toList();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      contentPadding: EdgeInsets.zero,
      clipBehavior: Clip.antiAlias,
      content: SizedBox(
        width: 500,
        height: 400,
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(12),
              child: TextField(
                controller: _searchCtrl,
                focusNode: _focusNode,
                autofocus: true,
                decoration: InputDecoration(
                  hintText: 'Search commands...',
                  prefixIcon: const Icon(Icons.search),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                  isDense: true,
                  contentPadding: const EdgeInsets.symmetric(vertical: 8),
                ),
              ),
            ),
            const Divider(height: 1),
            Expanded(
              child: ListView.builder(
                itemCount: _results.length,
                itemBuilder: (_, i) {
                  final cmd = _results[i];
                  return ListTile(
                    leading: Icon(cmd.icon, size: 20),
                    title: Text(cmd.title, style: const TextStyle(fontSize: 14)),
                    subtitle: Text(cmd.path, style: const TextStyle(fontSize: 11, color: Colors.grey)),
                    dense: true,
                    onTap: () {
                      Navigator.pop(context);
                      AdminRoute.go(cmd.routeModule,
                        resourceId: cmd.routeId,
                        action: cmd.routeAction,
                        subresource: cmd.routeSubresource,
                      );
                    },
                  );
                },
              ),
            ),
            Container(
              padding: const EdgeInsets.all(8),
              color: Colors.grey.shade100,
              child: Text(
                'Type to search · ${_results.length} commands',
                style: const TextStyle(fontSize: 11, color: Colors.grey),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CommandItem {
  final String title;
  final String path;
  final IconData icon;
  final String description;

  const _CommandItem(this.title, this.path, this.icon, this.description);

  String get routeModule {
    final parts = path.replaceFirst('/admin/', '').split('/');
    return parts[0];
  }

  String get routeId {
    final parts = path.replaceFirst('/admin/', '').split('/');
    if (parts.length >= 2 && !['new', 'report', 'rotate'].contains(parts[1])) {
      return parts[1];
    }
    return '';
  }

  String get routeAction {
    final parts = path.replaceFirst('/admin/', '').split('/');
    if (parts.last == 'new') return 'new';
    return '';
  }

  String get routeSubresource {
    final parts = path.replaceFirst('/admin/', '').split('/');
    if (parts.length >= 2 && !['new', 'rotate'].contains(parts[1]) && parts[1] != routeId) {
      return parts[1];
    }
    if (parts.last == 'report' || parts.last == 'rotate') return parts.last;
    return '';
  }
}
