// ignore_for_file: deprecated_member_use

import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_miuix/miuix.dart';

import '../../state/browser_controller.dart';
import '../glass/layout_motion_repaint.dart';
import '../glass/os4_glass_token.dart';
import '../glass/roam_glass.dart';
import '../glass/roam_glass_bridge.dart';
import '../widgets/glass_controls.dart';
import '../widgets/predictive_back.dart';
import '../pages/history_page.dart';
import '../pages/settings_page.dart';
import '../pages/translate_page.dart';

/// 底部菜单：ROAM 新版工具栏 —— 时间头 + 「工具栏」标题 + 4 列功能网格
/// + 页点。玻璃为 miuix 柔光玻璃（HyperOS），图标底座浅色圆。
///
/// [useSnapshot] 指明下层内容能否被离屏快照捕获：
///  - true（首页）：壁纸是普通 Flutter 图层，玻璃用 miuix 折射 shader；
///  - false（网页）：WebView 是 platform view，`toImage` 快照里没有它的
///    像素，shader 会拿到空纹理把面板画成全透明，必须改走实时
///    [BackdropFilter] 磨砂。
Future<void> showMenuSheet({
  required BuildContext context,
  required BrowserController controller,
  bool? isDark,
  bool useSnapshot = true,
}) {
  final dark = isDark ?? Theme.of(context).brightness == Brightness.dark;
  return showModalBottomSheet<void>(
    context: context,
    backgroundColor: Colors.transparent,
    isScrollControlled: true,
    barrierColor: Colors.black.withValues(alpha: 0.35),
    builder: (sheetContext) => PredictiveBackScope(
      style: PredictiveBackStyle.sheet,
      onCommit: () => Navigator.of(sheetContext).maybePop(),
      child: _MenuPanel(
        controller: controller,
        isDark: dark,
        useSnapshot: useSnapshot,
      ),
    ),
  );
}

class _MenuPanel extends StatefulWidget {
  const _MenuPanel({
    required this.controller,
    required this.isDark,
    required this.useSnapshot,
  });

  final BrowserController controller;
  final bool isDark;
  final bool useSnapshot;

  @override
  State<_MenuPanel> createState() => _MenuPanelState();
}

class _MenuPanelState extends State<_MenuPanel> {
  final _pages = PageController();
  int _page = 0;

  @override
  void dispose() {
    _pages.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // 玻璃参数（材质开关/玻璃类型/深色）变化时实时重建
    return ListenableBuilder(
      listenable: GlassRuntime.repaint,
      builder: (context, _) => _buildPanel(context),
    );
  }

