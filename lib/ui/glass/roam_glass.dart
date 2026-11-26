// ignore_for_file: deprecated_member_use

import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';

import 'os4_glass_token.dart';

/// 场景级背景快照。
///
/// 玻璃的三项输入——折射取样、反射取样、暗部染色——都要读"玻璃后面的画面"，
/// 而画面是邻居画的，不是玻璃自己的子树。所以由场景统一录一份：
/// 背景层包在 [RepaintBoundary] 里，一次性 `toImage`，再按 token 的
/// `blurRadius` 做一次引擎级高斯，结果作为纹理喂给着色器。
///
/// 只在 [RoamGlassScene.revision] 变化时重录，静态页面下等于零成本。
class GlassScene extends InheritedWidget {
  const GlassScene({
    super.key,
    required this.backdrop,
    required this.backdropBig,
    required this.textureSize,
    required this.origin,
    this.originOf,
    required super.child,
  });

  /// 已模糊的背景纹理；首帧还没录好时为 null，玻璃会退化成半透明实色。
  final ui.Image? backdrop;

  /// 大半径模糊版本，只用于内层色（官方 blur_texture_2 的对应物）。
  final ui.Image? backdropBig;

  /// 纹理对应的逻辑尺寸（不是像素尺寸）。
  final Size textureSize;

  /// 背景层左上角的全局坐标，用来把组件坐标换算到纹理坐标。
  /// 仅作 [originOf] 缺失时的兜底与 shouldRepaint 比较。
  final Offset origin;

  /// 实时背景层位置回调（桥接层传 `() => source.globalOffset`）。
  /// paint 时调用可与玻璃面 localToGlobal 同帧，避免 origin 滞后一帧。
  final Offset Function()? originOf;

  static GlassScene? maybeOf(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<GlassScene>();

  @override
  bool updateShouldNotify(GlassScene old) =>
      old.backdrop != backdrop ||
      old.backdropBig != backdropBig ||
      old.textureSize != textureSize ||
      old.origin != origin;
}

/// 背景录制宿主。
class RoamGlassScene extends StatefulWidget {
  const RoamGlassScene({
    super.key,
    required this.background,
    required this.child,
    this.revision = 0,
    this.blurSigma = 60,
    this.blurSigmaBig,
    this.pixelRatio = 0.5,
  });

  /// 背景内容，会整体被录成纹理。
  final Widget background;

  /// 前景内容（玻璃都在这一层）。
  final Widget child;

  /// 背景变化时自增，触发重录。
  final Object revision;

  /// 折射 / 反射取样的预模糊强度（σ，逻辑 px）。
  final double blurSigma;

  /// 体积色取样的预模糊强度。缺省取 [blurSigma] 的 3 倍；
  /// token 里 blurBig 与 blurSmall 可以差十几倍，调用方按档位给更准。
  final double? blurSigmaBig;

  /// 录制倍率。玻璃本身还要再糊一次，0.5x 足够且省 3/4 的拷贝量。
  final double pixelRatio;

  @override
  State<RoamGlassScene> createState() => _RoamGlassSceneState();
}

class _RoamGlassSceneState extends State<RoamGlassScene> {
  final GlobalKey _bgKey = GlobalKey();
  ui.Image? _backdrop;
  ui.Image? _backdropBig;
  Size _texSize = Size.zero;
  Offset _origin = Offset.zero;
  bool _capturing = false;

  @override
  void initState() {
    super.initState();
    _schedule();
  }

  @override
  void didUpdateWidget(RoamGlassScene old) {
    super.didUpdateWidget(old);
    if (old.revision != widget.revision ||
        old.blurSigma != widget.blurSigma ||
        old.blurSigmaBig != widget.blurSigmaBig) {
      _schedule();
    }
  }

  void _schedule() {
    WidgetsBinding.instance.addPostFrameCallback((_) => _capture());
  }

