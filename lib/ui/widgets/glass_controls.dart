// ignore_for_file: deprecated_member_use

import 'dart:ui' show ImageFilter;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_miuix/miuix.dart';

import '../glass/os4_glass_token.dart';
import '../glass/roam_glass.dart';
import '../glass/roam_glass_bridge.dart';
import '../../theme/roam_theme.dart';

/// 全局 miuix 背景采样器，供 MiuixGlass 使用。
/// 在 App 根部/页面根部用 MiuixLayerBackdropCapture 包住要采样的内容。
final miuixBackdrop = MiuixLayerBackdrop();

/// 材质显示效果的全局开关，由 App 在设置变化时写入。
///  - [material] 关闭后所有玻璃退回纯色，等同「材质显示效果」总开关。
///  - [rimLight] 对应「轮廓光材质」，关掉后不画玻璃边缘的高光。
///  - [edgeFade] 顶/底边缘的渐进模糊渐隐。
///  - [performance] 「高斯模糊效果」设为性能模式时关掉折射与边缘模糊。
///  - [customGlass] 玻璃引擎：true = 自绘 OS4 柔光玻璃（RoamGlass，
///    `shaders/roam_glass.frag`，commonSmallRegular 样式，默认）；
///    false = flutter_miuix 的 MiuixGlass（旧观感，可切换回来）。
///
/// Kyant 液态玻璃（fluid_glass）已整体移除：它的 `lens()` 是球面透镜，
/// 在 46dp 圆钮这类小控件上会把背景拉成一颗带色散条纹的玻璃球；而且
/// fragment shader 在 Impeller 下逐帧重算，滚动时明显掉帧。
abstract final class GlassRuntime {
  static final ValueNotifier<bool> material = ValueNotifier(true);
  static final ValueNotifier<bool> rimLight = ValueNotifier(true);
  static final ValueNotifier<bool> edgeFade = ValueNotifier(true);
  static final ValueNotifier<bool> performance = ValueNotifier(false);

  /// true = 自绘柔光玻璃（默认），false = miuix 玻璃。
  static final ValueNotifier<bool> customGlass = ValueNotifier(true);

  /// 模糊度倍率（仅自绘玻璃生效），0.5~2.0，1.0 为标准强度。
  static final ValueNotifier<double> blurScale = ValueNotifier(1.0);

  /// 旧版「玻璃透明程度」滑块的残留值，仅保留兼容读档，不再参与渲染。
  static final ValueNotifier<double> opacity = ValueNotifier(1.0);

  /// 所有玻璃参数的统一监听源，任一参数变化都触发重建。
  static final Listenable repaint = Listenable.merge([
    material,
    rimLight,
    edgeFade,
    performance,
    customGlass,
    blurScale,
  ]);

  /// 兼容旧调用点：直接赋值的写法。
  // ignore: unnecessary_getters_setters
  static set materialValue(bool v) => material.value = v;
}

/// 给可点击元素加一点“按下去会软一下”的反馈。
class PressableScale extends StatefulWidget {
  const PressableScale({
    super.key,
    required this.child,
    required this.onTap,
    this.scale = 0.94,
    this.behavior = HitTestBehavior.opaque,
    this.onLongPress,
  });

  final Widget child;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;
  final double scale;
  final HitTestBehavior behavior;

  @override
  State<PressableScale> createState() => _PressableScaleState();
}

class _PressableScaleState extends State<PressableScale> {
  bool _pressed = false;

  void _setPressed(bool value) {
    if (_pressed == value) return;
    setState(() => _pressed = value);
  }

  @override
  Widget build(BuildContext context) {
    final enabled = widget.onTap != null || widget.onLongPress != null;
    return GestureDetector(
      behavior: widget.behavior,
      onTapDown: enabled ? (_) => _setPressed(true) : null,
      onTapCancel: enabled ? () => _setPressed(false) : null,
      onTapUp: enabled
          ? (_) {
              _setPressed(false);
              HapticFeedback.selectionClick();
              widget.onTap?.call();
            }
          : null,
      onLongPress: widget.onLongPress,
      child: AnimatedScale(
        scale: _pressed ? widget.scale : 1,
        duration: const Duration(milliseconds: 160),
        curve: Curves.easeOutCubic,
        child: widget.child,
      ),
    );
  }
}