  Widget _buildPanel(BuildContext context) {
    // 明暗完全由调用方（BrowserShell 按 tab.isHome 与主题）传入。
    // 不再叠加全局 darkUi：那个值会被首页壁纸置成 true，污染其它页面。
    final isDark = widget.isDark;
    final fg = isDark ? Colors.white : const Color(0xFF0B1526);
    final now = DateTime.now();
    const weeks = ['周一', '周二', '周三', '周四', '周五', '周六', '周日'];
    final height = MediaQuery.sizeOf(context).height * 0.70;
    final useGlass = GlassRuntime.material.value;

    // 工具栏自定义：按设置里的顺序/显隐生成条目
    final all = _catalog(context);
    final ids = widget.controller.settings.toolbarItems;
    final items = [
      for (final id in ids)
        if (all[id] != null) all[id]!,
    ];
    // 两页：每页 12 个（4 列 × 3 行），不足则单页
    final pageOne = items.length > 12 ? items.sublist(0, 12) : items;
    final pageTwo = items.length > 12 ? items.sublist(12) : <_MenuEntry>[];
    final hasSecond = pageTwo.isNotEmpty;

    final Widget content = SizedBox(
      height: height,
      child: Column(
        children: [
          // 拖动条：25% 宽、5dp 高
          Container(
            width: MediaQuery.sizeOf(context).width * 0.25,
            height: 5,
            margin: const EdgeInsets.only(top: 15, bottom: 5),
            decoration: BoxDecoration(
              color: fg.withValues(alpha: 0.3),
              borderRadius: BorderRadius.circular(18),
            ),
          ),
          // 时间 + 日期（图2：大字时间 + 右侧两行日期）
          Padding(
            padding: const EdgeInsets.only(left: 22, top: 12),
            child: Row(
              children: [
                Text(
                  '${now.hour.toString().padLeft(2, '0')}:'
                  '${now.minute.toString().padLeft(2, '0')}',
                  style: TextStyle(
                    fontSize: 32,
                    fontWeight: FontWeight.bold,
                    color: fg,
                    height: 1,
                  ),
                ),
                const SizedBox(width: 8),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      '${now.month}月${now.day}日',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: fg,
                        height: 1.2,
                      ),
                    ),
                    Text(
                      weeks[now.weekday - 1],
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: fg,
                        height: 1.2,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          // 「工具栏」标题
          Padding(
            padding: const EdgeInsets.only(left: 22, top: 8, bottom: 2),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Text(
                '工具栏',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: fg.withValues(alpha: 0.7),
                ),
              ),
            ),
          ),
          // 图2：网格直接坐在玻璃上，不再套内层卡片
          Expanded(
            child: PageView(
              controller: _pages,
              onPageChanged: (value) => setState(() => _page = value),
              children: [
                _MenuGrid(items: pageOne, fg: fg),
                if (hasSecond) _MenuGrid(items: pageTwo, fg: fg),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.only(top: 4, bottom: 14),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _Dot(active: _page == 0, isDark: isDark),
                if (hasSecond) ...[
                  const SizedBox(width: 12),
                  _Dot(active: _page == 1, isDark: isDark),
                ],
              ],
            ),
          ),
          SizedBox(height: MediaQuery.paddingOf(context).bottom + 8),
        ],
      ),
    );

    return ClipRRect(
      borderRadius: const BorderRadius.vertical(top: Radius.circular(15)),
      child: useGlass
          ? _PanelGlass(
              isDark: isDark,
              useSnapshot: widget.useSnapshot,
              child: content,
            )
          : ColoredBox(
              color: isDark ? const Color(0xFF1C1C1E) : Colors.white,
              child: content,
            ),
    );
  }

  /// 功能目录：id → 条目。工具栏自定义页与这里共用 id。
  Map<String, _MenuEntry> _catalog(BuildContext context) {
    final controller = widget.controller;
    final tab = controller.activeTab;
    return {
      'history': _MenuEntry(
        icon: 'assets/images/history.png',
        label: '历史记录',
        onTap: () => _push(HistoryPage(controller: controller)),
      ),
      'ua': _MenuEntry(
        icon: 'assets/images/device.png',
        label: '浏览器标识',
        onTap: () => _toggleDesktop(context),
      ),
      'copy_link': _MenuEntry(
        icon: 'assets/images/clipboard.png',
        label: '复制链接',
        onTap: () {
          final url = tab?.url ?? '';
          if (url.isEmpty) {
            _toast(context, '当前没有可复制的链接');
            return;
          }
          Clipboard.setData(ClipboardData(text: url));
          _close(context);
          _toast(context, '已复制链接');
        },
      ),
      'settings': _MenuEntry(
        icon: 'assets/images/settings_menu.png',
        label: '设置',
        onTap: () => _push(SettingsPage(controller: controller)),
      ),
      'qrcode': _MenuEntry(
        icon: 'assets/images/qrcode.png',
        label: '二维码',
        onTap: () => _toast(context, '二维码功能开发中'),
      ),
      'incognito': _MenuEntry(
        icon: 'assets/images/eye_off.png',
        label: '无痕浏览',
        onTap: () {
          _close(context);
          controller.newTab(incognito: true);
        },
      ),
      'translate': _MenuEntry(
        icon: 'assets/images/translate.png',
        label: '翻译',
        onTap: () => _push(TranslatePage(controller: controller)),
      ),
      'sniffer': _MenuEntry(
        icon: 'assets/images/stacks_hardware_turbo.png',
        label: '资源嗅探',
        onTap: () => _toast(context, '资源嗅探功能开发中'),
      ),
      'bookmark_add': _MenuEntry(
        icon: 'assets/images/bookmark_add.png',
        label: '添加书签',
        onTap: () {
          if (tab == null || tab.isHome) {
            _toast(context, '请先打开一个网页');
            return;
          }
          controller.toggleBookmarkCurrent();
          _close(context);
          _toast(context, '已更新书签');
        },
      ),
      'drive': _MenuEntry(
        icon: 'assets/images/car.png',
        label: '驾驶模式',
        onTap: () => _toast(context, '驾驶模式开发中'),
      ),
      'fullscreen': _MenuEntry(
        icon: 'assets/images/fullscreen.png',
        label: '全屏',
        onTap: () => _toast(context, '全屏功能开发中'),
      ),
      'landscape': _MenuEntry(
        icon: 'assets/images/wize.png',
        label: '横屏',
        onTap: () => _toast(context, '横屏模式开发中'),
      ),
      'screenshot_block': _MenuEntry(
        icon: 'assets/images/phone-lock.png',
        label: '禁止截屏',
        onTap: () => _toast(context, '禁止截屏开发中'),
      ),
      'metaso': _MenuEntry(
        icon: 'assets/images/head.png',
        label: '秘塔AI',
        onTap: () => _toast(context, 'AI 功能开发中'),
      ),
      'cookie': _MenuEntry(
        icon: 'assets/images/cookie.png',
        label: 'Cookie 管理',
        onTap: () async {
          _close(context);
          await controller.clearBrowsingData(history: true, downloads: false);
        },
      ),
      'javascript': _MenuEntry(
        icon: 'assets/images/JavaScript.png',
        label: 'JavaScript',
        onTap: () {
          final enabled = !controller.settings.javascriptEnabled;
          controller.setJavascriptEnabled(enabled);
          _close(context);
          _toast(context, enabled ? '已启用 JavaScript' : '已停用 JavaScript');
        },
      ),
      'terminal': _MenuEntry(
        icon: 'assets/images/terminal.png',
        label: '终端',
        onTap: () => _toast(context, '终端功能开发中'),
      ),
      'view_source': _MenuEntry(
        icon: 'assets/images/viewSource.png',
        label: '源代码',
        onTap: () => _toast(context, '查看源代码开发中'),
      ),
      'print': _MenuEntry(
        icon: 'assets/images/print.png',
        label: '打印网页',
        onTap: () => _toast(context, '打印功能开发中'),
      ),
    };
  }

