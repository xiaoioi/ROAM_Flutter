// ignore_for_file: deprecated_member_use

import 'package:flutter/material.dart';
import 'package:flutter_miuix/miuix.dart';

import '../../state/browser_controller.dart';
import '../../theme/roam_theme.dart';
import '../widgets/predictive_back.dart';
import '../widgets/roam_chrome.dart';
import '../widgets/roam_sheet.dart';

/// 法律协议与政策。
/// 取自 pages/Copyright/main.lua：卡片式列表，点击进入内嵌 WebView。
/// 协议地址与原包一致（roamexplore.rth1.xyz）。
class LegalPage extends StatelessWidget {
  const LegalPage({super.key, required this.controller});

  final BrowserController controller;

  static const _items = [
    (
      '星环软件使用协议',
      'assets/images/account-privacy.png',
      'https://roamexplore.rth1.xyz/USERAGREEMENT_CN.html',
    ),
    (
      '星环软件隐私政策',
      'assets/images/safe.png',
      'https://roamexplore.rth1.xyz/PRIVACYPOLICY_CN.html',
    ),
    (
      '三方协议',
      'assets/images/plugin.png',
      'https://roamexplore.rth1.xyz/PRIVACYPOLICY_CN.html',
    ),
    ('三方信息共享清单', 'assets/images/list.png', ''),
    (
      '开放源代码',
      'assets/images/creation.png',
      'https://gitee.com/hairouse/roam_explore',
    ),
    ('字体版权', 'assets/images/fonts.png', 'http://scripts.sil.org/OFL'),
  ];

  void _open(BuildContext context, String url) {
    if (url.isEmpty) {
      _showSdkList(context);
      return;
    }
    controller.openAddress(url);
    Navigator.of(context).popUntil((route) => route.isFirst);
  }

  Future<void> _showSdkList(BuildContext context) async {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final fg = (isDark ? RoamColors.textPrimary : RoamColors.dayInk).withValues(
      alpha: 0.72,
    );
    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      barrierColor: MiuixGlassDialogDefaults.scrimColor,
      builder: (sheetContext) => PredictiveBackScope(
        style: PredictiveBackStyle.sheet,
        onCommit: () => Navigator.of(sheetContext).maybePop(),
        // 所有底部弹出框统一用 miuix GlassBottomSheet 的玻璃表面，
        // 这里只是浮起一点（16dp 外边距）做成卡片式抽屉。
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: RoamGlassSheetSurface(
            radius: 22,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 4, 20, 20),
              child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const RoamSheetHandle(),
              const SizedBox(height: 4),
              Text(
                '三方信息共享清单',
                style: TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w700,
                  color: isDark ? RoamColors.textPrimary : RoamColors.dayInk,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                '星环只在实现基础功能时调用系统能力，不向第三方共享浏览记录。'
                '内置的统计组件仅在崩溃诊断时上报匿名堆栈。',
                style: TextStyle(fontSize: 13, height: 1.6, color: fg),
              ),
              const SizedBox(height: 16),
              Align(
                alignment: Alignment.centerRight,
                child: TextButton(
                  onPressed: () => Navigator.of(sheetContext).pop(),
                  child: const Text('知道了'),
                ),
              ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return RoamPageScaffold(
      title: '法律协议与政策',
      child: ListView(
        padding: EdgeInsets.fromLTRB(
          25,
          RoamPageScaffold.contentTopPadding + 10,
          25,
          40,
        ),
        physics: const BouncingScrollPhysics(),
        children: [
          for (final item in _items)
            RoamListCard(
              radius: 15,
              margin: const EdgeInsets.only(bottom: 10),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
              onTap: () => _open(context, item.$3),
              child: Row(
                children: [
                  Image.asset(
                    item.$2,
                    width: 22,
                    height: 22,
                    color: Theme.of(context).brightness == Brightness.dark
                        ? RoamColors.textPrimary
                        : RoamColors.dayInk,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      item.$1,
                      style: TextStyle(
                        fontSize: 15,
                        color: Theme.of(context).brightness == Brightness.dark
                            ? RoamColors.textPrimary
                            : RoamColors.dayInk,
                      ),
                    ),
                  ),
                  Image.asset(
                    'assets/images/menu.png',
                    width: 26,
                    height: 26,
                    color: Theme.of(context).brightness == Brightness.dark
                        ? RoamColors.textTertiary
                        : const Color(0xFF9A9AA0),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}
