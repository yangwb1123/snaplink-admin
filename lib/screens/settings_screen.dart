import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import '../app_settings.dart';
import '../i18n/app_strings.dart';
import '../services/browser_navigation.dart';
import '../services/product_api_origin.dart';
import '../session.dart';
import '../widgets/language_selector.dart';
import 'settings/settings_form_layout.dart';
import 'settings/settings_theme_picker.dart';

/// Post-login settings: language, theme, admin nav mode, SSO base URL
/// (native-only), and a read-only timezone display. Reads/writes
/// [AppSettings.instance] directly — there is no local draft state for
/// language/theme, changes apply and propagate (via main.dart's
/// ListenableBuilder) the instant they're made.
///
/// Layout: antd/Stripe-style form rows inside two groups — a compact
/// "preferences" card and a "service" card that highlights the SSO base URL
/// (the one setting with side effects: changing it discards the session).
/// Every row is an icon + label + control line with a divider; no more
/// full-width card per setting.
class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final _baseUrlFormKey = GlobalKey<FormState>();
  late final TextEditingController _baseUrlController;

  @override
  void initState() {
    super.initState();
    _baseUrlController = TextEditingController(
      text: AppSettings.instance.ssoBaseUrlOverride,
    );
  }

  @override
  void dispose() {
    _baseUrlController.dispose();
    super.dispose();
  }

  String? _validateBaseUrl(String? value) {
    if (kIsWeb) return null;
    try {
      AppSettings.normalizeSsoBaseUrl(value);
      return null;
    } on FormatException {
      return AppStrings.of(context).translate(
        'Enter an absolute HTTPS server URL without credentials, '
        'path, query, or fragment. HTTP is allowed only for '
        'localhost or loopback addresses.',
      );
    }
  }

  void _saveBaseUrl() {
    if (!(_baseUrlFormKey.currentState?.validate() ?? false)) return;
    final previousOrigin = ProductApiOrigin.baseUri;
    AppSettings.instance.ssoBaseUrlOverride = _baseUrlController.text;
    _baseUrlController.text = AppSettings.instance.ssoBaseUrlOverride ?? '';
    final originChanged = previousOrigin != ProductApiOrigin.baseUri;
    if (originChanged && Session.read() != null) {
      // A bearer minted by one deployment must never be carried into a newly
      // configured deployment. Treat the origin change as an authentication
      // boundary and discard the entire navigation stack as well.
      Session.clear();
      BrowserNavigation.replaceLocation('/login/');
      return;
    }
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(AppStrings.of(context).saved)));
  }

  @override
  Widget build(BuildContext context) {
    final strings = AppStrings.of(context);
    return Scaffold(
      appBar: AppBar(title: Text(strings.settings)),
      body: ListenableBuilder(
        listenable: AppSettings.instance,
        builder: (context, _) => ListView(
          padding: const EdgeInsets.all(16),
          children: [
            // ── 偏好分组：紧凑 form 行 ──
            SettingsGroup(
              children: [
                SettingsFormItem(
                  icon: Icons.translate,
                  iconColor: const Color(0xFF0EA5E9), // sky
                  label: strings.language,
                  control: const LanguageDropdown(),
                ),
                SettingsFormItem(
                  icon: Icons.palette_outlined,
                  iconColor: const Color(0xFF7C6FF0), // indigo-violet
                  label: strings.theme,
                  description: strings.translate(
                    'Appearance follows the system or your explicit choice.',
                  ),
                  control: SettingsThemePicker(strings: strings),
                ),
                SettingsFormItem(
                  icon: Icons.view_sidebar_outlined,
                  iconColor: const Color(0xFF10B981), // emerald
                  label: strings.adminNavMode,
                  description: strings.translate(
                    'Standard shows Overview, Clients, and Users. Professional '
                    'shows every module enabled by your server.',
                  ),
                  control: _AdminNavModeSwitch(),
                ),
              ],
            ),
            const SizedBox(height: 16),
            // ── 服务分组：SSO 地址是唯一有副作用的设置（换源会清会话），
            // 用 amber 图标 + 行内表单突出。 ──
            SettingsGroup(
              children: [
                SettingsFormItem(
                  icon: Icons.dns_outlined,
                  iconColor: const Color(0xFFF59E0B), // amber（高风险强调）
                  label: strings.ssoBaseUrl,
                  description: strings.translate(
                    'Server endpoint used for OIDC and API calls. Changing it '
                    'discards the current session.',
                  ),
                  control: SizedBox(
                    width: 320,
                    child: Form(
                      key: _baseUrlFormKey,
                      child: TextFormField(
                        controller: _baseUrlController,
                        enabled: !kIsWeb,
                        keyboardType: TextInputType.url,
                        autovalidateMode: AutovalidateMode.onUserInteraction,
                        decoration: InputDecoration(
                          helperText: strings.ssoBaseUrlHint,
                        ),
                        validator: _validateBaseUrl,
                      ),
                    ),
                  ),
                ),
                SettingsFormItem(
                  icon: Icons.schedule_outlined,
                  iconColor: const Color(0xFF64748B), // slate
                  label: strings.timezone,
                  description: strings.translate(
                    'Current local timezone of this device.',
                  ),
                  control: Text(DateTime.now().timeZoneName),
                ),
              ],
            ),
            // 保存按钮跟随 SSO 行（web 禁用）。
            const SizedBox(height: 12),
            Align(
              alignment: Alignment.centerRight,
              child: FilledButton(
                onPressed: kIsWeb ? null : _saveBaseUrl,
                child: Text(strings.save),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// 管理导航模式：Switch（开启 = 专业模式，显示全部能力模块）。
class _AdminNavModeSwitch extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final strings = AppStrings.of(context);
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(strings.adminNavModeProfessional),
        const SizedBox(width: 8),
        Switch(
          value: AppSettings.instance.adminNavMode ==
              AdminNavMode.professional,
          onChanged: (professional) => AppSettings.instance.adminNavMode =
              professional ? AdminNavMode.professional : AdminNavMode.normal,
        ),
      ],
    );
  }
}
