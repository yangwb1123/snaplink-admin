import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:sso_admin/theme/app_colors.dart';

/// 登录页装饰性背景场景（orbit rings + 盾牌 + 节点簇 + 虚线环）。
///
/// 纯装饰：不拦截指针（IgnorePointer）、显式排除语义（ExcludeSemantics，
/// a11y R3）、无模糊/Ticker/Timer/资产/依赖。中央 ±230px 排除带保证
/// 440px 登录卡始终是视觉焦点。`paint()` 只按 [Brightness] 切换配色，
/// [CustomPainter.shouldRepaint] 仅比较亮度，主题切换时廉价重绘。
class LoginBackdrop extends StatelessWidget {
  final Brightness brightness;

  const LoginBackdrop({super.key, required this.brightness});

  @override
  Widget build(BuildContext context) => RepaintBoundary(
    child: IgnorePointer(
      child: ExcludeSemantics(
        child: CustomPaint(
          size: Size.infinite,
          painter: _LoginBackdropPainter(brightness),
        ),
      ),
    ),
  );
}

/// 装饰图元调参常量：透明度 / 线宽 / 角度 / 尺寸系数统一命名，与
/// [AppColors] 品牌色配对，避免 paint() 内散落魔法数字。
abstract final class _BackdropStyle {
  /// 中央排除带半宽：440px 卡水平居中 ±230px 内不绘制任何图元。
  static const double exclusionHalfWidth = 230;

  // 轨道环（orbit ring）：两条椭圆弧 + 两端卫星点。
  static const double orbitRingAlpha = 0.25;
  static const double orbitRingInnerAlpha = 0.15;
  static const double orbitDotAlpha = 0.6;
  static const double orbitDotRadius = 4;
  static const double orbitStrokeWidth = 2;
  static const double orbitRingInnerInset = 18; // 内弧相对外弧的收缩量。
  static const double orbitOuterStart = 3.49; // 外弧起点（rad）。
  static const double orbitOuterSweep = 2.44; // 外弧扫过角（rad）。
  static const double orbitOuterEnd = 5.93; // 起点 + 扫过角（卫星点位置）。
  static const double orbitInnerStart = 3.66; // 内弧起点（rad）。
  static const double orbitInnerSweep = 2.09; // 内弧扫过角（rad）。

  // 盾牌（shield）：填充 + 描边 + 中间对勾。
  static const double shieldFillAlpha = 0.08;
  static const double shieldStrokeAlpha = 0.35;
  static const double shieldCheckAlpha = 0.5;
  static const double shieldStrokeWidth = 2;
  static const double shieldCheckStrokeWidth = 3;

  // 节点簇（node cluster）：5 圆 + 2 连接线。
  static const double nodeLineAlpha = 0.3;
  static const double nodeLineStrokeWidth = 1.5;

  // 底部虚线环（dashed ring）：手动分段弧（无原生 dash）。
  static const double ringAlpha = 0.2;
  static const double ringStrokeWidth = 1.5;
  static const double ringSegment = 0.10; // 每段弧长（rad）。
  static const double ringGap = 0.10; // 段间距（rad）。
  static const int ringSegments = 32;
}

class _LoginBackdropPainter extends CustomPainter {
  final Brightness brightness;

  _LoginBackdropPainter(this.brightness);

  // 节点簇相对坐标（相对簇中心，单位 px）。
  static const List<Offset> _nodeOffsets = [
    Offset(0, 0),
    Offset(26, 14),
    Offset(-20, 22),
    Offset(18, -24),
    Offset(-30, -8),
  ];
  static const List<double> _nodeRadii = [5, 3.5, 4, 3, 4.5];
  static const List<double> _nodeAlphas = [0.7, 0.45, 0.5, 0.4, 0.6];

  final Paint _stroke = Paint()..style = PaintingStyle.stroke;
  final Paint _fill = Paint()..style = PaintingStyle.fill;

  // Path 复用（避免每帧分配）。
  final Path _shield = Path();
  final Path _shieldCheck = Path();

  @override
  void paint(Canvas canvas, Size size) {
    if (size.isEmpty) return;
    final primary = AppColors.primary;
    final brandTint = brightness == Brightness.dark
        ? AppColors.primaryDark
        : AppColors.primaryTint;
    final accent = AppColors.accentBlue;

    // 中央排除带：左右两个区域分别绘制。
    final band = Rect.fromLTRB(
      size.width / 2 - _BackdropStyle.exclusionHalfWidth,
      0,
      size.width / 2 + _BackdropStyle.exclusionHalfWidth,
      size.height,
    );
    canvas.save();
    canvas.clipPath(
      Path.combine(
        PathOperation.difference,
        Path()..addRect(Offset.zero & size),
        Path()..addRect(band),
      ),
    );

    _paintOrbitRings(canvas, size, brandTint);
    _paintShield(canvas, size, primary);
    _paintNodeCluster(canvas, size, accent);
    _paintDashedRing(canvas, size, brandTint);

    canvas.restore();
  }

