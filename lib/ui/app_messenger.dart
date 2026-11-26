import 'package:flutter_miuix/miuix.dart';

/// 全局 Snackbar 宿主：WebView 的原生回调里没有 BuildContext，
/// 需要一条「不依赖当前页面」的提示通道。
///
/// 宿主挂在 `MaterialApp.builder` 里（Navigator 之上），所以设置页、弹层、
/// 下载页里的提示都能浮在最上层；样式走 flutter_miuix 的 MiuixSnackbar，
/// 与系统一致（squircle 圆角 + 毛玻璃）。
final MiuixSnackbarHostState roamSnackbarHost = MiuixSnackbarHostState();

/// 轻提示。对应原来的 SnackBar 调用点。
void showRoamToast(
  String message, {
  Duration duration = const Duration(seconds: 2),
}) {
  if (message.isEmpty) return;
  // custom 要求毫秒数大于 0；短于 600ms 的提示基本看不清，兜个底。
  final millis = duration.inMilliseconds < 600 ? 600 : duration.inMilliseconds;
  roamSnackbarHost.showSnackbar(
    message,
    duration: MiuixSnackbarDuration.custom(millis),
  );
}

/// 带确认动作的提示，返回用户是否点了动作按钮。
///
/// 用于「网站要打开其他 App」这类需要用户点头的操作：不必弹全屏对话框，
/// 一条 MiuixSnackbar + 动作按钮就够，不打断浏览。
Future<bool> showRoamConfirmToast(
  String message, {
  String actionLabel = '打开',
  Duration duration = const Duration(seconds: 8),
}) async {
  final result = await roamSnackbarHost.showSnackbar(
    message,
    actionLabel: actionLabel,
    withDismissAction: true,
    duration: MiuixSnackbarDuration.custom(duration.inMilliseconds),
  );
  return result == MiuixSnackbarResult.actionPerformed;
}
