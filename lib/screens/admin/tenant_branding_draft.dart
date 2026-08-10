import 'dart:convert';

import '../../services/language_catalog.dart';

/// 核心品牌键 + 语言列表保留键。languages 由品牌表单独立编辑，但同样
/// 不允许出现在 Advanced JSON 里（避免重复）。
const tenantBrandingCoreKeys = {
  'brand_name',
  'primary_color',
  'logo_url',
  'languages',
};

Map<String, String> tenantBrandingDraft({
  required String advancedJson,
  required String brandName,
  required String primaryColor,
  required String logoUrl,
  required String languages,
}) {
  final decoded = jsonDecode(advancedJson.trim().isEmpty ? '{}' : advancedJson);
  if (decoded is! Map) {
    throw const FormatException('Advanced branding must be a JSON object.');
  }
  final branding = <String, String>{};
  for (final entry in decoded.entries) {
    final key = entry.key.toString().trim();
    if (key.isEmpty || tenantBrandingCoreKeys.contains(key)) {
      throw const FormatException(
        'Advanced keys must be non-empty and must not duplicate core fields.',
      );
    }
    if (entry.value is! String) {
      throw const FormatException('Every branding value must be a string.');
    }
    branding[key] = entry.value as String;
  }

  final name = brandName.trim();
  final color = primaryColor.trim();
  final logo = logoUrl.trim();
  if (name.length > 100) {
    throw const FormatException('Brand name must be 100 characters or less.');
  }
  if (color.isNotEmpty &&
      !RegExp(r'^#[0-9a-fA-F]{6}([0-9a-fA-F]{2})?$').hasMatch(color)) {
    throw const FormatException('Primary color must use #RRGGBB or #RRGGBBAA.');
  }
  if (logo.isNotEmpty) {
    final uri = Uri.tryParse(logo);
    if (uri == null || uri.scheme != 'https' || uri.host.isEmpty) {
      throw const FormatException('Logo URL must be an absolute HTTPS URL.');
    }
  }
  if (name.isNotEmpty) branding['brand_name'] = name;
  if (color.isNotEmpty) branding['primary_color'] = color;
  if (logo.isNotEmpty) branding['logo_url'] = logo;

  final languagesValue = languages.trim();
  if (languagesValue.isNotEmpty) {
    final tags = languagesValue
        .split(',')
        .map((tag) => tag.trim())
        .where((tag) => tag.isNotEmpty)
        .toList();
    if (tags.isEmpty || tags.any((tag) => !isValidLanguageTag(tag))) {
      throw const FormatException(
        'Languages must be a comma-separated list of BCP-47 tags.',
      );
    }
    branding['languages'] = languagesValue;
  }
  return branding;
}
