// ignore_for_file: deprecated_member_use

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../models/browser_models.dart';
import '../../state/browser_controller.dart';
import '../../theme/roam_theme.dart';
import '../widgets/glass_controls.dart';
import '../widgets/predictive_back.dart';
import '../widgets/roam_sheet.dart';
import 'material_effects_page.dart';
import '../app_messenger.dart';

/// 编辑主界面背景（对应原版 pages/LauncherStyleSettings）。
/// 中间是主界面预览，底部工具栏：HDR 显示 / 材质设置 / 背景设置 / 模糊背景 / 浅色模式。
class EditHomePage extends StatefulWidget {
  const EditHomePage({super.key, required this.controller});

  final BrowserController controller;

  @override
  State<EditHomePage> createState() => _EditHomePageState();
}

class _EditHomePageState extends State<EditHomePage> {
  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: widget.controller,
      builder: (context, _) {
        return Scaffold(
          backgroundColor: Colors.black,
          body: SafeArea(
            child: Column(
              children: [
                // ---- 顶部：退出 / 编辑主界面 / 应用 ----
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 10, 16, 6),
                  child: Row(
                    children: [
                      PressableScale(
                        scale: 0.92,
                        onTap: () => Navigator.of(context).maybePop(),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 18,
                            vertical: 8,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: const Text(
                            '退出',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: Colors.white,
                            ),
                          ),
                        ),
                      ),
                      const Spacer(),
                      const Text(
                        '编辑主界面',
                        style: TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.w700,
                          color: Colors.white,
                        ),
                      ),
                      const Spacer(),
                      PressableScale(
                        scale: 0.92,
                        onTap: () {
                          Navigator.of(context).maybePop();
                          showRoamToast(
                            '已应用主界面设置',
                            duration: const Duration(milliseconds: 1400),
                          );
                        },
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 18,
                            vertical: 8,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: const Text(
                            '应用',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: Color(0xFF101010),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 8),
                // ---- 中间：主界面预览 ----
                Expanded(child: _PreviewFrame(controller: widget.controller)),
                const SizedBox(height: 12),
                // ---- 底部工具栏 ----
                _BottomToolbar(controller: widget.controller),
                SizedBox(height: MediaQuery.paddingOf(context).bottom + 6),
              ],
            ),
          ),
        );
      },
    );
  }
}

/// 手机主界面预览框：圆角容器内显示 logo + 搜索框 + 底栏。
class _PreviewFrame extends StatelessWidget {
  const _PreviewFrame({required this.controller});

  final BrowserController controller;

