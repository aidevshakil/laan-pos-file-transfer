import 'package:flutter/material.dart';

/// Industrial POS (Point of Sale) Enterprise Color Palette.
/// High contrast, tactile, optimized for retail counters and handheld POS screens.
class AppColors {
  AppColors._();

  // POS Base Terminal Colors (Dark Slate / High Contrast)
  static const Color posDarkHeader = Color(0xFF0F172A); // Slate 900
  static const Color posSidebar = Color(0xFF1E293B);    // Slate 800
  static const Color posSidebarActive = Color(0xFF334155); // Slate 700

  static const Color background = Color(0xFFF1F5F9);    // Slate 100
  static const Color surface = Colors.white;
  static const Color surfaceMuted = Color(0xFFF8FAFC);  // Slate 50
  static const Color surfaceCard = Colors.white;

  // POS Brand Accents
  static const Color posAccent = Color(0xFF0284C7);     // Terminal Sky Blue
  static const Color posAccentDark = Color(0xFF0369A1);
  static const Color posOrange = Color(0xFFF97316);     // Retail Action Orange

  // High-contrast Typography
  static const Color textPrimary = Color(0xFF0F172A);
  static const Color textSecondary = Color(0xFF475569);
  static const Color textMuted = Color(0xFF94A3B8);

  // Borders & Dividers
  static const Color border = Color(0xFFCBD5E1);
  static const Color borderLight = Color(0xFFE2E8F0);

  // POS Status Indicators (Terminal Telemetry)
  static const Color posOnline = Color(0xFF10B981);     // Emerald green
  static const Color running = Color(0xFF0284C7);       // Active sync blue
  static const Color paused = Color(0xFFF59E0B);        // Amber warning
  static const Color failed = Color(0xFFEF4444);        // Error red
  static const Color queued = Color(0xFF64748B);        // Queued slate
  static const Color success = Color(0xFF10B981);       // Success
}
