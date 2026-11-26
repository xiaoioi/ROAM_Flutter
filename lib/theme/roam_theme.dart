// ignore_for_file: deprecated_member_use

import 'package:flutter/material.dart';

/// 星环的品牌色板：夜空为底，极光青为主色，虹紫作次色。
abstract final class RoamColors {
  static const ink = Color(0xFF05070D);
  static const night = Color(0xFF080D19);
  static const deep = Color(0xFF0C1424);
  static const slate = Color(0xFF16203A);

  static const aurora = Color(0xFF4EE3C2);
  static const auroraDeep = Color(0xFF17B99B);
  static const iris = Color(0xFF8C7BFF);
  static const sky = Color(0xFF3FC6FF);
  static const amber = Color(0xFFFFD08A);
  static const danger = Color(0xFFFF6B6B);

  static const textPrimary = Color(0xFFF2F7FF);
  static const textSecondary = Color(0xFF9FB0CB);
  static const textTertiary = Color(0xFF6B7C99);

  static const daySky = Color(0xFFF3F3F3);
  static const dayInk = Color(0xFF121216);
  static const daySecondary = Color(0xFF4C5D75);

  /// ROAM 原生界面的中性色：卡片、圆形图标底、次级文字。
  static const cardDark = Color(0xFF1C1C1E);
  static const itemDark = Color(0xFF2C2C2E);
  static const cardLight = Color(0xFFFFFFFF);
  static const itemLight = Color(0xFFECECEE);
  static const dimDark = Color(0xFF9A9AA0);
  static const dimLight = Color(0xFF6E6E76);
}

abstract final class RoamTheme {
  static ThemeData build(Brightness brightness, {String? fontFamily}) {
    final isDark = brightness == Brightness.dark;
    final scheme =
        ColorScheme.fromSeed(
          seedColor: RoamColors.aurora,
          brightness: brightness,
        ).copyWith(
          primary: isDark ? RoamColors.aurora : RoamColors.auroraDeep,
          secondary: RoamColors.iris,
          surface: isDark ? RoamColors.night : Colors.white,
          error: RoamColors.danger,
        );

    final base = ThemeData(
      useMaterial3: true,
      brightness: brightness,
      colorScheme: scheme,
      fontFamily: fontFamily,
      scaffoldBackgroundColor: isDark ? Colors.black : RoamColors.daySky,
      splashFactory: NoSplash.splashFactory,
      highlightColor: Colors.transparent,
    );

    return base.copyWith(
      textTheme: base.textTheme.apply(
        fontFamily: fontFamily,
        bodyColor: isDark ? RoamColors.textPrimary : RoamColors.dayInk,
        displayColor: isDark ? RoamColors.textPrimary : RoamColors.dayInk,
      ),
      iconTheme: IconThemeData(
        color: isDark ? RoamColors.textPrimary : RoamColors.dayInk,
      ),
      dividerTheme: DividerThemeData(
        color: (isDark ? Colors.white : Colors.black).withValues(alpha: 0.08),
        thickness: 1,
        space: 1,
      ),
      pageTransitionsTheme: const PageTransitionsTheme(
        builders: {
          // Android 14+ 的预测式返回：侧滑时实时预览上一页，
          // 松手才真正 pop，回拖可以取消。系统没开「预测式返回」
          // 或版本低于 14 时，builder 内部自动退回 FadeForwards，
          // 转场与之前完全一致。
          TargetPlatform.android: PredictiveBackPageTransitionsBuilder(),
          TargetPlatform.iOS: FadeForwardsPageTransitionsBuilder(),
        },
      ),
    );
  }
}

/// 全局的间距与圆角节奏，避免各处魔法数字漂移。
abstract final class RoamMetrics {
  static const gutter = 16.0;
  static const barHeight = 52.0;
  static const dockHeight = 60.0;
  static const cardRadius = 22.0;
  static const panelRadius = 28.0;
}

/// 关键字号与字重，中文优先使用系统字体。
abstract final class RoamType {
  static const wordmark = TextStyle(
    fontSize: 26,
    height: 1.1,
    fontWeight: FontWeight.w700,
    letterSpacing: 2.4,
  );

  static const title = TextStyle(
    fontSize: 17,
    height: 1.25,
    fontWeight: FontWeight.w600,
    letterSpacing: 0.2,
  );

  static const body = TextStyle(
    fontSize: 14,
    height: 1.45,
    fontWeight: FontWeight.w400,
  );

  static const caption = TextStyle(
    fontSize: 11.5,
    height: 1.3,
    fontWeight: FontWeight.w500,
    letterSpacing: 0.3,
  );

  static const mono = TextStyle(
    fontSize: 13,
    height: 1.3,
    fontWeight: FontWeight.w500,
    letterSpacing: 0.1,
    fontFeatures: [FontFeature.tabularFigures()],
  );
}
