import 'package:flutter/material.dart';
import 'package:sso_admin/widgets/empty_state.dart';
import 'package:sso_admin/widgets/skeleton_list.dart';
import 'package:sso_admin/i18n/app_strings.dart';

import 'portal_api.dart';
import 'portal_widgets.dart';

/// Account summary + editable display name + editable custom attributes +
/// read-only "Roles and access" disclosure. Ports app.js's `render()` /
/// `renderAttrs()` / `loadAuthz()` and the profile/attrs card markup from
/// index.html into one tab (the JS renders all of this as plain top-of-page
/// cards; grouping it under "Overview" is the only structural change).
///
/// Layout: MFA banner → metric strip → profile card (KvRow + display-name
/// editor) → custom attributes editor → access disclosure. Loading renders
/// SkeletonListTile, failures render a retryable [PortalErrorCard], and
/// empty profile rows render EmptyState (UI review X3/X4/X8).
class OverviewTab extends StatefulWidget {
  final PortalApi api;
  const OverviewTab({super.key, required this.api});

  @override
  State<OverviewTab> createState() => _OverviewTabState();
}

class _OverviewTabState extends State<OverviewTab> {
  bool _loading = true;
  String? _loadError;

  Map<String, dynamic> _me = const {};
  List<dynamic> _roles = const [];
  List<dynamic> _permissions = const [];
  List<dynamic> _menus = const [];

  final TextEditingController _nameCtrl = TextEditingController();
  Map<String, TextEditingController> _attrCtrls = {};
  bool _nameSaving = false;
  String? _nameMsg;
  bool _nameOk = false;

