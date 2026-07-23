import 'package:flutter/material.dart';

import 'snaplink_admin_api.dart';

/// Helpdesk controls for a Snaplink user account.
///
/// Every destructive control is scoped to one subject, requires a confirmation
/// dialog, and appears only when the related optional Snaplink feature is
/// present in the runtime inventory.
class UserSupportTab extends StatefulWidget {
  final SnaplinkAdminApi api;
  final SnaplinkAdminCapabilities capabilities;

  const UserSupportTab({
    super.key,
    required this.api,
    required this.capabilities,
  });

  @override
  State<UserSupportTab> createState() => _UserSupportTabState();
}

class _UserSupportTabState extends State<UserSupportTab> {
  final _userCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _reasonCtrl = TextEditingController();

  Map<String, dynamic> _data = const {};
  String? _error;
  bool _loading = false;
  bool _mutating = false;
  String? _nextLifecycleState;

  String? get _userId {
    final value = _userCtrl.text.trim();
    return value.isEmpty ? null : value;
  }

  bool _has(String suffix) {
    final prefix = '/api/v1/admin/$suffix';
    return widget.capabilities.hasAnyPathPrefix(prefix) ||
        SnaplinkAdminOperationCatalog.hasDocumentedPathPrefix(prefix);
  }

  String _userPath(String suffix) =>
      '/api/v1/admin/users/${Uri.encodeComponent(_userId!)}$suffix';

  @override
  void dispose() {
    _userCtrl.dispose();
    _passwordCtrl.dispose();
    _emailCtrl.dispose();
    _reasonCtrl.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    if (_userId == null) {
      setState(() => _error = 'Enter a user ID first.');
      return;
    }
    setState(() {
      _loading = true;
      _error = null;
    });
    final requests = <String, Future<Map<String, dynamic>>>{
      if (_has('users/:id/sessions'))
        'sessions': widget.api.get(_userPath('/sessions')),
      if (_has('users/:id/consents'))
        'consents': widget.api.get(_userPath('/consents')),
      if (_has('users/:id/mfa')) 'mfa': widget.api.get(_userPath('/mfa')),
      if (_has('users/:id/lifecycle'))
        'lifecycle': widget.api.get(_userPath('/lifecycle')),
      if (_has('users/:id/password-reset-tokens'))
        'passwordReset': widget.api.get(_userPath('/password-reset-tokens')),
      if (_has('users/:id/email-change-tokens'))
        'emailChange': widget.api.get(_userPath('/email-change-tokens')),
    };
    final entries = await Future.wait(
      requests.entries.map((entry) async {
        try {
          return (key: entry.key, data: await entry.value, error: null);
        } catch (error) {
          return (key: entry.key, data: null, error: error);
        }
      }),
    );
    if (!mounted) return;
    final unavailable = entries
        .where((entry) => entry.error != null)
        .map((entry) => entry.key)
        .join(', ');
    setState(() {
      _data = {
        for (final entry in entries)
          if (entry.data != null) entry.key: entry.data!,
      };
      _error = unavailable.isEmpty
          ? null
          : 'Some support data is unavailable: $unavailable.';
      _loading = false;
    });
  }

