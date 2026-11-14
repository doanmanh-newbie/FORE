import 'package:flutter/material.dart';

import '../../../core/motion.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/theme/app_theme.dart';
import '../domain/staff_contact.dart';

/// Công tắc nhỏ (viên thuốc nền nhạt) chọn nhập số điện thoại hay email. Dùng ở màn đăng nhập và màn tạo tài khoản nhân viên.
class ContactKindToggle extends StatelessWidget {
  const ContactKindToggle({
    super.key,
    required this.kind,
    required this.onChanged,
    this.enabled = true,
  });

  final ContactKind kind;
  final ValueChanged<ContactKind> onChanged;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    Widget segment(ContactKind k, String label) {
      final on = kind == k;
      return Expanded(
        child: Semantics(
          button: true,
          selected: on,
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: enabled ? () => onChanged(k) : null,
            child: AnimatedContainer(
              duration: Motion.of(context, const Duration(milliseconds: 200)),
              height: 40,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: on ? AppColors.surface : Colors.transparent,
                borderRadius: BorderRadius.circular(AppRadius.pill),
                boxShadow: on
                    ? [
                        BoxShadow(
                          color: AppColors.shadowMedium.withValues(alpha: 0.12),
                          blurRadius: 6,
                          offset: const Offset(0, 1),
                        ),
                      ]
                    : null,
              ),
              child: Text(
                label,
                style: AppTextStyles.segment.copyWith(
                  color: on ? AppColors.brand : AppColors.textSecondary,
                ),
              ),
            ),
          ),
        ),
      );
    }

    return DecoratedBox(
      decoration: BoxDecoration(
        color: AppColors.tint,
        borderRadius: BorderRadius.circular(AppRadius.pill),
        border: Border.all(color: AppColors.border),
      ),
      child: Padding(
        padding: const EdgeInsets.all(4),
        child: Row(
          children: [
            segment(ContactKind.phone, 'Số điện thoại'),
            segment(ContactKind.email, 'Email'),
          ],
        ),
      ),
    );
  }
}
