import 'package:flutter/material.dart';

class AppColors {
  const AppColors._();

  // 기본 팔레트
  static const Color primary = Color(0xFFD32F2F);
  static const Color primaryLight = Color(0xFFFFEBEE);
  static const Color secondary = Color(0xFF8D5656);

  // 배경/테두리
  static const Color background = Color(0xFFFFFDFC);
  static const Color surface = Colors.white;
  static const Color border = Color(0xFFEEEEEE);

  // 텍스트
  static const Color textPrimary = Color(0xFF333333);
  static const Color textSecondary = Color(0xFF8D5656);
  static const Color textDisabled = Color(0xFFAAAAAA);

  // 그림자
  static Color shadowLight = Colors.black.withValues(alpha: 0.05);
  static Color shadowChip = Colors.black.withValues(alpha: 0.1);
}

