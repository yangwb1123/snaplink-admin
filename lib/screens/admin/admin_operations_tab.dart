import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:sso_admin/api/snaplink_admin_api.dart';
import 'package:sso_admin/i18n/app_strings.dart';
import 'package:sso_admin/widgets/admin_breadcrumb.dart';
import 'package:sso_admin/widgets/confirm_dialog.dart';

import 'admin_ops_helpers.dart';
import 'tenant_export_download.dart';

/// Advanced, capability-bound access to Snaplink's optional admin routes.
/// This is not an open URL console: the selector is populated from Snaplink's
/// documented contract and enriched with the authenticated replica's runtime
/// inventory. Every mutation needs an explicit confirmation, providing a safe
/// operational bridge while high-volume workflows receive dedicated screens.
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
    if (!_adminEndpoints.contains(_selected)) {
      _select(_defaultEndpoint());
    }
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

  @override
  void dispose() {
    _bodyCtrl.dispose();
    _queryCtrl.dispose();
    _confirmCtrl.dispose();
    for (final controller in _pathCtrls.values) {
      controller.dispose();
    }
    super.dispose();
  }

  void _select(SnaplinkAdminEndpoint? endpoint) {
    for (final controller in _pathCtrls.values) {
      controller.dispose();
    }
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
    if (mounted) setState(() {});
  }

  String get _confirmationHint {
    final endpoint = _selected;
    if (endpoint == null) return 'CONFIRM';
    try {
      final path = endpoint.resolvePath({
        for (final entry in _pathCtrls.entries) entry.key: entry.value.text,
      });
      return AdminOpsHelpers.writeConfirmation(endpoint.method, path);
    } catch (_) {
      return 'CONFIRM ${endpoint.method} <resolved path>';
    }
  }

  Future<void> _run() async {
    final endpoint = _selected;
    if (endpoint == null) return;
    if (endpoint.method != 'GET' && _mutationOutcomeUnknown) {
      setState(
        () => _error =
            'Reconcile the previous write against authoritative server state '
            'before authorizing another mutation.',
      );
      return;
    }
    if (endpoint.path == '/api/v1/admin/events/stream') {
      setState(
        () => _error =
            'Use Live audit activity for the authenticated, cancellable event stream.',
      );
      return;
    }
    late final String path;
    late final Map<String, String> query;
    Object? body;
    var clearSensitiveBody = false;
    try {
      path = endpoint.resolvePath({
        for (final entry in _pathCtrls.entries) entry.key: entry.value.text,
      });
      query = _stringMap(_queryCtrl.text, 'Query parameters');
      if (endpoint.method != 'GET') {
        body = _jsonObject(_bodyCtrl.text, 'Request body');
        clearSensitiveBody =
            AdminOpsHelpers.pathMayReceiveSensitiveInput(endpoint.path) ||
            _containsSensitiveField(body);
      }
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
            'Type the exact confirmation phrase before running this write: '
            '$requiredConfirmation',
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
        final export = await widget.api.getDownload(path, query: query);
        if (mounted) {
          downloadAdminAttachment(
            export,
            fallbackFilename: 'snaplink-subject-export.json',
          );
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Subject export downloaded without previewing it.'),
            ),
          );
        }
        return;
      }
      final response = switch (endpoint.method) {
        'GET' when endpoint.path == '/api/v1/admin/docs' => null,
        'GET' => await widget.api.get(path, query: query),
        'POST' => await widget.api.post(path, body, _contentType(endpoint)),
        'PUT' => await widget.api.put(path, body, _contentType(endpoint)),
        'PATCH' => await widget.api.patch(path, body, _contentType(endpoint)),
        'DELETE' => await widget.api.delete(path, body, _contentType(endpoint)),
        _ => throw ArgumentError.value(
          endpoint.method,
          'method',
          'Unsupported HTTP method',
        ),
      };
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
            await _showOneTimeCredential(response, endpoint);
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
          if (unknown) _mutationOutcomeUnknown = true;
          _error = unknown
              ? 'Write outcome is unknown (HTTP ${error.status}). The '
                    'operation may have partially applied. Use a safe read or '
                    'the dedicated workflow to reconcile authoritative state '
                    'before acknowledging and sending another mutation.'
              : error.toString();
        });
      }
    } catch (_) {
      if (mounted) {
        final unknown = endpoint.method != 'GET' && !responseReceived;
        setState(() {
          if (unknown) _mutationOutcomeUnknown = true;
          _error = unknown
              ? 'Write outcome is unknown because no response was received. '
                    'The operation may have partially applied. Use a safe read '
                    'or the dedicated workflow to reconcile authoritative '
                    'state before acknowledging and sending another mutation.'
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
          'Confirm only after checking the affected resource in a safe read '
          'or dedicated workflow. This unlocks writes; it does not prove the '
          'previous request failed.',
      confirmLabel: 'Unlock writes',
      destructive: true,
      confirmText: 'RECONCILED',
    );
    if (!confirmed || !mounted) return;
    _confirmCtrl.clear();
    setState(() {
      _mutationOutcomeUnknown = false;
      _error =
          'Reconciliation acknowledged. Review the endpoint, path, and body '
          'before submitting another write.';
    });
  }

  /// Advanced operations intentionally accept arbitrary documented JSON. Once
  /// a request that can contain a credential has been submitted, don't leave
  /// its password, secret, or raw token in the browser form state.

  // moved to AdminOpsHelpers.containsSensitiveField
  bool _containsSensitiveField(Object? value) =>
      AdminOpsHelpers.containsSensitiveField(value);

  Map<String, dynamic> _jsonObject(String value, String label) {
    try {
      final decoded = jsonDecode(value.trim().isEmpty ? '{}' : value);
      if (decoded is Map<String, dynamic>) return decoded;
      if (decoded is Map) return Map<String, dynamic>.from(decoded);
    } on FormatException {
      // Normalized below so the operator sees which input needs correction.
    }
    throw FormatException('$label must be a JSON object.');
  }

  Future<void> _showOneTimeCredential(
    Map<String, dynamic> response,
    SnaplinkAdminEndpoint endpoint,
  ) async {
    await AdminOpsHelpers.showOneTimeCredential(context, response, endpoint);
  }

  String _contentType(SnaplinkAdminEndpoint endpoint) =>
      endpoint.path.startsWith('/api/v1/scim/')
      ? 'application/scim+json'
      : 'application/json';

  Map<String, String> _stringMap(String value, String label) {
    final object = _jsonObject(value, label);
    return object.map((key, item) => MapEntry(key, item.toString()));
  }

  @override
  Widget build(BuildContext context) {
    if (_adminEndpoints.isEmpty) {
      return const Center(
        child: Text(
          'No optional administration routes are registered on this replica.',
        ),
      );
    }
    final endpoint = _selected;
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        AdminBreadcrumb(),
        Text(
          AppStrings.of(context).adminOperations,
          style: Theme.of(context).textTheme.headlineSmall,
        ),
        const SizedBox(height: 8),
        const Text(
          'Documented Snaplink administration routes are listed here; runtime inventory marks routes the current replica reports as active. Server-side feature gates remain authoritative. Write operations are audited and require explicit confirmation.',
        ),
        const SizedBox(height: 4),
        const Text(
          'Provider configuration routes are intentionally hidden because '
          'the current backend DTO can echo stored client secrets. Decoded '
          'snapshot-resource reads are also hidden because they may contain '
          'credential attributes. High-impact workflows with dedicated '
          'preview or reconciliation screens cannot be bypassed here.',
          style: TextStyle(color: Colors.orangeAccent),
        ),
        const SizedBox(height: 16),
        DropdownButtonFormField<SnaplinkAdminEndpoint>(
          initialValue: endpoint,
          isExpanded: true,
          decoration: const InputDecoration(
            labelText: 'Administration endpoint',
          ),
          items: _adminEndpoints
              .map(
                (item) => DropdownMenuItem(
                  value: item,
                  child: Text(
                    '${item.method} ${item.path}',
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              )
              .toList(growable: false),
          onChanged: _running ? null : _select,
        ),
        if (endpoint != null) ...[
          const SizedBox(height: 16),
          Text(
            endpoint.feature == 'documented'
                ? 'Availability: documented contract; this replica has not advertised the route.'
                : 'Runtime feature surface: ${endpoint.feature}',
          ),
          for (final entry in _pathCtrls.entries) ...[
            const SizedBox(height: 12),
            TextField(
              controller: entry.value,
              enabled: !_running && (!_isMutation || !_mutationOutcomeUnknown),
              decoration: InputDecoration(
                labelText: 'Path parameter: ${entry.key}',
              ),
            ),
          ],
          const SizedBox(height: 12),
          TextField(
            controller: _queryCtrl,
            maxLines: 3,
            enabled: !_running && (!_isMutation || !_mutationOutcomeUnknown),
            style: const TextStyle(fontFamily: 'monospace', fontSize: 13),
            decoration: const InputDecoration(
              labelText: 'Query parameters JSON',
              helperText: 'Use {} when none are required.',
            ),
          ),
          if (_isMutation) ...[
            const SizedBox(height: 12),
            TextField(
              controller: _bodyCtrl,
              maxLines: 8,
              enabled: !_running && !_mutationOutcomeUnknown,
              style: const TextStyle(fontFamily: 'monospace', fontSize: 13),
              decoration: const InputDecoration(labelText: 'Request body JSON'),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _confirmCtrl,
              enabled: !_running && !_mutationOutcomeUnknown,
              decoration: InputDecoration(
                labelText: 'Exact write confirmation',
                helperText: _confirmationHint,
              ),
            ),
          ],
          const SizedBox(height: 16),
          FilledButton.icon(
            onPressed: _running || (_isMutation && _mutationOutcomeUnknown)
                ? null
                : _run,
            icon: _running
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.play_arrow),
            label: Text('Run ${endpoint.method}'),
          ),
        ],
        if (_mutationOutcomeUnknown) ...[
          const SizedBox(height: 16),
          Card(
            color: Theme.of(context).colorScheme.errorContainer,
            child: ListTile(
              leading: const Icon(Icons.sync_problem_outlined),
              title: const Text('Previous write outcome is unknown'),
              subtitle: const Text(
                'Mutation inputs are locked. Select and run a safe GET, or '
                'use the dedicated resource screen, then explicitly '
                'acknowledge reconciliation.',
              ),
              trailing: TextButton(
                onPressed: _running ? null : _acknowledgeReconciliation,
                child: const Text('I reconciled server state'),
              ),
            ),
          ),
        ],
        if (_error != null) ...[
          const SizedBox(height: 16),
          Text(_error!, style: const TextStyle(color: Colors.redAccent)),
        ],
        if (_response != null || _rawResponse != null) ...[
          const SizedBox(height: 16),
          Row(
            children: [
              Text('Response', style: Theme.of(context).textTheme.titleMedium),
              const Spacer(),
              TextButton.icon(
                onPressed: () async {
                  await Clipboard.setData(
                    ClipboardData(
                      text: _response == null
                          ? _rawResponse!
                          : const JsonEncoder.withIndent(
                              '  ',
                            ).convert(_response),
                    ),
                  );
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Response copied to clipboard.'),
                      ),
                    );
                  }
                },
                icon: const Icon(Icons.copy, size: 16),
                label: const Text('Copy'),
              ),
            ],
          ),
          Container(
            constraints: const BoxConstraints(maxHeight: 360),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              border: Border.all(color: Theme.of(context).dividerColor),
              borderRadius: BorderRadius.circular(8),
            ),
            child: SingleChildScrollView(
              child: SelectableText(
                _response == null
                    ? _rawResponse!
                    : const JsonEncoder.withIndent('  ').convert(_response),
                style: const TextStyle(fontFamily: 'monospace', fontSize: 12),
              ),
            ),
          ),
        ],
      ],
    );
  }
}
