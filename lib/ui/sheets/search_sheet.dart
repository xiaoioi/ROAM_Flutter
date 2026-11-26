// ignore_for_file: deprecated_member_use

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_miuix/miuix.dart';

import '../../models/browser_models.dart';
import '../../state/browser_controller.dart';
import '../widgets/predictive_back.dart';
import '../widgets/roam_sheet.dart';

/// 首页顶栏空白处 / 网页标题处点击后弹出的「第二界面」。
///
/// 逆向自原包 `assets/pages/Home/search_container.lua`：原版是
/// `BottomSheetDialog` + `STATE_EXPANDED`（不可拖动、透明底），内容为
///  - 25% 屏宽、5dp 的拖拽手柄
///  - 45dp 输入卡（内嵌返回钮 + EditText）+ 67.5dp「搜索」高对比按钮
///  - 1dp 分隔线（前景色 10% 透明度）
///  - 书签建议（5 列网格，100dp）
///  - 剪贴板内容卡（21dp 圆角）
///  - 历史记录卡（21dp 圆角，270dp 高）
///  - 收起键盘用的 1/4 屏占位
///
/// 这里把原版的 MaterialCardView / EditText / TextView 换成 miuix 的
/// [MiuixCard] / [MiuixTextField] / [MiuixButton] / [MiuixIcon]，
/// 面板本身沿用 App 内统一的 OS4 柔光玻璃。
Future<void> showSearchSheet({
  required BuildContext context,
  required BrowserController controller,
}) {
  return showModalBottomSheet<void>(
    context: context,
    backgroundColor: Colors.transparent,
    isScrollControlled: true,
    barrierColor: Colors.black.withValues(alpha: 0.35),
    builder: (sheetContext) => PredictiveBackScope(
      style: PredictiveBackStyle.sheet,
      onCommit: () {
        // 面板已经在侧滑离场了，别再让输入法弹起来把人拽回来。
        FocusScope.of(sheetContext).unfocus();
        Navigator.of(sheetContext).maybePop();
      },
      child: _SearchSheet(controller: controller),
    ),
  );
}

class _SearchSheet extends StatefulWidget {
  const _SearchSheet({required this.controller});

  final BrowserController controller;

  @override
  State<_SearchSheet> createState() => _SearchSheetState();
}

class _SearchSheetState extends State<_SearchSheet> {
  final _text = TextEditingController();
  final _focus = FocusNode();

  String? _clipboard;
  bool _clipboardChecked = false;

  @override
  void initState() {
    super.initState();
    _loadClipboard();
    // 原版 `task(100)` 延后唤起键盘：等 BottomSheet 展开动画结束再抢焦点，
    // 否则 IME 会在动画中途弹出、面板被顶一下。
    Future<void>.delayed(const Duration(milliseconds: 260), () {
      if (!mounted) return;
      // 这 260ms 里用户可能已经侧滑返回了，此时再 requestFocus 会把输入法
      // 硬弹出来（面板都下去了，键盘还在）。
      if (PredictiveBackCoordinator.instance.value > 0) return;
      _focus.requestFocus();
    });
  }

  @override
  void dispose() {
    _text.dispose();
    _focus.dispose();
    super.dispose();
  }

  Future<void> _loadClipboard() async {
    String? value;
    try {
      final data = await Clipboard.getData(Clipboard.kTextPlain);
      value = data?.text?.trim();
    } catch (_) {
      value = null;
    }
    if (!mounted) return;
    setState(() {
      _clipboard = (value == null || value.isEmpty) ? null : value;
      _clipboardChecked = true;
    });
  }

  void _close() {
    // 先把焦点放掉再收面板：否则 pop 动画期间 TextField 仍是焦点，
    // 键盘会在面板退场途中弹出来。
    FocusScope.of(context).unfocus();
    Navigator.of(context).maybePop();
  }

  void _submit() {
    final value = _text.text.trim();
    if (value.isEmpty) {
      _focus.requestFocus();
      return;
    }
    HapticFeedback.selectionClick();
    // 先收面板再跳转：原版也是 dismiss 后由 webView 接管，避免玻璃面板
    // 采样到正在加载的网页首帧。
    _close();
    widget.controller.openAddress(value);
  }

  void _openUrl(String url) {
    if (url.isEmpty) return;
    HapticFeedback.selectionClick();
    _close();
    widget.controller.openAddress(url);
  }

