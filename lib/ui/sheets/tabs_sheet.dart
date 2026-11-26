// ignore_for_file: deprecated_member_use

import 'package:flutter/material.dart';

import '../../models/browser_models.dart';
import '../../state/browser_controller.dart';
import '../../theme/roam_theme.dart';
import '../widgets/glass_controls.dart';
import '../widgets/roam_sheet.dart';

/// 标签总览：卡片式排列，当前标签带描边。
Future<void> showTabsSheet({
  required BuildContext context,
  required BrowserController controller,
}) {
  final isDark = Theme.of(context).brightness == Brightness.dark;
  final incognito = controller.tabs.where((tab) => tab.isIncognito).length;
  final subtitle = incognito == 0
      ? '${controller.tabs.length} 个标签页'
      : '${controller.tabs.length} 个标签页 · $incognito 个无痕';

  void close() => Navigator.of(context).pop();

  return showRoamSheet<void>(
    context: context,
    title: '标签页',
    subtitle: subtitle,
    children: [
      Row(
        children: [
          Expanded(
            child: _NewTabButton(
              icon: Icons.add_rounded,
              label: '新建标签',
              isDark: isDark,
              onTap: () {
                controller.newTab();
                close();
              },
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: _NewTabButton(
              icon: Icons.visibility_off_rounded,
              label: '无痕标签',
              isDark: isDark,
              onTap: () {
                controller.newTab(incognito: true);
                close();
              },
            ),
          ),
        ],
      ),
      const SizedBox(height: 14),
      GridView.builder(
        shrinkWrap: true,
        padding: EdgeInsets.zero,
        physics: const NeverScrollableScrollPhysics(),
        itemCount: controller.tabs.length,
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2,
          mainAxisSpacing: 10,
          crossAxisSpacing: 10,
          childAspectRatio: 0.92,
        ),
        itemBuilder: (context, index) {
          final tab = controller.tabs[index];
          return _TabCard(
            tab: tab,
            active: tab.id == controller.activeTab?.id,
            isDark: isDark,
            onTap: () {
              controller.selectTab(tab.id);
              close();
            },
            onClose: () {
              controller.closeTab(tab.id);
            },
          );
        },
      ),
    ],
  );
}

class _NewTabButton extends StatelessWidget {
  const _NewTabButton({
    required this.icon,
    required this.label,
    required this.isDark,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final bool isDark;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return PressableScale(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          color: (isDark ? Colors.white : Colors.black).withValues(alpha: 0.05),
          border: Border.all(
            color: (isDark ? Colors.white : Colors.black).withValues(
              alpha: 0.08,
            ),
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 18, color: RoamColors.aurora),
            const SizedBox(width: 7),
            Text(
              label,
              style: RoamType.caption.copyWith(
                fontSize: 12.5,
                color: isDark ? RoamColors.textPrimary : RoamColors.dayInk,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _TabCard extends StatelessWidget {
  const _TabCard({
    required this.tab,
    required this.active,
    required this.isDark,
    required this.onTap,
    required this.onClose,
  });

  final BrowserTab tab;
  final bool active;
  final bool isDark;
  final VoidCallback onTap;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    final accent = tab.isIncognito ? RoamColors.iris : _hueFor(tab.url);
    return PressableScale(
      onTap: onTap,
      scale: 0.965,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 220),
        padding: const EdgeInsets.fromLTRB(10, 9, 8, 10),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(18),
          color: (isDark ? Colors.white : Colors.black).withValues(
            alpha: active ? 0.085 : 0.04,
          ),
          border: Border.all(
            color: active
                ? RoamColors.aurora.withValues(alpha: 0.65)
                : (isDark ? Colors.white : Colors.black).withValues(
                    alpha: 0.07,
                  ),
            width: active ? 1.3 : 1,
          ),
          boxShadow: active
              ? [
                  BoxShadow(
                    color: RoamColors.aurora.withValues(alpha: 0.16),
                    blurRadius: 18,
                    offset: const Offset(0, 6),
                  ),
                ]
              : null,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 22,
                  height: 22,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(7),
                    gradient: LinearGradient(
                      colors: [
                        accent.withValues(alpha: 0.95),
                        Color.lerp(accent, Colors.black, 0.3) ?? accent,
                      ],
                    ),
                  ),
                  child: Center(
                    child: tab.isIncognito
                        ? const Icon(
                            Icons.visibility_off_rounded,
                            size: 12,
                            color: Colors.white,
                          )
                        : Text(
                            _glyph(tab),
                            style: const TextStyle(
                              fontSize: 11,
                              height: 1,
                              fontWeight: FontWeight.w700,
                              color: Colors.white,
                            ),
                          ),
                  ),
                ),
                const Spacer(),
                PressableScale(
                  onTap: onClose,
                  scale: 0.8,
                  child: Padding(
                    padding: const EdgeInsets.all(3),
                    child: Icon(
                      Icons.close_rounded,
                      size: 15,
                      color: isDark
                          ? RoamColors.textTertiary
                          : RoamColors.daySecondary,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 9),
            Text(
              tab.isHome ? '新标签页' : tab.title,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: RoamType.body.copyWith(
                fontSize: 12.5,
                height: 1.3,
                fontWeight: FontWeight.w600,
                color: isDark ? RoamColors.textPrimary : RoamColors.dayInk,
              ),
            ),
            const Spacer(),
            Text(
              tab.isHome ? '星环起始页' : _host(tab.url),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: RoamType.caption.copyWith(
                fontSize: 10.5,
                color: isDark
                    ? RoamColors.textTertiary
                    : RoamColors.daySecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }

  static String _glyph(BrowserTab tab) {
    if (tab.isHome) return '星';
    final host = _host(tab.url);
    if (host.isEmpty) return '·';
    return String.fromCharCode(host.runes.first).toUpperCase();
  }

  static String _host(String url) {
    final uri = Uri.tryParse(url);
    if (uri == null || uri.host.isEmpty) return url;
    return uri.host.startsWith('www.') ? uri.host.substring(4) : uri.host;
  }

  static Color _hueFor(String url) {
    const palette = [
      Color(0xFF3A7BD5),
      Color(0xFF8C7BFF),
      Color(0xFF17B99B),
      Color(0xFFE06C75),
      Color(0xFFD99A2B),
      Color(0xFF4AA8D8),
    ];
    if (url.isEmpty) return palette.first;
    return palette[url.hashCode.abs() % palette.length];
  }
}
