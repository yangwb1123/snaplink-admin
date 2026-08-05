import 'package:flutter/material.dart';
import 'package:sso_admin/i18n/localized_text.dart';
import 'package:sso_admin/api/snaplink_admin_api.dart';
import 'package:sso_admin/widgets/admin_breadcrumb.dart';
import 'package:sso_admin/widgets/async_view.dart';
import 'package:sso_admin/widgets/confirm_dialog.dart';

import 'local_user_validation.dart';

/// Password-authenticated directory users.
///
/// This is intentionally separate from the federated `/admin/users` surface:
/// local users own a username and password credential while federated users do
/// not. Mixing the two models makes password reset and identity-source status
/// ambiguous for operators.
class LocalUsersTab extends StatefulWidget {
  final SnaplinkAdminApi api;
  final SnaplinkAdminCapabilities capabilities;

  const LocalUsersTab({
    super.key,
    required this.api,
    required this.capabilities,
  });

  @override
  State<LocalUsersTab> createState() => _LocalUsersTabState();
}

class _LocalUsersTabState extends State<LocalUsersTab> {
  static const _basePath = '/api/v1/admin/local-users';
  static const _pageSize = 25;

  List<Map<String, dynamic>> _users = const [];
  String? _error;
  int _page = 1;
  int _total = 0;
  bool _loading = false;
  bool _mutating = false;

  bool get _available =>
      widget.capabilities.hasAnyPathPrefix(_basePath) ||
      SnaplinkAdminOperationCatalog.hasDocumentedPathPrefix(_basePath);

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load({int? page}) async {
    if (!_available) return;
    final target = page ?? _page;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final data = await widget.api.get(
        _basePath,
        query: {'page': '$target', 'limit': '$_pageSize'},
      );
      final values = data['users'] as List? ?? const [];
      if (!mounted) return;
      setState(() {
        _page = target;
        _total = (data['total'] as num?)?.toInt() ?? values.length;
        _users = values
            .whereType<Map>()
            .map((item) => Map<String, dynamic>.from(item))
            .toList(growable: false);
      });
    } on SnaplinkAdminApiError catch (error) {
      if (mounted) setState(() => _error = error.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _openForm([Map<String, dynamic>? existing]) async {
    final draft = await showDialog<_LocalUserDraft>(
      context: context,
      builder: (_) => _LocalUserDialog(existing: existing),
    );
    if (draft == null || !mounted) return;
    setState(() => _mutating = true);
    try {
      if (existing == null) {
        await widget.api.post(_basePath, draft.createBody);
      } else {
        final id = existing['id']?.toString() ?? '';
        await widget.api.put(
          '$_basePath/${Uri.encodeComponent(id)}',
          draft.updateBody,
        );
      }
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: LocalizedText(
            existing == null ? 'Local user created.' : 'Local user updated.',
          ),
        ),
      );
      await _load(page: existing == null ? 1 : _page);
    } on SnaplinkAdminApiError catch (error) {
      if (mounted) setState(() => _error = error.toString());
    } finally {
      if (mounted) setState(() => _mutating = false);
    }
  }

  Future<void> _delete(Map<String, dynamic> user) async {
    final id = user['id']?.toString() ?? '';
    if (id.isEmpty) return;
    final label = user['username']?.toString() ?? id;
    final confirmed = await ConfirmDialog.show(
      context,
      title: 'Delete local user?',
      message:
          'Delete $label and its password credential? This cannot be undone.',
      confirmLabel: 'Delete user',
      destructive: true,
      confirmText: label,
    );
    if (!confirmed) return;
    setState(() => _mutating = true);
    try {
      await widget.api.delete('$_basePath/${Uri.encodeComponent(id)}');
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: LocalizedText('Local user deleted.')),
      );
      final nextPage = _users.length == 1 && _page > 1 ? _page - 1 : _page;
      await _load(page: nextPage);
    } on SnaplinkAdminApiError catch (error) {
      if (mounted) setState(() => _error = error.toString());
    } finally {
      if (mounted) setState(() => _mutating = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!_available) {
      return const Center(
        child: LocalizedText(
          'Local password users are not enabled on this replica.',
        ),
      );
    }
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        const AdminBreadcrumb(),
        Row(
          children: [
            LocalizedText(
              'Local users',
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            const Spacer(),
            IconButton(
              onPressed: _loading || _mutating ? null : _load,
              tooltip: 'Refresh'.localized,
              icon: const Icon(Icons.refresh),
            ),
            const SizedBox(width: 8),
            FilledButton.icon(
              onPressed: _mutating ? null : _openForm,
              icon: const Icon(Icons.person_add_alt_1),
              label: const LocalizedText('Create local user'),
            ),
          ],
        ),
        const SizedBox(height: 4),
        const LocalizedText(
          'Password-authenticated accounts managed by this SSO server.',
        ),
        const SizedBox(height: 12),
        AsyncView<List<Map<String, dynamic>>>(
          loading: _loading,
          error: _error,
          data: _users,
          onRetry: _load,
          emptyTitle: 'No local users',
          emptySubtitle: 'Create the first password-authenticated account.',
          dataBuilder: (users) => Column(
            children: [
              for (final user in users)
                Card(
                  margin: const EdgeInsets.only(bottom: 8),
                  child: ListTile(
                    leading: const CircleAvatar(
                      child: Icon(Icons.person_outline),
                    ),
                    title: Text(
                      user['display_name']?.toString().isNotEmpty == true
                          ? user['display_name'].toString()
                          : user['username']?.toString() ?? '',
                    ),
                    subtitle: LocalizedText(
                      '${user['username'] ?? ''}\n${user['email'] ?? ''}',
                    ),
                    isThreeLine: true,
                    trailing: PopupMenuButton<String>(
                      enabled: !_mutating,
                      onSelected: (action) {
                        if (action == 'edit') _openForm(user);
                        if (action == 'delete') _delete(user);
                      },
                      itemBuilder: (_) => const [
                        PopupMenuItem(
                          value: 'edit',
                          child: LocalizedText('Edit'),
                        ),
                        PopupMenuItem(
                          value: 'delete',
                          child: LocalizedText('Delete'),
                        ),
                      ],
                    ),
                  ),
                ),
            ],
          ),
        ),
        if (_total > _pageSize)
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              LocalizedText('Page $_page · $_total users'),
              IconButton(
                onPressed: _page > 1 && !_loading
                    ? () => _load(page: _page - 1)
                    : null,
                icon: const Icon(Icons.chevron_left),
              ),
              IconButton(
                onPressed: _page * _pageSize < _total && !_loading
                    ? () => _load(page: _page + 1)
                    : null,
                icon: const Icon(Icons.chevron_right),
              ),
            ],
          ),
      ],
    );
  }
}