  void _useClipboard() {
    final value = _clipboard;
    if (value == null) return;
    _text.value = TextEditingValue(
      text: value,
      selection: TextSelection.collapsed(offset: value.length),
    );
    setState(() {});
    _focus.requestFocus();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final fg = isDark ? Colors.white : const Color(0xFF141418);
    final screen = MediaQuery.sizeOf(context);
    final keyboard = MediaQuery.viewInsetsOf(context).bottom;
    final height = ((screen.height - keyboard) * 0.82).clamp(
      320.0,
      screen.height,
    );

    final content = ConstrainedBox(
      // 面板高度跟随内容：历史/书签为空时只占屏幕下半部分，
      // 不会顶到 82% 留下一大片空白（原版是 wrap_content + 最大值）。
      constraints: BoxConstraints(maxHeight: height),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // 拖拽手柄：25% 屏宽、5dp 高、前景色 50% 透明度
          Container(
            width: screen.width * 0.25,
            height: 5,
            margin: const EdgeInsets.only(top: 15, bottom: 5),
            decoration: BoxDecoration(
              color: fg.withValues(alpha: 0.3),
              borderRadius: BorderRadius.circular(18),
            ),
          ),
          // 输入行：返回钮内嵌在输入卡里（原版 hideSearchViewButton），
          // 右侧是反色「搜索」按钮（原版 searchTextOrUrlButton）。
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 10, 20, 6),
            child: Row(
              children: [
                Expanded(
                  child: MiuixTextField(
                    controller: _text,
                    focusNode: _focus,
                    label: '搜索或输入网址',
                    singleLine: true,
                    textInputAction: TextInputAction.search,
                    onChanged: (_) => setState(() {}),
                    onSubmitted: (_) => _submit(),
                    insideMargin: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 12,
                    ),
                    cornerRadius: 15,
                    colors: MiuixTextFieldColors(
                      backgroundColor: fg.withValues(alpha: 0.07),
                      labelColor: fg.withValues(alpha: 0.42),
                      // 聚焦描边跟前景走（淡灰），不用主题蓝：
                      // 这块玻璃偏冷，蓝描边会把整行衬得很突兀。
                      borderColor: fg.withValues(alpha: 0.3),
                    ),
                    leadingIcon: GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onTap: _close,
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(14, 4, 10, 4),
                        child: MiuixIcon(
                          vector: MiuixIcons.os4.back,
                          size: 22,
                          tint: fg,
                          contentDescription: '收起搜索',
                        ),
                      ),
                    ),
                    trailingIcon: _text.text.isEmpty
                        ? null
                        : GestureDetector(
                            behavior: HitTestBehavior.opaque,
                            onTap: () {
                              _text.clear();
                              setState(() {});
                              _focus.requestFocus();
                            },
                            child: Padding(
                              padding: const EdgeInsets.fromLTRB(8, 4, 14, 4),
                              child: MiuixIcon(
                                vector: MiuixIcons.basic.searchCleanup,
                                size: 18,
                                tint: fg.withValues(alpha: 0.45),
                                contentDescription: '清空',
                              ),
                            ),
                          ),
                  ),
                ),
                const SizedBox(width: 10),
                MiuixButton(
                  onPressed: _submit,
                  minWidth: 0,
                  minHeight: 0,
                  cornerRadius: 16,
                  insideMargin: EdgeInsets.zero,
                  colors: MiuixButtonColors(
                    color: fg.withValues(alpha: 0.92),
                    disabledColor: fg.withValues(alpha: 0.3),
                    contentColor: isDark ? Colors.black : Colors.white,
                    disabledContentColor: isDark
                        ? Colors.black54
                        : Colors.white70,
                  ),
                  // 尺寸交给 SizedBox、文字交给 Center：MiuixButton 的
                  // minWidth/minHeight 只撑背景，不给内部对齐，
                  // 直接把 Text 丢进去会贴在左上角（真机上就是这样歪的）。
                  child: SizedBox(
                    width: 72,
                    // 与输入框同高（16sp 文字 + 上下 12 内边距 ≈ 52dp）
                    height: 52,
                    child: Center(
                      child: Text(
                        '搜索',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: isDark ? Colors.black : Colors.white,
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 10, 20, 5),
            child: MiuixHorizontalDivider(
              thickness: 1,
              color: fg.withValues(alpha: 0.1),
            ),
          ),
          Flexible(
            child: SingleChildScrollView(
              padding: EdgeInsets.fromLTRB(
                20,
                0,
                20,
                20 + MediaQuery.paddingOf(context).bottom,
              ),
              physics: const BouncingScrollPhysics(),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // 原版这里还有一块「书签建议」图标网格，但本应用的书签
                  // 就是首页那条「快捷访问」，放进面板会和主页重复，
                  // 因此只保留剪贴板与历史两段。
                  _SectionTitle('剪贴板内容', fg: fg),
                  _ClipboardCard(
                    text: _clipboard,
                    checked: _clipboardChecked,
                    fg: fg,
                    onTap: _useClipboard,
                  ),
                  _SectionTitle('历史记录', fg: fg),
                  _HistoryCard(
                    history: widget.controller.history,
                    fg: fg,
                    onOpen: _openUrl,
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );

    return Padding(
      // 键盘弹起时整块面板上移，输入框不会被 IME 盖住。
      padding: EdgeInsets.only(bottom: keyboard),
      child: RoamGlassSheetSurface(child: content),
    );
  }
}

/// 区块标题：15sp / w700 / 上下 14+6。原版 `书签建议` 等 TextView 的规格。
class _SectionTitle extends StatelessWidget {
  const _SectionTitle(this.text, {required this.fg});

  final String text;
  final Color fg;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 14, bottom: 6),
      child: Text(
        text,
        style: TextStyle(
          fontSize: 15,
          fontWeight: FontWeight.bold,
          color: fg.withValues(alpha: 0.92),
        ),
      ),
    );
  }
}

