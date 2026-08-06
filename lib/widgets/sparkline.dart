import 'package:flutter/material.dart';

/// 迷你趋势图（Sparkline）：数值序列 → 平滑折线 + 渐变面积。
///
/// 自绘 CustomPaint（无第三方依赖），数据动画（500ms 从左到右生长）。
class Sparkline extends StatelessWidget {
  final List<num> data;
  final Color? color;
  final double height;
  final double strokeWidth;

  const Sparkline({
    super.key,
    required this.data,
    this.color,
    this.height = 40,
    this.strokeWidth = 2,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final lineColor = color ?? scheme.primary;
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: const Duration(milliseconds: 500),
      curve: Curves.easeOutCubic,
      builder: (context, reveal, _) => CustomPaint(
        size: Size(double.infinity, height),
        painter: _SparklinePainter(
          data: data,
          color: lineColor,
          strokeWidth: strokeWidth,
          reveal: reveal,
        ),
      ),
    );
  }
}

class _SparklinePainter extends CustomPainter {
  final List<num> data;
  final Color color;
  final double strokeWidth;
  final double reveal;

  _SparklinePainter({
    required this.data,
    required this.color,
    required this.strokeWidth,
    required this.reveal,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (data.length < 2) return;
    final min = data.reduce((a, b) => a < b ? a : b).toDouble();
    final max = data.reduce((a, b) => a > b ? a : b).toDouble();
    final range = (max - min).abs() < 1e-9 ? 1.0 : max - min;

    Offset pointAt(int index) {
      final x = size.width * index / (data.length - 1);
      final y = size.height - (data[index].toDouble() - min) / range * size.height;
      return Offset(x, y);
    }

    final line = Path();
    for (var i = 0; i < data.length; i++) {
      final p = pointAt(i);
      if (i == 0) {
        line.moveTo(p.dx, p.dy);
      } else {
        line.lineTo(p.dx, p.dy);
      }
    }

    // 按 reveal 裁剪：折线从左到右生长。
    final clip = Path()
      ..addRect(Rect.fromLTWH(0, 0, size.width * reveal, size.height));
    canvas.save();
    canvas.clipPath(clip);

    // 渐变面积。
    final area = Path.from(line)
      ..lineTo(size.width, size.height)
      ..lineTo(0, size.height)
      ..close();
    canvas.drawPath(
      area,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            color.withValues(alpha: 0.25),
            color.withValues(alpha: 0.02),
          ],
        ).createShader(Offset.zero & size),
    );

    // 折线。
    canvas.drawPath(
      line,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = strokeWidth
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round
        ..color = color,
    );

    // 末端圆点。
    if (reveal > 0.98 && data.isNotEmpty) {
      final last = pointAt(data.length - 1);
      canvas.drawCircle(last, strokeWidth + 1.5, Paint()..color = color);
    }
    canvas.restore();
  }

  @override
  bool shouldRepaint(_SparklinePainter oldDelegate) =>
      oldDelegate.data != data ||
      oldDelegate.color != color ||
      oldDelegate.reveal != reveal;
}
