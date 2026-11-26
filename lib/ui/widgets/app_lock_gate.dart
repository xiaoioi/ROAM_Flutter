// ignore_for_file: deprecated_member_use

import 'dart:async';

import 'package:flutter/material.dart';

import '../../services/app_lock_service.dart';
import '../../state/browser_controller.dart';
import '../../theme/roam_theme.dart';

/// 应用锁。
///
/// 对应原版 `app_feature/enable_app_lock`：启动与回到前台时盖一层解锁页，
/// 密码由 [AppLockService] 校验；开启「进入时验证机主身份」后，进来先尝试
/// 系统生物识别，失败或取消再回到密码。
///
/// 锁页是**覆盖层**而不是替换整棵树：底下的 [child] 一直挂着，解锁后
/// WebView 不会被重建（否则每次回前台都要重新加载页面）。
class AppLockGate extends StatefulWidget {
  const AppLockGate({
    super.key,
    required this.controller,
    required this.child,
  });

  final BrowserController controller;
  final Widget child;

  @override
  State<AppLockGate> createState() => _AppLockGateState();
}

class _AppLockGateState extends State<AppLockGate>
    with WidgetsBindingObserver {
  bool _locked = false;
  String _pin = '';
  String? _error;
  DateTime? _leftAt;
  bool _promptingOwner = false;

  static const _maxPinLength = AppLockService.maxLength;

  bool get _shouldLock {
    final settings = widget.controller.settings;
    return settings.appLockEnabled && AppLockService.instance.hasPin;
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    if (AppLockService.instance.isLoaded) {
      _locked = _shouldLock;
      if (_locked) {
        WidgetsBinding.instance.addPostFrameCallback((_) => _tryOwner());
      }
    } else {
      unawaited(_boot());
    }
  }

  /// 正常路径上 [AppLockService] 已在 `main()` 里预载；这里兜底，
  /// 避免首次进入时锁页晚一帧出现。
  Future<void> _boot() async {
    await AppLockService.instance.load();
    if (!mounted) return;
    if (!_shouldLock) return;
    setState(() => _locked = true);
    await _tryOwner();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    switch (state) {
      case AppLifecycleState.paused:
      case AppLifecycleState.hidden:
        _leftAt = DateTime.now();
      case AppLifecycleState.resumed:
        final leftAt = _leftAt;
        _leftAt = null;
        if (leftAt == null) return;
        // 切出去不到 2 秒（比如授权弹窗、通知栏）不重新上锁。
        if (DateTime.now().difference(leftAt) < const Duration(seconds: 2)) {
          return;
        }
        if (!_shouldLock || _locked) return;
        setState(() {
          _locked = true;
          _pin = '';
          _error = null;
        });
        unawaited(_tryOwner());
      case AppLifecycleState.inactive:
      case AppLifecycleState.detached:
        break;
    }
  }

  Future<void> _tryOwner() async {
    if (!mounted || _promptingOwner) return;
    if (!widget.controller.settings.verifyOnLaunch) return;
    _promptingOwner = true;
    try {
      final ok = await AppLockService.instance.confirmOwner(reason: '解锁星环');
      if (ok && mounted) {
        setState(() {
          _locked = false;
          _pin = '';
          _error = null;
        });
      }
    } finally {
      _promptingOwner = false;
    }
  }

  void _tap(String digit) {
    if (_pin.length >= _maxPinLength) return;
    setState(() {
      _pin += digit;
      _error = null;
    });
  }

  void _backspace() {
    if (_pin.isEmpty) return;
    setState(() {
      _pin = _pin.substring(0, _pin.length - 1);
      _error = null;
    });
  }

  Future<void> _verify() async {
    final pin = _pin;
    final ok = await AppLockService.instance.verifyPin(pin);
    if (!mounted || pin != _pin) return;
    if (ok) {
      setState(() {
        _locked = false;
        _pin = '';
        _error = null;
      });
      return;
    }
    setState(() => _error = '密码错误');
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        widget.child,
        if (_locked)
          Positioned.fill(
            child: _LockScreen(
              pin: _pin,
              error: _error,
              obscure: widget.controller.settings.hidePassword,
              canUseOwner: widget.controller.settings.verifyOnLaunch,
              onDigit: _tap,
              onBackspace: _backspace,
              onOwner: _tryOwner,
              onUnlock: _verify,
            ),
          ),
      ],
    );
  }
}

class _LockScreen extends StatelessWidget {
  const _LockScreen({
    required this.pin,
    required this.error,
    required this.obscure,
    required this.canUseOwner,
    required this.onDigit,
    required this.onBackspace,
    required this.onOwner,
    required this.onUnlock,
  });

