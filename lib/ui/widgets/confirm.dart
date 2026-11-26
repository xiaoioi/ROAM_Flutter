// ignore_for_file: deprecated_member_use

import 'dart:ui' show ImageFilter;

import 'package:flutter/material.dart';
import 'package:flutter_miuix/miuix.dart';

import 'predictive_back.dart';
import 'roam_backdrop_scope.dart';

/// 对话框底部按钮：点按后以 [value] 关闭对话框。
class RoamDialogAction<T> {
  const RoamDialogAction({
    required this.label,
    required this.value,
    this.primary = false,
    this.destructive = false,
  });

  final String label;
  final T value;
  final bool primary;
  final bool destructive;
}

/// 通用 miuix 风格对话框（标题 + 说明 + 自定义内容 + 胶囊按钮）。
///
/// 表面走库的 `miuixGlassDialogSurface`：dialogGlass 三层材质 + small 高光
/// 描边 + 主题 background 兜底色，遮罩色也取 `GlassDialogDefaults.scrimColor`。
/// [RoamBackdropScope] 里的页面快照负责让对话框背后真的是糊的。
Future<T?> showRoamDialog<T>({
  required BuildContext context,
  required String title,
  required List<RoamDialogAction<T>> actions,
  String? message,
  Widget? body,
}) {
  final backdrop = RoamBackdropScope.samplingOf(context);
  return showDialog<T>(
    context: context,
    barrierColor: MiuixGlassDialogDefaults.scrimColor,
    builder: (dialogContext) => PredictiveBackScope(
      style: PredictiveBackStyle.dialog,
      onCommit: () => Navigator.of(dialogContext).maybePop(),
      child: _RoamDialog(
        title: title,
        message: message,
        body: body,
        backdrop: backdrop,
        actions: [
          for (final action in actions)
            _DialogAction(
              label: action.label,
              primary: action.primary,
              destructive: action.destructive,
              onPressed: () => Navigator.of(dialogContext).pop(action.value),
            ),
        ],
      ),
    ),
  );
}

/// 与系统柔光玻璃风格一致的确认框。
///
/// 面板 / 文本 / 按钮全部走 flutter_miuix：`MiuixSurface` 的 squircle
/// 圆角、`MiuixText` 的字体层级、`MiuixButton` 的胶囊按钮与按压缩放，
/// 比自绘的 TextButton 更贴近 HyperOS 4。
Future<bool> showRoamConfirm({
  required BuildContext context,
  required String title,
  required String message,
  String confirmLabel = '确定',
  String cancelLabel = '取消',
  bool destructive = false,
}) async {
  final result = await showRoamDialog<bool>(
    context: context,
    title: title,
    message: message,
    actions: [
      RoamDialogAction(label: cancelLabel, value: false),
      RoamDialogAction(
        label: confirmLabel,
        value: true,
        primary: true,
        destructive: destructive,
      ),
    ],
  );
  return result ?? false;
}

/// 单行文本输入对话框（重命名、自定义搜索模板等）。
Future<String?> showRoamInput({
  required BuildContext context,
  required String title,
  String? message,
  String initialValue = '',
  String hintText = '',
  String confirmLabel = '保存',
}) {
  final controller = TextEditingController(text: initialValue);
  final backdrop = RoamBackdropScope.samplingOf(context);
  return showDialog<String>(
    context: context,
    barrierColor: MiuixGlassDialogDefaults.scrimColor,
    builder: (dialogContext) => PredictiveBackScope(
      style: PredictiveBackStyle.dialog,
      onCommit: () => Navigator.of(dialogContext).maybePop(),
      child: _RoamDialog(
        title: title,
        message: message,
        backdrop: backdrop,
        body: Padding(
          padding: const EdgeInsets.only(top: 16),
          child: MiuixTextField(
            controller: controller,
            autofocus: true,
            singleLine: true,
            label: hintText,
            useLabelAsPlaceholder: true,
            textInputAction: TextInputAction.done,
            onSubmitted: (_) =>
                Navigator.of(dialogContext).pop(controller.text.trim()),
          ),
        ),
        actions: [
          _DialogAction(
            label: '取消',
            onPressed: () => Navigator.of(dialogContext).pop(),
          ),
          _DialogAction(
            label: confirmLabel,
            primary: true,
            onPressed: () =>
                Navigator.of(dialogContext).pop(controller.text.trim()),
          ),
        ],
      ),
    ),
  );
}

