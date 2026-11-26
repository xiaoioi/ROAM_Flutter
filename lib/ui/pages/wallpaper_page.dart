// ignore_for_file: deprecated_member_use

import 'package:flutter/material.dart';

import '../../state/browser_controller.dart';
import '../widgets/glass_controls.dart';
import '../widgets/hyperos_top_bar.dart';
import '../widgets/roam_chrome.dart';
import '../app_messenger.dart';

/// 默认壁纸（对应原版 pages/SystemWallpaper）。
/// 四张内置壁纸：万木、落阳、暮光、空境，整屏预览 + 设置为壁纸 / 下一张。
class WallpaperPage extends StatefulWidget {
  const WallpaperPage({super.key, required this.controller});

  final BrowserController controller;

  @override
  State<WallpaperPage> createState() => _WallpaperPageState();
}

class _WallpaperItem {
  const _WallpaperItem({
    required this.id,
    required this.title,
    required this.subtitle,
    required this.accent,
  });

  final String id;
  final String title;
  final String subtitle;
  final Color accent;
}

const _wallpapers = <_WallpaperItem>[
  _WallpaperItem(
    id: 'wanmu',
    title: '万木',
    subtitle: '万木葱茏，尽显无垠苍翠汪洋。',
    accent: Color(0xFF14532D),
  ),
  _WallpaperItem(
    id: 'luoyang',
    title: '落阳',
    subtitle: '坠日熔云，地平线燃尽最后余温。',
    accent: Color(0xFF9A3412),
  ),
  _WallpaperItem(
    id: 'muguang',
    title: '暮光',
    subtitle: '于黄昏之际，捕捉暮光消逝前的静谧。',
    accent: Color(0xFF4C1D95),
  ),
  _WallpaperItem(
    id: 'kongjing',
    title: '空境',
    subtitle: '万籁俱寂，唯余一片虚空之境。',
    accent: Color(0xFF1E3A8A),
  ),
];

class _WallpaperPageState extends State<WallpaperPage> {
  late final PageController _pages;
  late int _index;

  BrowserController get _controller => widget.controller;

  @override
  void initState() {
    super.initState();
    final current = _wallpapers.indexWhere(
      (item) => item.id == _controller.settings.wallpaper,
    );
    _index = current < 0 ? 0 : current;
    _pages = PageController(initialPage: _index);
  }

  @override
  void dispose() {
    _pages.dispose();
    super.dispose();
  }

  void _apply() {
    final item = _wallpapers[_index];
    _controller.updateSettings(
      _controller.settings.copyWith(wallpaper: item.id),
    );
    Navigator.of(context).maybePop();
    showRoamToast(
      '已设置为「${item.title}」',
      duration: const Duration(milliseconds: 1400),
    );
  }

  void _next() {
    final next = (_index + 1) % _wallpapers.length;
    _pages.animateToPage(
      next,
      duration: const Duration(milliseconds: 320),
      curve: Curves.easeOutCubic,
    );
  }

  void _clear() {
    _controller.updateSettings(
      _controller.settings.copyWith(wallpaper: 'none'),
    );
    Navigator.of(context).maybePop();
  }

  @override
  Widget build(BuildContext context) {
    final hasWallpaper = _controller.settings.wallpaper != 'none';
    return RoamPageScaffold(
      title: '默认壁纸',
      actions: [
        // 原版这里是文字按钮「不使用」，澎湃 4 顶栏只收圆钮，
        // 改成同一枚删除圆钮 + tooltip。
        if (hasWallpaper)
          HyperosBarAction(
            asset: 'assets/images/delete.png',
            tooltip: '不使用壁纸',
            iconSize: 26,
            onTap: _clear,
          ),
      ],
      child: Padding(
        padding: EdgeInsets.fromLTRB(
          25,
          RoamPageScaffold.contentTopPadding + 8,
          25,
          22,
        ),
        child: PageView.builder(
          controller: _pages,
          physics: const BouncingScrollPhysics(),
          onPageChanged: (value) => setState(() => _index = value),
          itemCount: _wallpapers.length,
          itemBuilder: (context, index) {
            final item = _wallpapers[index];
            return Padding(
              padding: const EdgeInsets.symmetric(horizontal: 2),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(24),
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    Image.asset(
                      'assets/wallpapers/${item.id}.jpg',
                      fit: BoxFit.cover,
                    ),
                    const DecoratedBox(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          stops: [0.5, 1.0],
                          colors: [Colors.transparent, Color(0x99000000)],
                        ),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(22, 22, 22, 20),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Spacer(),
                          Text(
                            item.title,
                            style: const TextStyle(
                              fontSize: 30,
                              height: 1.1,
                              fontWeight: FontWeight.w700,
                              color: Colors.white,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            item.subtitle,
                            style: TextStyle(
                              fontSize: 12,
                              height: 1.4,
                              color: Colors.white.withValues(alpha: 0.82),
                            ),
                          ),
                          const SizedBox(height: 16),
                          Row(
                            children: [
                              Expanded(
                                child: PressableScale(
                                  scale: 0.97,
                                  onTap: _apply,
                                  child: Container(
                                    height: 50,
                                    alignment: Alignment.center,
                                    decoration: BoxDecoration(
                                      color: item.accent,
                                      borderRadius: BorderRadius.circular(25),
                                      border: Border.all(
                                        color: Colors.white.withValues(
                                          alpha: 0.18,
                                        ),
                                      ),
                                    ),
                                    child: const Text(
                                      '设置为壁纸',
                                      style: TextStyle(
                                        fontSize: 14,
                                        fontWeight: FontWeight.w700,
                                        color: Colors.white,
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: PressableScale(
                                  scale: 0.97,
                                  onTap: _next,
                                  child: Container(
                                    height: 50,
                                    alignment: Alignment.center,
                                    decoration: BoxDecoration(
                                      color: Colors.white,
                                      borderRadius: BorderRadius.circular(25),
                                    ),
                                    child: const Text(
                                      '下一张',
                                      style: TextStyle(
                                        fontSize: 14,
                                        fontWeight: FontWeight.w700,
                                        color: Color(0xFF101010),
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}
