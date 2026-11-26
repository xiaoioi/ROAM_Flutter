// ignore_for_file: deprecated_member_use

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_miuix/miuix.dart';

import '../glass/os4_glass_token.dart';
import '../glass/roam_glass.dart';
import '../glass/roam_glass_bridge.dart';
import 'glass_controls.dart';

/// 澎湃 OS 4 顶栏按钮的数据描述。
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

/// 澎湃 OS 4 顶栏（HyperOS 4 TopAppBar）。
///
/// miuix 官方库只有 MiuixTopAppBar（Material 风格的大标题栏），没有
/// HyperOS 4 系统应用里这种「左右悬浮圆钮 + 居中标题」的形态，所以
/// 这里按系统应用的实测度量自绘：
///
/// | 项 | 值 |
/// |---|---|
/// | 栏高 | 64dp |
/// | 圆钮 | 46dp（含 46dp 触摸区） |
/// | 左右边距 | 12dp |
/// | 钮间距 | 8dp |
/// | 标题 | 21sp / w700 / 居中 |
///
/// 圆钮是 **surface 实心**（浅色纯白渐变 / 深色 #34343B→#242429），
/// 这就是 HyperOS 4 的原样：系统圆钮不是玻璃。开启 [glass] 后改由
/// flutter_miuix 的 [MiuixGlassIconButton] 渲染（OS4 原生玻璃圆钮，
/// 采样页面背景 + 柔光折射 + 方向高光），不再自己拼 shader。
///
/// 明暗只跟 [Theme.of] 的 brightness 走，**不要再读全局的
/// `GlassRuntime.darkUi`**——那个值会被首页的「有壁纸就强制深色」
/// 改掉，导致二级页顶栏在浅色模式下算出白字，白字打在浅底上看不见。
class HyperosTopBar extends StatelessWidget {
  const HyperosTopBar({
    super.key,
    required this.title,
    this.actions = const <HyperosBarAction>[],
    this.onBack,
    this.showBack = true,
    this.glass = false,
    this.miuixLayer,
  });

  /// 栏高。内容区给顶栏让位时用 [height]。
  static const height = 64.0;

  /// 圆钮直径。
  static const circleSize = 46.0;

  /// 圆钮到屏幕左右边缘的距离。
  static const side = 12.0;

  /// 圆钮之间的间距。
  static const gap = 8.0;

  final String title;
  final List<HyperosBarAction> actions;
  final VoidCallback? onBack;
  final bool showBack;

  /// 圆钮是否使用 OS4 柔光玻璃（MiuixGlassIconButton）。
  final bool glass;

  /// 玻璃态的背景采样源（页面级 [MiuixLayerBackdrop]）。
  final MiuixLayerBackdrop? miuixLayer;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    // 玻璃态的图标色跟 miuix 的内容色走，保证与材质混合后的底色对比一致；
    // 实心态沿用澎湃 4 的正文色。
    final fg = glass
        ? (MiuixTheme.maybeOf(context)?.colors.onSurface ??
              (isDark ? const Color(0xFFF3F3F5) : const Color(0xFF141418)))
        : (isDark ? const Color(0xFFF3F3F5) : const Color(0xFF141418));

    return SizedBox(
      height: height,
      child: Stack(
        children: [
          // 标题：绝对居中；两侧按「边距 + 圆钮 + 间距」留白，
          // 长标题只会自己省略，不会压到圆钮上。
          Positioned.fill(
            child: IgnorePointer(
              child: Center(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(
                    side + circleSize + gap + 4,
                    0,
                    side + circleSize + gap + 4,
                    // 汉字墨迹在 em 框里偏下，补 6dp 让标题中心与
                    // 圆钮中心落在同一条线上（图 1 的实测对齐）。
                    6,
                  ),
                  child: Text(
                    title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 21,
                      height: 1.1,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.2,
                      color: fg,
                    ),
                  ),
                ),
              ),
            ),
          ),
          if (showBack)
            Positioned(
              left: side,
              top: 0,
              bottom: 0,
              child: Center(
                child: HyperosCircleButton(
                  onTap: onBack ?? () => Navigator.of(context).maybePop(),
                  glass: glass,
                  miuixLayer: miuixLayer,
                  // 原包 PNG 的墨迹只占画布 50% 高，32dp 渲染出来
                  // 才是图 1 里约 16dp 高的箭头。
                  child: Image.asset(
                    'assets/images/back_images.png',
                    width: 32,
                    height: 32,
                    color: fg,
                  ),
                ),
              ),
            ),
          Positioned(
            right: side,
            top: 0,
            bottom: 0,
            child: Center(
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  for (var i = 0; i < actions.length; i++) ...[
                    if (i > 0) const SizedBox(width: gap),
                    HyperosCircleButton(
                      onTap: actions[i].onTap,
                      tooltip: actions[i].tooltip,
                      glass: glass,
                      miuixLayer: miuixLayer,
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
        ],
      ),
    );
  }
}

/// HyperOS 4 圆形按钮。
///
/// 两种形态：
///  - 默认（[glass] = false）：自绘 surface 圆，顶亮底暗的极轻渐变 +
///    5% 黑投影 + 半透明白细边；按下缩到 0.90 并压暗 4%，不铺水波纹。
///  - [glass] = true：交给 flutter_miuix 的 [MiuixGlassIconButton]，
///    复用 OS4 的 44/46dp 玻璃圆钮（柔光折射、方向光描边、按压弹簧），
///    采样 [miuixLayer] 捕获的页面背景。
///
/// 玻璃只作用于圆钮本体，不做「按钮里再套按钮」：46dp 的触摸区就是
/// miuix 按钮自身的尺寸。
class HyperosCircleButton extends StatefulWidget {
  const HyperosCircleButton({
    super.key,
    required this.child,
    this.onTap,
    this.tooltip,
    this.size = HyperosTopBar.circleSize,
    this.glass = false,
    this.miuixLayer,
  });

