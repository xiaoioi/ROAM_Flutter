// progressiveTextureBlur —— miuix `Modifier.progressiveTextureBlur` 的 Flutter 端实现。
//
// 原版：compose-miuix-ui/miuix · miuix-blur
//   fun Modifier.progressiveTextureBlur(backdrop, shape, blurRadius,
//       gradient = ProgressiveBlur.Top, noiseCoefficient, colors, ...)
//
// ⚠️ 千万不要用「多张不同模糊度的图叠加 + 三角权重」来模拟半径渐变
// （v1.0.38~v1.0.40 就是这么做的，实测三个致命问题）：
//   1. 文字是高频高对比内容，两张清晰度不同的图叠在一起就是「双重轮廓」，
//      人眼一眼看出是好几块，不是「整体散开」；
//   2. 档与档的交接处权重交叉，边界会浮出一条浅台阶（断层）；
//   3. 半透明档位合成时 alpha 补不满，下面的页面内容透上来，越靠边越「透明」。
// 而且每档一次 `saveLayer` + 一次全屏 `ImageFilter.blur`，7 档就是 7 倍填充率，
// 真机上直接卡死、滚动时模糊跟不上（延迟）。
//
// 现在只画**一张**图：按满强度半径模糊一次，再用一条连续的 alpha 遮罩把它从
// 「完全不透明」擦到「完全透明」。
//   • 只有一份图像 → 不存在重影、不存在档位断层；
//   • 顶部 alpha = 1 → 看不见模糊层后面的内容；
//   • 过渡段模糊层半透明 → 下面的正文透上来，视觉上就是「由清晰逐渐起雾」；
//   • 每次绘制只有 1 次 saveLayer + 1 次 blur，开销与带子面积成正比。
//
// 遮罩用 `ui.Gradient.linear` 显式给像素坐标：`Alignment` 渐变在非正方形区域
// 会把 stops 压到 [−.5,.5]，遮罩会整体错位（上半截反而清晰）。
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_miuix/miuix.dart';

/// 对应 Kotlin `ProgressiveBlur`：方向 + 过渡区间 + 衰减曲线。
@immutable
class ProgressiveBlur {
  const ProgressiveBlur({
    this.angle = 90,
    this.startFraction = 0,
    this.endFraction = 1,
    this.curve = 1,
  }) : assert(endFraction > startFraction);

  /// 90 = 从上往下（顶部糊），270 = 从下往上。
  final double angle;

  /// 满强度区结束位置（沿方向的 0..1），之前 alpha 恒为 1。
  final double startFraction;

  /// 过渡结束位置（之后 alpha = 0，完全清晰）。
  final double endFraction;

  /// 衰减指数：1 = 线性，>1 前段更糊（过渡更靠后）。
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

  /// 对应原版 `computeProgressiveGradient`：(gradVec, gradOffset)。
  (Offset, double) gradient() {
    final rad = angle * math.pi / 180;
    final ax = math.cos(rad);
    final ay = math.sin(rad);
    final projMin = (ax > 0 ? 0.0 : ax) + (ay > 0 ? 0.0 : ay);
    final projMax = (ax > 0 ? ax : 0.0) + (ay > 0 ? 0.0 : ay);
    final span = projMax - projMin;
    final full = projMin + startFraction * span;
    final zero = projMin + endFraction * span;
    final d = (zero - full).abs() < 1e-3 ? 1e-3 : zero - full;
    return (Offset(ax / d, ay / d), -full / d);
  }
}

/// 渐进纹理模糊：沿 [gradient] 方向，模糊强度从满强度连续淡到 0。
///
/// 需要 [backdrop] 提供快照（页面级 `MiuixLayerBackdrop`）。
class MiuixProgressiveTextureBlur extends StatelessWidget {
  const MiuixProgressiveTextureBlur({
    super.key,
    required this.backdrop,
    this.blurRadius = 80,
    this.gradient = ProgressiveBlur.top,
    this.shape,
    this.enabled = true,
    this.child,
  });

  final MiuixBackdrop backdrop;

  /// 满强度端的模糊半径（dp），与官方 `progressiveBlurRadius` 一致。
  final double blurRadius;

  final ProgressiveBlur gradient;
  final ShapeBorder? shape;
  final bool enabled;
  final Widget? child;

  @override
  Widget build(BuildContext context) {
    if (!enabled || blurRadius <= 0) {
      return child ?? const SizedBox.shrink();
    }
    final Widget blur = _ProgressiveBlur(
      backdrop: backdrop,
      blurRadius: blurRadius,
      gradient: gradient,
    );
    final Widget sized = SizedBox.expand(child: blur);
    if (shape == null) return sized;
    return ClipPath(clipper: ShapeBorderClipper(shape: shape!), child: sized);
  }
}

class _ProgressiveBlur extends SingleChildRenderObjectWidget {
  const _ProgressiveBlur({
    required this.backdrop,
    required this.blurRadius,
    required this.gradient,
  });

  final MiuixBackdrop backdrop;
  final double blurRadius;
  final ProgressiveBlur gradient;

  @override
  RenderObject createRenderObject(BuildContext context) => _RenderProgressive(
    backdrop: backdrop,
    blurRadius: blurRadius,
    gradient: gradient,
  );

  @override
  void updateRenderObject(BuildContext context, RenderObject renderObject) {
    (renderObject as _RenderProgressive)
      ..backdrop = backdrop
      ..blurRadius = blurRadius
      ..gradient = gradient;
  }
}

class _RenderProgressive extends RenderProxyBox {
  _RenderProgressive({
    required MiuixBackdrop backdrop,
    required double blurRadius,
    required ProgressiveBlur gradient,
  }) : _backdrop = backdrop,
       _blurRadius = blurRadius,
       _gradient = gradient {
    _backdrop.addListener(markNeedsPaint);
  }