  final String pin;
  final String? error;
  final bool obscure;
  final bool canUseOwner;
  final ValueChanged<String> onDigit;
  final VoidCallback onBackspace;
  final Future<void> Function() onOwner;
  final Future<void> Function() onUnlock;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final fg = isDark ? RoamColors.textPrimary : RoamColors.dayInk;
    final surface = isDark ? const Color(0xFF101114) : const Color(0xFFF4F5F7);
    return ColoredBox(
      color: surface,
      child: SafeArea(
        child: Column(
          children: [
            const Spacer(flex: 2),
            Container(
              width: 76,
              height: 76,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: fg.withValues(alpha: 0.06),
              ),
              child: Icon(
                Icons.lock_rounded,
                size: 34,
                color: fg.withValues(alpha: 0.72),
              ),
            ),
            const SizedBox(height: 18),
            Text(
              '星环已锁定',
              style: TextStyle(
                fontSize: 19,
                fontWeight: FontWeight.w600,
                color: fg,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              error ?? '输入应用锁密码继续',
              style: TextStyle(
                fontSize: 13,
                color: error != null
                    ? const Color(0xFFE5484D)
                    : fg.withValues(alpha: 0.45),
              ),
            ),
            const SizedBox(height: 26),
            _Dots(pin: pin, color: fg, obscure: obscure),
            const Spacer(flex: 2),
            _Keypad(
              onDigit: onDigit,
              onBackspace: onBackspace,
              biometric: canUseOwner ? onOwner : null,
            ),
            const SizedBox(height: 14),
            if (pin.length >= AppLockService.minLength)
              SizedBox(
                width: 200,
                height: 48,
                child: FilledButton(
                  onPressed: () => onUnlock(),
                  style: FilledButton.styleFrom(
                    backgroundColor: fg.withValues(alpha: 0.92),
                    foregroundColor: isDark ? Colors.black : Colors.white,
                  ),
                  child: const Text('解锁', style: TextStyle(fontSize: 15)),
                ),
              )
            else if (canUseOwner)
              TextButton(
                onPressed: () => onOwner(),
                child: Text(
                  '使用指纹 / 面容解锁',
                  style: TextStyle(
                    fontSize: 14,
                    color: fg.withValues(alpha: 0.6),
                  ),
                ),
              )
            else
              const SizedBox(height: 48),
            const SizedBox(height: 12),
          ],
        ),
      ),
    );
  }
}

class _Dots extends StatelessWidget {
  const _Dots({
    required this.pin,
    required this.color,
    required this.obscure,
  });

  final String pin;
  final Color color;

  /// 「不显示密码」关掉时直接把数字显示出来（原版同名开关的语义）。
  final bool obscure;

  @override
  Widget build(BuildContext context) {
    final count = pin.length;
    if (!obscure) {
      return SizedBox(
        height: 22,
        child: Text(
          pin,
          style: TextStyle(
            fontSize: 19,
            letterSpacing: 7,
            color: color.withValues(alpha: 0.86),
          ),
        ),
      );
    }
    final length = count > 6 ? count : 6;
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        for (var i = 0; i < length; i++)
          Container(
            width: 11,
            height: 11,
            margin: const EdgeInsets.symmetric(horizontal: 8),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: i < count
                  ? color.withValues(alpha: 0.86)
                  : color.withValues(alpha: 0.14),
            ),
          ),
      ],
    );
  }
}

class _Keypad extends StatelessWidget {
  const _Keypad({
    required this.onDigit,
    required this.onBackspace,
    this.biometric,
  });

  final ValueChanged<String> onDigit;
  final VoidCallback onBackspace;
  final Future<void> Function()? biometric;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final fg = isDark ? RoamColors.textPrimary : RoamColors.dayInk;
    Widget key(String label, {VoidCallback? onTap, Widget? child}) {
      return SizedBox(
        width: 78,
        height: 70,
        child: child != null
            ? GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: onTap,
                child: Center(child: child),
              )
            : TextButton(
                onPressed: onTap,
                style: TextButton.styleFrom(foregroundColor: fg),
                child: Text(
                  label,
                  style: const TextStyle(
                    fontSize: 26,
                    fontWeight: FontWeight.w400,
                  ),
                ),
              ),
      );
    }

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (final row in const [
          ['1', '2', '3'],
          ['4', '5', '6'],
          ['7', '8', '9'],
        ])
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [for (final d in row) key(d, onTap: () => onDigit(d))],
          ),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            SizedBox(
              width: 78,
              height: 70,
              child: biometric == null
                  ? null
                  : IconButton(
                      onPressed: () => biometric!(),
                      icon: Icon(
                        Icons.fingerprint_rounded,
                        size: 30,
                        color: fg.withValues(alpha: 0.55),
                      ),
                    ),
            ),
            key('0', onTap: () => onDigit('0')),
            SizedBox(
              width: 78,
              height: 70,
              child: IconButton(
                onPressed: onBackspace,
                icon: Icon(
                  Icons.backspace_outlined,
                  size: 24,
                  color: fg.withValues(alpha: 0.55),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }
}
