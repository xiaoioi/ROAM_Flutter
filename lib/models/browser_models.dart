import 'package:flutter/foundation.dart';
import 'package:webview_flutter/webview_flutter.dart';

enum SearchEngine { baidu, bing, google, sogou, custom }

extension SearchEngineX on SearchEngine {
  String get label => switch (this) {
    SearchEngine.baidu => '百度',
    SearchEngine.bing => '必应',
    SearchEngine.google => 'Google',
    SearchEngine.sogou => '搜狗',
    SearchEngine.custom => '自定义',
  };

  String searchUrl(String query, [String? customTemplate]) {
    final encoded = Uri.encodeQueryComponent(query);
    return switch (this) {
      SearchEngine.baidu => 'https://www.baidu.com/s?wd=$encoded',
      SearchEngine.bing => 'https://cn.bing.com/search?q=$encoded',
      SearchEngine.google => 'https://www.google.com/search?q=$encoded',
      SearchEngine.sogou => 'https://www.sogou.com/web?query=$encoded',
      SearchEngine.custom =>
        (customTemplate ?? '').contains('%s')
            ? customTemplate!.replaceAll('%s', encoded)
            : 'https://www.baidu.com/s?wd=$encoded',
    };
  }
}

enum AppThemeMode { system, light, dark }

@immutable
class BrowserSettings {
  const BrowserSettings({
    this.searchEngine = SearchEngine.bing,
    this.customSearchTemplate = 'https://www.baidu.com/s?wd=%s',
    this.themeMode = AppThemeMode.system,
    this.javascriptEnabled = true,
    this.desktopMode = false,
    this.restoreTabs = true,
    this.followSystemColor = true,
    this.liquidMaterial = true,
    this.appIcon = 'default',
    this.edgeSwipeBack = true,
    this.forwardGesture = true,
    this.forceZoom = false,
    this.magnifier = true,
    this.hideTopBarOnScroll = false,
    this.hideBottomBar = false,
    this.hardwareAcceleration = true,
    this.saveFormData = false,
    this.loadImages = true,
    this.blockAds = false,
    this.redirectControl = true,
    this.ignoreSslErrors = false,
    this.storeCookie = true,
    this.webViewOptimize = true,
    this.webViewDevTools = false,
    this.downloadOnCellular = false,
    this.smartDownloadOrder = true,
    this.notifyOnDownloadComplete = true,
    this.safeBrowsing = true,
    this.aiEnabled = false,
    this.aiImageTidy = true,
    this.aiPageInsight = false,
    this.edgeFade = true,
    this.showScrollbar = false,
    this.blurQuality = 'quality',
    this.rimLight = true,
    this.customGlass = true,
    this.glassBlur = 1.0,
    this.fontMode = 'default',
    this.wallpaper = 'none',
    this.customWallpaperPath = '',
    this.wallpaperDim = 0.38,
    this.aiApiBase = defaultAiApiBase,
    this.aiApiKey = '',
    this.aiModel = defaultAiModel,
    this.glassOpacity = 1.0,
    this.blurBackground = true,
    this.hdrDisplay = false,
    this.topBarGlass = false,
    List<String>? toolbarItems,
    List<String>? bottomBarItems,
  }) : toolbarItems = toolbarItems ?? defaultToolbarItems,
       bottomBarItems = bottomBarItems ?? defaultBottomBarItems;

  /// 工具栏默认显示项（两页共 19 项，id 即功能标识）。
  static const List<String> defaultToolbarItems = [
    'history',
    'ua',
    'copy_link',
    'settings',
    'qrcode',
    'incognito',
    'translate',
    'sniffer',
    'bookmark_add',
    'drive',
    'fullscreen',
    'landscape',
    'screenshot_block',
    'metaso',
    'cookie',
    'javascript',
    'terminal',
    'view_source',
    'print',
  ];

  /// 底栏默认显示项。
  static const List<String> defaultBottomBarItems = [
    'back',
    'forward',
    'home',
    'menu',
    'refresh',
  ];

