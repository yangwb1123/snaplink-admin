/// 应用颜色常量（从散落的硬编码色值集中提取，AI 规范门禁驱动）。
/// 替代各处散落的 `Color(0xFF...)` 字面量：单点定义、可主题化、可审计。
library;

import 'package:flutter/material.dart';

abstract final class AppColors {
  /// 主品牌色（indigo）
  static const Color primary = Color(0xFF6366F1);
  static const Color primaryDark = Color(0xFF3730A3);

  /// 文字与背景（slate 系）
  static const Color textStrong = Color(0xFF0F172A);
  static const Color textMuted = Color(0xFF1E293B);
  static const Color textSubtle = Color(0xFF334155);

  /// 品牌蓝（通用强调）
  static const Color accentBlue = Color(0xFF2563EB);

  /// 成功（emerald 系）
  static const Color success = Color(0xFF059669);
  static const Color successDark = Color(0xFF064E3B);
  static const Color successTint = Color(0xFFA7F3D0);

  /// 危险（red 系）
  static const Color danger = Color(0xFFB91C1C);
  static const Color dangerDark = Color(0xFF7F1D1D);
  static const Color dangerTint = Color(0xFFFECACA);

  /// 警告（amber）
  static const Color warning = Color(0xFFD97706);

  /// 中性灰（inactive 等）——slate-500：对白底点缀对比 ≥3（WCAG 非文本）
  static const Color muted = Color(0xFF64748B);
  /// 头像/标签辅助色（UserAvatar 调色板）
  static const Color violet = Color(0xFF7C3AED);
  static const Color cyan = Color(0xFF0891B2);
  static const Color pink = Color(0xFFDB2777);
  /// 辅助（indigo 淡色）
  static const Color primaryTint = Color(0xFFC7D2FE);
}
