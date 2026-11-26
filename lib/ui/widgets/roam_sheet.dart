// ignore_for_file: deprecated_member_use

import 'dart:ui' show ImageFilter;

import 'package:flutter/material.dart';
import 'package:flutter_miuix/miuix.dart';

import '../../theme/roam_theme.dart';
import 'glass_controls.dart';
import 'predictive_back.dart';

/// 星环统一的底部玻璃面板：`miuix` 的 GlassBottomSheet 表面 + 顶部圆角。
///
/// 表面直接取 flutter_miuix `GlassBottomSheet` 的那一套：
/// [MiuixGlassBottomSheetDefaults.material]（dialogGlass 三层材质）、
/// [MiuixGlassBottomSheetDefaults.stroke]（forTheme 高光描边）、
/// [MiuixBottomSheetDefaults.cornerRadius] 的顶部圆角。区别只在于
/// 面板底下多垫了一层实时高斯模糊——网页 / 设置页都能透出真实背景，
/// 而不是采样一份可能已经过期的快照（WebView 是 platform view，录不进快照）。
Future<T?> showRoamSheet<T>({
  required BuildContext context,
  required String title,
  String? subtitle,
  required List<Widget> children,
  double maxHeightFactor = 0.84,
  bool isDismissible = true,
}) {
  final isDark = Theme.of(context).brightness == Brightness.dark;
  return showModalBottomSheet<T>(
    context: context,
    useRootNavigator: true,
    isScrollControlled: true,
    useSafeArea: true,
    isDismissible: isDismissible,
    backgroundColor: Colors.transparent,
    barrierColor: Colors.black.withValues(alpha: isDark ? 0.46 : 0.28),
    elevation: 0,
    builder: (sheetContext) {
      final maxHeight =
          MediaQuery.sizeOf(sheetContext).height * maxHeightFactor;
      return PredictiveBackScope(
        style: PredictiveBackStyle.sheet,
        onCommit: () => Navigator.of(sheetContext).maybePop(),
        child: ConstrainedBox(
          constraints: BoxConstraints(maxHeight: maxHeight),
          child: RoamGlassSheetSurface(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const RoamSheetHandle(),
                _SheetHeader(title: title, subtitle: subtitle),
                Flexible(
                  child: SingleChildScrollView(
                    physics: const BouncingScrollPhysics(),
                    padding: EdgeInsets.fromLTRB(
                      14,
                      2,
                      14,
                      14 + MediaQuery.paddingOf(sheetContext).bottom,
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      mainAxisSize: MainAxisSize.min,
                      children: children,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    },
  );
}

/// miuix GlassBottomSheet 的玻璃表面。
///
/// 所有底部弹出框（[showRoamSheet]、菜单、搜索、许可协议、主界面设置）都用它，
/// 保证圆角、描边、材质、模糊是一家。`GlassRuntime.performance` 打开时
/// 跳过实时模糊，只留玻璃底与描边，避免低端机上每次拖动都重算背景。
class RoamGlassSheetSurface extends StatelessWidget {
  const RoamGlassSheetSurface({
    super.key,
    required this.child,
    this.radius = MiuixBottomSheetDefaults.cornerRadius,
    this.sigma = 30,
    this.forceDark,
  });

  final Widget child;
  final double radius;
  final double sigma;

  /// 强制按深色渲染（首页壁纸上的抽屉：壁纸上的玻璃要深底白字）。
  final bool? forceDark;

  @override
  Widget build(BuildContext context) {
    final isDark =
        forceDark ?? (Theme.of(context).brightness == Brightness.dark);
    final borderRadius = BorderRadius.vertical(top: Radius.circular(radius));
    final shape = MiuixGlassShape(borderRadius: borderRadius);

    // 材质总开关 / 性能模式：不跑实时模糊，保留 miuix 的玻璃底与描边。
    final blur =
        GlassRuntime.material.value && !GlassRuntime.performance.value;

    // OS4 三层材质：左上高光 → 底色 → 底部略沉，和 GlassBottomSheet 一致。
    final tint = isDark
        ? const Color(0xFF101318).withValues(alpha: 0.82)
        : Colors.white.withValues(alpha: 0.88);

    Widget body = DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color.alphaBlend(
              Colors.white.withValues(alpha: isDark ? 0.05 : 0.10),
              tint,
            ),
            tint,
            Color.alphaBlend(
              Colors.black.withValues(alpha: isDark ? 0.12 : 0.02),
              tint,
            ),
          ],
          stops: const [0, 0.55, 1],
        ),
      ),
      child: child,
    );
    if (blur) {
      body = BackdropFilter(
        filter: ImageFilter.blur(sigmaX: sigma, sigmaY: sigma),
        child: body,
      );
    }

    return ClipRRect(
      borderRadius: borderRadius,
      child: MiuixGlassPanel(
        shape: shape,
        material: MiuixGlassBottomSheetDefaults.material(context),
        stroke: MiuixGlassBottomSheetDefaults.stroke(context),
        // 底色由上面那层 tint 负责（要压在实时模糊之上），这里不再叠一次。
        fill: Colors.transparent,
        shadow: null,
        shading: false,
        child: body,
      ),
    );
  }
}

/// miuix 尺寸的拖拽手柄：45×4，按下时 55×4.6。
class RoamSheetHandle extends StatelessWidget {
  const RoamSheetHandle({super.key});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 10, bottom: 4),
      child: Container(
        width: 45,
        height: 4,
        decoration: BoxDecoration(
          color: MiuixBottomSheetDefaults.dragHandleColor(context),
          borderRadius: BorderRadius.circular(4),
        ),
      ),
    );
  }
}

