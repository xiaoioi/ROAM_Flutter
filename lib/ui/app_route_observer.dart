// ignore_for_file: deprecated_member_use

import 'package:flutter/material.dart';

/// 全局路由观察者：让浏览器主界面知道「有没有新页面盖在上面」。
///
/// 预测式返回需要这个信息——设置页/书签页在前台时，手势应该交给它们
/// 自己的页面转场，主界面不能抢。
final RouteObserver<ModalRoute<void>> roamRouteObserver =
    RouteObserver<ModalRoute<void>>();