class _LocalUserDraft {
  final String username;
  final String email;
  final String displayName;
  final String password;

  const _LocalUserDraft({
    required this.username,
    required this.email,
    required this.displayName,
    required this.password,
  });

  Map<String, dynamic> get createBody => {
    'username': username,
    'email': email,
    'display_name': displayName,
    'password': password,
  };

  Map<String, dynamic> get updateBody => {
    'email': email,
    'display_name': displayName,
  };
}

class _LocalUserDialog extends StatefulWidget {
  final Map<String, dynamic>? existing;

  const _LocalUserDialog({this.existing});

  @override
  State<_LocalUserDialog> createState() => _LocalUserDialogState();
}

class _LocalUserDialogState extends State<_LocalUserDialog> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _usernameCtrl;
  late final TextEditingController _emailCtrl;
  late final TextEditingController _nameCtrl;
  late final TextEditingController _passwordCtrl;

  bool get _editing => widget.existing != null;

  @override
  void initState() {
    super.initState();
    _usernameCtrl = TextEditingController(
      text: widget.existing?['username']?.toString() ?? '',
    );
    _emailCtrl = TextEditingController(
      text: widget.existing?['email']?.toString() ?? '',
    );
    _nameCtrl = TextEditingController(
      text:
          widget.existing?['display_name']?.toString() ??
          widget.existing?['name']?.toString() ??
          '',
    );
    _passwordCtrl = TextEditingController();
  }

  @override
  void dispose() {
    _usernameCtrl.dispose();
    _emailCtrl.dispose();
    _nameCtrl.dispose();
    _passwordCtrl.dispose();
    super.dispose();
  }

  void _submit() {
    if (!_formKey.currentState!.validate()) return;
    Navigator.pop(
      context,
      _LocalUserDraft(
        username: _usernameCtrl.text.trim(),
        email: _emailCtrl.text.trim(),
        displayName: _nameCtrl.text.trim(),
        password: _passwordCtrl.text,
      ),
    );
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: LocalizedText(_editing ? 'Edit local user' : 'Create local user'),
    content: Form(
      key: _formKey,
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextFormField(
              controller: _usernameCtrl,
              enabled: !_editing,
              decoration: InputDecoration(labelText: 'Username'.localized),
              validator: validateSnaplinkLocalUsername,
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _emailCtrl,
              decoration: InputDecoration(labelText: 'Email'.localized),
              keyboardType: TextInputType.emailAddress,
              validator: validateSnaplinkLocalEmail,
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _nameCtrl,
              decoration: InputDecoration(labelText: 'Display name'.localized),
            ),
            if (!_editing) ...[
              const SizedBox(height: 12),
              TextFormField(
                controller: _passwordCtrl,
                obscureText: true,
                decoration: InputDecoration(
                  labelText: 'Initial password'.localized,
                ),
                validator: validateSnaplinkInitialPassword,
              ),
            ],
          ],
        ),
      ),
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(context),
        child: const LocalizedText('Cancel'),
      ),
      FilledButton(onPressed: _submit, child: const LocalizedText('Save')),
    ],
  );
}
