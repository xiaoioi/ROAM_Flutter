// ignore_for_file: deprecated_member_use

import 'package:flutter/material.dart';
import 'package:flutter_miuix/miuix.dart';

import '../../models/browser_models.dart';
import '../../state/browser_controller.dart';
import '../../theme/roam_theme.dart';
import '../widgets/confirm.dart';
import '../widgets/glass_controls.dart';
import '../widgets/roam_chrome.dart';
import '../widgets/hyperos_top_bar.dart';

/// 书签管理。
/// 取自 pages/BookmarkSettings/main.lua：顶栏 60dp + 右侧“添加”，
/// 分组标题「管理书签」15sp/左边距 25dp，条目卡片圆角 15dp、上下间距 5.2dp，
/// 右下角 55dp 圆形删除按钮（右 25 / 下 40）。
class BookmarksPage extends StatelessWidget {
  const BookmarksPage({super.key, required this.controller});

  final BrowserController controller;

  Future<void> _add(BuildContext context) async {
    final titleController = TextEditingController();
    final urlController = TextEditingController();
    final created = await showRoamDialog<bool>(
      context: context,
      title: '添加书签',
      body: Padding(
        padding: const EdgeInsets.only(top: 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _GlassField(controller: titleController, hint: '标题'),
            const SizedBox(height: 10),
            _GlassField(
              controller: urlController,
              hint: '链接',
              keyboardType: TextInputType.url,
            ),
          ],
        ),
      ),
      actions: const [
        RoamDialogAction(label: '取消', value: false),
        RoamDialogAction(label: '确定', value: true, primary: true),
      ],
    );
    if (created == true && urlController.text.trim().isNotEmpty) {
      await controller.addBookmark(titleController.text, urlController.text);
    }
    titleController.dispose();
    urlController.dispose();
  }

  Future<void> _clearAll(BuildContext context) async {
    final confirmed = await showRoamConfirm(
      context: context,
      title: '删除全部书签',
      message: '要删除全部书签吗？删除后无法恢复。',
      confirmLabel: '全部删除',
      destructive: true,
    );
    if (confirmed) {
      await controller.clearBrowsingData(bookmarks: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: controller,
      builder: (context, _) {
        final bookmarks = controller.bookmarks;
        return RoamPageScaffold(
          title: '书签管理',
          actions: [
            HyperosBarAction(
              asset: 'assets/images/add.png',
              tooltip: '添加书签',
              // add.png 墨迹只占画布 59%，28dp 才是系统里加号的视觉大小
              iconSize: 28,
              onTap: () => _add(context),
            ),
          ],
          child: Stack(
            children: [
              ListView(
                padding: EdgeInsets.only(
                  top: RoamPageScaffold.contentTopPadding + 6,
                  bottom: 120,
                ),
                physics: const BouncingScrollPhysics(),
                children: [
                  const RoamGroupHeader(text: '管理书签', left: 25),
                  if (bookmarks.isEmpty)
                    const _EmptyBookmarks()
                  else
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 25),
                      child: Column(
                        children: [
                          for (final bookmark in bookmarks)
                            _BookmarkRow(
                              bookmark: bookmark,
                              onOpen: () {
                                controller.openAddress(bookmark.url);
                                Navigator.of(context)
                                    .popUntil((route) => route.isFirst);
                              },
                              onDelete: () =>
                                  controller.removeBookmark(bookmark.id),
                            ),
                        ],
                      ),
                    ),
                  const RoamGroupHeader(text: '恢复或导入书签', left: 25),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 25),
                    child: RoamSettingCard(
                      margin: EdgeInsets.zero,
                      children: [
                        RoamSettingRow(
                          icon: 'assets/images/backup.png',
                          label: '备份与恢复',
                          onTap: () => _showBackupHint(context),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              if (bookmarks.isNotEmpty)
                RoamGlassFab(
                  icon: 'assets/images/delete.png',
                  tooltip: '删除全部书签',
                  onTap: () => _clearAll(context),
                ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _showBackupHint(BuildContext context) async {
    await showRoamConfirm(
      context: context,
      title: '备份与恢复',
      message: '书签已保存在本机 Roam 数据目录，重装应用前可先导出备份。',
      confirmLabel: '知道了',
      cancelLabel: '关闭',
    );
  }
}

class _EmptyBookmarks extends StatelessWidget {
  const _EmptyBookmarks();

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 60),
      child: Column(
        children: [
          Image.asset(
            'assets/images/bookmark.png',
            width: 48,
            height: 48,
            color: (isDark ? RoamColors.textPrimary : RoamColors.dayInk)
                .withValues(alpha: 0.22),
          ),
          const SizedBox(height: 14),
          Text(
            '没有书签',
            style: TextStyle(
              fontSize: 15,
              color: (isDark ? RoamColors.textPrimary : RoamColors.dayInk)
                  .withValues(alpha: 0.45),
            ),
          ),
        ],
      ),
    );
  }
}

class _BookmarkRow extends StatelessWidget {
  const _BookmarkRow({
    required this.bookmark,
    required this.onOpen,
    required this.onDelete,
  });

  final Bookmark bookmark;
  final VoidCallback onOpen;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final fg = isDark ? RoamColors.textPrimary : RoamColors.dayInk;
    return Dismissible(
      key: ValueKey(bookmark.id),
      direction: DismissDirection.endToStart,
      background: Container(
        margin: const EdgeInsets.only(top: 5.2, bottom: 5.2),
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(15),
          color: RoamColors.danger.withValues(alpha: 0.16),
        ),
        child: const Icon(
          Icons.delete_rounded,
          color: RoamColors.danger,
          size: 19,
        ),
      ),
      onDismissed: (_) => onDelete(),
      child: RoamListCard(
        radius: 15,
        margin: const EdgeInsets.only(top: 5.2, bottom: 5.2),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
        onTap: onOpen,
        child: Row(
          children: [
            SiteGlyph(
              label: _initial(bookmark.title, bookmark.url),
              color: RoamColors.iris,
              size: 30,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    bookmark.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(fontSize: 15, color: fg),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    bookmark.url,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 11.5,
                      color: fg.withValues(alpha: 0.45),
                    ),
                  ),
                ],
              ),
            ),
            PressableScale(
              onTap: onDelete,
              scale: 0.86,
              child: Padding(
                padding: const EdgeInsets.only(left: 6),
                child: Image.asset(
                  'assets/images/delete.png',
                  width: 18,
                  height: 18,
                  color: fg.withValues(alpha: 0.32),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  static String _initial(String title, String url) {
    if (title.trim().isNotEmpty) return title.trim().characters.first;
    final uri = Uri.tryParse(url);
    final host = uri?.host ?? url;
    return host.isEmpty ? '?' : host.characters.first.toUpperCase();
  }
}

class _GlassField extends StatelessWidget {
  const _GlassField({
    required this.controller,
    required this.hint,
    this.keyboardType,
  });

  final TextEditingController controller;
  final String hint;
  final TextInputType? keyboardType;

  @override
  Widget build(BuildContext context) {
    return MiuixTextField(
      controller: controller,
      keyboardType: keyboardType,
      singleLine: true,
      label: hint,
      useLabelAsPlaceholder: true,
      textInputAction: TextInputAction.next,
    );
  }
}
