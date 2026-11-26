import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:webview_flutter_android/webview_flutter_android.dart';
import 'package:webview_flutter_ohos/webview_flutter_ohos.dart' as ohos;

import 'system_bridge.dart';

/// 网页能申请的敏感能力。
enum SitePermissionKind { camera, microphone, location, clipboard }

extension SitePermissionKindLabel on SitePermissionKind {
  String get label => switch (this) {
    SitePermissionKind.camera => '相机',
    SitePermissionKind.microphone => '麦克风',
    SitePermissionKind.location => '位置信息',
    SitePermissionKind.clipboard => '剪贴板',
  };

  String get reason => switch (this) {
    SitePermissionKind.camera => '拍摄照片或扫描二维码',
    SitePermissionKind.microphone => '录制语音、通话或语音输入',
    SitePermissionKind.location => '获取你当前所在的位置',
    SitePermissionKind.clipboard => '读取你剪贴板里的内容',
  };

  /// 传给原生侧申请系统权限的标识。
  String get nativeKey => switch (this) {
    SitePermissionKind.camera => 'camera',
    SitePermissionKind.microphone => 'microphone',
    SitePermissionKind.location => 'location',
    SitePermissionKind.clipboard => 'clipboard',
  };
}

/// 站点能力的全局开关（「网站行为管控」页）。
///
/// 与单站点的「记住选择」是两层：全局关掉就直接拒绝，连确认框都不弹。
@immutable
class SitePolicy {
  const SitePolicy({
    this.allowCamera = true,
    this.allowMicrophone = true,
    this.allowLocation = true,
    this.allowClipboardRead = true,
    this.allowClipboardWrite = true,
    this.preciseLocation = true,
  });

  final bool allowCamera;
  final bool allowMicrophone;
  final bool allowLocation;
  final bool allowClipboardRead;
  final bool allowClipboardWrite;
  final bool preciseLocation;

  bool allows(SitePermissionKind kind) => switch (kind) {
    SitePermissionKind.camera => allowCamera,
    SitePermissionKind.microphone => allowMicrophone,
    SitePermissionKind.location => allowLocation,
    SitePermissionKind.clipboard => allowClipboardRead,
  };
}

/// 一次待确认的站点权限申请。UI 拿到后需要调用
/// [WebPermissionService.approve] / [WebPermissionService.reject] 收尾。
class SitePermissionPrompt {
  SitePermissionPrompt({
    required this.origin,
    required this.host,
    required this.kinds,
  });

  final String origin;
  final String host;
  final Set<SitePermissionKind> kinds;
  final Completer<bool> _completer = Completer<bool>();
  bool remember = false;

  Future<bool> get result => _completer.future;

  void complete(bool allow) {
    if (!_completer.isCompleted) _completer.complete(allow);
  }
}

/// 网页权限中心：把 WebView 的相机/麦克风/定位/剪贴板请求统一成
/// 「弹一次 miuix 确认框 → 申请系统权限 → 回填结果」的流程。
///
/// 同一时刻只允许一个弹框，后来的请求排队；同一站点在同一会话里
/// 记住的选择会写进 SharedPreferences，下次直接放行 / 拒绝。
class WebPermissionService extends ChangeNotifier {
  WebPermissionService._();

  static final WebPermissionService instance = WebPermissionService._();

  static const _storeKey = 'roam.site_permissions.v1';

  final Map<String, Map<String, bool>> _decisions = {};

  /// 全局能力开关，由 [BrowserController] 在启动与设置变更时同步。
  SitePolicy policy = const SitePolicy();

  SitePermissionPrompt? _pending;
  Future<void> _queue = Future<void>.value();
  bool _loaded = false;

  /// 当前正在等待用户确认的申请，null 表示没有。
  SitePermissionPrompt? get pending => _pending;

  /// 同步全局开关；已记住的站点选择不受影响，但会被开关先拦一道。
  void applyPolicy(SitePolicy next) {
    policy = next;
    notifyListeners();
  }

