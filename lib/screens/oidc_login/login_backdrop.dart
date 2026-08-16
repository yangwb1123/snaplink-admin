import 'package:flutter/material.dart';
import 'package:sso_admin/theme/app_colors.dart';

/// 登录页装饰性背景（极光层次，login-redesign-2 §1）。
///
/// 纯装饰：不拦截指针（IgnorePointer）、显式排除语义（ExcludeSemantics，
/// a11y R3）、无模糊/Ticker/Timer/资产/依赖——全层静态渐变，`transientCallbackCount
/// == 0` 断言天然成立。层次：① 超大主光斑（900px）中央偏上打底，故意落在
/// 卡片排除带内——玻璃卡需要"背后有光"；② 四角光斑（480/560/340/440px）
/// 保留，仅微调亮色 α（0.30→0.32 等）；④ 底部渐隐收尾（暗 #0F172A→0.55）；
/// ⑤ 顶部微光带（900×140 三段线性渐变）。亮色"更清新"= 更高 α + 更浅
/// 色阶（indigo-400→indigo-200，新增装饰常量 [AppColors.violetTint]）。
class LoginBackdrop extends StatelessWidget {
  final Brightness brightness;

  const LoginBackdrop({super.key, required this.brightness});

  /// 中央排除带半宽：登录卡（520px，半宽 260）外留呼吸空间的光斑放置
  /// 规则——除主光斑（故意入带为玻璃卡供光）外，光斑中心尽量落在带外。
  static const double ambientSafeHalfWidth = 310;

  /// 光斑直径（px）。
  static const double glowMain = 900;
  static const double glowTopLeft = 480;
  static const double glowTopRight = 560;
  static const double glowBottomLeft = 340;
  static const double glowBottomRight = 440;

  bool get _light => brightness == Brightness.light;

  /// 按亮度换色（装饰三原则）：暗色保持 400/600 级原色，亮色更浅色阶
  /// （indigo-200 = primaryTint / violet-200 = violetTint）。
  Color _tint(Color darkColor, Color lightColor) => _light ? lightColor : darkColor;

  @override
  Widget build(BuildContext context) => RepaintBoundary(
    child: IgnorePointer(
      child: ExcludeSemantics(
        child: Stack(
          fit: StackFit.expand,
          children: [
            // ① 主光斑打底：中央偏上，暗 0.05 / 亮 0.22，为玻璃卡供光。
            _glow(
              size: glowMain,
              color: _tint(AppColors.primaryOnDark, AppColors.primaryTint),
              alpha: _light ? 0.22 : 0.05,
              alignment: const Alignment(0, -0.12),
            ),
            // ② 四角光斑（亮色 α 微调：0.30→0.32 / 0.22→0.24 / 0.16→0.18 / 0.08→0.10）。
            _glow(
              size: glowTopLeft,
              color: _tint(AppColors.primaryOnDark, AppColors.primaryTint),
              alpha: _light ? 0.32 : 0.14,
              alignment: const Alignment(-0.55, -0.75),
            ),
            _glow(
              size: glowTopRight,
              color: _tint(AppColors.accentBlueBright, AppColors.accentBlueBright),
              alpha: _light ? 0.24 : 0.10,
              alignment: const Alignment(0.65, -0.70),
            ),
            _glow(
              size: glowBottomLeft,
              color: _tint(AppColors.violet, AppColors.violetTint),
              alpha: _light ? 0.18 : 0.08,
              alignment: const Alignment(-0.75, 0.85),
            ),
            _glow(
              size: glowBottomRight,
              color: _tint(AppColors.primaryOnDark, AppColors.primaryTint),
              alpha: _light ? 0.10 : 0.06,
              alignment: const Alignment(0.70, 0.90),
            ),
            // ⑤ 顶部微光带：900×140 三段线性渐变（透明—色—透明）。
            _topBand(),
            // ④ 底部渐隐收尾：暗 textStrong→0.55 / 亮 →0.10，压暗底缘光斑。
            _bottomFade(),
          ],
        ),
      ),
    ),
  );

  /// 单个光斑：大半径径向渐变圆，边缘透明（Apple 式氛围光，无硬边）。
  Widget _glow({required double size, required Color color, required double alpha, required Alignment alignment}) =>
      Align(
        alignment: alignment,
        child: Container(
          width: size,
          height: size,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: RadialGradient(
              colors: [
                color.withValues(alpha: alpha),
                color.withValues(alpha: 0),
              ],
            ),
          ),
        ),
      );

  /// 顶部微光带颜色（亮色浅色阶 indigo-200）。
  Color get _bandColor => _tint(AppColors.primaryOnDark, AppColors.primaryTint);

  /// 顶部微光带：水平三段线性渐变，900×140。
  Widget _topBand() => Align(
    alignment: Alignment.topCenter,
    child: Container(
      width: 900,
      height: 140,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.centerLeft,
          end: Alignment.centerRight,
          colors: [
            _bandColor.withValues(alpha: 0),
            _bandColor.withValues(alpha: _light ? 0.30 : 0.08),
            _bandColor.withValues(alpha: 0),
          ],
        ),
      ),
    ),
  );

  /// 底部渐隐：透明 → textStrong（暗 0.55/亮 0.10）收尾，仅装饰。
  Widget _bottomFade() => Align(
    alignment: Alignment.bottomCenter,
    child: Container(
      height: 240,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            AppColors.textStrong.withValues(alpha: 0),
            AppColors.textStrong.withValues(alpha: _light ? 0.10 : 0.55),
          ],
        ),
      ),
    ),
  );
}
