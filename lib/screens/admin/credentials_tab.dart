import 'package:flutter/material.dart';
import 'package:sso_admin/i18n/localized_text.dart';
import 'package:sso_admin/api/snaplink_admin_api.dart';
import 'package:sso_admin/services/browser_navigation.dart';
import 'package:sso_admin/widgets/confirm_dialog.dart';
import 'package:sso_admin/widgets/admin_breadcrumb.dart';
import 'package:sso_admin/widgets/skeleton_list.dart';
import 'admin_route.dart';
import 'package:sso_admin/i18n/app_strings.dart';

/// Credential rotation inventory and compromise reporting tab.
/// URL: /admin/credentials[/report]
class CredentialsTab extends StatefulWidget {
  final SnaplinkAdminApi api;
  final SnaplinkAdminCapabilities capabilities;

  const CredentialsTab({
    super.key,
    required this.api,
    required this.capabilities,
  });

  @override
  State<CredentialsTab> createState() => _CredentialsTabState();
}

class _CredentialsTabState extends State<CredentialsTab> {
  static const _credsPath = '/api/v1/admin/credentials';

  List<Map<String, dynamic>> _credentials = const [];
  String? _error;
  bool _loading = false;
  bool _mutating = false;
  bool _showReportForm = false;
  final _typeCtrl = TextEditingController();
  late final void Function() _cancelPopState;

  bool get _available =>
      widget.capabilities.hasAnyPathPrefix(_credsPath) ||
      SnaplinkAdminOperationCatalog.hasDocumentedPathPrefix(_credsPath);

  @override
  void initState() {
    super.initState();
    _load();
    _handleRoute();
    _cancelPopState = BrowserNavigation.listenToLocationChange(() {
      if (mounted) _handleRoute();
    });
  }

  @override
  void dispose() {
    _cancelPopState();
    _typeCtrl.dispose();
    super.dispose();
  }

  void _handleRoute() {
    final route = AdminRoute.current();
    setState(() => _showReportForm = route.subresource == 'report');
  }

  Future<void> _load() async {
    widget.api.skipCache();
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final data = await widget.api.get(_credsPath);
      final items =
          data['credentials'] as List? ?? data['items'] as List? ?? [];
      if (!mounted) return;
      setState(() {
        _credentials = items
            .map((e) => Map<String, dynamic>.from(e as Map))
            .toList();
        _loading = false;
      });
    } on SnaplinkAdminApiError catch (e) {
      if (mounted) {
        setState(() {
          _error = e.toString();
          _loading = false;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _error = 'Could not load credentials.';
          _loading = false;
        });
      }
    }
  }

  Future<void> _reportCompromise() async {
    final type = _typeCtrl.text.trim();
    if (type.isEmpty) {
      setState(() => _error = 'Enter a credential type.');
      return;
    }
    final confirmed = await ConfirmDialog.show(
      context,
      title: 'Report compromise?',
      message: 'Report $type credentials as compromised?',
      confirmLabel: 'Report',
      destructive: true,
      confirmText: type,
    );
    if (!confirmed) return;
    setState(() {
      _mutating = true;
      _error = null;
    });
    try {
      await widget.api.post(
        '/api/v1/admin/credentials/${Uri.encodeComponent(type)}/compromise',
      );
      if (!mounted) return;
      _typeCtrl.clear();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: LocalizedText('Compromise reported.')),
      );
    } on SnaplinkAdminApiError catch (e) {
      if (mounted) setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _mutating = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!_available) {
      return const Center(
        child: LocalizedText(
          'Credential management is not enabled on this replica.',
        ),
      );
    }
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        AdminBreadcrumb(),
        Row(
          children: [
            Text(
              AppStrings.of(context).credentials,
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            const Spacer(),
            IconButton(
              onPressed: _loading ? null : _load,
              icon: const Icon(Icons.refresh),
              tooltip: 'Refresh'.localized,
            ),
          ],
        ),
        if (_error != null)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Text(
              _error!,
              style: const TextStyle(color: Colors.redAccent),
            ),
          ),
        if (_showReportForm) _buildReportForm(context),
        const SizedBox(height: 16),
        LocalizedText(
          'Rotation inventory',
          style: Theme.of(context).textTheme.titleMedium,
        ),
        if (_loading) const SkeletonListTile(itemCount: 4),
        if (!_loading && _credentials.isEmpty && !_showReportForm)
          const Padding(
            padding: EdgeInsets.only(top: 12),
            child: LocalizedText('No credentials found.'),
          ),
        if (!_loading)
          for (final c in _credentials)
            Card(
              margin: const EdgeInsets.only(top: 8),
              child: ListTile(
                leading: Icon(
                  Icons.vpn_key,
                  color: c['status'] == 'active' ? Colors.green : Colors.orange,
                ),
                title: Text(
                  c['type']?.toString() ??
                      c['credential_type']?.toString() ??
                      '',
                ),
                subtitle: LocalizedText(
                  '${c['id'] ?? ''}\nstatus: ${c['status'] ?? 'unknown'} · rotated: ${c['rotated_at'] ?? c['last_rotated'] ?? 'never'}',
                ),
                isThreeLine: true,
                onTap: () => AdminRoute.go('credentials'),
              ),
            ),
        if (!_showReportForm)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: OutlinedButton.icon(
              onPressed: () =>
                  AdminRoute.go('credentials', subresource: 'report'),
              icon: const Icon(Icons.warning),
              label: const LocalizedText('Report compromise'),
            ),
          ),
      ],
    );
  }

  Widget _buildReportForm(BuildContext context) => Card(
    child: Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          LocalizedText(
            'Report credential compromise',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _typeCtrl,
            decoration: InputDecoration(
              labelText: 'Credential type'.localized,
              hintText: 'client_secret, signing_key, etc.'.localized,
            ),
          ),
          const SizedBox(height: 12),
          OverflowBar(
            children: [
              OutlinedButton(
                onPressed: () => AdminRoute.go('credentials'),
                child: const LocalizedText('Cancel'),
              ),
              const SizedBox(width: 8),
              FilledButton(
                onPressed: _mutating ? null : _reportCompromise,
                child: const LocalizedText('Report compromise'),
              ),
            ],
          ),
        ],
      ),
    ),
  );
}