  Future<void> _ensureLoaded() async {
    if (_loaded) return;
    _loaded = true;
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_storeKey);
      if (raw == null || raw.isEmpty) return;
      final decoded = jsonDecode(raw);
      if (decoded is Map) {
        decoded.forEach((key, value) {
          if (value is Map) {
            _decisions['$key'] = value.map((k, v) => MapEntry('$k', v == true));
          }
        });
      }
    } catch (_) {
      // 存储损坏时当作没有任何记录。
    }
  }

  Future<void> _persist() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_storeKey, jsonEncode(_decisions));
    } catch (_) {
      // 写入失败不影响本次会话。
    }
  }

  /// 申请一组权限，返回是否全部放行。
  ///
  /// [origin] 用完整 origin 做键（例如 https://example.com），
  /// [host] 只用于展示。多个请求会排队，同一时刻只弹一个确认框。
  Future<bool> request(
    String origin,
    String host,
    Set<SitePermissionKind> kinds,
  ) {
    if (kinds.isEmpty) return Future<bool>.value(true);
    final next = _queue.then((_) => _requestInner(origin, host, kinds));
    _queue = next.then((_) {}, onError: (_) {});
    return next;
  }

  Future<bool> _requestInner(
    String origin,
    String host,
    Set<SitePermissionKind> kinds,
  ) async {
    await _ensureLoaded();

    // 全局关掉的直接拒绝，不弹确认框，也不写「记住」。
    final permitted = kinds.where(policy.allows).toSet();
    if (permitted.isEmpty) return false;
    kinds = permitted;

    final saved = _decisions[origin];
    if (saved != null) {
      final remembered = <SitePermissionKind>[];
      for (final kind in kinds) {
        final value = saved[kind.nativeKey];
        if (value == null) {
          break;
        }
        remembered.add(kind);
      }
      if (remembered.length == kinds.length) {
        final allow = kinds.every((kind) => saved[kind.nativeKey] == true);
        return allow ? _ensureSystem(kinds) : false;
      }
    }

    final prompt = SitePermissionPrompt(
      origin: origin,
      host: host,
      kinds: kinds,
    );
    _pending = prompt;
    notifyListeners();

    final allow = await prompt.result;
    _pending = null;
    notifyListeners();

    if (prompt.remember) {
      final bucket = _decisions.putIfAbsent(origin, () => <String, bool>{});
      for (final kind in kinds) {
        bucket[kind.nativeKey] = allow;
      }
      await _persist();
    }

    if (!allow) return false;
    return _ensureSystem(kinds);
  }

  Future<bool> _ensureSystem(Set<SitePermissionKind> kinds) async {
    final nativeKinds = kinds
        .where((kind) => kind != SitePermissionKind.clipboard)
        .map((kind) => kind.nativeKey)
        .toList();
    if (nativeKinds.isEmpty) return true;
    return SystemBridge.ensurePermissions(
      nativeKinds,
      preciseLocation: policy.preciseLocation,
    );
  }

  /// 用户点了「允许」。
  void approve({bool remember = false}) {
    final prompt = _pending;
    if (prompt == null) return;
    prompt.remember = remember;
    prompt.complete(true);
  }

  /// 用户点了「拒绝」。
  void reject({bool remember = false}) {
    final prompt = _pending;
    if (prompt == null) return;
    prompt.remember = remember;
    prompt.complete(false);
  }

  /// 清空所有已记住的站点权限（设置页「清除站点数据」用）。
  Future<void> clearAll() async {
    _decisions.clear();
    await _persist();
  }

  // ------------------------------------------------------------ WebView 挂载

  /// 把权限回调挂到标签的 WebView 上。
  ///
  /// 两端的平台控制器 API 同名同签名，但类型不同，所以按运行时类型分派。
  Future<void> attach(
    WebViewController controller, {
    required String Function() originOf,
  }) async {
    final platform = controller.platform;
    try {
      if (platform is AndroidWebViewController) {
        await platform.setGeolocationPermissionsPromptCallbacks(
          onShowPrompt: (params) => _onGeolocationAndroid(params.origin),
        );
        await platform.setOnPlatformPermissionRequest(
          (request) => _onMediaRequest(request, originOf()),
        );
        await platform.setGeolocationEnabled(true);
      } else if (platform is ohos.OhosWebViewController) {
        await platform.setGeolocationPermissionsPromptCallbacks(
          onShowPrompt: (params) => _onGeolocationOhos(params.origin),
        );
        await platform.setOnPlatformPermissionRequest(
          (request) => _onMediaRequest(request, originOf()),
        );
      }
    } catch (_) {
      // 平台实现不支持时静默跳过，网页会收到默认拒绝。
    }

    try {
      await controller.addJavaScriptChannel(
        'RoamClipboard',
        onMessageReceived: (message) {
          unawaited(
            _onClipboardMessage(message.message, controller, originOf()),
          );
        },
      );
    } catch (_) {}
  }

  Future<void> _onMediaRequest(
    PlatformWebViewPermissionRequest permission,
    String origin,
  ) async {
    final kinds = <SitePermissionKind>{
      for (final type in permission.types)
        if (type.name == 'camera')
          SitePermissionKind.camera
        else if (type.name == 'microphone')
          SitePermissionKind.microphone,
    };

    // MIDI / 受保护媒体等少见类型不打扰用户，直接放行。
    if (kinds.isEmpty) {
      await permission.grant();
      return;
    }

    final allow = await request(origin, _hostOf(origin), kinds);
    if (allow) {
      await permission.grant();
    } else {
      await permission.deny();
    }
  }

  /// 询问用户是否允许定位，并在放行后确保系统定位授权。
  Future<bool> _askLocation(String origin) {
    final clean = origin.isEmpty ? '' : origin;
    return request(clean, _hostOf(clean), {SitePermissionKind.location});
  }

  Future<GeolocationPermissionsResponse> _onGeolocationAndroid(
    String origin,
  ) async {
    final allow = await _askLocation(origin);
    return GeolocationPermissionsResponse(allow: allow, retain: true);
  }

  Future<ohos.GeolocationPermissionsResponse> _onGeolocationOhos(
    String origin,
  ) async {
    final allow = await _askLocation(origin);
    return ohos.GeolocationPermissionsResponse(allow: allow, retain: true);
  }

  Future<void> _onClipboardMessage(
    String raw,
    WebViewController controller,
    String origin,
  ) async {
    String id = '';
    try {
      final decoded = jsonDecode(raw);
      if (decoded is Map && decoded['id'] is String) {
        id = decoded['id'] as String;
      }
    } catch (_) {}
    if (id.isEmpty || !RegExp(r'^[A-Za-z0-9_-]{1,32}$').hasMatch(id)) return;

    final allow = await request(origin, _hostOf(origin), {
      SitePermissionKind.clipboard,
    });

    String? text;
    if (allow) {
      text = await SystemBridge.readClipboard();
      if (text == null) {
        try {
          text = (await Clipboard.getData(Clipboard.kTextPlain))?.text;
        } catch (_) {}
      }
    }

    final payload = allow ? 'true, ${_jsString(text ?? '')}' : 'false, null';
    try {
      await controller.runJavaScript(
        'window.__roamClipboardDeliver && '
        "window.__roamClipboardDeliver('$id', $payload);",
      );
    } catch (_) {}
  }

  /// 在页面里安装剪贴板垫片：先走浏览器原生实现，失败（NotAllowedError）
  /// 才转给宿主 App 弹权限框，避免破坏本来就正常的站点。
  Future<void> installClipboardShim(WebViewController controller) async {
    try {
      // 写入开关要先注入：垫片每次都会重装，但读取常量发生在调用时，
      // 所以页面中途改设置也能立刻生效。
      await controller.runJavaScript(
        'window.__roamAllowClipboardWrite = ${policy.allowClipboardWrite};',
      );
      await controller.runJavaScript(clipboardShimJs);
    } catch (_) {}
  }

  static String _hostOf(String origin) {
    final uri = Uri.tryParse(origin);
    if (uri == null || uri.host.isEmpty) return origin;
    return uri.host;
  }

  static String _jsString(String value) {
    return jsonEncode(value)
        .replaceAll('\u2028', r'\u2028')
        .replaceAll('\u2029', r'\u2029');
  }
}