class _SheetHeader extends StatelessWidget {
  const _SheetHeader({required this.title, this.subtitle});

  final String title;
  final String? subtitle;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 8, 12, 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  title,
                  style: RoamType.title.copyWith(
                    color: isDark ? RoamColors.textPrimary : RoamColors.dayInk,
                  ),
                ),
                if (subtitle != null) ...[
                  const SizedBox(height: 3),
                  Text(
                    subtitle!,
                    style: RoamType.caption.copyWith(
                      color: isDark
                          ? RoamColors.textSecondary
                          : RoamColors.daySecondary,
                    ),
                  ),
                ],
              ],
            ),
          ),
          PressableScale(
            onTap: () => Navigator.of(context).maybePop(),
            child: Padding(
              padding: const EdgeInsets.all(10),
              child: Icon(
                Icons.close_rounded,
                size: 20,
                color: isDark
                    ? RoamColors.textSecondary
                    : RoamColors.daySecondary,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// 面板里的一行：图标 + 标题 + 副标题 + 尾部组件。
class RoamSheetRow extends StatelessWidget {
  const RoamSheetRow({
    super.key,
    required this.icon,
    required this.title,
    this.subtitle,
    this.trailing,
    this.onTap,
    this.destructive = false,
    this.showDivider = true,
    this.iconColor,
  });

  final IconData icon;
  final String title;
  final String? subtitle;
  final Widget? trailing;
  final VoidCallback? onTap;
  final bool destructive;
  final bool showDivider;
  final Color? iconColor;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primary = destructive
        ? RoamColors.danger
        : (isDark ? RoamColors.textPrimary : RoamColors.dayInk);
    final secondary = isDark
        ? RoamColors.textSecondary
        : RoamColors.daySecondary;
    final accent = iconColor ?? RoamColors.aurora;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        PressableScale(
          onTap: onTap,
          scale: 0.985,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 9),
            child: Row(
              children: [
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(12),
                    color: (destructive ? RoamColors.danger : accent)
                        .withValues(alpha: isDark ? 0.16 : 0.12),
                  ),
                  child: Icon(
                    icon,
                    size: 18,
                    color: destructive ? RoamColors.danger : accent,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        title,
                        style: RoamType.body.copyWith(
                          color: primary,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      if (subtitle != null) ...[
                        const SizedBox(height: 2),
                        Text(
                          subtitle!,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: RoamType.caption.copyWith(color: secondary),
                        ),
                      ],
                    ],
                  ),
                ),
                if (trailing != null) ...[
                  const SizedBox(width: 10),
                  trailing!,
                ] else if (onTap != null)
                  Icon(
                    Icons.chevron_right_rounded,
                    size: 19,
                    color: secondary.withValues(alpha: 0.75),
                  ),
              ],
            ),
          ),
        ),
        if (showDivider)
          Padding(
            padding: const EdgeInsets.only(left: 54),
            child: Divider(
              height: 1,
              color: (isDark ? Colors.white : Colors.black).withValues(
                alpha: 0.06,
              ),
            ),
          ),
      ],
    );
  }
}

/// 面板内的分组标题。
class RoamSheetSection extends StatelessWidget {
  const RoamSheetSection({super.key, required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Padding(
      padding: const EdgeInsets.fromLTRB(10, 16, 10, 6),
      child: Text(
        label,
        style: RoamType.caption.copyWith(
          color: isDark ? RoamColors.textTertiary : RoamColors.daySecondary,
          letterSpacing: 1.2,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}
