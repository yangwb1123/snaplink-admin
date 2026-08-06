import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import '../app_settings.dart';
import '../i18n/app_strings.dart';
import '../services/browser_navigation.dart';
import '../services/product_api_origin.dart';
import '../session.dart';

/// Post-login settings: language, theme, SSO base URL (native-only), and a
/// read-only timezone display. Reads/writes [AppSettings.instance] directly —
/// there is no local draft state for language/theme, changes apply and
/// propagate (via main.dart's ListenableBuilder) the instant they're made.
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
            _SettingsCard(
              title: strings.language,
              description: strings.translate('App language and regional display preferences.'),
              children: [_LanguagePicker()],
            ),
            const SizedBox(height: 16),
            _SettingsCard(
              title: strings.theme,
              description: strings.translate('Appearance follows the system or your explicit choice.'),
              children: [_ThemePicker(strings: strings)],
            ),
            const SizedBox(height: 16),
            _SettingsCard(
              title: strings.ssoBaseUrl,
              description: strings.translate('Server endpoint used for OIDC and API calls.'),
              children: [
                Form(
                  key: _baseUrlFormKey,
                  child: TextFormField(
                    controller: _baseUrlController,
                    enabled: !kIsWeb,
                    keyboardType: TextInputType.url,
                    autovalidateMode: AutovalidateMode.onUserInteraction,
                    decoration: InputDecoration(helperText: strings.ssoBaseUrlHint),
                    validator: (value) {
                      if (kIsWeb) return null;
                      try {
                        AppSettings.normalizeSsoBaseUrl(value);
                        return null;
                      } on FormatException {
                        return strings.translate(
                          'Enter an absolute HTTPS server URL without credentials, '
                          'path, query, or fragment. HTTP is allowed only for '
                          'localhost or loopback addresses.',
                        );
                      }
                    },
                  ),
                ),
                const SizedBox(height: 12),
                Align(
                  alignment: Alignment.centerLeft,
                  child: FilledButton(
                    onPressed: kIsWeb ? null : _saveBaseUrl,
                    child: Text(strings.save),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            _SettingsCard(
              title: strings.timezone,
              description: strings.translate('Current local timezone of this device.'),
              children: [
                Row(
                  children: [
                    const Icon(Icons.schedule, size: 18),
                    const SizedBox(width: 8),
                    Text(DateTime.now().timeZoneName),
                  ],
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// 设置分组卡片（Stripe/Notion 风格）：标题 + 说明 + 控件。
class _SettingsCard extends StatelessWidget {
  final String title;
  final String description;
  final List<Widget> children;

  const _SettingsCard({
    required this.title,
    required this.description,
    required this.children,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              description,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 16),
            ...children,
          ],
        ),
      ),
    );
  }
}

class _LanguagePicker extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final current = AppSettings.instance.locale;
    return SegmentedButton<Locale>(
      segments: const [
        ButtonSegment(value: Locale('en'), label: Text('English')),
        ButtonSegment(value: Locale('zh'), label: Text('中文')),
      ],
      selected: {current},
      onSelectionChanged: (selection) =>
          AppSettings.instance.locale = selection.first,
    );
  }
}

class _ThemePicker extends StatelessWidget {
  final AppStrings strings;
  const _ThemePicker({required this.strings});

  @override
  Widget build(BuildContext context) {
    final current = AppSettings.instance.themeMode;
    return SegmentedButton<ThemeMode>(
      segments: [
        ButtonSegment(
          value: ThemeMode.system,
          label: Text(strings.themeSystem),
        ),
        ButtonSegment(value: ThemeMode.light, label: Text(strings.themeLight)),
        ButtonSegment(value: ThemeMode.dark, label: Text(strings.themeDark)),
      ],
      selected: {current},
      onSelectionChanged: (selection) =>
          AppSettings.instance.themeMode = selection.first,
    );
  }
}
