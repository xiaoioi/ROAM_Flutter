// progressiveTextureBlur —— miuix 原版组件的 Flutter 端移植。
//
// 原版：compose-miuix-ui/miuix · miuix-blur
//   fun Modifier.progressiveTextureBlur(backdrop, shape, blurRadius,
//       gradient = ProgressiveBlur.Top, noiseCoefficient, colors, ...)
//
// 原版的关键有两点，缺一不可：
//   1. 半径沿方向**连续**衰减（不是几张不同半径的图硬叠）；
//   2. 每一处模糊都是完整的**可分离高斯**（H/V 两 pass RenderEffect），
//      所以整块内容是一起散开的，不会出现离散采样点的重影。
//
// 上一版用 FragmentShader 逐像素算半径 + 40 个螺旋采样点近似二维高斯：
// 半径一大采样就变稀，画面被拆成一个个错位的块（看起来「像碎成好几块」），
// 而且每帧整条带子都要跑一遍逐像素循环——延迟也来自这里。
//
// 现在的做法：
//   • 半径分档，档位在 u 轴上按 `pow(i/(n-1), 1/curve)` 摆放（与原版逐像素
//     半径曲线同一个函数），相邻档用三角权重做线性插值；三角权重天然构成
//     单位分解（Σw ≡ 1），所以插值出来是连续的「半糊」过渡，没有台阶。
//   • 每档的模糊交给 `ImageFilter.blur`：Impeller/Skia 内部就是降采样 + 可分离
//     高斯，GPU 原生路径，没有块状伪影，也没有逐像素循环。
//   • 每档先 `saveLayer` 隔离、`dstIn` 打上权重遮罩再合成。全程只有 GPU 绘制，
//     没有 `toImageSync`、没有纹理重建。
//
// ⚠️ 实测坑：`canvas.saveLayer(bounds, Paint())` 的 bounds 如果取得和带子一样大，
// 那次 `drawImageRect` 的 `imageFilter` 会被连同输入一起裁掉（表现为「一点没糊」）。
// 所以 saveLayer 的 bounds 必须用采样区（dst）。
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

  /// 90 = 从上往下（顶部满强度），270 = 从下往上。
  final double angle;

  /// 满强度区结束位置（沿方向的 0..1）。
  final double startFraction;

  /// 过渡结束位置（之后 radius = 0，完全清晰）。
  final double endFraction;

  /// 衰减指数：1 = 线性，>1 前段更糊。
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

  /// 对应 `computeProgressiveGradient`：返回 (gradVec, gradOffset)，
  /// 使 `dot(q, vec) + offset` 在 startFraction 处为 0、endFraction 处为 1。
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

/// 渐进纹理模糊：半径沿 [gradient] 方向从 [blurRadius] 连续衰减到 0。
///
/// 需要 [backdrop] 提供快照（页面级 [MiuixLayerBackdrop]），不能跨 Navigator
/// 层实时采样。
class MiuixProgressiveTextureBlur extends StatelessWidget {
  const MiuixProgressiveTextureBlur({
    super.key,
    required this.backdrop,
    this.blurRadius = 80,
    this.gradient = ProgressiveBlur.top,
    this.shape,
    this.enabled = true,
    this.levels = 7,
    this.child,
  });

  final MiuixBackdrop backdrop;

  /// 满强度端的模糊半径（dp），与官方 `progressiveBlurRadius` 一致。
  final double blurRadius;

  final ProgressiveBlur gradient;
  final ShapeBorder? shape;
  final bool enabled;

  /// 半径档数。档间是线性插值，6 档在 200dp 的带子上已经看不出分段。
  final int levels;

  final Widget? child;

  @override
  Widget build(BuildContext context) {
    if (!enabled || blurRadius <= 0 || levels < 2) {
      return child ?? const SizedBox.shrink();
    }
    final Widget blur = _ProgressiveBlur(
      backdrop: backdrop,
      blurRadius: blurRadius,
      gradient: gradient,
      levels: levels,
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
    required this.levels,
  });

