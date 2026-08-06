import 'package:flutter/material.dart';
import 'package:sso_admin/i18n/localized_text.dart';
import 'package:sso_admin/api/snaplink_admin_api.dart';
import 'package:sso_admin/services/browser_navigation.dart';
import 'package:sso_admin/widgets/confirm_dialog.dart';
import 'package:sso_admin/widgets/admin_breadcrumb.dart';
import 'admin_route.dart';
import 'package:sso_admin/i18n/app_strings.dart';
import 'package:sso_admin/widgets/skeleton_list.dart';

/// Threat detection policy management tab.
/// URLs: /admin/threat-policies, /admin/threat-policies/new, /admin/threat-policies/{id}/edit
class ThreatPoliciesTab extends StatefulWidget {
  final SnaplinkAdminApi api;
  final SnaplinkAdminCapabilities capabilities;
  const ThreatPoliciesTab({
    super.key,
    required this.api,
    required this.capabilities,
  });
  @override
  State<ThreatPoliciesTab> createState() => _ThreatPoliciesTabState();
}

class _ThreatPoliciesTabState extends State<ThreatPoliciesTab> {
  static const _path = '/api/v1/admin/threat-policies';
  List<Map<String, dynamic>> _policies = const [];
  String? _error;
  bool _loading = false;
  bool _mutating = false;
  late final void Function() _cancelPopState;

  bool get _available => widget.capabilities.hasAnyPathPrefix(_path);
  @override
  void initState() {
    super.initState();
    _load();
    _cancelPopState = BrowserNavigation.listenToLocationChange(() {
      if (mounted) _handleRoute();
    });
  }

  bool _editing = false;
  bool _creating = false;
  final _nameCtrl = TextEditingController();
  final _descCtrl = TextEditingController();
  final _rulesCtrl = TextEditingController();
  String? _editId;

