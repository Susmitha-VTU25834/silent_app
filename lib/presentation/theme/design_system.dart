import 'package:flutter/material.dart';

class AppThemeMode {
  static bool isDark = true;
}

class AppColors {
  static Color get primary => AppThemeMode.isDark ? const Color(0xFF6366F1) : const Color(0xFF4F46E5); // Indigo
  static Color get secondary => const Color(0xFF06B6D4); // Cyan
  static Color get accent => const Color(0xFF10B981); // Emerald
  static Color get background => AppThemeMode.isDark ? const Color(0xFF121212) : const Color(0xFFF3F4F6);
  static Color get surface => AppThemeMode.isDark ? const Color(0xFF1E1E1E) : Colors.white;
  static Color get border => AppThemeMode.isDark ? const Color(0xFF2C2C2C) : const Color(0xFFE5E7EB);
  static Color get textPrimary => AppThemeMode.isDark ? Colors.white : const Color(0xFF111827);
  static Color get textSecondary => AppThemeMode.isDark ? const Color(0xFFB3B3B3) : const Color(0xFF6B7280);
}

class AppDesign {
  static BoxDecoration surfaceDecoration({Color? color, double borderRadius = 16}) {
    return BoxDecoration(
      color: color ?? AppColors.surface,
      borderRadius: BorderRadius.circular(borderRadius),
      border: Border.all(color: AppColors.border, width: 1),
      boxShadow: [
        BoxShadow(
          color: Colors.black.withOpacity(0.2),
          blurRadius: 8,
          offset: const Offset(0, 4),
        )
      ],
    );
  }

  static Widget surfaceContainer({
    required Widget child,
    EdgeInsets padding = const EdgeInsets.all(16),
    Color? color,
    double borderRadius = 16,
  }) {
    return Container(
      padding: padding,
      decoration: surfaceDecoration(color: color, borderRadius: borderRadius),
      child: child,
    );
  }
}
