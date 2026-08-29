import 'package:flutter/material.dart';
import 'package:sso_admin/theme/app_colors.dart';
import 'package:sso_admin/i18n/app_strings.dart';
import 'package:sso_admin/i18n/localized_text.dart';
import 'package:sso_admin/api/admin_paths.dart';
import 'package:sso_admin/api/snaplink_admin_api.dart';
import 'package:sso_admin/services/operator_persona.dart';
import 'package:sso_admin/widgets/admin_breadcrumb.dart';
import 'package:sso_admin/widgets/app_snackbar.dart';
import 'package:sso_admin/widgets/data_emphasis.dart';
import 'package:sso_admin/widgets/key_metric_card.dart';
import 'package:sso_admin/widgets/info_row.dart';
import 'package:sso_admin/widgets/async_view.dart';
import 'package:sso_admin/widgets/skeleton_list.dart';
import 'package:sso_admin/widgets/status_chip.dart';
import 'package:sso_admin/api/sso_client.dart';
import 'package:sso_admin/widgets/confirm_dialog.dart';
import 'admin_module_groups.dart';
import 'admin_route.dart';
import 'client_detail_secret_card.dart';
import 'client_form_dialog.dart';
import 'client_secret_lifecycle.dart';
import 'admin_ops_helpers.dart';

part 'client_detail_view.dart';

/// Client detail screen with actions (rotate-secret, approve, reject).
/// URL: /admin/clients/{id}[/{action}]
class ClientDetailScreen extends StatefulWidget {
  final SnaplinkAdminApi api;
  final SSOAdminClient client;
  final String clientId;

  /// Persona emphasis (derived by the dashboard; default = no emphasis).
  final OperatorPersona persona;

  const ClientDetailScreen({
    super.key,
    required this.api,
    required this.client,
    required this.clientId,
    this.persona = OperatorPersona.general,
  });

  @override
  State<ClientDetailScreen> createState() => _ClientDetailScreenState();
}

class _ClientDetailScreenState extends State<ClientDetailScreen> {
  Map<String, dynamic>? _client;
  String? _error;
  bool _loading = true;
  bool _mutating = false;
  bool _secretRotationOutcomeUnknown = false;

  /// 模块强调色（identity 组 indigo-violet）：详情页图标统一按组色上色。
  Color get _accent => adminModuleIconColor('clients');

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void didUpdateWidget(covariant ClientDetailScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.clientId != widget.clientId) {
      _client = null;
      _load();
    }
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final result = await widget.client.getClient(widget.clientId);
      if (!context.mounted) return;
      setState(() {
        _client = result as Map<String, dynamic>?;
        _loading = false;
      });
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = e.toString();
          _loading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) => _buildClientDetail(context);

  Future<void> _rotateSecret(BuildContext context) async {
    if (_secretRotationOutcomeUnknown) return;
    final confirmed = await ConfirmDialog.show(
      context,
      title: 'Rotate client secret?',
      message:
          'The current secret remains valid for 24 hours. Update all integrations before that overlap window closes.',
      confirmLabel: 'Rotate secret',
      destructive: true,
      confirmText: widget.clientId,
    );
    if (!confirmed) return;
    setState(() => _mutating = true);
    try {
      final rotation = await widget.client.rotateClientSecretWithPolicy(
        widget.clientId,
      );
      final newSecret = rotation['secret']?.toString() ?? '';
      if (!context.mounted) return;
      if (newSecret.isEmpty) {
        setState(() {
          _secretRotationOutcomeUnknown = true;
          _error = context.tr(
            'The secret was rotated, but the server did not return its one-time value. Reconcile client state before retrying.',
          );
        });
        await _load();
      } else {
        await showClientDetailSecret(
          context,
          newSecret,
          expiresAt: clientSecretExpiryUnix(rotation),
        );
        if (!context.mounted) return;
        showAppSnackBar(context, content: LocalizedText('Secret rotated.'));
      }
    } on SSOError catch (e) {
      if (!context.mounted) return;
      if (AdminOpsHelpers.isAmbiguousWriteStatus(e.status)) {
        setState(() {
          _secretRotationOutcomeUnknown = true;
          _error = context.tr(
            'Secret rotation result is unknown. Reconcile client state before retrying.',
          );
        });
      } else {
        showAppSnackBar(
          context,
          content: LocalizedText('Error: {detail}', args: {'detail': e}),
          kind: AppSnackBarKind.error,
        );
      }
    } catch (_) {
      if (!context.mounted) return;
      setState(() {
        _secretRotationOutcomeUnknown = true;
        _error = context.tr(
          'Secret rotation result is unknown. Reconcile client state before retrying.',
        );
      });
    } finally {
      if (mounted) setState(() => _mutating = false);
    }
  }

  Future<void> _acknowledgeSecretRotation() async {
    final confirmed = await ConfirmDialog.show(
      context,
      title: 'Client secret state reconciled?',
      message:
          'Confirm only after checking the client and its integrations in a safe read. This unlocks secret rotation; it does not prove the previous request failed.',
      confirmLabel: 'Unlock secret rotation',
      destructive: true,
      confirmText: 'RECONCILED',
    );
    if (!confirmed || !mounted) return;
    setState(() {
      _secretRotationOutcomeUnknown = false;
      _error = null;
    });
  }

  Future<void> _doAction(String action) async {
    final confirmed = await ConfirmDialog.show(
      context,
      title: action == 'approve' ? 'Approve client?' : 'Reject client?',
      message: context.tr(
        action == 'approve'
            ? 'Approve {clientId} for use on this authorization server?'
            : 'Reject the pending client registration for {clientId}?',
        {'clientId': widget.clientId},
      ),
      confirmLabel: action == 'approve' ? 'Approve' : 'Reject',
      destructive: true,
      confirmText: widget.clientId,
    );
    if (!confirmed) return;
    setState(() => _mutating = true);
    try {
      await widget.api.post(
        AdminPaths.clientReview(widget.clientId, action),
        {},
      );
      if (!mounted) return;
      showAppSnackBar(
        context,
        content: LocalizedText('Client {action}ed', args: {'action': action}),
      );
      _load();
    } catch (e) {
      if (!mounted) return;
      showAppSnackBar(
        context,
        content: LocalizedText('Error: {detail}', args: {'detail': e}),
        kind: AppSnackBarKind.error,
      );
    } finally {
      if (mounted) setState(() => _mutating = false);
    }
  }

  Future<void> _editClient(BuildContext context) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (_) =>
          ClientFormDialog(client: widget.client, existing: _client),
    );
    if (result == true) _load();
  }
}
