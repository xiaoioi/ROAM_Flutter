import 'dart:io';

import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';

/// 外部链接 / 系统能力桥接。
///
/// 网页里的 `intent://`、`weixin://`、`alipays://`、`bilibili://` 这类协议，
/// 以及 tel:/mailto:/market:，Flutter 侧无法自己发起，必须交给系统。
///
/// 之前用 `url_launcher` 的 `canLaunchUrl`：Android 11 起受包可见性限制，
/// 没有在 `<queries>` 里声明的第三方 scheme 一律返回 false，于是点了没反应。
/// 这里改为直接走原生 `startActivity`（隐式 Intent 不受包可见性限制）与
/// 鸿蒙的 `startAbility`，`url_launcher` 只作为兜底。
class SystemBridge {
  SystemBridge._();

  static const MethodChannel _channel = MethodChannel(
    'org.roam.roam_flutter/system',
  );

  /// 当前平台是否有原生实现（Android / iOS / HarmonyOS）。
  static bool get _hasNative =>
      Platform.isAndroid ||
      Platform.isIOS ||
      Platform.operatingSystem == 'ohos';

  /// 打开一个外部协议链接。
  ///
  /// 返回原生侧的处理结果；`fallbackUrl` 是 `intent://` 里携带的
  /// `S.browser_fallback_url`，用于「没装 App 就回网页」的场景。
  static Future<ExternalLaunchResult> openExternal(
    String url, {
    String? referer,
  }) async {
    // 鸿蒙不认识 intent://，先在 Dart 侧拆成真实 scheme。
    final intent = AndroidIntent.tryParse(url);
    final target = intent?.targetUrl ?? url;

    if (_hasNative) {
      try {
        final raw = await _channel.invokeMethod<String>('openExternal', {
          'url': target,
          'referer': referer,
        });
        switch (raw) {
          case 'opened':
            return const ExternalLaunchResult(ExternalLaunchStatus.opened);
          case null:
            break;
          default:
            if (raw.startsWith('fallback:')) {
              return ExternalLaunchResult(
                ExternalLaunchStatus.noHandler,
                fallbackUrl: raw.substring('fallback:'.length),
              );
            }
            if (raw.startsWith('failed:')) {
              return ExternalLaunchResult(
                ExternalLaunchStatus.failed,
                message: raw.substring('failed:'.length),
              );
            }
            return const ExternalLaunchResult(ExternalLaunchStatus.noHandler);
        }
      } on MissingPluginException {
        // 原生通道没注册（例如桌面端），继续走 Dart 兜底。
      } catch (_) {
        // 落到下面的兜底逻辑。
      }
    }

    if (await _launchWithUrlLauncher(target)) {
      return const ExternalLaunchResult(ExternalLaunchStatus.opened);
    }
    return ExternalLaunchResult(
      ExternalLaunchStatus.noHandler,
      fallbackUrl: intent?.fallbackUrl,
    );
  }

  static Future<bool> _launchWithUrlLauncher(String url) async {
    try {
      final uri = Uri.tryParse(url);
      if (uri == null) return false;
      if (!await canLaunchUrl(uri)) return false;
      return await launchUrl(uri, mode: LaunchMode.externalApplication);
    } catch (_) {
      return false;
    }
  }

  /// 申请系统运行时权限（相机 / 麦克风 / 定位）。
  ///
  /// 网页通过 `getUserMedia`、`geolocation` 请求设备时，WebView 只是把请求
  /// 转给我们；真正能不能拿到硬件，取决于宿主 App 是否已获得系统授权。
  ///
  /// [preciseLocation] 为 false 时只申请粗略定位（Android 12 起系统本来也
  /// 允许用户只给大致位置，这里对应「精确位置」开关）。
  static Future<bool> ensurePermissions(
    List<String> kinds, {
    bool preciseLocation = true,
  }) async {
    if (kinds.isEmpty) return true;
    if (!_hasNative) return true;
    try {
      final granted = await _channel.invokeMethod<bool>('ensurePermissions', {
        'kinds': kinds,
        'preciseLocation': preciseLocation,
      });
      return granted ?? false;
    } catch (_) {
      // 原生通道缺失时不做拦截，交给 WebView 自己报错。
      return true;
    }
  }

