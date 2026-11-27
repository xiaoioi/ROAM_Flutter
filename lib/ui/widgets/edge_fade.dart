// ignore_for_file: deprecated_member_use

import 'package:flutter/material.dart';
import 'package:flutter_miuix/miuix.dart';

import 'glass_controls.dart';

/// 内容边缘的渐进模糊（顶/底）。
///
/// 就是 [RoamProgressiveBlur] 的薄封装，保留原来的调用签名。
///
/// 之前这里走的是 miuix 的 `bandMaterial`（高斯 + 三层灰调），深色页面上
/// 会呈现为一条发灰的带子，像是「渐隐上盖了一层遮罩」。现在只做模糊，
/// 淡出仍由官方的 `bandBlurMask()` 完成，模糊在带子下缘连续消融。
class RoamEdgeFade extends StatelessWidget {
  const RoamEdgeFade({
    super.key,
    this.backdrop,
    this.fromTop = true,
    this.blurRadius = 32,
    this.strength = 1,
  });

  /// 页面级背景采样源：库的玻璃必须从快照取样，不能用裸 BackdropFilter。
  final MiuixBackdrop? backdrop;

  /// true：顶边（上糊下清）；false：底边（下糊上清）。
  final bool fromTop;

  /// 高斯 sigma（dp）。
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
      sigma: blurRadius,
      fromTop: fromTop,
      strength: strength,
    );
  }
}
