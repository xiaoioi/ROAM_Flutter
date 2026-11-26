// ignore_for_file: deprecated_member_use

import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_miuix/miuix.dart';

import '../../services/ai_translate_service.dart';
import '../../state/browser_controller.dart';
import '../widgets/glass_controls.dart';
import '../widgets/hyperos_top_bar.dart';
import '../widgets/roam_chrome.dart';
import 'ai_settings_page.dart';
import '../app_messenger.dart';

/// AI 翻译。
///
/// 界面按 HyperOS 的「输入 → 动作 → 结果」三段式组织：
///  - 语言条：源语言 / 目标语言，胶囊可选择；
///  - 原文卡：多行 MiuixTextField + 翻译按钮；
///  - 译文卡：可选中复制，底部标注服务与耗时。
///
/// 模型与接口从设置里读（默认哔哩哔哩 Index-Translate，OpenAI 兼容），
/// 顶栏齿轮直接进 AI 设置，缺 key / 换自建服务都在那里改。
class TranslatePage extends StatefulWidget {
  const TranslatePage({super.key, required this.controller, this.initialText});

  final BrowserController controller;

  /// 打开时预填的原文（例如菜单里带出来的当前页面文字）。
  final String? initialText;

  @override
  State<TranslatePage> createState() => _TranslatePageState();
}

class _TranslatePageState extends State<TranslatePage> {
  static const _targets = <String>['简体中文', '繁體中文', 'English', '日本語', '한국어'];
  static const _sources = <String>['auto', '中文', 'English', '日本語', '한국어'];

  final _input = TextEditingController();
  final _instruction = TextEditingController();
  final _service = const AiTranslateService();

  String _source = 'auto';
  String _target = '简体中文';
  bool _busy = false;
  bool _showInstruction = false;
  String? _error;
  TranslateResult? _result;

  @override
  void initState() {
    super.initState();
    final seeded = widget.initialText?.trim();
    if (seeded != null && seeded.isNotEmpty) {
      _input.text = seeded;
    }
  }

  @override
  void dispose() {
    _input.dispose();
    _instruction.dispose();
    super.dispose();
  }

