part of 'local_users_tab.dart';

class _LocalUserDraft {
  final String username, email, displayName, password;

  const _LocalUserDraft({
    required this.username,
    required this.email,
    required this.displayName,
    required this.password,
  });

  Map<String, dynamic> get createBody => {
    'username': username,
    'email': email,
    'display_name': displayName,
    'password': password,
  };
  Map<String, dynamic> get updateBody => {
    'email': email,
    'display_name': displayName,
  };
}

class _LocalUserDialog extends StatefulWidget {
  final Map<String, dynamic>? existing;
  const _LocalUserDialog({this.existing});
  @override
  State<_LocalUserDialog> createState() => _LocalUserDialogState();
}

class _LocalUserDialogState extends State<_LocalUserDialog> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _usernameCtrl,
      _emailCtrl,
      _nameCtrl,
      _passwordCtrl;

  bool get _editing => widget.existing != null;

  @override
  void initState() {
    super.initState();
    final existing = widget.existing;
    _usernameCtrl = TextEditingController(
      text: existing?['username']?.toString() ?? '',
    );
    _emailCtrl = TextEditingController(
      text: existing?['email']?.toString() ?? '',
    );
    _nameCtrl = TextEditingController(
      text:
          existing?['display_name']?.toString() ??
          existing?['name']?.toString() ??
          '',
    );
    _passwordCtrl = TextEditingController();
  }

  @override
  void dispose() {
    _usernameCtrl.dispose();
    _emailCtrl.dispose();
    _nameCtrl.dispose();
    _passwordCtrl.dispose();
    super.dispose();
  }

  /// 校验消息本地化：validator 返回目录键 → 渲染时按当前 locale 翻译。
  String? _validate(String? Function(String?) rule, String? value) =>
      rule(value) == null ? null : context.tr(rule(value)!);

  void _submit() {
    if (!_formKey.currentState!.validate()) return;
    Navigator.pop(
      context,
      _LocalUserDraft(
        username: _usernameCtrl.text.trim(),
        email: _emailCtrl.text.trim(),
        displayName: _nameCtrl.text.trim(),
        password: _passwordCtrl.text,
      ),
    );
  }

  Widget _field({
    required TextEditingController controller,
    required String label,
    bool enabled = true,
    bool obscure = false,
    bool autofocus = false,
    TextInputType? keyboard,
    String? Function(String?)? validate,
  }) => Padding(
    padding: const EdgeInsets.only(bottom: 12),
    child: TextFormField(
      controller: controller,
      enabled: enabled,
      autofocus: autofocus,
      obscureText: obscure,
      keyboardType: keyboard,
      decoration: InputDecoration(labelText: label.localized),
      validator: validate,
    ),
  );

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: LocalizedText(_editing ? 'Edit local user' : 'Create local user'),
    content: SizedBox(
      width: 560,
      child: Form(
        key: _formKey,
        autovalidateMode: AutovalidateMode.onUserInteraction,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _field(
                controller: _usernameCtrl,
                label: 'Username',
                enabled: !_editing,
                autofocus: !_editing,
                validate: (v) => _validate(validateSnaplinkLocalUsername, v),
              ),
              _field(
                controller: _emailCtrl,
                label: 'Email',
                keyboard: TextInputType.emailAddress,
                validate: (v) => _validate(validateSnaplinkLocalEmail, v),
              ),
              _field(controller: _nameCtrl, label: 'Display name'),
              if (!_editing)
                _field(
                  controller: _passwordCtrl,
                  label: 'Initial password',
                  obscure: true,
                  validate: (v) =>
                      _validate(validateSnaplinkInitialPassword, v),
                ),
            ],
          ),
        ),
      ),
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(context),
        child: const LocalizedText('Cancel'),
      ),
      FilledButton(onPressed: _submit, child: const LocalizedText('Save')),
    ],
  );
}
