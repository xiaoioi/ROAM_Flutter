// ignore_for_file: deprecated_member_use

import 'dart:ui' show ImageFilter;

import 'package:flutter/material.dart';
import 'package:flutter_miuix/miuix.dart';

import '../../theme/roam_theme.dart';
import 'glass_controls.dart';

/// 弹层（底部抽屉 / 对话框）统一使用的玻璃表面。
///
/// 关键点：**整块面板一起模糊**。之前用的是 miuix 的折射采样路径——
/// 它按快照局部取纹理再走 shader，在「压栈路由 + platform view」的组合下
/// 采样区域和面板对不上，表现就是面板里只有一块是糊的、其余是渐变实色。
/// 现在改成最直接的一层：面板自身开一个 [BackdropFilter]，把**整个矩形**
/// 高斯模糊，然后在上面叠 miuix 的材质色与高光描边。这样：
///
///  - 背后是什么（Flutter 页面或 WebView）都能糊；
///  - 模糊范围 = 面板范围，不会出现「糊一半」的接缝；
///  - 材质、描边仍取 [MiuixGlassMaterials.dialogGlass] /
///    [MiuixGlassStrokes.forTheme]，和 miuix 自己的弹层一致。
///
/// 三态：
///  - 材质关闭 → 纯色，不模糊；
///  - 性能优先 → 半透明磨砂 + 轮廓光（白边/浅黑边按明暗取）；
///  - 标准 → 实时高斯 + 高光描边。
class RoamPopupGlass extends StatelessWidget {
  const RoamPopupGlass({
    super.key,
    required this.child,
    this.borderRadius = const BorderRadius.vertical(
      top: Radius.circular(MiuixBottomSheetDefaults.cornerRadius),
    ),
    this.forceDark,
    this.sigma = 28,
  });

  final Widget child;

  /// 面板圆角（底部抽屉只有上方两角，对话框四角一致）。
  final BorderRadius borderRadius;

  /// 强制按深色渲染（壁纸上的抽屉：深底白字）。
  final bool? forceDark;

  /// 实时高斯半径。
  final double sigma;

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
        borderRadius: borderRadius,
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
          borderRadius: borderRadius,
          color: roamFrostedFill(dark),
          border: GlassRuntime.rimLight.value
              ? Border.all(color: roamRimColor(dark), width: 1)
              : null,
        ),
        clipBehavior: Clip.antiAlias,
        child: child,
      );
    }

    // 标准：整块实时高斯 + miuix 的弹层材质色与高光描边。
    final tint = dark
        ? const Color(0xFF17171B).withValues(alpha: 0.62)
        : Colors.white.withValues(alpha: 0.66);

    return ClipRRect(
      borderRadius: borderRadius,
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: sigma, sigmaY: sigma),
        child: MiuixGlassPanel(
          shape: MiuixGlassShape(borderRadius: borderRadius),
          material: MiuixGlassMaterials.dialogGlass(dark),
          stroke: MiuixGlassStrokes.forTheme(dark),
          fill: tint,
          shadow: null,
          shading: false,
          child: child,
        ),
      ),
    );
  }
}