  Future<void> _capture() async {
    if (_capturing || !mounted) return;
    _capturing = true;
    try {
      final ctx = _bgKey.currentContext;
      if (ctx == null) return;
      final boundary = ctx.findRenderObject() as RenderRepaintBoundary?;
      if (boundary == null || boundary.size.isEmpty) return;

      final raw = await boundary.toImage(pixelRatio: widget.pixelRatio);
      // 高斯在 0.5x 纹理上做，sigma 同比缩小，放大回逻辑尺寸后观感一致
      final blurred = await _blur(raw, widget.blurSigma);
      // 体积色（uWallpaperCoarse）：token 里 blurBig 与 blurSmall 可差十几倍，
      // 这里交给调用方按档位给；没给就退到 3 倍。
      final blurredBig = await _blur(
        raw,
        widget.blurSigmaBig ?? widget.blurSigma * 3.0,
      );
      raw.dispose();

      if (!mounted) {
        blurred.dispose();
        if (!identical(blurredBig, blurred)) blurredBig.dispose();
        return;
      }
      final old = _backdrop;
      final oldBig = _backdropBig;
      setState(() {
        _backdrop = blurred;
        _backdropBig = blurredBig;
        _texSize = boundary.size;
        _origin = boundary.localToGlobal(Offset.zero);
      });
      // 延迟 250ms 释放旧纹理，消除与栅格线程的竞态。
      if (old != null || oldBig != null) {
        Future.delayed(const Duration(milliseconds: 250), () {
          old?.dispose();
          if (!identical(oldBig, old)) oldBig?.dispose();
        });
      }
    } finally {
      _capturing = false;
    }
  }

  Future<ui.Image> _blur(ui.Image src, double sigma) async {
    if (sigma <= 0.01) return src;

    // σ>24 时降采样 k 倍再模糊，避免 GPU 大高斯核偶发退化。
    final effectiveSigma = sigma * widget.pixelRatio;
    final k = effectiveSigma > 24
        ? (effectiveSigma / 24).ceilToDouble().clamp(2.0, 8.0)
        : 1.0;

    if (k == 1.0) {
      // 小 σ 一步糊。
      final recorder = ui.PictureRecorder();
      final canvas = Canvas(recorder);
      canvas.drawImage(
        src,
        Offset.zero,
        Paint()
          ..imageFilter = ui.ImageFilter.blur(
            sigmaX: effectiveSigma,
            sigmaY: effectiveSigma,
            tileMode: TileMode.clamp,
          ),
      );
      final picture = recorder.endRecording();
      final out = await picture.toImage(src.width, src.height);
      picture.dispose();
      return out;
    }

    // 两步：降采样 → 小 σ 模糊 → 放大。
    final midW = (src.width / k).ceil();
    final midH = (src.height / k).ceil();

    // 降采样。
    final rec1 = ui.PictureRecorder();
    Canvas(rec1).drawImageRect(
      src,
      ui.Rect.fromLTWH(0, 0, src.width.toDouble(), src.height.toDouble()),
      ui.Rect.fromLTWH(0, 0, midW.toDouble(), midH.toDouble()),
      Paint()..filterQuality = FilterQuality.medium,
    );
    final pic1 = rec1.endRecording();
    final mid = await pic1.toImage(midW, midH);
    pic1.dispose();

    // 小 σ 模糊。
    final rec2 = ui.PictureRecorder();
    Canvas(rec2).drawImage(
      mid,
      Offset.zero,
      Paint()
        ..imageFilter = ui.ImageFilter.blur(
          sigmaX: effectiveSigma / k,
          sigmaY: effectiveSigma / k,
          tileMode: TileMode.clamp,
        ),
    );
    final pic2 = rec2.endRecording();
    final blurredMid = await pic2.toImage(midW, midH);
    pic2.dispose();
    mid.dispose();

    // 放大回原尺寸。
    final rec3 = ui.PictureRecorder();
    Canvas(rec3).drawImageRect(
      blurredMid,
      ui.Rect.fromLTWH(0, 0, midW.toDouble(), midH.toDouble()),
      ui.Rect.fromLTWH(0, 0, src.width.toDouble(), src.height.toDouble()),
      Paint()..filterQuality = FilterQuality.medium,
    );
    final pic3 = rec3.endRecording();
    final out = await pic3.toImage(src.width, src.height);
    pic3.dispose();
    blurredMid.dispose();
    return out;
  }

