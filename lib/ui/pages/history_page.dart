// ignore_for_file: deprecated_member_use

import 'package:flutter/material.dart';

import '../../models/browser_models.dart';
import '../../state/browser_controller.dart';
import '../../theme/roam_theme.dart';
import '../widgets/confirm.dart';
import '../widgets/glass_controls.dart';
import '../widgets/roam_chrome.dart';
import '../widgets/hyperos_top_bar.dart';
import '../widgets/roam_sheet.dart';

/// 历史记录管理。
/// 布局取自反编译的 pages/History/main.lua：
/// 顶栏 60dp / 标题 19sp bold / 右侧 dots 菜单，列表左右 25dp，
/// 条目卡片圆角 12dp、内边距 5dp，条目标题 12sp（alpha 0.8）。
class HistoryPage extends StatelessWidget {
  const HistoryPage({super.key, required this.controller});

  final BrowserController controller;

  Future<void> _clearAll(BuildContext context) async {
    Navigator.of(context).pop();
    final confirmed = await showRoamConfirm(
      context: context,
      title: '删除全部历史记录',
      message: '删除后无法恢复，书签与已下载的文件不受影响。',
      confirmLabel: '删除',
      destructive: true,
    );
    if (!confirmed) return;
    await controller.clearHistory();
  }