  final Widget child;
  final VoidCallback? onTap;
  final String? tooltip;
  final double size;
  final bool glass;
  final MiuixLayerBackdrop? miuixLayer;

  @override
  State<HyperosCircleButton> createState() => _HyperosCircleButtonState();
}

class _HyperosCircleButtonState extends State<HyperosCircleButton> {
  bool _down = false;

  void _setDown(bool value) {
    if (_down == value) return;
    setState(() => _down = value);
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    if (widget.glass) {
      final label = (widget.tooltip?.isNotEmpty ?? false)
          ? widget.tooltip
          : null;

      // 自绘 OS4 柔光玻璃圆钮（默认引擎）：commonSmallRegular 档、
      // 采样页面背景。按压反馈与实心态一致（缩放 + 触感，无水波纹）。
      if (GlassRuntime.customGlass.value) {
        return Semantics(
          button: true,
          label: label,
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTapDown: widget.onTap == null ? null : (_) => _setDown(true),
            onTapCancel: widget.onTap == null ? null : () => _setDown(false),
            onTapUp: widget.onTap == null
                ? null
                : (_) {
                    _setDown(false);
                    HapticFeedback.selectionClick();
                    widget.onTap?.call();
                  },
            child: AnimatedScale(
              scale: _down ? 0.92 : 1.0,
              duration: const Duration(milliseconds: 110),
              curve: Curves.easeOutCubic,
              child: SizedBox(
                width: widget.size,
                height: widget.size,
                child: RoamGlassSceneBridge(
                  backdrop: widget.miuixLayer ?? miuixBackdrop,
                  child: RoamGlass(
                    token: Os4GlassToken.commonSmallRegular,
                    radius: widget.size / 2,
                    child: Center(child: widget.child),
                  ),
                ),
              ),
            ),
          ),
        );
      }

      return MiuixGlassIconButton(
        onPressed: widget.onTap == null
            ? null
            : () {
                HapticFeedback.selectionClick();
                widget.onTap!();
              },
        size: widget.size,
        backdrop: widget.miuixLayer,
        // 脱离顶栏材质继承：这里只有圆钮是玻璃，标题/背景带仍是
        // 页面自己的渐进模糊，不能让按钮把整条顶栏的遮罩算进来。
        inheritTopBarMaterial: false,
        tooltip: label,
        semanticLabel: label,
        child: widget.child,
      );
    }

    final circle = AnimatedContainer(
      duration: const Duration(milliseconds: 130),
      curve: Curves.easeOut,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: isDark
              ? (_down
                    ? const [Color(0xFF3B3B42), Color(0xFF313137)]
                    : const [Color(0xFF34343B), Color(0xFF242429)])
              : (_down
                    ? const [Color(0xFFF2F2F5), Color(0xFFECECF0)]
                    : const [Color(0xFFFFFFFF), Color(0xFFFDFDFF)]),
        ),
        border: Border.all(
          color: isDark
              ? Colors.white.withValues(alpha: 0.07)
              : Colors.white.withValues(alpha: 0.9),
          width: 0.6,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.34 : 0.045),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Center(child: widget.child),
    );

    return Semantics(
      button: true,
      label: widget.tooltip,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTapDown: widget.onTap == null ? null : (_) => _setDown(true),
        onTapCancel: widget.onTap == null ? null : () => _setDown(false),
        onTapUp: widget.onTap == null
            ? null
            : (_) {
                _setDown(false);
                HapticFeedback.selectionClick();
                widget.onTap?.call();
              },
        child: AnimatedScale(
          scale: _down ? 0.90 : 1.0,
          duration: const Duration(milliseconds: 110),
          curve: Curves.easeOutCubic,
          child: SizedBox(
            width: widget.size,
            height: widget.size,
            child: circle,
          ),
        ),
      ),
    );
  }
}
