// ignore_for_file: deprecated_member_use

import 'package:flutter/material.dart';
import 'package:flutter_miuix/miuix.dart';

import '../../models/browser_models.dart';
import '../../services/app_lock_service.dart';
import '../../state/browser_controller.dart';
import '../../theme/roam_theme.dart';
import '../app_messenger.dart';
import '../widgets/confirm.dart';
import '../widgets/roam_chrome.dart';

/// 生物验证与锁定。
///
/// 还原 `pages/Biometrics/main.lua` 的「密码管理设置」卡片：不显示密码、
/// 进入时验证机主身份、应用锁密码保护、应用间跳转时验证，以及底部那句
/// 「若设备未设置锁屏密码，开启应用保护功能将无任何作用」。
///
/// 原版把开关写进 `app_feature/enable_app_lock` 等键，真正的验证交给
/// LuaActivity 的指纹弹窗。这里换成 [AppLockService]：密码只存加盐摘要，
/// 机主验证走系统 BiometricPrompt（不可用时回落设备凭据）。
class BiometricsPage extends StatefulWidget {
  const BiometricsPage({super.key, required this.controller});

  final BrowserController controller;

  @override
  State<BiometricsPage> createState() => _BiometricsPageState();
}

class _BiometricsPageState extends State<BiometricsPage> {
  /// 设备是否有机主验证能力（生物识别或锁屏密码）。
  bool _ownerAvailable = false;
  bool _checking = true;

  BrowserController get _controller => widget.controller;

  @override
  void initState() {
    super.initState();
    _checkOwner();
  }

