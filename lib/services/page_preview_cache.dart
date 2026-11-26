import 'package:flutter/foundation.dart';

/// 一个页面的低分辨率快照。
///
/// 预测式返回时 Android 的 WebView 是 platform view，Flutter 跟手变换它代价
/// 很高（每帧都要重新合成原生图层），所以这里走「加载完成时抓一张小图」的
/// 路子：手势开始时当前页跟着手指平移，露出来的地方铺上一页的小图 + 模糊，
/// 视觉上就是原生浏览器的效果，而且完全不碰 WebView 本身。
@immutable
class PagePreview {
  const PagePreview({
    required this.url,
    required this.bytes,
    required this.aspectRatio,
  });

  final String url;

  /// JPEG 字节（480px 宽，单张 20~40KB）。
  final Uint8List bytes;

  /// 宽 / 高，背景按这个比例铺满。
  final double aspectRatio;

  int get sizeInBytes => bytes.lengthInBytes;
}

class _TabPreviews {
  PagePreview? current;
  final List<PagePreview> back = <PagePreview>[];
  int revision = 0;
}

/// 每个标签页的「上一页」快照栈。
///
/// 语义：
/// * 页面加载完成 → [record] 当前页；若 URL 变了，上一张压进 back 栈；
/// * 手势开始 → [previous] 拿到栈顶，作为平移动画露出来的背景；
/// * 手势提交、真的后退了 → [consumeBack] 弹掉栈顶，避免下一次加载重复入栈。
class PagePreviewCache {
  PagePreviewCache._();

  static final PagePreviewCache instance = PagePreviewCache._();

  /// 每个标签页最多记几层。
  static const int _maxDepth = 4;

  /// 全部标签页加起来的上限，超了从最旧的一头丢。
  static const int _maxTotalBytes = 6 * 1024 * 1024;

  /// `consumeBack` 之后、下一页加载完成之前的空窗期，用来防止重复入栈。
  /// 用时间戳而不是布尔量，避免后退失败时标记永久残留。
  static const Duration _suppressWindow = Duration(seconds: 4);

  final Map<String, _TabPreviews> _tabs = <String, _TabPreviews>{};
  final Map<String, DateTime> _suppressUntil = <String, DateTime>{};

  _TabPreviews _of(String tabId) => _tabs.putIfAbsent(tabId, _TabPreviews.new);

  /// 页面加载完成后记录当前页。
  void record(String tabId, PagePreview preview) {
    final state = _of(tabId);
    final current = state.current;

    final until = _suppressUntil.remove(tabId);
    final suppressing = until != null && DateTime.now().isBefore(until);

    if (!suppressing && current != null && current.url != preview.url) {
      state.back.add(current);
      if (state.back.length > _maxDepth) {
        state.back.removeRange(0, state.back.length - _maxDepth);
      }
    }
    state.current = preview;
    state.revision++;
    _trim();
  }

  /// 当前页的快照（用于判断是否还缺一张，也用作没有上一页时的兜底背景）。
  PagePreview? currentOf(String tabId) => _tabs[tabId]?.current;

  /// 手势开始时要显示的「上一页」。
  PagePreview? previous(String tabId) {
    final state = _tabs[tabId];
    if (state == null || state.back.isEmpty) return null;
    return state.back.last;
  }

  /// 真的执行了后退：消费掉栈顶。
  void consumeBack(String tabId) {
    final state = _tabs[tabId];
    if (state == null || state.back.isEmpty) return;
    state.back.removeLast();
    _suppressUntil[tabId] = DateTime.now().add(_suppressWindow);
    state.revision++;
  }

  /// 背景图缓存版本号；UI 用它判断要不要重建模糊层。
  int revisionOf(String tabId) => _tabs[tabId]?.revision ?? 0;

  void drop(String tabId) {
    _tabs.remove(tabId);
    _suppressUntil.remove(tabId);
  }

  void clear() {
    _tabs.clear();
    _suppressUntil.clear();
  }

  int get totalBytes {
    var total = 0;
    for (final state in _tabs.values) {
      total += state.current?.sizeInBytes ?? 0;
      for (final item in state.back) {
        total += item.sizeInBytes;
      }
    }
    return total;
  }

  /// 内存兜底：多标签长时间浏览时，从最久没动过的标签页头部丢图。
  void _trim() {
    if (totalBytes <= _maxTotalBytes) return;
    for (final state in _tabs.values) {
      while (totalBytes > _maxTotalBytes && state.back.isNotEmpty) {
        state.back.removeAt(0);
      }
    }
  }
}
