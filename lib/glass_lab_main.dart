// ignore_for_file: deprecated_member_use

import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import 'ui/glass/os4_glass_token.dart';
import 'ui/glass/roam_glass.dart';

/// 独立预览入口：
///   flutter run -d linux -t lib/glass_lab_main.dart
void main() => runApp(const GlassLabApp());

class GlassLabApp extends StatelessWidget {
  const GlassLabApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        brightness: Brightness.dark,
        scaffoldBackgroundColor: const Color(0xFF0C0A10),
        splashFactory: NoSplash.splashFactory,
      ),
      home: const GlassLabPage(),
    );
  }
}

class GlassLabPage extends StatefulWidget {
  const GlassLabPage({super.key});

  @override
  State<GlassLabPage> createState() => _GlassLabPageState();
}

class _GlassLabPageState extends State<GlassLabPage> {
  int _bg = 3;
  int _index = 1; // commonSmallNormal（系统顶栏按钮实际使用的预设）

  static final List<Os4GlassToken> _picks = [
    Os4GlassToken.commonSmallThin,
    Os4GlassToken.commonSmallNormal,
    Os4GlassToken.commonSmallRegular,
    Os4GlassToken.commonMediumThinLow,
    Os4GlassToken.commonLargeRegular,
    Os4GlassToken.bionicMediumNormal,
    Os4GlassToken.tintPurple,
    Os4GlassToken.tintBlueNormal,
  ];

  Os4GlassToken get _token => _picks[_index];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: RoamGlassScene(
        revision: Object.hash(_bg, _index),
        // blurSmall/blurBig 是 3x 屏的物理像素（commonSmallNormal = 150 / 500）。
        // 原生把「半径」送进高斯，σ = r*0.57735 + 0.5，再除以 3 折算成逻辑像素。
        blurSigma: ((_token.blurSmall * 0.57735 + 0.5) / 3.0).clamp(4.0, 60.0),
        blurSigmaBig: ((_token.blurBig * 0.57735 + 0.5) / 3.0).clamp(
          20.0,
          180.0,
        ),
        background: _Wallpaper(style: _bg),
        child: Stack(
          children: [
            Positioned.fill(
              child: SafeArea(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 40),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      RoamGlass(
                        token: Os4GlassToken.commonSmallThin,
                        radius: 18,
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 14,
                            vertical: 10,
                          ),
                          child: _Header(
                            bg: _bg,
                            onBg: () => setState(() => _bg = (_bg + 1) % 4),
                          ),
                        ),
                      ),
                      const SizedBox(height: 18),
                      _BigPanel(token: _token),
                      const SizedBox(height: 18),
                      _RoundButtons(),
                      const SizedBox(height: 18),
                      _Rows(token: _token),
                      const SizedBox(height: 22),
                      _TokenPicker(
                        items: _picks,
                        index: _index,
                        onPick: (i) => setState(() => _index = i),
                      ),
                      const SizedBox(height: 10),
                      _Spec(token: _token),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ───────────────────────────────────────────────────────────── 头部

/// 玻璃是浅色的，白字需要一点描影才在浅底上站得住
const _ink = [
  Shadow(color: Color(0x66000000), blurRadius: 6, offset: Offset(0, 1)),
];

class _Header extends StatelessWidget {
  const _Header({required this.bg, required this.onBg});

  final int bg;
  final VoidCallback onBg;

  @override
  Widget build(BuildContext context) {
    const names = ['渐变壁纸', '彩色条纹', '高对比', '柔和壁纸'];
    return Row(
      children: [
        const Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '柔光玻璃 · 自绘管线',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w600,
                  color: Colors.white,
                  letterSpacing: 0.2,
                  shadows: _ink,
                ),
              ),
              SizedBox(height: 3),
              Text(
                'shaders/roam_glass.frag · 34 项原生参数',
                style: TextStyle(
                  fontSize: 11,
                  color: Colors.white70,
                  shadows: _ink,
                ),
              ),
            ],
          ),
        ),
        _Pill(label: names[bg], icon: Icons.wallpaper_outlined, onTap: onBg),
      ],
    );
  }
}