  Future<void> _translate() async {
    final text = _input.text.trim();
    if (text.isEmpty) {
      setState(() => _error = '先输入要翻译的内容');
      return;
    }
    FocusScope.of(context).unfocus();
    setState(() {
      _busy = true;
      _error = null;
    });
    final settings = widget.controller.settings;
    try {
      final result = await _service.translate(
        text: text,
        sourceLang: _source,
        targetLang: _target,
        base: settings.aiApiBase,
        apiKey: settings.aiApiKey,
        model: settings.aiModel,
        instruction: _showInstruction ? _instruction.text : null,
      );
      if (!mounted) return;
      setState(() {
        _result = result;
        _busy = false;
      });
    } on TranslateException catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.message;
        _busy = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = '翻译失败：$e';
        _busy = false;
      });
    }
  }

  Future<void> _paste() async {
    final data = await Clipboard.getData(Clipboard.kTextPlain);
    final text = data?.text?.trim();
    if (text == null || text.isEmpty) {
      _toast('剪贴板是空的');
      return;
    }
    setState(() => _input.text = text);
  }

  /// 把当前网页的可见正文取过来。platform view 里跑 JS，失败就提示手贴。
  Future<void> _grabPageText() async {
    final tab = widget.controller.activeTab;
    final web = tab?.webController;
    if (tab == null || tab.isHome || web == null) {
      _toast('当前没有打开的网页');
      return;
    }
    try {
      final raw = await web.runJavaScriptReturningResult(
        'document.body ? document.body.innerText : ""',
      );
      final text = _unwrapJsString(raw).trim();
      if (text.isEmpty) {
        _toast('没取到正文，可能还没加载完');
        return;
      }
      setState(() {
        _input.text = text.length > 6000 ? text.substring(0, 6000) : text;
        _source = 'auto';
      });
      _toast('已取当前网页正文（超长部分已截断）');
    } catch (_) {
      _toast('读取网页失败，请手动粘贴');
    }
  }

  static String _unwrapJsString(Object? raw) {
    if (raw is String) {
      // Android 的 runJavaScriptReturningResult 返回带引号的 JSON 串。
      var value = raw;
      if (value.length >= 2 && value.startsWith('"') && value.endsWith('"')) {
        try {
          final decoded = jsonDecode(value);
          if (decoded is String) return decoded;
        } catch (_) {
          value = value.substring(1, value.length - 1);
        }
      }
      return value.replaceAll(r'\n', '\n');
    }
    return raw?.toString() ?? '';
  }

  void _toast(String message) {
    showRoamToast(message, duration: const Duration(milliseconds: 1600));
  }

  Future<void> _copyResult() async {
    final text = _result?.text;
    if (text == null || text.isEmpty) return;
    await Clipboard.setData(ClipboardData(text: text));
    if (mounted) _toast('译文已复制');
  }

  void _swapLanguages() {
    // 只交换「具体语言」；源语言是自动识别时保持不动。
    if (_source == 'auto') return;
    setState(() {
      final previous = _source;
      _source = _target == '简体中文' ? '中文' : _target;
      _target = previous == '中文' ? '简体中文' : previous;
    });
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final colors = MiuixTheme.of(context).colors;
    return RoamPageScaffold(
      title: '翻译',
      actions: [
        HyperosBarAction(
          asset: 'assets/images/settings_menu.png',
          tooltip: '翻译服务设置',
          onTap: () => Navigator.of(context).push(
            MaterialPageRoute<void>(
              builder: (_) => AiSettingsPage(controller: widget.controller),
            ),
          ),
        ),
      ],
      child: ListView(
        padding: EdgeInsets.fromLTRB(
          20,
          RoamPageScaffold.contentTopPadding + 4,
          20,
          40 + MediaQuery.paddingOf(context).bottom,
        ),
        physics: const BouncingScrollPhysics(),
        children: [
          _LanguageBar(
            source: _source,
            target: _target,
            sources: _sources,
            targets: _targets,
            onSource: (value) => setState(() => _source = value),
            onTarget: (value) => setState(() => _target = value),
            onSwap: _swapLanguages,
          ),
          const SizedBox(height: 14),
          MiuixTextField(
            controller: _input,
            label: '原文',
            minLines: 5,
            maxLines: 12,
            textStyle: MiuixTheme.of(context).textStyles.main,
            trailingIcon: _InputActions(
              onPaste: _paste,
              onGrab: _grabPageText,
              onClear: () {
                setState(() {
                  _input.clear();
                  _result = null;
                  _error = null;
                });
              },
            ),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: MiuixButton(
                  onPressed: _busy ? null : _translate,
                  colors: MiuixButtonDefaults.buttonColorsPrimary(context),
                  insideMargin: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 14,
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      if (_busy) ...[
                        SizedBox(
                          width: 15,
                          height: 15,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: colors.onPrimary,
                          ),
                        ),
                        const SizedBox(width: 8),
                      ] else ...[
                        Icon(
                          Icons.translate_rounded,
                          size: 17,
                          color: colors.onPrimary,
                        ),
                        const SizedBox(width: 6),
                      ],
                      MiuixText(
                        _busy ? '翻译中…' : '开始翻译',
                        color: colors.onPrimary,
                        fontWeight: FontWeight.w600,
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 10),
              MiuixButton(
                onPressed: () =>
                    setState(() => _showInstruction = !_showInstruction),
                child: Icon(
                  Icons.tune_rounded,
                  size: 18,
                  color: _showInstruction
                      ? colors.primary
                      : (isDark
                            ? Colors.white70
                            : Colors.black.withValues(alpha: 0.55)),
                ),
              ),
            ],
          ),
          if (_showInstruction) ...[
            const SizedBox(height: 10),
            MiuixTextField(
              controller: _instruction,
              label: '翻译要求（可选）',
              useLabelAsPlaceholder: true,
              minLines: 1,
              maxLines: 3,
              textStyle: MiuixTheme.of(context).textStyles.main,
            ),
            const SizedBox(height: 6),
            MiuixText(
              '例如「口语化」「保留 Markdown」「术语：prompt→提示词」',
              fontSize: 11.5,
              color: colors.onBackgroundVariant,
            ),
          ],
          const SizedBox(height: 18),
          _ResultCard(
            busy: _busy,
            error: _error,
            result: _result,
            onCopy: _copyResult,
            onRetry: _translate,
          ),
        ],
      ),
    );
  }
}

/// 语言选择条：源语言 / 目标语言两组胶囊 + 中间的交换键。
class _LanguageBar extends StatelessWidget {
  const _LanguageBar({
    required this.source,
    required this.target,
    required this.sources,
    required this.targets,
    required this.onSource,
    required this.onTarget,
    required this.onSwap,
  });

  final String source;
  final String target;
  final List<String> sources;
  final List<String> targets;
  final ValueChanged<String> onSource;
  final ValueChanged<String> onTarget;
  final VoidCallback onSwap;

  @override
  Widget build(BuildContext context) {
    final colors = MiuixTheme.of(context).colors;
    return MiuixCard(
      cornerRadius: 18,
      insideMargin: const EdgeInsets.fromLTRB(14, 12, 14, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              MiuixText('源语言', fontSize: 12, color: colors.onBackgroundVariant),
              const Spacer(),
              PressableScale(
                scale: 0.9,
                onTap: onSwap,
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  child: Icon(
                    Icons.swap_horiz_rounded,
                    size: 20,
                    color: colors.primary,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          _Pills(
            values: sources,
            selected: source,
            labelOf: (value) => value == 'auto' ? '自动识别' : value,
            onSelected: onSource,
          ),
          const SizedBox(height: 12),
          MiuixText('目标语言', fontSize: 12, color: colors.onBackgroundVariant),
          const SizedBox(height: 6),
          _Pills(
            values: targets,
            selected: target,
            labelOf: (value) => value,
            onSelected: onTarget,
          ),
        ],
      ),
    );
  }
}

class _Pills extends StatelessWidget {
  const _Pills({
    required this.values,
    required this.selected,
    required this.labelOf,
    required this.onSelected,
  });

