import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:sso_admin/api/snaplink_admin_api.dart';
import 'package:sso_admin/widgets/admin_breadcrumb.dart';
import 'package:sso_admin/i18n/app_strings.dart';

/// ReBAC and WASM authorization policy check tool tab.
class AuthzCheckTab extends StatefulWidget {
  final SnaplinkAdminApi api;
  final SnaplinkAdminCapabilities capabilities;
  const AuthzCheckTab({
    super.key,
    required this.api,
    required this.capabilities,
  });
  @override
  State<AuthzCheckTab> createState() => _AuthzCheckTabState();
}

class _AuthzCheckTabState extends State<AuthzCheckTab> {
  final _rebacCtrl = TextEditingController(
    text: '{"object":"","relation":"","subject":""}',
  );
  final _wasmCtrl = TextEditingController(
    text: '{"principal":"","action":"","resource":{}}',
  );
  Map<String, dynamic>? _rebacResult;
  Map<String, dynamic>? _wasmResult;
  String? _error;
  bool _rebacLoading = false;
  bool _wasmLoading = false;

  bool get _hasRebac =>
      widget.capabilities.has('GET', '/api/v1/admin/rebac/check');
  bool get _hasWasm =>
      widget.capabilities.has('POST', '/api/v1/admin/wasmauthz/check');

  @override
  void dispose() {
    _rebacCtrl.dispose();
    _wasmCtrl.dispose();
    super.dispose();
  }

  Future<void> _checkRebac() async {
    setState(() {
      _rebacLoading = true;
      _error = null;
      _rebacResult = null;
    });
    try {
      final raw = jsonDecode(_rebacCtrl.text);
      if (raw is! Map) throw const FormatException();
      final data = Map<String, dynamic>.from(raw);
      final query = <String, String>{
        for (final key in const ['object', 'relation', 'subject'])
          key: data[key]?.toString().trim() ?? '',
      };
      if (query.values.any((value) => value.isEmpty)) {
        throw const FormatException();
      }
      final result = await widget.api.get(
        '/api/v1/admin/rebac/check',
        query: query,
      );
      if (!mounted) return;
      setState(() {
        _rebacResult = result;
        _rebacLoading = false;
      });
    } on SnaplinkAdminApiError catch (e) {
      if (mounted) {
        setState(() {
          _error = e.toString();
          _rebacLoading = false;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _error = 'Invalid JSON or request failed.';
          _rebacLoading = false;
        });
      }
    }
  }

  Future<void> _checkWasm() async {
    setState(() {
      _wasmLoading = true;
      _error = null;
      _wasmResult = null;
    });
    try {
      final data = jsonDecode(_wasmCtrl.text);
      final result = await widget.api.post(
        '/api/v1/admin/wasmauthz/check',
        data as Map<String, dynamic>,
      );
      if (!mounted) return;
      setState(() {
        _wasmResult = result;
        _wasmLoading = false;
      });
    } on SnaplinkAdminApiError catch (e) {
      if (mounted) {
        setState(() {
          _error = e.toString();
          _wasmLoading = false;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _error = 'Invalid JSON or request failed.';
          _wasmLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!_hasRebac && !_hasWasm) {
      return const Center(
        child: Text(
          'Authorization check tools are not enabled on this replica.',
        ),
      );
    }
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        AdminBreadcrumb(),
        Text(
          AppStrings.of(context).authzChecks,
          style: Theme.of(context).textTheme.headlineSmall,
        ),
        const SizedBox(height: 4),
        const Text('Test ReBAC and WASM authorization policies.'),
        if (_error != null)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Text(
              _error!,
              style: const TextStyle(color: Colors.redAccent),
            ),
          ),
        if (_hasRebac) ...[const SizedBox(height: 16), _rebacCard(context)],
        if (_hasWasm) ...[const SizedBox(height: 16), _wasmCard(context)],
      ],
    );
  }

  Widget _rebacCard(BuildContext context) => Card(
    child: Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'ReBAC policy check',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _rebacCtrl,
            maxLines: 4,
            style: const TextStyle(fontFamily: 'monospace', fontSize: 12),
            decoration: const InputDecoration(
              labelText: 'Check parameters',
              hintText:
                  '{"object":"document:42","relation":"viewer","subject":"user:alice"}',
            ),
          ),
          const SizedBox(height: 10),
          FilledButton(
            onPressed: _rebacLoading ? null : _checkRebac,
            child: _rebacLoading
                ? const SizedBox(
                    height: 16,
                    width: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Text('Check ReBAC'),
          ),
          if (_rebacResult != null) ...[
            const SizedBox(height: 12),
            const Text(
              'Result:',
              style: TextStyle(fontWeight: FontWeight.w500),
            ),
            SelectableText(
              const JsonEncoder.withIndent('  ').convert(_rebacResult!),
              style: const TextStyle(fontFamily: 'monospace', fontSize: 12),
            ),
          ],
        ],
      ),
    ),
  );

  Widget _wasmCard(BuildContext context) => Card(
    child: Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'WASM authorization check',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _wasmCtrl,
            maxLines: 4,
            style: const TextStyle(fontFamily: 'monospace', fontSize: 12),
            decoration: const InputDecoration(
              labelText: 'Request JSON',
              hintText: '{"principal":"","action":"","resource":{}}',
            ),
          ),
          const SizedBox(height: 10),
          FilledButton(
            onPressed: _wasmLoading ? null : _checkWasm,
            child: _wasmLoading
                ? const SizedBox(
                    height: 16,
                    width: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Text('Check WASM'),
          ),
          if (_wasmResult != null) ...[
            const SizedBox(height: 12),
            const Text(
              'Result:',
              style: TextStyle(fontWeight: FontWeight.w500),
            ),
            SelectableText(
              const JsonEncoder.withIndent('  ').convert(_wasmResult!),
              style: const TextStyle(fontFamily: 'monospace', fontSize: 12),
            ),
          ],
        ],
      ),
    ),
  );
}
