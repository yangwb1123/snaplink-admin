import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:sso_admin/api/snaplink_admin_api.dart';
import 'package:sso_admin/widgets/admin_breadcrumb.dart';
import 'admin_route.dart';
import 'tenant_export_download.dart';
import 'admin_ops_helpers.dart';

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

  List<SnaplinkAdminEndpoint> get _adminEndpoints =>
      SnaplinkAdminOperationCatalog.mergedWith(widget.endpoints)
          .where(
            (endpoint) =>
                endpoint.path.startsWith('/api/v1/admin/') ||
                endpoint.path.startsWith('/api/v1/clients/') ||
                endpoint.path.startsWith('/api/v1/audit') ||
                endpoint.path.startsWith('/api/v1/compliance/') ||
                endpoint.path.startsWith('/api/v1/scim/') ||
                endpoint.path.startsWith('/api/v1/netpolicy/'),
          )
          .toList(growable: false);

  @override
  void initState() {
    super.initState();
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
        (endpoint?.pathParameters ?? const <String>[]).map(
          (parameter) => MapEntry(parameter, TextEditingController()),
        ),
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

  Future<void> _run() async {
    final endpoint = _selected;
    if (endpoint == null) return;
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

    if (_isMutation && _confirmCtrl.text.trim() != 'CONFIRM') {
      setState(() => _error = 'Type CONFIRM before running a write operation.');
      return;
    }
    setState(() {
      _running = true;
      _error = null;
      _response = null;
      _rawResponse = null;
    });
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
          setState(() => _response = response);
        }
      }
    } on SnaplinkAdminApiError catch (error) {
      if (mounted) {
        setState(() => _error = error.toString());
      }
    } catch (_) {
      if (mounted) {
        setState(() => _error = 'The operation could not be completed.');
      }
    } finally {
      if (clearSensitiveBody) _bodyCtrl.clear();
      if (mounted) setState(() => _running = false);
    }
  }

  /// Advanced operations intentionally accept arbitrary documented JSON. Once
  /// a request that can contain a credential has been submitted, don't leave
  /// its password, secret, or raw token in the browser form state.

  // moved to AdminOpsHelpers.containsSensitiveField
  bool _containsSensitiveField(Object? value) => AdminOpsHelpers.containsSensitiveField(value);

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
          'Advanced operations',
          style: Theme.of(context).textTheme.headlineSmall,
        ),
        const SizedBox(height: 8),
        const Text(
          'Documented Snaplink administration routes are listed here; runtime inventory marks routes the current replica reports as active. Server-side feature gates remain authoritative. Write operations are audited and require explicit confirmation.',
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
              decoration: InputDecoration(
                labelText: 'Path parameter: ${entry.key}',
              ),
            ),
          ],
          const SizedBox(height: 12),
          TextField(
            controller: _queryCtrl,
            maxLines: 3,
            enabled: !_running,
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
              enabled: !_running,
              style: const TextStyle(fontFamily: 'monospace', fontSize: 13),
              decoration: const InputDecoration(labelText: 'Request body JSON'),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _confirmCtrl,
              enabled: !_running,
              decoration: const InputDecoration(
                labelText: 'Type CONFIRM to authorize this write operation',
              ),
            ),
          ],
          const SizedBox(height: 16),
          FilledButton.icon(
            onPressed: _running ? null : _run,
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