  @override
  void dispose() {
    _backdrop?.dispose();
    _backdropBig?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        RepaintBoundary(key: _bgKey, child: widget.background),
        GlassScene(
          backdrop: _backdrop,
          backdropBig: _backdropBig,
          textureSize: _texSize,
          origin: _origin,
          child: widget.child,
        ),
      ],
    );
  }
}

/// 自绘 OS4 柔光玻璃。
///
/// 与 `flutter_miuix` 的 `MiuixGlass` 是两条独立实现：这里直接消费
/// [Os4GlassToken] 的 34 个原始参数，走 `shaders/roam_glass.frag`。
class RoamGlass extends StatefulWidget {
  const RoamGlass({
    super.key,
    required this.token,
    this.radius = 24,
    this.borderRadius,
    this.child,
    this.fallbackColor,
  });

  final Os4GlassToken token;
  final double radius;

  /// 四角独立圆角；给了就忽略 [radius]。
  /// 工具栏面板这类只有顶角圆的面必须用它——shader 的 `uRadii`
  /// 本来就是四角独立（左上/右上/右下/左下）。
  final BorderRadius? borderRadius;
  final Widget? child;

  /// 纹理未就绪时的底色。
  final Color? fallbackColor;

  @override
  State<RoamGlass> createState() => _RoamGlassState();
}

class _RoamGlassState extends State<RoamGlass> {
  static ui.FragmentProgram? _program;
  static Future<void>? _loading;

  /// 外层滚动容器的位置。滚动只对子树做位移、不触发重绘，
  /// 而玻璃的采样原点是在 paint 里读的——不把滚动当成重绘信号，
  /// 玻璃里的背景就会停在原处，看起来像贴在屏幕上而不是"透"过去。
  ScrollPosition? _scroll;

  static Future<void> _ensureProgram() {
    return _loading ??= _loadProgram();
  }

  static Future<void> _loadProgram() async {
    try {
      _program = await ui.FragmentProgram.fromAsset('shaders/roam_glass.frag');
    } catch (e) {
      // 编译失败不阻塞界面，组件会退回半透明实色
      debugPrint('roam_glass.frag 加载失败: $e');
    }
  }

  @override
  void initState() {
    super.initState();
    _ensureProgram().then((_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Scrollable.maybeOf 在非滚动环境返回 null，此时靠普通重建重绘
    _scroll = Scrollable.maybeOf(context)?.position;
  }

  @override
  Widget build(BuildContext context) {
    final scene = GlassScene.maybeOf(context);
    final backdrop = scene?.backdrop;
    final backdropBig = scene?.backdropBig ?? backdrop;
    final token = widget.token;

    if (_program == null || backdrop == null) {
      return _Fallback(
        radius: widget.radius,
        token: token,
        color: widget.fallbackColor,
        child: widget.child,
      );
    }

    return CustomPaint(
      painter: _GlassPainter(
        program: _program!,
        token: token,
        radii: _radiiOf(context),
        backdrop: backdrop,
        backdropBig: backdropBig,
        textureSize: scene!.textureSize,
        sceneOrigin: scene.origin,
        originOf: scene.originOf,
        context: context,
        repaint: _scroll,
      ),
      child: widget.child,
    );
  }

  /// (左上, 右上, 右下, 左下)，与 shader `uRadii` 同序。
  List<double> _radiiOf(BuildContext context) {
    final br = widget.borderRadius;
    if (br == null)
      return [widget.radius, widget.radius, widget.radius, widget.radius];
    return [br.topLeft.x, br.topRight.x, br.bottomRight.x, br.bottomLeft.x];
  }
}

class _Fallback extends StatelessWidget {
  const _Fallback({
    required this.radius,
    required this.token,
    required this.child,
    this.color,
  });

  final double radius;
  final Os4GlassToken token;
  final Widget? child;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(radius),
        color:
            color ??
            (dark
                ? Colors.white.withValues(alpha: 0.08)
                : Colors.white.withValues(alpha: 0.35)),
      ),
      child: child,
    );
  }
}

