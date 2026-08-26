import 'package:flutter/material.dart';
import 'package:sso_admin/theme/app_colors.dart';
import 'package:sso_admin/i18n/localized_text.dart';
import 'package:sso_admin/services/browser_navigation.dart';
import 'package:sso_admin/widgets/admin_breadcrumb.dart';
import 'package:sso_admin/widgets/app_snackbar.dart';
import 'package:sso_admin/widgets/async_view.dart';
import 'package:sso_admin/widgets/admin_data_table.dart';
import 'package:sso_admin/widgets/data_emphasis.dart';
import 'package:sso_admin/widgets/empty_state.dart';
import 'package:sso_admin/widgets/key_metric_card.dart';
import 'package:sso_admin/widgets/pull_to_refresh.dart';
import 'package:sso_admin/widgets/section_header.dart';
import 'package:sso_admin/widgets/skeleton_list.dart';
import 'package:sso_admin/i18n/app_strings.dart';
import 'package:sso_admin/widgets/section_selector.dart';
import 'package:sso_admin/widgets/confirm_dialog.dart';
import 'admin_module_groups.dart';
import 'admin_navigation.dart';
import 'admin_ops_helpers.dart';
import 'admin_route.dart';
import 'snaplink_admin_api.dart';
part 'token_security_tab_view.dart';
part 'token_security_tab_action_views.dart';

/// Token security workbench: portfolio / anomalies / sessions / expiring
/// reads + bounded bulk revoke + one-time temp token + single revoke.
/// URLs: /admin/token-security[/:section]
class TokenSecurityTab extends StatefulWidget {
  final SnaplinkAdminApi api;
  final SnaplinkAdminCapabilities capabilities;
  const TokenSecurityTab({
    super.key,
    required this.api,
    required this.capabilities,
  });
  @override
  State<TokenSecurityTab> createState() => _TokenSecurityTabState();
}

class _TokenSecurityTabState extends State<TokenSecurityTab> {
  final _subjectCtrl = TextEditingController();
  final _clientCtrl = TextEditingController();
  final _createUserCtrl = TextEditingController();
  final _createScopesCtrl = TextEditingController(text: 'openid profile');
  final _revokeTokenCtrl = TextEditingController();
  final Map<String, Map<String, dynamic>> _data = {};
  String? _error;
  bool _loading = true, _mutating = false;

  /// 请求序号：总览刷新与后台 stale 回写必须属于同一批次。
  int _reqSeq = 0;
  bool _mutationOutcomeUnknown = false;
  String? _tempToken;
  String _revokeKind = 'session_id', _currentSection = 'all';
  late final void Function() _cancelPopState;

  static const _paths = {
    'sessions': '/api/v1/admin/sessions',
    'tokens': '/api/v1/admin/tokens',
    'portfolio': '/api/v1/admin/tokens/portfolio',
    'expiring': '/api/v1/admin/tokens/expiring',
    'suspicious': '/api/v1/admin/tokens/suspicious',
  };
  static const _bulkRevokePath = '/api/v1/admin/tokens/bulk-revoke';
  static const _tempTokenPath = '/api/v1/admin/tokens/temp';
  static const _singleRevokePath = '/api/v1/admin/tokens/revoke';
  static const _adminTokenPath = '/api/v1/admin/tokens/:id';
  bool _supports(String method, String path) =>
      widget.capabilities.has(method, path) ||
      SnaplinkAdminOperationCatalog.endpoints.any(
        (e) => e.method == method && e.path == path.replaceAll('/:id', '/{id}'),
      );
  bool get _supportsBulkRevoke => _supports('POST', _bulkRevokePath);
  bool get _supportsTempToken => _supports('POST', _tempTokenPath);
  bool get _supportsSingleRevoke => _supports('POST', _singleRevokePath);
  bool get _supportsAdminTokenRevoke => _supports('DELETE', _adminTokenPath);
  List<SectionDef> get _sections => _sectionDefinitions;
  @override
  void initState() {
    super.initState();
    _handleRoute();
    _cancelPopState = BrowserNavigation.listenToLocationChange(() {
      if (mounted) _handleRoute();
    });
    _load();
  }

