// ignore_for_file: deprecated_member_use

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// 预测式返回（Android 14+ Predictive Back）在星环里的统一实现。
///
/// Flutter 只为 `PageRoute` 提供了 `PredictiveBackPageTransitionsBuilder`，
/// 弹层（`showModalBottomSheet` / `showDialog`）和浏览器主界面都拿不到
/// 手势进度，表现就是「侧滑没反应，松手才关」。这里用
/// [WidgetsBindingObserver.handleStartBackGesture] 抢下手势，把系统给的
/// 0..1 进度映射成位移，做出跟手的返回动画：
///
/// * [PredictiveBackStyle.horizontal]：内容整体横向平移，露出的部分铺
///   [PredictiveBackScope.backdrop]（网页的上一页模糊快照）；
/// * [PredictiveBackStyle.sheet]：底部面板随手下移；
/// * [PredictiveBackStyle.dialog]：对话框缩小淡出。
///
/// 谁在栈顶谁接管：`PredictiveBackScope` 按挂载顺序入栈，只有最上面且
/// `enabled` 的那个能拿到手势；返回 false 时继续交给 Flutter 自己的
/// 页面转场，互不干扰。
enum PredictiveBackStyle { horizontal, sheet, dialog }

class PredictiveBackTarget {
  PredictiveBackTarget(this.onCommit, {this.instantCommit = false});

  final VoidCallback onCommit;

  /// 松手时直接归位再执行 [onCommit]，不做「先滑到 1.0 再复位」的收尾。
  ///
  /// 网页返回必须这样：内容区是同一个 WebView，滑到 1.0 时上一页已经加载
  /// 进来了，再等 240ms 复位，看到的就是「新页面先出现在右边、然后瞬移回原位」
  /// ——也就是那一下闪。
  final bool instantCommit;

  bool enabled = true;
}

/// 全局协调器：注册一个 [WidgetsBindingObserver]，独占一次返回手势。
class PredictiveBackCoordinator with WidgetsBindingObserver {
  PredictiveBackCoordinator._();

  static final PredictiveBackCoordinator instance =
      PredictiveBackCoordinator._();

  final List<PredictiveBackTarget> _targets = <PredictiveBackTarget>[];
  AnimationController? _controller;
  PredictiveBackTarget? _active;
  bool _observing = false;
  bool _settling = false;

  /// 0..1 的手势进度，弹层/页面直接用它做 `Transform`。
  Animation<double> get animation =>
      _controller ?? const AlwaysStoppedAnimation<double>(0);

  double get value => _controller?.value ?? 0;

  void attach(AnimationController controller) {
    _controller = controller;
    if (!_observing) {
      WidgetsBinding.instance.addObserver(this);
      _observing = true;
    }
  }

  void detach() {
    if (_observing) {
      WidgetsBinding.instance.removeObserver(this);
      _observing = false;
    }
    _controller = null;
  }

  void bind(PredictiveBackTarget target) => _targets.add(target);

  void unbind(PredictiveBackTarget target) {
    _targets.remove(target);
    if (identical(_active, target)) _active = null;
  }

  PredictiveBackTarget? get _top {
    for (var i = _targets.length - 1; i >= 0; i--) {
      if (_targets[i].enabled) return _targets[i];
    }
    return null;
  }

  @override
  bool handleStartBackGesture(PredictiveBackEvent backEvent) {
    final controller = _controller;
    if (controller == null || _settling) return false;
    final target = _top;
    if (target == null) return false;
    _active = target;
    controller.value = backEvent.progress;
    return true;
  }

  @override
  void handleUpdateBackGestureProgress(PredictiveBackEvent backEvent) {
    if (_active == null) return;
    _controller?.value = backEvent.progress;
  }

  @override
  void handleCommitBackGesture() {
    final target = _active;
    _active = null;
    if (target == null) return;
    final controller = _controller;
    if (controller == null) {
      target.onCommit();
      return;
    }

    // 网页：立刻归位再切页。内容区是同一个 WebView，任何「先滑出去再复位」
    // 的收尾都会让新页面在偏移位置上闪一下。
    if (target.instantCommit) {
      controller.value = 0;
      target.onCommit();
      return;
    }

    _settling = true;
    // 先把手势补到 1，让页面/面板先滑出屏幕，再真正 pop，
    // 否则会看到「滑到一半突然归位」的闪动。
    controller
        .animateTo(
          1,
          duration: const Duration(milliseconds: 110),
          curve: Curves.easeOut,
        )
        .whenComplete(() {
          target.onCommit();
          // 等退场动画走完再复位，避免新页面/新弹层从偏移状态开始。
          Future<void>.delayed(const Duration(milliseconds: 240), () {
            if (_controller == controller) {
              controller.value = 0;
              _settling = false;
            }
          });
        });
  }