class _Pill extends StatelessWidget {
  const _Pill({required this.label, required this.onTap, this.icon});

  final String label;
  final IconData? icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white.withValues(alpha: 0.14),
      shape: const StadiumBorder(),
      child: InkWell(
        customBorder: const StadiumBorder(),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (icon != null) ...[
                Icon(icon, size: 14, color: Colors.white70),
                const SizedBox(width: 6),
              ],
              Text(
                label,
                style: const TextStyle(fontSize: 12, color: Colors.white),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ───────────────────────────────────────────────────────────── 玻璃块

class _BigPanel extends StatelessWidget {
  const _BigPanel({required this.token});

  final Os4GlassToken token;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 208,
      child: RoamGlass(
        token: token,
        radius: 28,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 18, 20, 18),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Text(
                    '15:44',
                    style: TextStyle(
                      fontSize: 46,
                      height: 1.0,
                      fontWeight: FontWeight.w300,
                      color: Colors.white,
                      letterSpacing: -1.5,
                    ),
                  ),
                  const Spacer(),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 9,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(9),
                      border: Border.all(
                        color: Colors.white.withValues(alpha: 0.35),
                      ),
                    ),
                    child: const Text(
                      '26°',
                      style: TextStyle(fontSize: 11, color: Colors.white),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Text(
                '11月23日 周日',
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.white.withValues(alpha: 0.72),
                ),
              ),
              const Spacer(),
              Row(
                children: [
                  const Icon(
                    Icons.wb_sunny_outlined,
                    size: 15,
                    color: Colors.white70,
                  ),
                  const SizedBox(width: 6),
                  const Text(
                    '晴 · 微风',
                    style: TextStyle(fontSize: 12, color: Colors.white70),
                  ),
                  const Spacer(),
                  Text(
                    token.name.replaceFirst('Glass_', ''),
                    style: TextStyle(
                      fontSize: 9,
                      letterSpacing: 0.4,
                      color: Colors.white.withValues(alpha: 0.5),
                    ),
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

class _RoundButtons extends StatelessWidget {
  static const _icons = [
    Icons.settings_outlined,
    Icons.search,
    Icons.more_horiz,
    Icons.share_outlined,
    Icons.star_border,
  ];

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        for (final icon in _icons)
          SizedBox(
            width: 56,
            height: 56,
            child: RoamGlass(
              token: Os4GlassToken.commonSmallThin,
              radius: 28,
              child: Icon(icon, size: 21, color: Colors.white),
            ),
          ),
      ],
    );
  }
}

class _Rows extends StatelessWidget {
  const _Rows({required this.token});

  final Os4GlassToken token;

  @override
  Widget build(BuildContext context) {
    const items = [
      (Icons.palette_outlined, '外观与设计', '深色模式 · 柔光玻璃'),
      (Icons.widgets_outlined, '小组件管理', '12 个已启用'),
    ];
    return Column(
      children: [
        for (final it in items) ...[
          SizedBox(
            height: 66,
            child: RoamGlass(
              token: token,
              radius: 18,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Row(
                  children: [
                    Icon(it.$1, size: 20, color: Colors.white),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            it.$2,
                            style: const TextStyle(
                              fontSize: 14,
                              color: Colors.white,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            it.$3,
                            style: TextStyle(
                              fontSize: 11,
                              color: Colors.white.withValues(alpha: 0.6),
                            ),
                          ),
                        ],
                      ),
                    ),
                    Icon(
                      Icons.chevron_right,
                      size: 18,
                      color: Colors.white.withValues(alpha: 0.45),
                    ),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(height: 10),
        ],
      ],
    );
  }
}

class _TokenPicker extends StatelessWidget {
  const _TokenPicker({
    required this.items,
    required this.index,
    required this.onPick,
  });

  final List<Os4GlassToken> items;
  final int index;
  final ValueChanged<int> onPick;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        for (var i = 0; i < items.length; i++)
          GestureDetector(
            onTap: () => onPick(i),
            child: Container(
              height: 32,
              padding: const EdgeInsets.symmetric(horizontal: 12),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(16),
                color: i == index
                    ? Colors.white.withValues(alpha: 0.92)
                    : Colors.white.withValues(alpha: 0.10),
              ),
              // 不带 widthFactor 的 Center 会在松约束下撑满，chip 会变成整行
              child: Center(
                widthFactor: 1,
                child: Text(
                  items[i].name.replaceFirst('Glass_', '').replaceAll('_', ' '),
                  style: TextStyle(
                    fontSize: 10.5,
                    color: i == index
                        ? const Color(0xFF16121C)
                        : Colors.white70,
                    fontWeight: i == index ? FontWeight.w600 : FontWeight.w400,
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }
}

class _Spec extends StatelessWidget {
  const _Spec({required this.token});

  final Os4GlassToken token;

  @override
  Widget build(BuildContext context) {
    String n(double v) => v == v.roundToDouble() ? v.toStringAsFixed(0) : '$v';
    final rows = [
      ('模糊 small / big', '${n(token.blurSmall)} / ${n(token.blurBig)}'),
      ('边缘 宽 / 幂', '${n(token.edgeWidth)} / ${n(token.edgePow)}'),
      ('厚度 / 折射率', '${n(token.thickness)} / ${n(token.ior)}'),
      ('亮度 / 压暗', '${n(token.brightness)} / ${n(token.darker)}'),
      ('光强 / 对向', '${n(token.intensity)} / ${n(token.oppositeIntensity)}'),
    ];
    return RoamGlass(
      token: Os4GlassToken.commonSmallThin,
      radius: 14,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        child: Column(
          children: [
            for (final r in rows)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 2.5),
                child: Row(
                  children: [
                    Text(
                      r.$1,
                      style: TextStyle(
                        fontSize: 10.5,
                        color: Colors.white.withValues(alpha: 0.62),
                        shadows: _ink,
                      ),
                    ),
                    const Spacer(),
                    Text(
                      r.$2,
                      style: const TextStyle(
                        fontSize: 10.5,
                        color: Colors.white,
                        shadows: _ink,
                        fontFeatures: [ui.FontFeature.tabularFigures()],
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}

// ───────────────────────────────────────────────────────────── 背景

class _Wallpaper extends StatelessWidget {
  const _Wallpaper({required this.style});

  final int style;

  @override
  Widget build(BuildContext context) {
    return CustomPaint(painter: _WallpaperPainter(style), size: Size.infinite);
  }
}

class _WallpaperPainter extends CustomPainter {
  _WallpaperPainter(this.style);

  final int style;

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    switch (style) {
      case 1:
        _stripes(canvas, size, rect);
      case 2:
        _checker(canvas, rect);
      case 3:
        _soft(canvas, size, rect);
      default:
        _gradient(canvas, size, rect);
    }
  }

  void _gradient(Canvas canvas, Size size, Rect rect) {
    canvas.drawRect(
      rect,
      Paint()
        ..shader = ui.Gradient.linear(
          Offset.zero,
          Offset(size.width, size.height),
          const [Color(0xFF2B1B4D), Color(0xFF4433A8), Color(0xFF1E5C8A)],
          const [0.0, 0.55, 1.0],
        ),
    );
    canvas.drawCircle(
      Offset(size.width * 0.82, size.height * 0.18),
      size.width * 0.42,
      Paint()
        ..shader = ui.Gradient.radial(
          Offset(size.width * 0.82, size.height * 0.18),
          size.width * 0.42,
          const [Color(0xFFF0803C), Color(0x00F0803C)],
        ),
    );
    canvas.drawCircle(
      Offset(size.width * 0.12, size.height * 0.72),
      size.width * 0.36,
      Paint()
        ..shader = ui.Gradient.radial(
          Offset(size.width * 0.12, size.height * 0.72),
          size.width * 0.36,
          const [Color(0xFF33D6C0), Color(0x0033D6C0)],
        ),
    );
    // 细网格：能看出折射把直线掰弯
    final grid = Paint()
      ..color = Colors.white.withValues(alpha: 0.10)
      ..strokeWidth = 1;
    for (double x = 0; x < size.width; x += 34) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), grid);
    }
    for (double y = 0; y < size.height; y += 34) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), grid);
    }
  }

  /// 接近真实系统壁纸：低饱和暖灰底 + 两块柔和色晕。
  /// 柔光玻璃在原生环境里就是压在这种画面上，前面的高饱和渐变属于压力测试。
  void _soft(Canvas canvas, Size size, Rect rect) {
    canvas.drawRect(
      rect,
      Paint()
        ..shader = ui.Gradient.linear(
          Offset.zero,
          Offset(0, size.height),
          const [Color(0xFFB9B3AC), Color(0xFF9E98A6), Color(0xFF817B8E)],
          const [0.0, 0.5, 1.0],
        ),
    );
    canvas.drawCircle(
      Offset(size.width * 0.78, size.height * 0.22),
      size.width * 0.5,
      Paint()
        ..shader = ui.Gradient.radial(
          Offset(size.width * 0.78, size.height * 0.22),
          size.width * 0.5,
          const [Color(0x55D89A66), Color(0x00D89A66)],
        ),
    );
    canvas.drawCircle(
      Offset(size.width * 0.16, size.height * 0.66),
      size.width * 0.44,
      Paint()
        ..shader = ui.Gradient.radial(
          Offset(size.width * 0.16, size.height * 0.66),
          size.width * 0.44,
          const [Color(0x406A9EAE), Color(0x006A9EAE)],
        ),
    );
  }

  void _stripes(Canvas canvas, Size size, Rect rect) {
    canvas.drawRect(rect, Paint()..color = const Color(0xFF101018));
    const palette = [
      Color(0xFFE8553F),
      Color(0xFFF2A03C),
      Color(0xFF3FC27A),
      Color(0xFF3A7BD5),
      Color(0xFF8E5BE8),
    ];
    final w = size.width / 9;
    for (var i = -2; i < 12; i++) {
      final p = Path()
        ..moveTo(i * w, 0)
        ..lineTo(i * w + w * 0.62, 0)
        ..lineTo(i * w + w * 0.62 + size.height * 0.32, size.height)
        ..lineTo(i * w + size.height * 0.32, size.height)
        ..close();
      canvas.drawPath(p, Paint()..color = palette[i.abs() % palette.length]);
    }
  }

  void _checker(Canvas canvas, Rect rect) {
    canvas.drawRect(rect, Paint()..color = const Color(0xFFF2F0EB));
    final dark = Paint()..color = const Color(0xFF14121A);
    const s = 30.0;
    for (double y = 0; y < rect.height; y += s) {
      for (double x = 0; x < rect.width; x += s) {
        if (((x / s).floor() + (y / s).floor()) % 2 == 0) continue;
        canvas.drawRect(Rect.fromLTWH(x, y, s, s), dark);
      }
    }
    canvas.save();
    canvas.translate(rect.width / 2, rect.height * 0.62);
    canvas.rotate(-math.pi / 12);
    final tp = TextPainter(
      text: const TextSpan(
        text: 'GLASS',
        style: TextStyle(
          fontSize: 76,
          fontWeight: FontWeight.w900,
          letterSpacing: 4,
          color: Color(0xFFE8553F),
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    tp.paint(canvas, Offset(-tp.width / 2, -tp.height / 2));
    canvas.restore();
  }

  @override
  bool shouldRepaint(_WallpaperPainter old) => old.style != style;
}
