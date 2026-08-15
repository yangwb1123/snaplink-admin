/// R27 共享数字/时间格式化工具。
///
/// 此前各页手写 `toString()` / `substring` / `replaceFirst`，形状不一
/// （无千分位、ISO 原样 vs 截断、本地 vs 服务器时间混用）。本文件集中
/// 三类渲染约定，全部纯函数、无 i18n/上下文依赖：
///
/// - [formatCount]：大数（设备数/用量/金额）千分位；<1000 与
///   `toStringAsFixed(0)` 逐字符一致（既有测试不敏感）。
/// - [formatDecimal] / [formatPercent]：比率/小数固定精度。
/// - [formatServerTime] / [formatLocalTime]：人读时间统一
///   `YYYY-MM-DD HH:mm:ss`（[dateOnly] 截到日期），时区语义保持：
///   服务器时间原样截断 vs 显式 `toLocal()` 本地化；缺失值统一 '—'。
///
/// 机读路径（CSV 导出、API 载荷、JSON 回显）保持 ISO 原样，不走本文件。
library;

/// 整数千分位（`1,234,567`）；<1000 输出与 `round().toString()` 一致。
/// 非数字输入返回 [fallback]（默认 '—'，与页面占位约定一致）。
String formatCount(Object? value, {String fallback = '—'}) {
  final num? n = value is num ? value : num.tryParse('$value');
  if (n == null) return fallback;
  final rounded = n.round();
  final negative = rounded < 0;
  final digits = rounded.abs().toString();
  final buffer = StringBuffer();
  for (var i = 0; i < digits.length; i++) {
    if (i > 0 && (digits.length - i) % 3 == 0) buffer.write(',');
    buffer.write(digits[i]);
  }
  return '${negative ? '-' : ''}$buffer';
}

/// 固定小数位（默认 2 位，评分/比率用）；非数字输入返回 [fallback]。
String formatDecimal(Object? value, {int digits = 2, String fallback = '—'}) {
  final num? n = value is num ? value : num.tryParse('$value');
  if (n == null) return fallback;
  return n.toStringAsFixed(digits);
}

/// 百分比：`toStringAsFixed(digits)` + '%'（精度由调用方决定）。
String formatPercent(num value, {int digits = 0}) =>
    '${value.toStringAsFixed(digits)}%';

/// 服务器时间原样（不转换时区）：ISO 字符串截断为
/// `YYYY-MM-DD HH:mm:ss`（[dateOnly] 时 `YYYY-MM-DD`）。
/// 非 ISO/非空文本原样保留；缺失返回 '—'。
String formatServerTime(Object? value, {bool dateOnly = false}) {
  final text = value?.toString().trim() ?? '';
  if (text.isEmpty) return '—';
  final normalized = text.replaceFirst('T', ' ');
  final cut = dateOnly ? 10 : 19;
  return normalized.length <= cut ? normalized : normalized.substring(0, cut);
}

/// 本地化时间：解析后 `toLocal()` 再截断为 `YYYY-MM-DD HH:mm:ss`
/// （[dateOnly] 时 `YYYY-MM-DD`），时区语义显式标注为本地。
/// 不可解析的文本原样保留；缺失返回 '—'。
String formatLocalTime(Object? value, {bool dateOnly = false}) {
  final parsed = value is DateTime
      ? value
      : DateTime.tryParse(value?.toString() ?? '');
  if (parsed == null) return formatServerTime(value, dateOnly: dateOnly);
  final text = parsed.toLocal().toString().replaceFirst('T', ' ');
  final cut = dateOnly ? 10 : 19;
  return text.length <= cut ? text : text.substring(0, cut);
}
