// ignore_for_file: deprecated_member_use

import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_miuix/miuix.dart';

/// 渐变方向与区间。对应 `miuix-blur` 的 `ProgressiveBlur`。
///
/// 沿 [angle]（角度，从 +X 轴顺时针）投影，模糊在 [startFraction] 处为满强度，
/// 在 [endFraction] 处降为零；[curve] 是半径的幂次衰减曲线。
///
/// 说明：`flutter_miuix` 1.4.0 只移植了 `textureBlur`（[MiuixTextureBlur]），
/// 还没有 `Modifier.progressiveTextureBlur`。这里按同一份 API 语义、
/// 用库自己的 [MiuixTextureBlur] 叠出多档模糊层补位，不引第三方实现。
@immutable
class ProgressiveBlur {
  const ProgressiveBlur({
    this.angle = 90,
    this.startFraction = 0,
    this.endFraction = 1,
    this.curve = 1,
  }) : assert(curve > 0, 'curve 必须为正数'),
       assert(startFraction != endFraction, 'start/end 不能相等');

  /// 渐变方向（度，从 +X 轴顺时针）：0 左→右淡出，90 上→下，180 右→左，270 下→上。
  final double angle;

  /// 满强度位置，[0,1]。
  final double startFraction;

  /// 模糊降为零的位置，[0,1]。
  final double endFraction;

  /// 幂次衰减曲线：<1 半径变化集中在强端，>1 集中在清晰端。
  final double curve;

  /// 顶部最强（上糊下清）。
  static const top = ProgressiveBlur();

  /// 底部最强（下糊上清）。
  static const bottom = ProgressiveBlur(angle: 270);

  /// 左侧最强。
  static const left = ProgressiveBlur(angle: 0);

  /// 右侧最强。
  static const right = ProgressiveBlur(angle: 180);

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

  @override
  bool operator ==(Object other) =>
      other is ProgressiveBlur &&
      other.angle == angle &&
      other.startFraction == startFraction &&
      other.endFraction == endFraction &&
      other.curve == curve;

  @override
  int get hashCode => Object.hash(angle, startFraction, endFraction, curve);

  /// 单位方向向量（Flutter 画布 y 轴向下，与 Compose 一致）。
  Offset get direction {
    final r = angle * math.pi / 180;
    return Offset(math.cos(r), math.sin(r));
  }

  /// 归一化位置 [t] 处的「半径比例」：1 = 满强度，0 = 清晰。
  double ratioAt(double t) {
    final span = endFraction - startFraction;
    final u = ((endFraction - t) / span).clamp(0.0, 1.0);
    return math.pow(u, curve).toDouble();
  }

  /// 半径比例为 [ratio] 的点在 [t] 轴上的位置。
  double tAt(double ratio) =>
      endFraction -
      (endFraction - startFraction) *
          math.pow(ratio.clamp(0.0, 1.0), 1 / curve).toDouble();
}

/// 渐进（渐变）模糊：模糊强度沿 [gradient] 方向从满强度连续过渡到零，
/// 清晰端保持全分辨率。对应 `miuix-blur` 的 `Modifier.progressiveTextureBlur`。
///
/// 实现方式是把 [levels] 档不同半径的 [MiuixTextureBlur] 叠起来，每档用一条
/// 沿渐变方向的三角权重遮罩（`dstIn`）只保留自己那段强度，相邻两档交叉淡化，
/// 视觉上就是一整条连续的渐变模糊带。清晰端是第 0 档（半径 0），画的是原图，
/// 所以和周围内容无缝衔接、不会出现「渐变带边缘一条硬边」。
///
/// 只适合栏 / 边缘过渡带这类窄条，别铺满整屏（每档都是一次全分辨率绘制）。
class MiuixProgressiveTextureBlur extends StatelessWidget {
  const MiuixProgressiveTextureBlur({
    super.key,
    required this.backdrop,
    this.shape,
    this.blurRadius = 20,
    this.levels = 4,
    this.gradient = ProgressiveBlur.top,
    this.colors = const BlurColors(),
    this.enabled = true,
    this.child,
  }) : assert(levels >= 1);

  final MiuixBackdrop backdrop;
  final ShapeBorder? shape;

  /// 满强度处的模糊半径（dp）。
  final double blurRadius;

  /// 模糊档数，越多过渡越平顺、越费 GPU。4 档在 80dp 半径下已经看不出台阶。
  final int levels;

  final ProgressiveBlur gradient;
  final BlurColors colors;

  /// false 时跳过模糊、直接画 [child]。
  final bool enabled;

  final Widget? child;

  @override
  Widget build(BuildContext context) {
    final content = child ?? const SizedBox.expand();
    if (!enabled || blurRadius <= 0) return content;
    return Stack(
      fit: StackFit.passthrough,
      children: [
        Positioned.fill(
          child: _BlurLayers(
            backdrop: backdrop,
            blurRadius: blurRadius,
            levels: levels,
            gradient: gradient,
            colors: colors,
            shape: shape,
          ),
        ),
        ?child,
      ],
    );
  }
}

