// 渐进模糊带视觉检查：单独渲染一条 220dp 的带子，导出 PNG 人工对照。
import 'dart:io';

import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_miuix/miuix.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:roam_flutter/ui/widgets/glass_controls.dart';
import 'package:roam_flutter/ui/widgets/hyperos_top_bar.dart';
import 'package:roam_flutter/ui/widgets/roam_popup_glass.dart';

const _fontFamily = 'ProgCJK';

Future<void> _loadFont() async {
  final bytes = File(
    '/usr/share/fonts/opentype/noto/NotoSansCJK-Regular.ttc',
  ).readAsBytesSync();
  final loader = FontLoader(_fontFamily)
    ..addFont(Future.value(ByteData.view(Uint8List.fromList(bytes).buffer)));
  await loader.load();
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(_loadFont);

  testWidgets('渐进模糊带', (tester) async {
    tester.view.physicalSize = const Size(1080, 1600);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);

    final bd = MiuixLayerBackdrop();
    Widget row(int i) => Container(
      height: 96,
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.symmetric(horizontal: 24),
      alignment: Alignment.centerLeft,
      decoration: BoxDecoration(
        color: const Color(0xFF1B1D22),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        '示例文件 $i.pdf',
        style: const TextStyle(
          fontFamily: _fontFamily,
          fontSize: 46,
          color: Color(0xFFF2F4F8),
        ),
      ),
    );

    await tester.pumpWidget(
      MaterialApp(
        debugShowCheckedModeBanner: false,
        home: Scaffold(
          backgroundColor: const Color(0xFF0B0C0F),
          body: Stack(
            children: [
              Positioned.fill(
                child: MiuixLayerBackdropCapture(
                  backdrop: bd,
                  pixelRatio: 1,
                  child: ListView(
                    padding: const EdgeInsets.fromLTRB(24, 0, 24, 0),
                    physics: const NeverScrollableScrollPhysics(),
                    children: [for (var i = 0; i < 6; i++) row(i)],
                  ),
                ),
              ),
              Positioned(
                top: 0,
                left: 0,
                right: 0,
                height: 420,
                child: IgnorePointer(
                  child: RoamProgressiveBlur(
                    backdrop: bd,
                    blurRadius: 110,
                    startFraction: 0.58,
                    endFraction: 1,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );

    // capture 走 postFrame，需要多泵几帧让快照生效。
    for (var i = 0; i < 4; i++) {
      await tester.pump(const Duration(milliseconds: 40));
    }
    await tester.runAsync(() => Future<void>.delayed(
          const Duration(milliseconds: 120),
        ));
    for (var i = 0; i < 3; i++) {
      await tester.pump(const Duration(milliseconds: 40));
    }

    await expectLater(
      find.byType(MaterialApp),
      matchesGoldenFile('shots/prog-band.png'),
    );
  });

  testWidgets('顶栏渐隐带', (tester) async {
    tester.view.physicalSize = const Size(1080, 1600);
    tester.view.devicePixelRatio = 3;
    tester.view.padding = const FakeViewPadding(top: 90);
    addTearDown(tester.view.reset);

    final bd = MiuixLayerBackdrop();
    Widget row(int i) => Container(
      height: 96,
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.symmetric(horizontal: 24),
      alignment: Alignment.centerLeft,
      decoration: BoxDecoration(
        color: const Color(0xFF1B1D22),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        '示例文件 $i.pdf',
        style: const TextStyle(
          fontFamily: _fontFamily,
          fontSize: 46,
          color: Color(0xFFF2F4F8),
        ),
      ),
    );

    await tester.pumpWidget(
      MaterialApp(
        debugShowCheckedModeBanner: false,
        home: MiuixTheme(
          data: MiuixThemeData.of(Brightness.dark),
          child: Scaffold(
            backgroundColor: const Color(0xFF0B0C0F),
            body: Stack(
              children: [
                Positioned.fill(
                  child: MiuixLayerBackdropCapture(
                    backdrop: bd,
                    pixelRatio: 1,
                    child: Padding(
                      padding: const EdgeInsets.only(top: 30),
                      child: ListView(
                        padding: const EdgeInsets.only(left: 24, right: 24),
                        physics: const NeverScrollableScrollPhysics(),
                        children: [for (var i = 0; i < 6; i++) row(i)],
                      ),
                    ),
                  ),
                ),
                Positioned(
                  top: 0,
                  left: 0,
                  right: 0,
                  child: HyperosTopBar(
                    title: '下载管理',
                    miuixLayer: bd,
                    statusBarHeight: 30,
                    onBack: () {},
                    scrolled: true,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );

    for (var i = 0; i < 4; i++) {
      await tester.pump(const Duration(milliseconds: 40));
    }
    await tester.runAsync(() => Future<void>.delayed(
          const Duration(milliseconds: 120),
        ));
    for (var i = 0; i < 5; i++) {
      await tester.pump(const Duration(milliseconds: 80));
    }

    await expectLater(
      find.byType(MaterialApp),
      matchesGoldenFile('shots/prog-topbar.png'),
    );
  });

  testWidgets('弹层玻璃表面（有真实 backdrop）', (tester) async {
    tester.view.physicalSize = const Size(1080, 1500);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);

    // 造一张彩色条纹 + 文字的「页面快照」，确保 panel 一定能采到内容。
    const w = 360;
    const h = 500;
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);
    canvas.drawRect(
      const Rect.fromLTWH(0, 0, 360, 500),
      Paint()..color = const Color(0xFF0B2E22),
    );
    for (var i = 0; i < 8; i++) {
      canvas.drawRect(
        Rect.fromLTWH(0, i * 64.0, w.toDouble(), 40),
        Paint()..color = const Color(0xFF1E5C44).withValues(alpha: 0.9),
      );
      final para = (ui.ParagraphBuilder(ui.ParagraphStyle(fontSize: 28))
            ..pushStyle(ui.TextStyle(color: const Color(0xFFEFF6F2)))
            ..addText('示例内容 $i'))
          .build()
        ..layout(const ui.ParagraphConstraints(width: 320));
      canvas.drawParagraph(para, Offset(20, i * 64.0 + 4));
    }
    final image = await recorder.endRecording().toImage(w, h);
    final bd = MiuixLayerBackdrop()
      ..updateSnapshot(image, Offset.zero, 1);

    await tester.pumpWidget(
      MaterialApp(
        debugShowCheckedModeBanner: false,
        home: MiuixTheme(
          data: MiuixThemeData.of(Brightness.dark),
          child: Scaffold(
            body: Stack(
              children: [
                Positioned.fill(child: RawImage(image: image, fit: BoxFit.cover)),
                Positioned(
                  left: 0,
                  right: 0,
                  bottom: 0,
                  height: 260,
                  child: RoamPopupGlass(
                    backdrop: bd,
                    child: const SizedBox.expand(),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 60));

    await expectLater(
      find.byType(MaterialApp),
      matchesGoldenFile('shots/prog-popup.png'),
    );
  });
}
