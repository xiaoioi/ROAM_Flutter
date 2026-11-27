// ignore_for_file: deprecated_member_use

import 'package:flutter/material.dart';
import 'package:flutter_miuix/miuix.dart';

import '../../theme/roam_theme.dart';
import 'glass_controls.dart';
import 'predictive_back.dart';
import 'roam_backdrop_scope.dart';
import 'roam_popup_glass.dart';

/// 星环统一的底部玻璃面板：`miuix` 的 GlassBottomSheet 表面 + 顶部圆角。
///
/// 表面走 [RoamPopupGlass]：整块面板一层实时高斯，上面叠 miuix 的
/// dialogGlass 材质色与 forTheme 高光描边。不采样页面快照——弹层压的是新
/// 路由，快照在网页 tab 上还抓不到 WebView；实时模糊在两种场景下都成立，
/// 而且模糊范围就是面板范围，不会只糊一块。
Future<T?> showRoamSheet<T>({
  required BuildContext context,
  required String title,
  String? subtitle,
  required List<Widget> children,
  double maxHeightFactor = 0.84,
  bool isDismissible = true,
}) {
  // 弹层压的是新路由，读不到页面自己的捕获器，先取一次交给官方表面。
  final backdrop = RoamBackdropScope.samplingOf(context);
  return showModalBottomSheet<T>(
    context: context,
    useRootNavigator: true,
    isScrollControlled: true,
    useSafeArea: true,
    isDismissible: isDismissible,
    backgroundColor: Colors.transparent,
    // miuix GlassDialog / GlassBottomSheet 的遮罩色，不要自己调深。
    barrierColor: MiuixGlassDialogDefaults.scrimColor,
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
            backdrop: backdrop,
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

/// 底部弹出框的玻璃表面：整块实时高斯 + miuix 弹层材质与高光描边。
///
/// 所有底部弹出框（[showRoamSheet]、菜单、搜索、许可协议、主界面设置）都用它，
/// 保证圆角、描边、模糊是一家。
class RoamGlassSheetSurface extends StatelessWidget {
  const RoamGlassSheetSurface({
    super.key,
    required this.child,
    this.backdrop,
    this.forceDark,
  });

  final Widget child;

  /// 页面级背景采样源；由 [showRoamSheet] 从 [RoamBackdropScope] 取。
  final MiuixBackdrop? backdrop;

  /// 强制按深色渲染（首页壁纸上的抽屉：壁纸上的玻璃要深底白字）。
  final bool? forceDark;

  @override
  Widget build(BuildContext context) {
    return RoamPopupGlass(
      backdrop: backdrop,
      forceDark: forceDark,
      child: child,
    );
  }
}

/// miuix 的拖拽手柄：24dp 高的触区里放 45×4 的小白条，按下放大到 55×4.6。
class RoamSheetHandle extends StatefulWidget {
  const RoamSheetHandle({super.key});

  @override
  State<RoamSheetHandle> createState() => _RoamSheetHandleState();
}

class _RoamSheetHandleState extends State<RoamSheetHandle> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTapDown: (_) => setState(() => _pressed = true),
      onTapUp: (_) => setState(() => _pressed = false),
      onTapCancel: () => setState(() => _pressed = false),
      child: SizedBox(
        height: 24,
        width: double.infinity,
        child: Center(
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 160),
            curve: Curves.easeOutCubic,
            width: _pressed ? 55 : 45,
            height: _pressed ? 4.6 : 4,
            decoration: BoxDecoration(
              color: MiuixBottomSheetDefaults.dragHandleColor(context),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
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
