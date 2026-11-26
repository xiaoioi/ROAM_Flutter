// ignore_for_file: deprecated_member_use

import 'package:flutter/material.dart';

/// 星环的品牌色板：夜空为底，**miuix 蓝**为主色。
///
/// 强调色不再自创色相，直接取 flutter_miuix 的 `MiuixColors` 默认主色
/// （浅色 `#3482FF` / 深色 `#277AF7`），这样 Material 控件、`MiuixSwitch`、
/// 分段轨道、玻璃选中块全都是同一支蓝，不会再「突然冒出一块红色」。
/// [danger] 只留给「删除 / 危险操作」这类语义，不当强调色用。
abstract final class RoamColors {
  static const ink = Color(0xFF05070D);
  static const night = Color(0xFF080D19);
  static const deep = Color(0xFF0C1424);
  static const slate = Color(0xFF16203A);

  /// miuix 浅色主色。
  static const aurora = Color(0xFF3482FF);

  /// miuix 深色主色。
  static const auroraDeep = Color(0xFF277AF7);

  /// 次级蓝：miuix 滑块关键点前景色（浅色 `#6EB5FF`）。
  static const iris = Color(0xFF6EB5FF);
  static const sky = Color(0xFF5EC8FF);
  static const amber = Color(0xFFFFD08A);

  /// 危险操作：直接取 miuix 规范错误色（浅色 `#E94634`），不再自选粉红。
  static const danger = Color(0xFFE94634);

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
          // 浅色 #3482FF / 深色 #277AF7，与 MiuixColors 的两套主色一一对应。
          primary: isDark ? RoamColors.auroraDeep : RoamColors.aurora,
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
