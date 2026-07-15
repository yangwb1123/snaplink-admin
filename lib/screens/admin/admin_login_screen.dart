import 'package:flutter/material.dart';
import '../../sso_client.dart';
import 'dashboard_screen.dart';

/// LAN-vs-public default: mirrors the demo apps' is_ip_host() heuristic —
/// Uri.base reflects the browser's own location on Flutter Web, so a page
/// served from the NodePort IP defaults to the LAN SSO, everything else to
/// the public domain. Always user-editable below, so a wrong guess is cheap.
String _defaultSsoBase() {
  final host = Uri.base.host;
  final isIp = RegExp(r'^\d+\.\d+\.\d+\.\d+$').hasMatch(host);
  if (isIp) return 'http://192.168.1.139:30090';
  return 'https://sso.ywbsd.site';
}

class AdminLoginScreen extends StatefulWidget {
  const AdminLoginScreen({super.key});

  @override
  State<AdminLoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<AdminLoginScreen> {
  late final TextEditingController _baseUrlCtrl =
      TextEditingController(text: _defaultSsoBase());
  final TextEditingController _userCtrl = TextEditingController();
  final TextEditingController _passCtrl = TextEditingController();
  bool _loading = false;
  String? _error;

  Future<void> _login() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    final client = SSOAdminClient(_baseUrlCtrl.text.trim());
    try {
      await client.login(_userCtrl.text.trim(), _passCtrl.text);
      if (!mounted) return;
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => DashboardScreen(client: client)),
      );
    } on SSOError catch (e) {
      setState(() => _error = e.toString());
    } catch (e) {
      setState(() => _error = 'Network error: $e');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 420),
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Card(
              child: Padding(
                padding: const EdgeInsets.all(28),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.admin_panel_settings, color: Color(0xFF6366F1)),
                        const SizedBox(width: 10),
                        Text('SSO Admin', style: Theme.of(context).textTheme.titleLarge),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Flutter 跨端管理控制台',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                    const SizedBox(height: 24),
                    TextField(
                      controller: _baseUrlCtrl,
                      decoration: const InputDecoration(labelText: 'SSO base URL'),
                    ),
                    const SizedBox(height: 14),
                    TextField(
                      controller: _userCtrl,
                      decoration: const InputDecoration(labelText: '用户名'),
                      onSubmitted: (_) => _login(),
                    ),
                    const SizedBox(height: 14),
                    TextField(
                      controller: _passCtrl,
                      decoration: const InputDecoration(labelText: '密码'),
                      obscureText: true,
                      onSubmitted: (_) => _login(),
                    ),
                    if (_error != null) ...[
                      const SizedBox(height: 14),
                      Text(_error!, style: const TextStyle(color: Colors.redAccent)),
                    ],
                    const SizedBox(height: 20),
                    FilledButton(
                      onPressed: _loading ? null : _login,
                      child: _loading
                          ? const SizedBox(
                              height: 18, width: 18,
                              child: CircularProgressIndicator(strokeWidth: 2))
                          : const Text('登录'),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
