// progressiveTextureBlur —— miuix 原版组件的 Flutter 端移植。
//
// 原版：compose-miuix-ui/miuix · miuix-blur
//   fun Modifier.progressiveTextureBlur(backdrop, shape, blurRadius,
//       gradient = ProgressiveBlur.Top, noiseCoefficient, colors, ...)
//
// 实现路径（与 Kotlin 侧一一对应）：
//   ProgressiveBlur(angle/startFraction/endFraction/curve)
//     → computeProgressiveGradient() 归一化成 gradVec + gradOffset
//     → createProgressiveBlurEffect()：逐像素 radius = maxRadius * (1 - smooth)
//     → 半径随位置变化的高斯（原版 H/V 两 pass，这里单 pass 螺旋采样）
//
// 与上一版「多张不同半径的图叠在一起」的区别：半径是**逐像素**算出来的，
// 中间段是真正的中等模糊，清晰端是原图（radius→0 早退），所以没有台阶、
// 没有多档混合的重影，也不会因为叠 5 层全尺寸高斯而卡顿。
//
// Flutter 侧只多做一件事：按 sigma 把快照降采样（1×/2×/4×/8×）再卷积，
// 对齐原版 `downscaleFactor`（sigma<4.5 → 1×，<12 → 2×，<32 → 4×，<115 → 8×）。
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

  /// 衰减指数：0/1 = 线性，>1 前段更糊。
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
    final projMax = (ax > 0 ? ax : 0.0) + (ay > 0 ? ay : 0.0);
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
class MiuixProgressiveTextureBlur extends StatefulWidget {
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
  State<MiuixProgressiveTextureBlur> createState() =>
      _MiuixProgressiveTextureBlurState();
}

class _MiuixProgressiveTextureBlurState
    extends State<MiuixProgressiveTextureBlur> {
  static ui.FragmentShader? _shared;
  static bool _failed = false;

  ui.FragmentShader? _shader;

  @override
  void initState() {
    super.initState();
    _shader = _shared;
    if (_shared == null && !_failed) _load();
  }

  Future<void> _load() async {
    try {
      final program = await ui.FragmentProgram.fromAsset(
        'shaders/progressive_blur.frag',
      );
      _shared = program.fragmentShader();
      if (mounted) setState(() => _shader = _shared);
    } catch (_) {
      _failed = true;
      // 加载失败时退回单层纹理模糊（不做渐进），至少不会空白。
      if (mounted) setState(() {});
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.enabled || widget.blurRadius <= 0) {
      return widget.child ?? const SizedBox.shrink();
    }
    final shader = _shader;

    Widget blur;
    if (shader != null) {
      blur = _ProgressiveBlur(
        backdrop: widget.backdrop,
        blurRadius: widget.blurRadius,
        gradient: widget.gradient,
        shader: shader,
      );
    } else {
      // 兜底：库的 textureBlur + 官方 band 淡出（渐进 shader 就绪前的首帧）。
      blur = ShaderMask(
        blendMode: BlendMode.dstIn,
        shaderCallback:
            MiuixGlassTopAppBarDefaults.bandBlurMask().createShader,
        child: MiuixTextureBlur(
          backdrop: widget.backdrop,
          blurRadius: widget.blurRadius,
        ),
      );
    }

    final sized = SizedBox.expand(child: blur);
    if (widget.shape == null) return sized;
    return ClipPath(clipper: ShapeBorderClipper(shape: widget.shape!), child: sized);
  }
}

class _ProgressiveBlur extends SingleChildRenderObjectWidget {
  const _ProgressiveBlur({
    required this.backdrop,
    required this.blurRadius,
    required this.gradient,
    required this.shader,
  });

  final MiuixBackdrop backdrop;
  final double blurRadius;
  final ProgressiveBlur gradient;
  final ui.FragmentShader shader;

  @override
  RenderObject createRenderObject(BuildContext context) => _RenderProgressive(
    backdrop: backdrop,
    blurRadius: blurRadius,
    gradient: gradient,
    shader: shader,
  );

  @override
  void updateRenderObject(BuildContext context, RenderObject renderObject) {
    (renderObject as _RenderProgressive)
      ..backdrop = backdrop
      ..blurRadius = blurRadius
      ..gradient = gradient
      ..shader = shader;
  }
}

