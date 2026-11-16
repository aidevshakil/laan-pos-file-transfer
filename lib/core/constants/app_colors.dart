import 'package:flutter/material.dart';

class AppColors {
  AppColors._();

  static const Color primary = Color(0xFF2F5BEA);
  static const Color primaryDark = Color(0xFF1E3FBF);
  static const Color primarySoft = Color(0xFFEAF0FF);
  static const Color violet = Color(0xFF6D5DF6);
  static const Color violetSoft = Color(0xFFF0EDFF);
  static const Color ink = Color(0xFF0E1B4D);
  static const Color inkSoft = Color(0xFF1B2C6B);

  static const LinearGradient brandGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFF2F5BEA), Color(0xFF6D5DF6)],
  );
  static const LinearGradient heroGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFF0E1B4D), Color(0xFF1E3A9A)],
  );
  static const LinearGradient splashGradient = LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: [Color(0xFF1238C9), Color(0xFF0E1B4D)],
  );

  static const Color background = Color(0xFFF5F6FD);
  static const Color surface = Colors.white;
  static const Color surfaceMuted = Color(0xFFF7F8FC);

  static const Color textPrimary = Color(0xFF111A3A);
  static const Color textSecondary = Color(0xFF59627E);
  static const Color textMuted = Color(0xFF9AA2BA);

  static const Color border = Color(0xFFE6E9F4);
  static const Color borderStrong = Color(0xFFD3D8EA);

  static const Color running = primary;
  static const Color success = Color(0xFF16A34A);
  static const Color successSoft = Color(0xFFEAF8EF);
  static const Color warning = Color(0xFFD97706);
  static const Color warningSoft = Color(0xFFFFF7E6);
  static const Color danger = Color(0xFFE5484D);
  static const Color dangerSoft = Color(0xFFFFEEEE);
  static const Color neutral = Color(0xFF6B7393);

  static const Color upload = primary;
  static const Color uploadSoft = primarySoft;
  static const Color download = violet;
  static const Color downloadSoft = violetSoft;
}