  /// 中央偏上轨道环：两条椭圆弧 + 两个卫星点。
  void _paintOrbitRings(Canvas canvas, Size size, Color color) {
    final center = Offset(size.width / 2, size.height * 0.30);
    final rx = size.width * 0.30;
    final ry = size.height * 0.10;
    final rect = Rect.fromCenter(center: center, width: rx * 2, height: ry * 2);

    _stroke
      ..color = color.withValues(alpha: _BackdropStyle.orbitRingAlpha)
      ..strokeWidth = _BackdropStyle.orbitStrokeWidth;
    canvas.drawArc(
      rect,
      _BackdropStyle.orbitOuterStart,
      _BackdropStyle.orbitOuterSweep,
      false,
      _stroke,
    );

    _stroke.color = color.withValues(alpha: _BackdropStyle.orbitRingInnerAlpha);
    canvas.drawArc(
      rect.deflate(_BackdropStyle.orbitRingInnerInset),
      _BackdropStyle.orbitInnerStart,
      _BackdropStyle.orbitInnerSweep,
      false,
      _stroke,
    );

    // 卫星点：外弧两端。
    _fill.color = color.withValues(alpha: _BackdropStyle.orbitDotAlpha);
    for (final angle in const [
      _BackdropStyle.orbitOuterStart,
      _BackdropStyle.orbitOuterEnd,
    ]) {
      final dot = center + Offset(rx * math.cos(angle), ry * math.sin(angle));
      canvas.drawCircle(dot, _BackdropStyle.orbitDotRadius, _fill);
    }
  }

  /// 左侧盾牌：圆角盾形填充 + 描边 + 中间对勾。
  void _paintShield(Canvas canvas, Size size, Color color) {
    final cx = size.width * 0.08;
    final cy = size.height * 0.42;
    _shield
      ..reset()
      ..moveTo(cx, cy - 55)
      ..quadraticBezierTo(cx + 45, cy - 45, cx + 40, cy - 10)
      ..quadraticBezierTo(cx + 30, cy + 35, cx, cy + 55)
      ..quadraticBezierTo(cx - 30, cy + 35, cx - 40, cy - 10)
      ..quadraticBezierTo(cx - 45, cy - 45, cx, cy - 55)
      ..close();

    _fill.color = color.withValues(alpha: _BackdropStyle.shieldFillAlpha);
    canvas.drawPath(_shield, _fill);

    _stroke
      ..color = color.withValues(alpha: _BackdropStyle.shieldStrokeAlpha)
      ..strokeWidth = _BackdropStyle.shieldStrokeWidth;
    canvas.drawPath(_shield, _stroke);

    // 对勾 polyline（Path 复用，与盾形同一策略）。
    _shieldCheck
      ..reset()
      ..moveTo(cx - 18, cy - 8)
      ..lineTo(cx - 6, cy + 6)
      ..lineTo(cx + 22, cy - 16);
    _stroke
      ..color = color.withValues(alpha: _BackdropStyle.shieldCheckAlpha)
      ..strokeWidth = _BackdropStyle.shieldCheckStrokeWidth
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    canvas.drawPath(_shieldCheck, _stroke);
  }

  /// 右侧节点簇：5 个圆 + 2 条连接线。
  void _paintNodeCluster(Canvas canvas, Size size, Color color) {
    final center = Offset(size.width * 0.88, size.height * 0.60);

    _stroke
      ..color = color.withValues(alpha: _BackdropStyle.nodeLineAlpha)
      ..strokeWidth = _BackdropStyle.nodeLineStrokeWidth;
    canvas.drawLine(
      center + _nodeOffsets[0],
      center + _nodeOffsets[1],
      _stroke,
    );
    canvas.drawLine(
      center + _nodeOffsets[0],
      center + _nodeOffsets[4],
      _stroke,
    );

    for (var i = 0; i < _nodeOffsets.length; i++) {
      _fill.color = color.withValues(alpha: _nodeAlphas[i]);
      canvas.drawCircle(center + _nodeOffsets[i], _nodeRadii[i], _fill);
    }
  }

  /// 底部虚线环：手动分段弧（无原生 dash），固定段长避免每帧分配。
  void _paintDashedRing(Canvas canvas, Size size, Color color) {
    final center = Offset(size.width * 0.78, size.height * 0.84);
    final rx = size.width * 0.14;
    final ry = size.height * 0.045;
    final rect = Rect.fromCenter(center: center, width: rx * 2, height: ry * 2);

    _stroke
      ..color = color.withValues(alpha: _BackdropStyle.ringAlpha)
      ..strokeWidth = _BackdropStyle.ringStrokeWidth;
    for (var i = 0; i < _BackdropStyle.ringSegments; i++) {
      canvas.drawArc(
        rect,
        i * (_BackdropStyle.ringSegment + _BackdropStyle.ringGap),
        _BackdropStyle.ringSegment,
        false,
        _stroke,
      );
    }
  }

  @override
  bool shouldRepaint(_LoginBackdropPainter oldDelegate) =>
      oldDelegate.brightness != brightness;
}