  @override
  Widget build(BuildContext context) {
    final settings = controller.settings;
    final wallpaper = settings.wallpaper;
    final customPath = settings.customWallpaperPath;
    final hasWallpaper = wallpaper != 'none' || customPath.isNotEmpty;
    final isDarkUi =
        settings.themeMode == AppThemeMode.dark ||
        (settings.themeMode == AppThemeMode.system &&
            Theme.of(context).brightness == Brightness.dark);

    return Center(
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 30),
        decoration: BoxDecoration(
          color: Colors.grey.withValues(alpha: 0.18),
          borderRadius: BorderRadius.circular(28),
          border: Border.all(
            color: Colors.white.withValues(alpha: 0.12),
            width: 1.5,
          ),
        ),
        clipBehavior: Clip.antiAlias,
        child: Stack(
          fit: StackFit.expand,
          children: [
            // 壁纸 / 纯色背景
            if (customPath.isNotEmpty)
              Image.file(
                File(customPath),
                fit: BoxFit.cover,
                errorBuilder: (_, _, _) => const SizedBox.shrink(),
              )
            else if (wallpaper != 'none')
              Image.asset(
                'assets/wallpapers/$wallpaper.jpg',
                fit: BoxFit.cover,
                errorBuilder: (_, _, _) => const SizedBox.shrink(),
              )
            else
              ColoredBox(
                color: isDarkUi
                    ? const Color(0xFF1A1A2E)
                    : const Color(0xFFE8E8EC),
              ),
            if (hasWallpaper)
              ColoredBox(
                color: Colors.black.withValues(
                  alpha: settings.wallpaperDim.clamp(0.0, 0.85),
                ),
              ),
            if (hasWallpaper && settings.blurBackground)
              ColoredBox(
                color: (isDarkUi ? Colors.black : Colors.white).withValues(
                  alpha: 0.25,
                ),
              ),
            // 内容
            Column(
              children: [
                const SizedBox(height: 28),
                // logo
                SizedBox(
                  height: 20,
                  child: Image.asset(
                    'assets/images/roam_explore_logo.png',
                    width: 130,
                    fit: BoxFit.contain,
                    color: isDarkUi || hasWallpaper
                        ? Colors.white
                        : const Color(0xFF0B1526),
                  ),
                ),
                const SizedBox(height: 16),
                // 搜索框
                Container(
                  height: 32,
                  margin: const EdgeInsets.symmetric(horizontal: 18),
                  decoration: BoxDecoration(
                    color: isDarkUi || hasWallpaper
                        ? Colors.white.withValues(alpha: 0.15)
                        : Colors.white.withValues(alpha: 0.80),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: isDarkUi || hasWallpaper
                          ? Colors.white.withValues(alpha: 0.20)
                          : Colors.black.withValues(alpha: 0.08),
                    ),
                  ),
                  child: Row(
                    children: [
                      const SizedBox(width: 10),
                      Icon(
                        Icons.search,
                        size: 14,
                        color: isDarkUi || hasWallpaper
                            ? Colors.white70
                            : Colors.black45,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        '搜索或输入网址',
                        style: TextStyle(
                          fontSize: 10,
                          color: isDarkUi || hasWallpaper
                              ? Colors.white54
                              : Colors.black38,
                        ),
                      ),
                      const Spacer(),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 3,
                        ),
                        decoration: BoxDecoration(
                          color: isDarkUi || hasWallpaper
                              ? Colors.white.withValues(alpha: 0.18)
                              : Colors.black.withValues(alpha: 0.06),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Text(
                          '搜索',
                          style: TextStyle(
                            fontSize: 9,
                            fontWeight: FontWeight.w600,
                            color: isDarkUi || hasWallpaper
                                ? Colors.white
                                : Colors.black54,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                    ],
                  ),
                ),
                const Spacer(),
                // 底部导航栏
                Container(
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      for (final icon in [
                        Icons.arrow_back,
                        Icons.arrow_forward,
                        Icons.home_outlined,
                        Icons.menu,
                        Icons.refresh,
                      ])
                        Icon(
                          icon,
                          size: 18,
                          color: isDarkUi || hasWallpaper
                              ? Colors.white70
                              : Colors.black45,
                        ),
                    ],
                  ),
                ),
              ],
            ),
            // HDR 效果叠加
            if (settings.hdrDisplay)
              IgnorePointer(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        Colors.white.withValues(alpha: 0.06),
                        Colors.transparent,
                        Colors.black.withValues(alpha: 0.04),
                      ],
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// 底部工具栏：HDR 显示 / 材质设置 / 背景设置 / 模糊背景 / 浅色模式。
class _BottomToolbar extends StatelessWidget {
  const _BottomToolbar({required this.controller});

  final BrowserController controller;

  @override
  Widget build(BuildContext context) {
    final settings = controller.settings;
    final items = <_ToolItem>[
      _ToolItem(
        label: 'HDR 显示',
        icon: 'assets/images/hdr.png',
        fallbackIcon: Icons.hdr_on,
        active: settings.hdrDisplay,
        onTap: () => controller.updateSettings(
          settings.copyWith(hdrDisplay: !settings.hdrDisplay),
        ),
      ),
      _ToolItem(
        label: '材质设置',
        icon: 'assets/images/animation.png',
        fallbackIcon: Icons.auto_awesome,
        active: false,
        onTap: () => Navigator.of(context).push(
          MaterialPageRoute<void>(
            builder: (_) => MaterialEffectsPage(controller: controller),
          ),
        ),
      ),
      _ToolItem(
        label: '背景设置',
        icon: 'assets/images/wallpaper.png',
        fallbackIcon: Icons.wallpaper,
        active: false,
        onTap: () => _showBackgroundSheet(context),
      ),
      _ToolItem(
        label: '模糊背景',
        icon: 'assets/images/blur.png',
        fallbackIcon: Icons.blur_on,
        active: settings.blurBackground,
        onTap: () => controller.updateSettings(
          settings.copyWith(blurBackground: !settings.blurBackground),
        ),
      ),
      _ToolItem(
        label: '壁纸压暗',
        icon: 'assets/images/sun.png',
        fallbackIcon: Icons.brightness_6,
        active: settings.wallpaperDim > 0.02,
        onTap: () => _showDimSheet(context),
      ),
    ];

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          for (final item in items)
            Expanded(
              child: PressableScale(
                scale: 0.88,
                onTap: item.onTap,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 50,
                      height: 50,
                      decoration: BoxDecoration(
                        color: item.active
                            ? RoamColors.aurora
                            : Colors.white.withValues(alpha: 0.12),
                        shape: BoxShape.circle,
                      ),
                      child: item.icon.isNotEmpty
                          ? Padding(
                              padding: const EdgeInsets.all(12),
                              child: Image.asset(
                                item.icon,
                                color: item.active
                                    ? Colors.white
                                    : Colors.white70,
                                errorBuilder: (_, _, _) => Icon(
                                  item.fallbackIcon,
                                  color: item.active
                                      ? Colors.white
                                      : Colors.white70,
                                  size: 22,
                                ),
                              ),
                            )
                          : Icon(
                              item.fallbackIcon,
                              color: item.active
                                  ? Colors.white
                                  : Colors.white70,
                              size: 22,
                            ),
                    ),
                    const SizedBox(height: 5),
                    Text(
                      item.label,
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w500,
                        color: item.active
                            ? RoamColors.aurora
                            : Colors.white70,
                      ),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }

  void _showBackgroundSheet(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (sheetContext) => PredictiveBackScope(
        style: PredictiveBackStyle.sheet,
        onCommit: () => Navigator.of(sheetContext).maybePop(),
        child: _BackgroundSheet(controller: controller),
      ),
    );
  }

  /// 壁纸压暗：壁纸铺上后整屏会自动压暗一层，白字与玻璃才站得住。
  /// 原来这里是「浅色模式」开关，主题切换已在「外观」里，位置让给压暗强度。
  void _showDimSheet(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (sheetContext) => PredictiveBackScope(
        style: PredictiveBackStyle.sheet,
        onCommit: () => Navigator.of(sheetContext).maybePop(),
        child: _DimSheet(controller: controller),
      ),
    );
  }
}

/// 壁纸压暗调节面板：0~80%，默认 38%。
class _DimSheet extends StatelessWidget {
  const _DimSheet({required this.controller});

  final BrowserController controller;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: controller,
      builder: (context, _) {
        final settings = controller.settings;
        final value = settings.wallpaperDim.clamp(0.0, 0.8).toDouble();
        final hasWallpaper =
            settings.wallpaper != 'none' ||
            settings.customWallpaperPath.isNotEmpty;
        // 底部弹出框统一走 miuix GlassBottomSheet 表面；壁纸上固定深色。
        return RoamGlassSheetSurface(
          forceDark: true,
          child: Padding(
            padding: EdgeInsets.only(
              left: 20,
              right: 20,
              top: 15,
              bottom: MediaQuery.paddingOf(context).bottom + 20,
            ),
            child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.white24,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  const Text(
                    '壁纸压暗',
                    style: TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w700,
                      color: Colors.white,
                    ),
                  ),
                  const Spacer(),
                  Text(
                    '${(value * 100).round()}%',
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: RoamColors.aurora,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              const Text(
                '有壁纸时整屏会压暗一层，壁纸越亮、文字越需要压暗。',
                style: TextStyle(fontSize: 12, color: Colors.white54),
              ),
              const SizedBox(height: 8),
              SliderTheme(
                data: SliderTheme.of(context).copyWith(
                  trackHeight: 4,
                  activeTrackColor: RoamColors.aurora,
                  inactiveTrackColor: Colors.white24,
                  thumbColor: Colors.white,
                  overlayColor: const Color(0x33FF9500),
                  thumbShape: const RoundSliderThumbShape(
                    enabledThumbRadius: 9,
                  ),
                  overlayShape: const RoundSliderOverlayShape(
                    overlayRadius: 18,
                  ),
                ),
                child: Slider(
                  value: value,
                  min: 0,
                  max: 0.8,
                  divisions: 16,
                  onChanged: hasWallpaper
                      ? (v) => controller.updateSettings(
                          settings.copyWith(wallpaperDim: v),
                        )
                      : null,
                ),
              ),
              const SizedBox(height: 4),
              Row(
                children: [
                  for (final preset in const [
                    ('无', 0.0),
                    ('轻', 0.2),
                    ('标准', 0.38),
                    ('深', 0.6),
                  ])
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 4),
                        child: PressableScale(
                          scale: 0.94,
                          onTap: hasWallpaper
                              ? () => controller.updateSettings(
                                  settings.copyWith(wallpaperDim: preset.$2),
                                )
                              : null,
                          child: Container(
                            height: 38,
                            alignment: Alignment.center,
                            decoration: BoxDecoration(
                              color: (value - preset.$2).abs() < 0.01
                                  ? const Color(0x33FF9500)
                                  : Colors.white.withValues(alpha: 0.08),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: (value - preset.$2).abs() < 0.01
                                    ? RoamColors.aurora
                                    : Colors.transparent,
                              ),
                            ),
                            child: Text(
                              preset.$1,
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                                color: (value - preset.$2).abs() < 0.01
                                    ? RoamColors.aurora
                                    : Colors.white70,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                ],
              ),
              if (!hasWallpaper) ...[
                const SizedBox(height: 12),
                const Text(
                  '当前没有壁纸，压暗不会生效。先在「背景设置」里选一张。',
                  style: TextStyle(fontSize: 12, color: Colors.white38),
                ),
              ],
              ],
            ),
          ),
        );
      },
    );
  }
}