  final List<String> values;
  final String selected;
  final String Function(String) labelOf;
  final ValueChanged<String> onSelected;

  @override
  Widget build(BuildContext context) {
    final colors = MiuixTheme.of(context).colors;
    return SizedBox(
      height: 34,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        physics: const BouncingScrollPhysics(),
        itemCount: values.length,
        separatorBuilder: (_, _) => const SizedBox(width: 8),
        itemBuilder: (context, index) {
          final value = values[index];
          final active = value == selected;
          return PressableScale(
            scale: 0.94,
            onTap: () => onSelected(value),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 160),
              padding: const EdgeInsets.symmetric(horizontal: 14),
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: active
                    ? colors.primary
                    : colors.secondaryContainer.withValues(alpha: 0.7),
                borderRadius: BorderRadius.circular(999),
              ),
              child: MiuixText(
                labelOf(value),
                fontSize: 13,
                fontWeight: active ? FontWeight.w600 : FontWeight.w500,
                color: active ? colors.onPrimary : colors.onSecondaryContainer,
              ),
            ),
          );
        },
      ),
    );
  }
}

/// 输入框右侧的小动作列：粘贴 / 取网页正文 / 清空。
class _InputActions extends StatelessWidget {
  const _InputActions({
    required this.onPaste,
    required this.onGrab,
    required this.onClear,
  });

  final VoidCallback onPaste;
  final VoidCallback onGrab;
  final VoidCallback onClear;

  @override
  Widget build(BuildContext context) {
    final colors = MiuixTheme.of(context).colors;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        MiuixIconButton(
          onPressed: onPaste,
          child: Icon(
            Icons.content_paste_rounded,
            size: 18,
            color: colors.onBackgroundVariant,
          ),
        ),
        MiuixIconButton(
          onPressed: onGrab,
          child: Icon(
            Icons.travel_explore_rounded,
            size: 18,
            color: colors.onBackgroundVariant,
          ),
        ),
        MiuixIconButton(
          onPressed: onClear,
          child: Icon(
            Icons.backspace_outlined,
            size: 18,
            color: colors.onBackgroundVariant,
          ),
        ),
      ],
    );
  }
}

class _ResultCard extends StatelessWidget {
  const _ResultCard({
    required this.busy,
    required this.error,
    required this.result,
    required this.onCopy,
    required this.onRetry,
  });

  final bool busy;
  final String? error;
  final TranslateResult? result;
  final VoidCallback onCopy;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final colors = MiuixTheme.of(context).colors;
    return MiuixCard(
      cornerRadius: 18,
      insideMargin: const EdgeInsets.fromLTRB(16, 14, 12, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              MiuixText(
                '译文',
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: colors.onBackgroundVariant,
              ),
              const Spacer(),
              if (result != null)
                PressableScale(
                  scale: 0.92,
                  onTap: onCopy,
                  child: Padding(
                    padding: const EdgeInsets.all(6),
                    child: Icon(
                      Icons.copy_rounded,
                      size: 18,
                      color: colors.primary,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 6),
          if (busy)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 18),
              child: Row(
                children: [
                  const SizedBox(
                    width: 14,
                    height: 14,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                  const SizedBox(width: 10),
                  MiuixText(
                    '正在请求 AI 翻译…',
                    fontSize: 14,
                    color: colors.onBackgroundVariant,
                  ),
                ],
              ),
            )
          else if (error != null)
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Padding(
                      padding: EdgeInsets.only(top: 2),
                      child: Icon(
                        Icons.error_outline_rounded,
                        size: 17,
                        color: Color(0xFFFF453A),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        error!,
                        style: const TextStyle(
                          fontSize: 13,
                          height: 1.5,
                          color: Color(0xFFFF453A),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                MiuixTextButton('重试', onPressed: onRetry),
              ],
            )
          else if (result != null)
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SelectableText(
                  result!.text,
                  style: TextStyle(
                    fontSize: 15,
                    height: 1.62,
                    color: colors.onBackground,
                  ),
                ),
                const SizedBox(height: 10),
                Divider(
                  height: 1,
                  color: colors.onBackgroundVariant.withValues(alpha: 0.18),
                ),
                const SizedBox(height: 8),
                MiuixText(
                  '${_modelLabel(result!.model)} · '
                  '${(result!.elapsed.inMilliseconds / 1000).toStringAsFixed(1)}s',
                  fontSize: 11,
                  color: colors.onBackgroundVariant,
                ),
              ],
            )
          else
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 18),
              child: MiuixText(
                '译文会显示在这里',
                fontSize: 14,
                color: colors.onBackgroundVariant,
              ),
            ),
        ],
      ),
    );
  }

  static String _modelLabel(String model) {
    if (model.startsWith('index-mt-')) {
      return 'Index-Translate ${model.substring('index-mt-'.length).toUpperCase()}';
    }
    return model;
  }
}
