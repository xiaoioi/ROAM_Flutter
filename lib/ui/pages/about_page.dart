// ignore_for_file: deprecated_member_use

import 'dart:async';
import 'dart:io';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart' show ValueListenable;
import 'package:flutter/material.dart';
import 'package:flutter_miuix/miuix.dart';

import '../../theme/roam_theme.dart';
import '../widgets/glass_controls.dart';
import '../widgets/hyperos_top_bar.dart';
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
  static const versionCode = 139;

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
          // 背景：OS3 前景模糊流动色光，卡片玻璃采样它。
          Positioned.fill(
            child: MiuixLayerBackdropCapture(
              backdrop: _backdrop,
              pixelRatio: 1,
              child: _FlowBackground(isDark: isDark),
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
          _AboutTopBar(
            progress: _progress,
            isDark: isDark,
            title: '关于',
            backdrop: _backdrop,
          ),
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
    required this.backdrop,
  });

  final ValueListenable<double> progress;
  final bool isDark;
  final String title;

  /// 背景采样源：返回圆钮是玻璃，采样同一份背景快照。
  final MiuixLayerBackdrop backdrop;

  @override
  Widget build(BuildContext context) {
    final top = MediaQuery.paddingOf(context).top;
    final fg = isDark ? RoamColors.textPrimary : RoamColors.dayInk;

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
              // 滚动到一定程度后才出现的顶部渐隐：和二级页用同一条纯模糊带，
              // 不再铺 92% 的实色底（那在浅色下就是一层灰白遮罩）。
              Positioned.fill(
                child: IgnorePointer(
                  child: Opacity(
                    opacity: barAlpha,
                    child: const RoamProgressiveBlur(sigma: 32),
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
                        left: 24,
                        top: 0,
                        bottom: 0,
                        child: Center(
                          // 顶栏圆钮统一用 miuix 的 GlassIconButton。
                          child: HyperosCircleButton(
                            size: 40,
                            miuixLayer: backdrop,
                            onTap: () => Navigator.of(context).maybePop(),
                            child: Image.asset(
                              'assets/images/back_images.png',
                              width: 26,
                              height: 26,
                              color: fg,
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

/// OS3 风格「前景模糊」流动背景。
///
/// 对齐 miuix 示例的 `BgEffectPainter(isOs3 = true)`：底色 + 3~4 团色光，
/// 色光随时间在屏幕里缓慢漂移（`colorStage` 弹簧换色 + 点位动画），
/// 每一团都用 [MaskFilter.blur] 做成大面积柔焦——也就是 OS3 那层
/// 「前景模糊」：颜色是糊开的、没有边界，只有亮暗在流动。
///
/// 帧率刻意压到 10fps：这层在 `MiuixLayerBackdropCapture` 里，卡片玻璃
/// 采样它，60fps 会让 7 块玻璃每秒重画 60 次。色光是分钟级的慢动作，
/// 10fps 肉眼完全看不出台阶，却省掉 5/6 的玻璃重采样。
class _FlowBackground extends StatefulWidget {
  const _FlowBackground({required this.isDark});

  final bool isDark;

  @override
  State<_FlowBackground> createState() => _FlowBackgroundState();
}

class _FlowBackgroundState extends State<_FlowBackground> {
  /// 0~1 循环的相位，painter 通过 `repaint` 直接监听，不重建 widget。
  final ValueNotifier<double> _phase = ValueNotifier(0);
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(milliseconds: 100), (_) {
      _phase.value = (_phase.value + 1 / 900) % 1; // 90s 一圈
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    _phase.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return RepaintBoundary(
      child: CustomPaint(
        painter: _FlowPainter(isDark: widget.isDark, phase: _phase),
        size: Size.infinite,
      ),
    );
  }
}

class _FlowPainter extends CustomPainter {
  _FlowPainter({required this.isDark, required this.phase})
    : super(repaint: phase);

  final bool isDark;
  final ValueNotifier<double> phase;

  /// OS3 预设：深色是深海蓝底 + 蓝/靛/紫三团光；浅色是冷白底 + 天蓝/薰衣草。
  static const _darkBase = [
    Color(0xFF05070F),
    Color(0xFF0A1024),
    Color(0xFF04060C),
  ];
  static const _lightBase = [
    Color(0xFFF8FAFF),
    Color(0xFFEEF3FF),
    Color(0xFFFBF9FF),
  ];

  /// (色光, 半径系数, 基准 x, 基准 y)
  static const _darkBlobs = <(Color, double, double, double)>[
    (Color(0xFF2B5BFF), 0.62, 0.52, 0.16),
    (Color(0xFF6A3BE0), 0.46, 0.90, 0.26),
    (Color(0xFF1B3FA8), 0.38, 0.70, 0.62),
    (Color(0xFF8A5CFF), 0.30, 0.10, 0.82),
  ];

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    final w = size.width;
    final h = size.height;
    final t = phase.value * math.pi * 2;

    canvas.drawRect(
      rect,
      Paint()
        ..shader = ui.Gradient.linear(
          rect.topCenter,
          rect.bottomCenter,
          isDark ? _darkBase : _lightBase,
          const [0, 0.55, 1],
        ),
    );

    // 前景模糊：每团色光用 MaskFilter 做高斯柔焦，边界完全化开。
    void blob(double cx, double cy, double radius, Color color, double alpha) {
      canvas.drawCircle(
        Offset(cx, cy),
        radius,
        Paint()
          ..color = color.withValues(alpha: alpha)
          ..maskFilter = MaskFilter.blur(BlurStyle.normal, radius * 0.55),
      );
    }

    if (isDark) {
      for (var i = 0; i < _darkBlobs.length; i++) {
        final (color, radius, bx, by) = _darkBlobs[i];
        final drift = t + i * 1.7;
        blob(
          w * (bx + 0.05 * math.sin(drift)),
          h * (by + 0.035 * math.cos(drift * 0.8)),
          w * radius,
          color,
          0.30 + 0.10 * math.sin(drift * 1.3),
        );
      }
    } else {
      blob(w * (0.16 + 0.05 * math.sin(t)), h * (0.14 + 0.03 * math.cos(t)),
          w * 0.95, const Color(0xFFB7D2FF), 0.62);
      blob(w * (0.92 + 0.04 * math.cos(t + 1.2)),
          h * (0.24 + 0.04 * math.sin(t + 1.2)), w * 0.8,
          const Color(0xFFCBD9FF), 0.55);
      blob(w * (0.74 + 0.05 * math.sin(t + 2.4)),
          h * (0.58 + 0.04 * math.cos(t + 2.4)), w * 0.9,
          const Color(0xFFD9CCFF), 0.42);
      blob(w * (0.10 + 0.04 * math.cos(t + 3.6)),
          h * (0.80 + 0.03 * math.sin(t + 3.6)), w * 0.85,
          const Color(0xFFBFD4FF), 0.45);
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
  }

  @override
  bool shouldRepaint(covariant _FlowPainter old) =>
      old.isDark != isDark || old.phase != phase;
}