  Future<void> _menu(BuildContext context) async {
    await showRoamSheet<void>(
      context: context,
      title: '功能选项',
      children: [
        _SheetRow(
          icon: 'assets/images/delete.png',
          label: '删除全部历史记录',
          destructive: true,
          onTap: () => _clearAll(context),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: controller,
      builder: (context, _) {
        final entries = controller.history;
        return RoamPageScaffold(
          title: '历史记录管理',
          actions: [
            HyperosBarAction(
              asset: 'assets/images/dots.png',
              tooltip: '功能选项',
              onTap: () => _menu(context),
            ),
          ],
          child: entries.isEmpty
              ? const _EmptyHistory()
              : _HistoryList(
                  entries: entries,
                  onOpen: (url) {
                    controller.openAddress(url);
                    Navigator.of(context).popUntil((route) => route.isFirst);
                  },
                  onDelete: controller.removeHistoryEntry,
                ),
        );
      },
    );
  }
}

class _EmptyHistory extends StatelessWidget {
  const _EmptyHistory();

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Center(
      child: Padding(
        padding: const EdgeInsets.only(bottom: 40),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Image.asset(
              'assets/images/history.png',
              width: 48,
              height: 48,
              color: (isDark ? RoamColors.textPrimary : RoamColors.dayInk)
                  .withValues(alpha: 0.22),
            ),
            const SizedBox(height: 14),
            Text(
              '没有历史记录',
              style: TextStyle(
                fontSize: 15,
                color: (isDark ? RoamColors.textPrimary : RoamColors.dayInk)
                    .withValues(alpha: 0.45),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _HistoryList extends StatelessWidget {
  const _HistoryList({
    required this.entries,
    required this.onOpen,
    required this.onDelete,
  });

  final List<HistoryEntry> entries;
  final ValueChanged<String> onOpen;
  final ValueChanged<String> onDelete;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final rows = <Object>[];
    String? currentBucket;
    for (final entry in entries) {
      final bucket = _bucketOf(entry.visitedAt);
      if (bucket != currentBucket) {
        currentBucket = bucket;
        rows.add(bucket);
      }
      rows.add(entry);
    }

    return ListView.builder(
      padding: EdgeInsets.fromLTRB(
        25,
        RoamPageScaffold.topPadding(context) + 10,
        25,
        40,
      ),
      physics: const BouncingScrollPhysics(),
      itemCount: rows.length,
      itemBuilder: (context, index) {
        final row = rows[index];
        if (row is String) {
          return Padding(
            padding: EdgeInsets.fromLTRB(2, index == 0 ? 4 : 16, 2, 8),
            child: Text(
              row,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: (isDark ? RoamColors.textPrimary : RoamColors.dayInk)
                    .withValues(alpha: 0.55),
              ),
            ),
          );
        }
        final entry = row as HistoryEntry;
        return Dismissible(
          key: ValueKey(entry.id),
          direction: DismissDirection.endToStart,
          background: Container(
            margin: const EdgeInsets.only(top: 10, bottom: 10),
            alignment: Alignment.centerRight,
            padding: const EdgeInsets.only(right: 22),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              color: RoamColors.danger.withValues(alpha: 0.16),
            ),
            child: const Icon(
              Icons.delete_rounded,
              color: RoamColors.danger,
              size: 19,
            ),
          ),
          onDismissed: (_) => onDelete(entry.id),
          child: RoamListCard(
            radius: 12,
            margin: const EdgeInsets.only(top: 10, bottom: 10),
            padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 10),
            onTap: () => onOpen(entry.url),
            child: Row(
              children: [
                SizedBox(
                  width: 42,
                  child: Text(
                    _timeOf(entry.visitedAt),
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color:
                          (isDark ? RoamColors.textPrimary : RoamColors.dayInk)
                              .withValues(alpha: 0.8),
                    ),
                  ),
                ),
                Container(
                  width: 1,
                  height: 28,
                  margin: const EdgeInsets.symmetric(horizontal: 10),
                  color: (isDark ? Colors.white : Colors.black).withValues(
                    alpha: 0.08,
                  ),
                ),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        entry.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 15,
                          color: isDark
                              ? RoamColors.textPrimary
                              : RoamColors.dayInk,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        _host(entry.url),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 12,
                          color:
                              (isDark
                                      ? RoamColors.textPrimary
                                      : RoamColors.dayInk)
                                  .withValues(alpha: 0.45),
                        ),
                      ),
                    ],
                  ),
                ),
                PressableScale(
                  onTap: () => onDelete(entry.id),
                  scale: 0.86,
                  child: Padding(
                    padding: const EdgeInsets.only(left: 8),
                    child: Image.asset(
                      'assets/images/delete.png',
                      width: 18,
                      height: 18,
                      color:
                          (isDark ? RoamColors.textPrimary : RoamColors.dayInk)
                              .withValues(alpha: 0.35),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  static String _bucketOf(DateTime time) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final day = DateTime(time.year, time.month, time.day);
    final diff = today.difference(day).inDays;
    if (diff <= 0) return '今天';
    if (diff == 1) return '昨天';
    if (diff < 7) return '本周';
    return '${time.year} 年 ${time.month} 月 ${time.day} 日';
  }

  static String _timeOf(DateTime time) {
    String two(int value) => value.toString().padLeft(2, '0');
    return '${two(time.hour)}:${two(time.minute)}';
  }

  static String _host(String url) {
    final uri = Uri.tryParse(url);
    if (uri == null || uri.host.isEmpty) return url;
    return uri.host.startsWith('www.') ? uri.host.substring(4) : uri.host;
  }
}

/// 底部玻璃面板里的一行（历史、书签、下载共用样式）。
class _SheetRow extends StatelessWidget {
  const _SheetRow({
    required this.icon,
    required this.label,
    required this.onTap,
    this.destructive = false,
  });

  final String icon;
  final String label;
  final VoidCallback onTap;
  final bool destructive;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final color = destructive
        ? RoamColors.danger
        : (isDark ? RoamColors.textPrimary : RoamColors.dayInk);
    return PressableScale(
      onTap: onTap,
      scale: 0.99,
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: roamGlassDecoration(context, radius: 15, elevated: false),
        child: Row(
          children: [
            Image.asset(icon, width: 22, height: 22, color: color),
            const SizedBox(width: 12),
            Text(label, style: TextStyle(fontSize: 15, color: color)),
          ],
        ),
      ),
    );
  }
}
