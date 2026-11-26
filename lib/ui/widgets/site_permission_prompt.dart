// ignore_for_file: deprecated_member_use

import 'package:flutter/material.dart';
import 'package:flutter_miuix/miuix.dart';

import '../../services/web_permission_service.dart';
import '../../theme/roam_theme.dart';
import 'confirm.dart';
import 'roam_chrome.dart';

/// 挂在浏览器主界面上，负责把 [WebPermissionService] 的待确认申请
/// 变成一次 miuix 风格的对话框。
///
/// WebView 的权限回调来自原生线程，不能直接弹框，必须经由这里在
/// Flutter 侧完成。
class SitePermissionHost extends StatefulWidget {
  const SitePermissionHost({super.key, required this.child});

  final Widget child;

  @override
  State<SitePermissionHost> createState() => _SitePermissionHostState();
}

class _SitePermissionHostState extends State<SitePermissionHost> {
  final WebPermissionService _service = WebPermissionService.instance;
  bool _showing = false;

  @override
  void initState() {
    super.initState();
    _service.addListener(_onChanged);
    _onChanged();
  }

  @override
  void dispose() {
    _service.removeListener(_onChanged);
    super.dispose();
  }

  void _onChanged() {
    if (_showing) return;
    final prompt = _service.pending;
    if (prompt == null) return;
    _showing = true;
    WidgetsBinding.instance.addPostFrameCallback((_) => _present(prompt));
  }

  Future<void> _present(SitePermissionPrompt prompt) async {
    if (!mounted) {
      _showing = false;
      _service.reject();
      return;
    }

    final remember = ValueNotifier<bool>(false);
    final kinds = prompt.kinds.toList()
      ..sort((a, b) => a.index.compareTo(b.index));
    final names = kinds.map((kind) => kind.label).join('、');
    final reasons = kinds.map((kind) => kind.reason).join('；');

    final allow = await showRoamDialog<bool>(
      context: context,
      title: '允许 ${prompt.host} 使用$names？',
      message: '该网站想要$reasons。',
      body: Padding(
        padding: const EdgeInsets.only(top: 14),
        child: Row(
          children: [
            Expanded(
              child: MiuixText(
                '记住此网站的选择',
                fontSize: 14,
                color: Theme.of(context).brightness == Brightness.dark
                    ? RoamColors.textSecondary
                    : RoamColors.daySecondary,
              ),
            ),
            ValueListenableBuilder<bool>(
              valueListenable: remember,
              builder: (context, value, _) => RoamSwitch(
                value: value,
                onChanged: (next) => remember.value = next,
              ),
            ),
          ],
        ),
      ),
      actions: [
        RoamDialogAction(label: '拒绝', value: false),
        RoamDialogAction(label: '允许', value: true, primary: true),
      ],
    );

    if (allow == true) {
      _service.approve(remember: remember.value);
    } else {
      _service.reject(remember: remember.value);
    }
    remember.dispose();
    _showing = false;

    // 队列里可能还有下一个申请。
    _onChanged();
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