  /// AI 翻译默认服务：哔哩哔哩 Index-Translate 免费公网 API（OpenAI 兼容）。
  /// 免 key 即可调用；接口路径按 `<base>/chat/completions` 拼接。
  static const String defaultAiApiBase =
      'https://index-translate.bilibili.com/v1';
  static const String defaultAiModel = 'index-mt-35b';
  static const List<String> aiModelPresets = [
    'index-mt-35b',
    'index-mt-9b',
    'index-mt-2b',
  ];

  final SearchEngine searchEngine;
  final String customSearchTemplate;
  final AppThemeMode themeMode;
  final bool javascriptEnabled;
  final bool desktopMode;
  final bool restoreTabs;

  /// 跟随系统取色（Monet）。
  final bool followSystemColor;

  /// 柔光玻璃材质效果（flutter_miuix 的 OS4 材质）。
  final bool liquidMaterial;

  /// 应用图标：default / explore / intelligence / fashion。
  final String appIcon;

  // ---- 浏览器设置（WebViewSettings）----
  final bool edgeSwipeBack;
  final bool forwardGesture;
  final bool forceZoom;
  final bool magnifier;
  final bool hideTopBarOnScroll;
  final bool hideBottomBar;
  final bool hardwareAcceleration;
  final bool saveFormData;
  final bool loadImages;
  final bool blockAds;
  final bool redirectControl;
  final bool ignoreSslErrors;
  final bool storeCookie;
  final bool webViewOptimize;
  final bool webViewDevTools;
  final bool downloadOnCellular;
  final bool smartDownloadOrder;
  final bool notifyOnDownloadComplete;
  final bool safeBrowsing;

  // ---- AI 服务 ----
  final bool aiEnabled;
  final bool aiImageTidy;
  final bool aiPageInsight;

  // ---- 材质显示效果（ModifyMaterialEffect）----

  /// 内容到达边缘时的渐隐。
  final bool edgeFade;

  /// 列表滚动条。
  final bool showScrollbar;

  /// 高斯模糊效果：performance 性能优先 / quality 效果优先。
  final String blurQuality;

  /// 轮廓光材质（玻璃边缘高光）。
  final bool rimLight;

  /// 玻璃引擎：true = 自绘 OS4 柔光玻璃（commonSmallRegular，默认），
  /// false = flutter_miuix 的 MiuixGlass。
  final bool customGlass;

  /// 模糊度倍率（仅自绘玻璃生效），0.5~2.0，1.0 为标准强度。
  final double glassBlur;

  /// 字体：default / system / roboto / serif。
  final String fontMode;

  /// 主界面壁纸：none / wanmu / luoyang / muguang / kongjing / custom。
  final String wallpaper;
  final String customWallpaperPath;

  /// 壁纸压暗强度（0~0.8）。壁纸上的白色文字和玻璃需要一点压暗才稳，
  /// 原版固定 0.38，这里开放给用户调。
  final double wallpaperDim;

  /// AI 翻译服务（OpenAI 兼容接口）：base 形如 `https://host/v1`，
  /// 实际请求 `<base>/chat/completions`。key 可空（B 站公开 API 免 key）。
  final String aiApiBase;
  final String aiApiKey;
  final String aiModel;

  final double glassOpacity;
  final bool blurBackground;
  final bool hdrDisplay;

  /// 顶栏圆钮是否走真实背景采样玻璃（false = 澎湃 4 实心圆钮）。
  final bool topBarGlass;

  /// 工具栏自定义：显示的功能 id 有序列表。
  final List<String> toolbarItems;

  /// 底栏自定义：显示的按钮 id 有序列表。
  final List<String> bottomBarItems;

