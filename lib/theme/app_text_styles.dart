import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:red_time_app/theme/app_colors.dart';

class AppTextStyles {
  const AppTextStyles._();

  static TextStyle title = GoogleFonts.notoSansKr(
    fontSize: 16,
    fontWeight: FontWeight.w700,
    color: AppColors.textPrimary,
  );

  static TextStyle body = GoogleFonts.notoSansKr(
    fontSize: 14,
    fontWeight: FontWeight.w500,
    color: AppColors.textPrimary,
  );

  static TextStyle caption = GoogleFonts.notoSansKr(
    fontSize: 12,
    fontWeight: FontWeight.w400,
    color: AppColors.textSecondary,
  );
}
