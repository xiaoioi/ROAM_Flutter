// `Modifier.progressiveTextureBlur` 的 Flutter 补齐实现。
//
// 官方 compose 版 miuix-blur 提供
// `Modifier.progressiveTextureBlur(backdrop, shape, blurRadius,
//   gradient = ProgressiveBlur.Top/Bottom/Left/Right, colors)`：
// 模糊强度沿方向从满强度连续过渡到 0，清晰端保持全分辨率。
//
// `flutter_miuix`（pub 最新 1.4.0）只移植了 `textureBlur`，没有这个 Modifier。
// 这里按官方语义补齐：把 blurRadius 线性分成 levels 档，每档就用**库自己的**
// `MiuixTextureBlur` 画（不是第三方渲染、也不是裸 BackdropFilter），每档再套一条
// 沿方向的「三角权重」遮罩（partition of unity），相邻档交叉淡化。
// 任一位置各档权重之和恒为 1，所以不会叠出「越叠越暗」或台阶。
//
// 端点权重必须为 1（清晰端那档画的是原图，满强度端那档画的是最大半径）——
// 曾经把端点 alpha 写成 0，结果两端都露出中间档，观感就是「渐隐不对」。
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_miuix/miuix.dart';

/// 对应 Kotlin `ProgressiveBlur`：方向 + 过渡区间 + 衰减曲线。
@immutable
class ProgressiveBlur {
  const ProgressiveBlur({
    this.angle = 90,
    this.startFraction = 0,
    this.endFraction = 0.72,
    this.curve = 0.9,
  }) : assert(endFraction > startFraction);

  /// 90 = 从上往下（顶部最强），270 = 从下往上。
  final double angle;

  /// 满强度区终点（沿方向的 0..1 位置）。
  final double startFraction;

  /// 过渡结束位置（之后完全清晰）。
  final double endFraction;

  /// 衰减曲线指数：>1 前段更糊，<1 更早变清晰。
  final double curve;

  static const top = ProgressiveBlur();
  static const bottom = ProgressiveBlur(angle: 270);

  ProgressiveBlur copyWith({
    double? angle,
    double? startFraction,
    double? endFraction,
    double? curve,
  }) => ProgressiveBlur(
    angle: angle ?? this.angle,
    startFraction: startFraction ?? this.startFraction,
    endFraction: endFraction ?? this.endFraction,
    curve: curve ?? this.curve,
  );

  /// 渐变起点（满强度端）。
  Alignment get begin => angle == 270
      ? Alignment.bottomCenter
      : angle == 0
      ? Alignment.centerLeft
      : angle == 180
      ? Alignment.centerRight
      : Alignment.topCenter;

  /// 渐变终点（清晰端）。
  Alignment get end => angle == 270
      ? Alignment.topCenter
      : angle == 0
      ? Alignment.centerRight
      : angle == 180
      ? Alignment.centerLeft
      : Alignment.bottomCenter;

  /// 位置 [t]（沿方向的 0..1）处的模糊强度比例，1 = 满强度。
  double ratioAt(double t) {
    if (t <= startFraction) return 1;
    if (t >= endFraction) return 0;
    final u = (t - startFraction) / (endFraction - startFraction);
    return math.pow(1 - u, curve).toDouble();
  }

  /// [ratioAt] 的反函数：某强度比例对应的位置。
  double tAt(double ratio) {
    if (ratio >= 1) return startFraction;
    if (ratio <= 0) return endFraction;
    final u = 1 - math.pow(ratio, 1 / curve);
    return startFraction + u * (endFraction - startFraction);
  }
}

/// 渐进模糊本体：叠 [levels] 档库的 [MiuixTextureBlur]，档间用三角权重交叉淡化。
class MiuixProgressiveTextureBlur extends StatelessWidget {
  const MiuixProgressiveTextureBlur({
    super.key,
    required this.backdrop,
    this.blurRadius = 80,
    this.gradient = ProgressiveBlur.top,
    this.levels = 5,
    this.shape,
    this.colors = const BlurColors(),
    this.enabled = true,
    this.child,
  });

  final MiuixBackdrop backdrop;

  /// 满强度端的模糊半径（dp）。
  final double blurRadius;

  final ProgressiveBlur gradient;

  /// 档数；5 档在 80dp 半径下已看不出台阶。
  final int levels;

  final ShapeBorder? shape;
  final BlurColors colors;
  final bool enabled;
  final Widget? child;

  @override
  Widget build(BuildContext context) {
    if (!enabled || blurRadius <= 0) return child ?? const SizedBox.expand();
    final n = levels.clamp(2, 8);
    final layers = <Widget>[];
    for (var i = 0; i < n; i++) {
      // i=0 → 满强度半径；i=n-1 → 半径 0（原图，清晰端）。
      final ratio = 1 - i / (n - 1);
      layers.add(
        Positioned.fill(
          child: ShaderMask(
            blendMode: BlendMode.dstIn,
            shaderCallback: (bounds) => _mask(gradient, ratio, n).createShader(
              bounds,
            ),
            child: MiuixTextureBlur(
              backdrop: backdrop,
              blurRadius: blurRadius * ratio,
              colors: colors,
            ),
          ),
        ),
      );
    }

    Widget stack = Stack(fit: StackFit.expand, children: layers);
    if (child != null) {
      stack = Stack(
        fit: StackFit.expand,
        children: [stack, child!],
      );
    }
    if (shape == null) return stack;
    return ClipPath(clipper: ShapeBorderClipper(shape: shape!), child: stack);
  }

  /// 第 [ratio] 档的三角权重遮罩：峰值 1 落在它自己的位置，到相邻档位线性降到 0；
  /// 两端档在边界处保持 1（端点不能归零，否则清晰端/满强度端会露出别的档）。
  LinearGradient _mask(ProgressiveBlur g, double ratio, int n) {
    final self = g.tAt(ratio);
    // 相邻档位（在 t 轴上）——端点只取单侧。
    final idx = ((1 - ratio) * (n - 1)).round();
    final prevT = idx > 0 ? g.tAt(1 - (idx - 1) / (n - 1)) : null;
    final nextT = idx < n - 1 ? g.tAt(1 - (idx + 1) / (n - 1)) : null;

    final stops = <double>[];
    final alphas = <double>[];
    void add(double t, double a) {
      final v = t.clamp(0.0, 1.0);
      if (stops.isNotEmpty && (v - stops.last).abs() < 1e-4) {
        if (a > alphas.last) alphas[alphas.length - 1] = a;
        return;
      }
      stops.add(v);
      alphas.add(a);
    }

    if (prevT == null) {
      // 满强度端：从 t=0 起就是峰值。
      add(0, 1);
    } else {
      add(0, 0);
      add(prevT, 0);
      add(self, 1);
    }
    if (nextT == null) {
      // 清晰端：到 t=1 仍是峰值（这一档半径 0，画原图）。
      add(1, 1);
    } else {
      add(self, 1);
      add(nextT, 0);
      add(1, 0);
    }

    return LinearGradient(
      begin: g.begin,
      end: g.end,
      colors: [for (final a in alphas) Color.fromRGBO(255, 255, 255, a)],
      stops: stops,
    );
  }
}
