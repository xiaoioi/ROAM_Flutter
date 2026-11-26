// ignore_for_file: deprecated_member_use

import 'dart:async';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_miuix/miuix.dart';
import 'package:webview_flutter/webview_flutter.dart';

import '../models/browser_models.dart';
import '../services/page_preview_cache.dart';
import '../services/page_snapshot.dart';
import '../state/browser_controller.dart';
import '../theme/roam_theme.dart';
import 'app_route_observer.dart';
import 'pages/bookmarks_page.dart';
import 'pages/downloads_page.dart';
import 'pages/history_page.dart';
import 'pages/home_page.dart';
import 'pages/settings_page.dart';
import 'sheets/menu_sheet.dart';
import 'sheets/search_sheet.dart';
import 'sheets/tabs_sheet.dart';
import 'widgets/glass_controls.dart';
import 'widgets/predictive_back.dart';
import 'widgets/site_permission_prompt.dart';

/// 主界面：星空背景 + 标签内容 + 两层悬浮玻璃。
class BrowserShell extends StatefulWidget {
  const BrowserShell({super.key, required this.controller});

  final BrowserController controller;

  @override
  State<BrowserShell> createState() => _BrowserShellState();
}

class _BrowserShellState extends State<BrowserShell> with RouteAware {
  BrowserController get _controller => widget.controller;

  /// 有设置页 / 书签页 / 弹层盖在上面时为 true。
  /// 预测式返回要让给它们自己的转场，主界面不能抢手势。
  bool _covered = false;
  PageRoute<void>? _route;

