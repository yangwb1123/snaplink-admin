import 'package:flutter/material.dart';
import 'package:sso_admin/theme/app_colors.dart';

import '../../i18n/app_strings.dart';
import '../../services/browser_navigation.dart';
import '../../services/product_api_origin.dart';
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
  final Uri? routeUri;

  const DeviceVerifyScreen({
    super.key,
    this.api,
    this.accessTokenProvider,
    this.routeUri,
  });

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
  bool _requiresSignIn = false;

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
      (widget.routeUri ?? Uri.base).queryParameters['user_code'] ?? '',
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
        _preview = _codeStatus = _checkedCode = _message = null;
        _requiresSignIn = false;
        _ok = false;
      });
    }
  }

  Future<void> _checkCode() async {
    final strings = AppStrings.of(context);
    final code = DeviceVerifyApi.normalizeUserCode(_codeCtrl.text);
    if (code.replaceAll('-', '').length != 8) {
      _showMessage(strings.deviceCodeIncomplete);
      return;
    }
    setState(() {
      _busy = _checking = true;
      _message = _preview = _checkedCode = null;
      _requiresSignIn = false;
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
                ? strings.deviceCodeVerified
                : strings.deviceApprovalContextMissing,
          'approved' => strings.deviceAlreadyApproved,
          'denied' => strings.deviceAlreadyDenied,
          'expired' => strings.deviceCodeExpired,
          'not_found' || 'invalid' => strings.deviceCodeNotFound,
          'unavailable' => strings.deviceAuthorizationDisabled,
          _ => strings.deviceCodeCheckFailed,
        };
      });
    } catch (_) {
      if (mounted) {
        setState(() {
          _codeStatus = 'error';
          _checkedCode = null;
          _message = strings.deviceCodeCheckFailed;
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
    final login = ProductApiOrigin.baseUri
        .resolve('/login/')
        .replace(queryParameters: {'redirect': target});
    BrowserNavigation.replaceLocation(login.toString());
  }

  /// 单一消息出口：设置消息 + 成功/错误语义 + 可选重新登录提示。
  void _showMessage(String message, {bool ok = false, bool signIn = false}) {
    setState(() {
      _message = message;
      _ok = ok;
      _requiresSignIn = signIn;
    });
  }

  Future<bool> _confirm(bool approve) async {
    final strings = AppStrings.of(context);
    return await showDialog<bool>(
          context: context,
          barrierDismissible: !approve,
          builder: (context) => AlertDialog(
            title: Text(
              approve ? strings.approveDeviceTitle : strings.denyDeviceTitle,
            ),
            content: Text(
              approve
                  ? strings.approveDeviceDescription
                  : strings.denyDeviceDescription,
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: Text(strings.cancel),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(context, true),
                style: approve
                    ? null
                    : FilledButton.styleFrom(
                        backgroundColor: AppColors.danger,
                      ),
                child: Text(approve ? strings.approve : strings.deny),
              ),
            ],
          ),
        ) ??
        false;
  }

  Future<void> _verify(bool approve) async {
    final strings = AppStrings.of(context);
    final code = DeviceVerifyApi.normalizeUserCode(_codeCtrl.text);
    if (_codeStatus != 'pending' || _checkedCode != code) await _checkCode();
    if (!mounted || _codeStatus != 'pending') return;
    if (approve && !_hasSafeApprovalPreview) return;
    if (!await _confirm(approve)) return;
    final token = _accessToken();
    if (token == null || token.isEmpty) return _redirectToLogin();
    setState(() {
      _busy = true;
      _checking = false;
      _message = null;
      _requiresSignIn = false;
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
          _message = approve ? strings.deviceApproved : strings.deviceDenied;
          _ok = true;
          _codeStatus = approve ? 'approved' : 'denied';
        });
      } else if (response.statusCode == 401) {
        Session.clear();
        _showMessage(strings.signInExpired, signIn: true);
      } else if (response.statusCode == 404 || response.statusCode == 501) {
        _showMessage(strings.deviceAuthorizationDisabled);
      } else {
        _showMessage(strings.deviceCodeInvalidExpired);
      }
    } catch (_) {
      if (mounted) _showMessage(strings.requestFailedRetry);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  /// 消息 → (图标, 颜色, contained) 四级语义映射：成功（品牌主色）/
  /// 中性（onSurfaceVariant）/ 警告（amber）/ 错误（errorContainer 底）。
  (IconData, Color, bool) _statusStyle(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    if (_ok) {
      if (_codeStatus == 'pending' && !_hasSafeApprovalPreview) {
        return (Icons.warning_amber_outlined, scheme.onErrorContainer, true);
      }
      return (Icons.check_circle_outline, scheme.primary, false);
    }
    return switch (_codeStatus) {
      'approved' => (Icons.check_circle_outline, scheme.primary, false),
      'denied' => (Icons.block, scheme.onSurfaceVariant, false),
      'expired' => (Icons.schedule, AppColors.warning, false),
      'not_found' || 'invalid' =>
        (Icons.search_off, scheme.onErrorContainer, true),
      'unavailable' => (Icons.toggle_off_outlined, AppColors.warning, false),
      'error' => (Icons.error_outline, scheme.onErrorContainer, true),
      _ => (Icons.error_outline, scheme.onErrorContainer, true),
    };
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final strings = AppStrings.of(context);
    final preview = _preview;
    final status = _message == null ? null : _statusStyle(context);
    return Scaffold(
      body: ResponsiveEntryCard(
        maxWidth: 420,
        child: _redirectingToLogin
            ? DeviceStatusBlock(
                spinner: true,
                title: strings.redirectingToSignIn,
              )
            : Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Semantics(
                    container: true,
                    header: true,
                    child: Text(
                      strings.authorizeDevice,
                      style: theme.textTheme.titleLarge,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(strings.deviceCodeInstruction),
                  const SizedBox(height: 20),
                  TextField(
                    controller: _codeCtrl,
                    enabled: !_busy && !_terminal,
                    autofocus: true,
                    textCapitalization: TextCapitalization.characters,
                    autocorrect: false,
                    enableSuggestions: false,
                    autofillHints: const [AutofillHints.oneTimeCode],
                    textInputAction: TextInputAction.done,
                    decoration: InputDecoration(
                      labelText: strings.deviceCode,
                      hintText: 'XXXX-XXXX',
                      prefixIcon: Icon(
                        Icons.pin_outlined,
                        color: scheme.primary,
                      ),
                    ),
                    onSubmitted: (_) => _checkCode(),
                  ),
                  const SizedBox(height: 12),
                  OutlinedButton.icon(
                    onPressed: _busy || _terminal ? null : _checkCode,
                    icon: _busy && _checking
                        ? const SizedBox(
                            height: 18,
                            width: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.search),
                    label: Text(
                      _busy && _checking ? strings.checking : strings.checkCode,
                    ),
                  ),
                  const SizedBox(height: 20),
                  // 预览区三态：empty（未检查）/ data（安全预览）；loading
                  // 由按钮内 spinner 呈现，error 由下方消息通知承接。
                  if (preview != null && _hasSafeApprovalPreview)
                    DeviceRequestPreview(preview: preview)
                  else if (_message == null &&
                      _checkedCode == null &&
                      !_terminal)
                    DeviceInlineNotice(
                      text: strings.devicePreviewHint,
                      icon: Icons.devices_other,
                      color: scheme.onSurfaceVariant,
                    ),
                  if (_message != null) ...[
                    const SizedBox(height: 16),
                    DeviceInlineNotice(
                      text: _message!,
                      icon: status!.$1,
                      color: status.$2,
                      contained: status.$3,
                      liveRegion: true,
                    ),
                  ],
                  if (_requiresSignIn) ...[
                    const SizedBox(height: 12),
                    Align(
                      alignment: Alignment.centerLeft,
                      child: TextButton(
                        onPressed: _redirectToLogin,
                        child: Text(strings.signInAgain),
                      ),
                    ),
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
                ],
              ),
      ),
    );
  }
}
