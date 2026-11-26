// ignore_for_file: deprecated_member_use

import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../theme/roam_theme.dart';

/// 星环的背景：夜空、星点，以及一道斜掠过的行星环。
///
/// 整块背景是静态绘制，交给 [RepaintBoundary] 缓存；玻璃组件通过
/// `LayerBackdrop` 采样它，因此这里不需要任何动画就能产生折射。
class SpaceBackground extends StatelessWidget {
  const SpaceBackground({super.key, required this.brightness});

  final Brightness brightness;

  @override
  Widget build(BuildContext context) {
    return RepaintBoundary(
      child: CustomPaint(
        painter: _SpacePainter(isDark: brightness == Brightness.dark),
        size: Size.infinite,
        isComplex: true,
        willChange: false,
      ),
    );
  }
}

class _SpacePainter extends CustomPainter {
  const _SpacePainter({required this.isDark});

  final bool isDark;

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    _paintBase(canvas, size, rect);
    if (isDark) {
      _paintStars(canvas, size);
    } else {
      _paintDayHaze(canvas, size);
    }
    _paintRing(canvas, size);
    _paintVignette(canvas, size, rect);
  }

  void _paintBase(Canvas canvas, Size size, Rect rect) {
    final colors = isDark
        ? const [
            Color(0xFF05070D),
            Color(0xFF0A1220),
            Color(0xFF0B1526),
            Color(0xFF05070D),
          ]
        : const [
            Color(0xFFF6FBFE),
            Color(0xFFE7F2F9),
            Color(0xFFDCEBF6),
            Color(0xFFEFF7FB),
          ];
    final paint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: colors,
        stops: const [0, 0.34, 0.72, 1],
      ).createShader(rect);
    canvas.drawRect(rect, paint);

    // 左上极光、右下虹紫，两块大范围的低透明度光晕把画面撑开。
    _glow(
      canvas,
      center: Offset(size.width * 0.12, size.height * 0.06),
      radius: size.width * 0.95,
      color: isDark
          ? RoamColors.aurora.withValues(alpha: 0.20)
          : RoamColors.aurora.withValues(alpha: 0.18),
    );
    _glow(
      canvas,
      center: Offset(size.width * 0.98, size.height * 0.58),
      radius: size.width * 0.9,
      color: RoamColors.iris.withValues(alpha: isDark ? 0.22 : 0.12),
    );
    _glow(
      canvas,
      center: Offset(size.width * 0.05, size.height * 0.92),
      radius: size.width * 0.8,
      color: RoamColors.sky.withValues(alpha: isDark ? 0.10 : 0.14),
    );
  }

  void _glow(
    Canvas canvas, {
    required Offset center,
    required double radius,
    required Color color,
  }) {
    final paint = Paint()
      ..shader = RadialGradient(colors: [color, color.withValues(alpha: 0)])
          .createShader(Rect.fromCircle(center: center, radius: radius));
    canvas.drawCircle(center, radius, paint);
  }

  void _paintStars(Canvas canvas, Size size) {
    final random = math.Random(20261114);
    final paint = Paint();
    for (var i = 0; i < 128; i++) {
      final x = random.nextDouble() * size.width;
      final y = random.nextDouble() * size.height;
      // 越靠上越密，避免底部工具栏区域出现噪点。
      if (y > size.height * 0.82 && random.nextBool()) continue;
      final radius = 0.35 + random.nextDouble() * 1.15;
      final alpha = 0.16 + random.nextDouble() * 0.62;
      paint.color = (random.nextInt(6) == 0 ? RoamColors.aurora : Colors.white)
          .withValues(alpha: alpha);
      canvas.drawCircle(Offset(x, y), radius, paint);
      if (radius > 1.2) {
        paint.color = paint.color.withValues(alpha: alpha * 0.12);
        canvas.drawCircle(Offset(x, y), radius * 3.4, paint);
      }
    }
  }

  void _paintDayHaze(Canvas canvas, Size size) {
    final paint = Paint()..color = Colors.white.withValues(alpha: 0.35);
    for (var i = 0; i < 3; i++) {
      final cx = size.width * (0.2 + i * 0.34);
      final cy = size.height * (0.12 + i * 0.06);
      canvas.drawOval(
        Rect.fromCenter(
          center: Offset(cx, cy),
          width: size.width * 0.7,
          height: size.height * 0.18,
        ),
        paint,
      );
    }
  }

  void _paintRing(Canvas canvas, Size size) {
    final center = Offset(size.width * 0.54, size.height * 0.30);
    final width = size.width * 1.30;
    final height = width * 0.34;
    final aurora = isDark ? RoamColors.aurora : RoamColors.auroraDeep;

    canvas.save();
    canvas.translate(center.dx, center.dy);
    canvas.rotate(-0.42);

    final outer = Rect.fromCenter(
      center: Offset.zero,
      width: width,
      height: height,
    );
    // 用线性渐变而不是扫描渐变：后者在极端扁平的椭圆上会出现扇形色带。
    final outerPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.3
      ..shader = LinearGradient(
        begin: Alignment.centerLeft,
        end: Alignment.centerRight,
        colors: [
          aurora.withValues(alpha: 0),
          aurora.withValues(alpha: isDark ? 0.46 : 0.34),
          RoamColors.sky.withValues(alpha: isDark ? 0.52 : 0.36),
          RoamColors.iris.withValues(alpha: isDark ? 0.30 : 0.20),
          RoamColors.iris.withValues(alpha: 0),
        ],
        stops: const [0, 0.26, 0.52, 0.76, 1],
      ).createShader(outer);
    canvas.drawPath(Path()..addOval(outer), outerPaint);

    final inner = Rect.fromCenter(
      center: Offset.zero,
      width: width * 0.74,
      height: height * 0.74,
    );
    final innerPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.9
      ..shader = LinearGradient(
        begin: Alignment.centerLeft,
        end: Alignment.centerRight,
        colors: [
          Colors.transparent,
          (isDark ? Colors.white : RoamColors.sky).withValues(
            alpha: isDark ? 0.16 : 0.22,
          ),
          Colors.transparent,
        ],
        stops: const [0.1, 0.52, 0.94],
      ).createShader(inner);
    canvas.drawPath(Path()..addOval(inner), innerPaint);
    canvas.restore();

    // 环上的小行星：一个带光晕的实心点，是“星环”的视觉锚。
    final planetCenter = Offset(
      center.dx + math.cos(-1.15) * width * 0.48,
      center.dy + math.sin(-1.15) * height * 0.52,
    );
    _glow(
      canvas,
      center: planetCenter,
      radius: size.width * 0.09,
      color: (isDark ? RoamColors.aurora : RoamColors.auroraDeep).withValues(
        alpha: isDark ? 0.34 : 0.22,
      ),
    );
    canvas.drawCircle(
      planetCenter,
      2.6,
      Paint()..color = (isDark ? Colors.white : RoamColors.auroraDeep),
    );
  }

  void _paintVignette(Canvas canvas, Size size, Rect rect) {
    final paint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: isDark
            ? [
                Colors.transparent,
                Colors.transparent,
                RoamColors.ink.withValues(alpha: 0.34),
                RoamColors.ink.withValues(alpha: 0.72),
              ]
            : [
                Colors.transparent,
                Colors.transparent,
                Colors.white.withValues(alpha: 0.10),
                Colors.white.withValues(alpha: 0.46),
              ],
        stops: const [0, 0.58, 0.86, 1],
      ).createShader(rect);
    canvas.drawRect(rect, paint);
  }

  @override
  bool shouldRepaint(_SpacePainter oldDelegate) => oldDelegate.isDark != isDark;
}