class _RenderProgressive extends RenderProxyBox {
  _RenderProgressive({
    required MiuixBackdrop backdrop,
    required double blurRadius,
    required ProgressiveBlur gradient,
    required ui.FragmentShader shader,
  }) : _backdrop = backdrop,
       _blurRadius = blurRadius,
       _gradient = gradient,
       _shader = shader {
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

  ui.FragmentShader _shader;
  set shader(ui.FragmentShader v) {
    if (identical(_shader, v)) return;
    _shader = v;
    markNeedsPaint();
  }

  /// 降采样纹理缓存：快照/几何/参数不变时直接复用，避免静止画面每帧重建。
  ui.Image? _tex;
  Object? _texKey;

  @override
  void detach() {
    _backdrop.removeListener(markNeedsPaint);
    super.detach();
  }

  @override
  void attach(PipelineOwner owner) {
    super.attach(owner);
    _backdrop.addListener(markNeedsPaint);
  }

  @override
  void dispose() {
    _backdrop.removeListener(markNeedsPaint);
    _tex?.dispose();
    _tex = null;
    super.dispose();
  }

  /// 降采样倍率。原版按 sigma 分 1×/2×/4×/8×，但它有 H/V 两个可分离 pass，
  /// 单 pass 二维采样在 8× 纹理上会出块，这里封顶 4×。
  int _downscale(double radius) {
    final sigma = radius * 0.45;
    if (sigma < 10) return 1;
    return 2;
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
    final pad = _blurRadius * dpr;

    final l = math.max(0.0, compL - pad);
    final t = math.max(0.0, compT - pad);
    final r = math.min(image.width.toDouble(), compL + size.width * dpr + pad);
    final b = math.min(image.height.toDouble(), compT + size.height * dpr + pad);
    if (r <= l || b <= t) {
      super.paint(context, offset);
      return;
    }

    final scale = _downscale(_blurRadius);
    final tw = ((r - l) / scale).round().clamp(1, 4096);
    final th = ((b - t) / scale).round().clamp(1, 4096);

    // 降采样快照区域：纹理越小，单 pass 卷积的采样越密、越省。
    // 缓存键包含快照身份与全部几何参数，静止时不再每帧重建纹理。
    final key = (
      identityHashCode(image),
      l,
      t,
      r,
      b,
      tw,
      th,
      scale,
    );
    if (_texKey != key || _tex == null) {
      final recorder = ui.PictureRecorder();
      final canvas = Canvas(recorder);
      canvas.drawImageRect(
        image,
        Rect.fromLTRB(l, t, r, b),
        Rect.fromLTWH(0, 0, tw.toDouble(), th.toDouble()),
        Paint()
          ..filterQuality = FilterQuality.medium
          // 降采样时先轻糊一次：小图做 sampler 时过滤是线性的，但放大后未平滑
          // 的像素仍会呈现方块；把纹理本身预先柔化，块状消失。
          ..imageFilter = ui.ImageFilter.blur(sigmaX: 1.2, sigmaY: 1.2),
      );
      final next = recorder.endRecording().toImageSync(tw, th);
      _tex?.dispose();
      _tex = next;
      _texKey = key;
    }
    final small = _tex!;

    final (vec, gradOffset) = _gradient.gradient();
    final shader = _shader;
    // uniform 顺序必须与 .frag 声明一致。
    shader
      ..setFloat(0, size.width)
      ..setFloat(1, size.height)
      ..setFloat(2, tw.toDouble())
      ..setFloat(3, th.toDouble())
      // 组件左上角在纹理像素坐标里（可能为负，表示采样区向组件外扩了）。
      ..setFloat(4, (compL - l) / scale)
      ..setFloat(5, (compT - t) / scale)
      ..setFloat(6, _blurRadius)
      ..setFloat(7, vec.dx)
      ..setFloat(8, vec.dy)
      ..setFloat(9, gradOffset)
      ..setFloat(10, _gradient.curve)
      ..setFloat(11, dpr / scale)
      ..setImageSampler(0, small);

    context.canvas.drawRect(
      offset & size,
      Paint()
        ..shader = shader
        ..isAntiAlias = false,
    );

    super.paint(context, offset);
  }
}
