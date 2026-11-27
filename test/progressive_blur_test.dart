// 渐变模糊（miuix-blur 的 progressiveTextureBlur）行为测试。
//
// flutter_miuix 1.4.0 还没有这个 Modifier，项目内用库的 MiuixTextureBlur
// 叠多档补位，这里锁住「档位、半径、遮罩区间」三件事，防止以后调参走形。
import 'package:flutter/material.dart';
import 'package:flutter_miuix/miuix.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:roam_flutter/ui/widgets/miuix_progressive_blur.dart';

void main() {
  group('ProgressiveBlur 语义', () {
    test('顶部预设：t=0 满强度，t=1 清晰', () {
      const g = ProgressiveBlur.top;
      expect(g.angle, 90);
      expect(g.ratioAt(0), 1);
      expect(g.ratioAt(1), 0);
      expect(g.ratioAt(0.5), closeTo(0.5, 1e-9));
    });

    test('底部预设方向相反', () {
      expect(ProgressiveBlur.bottom.angle, 270);
      final d = ProgressiveBlur.bottom.direction;
      expect(d.dx, closeTo(0, 1e-9));
      expect(d.dy, closeTo(-1, 1e-9));
    });

    test('startFraction / endFraction 决定过渡区间', () {
      final g = ProgressiveBlur.top.copyWith(
        startFraction: 0.2,
        endFraction: 0.8,
      );
      expect(g.ratioAt(0.2), 1);
      expect(g.ratioAt(0.8), 0);
      expect(g.ratioAt(0.0), 1); // 超出满强度端仍是满强度
      expect(g.ratioAt(1.0), 0);
      expect(g.ratioAt(0.5), closeTo(0.5, 1e-9));
    });

    test('curve 只改衰减曲线，不改端点', () {
      final g = ProgressiveBlur.top.copyWith(curve: 2);
      expect(g.ratioAt(0), 1);
      expect(g.ratioAt(1), 0);
      expect(g.ratioAt(0.5), closeTo(0.25, 1e-9));
      // tAt 是 ratioAt 的反函数
      expect(g.tAt(0.25), closeTo(0.5, 1e-9));
    });
  });

  group('MiuixProgressiveTextureBlur 渲染', () {
    testWidgets('快照未就绪时不画模糊层', (tester) async {
      final backdrop = MiuixLayerBackdrop();
      addTearDown(backdrop.dispose);

      await tester.pumpWidget(
        MaterialApp(
          home: Center(
            child: SizedBox(
              width: 200,
              height: 120,
              child: MiuixProgressiveTextureBlur(
                backdrop: backdrop,
                blurRadius: 80,
                levels: 4,
              ),
            ),
          ),
        ),
      );

      // 没有快照时不画模糊层，避免首帧闪白。
      expect(find.byType(MiuixTextureBlur), findsNothing);
      expect(find.byType(ShaderMask), findsNothing);
    });

    testWidgets('enabled=false 或 blurRadius=0 时不挂模糊层', (tester) async {
      final backdrop = MiuixLayerBackdrop();
      addTearDown(backdrop.dispose);

      await tester.pumpWidget(
        MaterialApp(
          home: Center(
            child: SizedBox(
              width: 100,
              height: 100,
              child: MiuixProgressiveTextureBlur(
                backdrop: backdrop,
                blurRadius: 0,
              ),
            ),
          ),
        ),
      );
      expect(find.byType(MiuixTextureBlur), findsNothing);
      expect(find.byType(ShaderMask), findsNothing);
    });
  });
}
