// ignore_for_file: deprecated_member_use

import 'package:flutter/material.dart';
import 'package:flutter_miuix/miuix.dart';

import '../../state/browser_controller.dart';
import '../../theme/roam_theme.dart';
import '../widgets/glass_controls.dart';
import '../widgets/roam_chrome.dart';

/// 材质显示效果（对应原版 pages/ModifyMaterialEffect）。
///
/// 四组：边缘渐显 / 滚动条、高斯模糊、轮廓光材质；
/// 最后一张卡是绿色壁纸上的组合卡片实拍预览，用来直观看出轮廓光。
class MaterialEffectsPage extends StatelessWidget {
  const MaterialEffectsPage({super.key, required this.controller});

  final BrowserController controller;

  static const _accent = Color(0xFFFF3B30);

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: controller,
      builder: (context, _) {
        final isDark = Theme.of(context).brightness == Brightness.dark;
        final settings = controller.settings;
        return RoamPageScaffold(
          title: '材质显示效果',
          child: ListView(
            padding: EdgeInsets.only(
              top: RoamPageScaffold.contentTopPadding + 6,
              bottom: 40,
            ),
            physics: const BouncingScrollPhysics(),
            children: [
              RoamSettingCard(
                children: [
                  RoamSettingRow(
                    icon: 'assets/images/animation.png',
                    label: '边缘渐显效果',
                    showChevron: false,
                    onTap: () => controller.updateSettings(
                      settings.copyWith(edgeFade: !settings.edgeFade),
                    ),
                    trailing: RoamSwitch(
                      value: settings.edgeFade,
                      color: _accent,
                      onChanged: (value) => controller.updateSettings(
                        settings.copyWith(edgeFade: value),
                      ),
                    ),
                  ),
                  RoamSettingRow(
                    icon: 'assets/images/list.png',
                    label: '滚动条',
                    showChevron: false,
                    onTap: () => controller.updateSettings(
                      settings.copyWith(showScrollbar: !settings.showScrollbar),
                    ),
                    trailing: RoamSwitch(
                      value: settings.showScrollbar,
                      color: _accent,
                      onChanged: (value) => controller.updateSettings(
                        settings.copyWith(showScrollbar: value),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Padding(
                padding: const EdgeInsets.fromLTRB(25, 5.2, 25, 5.2),
                child: Container(
                  padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
                  decoration: BoxDecoration(
                    color: isDark ? RoamColors.cardDark : RoamColors.cardLight,
                    borderRadius: BorderRadius.circular(15),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Image.asset(
                            'assets/images/animation.png',
                            width: 25,
                            height: 25,
                            color: isDark
                                ? RoamColors.textPrimary
                                : RoamColors.dayInk,
                          ),
                          const SizedBox(width: 7),
                          Text(
                            '高斯模糊效果',
                            style: TextStyle(
                              fontSize: 15,
                              color: isDark
                                  ? RoamColors.textPrimary
                                  : RoamColors.dayInk,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      _Segments(
                        value: settings.blurQuality,
                        options: const [
                          ('performance', '性能优先'),
                          ('quality', '效果优先'),
                        ],
                        onChanged: (value) => controller.updateSettings(
                          settings.copyWith(blurQuality: value),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 8),
              // 玻璃引擎：自绘 OS4 柔光玻璃（roam_glass.frag，commonSmallRegular）
              // / flutter_miuix 的 MiuixGlass。默认自绘，可随时切回。
              Padding(
                padding: const EdgeInsets.fromLTRB(25, 5.2, 25, 5.2),
                child: Container(
                  padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
                  decoration: BoxDecoration(
                    color: isDark ? RoamColors.cardDark : RoamColors.cardLight,
                    borderRadius: BorderRadius.circular(15),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Image.asset(
                            'assets/images/palette.png',
                            width: 25,
                            height: 25,
                            color: isDark
                                ? RoamColors.textPrimary
                                : RoamColors.dayInk,
                          ),
                          const SizedBox(width: 7),
                          Text(
                            '玻璃引擎',
                            style: TextStyle(
                              fontSize: 15,
                              color: isDark
                                  ? RoamColors.textPrimary
                                  : RoamColors.dayInk,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      _Segments(
                        value: settings.customGlass ? 'roam' : 'miuix',
                        options: const [
                          ('roam', '自绘柔光玻璃'),
                          ('miuix', 'MIUIX 玻璃'),
                        ],
                        onChanged: (value) => controller.updateSettings(
                          settings.copyWith(customGlass: value == 'roam'),
                        ),
                      ),
                      // 模糊度调节：仅自绘玻璃模式显示。
                      if (settings.customGlass) ...[
                        const SizedBox(height: 16),
                        Row(
                          children: [
                            Text(
                              '模糊度调节',
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                                color:
                                    (isDark
                                            ? RoamColors.textPrimary
                                            : RoamColors.dayInk)
                                        .withValues(alpha: 0.85),
                              ),
                            ),
                            const Spacer(),
                            Text(
                              '${(settings.glassBlur * 100).round()}%',
                              style: TextStyle(
                                fontSize: 12,
                                color:
                                    (isDark
                                            ? RoamColors.textPrimary
                                            : RoamColors.dayInk)
                                        .withValues(alpha: 0.55),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        SliderTheme(
                          data: SliderTheme.of(context).copyWith(
                            trackHeight: 4,
                            thumbShape: const RoundSliderThumbShape(
                              enabledThumbRadius: 8,
                            ),
                            overlayShape: const RoundSliderOverlayShape(
                              overlayRadius: 16,
                            ),
                            activeTrackColor: _accent,
                            inactiveTrackColor:
                                (isDark
                                        ? RoamColors.textPrimary
                                        : RoamColors.dayInk)
                                    .withValues(alpha: 0.12),
                            thumbColor: _accent,
                            overlayColor: _accent.withValues(alpha: 0.15),
                          ),
                          child: Slider(
                            value: settings.glassBlur.clamp(0.5, 2.0),
                            min: 0.5,
                            max: 2.0,
                            divisions: 15,
                            onChanged: (value) => controller.updateSettings(
                              settings.copyWith(glassBlur: value),
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 8),
              // 顶栏圆钮材质：柔光玻璃只有一套，这里切换的是
              // 「实心圆钮（澎湃 4 原样）」与「真实背景采样的柔光玻璃」。
              RoamSettingCard(
                children: [
                  RoamSettingRow(
                    icon: 'assets/images/palette.png',
                    label: '顶栏圆钮玻璃',
                    subtitle: '关闭时使用澎湃 4 实心圆钮',
                    showChevron: false,
                    onTap: () => controller.updateSettings(
                      settings.copyWith(topBarGlass: !settings.topBarGlass),
                    ),
                    trailing: RoamSwitch(
                      value: settings.topBarGlass,
                      color: _accent,
                      onChanged: (value) => controller.updateSettings(
                        settings.copyWith(topBarGlass: value),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Padding(
                padding: const EdgeInsets.fromLTRB(25, 5.2, 25, 5.2),
                child: Container(
                  decoration: BoxDecoration(
                    color: isDark ? RoamColors.cardDark : RoamColors.cardLight,
                    borderRadius: BorderRadius.circular(15),
                  ),
                  padding: const EdgeInsets.only(bottom: 12),
                  child: Column(
                    children: [
                      RoamSettingRow(
                        icon: 'assets/images/palette.png',
                        label: '轮廓光材质',
                        showChevron: false,
                        onTap: () => controller.updateSettings(
                          settings.copyWith(rimLight: !settings.rimLight),
                        ),
                        trailing: RoamSwitch(
                          value: settings.rimLight,
                          color: _accent,
                          onChanged: (value) => controller.updateSettings(
                            settings.copyWith(rimLight: value),
                          ),
                        ),
                      ),
                      const Padding(
                        padding: EdgeInsets.fromLTRB(12, 2, 12, 0),
                        child: _MaterialPreview(),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

/// 分段选择器：高斯模糊（性能/效果）、玻璃引擎（自绘/MIUIX）共用。
class _Segments extends StatelessWidget {
  const _Segments({
    required this.value,
    required this.options,
    required this.onChanged,
  });

  final String value;

  /// `(值, 展示文案)` 有序表。
  final List<(String, String)> options;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      height: 44,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(22),
        color: isDark ? RoamColors.itemDark : RoamColors.itemLight,
      ),
      child: Row(
        children: [
          for (final option in options)
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(5),
                child: PressableScale(
                  scale: 0.97,
                  onTap: () => onChanged(option.$1),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 180),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(17),
                      color: option.$1 == value
                          ? (isDark ? const Color(0xFF3A3A3C) : Colors.white)
                          : Colors.transparent,
                    ),
                    alignment: Alignment.center,
                    child: Text(
                      option.$2,
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: option.$1 == value
                            ? FontWeight.w700
                            : FontWeight.w500,
                        color:
                            (isDark
                                    ? RoamColors.textPrimary
                                    : RoamColors.dayInk)
                                .withValues(
                                  alpha: option.$1 == value ? 1 : 0.62,
                                ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// 绿色壁纸上的组合卡片预览：笔记卡和四个服务图标都是真玻璃。
class _MaterialPreview extends StatefulWidget {
  const _MaterialPreview();

  @override
  State<_MaterialPreview> createState() => _MaterialPreviewState();
}

class _MaterialPreviewState extends State<_MaterialPreview> {
  /// miuix 柔光玻璃的局部采样器：只捕获预览卡的绿色底图。
  /// 不传的话会退回全局 [miuixBackdrop]——那是 BrowserShell 捕获的整页
  /// 内容，在设置页（压栈路由）下是陈旧快照，预览里会透出首页图标。
  final MiuixLayerBackdrop _miuixBackdrop = MiuixLayerBackdrop();

  static const _services = [
    'assets/services/ic_weather.png',
    'assets/services/ic_gallery3d.png',
    'assets/services/ic_camera.png',
    'assets/services/ic_calendar.png',
  ];

  @override
  void dispose() {
    _miuixBackdrop.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: SizedBox(
        height: 196,
        child: Stack(
          fit: StackFit.expand,
          children: [
            MiuixLayerBackdropCapture(
              backdrop: _miuixBackdrop,
              child: Image.asset(
                'assets/wallpapers/wanmu.jpg',
                fit: BoxFit.cover,
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(10, 10, 10, 8),
              child: Column(
                children: [
                  Expanded(
                    child: Row(
                      children: [
                        Expanded(
                          child: RoamGlassSurface(
                            miuixLayer: _miuixBackdrop,
                            radius: 12,
                            surfaceColor: Colors.white.withValues(alpha: 0.18),
                            child: SizedBox(
                              height: double.infinity,
                              child: Column(
                                children: [
                                  Padding(
                                    padding: const EdgeInsets.only(
                                      top: 8,
                                      left: 8,
                                      right: 8,
                                    ),
                                    child: Row(
                                      children: [
                                        Image.asset(
                                          'assets/services/ic_note.png',
                                          width: 16,
                                          height: 16,
                                        ),
                                        const SizedBox(width: 4),
                                        const Text(
                                          '我的笔记',
                                          style: TextStyle(
                                            fontSize: 11,
                                            fontWeight: FontWeight.w700,
                                            color: Colors.white,
                                            height: 1.2,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  const Expanded(
                                    child: Center(
                                      child: Text(
                                        '暂无笔记',
                                        style: TextStyle(
                                          fontSize: 13,
                                          fontWeight: FontWeight.w700,
                                          color: Colors.white70,
                                        ),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        SizedBox(
                          width: 116,
                          child: GridView.builder(
                            physics: const NeverScrollableScrollPhysics(),
                            padding: EdgeInsets.zero,
                            itemCount: 4,
                            gridDelegate:
                                const SliverGridDelegateWithFixedCrossAxisCount(
                                  crossAxisCount: 2,
                                  mainAxisSpacing: 8,
                                  crossAxisSpacing: 8,
                                ),
                            itemBuilder: (context, index) {
                              return RoamGlassSurface(
                                miuixLayer: _miuixBackdrop,
                                radius: 12,
                                surfaceColor: Colors.white.withValues(
                                  alpha: 0.18,
                                ),
                                child: Padding(
                                  padding: const EdgeInsets.all(9),
                                  child: Image.asset(
                                    _services[index],
                                    fit: BoxFit.contain,
                                  ),
                                ),
                              );
                            },
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 6),
                  const Text(
                    '组合卡片',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: Colors.white,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
