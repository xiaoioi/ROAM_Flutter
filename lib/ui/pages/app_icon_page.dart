// ignore_for_file: deprecated_member_use

import 'package:flutter/material.dart';

import '../../state/browser_controller.dart';
import '../../theme/roam_theme.dart';
import '../widgets/glass_controls.dart';
import '../widgets/roam_chrome.dart';
import '../app_messenger.dart';

/// 编辑 App 图标。
/// 取自 pages/ChangeAppIconUI/main.lua：两组卡片——「默认图标」为 ROAM Explore Monet，
/// 「其他图标」依次为 星环 / Hero / 智慧 / 潮流。
/// 每张卡 15dp 圆角，内含 16dp 圆角的 100dp 图标块、名称与 50dp 高的
/// 360dp 圆角「设置为图标」按钮。
class AppIconPage extends StatelessWidget {
  const AppIconPage({super.key, required this.controller});

  final BrowserController controller;

  static const _others = [
    ('explore', '星环', 'assets/images/ic_launcher_explorelogo.png'),
    ('hero', 'Hero', 'assets/images/ic_launcher_hero.png'),
    ('intelligence', '智慧', 'assets/images/ic_launcher_intelligence.png'),
    ('fashion', '潮流', 'assets/images/ic_launcher_fashion.png'),
  ];

  Future<void> _pick(BuildContext context, String key) async {
    await controller.updateSettings(controller.settings.copyWith(appIcon: key));
    if (!context.mounted) return;
    showRoamToast(
      '已更改图标，需要重新启动 App',
      duration: const Duration(milliseconds: 1800),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: controller,
      builder: (context, _) {
        final current = controller.settings.appIcon;
        return RoamPageScaffold(
          title: '编辑 App 图标',
          child: ListView(
            padding: EdgeInsets.only(
              top: RoamPageScaffold.topPadding(context) + 2,
              bottom: 40,
            ),
            physics: const BouncingScrollPhysics(),
            children: [
              const RoamGroupHeader(text: '默认图标'),
              _IconCard(
                title: 'ROAM Explore Monet',
                asset: 'assets/images/ic_launcher.png',
                selected: current == 'default',
                onApply: () => _pick(context, 'default'),
              ),
              const RoamGroupHeader(text: '其他图标'),
              for (final item in _others)
                _IconCard(
                  title: item.$2,
                  asset: item.$3,
                  selected: current == item.$1,
                  onApply: () => _pick(context, item.$1),
                ),
              const SizedBox(height: 10),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 27),
                child: Text(
                  '更换图标后需要重新启动星环，桌面上的图标才会更新。',
                  style: TextStyle(
                    fontSize: 12,
                    height: 1.5,
                    color:
                        (Theme.of(context).brightness == Brightness.dark
                                ? RoamColors.textPrimary
                                : RoamColors.dayInk)
                            .withValues(alpha: 0.45),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _IconCard extends StatelessWidget {
  const _IconCard({
    required this.title,
    required this.asset,
    required this.selected,
    required this.onApply,
  });

  final String title;
  final String asset;
  final bool selected;
  final VoidCallback onApply;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final fg = isDark ? RoamColors.textPrimary : RoamColors.dayInk;
    return Padding(
      padding: const EdgeInsets.fromLTRB(25, 5.2, 25, 5.2),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(15),
          color: isDark ? RoamColors.cardDark : RoamColors.cardLight,
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(15),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(14, 14, 14, 14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Container(
                  height: 100,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(16),
                    color: (isDark ? Colors.white : Colors.black).withValues(
                      alpha: isDark ? 0.05 : 0.03,
                    ),
                  ),
                  alignment: Alignment.center,
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(16),
                    child: Image.asset(
                      asset,
                      height: 100,
                      width: 100,
                      fit: BoxFit.cover,
                    ),
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: fg,
                  ),
                ),
                const SizedBox(height: 10),
                PressableScale(
                  onTap: selected ? null : onApply,
                  scale: 0.97,
                  child: Container(
                    height: 50,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(360),
                      color: selected
                          ? (isDark ? Colors.white : Colors.black).withValues(
                              alpha: isDark ? 0.08 : 0.04,
                            )
                          : (isDark ? Colors.white : RoamColors.dayInk),
                      border: Border.all(
                        color: (isDark ? Colors.white : Colors.black)
                            .withValues(alpha: selected ? 0.1 : 0),
                      ),
                    ),
                    child: Text(
                      selected ? '当前图标' : '设置为图标',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: selected
                            ? fg.withValues(alpha: 0.45)
                            : (isDark ? RoamColors.dayInk : Colors.white),
                      ),
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
