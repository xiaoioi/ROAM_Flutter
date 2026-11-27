// ignore_for_file: deprecated_member_use

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_miuix/miuix.dart';

import '../../theme/roam_theme.dart';
import 'glass_controls.dart';

/// 一条搜索结果。
class GlassSearchEntry {
  const GlassSearchEntry({
    required this.title,
    required this.onTap,
    this.subtitle,
    this.group = '',
    this.icon,
  });

  final String title;
  final String? subtitle;

  /// 所属分组（搜索时一并匹配，结果里作为小字提示）。
  final String group;
  final String? icon;
  final VoidCallback onTap;
}

/// 全屏玻璃搜索浮层，对齐 miuix 的 `GlassSearchOverlay`。
///
/// 还原的结构（见 compose-miuix `GlassSearchOverlay.kt`）：
///
///  - 顶部一条 **progressive blur** 过渡带，高度盖住状态栏 + 搜索行；
///    模糊和顶栏用同一条渐进模糊带（`RoamProgressiveBlur`）；
///  - 胶囊形玻璃搜索框（`popupViewGlass` 材质 + `small` 描边 + `floating` 投影），
///    前置放大镜、输入非空时给清除钮；
///  - 右侧「取消」圆钮（[MiuixGlassIconButton]），点它或按返回收起；
///  - 下方是可滚动的结果容器，每行是「图标 + 标题 + 副标题」，
///    分组名作为右侧灰色小字。
///
/// 浮层不新开路由：它挂在设置页的 Stack 里（`RoamPageScaffold.overlayBuilder`），
/// 这样能直接复用页面级背景快照做真实采样，而不是隔着路由拿到过期纹理。
class RoamGlassSearchOverlay extends StatefulWidget {
  const RoamGlassSearchOverlay({
    super.key,
    required this.backdrop,
    required this.entries,
    required this.onClose,
    this.hint = '搜索',
    this.emptyHint = '没有找到相关结果',
  });

  /// 页面级背景采样源（与顶栏玻璃、边缘渐隐共用）。
  final MiuixBackdrop backdrop;
  final List<GlassSearchEntry> entries;
  final VoidCallback onClose;
  final String hint;
  final String emptyHint;

  @override
  State<RoamGlassSearchOverlay> createState() => _RoamGlassSearchOverlayState();
}