class _DialogAction {
  const _DialogAction({
    required this.label,
    required this.onPressed,
    this.primary = false,
    this.destructive = false,
  });

  final String label;
  final VoidCallback onPressed;
  final bool primary;
  final bool destructive;
}

/// 柔光玻璃对话框：28dp squircle、标题 17sp、正文 14sp、底部胶囊按钮。
///
/// 表面由库的 `miuixGlassDialogSurface` 出（与 `MiuixGlassDialog` 同一套），
/// 没有页面快照时退回 BackdropFilter + 同一份 dialogGlass 材质，
/// 保证网页 tab（platform view 不进快照）上也是"背后是糊的"。
class _RoamDialog extends StatelessWidget {
  const _RoamDialog({
    required this.title,
    required this.actions,
    this.message,
    this.body,
    this.backdrop,
  });

  final String title;
  final String? message;
  final Widget? body;
  final MiuixBackdrop? backdrop;
  final List<_DialogAction> actions;

  @override
  Widget build(BuildContext context) {
    final miuix = MiuixTheme.of(context);
    final dark = miuix.colors.background.computeLuminance() < .5;
    final fg = miuix.colors.onSurface;
    final sub = miuix.colors.onSurfaceVariantSummary;
    final hasBackdrop = backdrop?.hasContent ?? false;

    final fallbackFill = (dark ? const Color(0xFF242424) : Colors.white)
        .withValues(alpha: 0.82);
    Widget surface = miuixGlassDialogSurface(
      backdrop: hasBackdrop ? backdrop : null,
      containerColor: hasBackdrop ? null : fallbackFill,
    )(
      context,
      28,
      MiuixGlassDialogDefaults.scrimColor,
      1.0,
      Padding(
        padding: const EdgeInsets.fromLTRB(24, 22, 24, 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            MiuixText(
              title,
              textAlign: TextAlign.center,
              fontSize: 17,
              fontWeight: FontWeight.w700,
              height: 1.3,
              color: fg,
            ),
            if (message != null && message!.isNotEmpty) ...[
              const SizedBox(height: 8),
              MiuixText(
                message!,
                textAlign: TextAlign.center,
                fontSize: 14,
                height: 1.45,
                color: sub,
              ),
            ],
            ?body,
            const SizedBox(height: 20),
            Row(
              children: [
                for (var i = 0; i < actions.length; i++) ...[
                  if (i > 0) const SizedBox(width: 8),
                  Expanded(child: _DialogActionButton(action: actions[i])),
                ],
              ],
            ),
          ],
        ),
      ),
    );

    if (!hasBackdrop) {
      final blur = MiuixGlassDialogDefaults.material(context).blurRadius * .45;
      surface = ClipRRect(
        borderRadius: BorderRadius.circular(28),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: blur, sigmaY: blur),
          child: surface,
        ),
      );
    }

    return Dialog(
      backgroundColor: Colors.transparent,
      elevation: 0,
      insetPadding: const EdgeInsets.symmetric(horizontal: 34),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 360),
        child: surface,
      ),
    );
  }
}

class _DialogActionButton extends StatelessWidget {
  const _DialogActionButton({required this.action});

  final _DialogAction action;

  @override
  Widget build(BuildContext context) {
    // 官方 GlassDialogButton：普通/危险用半透明底 + 文字色区分，
    // 主按钮用主题主色，16dp 圆角、50dp 高，不再自选胶囊与红底白字。
    return MiuixGlassDialogButton(
      onPressed: action.onPressed,
      role: action.destructive
          ? MiuixGlassDialogButtonRole.destructive
          : action.primary
          ? MiuixGlassDialogButtonRole.primary
          : MiuixGlassDialogButtonRole.normal,
      insideMargin: const EdgeInsets.symmetric(horizontal: 10),
      child: Text(action.label, maxLines: 1, overflow: TextOverflow.ellipsis),
    );
  }
}