/// `GlassToken` 里的长度量以物理像素计（系统按 3x 屏标定），渲染时折回逻辑像素。
const double kTokenLengthScale = 1 / 3;

/// 系统的 `darkerColor`：偏紫的冷黑。亮部被拉向它，是大面板"发乌"的来源。
const Color kDarkerColor = Color.fromARGB(255, 20, 7, 24);

/// 竖直剖面的五阶平滑，用于把「3 物理 px 抗锯齿」换算成法线 z 的阈值。
double _smooth5Vertical(double x) {
  var t = 0.5 + 0.5 * math.sqrt(x.clamp(0.0, 1.0));
  t = t * t * t * (t * (t * 6 - 15) + 10);
  return (t - 0.5) * 2;
}

class _GlassPainter extends CustomPainter {
  _GlassPainter({
    required this.program,
    required this.token,
    required this.radii,
    required this.backdrop,
    required this.backdropBig,
    required this.textureSize,
    required this.sceneOrigin,
    required this.context,
    this.originOf,
    super.repaint,
  });

  final ui.FragmentProgram program;
  final Os4GlassToken token;

  /// (左上, 右上, 右下, 左下)。
  final List<double> radii;
  final ui.Image backdrop;
  final ui.Image? backdropBig;
  final Size textureSize;

  /// 捕获层全局位置（缓存值，仅作 shouldRepaint 比较与 originOf 缺失时兜底）。
  final Offset sceneOrigin;

  /// 实时捕获层位置回调。paint 时调用，与玻璃面 localToGlobal 同帧取值，
  /// 消除「postFrame 更新的 sceneOrigin 滞后一帧」导致的采样错位。
  final Offset Function()? originOf;
  final BuildContext context;

