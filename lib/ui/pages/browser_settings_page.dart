// ignore_for_file: deprecated_member_use

import 'package:flutter/material.dart';
import 'package:flutter_miuix/miuix.dart';

import '../../models/browser_models.dart';
import '../../state/browser_controller.dart';
import '../../theme/roam_theme.dart';
import '../widgets/glass_controls.dart';
import '../widgets/roam_chrome.dart';
import '../widgets/roam_sheet.dart';

/// 浏览器设置。
/// 严格按 pages/WebViewSettings/main.lua 的分组与顺序重建：
/// 浏览器标识 / 脚本与扩展 / 通用控制 / 内容元素控制 / 隐私与安全访问 / WebView 调试；
/// 组标题 15sp 粗体（上 10dp、下 5dp），卡片 15dp 圆角、上下 5.2dp，
/// 行内上下 10dp、图标 25dp（左 9dp）、文案 15sp（左 7dp）、行间 1dp 分隔线。
class BrowserSettingsPage extends StatelessWidget {
  const BrowserSettingsPage({super.key, required this.controller});

  final BrowserController controller;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: controller,
      builder: (context, _) {
        final s = controller.settings;
        void set(BrowserSettings next) => controller.updateSettings(next);
        return RoamPageScaffold(
          title: '浏览器设置',
          child: ListView(
            padding: EdgeInsets.only(
              top: RoamPageScaffold.topPadding(context) + 2,
              bottom: 40,
            ),
            physics: const BouncingScrollPhysics(),
            children: [
              const MiuixSmallTitle('浏览器标识'),
              RoamSettingCard(
                children: [
                  RoamSettingRow(
                    icon: 'assets/images/device.png',
                    label: '浏览器标识',
                    subtitle: s.desktopMode ? '桌面版 Chrome' : '默认（手机版）',
                    onTap: () => _userAgent(context),
                  ),
                ],
              ),
              const MiuixSmallTitle('脚本与扩展'),
              RoamSettingCard(
                children: [
                  _SwitchRow(
                    icon: 'assets/images/JavaScript.png',
                    label: 'JavaScript',
                    value: s.javascriptEnabled,
                    onChanged: (v) => set(s.copyWith(javascriptEnabled: v)),
                  ),
                ],
              ),
              const MiuixSmallTitle('通用控制'),
              RoamSettingCard(
                children: [
                  _SwitchRow(
                    icon: 'assets/images/back.png',
                    label: '边缘滑动返回/前进',
                    value: s.edgeSwipeBack,
                    onChanged: (v) => set(s.copyWith(edgeSwipeBack: v)),
                  ),
                  _SwitchRow(
                    icon: 'assets/images/adaptive.png',
                    label: '内容强制缩放',
                    value: s.forceZoom,
                    onChanged: (v) => set(s.copyWith(forceZoom: v)),
                  ),
                  _SwitchRow(
                    icon: 'assets/images/search_lc.png',
                    label: '放大镜',
                    value: s.magnifier,
                    onChanged: (v) => set(s.copyWith(magnifier: v)),
                  ),
                  _SwitchRow(
                    icon: 'assets/images/fullscreen.png',
                    label: '滑动时隐藏顶栏/底栏',
                    value: s.hideTopBarOnScroll,
                    onChanged: (v) => set(
                      s.copyWith(hideTopBarOnScroll: v, hideBottomBar: v),
                    ),
                  ),
                  _SwitchRow(
                    icon: 'assets/images/stacks_hardware_turbo.png',
                    label: '硬件加速',
                    value: s.hardwareAcceleration,
                    onChanged: (v) => set(s.copyWith(hardwareAcceleration: v)),
                  ),
                  _SwitchRow(
                    icon: 'assets/images/database.png',
                    label: '保存表单数据',
                    value: s.saveFormData,
                    onChanged: (v) => set(s.copyWith(saveFormData: v)),
                  ),
                ],
              ),
              const MiuixSmallTitle('内容元素控制'),
              RoamSettingCard(
                children: [
                  _SwitchRow(
                    icon: 'assets/images/image.png',
                    label: '不加载图片',
                    value: !s.loadImages,
                    onChanged: (v) => set(s.copyWith(loadImages: !v)),
                  ),
                  _SwitchRow(
                    icon: 'assets/images/refresh.png',
                    label: '网站重定向控制',
                    value: s.redirectControl,
                    onChanged: (v) => set(s.copyWith(redirectControl: v)),
                  ),
                  _SwitchRow(
                    icon: 'assets/images/lock.png',
                    label: '遮盖广告内容',
                    value: s.blockAds,
                    onChanged: (v) => set(s.copyWith(blockAds: v)),
                  ),
                ],
              ),
              const MiuixSmallTitle('隐私与安全访问'),
              RoamSettingCard(
                children: [
                  _SwitchRow(
                    icon: 'assets/images/alert.png',
                    label: '禁用 WebView 安全浏览',
                    value: !s.safeBrowsing,
                    onChanged: (v) => set(s.copyWith(safeBrowsing: !v)),
                  ),
                  _SwitchRow(
                    icon: 'assets/images/safe.png',
                    label: '忽略 SSL 证书异常',
                    value: s.ignoreSslErrors,
                    onChanged: (v) => set(s.copyWith(ignoreSslErrors: v)),
                  ),
                  _SwitchRow(
                    icon: 'assets/images/cookie.png',
                    label: '存储 Cookie',
                    value: s.storeCookie,
                    onChanged: (v) => set(s.copyWith(storeCookie: v)),
                  ),
                ],
              ),
              const MiuixSmallTitle('WebView 调试'),
              RoamSettingCard(
                children: [
                  _SwitchRow(
                    icon: 'assets/images/internet.png',
                    label: 'WebView 优化',
                    value: s.webViewOptimize,
                    onChanged: (v) => set(s.copyWith(webViewOptimize: v)),
                  ),
                  _SwitchRow(
                    icon: 'assets/images/settings.png',
                    label: 'WebView DevTools',
                    value: s.webViewDevTools,
                    onChanged: (v) => set(s.copyWith(webViewDevTools: v)),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _userAgent(BuildContext context) async {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final s = controller.settings;
    await showRoamSheet<void>(
      context: context,
      title: '浏览器标识',
      children: [
        _AgentChoice(
          label: '默认（手机版）',
          selected: !s.desktopMode,
          onTap: () async {
            await controller.setDesktopMode(false);
            if (context.mounted) Navigator.of(context).pop();
          },
        ),
        _AgentChoice(
          label: '桌面版 Chrome',
          selected: s.desktopMode,
          onTap: () async {
            await controller.setDesktopMode(true);
            if (context.mounted) Navigator.of(context).pop();
          },
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(4, 6, 4, 0),
          child: Text(
            '站点会按所选标识返回对应的页面版本，切换后需要重新加载网页。',
            style: TextStyle(
              fontSize: 12,
              height: 1.5,
              color: (isDark ? RoamColors.textPrimary : RoamColors.dayInk)
                  .withValues(alpha: 0.42),
            ),
          ),
        ),
      ],
    );
  }
}

class _SwitchRow extends StatelessWidget {
  const _SwitchRow({
    required this.icon,
    required this.label,
    required this.value,
    required this.onChanged,
  });

  final String icon;
  final String label;
  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return RoamSettingRow(
      icon: icon,
      label: label,
      showChevron: false,
      onTap: () => onChanged(!value),
      trailing: RoamSwitch(value: value, onChanged: onChanged),
    );
  }
}

class _AgentChoice extends StatelessWidget {
  const _AgentChoice({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final fg = isDark ? RoamColors.textPrimary : RoamColors.dayInk;
    return PressableScale(
      onTap: onTap,
      scale: 0.99,
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 15),
        decoration: roamGlassDecoration(context, radius: 15, elevated: false),
        child: Row(
          children: [
            Text(label, style: TextStyle(fontSize: 15, color: fg)),
            const Spacer(),
            if (selected)
              const Icon(
                Icons.check_rounded,
                size: 19,
                color: RoamColors.aurora,
              ),
          ],
        ),
      ),
    );
  }
}
