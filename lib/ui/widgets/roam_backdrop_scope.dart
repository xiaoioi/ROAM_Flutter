// ignore_for_file: deprecated_member_use

import 'package:flutter/widgets.dart';
import 'package:flutter_miuix/miuix.dart';

import 'glass_controls.dart';

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

  /// 最近产出过快照的页面级采样源，栈顶 = 当前最该被采样的那一页。
  ///
  /// 为什么要这个：页面（`SettingsPage`、`DownloadsPage`…）自己的 `build`
  /// context 位于 [RoamPageScaffold] **之上**，而作用域挂在 `Scaffold.body`
  /// 里，页面里 `showRoamSheet(context)` 拿到的是页面自己的 context，向上查
  /// 不到作用域。以前这里直接回退到全局 `miuixBackdrop`（浏览器外壳的捕获层，
  /// 内容是主页 tab），结果在设置页打开的弹层里糊的是**主页的壁纸**。
  ///
  /// 现在回退到「最后出过快照的那一页」：被压在下层的路由不再 paint，也就
  /// 不再更新快照，所以栈顶必然是用户正在看的这一页。
  static final List<MiuixBackdrop> _active = [];

  static void markActive(MiuixBackdrop backdrop) {
    _active
      ..remove(backdrop)
      ..add(backdrop);
  }

  static void clearActive(MiuixBackdrop backdrop) => _active.remove(backdrop);

  static MiuixBackdrop? get _current => _active.isEmpty ? null : _active.last;

  /// 适合交给 miuix 做折射采样的源；不可信时返回 null。
  static MiuixBackdrop? samplingOf(BuildContext context) {
    final scope = maybeScopeOf(context);
    if (scope != null) return scope.trustSnapshot ? scope.backdrop : null;
    final active = _current;
    if (active != null && active.hasContent) return active;
    // 浏览器外壳（`browser_shell`）的抽屉从 State 的 context 打开，拿不到
    // 作用域；此时全局捕获层就是它背后的内容，回退它是正确的。
    return miuixBackdrop.hasContent ? miuixBackdrop : null;
  }

  @override
  bool updateShouldNotify(RoamBackdropScope oldWidget) =>
      !identical(backdrop, oldWidget.backdrop) ||
      trustSnapshot != oldWidget.trustSnapshot;
}
