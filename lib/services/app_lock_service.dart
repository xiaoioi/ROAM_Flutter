import 'dart:convert';
import 'dart:math';

import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'system_bridge.dart';

/// 应用锁 / 机主验证。
///
/// 原版 `pages/Biometrics/main.lua` 管四件事：不显示密码、进入时验证机主身份、
/// 应用锁密码保护、应用间跳转时验证。这里把它们落到一份「应用锁密码 + 系统
/// 生物识别」的实现上：
///
/// * 密码只存 `salt$sha256(salt + pin + pepper)`，不落明文；
/// * 机主验证优先走系统生物识别，失败/不可用回退设备凭据（锁屏密码）；
/// * 密码本身不进入 `BrowserSettings`（设置要写进 SharedPreferences 的明文 JSON）。
class AppLockService extends ChangeNotifier {
  AppLockService._();

  static final AppLockService instance = AppLockService._();

  static const _pinKey = 'roam.app_lock.pin.v1';
  static const _pepper = 'roam.app_lock.v1';
  static const minLength = 4;
  static const maxLength = 12;

  String? _digest;
  bool _loaded = false;

  bool get hasPin => _loaded && _digest != null;

  bool get isLoaded => _loaded;

  Future<void> load() async {
    if (_loaded) return;
    final prefs = await SharedPreferences.getInstance();
    _digest = prefs.getString(_pinKey);
    _loaded = true;
    notifyListeners();
  }

  /// 设置 / 修改密码。返回 false 表示长度不合法。
  Future<bool> setPin(String pin) async {
    if (pin.length < minLength || pin.length > maxLength) return false;
    final salt = _randomSalt();
    _digest = '$salt\$${_hash(salt, pin)}';
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_pinKey, _digest!);
    notifyListeners();
    return true;
  }

  Future<void> clearPin() async {
    _digest = null;
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_pinKey);
    notifyListeners();
  }

  Future<bool> verifyPin(String pin) async {
    await load();
    final digest = _digest;
    if (digest == null) return false;
    final split = digest.indexOf(r'$');
    if (split <= 0) return false;
    final salt = digest.substring(0, split);
    final expected = digest.substring(split + 1);
    return _constantTimeEquals(_hash(salt, pin), expected);
  }

  /// 验证机主身份：生物识别 → 设备凭据 → 不可用。
  ///
  /// 返回 true 表示验证通过；不可用时也返回 false，调用方可以退回到
  /// 「输入应用锁密码」。
  Future<bool> confirmOwner({String reason = '验证机主身份'}) async {
    final result = await requestOwnerVerification(reason: reason);
    return result == OwnerConfirmStatus.confirmed;
  }

  /// 需要区分「用户取消」与「设备不支持」时用这个。
  Future<OwnerConfirmStatus> requestOwnerVerification({
    String reason = '验证机主身份',
  }) {
    return SystemBridge.confirmOwner(reason);
  }

  /// 当前设备是否有可能支持机主验证（用于解锁页是否显示指纹入口）。
  Future<bool> get ownerVerificationAvailable =>
      SystemBridge.ownerVerificationAvailable();

  static String _randomSalt() {
    final random = Random.secure();
    final bytes = List<int>.generate(16, (_) => random.nextInt(256));
    return base64Url.encode(bytes);
  }

  static String _hash(String salt, String pin) {
    return sha256.convert(utf8.encode('$salt|$pin|$_pepper')).toString();
  }

  static bool _constantTimeEquals(String a, String b) {
    if (a.length != b.length) return false;
    var diff = 0;
    for (var i = 0; i < a.length; i++) {
      diff |= a.codeUnitAt(i) ^ b.codeUnitAt(i);
    }
    return diff == 0;
  }
}