/// 剪贴板内容卡：原版 21dp 圆角、内边距 15dp。
class _ClipboardCard extends StatelessWidget {
  const _ClipboardCard({
    required this.text,
    required this.checked,
    required this.fg,
    required this.onTap,
  });

  final String? text;
  final bool checked;
  final Color fg;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final empty = text == null;
    return MiuixCard(
      cornerRadius: 21,
      insideMargin: EdgeInsets.zero,
      colors: MiuixCardColors(
        color: fg.withValues(alpha: 0.07),
        contentColor: fg,
      ),
      onPressed: empty ? null : onTap,
      feedbackType: MiuixPressFeedbackType.sink,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 14),
        child: Text(
          empty ? (checked ? '剪贴板最新一条内容将在此处展示。' : '正在读取剪贴板…') : text!,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            fontSize: 14,
            height: 1.35,
            color: fg.withValues(alpha: empty ? 0.45 : 0.86),
          ),
        ),
      ),
    );
  }
}

/// 历史记录卡：270dp 高，最多显示 6 条（原版 ListView 同样固定 270dp）。
class _HistoryCard extends StatelessWidget {
  const _HistoryCard({
    required this.history,
    required this.fg,
    required this.onOpen,
  });

  final List<HistoryEntry> history;
  final Color fg;
  final ValueChanged<String> onOpen;

  @override
  Widget build(BuildContext context) {
    if (history.isEmpty) {
      return MiuixCard(
        cornerRadius: 21,
        insideMargin: EdgeInsets.zero,
        colors: MiuixCardColors(
          color: fg.withValues(alpha: 0.07),
          contentColor: fg,
        ),
        child: SizedBox(
          height: 96,
          child: Center(
            child: Text(
              '没有历史记录',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: fg.withValues(alpha: 0.4),
              ),
            ),
          ),
        ),
      );
    }
    final items = history.take(6).toList();
    return MiuixCard(
      cornerRadius: 21,
      insideMargin: EdgeInsets.zero,
      colors: MiuixCardColors(
        color: fg.withValues(alpha: 0.07),
        contentColor: fg,
      ),
      child: SizedBox(
        height: 270,
        child: ListView.separated(
          padding: const EdgeInsets.symmetric(vertical: 6),
          physics: const BouncingScrollPhysics(),
          itemCount: items.length,
          separatorBuilder: (_, _) => Padding(
            padding: const EdgeInsets.only(left: 15, right: 15),
            child: MiuixHorizontalDivider(
              thickness: 0.75,
              color: fg.withValues(alpha: 0.08),
            ),
          ),
          itemBuilder: (context, index) {
            final entry = items[index];
            final host = Uri.tryParse(entry.url)?.host ?? '';
            return InkWell(
              onTap: () => onOpen(entry.url),
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 15,
                  vertical: 10,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      entry.title.isEmpty ? entry.url : entry.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                        color: fg.withValues(alpha: 0.9),
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      host.isEmpty ? entry.url : host,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 12,
                        color: fg.withValues(alpha: 0.45),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}

