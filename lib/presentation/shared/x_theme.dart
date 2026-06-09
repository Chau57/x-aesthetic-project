import 'package:flutter/material.dart';

class XColors {
  static const darkBackground = Color(0xFF05080C);
  static const darkBackground2 = Color(0xFF0B1118);
  static const darkSurface = Color(0xFF111820);
  static const darkSurface2 = Color(0xFF18202A);
  static const darkBorder = Color(0xFF2A3541);

  static const lightBackground = Color(0xFFF7F8F5);
  static const lightSurface = Color(0xFFFFFFFF);
  static const lightSurface2 = Color(0xFFF2F5F0);
  static const lightBorder = Color(0xFFE3E8DF);

  static const muted = Color(0xFF8A96A3);
  static const darkText = Color(0xFFF4F7FA);
  static const lightText = Color(0xFF101814);
  static const cyan = Color(0xFF10BDF5);
  static const cyan2 = Color(0xFF22D3EE);
  static const green = Color(0xFF2F7D3B);
  static const greenBright = Color(0xFF29E06D);
  static const amber = Color(0xFFFFC44D);
  static const orange = Color(0xFFFF6235);
}

class XThemeTokens {
  final bool isDark;

  const XThemeTokens(this.isDark);

  Color get background =>
      isDark ? XColors.darkBackground : XColors.lightBackground;
  Color get background2 =>
      isDark ? XColors.darkBackground2 : XColors.lightSurface2;
  Color get surface => isDark ? XColors.darkSurface : XColors.lightSurface;
  Color get surface2 => isDark ? XColors.darkSurface2 : XColors.lightSurface2;
  Color get border =>
      isDark ? Colors.white.withValues(alpha: 0.12) : XColors.lightBorder;
  Color get text => isDark ? XColors.darkText : XColors.lightText;
  Color get muted => isDark ? XColors.muted : const Color(0xFF657064);
  Color get primary => isDark ? XColors.cyan : XColors.green;
  Color get primarySoft => primary.withValues(alpha: isDark ? 0.16 : 0.10);
  Color get positive => isDark ? XColors.greenBright : XColors.green;
  Color get warning => XColors.amber;
  Color get error => XColors.orange;
  Color get shadow => isDark
      ? Colors.black.withValues(alpha: 0.40)
      : Colors.black.withValues(alpha: 0.08);

  LinearGradient get backgroundGradient => LinearGradient(
        colors: isDark
            ? const [
                XColors.darkBackground,
                XColors.darkBackground2,
                XColors.darkBackground
              ]
            : const [Color(0xFFFAFBF8), Color(0xFFF4F7F0), Color(0xFFF9FAF7)],
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
      );
}

extension XThemeContext on BuildContext {
  XThemeTokens get x =>
      XThemeTokens(Theme.of(this).brightness == Brightness.dark);
}

class XAestheticTheme {
  static ThemeData get darkTheme {
    final base = ThemeData.dark(useMaterial3: true);
    return base.copyWith(
      scaffoldBackgroundColor: XColors.darkBackground,
      colorScheme: ColorScheme.fromSeed(
        seedColor: XColors.cyan,
        brightness: Brightness.dark,
        primary: XColors.cyan,
        secondary: XColors.cyan2,
        surface: XColors.darkSurface,
      ),
      textTheme: base.textTheme.apply(
        bodyColor: XColors.darkText,
        displayColor: XColors.darkText,
        fontFamily: 'Roboto',
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
      ),
    );
  }

  static ThemeData get lightTheme {
    final base = ThemeData.light(useMaterial3: true);
    return base.copyWith(
      scaffoldBackgroundColor: XColors.lightBackground,
      colorScheme: ColorScheme.fromSeed(
        seedColor: XColors.green,
        brightness: Brightness.light,
        primary: XColors.green,
        secondary: XColors.green,
        surface: XColors.lightSurface,
      ),
      textTheme: base.textTheme.apply(
        bodyColor: XColors.lightText,
        displayColor: XColors.lightText,
        fontFamily: 'Roboto',
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
      ),
    );
  }
}