  Future<void> _checkOwner() async {
    final available = await AppLockService.instance.ownerVerificationAvailable;
    if (!mounted) return;
    setState(() {
      _ownerAvailable = available;
      _checking = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final service = AppLockService.instance;
    return AnimatedBuilder(
      animation: Listenable.merge([_controller, service]),
      builder: (context, _) {
        final s = _controller.settings;
        void set(BrowserSettings next) => _controller.updateSettings(next);
        return RoamPageScaffold(
          title: '生物验证与锁定',
          child: ListView(
            padding: EdgeInsets.only(
              top: RoamPageScaffold.contentTopPadding + 2,
              bottom: 40,
            ),
            physics: const BouncingScrollPhysics(),
            children: [
              const MiuixSmallTitle('密码管理设置'),
              RoamSettingCard(
                children: [
                  _SwitchRow(
                    icon: 'assets/images/eye_off.png',
                    label: '不显示密码',
                    subtitle: '输入应用锁密码时以圆点掩码显示',
                    value: s.hidePassword,
                    onChanged: (v) => set(s.copyWith(hidePassword: v)),
                  ),
                  _SwitchRow(
                    icon: 'assets/images/fingerprint.png',
                    label: '进入时验证机主身份',
                    subtitle: _ownerAvailable
                        ? '解锁时优先使用指纹 / 面容，不可用再输入密码'
                        : '当前设备没有可用的生物识别或锁屏密码',
                    value: s.verifyOnLaunch,
                    enabled: !_checking,
                    onChanged: (v) => _toggleVerifyOnLaunch(v, s),
                  ),
                  _SwitchRow(
                    icon: 'assets/images/phone-lock.png',
                    label: '应用锁密码保护',
                    subtitle: service.hasPin ? '启动星环需要输入应用锁密码' : '先设置一个 4 位以上的密码',
                    value: s.appLockEnabled,
                    onChanged: (v) => _toggleAppLock(v, s),
                  ),
                  _SwitchRow(
                    icon: 'assets/images/lock.png',
                    label: '应用间跳转时验证',
                    subtitle: '网站拉起其他 App 前先验证机主身份',
                    value: s.verifyOnExternal,
                    enabled: !_checking,
                    onChanged: (v) => _toggleVerifyOnExternal(v, s),
                  ),
                ],
              ),
              if (service.hasPin) ...[
                const MiuixSmallTitle('应用锁'),
                RoamSettingCard(
                  children: [
                    RoamSettingRow(
                      icon: 'assets/images/key.png',
                      label: '修改应用锁密码',
                      subtitle: '不修改则保持原密码',
                      onTap: _changePin,
                    ),
                    RoamSettingRow(
                      icon: 'assets/images/delete.png',
                      label: '清除应用锁密码',
                      subtitle: '清除后应用锁会自动关闭',
                      onTap: _clearPin,
                    ),
                  ],
                ),
              ],
              Padding(
                padding: const EdgeInsets.fromLTRB(30, 16, 30, 0),
                child: Text(
                  '若设备未设置锁屏密码，开启应用保护功能将无任何作用。\n'
                  '应用锁密码只保存在本机（加盐摘要），不会上传，也无法找回；'
                  '忘记密码时可在系统设置中清除星环的应用数据。',
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

  Future<void> _toggleAppLock(bool value, BrowserSettings s) async {
    final service = AppLockService.instance;
    if (!value) {
      await _controller.updateSettings(s.copyWith(appLockEnabled: false));
      _toast('已关闭应用锁');
      return;
    }
    if (service.hasPin) {
      await _controller.updateSettings(s.copyWith(appLockEnabled: true));
      _toast('已打开应用锁');
      return;
    }
    final pin = await _askPin(
      context,
      title: '设置应用锁密码',
      message: '密码用于解锁星环，至少 ${AppLockService.minLength} 位，请牢记。',
    );
    if (pin == null) return;
    if (pin.length < AppLockService.minLength) {
      _toast('密码至少 ${AppLockService.minLength} 位');
      return;
    }
    await service.setPin(pin);
    await _controller.updateSettings(s.copyWith(appLockEnabled: true));
    _toast('已打开应用锁');
  }

  Future<void> _toggleVerifyOnLaunch(bool value, BrowserSettings s) async {
    if (value && !_ownerAvailable && !AppLockService.instance.hasPin) {
      _toast('设备没有可用的机主验证方式');
      return;
    }
    await _controller.updateSettings(s.copyWith(verifyOnLaunch: value));
  }

  Future<void> _toggleVerifyOnExternal(bool value, BrowserSettings s) async {
    if (value && !_ownerAvailable && !AppLockService.instance.hasPin) {
      _toast('设备没有可用的机主验证方式');
      return;
    }
    await _controller.updateSettings(s.copyWith(verifyOnExternal: value));
  }

  Future<void> _changePin() async {
    final service = AppLockService.instance;
    final oldPin = await _askPin(
      context,
      title: '验证当前密码',
      message: '先输入当前的应用锁密码。',
    );
    if (oldPin == null) return;
    final ok = await service.verifyPin(oldPin);
    if (!ok) {
      _toast('密码错误');
      return;
    }
    if (!mounted) return;
    final next = await _askPin(
      context,
      title: '设置新密码',
      message: '至少 ${AppLockService.minLength} 位。',
    );
    if (next == null) return;
    if (next.length < AppLockService.minLength) {
      _toast('密码至少 ${AppLockService.minLength} 位');
      return;
    }
    await service.setPin(next);
    _toast('密码已更新');
  }

  Future<void> _clearPin() async {
    final confirmed = await showRoamConfirm(
      context: context,
      title: '清除应用锁密码',
      message: '清除后应用锁会一并关闭，下次需要重新设置密码才能开启。',
      confirmLabel: '清除',
      destructive: true,
    );
    if (!confirmed) return;
    final s = _controller.settings;
    await AppLockService.instance.clearPin();
    await _controller.updateSettings(
      s.copyWith(appLockEnabled: false, verifyOnLaunch: false),
    );
    _toast('已清除应用锁密码');
  }

  /// 输入密码的小弹层：掩码跟随「不显示密码」开关。
  Future<String?> _askPin(
    BuildContext context, {
    required String title,
    required String message,
  }) async {
    final text = TextEditingController();
    final obscure = _controller.settings.hidePassword;
    final result = await showRoamDialog<bool>(
      context: context,
      title: title,
      message: message,
      body: Padding(
        padding: const EdgeInsets.only(top: 16),
        child: MiuixTextField(
          controller: text,
          autofocus: true,
          singleLine: true,
          obscureText: obscure,
          keyboardType: TextInputType.number,
          label: '应用锁密码',
          useLabelAsPlaceholder: true,
          onSubmitted: (value) =>
              Navigator.of(context, rootNavigator: true).pop(true),
        ),
      ),
      actions: [
        const RoamDialogAction(label: '取消', value: false),
        const RoamDialogAction(label: '确定', value: true, primary: true),
      ],
    );
    final value = text.text.trim();
    text.dispose();
    return result == true ? value : null;
  }

  void _toast(String message) {
    if (!mounted) return;
    showRoamToast(message);
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