  final MiuixBackdrop backdrop;
  final double blurRadius;
  final ProgressiveBlur gradient;
  final int levels;

  @override
  RenderObject createRenderObject(BuildContext context) => _RenderProgressive(
    backdrop: backdrop,
    blurRadius: blurRadius,
    gradient: gradient,
    levels: levels,
  );

  @override
  void updateRenderObject(BuildContext context, RenderObject renderObject) {
    (renderObject as _RenderProgressive)
      ..backdrop = backdrop
      ..blurRadius = blurRadius
      ..gradient = gradient
      ..levels = levels;
  }
}

/// 单个档位：模糊半径 + 三角权重 (stops, alphas) + 该档覆盖的 u 区间。
class _Layer {
  const _Layer({
    required this.sigma,
    required this.stops,
    required this.alphas,
    required this.u0,
    required this.u1,
  });

  final double sigma;
  final List<double> stops;
  final List<double> alphas;

  /// 遮罩不为零的 u 区间，用来把这一档的绘制裁成窄条（省填充率）。
  final double u0;
  final double u1;
}

class _RenderProgressive extends RenderProxyBox {
  _RenderProgressive({
    required MiuixBackdrop backdrop,
    required double blurRadius,
    required ProgressiveBlur gradient,
    required int levels,
  }) : _backdrop = backdrop,
       _blurRadius = blurRadius,
       _gradient = gradient,
       _levels = levels {
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

  int _levels;
  set levels(int v) {
    if (_levels == v) return;
    _levels = v;
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

  /// 档位表。`sigma = radius * .5 + .5`（与原版一致），u 轴位置由原版曲线反解。
  List<_Layer> _layers(double maxRadius) {
    final n = _levels;
    final g = _gradient;
    final curve = g.curve <= 0 ? 1.0 : g.curve;
    final sf = g.startFraction;
    final ef = g.endFraction;

    final u = List<double>.filled(n, 0);
    final s = List<double>.filled(n, 0);
    for (var i = 0; i < n; i++) {
      // 反解：smooth(u_i) = i/(n-1) → u_i，再线性映射到 box 投影参数 s。
      u[i] = math.pow(i / (n - 1), 1 / curve).toDouble();
      s[i] = (sf + u[i] * (ef - sf)).clamp(0.0, 1.0);
    }

    final out = <_Layer>[];
    for (var i = 0; i < n; i++) {
      final radius = maxRadius * (1 - i / (n - 1));
      // 原版 sigma = radius*.5+.5；这里取 .62，同一 radius 下模糊更实一档
      // （「模糊程度不够」的反馈），过渡段宽度不变。
      final sigma = radius * 0.55 + 0.5;

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

      if (i == 0) {
        add(0, 1);
        add(s[1], 0);
      } else if (i == n - 1) {
        add(s[n - 2], 0);
        add(1, 1);
      } else {
        add(s[i - 1], 0);
        add(s[i], 1);
        add(s[i + 1], 0);
      }
      if (stops.length >= 2) {
        out.add(
          _Layer(
            sigma: sigma,
            stops: stops,
            alphas: alphas,
            u0: i == 0 ? -1 : u[i - 1],
            u1: i == n - 1 ? 2 : u[i + 1],
          ),
        );
      }
    }
    return out;
  }

  @override
  void paint(PaintingContext context, Offset offset) {
    final image = _backdrop.snapshot;
    final bg = _backdrop.globalOffset;
    if (image == null || bg == null || size.isEmpty) {
      super.paint(context, offset);
      return;
    }

    final dpr = _backdrop.pixelRatio;
    final selfGlobal = localToGlobal(Offset.zero);
    // 组件在快照像素空间里的位置。
    final compL = (selfGlobal.dx - bg.dx) * dpr;
    final compT = (selfGlobal.dy - bg.dy) * dpr;

    final maxSigma = _blurRadius * 0.55 + 0.5;
    // 采样区按 3σ 外扩：高斯核要吃进带子外面的像素，否则上缘会掉色。
    final pad = maxSigma * 3 * dpr;
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

    final g = _gradient;
    final rad = g.angle * math.pi / 180;
    final d = Offset(math.cos(rad), math.sin(rad));
    // 把方向投影到带子四角，得到 u=0 / u=1 对应的两个像素点：
    // 用 ui.Gradient.linear 显式给坐标，不依赖 Alignment 的归一化（非正方形
    // 区域上 Alignment 渐变会把 stops 映射到 [−.5,.5]，遮罩会整体错位）。
    double proj(Offset p) => p.dx * d.dx + p.dy * d.dy;
    final p0 = proj(band.topLeft);
    final p1 = proj(band.topRight);
    final p2 = proj(band.bottomLeft);
    final p3 = proj(band.bottomRight);
    final pMin = math.min(math.min(p0, p1), math.min(p2, p3));
    final pMax = math.max(math.max(p0, p1), math.max(p2, p3));
    final spanP = math.max(1e-3, pMax - pMin);
    final center = band.center;
    final base = proj(center);
    Offset at(double t) => center + d * (pMin + t * spanP - base);
    final start = at(g.startFraction);
    final finish = at(g.endFraction.clamp(g.startFraction + 1e-3, 1.0));

    final layers = _layers(_blurRadius);
    final vertical = g.angle == 90 || g.angle == 270;

    final canvas = context.canvas;
    // 外层隔离：所有档位都在这层里合成，避免半透明档位把下面的页面内容
    // 透上来（那会让上半段又「变清楚」）。bounds 同样用 dst。
    canvas.saveLayer(dst, Paint());
    for (final layer in layers) {
      // 该档负责的 u 区间 → 屏幕上的窄条（只对上下方向做裁剪）。
      Rect? strip;
      if (vertical) {
        final h = size.height;
        double yOf(double u) {
          final sN = (g.startFraction + u * (g.endFraction - g.startFraction))
              .clamp(0.0, 1.0);
          return offset.dy + (g.angle == 90 ? sN : 1 - sN) * h;
        }

        final top = yOf(layer.u0).clamp(band.top, band.bottom);
        final bottom = yOf(layer.u1).clamp(band.top, band.bottom);
        if (bottom - top <= 0.5) continue;
        strip = Rect.fromLTRB(band.left, top, band.right, bottom);
      }

      final mask = ui.Gradient.linear(
        start,
        finish,
        [for (final a in layer.alphas) Color.fromRGBO(255, 255, 255, a)],
        layer.stops,
        TileMode.clamp,
      );

      // ⚠️ bounds 用 dst：用 band 的话 Skia 会把 filter 的输入一起裁掉，
      // 结果就是「图层保存了，但一点没糊」。
      //
      // 合成用 plus（预乘 alpha 相加）：三角权重和恒为 1，所以 alpha 相加正好
      // 回到 1（不透明），颜色就是加权平均。用 srcOver 的话两个半透明档会
      // 留下 1-Π(1-a) 的空隙，下面的页面内容透上来，文字又「变清楚」了。
      canvas.saveLayer(dst, Paint()..blendMode = BlendMode.plus);
      canvas.clipRect(strip ?? dst);
      canvas.drawImageRect(
        image,
        src,
        dst,
        Paint()
          ..filterQuality = FilterQuality.medium
          ..imageFilter = ui.ImageFilter.blur(
            sigmaX: layer.sigma,
            sigmaY: layer.sigma,
            tileMode: TileMode.clamp,
          ),
      );
      // dstIn：用三角权重把这一档擦掉，只留它负责的那一段。
      canvas.drawRect(
        strip ?? dst,
        Paint()
          ..blendMode = BlendMode.dstIn
          ..shader = mask
          ..isAntiAlias = false,
      );
      canvas.restore();
    }
    canvas.restore();

    super.paint(context, offset);
  }
}