  MiuixBackdrop _backdrop;
  set backdrop(MiuixBackdrop v) {
    if (identical(_backdrop, v)) return;
    _backdrop.removeListener(markNeedsPaint);
    _backdrop = v..addListener(markNeedsPaint);
    markNeedsPaint();
  }

  double _blurRadius;
  set blurRadius(double v) {
    if (_blurRadius == v) return;
    _blurRadius = v;
    markNeedsPaint();
  }

  ProgressiveBlur _gradient;
  set gradient(ProgressiveBlur v) {
    if (_gradient == v) return;
    _gradient = v;
    markNeedsPaint();
  }

  @override
  void attach(PipelineOwner owner) {
    super.attach(owner);
    _backdrop.addListener(markNeedsPaint);
  }

  @override
  void detach() {
    _backdrop.removeListener(markNeedsPaint);
    super.detach();
  }

  @override
  void dispose() {
    _backdrop.removeListener(markNeedsPaint);
    super.dispose();
  }

  @override
  void paint(PaintingContext context, Offset offset) {
    final image = _backdrop.snapshot;
    final bg = _backdrop.globalOffset;
    final dpr = _backdrop.pixelRatio;
    if (image == null || bg == null || dpr <= 0 || size.isEmpty) {
      super.paint(context, offset);
      return;
    }

    // 原版 sigma = radius * .5 + .5（逻辑像素；Skia 会按画布变换换算设备像素）。
    final sigma = _blurRadius * 0.5 + 0.5;
    // 采样区按 2σ 外扩：高斯核要吃进带子外面的像素，否则上缘会掉色。
    final pad = (sigma * 2).ceilToDouble() * dpr;

    final selfGlobal = localToGlobal(Offset.zero);
    final compL = (selfGlobal.dx - bg.dx) * dpr;
    final compT = (selfGlobal.dy - bg.dy) * dpr;

    final l = math.max(0.0, compL - pad);
    final t = math.max(0.0, compT - pad);
    final r = math.min(image.width.toDouble(), compL + size.width * dpr + pad);
    final b = math.min(image.height.toDouble(), compT + size.height * dpr + pad);
    if (r <= l || b <= t) {
      super.paint(context, offset);
      return;
    }

    final src = Rect.fromLTRB(l, t, r, b);
    final dst = Rect.fromLTRB(
      offset.dx + (l - compL) / dpr,
      offset.dy + (t - compT) / dpr,
      offset.dx + (r - compL) / dpr,
      offset.dy + (b - compT) / dpr,
    );
    final band = offset & size;

    // 沿方向投影到带子四角，得到 u=0 / u=1 的像素点位（显式坐标，避免
    // Alignment 归一化在非正方形区域上把 stops 压扁）。
    final g = _gradient;
    final rad = g.angle * math.pi / 180;
    final dir = Offset(math.cos(rad), math.sin(rad));
    double proj(Offset p) => p.dx * dir.dx + p.dy * dir.dy;
    final pMin = math.min(
      math.min(proj(band.topLeft), proj(band.topRight)),
      math.min(proj(band.bottomLeft), proj(band.bottomRight)),
    );
    final pMax = math.max(
      math.max(proj(band.topLeft), proj(band.topRight)),
      math.max(proj(band.bottomLeft), proj(band.bottomRight)),
    );
    final spanP = math.max(1e-3, pMax - pMin);
    final center = band.center;
    final base = proj(center);
    Offset at(double u) => center + dir * (pMin + u * spanP - base);

    final ef = g.endFraction.clamp(1e-2, 1.0);
    final sf = g.startFraction.clamp(0.0, ef - 1e-3);
    final curve = g.curve <= 0 ? 1.0 : g.curve;
    final from = at(0);
    final to = at(ef);

    // 遮罩：0..sf 恒为 1（满强度、完全不透明），sf..ef 按 pow(1-u, curve) 淡到 0，
    // ef 之后为 0（clamp 外推）。
    final stops = <double>[0];
    final alphas = <double>[1];
    void addStop(double s, double a) {
      final v = s.clamp(0.0, 1.0);
      final av = a.clamp(0.0, 1.0);
      if (stops.isNotEmpty && (v - stops.last).abs() < 1e-4) {
        alphas[alphas.length - 1] = math.max(alphas.last, av);
        return;
      }
      stops.add(v);
      alphas.add(av);
    }

    const steps = 8;
    for (var i = 0; i <= steps; i++) {
      final k = i / steps;
      final u = sf + (ef - sf) * k; // 带子归一化坐标
      final a = math.pow(1 - k, curve).toDouble();
      addStop(u / ef, a); // 归一化到 from→to
    }

    final canvas = context.canvas;
    // 隔离层：遮罩用 dstIn，不隔离会把画布下层一起擦掉。
    canvas.saveLayer(dst, Paint());
    canvas.clipRect(band);
    canvas.drawImageRect(
      image,
      src,
      dst,
      Paint()
        ..filterQuality = FilterQuality.medium
        ..imageFilter = ui.ImageFilter.blur(
          sigmaX: sigma,
          sigmaY: sigma,
          tileMode: TileMode.clamp,
        ),
    );
    canvas.drawRect(
      dst,
      Paint()
        ..blendMode = BlendMode.dstIn
        ..shader = ui.Gradient.linear(
          from,
          to,
          [for (final a in alphas) Color.fromRGBO(255, 255, 255, a)],
          stops,
          TileMode.clamp,
        )
        ..isAntiAlias = false,
    );
    canvas.restore();

    super.paint(context, offset);
  }
}
