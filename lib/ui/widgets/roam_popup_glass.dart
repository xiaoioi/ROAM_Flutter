// ignore_for_file: deprecated_member_use

import 'package:flutter/material.dart';
import 'package:flutter_miuix/miuix.dart';

import '../../theme/roam_theme.dart';
import 'glass_controls.dart';

/// 弹层（底部抽屉 / 对话框）统一使用的玻璃表面。
///
/// 标准态不用 `MiuixGlassPanel` 的折射管线，而是把库的两件现成东西拼在一起：
///  - 模糊本体：库的纹理模糊 [MiuixTextureBlur]，从页面快照整块高斯；
///  - 色调：库的 `MiuixGlassMaterials.dialogGlass(dark)` 三层色，
///    原样转成 [MiuixTextureBlur] 的 [BlurColors]；描边用库的
///    `MiuixGlassStrokes.forTheme(dark)`。
///
/// 为什么不用 `GlassBottomSheet` 的官方表面函数：它内部走 `MiuixGlassPanel` 的
/// 折射 shader，只在面板边缘做采样/拉伸，中间区域接近原图再叠色调，真机上
/// 看起来就是「只有边缘一圈糊、中间实色」——也就是「局部模糊」。
/// [MiuixTextureBlur] 是对整个面板矩形做一次高斯，整块均匀糊。
///
/// [backdrop] 由调用方在**打开弹层之前**从 [RoamBackdropScope] 取（弹层自己的
/// context 读不到页面级采样器）。没有快照时退回不透明兜底色。
///
/// 三态（跟随「材质显示效果」/「高斯模糊效果」）：
///  - 材质关闭 → 纯色，不模糊；
///  - 性能优先 → 半透明磨砂 + 轮廓光（白边/浅黑边按明暗取）；
///  - 标准     → 整块纹理模糊 + dialogGlass 色调 + 轮廓光。
class RoamPopupGlass extends StatelessWidget {
  const RoamPopupGlass({
    super.key,
    required this.child,
    this.backdrop,
    this.isDialog = false,
    this.forceDark,
  });

  final Widget child;

  /// 页面级背景采样源；为空时用不透明兜底色。
  final MiuixBackdrop? backdrop;

  /// true：对话框（四角 28）；false：底部抽屉（只有上方两角）。
  final bool isDialog;

  /// 强制深色（首页壁纸上的抽屉）。
  final bool? forceDark;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: GlassRuntime.repaint,
      builder: (context, _) => _build(context),
    );
  }

  Widget _build(BuildContext context) {
    final dark =
        forceDark ??
        (MiuixTheme.of(context).colors.background.computeLuminance() < .5);
    final mode = GlassRuntime.mode;

    // 材质关闭：纯色背景，任何模糊都不跑。
    if (mode == RoamGlassMode.off) {
      return ClipRRect(
        borderRadius: _shapeRadius,
        child: ColoredBox(
          color: dark ? RoamColors.cardDark : RoamColors.cardLight,
          child: child,
        ),
      );
    }

    // 性能优先：简单模糊——半透明磨砂底，轮廓光描一圈对比色细边。
    if (mode == RoamGlassMode.performance) {
      return Container(
        decoration: BoxDecoration(
          borderRadius: _shapeRadius,
          color: roamFrostedFill(dark),
          border: GlassRuntime.rimLight.value
              ? Border.all(color: roamRimColor(dark), width: 1)
              : null,
        ),
        clipBehavior: Clip.antiAlias,
        child: child,
      );
    }

    // 标准：整块纹理模糊 + dialogGlass 色调 + 轮廓光。
    final material = MiuixGlassMaterials.dialogGlass(dark);
    final blur =
        (material.blurRadius * GlassRuntime.blurScale.value)
            .clamp(0.0, MiuixBlurDefaults.maxBlurRadius);
    final fallback = dark ? RoamColors.cardDark : RoamColors.cardLight;
    final source = backdrop;
    final ready = source != null && source.hasContent;
    final rim = GlassRuntime.rimLight.value;

    return ClipRRect(
      borderRadius: _shapeRadius,
      child: Stack(
        children: [
          // 底层：整块模糊 + 材质色调（不是透明度/遮罩，是库的色层）。
          Positioned.fill(
            child: ready
                ? MiuixTextureBlur(
                    backdrop: source,
                    blurRadius: blur,
                    colors: _blurColors(material, dark),
                  )
                : ColoredBox(color: fallback),
          ),
          // 内容决定面板大小。
          if (!ready) ColoredBox(color: fallback, child: child) else child,
          // 轮廓光：库的 stroke 色（上亮下隐），画在圆角内侧。
          if (rim)
            Positioned.fill(
              child: IgnorePointer(
                child: CustomPaint(
                  painter: _GlassEdgePainter(
                    radius: _shapeRadius,
                    stroke: MiuixGlassStrokes.forTheme(dark),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  /// `MiuixGlassMaterial` 的三层色 → [MiuixTextureBlur] 的 [BlurColors]。
  ///
  /// 扩展混合模式（plusDarker / plusLighter，>=100）在纹理模糊里没有等价实现，
  /// 用库自己给的 `fallback`（multiply / plus）代替，保证「模糊后调色」的顺序
  /// 和官方材质一致。
  BlurColors _blurColors(MiuixGlassMaterial material, bool dark) {
    // 深色材质原本按「折射玻璃」调的：panel 会在边缘叠 alpha/折射增强，所以
    // 中层压得很重。整块纹理模糊没有那层增强，原样照搬会糊成一块深灰，
    // 背后内容几乎透不出来——这里把后两层压暗的 alpha 收一档。
    final scale = dark ? 0.72 : 1.0;
    return BlurColors(
      blendColors: [
        for (final layer in material.layers)
          BlendColorEntry(
            layer.color.withValues(alpha: layer.color.a * scale),
            BlurBlendMode(layer.mode.fallback.index),
          ),
      ],
    );
  }

  BorderRadius get _shapeRadius => isDialog
      ? BorderRadius.circular(28)
      : BorderRadius.vertical(
          top: Radius.circular(MiuixBottomSheetDefaults.cornerRadius),
        );
}

/// 圆角描边：一层全周底色 + 一条从顶部往下淡出的高光，对应 miuix 玻璃的
/// `MiuixGlassStroke`（`color` / `primary` / `secondary` 三档光）。
class _GlassEdgePainter extends CustomPainter {
  const _GlassEdgePainter({required this.radius, required this.stroke});

  final BorderRadius radius;
  final MiuixGlassStroke stroke;

  @override
  void paint(Canvas canvas, Size size) {
    final rrect = radius
        .toRRect(Offset.zero & size)
        .deflate(stroke.width / 2);

    canvas.drawRRect(
      rrect,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = stroke.width
        ..color = stroke.color,
    );

    canvas.drawRRect(
      rrect,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = stroke.width
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [stroke.primary.color, stroke.primary.color.withValues(alpha: 0)],
          stops: const [0, .7],
        ).createShader(Offset.zero & size),
    );
  }

  @override
  bool shouldRepaint(covariant _GlassEdgePainter oldDelegate) =>
      oldDelegate.radius != radius || oldDelegate.stroke != stroke;
}
