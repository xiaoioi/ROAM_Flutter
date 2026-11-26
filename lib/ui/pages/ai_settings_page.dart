// ignore_for_file: deprecated_member_use

import 'package:flutter/material.dart';
import 'package:flutter_miuix/miuix.dart';

import '../../models/browser_models.dart';
import '../../state/browser_controller.dart';
import '../widgets/glass_controls.dart';
import '../widgets/roam_chrome.dart';

/// AI 设置。
///
/// 两组：
///  - 「AI 服务」：整理图片内容 / 分析已浏览网页（原包 pages/AISettings）；
///  - 「翻译服务」：OpenAI 兼容的接口地址、模型、密钥。默认指向哔哩哔哩
///    Index-Translate 的免费公网接口（免 key），也可以换成任意
///    自建 / 第三方 `…/v1` 服务，翻译页立即生效。
class AiSettingsPage extends StatelessWidget {
  const AiSettingsPage({super.key, required this.controller});

  final BrowserController controller;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final colors = MiuixTheme.of(context).colors;
    return AnimatedBuilder(
      animation: controller,
      builder: (context, _) {
        final s = controller.settings;
        return RoamPageScaffold(
          title: 'AI 设置',
          child: ListView(
            padding: EdgeInsets.only(
              top: RoamPageScaffold.contentTopPadding + 4,
              bottom: 50 + MediaQuery.paddingOf(context).bottom,
            ),
            physics: const BouncingScrollPhysics(),
            children: [
              const MiuixSmallTitle('AI 服务'),
              RoamSettingCard(
                children: [
                  RoamSettingRow(
                    icon: 'assets/images/image.png',
                    label: '整理图片内容',
                    showChevron: false,
                    onTap: () => controller.updateSettings(
                      s.copyWith(aiImageTidy: !s.aiImageTidy),
                    ),
                    trailing: RoamSwitch(
                      value: s.aiImageTidy,
                      onChanged: (v) =>
                          controller.updateSettings(s.copyWith(aiImageTidy: v)),
                    ),
                  ),
                  RoamSettingRow(
                    icon: 'assets/images/web.png',
                    label: '分析已浏览的网页',
                    showChevron: false,
                    onTap: () => controller.updateSettings(
                      s.copyWith(aiPageInsight: !s.aiPageInsight),
                    ),
                    trailing: RoamSwitch(
                      value: s.aiPageInsight,
                      onChanged: (v) => controller.updateSettings(
                        s.copyWith(aiPageInsight: v),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              const MiuixSmallTitle('翻译服务'),
              _ApiConfigCard(controller: controller),
              Padding(
                padding: const EdgeInsets.fromLTRB(28, 10, 28, 0),
                child: MiuixText(
                  '接口需兼容 OpenAI 规范：地址填到 /v1，请求会自动补 '
                  '/chat/completions。默认使用哔哩哔哩 Index-Translate '
                  '免费接口（index-mt-35b），无需密钥。',
                  fontSize: 11.5,
                  height: 1.55,
                  color: isDark
                      ? Colors.white.withValues(alpha: 0.42)
                      : colors.onBackgroundVariant,
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _ApiConfigCard extends StatefulWidget {
  const _ApiConfigCard({required this.controller});

  final BrowserController controller;

  @override
  State<_ApiConfigCard> createState() => _ApiConfigCardState();
}

class _ApiConfigCardState extends State<_ApiConfigCard> {
  late final TextEditingController _base;
  late final TextEditingController _model;
  late final TextEditingController _key;
  final _baseFocus = FocusNode();
  final _modelFocus = FocusNode();
  final _keyFocus = FocusNode();
  bool _obscure = true;

  BrowserSettings get _settings => widget.controller.settings;

  @override
  void initState() {
    super.initState();
    _base = TextEditingController(text: _settings.aiApiBase);
    _model = TextEditingController(text: _settings.aiModel);
    _key = TextEditingController(text: _settings.aiApiKey);
    // 失焦即落盘：逐字保存会频繁写 prefs，失焦/回车足够。
    _baseFocus.addListener(() {
      if (!_baseFocus.hasFocus) _commitBase();
    });
    _modelFocus.addListener(() {
      if (!_modelFocus.hasFocus) _commitModel();
    });
    _keyFocus.addListener(() {
      if (!_keyFocus.hasFocus) _commitKey();
    });
  }

  @override
  void dispose() {
    _base.dispose();
    _model.dispose();
    _key.dispose();
    _baseFocus.dispose();
    _modelFocus.dispose();
    _keyFocus.dispose();
    super.dispose();
  }

  void _commitBase() {
    final value = _base.text.trim();
    if (value == _settings.aiApiBase) return;
    widget.controller.updateSettings(
      _settings.copyWith(
        aiApiBase: value.isEmpty ? BrowserSettings.defaultAiApiBase : value,
      ),
    );
  }

  void _commitModel() {
    final value = _model.text.trim();
    if (value == _settings.aiModel) return;
    widget.controller.updateSettings(
      _settings.copyWith(
        aiModel: value.isEmpty ? BrowserSettings.defaultAiModel : value,
      ),
    );
  }

  void _commitKey() {
    final value = _key.text.trim();
    if (value == _settings.aiApiKey) return;
    widget.controller.updateSettings(_settings.copyWith(aiApiKey: value));
  }

  void _resetDefaults() {
    _base.text = BrowserSettings.defaultAiApiBase;
    _model.text = BrowserSettings.defaultAiModel;
    _key.text = '';
    setState(() => _obscure = true);
    widget.controller.updateSettings(
      _settings.copyWith(
        aiApiBase: BrowserSettings.defaultAiApiBase,
        aiModel: BrowserSettings.defaultAiModel,
        aiApiKey: '',
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colors = MiuixTheme.of(context).colors;
    return Padding(
      padding: const EdgeInsets.fromLTRB(25, 4, 25, 4),
      child: MiuixCard(
        cornerRadius: 15,
        insideMargin: const EdgeInsets.fromLTRB(14, 14, 14, 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            MiuixTextField(
              controller: _base,
              focusNode: _baseFocus,
              label: '接口地址',
              useLabelAsPlaceholder: true,
              singleLine: true,
              keyboardType: TextInputType.url,
              textInputAction: TextInputAction.next,
              textStyle: MiuixTheme.of(context).textStyles.main,
              onSubmitted: (_) => _commitBase(),
            ),
            const SizedBox(height: 10),
            MiuixTextField(
              controller: _model,
              focusNode: _modelFocus,
              label: '模型',
              useLabelAsPlaceholder: true,
              singleLine: true,
              textInputAction: TextInputAction.next,
              textStyle: MiuixTheme.of(context).textStyles.main,
              onSubmitted: (_) => _commitModel(),
            ),
            const SizedBox(height: 8),
            SizedBox(
              height: 30,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                physics: const BouncingScrollPhysics(),
                itemCount: BrowserSettings.aiModelPresets.length,
                separatorBuilder: (_, _) => const SizedBox(width: 8),
                itemBuilder: (context, index) {
                  final preset = BrowserSettings.aiModelPresets[index];
                  return _ModelChip(
                    label: preset,
                    onTap: () {
                      _model.text = preset;
                      _commitModel();
                    },
                  );
                },
              ),
            ),
            const SizedBox(height: 10),
            MiuixTextField(
              controller: _key,
              focusNode: _keyFocus,
              label: 'API Key（B 站接口可留空）',
              useLabelAsPlaceholder: true,
              singleLine: true,
              obscureText: _obscure,
              textInputAction: TextInputAction.done,
              textStyle: MiuixTheme.of(context).textStyles.main,
              onSubmitted: (_) => _commitKey(),
              trailingIcon: PressableScale(
                scale: 0.9,
                onTap: () => setState(() => _obscure = !_obscure),
                child: Padding(
                  padding: const EdgeInsets.all(6),
                  child: Icon(
                    _obscure
                        ? Icons.visibility_off_rounded
                        : Icons.visibility_rounded,
                    size: 18,
                    color: colors.onBackgroundVariant,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                MiuixTextButton('恢复默认', onPressed: _resetDefaults),
                const Spacer(),
                MiuixText(
                  '当前：${_settings.aiModel}',
                  fontSize: 11,
                  color: colors.onBackgroundVariant,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _ModelChip extends StatelessWidget {
  const _ModelChip({required this.label, required this.onTap});

  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = MiuixTheme.of(context).colors;
    return PressableScale(
      scale: 0.94,
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: colors.secondaryContainer.withValues(alpha: 0.75),
          borderRadius: BorderRadius.circular(999),
        ),
        child: MiuixText(
          label,
          fontSize: 12,
          color: colors.onSecondaryContainer,
        ),
      ),
    );
  }
}
