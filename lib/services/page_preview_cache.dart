import 'dart:ui' show Color;

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
    this.averageColor = const Color(0xFFFFFFFF),
    this.flatness = 0,
  });

  final String url;

  /// JPEG 字节（480px 宽，单张 20~40KB）。
  final Uint8List bytes;

  /// 宽 / 高，背景按这个比例铺满。
  final double aspectRatio;

  /// 整张图的平均色。白底页面模糊之后会糊成一片灰雾，
  /// 拿平均色打底再让模糊图半透明叠上去，亮度才不会跑偏。
  final Color averageColor;

  /// 画面「接近纯色」的程度，0（花）~ 1（纯色）。
  /// 纯白页 / 纯黑页模糊后毫无意义，直接用平均色。
  final double flatness;

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
///
/// 自己就是一个 [ChangeNotifier]：抓图是异步的，UI 必须知道「新的上一页
/// 到了」，否则侧滑时铺的还是上一张旧图（模糊不及时刷新）。
class PagePreviewCache extends ChangeNotifier {
  PagePreviewCache._();

  static final PagePreviewCache instance = PagePreviewCache._();

  /// 每个标签页最多记几层。
  static const int _maxDepth = 4;

  /// 全部标签页加起来的上限，超了从最旧的一头丢。
  static const int _maxTotalBytes = 6 * 1024 * 1024;

  /// `consumeBack` 之后、下一页真正开始加载之前的空窗期，用来防止后退
  /// 被误当成「又进了一页」而重复入栈。
  ///
  /// 只覆盖从 `onPageStarted` 到 `onPageFinished` 这段，1.5s 足够；
  /// 原来设 4s 会把「后退回来之后马上又点进另一个页面」也吞掉。
  static const Duration _suppressWindow = Duration(milliseconds: 1500);

  final Map<String, _TabPreviews> _tabs = <String, _TabPreviews>{};
  final Map<String, DateTime> _suppressUntil = <String, DateTime>{};

  /// 已经判定为「后退」的导航：`onPageStarted` 消费了抑制标记，
  /// 但同一次导航的 `onPageFinished` 也不能再入栈。
  final Set<String> _skipRecord = <String>{};

  _TabPreviews _of(String tabId) => _tabs.putIfAbsent(tabId, _TabPreviews.new);

  /// 消费一次抑制标记：一次后退只拦「这一次导航」。
  bool _consumeSuppression(String tabId) {
    final until = _suppressUntil.remove(tabId);
    return until != null && DateTime.now().isBefore(until);
  }

  /// 压栈，同一张图不重复压。
  void _pushBack(_TabPreviews state, PagePreview preview) {
    if (state.back.isNotEmpty && state.back.last.url == preview.url) return;
    state.back.add(preview);
    if (state.back.length > _maxDepth) {
      state.back.removeRange(0, state.back.length - _maxDepth);
    }
  }

  /// 新页面开始加载时调用（`onPageStarted`）：**立刻**把当前页压栈。
  ///
  /// 这是「上一页」最可靠的来源：压栈不再依赖新页面抓图成功。以前只在
  /// 新页加载完成后比较 URL 才补压，新页一慢、一失败、或者 URL 恰好没变，
  /// 栈就一直是空的，侧滑时自然没有可铺的背景。
  void beginNavigation(String tabId) {
    _skipRecord.remove(tabId);
    final state = _tabs[tabId];
    final current = state?.current;
    if (state == null || current == null) return;
    // 后退回来的那一次不再入栈，否则栈里会多出一张「刚离开的页」。
    if (_consumeSuppression(tabId)) {
      _skipRecord.add(tabId);
      return;
    }
    _pushBack(state, current);
    state.revision++;
    notifyListeners();
  }

  /// 页面加载完成后记录当前页。
  void record(String tabId, PagePreview preview) {
    final state = _of(tabId);
    final current = state.current;
    // 兜底：单页应用改 URL 不走 onPageStarted，这里补一次入栈。
    final skip = _skipRecord.remove(tabId) || _consumeSuppression(tabId);
    if (!skip && current != null && current.url != preview.url) {
      _pushBack(state, current);
    }
    state.current = preview;
    state.revision++;
    _trim();
    notifyListeners();
  }

  /// 当前页的快照。
  PagePreview? currentOf(String tabId) => _tabs[tabId]?.current;

  /// 手势开始时要显示的「上一页」。
  ///
  /// 没有历史（第一页，退回去就是首页）时返回 null——上层据此显示空白，
  /// 而不是拿当前页或首页的图凑数。
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
    notifyListeners();
  }

  /// 背景图缓存版本号；UI 用它判断要不要重建模糊层。
  int revisionOf(String tabId) => _tabs[tabId]?.revision ?? 0;

  void drop(String tabId) {
    final changed = _tabs.remove(tabId) != null;
    _suppressUntil.remove(tabId);
    _skipRecord.remove(tabId);
    if (changed) notifyListeners();
  }

  /// 清空全部快照（清历史时一起丢）。
  void clear() {
    if (_tabs.isEmpty) return;
    _tabs.clear();
    _suppressUntil.clear();
    _skipRecord.clear();
    notifyListeners();
  }

  @override
  void dispose() {
    _tabs.clear();
    _suppressUntil.clear();
    _skipRecord.clear();
    super.dispose();
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