  @override
  void dispose() {
    _tempToken = null;
    _revokeTokenCtrl.clear();
    _cancelPopState();
    for (final c in [
      _subjectCtrl,
      _clientCtrl,
      _createUserCtrl,
      _createScopesCtrl,
      _revokeTokenCtrl,
    ]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _load() async {
    final seq = ++_reqSeq;
    setState(() {
      _loading = true;
      _error = null;
    });
    final results = await Future.wait(
      _paths.entries.where((e) => _supports('GET', e.value)).map((e) async {
        try {
          return (
            key: e.key,
            data: await widget.api.getStaleWhileRevalidate(
              e.value,
              onRefresh: (fresh) {
                if (mounted && seq == _reqSeq) {
                  setState(() => _data[e.key] = fresh);
                }
              },
            ),
            error: null,
          );
        } catch (error) {
          return (key: e.key, data: null, error: error);
        }
      }),
    );
    if (!mounted || seq != _reqSeq) return;
    final unavailable = results
        .where((r) => r.error != null)
        .map((r) => r.key)
        .join(', ');
    setState(() {
      _data
        ..clear()
        ..addEntries([
          for (final r in results)
            if (r.data != null) MapEntry(r.key, r.data!),
        ]);
      _error = unavailable.isEmpty
          ? null
          : 'Some token data is unavailable: $unavailable.';
      _loading = false;
    });
  }

  Future<void> _write(
    Future<Map<String, dynamic>> Function() request,
    String message,
  ) async {
    if (_mutationOutcomeUnknown) return;
    setState(() => _mutating = true);
    try {
      await request();
      if (!mounted) return;
      showAppSnackBar(context, content: LocalizedText(message));
      await _load();
    } on SnaplinkAdminApiError catch (error) {
      if (mounted) {
        final unknown = AdminOpsHelpers.isAmbiguousWriteStatus(error.status);
        setState(() {
          _mutationOutcomeUnknown = _mutationOutcomeUnknown || unknown;
          _error = unknown
              ? context.tr(
                  'The write result is unknown (HTTP {status}). Reconcile token and session state before retrying.',
                  {'status': error.status},
                )
              : error.toString();
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _mutationOutcomeUnknown = true;
          _error = context.tr(
            'The write result is unknown because no response was received. Reconcile token and session state before retrying.',
          );
        });
      }
    } finally {
      if (mounted) setState(() => _mutating = false);
    }
  }

  Future<void> _acknowledgeUnknownOutcome() async {
    final confirmed = await ConfirmDialog.show(
      context,
      title: 'Token state reconciled?',
      message:
          'Confirm only after checking the affected token or session in a safe read. This unlocks token writes; it does not prove the previous request failed.',
      confirmLabel: 'Unlock token writes',
      destructive: true,
      confirmText: 'RECONCILED',
    );
    if (!confirmed || !mounted) return;
    setState(() {
      _mutationOutcomeUnknown = false;
      _error = context.tr(
        'Token reconciliation acknowledged. Review the scope before sending another write.',
      );
    });
  }

  Future<bool> _confirm(String title, String body, {String? confirmText}) =>
      ConfirmDialog.show(
        context,
        title: title,
        message: body,
        destructive: true,
        confirmText: confirmText,
      );
  Future<void> _revokeAdminToken(String id) async {
    if (_mutationOutcomeUnknown) return;
    if (!await _confirm(
      'Revoke administrator token?',
      'The selected administrator session will immediately lose access.',
    )) {
      return;
    }
    await _write(
      () =>
          widget.api.delete('/api/v1/admin/tokens/${Uri.encodeComponent(id)}'),
      'Administrator token revoked.',
    );
  }

  Future<void> _bulkRevoke() async {
    if (_mutationOutcomeUnknown) return;
    final subject = _subjectCtrl.text.trim(),
        clientId = _clientCtrl.text.trim();
    if (subject.isEmpty && clientId.isEmpty) {
      setState(
        () =>
            _error = 'Set a subject and/or client ID to bound the revocation.',
      );
      return;
    }
    if (!await _confirm(
      'Bulk revoke refresh tokens?',
      'Refresh tokens in the supplied scope will be invalidated. Existing stateless access tokens expire naturally.',
    )) {
      return;
    }
    await _write(
      () => widget.api.post(_bulkRevokePath, {
        if (subject.isNotEmpty) 'subject': subject,
        if (clientId.isNotEmpty) 'client_id': clientId,
        'confirm': true,
      }),
      'Refresh-token revocation completed.',
    );
  }

  Future<void> _createTempToken() async {
    if (_mutationOutcomeUnknown) return;
    final userId = _createUserCtrl.text.trim();
    if (userId.isEmpty) {
      setState(() => _error = 'User ID is required.');
      return;
    }
    final scopes = _createScopesCtrl.text
        .split(RegExp(r'\s+'))
        .where((s) => s.isNotEmpty)
        .toList(growable: false);
    if (!await _confirm(
      'Issue one-time token?',
      context.tr(
        'Issue a temporary bearer credential for {userId} with scopes {scopes}. The raw value must be transferred through an approved secure channel.',
        {
          'userId': userId,
          'scopes': scopes.isEmpty ? '(none)' : scopes.join(' '),
        },
      ),
      confirmText: userId,
    )) {
      return;
    }
    setState(() {
      _mutating = true;
      _error = null;
      _tempToken = null;
    });
    try {
      final data = await widget.api.post(_tempTokenPath, {
        'user_id': userId,
        'scopes': scopes,
      });
      if (!mounted) return;
      final token =
          data['token']?.toString() ?? data['access_token']?.toString() ?? '';
      setState(() {
        if (token.isEmpty) {
          _mutationOutcomeUnknown = true;
          _error = context.tr(
            'The token may have been issued, but Snaplink did not return its one-time value. Do not retry until you verify server state.',
          );
          _tempToken = null;
        } else {
          _tempToken = token;
        }
      });
    } on SnaplinkAdminApiError catch (e) {
      if (mounted) {
        final unknown = AdminOpsHelpers.isAmbiguousWriteStatus(e.status);
        setState(() {
          _mutationOutcomeUnknown = _mutationOutcomeUnknown || unknown;
          _error = unknown
              ? context.tr(
                  'The temporary token result is unknown (HTTP {status}). Do not retry until token state is verified.',
                  {'status': e.status},
                )
              : e.toString();
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _mutationOutcomeUnknown = true;
          _error = context.tr(
            'The temporary token result is unknown because no response was received. Do not retry until token state is verified.',
          );
        });
      }
    } finally {
      if (mounted) setState(() => _mutating = false);
    }
  }

  Future<void> _revokeToken() async {
    if (_mutationOutcomeUnknown) return;
    final value = _revokeTokenCtrl.text.trim();
    if (value.isEmpty) {
      setState(
        () => _error = _revokeKind == 'token'
            ? 'Enter the raw token value.'
            : 'Enter a session ID.',
      );
      return;
    }
    if (!await _confirm(
      _revokeKind == 'token' ? 'Revoke token?' : 'Revoke session?',
      'This revocation is immediate and cannot be undone.',
      confirmText: _revokeKind == 'session_id' ? value : null,
    )) {
      return;
    }
    setState(() {
      _mutating = true;
      _error = null;
    });
    try {
      await widget.api.post(_singleRevokePath, {_revokeKind: value});
      if (!mounted) return;
      _revokeTokenCtrl.clear();
      showAppSnackBar(
        context,
        content: LocalizedText(
          _revokeKind == 'token' ? 'Token revoked.' : 'Session revoked.',
        ),
      );
    } on SnaplinkAdminApiError catch (e) {
      if (mounted) setState(() => _error = e.toString());
    } finally {
      if (_revokeKind == 'token') _revokeTokenCtrl.clear();
      if (mounted) setState(() => _mutating = false);
    }
  }

  void _handleRoute() {
    final route = AdminRoute.current();
    if (route.module != 'token-security') return;
    final section = route.subresource.isNotEmpty ? route.subresource : 'all';
    if (_sections.any((s) => s.id == section)) {
      setState(() {
        _currentSection = section;
        if (section != 'all' && section != 'temp') _tempToken = null;
      });
    }
  }

  void _selectSection(String section) {
    setState(() {
      _currentSection = section;
      if (section != 'all' && section != 'temp') _tempToken = null;
    });
    if (section == 'all') {
      AdminRoute.go('token-security');
    } else {
      AdminRoute.go('token-security', subresource: section);
    }
  }

  @override
  Widget build(BuildContext context) => _buildTokenSecurityTab(context);
}
