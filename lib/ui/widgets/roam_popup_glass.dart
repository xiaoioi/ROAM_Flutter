// ignore_for_file: deprecated_member_use

import 'package:flutter/material.dart';
import 'package:flutter_miuix/miuix.dart';

import '../../theme/roam_theme.dart';
import 'glass_controls.dart';

/// 弹层（底部抽屉 / 对话框）统一使用的玻璃表面。
///
/// 标准态**完全交给 miuix 的官方玻璃表面**：
///  - 底部抽屉 → [miuixGlassBottomSheetSurface]
///    （Kotlin `glassBottomSheetSurface`，内部 `MiuixGlassPanel` +
///    `MiuixScrimBackdrop`：先按遮罩色压暗再采样，材质 / 顶部圆角 / 描边全由库出）
///  - 对话框 → [miuixGlassDialogSurface]
///    （Kotlin `glassDialogSurface`，圆角取 `MiuixDialogDefaults.cornerRadius`）
///
/// 不再自己拼「纹理模糊 + 手调 BlurColors + 自绘描边」——那套东西和官方的
/// 材质层、遮罩压暗顺序都对不齐，调参也调不出 ROM 的观感。
///
/// [backdrop] 由调用方在**打开弹层之前**从 [RoamBackdropScope] 取（弹层自己的
/// context 读不到页面级采样器）。没有快照时官方表面会退回不透明 containerColor。
///
/// 三态（跟随「材质显示效果」/「高斯模糊效果」）：
///  - 材质关闭 → 纯色，不模糊（官方表面在无 backdrop 时也是纯色，这里提前短路）；
///  - 性能优先 → 半透明磨砂 + 轮廓光（不跑高斯）；
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

  /// 页面级背景采样源；为空时用不透明兜底色。
  final MiuixBackdrop? backdrop;

  /// true：对话框（圆角 32）；false：底部抽屉（只有上方两角）。
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

    // 标准：官方玻璃表面。
    final surface = isDialog
        ? miuixGlassDialogSurface(
            backdrop: backdrop,
          )(
            context,
            MiuixDialogDefaults.cornerRadius,
            MiuixGlassDialogDefaults.scrimColor,
            1,
            child,
          )
        : miuixGlassBottomSheetSurface(
            backdrop: backdrop,
          )(
            context,
            MiuixBottomSheetDefaults.cornerRadius,
            MiuixGlassBottomSheetDefaults.scrimColor,
            false,
            child,
          );

    // 首页壁纸上的抽屉要深底白字：官方表面的材质跟主题走，这里把
    // 主题强制成深色即可，不必再自己换一套颜色。
    final forceDarkTheme = forceDark == true && !dark;
    return forceDarkTheme
        ? MiuixTheme(data: MiuixThemeData.of(Brightness.dark), child: surface)
        : surface;
  }

  BorderRadius get _shapeRadius => isDialog
      ? BorderRadius.circular(MiuixDialogDefaults.cornerRadius)
      : BorderRadius.vertical(
          top: Radius.circular(MiuixBottomSheetDefaults.cornerRadius),
        );
}
