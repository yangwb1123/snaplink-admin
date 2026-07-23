import 'package:flutter/material.dart';
import 'package:web/web.dart' as web;

import '../../session.dart';
import 'device_verify_api.dart';

/// SPA equivalent of Snaplink's public RFC 8628 verification page.
///
/// A device code must be approved by an already authenticated user. Keeping
/// the bearer only in [Session] means the short user code never becomes a
/// substitute credential in browser storage or query logs.
class DeviceVerifyScreen extends StatefulWidget {
  const DeviceVerifyScreen({super.key});

  @override
  State<DeviceVerifyScreen> createState() => _DeviceVerifyScreenState();
}

class _DeviceVerifyScreenState extends State<DeviceVerifyScreen> {
  final _api = DeviceVerifyApi();
  final _codeCtrl = TextEditingController();
  bool _redirectingToLogin = false;
  bool _busy = false;
  String? _message;
  bool _ok = false;

  @override
  void initState() {
    super.initState();
    _codeCtrl.text = Uri.base.queryParameters['user_code'] ?? '';
    if (Session.read() == null) {
      _redirectingToLogin = true;
      WidgetsBinding.instance.addPostFrameCallback((_) => _redirectToLogin());
    }
  }

  @override
  void dispose() {
    _codeCtrl.dispose();
    super.dispose();
  }

  void _redirectToLogin() {
    final code = _codeCtrl.text.trim();
    final target = Uri(
      path: '/device/verify',
      queryParameters: code.isEmpty ? null : {'user_code': code},
    ).toString();
    final login = Uri.base
        .resolve('/login/')
        .replace(queryParameters: {'redirect': target});
    web.window.location.replace(login.toString());
  }

  Future<bool> _confirm(bool approve) async {
    return await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: Text(approve ? 'Approve this device?' : 'Deny this device?'),
            content: Text(
              approve
                  ? 'The device waiting for this code will be able to continue sign-in.'
                  : 'The device waiting for this code will be denied sign-in.',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('Cancel'),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(context, true),
                style: approve
                    ? null
                    : FilledButton.styleFrom(
                        backgroundColor: Colors.red.shade700,
                      ),
                child: Text(approve ? 'Approve' : 'Deny'),
              ),
            ],
          ),
        ) ??
        false;
  }

  Future<void> _verify(bool approve) async {
    final code = _codeCtrl.text.trim();
    if (code.isEmpty) {
      setState(() {
        _message = 'Enter the code shown on your device.';
        _ok = false;
      });
      return;
    }
    if (!await _confirm(approve)) return;
    final token = Session.read();
    if (token == null || token.isEmpty) {
      _redirectToLogin();
      return;
    }
    setState(() {
      _busy = true;
      _message = null;
    });
    try {
      final response = await _api.verify(
        accessToken: token,
        userCode: code,
        approve: approve,
      );
      if (!mounted) return;
      if (response.statusCode == 200) {
        setState(() {
          _message = approve
              ? 'Device approved. You can return to it now.'
              : 'Device sign-in was denied.';
          _ok = true;
        });
      } else if (response.statusCode == 401) {
        Session.clear();
        setState(() {
          _message = 'Your sign-in expired. Please sign in again.';
          _ok = false;
        });
      } else if (response.statusCode == 404 || response.statusCode == 501) {
        setState(() {
          _message = 'Device authorization is not enabled.';
          _ok = false;
        });
      } else {
        setState(() {
          _message = 'This code is invalid or has expired.';
          _ok = false;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _message = 'Request failed. Please try again.';
          _ok = false;
        });
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    body: Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 420),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Card(
            child: Padding(
              padding: const EdgeInsets.all(28),
              child: _redirectingToLogin
                  ? const Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        CircularProgressIndicator(),
                        SizedBox(height: 16),
                        Text('Redirecting to sign in…'),
                      ],
                    )
                  : Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Text(
                          'Authorize a device',
                          style: Theme.of(context).textTheme.titleLarge,
                        ),
                        const SizedBox(height: 10),
                        const Text(
                          'Enter the code displayed by the device you want to sign in on.',
                        ),
                        const SizedBox(height: 20),
                        TextField(
                          controller: _codeCtrl,
                          enabled: !_busy,
                          textCapitalization: TextCapitalization.characters,
                          autocorrect: false,
                          decoration: const InputDecoration(
                            labelText: 'Device code',
                          ),
                        ),
                        const SizedBox(height: 20),
                        Row(
                          children: [
                            Expanded(
                              child: OutlinedButton(
                                onPressed: _busy ? null : () => _verify(false),
                                style: OutlinedButton.styleFrom(
                                  foregroundColor: Colors.redAccent,
                                ),
                                child: const Text('Deny'),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: FilledButton(
                                onPressed: _busy ? null : () => _verify(true),
                                child: _busy
                                    ? const SizedBox(
                                        height: 18,
                                        width: 18,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                        ),
                                      )
                                    : const Text('Approve'),
                              ),
                            ),
                          ],
                        ),
                        if (_message != null) ...[
                          const SizedBox(height: 14),
                          Text(
                            _message!,
                            style: TextStyle(
                              color: _ok
                                  ? Colors.greenAccent
                                  : Colors.redAccent,
                            ),
                          ),
                        ],
                        if (_message?.contains('sign in again') == true)
                          Align(
                            alignment: Alignment.centerLeft,
                            child: TextButton(
                              onPressed: _redirectToLogin,
                              child: const Text('Sign in'),
                            ),
                          ),
                      ],
                    ),
            ),
          ),
        ),
      ),
    ),
  );
}
