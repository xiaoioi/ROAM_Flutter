// ignore_for_file: deprecated_member_use

import 'dart:io';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart' show ValueListenable;
import 'package:flutter/material.dart';
import 'package:flutter_miuix/miuix.dart';

import '../../theme/roam_theme.dart';
import '../widgets/roam_sheet.dart';

/// 关于页。
///
/// 版式对齐 miuix 官方 Compose 示例（`example/shared/.../AboutPage.kt`）：
///  - 全屏彩色光晕背景，静态绘制、只录一次快照，玻璃卡片直接采样它；
///  - 顶部固定「大图标 + 大标题 + 版本号」三段式 hero，随滚动淡出并缩一点；
///  - 内容是一组 OS4 玻璃卡片，行式 `ArrowPreference`（标题 + 右侧取值 + 箭头）；
///  - 顶栏透明，滚过 hero 之后才浮出标题与底衬。
class AboutPage extends StatefulWidget {
  const AboutPage({super.key});

  /// 与 `pubspec.yaml` 的 version 保持同步。
  static const versionName = '1.0.31';
  static const versionCode = 138;

  static const _releaseLabel = '100.3Beta4';

  static const _enhancements = [
    'Windmill 预测性手势支持',
    '星环「听见」音效均衡器',
    'Vulkan 网页渲染API',
    'EasyGo 平行视界',
    '新一代浏览器内核平台',
    '新一代浏览器内核平台增强型优化',
    '黑白韵调相机滤镜',
    'QmBlurView For ROAM Explore',
    'HDR 高光能力',
    'Dolby Vision 杜比视界 API',
    'App Shortcut 快捷磁贴',
    'Web Game 渲染优化',
    '星环无极可变字体交互框架',
  ];

  @override
  State<AboutPage> createState() => _AboutPageState();
}

class _AboutPageState extends State<AboutPage> {
  /// 只捕获背景层：卡片玻璃采样它，自己不在捕获子树里，不会自采样。
  final MiuixLayerBackdrop _backdrop = MiuixLayerBackdrop();
  final ScrollController _scroll = ScrollController();
  final ValueNotifier<double> _progress = ValueNotifier(0);

  static const _heroIcon = 88.0;
  static const _heroGap = 12.0;
  static const _heroTitle = 44.0;
  static const _heroVersion = 20.0;
  static const _heroHeight = _heroIcon + _heroGap + _heroTitle + _heroVersion;

  @override
  void initState() {
    super.initState();
    _scroll.addListener(_onScroll);
  }

  void _onScroll() {
    if (!_scroll.hasClients) return;
    final next = (_scroll.offset / 210).clamp(0.0, 1.0);
    if ((next - _progress.value).abs() < 0.008) return;
    _progress.value = next;
  }

