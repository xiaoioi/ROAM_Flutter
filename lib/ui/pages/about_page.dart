// ignore_for_file: deprecated_member_use

import 'dart:io';

import 'package:flutter/material.dart';

import '../../theme/roam_theme.dart';
import '../widgets/glass_controls.dart';
import '../widgets/roam_chrome.dart';
import '../widgets/roam_sheet.dart';

/// 关于。
/// 严格按 pages/AboutSoftware/main.lua：
/// 顶栏 60dp，logo 高 36.86dp（其下「基于 Flutter 构建」）、版本号 100.3、
/// 210×50dp、360dp 圆角的「软件更新」按钮；
/// 四组 15dp 圆角卡片——软件与版本信息（含「增强特性」行）、设备与系统信息、
/// 软件产品法律信息、许可与服务协议，行间 1dp 分隔线。
class AboutPage extends StatelessWidget {
  const AboutPage({super.key});

  static const _version = '100.3';

  static const _enhancements = [
    'Windmill 预测性手势支持',
    '星环「听见」音效均衡器',
    'Vulkan 网页渲染API',
    'EasyGo 平行视界',
    '新一代浏览器内核平台',
    '新一代浏览器内核平台增强型优化',
    '黑白韵调相机滤镜',
    'QmBlurView For ROAM Explore',
    'HDR 高光能力',
    'Dolby Vision 杜比视界 API',
    'App Shortcut 快捷磁贴',
    'Web Game 渲染优化',
    '星环无极可变字体交互框架',
  ];

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final fg = isDark ? RoamColors.textPrimary : RoamColors.dayInk;
    final media = MediaQuery.of(context);
    final dpr = media.devicePixelRatio;
    final size = media.size;