/// 注入到每个页面顶部的剪贴板垫片。
///
/// 只在 `navigator.clipboard.readText()` 抛错时才向宿主申请权限，
/// 原本能读的站点行为完全不变。
const String clipboardShimJs = r'''
(function () {
  if (window.__roamClipboardHooked) return;
  window.__roamClipboardHooked = true;
  var pending = {};
  var seq = 0;

  window.__roamClipboardDeliver = function (id, ok, text) {
    var entry = pending[id];
    if (!entry) return;
    delete pending[id];
    if (ok) {
      entry.resolve(text == null ? '' : text);
    } else {
      entry.reject(new DOMException('剪贴板权限被拒绝', 'NotAllowedError'));
    }
  };

  function roamRead() {
    return new Promise(function (resolve, reject) {
      var id = 'c' + (++seq) + '_' + Date.now().toString(36);
      pending[id] = { resolve: resolve, reject: reject };
      try {
        if (!window.RoamClipboard) throw new Error('no bridge');
        RoamClipboard.postMessage(JSON.stringify({ id: id, type: 'readText' }));
      } catch (err) {
        delete pending[id];
        reject(new DOMException('剪贴板不可用', 'NotAllowedError'));
      }
    });
  }

  try {
    var proto = window.Clipboard && Clipboard.prototype;
    if (proto && typeof proto.readText === 'function') {
      var original = proto.readText;
      proto.readText = function () {
        var self = this;
        var args = arguments;
        var result;
        try {
          result = original.apply(self, args);
        } catch (err) {
          return roamRead();
        }
        return Promise.resolve(result).catch(function (err) {
          if (err && (err.name === 'NotAllowedError' || err.name === 'SecurityError')) {
            return roamRead();
          }
          throw err;
        });
      };
    } else if (navigator.clipboard && typeof navigator.clipboard.readText !== 'function') {
      navigator.clipboard.readText = roamRead;
    }
  } catch (err) {
    // 某些内核拒绝改写原型，忽略即可。
  }

  // 写入方向只受「网站行为管控」的全局开关控制：关掉就直接拒绝，
  // 不弹框（写剪贴板不会泄露用户数据，原版也是纯开关）。
  try {
    var writeProto = window.Clipboard && Clipboard.prototype;
    if (writeProto && typeof writeProto.writeText === 'function') {
      var originalWrite = writeProto.writeText;
      writeProto.writeText = function (text) {
        if (window.__roamAllowClipboardWrite === false) {
          return Promise.reject(
            new DOMException('网站不允许写入剪贴板', 'NotAllowedError')
          );
        }
        return originalWrite.apply(this, arguments);
      };
    }
  } catch (err) {}
})();
''';
