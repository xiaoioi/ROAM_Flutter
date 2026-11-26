// ignore_for_file: deprecated_member_use

import 'package:flutter/material.dart';
import 'package:flutter_miuix/miuix.dart';

import '../../models/browser_models.dart';
import '../../state/browser_controller.dart';
import '../../theme/roam_theme.dart';
import '../widgets/roam_chrome.dart';
import '../widgets/roam_segmented.dart';
import 'app_icon_page.dart';
import 'edit_home_page.dart';
import 'font_page.dart';
import 'material_effects_page.dart';
import 'wallpaper_page.dart';

/// 外观与设计。
/// 取自 pages/CustomAndUX/main.lua：顶部两枚 170×340 圆角 20 的预览卡，
/// 「应用主题风格」16dp 圆角卡内三段 20dp 圆角选项（13sp bold），
/// 其余条目为 15dp 圆角的设置卡。玻璃质感叠加在原有结构之上。
class AppearancePage extends StatefulWidget {
  const AppearancePage({super.key, required this.controller});

  final BrowserController controller;

  @override
  State<AppearancePage> createState() => _AppearancePageState();
}

class _AppearancePageState extends State<AppearancePage> {
  BrowserController get _controller => widget.controller;

  @override
  Widget build(BuildContext context) {
    // settings 必须每次重建时重新读：写在 AnimatedBuilder 外面会被闭包捕获成
    // 旧值，开关/分段器点了不跟着走（「材质显示效果」旁边的按钮不同步就是这个）。
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, _) {
        final settings = _controller.settings;
        final isDark = Theme.of(context).brightness == Brightness.dark;
        return RoamPageScaffold(
          title: '外观与设计',
          child: ListView(
            padding: EdgeInsets.only(
              top: RoamPageScaffold.topPadding(context) + 4,
              bottom: 40,
            ),
            physics: const BouncingScrollPhysics(),
            children: [
              SizedBox(
                height: 386,
                child: ListView(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.fromLTRB(20, 8, 20, 0),
                  physics: const BouncingScrollPhysics(),
                  children: const [
                    _PreviewCard(title: '主界面背景', kind: _PreviewKind.launcher),
                    SizedBox(width: 15),
                    _PreviewCard(title: '全天候显示', kind: _PreviewKind.aod),
                    SizedBox(width: 15),
                    _PreviewCard(title: '轻影主题图标', kind: _PreviewKind.icons),
                  ],
                ),
              ),
              const MiuixSmallTitle('外观与显示效果'),
              Padding(
                padding: const EdgeInsets.fromLTRB(25, 5.2, 25, 5.2),
                child: Container(
                  padding: const EdgeInsets.fromLTRB(14, 14, 14, 12),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(16),
                    color: isDark ? RoamColors.cardDark : RoamColors.cardLight,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Image.asset(
                            'assets/images/ui.png',
                            width: 25,
                            height: 25,
                            color: isDark
                                ? RoamColors.textPrimary
                                : RoamColors.dayInk,
                          ),
                          const SizedBox(width: 7),
                          Text(
                            '应用主题风格',
                            style: TextStyle(
                              fontSize: 15,
                              color: isDark
                                  ? RoamColors.textPrimary
                                  : RoamColors.dayInk,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      _ThemeSegments(
                        value: settings.themeMode,
                        onChanged: (mode) => _controller.setThemeMode(mode),
                      ),
                      const SizedBox(height: 10),
                      Text(
                        '为了不中断和影响你正在进行的工作，在系统主题切换时，'
                        '你需要手动重启星环软件才能切换系统主题。',
                        style: TextStyle(
                          fontSize: 11,
                          height: 1.45,
                          color:
                              (isDark
                                      ? RoamColors.textPrimary
                                      : RoamColors.dayInk)
                                  .withValues(alpha: 0.42),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 8),
              RoamSettingCard(
                children: [
                  RoamSettingRow(
                    icon: 'assets/images/android.png',
                    label: '跟随系统颜色',
                    onTap: () => _controller.updateSettings(
                      settings.copyWith(
                        followSystemColor: !settings.followSystemColor,
                      ),
                    ),
                    showChevron: false,
                    trailing: RoamSwitch(
                      value: settings.followSystemColor,
                      onChanged: (value) => _controller.updateSettings(
                        settings.copyWith(followSystemColor: value),
                      ),
                    ),
                  ),
                  RoamSettingRow(
                    icon: 'assets/images/animation.png',
                    label: '材质显示效果',
                    subtitle: settings.liquidMaterial ? '柔光玻璃' : '标准',
                    onTap: () => Navigator.of(context).push(
                      MaterialPageRoute<void>(
                        builder: (_) =>
                            MaterialEffectsPage(controller: _controller),
                      ),
                    ),
                    showChevron: false,
                    trailing: RoamSwitch(
                      value: settings.liquidMaterial,
                      onChanged: (value) => _controller.updateSettings(
                        settings.copyWith(liquidMaterial: value),
                      ),
                    ),
                  ),
                ],
              ),
              const MiuixSmallTitle('个性化字体显示'),
              RoamSettingCard(
                children: [
                  RoamSettingRow(
                    icon: 'assets/images/fonts.png',
                    label: '字体',
                    subtitle: _fontLabel(settings.fontMode),
                    onTap: () => Navigator.of(context).push(
                      MaterialPageRoute<void>(
                        builder: (_) => FontPage(controller: _controller),
                      ),
                    ),
                  ),
                ],
              ),
              const MiuixSmallTitle('个性化桌面图标'),
              RoamSettingCard(
                children: [
                  RoamSettingRow(
                    icon: 'assets/images/edit.png',
                    label: '编辑 App 图标',
                    subtitle: _iconLabel(settings.appIcon),
                    onTap: () => Navigator.of(context).push(
                      MaterialPageRoute<void>(
                        builder: (_) => AppIconPage(controller: _controller),
                      ),
                    ),
                  ),
                ],
              ),
              const MiuixSmallTitle('壁纸与主界面背景'),
              RoamSettingCard(
                children: [
                  RoamSettingRow(
                    icon: 'assets/images/launcher_edit.png',
                    label: '编辑主界面背景',
                    onTap: () => Navigator.of(context).push(
                      MaterialPageRoute<void>(
                        builder: (_) => EditHomePage(controller: _controller),
                      ),
                    ),
                  ),
                  RoamSettingRow(
                    icon: 'assets/images/wallpaper.png',
                    label: '默认壁纸',
                    subtitle: _wallpaperLabel(settings.wallpaper),
                    onTap: () => _openWallpapers(context),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  static String _iconLabel(String value) => switch (value) {
    'explore' => '星环探索',
    'intelligence' => '智慧',
    'fashion' => '潮流',
    _ => '默认图标',
  };

  static String _fontLabel(String value) => switch (value) {
    'system' => '跟随系统字体',
    'roboto' => 'Roboto',
    'serif' => 'OPPO Serif',
    _ => '星环无极可变字体',
  };

  static String _wallpaperLabel(String value) => switch (value) {
    'wanmu' => '万木',
    'luoyang' => '落阳',
    'muguang' => '暮光',
    'kongjing' => '空境',
    'custom' => '自定义背景',
    _ => '未设置',
  };

  void _openWallpapers(BuildContext context) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => WallpaperPage(controller: _controller),
      ),
    );
  }
}

enum _PreviewKind { launcher, aod, icons }

class _PreviewCard extends StatelessWidget {
  const _PreviewCard({required this.title, required this.kind});

  final String title;
  final _PreviewKind kind;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 170,
          height: 340,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: isDark
                  ? const [
                      Color(0xFF0B1220),
                      Color(0xFF1B2440),
                      Color(0xFF07101C),
                    ]
                  : const [
                      Color(0xFFEAF1FF),
                      Color(0xFFDCE8FF),
                      Color(0xFFF7F2FF),
                    ],
            ),
            border: Border.all(
              color: Colors.white.withValues(alpha: isDark ? 0.12 : 0.7),
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: isDark ? 0.4 : 0.08),
                blurRadius: 24,
                offset: const Offset(0, 10),
              ),
            ],
          ),
          clipBehavior: Clip.antiAlias,
          child: switch (kind) {
            _PreviewKind.launcher => _LauncherPreview(isDark: isDark),
            _PreviewKind.aod => _AodPreview(isDark: isDark),
            _PreviewKind.icons => _IconPreview(isDark: isDark),
          },
        ),
        const SizedBox(height: 10),
        Padding(
          padding: const EdgeInsets.only(left: 2),
          child: Text(
            title,
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w700,
              color: isDark ? RoamColors.textPrimary : RoamColors.dayInk,
            ),
          ),
        ),
      ],
    );
  }
}