  @override
  void handleCancelBackGesture() {
    _active = null;
    _controller?.animateBack(
      0,
      duration: const Duration(milliseconds: 200),
      curve: Curves.easeOutCubic,
    );
  }
}

/// 挂在 `MaterialApp.builder` 上，提供 [AnimationController] 的 vsync。
class PredictiveBackHost extends StatefulWidget {
  const PredictiveBackHost({super.key, required this.child});

  final Widget child;

  @override
  State<PredictiveBackHost> createState() => _PredictiveBackHostState();
}

class _PredictiveBackHostState extends State<PredictiveBackHost>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 200),
  );

  @override
  void initState() {
    super.initState();
    PredictiveBackCoordinator.instance.attach(_controller);
  }

  @override
  void dispose() {
    PredictiveBackCoordinator.instance.detach();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.child;
}

/// 让子树接入预测式返回：侧滑时跟手位移，松手调用 [onCommit]。
///
/// [backdrop] 只在 [PredictiveBackStyle.horizontal] 下生效：内容平移后露出来
/// 的那一侧铺什么。传 null 就露出下层本来有的东西（页面底色）。
class PredictiveBackScope extends StatefulWidget {
  const PredictiveBackScope({
    super.key,
    required this.child,
    required this.onCommit,
    this.style = PredictiveBackStyle.sheet,
    this.enabled = true,
    this.backdrop,
  });

  final Widget child;
  final VoidCallback onCommit;
  final PredictiveBackStyle style;
  final bool enabled;
  final Widget? backdrop;

  @override
  State<PredictiveBackScope> createState() => _PredictiveBackScopeState();
}

class _PredictiveBackScopeState extends State<PredictiveBackScope> {
  late final PredictiveBackTarget _target = PredictiveBackTarget(
    () => widget.onCommit(),
    instantCommit: widget.style == PredictiveBackStyle.horizontal,
  );

  @override
  void initState() {
    super.initState();
    _target.enabled = widget.enabled;
    PredictiveBackCoordinator.instance.bind(_target);
  }

  @override
  void didUpdateWidget(covariant PredictiveBackScope oldWidget) {
    super.didUpdateWidget(oldWidget);
    _target.enabled = widget.enabled;
  }

  @override
  void dispose() {
    PredictiveBackCoordinator.instance.unbind(_target);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final coordinator = PredictiveBackCoordinator.instance;
    // 这里刻意不因为 `enabled == false` 或 `p == 0` 就换成裸 child。
    // 一旦结构在「直接 child / 包一层 Stack」之间切换，子树里的
    // WebView（platform view）就会被重建，表现就是每次手势开始和结束
    // 都闪一下。结构恒定、只让数值变化，才是最省也最稳的做法。
    return AnimatedBuilder(
      animation: coordinator.animation,
      builder: (context, child) {
        final p = coordinator.animation.value;
        switch (widget.style) {
          case PredictiveBackStyle.horizontal:
            // 网页区整体右移，左侧露出的部分是「上一页」的模糊快照。
            // 只做左边缘圆角：右边缘已经滑出屏幕，圆角看不见，反而多一次裁剪。
            final width = MediaQuery.sizeOf(context).width;
            final backdrop = widget.backdrop;
            return Stack(
              clipBehavior: Clip.hardEdge,
              children: [
                // 占位始终保持一个 child，避免 backdrop 出现/消失时
                // Stack 的 children 数量变化，把下面那块内容重新挂一遍。
                Positioned.fill(
                  child: backdrop == null
                      ? const SizedBox.shrink()
                      // 背景比手势慢一点：从左侧 4.5% 归位，做出前后层次。
                      : Transform.translate(
                          offset: Offset((p - 1) * width * 0.045, 0),
                          child: backdrop,
                        ),
                ),
                Positioned.fill(
                  child: Transform.translate(
                    offset: Offset(p * width * 0.34, 0),
                    child: ClipRRect(
                      borderRadius: BorderRadius.horizontal(
                        left: Radius.circular(24 * p),
                      ),
                      child: child,
                    ),
                  ),
                ),
              ],
            );
          case PredictiveBackStyle.sheet:
            // 跟手往下走，同时轻微缩小 + 变淡：面板像是「沉」下去，
            // 而不是一张图直接平移，玻璃的静态感会弱很多。
            final height = MediaQuery.sizeOf(context).height;
            return Transform.translate(
              offset: Offset(0, p * height * 0.55),
              child: Transform.scale(
                scale: 1 - 0.04 * p,
                alignment: Alignment.bottomCenter,
                child: Opacity(
                  opacity: (1 - p * 0.12).clamp(0.0, 1.0),
                  child: child,
                ),
              ),
            );
          case PredictiveBackStyle.dialog:
            return Transform.scale(
              scale: 1 - 0.06 * p,
              child: Opacity(
                opacity: (1 - 0.25 * p).clamp(0.0, 1.0),
                child: child,
              ),
            );
        }
      },
      child: widget.child,
    );
  }
}
