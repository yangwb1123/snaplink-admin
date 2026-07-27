import 'package:flutter/material.dart';

import '../../services/browser_navigation.dart';
import '../../session.dart';
import '../../widgets/responsive_entry_card.dart';
import 'device_verify_api.dart';
import 'device_verify_widgets.dart';

/// SPA equivalent of Snaplink's public RFC 8628 verification page.
///
/// A device code must be approved by an already authenticated user. Keeping
/// the bearer only in [Session] means the short user code never becomes a
/// substitute credential in browser storage or query logs.
class DeviceVerifyScreen extends StatefulWidget {
  final DeviceVerifyApi? api;
  final String? Function()? accessTokenProvider;

  const DeviceVerifyScreen({super.key, this.api, this.accessTokenProvider});

  @override
  State<DeviceVerifyScreen> createState() => _DeviceVerifyScreenState();
}

class _DeviceVerifyScreenState extends State<DeviceVerifyScreen> {
  late final _api = widget.api ?? DeviceVerifyApi();
  final _codeCtrl = TextEditingController();
  bool _redirectingToLogin = false;
  bool _busy = false;
  bool _checking = false;
  bool _formatting = false;
  String? _message;
  bool _ok = false;
  Map<String, dynamic>? _preview;
  String? _codeStatus;
  String? _checkedCode;

  String? _accessToken() =>
      widget.accessTokenProvider?.call() ?? Session.read();

  bool get _terminal => const {
    'approved',
    'denied',
    'expired',
    'not_found',
  }.contains(_codeStatus);

  bool get _hasSafeApprovalPreview {
    final preview = _preview;
    if (preview == null) return false;
    final client =
        preview['client_name']?.toString() ??
        preview['client_id']?.toString() ??
        '';
    return client.isNotEmpty && preview['scopes'] is List;
  }

  @override
  void initState() {
    super.initState();
    _codeCtrl.text = DeviceVerifyApi.normalizeUserCode(
      Uri.base.queryParameters['user_code'] ?? '',
    );
    _codeCtrl.addListener(_formatCode);
    if (_accessToken() == null) {
      _redirectingToLogin = true;
      WidgetsBinding.instance.addPostFrameCallback((_) => _redirectToLogin());
    } else if (_codeCtrl.text.replaceAll('-', '').length == 8) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _checkCode());
    }
  }

  void _formatCode() {
    if (_formatting) return;
    final formatted = DeviceVerifyApi.normalizeUserCode(_codeCtrl.text);
    if (formatted != _codeCtrl.text) {
      _formatting = true;
      _codeCtrl.value = TextEditingValue(
        text: formatted,
        selection: TextSelection.collapsed(offset: formatted.length),
      );
      _formatting = false;
    }
    if (formatted != _checkedCode &&
        (_preview != null || _codeStatus != null || _message != null)) {
      setState(() {
        _preview = null;
        _codeStatus = null;
        _checkedCode = null;
        _message = null;
        _ok = false;
      });
    }
  }

  Future<void> _checkCode() async {
    final code = DeviceVerifyApi.normalizeUserCode(_codeCtrl.text);
    if (code.replaceAll('-', '').length != 8) {
      setState(() {
        _message = 'Enter the complete XXXX-XXXX code.';
        _ok = false;
      });
      return;
    }
    setState(() {
      _busy = true;
      _checking = true;
      _message = null;
      _preview = null;
      _checkedCode = null;
    });
    try {
      final preview = await _api.check(code);
      if (!mounted) return;
      final status = preview['status']?.toString() ?? 'error';
      setState(() {
        _preview = preview;
        _codeStatus = status;
        _checkedCode = code;
        _ok = status == 'pending';
        _message = switch (status) {
          'pending' =>
            _hasSafeApprovalPreview
                ? 'Code verified. Review the requesting application below.'
                : 'Code is pending, but this server does not expose the '
                      'requesting application and scopes to the SPA. Approval '
                      'is disabled to prevent blind device authorization.',
          'approved' => 'This device code has already been approved.',
          'denied' => 'This device code has already been denied.',
          'expired' => 'This device code has expired.',
          'not_found' || 'invalid' => 'This device code was not found.',
          'unavailable' => 'Device authorization is not enabled.',
          _ => 'Could not verify this code. Try again.',
        };
      });
    } catch (_) {
      if (mounted) {
        setState(() {
          _codeStatus = 'error';
          _checkedCode = null;
          _message = 'Could not verify this code. Try again.';
          _ok = false;
        });
      }
    } finally {
      if (mounted) {
        setState(() {
          _busy = false;
          _checking = false;
        });
      }
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
    BrowserNavigation.replaceLocation(login.toString());
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
    final code = DeviceVerifyApi.normalizeUserCode(_codeCtrl.text);
    if (_codeStatus != 'pending' || _checkedCode != code) await _checkCode();
    if (!mounted || _codeStatus != 'pending') return;
    if (approve && !_hasSafeApprovalPreview) return;
    if (!await _confirm(approve)) return;
    final token = _accessToken();
    if (token == null || token.isEmpty) {
      _redirectToLogin();
      return;
    }
    setState(() {
      _busy = true;
      _checking = false;
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
          _codeStatus = approve ? 'approved' : 'denied';
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
    body: ResponsiveEntryCard(
      maxWidth: 420,
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
                  enabled: !_busy && !_terminal,
                  textCapitalization: TextCapitalization.characters,
                  autocorrect: false,
                  enableSuggestions: false,
                  autofillHints: const [AutofillHints.oneTimeCode],
                  textInputAction: TextInputAction.done,
                  decoration: const InputDecoration(
                    labelText: 'Device code',
                    hintText: 'XXXX-XXXX',
                  ),
                  onSubmitted: (_) => _checkCode(),
                ),
                const SizedBox(height: 10),
                OutlinedButton.icon(
                  onPressed: _busy || _terminal ? null : _checkCode,
                  icon: _busy && _checking
                      ? const SizedBox(
                          height: 18,
                          width: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.search),
                  label: Text(_busy && _checking ? 'Checking…' : 'Check code'),
                ),
                if (_hasSafeApprovalPreview) ...[
                  const SizedBox(height: 14),
                  DeviceRequestPreview(preview: _preview!),
                ],
                const SizedBox(height: 20),
                DeviceDecisionButtons(
                  busy: _busy,
                  checking: _checking,
                  onDeny: _busy || _terminal || _codeStatus != 'pending'
                      ? null
                      : () => _verify(false),
                  onApprove:
                      _busy ||
                          _terminal ||
                          _codeStatus != 'pending' ||
                          !_hasSafeApprovalPreview
                      ? null
                      : () => _verify(true),
                ),
                if (_message != null) ...[
                  const SizedBox(height: 14),
                  Semantics(
                    liveRegion: true,
                    child: Text(
                      _message!,
                      style: TextStyle(
                        color: _ok
                            ? Theme.of(context).colorScheme.primary
                            : Theme.of(context).colorScheme.error,
                      ),
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
  );
}
