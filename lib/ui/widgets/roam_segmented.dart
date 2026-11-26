// ignore_for_file: deprecated_member_use

import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_miuix/miuix.dart';

/// 相连分段轨道（miuix `GlassSegmentedTabRow`）+ 真正可拖动的交互。
///
/// 库里的 [MiuixGlassSegmentedTabRow] 只给每段挂了独立的 tap，没有拖动，
/// 段与段之间还有 8dp 的缝（缝里点了没有任何反应）。这里保持官方外观
/// 不动，在外面补一层按坐标定位的兜底与横向拖动：
///
///  - 段内点击仍走官方的 `onSelect`（第几段就回第几段）；
///  - 落在缝隙里、或一次移动越过多段时，用 `x / 段宽` 直接换算成第几段，
///    点第几段就落第几段；
///  - 水平拖动在 gesture arena 里与列表的垂直滚动竞争，横向滑动归这里，
///    纵向仍然滚页面；
///  - 指示块仍然是官方那条弹簧，跟手连续移动。
class RoamSegmented extends StatelessWidget {
  const RoamSegmented({
    super.key,
    required this.tabs,
    required this.selectedIndex,
    required this.onSelect,
    this.height = 40,
    this.backdrop,
  });

  final List<String> tabs;
  final int selectedIndex;
  final ValueChanged<int> onSelect;
  final double height;
  final MiuixBackdrop? backdrop;

  /// 把面板内的 x 坐标换算成第几段。
  ///
  /// 与 [MiuixGlassSegmentedTabRow] 的内部布局严格对齐：轨道内边距 3dp，
  /// 段间 gap = min(8, 内宽 / (n-1))，剩余宽度均分给各段。
  int _indexAt(double dx, double width) {
    final n = tabs.length;
    if (n <= 1) return 0;
    const padding = MiuixGlassSegmentedTabRowDefaults.trackPadding;
    final inner = math.max(1.0, width - padding * 2);
    final gap = math.min(
      MiuixGlassSegmentedTabRowDefaults.tabGap,
      inner / (n - 1),
    );
    final segment = math.max(1.0, (inner - gap * (n - 1)) / n);
    final index = ((dx - padding) / (segment + gap)).floor();
    return index.clamp(0, n - 1);
  }

  void _pick(double dx, double width) {
    final index = _indexAt(dx, width);
    if (index != selectedIndex) onSelect(index);
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        return GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTapUp: (details) => _pick(details.localPosition.dx, width),
          onHorizontalDragStart: (details) =>
              _pick(details.localPosition.dx, width),
          onHorizontalDragUpdate: (details) =>
              _pick(details.localPosition.dx, width),
          child: MiuixGlassSegmentedTabRow(
            tabs: tabs,
            selectedIndex: selectedIndex,
            // 段内点击交给官方；外层只兜「点在缝里」和横向拖动。
            onSelect: onSelect,
            height: height,
            backdrop: backdrop,
          ),
        );
      },
    );
  }
}
