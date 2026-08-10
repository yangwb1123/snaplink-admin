import 'dart:ui' show Locale;

/// 品牌/租户响应中"该 client 可选择的语言列表"保留键。
///
/// 值约定：逗号分隔的 BCP-47 语言标签（与 OIDC `ui_locales` 一致），例如
/// `"en,zh,ja"`。来源为登录响应的 `branding` map（client 所属租户
/// `Settings`）与公共 `/branding` 响应（租户 `Branding.Values`）。旧部署
/// 或未配置时键缺失，前端回退 [defaultLanguageOptions]（fail-closed，
/// 不猜测接口）。
const languageCatalogKey = 'languages';

/// 后端未公布语言列表时的回退集合（现有硬编码行为保持不变）。
const defaultLanguageOptions = <Locale>[Locale('en'), Locale('zh')];

/// 解析 branding map 的 `languages` 值：按逗号拆分、trim、去重、过滤
/// 无法解析的标签；空结果回退默认集合。顺序按后端声明保留。
List<Locale> parseLanguageOptions(Object? raw) {
  if (raw is! String || raw.trim().isEmpty) return defaultLanguageOptions;
  final seen = <String>{};
  final result = <Locale>[];
  for (final part in raw.split(',')) {
    final tag = part.trim();
    if (tag.isEmpty) continue;
    final locale = _parseBcp47(tag);
    if (locale == null) continue;
    // 按 languageCode 去重（大小写不敏感，`en`/`EN`/`en-US` 只保留首个）。
    if (!seen.add(locale.languageCode)) continue;
    result.add(locale);
  }
  return result.isEmpty ? defaultLanguageOptions : result;
}

/// DropdownButton 的 `value` 必须命中 items 之一，否则断言失败。当前语言
/// 不在后端列表时（例如设备 locale 为 ja 而后端只允许 en/zh），把它附加
/// 到末尾，保证选择器既能渲染当前值又不丢失后端控制的集合。
List<Locale> languageOptionsIncludingCurrent(
  List<Locale> options,
  Locale current,
) {
  if (options.any((l) => l.languageCode == current.languageCode)) {
    return options;
  }
  return [...options, current];
}

/// 语言选项的显示名。使用固定小表（与控制台 i18n 边界一致，不引入
/// Flutter 本地化依赖）；未知语言回退大写 languageCode。
String languageOptionLabel(Locale locale) {
  const labels = <String, String>{
    'en': 'English',
    'zh': '中文',
    'ja': '日本語',
    'ko': '한국어',
    'fr': 'Français',
    'de': 'Deutsch',
    'es': 'Español',
    'pt': 'Português',
    'it': 'Italiano',
    'ru': 'Русский',
    'ar': 'العربية',
    'hi': 'हिन्दी',
  };
  return labels[locale.languageCode] ?? locale.languageCode.toUpperCase();
}

/// 校验单个 BCP-47 标签是否可解析（品牌表单的 languages 输入校验用）。
bool isValidLanguageTag(String tag) => _parseBcp47(tag.trim()) != null;

/// 宽松 BCP-47 解析：`en`、`zh-Hans-CN`、`pt-BR` 等；第二段为 4 位字母时
/// 视为 script，2 位字母/3 位数字时视为 region。语言代码段必须是 2-8 位
/// 字母。
Locale? _parseBcp47(String tag) {
  final segments = tag.split('-');
  final language = segments.first;
  if (language.length < 2 ||
      language.length > 8 ||
      !RegExp(r'^[A-Za-z]+$').hasMatch(language)) {
    return null;
  }
  String? script;
  String? region;
  if (segments.length > 1) {
    final second = segments[1];
    if (RegExp(r'^[A-Za-z]{4}$').hasMatch(second)) {
      script = second;
      if (segments.length > 2) region = segments[2];
    } else if (RegExp(r'^[A-Za-z]{2}$|^[0-9]{3}$').hasMatch(second)) {
      region = second;
    } else {
      return null;
    }
  }
  return Locale.fromSubtags(
    languageCode: language.toLowerCase(),
    scriptCode: script == null
        ? null
        : script[0].toUpperCase() + script.substring(1).toLowerCase(),
    countryCode: region?.toUpperCase(),
  );
}
