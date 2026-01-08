import 'package:flutter/material.dart';
import 'package:red_time_app/theme/app_colors.dart';
import 'package:red_time_app/theme/app_spacing.dart';
import 'package:red_time_app/theme/app_text_styles.dart';

class MemoBottomSheet extends StatefulWidget {
  final String? initialMemo;
  final Function(String) onSave;
  final VoidCallback? onDelete;

  const MemoBottomSheet({
    super.key,
    this.initialMemo,
    required this.onSave,
    this.onDelete,
  });

  @override
  State<MemoBottomSheet> createState() => _MemoBottomSheetState();
}

class _MemoBottomSheetState extends State<MemoBottomSheet> {
  late TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.initialMemo ?? '');
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _handleSave() {
    widget.onSave(_controller.text);
    Navigator.of(context).pop();
  }

  void _handleDelete() {
    if (widget.onDelete != null) {
      widget.onDelete!();
      Navigator.of(context).pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
        left: AppSpacing.lg,
        right: AppSpacing.lg,
        top: AppSpacing.lg,
      ),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 드래그 핸들
          Center(
            child: Container(
              width: 40,
              height: 4,
              margin: const EdgeInsets.only(bottom: AppSpacing.md),
              decoration: BoxDecoration(
                color: AppColors.border,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          // 제목
          Text(
            '메모',
            style: AppTextStyles.title.copyWith(
              fontSize: 20,
              fontWeight: FontWeight.w700,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          // 텍스트 입력 필드
          TextField(
            controller: _controller,
            maxLines: 5,
            decoration: InputDecoration(
              hintText: '메모를 입력하세요...',
              hintStyle: AppTextStyles.body.copyWith(
                color: AppColors.textDisabled,
              ),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: AppColors.border),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: AppColors.border),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: AppColors.primary, width: 2),
              ),
              contentPadding: const EdgeInsets.all(AppSpacing.md),
            ),
            style: AppTextStyles.body,
          ),
          const SizedBox(height: AppSpacing.lg),
          // 버튼 영역
          Row(
            children: [
              // 삭제 버튼 (기존 메모가 있을 때만 표시)
              if (widget.initialMemo != null && widget.initialMemo!.isNotEmpty)
                Expanded(
                  child: OutlinedButton(
                    onPressed: _handleDelete,
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.red,
                      side: const BorderSide(color: Colors.red),
                      padding: const EdgeInsets.symmetric(
                        vertical: AppSpacing.md,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: Text(
                      '삭제',
                      style: AppTextStyles.body.copyWith(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: Colors.red,
                      ),
                    ),
                  ),
                ),
              if (widget.initialMemo != null && widget.initialMemo!.isNotEmpty)
                const SizedBox(width: AppSpacing.md),
              // 저장 버튼
              Expanded(
                child: ElevatedButton(
                  onPressed: _handleSave,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(
                      vertical: AppSpacing.md,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: Text(
                    '저장',
                    style: AppTextStyles.body.copyWith(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
        ],
      ),
    );
  }
}
