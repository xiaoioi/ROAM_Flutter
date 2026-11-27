// ignore_for_file: deprecated_member_use

import 'package:flutter/material.dart';
import 'package:flutter_miuix/miuix.dart';

import '../../state/browser_controller.dart';
import '../../theme/roam_theme.dart';
import '../widgets/glass_controls.dart';
import '../widgets/roam_chrome.dart';
import '../widgets/roam_segmented.dart';

/// 材质显示效果（对应原版 pages/ModifyMaterialEffect）。
///
/// 显示哪些分区由两个开关决定：
///  - 「材质显示效果」关闭（标准）→ 只剩边缘渐显/滚动条，玻璃相关全部收起；
///  - 高斯模糊 = 性能优先 → 收起「玻璃引擎」，玻璃退化成简单模糊 + 轮廓光；
///  - 都打开 → 高斯模糊 / 玻璃引擎 / 轮廓光材质 三张都在。
class MaterialEffectsPage extends StatelessWidget {
  const MaterialEffectsPage({super.key, required this.controller});

  final BrowserController controller;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: controller,
      builder: (context, _) {
        final isDark = Theme.of(context).brightness == Brightness.dark;
        // 强调色统一取主题色（miuix 蓝），不再自带一套红色。
        final accent = Theme.of(context).colorScheme.primary;
        final settings = controller.settings;
        final materialOn = settings.liquidMaterial;
        final performance = settings.blurQuality == 'performance';

        return RoamPageScaffold(
          title: '材质显示效果',
          child: ListView(
            padding: EdgeInsets.only(
              top: RoamPageScaffold.topPadding(context) + 6,
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
                      color: accent,
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
                      color: accent,
                      onChanged: (value) => controller.updateSettings(
                        settings.copyWith(showScrollbar: value),
                      ),
                    ),
                  ),
                ],
              ),
              if (materialOn) ...[
                const SizedBox(height: 8),
                _SectionCard(
                  icon: 'assets/images/animation.png',
                  title: '高斯模糊效果',
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
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
                      if (performance) ...[
                        const SizedBox(height: 10),
                        Text(
                          '性能优先：玻璃改为简单模糊（半透明磨砂 + 轮廓光），'
                          '不跑实时高斯，滚动更省电。',
                          style: TextStyle(
                            fontSize: 11,
                            height: 1.45,
                            color:
                                (isDark
                                        ? RoamColors.textPrimary
                                        : RoamColors.dayInk)
                                    .withValues(alpha: 0.45),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ],
              // 玻璃引擎只在「效果优先」时才有意义：性能优先一律降级成
              // 简单模糊，引擎选择不影响渲染，露出来只会让人以为是坏的。
              if (materialOn && !performance) ...[
                const SizedBox(height: 8),
                _SectionCard(
                  icon: 'assets/images/palette.png',
                  title: '玻璃引擎',
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
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
                        // 拖动条直接用 miuix 的 Slider（轨道 / 滑块 / 触感都是官方的），
                        // 不再套 Material 的 SliderTheme 自己画。
                        // MiuixSlider 内部是「SizedBox + CustomPaint」，
                        // 没有 child 时宽度会坍缩成 0；必须给一条撑满的约束。
                        SizedBox(
                          width: double.infinity,
                          child: MiuixSlider(
                            value: settings.glassBlur.clamp(0.5, 2.0),
                            min: 0.5,
                            max: 2.0,
                            steps: 15,
                            onValueChanged: (value) => controller.updateSettings(
                              settings.copyWith(glassBlur: value),
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ],
              if (materialOn) ...[
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
                          subtitle: performance
                              ? '玻璃边缘描一圈对比色细边'
                              : '玻璃边缘的高光描边',
                          showChevron: false,
                          onTap: () => controller.updateSettings(
                            settings.copyWith(rimLight: !settings.rimLight),
                          ),
                          trailing: RoamSwitch(
                            value: settings.rimLight,
                            color: accent,
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
            ],
          ),
        );
      },
    );
  }
}

/// 设置卡：图标 + 标题一行，下面跟自定义内容（分段器 / 滑块）。
class _SectionCard extends StatelessWidget {
  const _SectionCard({
    required this.icon,
    required this.title,
    required this.child,
  });

  final String icon;
  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Padding(
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
                  icon,
                  width: 25,
                  height: 25,
                  color: isDark ? RoamColors.textPrimary : RoamColors.dayInk,
                ),
                const SizedBox(width: 7),
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 15,
                    color: isDark ? RoamColors.textPrimary : RoamColors.dayInk,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            child,
          ],
        ),
      ),
    );
  }
}

/// 分段选择器：高斯模糊（性能/效果）、玻璃引擎（自绘 / MIUIX）共用。
///
/// 用 miuix 的相连分段轨道（共用轨道 + 滑动指示块），点第几段就落第几段。
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
    final index = options.indexWhere((option) => option.$1 == value);
    return RoamSegmented(
      tabs: [for (final option in options) option.$2],
      selectedIndex: index < 0 ? 0 : index,
      onSelect: (i) => onChanged(options[i].$1),
      height: 40,
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
              pixelRatio: 1,
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
