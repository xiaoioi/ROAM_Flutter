// ignore_for_file: deprecated_member_use

import 'package:flutter/material.dart';
import 'package:flutter_miuix/miuix.dart';

import '../../theme/roam_theme.dart';
import 'edge_fade.dart';
import 'glass_controls.dart';
import 'hyperos_top_bar.dart';
import 'roam_backdrop_scope.dart';

/// 二级页外壳（澎湃 OS 4 样式）：
///  - 内容从状态栏下方铺满，可以一直滚到顶栏下面；
///  - 顶栏透明悬浮，左侧返回/右侧动作交给 [HyperosTopBar] 自绘的圆钮；
///  - 边缘渐隐贴在**状态栏正下方**，内容滚到那里时渐进模糊消融，
///    而不是被硬切断（[RoamEdgeFade]，引擎原生 BackdropFilter）。
class RoamPageScaffold extends StatefulWidget {
  const RoamPageScaffold({
    super.key,
    required this.title,
    required this.child,
    this.actions = const <HyperosBarAction>[],
    this.bottom,
    this.onBack,
    this.showBack = true,
    this.topBar,
    this.overlayBuilder,
  });

  /// 悬浮顶栏高度（HyperOS 4 系统应用实测值）。
  static const barHeight = HyperosTopBar.height;

  /// 列表内容让出顶栏的最小上边距（顶栏高度 + 8dp 呼吸位）。
  ///
  /// 页面内容从 y=0 起铺（边到边，滚动时从状态栏后面穿过），
  /// 所以实际还要加上状态栏高度，用 [topPadding] 取。
  static const contentTopPadding = barHeight + 8;

  /// 列表内容真正的上边距：状态栏 + 顶栏 + 呼吸位。
  ///
  /// 边到边之后 body 不再被 `Padding(top: safeTop)` 顶下来，滚动内容会从
  /// 状态栏后面穿过并被顶部的渐进模糊糊掉；首屏内容则要自己让出这一段。
  static double topPadding(BuildContext context) =>
      MediaQuery.paddingOf(context).top + contentTopPadding;

  final String title;
  final Widget child;
  final List<HyperosBarAction> actions;
  final Widget? bottom;
  final VoidCallback? onBack;
  final bool showBack;

  /// 替换默认顶栏（例如搜索模式下的搜索栏）。
  /// 高度仍按 [barHeight] 的槽位摆放，内容自行决定在槽位里怎么排。
  final Widget? topBar;

  /// 盖在整页之上的浮层（全屏搜索等）。
  ///
  /// 它落在**背景捕获子树之外**：采样 [MiuixLayerBackdrop] 时拿到的是
  /// 干净的页面快照，不会把浮层自己录进去（避免玻璃自采样）。
  final Widget Function(MiuixLayerBackdrop backdrop)? overlayBuilder;

  @override
  State<RoamPageScaffold> createState() => _RoamPageScaffoldState();
}

class _RoamPageScaffoldState extends State<RoamPageScaffold> {
  /// 页面级背景采样器：顶栏玻璃圆钮、顶栏模糊带和底部渐隐共用同一份快照。
  ///
  /// 之前的实现只把 `widget.child` 包进捕获层，页面底色是由
  /// `Scaffold.backgroundColor` 画的、在捕获范围之外——子页快照里只有
  /// 透明像素和卡片，玻璃采样不到底色就退回实心灰，这正是「玻璃按钮
  /// 只在设置主页生效」的原因。现在把底色一起包进来。
  final MiuixLayerBackdrop _backdrop = MiuixLayerBackdrop();

  /// 内容是否已离开顶部。miuix 的顶栏按钮用它决定「玻璃底 + 描边」是否淡入。
  bool _scrolled = false;

  /// 每次快照更新就把自己顶成「当前活跃采样源」：本页打开的弹层用自己的
  /// context 查不到作用域（页面 context 在 `Scaffold.body` 之上），回退时
  /// 靠它避免糊到上一层页面（比如在设置页里弹出主页壁纸的模糊）。
  void _markActive() => RoamBackdropScope.markActive(_backdrop);

  @override
  void initState() {
    super.initState();
    _backdrop.addListener(_markActive);
    RoamBackdropScope.markActive(_backdrop);
  }

