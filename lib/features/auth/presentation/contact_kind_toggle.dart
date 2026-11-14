import 'package:flutter/material.dart';

import '../../../core/motion.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_theme.dart';
import '../domain/staff_contact.dart';

/// Công tắc chọn nhập số điện thoại hay email. Dùng ở màn đăng nhập và màn tạo tài khoản nhân viên.
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
                color: on ? AppColors.brand : Colors.transparent,
                borderRadius: BorderRadius.circular(AppSizes.radius - 2),
              ),
              child: Text(
                label,
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                  color: on ? AppColors.onInk : AppColors.brand,
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
        borderRadius: BorderRadius.circular(AppSizes.radius),
      ),
      child: Padding(
        padding: const EdgeInsets.all(3),
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
