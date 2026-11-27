// 弹层背景采样回退：没有作用域时必须取「当前页面」而不是浏览器外壳的全局快照。
//
// 曾经的 bug：在设置页里打开弹层，面板糊的是主页壁纸——页面自己的 build
// context 在 `RoamPageScaffold` 之上，查不到作用域，直接回退到了全局
// `miuixBackdrop`（内容是主页 tab）。
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_miuix/miuix.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:roam_flutter/ui/widgets/roam_backdrop_scope.dart';

Future<ui.Image> _image() async {
  final recorder = ui.PictureRecorder();
  ui.Canvas(recorder).drawRect(
    const Rect.fromLTWH(0, 0, 8, 8),
    ui.Paint()..color = const Color(0xFF123456),
  );
  return recorder.endRecording().toImage(8, 8);
}

void main() {
  testWidgets('没有作用域时取最近活跃的页面级采样源', (tester) async {
    final home = MiuixLayerBackdrop();
    final settings = MiuixLayerBackdrop();
    final img = await _image();
    home.updateSnapshot(img, Offset.zero, 1);
    settings.updateSnapshot(img, Offset.zero, 1);

    late BuildContext ctx;
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) {
            ctx = context;
            return const SizedBox.expand();
          },
        ),
      ),
    );

    // 设置页在主页之后出快照 → 它就是当前页。
    RoamBackdropScope.markActive(home);
    RoamBackdropScope.markActive(settings);
    expect(identical(RoamBackdropScope.samplingOf(ctx), settings), isTrue);

    // 回到主页：设置页注销，栈里只剩主页。
    RoamBackdropScope.clearActive(settings);
    expect(identical(RoamBackdropScope.samplingOf(ctx), home), isTrue);
  });
}
