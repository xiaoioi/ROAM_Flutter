import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_miuix/miuix.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:roam_flutter/ui/widgets/miuix_progressive_blur.dart';

// 渐变模糊的视觉验收：彩色文字底 + 顶部 220dp 的渐进模糊带，
// 用来人眼确认「越靠上越糊、往下连续变清晰」，不是一张糊图淡出。

const _font = 'PreviewCJK';

Future<void> _loadFont() async {
  final bytes = File('/usr/share/fonts/opentype/noto/NotoSansCJK-Regular.ttc').readAsBytesSync();
  final loader = FontLoader(_font)
    ..addFont(Future.value(ByteData.view(Uint8List.fromList(bytes).buffer)));
  await loader.load();
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(_loadFont);

  testWidgets('progressive blur shot', (tester) async {
    tester.view.physicalSize = const Size(900, 1200);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);

    final backdrop = MiuixLayerBackdrop();
    addTearDown(backdrop.dispose);

    await tester.pumpWidget(MaterialApp(
      debugShowCheckedModeBanner: false,
      home: Scaffold(
        body: Stack(
          children: [
            Positioned.fill(
              child: MiuixLayerBackdropCapture(
                backdrop: backdrop,
                pixelRatio: 1,
                child: Container(
                  decoration: const BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [Color(0xFF2D6BFF), Color(0xFF00C2A8), Color(0xFFFF7A3D)],
                    ),
                  ),
                  child: ListView(
                    physics: const NeverScrollableScrollPhysics(),
                    padding: EdgeInsets.zero,
                    children: [
                      for (var i = 0; i < 40; i++)
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 20),
                          child: Text(
                            '第 $i 行 文字 · Progressive Blur 12345',
                            style: const TextStyle(fontFamily: _font, fontSize: 22, color: Colors.white, fontWeight: FontWeight.w600),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            ),
            Positioned(
              top: 0, left: 0, right: 0, height: 220,
              child: IgnorePointer(
                child: MiuixProgressiveTextureBlur(
                  backdrop: backdrop,
                  blurRadius: 80,
                  gradient: ProgressiveBlur.top.copyWith(endFraction: 0.8, curve: 0.75),
                  levels: 4,
                ),
              ),
            ),
          ],
        ),
      ),
    ));
    await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 250)));
    await tester.pump(const Duration(milliseconds: 100));
    await tester.pump(const Duration(milliseconds: 400));
    await expectLater(find.byType(MaterialApp), matchesGoldenFile('shots/prog-top.png'));
  });
}
