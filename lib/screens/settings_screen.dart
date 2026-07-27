import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import '../app_settings.dart';
import '../i18n/app_strings.dart';

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
    AppSettings.instance.ssoBaseUrlOverride = _baseUrlController.text;
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
          padding: const EdgeInsets.all(24),
          children: [
            Text(
              strings.language,
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            _LanguagePicker(),
            const SizedBox(height: 32),
            Text(strings.theme, style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            _ThemePicker(strings: strings),
            const SizedBox(height: 32),
            Text(
              strings.ssoBaseUrl,
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            TextFormField(
              controller: _baseUrlController,
              enabled: !kIsWeb,
              decoration: InputDecoration(helperText: strings.ssoBaseUrlHint),
            ),
            const SizedBox(height: 12),
            Align(
              alignment: Alignment.centerLeft,
              child: FilledButton(
                onPressed: kIsWeb ? null : _saveBaseUrl,
                child: Text(strings.save),
              ),
            ),
            const SizedBox(height: 32),
            Text(
              strings.timezone,
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            Text(
              DateTime.now().timeZoneName,
              style: Theme.of(context).textTheme.bodyLarge,
            ),
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
