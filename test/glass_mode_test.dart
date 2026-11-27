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

  testWidgets('标准：整块纹理模糊，不用折射 panel', (tester) async {
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
    // 标准态不用会「只在边缘采样」的折射 panel：MiuixGlassPanel 的 shader 让
    // 面板中间接近原图，真机看起来是局部模糊；改为库的纹理模糊整块高斯。
    // 这里没有 backdrop，走不透明兜底色，所以只有 ClipRRect + 内容。
    expect(find.byType(MiuixGlassPanel), findsNothing);
    expect(find.byType(BackdropFilter), findsNothing);
    expect(find.byType(ClipRRect), findsWidgets);
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