  BrowserSettings copyWith({
    SearchEngine? searchEngine,
    String? customSearchTemplate,
    AppThemeMode? themeMode,
    bool? javascriptEnabled,
    bool? desktopMode,
    bool? restoreTabs,
    bool? followSystemColor,
    bool? liquidMaterial,
    String? appIcon,
    bool? edgeSwipeBack,
    bool? forwardGesture,
    bool? forceZoom,
    bool? magnifier,
    bool? hideTopBarOnScroll,
    bool? hideBottomBar,
    bool? hardwareAcceleration,
    bool? saveFormData,
    bool? loadImages,
    bool? blockAds,
    bool? redirectControl,
    bool? ignoreSslErrors,
    bool? storeCookie,
    bool? webViewOptimize,
    bool? webViewDevTools,
    bool? downloadOnCellular,
    bool? smartDownloadOrder,
    bool? notifyOnDownloadComplete,
    bool? safeBrowsing,
    bool? aiEnabled,
    bool? aiImageTidy,
    bool? aiPageInsight,
    bool? edgeFade,
    bool? showScrollbar,
    String? blurQuality,
    bool? rimLight,
    bool? customGlass,
    double? glassBlur,
    String? fontMode,
    String? wallpaper,
    String? customWallpaperPath,
    double? wallpaperDim,
    String? aiApiBase,
    String? aiApiKey,
    String? aiModel,
    double? glassOpacity,
    bool? blurBackground,
    bool? hdrDisplay,
    bool? topBarGlass,
    List<String>? toolbarItems,
    List<String>? bottomBarItems,
  }) {
    return BrowserSettings(
      searchEngine: searchEngine ?? this.searchEngine,
      customSearchTemplate: customSearchTemplate ?? this.customSearchTemplate,
      themeMode: themeMode ?? this.themeMode,
      javascriptEnabled: javascriptEnabled ?? this.javascriptEnabled,
      desktopMode: desktopMode ?? this.desktopMode,
      restoreTabs: restoreTabs ?? this.restoreTabs,
      followSystemColor: followSystemColor ?? this.followSystemColor,
      liquidMaterial: liquidMaterial ?? this.liquidMaterial,
      appIcon: appIcon ?? this.appIcon,
      edgeSwipeBack: edgeSwipeBack ?? this.edgeSwipeBack,
      forwardGesture: forwardGesture ?? this.forwardGesture,
      forceZoom: forceZoom ?? this.forceZoom,
      magnifier: magnifier ?? this.magnifier,
      hideTopBarOnScroll: hideTopBarOnScroll ?? this.hideTopBarOnScroll,
      hideBottomBar: hideBottomBar ?? this.hideBottomBar,
      hardwareAcceleration: hardwareAcceleration ?? this.hardwareAcceleration,
      saveFormData: saveFormData ?? this.saveFormData,
      loadImages: loadImages ?? this.loadImages,
      blockAds: blockAds ?? this.blockAds,
      redirectControl: redirectControl ?? this.redirectControl,
      ignoreSslErrors: ignoreSslErrors ?? this.ignoreSslErrors,
      storeCookie: storeCookie ?? this.storeCookie,
      webViewOptimize: webViewOptimize ?? this.webViewOptimize,
      webViewDevTools: webViewDevTools ?? this.webViewDevTools,
      downloadOnCellular: downloadOnCellular ?? this.downloadOnCellular,
      smartDownloadOrder: smartDownloadOrder ?? this.smartDownloadOrder,
      notifyOnDownloadComplete:
          notifyOnDownloadComplete ?? this.notifyOnDownloadComplete,
      safeBrowsing: safeBrowsing ?? this.safeBrowsing,
      aiEnabled: aiEnabled ?? this.aiEnabled,
      aiImageTidy: aiImageTidy ?? this.aiImageTidy,
      aiPageInsight: aiPageInsight ?? this.aiPageInsight,
      edgeFade: edgeFade ?? this.edgeFade,
      showScrollbar: showScrollbar ?? this.showScrollbar,
      blurQuality: blurQuality ?? this.blurQuality,
      rimLight: rimLight ?? this.rimLight,
      customGlass: customGlass ?? this.customGlass,
      glassBlur: glassBlur ?? this.glassBlur,
      fontMode: fontMode ?? this.fontMode,
      wallpaper: wallpaper ?? this.wallpaper,
      customWallpaperPath: customWallpaperPath ?? this.customWallpaperPath,
      wallpaperDim: wallpaperDim ?? this.wallpaperDim,
      aiApiBase: aiApiBase ?? this.aiApiBase,
      aiApiKey: aiApiKey ?? this.aiApiKey,
      aiModel: aiModel ?? this.aiModel,
      glassOpacity: glassOpacity ?? this.glassOpacity,
      blurBackground: blurBackground ?? this.blurBackground,
      hdrDisplay: hdrDisplay ?? this.hdrDisplay,
      topBarGlass: topBarGlass ?? this.topBarGlass,
      toolbarItems: toolbarItems ?? this.toolbarItems,
      bottomBarItems: bottomBarItems ?? this.bottomBarItems,
    );
  }

