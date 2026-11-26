// ignore_for_file: deprecated_member_use

import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../theme/roam_theme.dart';

/// 星环的标记：一颗被斜环穿过的行星。
class RoamMark extends StatelessWidget {
  const RoamMark({
    super.key,
    this.size = 34,
    this.brightness = Brightness.dark,
  });

  final double size;
  final Brightness brightness;

  @override
  Widget build(BuildContext context) {
    return SizedBox.square(
      dimension: size,
      child: CustomPaint(
        painter: _MarkPainter(isDark: brightness == Brightness.dark),
      ),
    );
  }
}

class _MarkPainter extends CustomPainter {
  const _MarkPainter({required this.isDark});

  final bool isDark;

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.shortestSide * 0.30;

    // 行星本身：中心亮、边缘暗，带一点青色。
    final core = Paint()
      ..shader = RadialGradient(
        center: const Alignment(-0.35, -0.45),
        colors: [
          Colors.white,
          isDark ? RoamColors.aurora : RoamColors.auroraDeep,
          isDark ? const Color(0xFF0E6F63) : const Color(0xFF0A5C52),
        ],
        stops: const [0, 0.55, 1],
      ).createShader(Rect.fromCircle(center: center, radius: radius));
    canvas.drawCircle(center, radius, core);

    final halo = Paint()
      ..shader = RadialGradient(
        colors: [
          RoamColors.aurora.withValues(alpha: isDark ? 0.34 : 0.22),
          RoamColors.aurora.withValues(alpha: 0),
        ],
      ).createShader(Rect.fromCircle(center: center, radius: size.width * 0.5));
    canvas.drawCircle(center, size.width * 0.5, halo);

    // 环：一条压扁的椭圆，前后两段粗细不同，形成穿插感。
    canvas.save();
    canvas.translate(center.dx, center.dy);
    canvas.rotate(-0.42);
    final ringRect = Rect.fromCenter(
      center: Offset.zero,
      width: size.width * 1.02,
      height: size.width * 0.40,
    );
    final ring = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = size.shortestSide * 0.075
      ..strokeCap = StrokeCap.round
      ..shader = SweepGradient(
        colors: [
          (isDark ? Colors.white : Colors.white).withValues(alpha: 0.95),
          RoamColors.iris.withValues(alpha: 0.85),
          RoamColors.aurora.withValues(alpha: 0.15),
          Colors.white.withValues(alpha: 0.9),
        ],
        stops: const [0, 0.36, 0.68, 1],
      ).createShader(ringRect);
    canvas.drawOval(ringRect, ring);
    canvas.restore();

    // 环上的小卫星。
    final moonAngle = -2.35;
    final moon = Offset(
      center.dx + math.cos(moonAngle) * size.width * 0.49,
      center.dy + math.sin(moonAngle) * size.width * 0.13,
    );
    canvas.drawCircle(
      moon,
      size.shortestSide * 0.045,
      Paint()..color = isDark ? Colors.white : RoamColors.iris,
    );
  }

  @override
  bool shouldRepaint(_MarkPainter oldDelegate) => oldDelegate.isDark != isDark;
}

/// 「星环 ROAM」字标。
class RoamWordmark extends StatelessWidget {
  const RoamWordmark({
    super.key,
    this.brightness = Brightness.dark,
    this.compact = false,
  });

  final Brightness brightness;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final isDark = brightness == Brightness.dark;
    final primary = isDark ? RoamColors.textPrimary : RoamColors.dayInk;
    return Row(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.baseline,
      textBaseline: TextBaseline.alphabetic,
      children: [
        Text(
          '星环',
          style: RoamType.wordmark.copyWith(
            color: primary,
            fontSize: compact ? 20 : 26,
            letterSpacing: compact ? 1.6 : 2.4,
          ),
        ),
        const SizedBox(width: 7),
        Text(
          'ROAM',
          style: RoamType.caption.copyWith(
            color: isDark ? RoamColors.aurora : RoamColors.auroraDeep,
            fontWeight: FontWeight.w700,
            letterSpacing: compact ? 2.0 : 3.4,
            fontSize: compact ? 9.5 : 11,
          ),
        ),
      ],
    );
  }
}
