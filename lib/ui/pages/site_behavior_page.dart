// ignore_for_file: deprecated_member_use

import 'package:flutter/material.dart';
import 'package:flutter_miuix/miuix.dart';

import '../../models/browser_models.dart';
import '../../state/browser_controller.dart';
import '../../theme/roam_theme.dart';
import '../widgets/roam_chrome.dart';

/// 网站行为管控。
///
/// 还原 `pages/BehaviorControl/main.lua`：应用列表 / 位置信息 / JavaScript /
/// 剪贴板 / 相机五组开关。原版这些开关只是写 `appConfig_*` 键，Flutter 版
/// 直接接进能力管线：
///
/// * 相机 / 定位在 [WebPermissionService] 里先过全局开关，关掉连确认框都不弹；
/// * 定位关闭「精确位置」时只申请粗略定位（Android 12 的近似位置语义）；
/// * 剪贴板读取走逐站确认，写入是纯开关（垫片里直接拒绝）；
/// * 应用列表的两项在控制器外跳链路里拦截。
class SiteBehaviorPage extends StatelessWidget {
  const SiteBehaviorPage({super.key, required this.controller});

  final BrowserController controller;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: controller,
      builder: (context, _) {
        final s = controller.settings;
        void set(BrowserSettings next) => controller.updateSettings(next);
        return RoamPageScaffold(
          title: '网站行为管控',
          child: ListView(
            padding: EdgeInsets.only(
              top: RoamPageScaffold.topPadding(context) + 2,
              bottom: 40,
            ),
            physics: const BouncingScrollPhysics(),
            children: [
              const MiuixSmallTitle('应用列表'),
              RoamSettingCard(
                children: [
                  _SwitchRow(
                    icon: 'assets/images/behavior_control.png',
                    label: '允许网站跳转到 App',
                    subtitle: '关闭后不影响网站跳转到对应的 App 操作',
                    value: s.allowAppRedirect,
                    onChanged: (v) => set(s.copyWith(allowAppRedirect: v)),
                  ),
                  _SwitchRow(
                    icon: 'assets/images/plugin.png',
                    label: '只允许获取系统应用（Beta）',
                    subtitle: '仅放行电话、短信、邮件、应用商店等系统协议',
                    value: s.systemAppOnlyRedirect,
                    enabled: s.allowAppRedirect,
                    onChanged: (v) =>
                        set(s.copyWith(systemAppOnlyRedirect: v)),
                  ),
                ],
              ),
              const MiuixSmallTitle('位置信息'),
              RoamSettingCard(
                children: [
                  _SwitchRow(
                    icon: 'assets/images/track_changes.png',
                    label: '允许所有网站获取',
                    subtitle: '关闭后将影响网站获取设备的地理位置信息',
                    value: s.allowLocation,
                    onChanged: (v) => set(s.copyWith(allowLocation: v)),
                  ),
                  _SwitchRow(
                    icon: 'assets/images/device.png',
                    label: '精确位置',
                    subtitle: '关闭后只提供大致范围，站点无法定位到街道',
                    value: s.preciseLocation,
                    enabled: s.allowLocation,
                    onChanged: (v) => set(s.copyWith(preciseLocation: v)),
                  ),
                ],
              ),
              const MiuixSmallTitle('JavaScript'),
              RoamSettingCard(
                children: [
                  _SwitchRow(
                    icon: 'assets/images/JavaScript.png',
                    label: '允许所有网站加载',
                    subtitle: '关闭后将影响网站的正常浏览',
                    value: s.javascriptEnabled,
                    onChanged: (v) =>
                        set(s.copyWith(javascriptEnabled: v)),
                  ),
                ],
              ),
              const MiuixSmallTitle('剪贴板'),
              RoamSettingCard(
                children: [
                  _SwitchRow(
                    icon: 'assets/images/clipboard.png',
                    label: '允许所有网站读取',
                    subtitle: '支持管理读取到系统剪贴板，首次读取仍会逐站确认',
                    value: s.allowClipboardRead,
                    onChanged: (v) => set(s.copyWith(allowClipboardRead: v)),
                  ),
                  _SwitchRow(
                    icon: 'assets/images/password-manager.png',
                    label: '允许所有网站写入',
                    subtitle: '关闭后网站无法把内容写入剪贴板',
                    value: s.allowClipboardWrite,
                    onChanged: (v) => set(s.copyWith(allowClipboardWrite: v)),
                  ),
                ],
              ),
              const MiuixSmallTitle('相机'),
              RoamSettingCard(
                children: [
                  _SwitchRow(
                    icon: 'assets/images/camera.png',
                    label: '允许启动相机',
                    subtitle: '关闭后影响网站调用相机拍摄',
                    value: s.allowCamera,
                    onChanged: (v) => set(s.copyWith(allowCamera: v)),
                  ),
                ],
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(30, 14, 30, 0),
                child: Text(
                  '开关立即生效。已记住的站点授权仍然保留，但会被这里的总开关先拦一道；'
                  'JavaScript 与相机修改后，已打开的网页需要刷新一次。',
                  style: TextStyle(
                    fontSize: 12,
                    height: 1.55,
                    color: (Theme.of(context).brightness == Brightness.dark
                            ? RoamColors.textPrimary
                            : RoamColors.dayInk)
                        .withValues(alpha: 0.42),
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

class _SwitchRow extends StatelessWidget {
  const _SwitchRow({
    required this.icon,
    required this.label,
    required this.value,
    required this.onChanged,
    this.subtitle,
    this.enabled = true,
  });

  final String icon;
  final String label;
  final String? subtitle;
  final bool value;
  final ValueChanged<bool> onChanged;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final fg = isDark ? RoamColors.textPrimary : RoamColors.dayInk;
    return RoamSettingRow(
      icon: icon,
      label: label,
      subtitle: subtitle,
      showChevron: false,
      labelColor: enabled ? null : fg.withValues(alpha: 0.38),
      onTap: enabled ? () => onChanged(!value) : () {},
      trailing: RoamSwitch(
        value: value,
        onChanged: enabled ? onChanged : null,
      ),
    );
  }
}