/// 弹层/对话框用的柔光玻璃面板。
///
/// 这里用 [BackdropFilter] 而不是 OS4 折射 shader，理由是弹层走
/// Navigator 压栈、采样源常常是下层页面的快照（网页 tab 下 WebView
/// 是 platform view，根本不进快照），折射会算出脏纹理。模糊 + 磨砂
/// 底色在 Impeller 上是原生路径，滚动和动画都稳。
class RoamGlassPanel extends StatelessWidget {
  const RoamGlassPanel({
    super.key,
    required this.child,
    this.borderRadius = const BorderRadius.all(Radius.circular(26)),
    this.surfaceColor,
    this.sigma = 26,
    this.forceDark,
  });

  final Widget child;
  final BorderRadius borderRadius;
  final Color? surfaceColor;
  final double sigma;
  final bool? forceDark;

  @override
  Widget build(BuildContext context) {
    final isDark =
        forceDark ?? (Theme.of(context).brightness == Brightness.dark);
    final tint =
        surfaceColor ??
        (isDark
            ? Colors.white.withValues(alpha: 0.10)
            : Colors.white.withValues(alpha: 0.86));

    if (!GlassRuntime.material.value || GlassRuntime.performance.value) {
      return ClipRRect(
        borderRadius: borderRadius,
        child: ColoredBox(
          color: isDark ? RoamColors.cardDark : RoamColors.cardLight,
          child: child,
        ),
      );
    }

    final body = ClipRRect(
      borderRadius: borderRadius,
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: sigma, sigmaY: sigma),
        child: DecoratedBox(
          // OS4 三层材质：左上高光 → 底部略沉，避免整块纯色像贴纸。
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                Color.alphaBlend(
                  Colors.white.withValues(alpha: isDark ? 0.06 : 0.12),
                  tint,
                ),
                tint,
                Color.alphaBlend(
                  Colors.black.withValues(alpha: isDark ? 0.10 : 0.02),
                  tint,
                ),
              ],
              stops: const [0, 0.55, 1],
            ),
          ),
          child: child,
        ),
      ),
    );

    // 描边放在裁剪外面，圆角处不会缺一条。
    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: borderRadius,
        border: Border.all(
          color: isDark
              ? Colors.white.withValues(alpha: 0.14)
              : Colors.white.withValues(alpha: 0.9),
          width: 0.9,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.36 : 0.08),
            blurRadius: 28,
            offset: const Offset(0, 12),
          ),
        ],
      ),
      child: body,
    );
  }
}

/// 页面里承载内容的玻璃面。
///
/// 三种形态：
///  - [miuixSolid] = false + `GlassRuntime.customGlass`：自绘 OS4 柔光
///    玻璃（[RoamGlass] + `roam_glass.frag`，commonSmallRegular）。
///  - [miuixSolid] = false + 旧引擎：flutter_miuix 的 MiuixGlass。
///  - [miuixSolid] = true：白色实心胶囊（不带折射），用于搜索栏、
///    顶栏圆钮这类「系统本来就是实色」的控件。
class RoamGlassSurface extends StatelessWidget {
  const RoamGlassSurface({
    super.key,
    required this.child,
    this.miuixLayer,
    this.radius = 18,
    this.capsule = false,
    this.surfaceColor,
    this.miuixSolid = false,
    this.forceDark,
  });

  /// miuix 柔光玻璃的采样源；默认用全局 [miuixBackdrop]。
  /// 页面级玻璃（如设置页搜索框）传入页面自持的局部捕获器，
  /// 避免压栈路由采到下层页面的陈旧纹理（OS4：foreground 与 capture 为兄弟节点）。
  final MiuixLayerBackdrop? miuixLayer;
  final Widget child;
  final double radius;
  final bool capsule;
  final Color? surfaceColor;

  /// 实心模式：白色 surface + 细边 + 轻投影，不跑折射 shader。
  final bool miuixSolid;

  /// 强制按深色渲染（首页有壁纸时用：壁纸上的玻璃要深底白字）。
  ///
  /// 必须是**逐控件**传入，不能再用全局开关：首页有壁纸时会把全局值
  /// 置成深色，一旦用户从首页 Push 到设置页，二级页顶栏也跟着变白字，
  /// 白字打在浅色底上直接看不见。
  final bool? forceDark;

  @override
  Widget build(BuildContext context) {
    // 玻璃参数（材质/轮廓光/深色）变化时实时重建
    return ListenableBuilder(
      listenable: GlassRuntime.repaint,
      builder: (context, _) => _buildSurface(context),
    );
  }

