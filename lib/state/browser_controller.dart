// ignore_for_file: deprecated_member_use

import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart' show Colors;
import 'package:webview_flutter/webview_flutter.dart';

import '../models/browser_models.dart';
import '../services/browser_store.dart';
import '../services/default_bookmarks.dart';
import '../services/download_service.dart';
import '../services/system_bridge.dart';
import '../services/url_resolver.dart';
import '../services/web_permission_service.dart';
import '../ui/app_messenger.dart';

/// 浏览器唯一的可变状态源。
///
/// 页面只读这里的数据，所有动作都走这里的方法，避免 WebView、地址栏、
/// 书签与历史各自维护一份互相打架的状态。
class BrowserController extends ChangeNotifier {
  BrowserController({
    required this.store,
    DownloadService? downloader,
    UrlResolver? resolver,
  }) : _downloader = downloader ?? DownloadService(),
       _resolver = resolver ?? const UrlResolver();

  final BrowserStore store;
  final DownloadService _downloader;
  final UrlResolver _resolver;

  static const _desktopUserAgent =
      'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 '
      '(KHTML, like Gecko) Chrome/131.0.0.0 Safari/537.36';

  BrowserSettings settings = const BrowserSettings();
  final List<BrowserTab> _tabs = [];
  final List<Bookmark> bookmarks = [];
  final List<HistoryEntry> history = [];
  final List<DownloadEntry> downloads = [];

  String _activeTabId = '';
  bool _ready = false;
  bool _disposed = false;
  bool _webViewAvailable = true;
  Timer? _tabPersistTimer;
  Timer? _historyPersistTimer;
  Timer? _downloadPersistTimer;

  bool get ready => _ready;
  bool get webViewAvailable => _webViewAvailable;
  List<BrowserTab> get tabs => List.unmodifiable(_tabs);
  List<DownloadEntry> get activeDownloads => List.unmodifiable(downloads);

  BrowserTab? get activeTab {
    for (final tab in _tabs) {
      if (tab.id == _activeTabId) return tab;
    }
    return _tabs.isEmpty ? null : _tabs.first;
  }

  int get activeIndex {
    final index = _tabs.indexWhere((tab) => tab.id == _activeTabId);
    return index < 0 ? 0 : index;
  }

  // ---------------------------------------------------------------- 生命周期

  Future<void> initialize() async {
    settings = store.loadSettings();
    bookmarks
      ..clear()
      ..addAll(store.loadBookmarks());

    // 预置一屏快捷访问（原版首次打开就有站点，不用用户先手动加书签）。
    // 只写一次：真的按 URL 去重后追加，写过的用户不会被反复塞回来，
    // 老版本升级上来（书签里已有自己存的东西）也能补上这一屏。
    if (!store.defaultsSeeded) {
      final known = {for (final item in bookmarks) item.url};
      final seeds = defaultBookmarks(DateTime.now())
          .where((item) => !known.contains(item.url))
          .toList();
      if (seeds.isNotEmpty) {
        bookmarks.addAll(seeds);
        await store.saveBookmarks(bookmarks);
      }
      await store.markDefaultsSeeded();
    }
    history
      ..clear()
      ..addAll(store.loadHistory());
    downloads
      ..clear()
      ..addAll(store.loadDownloads());

    final restored = settings.restoreTabs ? store.loadTabs() : <BrowserTab>[];
    final activeId = store.loadActiveTabId();

    if (restored.isEmpty) {
      newTab(select: true, notify: false);
    } else {
      _tabs.addAll(restored);
      _activeTabId = restored.any((tab) => tab.id == activeId)
          ? activeId!
          : restored.first.id;
      // 恢复的标签只还原标题与地址，等选中时再创建 WebView，避免启动即分配
      // 多个 WebView 实例。
      for (final tab in _tabs) {
        tab.isLoading = false;
      }
    }

    _ready = true;
    _notify();
  }

  @override
  void dispose() {
    _disposed = true;
    _tabPersistTimer?.cancel();
    _historyPersistTimer?.cancel();
    _downloadPersistTimer?.cancel();
    super.dispose();
  }

  void _notify() {
    if (!_disposed) notifyListeners();
  }

  // ------------------------------------------------------------------- 标签

  BrowserTab newTab({
    String? url,
    bool incognito = false,
    bool select = true,
    bool notify = true,
  }) {
    final tab = BrowserTab(
      id: 'tab_${DateTime.now().microsecondsSinceEpoch}_${_tabs.length}',
      createdAt: DateTime.now(),
      isIncognito: incognito,
    );
    _tabs.add(tab);
    if (select || _tabs.length == 1) {
      _activeTabId = tab.id;
    }
    if (url != null && url.isNotEmpty) {
      openAddress(url, tab: tab);
    } else if (select) {
      _ensureController(tab);
    }
    _persistTabsSoon();
    if (notify) _notify();
    return tab;
  }