  void _handleRoute() {
    final route = AdminRoute.current();
    _creating = route.isNew;
    _editing = route.isEdit;
    _editId = route.resourceId;
    if (_creating) {
      _nameCtrl.clear();
      _descCtrl.clear();
      _rulesCtrl.clear();
    }
    if (_editing && _editId != null) {
      final existing = _policies
          .where((p) => p['id']?.toString() == _editId)
          .firstOrNull;
      if (existing != null) {
        _nameCtrl.text = existing['name']?.toString() ?? '';
        _descCtrl.text = existing['description']?.toString() ?? '';
        _rulesCtrl.text =
            existing['rules']?.toString() ??
            existing['config']?.toString() ??
            '';
      }
    }
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _cancelPopState();
    _nameCtrl.dispose();
    _descCtrl.dispose();
    _rulesCtrl.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final data = await widget.api.get(_path);
      final items = data['policies'] as List? ?? [];
      if (!mounted) return;
      setState(() {
        _policies = items
            .map((e) => Map<String, dynamic>.from(e as Map))
            .toList();
        _loading = false;
        _handleRoute();
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
          _error = 'Could not load threat policies.';
          _loading = false;
        });
      }
    }
  }

  Future<void> _save() async {
    final name = _nameCtrl.text.trim();
    if (name.isEmpty) {
      setState(() => _error = 'Enter a policy name.');
      return;
    }
    final body = {
      'name': name,
      'description': _descCtrl.text.trim(),
      'rules': _rulesCtrl.text.trim(),
    };
    setState(() => _mutating = true);
    try {
      final pathName = _editing && _editId != null ? _editId! : name;
      await widget.api.put('$_path/${Uri.encodeComponent(pathName)}', body);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: LocalizedText(
            _editing ? 'Policy updated.' : 'Policy created.',
          ),
        ),
      );
      if (mounted) AdminRoute.go('threat-policies');
      await _load();
    } on SnaplinkAdminApiError catch (e) {
      if (mounted) setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _mutating = false);
    }
  }

  Future<void> _delete(String id) async {
    final confirmed = await ConfirmDialog.show(
      context,
      title: 'Delete policy?',
      message: 'Delete this threat policy?',
      confirmLabel: 'Delete',
      destructive: true,
      confirmText: id,
    );
    if (!confirmed) return;
    setState(() => _mutating = true);
    try {
      await widget.api.delete('$_path/${Uri.encodeComponent(id)}');
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: LocalizedText('Policy deleted.')));
      await _load();
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
        child: LocalizedText('Threat policy management is not enabled.'),
      );
    }
    if (_creating || _editing) return _buildForm(context);
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        AdminBreadcrumb(),
        Row(
          children: [
            Text(
              AppStrings.of(context).threatPolicies,
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
            child: Row(
              children: [
                Expanded(
                  child: LocalizedText(
                    _error!,
                    style: const TextStyle(color: Colors.redAccent),
                  ),
                ),
                TextButton.icon(
                  onPressed: _load,
                  icon: const Icon(Icons.refresh, size: 18),
                  label: const LocalizedText('Retry'),
                ),
              ],
            ),
          ),
        if (_loading) const SkeletonListTile(itemCount: 3),
        if (!_loading && _policies.isEmpty)
          const Padding(
            padding: EdgeInsets.only(top: 12),
            child: LocalizedText('No threat policies configured.'),
          ),
        if (!_loading) ...[
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: FilledButton.icon(
              onPressed: () => AdminRoute.go('threat-policies', action: 'new'),
              icon: const Icon(Icons.add),
              label: const LocalizedText('New policy'),
            ),
          ),
          for (final p in _policies)
            Card(
              margin: const EdgeInsets.only(bottom: 8),
              child: ListTile(
                leading: Icon(
                  Icons.shield,
                  color: p['enabled'] == true ? Colors.green : Colors.grey,
                ),
                title: Text(p['name']?.toString() ?? ''),
                subtitle: LocalizedText(
                  '${p['description']?.toString() ?? ''}\n${p['id'] ?? ''}',
                ),
                isThreeLine: true,
                onTap: () => AdminRoute.go(
                  'threat-policies',
                  resourceId: p['name']?.toString() ?? '',
                  action: 'edit',
                ),
                trailing: TextButton(
                  onPressed: () => _delete(p['name']?.toString() ?? ''),
                  style: TextButton.styleFrom(
                    foregroundColor: Colors.redAccent,
                  ),
                  child: const LocalizedText('Delete'),
                ),
              ),
            ),
        ],
      ],
    );
  }

  Widget _buildForm(BuildContext context) => ListView(
    padding: const EdgeInsets.all(16),
    children: [
      AdminBreadcrumb(),
      LocalizedText(
        _editing ? 'Edit policy' : 'New policy',
        style: Theme.of(context).textTheme.headlineSmall,
      ),
      const SizedBox(height: 16),
      TextField(
        controller: _nameCtrl,
        decoration: InputDecoration(labelText: 'Name'.localized),
      ),
      const SizedBox(height: 12),
      TextField(
        controller: _descCtrl,
        decoration: InputDecoration(labelText: 'Description'.localized),
        maxLines: 2,
      ),
      const SizedBox(height: 12),
      TextField(
        controller: _rulesCtrl,
        decoration: InputDecoration(labelText: 'Rules / Config'.localized),
        maxLines: 4,
      ),
      const SizedBox(height: 16),
      OverflowBar(
        children: [
          OutlinedButton(
            onPressed: () => AdminRoute.go('threat-policies'),
            child: const LocalizedText('Cancel'),
          ),
          const SizedBox(width: 8),
          FilledButton(
            onPressed: _mutating ? null : _save,
            child: LocalizedText(_editing ? 'Update' : 'Create'),
          ),
        ],
      ),
      if (_error != null)
        Padding(
          padding: const EdgeInsets.only(top: 8),
          child: LocalizedText(
            _error!,
            style: const TextStyle(color: Colors.redAccent),
          ),
        ),
    ],
  );
}
