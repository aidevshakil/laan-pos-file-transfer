import 'package:flutter/material.dart';

/// Clean color palette optimized for POS (Point of Sale) enterprise environments.
class AppColors {
  AppColors._();

  static const Color primary = Color(0xFF0F172A); // Slate 900
  static const Color primaryLight = Color(0xFF1E293B); // Slate 800
  static const Color accent = Color(0xFF2563EB); // Royal Blue
  static const Color accentLight = Color(0xFF3B82F6);

  static const Color background = Color(0xFFF8FAFC); // Slate 50
  static const Color surface = Colors.white;
  static const Color surfaceMuted = Color(0xFFF1F5F9); // Slate 100

  static const Color textPrimary = Color(0xFF0F172A);
  static const Color textSecondary = Color(0xFF64748B); // Slate 500
  static const Color textMuted = Color(0xFF94A3B8); // Slate 400

  static const Color border = Color(0xFFE2E8F0); // Slate 200
  static const Color divider = Color(0xFFF1F5F9);

  // Status colors
  static const Color success = Color(0xFF10B981); // Emerald 500
  static const Color running = Color(0xFF2563EB); // Blue
  static const Color paused = Color(0xFFF59E0B); // Amber 500
  static const Color failed = Color(0xFFEF4444); // Red 500
  static const Color queued = Color(0xFF6B7280); // Gray 500
}
