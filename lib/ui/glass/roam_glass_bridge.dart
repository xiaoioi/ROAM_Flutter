// ignore_for_file: deprecated_member_use

import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_miuix/miuix.dart';

import 'os4_glass_token.dart';
import 'roam_glass.dart';

/// 把 flutter_miuix 的 [MiuixLayerBackdrop]（每帧原始快照）桥接成
/// 自绘柔光玻璃 [RoamGlass] 消费的 [GlassScene]（预模糊双纹理）。
///
/// 两条玻璃管线的输入不一样：
///  - `MiuixGlass` 直接在 shader 里对原始快照做多 tap 模糊；
///  - `roam_glass.frag` 消费**预模糊好的**两张纹理（小模糊走折射/反射
///    采样，大模糊走体积色），即 [GlassScene.backdrop] /
///    [GlassScene.backdropBig]。
///
/// 桥接层补的就是这一步：监听采样器更新，把 `snapshot` 用
/// [ui.ImageFilter] 高斯成两张纹理，按 [GlassScene] 的约定连同
/// 逻辑尺寸、全局原点一起提供给子树。模糊强度沿用玻璃实验室对真机
/// 的标定（`glass_lab_main.dart` 的 σ 映射）。
///
/// 同一个 [MiuixLayerBackdrop] 上的多个玻璃面共享一份模糊结果
/// （引用计数缓存），一张页面上的六七个卡片只糊一次。
class RoamGlassSceneBridge extends StatefulWidget {
  const RoamGlassSceneBridge({
    super.key,
    required this.backdrop,
    required this.child,
    this.token = Os4GlassToken.commonSmallRegular,
    this.blurScale = 1.0,
  });

  /// 采样源，通常是页面级 [MiuixLayerBackdropCapture] 持有的那个。
  final MiuixLayerBackdrop backdrop;

  /// 决定模糊强度的档位（只读 `blurSmall`/`blurBig` 两项）。
  final Os4GlassToken token;

  /// 模糊度倍率（0.5~2.0），1.0 为标准强度。
  final double blurScale;

  final Widget child;

  /// 与玻璃实验室一致：原生把「模糊半径」送进高斯，
  /// σ = r × 0.57735 + 0.5，再除以 3 折算成逻辑像素，最后按
  /// 实验室的上下限夹取（下限就是真机对齐时的观感底线）。
  ///
  /// [scale] 是用户调节的模糊度倍率，**作用在标定后的 σ 上**。
  /// 早先是先乘 scale 再 clamp(4,60)——而 commonSmallRegular 的原始
  /// σ 只有 1.7，50%~200% 全被夹到 4.0，滑杆对小纹理完全无效。
  /// 现在 scale=1 与旧观感逐像素一致，往上往下都能真的变糊/变清。
  static double smallSigmaOf(Os4GlassToken token, {double scale = 1.0}) {
    final base = ((token.blurSmall * 0.57735 + 0.5) / 3.0).clamp(4.0, 60.0);
    return (base * scale).clamp(1.5, 120.0);
  }

  static double bigSigmaOf(Os4GlassToken token, {double scale = 1.0}) {
    final base = ((token.blurBig * 0.57735 + 0.5) / 3.0).clamp(20.0, 180.0);
    return (base * scale).clamp(10.0, 320.0);
  }

  @override
  State<RoamGlassSceneBridge> createState() => _RoamGlassSceneBridgeState();
}

class _RoamGlassSceneBridgeState extends State<RoamGlassSceneBridge> {
  late _SharedScene _scene;

  @override
  void initState() {
    super.initState();
    _scene = _SharedScene.acquire(
      widget.backdrop,
      sigmaSmall: RoamGlassSceneBridge.smallSigmaOf(
        widget.token,
        scale: widget.blurScale,
      ),
      sigmaBig: RoamGlassSceneBridge.bigSigmaOf(
        widget.token,
        scale: widget.blurScale,
      ),
    );
    _scene.addListener(_onChange);
  }

  @override
  void didUpdateWidget(RoamGlassSceneBridge old) {
    super.didUpdateWidget(old);
    final sigmaSmall = RoamGlassSceneBridge.smallSigmaOf(
      widget.token,
      scale: widget.blurScale,
    );
    final sigmaBig = RoamGlassSceneBridge.bigSigmaOf(
      widget.token,
      scale: widget.blurScale,
    );
    if (old.backdrop != widget.backdrop) {
      _scene.removeListener(_onChange);
      _SharedScene.release(_scene);
      _scene = _SharedScene.acquire(
        widget.backdrop,
        sigmaSmall: sigmaSmall,
        sigmaBig: sigmaBig,
      );
      _scene.addListener(_onChange);
      return;
    }
    // 采样源没变、只是模糊度变了：就地更新共享 scene 的 sigma 并重糊。
    // 以前这里是 release+acquire，而池子只按采样源做 key——
    // 同一页多个玻璃面依次重建时，后一个的 release 会把前一个刚建立的
    // 新 scene 顶掉，引用计数变负、scene 被 dispose 两次，
    // 桥接层就会绑到已销毁的 scene 上：纹理为空、玻璃整块消失。
    if (_scene.updateSigmas(sigmaSmall, sigmaBig)) {
      _onChange();
    }
  }

