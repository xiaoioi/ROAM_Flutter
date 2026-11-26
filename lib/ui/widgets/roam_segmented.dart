// ignore_for_file: deprecated_member_use

import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_miuix/miuix.dart';

/// 相连分段轨道（miuix `GlassSegmentedTabRow`）+ 真正可拖动的交互。
///
/// 库里的 [MiuixGlassSegmentedTabRow] 只给每段挂了独立的 tap，没有
/// 拖动：手指横向划过时会被外层列表的垂直手势吃掉，或者因为相邻两段的
/// 命中缝隙而"点了没反应 / 直接跳一格"。这里保持官方外观不动，外面补
/// 一层水平拖动与按下即定位：
///
///  - 按下 / 拖动到的位置 → 直接换算成第几段（`x / 段宽`），不再依赖
///    每段自己的点击区域，越界与缝隙都被吸收；
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

  int _indexAt(double dx, double width) {
    final n = tabs.length;
    if (n <= 1) return 0;
    final gap = math.min(8.0, width / (n - 1));
    final segment = math.max(1.0, (width - gap * (n - 1)) / n);
    final index = (dx / (segment + gap)).floor();
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
            onSelect: onSelect,
            height: height,
            backdrop: backdrop,
          ),
        );
      },
    );
  }
}
