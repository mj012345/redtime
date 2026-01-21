import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:red_time_app/theme/app_colors.dart';
import 'package:red_time_app/theme/app_text_styles.dart';

enum NavTab { calendar, report, my }

class BottomNav extends StatelessWidget {
  final NavTab current;
  final ValueChanged<NavTab> onTap;

  const BottomNav({super.key, required this.current, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.background,
        border: const Border(top: BorderSide(color: AppColors.primaryLight)),
        boxShadow: [
          BoxShadow(
            color: AppColors.shadowLight,
            blurRadius: 10,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 6),
          child: Row(
            children: [
              Expanded(
                child: _NavItem(
                  svgString: '''
<svg width="24" height="24" viewBox="0 0 24 24" fill="none" xmlns="http://www.w3.org/2000/svg">
<path d="M4 8V16.8002C4 17.9203 4 18.4801 4.21799 18.9079C4.40973 19.2842 4.71547 19.5905 5.0918 19.7822C5.5192 20 6.07899 20 7.19691 20H16.8031C17.921 20 18.48 20 18.9074 19.7822C19.2837 19.5905 19.5905 19.2842 19.7822 18.9079C20 18.4805 20 17.9215 20 16.8036V8M4 8V7.2002C4 6.08009 4 5.51962 4.21799 5.0918C4.40973 4.71547 4.71547 4.40973 5.0918 4.21799C5.51962 4 6.08009 4 7.2002 4H8M4 8H12H20M20 8V7.19691C20 6.07899 20 5.5192 19.7822 5.0918C19.5905 4.71547 19.2837 4.40973 18.9074 4.21799C18.4796 4 17.9203 4 16.8002 4H16M16 2V4M16 4H8M8 2V4" stroke="white" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"/>
</svg>
''',
                  label: 'calendar',
                  selected: current == NavTab.calendar,
                  onTap: () => onTap(NavTab.calendar),
                ),
              ),
              Expanded(
                child: _NavItem(
                  svgString: '''
<svg width="24" height="24" viewBox="0 0 24 24" fill="none" xmlns="http://www.w3.org/2000/svg">
<path d="M3 15.0002V16.8C3 17.9201 3 18.4798 3.21799 18.9076C3.40973 19.2839 3.71547 19.5905 4.0918 19.7822C4.5192 20 5.07899 20 6.19691 20H21.0002M3 15.0002V5M3 15.0002L6.8534 11.7891L6.85658 11.7865C7.55366 11.2056 7.90288 10.9146 8.28154 10.7964C8.72887 10.6567 9.21071 10.6788 9.64355 10.8584C10.0105 11.0106 10.3323 11.3324 10.9758 11.9759L10.9822 11.9823C11.6357 12.6358 11.9633 12.9635 12.3362 13.1153C12.7774 13.2951 13.2685 13.3106 13.7207 13.1606C14.1041 13.0334 14.4542 12.7275 15.1543 12.115L21 7" stroke="white" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"/>
</svg>
''',
                  label: 'report',
                  selected: current == NavTab.report,
                  onTap: () => onTap(NavTab.report),
                ),
              ),
              Expanded(
                child: _NavItem(
                  svgString: '''
<svg width="24" height="24" viewBox="0 0 24 24" fill="none" xmlns="http://www.w3.org/2000/svg">
<path d="M20 21C20 18.2386 16.4183 16 12 16C7.58172 16 4 18.2386 4 21M12 13C9.23858 13 7 10.7614 7 8C7 5.23858 9.23858 3 12 3C14.7614 3 17 5.23858 17 8C17 10.7614 14.7614 13 12 13Z" stroke="white" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"/>
</svg>
''',
                  label: 'my',
                  selected: current == NavTab.my,
                  onTap: () => onTap(NavTab.my),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _NavItem extends StatelessWidget {
  final IconData? icon;
  final String? svgString;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _NavItem({
    this.icon,
    this.svgString,
    required this.label,
    required this.selected,
    required this.onTap,
  }) : assert(icon != null || svgString != null);

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () {
        HapticFeedback.lightImpact();
        onTap();
      },
      child: RepaintBoundary(
        child: TweenAnimationBuilder<Color?>(
          duration: const Duration(milliseconds: 200),
          tween: ColorTween(
            end: selected ? AppColors.primary : AppColors.textDisabled,
          ),
          builder: (context, color, child) {
            final activeColor = color ?? AppColors.textDisabled;
            return Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                AnimatedScale(
                  scale: selected ? 1.0 : 1.15,
                  duration: const Duration(milliseconds: 200),
                  curve: Curves.easeOutBack,
                  child: icon != null
                      ? Icon(icon, color: activeColor, size: 24)
                      : SvgPicture.string(
                          svgString!,
                          colorFilter:
                              ColorFilter.mode(activeColor, BlendMode.srcIn),
                          width: 22,
                          height: 22,
                        ),
                ),
                if (selected) ...[
                  const SizedBox(height: 2),
                  Text(
                    label,
                    style: AppTextStyles.caption.copyWith(
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
                      color: activeColor,
                    ),
                  ),
                ],
              ],
            );
          },
        ),
      ),
    );
  }
}