  bool _onScroll(ScrollNotification notification) {
    if (notification.depth != 0) return false;
    if (notification.metrics.axis != Axis.vertical) return false;
    final next = notification.metrics.pixels > 4;
    if (next != _scrolled) setState(() => _scrolled = next);
    return false;
  }

  @override
  void dispose() {
    _backdrop.removeListener(_markActive);
    RoamBackdropScope.clearActive(_backdrop);
    _backdrop.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final background = isDark ? Colors.black : RoamColors.daySky;
    final safeTop = MediaQuery.paddingOf(context).top;

    return Scaffold(
      backgroundColor: background,
      resizeToAvoidBottomInset: widget.bottom != null,
      body: ListenableBuilder(
        listenable: GlassRuntime.repaint,
        builder: (context, _) {
          // 材质总开关关闭 / 性能模式下不采样、不跑模糊，圆钮退回纯图标。
          final perf = GlassRuntime.performance.value;
          final edgeFade = GlassRuntime.edgeFade.value && !perf;
          final material = GlassRuntime.material.value && !perf;
          final needCapture = edgeFade || material;

          // 底色 + 内容放在同一个捕获子树里：玻璃和渐隐都采样它。
          // 内容从 y=0 起铺（边到边）：滚到状态栏后面时被顶部的渐进模糊
          // 带糊掉，而不是在状态栏下方出现一条硬缝。
          Widget page = ColoredBox(color: background, child: widget.child);
          if (needCapture) {
            page = MiuixLayerBackdropCapture(
              backdrop: _backdrop,
              // 快照只给「会被再模糊一次」的玻璃/渐隐使用。按 1x 采样：
              // 3x 屏上每帧 toImage 的数据量从 ~13MB 降到 ~1.4MB，
              // 而玻璃本身有高斯模糊，肉眼分辨不出 1x 与 3x。
              pixelRatio: 1,
              child: page,
            );
          }

          return RoamBackdropScope(
            backdrop: _backdrop,
            child: Stack(
              fit: StackFit.expand,
              children: [
                // 内容：从屏幕顶端（含状态栏）铺满；页面用
                // RoamPageScaffold.topPadding(context) 给顶栏与状态栏让位。
                Positioned.fill(
                  child: NotificationListener<ScrollNotification>(
                    onNotification: _onScroll,
                    child: page,
                  ),
                ),
                // 底边渐隐：内容到达底栏前淡出（官方 band 参数，非自造遮罩）
                if (edgeFade)
                  Positioned(
                    left: 0,
                    right: 0,
                    bottom: 0,
                    height: 32,
                    child: IgnorePointer(
                      child: RoamEdgeFade(
                        backdrop: _backdrop,
                        fromTop: false,
                        strength: 0.9,
                      ),
                    ),
                  ),
                // 顶栏：玻璃 band + 官方 SmallTopAppBar + 玻璃圆钮。
                // 槽位从 y=0 起算，状态栏这一段也算在带子里——内容滚到
                // 通知栏后面时同样被渐进模糊磨掉，而不是只糊顶栏那 64dp。
                // 栏本身放在状态栏下方 64dp 槽位里；模糊带由 HyperosTopBar
                // 自己向上多铺 statusBarHeight，一直糊到屏幕最顶端。
                Positioned(
                  top: safeTop,
                  left: 0,
                  right: 0,
                  height: RoamPageScaffold.barHeight,
                  child: Align(
                    alignment: Alignment.topCenter,
                    child:
                        widget.topBar ??
                        HyperosTopBar(
                          title: widget.title,
                          actions: widget.actions,
                          onBack: widget.onBack,
                          showBack: widget.showBack,
                          miuixLayer: material ? _backdrop : null,
                          scrolled: _scrolled,
                          edgeFade: edgeFade,
                          statusBarHeight: safeTop,
                        ),
                  ),
                ),
                if (widget.bottom != null)
                  Positioned(left: 0, right: 0, bottom: 0, child: widget.bottom!),
                // 全屏浮层（搜索）：在捕获子树外面，玻璃能采到真背景。
                if (widget.overlayBuilder != null)
                  Positioned.fill(child: widget.overlayBuilder!(_backdrop)),
              ],
            ),
          );
        },
      ),
    );
  }
}

