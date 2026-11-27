// ignore_for_file: deprecated_member_use

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_miuix/miuix.dart';

import '../../models/browser_models.dart';
import '../../state/browser_controller.dart';
import '../../theme/roam_theme.dart';
import '../sheets/search_sheet.dart';
import '../widgets/glass_controls.dart';

class HomePage extends StatefulWidget {
  const HomePage({
    super.key,
    required this.controller,
    required this.brightness,
  });

  final BrowserController controller;
  final Brightness brightness;

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  // 页面级采样器：只捕获壁纸层，玻璃面板全部是捕获子树的兄弟节点，
  // 因此不会把玻璃自身采样进快照（OS4 规则，避免反馈叠色）。
  // 全局 miuixBackdrop / fluidBackdrop 由 BrowserShell 捕获整个页面内容，
  // 专供 modal 弹层（工具栏、标签页）在压栈路由里采样。
  final _miuixBg = MiuixLayerBackdrop();

  @override
  void dispose() {
    _miuixBg.dispose();
    super.dispose();
  }

  void _open(String url) {
    widget.controller.openAddress(url);
  }

  /// 原版首页的搜索框是「假框」：`searchBoxOccupancyView.onClick`
  /// → `showSearchView()`，真正输入发生在弹出的搜索面板里。
  void _openSearch() {
    showSearchSheet(context: context, controller: widget.controller);
  }

  @override
  Widget build(BuildContext context) {
    final isDark = widget.brightness == Brightness.dark;
    final wallpaper = widget.controller.settings.wallpaper;
    final customPath = widget.controller.settings.customWallpaperPath;
    final hasCustom = customPath.isNotEmpty;
    final hasWallpaper = wallpaper != 'none' || hasCustom;
    // 壁纸上统一按深色界面处理：白字、深色玻璃，浅色模式下也不会糊掉。
    final darkUi = isDark || hasWallpaper;
    final fg = darkUi ? Colors.white : const Color(0xFF0B1526);
    // 注意：darkUi 只在本页通过 forceDark 逐控件传下去。
    // 早先这里写的是全局 GlassRuntime.darkUi，结果首页有壁纸就把全局置成
    // 深色，用户 Push 到设置页后顶栏跟着用白字，白字打在浅底上看不见。

    return Stack(
      fit: StackFit.expand,
      children: [
        // 壁纸或纯色底，玻璃折射的就是这一层。
        // 柔光玻璃的捕获层只包背景：玻璃面板全部是它的兄弟节点，
        // 否则每帧会把玻璃自身采样进快照，形成「越叠越浓」的反馈。
        MiuixLayerBackdropCapture(
          backdrop: _miuixBg,
          // 1x 采样：快照只喂给「会再模糊一次」的玻璃/渐隐，3x 屏上每帧
          // toImage 的数据量从 ~13MB 降到 ~1.4MB（顶栏渐隐是常驻的，
          // 每帧全屏 3x 出图就是滚动卡顿的主因）。
          pixelRatio: 1,
          child: Stack(
            fit: StackFit.expand,
            children: [
              if (hasCustom)
                Image.file(
                  File(customPath),
                  fit: BoxFit.cover,
                  filterQuality: FilterQuality.medium,
                  errorBuilder: (_, _, _) => ColoredBox(
                    color: isDark ? Colors.black : RoamColors.daySky,
                  ),
                )
              else if (wallpaper != 'none')
                Image.asset(
                  'assets/wallpapers/$wallpaper.jpg',
                  fit: BoxFit.cover,
                  filterQuality: FilterQuality.medium,
                  errorBuilder: (_, _, _) => ColoredBox(
                    color: isDark ? Colors.black : RoamColors.daySky,
                  ),
                )
              else
                ColoredBox(color: isDark ? Colors.black : RoamColors.daySky),
              if (hasWallpaper)
                ColoredBox(
                  color: Colors.black.withValues(
                    alpha: widget.controller.settings.wallpaperDim.clamp(
                      0.0,
                      0.85,
                    ),
                  ),
                ),
            ],
          ),
        ),
        SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
          padding: const EdgeInsets.only(bottom: 24),
          child: Column(
            children: [
              // 原版 logoCardView：marginTop 80dp，236 × 36.86dp
              const SizedBox(height: 80),
              SizedBox(
                height: 36.86,
                child: Image.asset(
                  'assets/images/roam_explore_logo.png',
                  width: 236,
                  fit: BoxFit.contain,
                  color: fg,
                  filterQuality: FilterQuality.high,
                ),
              ),
              _SearchBar(
                isDark: darkUi,
                miuixLayer: _miuixBg,
                onTap: _openSearch,
              ),
              _CardsRow(isDark: darkUi, miuixLayer: _miuixBg, onOpen: _open),
              _SectionTitle(text: '快捷访问', isDark: darkUi),
              _ShortcutCard(
                bookmarks: widget.controller.bookmarks,
                isDark: darkUi,
                miuixLayer: _miuixBg,
                onOpen: _open,
              ),
              const SizedBox(height: 16),
            ],
          ),
        ),
      ],
    );
  }
}