  void selectTab(String id) {
    if (_activeTabId == id) return;
    final tab = _tabById(id);
    if (tab == null) return;
    _activeTabId = id;
    _ensureController(tab);
    _persistTabsSoon();
    _notify();
  }

  Future<void> closeTab(String id) async {
    final index = _tabs.indexWhere((tab) => tab.id == id);
    if (index < 0) return;
    final tab = _tabs.removeAt(index);

    if (tab.isIncognito) {
      unawaited(_wipeIncognito(tab));
    }

    if (_tabs.isEmpty) {
      newTab(select: true, notify: false);
    } else if (_activeTabId == id) {
      final next = index.clamp(0, _tabs.length - 1);
      _activeTabId = _tabs[next].id;
      _ensureController(_tabs[next]);
    }
    _persistTabsSoon();
    _notify();
  }

  Future<void> _wipeIncognito(BrowserTab tab) async {
    final controller = tab.webController;
    if (controller == null) return;
    try {
      await controller.clearCache();
      await controller.clearLocalStorage();
    } catch (_) {
      // 无痕数据清理失败不应该影响标签关闭。
    }
  }

  BrowserTab? _tabById(String id) {
    for (final tab in _tabs) {
      if (tab.id == id) return tab;
    }
    return null;
  }

  // ---------------------------------------------------------------- 地址与搜索

  Future<void> openAddress(String input, {BrowserTab? tab}) async {
    final target = tab ?? activeTab;
    if (target == null) return;
    final resolved = _resolver.resolve(input, settings);

    if (resolved.kind == AddressKind.home) {
      goHome(target);
      return;
    }

    if (resolved.kind == AddressKind.external) {
      await _launchExternal(resolved.uri!, target);
      return;
    }

    final uri = resolved.uri!;
    target
      ..url = uri.toString()
      ..errorDescription = null
      ..isLoading = true
      ..progress = 0;

    final controller = _ensureController(target);
    if (controller == null) {
      target.isLoading = false;
      target.errorDescription = '当前平台没有可用的 WebView 实现';
      _notify();
      return;
    }

    _notify();
    try {
      await controller.loadRequest(uri);
    } catch (error) {
      target
        ..isLoading = false
        ..errorDescription = error.toString();
      _notify();
    }
  }

  Future<void> search(String query) => openAddress(query, tab: activeTab);

  void goHome(BrowserTab? tab) {
    final target = tab ?? activeTab;
    if (target == null) return;
    target
      ..url = ''
      ..title = '新标签页'
      ..isLoading = false
      ..progress = 0
      ..errorDescription = null
      ..canGoBack = false
      ..canGoForward = false;
    _persistTabsSoon();
    _notify();
  }

  // ------------------------------------------------------------------ 导航动作

  /// 后退一页；真的后退了返回 true，网页没有历史返回 false。
  Future<bool> goBack() async {
    final controller = activeTab?.webController;
    if (controller == null) return false;
    if (await controller.canGoBack()) {
      await controller.goBack();
      return true;
    }
    return false;
  }

  Future<void> goForward() async {
    final controller = activeTab?.webController;
    if (controller == null) return;
    if (await controller.canGoForward()) await controller.goForward();
  }

  Future<void> reload() async {
    final controller = activeTab?.webController;
    if (controller == null) return;
    final tab = activeTab!;
    tab
      ..errorDescription = null
      ..isLoading = true
      ..progress = 0;
    _notify();
    await controller.reload();
  }

  Future<void> stopLoading() async {
    final tab = activeTab;
    final controller = tab?.webController;
    if (tab == null || controller == null) return;
    // 当前 webview_flutter 没有 stopLoading，用页面脚本停掉正在进行的请求。
    try {
      await controller.runJavaScript('window.stop();');
    } catch (_) {}
    tab
      ..isLoading = false
      ..progress = 0;
    _notify();
  }

  void clearError(BrowserTab tab) {
    tab.errorDescription = null;
    _notify();
  }

  Future<void> openUrlInNewTab(String url, {bool incognito = false}) {
    newTab(url: url, incognito: incognito);
    return Future.value();
  }

  // ------------------------------------------------------------------ 书签

  bool isBookmarked(String url) =>
      bookmarks.any((bookmark) => bookmark.url == url);