class _LauncherPreview extends StatelessWidget {
  const _LauncherPreview({required this.isDark});

  final bool isDark;

  @override
  Widget build(BuildContext context) {
    final fg = isDark ? Colors.white : RoamColors.dayInk;
    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 30, 14, 16),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Container(
            height: 34,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(17),
              color: Colors.white.withValues(alpha: isDark ? 0.1 : 0.62),
              border: Border.all(
                color: Colors.white.withValues(alpha: isDark ? 0.16 : 0.8),
              ),
            ),
            child: Row(
              children: [
                const SizedBox(width: 12),
                Icon(
                  Icons.search_rounded,
                  size: 15,
                  color: fg.withValues(alpha: 0.5),
                ),
                const SizedBox(width: 6),
                Text(
                  '搜索或输入网址',
                  style: TextStyle(
                    fontSize: 9,
                    color: fg.withValues(alpha: 0.45),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 18),
          Wrap(
            spacing: 10,
            runSpacing: 14,
            children: [
              for (var i = 0; i < 8; i++)
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(13),
                    color: Colors.white.withValues(alpha: isDark ? 0.14 : 0.72),
                    border: Border.all(
                      color: Colors.white.withValues(
                        alpha: isDark ? 0.18 : 0.85,
                      ),
                    ),
                  ),
                  child: Icon(
                    _icons[i],
                    size: 18,
                    color: fg.withValues(alpha: 0.55),
                  ),
                ),
            ],
          ),
          Container(
            height: 30,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(15),
              color: Colors.white.withValues(alpha: isDark ? 0.1 : 0.6),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                for (final icon in [
                  Icons.arrow_back_ios_new_rounded,
                  Icons.arrow_forward_ios_rounded,
                  Icons.home_rounded,
                  Icons.grid_view_rounded,
                  Icons.refresh_rounded,
                ])
                  Icon(icon, size: 12, color: fg.withValues(alpha: 0.5)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  static const _icons = [
    Icons.language_rounded,
    Icons.movie_rounded,
    Icons.shopping_bag_rounded,
    Icons.music_note_rounded,
    Icons.cloud_rounded,
    Icons.article_rounded,
    Icons.sports_esports_rounded,
    Icons.photo_rounded,
  ];
}

class _AodPreview extends StatelessWidget {
  const _AodPreview({required this.isDark});

  final bool isDark;

  @override
  Widget build(BuildContext context) {
    final fg = isDark ? Colors.white : RoamColors.dayInk;
    final now = DateTime.now();
    final time =
        '${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}';
    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 40, 14, 20),
      child: Column(
        children: [
          Text(
            time,
            style: TextStyle(
              fontSize: 42,
              height: 1,
              fontWeight: FontWeight.w300,
              letterSpacing: -1,
              color: fg,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            '${now.month} 月 ${now.day} 日',
            style: TextStyle(fontSize: 11, color: fg.withValues(alpha: 0.45)),
          ),
          const SizedBox(height: 22),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              for (final icon in [
                Icons.videocam_rounded,
                Icons.photo_library_rounded,
                Icons.sticky_note_2_rounded,
                Icons.lock_rounded,
              ])
                Container(
                  width: 34,
                  height: 34,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.white.withValues(alpha: isDark ? 0.12 : 0.6),
                    border: Border.all(
                      color: Colors.white.withValues(
                        alpha: isDark ? 0.16 : 0.8,
                      ),
                    ),
                  ),
                  child: Icon(icon, size: 16, color: fg.withValues(alpha: 0.5)),
                ),
            ],
          ),
          const Spacer(),
          Text(
            '星环 · 全天候显示',
            style: TextStyle(fontSize: 9, color: fg.withValues(alpha: 0.35)),
          ),
        ],
      ),
    );
  }
}

