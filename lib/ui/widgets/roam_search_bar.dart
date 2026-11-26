// ignore_for_file: deprecated_member_use

import 'package:flutter/material.dart';

import '../../theme/roam_theme.dart';

/// 搜索栏（按安全服务 13.2.0 的 miuix SearchActionMode 逆向）。
///
/// 逆向依据（`res/values/dimens.xml` / `colors.xml` / `layout/miuix_appcompat_search_stub.xml`）：
///
/// | 项 | 原版值 | 来源 |
/// |---|---|---|
/// | 栏总高 | 56dp（4 + 44 + 8） | `miuix_appcompat_search_view_default_height` / `_padding_top` / `_padding_bottom` |
/// | 输入框高 | 44dp | `miuix_appcompat_searchbar_bg_height` |
/// | 输入框圆角 | 72dp（≈胶囊） | `miuix_appcompat_search_mode_bg_radius` |
/// | 浅色底 | `#0F000000` | `miuix_color_black_level9` |
/// | 深色底 | `#24FFFFFF` | `miuix_color_white_level8` |
/// | 提示色 | `#4D000000` / `#4DFFFFFF` | `on_surface_octonary` |
/// | 框内左右 | 12dp | `_search_container_padding_horizontal` |
/// | 放大镜 | 24dp，右间距 8dp | `_search_icon_size` / `_search_icon_margin_end` |
/// | 输入字号 | 17sp | `miuix_font_size_headline1` |
/// | 返回/取消间距 | 10dp | `_start_back_icon_margin_end` / `_end_back_icon_margin_start` |
/// | 取消 | 17sp，左右 10dp | `SearchView.Widget.Button` |
///
/// 结构照搬原版 `miuix_appcompat_search_view`：返回图标 → 输入框 → 取消，
/// 整条替换顶栏；输入框内的清除按钮对应 `ClearableEditText` 的
/// `?clearEditTextIcon`。
class RoamSearchBar extends StatefulWidget {
  const RoamSearchBar({
    super.key,
    required this.controller,
    required this.focusNode,
    required this.onChanged,
    required this.onCancel,
    this.hint = '搜索设置项',
  });

  /// 栏总高（含 4dp 上、8dp 下内边距）。
  static const height = 56.0;

  /// 输入框高度。
  static const fieldHeight = 44.0;

  final TextEditingController controller;
  final FocusNode focusNode;
  final ValueChanged<String> onChanged;

  /// 左侧返回与右侧「取消」都退出搜索。
  final VoidCallback onCancel;
  final String hint;

  @override
  State<RoamSearchBar> createState() => _RoamSearchBarState();
}

class _RoamSearchBarState extends State<RoamSearchBar> {
  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final fg = isDark ? RoamColors.textPrimary : RoamColors.dayInk;
    // 原版 6% 黑 / 14% 白，落在纯色页面上就是一条比底色深一档的胶囊。
    final fieldBg = isDark ? const Color(0x24FFFFFF) : const Color(0x0F000000);
    final hintColor = isDark
        ? const Color(0x4DFFFFFF)
        : const Color(0x4D000000);
    final iconColor = isDark
        ? const Color(0x8AFFFFFF)
        : const Color(0x8A000000);

    return ColoredBox(
      // 原版 SearchActionMode 的底是 window 色（不透明），列表滚到
      // 搜索栏下面时会被遮住；这里同样给一条实色底。
      color: isDark ? Colors.black : RoamColors.daySky,
      child: SizedBox(
        height: RoamSearchBar.height,
        child: Padding(
          padding: const EdgeInsets.only(top: 4, bottom: 8),
          child: Row(
            children: [
              // 返回：44dp 触区，图标按原包 PNG 的墨迹比例放大到 30dp。
              _IconTap(
                width: 44,
                onTap: widget.onCancel,
                tooltip: '退出搜索',
                child: Image.asset(
                  'assets/images/back_images.png',
                  width: 30,
                  height: 30,
                  color: fg,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Container(
                  height: RoamSearchBar.fieldHeight,
                  decoration: BoxDecoration(
                    color: fieldBg,
                    borderRadius: BorderRadius.circular(
                      RoamSearchBar.fieldHeight / 2,
                    ),
                  ),
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  child: Row(
                    children: [
                      Image.asset(
                        'assets/images/search_lc.png',
                        width: 24,
                        height: 24,
                        color: iconColor,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: TextField(
                          controller: widget.controller,
                          focusNode: widget.focusNode,
                          onChanged: widget.onChanged,
                          textInputAction: TextInputAction.search,
                          style: TextStyle(
                            fontSize: 17,
                            color: fg,
                            height: 1.2,
                          ),
                          cursorColor: RoamColors.aurora,
                          decoration: InputDecoration(
                            isDense: true,
                            border: InputBorder.none,
                            contentPadding: EdgeInsets.zero,
                            hintText: widget.hint,
                            hintStyle: TextStyle(
                              fontSize: 17,
                              color: hintColor,
                              height: 1.2,
                            ),
                          ),
                        ),
                      ),
                      ValueListenableBuilder<TextEditingValue>(
                        valueListenable: widget.controller,
                        builder: (context, value, _) {
                          if (value.text.isEmpty) {
                            return const SizedBox.shrink();
                          }
                          return Padding(
                            padding: const EdgeInsets.only(left: 6),
                            child: GestureDetector(
                              onTap: () {
                                widget.controller.clear();
                                widget.onChanged('');
                                widget.focusNode.requestFocus();
                              },
                              behavior: HitTestBehavior.opaque,
                              child: Container(
                                width: 18,
                                height: 18,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: isDark
                                      ? const Color(0x3DFFFFFF)
                                      : const Color(0x3D000000),
                                ),
                                child: Icon(
                                  Icons.close,
                                  size: 12,
                                  color: isDark ? Colors.black : Colors.white,
                                ),
                              ),
                            ),
                          );
                        },
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 10),
              _IconTap(
                onTap: widget.onCancel,
                tooltip: '取消',
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 10),
                  child: Text(
                    '取消',
                    style: TextStyle(
                      fontSize: 17,
                      color: fg,
                      fontWeight: FontWeight.w400,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _IconTap extends StatelessWidget {
  const _IconTap({
    required this.child,
    required this.onTap,
    this.width,
    this.tooltip,
  });

  final Widget child;
  final VoidCallback onTap;
  final double? width;
  final String? tooltip;

  @override
  Widget build(BuildContext context) {
    final button = GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: SizedBox(
        width: width,
        height: RoamSearchBar.fieldHeight,
        child: Center(child: child),
      ),
    );
    if (tooltip == null) return button;
    return Tooltip(message: tooltip!, child: button);
  }
}