  Future<void> toggleBookmarkCurrent() async {
    final tab = activeTab;
    if (tab == null || tab.url.isEmpty) return;
    final index = bookmarks.indexWhere((bookmark) => bookmark.url == tab.url);
    if (index >= 0) {
      bookmarks.removeAt(index);
    } else {
      bookmarks.insert(
        0,
        Bookmark(
          id: 'bm_${DateTime.now().microsecondsSinceEpoch}',
          title: tab.title.isEmpty ? tab.url : tab.title,
          url: tab.url,
          createdAt: DateTime.now(),
        ),
      );
    }
    await store.saveBookmarks(bookmarks);
    _notify();
  }

  Future<void> addBookmark(String title, String url) async {
    final cleanUrl = url.trim();
    if (cleanUrl.isEmpty) return;
    final index = bookmarks.indexWhere((bookmark) => bookmark.url == cleanUrl);
    final entry = Bookmark(
      id: 'bm_${DateTime.now().microsecondsSinceEpoch}',
      title: title.trim().isEmpty ? cleanUrl : title.trim(),
      url: cleanUrl,
      createdAt: DateTime.now(),
    );
    if (index >= 0) {
      bookmarks[index] = entry;
    } else {
      bookmarks.insert(0, entry);
    }
    await store.saveBookmarks(bookmarks);
    _notify();
  }

  Future<void> removeBookmark(String id) async {
    bookmarks.removeWhere((bookmark) => bookmark.id == id);
    await store.saveBookmarks(bookmarks);
    _notify();
  }

  // ------------------------------------------------------------------ 历史

  void _recordVisit(BrowserTab tab) {
    if (tab.isIncognito || tab.url.isEmpty) return;
    if (tab.url.startsWith('about:') || tab.url.startsWith('data:')) return;
    final last = history.isEmpty ? null : history.first;
    if (last != null && last.url == tab.url) {
      history.removeAt(0);
    }
    history.insert(
      0,
      HistoryEntry(
        id: 'h_${DateTime.now().microsecondsSinceEpoch}',
        title: tab.title.isEmpty ? tab.url : tab.title,
        url: tab.url,
        visitedAt: DateTime.now(),
      ),
    );
    if (history.length > 600) history.removeRange(600, history.length);
    _historyPersistTimer?.cancel();
    _historyPersistTimer = Timer(
      const Duration(milliseconds: 600),
      () => store.saveHistory(history),
    );
  }

  Future<void> removeHistoryEntry(String id) async {
    history.removeWhere((entry) => entry.id == id);
    await store.saveHistory(history);
    _notify();
  }

  Future<void> clearHistory() async {
    history.clear();
    await store.saveHistory(history);
    _notify();
  }

  // ------------------------------------------------------------------ 下载

  Future<void> startDownload(
    String url, {
    String? fileName,
    String? mimeType,
    int contentLength = 0,
    String? userAgent,
  }) async {
    final name = fileName?.trim().isNotEmpty == true
        ? fileName!.trim()
        : DownloadService.suggestedFileName(url, null, mimeType);
    final entry = await _downloader.createEntry(
      id: 'dl_${DateTime.now().microsecondsSinceEpoch}',
      url: url,
      fileName: name,
      mimeType: mimeType ?? 'application/octet-stream',
      totalBytes: contentLength > 0 ? contentLength : 0,
    );
    downloads.insert(0, entry);
    if (downloads.length > 120) downloads.removeRange(120, downloads.length);
    _persistDownloadsSoon();
    _notify();

    unawaited(
      _downloader.download(
        entry,
        userAgent: userAgent,
        onUpdate: () {
          _persistDownloadsSoon();
          _notify();
        },
      ),
    );
  }

  void cancelDownload(String id) {
    _downloader.cancel(id);
    for (final entry in downloads) {
      if (entry.id == id && entry.status == DownloadStatus.running) {
        entry
          ..status = DownloadStatus.cancelled
          ..error = '已取消';
      }
    }
    _notify();
  }

  Future<void> removeDownload(String id) async {
    downloads.removeWhere((entry) => entry.id == id);
    await store.saveDownloads(downloads);
    _notify();
  }

  Future<void> clearDownloadRecords() async {
    downloads.clear();
    await store.saveDownloads(downloads);
    _notify();
  }

  // ------------------------------------------------------------------ 设置

  Future<void> updateSettings(BrowserSettings next) async {
    final previous = settings;
    settings = next;
    // 先同步 UI（开关/玻璃要立即响应），再做异步持久化
    _notify();

    if (previous.javascriptEnabled != next.javascriptEnabled) {
      await _applyJavaScriptMode();
    }
    if (previous.desktopMode != next.desktopMode) {
      await _applyUserAgent(reload: true);
    }
    await store.saveSettings(settings);
    _notify();
  }