/// 搜索框：50dp 高、圆角 180dp（胶囊）、描边 2.5dp、左右 20dp。
///
/// 原版这里是不可输入的「假框」——点击后弹出搜索面板（第二界面），
/// 真正输入在面板的 EditText 里完成。这里保持同样的行为。
class _SearchBar extends StatelessWidget {
  const _SearchBar({
    required this.isDark,
    required this.miuixLayer,
    required this.onTap,
  });

  final bool isDark;
  final MiuixLayerBackdrop miuixLayer;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final fg = isDark ? Colors.white : const Color(0xFF0B1526);

    return Padding(
      padding: const EdgeInsets.only(left: 20, right: 20, top: 20),
      child: SizedBox(
        height: 50,
        child: RoamGlassSurface(
          miuixLayer: miuixLayer,
          forceDark: isDark,
          capsule: true,
          surfaceColor: isDark
              ? Colors.white.withValues(alpha: 0.09)
              : Colors.white.withValues(alpha: 0.86),
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: onTap,
            child: Row(
              children: [
                const SizedBox(width: 15),
                Image.asset(
                  'assets/images/search_lc.png',
                  width: 25,
                  height: 25,
                  color: fg,
                ),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.only(left: 5, right: 10),
                    child: Text(
                      '搜索或输入网址',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 16,
                        color: fg.withValues(alpha: 0.35),
                      ),
                    ),
                  ),
                ),
                Container(
                  width: 1.2,
                  height: 20,
                  margin: const EdgeInsets.only(top: 15, bottom: 15),
                  color: fg.withValues(alpha: 0.2),
                ),
                Padding(
                  padding: const EdgeInsets.only(left: 10, right: 20),
                  child: Text(
                    '搜索',
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                      color: fg,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// 笔记卡 135dp + 右侧 135dp 的 2×2 组件，间距 12dp。
class _CardsRow extends StatelessWidget {
  const _CardsRow({
    required this.isDark,
    required this.miuixLayer,
    required this.onOpen,
  });

  final bool isDark;
  final MiuixLayerBackdrop miuixLayer;
  final void Function(String url) onOpen;

  @override
  Widget build(BuildContext context) {
    final fg = isDark ? Colors.white : const Color(0xFF0B1526);
    const services = <List<String>>[
      ['assets/services/ic_weather.png', '天气'],
      ['assets/services/ic_gallery3d.png', '相册'],
      ['assets/services/ic_camera.png', '相机'],
      ['assets/services/ic_calendar.png', '日历'],
    ];

    return Padding(
      padding: const EdgeInsets.only(left: 20, right: 20, top: 15),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: RoamGlassSurface(
              miuixLayer: miuixLayer,
              forceDark: isDark,
              radius: 18,
              child: SizedBox(
                height: 135,
                child: Column(
                  children: [
                    Padding(
                      padding: const EdgeInsets.only(
                        top: 9,
                        left: 10,
                        right: 10,
                      ),
                      child: Row(
                        children: [
                          Image.asset(
                            'assets/services/ic_note.png',
                            width: 18,
                            height: 18,
                          ),
                          const SizedBox(width: 5),
                          Text(
                            '我的笔记',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              color: fg,
                              height: 1.2,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Expanded(
                      child: Center(
                        child: Text(
                          '暂无笔记',
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.bold,
                            color: fg.withValues(alpha: 0.55),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          SizedBox(
            width: 135,
            height: 135,
            child: RoamGlassSurface(
              miuixLayer: miuixLayer,
              forceDark: isDark,
              radius: 18,
              child: GridView.builder(
                physics: const NeverScrollableScrollPhysics(),
                padding: const EdgeInsets.all(4),
                itemCount: 4,
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 2,
                  childAspectRatio: 1,
                ),
                itemBuilder: (context, index) {
                  final item = services[index];
                  return Center(
                    child: Image.asset(
                      item[0],
                      width: 50,
                      height: 50,
                      fit: BoxFit.contain,
                      semanticLabel: item[1],
                    ),
                  );
                },
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// 组合卡片：5 列网格，内容就是书签列表。
///
/// 原版 Roam 的「快捷访问」直接取书签数据（首页没有独立的快捷方式库），
/// 所以这里渲染 `controller.bookmarks`：书签管理页里有什么，首页就显示
/// 什么。以前这里挂的是一串写死的站点，书签管理页里根本查不到，
/// 下面又重复渲染了一遍书签横条——两处数据两套样子，属于还原错误。
class _ShortcutCard extends StatelessWidget {
  const _ShortcutCard({
    required this.bookmarks,
    required this.isDark,
    required this.miuixLayer,
    required this.onOpen,
  });

  final List<Bookmark> bookmarks;
  final bool isDark;
  final MiuixLayerBackdrop miuixLayer;
  final void Function(String url) onOpen;

  static const int _columns = 5;
  static const int _maxItems = 20;

  @override
  Widget build(BuildContext context) {
    final fg = isDark ? Colors.white : const Color(0xFF0B1526);
    // 超过 20 个时最后一格让给「更多」，跳书签管理页，
    // 不做静默截断（否则用户会觉得书签凭空少了几条）。
    final hasMore = bookmarks.length > _maxItems;
    final items = bookmarks.take(hasMore ? _maxItems - 1 : _maxItems).toList();
    final count = items.length + (hasMore ? 1 : 0);

    if (items.isEmpty) {
      return Padding(
        padding: const EdgeInsets.only(left: 20, right: 20, top: 15),
        child: RoamGlassSurface(
          miuixLayer: miuixLayer,
          forceDark: isDark,
          radius: 18,
          child: SizedBox(
            height: 96,
            child: Center(
              child: Text(
                '暂无快捷访问，在底栏菜单「添加书签」',
                style: TextStyle(
                  fontSize: 13,
                  color: fg.withValues(alpha: 0.42),
                ),
              ),
            ),
          ),
        ),
      );
    }

    final rows = (count / _columns).ceil().clamp(1, _maxItems ~/ 5);
    return Padding(
      padding: const EdgeInsets.only(left: 20, right: 20, top: 15),
      child: RoamGlassSurface(
        miuixLayer: miuixLayer,
        forceDark: isDark,
        radius: 18,
        child: SizedBox(
          // 行数跟着书签数量走：一两条书签不再留一个 405dp 的空盒子。
          height: rows * 80.0 + 20,
          child: GridView.builder(
            physics: const NeverScrollableScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(6, 10, 6, 10),
            itemCount: count,
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: _columns,
              // 用固定行高而不是 childAspectRatio：宽高比会随屏宽变化，
              // 换算出来的总高跟外面 SizedBox 对不上，最后一排会被切掉一半。
              mainAxisExtent: 80,
            ),
            itemBuilder: (context, index) {
              if (index >= items.length) {
                return _MoreTile(
                  isDark: isDark,
                  onTap: () => Navigator.of(context).pushNamed('/bookmarks'),
                );
              }
              final item = items[index];
              return _ShortcutTile(
                bookmark: item,
                isDark: isDark,
                onTap: () => onOpen(item.url),
              );
            },
          ),
        ),
      ),
    );
  }
}

class _ShortcutTile extends StatelessWidget {
  const _ShortcutTile({
    required this.bookmark,
    required this.isDark,
    required this.onTap,
  });

  final Bookmark bookmark;
  final bool isDark;
  final VoidCallback onTap;

  /// 图标里的字：取标题首字；标题为空时退回域名首字母。
  String get _initial {
    final title = bookmark.title.trim();
    if (title.isNotEmpty) return title.characters.first;
    final host = Uri.tryParse(bookmark.url)?.host ?? '';
    return host.isEmpty ? '?' : host.characters.first.toUpperCase();
  }

  @override
  Widget build(BuildContext context) {
    final fg = isDark ? Colors.white : const Color(0xFF0B1526);
    final host = Uri.tryParse(bookmark.url)?.host ?? '';
    final label = bookmark.title.trim().isEmpty
        ? (host.isEmpty ? bookmark.url : host)
        : bookmark.title.trim();

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: isDark ? RoamColors.itemDark : RoamColors.itemLight,
              shape: BoxShape.circle,
            ),
            alignment: Alignment.center,
            child: Text(
              _initial,
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w500,
                color: fg,
              ),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(fontSize: 11, color: fg.withValues(alpha: 0.85)),
          ),
        ],
      ),
    );
  }
}

/// 「更多」格子：书签超过 20 个时占最后一格，点开书签管理页。
class _MoreTile extends StatelessWidget {
  const _MoreTile({required this.isDark, required this.onTap});

  final bool isDark;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final fg = isDark ? Colors.white : const Color(0xFF0B1526);
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: isDark ? RoamColors.itemDark : RoamColors.itemLight,
              shape: BoxShape.circle,
            ),
            alignment: Alignment.center,
            child: Text(
              '››',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w500,
                color: fg.withValues(alpha: 0.7),
              ),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            '更多',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(fontSize: 11, color: fg.withValues(alpha: 0.85)),
          ),
        ],
      ),
    );
  }
}

/// 区块标题：左 20dp、上 18dp、下 6dp、15sp 粗体（与设置页分组标题同一套规格）。
class _SectionTitle extends StatelessWidget {
  const _SectionTitle({required this.text, required this.isDark});

  final String text;
  final bool isDark;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 18, 20, 6),
      child: Align(
        alignment: Alignment.centerLeft,
        child: Text(
          text,
          style: TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w700,
            color: isDark ? Colors.white : const Color(0xFF0B1526),
          ),
        ),
      ),
    );
  }
}