class _RoamGlassSearchOverlayState extends State<RoamGlassSearchOverlay>
    with SingleTickerProviderStateMixin {
  final _text = TextEditingController();
  final _focus = FocusNode();
  late final AnimationController _enter = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 260),
  )..forward();

  String _query = '';

  @override
  void initState() {
    super.initState();
    // 等浮层落位再抢焦点：否则 IME 会在入场动画中途弹起，把面板顶一下。
    Future<void>.delayed(const Duration(milliseconds: 200), () {
      if (mounted) _focus.requestFocus();
    });
  }

  @override
  void dispose() {
    _enter.dispose();
    _text.dispose();
    _focus.dispose();
    super.dispose();
  }

  void _close() {
    _focus.unfocus();
    widget.onClose();
  }

  List<GlassSearchEntry> get _results {
    final q = _query.trim().toLowerCase();
    if (q.isEmpty) return const [];
    return [
      for (final entry in widget.entries)
        if (entry.title.toLowerCase().contains(q) ||
            (entry.subtitle ?? '').toLowerCase().contains(q) ||
            entry.group.toLowerCase().contains(q))
          entry,
    ];
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final fg = isDark ? RoamColors.textPrimary : RoamColors.dayInk;
    final sub = isDark ? RoamColors.textSecondary : RoamColors.daySecondary;
    final top = MediaQuery.paddingOf(context).top;
    const rowHeight = 52.0;
    final bandHeight = top + rowHeight + 26;

    return AnimatedBuilder(
      animation: _enter,
      builder: (context, _) {
        final t = Curves.easeOutCubic.transform(_enter.value);
        return Stack(
          children: [
            // 背景压一层薄 scrim，让内容退到后面（点击也由它接住，
            // 点空白处等于取消）。
            Positioned.fill(
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: _close,
                child: ColoredBox(
                  color: Colors.black.withValues(alpha: (isDark ? 0.34 : 0.18) * t),
                ),
              ),
            ),
            // 顶部 progressive blur 过渡带。
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              height: bandHeight,
              child: IgnorePointer(
                child: Opacity(
                  opacity: t,
                  child: _ProgressiveBlurBand(
                    backdrop: widget.backdrop,
                    isDark: isDark,
                  ),
                ),
              ),
            ),
            // 搜索行：胶囊输入 + 取消圆钮。
            Positioned(
              top: top + 6,
              left: 12,
              right: 12,
              child: Opacity(
                opacity: t,
                child: Transform.translate(
                  offset: Offset(0, (1 - t) * -10),
                  child: Row(
                    children: [
                      Expanded(child: _field(context, isDark, fg, sub)),
                      const SizedBox(width: 8),
                      MiuixGlassIconButton(
                        onPressed: _close,
                        size: 44,
                        backdrop: widget.backdrop,
                        inheritTopBarMaterial: false,
                        tooltip: '取消',
                        child: MiuixIcon(
                          vector: MiuixIcons.basic.close,
                          size: 20,
                          tint: fg,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            // 结果容器：从搜索行下方开始，整块可以滚。
            Positioned(
              top: bandHeight - 8,
              left: 12,
              right: 12,
              bottom: 0,
              child: Opacity(
                opacity: t,
                child: _results.isEmpty
                    ? Align(
                        alignment: Alignment.topCenter,
                        child: Padding(
                          padding: const EdgeInsets.only(top: 28),
                          child: Text(
                            _query.trim().isEmpty ? '输入关键词搜索设置项' : widget.emptyHint,
                            style: TextStyle(
                              fontSize: 13.5,
                              color: sub.withValues(alpha: 0.7),
                            ),
                          ),
                        ),
                      )
                    : ListView.builder(
                        physics: const BouncingScrollPhysics(),
                        padding: EdgeInsets.only(
                          bottom: MediaQuery.paddingOf(context).bottom + 24,
                        ),
                        itemCount: _results.length,
                        itemBuilder: (context, index) => _row(
                          context,
                          _results[index],
                          isDark: isDark,
                          fg: fg,
                          sub: sub,
                        ),
                      ),
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _field(BuildContext context, bool isDark, Color fg, Color sub) {
    return MiuixGlassPanel(
      backdrop: widget.backdrop,
      shape: MiuixGlassShape(cornerRadius: 22),
      material: MiuixGlassMaterials.popupViewGlass(isDark),
      stroke: MiuixGlassStrokes.small(isDark),
      shadow: MiuixGlassShadows.floating,
      shading: false,
      // TextField 需要 Material 祖先（浮层可能挂在没有 Scaffold 的宿主上）。
      child: Material(
        type: MaterialType.transparency,
        child: SizedBox(
          height: 44,
          child: Row(
          children: [
            const SizedBox(width: 14),
            MiuixIcon(
              vector: MiuixIcons.basic.search,
              size: 19,
              tint: fg.withValues(alpha: 0.5),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: TextField(
                controller: _text,
                focusNode: _focus,
                onChanged: (value) => setState(() => _query = value),
                textInputAction: TextInputAction.search,
                cursorColor: RoamColors.aurora,
                style: TextStyle(fontSize: 16, height: 1.2, color: fg),
                decoration: InputDecoration(
                  isDense: true,
                  border: InputBorder.none,
                  contentPadding: EdgeInsets.zero,
                  hintText: widget.hint,
                  hintStyle: TextStyle(
                    fontSize: 16,
                    height: 1.2,
                    color: sub.withValues(alpha: 0.6),
                  ),
                ),
              ),
            ),
            if (_query.isNotEmpty)
              GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: () {
                  _text.clear();
                  setState(() => _query = '');
                  _focus.requestFocus();
                },
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  child: MiuixIcon(
                    vector: MiuixIcons.basic.searchCleanup,
                    size: 18,
                    tint: sub.withValues(alpha: 0.7),
                  ),
                ),
              ),
              const SizedBox(width: 6),
            ],
          ),
        ),
      ),
    );
  }

  Widget _row(
    BuildContext context,
    GlassSearchEntry entry, {
    required bool isDark,
    required Color fg,
    required Color sub,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: MiuixGlassPanel(
        backdrop: widget.backdrop,
        shape: MiuixGlassShape(cornerRadius: 16),
        material: MiuixGlassMaterials.popupViewGlass(isDark),
        stroke: MiuixGlassStrokes.small(isDark),
        shadow: MiuixGlassShadows.low,
        shading: false,
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            borderRadius: BorderRadius.circular(16),
            onTap: () {
              HapticFeedback.selectionClick();
              _focus.unfocus();
              // 先收起浮层再导航：否则新页压栈时浮层还挂在旧页上。
              widget.onClose();
              entry.onTap();
            },
            child: SizedBox(
              height: 58,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 14),
                child: Row(
                  children: [
                    if (entry.icon != null) ...[
                      Image.asset(
                        entry.icon!,
                        width: 22,
                        height: 22,
                        color: fg,
                      ),
                      const SizedBox(width: 12),
                    ],
                    Expanded(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            entry.title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(fontSize: 15, color: fg),
                          ),
                          if (entry.subtitle != null) ...[
                            const SizedBox(height: 2),
                            Text(
                              entry.subtitle!,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(fontSize: 11.5, color: sub),
                            ),
                          ],
                        ],
                      ),
                    ),
                    if (entry.group.isNotEmpty)
                      Text(
                        entry.group,
                        style: TextStyle(
                          fontSize: 11.5,
                          color: sub.withValues(alpha: 0.55),
                        ),
                      ),
                    const SizedBox(width: 6),
                    MiuixIcon(
                      vector: MiuixIcons.basic.arrowRight,
                      size: 14,
                      tint: fg.withValues(alpha: 0.3),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// 顶部渐进模糊带：纯模糊，半径沿竖直方向衰减到 0，不叠任何色调。
class _ProgressiveBlurBand extends StatelessWidget {
  const _ProgressiveBlurBand({required this.backdrop, required this.isDark});

  final MiuixBackdrop backdrop;
  final bool isDark;

  @override
  Widget build(BuildContext context) {
    // 只有模糊，没有色调：原来那层 surface 32%→0 的渐变就是「灰遮罩」，
    // bandMaterial 深色版又自带 #565656/#3F3F3F 的灰调，一起去掉。
    if (!GlassRuntime.material.value ||
        GlassRuntime.performance.value) {
      return const SizedBox.shrink();
    }
    return RoamProgressiveBlur(backdrop: backdrop);
  }
}
