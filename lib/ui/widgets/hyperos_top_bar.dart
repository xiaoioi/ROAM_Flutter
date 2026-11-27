// ignore_for_file: deprecated_member_use

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_miuix/miuix.dart';
// `GlassBarScope` 是 miuix 顶栏与圆钮之间的官方作用域（GlassTopAppBar 内部
// 就是这么用的），库暂未从 miuix.dart 导出，这里按内部路径引入以复用同一套
// 「浮起进度 → 材质/描边淡入」逻辑，而不是自己再写一份状态机。
// ignore: implementation_imports
import 'package:flutter_miuix/src/theme/miuix/glass/internal/bar_scope.dart';

import 'glass_controls.dart';

/// 顶栏按钮的数据描述。
///
/// 用数据而不是 Widget，是因为圆钮的尺寸、图标大小、点击态必须由
/// [HyperosTopBar] 统一控制——把 `RoamBarAction` 之类的 40dp 按钮
/// 塞进圆钮里会形成「按钮套按钮」，点按缩放两次、图标还会偏。
class HyperosBarAction {
  const HyperosBarAction({
    required this.asset,
    required this.onTap,
    this.tooltip,
    this.iconSize = 26,
  });

  /// 原包图标（白色 PNG，渲染时按前景色染色）。
  final String asset;
  final VoidCallback? onTap;
  final String? tooltip;
  final double iconSize;
}

/// 澎湃 OS 4 顶栏 = **miuix 的 SmallTopAppBar + GlassBarScope（官方玻璃作用域）**。
///
/// 之前这里是自绘的 64dp 栏 + 一直带玻璃底的圆钮，两处都不符合 miuix：
///
///  1. 顶栏应当由 `MiuixSmallTopAppBar` 出（居中标题、50dp 内容高、
///     官方 title3 字重与左右 12dp 图标位），而不是另写一套 Text/Stack；
///  2. 圆钮的材质与**高光描边属于「栏浮起」状态**，由 [GlassBarScope]
///     的 `progress` 驱动：内容还在顶部时 progress=0（只有图标），
///     内容滚过一段距离后 progress→1，玻璃底和描边才淡入。
///     这对应 `MiuixGlassTopAppBar` 的 `isContentScrolled` 语义。
///
/// 顶部的渐进模糊带（band）只做模糊、不叠色调：miuix 的 `bandMaterial`
/// 自带三层灰调（深色 #565656 + #3F3F3F），铺在深色页面上就是一条灰遮罩。
/// 淡出仍用官方的 `bandBlurMask()`，所以下缘依旧是连续消融的。
class HyperosTopBar extends StatelessWidget {
  const HyperosTopBar({
    super.key,
    required this.title,
    this.actions = const <HyperosBarAction>[],
    this.onBack,
    this.showBack = true,
    this.miuixLayer,
    this.scrolled = true,
    this.edgeFade = true,
    this.glass = true,
    this.statusBarHeight = 0,
  });

  /// 槽位高度（保持页面原有节奏；栏本身是官方的 50dp 居中）。
  static const height = 64.0;

  /// 官方 SmallTopAppBar 的内容高度。
  static const barContentHeight = MiuixTopAppBarDefaults.smallTopAppBarCenterHeight;

  /// 圆钮直径（官方 GlassTopAppBarDefaults.buttonSize）。
  static const circleSize = MiuixGlassTopAppBarDefaults.buttonSize;

  /// 圆钮到屏幕左右边缘的距离（官方 GlassTopAppBar 的 horizontalPadding）。
  static const side = MiuixGlassTopAppBarDefaults.horizontalPadding;

  /// 圆钮之间的间距。
  static const gap = 8.0;

  final String title;
  final List<HyperosBarAction> actions;
  final VoidCallback? onBack;
  final bool showBack;

  /// 玻璃态的背景采样源（页面级 [MiuixLayerBackdrop]）。
  final MiuixLayerBackdrop? miuixLayer;

  /// 内容是否已离开顶部；决定圆钮的玻璃底 / 描边是否淡入。
  final bool scrolled;

  /// 是否启用顶部的 progressive blur 带。
  final bool edgeFade;

  /// 状态栏高度：模糊带要一直铺到屏幕最顶端（y=0），
  /// 而不是只盖住 64dp 的栏——否则状态栏那一段会出现一条硬缝。
  final double statusBarHeight;

  /// 材质总开关。关掉时圆钮只剩图标（不出现玻璃底与描边）。
  final bool glass;