class _ToolItem {
  const _ToolItem({
    required this.label,
    required this.icon,
    required this.fallbackIcon,
    required this.active,
    required this.onTap,
  });

  final String label;
  final String icon;
  final IconData fallbackIcon;
  final bool active;
  final VoidCallback onTap;
}

/// 背景设置弹出面板：预设壁纸 / 从相册选择 / 纯色。
class _BackgroundSheet extends StatelessWidget {
  const _BackgroundSheet({required this.controller});

  final BrowserController controller;

  @override
  Widget build(BuildContext context) {
    final settings = controller.settings;
    final current = settings.wallpaper;

    return RoamGlassSheetSurface(
      forceDark: true,
      child: Padding(
        padding: EdgeInsets.only(
          left: 20,
          right: 20,
          top: 15,
          bottom: MediaQuery.paddingOf(context).bottom + 20,
        ),
        child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 拖动条
          Center(
            child: Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.white24,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 16),
          const Text(
            '背景设置',
            style: TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.w700,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 16),
          // 预设壁纸
          const Text(
            '预设壁纸',
            style: TextStyle(fontSize: 13, color: Colors.white54),
          ),
          const SizedBox(height: 10),
          SizedBox(
            height: 100,
            child: ListView(
              scrollDirection: Axis.horizontal,
              children: [
                for (final wp in [
                  'none',
                  'wanmu',
                  'luoyang',
                  'muguang',
                  'kongjing',
                ])
                  GestureDetector(
                    onTap: () {
                      controller.updateSettings(
                        settings.copyWith(
                          wallpaper: wp,
                          customWallpaperPath: '',
                        ),
                      );
                    },
                    child: Container(
                      width: 55,
                      margin: const EdgeInsets.only(right: 10),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color:
                              current == wp &&
                                  settings.customWallpaperPath.isEmpty
                              ? RoamColors.aurora
                              : Colors.white24,
                          width: 2,
                        ),
                      ),
                      clipBehavior: Clip.antiAlias,
                      child: wp == 'none'
                          ? const ColoredBox(
                              color: Color(0xFF2C2C2E),
                              child: Center(
                                child: Icon(
                                  Icons.block,
                                  color: Colors.white38,
                                  size: 20,
                                ),
                              ),
                            )
                          : Image.asset(
                              'assets/wallpapers/$wp.jpg',
                              fit: BoxFit.cover,
                              errorBuilder: (_, _, _) =>
                                  const ColoredBox(color: Color(0xFF2C2C2E)),
                            ),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          // 从相册选择
          PressableScale(
            scale: 0.96,
            onTap: () async {
              final path = await _pickImageFromGallery();
              if (path == null) return;
              final previous = settings.customWallpaperPath;
              // 新路径是唯一的（原生侧带时间戳），旧图从解码缓存里清掉，
              // 避免同一张图被二次选择时命中旧缓存。
              if (previous.isNotEmpty) {
                await FileImage(File(previous)).evict();
              }
              await FileImage(File(path)).evict();
              if (!context.mounted) return;
              controller.updateSettings(
                settings.copyWith(
                  customWallpaperPath: path,
                  wallpaper: 'custom',
                ),
              );
              Navigator.of(context).maybePop();
            },
            child: Container(
              height: 50,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.10),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: Colors.white24),
              ),
              child: const Row(
                children: [
                  SizedBox(width: 16),
                  Icon(Icons.photo_library, color: Colors.white70, size: 22),
                  SizedBox(width: 12),
                  Text(
                    '从相册选择自定义背景',
                    style: TextStyle(fontSize: 15, color: Colors.white),
                  ),
                  Spacer(),
                  Icon(Icons.chevron_right, color: Colors.white38),
                  SizedBox(width: 12),
                ],
              ),
            ),
          ),
          const SizedBox(height: 10),
          // 清除自定义
          if (settings.customWallpaperPath.isNotEmpty)
            PressableScale(
              scale: 0.96,
              onTap: () {
                controller.updateSettings(
                  settings.copyWith(customWallpaperPath: '', wallpaper: 'none'),
                );
                Navigator.of(context).maybePop();
              },
              child: Container(
                height: 50,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.06),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: const Row(
                  children: [
                    SizedBox(width: 16),
                    Icon(Icons.delete_outline, color: Colors.red, size: 22),
                    SizedBox(width: 12),
                    Text(
                      '清除自定义背景',
                      style: TextStyle(fontSize: 15, color: Colors.red),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// 调用系统隐私相册选择器（MediaStore.ACTION_PICK_IMAGES）。
  /// 无需申请存储权限，用户只授权选中的照片。
  Future<String?> _pickImageFromGallery() async {
    const channel = MethodChannel('org.roam.roam_flutter/photo_picker');
    try {
      final path = await channel.invokeMethod<String>('pickImage');
      return path;
    } on PlatformException catch (e) {
      debugPrint('PhotoPicker failed: ${e.message}');
      return null;
    } on MissingPluginException {
      // 非 Android 平台或插件未注册
      debugPrint('PhotoPicker not available on this platform');
      return null;
    }
  }
}