  @override
  void paint(Canvas canvas, Size size) {
    if (size.isEmpty || textureSize.isEmpty) return;

    final shader = program.fragmentShader();

    // 按名绑定：不依赖声明顺序，也不会因 shader 里增删 uniform 而错位。
    final ro = context.findRenderObject() as RenderBox?;
    // 同帧实时取捕获层位置：玻璃面位置与捕获层位置必须来自同一帧，
    // 否则滚动时 origin 差一帧 → 玻璃采样错位。
    final sceneOriginNow = originOf?.call() ?? sceneOrigin;
    final origin =
        (ro?.localToGlobal(Offset.zero) ?? Offset.zero) - sceneOriginNow;
    final maxR = size.shortestSide / 2;

    // ── 几何
    shader.getUniformVec2('uSize').set(size.width, size.height);
    shader.getUniformVec2('uOrigin').set(origin.dx, origin.dy);
    shader
        .getUniformVec2('uTexSize')
        .set(textureSize.width, textureSize.height);
    shader
        .getUniformVec4('uRadii')
        .set(
          radii[0].clamp(0.0, maxR),
          radii[1].clamp(0.0, maxR),
          radii[2].clamp(0.0, maxR),
          radii[3].clamp(0.0, maxR),
        );

    shader.setImageSampler(0, backdrop);
    // sampler 索引按声明顺序：0 = uBackdrop（小模糊），1 = uBackdropBig（大模糊）
    if (backdropBig != null) shader.setImageSampler(1, backdropBig!);

    // ── 光学几何：token 以 3x 物理像素标定，折回逻辑像素
    shader.getUniformFloat('uEdgePx').set(token.edgeWidth * kTokenLengthScale);
    shader.getUniformFloat('uEdgePow').set(token.edgePow);
    shader
        .getUniformFloat('uThicknessPx')
        .set(token.thickness * kTokenLengthScale);
    shader
        .getUniformFloat('uReflectOffsetPx')
        .set(token.reflectOffset * kTokenLengthScale);
    shader.getUniformFloat('uIOR').set(token.ior);
    shader.getUniformFloat('uReflStrength').set(token.reflectStrength);
    shader.getUniformFloat('uReflLighten').set(token.reflectLighten);
    shader.getUniformFloat('uInnerBottom').set(token.innerBottom);
    shader.getUniformFloat('uLightFalloff').set(1.0);

    // ── 方向光（OS4 标定）
    //
    // token 里解析出的 lightDir 在 z=0 的档位（如 Common_Small_Normal 的
    // [0.6, -1, 0]）会让光打在**四个角和所有边**上——两盏对向灯各照亮一对
    // 对角，退化成整圈描边，正是真机没有的效果。参考实现（softglass 的
    // GlassLightDirection）给的是 (-0.42, 0.74, -1.15)：z 分量强、y 为正，
    // 配合 processLighting 里的 y 翻转，光从上方偏左打来，上边/左上角最亮、
    // 右边/左下角几乎不亮，与真机"水平边有亮线、垂直边没有"一致。
    shader.getUniformVec3('uLightDir').set(-0.42, 0.74, -1.15);
    const angleRange = 1.0;
    final cosA = math.cos(angleRange * math.pi * 0.5);
    shader
        .getUniformFloat('uAngleK')
        .set(0.5 / math.sqrt(math.max(1.0 - cosA, 1e-6)));
    // 强度按本管线的倒角几何标定：edgeWidth=14 物理 px、edgePow=2，
    // 倒角带只有参考实现（edgeWidth=60、edgePow=4）的 1/4，法线在带内转得快，
    // 光集中在最外 1~2px，强度要相应抬高才能把峰值顶到真机的 0.66。
    // v2：真机反馈打光过强，9.0→4.6（shader 内 hsvv 也由 2.0 收到 1.1），
    // 且打光色改为环境光（bigCol 归一化），不再纯白。
    shader.getUniformFloat('uLightIntensity').set(4.6);
    shader.getUniformFloat('uLightOpposite').set(0.45);
    // 3 物理 px 的抗锯齿换算到法线 z：用原始物理量比值，与 /3 折算无关
    shader
        .getUniformFloat('uNmlZAAThreshold')
        .set(_smooth5Vertical(3.0 / math.max(token.edgeWidth, 1.0)));

    // ── 调色
    shader.getUniformFloat('uDarker').set(token.darker);
    shader
        .getUniformVec3('uDarkerColor')
        .set(kDarkerColor.r, kDarkerColor.g, kDarkerColor.b);
    shader
        .getUniformVec2('uDarkerRange')
        .set(token.darkerStart, token.darkerEnd);
    final lc = token.curve;
    shader
        .getUniformVec4('uLuminance')
        .set(
          lc.isNotEmpty ? lc[0] : 0.0,
          lc.length > 1 ? lc[1] : 0.0,
          lc.length > 2 ? lc[2] : 0.0,
          lc.length > 3 ? lc[3] : 1.0,
        );
    shader.getUniformFloat('uLuminanceAmount').set(token.amount);
    shader.getUniformFloat('uSaturation').set(1.0); // 不调整饱和度，保持原图观感
    shader.getUniformFloat('uBrightness').set(token.brightness);
    shader.getUniformFloat('uBgSat').set(1.0); // 背景也不调饱和
    shader.getUniformFloat('uBgBri').set(token.bgBrightness);
    shader.getUniformFloat('uInnerWhite').set(token.colorWhite);
    shader.getUniformFloat('uInnerMix').set(token.colorMix);
    shader.getUniformFloat('uBurn').set(token.burn);
    shader.getUniformFloat('uColorPow').set(token.colorPow);
    shader.getUniformFloat('uAlpha').set(token.alpha);
    shader.getUniformFloat('uUnshade').set(token.unShade);

    // 染色：tint 的 alpha 与 tintStrength 相乘得到实际混合权重
    shader
        .getUniformVec4('uTint')
        .set(
          token.tint.r,
          token.tint.g,
          token.tint.b,
          (token.tint.a * token.tintStrength).clamp(0.0, 1.0),
        );

    canvas.drawRect(Offset.zero & size, Paint()..shader = shader);
    shader.dispose();
  }

  @override
  bool shouldRepaint(_GlassPainter old) =>
      old.token != token ||
      !listEquals(old.radii, radii) ||
      old.backdrop != backdrop ||
      old.backdropBig != backdropBig ||
      old.textureSize != textureSize ||
      old.sceneOrigin != sceneOrigin;
}