  Future<void> setSearchEngine(SearchEngine engine) =>
      updateSettings(settings.copyWith(searchEngine: engine));

  Future<void> setCustomSearchTemplate(String template) =>
      updateSettings(settings.copyWith(customSearchTemplate: template));

  Future<void> setThemeMode(AppThemeMode mode) =>
      updateSettings(settings.copyWith(themeMode: mode));

  Future<void> setJavascriptEnabled(bool enabled) =>
      updateSettings(settings.copyWith(javascriptEnabled: enabled));

  Future<void> setDesktopMode(bool enabled) =>
      updateSettings(settings.copyWith(desktopMode: enabled));

  Future<void> setRestoreTabs(bool enabled) =>
      updateSettings(settings.copyWith(restoreTabs: enabled));

  Future<void> clearBrowsingData({
    bool history = true,
    bool bookmarks = false,
    bool downloads = false,
  }) async {
    if (history) {
      this.history.clear();
      await store.saveHistory(this.history);
    }
    if (bookmarks) {
      this.bookmarks.clear();
      await store.saveBookmarks(this.bookmarks);
    }
    if (downloads) {
      this.downloads.clear();
      await store.saveDownloads(this.downloads);
    }
    for (final tab in _tabs) {
      if (tab.webController == null) continue;
      try {
        await tab.webController!.clearCache();
      } catch (_) {}
    }
    _notify();
  }

  // -------------------------------------------------------------- WebView 装配

  /// 为标签补建 WebView。页面在首帧调用，避免启动时一次性创建所有实例。
  void ensureTabController(BrowserTab tab) {
    _ensureController(tab);
  }

  WebViewController? _ensureController(BrowserTab tab) {
    if (!_webViewAvailable) return null;
    final existing = tab.webController;
    if (existing != null) return existing;

    try {
      late final WebViewController controller;
      controller = WebViewController()
        ..setJavaScriptMode(
          settings.javascriptEnabled
              ? JavaScriptMode.unrestricted
              : JavaScriptMode.disabled,
        )
        ..setBackgroundColor(Colors.transparent)
        ..setNavigationDelegate(
          NavigationDelegate(
            onProgress: (value) {
              tab.progress = value;
              tab.isLoading = value < 100;
              _notify();
            },
            onPageStarted: (url) {
              tab
                ..isLoading = true
                ..progress = 0
                ..errorDescription = null
                ..url = url;
              _notify();
              // 剪贴板垫片要尽早注入，晚了站点可能已经调用过。
              unawaited(
                WebPermissionService.instance.installClipboardShim(controller),
              );
            },
            onPageFinished: (url) async {
              tab.isLoading = false;
              if (url.isNotEmpty && !url.startsWith('about:')) {
                tab.url = url;
              }
              // 单页应用可能改了 URL 但没触发 onPageStarted，这里补一次。
              unawaited(
                WebPermissionService.instance.installClipboardShim(controller),
              );
              try {
                final title = await controller.getTitle();
                if (title != null && title.trim().isNotEmpty) {
                  tab.title = title.trim();
                }
              } catch (_) {}
              try {
                tab.canGoBack = await controller.canGoBack();
                tab.canGoForward = await controller.canGoForward();
              } catch (_) {}
              _recordVisit(tab);
              _persistTabsSoon();
              _notify();
            },
            onUrlChange: (change) {
              final url = change.url;
              if (url == null || url.isEmpty) return;
              tab.url = url;
              _persistTabsSoon();
              _notify();
            },
            onWebResourceError: (error) {
              if (error.isForMainFrame == false) return;
              tab
                ..isLoading = false
                ..errorDescription =
                    '${error.description}${error.errorCode > 0 ? ' (${error.errorCode})' : ''}';
              _notify();
            },
            onNavigationRequest: (request) {
              return _handleNavigation(request, tab);
            },
          ),
        );

      if (settings.desktopMode) {
        unawaited(controller.setUserAgent(_desktopUserAgent));
      }
      // 相机 / 麦克风 / 定位的确认与系统授权全部交给 WebPermissionService，
      // WebView 自己只会「默认拒绝」。
      unawaited(
        WebPermissionService.instance.attach(
          controller,
          originOf: () => _originOf(tab),
        ),
      );
      tab.webController = controller;
      return controller;
    } catch (_) {
      _webViewAvailable = false;
      return null;
    }
  }

