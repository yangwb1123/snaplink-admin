# lib/i18n — 双语（EN/ZH）字符串系统

- `app_strings_source_*.dart`：分域 catalog（common/portal/admin_core/
  admin_dynamic/…）——**新增 key 前先查跨 catalog 重复**（const map spread
  重复 = 编译错误）
- `localized_text.dart`：`LocalizedText`（界面文案查表 + `{n}` 模板 args）
- `app_strings.dart`：查找入口（locale → 表 → pattern 匹配）

规则：
- 界面文案用 LocalizedText/context.tr；**纯数据（版本号/计数/动态字段）用 Text**
  （值==key 的占位翻译会污染 pattern 匹配）
- 动态消息用 `{name}` 模板 + args（如 'Client {id} approved.'）
- i18n_coverage_test 门禁：裸 Text 里的新文案会被抓