/// 「轻影主题图标」预览：一行 45dp 圆底图标，间距 10dp（原版 45dp + 10dp）。
class _IconPreview extends StatelessWidget {
  const _IconPreview({required this.isDark});

  final bool isDark;

  static const _items = [
    ('assets/services/ic_gallery3d.png', 0xFF4D9EFF),
    ('assets/services/ic_note.png', 0xFFFFC44D),
    ('assets/services/ic_camera.png', 0xFF6BE39A),
    ('assets/services/ic_calendar.png', 0xFF9B8CFF),
  ];

  @override
  Widget build(BuildContext context) {
    final fg = isDark ? Colors.white : RoamColors.dayInk;
    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 26, 14, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '轻影',
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w600,
              color: fg,
            ),
          ),
          const SizedBox(height: 16),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              for (final item in _items)
                Container(
                  width: 45,
                  height: 45,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Color(item.$2)
                        .withValues(alpha: isDark ? 0.28 : 0.18),
                    border: Border.all(
                      color: Colors.white.withValues(
                        alpha: isDark ? 0.14 : 0.8,
                      ),
                    ),
                  ),
                  padding: const EdgeInsets.all(11),
                  child: Image.asset(
                    item.$1,
                    color: Color(item.$2),
                    fit: BoxFit.contain,
                  ),
                ),
            ],
          ),
          const Spacer(),
          Text(
            '图标随壁纸取色',
            style: TextStyle(fontSize: 9, color: fg.withValues(alpha: 0.35)),
          ),
        ],
      ),
    );
  }
}

/// 三段主题选择 → miuix 的 [MiuixGlassSegmentedTabRow]（相连分段轨道）。
///
/// 一条共用玻璃轨道 + 选中指示块连续滑动，跟系统「过滤排序」控件一致；
/// 颜色全部交给 miuix 默认（轨道 = surface 提亮，指示块 = 主题蓝），
/// 不再自绘一套黑/白选中块。
class _ThemeSegments extends StatelessWidget {
  const _ThemeSegments({required this.value, required this.onChanged});

  final AppThemeMode value;
  final ValueChanged<AppThemeMode> onChanged;

  @override
  Widget build(BuildContext context) {
    const options = [
      (AppThemeMode.system, '跟随系统'),
      (AppThemeMode.dark, '深色模式'),
      (AppThemeMode.light, '浅色模式'),
    ];
    final index = options.indexWhere((option) => option.$1 == value);
    return RoamSegmented(
      tabs: [for (final option in options) option.$2],
      selectedIndex: index < 0 ? 0 : index,
      onSelect: (i) => onChanged(options[i].$1),
      height: 40,
    );
  }
}
