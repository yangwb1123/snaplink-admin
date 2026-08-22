import 'package:flutter/material.dart';
import 'package:sso_admin/i18n/localized_text.dart';
import 'package:sso_admin/api/sso_client.dart';
import 'package:sso_admin/widgets/app_snackbar.dart';

part 'client_form_dialog_view.dart';

/// Create/edit form for an [AdminClient]. Pass [existing] to edit; omit to create.
class ClientFormDialog extends StatefulWidget {
  final SSOAdminClient client;
  final Map<String, dynamic>? existing;

  const ClientFormDialog({super.key, required this.client, this.existing});

  bool get isEdit => existing != null;

  @override
  State<ClientFormDialog> createState() => _ClientFormDialogState();
}

class _ClientFormDialogState extends State<ClientFormDialog> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _idController;
  late final TextEditingController _nameController;
  late final TextEditingController _redirectUrisController;
  late final TextEditingController _loginPageUriController;
  late final TextEditingController _allowedScopesController;
  late final TextEditingController _allowedAuthenticatorsController;
  late final TextEditingController _secretController;
  String _tokenStrategy = 'jwt';
  bool _active = true;
  bool _submitting = false;

  @override
  void initState() {
    super.initState();
    final existing = widget.existing;
    _idController = TextEditingController(
      text: existing?['id']?.toString() ?? '',
    );
    _nameController = TextEditingController(
      text: existing?['name']?.toString() ?? '',
    );
    _redirectUrisController = TextEditingController(
      text: _joinList(existing?['redirect_uris']),
    );
    _loginPageUriController = TextEditingController(
      text:
          existing?['login_page_uri']?.toString() ??
          existing?['loginPageUri']?.toString() ??
          '',
    );
    _allowedScopesController = TextEditingController(
      text: _joinList(existing?['allowed_scopes']),
    );
    _allowedAuthenticatorsController = TextEditingController(
      text: _joinList(
        existing?['allowed_authenticators'] ??
            existing?['allowedAuthenticators'],
      ),
    );
    _secretController = TextEditingController();
    final strategy =
        existing?['token_strategy']?.toString() ??
        existing?['tokenStrategy']?.toString();
    if (strategy == 'jwt' || strategy == 'session') _tokenStrategy = strategy!;
    _active = existing?['active'] == true || existing == null;
  }

  static String _joinList(dynamic value) {
    if (value is List) return value.map((e) => e.toString()).join('\n');
    return '';
  }

  static List<String> _splitList(String text) => text
      .split(RegExp(r'[,\n]'))
      .map((s) => s.trim())
      .where((s) => s.isNotEmpty)
      .toList();

  static String? _validateRedirectUris(String? value) {
    for (final raw in _splitList(value ?? '')) {
      final uri = Uri.tryParse(raw);
      if (uri == null ||
          !uri.hasScheme ||
          uri.fragment.isNotEmpty ||
          uri.userInfo.isNotEmpty) {
        return 'Invalid redirect URI: {uri}'.localized.replaceFirst(
          '{uri}',
          raw,
        );
      }
    }
    return null;
  }

  static String? _validateLoginPageUri(String? value) {
    final raw = value?.trim() ?? '';
    if (raw.isEmpty) return null;
    final uri = Uri.tryParse(raw);
    if (uri == null ||
        !uri.hasScheme ||
        !uri.hasAuthority ||
        uri.host.isEmpty ||
        uri.userInfo.isNotEmpty) {
      return 'Use an HTTPS login page URI (or localhost HTTP).'.localized;
    }
    if (uri.scheme == 'https') return null;
    final isLoopback =
        uri.host == 'localhost' || uri.host == '127.0.0.1' || uri.host == '::1';
    if (uri.scheme == 'http' && isLoopback) return null;
    return 'Use an HTTPS login page URI (or localhost HTTP).'.localized;
  }

  void _selectTokenStrategy(Set<String> selection) =>
      setState(() => _tokenStrategy = selection.first);

  void _setActive(bool value) => setState(() => _active = value);

  @override
  void dispose() {
    _idController.dispose();
    _nameController.dispose();
    _redirectUrisController.dispose();
    _loginPageUriController.dispose();
    _allowedScopesController.dispose();
    _allowedAuthenticatorsController.dispose();
    _secretController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _submitting = true);
    final body = <String, dynamic>{
      'name': _nameController.text.trim(),
      'redirect_uris': _splitList(_redirectUrisController.text),
      'login_page_uri': _loginPageUriController.text.trim(),
      'allowed_scopes': _splitList(_allowedScopesController.text),
      'allowed_authenticators': _splitList(
        _allowedAuthenticatorsController.text,
      ),
      'token_strategy': _tokenStrategy,
      'active': _active,
    };
    final secret = _secretController.text.trim();
    if (secret.isNotEmpty) body['secret'] = secret;
    try {
      if (widget.isEdit) {
        final id = widget.existing!['id'].toString();
        await widget.client.updateClient(id, body);
      } else {
        body['id'] = _idController.text.trim();
        await widget.client.createClient(body);
      }
      if (!mounted) return;
      Navigator.pop(context, true);
    } on SSOError catch (e) {
      if (!mounted) return;
      setState(() => _submitting = false);
      showAppSnackBar(
        context,
        content: Text(e.toString()),
        kind: AppSnackBarKind.error,
      );
    }
  }

  @override
  Widget build(BuildContext context) => _buildClientFormDialog(context);
}
