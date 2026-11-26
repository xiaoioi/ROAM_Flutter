// ignore_for_file: deprecated_member_use

import 'package:flutter/widgets.dart';
import 'package:flutter_miuix/miuix.dart';

/// 把当前页面的背景采样源（[MiuixLayerBackdrop]）向下暴露给弹层。
///
/// miuix 的玻璃组件（`GlassBottomSheet` / `GlassDialog` / `GlassIconButton`）
/// 都是「用 backdrop 里的快照做模糊 + 折射」，没有 backdrop 时只能画一块
/// 不透明兜底色。`showModalBottomSheet` / `showDialog` 会把面板压进新的
/// Navigator 路由，panel 自己的 context 读不到页面级 backdrop，所以页面
/// 外壳要把自己的捕获器放到这个 scope 里，弹层在**打开之前**先取走。
class RoamBackdropScope extends InheritedWidget {
  const RoamBackdropScope({
    super.key,
    required this.backdrop,
    this.trustSnapshot = true,
    required super.child,
  });

  final MiuixLayerBackdrop backdrop;

  /// 快照是否可信（能代表面板背后真正画的东西）。
  ///
  /// 网页 tab 里的 WebView 是 platform view，`toImage` 抓不到画面，快照里
  /// 那块是空的；此时宁可走实时 [BackdropFilter]，也不要让玻璃采样到一片黑。
  final bool trustSnapshot;

  static RoamBackdropScope? maybeScopeOf(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<RoamBackdropScope>();

  static MiuixLayerBackdrop? maybeOf(BuildContext context) =>
      maybeScopeOf(context)?.backdrop;

  /// 适合交给 miuix 做折射采样的源；不可信时返回 null（调用方走实时模糊）。
  static MiuixBackdrop? samplingOf(BuildContext context) {
    final scope = maybeScopeOf(context);
    if (scope == null || !scope.trustSnapshot) return null;
    return scope.backdrop;
  }

  @override
  bool updateShouldNotify(RoamBackdropScope oldWidget) =>
      !identical(backdrop, oldWidget.backdrop) ||
      trustSnapshot != oldWidget.trustSnapshot;
}