  @override
  void dispose() {
    _scroll.removeListener(_onScroll);
    _scroll.dispose();
    _progress.dispose();
    _backdrop.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final fg = isDark ? RoamColors.textPrimary : RoamColors.dayInk;
    final sub = isDark ? RoamColors.textSecondary : RoamColors.daySecondary;
    final media = MediaQuery.of(context);
    final heroTop = media.padding.top + 44;

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF07060F) : const Color(0xFFF7F5FC),
      body: Stack(
        children: [
          // 背景：静态光晕，录一次快照给玻璃采样。
          Positioned.fill(
            child: MiuixLayerBackdropCapture(
              backdrop: _backdrop,
              pixelRatio: 1,
              child: RepaintBoundary(
                child: CustomPaint(
                  painter: _AuraPainter(isDark: isDark),
                  size: Size.infinite,
                ),
              ),
            ),
          ),
          // 内容：上边距留出 hero 那一块，滚动时从 hero 底下穿过去。
          ListView(
            controller: _scroll,
            physics: const BouncingScrollPhysics(
              parent: AlwaysScrollableScrollPhysics(),
            ),
            padding: EdgeInsets.fromLTRB(
              0,
              heroTop + _heroHeight + 10,
              0,
              32 + media.padding.bottom,
            ),
            children: [
              _card(
                isDark: isDark,
                children: [
                  _AboutRow(
                    title: '软件更新',
                    value: '已是最新',
                    onTap: () => _checkUpdate(context),
                  ),
                  _AboutRow(
                    title: '增强特性',
                    value: '${AboutPage._enhancements.length} 项',
                    onTap: () => _showEnhancements(context),
                  ),
                ],
              ),
              _card(
                isDark: isDark,
                children: [
                  _AboutRow(
                    title: '软件与版本信息',
                    value: AboutPage._releaseLabel,
                    onTap: () => _showSoftwareInfo(context),
                  ),
                  _AboutRow(
                    title: '设备与系统',
                    value: _systemName(),
                    onTap: () => _showDeviceInfo(context),
                  ),
                ],
              ),
              _card(
                isDark: isDark,
                children: [
                  _AboutRow(
                    title: '开源许可',
                    value: 'Apache-2.0',
                    onTap: () => _sheet(
                      context,
                      '开源许可',
                      '本应用基于 Flutter 构建，界面组件来自 flutter_miuix'
                          '（Apache-2.0 / 上游 compose-miuix-ui），'
                          '网页内核为系统 WebView。',
                    ),
                  ),
                  _AboutRow(
                    title: '第三方许可',
                    onTap: () => _sheet(
                      context,
                      '第三方许可',
                      'Flutter · BSD-3-Clause\n'
                          'flutter_miuix · Apache-2.0\n'
                          'webview_flutter · BSD-3-Clause\n'
                          'shared_preferences · BSD-3-Clause\n'
                          'Android System WebView · 随系统分发',
                    ),
                  ),
                  _AboutRow(
                    title: '备案与著作权',
                    value: '软著登字第17704850号',
                    onTap: () => _sheet(
                      context,
                      '备案与著作权',
                      'App 备案：已按国家规定完成备案。\n'
                          '著作权登记：软著登字第17704850号。',
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 22),
              Center(
                child: Text(
                  '星环团队荣誉出品 · NWind 北风架构 Xe',
                  style: TextStyle(
                    fontSize: 12,
                    letterSpacing: 0.3,
                    color: fg.withValues(alpha: 0.34),
                  ),
                ),
              ),
              const SizedBox(height: 6),
              Center(
                child: Text(
                  'v${AboutPage.versionName} (${AboutPage.versionCode})',
                  style: TextStyle(
                    fontSize: 11.5,
                    color: sub.withValues(alpha: 0.5),
                  ),
                ),
              ),
            ],
          ),
          // hero：固定不动，滚动时淡出。
          Positioned(
            top: heroTop,
            left: 0,
            right: 0,
            child: _Hero(
              progress: _progress,
              isDark: isDark,
              title: '星环 · ROAM',
              version: 'v${AboutPage.versionName} (${AboutPage.versionCode})',
            ),
          ),
          _AboutTopBar(progress: _progress, isDark: isDark, title: '关于'),
        ],
      ),
    );
  }

  /// 一张 OS4 玻璃卡片：三层材质 + 大号高光描边 + 低投影。
  Widget _card({required bool isDark, required List<Widget> children}) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
      child: MiuixGlassPanel(
        backdrop: _backdrop,
        shape: const MiuixGlassShape(cornerRadius: 20),
        material: MiuixGlassMaterials.popupViewGlass(isDark),
        stroke: MiuixGlassStrokes.small(isDark),
        shadow: MiuixGlassShadows.low,
        shading: false,
        // 只在拿不到背景快照（首帧 / 低端设备）时才会用到：给一层半透明白，
        // 退化成「磨砂片」而不是一块死黑或死白。
        fill: Colors.white.withValues(alpha: isDark ? 0.12 : 0.72),
        child: Column(
          children: [
            for (var i = 0; i < children.length; i++) ...[
              if (i > 0)
                Container(
                  height: 1,
                  margin: const EdgeInsets.only(left: 18),
                  color: (isDark ? Colors.white : Colors.black)
                      .withValues(alpha: isDark ? 0.07 : 0.055),
                ),
              children[i],
            ],
          ],
        ),
      ),
    );
  }

  /// 鸿蒙（OpenHarmony 版 Flutter）上 `Platform.operatingSystem` 是 `ohos`。
  static bool get _isOhos => Platform.operatingSystem == 'ohos';

  static String _systemName() {
    if (Platform.isAndroid) return 'Android';
    if (_isOhos) return 'HarmonyOS';
    if (Platform.isLinux) return 'Linux';
    if (Platform.isMacOS) return 'macOS';
    if (Platform.isWindows) return 'Windows';
    return Platform.operatingSystem;
  }

  static String _systemVersion() {
    if (Platform.isAndroid) return _androidVersion();
    if (_isOhos) return Platform.operatingSystemVersion;
    return Platform.operatingSystem;
  }

  static String _webEngineName() {
    if (Platform.isAndroid) return 'Android System WebView';
    if (_isOhos) return 'ArkWeb 内核';
    return '系统 WebView';
  }

  static String _androidVersion() {
    final raw = Platform.operatingSystemVersion;
    final match = RegExp(r'Android[^,]*').firstMatch(raw);
    return match?.group(0) ?? 'Android';
  }

  Future<void> _checkUpdate(BuildContext context) {
    return _sheet(
      context,
      '软件更新',
      '当前版本 v${AboutPage.versionName} (${AboutPage.versionCode}) 已是最新版本。',
    );
  }

  Future<void> _showSoftwareInfo(BuildContext context) {
    return _sheet(
      context,
      '软件与版本信息',
      '软件名称：星环 · ROAM AI Explore\n'
          '产品型号：Roam Flutter\n'
          '软件版本：${AboutPage.versionName} (${AboutPage.versionCode})\n'
          '软件版本标识：100.3Beta4 · Flutter 重构版\n'
          '编译日期：2026-11-26\n'
          '软件安全更新级别：2026-11',
    );
  }

  Future<void> _showDeviceInfo(BuildContext context) {
    final media = MediaQuery.of(context);
    final size = media.size;
    final dpr = media.devicePixelRatio;
    return _sheet(
      context,
      '设备与系统',
      '系统版本：${_systemVersion()}\n'
          '语言与地区：${Localizations.localeOf(context)} · 简体中文\n'
          '屏幕分辨率：${(size.width * dpr).round()} × ${(size.height * dpr).round()}\n'
          'WebKit：${_webEngineName()}',
    );
  }

  Future<void> _showEnhancements(BuildContext context) async {
    await showRoamSheet<void>(
      context: context,
      title: '增强特性',
      subtitle: '共 ${AboutPage._enhancements.length} 项',
      children: [
        for (final item in AboutPage._enhancements)
          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: Text(
              item,
              style: TextStyle(
                fontSize: 13,
                height: 1.5,
                color:
                    (Theme.of(context).brightness == Brightness.dark
                            ? RoamColors.textPrimary
                            : RoamColors.dayInk)
                        .withValues(alpha: 0.72),
              ),
            ),
          ),
      ],
    );
  }

  Future<void> _sheet(BuildContext context, String title, String body) async {
    await showRoamSheet<void>(
      context: context,
      title: title,
      children: [
        Text(
          body,
          style: TextStyle(
            fontSize: 13,
            height: 1.6,
            color:
                (Theme.of(context).brightness == Brightness.dark
                        ? RoamColors.textPrimary
                        : RoamColors.dayInk)
                    .withValues(alpha: 0.7),
          ),
        ),
      ],
    );
  }
}

