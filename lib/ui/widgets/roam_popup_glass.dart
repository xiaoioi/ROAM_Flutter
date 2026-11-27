// ignore_for_file: deprecated_member_use

import 'package:flutter/material.dart';
import 'package:flutter_miuix/miuix.dart';

import '../../theme/roam_theme.dart';
import 'glass_controls.dart';

/// 弹层（底部抽屉 / 对话框）统一使用的玻璃表面。
///
/// 标准态直接用库自己的表面构建器：
///  - 底部抽屉 → [miuixGlassBottomSheetSurface]
///  - 对话框   → [miuixGlassDialogSurface]
///
/// 两者都是「scrim 预压暗的 backdrop 快照 → dialogGlass 材质混色 → forTheme
/// 高光描边」这条官方管线，面板和 miuix 自己的 GlassBottomSheet / GlassDialog
/// 一模一样，不再自己套 [BackdropFilter]。
///
/// 为什么不再用 `BackdropFilter`：弹层压在新的 Navigator 路由里，Overlay 的每个
/// entry 都是独立的合成层，`BackdropFilter` 只能读同一层里已经画过的像素，跨层
/// 读到的是空图层——表现就是「弹框一点都不糊」，只会露出下面那层半透明 fill。
///
/// [backdrop] 由调用方在**打开弹层之前**从 [RoamBackdropScope] 取（弹层自己的
/// context 读不到页面级采样器）。没有 backdrop 时库会退回不透明兜底色。
///
/// 三态（跟随「材质显示效果」/「高斯模糊效果」）：
///  - 材质关闭 → 纯色，不模糊；
///  - 性能优先 → 半透明磨砂 + 轮廓光（白边/浅黑边按明暗取）；
///  - 标准     → 官方玻璃表面。
class RoamPopupGlass extends StatelessWidget {
  const RoamPopupGlass({
    super.key,
    required this.child,
    this.backdrop,
    this.isDialog = false,
    this.forceDark,
  });

  final Widget child;

  /// 页面级背景采样源；为空时官方表面用不透明兜底色。
  final MiuixBackdrop? backdrop;

  /// true：对话框（四角 28）；false：底部抽屉（只有上方两角）。
  final bool isDialog;

  /// 强制深色（首页壁纸上的抽屉）。只影响兜底底色，标准态仍跟随主题。
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

    // 标准：官方表面。模糊半径跟随「模糊度」滑杆，描边跟随「轮廓光」开关。
    final blur =
        (MiuixGlassMaterials.dialogGlass(dark).blurRadius *
                GlassRuntime.blurScale.value)
            .clamp(0.0, MiuixBlurDefaults.maxBlurRadius);
    final material = MiuixGlassMaterials.dialogGlass(dark)
        .copyWith(blurRadius: blur);
    final rim = GlassRuntime.rimLight.value;
    final stroke = rim ? MiuixGlassStrokes.forTheme(dark) : null;
    final containerColor = dark ? RoamColors.cardDark : RoamColors.cardLight;

    if (isDialog) {
      return miuixGlassDialogSurface(
        backdrop: backdrop,
        material: material,
        stroke: stroke,
        showStroke: rim,
        containerColor: containerColor,
      )(
        context,
        _shapeRadius.topLeft.x,
        MiuixGlassDialogDefaults.scrimColor,
        1,
        child,
      );
    }
    return miuixGlassBottomSheetSurface(
      backdrop: backdrop,
      material: material,
      stroke: stroke,
      showStroke: rim,
      containerColor: containerColor,
    )(
      context,
      MiuixBottomSheetDefaults.cornerRadius,
      MiuixGlassBottomSheetDefaults.scrimColor,
      false,
      child,
    );
  }

  BorderRadius get _shapeRadius => isDialog
      ? BorderRadius.circular(28)
      : BorderRadius.vertical(
          top: Radius.circular(MiuixBottomSheetDefaults.cornerRadius),
        );
}