  void _toggleDesktop(BuildContext context) {
    final enabled = !widget.controller.settings.desktopMode;
    widget.controller.setDesktopMode(enabled);
    _close(context);
    _toast(context, enabled ? '已切换到桌面模式' : '已切换到移动模式');
  }

  void _push(Widget page) {
    final navigator = Navigator.of(context);
    navigator.pop();
    navigator.push(MaterialPageRoute<void>(builder: (_) => page));
  }

  void _close(BuildContext context) {
    if (Navigator.of(context).canPop()) Navigator.of(context).pop();
  }

  void _toast(BuildContext context, String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..clearSnackBars()
      ..showSnackBar(
        SnackBar(
          content: Text(message),
          behavior: SnackBarBehavior.floating,
          duration: const Duration(milliseconds: 1400),
        ),
      );
  }
}

/// 工具栏玻璃：flutter_miuix 的 OS4 柔光玻璃，图2 的通透磨砂。
class _PanelGlass extends StatelessWidget {
  const _PanelGlass({
    required this.isDark,
    required this.useSnapshot,
    required this.child,
  });

  final bool isDark;

  /// 下层内容能否被离屏快照捕获（首页 true / 网页 false）。
  final bool useSnapshot;
  final Widget child;

  /// 面板级薄玻璃参数。
  ///
  /// 工具栏是 70% 屏高的大面积，不能用 small（按钮级）样式：
  /// `commonSmallThin` 的 `reflect.lighten = 2.0` 在这么大面积上会把背景
  /// 高光整片放大成雾状泛光（「光全散开」）；`commonMediumThinLow` 是
  /// MIUI 的面板级参数（lighten 1.0、ior 2.0），折射更强、泛光收敛。
  /// 模糊半径再从 36 收到 18，保留一点背景轮廓，不至于糊成一团。
  static final MiuixGlassStyle _panelStyle = () {
    final base = MiuixGlassStyles.commonMediumThinLow;
    return base.copyWith(
      blend: base.blend.copyWith(saturation: 1.2),
      blur: const MiuixGlassBlur(small: 18, big: 260),
    );
  }();