/// 分组标题：15sp 粗体，正文 25dp 内边距，上 10dp、下 5dp。
class RoamGroupHeader extends StatelessWidget {
  const RoamGroupHeader({super.key, required this.text, this.left = 25});

  final String text;
  final double left;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Padding(
      padding: EdgeInsets.fromLTRB(left, 10, 25, 5),
      child: Text(
        text,
        style: TextStyle(
          fontSize: 15,
          fontWeight: FontWeight.w700,
          color: isDark ? RoamColors.textPrimary : RoamColors.dayInk,
        ),
      ),
    );
  }
}

/// 静态玻璃质感：列表里高频复用，用渐变 + 高光描边代替实时折射，避免逐项开图层。
BoxDecoration roamGlassDecoration(
  BuildContext context, {
  double radius = 15,
  bool elevated = true,
}) {
  final isDark = Theme.of(context).brightness == Brightness.dark;
  return BoxDecoration(
    borderRadius: BorderRadius.circular(radius),
    gradient: LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: isDark
          ? [
              Colors.white.withValues(alpha: 0.085),
              Colors.white.withValues(alpha: 0.035),
            ]
          : [
              Colors.white.withValues(alpha: 0.86),
              Colors.white.withValues(alpha: 0.58),
            ],
    ),
    border: Border.all(
      color: isDark
          ? Colors.white.withValues(alpha: 0.12)
          : Colors.white.withValues(alpha: 0.9),
      width: 1,
    ),
    boxShadow: elevated
        ? [
            BoxShadow(
              color: Colors.black.withValues(alpha: isDark ? 0.34 : 0.06),
              blurRadius: 18,
              offset: const Offset(0, 8),
            ),
          ]
        : null,
  );
}

/// 原版设置卡：正文 25dp 内边距、上下 5.2dp 外边距、15dp 圆角、
/// 行内 25dp 图标 + 15sp 文字 + 28dp 箭头，行间 1dp 分隔线（左右缩进 20dp）。
/// 卡片底换成柔光玻璃面板，尺寸与层级不动。
class RoamSettingCard extends StatelessWidget {
  const RoamSettingCard({
    super.key,
    required this.children,
    this.margin = const EdgeInsets.fromLTRB(25, 5.2, 25, 5.2),
  });

  final List<Widget> children;
  final EdgeInsets margin;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Padding(
      padding: margin,
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(15),
          color: isDark ? RoamColors.cardDark : RoamColors.cardLight,
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(15),
          child: Column(
            children: [
              for (var i = 0; i < children.length; i++) ...[
                if (i > 0)
                  Container(
                    height: 1,
                    margin: const EdgeInsets.symmetric(horizontal: 20),
                    color: isDark
                        ? Colors.white.withValues(alpha: 0.08)
                        : Colors.black.withValues(alpha: 0.06),
                  ),
                children[i],
              ],
            ],
          ),
        ),
      ),
    );
  }
}

/// 设置行：左侧 25dp 单色图标，主文案 15sp，右侧 28dp 箭头。
class RoamSettingRow extends StatelessWidget {
  const RoamSettingRow({
    super.key,
    required this.label,
    required this.onTap,
    this.icon,
    this.iconWidget,
    this.subtitle,
    this.trailing,
    this.showChevron = true,
    this.labelColor,
  });

  final String label;
  final String? subtitle;
  final String? icon;
  final Widget? iconWidget;
  final Widget? trailing;
  final bool showChevron;
  final VoidCallback? onTap;
  final Color? labelColor;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final fg =
        labelColor ?? (isDark ? RoamColors.textPrimary : RoamColors.dayInk);
    final dim = isDark ? RoamColors.dimDark : RoamColors.dimLight;

