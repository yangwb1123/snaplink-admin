import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import '../app_settings.dart';
import '../i18n/app_strings.dart';
import '../services/browser_navigation.dart';
import '../services/product_api_origin.dart';
import '../session.dart';
import '../widgets/language_selector.dart';
import '../widgets/theme_selector.dart';

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
            _SettingsGroup(
              children: [
                _SettingsFormItem(
                  icon: Icons.translate,
                  iconColor: const Color(0xFF0EA5E9), // sky
                  label: strings.language,
                  control: const LanguageDropdown(),
                ),
                _SettingsFormItem(
                  icon: Icons.palette_outlined,
                  iconColor: const Color(0xFF7C6FF0), // indigo-violet
                  label: strings.theme,
                  description: strings.translate(
                    'Appearance follows the system or your explicit choice.',
                  ),
                  control: _ThemePicker(strings: strings),
                ),
                _SettingsFormItem(
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
            _SettingsGroup(
              children: [
                _SettingsFormItem(
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
                _SettingsFormItem(
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

/// 设置分组卡片：多个 form 行 + 分隔线，替代"每个设置一张大卡片"。
class _SettingsGroup extends StatelessWidget {
  final List<Widget> children;

  const _SettingsGroup({required this.children});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        child: Column(
          children: [
            for (final (index, child) in children.indexed) ...[
              if (index > 0)
                Divider(
                  height: 1,
                  indent: 32, // 对齐 label 起点（icon 20 + gap 12）
                  color: theme.colorScheme.outlineVariant.withValues(alpha: 0.5),
                ),
              child,
            ],
          ],
        ),
      ),
    );
  }
}

/// 单行 form item：彩色图标 + 标签（可带描述）+ 控件，antd/el-form 风格。
class _SettingsFormItem extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String label;
  final String? description;
  final Widget control;

  const _SettingsFormItem({
    required this.icon,
    required this.iconColor,
    required this.label,
    required this.control,
    this.description,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Icon(icon, size: 20, color: iconColor),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
                if (description != null) ...[
                  const SizedBox(height: 2),
                  Text(
                    description!,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(width: 16),
          control,
        ],
      ),
    );
  }
}

/// 主题选择：三枚紧凑瓦片（彩色图标 + 短 caption），选中态 primaryContainer
/// 填充 + primary 边框 + 对勾徽标，键盘焦点由 InkWell.onFocusChange 驱动。
/// 图标色沿用登录头主题菜单的亮度感知强调色（theme_selector）。
class _ThemePicker extends StatelessWidget {
  final AppStrings strings;
  const _ThemePicker({required this.strings});

  @override
  Widget build(BuildContext context) {
    final current = AppSettings.instance.themeMode;
    final brightness = Theme.of(context).brightness;
    final modes = [
      (ThemeMode.system, Icons.brightness_auto, strings.themeSystem),
      (ThemeMode.light, Icons.light_mode, strings.themeLight),
      (ThemeMode.dark, Icons.dark_mode, strings.themeDark),
    ];
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (final (index, mode) in modes.indexed) ...[
          _ThemeOptionTile(
            mode: mode.$1,
            icon: mode.$2,
            caption: mode.$3,
            iconColor: ThemeDropdown.themeModeAccentColor(mode.$1, brightness),
            selected: current == mode.$1,
            onTap: () => AppSettings.instance.themeMode = mode.$1,
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
  final Color iconColor;
  final bool selected;
  final VoidCallback onTap;

  const _ThemeOptionTile({
    required this.mode,
    required this.icon,
    required this.caption,
    required this.iconColor,
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
      // 本 SDK（Flutter 3.47 master）无 hover/never 模式：manual = 触屏永不
      // 触发，鼠标 hover 仍显示——web 悬停专属、触屏禁用的设计意图。
      triggerMode: TooltipTriggerMode.manual,
      child: Semantics(
        selected: widget.selected,
        child: InkWell(
          onTap: widget.onTap,
          onFocusChange: (focused) => setState(() => _focused = focused),
          borderRadius: BorderRadius.circular(10),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 150),
            curve: Curves.easeOut,
            padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 10),
            decoration: BoxDecoration(
              color: widget.selected
                  ? colorScheme.primaryContainer
                  : colorScheme.surfaceContainerHighest.withValues(alpha: 0.4),
              borderRadius: BorderRadius.circular(10),
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
                    Icon(widget.icon, size: 20, color: widget.iconColor),
                    const SizedBox(height: 4),
                    Text(
                      widget.caption,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
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
                      size: 14,
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