  Map<String, Object?> toJson() => {
    'searchEngine': searchEngine.name,
    'customSearchTemplate': customSearchTemplate,
    'themeMode': themeMode.name,
    'javascriptEnabled': javascriptEnabled,
    'desktopMode': desktopMode,
    'restoreTabs': restoreTabs,
    'followSystemColor': followSystemColor,
    'liquidMaterial': liquidMaterial,
    'appIcon': appIcon,
    'edgeSwipeBack': edgeSwipeBack,
    'forwardGesture': forwardGesture,
    'forceZoom': forceZoom,
    'magnifier': magnifier,
    'hideTopBarOnScroll': hideTopBarOnScroll,
    'hideBottomBar': hideBottomBar,
    'hardwareAcceleration': hardwareAcceleration,
    'saveFormData': saveFormData,
    'loadImages': loadImages,
    'blockAds': blockAds,
    'redirectControl': redirectControl,
    'ignoreSslErrors': ignoreSslErrors,
    'storeCookie': storeCookie,
    'webViewOptimize': webViewOptimize,
    'webViewDevTools': webViewDevTools,
    'downloadOnCellular': downloadOnCellular,
    'smartDownloadOrder': smartDownloadOrder,
    'notifyOnDownloadComplete': notifyOnDownloadComplete,
    'safeBrowsing': safeBrowsing,
    'aiEnabled': aiEnabled,
    'aiImageTidy': aiImageTidy,
    'aiPageInsight': aiPageInsight,
    'edgeFade': edgeFade,
    'showScrollbar': showScrollbar,
    'blurQuality': blurQuality,
    'rimLight': rimLight,
    'customGlass': customGlass,
    'glassBlur': glassBlur,
    'fontMode': fontMode,
    'wallpaper': wallpaper,
    'customWallpaperPath': customWallpaperPath,
    'wallpaperDim': wallpaperDim,
    'aiApiBase': aiApiBase,
    'aiApiKey': aiApiKey,
    'aiModel': aiModel,
    'glassOpacity': glassOpacity,
    'blurBackground': blurBackground,
    'hdrDisplay': hdrDisplay,
    'topBarGlass': topBarGlass,
    'toolbarItems': toolbarItems,
    'bottomBarItems': bottomBarItems,
  };

