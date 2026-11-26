// ignore_for_file: deprecated_member_use

import 'package:flutter/material.dart';

import '../../theme/roam_theme.dart';
import 'glass_controls.dart';
import 'predictive_back.dart';

/// 星环统一的底部玻璃面板：圆角只留在顶部，内容超出时可滚动。
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
          child: RoamGlassPanel(
            borderRadius: const BorderRadius.vertical(top: Radius.circular(30)),
            surfaceColor: isDark
                ? const Color(0xFF0B1424).withValues(alpha: 0.80)
                : Colors.white.withValues(alpha: 0.86),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const _SheetHandle(),
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

class _SheetHandle extends StatelessWidget {
  const _SheetHandle();

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Padding(
      padding: const EdgeInsets.only(top: 10, bottom: 4),
      child: Container(
        width: 38,
        height: 4,
        decoration: BoxDecoration(
          color: (isDark ? Colors.white : Colors.black).withValues(alpha: 0.22),
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
