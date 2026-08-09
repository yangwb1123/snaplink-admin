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
            _SettingsCard(
              icon: Icons.language_outlined,
              title: strings.language,
              description: strings.translate(
                'App language and regional display preferences.',
              ),
              children: [_LanguagePicker()],
            ),
            const SizedBox(height: 16),
            _SettingsCard(
              icon: Icons.palette_outlined,
              title: strings.theme,
              description: strings.translate(
                'Appearance follows the system or your explicit choice.',
              ),
              children: [_ThemePicker(strings: strings)],
            ),
            const SizedBox(height: 16),
            _SettingsCard(
              icon: Icons.view_sidebar_outlined,
              title: strings.adminNavMode,
              description: strings.translate(
                'Standard shows Overview, Clients, and Users. Professional adds '
                'Tenants, Token Security, and Audit Log.',
              ),
              children: [_AdminNavModePicker(strings: strings)],
            ),
            const SizedBox(height: 16),
            _SettingsCard(
              icon: Icons.dns_outlined,
              title: strings.ssoBaseUrl,
              description: strings.translate(
                'Server endpoint used for OIDC and API calls.',
              ),
              children: [
                Form(
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
              icon: Icons.schedule_outlined,
              title: strings.timezone,
              description: strings.translate(
                'Current local timezone of this device.',
              ),
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
  final IconData icon;

  const _SettingsCard({
    required this.title,
    required this.description,
    required this.children,
    required this.icon,
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
            Row(
              children: [
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: theme.colorScheme.primary.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(icon, size: 20, color: theme.colorScheme.primary),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    title,
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Divider(
              height: 1,
              color: theme.colorScheme.outlineVariant.withValues(alpha: 0.5),
            ),
            const SizedBox(height: 12),
            Align(
              alignment: Alignment.centerLeft,
              child: Text(
                description,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
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
    return InputDecorator(
      decoration: InputDecoration(
        isDense: true,
        prefixIcon: const Icon(Icons.translate),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
        contentPadding: const EdgeInsets.symmetric(horizontal: 12),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<Locale>(
          value: current,
          isExpanded: true,
          isDense: true,
          items: const [
            DropdownMenuItem(value: Locale('en'), child: Text('English')),
            DropdownMenuItem(value: Locale('zh'), child: Text('中文')),
          ],
          onChanged: (selection) {
            if (selection != null) AppSettings.instance.locale = selection;
          },
        ),
      ),
    );
  }
}

/// 主题选择：图标瓦片行（system/light/dark），选中态 primaryContainer
/// 填充 + primary 边框 + 对勾徽标，键盘焦点由 InkWell.onFocusChange 驱动。
class _ThemePicker extends StatelessWidget {
  final AppStrings strings;
  const _ThemePicker({required this.strings});

  @override
  Widget build(BuildContext context) {
    final current = AppSettings.instance.themeMode;
    final modes = [
      (ThemeMode.system, Icons.brightness_auto, strings.themeSystem),
      (ThemeMode.light, Icons.light_mode, strings.themeLight),
      (ThemeMode.dark, Icons.dark_mode, strings.themeDark),
    ];
    return Row(
      children: [
        for (final (index, mode) in modes.indexed) ...[
          Expanded(
            child: _ThemeOptionTile(
              mode: mode.$1,
              icon: mode.$2,
              caption: mode.$3,
              selected: current == mode.$1,
              onTap: () => AppSettings.instance.themeMode = mode.$1,
            ),
          ),
          if (index < modes.length - 1) const SizedBox(width: 8),
        ],
      ],
    );
  }
}

class _ThemeOptionTile extends StatefulWidget {
  final ThemeMode mode;
  final IconData icon;
  final String caption;
  final bool selected;
  final VoidCallback onTap;

  const _ThemeOptionTile({
    required this.mode,
    required this.icon,
    required this.caption,
    required this.selected,
    required this.onTap,
  });

  @override
  State<_ThemeOptionTile> createState() => _ThemeOptionTileState();
}

class _ThemeOptionTileState extends State<_ThemeOptionTile> {
  bool _focused = false;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Tooltip(
      message: widget.caption,
      // 本 SDK（Flutter 3.47 master）无 hover/never 模式（设计 §1.1 引用
      // 的枚举值在 SDK 中不存在）：manual = 触屏永不触发，鼠标 hover 仍显示
      // （raw_tooltip.dart 文档：triggerMode 不影响鼠标设备）——即 web 悬停
      // 专属、触屏禁用的设计意图。
      triggerMode: TooltipTriggerMode.manual,
      child: Semantics(
        selected: widget.selected,
        child: InkWell(
          onTap: widget.onTap,
          onFocusChange: (focused) => setState(() => _focused = focused),
          borderRadius: BorderRadius.circular(12),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 150),
            curve: Curves.easeOut,
            padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 4),
            decoration: BoxDecoration(
              color: widget.selected
                  ? colorScheme.primaryContainer
                  : colorScheme.surfaceContainerHighest.withValues(alpha: 0.4),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: widget.selected || _focused
                    ? colorScheme.primary
                    : colorScheme.outlineVariant.withValues(alpha: 0.5),
                width: 2,
              ),
            ),
            child: Stack(
              children: [
                Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      widget.icon,
                      size: 22,
                      color: widget.selected
                          ? colorScheme.primary
                          : colorScheme.onSurfaceVariant,
                    ),
                    const SizedBox(height: 6),
                    Text(
                      widget.caption,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: widget.selected
                            ? colorScheme.primary
                            : colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
                if (widget.selected)
                  Positioned(
                    right: 0,
                    top: 0,
                    child: Icon(
                      Icons.check_circle,
                      size: 16,
                      color: colorScheme.primary,
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _AdminNavModePicker extends StatelessWidget {
  final AppStrings strings;
  const _AdminNavModePicker({required this.strings});

  @override
  Widget build(BuildContext context) {
    final current = AppSettings.instance.adminNavMode;
    return SegmentedButton<AdminNavMode>(
      segments: [
        ButtonSegment(
          value: AdminNavMode.normal,
          label: Text(strings.adminNavModeNormal),
        ),
        ButtonSegment(
          value: AdminNavMode.professional,
          label: Text(strings.adminNavModeProfessional),
        ),
      ],
      selected: {current},
      onSelectionChanged: (selection) =>
          AppSettings.instance.adminNavMode = selection.first,
    );
  }
}
