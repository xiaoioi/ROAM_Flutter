// ignore_for_file: deprecated_member_use

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_miuix/miuix.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'app.dart';
import 'services/browser_store.dart';
import 'state/browser_controller.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);

  // 预编译 OS4 玻璃的 6 个 fragment shader：不预热的话，第一次打开
  // 玻璃圆钮/对话框会在首帧同步编译，滚动一开始就掉一帧。
  // 失败不阻塞启动，组件会退回「模糊 + 原生混色」。
  MiuixGlassRendering.load();

  final preferences = await SharedPreferences.getInstance();
  final controller = BrowserController(store: BrowserStore(preferences));
  await controller.initialize();

  runApp(RoamApp(controller: controller));
}
