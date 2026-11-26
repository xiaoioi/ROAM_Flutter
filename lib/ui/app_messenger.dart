import 'package:flutter/material.dart';

/// 全局 Messenger：WebView 的原生回调里没有 BuildContext，
/// 需要一条「不依赖当前页面」的提示通道。
final GlobalKey<ScaffoldMessengerState> roamMessengerKey =
    GlobalKey<ScaffoldMessengerState>();

void showRoamToast(
  String message, {
  Duration duration = const Duration(seconds: 2),
}) {
  final messenger = roamMessengerKey.currentState;
  if (messenger == null) return;
  messenger
    ..hideCurrentSnackBar()
    ..showSnackBar(
      SnackBar(
        content: Text(message, textAlign: TextAlign.center),
        duration: duration,
        behavior: SnackBarBehavior.floating,
        backgroundColor: const Color(0xE6202026),
        elevation: 0,
        margin: const EdgeInsets.fromLTRB(28, 0, 28, 96),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      ),
    );
}
