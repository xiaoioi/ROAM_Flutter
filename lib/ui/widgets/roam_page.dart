// ignore_for_file: deprecated_member_use

import 'package:flutter/material.dart';

import '../../theme/roam_theme.dart';
import 'glass_controls.dart';
import 'hyperos_top_bar.dart';
import 'roam_chrome.dart';

/// 全屏二级页的统一外壳：星空背景 + 原版 60dp 柔光玻璃顶栏。
class RoamPage extends StatelessWidget {
  const RoamPage({
    super.key,
    required this.title,
    this.subtitle,
    this.actions = const <HyperosBarAction>[],
    required this.child,
  });

  final String title;
  final String? subtitle;
  final List<HyperosBarAction> actions;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return RoamPageScaffold(
      title: title,
      actions: actions,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // 悬浮顶栏（64dp）：内容从状态栏下开始时先让出这条。
          const SizedBox(height: RoamPageScaffold.barHeight),
          if (subtitle != null)
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 10, 20, 2),
              child: Text(
                subtitle!,
                style: RoamType.caption.copyWith(
                  fontSize: 12,
                  color: Theme.of(context).brightness == Brightness.dark
                      ? RoamColors.textTertiary
                      : RoamColors.daySecondary,
                ),
              ),
            ),
          Expanded(child: child),
        ],
      ),
    );
  }
}

/// 空状态：一枚图标、一句说明和一个可选动作。
class RoamEmptyState extends StatelessWidget {
  const RoamEmptyState({
    super.key,
    required this.icon,
    required this.title,
    required this.message,
    this.actionLabel,
    this.onAction,
  });

  final IconData icon;
  final String title;
  final String message;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 40),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 64,
              height: 64,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(22),
                color: RoamColors.aurora.withValues(
                  alpha: isDark ? 0.12 : 0.10,
                ),
                border: Border.all(
                  color: RoamColors.aurora.withValues(alpha: 0.24),
                ),
              ),
              child: Icon(icon, size: 28, color: RoamColors.aurora),
            ),
            const SizedBox(height: 16),
            Text(
              title,
              textAlign: TextAlign.center,
              style: RoamType.title.copyWith(
                fontSize: 16,
                color: isDark ? RoamColors.textPrimary : RoamColors.dayInk,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              message,
              textAlign: TextAlign.center,
              style: RoamType.body.copyWith(
                fontSize: 13,
                color: isDark
                    ? RoamColors.textSecondary
                    : RoamColors.daySecondary,
              ),
            ),
            if (actionLabel != null) ...[
              const SizedBox(height: 18),
              PressableScale(
                onTap: onAction,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 18,
                    vertical: 10,
                  ),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(999),
                    color: RoamColors.aurora.withValues(alpha: 0.16),
                    border: Border.all(
                      color: RoamColors.aurora.withValues(alpha: 0.4),
                    ),
                  ),
                  child: Text(
                    actionLabel!,
                    style: RoamType.caption.copyWith(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w600,
                      color: RoamColors.aurora,
                    ),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
