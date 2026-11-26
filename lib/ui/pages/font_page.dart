// ignore_for_file: deprecated_member_use

import 'package:flutter/material.dart';

import '../../state/browser_controller.dart';
import '../../theme/roam_theme.dart';
import '../widgets/roam_chrome.dart';

/// 字体（对应原版 pages/FontSettings）。
/// 上方是字体样张，下方是可切换的字体列表。
class FontPage extends StatefulWidget {
  const FontPage({super.key, required this.controller});

  final BrowserController controller;

  @override
  State<FontPage> createState() => _FontPageState();
}

class _FontPageState extends State<FontPage> {
  late String _mode;

  static const _options = <(String, String, String)>[
    ('default', '默认字体', '星环无极可变字体'),
    ('system', '跟随系统字体', '使用系统当前字体'),
    ('roboto', '使用 Google Roboto 字体', 'Roboto'),
    ('serif', '使用 OPPO Serif 字体', '衬线体'),
  ];

  @override
  void initState() {
    super.initState();
    _mode = widget.controller.settings.fontMode;
  }

  String? get _family => switch (_mode) {
    'roboto' => 'Roboto',
    'serif' => 'serif',
    _ => null,
  };

  void _select(String mode) {
    setState(() => _mode = mode);
    widget.controller.updateSettings(
      widget.controller.settings.copyWith(fontMode: mode),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final fg = isDark ? RoamColors.textPrimary : RoamColors.dayInk;

    return RoamPageScaffold(
      title: '字体',
      child: ListView(
        padding: EdgeInsets.only(
          top: RoamPageScaffold.contentTopPadding + 10,
          bottom: 40,
        ),
        physics: const BouncingScrollPhysics(),
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(25, 5.2, 25, 5.2),
            child: Container(
              height: 236,
              padding: const EdgeInsets.symmetric(horizontal: 18),
              decoration: BoxDecoration(
                color: isDark ? RoamColors.cardDark : RoamColors.cardLight,
                borderRadius: BorderRadius.circular(15),
              ),
              child: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '0123456789',
                      style: TextStyle(
                        fontFamily: _family,
                        fontSize: 34,
                        height: 1.15,
                        fontWeight: FontWeight.w600,
                        color: fg,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      'ABCDEFGHIJKLMNOPQRSTUVWXYZ',
                      style: TextStyle(
                        fontFamily: _family,
                        fontSize: 13,
                        height: 1.3,
                        color: fg.withValues(alpha: 0.72),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      '新一代星环，满分体验',
                      style: TextStyle(
                        fontFamily: _family,
                        fontSize: 20,
                        height: 1.3,
                        fontWeight: FontWeight.w600,
                        color: fg,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'ROAM AI Explore',
                      style: TextStyle(
                        fontFamily: _family,
                        fontSize: 14,
                        letterSpacing: 1.2,
                        color: fg.withValues(alpha: 0.55),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          const RoamGroupHeader(text: '支持设置的字体'),
          RoamSettingCard(
            children: [
              for (final option in _options)
                RoamSettingRow(
                  label: option.$2,
                  subtitle: option.$3,
                  showChevron: false,
                  onTap: () => _select(option.$1),
                  trailing: option.$1 == _mode
                      ? const Icon(
                          Icons.check_rounded,
                          size: 20,
                          color: RoamColors.auroraDeep,
                        )
                      : const SizedBox(width: 20),
                ),
            ],
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(25, 12, 25, 0),
            child: Text(
              '网页内容仍以站点自身字体为准，这里影响的是星环界面文字。',
              style: TextStyle(
                fontSize: 11,
                height: 1.45,
                color: (isDark ? RoamColors.textPrimary : RoamColors.dayInk)
                    .withValues(alpha: 0.42),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