  Future<void> _mutate(
    String title,
    String message,
    Future<Map<String, dynamic>> Function() request, {
    String? success,
  }) async {
    if (!await _confirm(title, message)) return;
    setState(() {
      _mutating = true;
      _error = null;
    });
    try {
      await request();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(success ?? 'Operation completed.')),
      );
      await _load();
    } on SnaplinkAdminApiError catch (error) {
      if (mounted) setState(() => _error = error.toString());
    } finally {
      if (mounted) setState(() => _mutating = false);
    }
  }

  Future<bool> _confirm(String title, String message) async =>
      await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: Text(title),
          content: Text(message),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, true),
              style: FilledButton.styleFrom(backgroundColor: Colors.red),
              child: const Text('Confirm'),
            ),
          ],
        ),
      ) ??
      false;

  List<Map<String, dynamic>> _list(String key, String valueKey) {
    final values = _data[key]?[valueKey];
    if (values is! List) return const [];
    return values
        .whereType<Map>()
        .map((value) => Map<String, dynamic>.from(value))
        .toList(growable: false);
  }

  @override
  Widget build(BuildContext context) {
    final loaded = _userId != null && !_loading;
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Row(
          children: [
            Text(
              'User support',
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            const Spacer(),
            IconButton(
              onPressed: _loading ? null : _load,
              icon: const Icon(Icons.refresh),
            ),
          ],
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _userCtrl,
          decoration: const InputDecoration(labelText: 'User ID'),
          onSubmitted: (_) => _load(),
        ),
        const SizedBox(height: 12),
        FilledButton(
          onPressed: _loading ? null : _load,
          child: const Text('Load account support data'),
        ),
        if (_error != null)
          Padding(
            padding: const EdgeInsets.only(top: 12),
            child: Text(
              _error!,
              style: const TextStyle(color: Colors.redAccent),
            ),
          ),
        if (_loading)
          const Padding(
            padding: EdgeInsets.only(top: 20),
            child: Center(child: CircularProgressIndicator()),
          ),
        if (loaded) ...[
          if (_has('users/:id/sessions')) _sessionsCard(context),
          if (_has('users/:id/consents')) _consentsCard(context),
          if (_has('users/:id/mfa')) _mfaCard(context),
          if (_has('users/:id/lifecycle')) _lifecycleCard(context),
          _credentialRecoveryCard(context),
        ],
      ],
    );
  }

  Widget _sessionsCard(BuildContext context) {
    final sessions = _list('sessions', 'sessions');
    return _card(
      context,
      'Active sessions',
      sessions.isEmpty
          ? const [Text('No active sessions.')]
          : sessions
                .map(
                  (session) => ListTile(
                    contentPadding: EdgeInsets.zero,
                    title: Text(session['id']?.toString() ?? ''),
                    subtitle: Text(
                      '${session['ip'] ?? ''} ${session['user_agent'] ?? ''}'
                          .trim(),
                    ),
                  ),
                )
                .toList(growable: false),
    );
  }

  Widget _consentsCard(BuildContext context) {
    final consents = _list('consents', 'consents');
    return _card(context, 'Application consents', [
      if (consents.isEmpty) const Text('No grants found.'),
      for (final consent in consents)
        ListTile(
          contentPadding: EdgeInsets.zero,
          title: Text(consent['client_id']?.toString() ?? ''),
          subtitle: Text((consent['scopes'] as List? ?? const []).join(' ')),
          trailing: TextButton(
            onPressed: _mutating
                ? null
                : () => _mutate(
                    'Revoke consent?',
                    'Remove this application grant for ${_userId!}?',
                    () => widget.api.delete(
                      '${_userPath('/consents')}/${Uri.encodeComponent(consent['client_id'].toString())}',
                    ),
                    success: 'Consent revoked.',
                  ),
            style: TextButton.styleFrom(foregroundColor: Colors.redAccent),
            child: const Text('Revoke'),
          ),
        ),
    ]);
  }

  Widget _mfaCard(BuildContext context) {
    final factors = _list('mfa', 'factors');
    return _card(context, 'Second factors', [
      if (factors.isEmpty) const Text('No registered factors.'),
      for (final factor in factors)
        ListTile(
          contentPadding: EdgeInsets.zero,
          title: Text(
            factor['label']?.toString() ?? factor['method']?.toString() ?? '',
          ),
          subtitle: Text(factor['method']?.toString() ?? ''),
          trailing: TextButton(
            onPressed: _mutating
                ? null
                : () => _mutate(
                    'Remove second factor?',
                    'The user will no longer be able to use this factor.',
                    () => widget.api.delete(
                      '${_userPath('/mfa')}/${Uri.encodeComponent(factor['id'].toString())}',
                    ),
                    success: 'Second factor removed.',
                  ),
            style: TextButton.styleFrom(foregroundColor: Colors.redAccent),
            child: const Text('Remove'),
          ),
        ),
      if (_has('users/:id/mfa/recovery-codes'))
        OutlinedButton(
          onPressed: _mutating
              ? null
              : () => _mutate(
                  'Reset recovery codes?',
                  'All remaining recovery codes will be invalidated. Codes are never shown to support staff.',
                  () => widget.api.post(_userPath('/mfa/recovery-codes')),
                ),
          child: const Text('Reset recovery codes'),
        ),
    ]);
  }

  Widget _lifecycleCard(BuildContext context) {
    final lifecycle = _data['lifecycle'] ?? const <String, dynamic>{};
    final allowed = (lifecycle['allowed_transitions'] as List? ?? const [])
        .map((value) => value.toString())
        .toList();
    return _card(context, 'Account lifecycle', [
      Text('Current state: ${lifecycle['state'] ?? 'active'}'),
      const SizedBox(height: 10),
      DropdownButtonFormField<String>(
        initialValue: allowed.contains(_nextLifecycleState)
            ? _nextLifecycleState
            : null,
        decoration: const InputDecoration(labelText: 'Transition to'),
        items: allowed
            .map((state) => DropdownMenuItem(value: state, child: Text(state)))
            .toList(growable: false),
        onChanged: _mutating
            ? null
            : (state) => setState(() => _nextLifecycleState = state),
      ),
      const SizedBox(height: 10),
      TextField(
        controller: _reasonCtrl,
        decoration: const InputDecoration(
          labelText: 'Reason / ticket reference',
        ),
      ),
      const SizedBox(height: 10),
      FilledButton(
        onPressed: _mutating || _nextLifecycleState == null
            ? null
            : () => _mutate(
                'Change lifecycle state?',
                'Transition ${_userId!} to $_nextLifecycleState?',
                () => widget.api.post(_userPath('/lifecycle'), {
                  'state': _nextLifecycleState,
                  'reason': _reasonCtrl.text.trim(),
                }),
              ),
        child: const Text('Apply transition'),
      ),
    ]);
  }

  Widget _credentialRecoveryCard(BuildContext context) => _card(
    context,
    'Credential recovery and containment',
    [
      if (_data.containsKey('passwordReset'))
        _recoveryStatus('Active password-reset links', _data['passwordReset']!),
      if (_data.containsKey('emailChange'))
        _recoveryStatus('Active email-change links', _data['emailChange']!),
      if (_has('users/:id/password')) ...[
        TextField(
          controller: _passwordCtrl,
          obscureText: true,
          onChanged: (_) => setState(() {}),
          decoration: const InputDecoration(labelText: 'New password'),
        ),
        const SizedBox(height: 10),
        FilledButton(
          onPressed: _mutating || _passwordCtrl.text.isEmpty
              ? null
              : () => _mutate(
                  'Set a new password?',
                  'This immediately replaces the user password.',
                  () => widget.api.post(_userPath('/password'), {
                    'new_password': _passwordCtrl.text,
                  }),
                  success: 'Password reset.',
                ),
          child: const Text('Set password'),
        ),
      ],
      if (_has('users/:id/email')) ...[
        const SizedBox(height: 12),
        TextField(
          controller: _emailCtrl,
          keyboardType: TextInputType.emailAddress,
          onChanged: (_) => setState(() {}),
          decoration: const InputDecoration(labelText: 'Replacement email'),
        ),
        const SizedBox(height: 10),
        FilledButton(
          onPressed: _mutating || _emailCtrl.text.trim().isEmpty
              ? null
              : () => _mutate(
                  'Force-set email?',
                  'This bypasses the self-service email verification flow.',
                  () => widget.api.post(_userPath('/email'), {
                    'email': _emailCtrl.text.trim(),
                  }),
                ),
          child: const Text('Set email'),
        ),
      ],
      const SizedBox(height: 12),
      Wrap(
        spacing: 10,
        runSpacing: 10,
        children: [
          if (_has('users/:id/refresh-tokens'))
            _dangerButton(
              'Revoke all refresh tokens',
              () => widget.api.delete(_userPath('/refresh-tokens')),
            ),
          if (_has('users/:id/device-secrets'))
            _dangerButton(
              'Revoke device secrets',
              () => widget.api.delete(_userPath('/device-secrets')),
            ),
          if (_has('users/:id/password-reset-tokens'))
            _dangerButton(
              'Revoke password reset links',
              () => widget.api.delete(_userPath('/password-reset-tokens')),
            ),
          if (_has('users/:id/email-change-tokens'))
            _dangerButton(
              'Revoke email change links',
              () => widget.api.delete(_userPath('/email-change-tokens')),
            ),
        ],
      ),
    ],
  );

  Widget _recoveryStatus(String label, Map<String, dynamic> data) {
    final records = data['tokens'] ?? data['links'] ?? data['items'];
    final count =
        data['total'] ??
        data['count'] ??
        (records is List ? records.length : 0);
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Text('$label: $count'),
    );
  }

  Widget _dangerButton(
    String label,
    Future<Map<String, dynamic>> Function() request,
  ) => OutlinedButton(
    onPressed: _mutating
        ? null
        : () => _mutate(
            '$label?',
            'This action is immediate and cannot be undone.',
            request,
            success: '$label completed.',
          ),
    style: OutlinedButton.styleFrom(
      foregroundColor: Colors.redAccent,
      side: const BorderSide(color: Colors.redAccent),
    ),
    child: Text(label),
  );

  Widget _card(BuildContext context, String title, List<Widget> children) =>
      Card(
        margin: const EdgeInsets.only(top: 20),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(title, style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 10),
              ...children,
            ],
          ),
        ),
      );
}
