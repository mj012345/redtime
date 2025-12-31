import 'package:flutter/material.dart';
import 'package:red_time_app/theme/app_colors.dart';

class HorizontalLine extends StatelessWidget {
  const HorizontalLine({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(height: 1, color: AppColors.border);
  }
}
