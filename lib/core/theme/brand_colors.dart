import 'package:flutter/material.dart';

/// Shared indigo brand palette used across user-facing screens.
///
/// Kept in one place so screen shells (dashboard, ride history, offers,
/// support center, privacy policy) stay visually consistent instead of
/// each screen re-declaring its own hex constants.
class BrandColors {
  BrandColors._();

  static const Color brand = Color(0xFF4F46E5);
  static const Color brandDark = Color(0xFF1E1B4B);
  static const Color bgLight = Color(0xFFF4F6FA);
}
