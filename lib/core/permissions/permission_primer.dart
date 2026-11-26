import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../design/colors.dart';
import '../design/typography.dart';
import '../motion.dart';
import 'app_permissions.dart';

/// Hiện màn giải thích trước khi hệ thống hỏi quyền (thẻ nổi giữa màn hình: hình minh họa,
/// tiêu đề, lý do, "Cho phép" / "Để sau"). Quyền đã bị chặn thì nút chính mở Cài đặt.
///
/// [onAllow] thay cách xin quyền mặc định (vd thông báo đi qua Firebase Messaging để đăng ký
/// máy luôn). Trả trạng thái sau cùng, hoặc `null` nếu người dùng chọn "Để sau".
/// [step] / [total]: hiện "1/3" khi chạy chuỗi nhiều quyền.
Future<PermissionAccess?> showPermissionPrimer(
  BuildContext context, {
  required AppPermission permission,
  required PermissionGateway gateway,
  Future<PermissionAccess> Function()? onAllow,
  int? step,
  int? total,
}) async {
  final current = await gateway.status(permission);
  if (current.isGranted || current == PermissionAccess.unsupported) {
    return current;
  }
  if (!context.mounted) return null;
  return showGeneralDialog<PermissionAccess>(
    context: context,
    barrierDismissible: true,
    barrierLabel: 'Đóng',
    barrierColor: Colors.black.withValues(alpha: 0.55),
    transitionDuration: Motion.of(context, const Duration(milliseconds: 260)),
    pageBuilder: (context, _, __) => _PrimerDialog(
      permission: permission,
      blocked: current == PermissionAccess.blocked,
      gateway: gateway,
      onAllow: onAllow,
      step: step,
      total: total,
    ),
    transitionBuilder: (context, animation, _, child) {
      final curved =
          CurvedAnimation(parent: animation, curve: Curves.easeOutCubic);
      return FadeTransition(
        opacity: curved,
        child: ScaleTransition(
          scale: Tween<double>(begin: 0.94, end: 1).animate(curved),
          child: child,
        ),
      );
    },
  );
}

class _PrimerDialog extends StatefulWidget {
  const _PrimerDialog({
    required this.permission,
    required this.blocked,
    required this.gateway,
    this.onAllow,
    this.step,
    this.total,
  });

  final AppPermission permission;
  final bool blocked;
  final PermissionGateway gateway;
  final Future<PermissionAccess> Function()? onAllow;
  final int? step;
  final int? total;

  @override
  State<_PrimerDialog> createState() => _PrimerDialogState();
}

class _PrimerDialogState extends State<_PrimerDialog> {
  bool _busy = false;

  Future<void> _allow() async {
    setState(() => _busy = true);
    final navigator = Navigator.of(context);
    PermissionAccess result;
    if (widget.blocked) {
      await widget.gateway.openSettings();
      result = PermissionAccess.blocked;
    } else {
      result = await (widget.onAllow?.call() ??
          widget.gateway.request(widget.permission));
    }
    if (mounted) navigator.pop(result);
  }

  @override
  Widget build(BuildContext context) {
    final p = widget.permission;
    return SafeArea(
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 360),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Material(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(28),
              clipBehavior: Clip.antiAlias,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(24, 20, 24, 20),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (widget.step != null && widget.total != null)
                      Align(
                        alignment: Alignment.centerRight,
                        child: Text('${widget.step}/${widget.total}',
                            style: AppTextStyles.caption),
                      ),
                    PermissionIllustration(permission: p),
                    const SizedBox(height: 16),
                    Text(
                      p.title,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontFamily: AppFonts.body,
                        fontSize: 20,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      widget.blocked
                          ? '${p.purpose}\nQuyền đang tắt. Mở Cài đặt của máy để bật lại.'
                          : p.purpose,
                      textAlign: TextAlign.center,
                      style: AppTextStyles.body.copyWith(height: 1.45),
                    ),
                    const SizedBox(height: 22),
                    SizedBox(
                      width: double.infinity,
                      child: FilledButton(
                        onPressed: _busy ? null : _allow,
                        child: _busy
                            ? const SizedBox.square(
                                dimension: 20,
                                child:
                                    CircularProgressIndicator(strokeWidth: 2.5),
                              )
                            : Text(widget.blocked ? 'Mở cài đặt' : p.allowLabel),
                      ),
                    ),
                    const SizedBox(height: 10),
                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton(
                        onPressed: _busy ? null : () => Navigator.pop(context),
                        child: const Text('Để sau'),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Hình minh họa quyền: đốm màu nhạt hình hữu cơ, icon trong ô navy chuyển sắc, hai chấm trang trí.
class PermissionIllustration extends StatelessWidget {
  const PermissionIllustration(
      {super.key, required this.permission, this.size = 132});

  final AppPermission permission;
  final double size;

  @override
  Widget build(BuildContext context) => ExcludeSemantics(
        child: SizedBox.square(
          dimension: size,
          child: Stack(
            alignment: Alignment.center,
            children: [
              CustomPaint(
                size: Size.square(size),
                painter: _BlobPainter(AppColors.backgroundTint),
              ),
              Positioned(
                right: size * 0.16,
                top: size * 0.18,
                child: _Dot(size: size * 0.07, color: AppColors.mustard),
              ),
              Positioned(
                left: size * 0.18,
                bottom: size * 0.22,
                child: _Dot(size: size * 0.05, color: AppColors.brandAccent),
              ),
              Container(
                width: size * 0.46,
                height: size * 0.46,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(size * 0.14),
                  gradient: const LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [AppColors.leafFixed, AppColors.moss],
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.moss.withValues(alpha: 0.30),
                      blurRadius: 16,
                      offset: const Offset(0, 8),
                    ),
                  ],
                ),
                child: Icon(permission.icon,
                    color: AppColors.white, size: size * 0.24),
              ),
            ],
          ),
        ),
      );
}

class _Dot extends StatelessWidget {
  const _Dot({required this.size, required this.color});
  final double size;
  final Color color;

  @override
  Widget build(BuildContext context) => Container(
        width: size,
        height: size,
        decoration: BoxDecoration(color: color, shape: BoxShape.circle),
      );
}

/// Đốm hữu cơ: đường cong khép kín qua 8 điểm bán kính lệch nhau.
class _BlobPainter extends CustomPainter {
  _BlobPainter(this.color);
  final Color color;

  static const _radii = [0.92, 0.78, 0.95, 0.82, 0.9, 0.76, 0.97, 0.84];

  @override
  void paint(Canvas canvas, Size size) {
    final c = size.center(Offset.zero);
    final r = size.shortestSide / 2;
    final pts = <Offset>[
      for (var i = 0; i < _radii.length; i++)
        c +
            Offset.fromDirection(
                i * 2 * math.pi / _radii.length - math.pi / 2, r * _radii[i]),
    ];
    final path = Path();
    for (var i = 0; i < pts.length; i++) {
      final p0 = pts[i];
      final p1 = pts[(i + 1) % pts.length];
      final mid = Offset((p0.dx + p1.dx) / 2, (p0.dy + p1.dy) / 2);
      if (i == 0) {
        final prev = pts.last;
        path.moveTo((prev.dx + p0.dx) / 2, (prev.dy + p0.dy) / 2);
      }
      path.quadraticBezierTo(p0.dx, p0.dy, mid.dx, mid.dy);
    }
    path.close();
    canvas.drawPath(path, Paint()..color = color);
  }

  @override
  bool shouldRepaint(_BlobPainter old) => old.color != color;
}
