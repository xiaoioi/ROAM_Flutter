// 底栏自定义：编辑浏览器底部导航栏的按钮（显隐 / 排序）。
// ignore_for_file: deprecated_member_use

import 'package:flutter/material.dart';

import '../../state/browser_controller.dart';
import '../../theme/roam_theme.dart';
import '../widgets/roam_chrome.dart';

/// 底栏功能目录（id 与 browser_shell 的 _RoamBottomBar 保持一致）。
const bottomBarCatalog = <(String, String, String)>[
  ('back', '返回', 'assets/toolbar/webkit_back.png'),
  ('forward', '前进', 'assets/toolbar/webkit_forward.png'),
  ('home', '主页', 'assets/toolbar/webkit_home.png'),
  ('tabs', '标签页', 'assets/toolbar/multi_task.png'),
  ('menu', '菜单', 'assets/toolbar/toolbar.png'),
  ('refresh', '刷新', 'assets/toolbar/refresh_url.png'),
];

class BottomBarCustomizePage extends StatefulWidget {
  const BottomBarCustomizePage({super.key, required this.controller});

  final BrowserController controller;

  @override
  State<BottomBarCustomizePage> createState() => _BottomBarCustomizePageState();
}

class _BottomBarCustomizePageState extends State<BottomBarCustomizePage> {
  late List<String> _enabled;

  @override
  void initState() {
    super.initState();
    _enabled = [...widget.controller.settings.bottomBarItems];
  }

  Future<void> _save() async {
    await widget.controller.updateSettings(
      widget.controller.settings.copyWith(bottomBarItems: _enabled),
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

    final enabledRows = <(String, String, String)>[
      for (final id in _enabled)
        for (final entry in bottomBarCatalog)
          if (entry.$1 == id) entry,
    ];
    final disabledRows = <(String, String, String)>[
      for (final entry in bottomBarCatalog)
        if (!_enabled.contains(entry.$1)) entry,
    ];

    return RoamPageScaffold(
      title: '底栏自定义',
      child: ListView(
        padding: EdgeInsets.fromLTRB(
          25,
          RoamPageScaffold.contentTopPadding + 10,
          25,
          24,
        ),
        children: [
          Text(
            '显示的按钮（拖动箭头调整顺序）',
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
                '还没有启用任何按钮',
                style: TextStyle(
                  fontSize: 13,
                  color: fg.withValues(alpha: 0.4),
                ),
              ),
            ),
          for (int i = 0; i < enabledRows.length; i++)
            _BarRow(
              entry: enabledRows[i],
              enabled: true,
              isDark: isDark,
              onToggle: () => _toggle(enabledRows[i].$1),
              onUp: i > 0 ? () => _move(i, -1) : null,
              onDown: i < enabledRows.length - 1 ? () => _move(i, 1) : null,
            ),
          const SizedBox(height: 18),
          Text(
            '未显示的按钮',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: fg.withValues(alpha: 0.6),
            ),
          ),
          const SizedBox(height: 8),
          for (final entry in disabledRows)
            _BarRow(
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

class _BarRow extends StatelessWidget {
  const _BarRow({
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
