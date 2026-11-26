// ignore_for_file: deprecated_member_use

import 'package:flutter/rendering.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/widgets.dart';

/// 位置变了就重绘：给「只被外层位移带走、自己没重建」的子树一个重绘信号。
///
/// 玻璃（[RoamGlass]）是在 `paint()` 里读自身 `localToGlobal` 来算采样 UV 的。
/// 只要它自己不被重绘，绘制结果（含采样到的背景）就会被上层当作一层图搬来
/// 搬去——表现出来就是「面板在动，玻璃里的背景却钉在原地」。
///
/// 典型场景：底部面板被 `showModalBottomSheet` 的拖拽（改变的是父级布局偏移，
/// 子树不会 rebuild 也不会 relayout），以及被预测式返回的 `Transform` 平移。
///
/// 这里在每帧开始比对一次全局原点，位置变了就 `markNeedsPaint()`。
/// 只在有帧的时候跑（拖动/动画期间才产帧，静止时零开销），
/// 计算量是一次矩阵乘法。
class LayoutMotionRepaint extends SingleChildRenderObjectWidget {
  const LayoutMotionRepaint({super.key, required Widget super.child});

  @override
  RenderObject createRenderObject(BuildContext context) =>
      _RenderLayoutMotionRepaint();
}

class _RenderLayoutMotionRepaint extends RenderProxyBox {
  Offset? _lastOrigin;
  bool _running = false;

  @override
  void attach(PipelineOwner owner) {
    super.attach(owner);
    _running = true;
    _schedule();
  }

  @override
  void detach() {
    _running = false;
    super.detach();
  }

  void _schedule() {
    if (!_running) return;
    SchedulerBinding.instance.scheduleFrameCallback(_onFrame);
  }

  void _onFrame(Duration _) {
    if (!_running || !attached) return;
    if (hasSize) {
      final origin = localToGlobal(Offset.zero);
      final last = _lastOrigin;
      _lastOrigin = origin;
      if (last != null && last != origin) markNeedsPaint();
    }
    // transient 回调每帧清空，自己续上。
    _schedule();
  }
}
