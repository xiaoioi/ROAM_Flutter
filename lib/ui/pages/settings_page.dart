// ignore_for_file: deprecated_member_use

import 'package:flutter/material.dart';
import 'package:flutter_miuix/miuix.dart';

import '../../models/browser_models.dart';
import '../../state/browser_controller.dart';
import '../../theme/roam_theme.dart';
import '../widgets/confirm.dart';
import '../widgets/glass_controls.dart';
import '../widgets/roam_chrome.dart';
import '../widgets/hyperos_top_bar.dart';
import '../widgets/roam_search_bar.dart';
import '../widgets/roam_sheet.dart';
import 'about_page.dart';
import 'ai_settings_page.dart';
import 'appearance_page.dart';
import 'biometrics_page.dart';
import 'bookmarks_page.dart';
import 'bottom_bar_customize_page.dart';
import 'browser_settings_page.dart';
import 'downloads_page.dart';
import 'history_page.dart';
import 'legal_page.dart';
import 'site_behavior_page.dart';
import 'toolbar_customize_page.dart';

/// 设置。
/// 分组与文案取自 pages/Settings/main.lua：
/// 账号卡（50dp 圆头像 / 21sp 粗体用户名 / 12sp 副标题）、关于行（36dp 圆角 9 图标），
/// 各组标题 15sp 粗体、卡片 15dp 圆角、行内 25dp 图标 + 15sp 文案 + 28dp 箭头，
/// 底部为 50dp 的搜索设置项输入条。
class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key, required this.controller});

  final BrowserController controller;

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  final _searchController = TextEditingController();
  final _searchFocus = FocusNode();
  String _query = '';

  /// 搜索模式：整条顶栏替换成安全服务同款搜索栏（56dp）。
  bool _searching = false;

  BrowserController get _controller => widget.controller;

  @override
  void dispose() {
    _searchController.dispose();
    _searchFocus.dispose();
    super.dispose();
  }

  void _enterSearch() {
    setState(() => _searching = true);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _searchFocus.requestFocus();
    });
  }

  void _exitSearch() {
    if (!_searching) return;
    _searchFocus.unfocus();
    _searchController.clear();
    setState(() {
      _searching = false;
      _query = '';
    });
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final groups = _buildGroups(context);
    final query = _query.trim().toLowerCase();
    final visible = query.isEmpty
        ? groups
        : [
            for (final group in groups)
              _Group(group.title, [
                for (final item in group.items)
                  if (item.label.toLowerCase().contains(query) ||
                      (item.subtitle ?? '').toLowerCase().contains(query))
                    item,
              ]),
          ].where((group) => group.items.isNotEmpty).toList();

    return PopScope(
      // 搜索模式下按返回键先退出搜索，不直接退出设置页。
      canPop: !_searching,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _exitSearch();
      },
      child: RoamPageScaffold(
        title: _searching ? '' : '设置',
        topBar: _searching
            ? RoamSearchBar(
                controller: _searchController,
                focusNode: _searchFocus,
                onChanged: (value) => setState(() => _query = value),
                onCancel: _exitSearch,
              )
            : null,
        actions: [
          // 图 1 的两个圆钮：搜索（切到搜索栏）+ 更多
          HyperosBarAction(
            asset: 'assets/images/search_lc.png',
            tooltip: '搜索设置',
            onTap: _enterSearch,
          ),
          HyperosBarAction(
            asset: 'assets/images/dots.png',
            tooltip: '更多',
            onTap: () => _moreSheet(context),
          ),
        ],
        // 背景捕获已由 RoamPageScaffold 统一提供（底色 + 内容一起采样），
        // 这里再录一份只会让每帧多一次 toImage。
        child: ListView(
          padding: EdgeInsets.only(
            // 普通态让出悬浮顶栏；搜索态让出 56dp 搜索栏。
            top: _searching
                ? RoamSearchBar.height + 8
                : RoamPageScaffold.contentTopPadding,
            bottom: 16,
          ),
          physics: const BouncingScrollPhysics(),
          children: [
            if (query.isEmpty) _AccountCard(controller: _controller),
            for (final group in visible) ...[
              if (group.title.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.fromLTRB(25, 14, 25, 5),
                  child: MiuixSmallTitle(
                    group.title,
                    textColor: const Color(0xFF8E8E93),
                  ),
                ),
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 5,
                ),
                child: MiuixCard(
                  colors: MiuixCardColors(
                    color: isDark ? RoamColors.cardDark : RoamColors.cardLight,
                    contentColor: isDark
                        ? RoamColors.textPrimary
                        : RoamColors.dayInk,
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      for (int i = 0; i < group.items.length; i++) ...[
                        if (i > 0)
                          Divider(
                            height: 1,
                            indent: 52,
                            color: isDark
                                ? Colors.white.withValues(alpha: 0.06)
                                : Colors.black.withValues(alpha: 0.06),
                          ),
                        MiuixArrowPreference(
                          title: group.items[i].label,
                          startAction: Padding(
                            padding: const EdgeInsets.only(right: 10),
                            child: Image.asset(
                              group.items[i].icon,
                              width: 25,
                              height: 25,
                              color: isDark
                                  ? RoamColors.textPrimary
                                  : RoamColors.dayInk,
                            ),
                          ),
                          onClick: group.items[i].onTap,
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ],
            if (visible.isEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 80),
                child: Center(
                  child: Text(
                    '没有找到相关设置项',
                    style: TextStyle(
                      fontSize: 14,
                      color:
                          (isDark ? RoamColors.textPrimary : RoamColors.dayInk)
                              .withValues(alpha: 0.4),
                    ),
                  ),
                ),
              ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  List<_Group> _buildGroups(BuildContext context) {
    final themeLabel = switch (_controller.settings.themeMode) {
      AppThemeMode.light => '浅色模式',
      AppThemeMode.dark => '深色模式',
      AppThemeMode.system => '跟随系统',
    };
    return [
      _Group('', [
        _Item(
          icon: 'assets/images/bug.png',
          label: '实验性功能',
          subtitle: '桌面模式 · 恢复标签页',
          onTap: () => _experimental(context),
        ),
        _Item(
          icon: 'assets/images/internet.png',
          label: '设置为默认浏览器',
          onTap: () => _toast('请在系统设置的默认应用中选择星环'),
        ),
      ]),
      _Group('外观与通用设置', [
        _Item(
          icon: 'assets/images/ui.png',
          label: '外观与设计',
          subtitle: themeLabel,
          onTap: () => _open(AppearancePage(controller: _controller)),
        ),
        _Item(
          icon: 'assets/images/home.png',
          label: '主界面',
          subtitle: _controller.settings.searchEngine.label,
          onTap: () => _pickEngine(context),
        ),
        _Item(
          icon: 'assets/images/widget.png',
          label: '小组件管理',
          subtitle: '笔记 · 天气 · 相册 · 相机 · 日历',
          onTap: () => _hint(
            context,
            '小组件管理',
            '星环桌面小组件（笔记、天气、相册、相机、日历）由原版扩展模块提供，Flutter 重构版正在逐个接入。',
          ),
        ),
        _Item(
          icon: 'assets/images/view-quilt.png',
          label: '工具栏自定义',
          onTap: () => _open(ToolbarCustomizePage(controller: _controller)),
        ),
        _Item(
          icon: 'assets/toolbar/toolbar.png',
          label: '底栏自定义',
          onTap: () => _open(BottomBarCustomizePage(controller: _controller)),
        ),
      ]),
      _Group('浏览器设置', [
        _Item(
          icon: 'assets/images/web.png',
          label: '浏览器设置',
          subtitle: '通用控制 · 内容元素 · 隐私',
          onTap: () => _open(BrowserSettingsPage(controller: _controller)),
        ),
        _Item(
          icon: 'assets/images/bookmark.png',
          label: '书签管理',
          subtitle: '${_controller.bookmarks.length} 个书签',
          onTap: () => _open(BookmarksPage(controller: _controller)),
        ),
        _Item(
          icon: 'assets/images/history.png',
          label: '历史记录管理',
          subtitle: '${_controller.history.length} 条记录',
          onTap: () => _open(HistoryPage(controller: _controller)),
        ),
        _Item(
          icon: 'assets/images/cookie.png',
          label: 'Cookie 管理',
          subtitle: '清除浏览数据',
          onTap: () => _clearData(context),
        ),
      ]),
      _Group('文件存储与恢复', [
        _Item(
          icon: 'assets/images/backup.png',
          label: '备份与恢复',
          onTap: () => _hint(context, '备份与恢复', '书签、历史与设置已保存在应用私有目录，可随系统备份迁移。'),
        ),
        _Item(
          icon: 'assets/images/folder.png',
          label: '文件管理',
          subtitle: '${_controller.downloads.length} 个已下载文件',
          onTap: () => _open(DownloadsPage(controller: _controller)),
        ),
        _Item(
          icon: 'assets/images/chart.png',
          label: '存储空间管理',
          onTap: () =>
              _hint(context, '存储空间管理', '下载文件、缓存与书签数据都存放在应用私有空间，卸载后一并清除。'),
        ),
      ]),
      _Group('系统安全设置', [
        _Item(
          icon: 'assets/images/fingerprint.png',
          label: '生物验证与锁定',
          subtitle: _controller.settings.appLockEnabled ? '应用锁已开启' : '密码 · 指纹 · 面容',
          onTap: () => _open(BiometricsPage(controller: _controller)),
        ),
        _Item(
          icon: 'assets/images/behavior_control.png',
          label: '网站行为管控',
          subtitle: '应用跳转 · 权限 · 剪贴板',
          onTap: () => _open(SiteBehaviorPage(controller: _controller)),
        ),
        _Item(
          icon: 'assets/images/safe.png',
          label: '隐私与安全',
          onTap: () => _privacySheet(context),
        ),
      ]),
      _Group('辅助功能与更多', [
        _Item(
          icon: 'assets/images/bell.png',
          label: '通知、声音与触感',
          onTap: () => _hint(context, '通知、声音与触感', '下载完成提醒与触感反馈会跟随系统设置。'),
        ),
        _Item(
          icon: 'assets/images/creation.png',
          label: 'AI 设置',
          subtitle: _controller.settings.aiEnabled ? '已开启' : '已关闭',
          onTap: () => _open(AiSettingsPage(controller: _controller)),
        ),
        _Item(
          icon: 'assets/images/human.png',
          label: '无障碍与辅助功能',
          onTap: () => _hint(context, '无障碍与辅助功能', '星环已适配系统字号缩放与高对比度显示。'),
        ),
        _Item(
          icon: 'assets/images/battery.png',
          label: '性能与用量',
          onTap: () => _hint(
            context,
            '性能与用量',
            '当前有 ${_controller.tabs.length} 个标签页在运行，'
                '每个标签独立 WebView 进程。',
          ),
        ),
        _Item(
          icon: 'assets/images/terminal.png',
          label: '终端',
          onTap: () => _hint(context, '终端', '终端功能需要 Root 权限，当前版本未启用。'),
        ),
        _Item(
          icon: 'assets/images/more.png',
          label: '高级设置',
          onTap: () => _advancedSheet(context),
        ),
      ]),
      _Group('用户体验与联系', [
        _Item(
          icon: 'assets/images/account-privacy.png',
          label: '未成年人保护功能',
          onTap: () => _hint(context, '未成年人保护功能', '可在系统「数字健康」中为星环设置使用时长限制。'),
        ),
        _Item(
          icon: 'assets/images/comment-search.png',
          label: '支持与联系',
          onTap: () => _hint(context, '支持与联系', '可通过「使用建议与反馈」提交问题，我们会逐条查看。'),
        ),
        _Item(
          icon: 'assets/images/message.png',
          label: '使用建议与反馈',
          onTap: () =>
              _hint(context, '使用建议与反馈', '反馈入口正在接入，目前可先到 Gitee 仓库提交 issue。'),
        ),
      ]),
    ];
  }

  void _open(Widget page) {
    Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => page));
  }

  void _toast(String message) {
    ScaffoldMessenger.of(context)
      ..clearSnackBars()
      ..showSnackBar(
        SnackBar(
          content: Text(message),
          behavior: SnackBarBehavior.floating,
          duration: const Duration(milliseconds: 1600),
        ),
      );
  }

  Future<void> _hint(BuildContext context, String title, String body) async {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    await showRoamSheet<void>(
      context: context,
      title: title,
      children: [
        Text(
          body,
          style: TextStyle(
            fontSize: 13,
            height: 1.6,
            color: (isDark ? RoamColors.textPrimary : RoamColors.dayInk)
                .withValues(alpha: 0.7),
          ),
        ),
      ],
    );
  }

  Future<void> _experimental(BuildContext context) async {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    await showRoamSheet<void>(
      context: context,
      title: '实验性功能',
      children: [
        StatefulBuilder(
          builder: (context, setSheetState) => Column(
            children: [
              _SheetSwitch(
                label: '默认桌面模式',
                subtitle: '以桌面 UA 加载所有站点',
                value: _controller.settings.desktopMode,
                isDark: isDark,
                onChanged: (value) async {
                  await _controller.setDesktopMode(value);
                  setSheetState(() {});
                  setState(() {});
                },
              ),
              _SheetSwitch(
                label: '启动时恢复标签页',
                subtitle: '重新打开上次退出时的标签',
                value: _controller.settings.restoreTabs,
                isDark: isDark,
                onChanged: (value) async {
                  await _controller.setRestoreTabs(value);
                  setSheetState(() {});
                },
              ),
            ],
          ),
        ),
      ],
    );
  }

  Future<void> _pickEngine(BuildContext context) async {
    final current = _controller.settings.searchEngine;
    await showRoamSheet<void>(
      context: context,
      title: '默认搜索引擎',
      children: [
        for (final engine in SearchEngine.values)
          _SheetChoice(
            label: engine.label,
            selected: engine == current,
            onTap: () async {
              await _controller.setSearchEngine(engine);
              if (context.mounted) Navigator.of(context).pop();
              setState(() {});
            },
          ),
      ],
    );
  }

  Future<void> _privacySheet(BuildContext context) async {
    await showRoamSheet<void>(
      context: context,
      title: '隐私与安全',
      children: [
        _SheetAction(
          icon: 'assets/images/safe.png',
          label: '法律协议与政策',
          onTap: () {
            Navigator.of(context).pop();
            _open(LegalPage(controller: _controller));
          },
        ),
        _SheetAction(
          icon: 'assets/images/creation.png',
          label: 'AI 设置',
          onTap: () {
            Navigator.of(context).pop();
            _open(AiSettingsPage(controller: _controller));
          },
        ),
        _SheetAction(
          icon: 'assets/images/cookie.png',
          label: '清除浏览数据',
          destructive: true,
          onTap: () {
            Navigator.of(context).pop();
            _clearData(context);
          },
        ),
      ],
    );
  }

  Future<void> _advancedSheet(BuildContext context) async {
    await showRoamSheet<void>(
      context: context,
      title: '高级设置',
      children: [
        _SheetAction(
          icon: 'assets/images/web.png',
          label: '浏览器设置',
          onTap: () {
            Navigator.of(context).pop();
            _open(BrowserSettingsPage(controller: _controller));
          },
        ),
        _SheetAction(
          icon: 'assets/images/safe.png',
          label: '法律协议与政策',
          onTap: () {
            Navigator.of(context).pop();
            _open(LegalPage(controller: _controller));
          },
        ),
        _SheetAction(
          icon: 'assets/images/info.png',
          label: '关于',
          onTap: () {
            Navigator.of(context).pop();
            _open(const AboutPage());
          },
        ),
      ],
    );
  }

  Future<void> _moreSheet(BuildContext context) async {
    await showRoamSheet<void>(
      context: context,
      title: '功能选项',
      children: [
        _SheetAction(
          icon: 'assets/images/creation.png',
          label: 'AI 设置',
          onTap: () {
            Navigator.of(context).pop();
            _open(AiSettingsPage(controller: _controller));
          },
        ),
        _SheetAction(
          icon: 'assets/images/safe.png',
          label: '法律协议与政策',
          onTap: () {
            Navigator.of(context).pop();
            _open(LegalPage(controller: _controller));
          },
        ),
        _SheetAction(
          icon: 'assets/images/info.png',
          label: '关于星环',
          onTap: () {
            Navigator.of(context).pop();
            _open(const AboutPage());
          },
        ),
      ],
    );
  }

  Future<void> _clearData(BuildContext context) async {
    final confirmed = await showRoamConfirm(
      context: context,
      title: '清除浏览数据',
      message: '将清除历史记录与下载记录，书签会保留。',
      confirmLabel: '清除',
      destructive: true,
    );
    if (!confirmed) return;
    await _controller.clearBrowsingData(history: true);
    _toast('已清除浏览数据');
    setState(() {});
  }
}

class _Group {
  const _Group(this.title, this.items);

  final String title;
  final List<_Item> items;
}

class _Item {
  const _Item({
    required this.icon,
    required this.label,
    required this.onTap,
    this.subtitle,
  });

  final String icon;
  final String label;
  final String? subtitle;
  final VoidCallback onTap;
}

/// 账号卡：50dp 圆头像、21sp 粗体用户名、12sp 副标题，下方分隔线接「关于」。
class _AccountCard extends StatelessWidget {
  const _AccountCard({required this.controller});

  final BrowserController controller;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final fg = isDark ? RoamColors.textPrimary : RoamColors.dayInk;
    return Padding(
      padding: const EdgeInsets.fromLTRB(25, 5.2, 25, 0),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(15),
          color: isDark ? RoamColors.cardDark : RoamColors.cardLight,
        ),
        child: Column(
          children: [
            InkWell(
              onTap: () {
                ScaffoldMessenger.of(context)
                  ..clearSnackBars()
                  ..showSnackBar(
                    const SnackBar(
                      content: Text('星构云登录暂未接入'),
                      behavior: SnackBarBehavior.floating,
                    ),
                  );
              },
              child: Padding(
                padding: const EdgeInsets.fromLTRB(10, 15, 10, 15),
                child: Row(
                  children: [
                    Container(
                      width: 50,
                      height: 50,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(color: fg.withValues(alpha: 0.12)),
                      ),
                      child: ClipOval(
                        child: Image.asset(
                          'assets/images/account_profile.png',
                          color: fg.withValues(alpha: 0.85),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            '登录星构云',
                            style: TextStyle(
                              fontSize: 21,
                              fontWeight: FontWeight.w700,
                              color: fg,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Image.asset(
                      'assets/images/menu.png',
                      width: 28,
                      height: 28,
                      color: fg.withValues(alpha: 0.35),
                    ),
                  ],
                ),
              ),
            ),
            Container(
              height: 1,
              margin: const EdgeInsets.only(left: 14),
              color: fg.withValues(alpha: 0.08),
            ),
            RoamSettingRow(
              iconWidget: ClipRRect(
                borderRadius: BorderRadius.circular(9),
                child: Image.asset(
                  'assets/images/ic_launcher.png',
                  width: 36,
                  height: 36,
                  fit: BoxFit.cover,
                ),
              ),
              label: '关于',
              onTap: () => Navigator.of(context).push(
                MaterialPageRoute<void>(builder: (_) => const AboutPage()),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SheetSwitch extends StatelessWidget {
  const _SheetSwitch({
    required this.label,
    required this.subtitle,
    required this.value,
    required this.onChanged,
    required this.isDark,
  });

  final String label;
  final String subtitle;
  final bool value;
  final ValueChanged<bool> onChanged;
  final bool isDark;

  @override
  Widget build(BuildContext context) {
    final fg = isDark ? RoamColors.textPrimary : RoamColors.dayInk;
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.fromLTRB(16, 10, 10, 10),
      decoration: roamGlassDecoration(context, radius: 15, elevated: false),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: TextStyle(fontSize: 15, color: fg)),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: TextStyle(
                    fontSize: 11.5,
                    color: fg.withValues(alpha: 0.45),
                  ),
                ),
              ],
            ),
          ),
          RoamSwitch(value: value, onChanged: onChanged),
        ],
      ),
    );
  }
}

class _SheetChoice extends StatelessWidget {
  const _SheetChoice({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final fg = isDark ? RoamColors.textPrimary : RoamColors.dayInk;
    return PressableScale(
      onTap: onTap,
      scale: 0.99,
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 15),
        decoration: roamGlassDecoration(context, radius: 15, elevated: false),
        child: Row(
          children: [
            Text(label, style: TextStyle(fontSize: 15, color: fg)),
            const Spacer(),
            if (selected)
              const Icon(
                Icons.check_rounded,
                size: 19,
                color: RoamColors.aurora,
              ),
          ],
        ),
      ),
    );
  }
}

class _SheetAction extends StatelessWidget {
  const _SheetAction({
    required this.icon,
    required this.label,
    required this.onTap,
    this.destructive = false,
  });

  final String icon;
  final String label;
  final VoidCallback onTap;
  final bool destructive;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final color = destructive
        ? RoamColors.danger
        : (isDark ? RoamColors.textPrimary : RoamColors.dayInk);
    return PressableScale(
      onTap: onTap,
      scale: 0.99,
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: roamGlassDecoration(context, radius: 15, elevated: false),
        child: Row(
          children: [
            Image.asset(icon, width: 22, height: 22, color: color),
            const SizedBox(width: 12),
            Text(label, style: TextStyle(fontSize: 15, color: color)),
          ],
        ),
      ),
    );
  }
}
