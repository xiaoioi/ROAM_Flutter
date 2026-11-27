// ignore_for_file: deprecated_member_use

import 'package:flutter/material.dart';
import 'package:flutter_miuix/miuix.dart';

import '../../theme/roam_theme.dart';
import 'glass_controls.dart';

/// 弹层（底部抽屉 / 对话框）统一使用的玻璃表面。
///
/// 标准态**直接用 miuix 的官方表面函数**：
///  - 底部抽屉 → `miuixGlassBottomSheetSurface`
///  - 对话框 → `miuixGlassDialogSurface`
///
/// 它们就是 `MiuixGlassBottomSheet` / `MiuixGlassDialog` 内部用的那一份：
/// 先按遮罩色把采样到的背景压暗，再走 dialogGlass 三层材质 + forTheme 高光描边，
/// 顶部圆角、过拖延展去描边这些细节都在里面，不需要外面再拼一遍。
///
/// [backdrop] 由页面外壳通过 [RoamBackdropScope] 交出。压栈路由里的弹层自己
/// 读不到页面捕获器，所以必须在打开之前取一次；拿不到时传 null，官方表面会
/// 用 `containerColor` 兜底（这里给半透明，至少还是磨砂而不是实色块）。
///
/// 三态（跟随「材质显示效果」/「高斯模糊效果」）：
///  - 材质关闭 → 纯色，不模糊；
///  - 性能优先 → 半透明磨砂 + 轮廓光（白边/浅黑边按明暗取）；
///  - 标准 → 官方玻璃表面。
class RoamPopupGlass extends StatelessWidget {
  const RoamPopupGlass({
    super.key,
    required this.child,
    this.backdrop,
    this.isDialog = false,
    this.forceDark,
  });

  final Widget child;

  /// 页面级背景采样源；为空时官方表面用半透明兜底色。
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

    // 标准：官方表面（遮罩压暗 → dialogGlass 材质 → 描边）。
    // 没有快照时用半透明兜底色，而不是主题 background（那是一块实色）。
    final fallback = (dark ? RoamColors.cardDark : Colors.white).withValues(
      alpha: 0.72,
    );
    final scrim = MiuixGlassDialogDefaults.scrimColor;
    if (isDialog) {
      return miuixGlassDialogSurface(
        backdrop: backdrop,
        containerColor: fallback,
      )(context, 28, scrim, 1, child);
    }
    return miuixGlassBottomSheetSurface(
      backdrop: backdrop,
      containerColor: fallback,
    )(context, MiuixBottomSheetDefaults.cornerRadius, scrim, false, child);
  }

  BorderRadius get _shapeRadius => isDialog
      ? BorderRadius.circular(28)
      : BorderRadius.vertical(
          top: Radius.circular(MiuixBottomSheetDefaults.cornerRadius),
        );
}
