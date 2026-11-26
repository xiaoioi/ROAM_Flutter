// ignore_for_file: deprecated_member_use

import 'package:flutter/material.dart';
import 'package:flutter_miuix/miuix.dart';

import 'glass_controls.dart';

/// 内容边缘的渐进模糊（顶/底），走 miuix 的 **progressive blur**。
///
/// 实现与 `MiuixGlassTopAppBar` 的顶栏模糊带完全同一套：
///
///  - 采样源是页面级 [MiuixBackdrop]（[MiuixLayerBackdropCapture] 录的 1x 快照）；
///  - 模糊层用 [MiuixGlassPanel] + `MiuixGlassTopAppBarDefaults.bandMaterial`
///    （`puredThinGlass` 换上 [MiuixGlassTopAppBarDefaults.progressiveBlurRadius]
///    的半径），和顶栏那层是同一份缓存实例，不逐帧新建材质；
///  - 淡出由 `MiuixGlassTopAppBarDefaults.bandBlurMask()` 这条官方遮罩完成，
///    模糊在带子下缘连续消融，不会出现分带的硬边，也不需要横切多条
///    `BackdropFilter`。
///
/// 底边只是把同一条遮罩翻过来（下糊上清）。
class RoamEdgeFade extends StatelessWidget {
  const RoamEdgeFade({
    super.key,
    required this.backdrop,
    this.fromTop = true,
    this.blurRadius = MiuixGlassTopAppBarDefaults.progressiveBlurRadius,
    this.strength = 1,
  });

  /// 页面级背景采样源（与顶栏玻璃共用同一份快照）。
  final MiuixBackdrop backdrop;

  /// true：顶边（上糊下清）；false：底边（下糊上清）。
  final bool fromTop;

  /// progressive blur 半径（dp）。默认取 miuix 顶栏的 80。
  final double blurRadius;

  /// 渐变强度：0 完全不显示，1 满强度。
  final double strength;

  @override
  Widget build(BuildContext context) {
    if (GlassRuntime.performance.value ||
        !GlassRuntime.material.value ||
        strength <= 0) {
      return const SizedBox.shrink();
    }
    final isDark = Theme.of(context).brightness == Brightness.dark;

    // 官方遮罩：白色=保留，透明=擦除。
    final LinearGradient mask = fromTop
        ? MiuixGlassTopAppBarDefaults.bandBlurMask()
        : const LinearGradient(
            begin: Alignment.bottomCenter,
            end: Alignment.topCenter,
            stops: [0, .55, 1],
            colors: [
              Color(0xFFFFFFFF),
              Color(0xFFFFFFFF),
              Color(0x00FFFFFF),
            ],
          );

    return Opacity(
      opacity: strength.clamp(0.0, 1.0),
      child: ShaderMask(
        blendMode: BlendMode.dstIn,
        shaderCallback: (bounds) => mask.createShader(bounds),
        child: MiuixGlassPanel(
          backdrop: backdrop,
          // 与顶栏模糊带共用材质缓存，避免每帧丢纹理缓存。
          material: MiuixGlassTopAppBarDefaults.bandMaterial(
            isDark,
            blurRadius,
          ),
          shape: const MiuixGlassShape(cornerRadius: 0),
          stroke: null,
          shadow: null,
          shading: false,
          child: const SizedBox.expand(),
        ),
      ),
    );
  }
}