  NavigationDecision _handleNavigation(
    NavigationRequest request,
    BrowserTab tab,
  ) {
    final uri = Uri.tryParse(request.url);
    if (uri == null) return NavigationDecision.navigate;

    if (uri.scheme == 'http' || uri.scheme == 'https') {
      if (_looksLikeDownload(uri)) {
        unawaited(startDownload(request.url));
        return NavigationDecision.prevent;
      }
      return NavigationDecision.navigate;
    }

    if (uri.scheme == 'about' ||
        uri.scheme == 'data' ||
        uri.scheme == 'blob' ||
        uri.scheme == 'javascript') {
      return NavigationDecision.navigate;
    }

    // tel:/mailto:/market:/intent:/weixin:/alipays:… 交给系统处理，
    // 别让 WebView 报 ERR_UNKNOWN_URL_SCHEME。
    unawaited(_launchExternal(uri, tab));
    return NavigationDecision.prevent;
  }

  /// 把非 http(s) 链接交给系统：Android 走隐式 Intent，鸿蒙走 startAbility。
  ///
  /// 失败时按 `intent://` 自带的 browser_fallback_url 回网页，再不行给个提示，
  /// 避免用户点了完全没反应。
  Future<void> _launchExternal(Uri uri, BrowserTab tab) async {
    final result = await SystemBridge.openExternal(
      uri.toString(),
      referer: tab.url.isEmpty ? null : tab.url,
    );
    if (result.handled) return;

    final fallback = result.fallbackUrl;
    if (fallback != null && fallback.isNotEmpty) {
      await openAddress(fallback, tab: tab);
      return;
    }

    final label = uri.scheme.isEmpty ? '该链接' : '${uri.scheme}:// 链接';
    showRoamToast('没有找到可以打开$label的应用');
  }

  /// 当前标签页的 origin，用于站点权限的「记住」与提示文案。
  String _originOf(BrowserTab tab) {
    final uri = Uri.tryParse(tab.url);
    if (uri == null || !uri.hasScheme) return '';
    if (uri.host.isEmpty) return '${uri.scheme}://';
    final port = uri.hasPort ? ':${uri.port}' : '';
    return '${uri.scheme}://${uri.host}$port';
  }

  static const _downloadExtensions = {
    'apk',
    'zip',
    'rar',
    '7z',
    'tar',
    'gz',
    'bz2',
    'xz',
    'iso',
    'pdf',
    'doc',
    'docx',
    'xls',
    'xlsx',
    'ppt',
    'pptx',
    'epub',
    'mobi',
    'mp3',
    'flac',
    'wav',
    'aac',
    'm4a',
    'ogg',
    'mp4',
    'mkv',
    'avi',
    'mov',
    'wmv',
    'flv',
    'webm',
    'ts',
    'm3u8',
    'exe',
    'dmg',
    'deb',
    'rpm',
    'msi',
    'jpg',
    'jpeg',
    'png',
    'gif',
    'webp',
    'svg',
    'heic',
  };

  static bool _looksLikeDownload(Uri uri) {
    if (uri.pathSegments.isEmpty) return false;
    final last = uri.pathSegments.last;
    final dot = last.lastIndexOf('.');
    if (dot < 0 || dot == last.length - 1) return false;
    return _downloadExtensions.contains(last.substring(dot + 1).toLowerCase());
  }

  Future<void> _applyJavaScriptMode() async {
    for (final tab in _tabs) {
      final controller = tab.webController;
      if (controller == null) continue;
      try {
        await controller.setJavaScriptMode(
          settings.javascriptEnabled
              ? JavaScriptMode.unrestricted
              : JavaScriptMode.disabled,
        );
      } catch (_) {}
    }
  }

  Future<void> _applyUserAgent({bool reload = false}) async {
    for (final tab in _tabs) {
      final controller = tab.webController;
      if (controller == null) continue;
      try {
        await controller.setUserAgent(
          settings.desktopMode ? _desktopUserAgent : null,
        );
        if (reload && tab.url.isNotEmpty) {
          await controller.reload();
        }
      } catch (_) {}
    }
  }

  // ------------------------------------------------------------------ 持久化

  void _persistTabsSoon() {
    _tabPersistTimer?.cancel();
    _tabPersistTimer = Timer(const Duration(milliseconds: 400), () {
      store.saveTabs(
        _tabs.where((tab) => !tab.isIncognito).toList(),
        _activeTabId,
      );
    });
  }

  void _persistDownloadsSoon() {
    _downloadPersistTimer?.cancel();
    _downloadPersistTimer = Timer(
      const Duration(milliseconds: 800),
      () => store.saveDownloads(downloads),
    );
  }
}
