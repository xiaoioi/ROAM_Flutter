// ignore_for_file: deprecated_member_use

import 'package:flutter/material.dart';
import 'package:flutter_miuix/miuix.dart';

import 'glass_controls.dart';

/// 内容边缘的渐进模糊（顶/底）。
///
/// 用 flutter_miuix 的 [MiuixTextureBlur] 采样页面级 [MiuixBackdrop]，
/// 再用 [ShaderMask] 给整条带套一层线性 alpha 渐变：
///
///  - 只做 **一次** 高斯模糊（快照图上的 `ImageFilter.blur`），
///    不再像旧实现那样横切 6 条 [BackdropFilter]，每帧 6 次
///    saveLayer + 背景采样；
///  - 渐变由 mask 完成，过渡是连续的，不会出现分带的硬边；
///  - 快照来自 1x 页面捕获，滚动时没有额外的实时采样开销。
///
/// 注意这里必须用「快照 + mask」，不能用 `BackdropFilter + ShaderMask`：
/// ShaderMask 会先 saveLayer，BackdropFilter 在空图层里采样不到页面内容，
/// 整条带会变成全透明。
class RoamEdgeFade extends StatelessWidget {
  const RoamEdgeFade({
    super.key,
    required this.backdrop,
    this.fromTop = true,
    this.blurRadius = 48,
    this.strength = 1,
    this.solidStop = 0.55,
  });

  /// 页面级背景采样源（与顶栏玻璃共用同一份快照）。
  final MiuixBackdrop backdrop;

  /// true：顶边（上糊下清）；false：底边（下糊上清）。
  final bool fromTop;

  /// 模糊半径（dp）。系统界面默认玻璃半径为 110 源单位，
  /// 换算到一条 72dp 高的渐隐带上取 48dp 观感最接近。
  final double blurRadius;

  /// 渐变强度：0 完全不显示，1 满强度。
  final double strength;

  /// 满强度区占比。顶栏渐隐会把它算成「状态栏 + 顶栏」所占的比例，
  /// 保证整条顶栏都是均匀磨砂，只在下面 8dp 左右开始消融。
  final double solidStop;

  @override
  Widget build(BuildContext context) {
    if (GlassRuntime.performance.value || strength <= 0) {
      return const SizedBox.shrink();
    }

    final gradient = LinearGradient(
      begin: fromTop ? Alignment.topCenter : Alignment.bottomCenter,
      end: fromTop ? Alignment.bottomCenter : Alignment.topCenter,
      colors: [
        Color.fromRGBO(255, 255, 255, strength),
        Color.fromRGBO(255, 255, 255, 0.72 * strength),
        const Color(0x00FFFFFF),
      ],
      stops: [0, solidStop.clamp(0, 0.95), 1],
    );

    return ShaderMask(
      // dstIn = 用渐变的 alpha 去乘子内容的 alpha，颜色不参与。
      blendMode: BlendMode.dstIn,
      shaderCallback: (bounds) => gradient.createShader(bounds),
      child: MiuixTextureBlur(
        backdrop: backdrop,
        blurRadius: blurRadius,
        // 不额外染色：系统界面的顶栏渐隐就是纯模糊，
        // 颜色仍由页面底色决定。
        child: const SizedBox.expand(),
      ),
    );
  }
}
