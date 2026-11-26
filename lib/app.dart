// ignore_for_file: deprecated_member_use

import 'package:flutter/material.dart';
import 'package:flutter_miuix/miuix.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'models/browser_models.dart';
import 'state/browser_controller.dart';
import 'theme/roam_theme.dart';
import 'ui/app_messenger.dart';
import 'ui/app_route_observer.dart';
import 'ui/browser_shell.dart';
import 'ui/pages/settings_page.dart';
import 'ui/pages/material_effects_page.dart';
import 'ui/pages/welcome_page.dart';
import 'ui/widgets/app_lock_gate.dart';
import 'ui/widgets/glass_controls.dart';
import 'ui/widgets/predictive_back.dart';

class RoamApp extends StatefulWidget {
  const RoamApp({super.key, required this.controller});

  final BrowserController controller;

  @override
  State<RoamApp> createState() => _RoamAppState();
}

class _RoamAppState extends State<RoamApp> {
  late AppThemeMode _mode;
  late String _fontMode;
  late String _blurQuality;
  late bool _liquidMaterial;
  late bool _rimLight;
  late bool _showScrollbar;
  late bool _edgeFade;
  late bool _customGlass;
  late double _glassBlur;

  /// OOBE 启动引导：null=读取中，true=待展示。与原包一致按
  /// software_startupguide_tag 判断（首次/引导版本变化时展示一次）。
  bool? _oobePending;

  @override
  void initState() {
    super.initState();
    final settings = widget.controller.settings;
    _mode = settings.themeMode;
    _fontMode = settings.fontMode;
    _blurQuality = settings.blurQuality;
    _liquidMaterial = settings.liquidMaterial;
    _rimLight = settings.rimLight;
    _showScrollbar = settings.showScrollbar;
    _edgeFade = settings.edgeFade;
    _customGlass = settings.customGlass;
    _glassBlur = settings.glassBlur;
    GlassRuntime.customGlass.value = _customGlass;
    GlassRuntime.blurScale.value = _glassBlur;
    GlassRuntime.performance.value = _blurQuality == 'performance';
    widget.controller.addListener(_onControllerChanged);
    _loadOobe();
  }

  static const _oobeTagKey = 'software_startupguide_tag';
  static const _oobeTag = 'roamWelcomeUI_100.0';

  Future<void> _loadOobe() async {
    final prefs = await SharedPreferences.getInstance();
    final pending = prefs.getString(_oobeTagKey) != _oobeTag;
    if (!mounted) return;
    setState(() => _oobePending = pending);
  }

