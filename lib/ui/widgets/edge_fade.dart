// ignore_for_file: deprecated_member_use

import 'package:flutter/material.dart';
import 'package:flutter_miuix/miuix.dart';

import 'glass_controls.dart';

/// 内容边缘的渐进模糊（顶/底）。
///
/// 就是 [RoamProgressiveBlur] 的薄封装，保留原来的调用签名。
///
/// 走 `miuix-blur` 的渐进模糊（`progressiveTextureBlur` 语义）：越靠边缘越糊，
/// 清晰端是全分辨率原图，所以不存在「带子下缘一条硬边」。
///
/// 不再用 miuix 的 `bandMaterial`：它自带三层灰调（深色 #565656 + #3F3F3F），
/// 铺在深色页面上就是一条灰遮罩。这里只做模糊，不叠任何颜色。
class RoamEdgeFade extends StatelessWidget {
  const RoamEdgeFade({
    super.key,
    this.backdrop,
    this.fromTop = true,
    this.blurRadius = MiuixGlassTopAppBarDefaults.progressiveBlurRadius,
    this.strength = 1,
  });

  /// 页面级背景采样源：库的玻璃必须从快照取样，不能用裸 BackdropFilter。
  final MiuixBackdrop? backdrop;

  /// true：顶边（上糊下清）；false：底边（下糊上清）。
  final bool fromTop;

  /// 满强度处的模糊半径（dp），交给库的 [MiuixTextureBlur]。
  final double blurRadius;

  /// 渐变强度：0 完全不显示，1 满强度。
  final double strength;

  @override
  Widget build(BuildContext context) {
    if (GlassRuntime.performance.value || !GlassRuntime.material.value) {
      return const SizedBox.shrink();
    }
    return RoamProgressiveBlur(
      backdrop: backdrop,
      blurRadius: blurRadius,
      fromTop: fromTop,
      strength: strength,
      // 底栏渐隐只有 32dp，整条都拿来做过渡，不要留一段满强度死糊。
      endFraction: 0.95,
      curve: 1,
    );
  }
}
