import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:sso_admin/api/snaplink_admin_api.dart';
import 'package:sso_admin/i18n/app_strings.dart';
import 'package:sso_admin/i18n/localized_text.dart';
import 'package:sso_admin/theme/app_colors.dart';
import 'package:sso_admin/widgets/admin_breadcrumb.dart';
import 'package:sso_admin/widgets/app_snackbar.dart';
import 'package:sso_admin/widgets/confirm_dialog.dart';
import 'package:sso_admin/widgets/empty_state.dart';
import 'package:sso_admin/widgets/section_header.dart';
import 'package:sso_admin/widgets/status_chip.dart';

import 'admin_module_groups.dart';
import 'admin_navigation.dart';
import 'admin_ops_helpers.dart';

part 'admin_operations_tab_view.dart';

/// Advanced, capability-bound access to Snaplink's optional admin routes.
/// The selector is populated from Snaplink's documented contract and enriched
/// with the authenticated replica's runtime inventory. Every mutation needs an
/// explicit confirmation, providing a safe operational bridge while
/// high-volume workflows receive dedicated screens.
class AdminOperationsTab extends StatefulWidget {
  final SnaplinkAdminApi api;
  final List<SnaplinkAdminEndpoint> endpoints;
  const AdminOperationsTab({
    super.key,
    required this.api,
    required this.endpoints,
  });
  @override
  State<AdminOperationsTab> createState() => _AdminOperationsTabState();
}

class _AdminOperationsTabState extends State<AdminOperationsTab> {
  final _bodyCtrl = TextEditingController(text: '{}');
  final _queryCtrl = TextEditingController(text: '{}');
  final _confirmCtrl = TextEditingController();
  final Map<String, TextEditingController> _pathCtrls = {};
  SnaplinkAdminEndpoint? _selected;
  Map<String, dynamic>? _response;
  String? _rawResponse;
  String? _error;
  bool _running = false;
  bool _mutationOutcomeUnknown = false;

  /// 模块组色（operations → developers 组 emerald）：页头/卡片图标统一上色。
  Color get _accent => adminModuleIconColor(AdminModuleId.operations);

  List<SnaplinkAdminEndpoint> get _adminEndpoints =>
      SnaplinkAdminOperationCatalog.mergedWith(widget.endpoints)
          .where(
            (endpoint) =>
                !AdminOpsHelpers.exposesUnredactedProviderConfig(endpoint) &&
                !AdminOpsHelpers.exposesDecodedSnapshotResources(endpoint) &&
                !AdminOpsHelpers.requiresDedicatedWorkflow(endpoint) &&
                (endpoint.path.startsWith('/api/v1/admin/') ||
                    endpoint.path.startsWith('/api/v1/clients/') ||
                    endpoint.path.startsWith('/api/v1/audit') ||
                    endpoint.path.startsWith('/api/v1/compliance/') ||
                    endpoint.path.startsWith('/api/v1/scim/') ||
                    endpoint.path.startsWith('/api/v1/netpolicy/')),
          )
          .toList(growable: false);
  @override
  void initState() {
    super.initState();
    _bodyCtrl.addListener(_invalidateConfirmation);
    _queryCtrl.addListener(_invalidateConfirmation);
    _select(_defaultEndpoint());
  }

