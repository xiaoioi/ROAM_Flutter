// 分段器交互回归：点击任意一段必须精确落到那一段，横向拖动要跟手切换。
import 'package:flutter/material.dart';
import 'package:flutter_miuix/miuix.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:roam_flutter/ui/widgets/roam_segmented.dart';

Widget _host(ValueNotifier<int> index) {
  const tabs = ['跟随系统', '深色模式', '浅色模式'];
  return MaterialApp(
    theme: ThemeData(brightness: Brightness.dark),
    home: MiuixTheme(
      data: MiuixThemeData.of(Brightness.dark),
      child: Scaffold(
        backgroundColor: Colors.black,
        body: Center(
          child: SizedBox(
            width: 340,
            child: ValueListenableBuilder<int>(
              valueListenable: index,
              builder: (context, value, _) => RoamSegmented(
                tabs: tabs,
                selectedIndex: value,
                onSelect: (i) => index.value = i,
              ),
            ),
          ),
        ),
      ),
    ),
  );
}

void main() {
  testWidgets('点第几段就切到第几段（可跨越）', (tester) async {
    final index = ValueNotifier<int>(0);
    addTearDown(index.dispose);
    await tester.pumpWidget(_host(index));
    await tester.pump(const Duration(milliseconds: 400));

    // 直接点最后一段：必须一次跳到 2，而不是"一格一格"或用相邻项。
    await tester.tap(find.text('浅色模式'));
    await tester.pump(const Duration(milliseconds: 400));
    expect(index.value, 2);

    // 再点回第一段。
    await tester.tap(find.text('跟随系统'));
    await tester.pump(const Duration(milliseconds: 400));
    expect(index.value, 0);

    // 中间的段。
    await tester.tap(find.text('深色模式'));
    await tester.pump(const Duration(milliseconds: 400));
    expect(index.value, 1);
  });

  testWidgets('放在可滚动列表里也能一次点中目标段', (tester) async {
    final index = ValueNotifier<int>(0);
    addTearDown(index.dispose);
    const tabs = ['跟随系统', '深色模式', '浅色模式'];
    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData(brightness: Brightness.dark),
        home: MiuixTheme(
          data: MiuixThemeData.of(Brightness.dark),
          child: Scaffold(
            backgroundColor: Colors.black,
            body: ListView(
              children: [
                const SizedBox(height: 300),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 25),
                  child: ValueListenableBuilder<int>(
                    valueListenable: index,
                    builder: (context, value, _) => RoamSegmented(
                      tabs: tabs,
                      selectedIndex: value,
                      onSelect: (i) => index.value = i,
                    ),
                  ),
                ),
                const SizedBox(height: 900),
              ],
            ),
          ),
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 400));
    await tester.tap(find.text('浅色模式'));
    await tester.pump(const Duration(milliseconds: 400));
    expect(index.value, 2);
  });

  testWidgets('点在段间缝隙也能落到对应段', (tester) async {
    // 从第 3 段开始，点第 1、2 段之间的缝：官方那三段各自只覆盖自己的
    // 矩形，缝隙里点了原本没有任何反应，这里由外层坐标定位兜住。
    final index = ValueNotifier<int>(2);
    addTearDown(index.dispose);
    await tester.pumpWidget(_host(index));
    await tester.pump(const Duration(milliseconds: 400));

    final row = tester.getRect(find.byType(RoamSegmented));
    const inner = 340 - 6.0;
    const gap = 8.0;
    const segment = (inner - gap * 2) / 3;
    final gapX = row.left + 3 + segment + gap * .6;
    await tester.tapAt(Offset(gapX, row.center.dy));
    await tester.pump(const Duration(milliseconds: 400));
    expect(index.value, 0);
  });

  testWidgets('横向拖动经过的段都会切换', (tester) async {
    final index = ValueNotifier<int>(0);
    addTearDown(index.dispose);
    await tester.pumpWidget(_host(index));
    await tester.pump(const Duration(milliseconds: 400));

    final start = tester.getCenter(find.text('跟随系统'));
    final end = tester.getCenter(find.text('浅色模式'));
    final gesture = await tester.startGesture(start);
    await tester.pump(const Duration(milliseconds: 20));
    // 分几步移动，模拟真实拖动。
    for (var i = 0; i < 10; i++) {
      await gesture.moveBy(Offset((end.dx - start.dx) / 10, 0));
      await tester.pump(const Duration(milliseconds: 16));
    }
    await gesture.up();
    await tester.pump(const Duration(milliseconds: 400));
    expect(index.value, 2);
  });
}