  Future<void> _finishOobe() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_oobeTagKey, _oobeTag);
    if (mounted) setState(() => _oobePending = false);
  }

  @override
  void dispose() {
    widget.controller.removeListener(_onControllerChanged);
    super.dispose();
  }

  /// 只在主题、字体、材质这些全局外观项真的变化时重建 MaterialApp。
  void _onControllerChanged() {
    final settings = widget.controller.settings;
    final changed =
        settings.themeMode != _mode ||
        settings.fontMode != _fontMode ||
        settings.blurQuality != _blurQuality ||
        settings.liquidMaterial != _liquidMaterial ||
        settings.rimLight != _rimLight ||
        settings.showScrollbar != _showScrollbar ||
        settings.edgeFade != _edgeFade ||
        settings.customGlass != _customGlass ||
        settings.glassBlur != _glassBlur;
    if (!changed || !mounted) return;
    setState(() {
      _mode = settings.themeMode;
      _fontMode = settings.fontMode;
      _blurQuality = settings.blurQuality;
      _liquidMaterial = settings.liquidMaterial;
      _rimLight = settings.rimLight;
      _showScrollbar = settings.showScrollbar;
        _edgeFade = settings.edgeFade;
      _customGlass = settings.customGlass;
      _glassBlur = settings.glassBlur;
    });
  }

  ThemeMode get _themeMode => switch (_mode) {
    AppThemeMode.system => ThemeMode.system,
    AppThemeMode.light => ThemeMode.light,
    AppThemeMode.dark => ThemeMode.dark,
  };

  String? get _fontFamily => switch (_fontMode) {
    'roboto' => 'Roboto',
    'serif' => 'serif',
    _ => null,
  };

  @override
  Widget build(BuildContext context) {
    GlassRuntime.material.value = _liquidMaterial;
    GlassRuntime.rimLight.value = _rimLight;
    GlassRuntime.edgeFade.value = _edgeFade;
    GlassRuntime.customGlass.value = _customGlass;
    GlassRuntime.blurScale.value = _glassBlur;
    GlassRuntime.performance.value = _blurQuality == 'performance';
    return MiuixSystemTheme(
      child: MaterialApp(
        title: '星环 Roam',
        debugShowCheckedModeBanner: false,
        navigatorObservers: [roamRouteObserver],
        theme: RoamTheme.build(Brightness.light, fontFamily: _fontFamily),
        darkTheme: RoamTheme.build(Brightness.dark, fontFamily: _fontFamily),
        themeMode: const bool.fromEnvironment('ROAM_DEV_DARK')
            ? ThemeMode.dark
            : _themeMode,
        locale: const Locale('zh', 'CN'),
        supportedLocales: const [
          Locale('zh', 'CN'),
          Locale('zh', 'TW'),
          Locale('en', 'US'),
        ],
        localizationsDelegates: const [
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        builder: (context, child) {
          final brightness = Theme.of(context).brightness;
          final isDark = brightness == Brightness.dark;
          // MiuixSystemTheme 跟随系统亮度，会和 App 内主题打架（系统浅色 + App
          // 深色时 miuix 全按浅色渲染，卡片/玻璃发白）。这里按 App 实际亮度覆盖。
          return PredictiveBackHost(
            child: MiuixTheme(
              data: MiuixThemeData.of(brightness),
              child: ScrollConfiguration(
                behavior: ScrollConfiguration.of(context)
                    .copyWith(scrollbars: _showScrollbar),
                child: AnnotatedRegion<SystemUiOverlayStyle>(
                  value:
                      (isDark
                              ? SystemUiOverlayStyle.light
                              : SystemUiOverlayStyle.dark)
                          .copyWith(
                            statusBarColor: Colors.transparent,
                            systemNavigationBarColor: Colors.transparent,
                            systemNavigationBarDividerColor: Colors.transparent,
                            systemNavigationBarIconBrightness: isDark
                                ? Brightness.light
                                : Brightness.dark,
                          ),
                  // 注意：MiuixLayerBackdropCapture 的捕获层放在 BrowserShell
                  // 的 body 内（只包页面内容，不含 Navigator），modal 弹层在
                  // 其外采样，因此不会把玻璃自身录进快照（OS4 反馈循环）。
                  //
                  // 应用锁套在 Navigator 外面：锁页要盖住设置页、弹层这些
                  // 后压进来的路由，同时底下的 WebView 保持挂载不重建。
                  child: AppLockGate(
                    controller: widget.controller,
                    child: Stack(
                      children: [
                        child ?? const SizedBox.shrink(),
                        // Miuix Snackbar 宿主：提示统一走系统样式，挂在
                        // Navigator 之上，抬到工具栏上方免得被底栏挡住。
                        Positioned(
                          left: 0,
                          right: 0,
                          // 底栏 50dp + 手势条安全区，再留 8dp 呼吸；提示不压工具栏。
                          bottom: 58 + MediaQuery.paddingOf(context).bottom,
                          child: ListenableBuilder(
                            listenable: GlassRuntime.repaint,
                            builder: (context, _) => MiuixSnackbarHost(
                              state: roamSnackbarHost,
                              // 材质关闭 / 性能优先时不跑背景模糊。
                              blurSigma:
                                  GlassRuntime.mode == RoamGlassMode.standard
                                  ? 28
                                  : 0,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          );
        },
        home: const bool.fromEnvironment('ROAM_DEV_SETTINGS')
            ? SettingsPage(controller: widget.controller)
            : const bool.fromEnvironment('ROAM_DEV_MATERIAL')
            ? MaterialEffectsPage(controller: widget.controller)
            : const bool.fromEnvironment('ROAM_DEV_HOME')
            ? BrowserShell(controller: widget.controller)
            : switch (_oobePending) {
                null => const ColoredBox(color: Color(0xFF202124)),
                true => WelcomePage(onDone: _finishOobe),
                false => BrowserShell(controller: widget.controller),
              },
        onGenerateRoute: (settings) =>
            buildRoamRoute(settings, widget.controller),
      ),
    );
  }
}