  @override
  void didUpdateWidget(covariant AdminOperationsTab oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!_adminEndpoints.contains(_selected)) _select(_defaultEndpoint());
  }

  SnaplinkAdminEndpoint? _defaultEndpoint() {
    if (_adminEndpoints.isEmpty) return null;
    return _adminEndpoints.firstWhere(
      (endpoint) =>
          endpoint.method == 'GET' &&
          endpoint.path == '/api/v1/admin/endpoints',
      orElse: () => _adminEndpoints.first,
    );
  }

  void _disposeController(TextEditingController controller) {
    controller.dispose();
  }

  @override
  void dispose() {
    _bodyCtrl.dispose();
    _queryCtrl.dispose();
    _confirmCtrl.dispose();
    _pathCtrls.values.forEach(_disposeController);
    super.dispose();
  }

  void _select(SnaplinkAdminEndpoint? endpoint) {
    _pathCtrls.values.forEach(_disposeController);
    _pathCtrls
      ..clear()
      ..addEntries(
        (endpoint?.pathParameters ?? const <String>[]).map((parameter) {
          final controller = TextEditingController();
          controller.addListener(_pathChanged);
          return MapEntry(parameter, controller);
        }),
      );
    _confirmCtrl.clear();
    setState(() {
      _selected = endpoint;
      _response = null;
      _rawResponse = null;
      _error = null;
    });
  }

  bool get _isMutation => _selected != null && _selected!.method != 'GET';
  void _invalidateConfirmation() {
    if (_confirmCtrl.text.isNotEmpty) _confirmCtrl.clear();
  }

  void _pathChanged() {
    _invalidateConfirmation();
  }

  String get _confirmationHint {
    final endpoint = _selected;
    if (endpoint == null) return 'CONFIRM';
    try {
      final path = endpoint.resolvePath(
        Map.fromEntries(
          _pathCtrls.entries.map(
            (entry) => MapEntry(entry.key, entry.value.text),
          ),
        ),
      );
      return AdminOpsHelpers.writeConfirmation(endpoint.method, path);
    } catch (_) {
      return 'CONFIRM ${endpoint.method} <resolved path>';
    }
  }

  Future<void> _run() async {
    final endpoint = _selected;
    if (endpoint == null) return;
    final blocked = endpoint.method != 'GET' && _mutationOutcomeUnknown
        ? 'Reconcile the previous write against authoritative server state before authorizing another mutation.'
        : endpoint.path == '/api/v1/admin/events/stream'
        ? 'Use Live audit activity for the authenticated, cancellable event stream.'
        : null;
    if (blocked != null) {
      setState(() => _error = blocked);
      return;
    }
    late final String path;
    late final Map<String, String> query;
    Object? body;
    var clearSensitiveBody = false;
    try {
      path = endpoint.resolvePath(
        Map.fromEntries(
          _pathCtrls.entries.map(
            (entry) => MapEntry(entry.key, entry.value.text),
          ),
        ),
      );
      query = AdminOpsHelpers.stringMap(_queryCtrl.text, 'Query parameters');
      body = endpoint.method == 'GET'
          ? null
          : AdminOpsHelpers.parseJsonObject(_bodyCtrl.text, 'Request body');
      clearSensitiveBody =
          endpoint.method != 'GET' &&
          (AdminOpsHelpers.pathMayReceiveSensitiveInput(endpoint.path) ||
              AdminOpsHelpers.containsSensitiveField(body));
    } on FormatException catch (error) {
      setState(() => _error = error.message);
      return;
    } on ArgumentError catch (error) {
      setState(() => _error = error.message.toString());
      return;
    }
    final requiredConfirmation = AdminOpsHelpers.writeConfirmation(
      endpoint.method,
      path,
    );
    if (_isMutation && _confirmCtrl.text.trim() != requiredConfirmation) {
      setState(
        () => _error =
            'Type the exact confirmation phrase before running this write: $requiredConfirmation',
      );
      return;
    }
    setState(() {
      _running = true;
      _error = null;
      _response = null;
      _rawResponse = null;
    });
    var responseReceived = false;
    try {
      if (AdminOpsHelpers.isSubjectExport(endpoint)) {
        await AdminOpsHelpers.downloadSubjectExport(
          context,
          widget.api,
          path,
          query,
        );
        return;
      }
      final response = await AdminOpsHelpers.dispatchRequest(
        widget.api,
        endpoint,
        path,
        query,
        body,
      );
      responseReceived = true;
      if (endpoint.method != 'GET' && mounted) {
        setState(() => _mutationOutcomeUnknown = false);
      }
      if (mounted) {
        if (endpoint.path == '/api/v1/admin/docs') {
          final document = await widget.api.getText(path, query: query);
          if (mounted) setState(() => _rawResponse = document);
        } else if (AdminOpsHelpers.returnsOneTimeCredential(endpoint)) {
          if (response == null) {
            setState(() => _error = 'The server returned an empty response.');
          } else {
            await AdminOpsHelpers.showOneTimeCredential(
              context,
              response,
              endpoint,
            );
          }
        } else {
          setState(
            () => _response = response == null
                ? null
                : AdminOpsHelpers.redactResponse(response),
          );
        }
      }
    } on SnaplinkAdminApiError catch (error) {
      if (mounted) {
        final unknown =
            endpoint.method != 'GET' &&
            AdminOpsHelpers.isAmbiguousWriteStatus(error.status);
        setState(() {
          _mutationOutcomeUnknown = _mutationOutcomeUnknown || unknown;
          _error = unknown
              ? 'Write outcome is unknown (HTTP ${error.status}). The operation may have partially applied. Use a safe read or the dedicated workflow to reconcile authoritative state before acknowledging and sending another mutation.'
              : error.toString();
        });
      }
    } catch (_) {
      if (mounted) {
        final unknown = endpoint.method != 'GET' && !responseReceived;
        setState(() {
          _mutationOutcomeUnknown = _mutationOutcomeUnknown || unknown;
          _error = unknown
              ? 'Write outcome is unknown because no response was received. The operation may have partially applied. Use a safe read or the dedicated workflow to reconcile authoritative state before acknowledging and sending another mutation.'
              : responseReceived
              ? 'The response was received, but it could not be displayed.'
              : 'The read could not be completed.';
        });
      }
    } finally {
      if (clearSensitiveBody) _bodyCtrl.clear();
      _confirmCtrl.clear();
      if (mounted) setState(() => _running = false);
    }
  }

  Future<void> _acknowledgeReconciliation() async {
    final confirmed = await ConfirmDialog.show(
      context,
      title: 'Authoritative state reconciled?',
      message:
          'Confirm only after checking the affected resource in a safe read or dedicated workflow. This unlocks writes; it does not prove the previous request failed.',
      confirmLabel: 'Unlock writes',
      destructive: true,
      confirmText: 'RECONCILED',
    );
    if (!confirmed || !mounted) return;
    _confirmCtrl.clear();
    setState(() {
      _mutationOutcomeUnknown = false;
      _error =
          'Reconciliation acknowledged. Review the endpoint, path, and body before submitting another write.';
    });
  }

  @override
  Widget build(BuildContext context) => _buildAdminOperationsTab(context);
}
