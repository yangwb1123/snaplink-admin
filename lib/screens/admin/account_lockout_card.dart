import 'package:flutter/material.dart';
import 'package:sso_admin/api/snaplink_admin_api.dart';
import 'package:sso_admin/widgets/confirm_dialog.dart';

/// Clears one brute-force lockout key without conflating it with a user ID.
class AccountLockoutCard extends StatefulWidget {
  final SnaplinkAdminApi api;

  const AccountLockoutCard({super.key, required this.api});

  @override
  State<AccountLockoutCard> createState() => _AccountLockoutCardState();
}

class _AccountLockoutCardState extends State<AccountLockoutCard> {
  static const _path = '/api/v1/admin/account-lockout/clear';
  final _clientController = TextEditingController();
  final _identifierController = TextEditingController();
  String? _error;
  bool _mutating = false;

  @override
  void dispose() {
    _clientController.dispose();
    _identifierController.dispose();
    super.dispose();
  }

  Future<void> _clear() async {
    final clientId = _clientController.text.trim();
    final identifier = _identifierController.text.trim();
    if (clientId.isEmpty || identifier.isEmpty) {
      setState(() {
        _error =
            'Client ID and the exact login identifier are required to clear a lockout.';
      });
      return;
    }
    final confirmed = await ConfirmDialog.show(
      context,
      title: 'Clear account lockout?',
      message: 'Unlock $identifier for client $clientId?',
      confirmLabel: 'Clear lockout',
    );
    if (!confirmed) return;
    setState(() {
      _error = null;
      _mutating = true;
    });
    try {
      await widget.api.post(_path, {
        'client_id': clientId,
        'identifier': identifier,
      });
      if (!mounted) return;
      _identifierController.clear();
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Account lockout cleared.')));
    } on SnaplinkAdminApiError catch (error) {
      if (mounted) setState(() => _error = error.toString());
    } finally {
      if (mounted) setState(() => _mutating = false);
    }
  }

  @override
  Widget build(BuildContext context) => Card(
    margin: const EdgeInsets.only(top: 20),
    child: Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'Account lockout recovery',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 10),
          const Text(
            'Lockouts are scoped by OAuth client and the exact username, email, '
            'or phone value used at login—not by the internal user ID.',
          ),
          const SizedBox(height: 10),
          TextField(
            key: const Key('lockout-client-id'),
            controller: _clientController,
            decoration: const InputDecoration(labelText: 'Client ID'),
          ),
          const SizedBox(height: 10),
          TextField(
            key: const Key('lockout-identifier'),
            controller: _identifierController,
            decoration: const InputDecoration(labelText: 'Login identifier'),
          ),
          const SizedBox(height: 10),
          FilledButton.icon(
            key: const Key('clear-account-lockout'),
            onPressed: _mutating ? null : _clear,
            icon: const Icon(Icons.lock_open),
            label: const Text('Clear account lockout'),
          ),
          if (_error != null) ...[
            const SizedBox(height: 8),
            Text(_error!, style: const TextStyle(color: Colors.redAccent)),
          ],
        ],
      ),
    ),
  );
}
