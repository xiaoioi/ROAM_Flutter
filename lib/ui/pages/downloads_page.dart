// ignore_for_file: deprecated_member_use

import 'package:flutter/material.dart';
import 'package:flutter_miuix/miuix.dart';
import 'package:open_filex/open_filex.dart';

import '../../models/browser_models.dart';
import '../../state/browser_controller.dart';
import '../../theme/roam_theme.dart';
import '../widgets/confirm.dart';
import '../widgets/glass_controls.dart';
import '../widgets/roam_chrome.dart';
import '../widgets/hyperos_top_bar.dart';
import '../widgets/roam_sheet.dart';
import '../app_messenger.dart';

class DownloadsPage extends StatelessWidget {
  const DownloadsPage({super.key, required this.controller});

  final BrowserController controller;

  /// 打开下载文件。open_filex 目前只有 Android/iOS/桌面实现，
  /// 鸿蒙上会抛 MissingPluginException——兜底给出文件路径，别让点击无声失败。
  Future<void> _openFile(BuildContext context, DownloadEntry entry) async {
    try {
      await OpenFilex.open(entry.path);
    } catch (_) {
      if (!context.mounted) return;
      showRoamToast(
        '当前系统暂不支持直接打开，文件位置：${entry.path}',
        duration: const Duration(seconds: 4),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return AnimatedBuilder(
      animation: controller,
      builder: (context, _) {
        final items = controller.downloads;
        final s = controller.settings;
        return RoamPageScaffold(
          title: '下载管理',
          actions: [
            HyperosBarAction(
              asset: 'assets/images/dots.png',
              tooltip: '功能选项',
              onTap: () => _menu(context, items),
            ),
          ],
          child: Stack(
            children: [
              ListView(
                padding: EdgeInsets.only(
                  top: RoamPageScaffold.contentTopPadding + 2,
                  bottom: 110,
                ),
                physics: const BouncingScrollPhysics(),
                children: [
                  const RoamGroupHeader(text: '下载的文件'),
                  if (items.isEmpty)
                    const _EmptyDownloads()
                  else
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 25),
                      child: Column(
                        children: [
                          for (final entry in items)
                            Dismissible(
                              key: ValueKey(entry.id),
                              direction: DismissDirection.endToStart,
                              background: Container(
                                margin: const EdgeInsets.only(
                                  top: 5.2,
                                  bottom: 5.2,
                                ),
                                alignment: Alignment.centerRight,
                                padding: const EdgeInsets.only(right: 22),
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(15),
                                  color: RoamColors.danger.withValues(
                                    alpha: 0.16,
                                  ),
                                ),
                                child: const Icon(
                                  Icons.delete_rounded,
                                  color: RoamColors.danger,
                                  size: 19,
                                ),
                              ),
                              onDismissed: (_) =>
                                  controller.removeDownload(entry.id),
                              child: _DownloadTile(
                                entry: entry,
                                isDark: isDark,
                                onOpen: () => _openFile(context, entry),
                                onCancel: () =>
                                    controller.cancelDownload(entry.id),
                              ),
                            ),
                        ],
                      ),
                    ),
                  const RoamGroupHeader(text: '数据网络设置'),
                  RoamSettingCard(
                    children: [
                      RoamSettingRow(
                        icon: 'assets/images/stacks_hardware_turbo.png',
                        label: '使用5G/4G流量下载',
                        showChevron: false,
                        onTap: () => controller.updateSettings(
                          s.copyWith(downloadOnCellular: !s.downloadOnCellular),
                        ),
                        trailing: RoamSwitch(
                          value: s.downloadOnCellular,
                          onChanged: (v) => controller.updateSettings(
                            s.copyWith(downloadOnCellular: v),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const RoamGroupHeader(text: '文件下载设置'),
                  RoamSettingCard(
                    children: [
                      RoamSettingRow(
                        icon: 'assets/images/list.png',
                        label: '多下载任务智能排序',
                        showChevron: false,
                        onTap: () => controller.updateSettings(
                          s.copyWith(smartDownloadOrder: !s.smartDownloadOrder),
                        ),
                        trailing: RoamSwitch(
                          value: s.smartDownloadOrder,
                          onChanged: (v) => controller.updateSettings(
                            s.copyWith(smartDownloadOrder: v),
                          ),
                        ),
                      ),
                      RoamSettingRow(
                        icon: 'assets/images/bell.png',
                        label: '下载完成后通知我',
                        showChevron: false,
                        onTap: () => controller.updateSettings(
                          s.copyWith(
                            notifyOnDownloadComplete:
                                !s.notifyOnDownloadComplete,
                          ),
                        ),
                        trailing: RoamSwitch(
                          value: s.notifyOnDownloadComplete,
                          onChanged: (v) => controller.updateSettings(
                            s.copyWith(notifyOnDownloadComplete: v),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              Positioned(
                right: 25,
                bottom: 28,
                child: RoamGlassFab(
                  icon: 'assets/images/add.png',
                  tooltip: '新增下载',
                  onTap: () => _newTask(context),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _newTask(BuildContext context) async {
    final linkController = TextEditingController();
    final started = await showRoamDialog<bool>(
      context: context,
      title: '新建任务',
      body: Padding(
        padding: const EdgeInsets.only(top: 16),
        child: MiuixTextField(
          controller: linkController,
          keyboardType: TextInputType.url,
          singleLine: true,
          label: '链接',
          useLabelAsPlaceholder: true,
          textInputAction: TextInputAction.done,
        ),
      ),
      actions: const [
        RoamDialogAction(label: '取消下载', value: false),
        RoamDialogAction(label: '开始下载', value: true, primary: true),
      ],
    );
    if (started == true) {
      final link = linkController.text.trim();
      if (link.isNotEmpty) await controller.startDownload(link);
    }
    linkController.dispose();
  }

  Future<void> _menu(BuildContext context, List<DownloadEntry> items) async {
    await showRoamSheet<void>(
      context: context,
      title: '基础功能选项',
      children: [
        _DownloadSheetRow(
          icon: 'assets/images/delete.png',
          label: '清理缓存',
          destructive: true,
          onTap: () async {
            Navigator.of(context).pop();
            final confirmed = await showRoamConfirm(
              context: context,
              title: '清理缓存',
              message: '只清理下载记录，已经存到手机里的文件不会被删除。',
              confirmLabel: '清理',
              destructive: true,
            );
            if (confirmed) await controller.clearDownloadRecords();
          },
        ),
      ],
    );
  }
}

class _DownloadTile extends StatelessWidget {
  const _DownloadTile({
    required this.entry,
    required this.isDark,
    required this.onOpen,
    required this.onCancel,
  });

  final DownloadEntry entry;
  final bool isDark;
  final VoidCallback onOpen;
  final VoidCallback onCancel;

  @override
  Widget build(BuildContext context) {
    final accent = _accentFor(entry.fileName);
    final running = entry.status == DownloadStatus.running;
    final complete = entry.status == DownloadStatus.complete;
    final ratio = entry.totalBytes > 0
        ? (entry.receivedBytes / entry.totalBytes).clamp(0.0, 1.0)
        : null;
    final statusText = switch (entry.status) {
      DownloadStatus.running =>
        ratio == null
            ? '下载中 · ${_bytes(entry.receivedBytes)}'
            : '下载中 · ${(ratio * 100).toStringAsFixed(0)}%',
      DownloadStatus.complete => _bytes(entry.receivedBytes),
      DownloadStatus.failed =>
        '失败${entry.error == null ? '' : ' · ${_shortError(entry.error!)}'}',
      DownloadStatus.cancelled => '已取消',
    };

    return PressableScale(
      onTap: complete ? onOpen : null,
      scale: 0.985,
      child: Container(
        margin: const EdgeInsets.only(top: 5.2, bottom: 5.2),
        padding: const EdgeInsets.fromLTRB(12, 11, 8, 11),
        decoration: roamGlassDecoration(context, radius: 15),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(12),
                color: accent.withValues(alpha: 0.16),
              ),
              child: Icon(_iconFor(entry.fileName), size: 20, color: accent),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    entry.fileName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: RoamType.body.copyWith(
                      fontSize: 13.5,
                      fontWeight: FontWeight.w600,
                      color: isDark
                          ? RoamColors.textPrimary
                          : RoamColors.dayInk,
                    ),
                  ),
                  const SizedBox(height: 4),
                  if (running)
                    Padding(
                      padding: const EdgeInsets.only(right: 8, bottom: 4),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(3),
                        child: LinearProgressIndicator(
                          value: ratio,
                          minHeight: 4,
                          backgroundColor:
                              (isDark ? Colors.white : Colors.black).withValues(
                                alpha: 0.10,
                              ),
                          valueColor: const AlwaysStoppedAnimation(
                            RoamColors.aurora,
                          ),
                        ),
                      ),
                    ),
                  Text(
                    statusText,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: RoamType.caption.copyWith(
                      color: running
                          ? RoamColors.aurora
                          : entry.status == DownloadStatus.failed
                          ? RoamColors.danger
                          : (isDark
                                ? RoamColors.textTertiary
                                : RoamColors.daySecondary),
                    ),
                  ),
                ],
              ),
            ),
            if (running)
              PressableScale(
                onTap: onCancel,
                scale: 0.8,
                child: Padding(
                  padding: const EdgeInsets.all(8),
                  child: Icon(
                    Icons.close_rounded,
                    size: 18,
                    color: isDark
                        ? RoamColors.textSecondary
                        : RoamColors.daySecondary,
                  ),
                ),
              )
            else if (complete)
              PressableScale(
                onTap: onOpen,
                scale: 0.8,
                child: Padding(
                  padding: const EdgeInsets.all(8),
                  child: Icon(
                    Icons.open_in_new_rounded,
                    size: 17,
                    color: isDark
                        ? RoamColors.textSecondary
                        : RoamColors.daySecondary,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  static String _bytes(int value) {
    if (value <= 0) return '0 B';
    const units = ['B', 'KB', 'MB', 'GB'];
    var size = value.toDouble();
    var unit = 0;
    while (size >= 1024 && unit < units.length - 1) {
      size /= 1024;
      unit++;
    }
    return '${size.toStringAsFixed(size >= 100 || unit == 0 ? 0 : 1)} ${units[unit]}';
  }

  static String _shortError(String error) {
    return error.length > 40 ? '${error.substring(0, 40)}…' : error;
  }

  static IconData _iconFor(String name) {
    final dot = name.lastIndexOf('.');
    final ext = dot < 0 ? '' : name.substring(dot + 1).toLowerCase();
    return switch (ext) {
      'apk' => Icons.android_rounded,
      'zip' || 'rar' || '7z' || 'tar' || 'gz' => Icons.folder_zip_rounded,
      'pdf' => Icons.picture_as_pdf_rounded,
      'doc' || 'docx' => Icons.description_rounded,
      'xls' || 'xlsx' => Icons.grid_on_rounded,
      'ppt' || 'pptx' => Icons.slideshow_rounded,
      'mp3' || 'flac' || 'wav' || 'm4a' => Icons.graphic_eq_rounded,
      'mp4' || 'mkv' || 'mov' || 'webm' => Icons.movie_rounded,
      'jpg' || 'jpeg' || 'png' || 'gif' || 'webp' => Icons.image_rounded,
      _ => Icons.insert_drive_file_rounded,
    };
  }

  static Color _accentFor(String name) {
    final dot = name.lastIndexOf('.');
    final ext = dot < 0 ? '' : name.substring(dot + 1).toLowerCase();
    return switch (ext) {
      'apk' => const Color(0xFF4EE3C2),
      'zip' || 'rar' || '7z' => const Color(0xFFD99A2B),
      'pdf' => const Color(0xFFE06C75),
      'mp4' || 'mkv' || 'mov' => const Color(0xFF8C7BFF),
      'jpg' || 'jpeg' || 'png' || 'webp' => const Color(0xFF4AA8D8),
      _ => const Color(0xFF3A7BD5),
    };
  }
}

class _EmptyDownloads extends StatelessWidget {
  const _EmptyDownloads();

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final fg = (isDark ? RoamColors.textPrimary : RoamColors.dayInk).withValues(
      alpha: 0.45,
    );
    return Center(
      child: Padding(
        padding: const EdgeInsets.only(bottom: 40),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Image.asset(
              'assets/images/download.png',
              width: 48,
              height: 48,
              color: fg.withValues(alpha: 0.5),
            ),
            const SizedBox(height: 14),
            Text('没有下载的文件', style: TextStyle(fontSize: 15, color: fg)),
          ],
        ),
      ),
    );
  }
}

class _DownloadSheetRow extends StatelessWidget {
  const _DownloadSheetRow({
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