/// 等快照就绪后再挂模糊层：首帧 `backdrop.snapshot` 为空时
/// [MiuixTextureBlur] 什么都画不出来，会先闪一下空白。
class _BlurLayers extends StatefulWidget {
  const _BlurLayers({
    required this.backdrop,
    required this.blurRadius,
    required this.levels,
    required this.gradient,
    required this.colors,
    this.shape,
  });

  final MiuixBackdrop backdrop;
  final double blurRadius;
  final int levels;
  final ProgressiveBlur gradient;
  final BlurColors colors;
  final ShapeBorder? shape;

  @override
  State<_BlurLayers> createState() => _BlurLayersState();
}

class _BlurLayersState extends State<_BlurLayers> {
  late bool _ready = widget.backdrop.hasContent;

  @override
  void initState() {
    super.initState();
    widget.backdrop.addListener(_onBackdrop);
  }

  @override
  void didUpdateWidget(_BlurLayers oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!identical(oldWidget.backdrop, widget.backdrop)) {
      oldWidget.backdrop.removeListener(_onBackdrop);
      widget.backdrop.addListener(_onBackdrop);
      _ready = widget.backdrop.hasContent;
    }
  }

  @override
  void dispose() {
    widget.backdrop.removeListener(_onBackdrop);
    super.dispose();
  }

  void _onBackdrop() {
    final ready = widget.backdrop.hasContent;
    if (ready != _ready) setState(() => _ready = ready);
  }

  @override
  Widget build(BuildContext context) {
    if (!_ready) return const SizedBox.shrink();
    final layers = <Widget>[];
    for (var i = 0; i < widget.levels; i++) {
      final ratio = widget.levels == 1 ? 1.0 : i / (widget.levels - 1);
      final mask = _maskStops(widget.gradient, ratio, widget.levels);
      layers.add(
        Positioned.fill(
          child: ShaderMask(
            blendMode: BlendMode.dstIn,
            shaderCallback: (bounds) =>
                _maskGradient(widget.gradient, mask).createShader(bounds),
            // 模糊本体完全交给库的 [MiuixTextureBlur]（采样快照 → 高斯 → 画回
            // 原位置），它自己画位图，不受 ShaderMask 的 saveLayer 影响。
            child: MiuixTextureBlur(
              backdrop: widget.backdrop,
              blurRadius: widget.blurRadius * ratio,
              colors: widget.colors,
              child: const SizedBox.expand(),
            ),
          ),
        ),
      );
    }
    final stack = Stack(fit: StackFit.expand, children: layers);
    final shape = widget.shape;
    if (shape == null) return stack;
    return ClipPath(
      clipper: ShapeBorderClipper(shape: shape),
      child: stack,
    );
  }
}

/// 第 [ratio] 档的三角权重遮罩：在它自己的强度位置为 1，到相邻档位线性降到 0。
({List<double> stops, List<double> alphas}) _maskStops(
  ProgressiveBlur g,
  double ratio,
  int levels,
) {
  final n = levels;
  if (n == 1) {
    return (stops: const [0.0, 1.0], alphas: const [1.0, 1.0]);
  }
  // 档位节点在 t 轴上的位置（ratio 0 → t=end，ratio 1 → t=start）。
  double tOf(int i) => g.tAt(i / (n - 1));
  final self = g.tAt(ratio);
  final idx = (ratio * (n - 1)).round();
  final lo = idx < n - 1 ? tOf(idx + 1) : 0.0; // 更靠近模糊端
  final hi = idx > 0 ? tOf(idx - 1) : 1.0; // 更靠近清晰端

  final stops = <double>[];
  final alphas = <double>[];
  void add(double t, double a) {
    final v = t.clamp(0.0, 1.0);
    if (stops.isNotEmpty && (v - stops.last).abs() < 1e-4) {
      // 合并重合节点，取较大的 alpha。
      if (a > alphas.last) alphas[alphas.length - 1] = a;
      return;
    }
    stops.add(v);
    alphas.add(a);
  }

  add(0, 0);
  add(lo, 0);
  add(self, 1);
  add(hi, 0);
  add(1, 0);
  return (stops: stops, alphas: alphas);
}

/// 沿 [g] 方向铺的白色 alpha 遮罩。
LinearGradient _maskGradient(
  ProgressiveBlur g,
  ({List<double> stops, List<double> alphas}) mask,
) {
  final d = g.direction;
  return LinearGradient(
    begin: Alignment(-d.dx, -d.dy),
    end: Alignment(d.dx, d.dy),
    colors: [for (final a in mask.alphas) Color.fromRGBO(255, 255, 255, a)],
    stops: mask.stops,
  );
}