  @override
  Widget build(BuildContext context) {
    final dark =
        MiuixTheme.of(context).colors.background.computeLuminance() < .5;
    final fg = MiuixTheme.of(context).colors.onSurface;
    final animate = !(MediaQuery.maybeDisableAnimationsOf(context) ?? false);
    final mode = GlassRuntime.mode;
    // 只有标准模式才跑顶部的渐进模糊带；性能优先不糊，材质关闭更不糊。
    final showBand =
        edgeFade && miuixLayer != null && mode == RoamGlassMode.standard;
    final enabled = glass && mode != RoamGlassMode.off;
    // 性能优先：圆钮改成「简单模糊」——不采样、不做高斯，只铺半透明磨砂底。
    final frosted = mode == RoamGlassMode.performance;
    final radius = MiuixGlassTopAppBarDefaults.rampDistance;

    return TweenAnimationBuilder<double>(
      duration: animate
          ? MiuixGlassMotion.topBarButtonFloat
          : Duration.zero,
      tween: Tween(begin: scrolled ? 1 : 0, end: scrolled ? 1 : 0),
      builder: (context, rawProgress, _) {
        final progress = enabled ? rawProgress : 0.0;
        return GlassBarScope(
          // 按钮与 band 都采样同一份页面快照；性能优先时不采样。
          backdrop: frosted ? null : miuixLayer,
          buttonBackdrop: frosted ? null : miuixLayer,
          material: MiuixGlassTopAppBarDefaults.nestedMaterial(dark),
          underlay: null,
          buttonUnderlay: null,
          style: MiuixGlassDefaults.style(context),
          // 0 = 内容在顶部（按钮只有图标），1 = 已浮起（玻璃底 + 描边）。
          progress: progress,
          alpha: 1,
          floating: progress > .001,
          ramp: radius == 0 ? 1 : progress,
          buttonSize: circleSize,
          // 磨砂底由 fill 承担；高光描边在性能优先时换成按明暗取色的轮廓光。
          fill: frosted ? roamFrostedFill(dark) : null,
          showStroke: !frosted,
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              // 顶部渐进模糊带：官方的 80dp 半径 + 下缘消融遮罩，
              // 高度按「栏高 + bandOverhang」向上多探一点，与库一致。
              if (showBand)
                Positioned(
                  top: -statusBarHeight,
                  left: 0,
                  right: 0,
                  bottom: -MiuixGlassTopAppBarDefaults.bandOverhang,
                  child: IgnorePointer(
                    child: Opacity(
                      opacity: progress,
                      // 只糊不改色：miuix 的 bandMaterial 自带三层灰调
                      // （深色 #565656 + #3F3F3F），在深色页面上就是一条
                      // 灰遮罩；渐隐本来就只该让内容糊掉，不能顺带压暗。
                      child: RoamProgressiveBlur(
                        backdrop: miuixLayer,
                        sigma: 32,
                      ),
                    ),
                  ),
                ),
              Align(
                alignment: Alignment.center,
                child: SizedBox(
                  height: barContentHeight,
                  // SmallTopAppBar 自带 SafeArea(top: true)；槽位本身已经在
                  // 状态栏下方，这里把那份 padding 去掉，避免整条栏下沉。
                  child: MediaQuery.removePadding(
                    context: context,
                    removeTop: true,
                    child: MiuixSmallTopAppBar(
                      title: title,
                      color: Colors.transparent,
                      titleColor: fg,
                      defaultWindowInsetsPadding: false,
                      navigationIconPadding: side,
                      actionIconPadding: side,
                      titlePadding: 26,
                      navigationIcon: showBack
                          ? HyperosCircleButton(
                              onTap:
                                  onBack ??
                                  () => Navigator.of(context).maybePop(),
                              // 原包 PNG 的墨迹只占画布 50% 高，32dp 渲染出来
                              // 才是截图里约 16dp 高的箭头。
                              child: Image.asset(
                                'assets/images/back_images.png',
                                width: 32,
                                height: 32,
                                color: fg,
                              ),
                            )
                          : null,
                      actions: [
                        for (var i = 0; i < actions.length; i++) ...[
                          if (i > 0) const SizedBox(width: gap),
                          HyperosCircleButton(
                            onTap: actions[i].onTap,
                            tooltip: actions[i].tooltip,
                            child: Image.asset(
                              actions[i].asset,
                              width: actions[i].iconSize,
                              height: actions[i].iconSize,
                              color: fg,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

/// 圆形按钮 → flutter_miuix 的 [MiuixGlassIconButton]。
///
/// 材质、描边、显隐进度全部继承 [GlassBarScope]：内容在顶部时只有图标，
/// 滚动后玻璃底与高光描边才淡入。不做「按钮里再套按钮」——
/// 44dp 的触摸区就是 miuix 按钮自身的尺寸。
class HyperosCircleButton extends StatelessWidget {
  const HyperosCircleButton({
    super.key,
    required this.child,
    this.onTap,
    this.tooltip,
    this.size = HyperosTopBar.circleSize,
    this.miuixLayer,
  });

  final Widget child;
  final VoidCallback? onTap;
  final String? tooltip;
  final double size;
  final MiuixLayerBackdrop? miuixLayer;

  @override
  Widget build(BuildContext context) {
    final label = (tooltip?.isNotEmpty ?? false) ? tooltip : null;
    final button = MiuixGlassIconButton(
      onPressed: onTap == null
          ? null
          : () {
              HapticFeedback.selectionClick();
              onTap!();
            },
      size: size,
      // 显式给采样源，脱离顶栏作用域时（独立浮钮）也能出玻璃。
      backdrop: miuixLayer,
      tooltip: label,
      semanticLabel: label,
      child: child,
    );

    // 性能优先：没有高光 shader，轮廓光改成「按明暗取色的 1px 细边」，
    // 和 miuix 的浮起进度同步淡入（内容在顶部时仍然只有图标）。
    final scope = GlassBarScope.maybeOf(context);
    final progress = (scope?.progress ?? 1).clamp(0.0, 1.0);
    final rim =
        GlassRuntime.mode == RoamGlassMode.performance &&
        GlassRuntime.rimLight.value &&
        progress > .01;
    if (!rim) return button;
    final dark =
        MiuixTheme.of(context).colors.background.computeLuminance() < .5;
    return SizedBox.square(
      dimension: size,
      child: Stack(
        alignment: Alignment.center,
        children: [
          button,
          Positioned.fill(
            child: IgnorePointer(
              child: Opacity(
                opacity: progress,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(color: roamRimColor(dark)),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