  @override
  void dispose() {
    _scene.removeListener(_onChange);
    _SharedScene.release(_scene);
    super.dispose();
  }

  void _onChange() {
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    return GlassScene(
      backdrop: _scene.small,
      backdropBig: _scene.big,
      textureSize: _scene.textureSize,
      origin: _scene.origin,
      // 实时位置回调：paint 时与玻璃面 localToGlobal 同帧取值，
      // 消除 postFrame 更新 origin 滞后一帧导致的采样错位。
      originOf: () => widget.backdrop.globalOffset ?? Offset.zero,
      child: widget.child,
    );
  }
}

/// 一个采样源对应一份模糊纹理，多个桥接共享。
class _SharedScene extends ChangeNotifier {
  _SharedScene._(this.source, this.sigmaSmall, this.sigmaBig) {
    source.addListener(_onSource);
    _reblur();
  }

  static final Map<MiuixLayerBackdrop, _SharedScene> _pool = {};

  static _SharedScene acquire(
    MiuixLayerBackdrop source, {
    required double sigmaSmall,
    required double sigmaBig,
  }) {
    final existing = _pool[source];
    if (existing != null) {
      existing._refCount += 1;
      // 同一采样源只保留一份模糊结果；新请求的强度就地更新，
      // 否则「模糊度调节」会被旧 scene 的 sigma 吃掉（滑杆无效）。
      existing.updateSigmas(sigmaSmall, sigmaBig);
      return existing;
    }
    final scene = _SharedScene._(source, sigmaSmall, sigmaBig);
    _pool[source] = scene;
    return scene;
  }

  static void release(_SharedScene scene) {
    if (scene._refCount <= 0) return;
    scene._refCount -= 1;
    if (scene._refCount > 0) return;
    // 只摘掉自己这一份：池子按采样源做 key，若不比对实例，
    // 可能把后来者新建的 scene 顶掉。
    if (identical(_pool[scene.source], scene)) {
      _pool.remove(scene.source);
    }
    scene._disposed = true;
    scene._disposeTextures();
    scene.source.removeListener(scene._onSource);
    scene.dispose();
  }

  final MiuixLayerBackdrop source;

  /// 当前模糊强度，随「模糊度调节」滑杆变化。
  double sigmaSmall;
  double sigmaBig;
  int _refCount = 1;
  bool _disposed = false;

  ui.Image? small;
  ui.Image? big;
  Size textureSize = Size.zero;
  Offset origin = Offset.zero;

  /// 采样器每帧都会通知（捕获层逐帧 toImageSync），玻璃的预模糊纹理
  /// 没必要 60fps 重做——夹到 ~25fps，模糊本身会抹掉时间精度。
  DateTime _lastBlur = DateTime.fromMillisecondsSinceEpoch(0);
  static const _minInterval = Duration(milliseconds: 40);

  /// 快照还没就绪（首帧、路由返回、捕获层刚挂载）时的重试计数。
  int _retries = 0;
  bool _retryScheduled = false;

  /// 更新模糊强度；有变化就重糊并返回 true。
  bool updateSigmas(double nextSmall, double nextBig) {
    if ((sigmaSmall - nextSmall).abs() < 0.01 &&
        (sigmaBig - nextBig).abs() < 0.01) {
      return false;
    }
    sigmaSmall = nextSmall;
    sigmaBig = nextBig;
    _scheduleReblur();
    return true;
  }

