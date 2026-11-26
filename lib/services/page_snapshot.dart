import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// 抓取 WebView 区域当前画面（低分辨率）。
///
/// WebView 在 Android 上是 platform view，`RepaintBoundary.toImage()` 拿不到
/// 它的内容，只能在原生侧抓：优先 `PixelCopy` 读窗口像素（能拿到硬件合成的
/// 真实画面），失败再退到 `WebView.draw()` 把内容画进一张缩小的 Bitmap。
///
/// 只在真正需要的地方调用——每次页面加载完成一次，约 20~40ms。
class PageSnapshotService {
  const PageSnapshotService();

  static const MethodChannel _channel = MethodChannel(
    'org.roam.roam_flutter/page_snapshot',
  );

  /// 目前只有 Android 侧实现了原生抓图；鸿蒙/iOS 返回 null，动画自动降级
  /// 成「只有当前页平移」。
  static bool get supported =>
      !kIsWeb && Platform.operatingSystem == 'android';

  /// [rect] 是 Flutter 全局坐标（FlutterView 左上角为原点）；
  /// 原生侧会再加上 FlutterView 在窗口里的偏移，取窗口坐标。
  Future<Uint8List?> capture({
    required Rect rect,
    required double devicePixelRatio,
    int targetWidth = 480,
  }) async {
    if (!supported || rect.isEmpty) return null;
    final scale = devicePixelRatio > 0 ? devicePixelRatio : 1.0;
    try {
      final bytes = await _channel.invokeMethod<Uint8List>('capture', {
        'x': (rect.left * scale).round(),
        'y': (rect.top * scale).round(),
        'width': (rect.width * scale).round(),
        'height': (rect.height * scale).round(),
        'targetWidth': targetWidth,
      });
      if (bytes == null || bytes.isEmpty) return null;
      return bytes;
    } catch (_) {
      return null;
    }
  }
}