  /// 验证机主身份：生物识别优先，回退设备凭据（锁屏密码 / 图案）。
  ///
  /// 鸿蒙与桌面端暂未接入，返回 [OwnerConfirmStatus.unavailable]，调用方
  /// 退回到应用锁密码。
  static Future<OwnerConfirmStatus> confirmOwner(String reason) async {
    if (!_hasNative) return OwnerConfirmStatus.unavailable;
    try {
      final raw = await _channel.invokeMethod<String>('confirmOwner', {
        'reason': reason,
      });
      return switch (raw) {
        'confirmed' => OwnerConfirmStatus.confirmed,
        'cancelled' => OwnerConfirmStatus.cancelled,
        'unavailable' => OwnerConfirmStatus.unavailable,
        null => OwnerConfirmStatus.failed,
        _ => OwnerConfirmStatus.failed,
      };
    } on MissingPluginException {
      return OwnerConfirmStatus.unavailable;
    } catch (_) {
      return OwnerConfirmStatus.failed;
    }
  }

  /// 设备是否具备机主验证能力（有生物识别硬件或设置了锁屏密码）。
  static Future<bool> ownerVerificationAvailable() async {
    if (!_hasNative) return false;
    try {
      return await _channel.invokeMethod<bool>('ownerVerificationAvailable') ??
          false;
    } catch (_) {
      return false;
    }
  }

  /// 读取系统剪贴板文本。
  ///
  /// 鸿蒙的 pasteboard 读取会由系统弹出「允许读取剪贴板」确认，Android 则
  /// 直接返回（系统会提示「已粘贴」），所以这里优先走原生，失败再回落到
  /// Flutter 的 Clipboard。
  static Future<String?> readClipboard() async {
    if (!_hasNative) return null;
    try {
      return await _channel.invokeMethod<String>('readClipboard');
    } catch (_) {
      return null;
    }
  }
}

/// 机主验证结果。
enum OwnerConfirmStatus {
  /// 通过（生物识别或设备凭据）。
  confirmed,

  /// 用户主动取消。
  cancelled,

  /// 设备没有可用的验证方式。
  unavailable,

  /// 调用失败（原生异常等）。
  failed,
}

enum ExternalLaunchStatus { opened, noHandler, failed }

class ExternalLaunchResult {
  const ExternalLaunchResult(this.status, {this.fallbackUrl, this.message});

  final ExternalLaunchStatus status;

  /// `intent://…#Intent;…S.browser_fallback_url=…;end` 里带的回退地址。
  final String? fallbackUrl;

  final String? message;

  bool get handled => status == ExternalLaunchStatus.opened;
}

/// Android `intent://` 协议解析。
///
/// 形如：
/// `intent://details?id=com.x#Intent;scheme=market;package=com.x;` +
/// `S.browser_fallback_url=https%3A%2F%2Fexample.com;end`
class AndroidIntent {
  const AndroidIntent({required this.targetUrl, this.fallbackUrl});

  final String targetUrl;
  final String? fallbackUrl;

  static AndroidIntent? tryParse(String url) {
    if (!url.startsWith('intent:')) return null;
    final marker = url.indexOf('#Intent;');
    final body = marker >= 0
        ? url.substring('intent:'.length, marker)
        : url.substring('intent:'.length);

    final params = <String, String>{};
    if (marker >= 0) {
      final tail = url.substring(marker + '#Intent;'.length);
      for (final part in tail.split(';')) {
        if (part.isEmpty || part == 'end') continue;
        final eq = part.indexOf('=');
        if (eq <= 0) continue;
        final key = part.substring(0, eq);
        final value = Uri.decodeComponent(part.substring(eq + 1));
        params[key] = value;
      }
    }

    final scheme = params['scheme'];
    if (scheme == null || scheme.isEmpty) return null;

    // intent://host/path?query → scheme://host/path?query
    // 注意 body 以 `//` 开头（intent://details…），要先去掉，
    // 否则会拼出 `scheme:////details`。
    var rest = body;
    while (rest.startsWith('/')) {
      rest = rest.substring(1);
    }
    final target = rest.isEmpty ? '$scheme://' : '$scheme://$rest';
    return AndroidIntent(
      targetUrl: target,
      fallbackUrl: params['S.browser_fallback_url'],
    );
  }
}