/// 顶栏：透明；滚过 hero 后浮出标题与一层底衬。
class _AboutTopBar extends StatelessWidget {
  const _AboutTopBar({
    required this.progress,
    required this.isDark,
    required this.title,
  });

  final ValueListenable<double> progress;
  final bool isDark;
  final String title;

  @override
  Widget build(BuildContext context) {
    final top = MediaQuery.paddingOf(context).top;
    final fg = isDark ? RoamColors.textPrimary : RoamColors.dayInk;
    final surface = isDark ? Colors.black : RoamColors.daySky;

    return Positioned(
      top: 0,
      left: 0,
      right: 0,
      child: ValueListenableBuilder<double>(
        valueListenable: progress,
        builder: (context, p, _) {
          final barAlpha = ((p - 0.55) / 0.35).clamp(0.0, 1.0);
          final titleAlpha = ((p - 0.62) / 0.3).clamp(0.0, 1.0);
          return Stack(
            children: [
              Positioned.fill(
                child: IgnorePointer(
                  child: ColoredBox(
                    color: surface.withValues(alpha: 0.92 * barAlpha),
                  ),
                ),
              ),
              Padding(
                padding: EdgeInsets.only(top: top),
                child: SizedBox(
                  height: 56,
                  child: Stack(
                    children: [
                      Positioned.fill(
                        child: IgnorePointer(
                          child: Center(
                            child: Opacity(
                              opacity: titleAlpha,
                              child: Text(
                                title,
                                style: TextStyle(
                                  fontSize: 17,
                                  fontWeight: FontWeight.w600,
                                  color: fg,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                      Positioned(
                        left: 6,
                        top: 0,
                        bottom: 0,
                        child: Center(
                          child: GestureDetector(
                            behavior: HitTestBehavior.opaque,
                            onTap: () => Navigator.of(context).maybePop(),
                            child: SizedBox(
                              width: 44,
                              height: 44,
                              child: Center(
                                child: Image.asset(
                                  'assets/images/back_images.png',
                                  width: 28,
                                  height: 28,
                                  color: fg,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

/// hero：88dp 白色圆角图标 + 玻璃质感大标题 + 版本号，滚动时依次淡出。
class _Hero extends StatelessWidget {
  const _Hero({
    required this.progress,
    required this.isDark,
    required this.title,
    required this.version,
  });

  final ValueListenable<double> progress;
  final bool isDark;
  final String title;
  final String version;

  @override
  Widget build(BuildContext context) {
    final sub = isDark ? RoamColors.textSecondary : RoamColors.daySecondary;

    return ValueListenableBuilder<double>(
      valueListenable: progress,
      builder: (context, p, _) {
        double fade(double start) => 1 - ((p - start) / 0.15).clamp(0.0, 1.0);
        final iconFade = fade(0.45);
        final titleFade = fade(0.25);
        final versionFade = fade(0.06);
        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Opacity(
              opacity: iconFade,
              child: Transform.scale(
                scale: 1 - (1 - iconFade) * 0.06,
                child: Container(
                  width: 88,
                  height: 88,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(24),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(
                          alpha: isDark ? 0.42 : 0.12,
                        ),
                        blurRadius: 28,
                        offset: const Offset(0, 10),
                      ),
                    ],
                  ),
                  // 图标自带白色 squircle 底与圆角，不要再套一层白框。
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(24),
                    child: Image.asset(
                      'assets/images/ic_launcher_explorelogo.png',
                      width: 88,
                      height: 88,
                      fit: BoxFit.cover,
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 12),
            Opacity(
              opacity: titleFade,
              child: Transform.scale(
                scale: 1 - (1 - titleFade) * 0.05,
                child: ShaderMask(
                  blendMode: BlendMode.srcIn,
                  shaderCallback: (rect) => LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: isDark
                        ? const [
                            Color(0xFFF4EEFF),
                            Color(0xFFD6C6FF),
                            Color(0xFF9FC0FF),
                          ]
                        : const [
                            Color(0xFF2B2350),
                            Color(0xFF4B3A8C),
                            Color(0xFF2F5FA8),
                          ],
                  ).createShader(rect),
                  child: Text(
                    title,
                    style: const TextStyle(
                      fontSize: 34,
                      height: 1.15,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.2,
                    ),
                  ),
                ),
              ),
            ),
            SizedBox(
              height: 20,
              child: Opacity(
                opacity: versionFade,
                child: Transform.scale(
                  scale: 1 - (1 - versionFade) * 0.05,
                  child: Text(
                    version,
                    style: TextStyle(
                      fontSize: 14,
                      color: sub.withValues(alpha: 0.72),
                    ),
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}

/// 玻璃卡片里的一行：标题 + 右侧取值 + 箭头。
class _AboutRow extends StatelessWidget {
  const _AboutRow({required this.title, this.value, required this.onTap});

  final String title;
  final String? value;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final fg = isDark ? RoamColors.textPrimary : RoamColors.dayInk;
    final sub = isDark ? RoamColors.textSecondary : RoamColors.daySecondary;

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: SizedBox(
        height: 56,
        child: Padding(
          padding: const EdgeInsets.only(left: 18, right: 12),
          child: Row(
            children: [
              Text(
                title,
                style: TextStyle(
                  fontSize: 15.5,
                  fontWeight: FontWeight.w500,
                  color: fg,
                ),
              ),
              const Spacer(),
              if (value != null)
                ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 170),
                  child: Text(
                    value!,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 13.5,
                      color: sub.withValues(alpha: 0.62),
                    ),
                  ),
                ),
              const SizedBox(width: 8),
              MiuixIcon(
                vector: MiuixIcons.basic.arrowRight,
                size: 14,
                tint: fg.withValues(alpha: 0.3),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// 彩色光晕背景：深色是紫罗兰 + 靛蓝 + 青，浅色是薰衣草 + 天蓝。
///
/// 纯静态绘制（渐变 + 径向光斑），外面套了 RepaintBoundary 与背景捕获，
/// 滚动时不重绘，玻璃卡片采样它做折射。
class _AuraPainter extends CustomPainter {
  const _AuraPainter({required this.isDark});

  final bool isDark;

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    canvas.drawRect(
      rect,
      Paint()
        ..shader = ui.Gradient.linear(
          rect.topCenter,
          rect.bottomCenter,
          isDark
              ? const [
                  Color(0xFF0B0818),
                  Color(0xFF120C26),
                  Color(0xFF08060F),
                ]
              : const [
                  Color(0xFFF8F5FF),
                  Color(0xFFEFF3FF),
                  Color(0xFFFBF8FF),
                ],
          const [0, 0.55, 1],
        ),
    );

    final w = size.width;
    final h = size.height;
    void blob(Offset center, double radius, Color color) {
      canvas.drawCircle(
        center,
        radius,
        Paint()
          ..shader = ui.Gradient.radial(
            center,
            radius,
            [color, color.withValues(alpha: 0)],
          ),
      );
    }

    if (isDark) {
      blob(
        Offset(w * 0.16, h * 0.14),
        w * 0.95,
        const Color(0xFF6B3FE0).withValues(alpha: 0.55),
      );
      blob(
        Offset(w * 0.92, h * 0.24),
        w * 0.8,
        const Color(0xFF1E62FF).withValues(alpha: 0.40),
      );
      blob(
        Offset(w * 0.72, h * 0.60),
        w * 0.9,
        const Color(0xFF7B2BD6).withValues(alpha: 0.30),
      );
      blob(
        Offset(w * 0.08, h * 0.78),
        w * 0.85,
        const Color(0xFF0E7C86).withValues(alpha: 0.26),
      );
      blob(
        Offset(w * 0.5, h * 0.98),
        w * 0.9,
        const Color(0xFF2B3AA8).withValues(alpha: 0.32),
      );
    } else {
      blob(
        Offset(w * 0.14, h * 0.12),
        w * 0.95,
        const Color(0xFFC9B6FF).withValues(alpha: 0.62),
      );
      blob(
        Offset(w * 0.95, h * 0.22),
        w * 0.8,
        const Color(0xFFA9C8FF).withValues(alpha: 0.55),
      );
      blob(
        Offset(w * 0.78, h * 0.58),
        w * 0.9,
        const Color(0xFFD9B8FF).withValues(alpha: 0.40),
      );
      blob(
        Offset(w * 0.06, h * 0.76),
        w * 0.85,
        const Color(0xFFB2EDE4).withValues(alpha: 0.38),
      );
      blob(
        Offset(w * 0.5, h * 0.98),
        w * 0.9,
        const Color(0xFFBFD4FF).withValues(alpha: 0.45),
      );
    }

    // 顶部压暗 / 提亮，让状态栏与顶栏图标有对比。
    canvas.drawRect(
      Rect.fromLTWH(0, 0, w, h * 0.18),
      Paint()
        ..shader = ui.Gradient.linear(
          Offset.zero,
          Offset(0, h * 0.18),
          isDark
              ? [Colors.black.withValues(alpha: 0.34), Colors.transparent]
              : [Colors.white.withValues(alpha: 0.30), Colors.transparent],
        ),
    );

    // 轻微颗粒，避免大面积渐变出现色带。
    final grain = Paint()
      ..color = (isDark ? Colors.white : Colors.black).withValues(alpha: 0.02);
    final random = math.Random(20261126);
    for (var i = 0; i < 320; i++) {
      canvas.drawCircle(
        Offset(random.nextDouble() * w, random.nextDouble() * h),
        0.9,
        grain,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _AuraPainter old) => old.isDark != isDark;
}
