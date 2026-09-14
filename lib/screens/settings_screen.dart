import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import '../app_settings.dart';
import '../i18n/app_strings.dart';
import '../services/browser_navigation.dart';
import '../services/agent_hub_api_origin.dart';
import '../services/product_api_origin.dart';
import '../services/session_cleanup.dart';
import '../session.dart';
import '../widgets/app_snackbar.dart';
import '../widgets/error_boundary.dart';
import '../widgets/language_selector.dart';
import '../theme/app_colors.dart';
import 'settings/settings_form_layout.dart';
import 'settings/settings_theme_picker.dart';

/// Post-login settings: language, theme, admin nav mode, SSO base URL
/// and Agent Hub origins (native-only), and a read-only timezone display. Reads/writes
/// [AppSettings.instance] directly — there is no local draft state for
/// language/theme, changes apply and propagate (via main.dart's
/// ListenableBuilder) the instant they're made.
///
/// Layout: antd/Stripe-style form rows inside two groups — a compact
/// "preferences" card and a "service" card for API origins and timezone.
/// Changing an API origin discards the authenticated session.
/// Every row is an icon + label + control line with a divider; no more
/// full-width card per setting.
class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final _baseUrlFormKey = GlobalKey<FormState>();
  final _agentHubBaseUrlFormKey = GlobalKey<FormState>();
  late final TextEditingController _baseUrlController;
  late final TextEditingController _agentHubBaseUrlController;

  @override
  void initState() {
    super.initState();
    _baseUrlController = TextEditingController(
      text: AppSettings.instance.ssoBaseUrlOverride,
    );
    _agentHubBaseUrlController = TextEditingController(
      text: AppSettings.instance.agentHubBaseUrlOverride,
    );
  }

  @override
  void dispose() {
    _baseUrlController.dispose();
    _agentHubBaseUrlController.dispose();
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

  String? _validateAgentHubBaseUrl(String? value) {
    if (kIsWeb) return null;
    try {
      AppSettings.normalizeAgentHubBaseUrl(value);
      return null;
    } on FormatException {
      return AppStrings.of(context).translate(
        'Enter an absolute HTTPS Agent Hub origin without credentials, '
        'path, query, or fragment. HTTP is allowed only for localhost or '
        'loopback addresses.',
      );
    }
  }

  void _saveBaseUrl() {
    if (!(_baseUrlFormKey.currentState?.validate() ?? false)) return;
    if (!(_agentHubBaseUrlFormKey.currentState?.validate() ?? false)) return;
    final previousOrigin = ProductApiOrigin.baseUri;
    final previousHubOrigin = AgentHubApiOrigin.baseUrl;
    AppSettings.instance.ssoBaseUrlOverride = _baseUrlController.text;
    AppSettings.instance.agentHubBaseUrlOverride =
        _agentHubBaseUrlController.text;
    _baseUrlController.text = AppSettings.instance.ssoBaseUrlOverride ?? '';
    _agentHubBaseUrlController.text =
        AppSettings.instance.agentHubBaseUrlOverride ?? '';
    final originChanged =
        previousOrigin != ProductApiOrigin.baseUri ||
        previousHubOrigin != AgentHubApiOrigin.baseUrl;
    if (originChanged && Session.read() != null) {
      // A bearer minted by one deployment must never be carried into a newly
      // configured identity or Agent Hub origin. The Agent Hub audience is
      // still a bearer credential, so changing its destination is a trust
      // boundary even though Snaplink remains the token issuer.
      clearAllSessionsBestEffort();
      BrowserNavigation.replaceLocation('/login/');
      return;
    }
    showAppSnackBar(context, content: Text(AppStrings.of(context).saved));
  }

  @override
  Widget build(BuildContext context) {
    final strings = AppStrings.of(context);
    return Scaffold(
      appBar: AppBar(
        title: Semantics(
          container: true,
          header: true,
          child: Text(strings.settings),
        ),
      ),
      body: ErrorBoundary(
        // 设置页（从 admin 壳层/命令面板/登录页三处 push 的独立路由页）
        // 页面级边界：表单构建崩溃 → 兜底 UI + 重载，不影响来源页面。
        child: Center(
          // 桌面超宽屏：表单行不再贴边拉伸，居中收窄到可读宽度。
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 840),
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                // ── 偏好分组：紧凑 form 行 ──
                SettingsGroup(
                  children: [
                    SettingsFormItem(
                      icon: Icons.translate,
                      iconColor: AppColors.groupOverview, // 导航组色板 sky
                      label: strings.language,
                      control: _SettingsReactive(
                        builder: (_) => LanguageDropdown(),
                      ),
                    ),
                    SettingsFormItem(
                      icon: Icons.palette_outlined,
                      iconColor: AppColors.groupIdentity, // 导航组色板 indigo-violet
                      label: strings.theme,
                      description: strings.translate(
                        'Appearance follows the system or your explicit choice.',
                      ),
                      control: _SettingsReactive(
                        builder: (_) => SettingsThemePicker(strings: strings),
                      ),
                    ),
                    SettingsFormItem(
                      icon: Icons.view_sidebar_outlined,
                      iconColor: AppColors.groupDevelopers, // 导航组色板 emerald
                      label: strings.adminNavMode,
                      description: strings.translate(
                        'Standard shows Overview, Clients, and Users. Professional '
                        'shows every module enabled by your server.',
                      ),
                      control: _SettingsReactive(
                        builder: (_) => _AdminNavModeSwitch(),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                // 服务分组：切换 SSO 或 Agent Hub 地址会清除会话。
                _buildServiceGroup(strings),
                // 保存两个 API 地址（web 禁用）。
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
        ),
      ),
    );
  }

  /// 服务分组：两个 API 地址（换源会丢弃会话）与只读时区展示。
  /// 拆出后 build 只负责偏好分组与页面骨架。
  Widget _buildServiceGroup(AppStrings strings) {
    return SettingsGroup(
      children: [
        SettingsFormItem(
          icon: Icons.dns_outlined,
          iconColor: AppColors.groupTenants, // 导航组色板 amber（高风险强调）
          label: strings.ssoBaseUrl,
          description: strings.translate(
            'Server endpoint used for OIDC and API calls. Changing it '
            'discards the current session.',
          ),
          control: SizedBox(
            width: 320,
            child: Form(
              key: _baseUrlFormKey,
              // 行内 label 不可见时仍需为字段命名（屏幕阅读器）。
              child: Semantics(
                label: strings.ssoBaseUrl,
                child: TextFormField(
                  key: const ValueKey('sso-api-origin'),
                  controller: _baseUrlController,
                  enabled: !kIsWeb,
                  keyboardType: TextInputType.url,
                  textInputAction: TextInputAction.done,
                  autovalidateMode: AutovalidateMode.onUserInteraction,
                  onFieldSubmitted: (_) => _saveBaseUrl(),
                  decoration: InputDecoration(
                    helperText: strings.ssoBaseUrlHint,
                  ),
                  validator: _validateBaseUrl,
                ),
              ),
            ),
          ),
        ),
        SettingsFormItem(
          icon: Icons.schedule_outlined,
          iconColor: AppColors.muted, // slate
          label: strings.timezone,
          description: strings.translate(
            'Current local timezone of this device.',
          ),
          control: Semantics(
            readOnly: true,
            child: Text(DateTime.now().timeZoneName),
          ),
        ),
        SettingsFormItem(
          icon: Icons.hub_outlined,
          iconColor: AppColors.groupDevelopers,
          label: strings.translate('Agent Hub API origin'),
          description: strings.translate(
            'Optional native API origin for Agent Operations. Snaplink remains '
            'the token issuer; web always uses the page origin.',
          ),
          control: SizedBox(
            width: 320,
            child: Form(
              key: _agentHubBaseUrlFormKey,
              child: Semantics(
                label: strings.translate('Agent Hub API origin'),
                child: TextFormField(
                  key: const ValueKey('agent-hub-api-origin'),
                  controller: _agentHubBaseUrlController,
                  enabled: !kIsWeb,
                  keyboardType: TextInputType.url,
                  textInputAction: TextInputAction.done,
                  autovalidateMode: AutovalidateMode.onUserInteraction,
                  onFieldSubmitted: (_) => _saveBaseUrl(),
                  decoration: InputDecoration(
                    helperText: strings.translate(
                      'Leave blank to use the Snaplink origin.',
                    ),
                  ),
                  validator: _validateAgentHubBaseUrl,
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

/// 管理导航模式：Switch（开启 = 专业模式，显示全部能力模块）。
class _AdminNavModeSwitch extends StatelessWidget {
  const _AdminNavModeSwitch();

  @override
  Widget build(BuildContext context) {
    final strings = AppStrings.of(context);
    // R29 字体缩放：标签+Switch 改 Wrap——1.5x/2.0x 下同排放不下时
    // Switch 换行（原 Row 溢出 20px），1x 桌面仍单行不变。
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        Text(strings.adminNavModeProfessional),
        Switch(
          value: AppSettings.instance.adminNavMode == AdminNavMode.professional,
          onChanged: (professional) => AppSettings.instance.adminNavMode =
              professional ? AdminNavMode.professional : AdminNavMode.normal,
        ),
      ],
    );
  }
}

/// 让子控件在 [AppSettings] 变化时单独重建——只有真正读取设置值的控件
/// （语言/主题/导航模式）订阅，静态行（SSO 表单、时区、保存按钮）不再
/// 因任何设置变更整页重建。
///
/// child 经 [WidgetBuilder] 在 builder 内新建：直接传入 child 字段会让
/// ListenableBuilder 每次通知后返回同一个 widget 实例，命中 Flutter 的
/// identical 快速路径导致子树不重建（T11 回归点）。
class _SettingsReactive extends StatelessWidget {
  const _SettingsReactive({required this.builder});

  final WidgetBuilder builder;

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: AppSettings.instance,
    builder: (context, _) => builder(context),
  );
}
