// 工具栏自定义：编辑三条杠菜单里的功能项（显隐 / 排序）。
// ignore_for_file: deprecated_member_use

import 'package:flutter/material.dart';

import '../../state/browser_controller.dart';
import '../../theme/roam_theme.dart';
import '../widgets/roam_chrome.dart';

/// 全部工具栏功能目录（id 与 menu_sheet 的 _catalog 保持一致）。
const toolbarCatalog = <(String, String, String)>[
  ('history', '历史记录', 'assets/images/history.png'),
  ('ua', '浏览器标识', 'assets/images/device.png'),
  ('copy_link', '复制链接', 'assets/images/clipboard.png'),
  ('settings', '设置', 'assets/images/settings_menu.png'),
  ('qrcode', '二维码', 'assets/images/qrcode.png'),
  ('incognito', '无痕浏览', 'assets/images/eye_off.png'),
  ('translate', '翻译', 'assets/images/translate.png'),
  ('sniffer', '资源嗅探', 'assets/images/stacks_hardware_turbo.png'),
  ('bookmark_add', '添加书签', 'assets/images/bookmark_add.png'),
  ('drive', '驾驶模式', 'assets/images/car.png'),
  ('fullscreen', '全屏', 'assets/images/fullscreen.png'),
  ('landscape', '横屏', 'assets/images/wize.png'),
  ('screenshot_block', '禁止截屏', 'assets/images/phone-lock.png'),
  ('metaso', '秘塔AI', 'assets/images/head.png'),
  ('cookie', 'Cookie 管理', 'assets/images/cookie.png'),
  ('javascript', 'JavaScript', 'assets/images/JavaScript.png'),
  ('terminal', '终端', 'assets/images/terminal.png'),
  ('view_source', '源代码', 'assets/images/viewSource.png'),
  ('print', '打印网页', 'assets/images/print.png'),
];

class ToolbarCustomizePage extends StatefulWidget {
  const ToolbarCustomizePage({super.key, required this.controller});

  final BrowserController controller;

  @override
  State<ToolbarCustomizePage> createState() => _ToolbarCustomizePageState();
}

class _ToolbarCustomizePageState extends State<ToolbarCustomizePage> {
  late List<String> _enabled;

  @override
  void initState() {
    super.initState();
    _enabled = [...widget.controller.settings.toolbarItems];
  }

  Future<void> _save() async {
    await widget.controller.updateSettings(
      widget.controller.settings.copyWith(toolbarItems: _enabled),
    );
    if (mounted) setState(() {});
  }

  void _toggle(String id) {
    setState(() {
      if (_enabled.contains(id)) {
        _enabled.remove(id);
      } else {
        _enabled.add(id);
      }
    });
    _save();
  }

  void _move(int index, int delta) {
    final item = _enabled[index];
    final target = index + delta;
    if (target < 0 || target >= _enabled.length) return;
    setState(() {
      _enabled
        ..removeAt(index)
        ..insert(target, item);
    });
    _save();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final fg = isDark ? RoamColors.textPrimary : RoamColors.dayInk;

    // 已启用（按当前顺序） + 未启用（目录里剩余）
    final enabledRows = <(String, String, String)>[
      for (final id in _enabled)
        for (final entry in toolbarCatalog)
          if (entry.$1 == id) entry,
    ];
    final disabledRows = <(String, String, String)>[
      for (final entry in toolbarCatalog)
        if (!_enabled.contains(entry.$1)) entry,
    ];

    return RoamPageScaffold(
      title: '工具栏自定义',
      child: ListView(
        padding: EdgeInsets.fromLTRB(
          25,
          RoamPageScaffold.topPadding(context) + 10,
          25,
          24,
        ),
        children: [
          Text(
            '显示的功能（拖动箭头调整顺序）',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: fg.withValues(alpha: 0.6),
            ),
          ),
          const SizedBox(height: 8),
          if (enabledRows.isEmpty)
            Padding(
              padding: const EdgeInsets.all(12),
              child: Text(
                '还没有启用任何功能',
                style: TextStyle(
                  fontSize: 13,
                  color: fg.withValues(alpha: 0.4),
                ),
              ),
            ),
          for (int i = 0; i < enabledRows.length; i++)
            _CustomizeRow(
              entry: enabledRows[i],
              enabled: true,
              isDark: isDark,
              onToggle: () => _toggle(enabledRows[i].$1),
              onUp: i > 0 ? () => _move(i, -1) : null,
              onDown: i < enabledRows.length - 1 ? () => _move(i, 1) : null,
            ),
          const SizedBox(height: 18),
          Text(
            '未显示的功能',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: fg.withValues(alpha: 0.6),
            ),
          ),
          const SizedBox(height: 8),
          for (final entry in disabledRows)
            _CustomizeRow(
              entry: entry,
              enabled: false,
              isDark: isDark,
              onToggle: () => _toggle(entry.$1),
            ),
        ],
      ),
    );
  }
}

class _CustomizeRow extends StatelessWidget {
  const _CustomizeRow({
    required this.entry,
    required this.enabled,
    required this.isDark,
    required this.onToggle,
    this.onUp,
    this.onDown,
  });

  final (String, String, String) entry;
  final bool enabled;
  final bool isDark;
  final VoidCallback onToggle;
  final VoidCallback? onUp;
  final VoidCallback? onDown;

  @override
  Widget build(BuildContext context) {
    final fg = isDark ? RoamColors.textPrimary : RoamColors.dayInk;
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: isDark ? RoamColors.cardDark : RoamColors.cardLight,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Image.asset(
            entry.$3,
            width: 22,
            height: 22,
            color: enabled ? fg : fg.withValues(alpha: 0.35),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              entry.$2,
              style: TextStyle(
                fontSize: 14,
                color: enabled ? fg : fg.withValues(alpha: 0.4),
              ),
            ),
          ),
          if (onUp != null)
            IconButton(
              onPressed: onUp,
              visualDensity: VisualDensity.compact,
              icon: Icon(
                Icons.arrow_upward,
                size: 18,
                color: fg.withValues(alpha: 0.55),
              ),
            ),
          if (onDown != null)
            IconButton(
              onPressed: onDown,
              visualDensity: VisualDensity.compact,
              icon: Icon(
                Icons.arrow_downward,
                size: 18,
                color: fg.withValues(alpha: 0.55),
              ),
            ),
          Switch(
            value: enabled,
            activeColor: Colors.white,
            activeTrackColor: const Color(0xFF3482FF),
            onChanged: (_) => onToggle(),
          ),
        ],
      ),
    );
  }
}