    return RoamPageScaffold(
      title: '关于',
      child: ListView(
        padding: const EdgeInsets.only(
          top: RoamPageScaffold.contentTopPadding,
          bottom: 40,
        ),
        physics: const BouncingScrollPhysics(),
        children: [
          const SizedBox(height: 36),
          Center(
            child: Image.asset(
              'assets/images/roam_explore_logo.png',
              height: 36.86,
              fit: BoxFit.contain,
            ),
          ),
          const SizedBox(height: 8),
          Center(
            child: Text(
              '基于 Flutter 构建',
              style: TextStyle(
                fontSize: 12,
                letterSpacing: 0.6,
                color: fg.withValues(alpha: 0.45),
              ),
            ),
          ),
          const SizedBox(height: 16),
          Center(
            child: Text(
              _version,
              style: TextStyle(
                fontSize: 26,
                fontWeight: FontWeight.w700,
                letterSpacing: 1,
                color: fg,
              ),
            ),
          ),
          const SizedBox(height: 18),
          Center(
            child: PressableScale(
              onTap: () => _checkUpdate(context),
              scale: 0.96,
              child: Container(
                width: 210,
                height: 50,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(360),
                  color: isDark ? Colors.white : RoamColors.dayInk,
                ),
                child: Text(
                  '软件更新',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: isDark ? RoamColors.dayInk : Colors.white,
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 20),
          const RoamGroupHeader(text: '软件与版本信息'),
          RoamSettingCard(
            children: [
              _InfoRow(label: '软件名称', value: '星环 · ROAM AI Explore'),
              _InfoRow(label: '产品型号', value: 'Roam Flutter'),
              _InfoRow(label: '软件版本', value: _version),
              _InfoRow(label: '软件版本标识', value: '100.3Beta4 · Flutter 重构版'),
              _InfoRow(label: '编译日期', value: '2026-11-13'),
              _InfoRow(
                label: '增强特性',
                value:
                    '${_enhancements.take(3).join('\n')}\n等 ${_enhancements.length} 项',
                onTap: () => _showEnhancements(context),
              ),
              _InfoRow(label: '软件安全更新级别', value: '2026-11'),
              _InfoRow(label: '内核版本', value: _systemName(), last: true),
            ],
          ),
          const RoamGroupHeader(text: '设备与系统信息'),
          RoamSettingCard(
            children: [
              _InfoRow(label: '系统版本', value: _systemVersion()),
              _InfoRow(
                label: '语言与地区',
                value: '${Localizations.localeOf(context)} · 简体中文',
              ),
              _InfoRow(label: '设备', value: _deviceName()),
              _InfoRow(
                label: '屏幕分辨率',
                value:
                    '${(size.width * dpr).round()} × ${(size.height * dpr).round()}',
              ),
              _InfoRow(label: 'WebKit', value: _webEngineName(), last: true),
            ],
          ),
          const RoamGroupHeader(text: '软件产品法律信息'),
          RoamSettingCard(
            children: [
              _InfoRow(label: 'App 备案号', value: '已按国家规定完成备案'),
              _InfoRow(label: '著作权登记证书', value: '软著登字第17704850号', last: true),
            ],
          ),
          const RoamGroupHeader(text: '许可与服务协议'),
          RoamSettingCard(
            children: [
              RoamSettingRow(
                icon: 'assets/images/safe.png',
                label: '本应用自觉遵守《Android 绿色应用公约》',
                onTap: () => _sheet(
                  context,
                  'Android 绿色应用公约',
                  '星环承诺不强行唤醒、不偷跑流量、不滥发通知，'
                      '所有权限都在使用时才向你申请。',
                ),
              ),
              RoamSettingRow(
                icon: 'assets/images/creation.png',
                label: '星环团队荣誉出品',
                subtitle: 'NWind 北风架构 Xe',
                onTap: () => _sheet(
                  context,
                  '星环团队荣誉出品',
                  '第二代 NWind 北风架构：Xe / X / Pro / ULTRA / Pro Max / Pro，'
                      '星环网络优化单元（感知能力）。',
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          Center(
            child: Text(
              '星环团队荣誉出品',
              style: TextStyle(fontSize: 12, color: fg.withValues(alpha: 0.35)),
            ),
          ),
          const SizedBox(height: 20),
        ],
      ),
    );
  }

  /// 鸿蒙（OpenHarmony 版 Flutter）上 `Platform.operatingSystem` 是 `ohos`。
  static bool get _isOhos => Platform.operatingSystem == 'ohos';

  static String _systemName() {
    if (Platform.isAndroid) return 'Android';
    if (_isOhos) return 'HarmonyOS';
    if (Platform.isLinux) return 'Linux';
    if (Platform.isMacOS) return 'macOS';
    if (Platform.isWindows) return 'Windows';
    return Platform.operatingSystem;
  }

  static String _systemVersion() {
    if (Platform.isAndroid) return _androidVersion();
    if (_isOhos) return Platform.operatingSystemVersion;
    return Platform.operatingSystem;
  }

  static String _deviceName() {
    if (Platform.isAndroid) return 'Android 设备';
    if (_isOhos) return 'HarmonyOS 设备';
    return '${_systemName()} 桌面';
  }

  static String _webEngineName() {
    if (Platform.isAndroid) return 'Android System WebView';
    if (_isOhos) return 'ArkWeb 内核';
    return '系统 WebView';
  }

  static String _androidVersion() {
    final raw = Platform.operatingSystemVersion;
    final match = RegExp(r'Android[^,]*').firstMatch(raw);
    return match?.group(0) ?? 'Android';
  }

  Future<void> _checkUpdate(BuildContext context) async {
    await showRoamSheet<void>(
      context: context,
      title: '软件更新',
      children: [
        Text(
          '当前版本 $_version 已是最新版本。',
          style: TextStyle(
            fontSize: 13,
            height: 1.6,
            color:
                (Theme.of(context).brightness == Brightness.dark
                        ? RoamColors.textPrimary
                        : RoamColors.dayInk)
                    .withValues(alpha: 0.7),
          ),
        ),
      ],
    );
  }

  Future<void> _sheet(BuildContext context, String title, String body) async {
    await showRoamSheet<void>(
      context: context,
      title: title,
      children: [
        Text(
          body,
          style: TextStyle(
            fontSize: 13,
            height: 1.6,
            color:
                (Theme.of(context).brightness == Brightness.dark
                        ? RoamColors.textPrimary
                        : RoamColors.dayInk)
                    .withValues(alpha: 0.7),
          ),
        ),
      ],
    );
  }

  Future<void> _showEnhancements(BuildContext context) async {
    await showRoamSheet<void>(
      context: context,
      title: '增强特性',
      children: [
        for (final item in _enhancements)
          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: Text(
              item,
              style: TextStyle(
                fontSize: 13,
                height: 1.5,
                color:
                    (Theme.of(context).brightness == Brightness.dark
                            ? RoamColors.textPrimary
                            : RoamColors.dayInk)
                        .withValues(alpha: 0.72),
              ),
            ),
          ),
      ],
    );
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({
    required this.label,
    required this.value,
    this.last = false,
    this.onTap,
  });

  final String label;
  final String value;
  final bool last;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final fg = isDark ? RoamColors.textPrimary : RoamColors.dayInk;
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Container(
        padding: const EdgeInsets.fromLTRB(9, 10, 14, 10),
        decoration: BoxDecoration(
          border: last
              ? null
              : Border(bottom: BorderSide(color: fg.withValues(alpha: 0.06))),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label, style: TextStyle(fontSize: 15, color: fg)),
            const SizedBox(width: 16),
            Expanded(
              child: Text(
                value,
                textAlign: TextAlign.right,
                style: TextStyle(
                  fontSize: 12.5,
                  height: 1.45,
                  color: fg.withValues(alpha: 0.45),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
