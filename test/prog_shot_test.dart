import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_miuix/miuix.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:roam_flutter/ui/widgets/glass_controls.dart';

const _font = 'PreviewCJK';

Future<void> _loadFont() async {
  final bytes = File('/usr/share/fonts/opentype/noto/NotoSansCJK-Regular.ttc')
      .readAsBytesSync();
  final loader = FontLoader(_font)
    ..addFont(Future.value(ByteData.view(Uint8List.fromList(bytes).buffer)));
  await loader.load();
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(_loadFont);

  testWidgets('progressive shot', (tester) async {
    tester.view.physicalSize = const Size(900, 1200);
    tester.view.devicePixelRatio = 2;
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
                      for (var i = 0; i < 30; i++)
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 20),
                          child: Text(
                            '第 $i 行 文字 · Progressive Blur 12345',
                            style: const TextStyle(
                              fontFamily: _font,
                              fontSize: 22,
                              color: Colors.white,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            ),
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              height: 240,
              child: IgnorePointer(
                child: RoamProgressiveBlur(backdrop: backdrop, endFraction: 0.8),
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