  /// [_backdropFor] 的一格缓存。
  String? _backdropTabId;
  int _backdropRevision = -1;
  Widget? _backdrop;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final route = ModalRoute.of(context);
    if (route is PageRoute<void> && !identical(route, _route)) {
      if (_route != null) roamRouteObserver.unsubscribe(this);
      _route = route;
      roamRouteObserver.subscribe(this, route);
    }
  }

  @override
  void didPushNext() {
    if (_covered) return;
    setState(() => _covered = true);
  }

  @override
  void didPopNext() {
    if (!_covered) return;
    setState(() => _covered = false);
  }

  @override
  void dispose() {
    roamRouteObserver.unsubscribe(this);
    super.dispose();
  }

  void _openTabs() {
    showTabsSheet(context: context, controller: _controller);
  }

  void _openMenu() {
    // 首页的下层是普通 Flutter 图层，能被离屏快照捕获；
    // 网页是 platform view，快照里没有内容，玻璃要走实时模糊分支。
    final tab = _controller.activeTab;
    showMenuSheet(
      context: context,
      controller: _controller,
      useSnapshot: tab?.isHome ?? true,
    );
  }

  /// 顶栏中间的空白 / 标题区域：原版 `webViewSearchResponseView.onClick`
  /// → `showSearchView()`，弹出第二个界面（搜索面板）。
  void _openSearch() {
    final tab = _controller.activeTab;
    showSearchSheet(
      context: context,
      controller: _controller,
      useSnapshot: tab?.isHome ?? true,
    );
  }

  @override
  Widget build(BuildContext context) {
    final brightness = Theme.of(context).brightness;
    final isDark = brightness == Brightness.dark;

    return AnimatedBuilder(
      animation: _controller,
      builder: (context, _) {
        final tab = _controller.activeTab;
        final onHome = tab?.isHome ?? true;

        return PopScope(
          // 首页时允许离开（系统会显示「返回桌面」的预测预览），
          // 网页页禁止直接 pop：系统返回 / 侧滑先落到网页历史上，
          // 回不去了才回首页，避免侧滑一下就把整个浏览器关掉。
          canPop: tab == null || tab.isHome,
          onPopInvokedWithResult: (didPop, _) {
            if (didPop) return;
            unawaited(_handleSystemBack());
          },
          child: SitePermissionHost(
            child: Scaffold(
              backgroundColor: isDark ? Colors.black : RoamColors.daySky,
              resizeToAvoidBottomInset: true,
              // 全局背景捕获：只包页面内容（顶栏/进度条/标签内容/底栏）。
              // 工具栏、标签页等 modal 弹层走 Navigator 压栈，在本子树之外，
              // 因此它们采样到的是「下层页面的最终画面」，不会自采样。
              // 页面内部的玻璃（HomePage/设置页）各自持有局部捕获器，
              // 不读这两个全局快照，避免玻璃把自己叠进背景（反馈循环）。
              body: MiuixLayerBackdropCapture(
                backdrop: miuixBackdrop,
                child: Column(
                  children: [
                    _RoamTopBar(
                      isDark: isDark,
                      title: onHome ? '' : _titleOf(tab!),
                      onNewTab: _openTabs,
                      onTapTitle: _openSearch,
                    ),
                    _RoamProgress(tab: tab),
                    // 只有网页区参与侧滑动画：顶栏、进度条、底栏原地不动，
                    // 跟原生浏览器「内容区退场、外壳不动」的表现一致。
                    Expanded(
                      child: _buildPageArea(tab, isDark, brightness, onHome),
                    ),
                    _RoamBottomBar(
                      isDark: isDark,
                      tab: tab,
                      controller: _controller,
                      onMenu: _openMenu,
                      onTabs: _openTabs,
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  /// 系统返回（含 Android 14 预测式返回手势）的统一落点。
  Future<void> _handleSystemBack() async {
    final tab = _controller.activeTab;
    if (tab == null || tab.isHome) {
      SystemNavigator.pop();
      return;
    }
    // 以 WebView 的真实历史为准，避免 tab.canGoBack 缓存滞后。
    if (await _controller.goBack()) return;
    _controller.goHome(tab);
  }

  static String _titleOf(BrowserTab tab) {
    final uri = Uri.tryParse(tab.url);
    if (uri == null || uri.host.isEmpty) return tab.title;
    final path = uri.path == '/' ? '' : uri.path;
    return '${uri.host}$path';
  }

  Widget _buildPageArea(
    BrowserTab? tab,
    bool isDark,
    Brightness brightness,
    bool onHome,
  ) {
    final site = tab;
    final enabled = site != null && !_covered && !onHome;
    Widget? backdrop;
    if (site != null && !_covered && !onHome) {
      backdrop = _backdropFor(site.id);
    }
    return PredictiveBackScope(
      style: PredictiveBackStyle.horizontal,
      enabled: enabled,
      backdrop: backdrop,
      onCommit: () => unawaited(_handleSystemBack()),
      child: _buildTabs(isDark, brightness),
    );
  }

  /// 上一页的模糊快照层。
  ///
  /// 这个子树里有一层全屏高斯模糊，重建一次就是一次全屏重绘，所以按
  /// `(tabId, 缓存版本号)` 缓存 widget 实例：手势过程中 [AnimatedBuilder]
  /// 反复重建也不会重新算模糊，只是改一层 Transform。
  Widget? _backdropFor(String tabId) {
    final cache = PagePreviewCache.instance;
    final revision = cache.revisionOf(tabId);
    if (_backdropTabId == tabId && _backdropRevision == revision) {
      return _backdrop;
    }
    _backdropTabId = tabId;
    _backdropRevision = revision;
    // 没有上一页时（新标签的第一页）退化成当前页的虚影：总比露出一块纯色底好，
    // 视觉上就是「页面被推开，露出自己的虚影」。
    final preview = cache.previous(tabId) ?? cache.currentOf(tabId);
    _backdrop = preview == null
        ? null
        : _PageBackdrop(
            key: ValueKey<String>('backdrop_${preview.url}_$revision'),
            preview: preview,
          );
    return _backdrop;
  }

  Widget _buildTabs(bool isDark, Brightness brightness) {
    final tabs = _controller.tabs;
    if (tabs.isEmpty) return const SizedBox.shrink();
    final index = _controller.activeIndex.clamp(0, tabs.length - 1);
    return IndexedStack(
      index: index,
      children: [
        for (final tab in tabs)
          tab.isHome
              ? HomePage(
                  key: ValueKey('home_${tab.id}'),
                  controller: _controller,
                  brightness: brightness,
                )
              : WebViewHost(
                  key: ValueKey('web_${tab.id}'),
                  tab: tab,
                  controller: _controller,
                  isDark: isDark,
                ),
      ],
    );
  }
}

/// 顶栏：50dp，左侧 29dp 多任务，中间 15dp 加粗标题，右侧 11dp 日期。
class _RoamTopBar extends StatelessWidget {
  const _RoamTopBar({
    required this.isDark,
    required this.title,
    required this.onNewTab,
    required this.onTapTitle,
  });

  final bool isDark;
  final String title;
  final VoidCallback onNewTab;
  final VoidCallback onTapTitle;

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    const weeks = ['周一', '周二', '周三', '周四', '周五', '周六', '周日'];
    final fg = isDark ? Colors.white : const Color(0xFF0B1526);

    return SafeArea(
      bottom: false,
      child: SizedBox(
        height: 50,
        child: Row(
          children: [
            const SizedBox(width: 20),
            GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: onNewTab,
              child: Image.asset(
                'assets/images/view-quilt.png',
                width: 26,
                height: 26,
                color: fg,
              ),
            ),
            const SizedBox(width: 15),
            // 原版顶栏中间是 `webViewSearchResponseView`（layout_weight=1），
            // 首页没有标题时就是一片空白；点它不会切换标签，而是弹出搜索
            // 面板——这是原版最容易漏掉的入口。
            Expanded(
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: onTapTitle,
                child: Semantics(
                  button: true,
                  label: '搜索',
                  child: Text(
                    title,
                    maxLines: 1,
                    textAlign: TextAlign.center,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                      color: fg,
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 15),
            SizedBox(
              width: 76,
              child: Padding(
                padding: const EdgeInsets.only(right: 20),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      '${now.month}月${now.day}日',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        color: fg,
                        height: 1.15,
                      ),
                    ),
                    Text(
                      weeks[now.weekday - 1],
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        color: fg,
                        height: 1.15,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// 进度条：原版 5dp 高。
class _RoamProgress extends StatelessWidget {
  const _RoamProgress({required this.tab});

  final BrowserTab? tab;

  @override
  Widget build(BuildContext context) {
    final loading = tab?.isLoading ?? false;
    final value = loading ? (tab!.progress <= 0 ? 0.08 : tab!.progress) : 0.0;
    return SizedBox(
      height: 3,
      child: loading
          ? Align(
              alignment: Alignment.centerLeft,
              child: FractionallySizedBox(
                widthFactor: value.clamp(0.0, 1.0).toDouble(),
                child: const ColoredBox(color: Color(0xFFFF2C1E)),
              ),
            )
          : const SizedBox.shrink(),
    );
  }
}

/// 底栏：50dp，5 个 24dp 图标。
class _RoamBottomBar extends StatelessWidget {
  const _RoamBottomBar({
    required this.isDark,
    required this.tab,
    required this.controller,
    required this.onMenu,
    required this.onTabs,
  });

  final bool isDark;
  final BrowserTab? tab;
  final BrowserController controller;
  final VoidCallback onMenu;
  final VoidCallback onTabs;

  @override
  Widget build(BuildContext context) {
    final active = isDark ? Colors.white : const Color(0xFF0B1526);
    final dim = active.withValues(alpha: 0.3);
    final canBack = tab?.canGoBack ?? false;
    final canForward = tab?.canGoForward ?? false;

    // 底栏自定义：按设置里的顺序/显隐生成按钮
    final catalog = <String, (String, String, bool, VoidCallback)>{
      'back': (
        'assets/toolbar/webkit_back.png',
        '返回',
        canBack,
        controller.goBack,
      ),
      'forward': (
        'assets/toolbar/webkit_forward.png',
        '前进',
        canForward,
        controller.goForward,
      ),
      'home': (
        'assets/toolbar/webkit_home.png',
        '主页',
        true,
        () => controller.goHome(tab),
      ),
      'tabs': ('assets/toolbar/multi_task.png', '标签页', true, onTabs),
      'menu': ('assets/toolbar/toolbar.png', '菜单', true, onMenu),
      'refresh': (
        'assets/toolbar/refresh_url.png',
        '刷新',
        true,
        controller.reload,
      ),
    };
    final items = [
      for (final id in controller.settings.bottomBarItems)
        if (catalog[id] != null) catalog[id]!,
    ];

    return Container(
      color: isDark ? Colors.black : RoamColors.daySky,
      padding: EdgeInsets.only(bottom: MediaQuery.paddingOf(context).bottom),
      child: SizedBox(
        height: 50,
        child: Row(
          children: [
            const SizedBox(width: 15),
            for (final item in items)
              Expanded(
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: item.$3 ? item.$4 : null,
                  child: Center(
                    child: Image.asset(
                      item.$1,
                      width: 24,
                      height: 24,
                      color: item.$3 ? active : dim,
                      semanticLabel: item.$2,
                    ),
                  ),
                ),
              ),
            const SizedBox(width: 15),
          ],
        ),
      ),
    );
  }
}

class WebViewHost extends StatefulWidget {
  const WebViewHost({
    super.key,
    required this.tab,
    required this.controller,
    required this.isDark,
  });

  final BrowserTab tab;
  final BrowserController controller;
  final bool isDark;

  @override
  State<WebViewHost> createState() => _WebViewHostState();
}

class _WebViewHostState extends State<WebViewHost> {
  static const PageSnapshotService _snapshots = PageSnapshotService();

  Timer? _captureTimer;
  int _seenGeneration = -1;
  bool _capturing = false;

  @override
  void initState() {
    super.initState();
    widget.controller.ensureTabController(widget.tab);
    widget.controller.addListener(_onControllerChanged);
    _seenGeneration = widget.tab.loadGeneration;
  }

  @override
  void didUpdateWidget(covariant WebViewHost oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.tab.id != widget.tab.id) {
      oldWidget.controller.removeListener(_onControllerChanged);
      widget.controller.addListener(_onControllerChanged);
      widget.controller.ensureTabController(widget.tab);
      _seenGeneration = widget.tab.loadGeneration;
    }
  }

  @override
  void dispose() {
    _captureTimer?.cancel();
    widget.controller.removeListener(_onControllerChanged);
    super.dispose();
  }

  /// 页面加载完成（[BrowserTab.loadGeneration] 变化）后补一张低分辨率快照。
  ///
  /// 只在标签页可见时抓：IndexedStack 里没显示的 WebView 不在窗口合成里，
  /// 抓出来是一张空白图。
  void _onControllerChanged() {
    final tab = widget.tab;
    if (widget.controller.activeTab?.id != tab.id) return;
    if (tab.isLoading || tab.url.isEmpty) return;
    if (tab.loadGeneration == _seenGeneration) return;
    _seenGeneration = tab.loadGeneration;
    _captureTimer?.cancel();
    _captureTimer = Timer(const Duration(milliseconds: 260), () {
      unawaited(_capture(tab));
    });
  }

  Future<void> _capture(BrowserTab tab) async {
    if (!mounted || _capturing) return;
    if (widget.controller.activeTab?.id != tab.id) return;
    final box = context.findRenderObject() as RenderBox?;
    if (box == null || !box.hasSize) return;
    final size = box.size;
    if (size.width < 32 || size.height < 32) return;

    final origin = box.localToGlobal(Offset.zero);
    final ratio = MediaQuery.devicePixelRatioOf(context);
    _capturing = true;
    try {
      final bytes = await _snapshots.capture(
        rect: Rect.fromLTWH(origin.dx, origin.dy, size.width, size.height),
        devicePixelRatio: ratio,
      );
      if (bytes == null || !mounted) return;
      final preview = PagePreview(
        url: tab.url,
        bytes: bytes,
        aspectRatio: size.width / size.height,
      );
      PagePreviewCache.instance.record(tab.id, preview);
      // 提前解码，手势开始时第一帧就能画出来，不然会闪一下空白。
      try {
        await precacheImage(MemoryImage(bytes), context);
      } catch (_) {}
    } finally {
      _capturing = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    final tab = widget.tab;
    final web = tab.webController;
    if (web == null) {
      return _UnavailableView(tab: tab, isDark: widget.isDark);
    }

    final error = tab.errorDescription;
    return Stack(
      fit: StackFit.expand,
      children: [
        WebViewWidget(controller: web),
        if (error != null)
          _ErrorView(
            tab: tab,
            message: error,
            isDark: widget.isDark,
            onRetry: () {
              widget.controller.clearError(tab);
              widget.controller.reload();
            },
            onBack: () {
              widget.controller.clearError(tab);
              if (tab.canGoBack) {
                widget.controller.goBack();
              } else {
                widget.controller.goHome(tab);
              }
            },
          ),
      ],
    );
  }
}

/// 侧滑时露出来的「上一页」：一张低分辨率快照 + 重度模糊。
///
/// 快照本身只有 480px 宽，`FilterQuality.low` 放大已经自带柔化，再叠一层
/// 高斯模糊，看起来就是原生浏览器把上一页压在后面的效果。
///
/// 整个子树放在 [RepaintBoundary] 里：手势过程中只有外层 Transform 在变，
/// 模糊结果缓存成一层，不会每帧重算。
class _PageBackdrop extends StatelessWidget {
  const _PageBackdrop({super.key, required this.preview});

  final PagePreview preview;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return ColoredBox(
      color: isDark ? Colors.black : RoamColors.daySky,
      child: RepaintBoundary(
        child: ClipRect(
          // 1.12 倍是留给外层视差位移的余量，同时补掉模糊采样到边界外的半透明。
          child: Transform.scale(
            scale: 1.12,
            child: ImageFiltered(
              imageFilter: ui.ImageFilter.blur(
                sigmaX: 18,
                sigmaY: 18,
                tileMode: ui.TileMode.decal,
              ),
              child: Image.memory(
                preview.bytes,
                fit: BoxFit.cover,
                filterQuality: FilterQuality.low,
                gaplessPlayback: true,
                excludeFromSemantics: true,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _ErrorView extends StatelessWidget {
  const _ErrorView({
    required this.tab,
    required this.message,
    required this.isDark,
    required this.onRetry,
    required this.onBack,
  });

  final BrowserTab tab;
  final String message;
  final bool isDark;
  final VoidCallback onRetry;
  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) {
    return Container(
      color: (isDark ? RoamColors.ink : RoamColors.daySky).withValues(
        alpha: 0.86,
      ),
      alignment: Alignment.center,
      padding: const EdgeInsets.symmetric(horizontal: 32),
      child: RoamGlassPanel(
        borderRadius: const BorderRadius.all(Radius.circular(26)),
        surfaceColor: isDark
            ? const Color(0xFF0E1728).withValues(alpha: 0.82)
            : Colors.white.withValues(alpha: 0.9),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(22, 22, 22, 18),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 52,
                height: 52,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: RoamColors.danger.withValues(alpha: 0.14),
                ),
                child: const Icon(
                  Icons.cloud_off_rounded,
                  size: 24,
                  color: RoamColors.danger,
                ),
              ),
              const SizedBox(height: 14),
              Text(
                '这个页面没能打开',
                style: RoamType.title.copyWith(
                  fontSize: 16,
                  color: isDark ? RoamColors.textPrimary : RoamColors.dayInk,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                message,
                textAlign: TextAlign.center,
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
                style: RoamType.caption.copyWith(
                  height: 1.5,
                  color: isDark
                      ? RoamColors.textSecondary
                      : RoamColors.daySecondary,
                ),
              ),
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  _PillButton(
                    label: '重新加载',
                    icon: Icons.refresh_rounded,
                    filled: true,
                    isDark: isDark,
                    onTap: onRetry,
                  ),
                  const SizedBox(width: 10),
                  _PillButton(
                    label: '返回',
                    icon: Icons.arrow_back_rounded,
                    isDark: isDark,
                    onTap: onBack,
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _UnavailableView extends StatelessWidget {
  const _UnavailableView({required this.tab, required this.isDark});

  final BrowserTab tab;
  final bool isDark;

  @override
  Widget build(BuildContext context) {
    return Container(
      color: isDark ? RoamColors.ink : RoamColors.daySky,
      padding: const EdgeInsets.symmetric(horizontal: 28),
      alignment: Alignment.center,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.devices_other_rounded,
            size: 40,
            color: isDark ? RoamColors.textTertiary : RoamColors.daySecondary,
          ),
          const SizedBox(height: 14),
          Text(
            '当前平台没有 WebView',
            style: RoamType.title.copyWith(
              fontSize: 16,
              color: isDark ? RoamColors.textPrimary : RoamColors.dayInk,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Android / iOS 构建会自动启用网页渲染。\n'
            '桌面端仅用于预览界面，地址栏与标签功能仍可操作。',
            textAlign: TextAlign.center,
            style: RoamType.caption.copyWith(
              height: 1.6,
              color: isDark
                  ? RoamColors.textSecondary
                  : RoamColors.daySecondary,
            ),
          ),
          if (tab.url.isNotEmpty) ...[
            const SizedBox(height: 14),
            Text(
              tab.url,
              textAlign: TextAlign.center,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: RoamType.mono.copyWith(
                fontSize: 11,
                color: isDark
                    ? RoamColors.textTertiary
                    : RoamColors.daySecondary,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _PillButton extends StatelessWidget {
  const _PillButton({
    required this.label,
    required this.icon,
    required this.isDark,
    required this.onTap,
    this.filled = false,
  });

  final String label;
  final IconData icon;
  final bool isDark;
  final VoidCallback onTap;
  final bool filled;

  @override
  Widget build(BuildContext context) {
    return PressableScale(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(999),
          color: filled
              ? RoamColors.aurora.withValues(alpha: 0.18)
              : (isDark ? Colors.white : Colors.black).withValues(alpha: 0.05),
          border: Border.all(
            color: filled
                ? RoamColors.aurora.withValues(alpha: 0.42)
                : Colors.transparent,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 15,
              color: filled
                  ? RoamColors.aurora
                  : (isDark
                        ? RoamColors.textSecondary
                        : RoamColors.daySecondary),
            ),
            const SizedBox(width: 6),
            Text(
              label,
              style: RoamType.caption.copyWith(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: filled
                    ? RoamColors.aurora
                    : (isDark
                          ? RoamColors.textSecondary
                          : RoamColors.daySecondary),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// 供 `onGenerateRoute` 复用的页面构造器。
Route<void> buildRoamRoute(
  RouteSettings settings,
  BrowserController controller,
) {
  final page = switch (settings.name) {
    '/bookmarks' => BookmarksPage(controller: controller),
    '/history' => HistoryPage(controller: controller),
    '/downloads' => DownloadsPage(controller: controller),
    '/settings' => SettingsPage(controller: controller),
    _ => null,
  };
  if (page == null) {
    return MaterialPageRoute<void>(
      builder: (_) => BrowserShell(controller: controller),
      settings: settings,
    );
  }
  return MaterialPageRoute<void>(builder: (_) => page, settings: settings);
}