  @override
  Widget build(BuildContext context) {
    const corner = BorderRadius.vertical(top: Radius.circular(15));
    const shape = MiuixGlassShape(borderRadius: corner);

    // 玻璃的采样 UV 是在 paint 里读的；面板被 BottomSheet 拖拽或
    // 预测式返回的 Transform 带走时子树不会重绘，背景就会停在原处。
    // 这一层把「位置变了」变成一次重绘信号。
    return LayoutMotionRepaint(
      child: ListenableBuilder(
        listenable: GlassRuntime.repaint,
        builder: (context, _) {
        final customGlass = GlassRuntime.customGlass.value;

        // 网页 tab：WebView 是 platform view，离屏快照（toImage）里没有它的
        // 像素——shader 采样到空纹理，整块面板会画成透明。这里改用实时
        // BackdropFilter（在图层合成时取背景，platform view 也能被模糊），
        // 再叠实色面 + 描边/rim，得到可读的磨砂玻璃。
        // 折射在这里无法实现，属于平台限制下的降级。
        if (!useSnapshot) {
          if (customGlass) {
            return ClipRRect(
              borderRadius: corner,
              child: BackdropFilter(
                filter: ui.ImageFilter.blur(sigmaX: 18, sigmaY: 18),
                child: ColoredBox(
                  color: isDark
                      ? const Color(0xE62A2A2C)
                      : Colors.white.withValues(alpha: 0.76),
                  child: child,
                ),
              ),
            );
          }
          return ClipRRect(
            borderRadius: corner,
            child: BackdropFilter(
              filter: ui.ImageFilter.blur(sigmaX: 18, sigmaY: 18),
              child: MiuixGlass(
                style: _panelStyle,
                // 平台限制下不冒充折射：关掉 shading 走磨砂面。
                shading: false,
                fill: isDark
                    ? const Color(0xE62A2A2C)
                    : Colors.white.withValues(alpha: 0.76),
                shape: shape,
                child: child,
              ),
            ),
          );
        }

        // 自绘 OS4 柔光玻璃（默认引擎）。面板四角只圆上面两个——
        // 底边贴屏幕下沿，用 borderRadius 而不是统一 radius。
        if (customGlass) {
          return ClipRRect(
            borderRadius: corner,
            child: RoamGlassSceneBridge(
              backdrop: miuixBackdrop,
              child: RoamGlass(
                token: Os4GlassToken.commonSmallRegular,
                borderRadius: corner,
                child: child,
              ),
            ),
          );
        }

        // miuix 柔光玻璃（可切换回的旧引擎）——仿生 GlassStyle。
        // 注意 shading 模式会忽略 fill；alpha 是淡入动画进度而非透明度。
        return MiuixGlass(
          backdrop: miuixBackdrop,
          style: _panelStyle,
          shading: true,
          shape: shape,
          child: child,
        );
        },
      ),
    );
  }
}

class _MenuEntry {
  const _MenuEntry({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final String icon;
  final String label;
  final VoidCallback onTap;
}

class _MenuGrid extends StatelessWidget {
  const _MenuGrid({required this.items, required this.fg});

  final List<_MenuEntry> items;
  final Color fg;

  @override
  Widget build(BuildContext context) {
    return GridView.builder(
      physics: const NeverScrollableScrollPhysics(),
      padding: const EdgeInsets.only(top: 8),
      itemCount: items.length,
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 4,
        mainAxisExtent: 84,
      ),
      itemBuilder: (context, index) {
        final item = items[index];
        return Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: item.onTap,
                child: Container(
                  width: 58,
                  height: 58,
                  decoration: BoxDecoration(
                    // 图2：图标底座是浅色半透明圆
                    color: fg.withValues(alpha: 0.13),
                    shape: BoxShape.circle,
                    border: Border.all(color: fg.withValues(alpha: 0.10)),
                  ),
                  padding: const EdgeInsets.all(14),
                  child: Image.asset(item.icon, color: fg),
                ),
              ),
              const SizedBox(height: 5),
              Text(
                item.label,
                maxLines: 1,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: fg,
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _Dot extends StatelessWidget {
  const _Dot({required this.active, required this.isDark});

  final bool active;
  final bool isDark;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 9,
      height: 9,
      decoration: BoxDecoration(
        color: active
            ? const Color(0xFFFF2C1E)
            : (isDark ? Colors.white24 : Colors.black26),
        shape: BoxShape.circle,
      ),
    );
  }
}