    return InkWell(
      onTap: onTap,
      splashColor: Colors.transparent,
      highlightColor: Colors.white.withValues(alpha: 0.04),
      child: Container(
        constraints: const BoxConstraints(minHeight: 50),
        padding: const EdgeInsets.fromLTRB(9, 10, 12, 10),
        child: Row(
          children: [
            if (iconWidget != null)
              iconWidget!
            else if (icon != null)
              Image.asset(
                icon!,
                width: 25,
                height: 25,
                color: isDark ? RoamColors.textPrimary : RoamColors.dayInk,
              ),
            if (icon != null || iconWidget != null) const SizedBox(width: 7),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(fontSize: 15, color: fg),
                  ),
                  if (subtitle != null) ...[
                    const SizedBox(height: 2),
                    Text(
                      subtitle!,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(fontSize: 11.5, color: dim),
                    ),
                  ],
                ],
              ),
            ),
            ?trailing,
            if (showChevron)
              Image.asset(
                'assets/images/menu.png',
                width: 28,
                height: 28,
                color: isDark
                    ? RoamColors.textTertiary
                    : const Color(0xFF9A9AA0),
              ),
          ],
        ),
      ),
    );
  }
}

/// 列表通用玻璃卡：历史、书签、下载共用。
class RoamListCard extends StatelessWidget {
  const RoamListCard({
    super.key,
    required this.child,
    this.radius = 12,
    this.margin = const EdgeInsets.only(bottom: 6),
    this.padding = const EdgeInsets.symmetric(horizontal: 15, vertical: 10),
    this.onTap,
    this.onLongPress,
  });

  final Widget child;
  final double radius;
  final EdgeInsets margin;
  final EdgeInsets padding;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final card = Container(
      margin: margin,
      padding: padding,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(radius),
        color: isDark ? RoamColors.cardDark : RoamColors.cardLight,
      ),
      child: child,
    );
    if (onTap == null && onLongPress == null) return card;
    return GestureDetector(
      onTap: onTap,
      onLongPress: onLongPress,
      behavior: HitTestBehavior.opaque,
      child: card,
    );
  }
}

/// 悬浮圆形玻璃按钮（书签页的“删除全部”用的就是 55dp 圆钮）。
class RoamGlassFab extends StatelessWidget {
  const RoamGlassFab({
    super.key,
    required this.icon,
    required this.onTap,
    this.size = 55,
    this.iconSize = 24,
    this.right = 25,
    this.bottom = 40,
    this.tooltip,
  });

  final String icon;
  final VoidCallback onTap;
  final double size;
  final double iconSize;
  final double right;
  final double bottom;
  final String? tooltip;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Positioned(
      right: right,
      bottom: bottom,
      child: Tooltip(
        message: tooltip ?? '',
        child: PressableScale(
          onTap: onTap,
          scale: 0.9,
          child: RoamGlassSurface(
            capsule: true,
            miuixSolid: true,
            forceDark: isDark,
            surfaceColor: isDark
                ? const Color(0xFF2C2C33).withValues(alpha: 0.94)
                : Colors.white.withValues(alpha: 0.96),
            child: SizedBox(
              width: size,
              height: size,
              child: Center(
                child: Image.asset(
                  icon,
                  width: iconSize,
                  height: iconSize,
                  color: isDark ? RoamColors.textPrimary : RoamColors.dayInk,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// 原版单选/开关行用的右侧胶囊开关，内部使用 MiuixSwitch（MIUI X 风格）。
class RoamSwitch extends StatelessWidget {
  const RoamSwitch({
    super.key,
    required this.value,
    required this.onChanged,
    this.color,
  });

  final bool value;
  final ValueChanged<bool>? onChanged;

  /// 打开状态下的轨道颜色；不传则跟随 miuix 主题色（蓝）。
  final Color? color;

  @override
  Widget build(BuildContext context) {
    // 自定义颜色时覆盖默认 MiuixSwitchColors 的 checked 轨道色
    final MiuixSwitchColors? colors;
    if (color != null) {
      final base = MiuixSwitchDefaults.switchColors(context);
      colors = MiuixSwitchColors(
        checkedThumbColor: base.checkedThumbColor,
        uncheckedThumbColor: base.uncheckedThumbColor,
        disabledCheckedThumbColor: base.disabledCheckedThumbColor,
        disabledUncheckedThumbColor: base.disabledUncheckedThumbColor,
        checkedTrackColor: color!,
        uncheckedTrackColor: base.uncheckedTrackColor,
        disabledCheckedTrackColor: base.disabledCheckedTrackColor,
        disabledUncheckedTrackColor: base.disabledUncheckedTrackColor,
      );
    } else {
      colors = null; // 使用 MiuixTheme 默认色
    }
    return MiuixSwitch(value: value, onChanged: onChanged, colors: colors);
  }
}