  factory BrowserSettings.fromJson(Map<String, Object?> json) {
    return BrowserSettings(
      searchEngine:
          SearchEngine.values.asNameMap()[json['searchEngine']] ??
          SearchEngine.bing,
      customSearchTemplate:
          json['customSearchTemplate'] as String? ??
          'https://www.baidu.com/s?wd=%s',
      themeMode:
          AppThemeMode.values.asNameMap()[json['themeMode']] ??
          AppThemeMode.system,
      javascriptEnabled: json['javascriptEnabled'] as bool? ?? true,
      desktopMode: json['desktopMode'] as bool? ?? false,
      restoreTabs: json['restoreTabs'] as bool? ?? true,
      followSystemColor: json['followSystemColor'] as bool? ?? true,
      liquidMaterial: json['liquidMaterial'] as bool? ?? true,
      appIcon: json['appIcon'] as String? ?? 'default',
      edgeSwipeBack: json['edgeSwipeBack'] as bool? ?? true,
      forwardGesture: json['forwardGesture'] as bool? ?? true,
      forceZoom: json['forceZoom'] as bool? ?? false,
      magnifier: json['magnifier'] as bool? ?? true,
      hideTopBarOnScroll: json['hideTopBarOnScroll'] as bool? ?? false,
      hideBottomBar: json['hideBottomBar'] as bool? ?? false,
      hardwareAcceleration: json['hardwareAcceleration'] as bool? ?? true,
      saveFormData: json['saveFormData'] as bool? ?? false,
      loadImages: json['loadImages'] as bool? ?? true,
      blockAds: json['blockAds'] as bool? ?? false,
      redirectControl: json['redirectControl'] as bool? ?? true,
      ignoreSslErrors: json['ignoreSslErrors'] as bool? ?? false,
      storeCookie: json['storeCookie'] as bool? ?? true,
      webViewOptimize: json['webViewOptimize'] as bool? ?? true,
      webViewDevTools: json['webViewDevTools'] as bool? ?? false,
      downloadOnCellular: json['downloadOnCellular'] as bool? ?? false,
      smartDownloadOrder: json['smartDownloadOrder'] as bool? ?? true,
      notifyOnDownloadComplete:
          json['notifyOnDownloadComplete'] as bool? ?? true,
      safeBrowsing: json['safeBrowsing'] as bool? ?? true,
      aiEnabled: json['aiEnabled'] as bool? ?? false,
      aiImageTidy: json['aiImageTidy'] as bool? ?? true,
      aiPageInsight: json['aiPageInsight'] as bool? ?? false,
      edgeFade: json['edgeFade'] as bool? ?? true,
      showScrollbar: json['showScrollbar'] as bool? ?? false,
      blurQuality: json['blurQuality'] as String? ?? 'quality',
      rimLight: json['rimLight'] as bool? ?? true,
      customGlass: json['customGlass'] as bool? ?? true,
      glassBlur: (json['glassBlur'] as num?)?.toDouble() ?? 1.0,
      fontMode: json['fontMode'] as String? ?? 'default',
      wallpaper: json['wallpaper'] as String? ?? 'none',
      customWallpaperPath: json['customWallpaperPath'] as String? ?? '',
      wallpaperDim: (json['wallpaperDim'] as num?)?.toDouble() ?? 0.38,
      aiApiBase: json['aiApiBase'] as String? ?? defaultAiApiBase,
      aiApiKey: json['aiApiKey'] as String? ?? '',
      aiModel: json['aiModel'] as String? ?? defaultAiModel,
      glassOpacity: (json['glassOpacity'] as num?)?.toDouble() ?? 1.0,
      blurBackground: json['blurBackground'] as bool? ?? true,
      hdrDisplay: json['hdrDisplay'] as bool? ?? false,
      topBarGlass: json['topBarGlass'] as bool? ?? false,
      toolbarItems:
          (json['toolbarItems'] as List?)?.cast<String>() ??
          BrowserSettings.defaultToolbarItems,
      bottomBarItems:
          (json['bottomBarItems'] as List?)?.cast<String>() ??
          BrowserSettings.defaultBottomBarItems,
    );
  }
}

class BrowserTab {
  BrowserTab({
    required this.id,
    required this.createdAt,
    this.title = '新标签页',
    this.url = '',
    this.isIncognito = false,
  });

  final String id;
  final DateTime createdAt;
  String title;
  String url;
  final bool isIncognito;
  WebViewController? webController;
  int progress = 0;
  bool isLoading = false;
  bool canGoBack = false;
  bool canGoForward = false;
  String? errorDescription;