  Widget _buildSurface(BuildContext context) {
    final isDark =
        forceDark ?? (Theme.of(context).brightness == Brightness.dark);
    final clipRadius = capsule ? 999.0 : radius;

    if (!GlassRuntime.material.value || GlassRuntime.performance.value) {
      return Container(
        decoration: BoxDecoration(
          color: isDark ? RoamColors.cardDark : RoamColors.cardLight,
          borderRadius: BorderRadius.circular(clipRadius),
        ),
        clipBehavior: Clip.antiAlias,
        child: child,
      );
    }

    // 实心态：MIUI 的栏按钮/搜索栏本身就是实色 surface（白底 + 细边 +
    // 轻投影），不是实时模糊玻璃。这里不能走 MiuixGlass 的 fill——
    // 那个参数只在快照为空时生效，有快照时会改走「模糊 + 混色」，
    // 圆钮会变成一团半透明灰雾。
    if (miuixSolid) {
      return Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(clipRadius),
          color:
              surfaceColor ??
              (isDark
                  ? Colors.white.withValues(alpha: 0.14)
                  : Colors.white.withValues(alpha: 0.96)),
          border: Border.all(
            color: isDark
                ? Colors.white.withValues(alpha: 0.10)
                : Colors.white.withValues(alpha: 0.9),
            width: 0.8,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: isDark ? 0.30 : 0.08),
              blurRadius: 14,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        clipBehavior: Clip.antiAlias,
        child: child,
      );
    }

    // 自绘 OS4 柔光玻璃（默认引擎）：commonSmallRegular 是系统
    // 「通用小号常规」档，真机像素对齐时用的就是这套参数。
    // 采样源仍是 miuix 的 MiuixLayerBackdrop，桥接层负责把原始快照
    // 预模糊成 roam_glass.frag 需要的双纹理。
    if (GlassRuntime.customGlass.value) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(clipRadius),
        child: RoamGlassSceneBridge(
          backdrop: miuixLayer ?? miuixBackdrop,
          blurScale: GlassRuntime.blurScale.value,
          child: RoamGlass(
            token: Os4GlassToken.commonSmallRegular,
            radius: clipRadius,
            fallbackColor: surfaceColor,
            child: child,
          ),
        ),
      );
    }

    // miuix 玻璃（可切换回的旧引擎）：仿生 GlassStyle（折射/反射/方向光）。
    // commonSmallThin 是薄玻璃原版参数，但它的 blend.saturation=2.0
    // 会把背景色彩翻倍，这里压到 1.15。
    // alpha 保持默认 1.0——它在 OS4 里是「淡入动画进度」而非透明度，
    // 传 0.86 会让整层降不透明度、壁纸直通，叠出「染色玻璃」。
    final base = MiuixGlassStyles.commonSmallThin;
    return ClipRRect(
      borderRadius: BorderRadius.circular(clipRadius),
      // 用 MiuixGlass 而不是 MiuixGlassPanel：后者默认带 regular 投影，
      // 纯色/深色底上会糊出一圈灰色雾块，看起来像渲染错位。
      child: MiuixGlass(
        backdrop: miuixLayer ?? miuixBackdrop,
        style: base.copyWith(blend: base.blend.copyWith(saturation: 1.15)),
        shading: true,
        shape: MiuixGlassShape(borderRadius: BorderRadius.circular(clipRadius)),
        child: child,
      ),
    );
  }
}

/// 首页快捷方式的小图标块，用站点主色做一个柔和的渐变。
class SiteGlyph extends StatelessWidget {
  const SiteGlyph({
    super.key,
    required this.label,
    required this.color,
    this.size = 46,
    this.icon,
  });

  final String label;
  final Color color;
  final double size;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(size * 0.32),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            color.withValues(alpha: 0.95),
            Color.lerp(color, Colors.black, 0.28) ?? color,
          ],
        ),
        border: Border.all(color: Colors.white.withValues(alpha: 0.22)),
        boxShadow: [
          BoxShadow(
            color: color.withValues(alpha: 0.32),
            blurRadius: 14,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Center(
        child: icon != null
            ? Icon(icon, color: Colors.white, size: size * 0.46)
            : Text(
                label,
                style: TextStyle(
                  color: Colors.white,
                  fontSize: size * 0.40,
                  height: 1,
                  fontWeight: FontWeight.w700,
                ),
              ),
      ),
    );
  }
}

/// 页面内的小标题。
class SectionLabel extends StatelessWidget {
  const SectionLabel({super.key, required this.text, this.trailing});

  final String text;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 18, 4, 10),
      child: Row(
        children: [
          Text(
            text,
            style: RoamType.caption.copyWith(
              color: isDark
                  ? RoamColors.textSecondary
                  : RoamColors.daySecondary,
              letterSpacing: 1.4,
              fontWeight: FontWeight.w700,
            ),
          ),
          const Spacer(),
          ?trailing,
        ],
      ),
    );
  }
}