  /// 一帧内多次调参（拖滑杆）只重糊一次。
  void _scheduleReblur() {
    if (_disposed || _retryScheduled) return;
    _retryScheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _retryScheduled = false;
      if (_disposed) return;
      _reblur();
    });
  }

  void _onSource() {
    if (_disposed) return;
    // origin（捕获层全局位置）必须每帧实时更新，否则快速滚动时
    // 玻璃 UV 映射会滞后数帧，表现为采样错位。
    // 纹理模糊仍按 _minInterval 节流，性能与正确性兼顾。
    final newOrigin = source.globalOffset ?? Offset.zero;
    if (newOrigin != origin) {
      origin = newOrigin;
      notifyListeners();
    }
    final now = DateTime.now();
    if (now.difference(_lastBlur) < _minInterval) return;
    _reblur();
  }

  void _reblur() {
    if (_disposed) return;
    _lastBlur = DateTime.now();
    final img = source.snapshot;
    final pr = source.pixelRatio;
    if (img == null || pr <= 0) {
      // 快照暂时不可用（首帧 / 从二级页返回 / 捕获层重绘的下一帧）。
      // 这里**不销毁已有纹理**：旧纹理虽然旧，也好过整块玻璃变透明。
      // 只有在从没拿到过快照时才安排重试。
      if (_retries < 8) {
        _retries += 1;
        _scheduleReblur();
      }
      return;
    }
    final w = img.width / pr;
    final h = img.height / pr;
    if (w <= 0 || h <= 0) {
      _scheduleReblur();
      return;
    }
    _retries = 0;

    final src = ui.Rect.fromLTWH(
      0,
      0,
      img.width.toDouble(),
      img.height.toDouble(),
    );
    // 模糊在逻辑像素空间做：把快照缩到逻辑尺寸再高斯，σ 直接就是
    // 逻辑像素。输出纹理固定 1x 逻辑密度——玻璃本身还会再采样一次，
    // 高斯之后 1x 与 3x 肉眼无差（捕获层自己的注释同理）。
    final dst = ui.Rect.fromLTWH(0, 0, w, h);
    final oldSmall = small;
    final oldBig = big;

    small = _blurOnce(img, src, dst, w, h, sigmaSmall);
    big = _blurOnce(img, src, dst, w, h, sigmaBig);
    textureSize = Size(w, h);
    // 与 RoamGlassScene 一致：原点在录制时取全局坐标。
    origin = source.globalOffset ?? Offset.zero;
    notifyListeners();

    // 旧纹理延迟 250ms 再放：此刻还有 painter 拿着旧引用，
    // 且 GPU 可能仍在用旧纹理合成当前帧。
    _delayedDispose(oldSmall, oldBig);
  }

  /// 延迟释放纹理，避免与栅格线程竞态。
  static void _delayedDispose(ui.Image? a, ui.Image? b) {
    if (a == null && b == null) return;
    Future.delayed(const Duration(milliseconds: 250), () {
      a?.dispose();
      if (!identical(b, a)) b?.dispose();
    });
  }

  /// 两步高斯：大 σ 先降采样再模糊，避免 GPU 大高斯核偶发退化
  /// （真机上表现为白雾/HF 反高）。
  ui.Image _blurOnce(
    ui.Image img,
    ui.Rect src,
    ui.Rect dst,
    double w,
    double h,
    double sigma,
  ) {
    // σ>24 时降采样 k 倍，用 σ/k 糊再放大，等效大高斯但更稳。
    final k = sigma > 24 ? (sigma / 24).ceilToDouble().clamp(2.0, 8.0) : 1.0;
    final outW = w.ceil();
    final outH = h.ceil();

    if (k == 1.0) {
      // 小 σ 直接一步糊。
      final recorder = ui.PictureRecorder();
      final canvas = Canvas(recorder);
      canvas.drawImageRect(
        img,
        src,
        dst,
        Paint()
          ..filterQuality = FilterQuality.medium
          ..imageFilter = ui.ImageFilter.blur(
            sigmaX: sigma,
            sigmaY: sigma,
            tileMode: ui.TileMode.clamp,
          ),
      );
      final picture = recorder.endRecording();
      final out = picture.toImageSync(outW, outH);
      picture.dispose();
      return out;
    }

    // 两步：先降采样到 1/k，再 σ/k 模糊，最后放大回来。
    final midW = (w / k).ceil();
    final midH = (h / k).ceil();
    final midDst = ui.Rect.fromLTWH(0, 0, midW.toDouble(), midH.toDouble());

    // 第一步：降采样。
    final rec1 = ui.PictureRecorder();
    final cv1 = Canvas(rec1);
    cv1.drawImageRect(
      img,
      src,
      midDst,
      Paint()..filterQuality = FilterQuality.medium,
    );
    final pic1 = rec1.endRecording();
    final mid = pic1.toImageSync(midW, midH);
    pic1.dispose();

    // 第二步：小 σ 模糊。
    final rec2 = ui.PictureRecorder();
    final cv2 = Canvas(rec2);
    cv2.drawImageRect(
      mid,
      ui.Rect.fromLTWH(0, 0, midW.toDouble(), midH.toDouble()),
      midDst,
      Paint()
        ..filterQuality = FilterQuality.medium
        ..imageFilter = ui.ImageFilter.blur(
          sigmaX: sigma / k,
          sigmaY: sigma / k,
          tileMode: ui.TileMode.clamp,
        ),
    );
    final pic2 = rec2.endRecording();
    final blurredMid = pic2.toImageSync(midW, midH);
    pic2.dispose();
    mid.dispose();

    // 第三步：放大回目标尺寸。
    final rec3 = ui.PictureRecorder();
    final cv3 = Canvas(rec3);
    cv3.drawImageRect(
      blurredMid,
      ui.Rect.fromLTWH(0, 0, midW.toDouble(), midH.toDouble()),
      dst,
      Paint()..filterQuality = FilterQuality.medium,
    );
    final pic3 = rec3.endRecording();
    final out = pic3.toImageSync(outW, outH);
    pic3.dispose();
    blurredMid.dispose();
    return out;
  }

  void _disposeTextures() {
    final oldSmall = small;
    final oldBig = big;
    small = null;
    big = null;
    textureSize = Size.zero;
    _delayedDispose(oldSmall, oldBig);
  }
}