  String? _attrsMsg;
  bool _attrsOk = false;
  bool _attrsSaving = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    for (final c in _attrCtrls.values) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _loadError = null;
    });
    try {
      final me = await widget.api.fetchMe();
      final roles = await widget.api.fetchListOrEmpty('/roles/me', 'roles');
      final permissions = await widget.api.fetchListOrEmpty(
        '/permissions/me',
        'permissions',
      );
      final menus = await widget.api.fetchListOrEmpty('/menus/me', 'menus');

      final user = (me['user'] as Map?) ?? const {};
      _nameCtrl.text = (user['name'] ?? '').toString();

      final rawAttrs = (user['attributes'] as Map?) ?? const {};
      for (final c in _attrCtrls.values) {
        c.dispose();
      }
      _attrCtrls = {
        for (final entry in rawAttrs.entries)
          entry.key.toString(): TextEditingController(
            text: entry.value?.toString() ?? '',
          ),
      };

      if (!mounted) return;
      setState(() {
        _me = me;
        _roles = roles;
        _permissions = permissions;
        _menus = menus;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loadError = e.toString();
        _loading = false;
      });
    }
  }

  Future<void> _saveName() async {
    setState(() {
      _nameSaving = true;
      _nameMsg = null;
    });
    try {
      final response = await widget.api.patch('/me', {'name': _nameCtrl.text});
      if (response.statusCode < 200 || response.statusCode >= 300) {
        setState(() {
          _nameMsg = 'Could not save your display name.';
          _nameOk = false;
        });
        return;
      }
      setState(() {
        _nameMsg = 'Display name saved.';
        _nameOk = true;
      });
      await _load();
    } catch (_) {
      if (mounted) {
        setState(() {
          _nameMsg = 'Could not save your display name.';
          _nameOk = false;
        });
      }
    } finally {
      if (mounted) setState(() => _nameSaving = false);
    }
  }

  Future<void> _saveAttrs() async {
    final attrs = {for (final e in _attrCtrls.entries) e.key: e.value.text};
    setState(() {
      _attrsSaving = true;
      _attrsMsg = null;
    });
    try {
      final r = await widget.api.patch('/me', {'attributes': attrs});
      if (r.statusCode == 404) {
        setState(() {
          _attrsMsg = 'Profile editing is not available.';
          _attrsOk = false;
        });
      } else if (r.statusCode < 200 || r.statusCode >= 300) {
        setState(() {
          _attrsMsg = 'Some attributes could not be saved.';
          _attrsOk = false;
        });
      } else {
        setState(() {
          _attrsMsg = 'Attributes saved.';
          _attrsOk = true;
        });
        await _load();
      }
    } catch (_) {
      setState(() {
        _attrsMsg = 'Request failed.';
        _attrsOk = false;
      });
    } finally {
      if (mounted) setState(() => _attrsSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Text(
                context.strings.overview,
                style: Theme.of(context).textTheme.headlineSmall,
              ),
              const Spacer(),
              IconButton(
                onPressed: _loading ? null : _load,
                icon: const Icon(Icons.refresh),
              ),
            ],
          ),
        ),
        Expanded(
          child: _loading
              ? const SkeletonListTile(itemCount: 4)
              : _loadError != null
              ? PortalErrorCard(message: _loadError!, onRetry: _load)
              : _buildContent(context),
        ),
      ],
    );
  }

  Widget _buildContent(BuildContext context) {
    final user = (_me['user'] as Map?) ?? const {};
    final rows = <MapEntry<String, String>>[
      MapEntry('Subject', _me['sub']?.toString() ?? ''),
      MapEntry('Name', user['name']?.toString() ?? ''),
      MapEntry('Email', user['email']?.toString() ?? ''),
      MapEntry('Active sessions', _me['active_sessions']?.toString() ?? ''),
      MapEntry('Connected apps', _me['granted_apps']?.toString() ?? ''),
    ].where((e) => e.value.isNotEmpty).toList();

    final anyAuthz =
        _roles.isNotEmpty || _permissions.isNotEmpty || _menus.isNotEmpty;

    return ListView(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      children: [
        // 账户摘要（信息优先级：用户 3 秒知道自己的安全状态）。
        PortalSecurityBanner(mfaEnabled: _me['mfa_enabled'] == true),
        const SizedBox(height: 12),
        PortalCard(
          title: 'Profile',
          children: [
            if (rows.isEmpty)
              const EmptyState(
                compact: true,
                icon: Icons.person_outline,
                title: 'No profile data.',
              )
            else
              for (final r in rows) KvRow(r.key, r.value),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _nameCtrl,
                    decoration: InputDecoration(
                      labelText: context.tr('Display name'),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                _saveButton(
                  saving: _nameSaving,
                  onPressed: _saveName,
                  label: 'Save name',
                ),
              ],
            ),
            MessageBanner(_nameMsg, ok: _nameOk),
          ],
        ),
        if (_attrCtrls.isNotEmpty)
          PortalCard(
            title: 'Custom attributes',
            children: [
              for (final entry in _attrCtrls.entries) ...[
                TextField(
                  controller: entry.value,
                  decoration: InputDecoration(labelText: entry.key),
                ),
                const SizedBox(height: 12),
              ],
              Align(
                alignment: Alignment.centerLeft,
                child: _saveButton(
                  saving: _attrsSaving,
                  onPressed: _saveAttrs,
                  label: 'Save attributes',
                ),
              ),
              MessageBanner(_attrsMsg, ok: _attrsOk),
            ],
          ),
        PortalMetricsStrip(
          activeSessions: (_me['active_sessions'] as num?)?.toInt() ?? 0,
          connectedApps: (_me['granted_apps'] as num?)?.toInt() ?? 0,
        ),
        const SizedBox(height: 16),
        if (anyAuthz)
          PortalCard(
            title: 'Roles and access',
            children: [
              if (_roles.isNotEmpty)
                ..._authzSection(
                  'Roles',
                  Icons.badge_outlined,
                  _roles,
                  (m) => m['name'] ?? m['code'],
                  (m) => m['code']?.toString() ?? '',
                ),
              if (_permissions.isNotEmpty)
                ..._authzSection(
                  'Permissions',
                  Icons.key_outlined,
                  _permissions,
                  (m) => m['code'],
                  (m) => m['resource']?.toString() ?? '',
                ),
              if (_menus.isNotEmpty)
                ..._authzSection(
                  'Menu access',
                  Icons.menu_outlined,
                  _menus,
                  (m) => m['name'] ?? m['id'],
                  (m) => m['path']?.toString() ?? '',
                ),
            ],
          ),
      ],
    );
  }

  Widget _saveButton({
    required bool saving,
    required VoidCallback onPressed,
    required String label,
  }) {
    return FilledButton(
      onPressed: saving ? null : onPressed,
      child: saving
          ? const SizedBox(
              height: 16,
              width: 16,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          : Text(context.tr(label)),
    );
  }

  List<Widget> _authzSection(
    String title,
    IconData icon,
    List<dynamic> items,
    Object? Function(Map m) titleOf,
    String Function(Map m) metaOf,
  ) {
    final theme = Theme.of(context);
    return [
      Padding(
        padding: const EdgeInsets.only(top: 8, bottom: 4),
        child: Row(
          children: [
            Icon(icon, size: 16, color: theme.colorScheme.primary),
            const SizedBox(width: 8),
            Text(
              context.tr(title),
              style: theme.textTheme.labelLarge?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
      for (final raw in items)
        PortalAuthzRow(
          icon: icon,
          title: titleOf(raw)?.toString() ?? '',
          meta: metaOf(raw),
        ),
    ];
  }
}
