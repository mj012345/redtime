import 'package:flutter/material.dart';

class AppColors {
  const AppColors._();

  // 기본 팔레트
  static const Color primary = Color(0xFFF35A4E);
  static const Color primaryLight = Color(0xFFFFF4EA);
  static const Color secondary = Color(0xFF8D5656);

  // 배경/테두리
  static const Color background = Color(0xFFFBF9F5);
  static const Color surface = Colors.white;
  static const Color border = Color(0xFFEEEEEE);
  static const Color disabled = Color(0xFFFAFAFA);

  // 텍스트
  static const Color textPrimary = Color(0xFF333333);
  static const Color textPrimaryLight = Color(0xFFF35A4E);
  static const Color textSecondary = Color(0xFF8D5656);
  static const Color textDisabled = Color(0xFFAAAAAA);

  // 그림자
  static Color shadowLight = Colors.black.withValues(alpha: 0.05);
  static Color shadowChip = Colors.black.withValues(alpha: 0.1);
}

class SymptomColors {
  const SymptomColors._();

  static const Color period = Color(0xFFFEEEEE); // 생리일
  static const Color fertile = Color(0xFFECFDF5); // 가임기
  static const Color border = Color(0xFFE7E7E7); // 테두리
  static const Color symptomBase = Color(0xFFFFDD85); // 증상 기본 색상
  static const Color goodSymptom = Color(0xFFACEEBB); // 좋음 증상 색상
  static const Color relationship = Color(0xFFFF80AB); // 관계(하트) 색상
  static const Color memo = Color(0xFF91C2F4); // 메모 색상
  static const Color frequentHigh = Color(0xFFF27676); // 가장 많이 기록된 증상 색상
  static const Color frequentMid = Color(0xFFF59D6E); // 두 번째 많이 기록된 증상 색상
  static const Color frequentLow = Color(0xFFF8DC82); // 세 번째 많이 기록된 증상 색상
}
