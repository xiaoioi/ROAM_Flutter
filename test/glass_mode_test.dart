// 玻璃三态回归：材质关闭=纯色、性能优先=简单模糊+轮廓光、标准=整块实时高斯。
import 'package:flutter/material.dart';
import 'package:flutter_miuix/miuix.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:roam_flutter/ui/widgets/glass_controls.dart';
import 'package:roam_flutter/ui/widgets/roam_popup_glass.dart';

Widget _host(Widget child) => MaterialApp(
  home: MiuixTheme(
    data: MiuixThemeData.of(Brightness.dark),
    child: Scaffold(backgroundColor: Colors.black, body: child),
  ),
);

void main() {
  tearDown(() {
    GlassRuntime.material.value = true;
    GlassRuntime.performance.value = false;
    GlassRuntime.rimLight.value = true;
  });

  testWidgets('材质关闭：弹层不模糊、不描边，纯色底', (tester) async {
    GlassRuntime.material.value = false;
    await tester.pumpWidget(
      _host(
        const Center(
          child: SizedBox(
            width: 300,
            height: 200,
            child: RoamPopupGlass(
              isDialog: true,
              child: SizedBox.expand(),
            ),
          ),
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.byType(BackdropFilter), findsNothing);
    expect(find.byType(MiuixGlassPanel), findsNothing);
    expect(GlassRuntime.mode, RoamGlassMode.off);
  });

  testWidgets('性能优先：简单模糊，不跑高斯，画轮廓光', (tester) async {
    GlassRuntime.performance.value = true;
    await tester.pumpWidget(
      _host(
        const Center(
          child: SizedBox(
            width: 300,
            height: 200,
            child: RoamPopupGlass(
              isDialog: true,
              child: SizedBox.expand(),
            ),
          ),
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 300));

    expect(GlassRuntime.mode, RoamGlassMode.performance);
    expect(find.byType(BackdropFilter), findsNothing);
    // 轮廓光 = 一圈 1px 对比色描边
    final box = tester.widget<Container>(
      find.ancestor(
        of: find.byType(SizedBox),
        matching: find.byType(Container),
      ).first,
    );
    final decoration = box.decoration! as BoxDecoration;
    expect(decoration.border, isNotNull);
  });

  testWidgets('标准：走 miuix 官方玻璃表面', (tester) async {
    await tester.pumpWidget(
      _host(
        const Center(
          child: SizedBox(
            width: 300,
            height: 200,
            child: RoamPopupGlass(
              isDialog: true,
              child: SizedBox.expand(),
            ),
          ),
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 300));

    expect(GlassRuntime.mode, RoamGlassMode.standard);
    // 标准态就是库的官方表面（`glassDialogSurface` → MiuixGlassPanel +
    // MiuixScrimBackdrop）：材质 / 圆角 / 描边全部由 miuix 出，不再自己拼。
    // 没有 backdrop 时官方 surface 画不透明 containerColor，仍是完整面板。
    expect(find.byType(MiuixGlassPanel), findsWidgets);
    expect(find.byType(BackdropFilter), findsNothing);
  });

  testWidgets('轮廓光可单独关闭', (tester) async {
    GlassRuntime.performance.value = true;
    GlassRuntime.rimLight.value = false;
    await tester.pumpWidget(
      _host(
        const Center(
          child: SizedBox(
            width: 300,
            height: 200,
            child: RoamPopupGlass(
              isDialog: true,
              child: SizedBox.expand(),
            ),
          ),
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 300));
    final box = tester.widget<Container>(
      find.ancestor(
        of: find.byType(SizedBox),
        matching: find.byType(Container),
      ).first,
    );
    expect((box.decoration! as BoxDecoration).border, isNull);
  });
}
