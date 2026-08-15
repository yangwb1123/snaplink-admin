import 'package:flutter/material.dart';
import 'app_colors.dart';

/// 品牌化应用主题（设计系统升级：脱离 Material 模板感）。
///
/// 统一：品牌色系、圆角、卡片阴影、输入框风格、字体层级。
/// 所有页面自动继承——新组件无需单独定制。
abstract final class AppTheme {
  /// 品牌主色（indigo 紫，标识色）。
  static const Color _brand = AppColors.primary;

  /// 圆角体系（component-spec: Card 12 / Button 8 / Input 8）。
  static const double radiusCard = 12;
  static const double radiusControl = 8;

  static ThemeData light() => _build(Brightness.light);

  static ThemeData dark() => _build(Brightness.dark);

  /// dark 表面抬升步：品牌 slate 表面（textMuted）上叠白色 step。
  /// 种子色派生的 surfaceContainer* 偏紫且与 slate 表面同亮度
  /// （scH vs surface ≈1.01，深色下不可感知）；改为 slate 同族白色
  /// step。scH（菜单底）封顶 white@2%（primary 边框对比 ≥3:1），
  /// scHH（悬停行/浮层/瓦片）white@10% 承担可感知抬升——阴影由
  /// surface 层级替代（R18）。
  static Color _darkLift(double whiteAlpha) => Color.alphaBlend(
    Colors.white.withValues(alpha: whiteAlpha),
    AppColors.textMuted,
  );

  static ThemeData _build(Brightness brightness) {
    final isDark = brightness == Brightness.dark;
    final seedScheme = ColorScheme.fromSeed(
      seedColor: _brand,
      brightness: brightness,
      surface: isDark ? AppColors.textMuted : Colors.white,
      primary: isDark ? AppColors.primary : AppColors.primary,
      secondary: isDark ? AppColors.primary : AppColors.primaryDark,
    );
    final scheme = isDark
        ? seedScheme.copyWith(
            surfaceContainerLowest: _darkLift(0.005),
            surfaceContainerLow: _darkLift(0.01),
            surfaceContainer: _darkLift(0.015),
            surfaceContainerHigh: _darkLift(0.02),
            surfaceContainerHighest: _darkLift(0.10),
          )
        : seedScheme;
    final base = ThemeData(
      useMaterial3: true,
      brightness: brightness,
      colorScheme: scheme,
      scaffoldBackgroundColor: isDark
          ? AppColors.textStrong
          : AppColors.surfaceSubtle, // 浅灰品牌背景（区别于纯白模板）
    );
    return base.copyWith(
      // dark 下 primary@6% 对深色表面仅 1.06:1（不可感知），改用中性
      // 白色 step（≈1.28:1，M3 dark hover 惯例）；浅色保持品牌色淡底。
      hoverColor: isDark
          ? Colors.white.withValues(alpha: 0.08)
          : scheme.primary.withValues(alpha: 0.06),
      dialogTheme: DialogThemeData(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(radiusCard),
        ),
      ),
      cardTheme: CardThemeData(
        elevation: isDark ? 0 : 1,
        shadowColor: Colors.black.withValues(alpha: isDark ? 0.4 : 0.08),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(radiusCard),
        ),
        clipBehavior: Clip.antiAlias,
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: isDark ? AppColors.textMuted : Colors.white,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        centerTitle: false,
        titleTextStyle: TextStyle(
          color: isDark ? Colors.white : AppColors.textStrong,
          fontSize: 20,
          fontWeight: FontWeight.w600,
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: isDark
            ? AppColors.textStrong.withValues(alpha: 0.6)
            : Colors.white,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(radiusControl),
          borderSide: BorderSide(
            color: isDark
                ? Colors.white24
                : AppColors.textSubtle.withValues(alpha: 0.3),
          ),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(radiusControl),
          borderSide: BorderSide(
            color: isDark
                ? Colors.white24
                : AppColors.textSubtle.withValues(alpha: 0.3),
          ),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(radiusControl),
          borderSide: const BorderSide(color: AppColors.primary, width: 1.6),
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          minimumSize: const Size(48, 40),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(radiusControl),
          ),
          textStyle: const TextStyle(fontWeight: FontWeight.w600),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          minimumSize: const Size(48, 40),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(radiusControl),
          ),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(radiusControl),
          ),
        ),
      ),
      dividerTheme: DividerThemeData(
        color: isDark
            ? Colors.white12
            : AppColors.textSubtle.withValues(alpha: 0.2),
        thickness: 1,
      ),
      chipTheme: base.chipTheme.copyWith(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(999),
        ),
        side: BorderSide.none,
        labelStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
      ),
      listTileTheme: ListTileThemeData(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
        ),
        iconColor: scheme.primary,
        selectedColor: scheme.primary,
      ),
      navigationRailTheme: const NavigationRailThemeData(
        indicatorShape: RoundedRectangleBorder(
          borderRadius: BorderRadius.all(Radius.circular(8)),
        ),
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        contentTextStyle: const TextStyle(fontWeight: FontWeight.w500),
      ),
    );
  }
}