  bool get isHome => url.isEmpty;

  Map<String, Object?> toJson() => {
    'id': id,
    'createdAt': createdAt.toIso8601String(),
    'title': title,
    'url': url,
    'isIncognito': isIncognito,
  };

  factory BrowserTab.fromJson(Map<String, Object?> json) {
    return BrowserTab(
      id: json['id'] as String? ?? '',
      createdAt:
          DateTime.tryParse(json['createdAt'] as String? ?? '') ??
          DateTime.now(),
      title: json['title'] as String? ?? '新标签页',
      url: json['url'] as String? ?? '',
      isIncognito: json['isIncognito'] as bool? ?? false,
    );
  }
}

@immutable
class Bookmark {
  const Bookmark({
    required this.id,
    required this.title,
    required this.url,
    required this.createdAt,
  });

  final String id;
  final String title;
  final String url;
  final DateTime createdAt;

  Map<String, Object?> toJson() => {
    'id': id,
    'title': title,
    'url': url,
    'createdAt': createdAt.toIso8601String(),
  };

  factory Bookmark.fromJson(Map<String, Object?> json) => Bookmark(
    id: json['id'] as String? ?? '',
    title: json['title'] as String? ?? '未命名书签',
    url: json['url'] as String? ?? '',
    createdAt:
        DateTime.tryParse(json['createdAt'] as String? ?? '') ?? DateTime.now(),
  );
}

@immutable
class HistoryEntry {
  const HistoryEntry({
    required this.id,
    required this.title,
    required this.url,
    required this.visitedAt,
  });

  final String id;
  final String title;
  final String url;
  final DateTime visitedAt;

  Map<String, Object?> toJson() => {
    'id': id,
    'title': title,
    'url': url,
    'visitedAt': visitedAt.toIso8601String(),
  };

  factory HistoryEntry.fromJson(Map<String, Object?> json) => HistoryEntry(
    id: json['id'] as String? ?? '',
    title: json['title'] as String? ?? '未命名页面',
    url: json['url'] as String? ?? '',
    visitedAt:
        DateTime.tryParse(json['visitedAt'] as String? ?? '') ?? DateTime.now(),
  );
}

enum DownloadStatus { running, complete, failed, cancelled }

class DownloadEntry {
  DownloadEntry({
    required this.id,
    required this.fileName,
    required this.url,
    required this.path,
    required this.mimeType,
    required this.createdAt,
    this.totalBytes = 0,
    this.receivedBytes = 0,
    this.status = DownloadStatus.running,
    this.error,
  });

  final String id;
  final String fileName;
  final String url;
  final String path;
  final String mimeType;
  final DateTime createdAt;
  int totalBytes;
  int receivedBytes;
  DownloadStatus status;
  String? error;

  Map<String, Object?> toJson() => {
    'id': id,
    'fileName': fileName,
    'url': url,
    'path': path,
    'mimeType': mimeType,
    'createdAt': createdAt.toIso8601String(),
    'totalBytes': totalBytes,
    'receivedBytes': receivedBytes,
    'status': status.name,
    'error': error,
  };

  factory DownloadEntry.fromJson(Map<String, Object?> json) {
    final status =
        DownloadStatus.values.asNameMap()[json['status']] ??
        DownloadStatus.failed;
    return DownloadEntry(
      id: json['id'] as String? ?? '',
      fileName: json['fileName'] as String? ?? 'download',
      url: json['url'] as String? ?? '',
      path: json['path'] as String? ?? '',
      mimeType: json['mimeType'] as String? ?? 'application/octet-stream',
      createdAt:
          DateTime.tryParse(json['createdAt'] as String? ?? '') ??
          DateTime.now(),
      totalBytes: json['totalBytes'] as int? ?? 0,
      receivedBytes: json['receivedBytes'] as int? ?? 0,
      status: status == DownloadStatus.running ? DownloadStatus.failed : status,
      error: json['error'] as String?,
    );
  }
}
