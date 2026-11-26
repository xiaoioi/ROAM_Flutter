// 视觉验收截图：把关键界面渲染成 PNG，方便人工对照 miuix 规范。
// 运行：flutter test test/preview_shot_test.dart
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_miuix/miuix.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:roam_flutter/theme/roam_theme.dart';
import 'package:roam_flutter/ui/widgets/confirm.dart';
import 'package:roam_flutter/ui/widgets/hyperos_top_bar.dart';
import 'package:roam_flutter/ui/widgets/roam_chrome.dart';
import 'package:roam_flutter/ui/widgets/roam_sheet.dart';
import 'package:roam_flutter/ui/widgets/roam_segmented.dart';

const _fontFamily = 'PreviewCJK';
final _boundaryKey = GlobalKey();

Future<void> _loadFont() async {
  final bytes = File(
    '/usr/share/fonts/opentype/noto/NotoSansCJK-Regular.ttc',
  ).readAsBytesSync();
  final loader = FontLoader(_fontFamily)
    ..addFont(Future.value(ByteData.view(Uint8List.fromList(bytes).buffer)));
  await loader.load();
}

Future<void> _save(WidgetTester tester, String name) async {
  await expectLater(
    find.byType(MaterialApp),
    matchesGoldenFile('shots/$name.png'),
  );
}

Widget _app(Widget home, {Brightness brightness = Brightness.dark}) {
  return MaterialApp(
    debugShowCheckedModeBanner: false,
    theme: RoamTheme.build(brightness, fontFamily: _fontFamily),
    home: RepaintBoundary(key: _boundaryKey, child: home),
    builder: (context, child) => MiuixTheme(
      data: MiuixThemeData.of(brightness),
      child: child ?? const SizedBox.shrink(),
    ),
  );
}

/// 一个最小二级页：顶栏 + 长列表（可滚动，用来验证圆钮描边随滚动出现）。
class _DemoPage extends StatefulWidget {
  const _DemoPage();

  @override
  State<_DemoPage> createState() => _DemoPageState();
}

class _DemoPageState extends State<_DemoPage> {
  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return RoamPageScaffold(
      title: '下载管理',
      actions: [
        HyperosBarAction(asset: 'assets/images/menu.png', onTap: () {}),
      ],
      child: ListView(
        padding: const EdgeInsets.only(
          top: RoamPageScaffold.contentTopPadding + 4,
          bottom: 40,
        ),
        physics: const BouncingScrollPhysics(),
        children: [
          const RoamGroupHeader(text: '下载的文件'),
          for (var i = 0; i < 8; i++)
            RoamListCard(
              child: Row(
                children: [
                  Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: RoamColors.aurora.withValues(alpha: 0.16),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(
                      Icons.insert_drive_file_outlined,
                      size: 18,
                      color: RoamColors.aurora,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Text(
                    '示例文件 $i.pdf',
                    style: TextStyle(
                      color: isDark
                          ? RoamColors.textPrimary
                          : RoamColors.dayInk,
                    ),
                  ),
                ],
              ),
            ),
          const RoamGroupHeader(text: '数据网络设置'),
          RoamSettingCard(
            children: [
              RoamSettingRow(
                icon: 'assets/images/menu.png',
                label: '使用 5G/4G 流量下载',
                showChevron: false,
                trailing: RoamSwitch(value: true, onChanged: (_) {}),
                onTap: () {},
              ),
            ],
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(25, 16, 25, 0),
            child: RoamSegmented(
              tabs: const ['跟随系统', '深色模式', '浅色模式'],
              selectedIndex: 1,
              onSelect: (_) {},
            ),
          ),
        ],
      ),
    );
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    await _loadFont();
  });

  testWidgets('预览截图', (tester) async {
    tester.view.physicalSize = const Size(1080, 2340);
    tester.view.devicePixelRatio = 3;
    tester.view.padding = const FakeViewPadding(top: 90, bottom: 60);
    addTearDown(tester.view.reset);

    await tester.pumpWidget(_app(const _DemoPage()));
    // 让 Image.asset 在 fake async 下真的解码完（否则首帧截到的是空图标）。
    await tester.runAsync(() => Future<void>.delayed(
          const Duration(milliseconds: 200),
        ));
    await tester.pump(const Duration(milliseconds: 60));
    await tester.pump(const Duration(milliseconds: 400));
    await _save(tester, 'new-01-page-top');

    // 滚动一段 → 顶栏浮起（圆钮玻璃 + 描边 + 模糊带）
    await tester.drag(find.byType(ListView), const Offset(0, -420));
    await tester.pump(const Duration(milliseconds: 60));
    await tester.pump(const Duration(milliseconds: 500));
    await _save(tester, 'new-02-page-scrolled');

    // 底部弹出框
    final ctx = tester.element(find.byType(ListView));
    showRoamSheet<void>(
      context: ctx,
      title: '新建任务',
      children: [
        for (var i = 0; i < 3; i++)
          RoamSheetRow(
            icon: Icons.link,
            title: '示例条目 $i',
            subtitle: '这是一行说明文字',
            onTap: () {},
          ),
      ],
    );
    await tester.pump(const Duration(milliseconds: 60));
    await tester.pump(const Duration(milliseconds: 700));
    await _save(tester, 'new-03-sheet');

    // 关掉再开对话框
    Navigator.of(tester.element(find.byType(ListView))).pop();
    await tester.pump(const Duration(milliseconds: 500));
    showRoamDialog<bool>(
      context: tester.element(find.byType(ListView)),
      title: '删除全部书签',
      message: '要删除全部书签吗？删除后无法恢复。',
      actions: const [
        RoamDialogAction(label: '取消', value: false),
        RoamDialogAction(
          label: '全部删除',
          value: true,
          primary: true,
          destructive: true,
        ),
      ],
    );
    await tester.pump(const Duration(milliseconds: 60));
    await tester.pump(const Duration(milliseconds: 700));
    await _save(tester, 'new-04-dialog');
  });
}
