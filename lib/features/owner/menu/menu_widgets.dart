import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/design/colors.dart';
import '../../../core/design/spacing.dart';
import '../../../core/design/typography.dart';
import '../../../core/widgets/content_width.dart';
import '../../../core/errors/app_failure.dart';
import '../../../core/errors/failure_messages.dart';
import '../../../core/errors/network_errors.dart';
import '../../../core/format.dart';
import '../../auth/application/session_controller.dart';
import 'menu_format.dart';
import 'menu_store.dart';
import '../../../core/widgets/lazy_list_view.dart';

SessionState? _sessionState(BuildContext context) {
  try {
    return context.read<SessionController>().state;
  } on ProviderNotFoundException {
    return null;
  }
}

/// Tên quán đang chọn (hiện ở góc phải của thanh trên các màn Thực đơn).
String menuShopName(BuildContext context) {
  final state = _sessionState(context);
  if (state is SessionReady && state.profile.shopName.isNotEmpty) {
    return state.profile.shopName;
  }
  return 'Fore';
}

String menuOwnerName(BuildContext context) {
  final state = _sessionState(context);
  return state is SessionReady ? state.profile.fullName : '';
}

String menuShopId(BuildContext context) {
  final state = _sessionState(context);
  return state is SessionReady ? state.profile.shopId : '';
}

/// Mở một màn của Thực đơn, dùng chung [MenuStore] với màn gọi.
Future<T?> openMenuPage<T>(BuildContext context, Widget page) {
  final store = context.read<MenuStore>();
  return Navigator.of(context).push<T>(
    MaterialPageRoute<T>(
      builder: (_) => ChangeNotifierProvider<MenuStore>.value(
        value: store,
        child: page,
      ),
    ),
  );
}

/// Báo lỗi của một lệnh ghi bằng thanh thông báo; trả `null` khi lỗi.
Future<T?> menuGuard<T>(
    BuildContext context, Future<T> Function() action) async {
  try {
    return await action();
  } catch (error) {
    if (context.mounted) {
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(content: Text(menuErrorMessage(error))));
    }
    return null;
  }
}

String menuErrorMessage(Object error) {
  if (error is AppFailure) {
    if (error is DatabaseFailure) {
      return _menuMessages[error.code] ?? error.userMessage;
    }
    return error.userMessage;
  }
  if (looksLikeNetworkError(error)) {
    return 'Không có mạng. Kiểm tra kết nối rồi thử lại.';
  }
  return 'Có lỗi xảy ra. Thử lại sau ít phút.';
}

/// Câu tiếng Việt cho các mã lỗi của `database/05_menu_management.sql`.
const _menuMessages = <String, String>{
  'MENU_NAME_REQUIRED': 'Nhập tên món để nhận biết trong thực đơn.',
  'MENU_NAME_DUPLICATE': 'Quán đã có món tên này. Hãy đặt tên khác.',
  'MENU_ITEM_NOT_FOUND': 'Không tìm thấy món này. Đang tải lại.',
  'MENU_SIZE_NOT_FOUND': 'Không tìm thấy size này. Đang tải lại.',
  'MENU_SIZE_REQUIRED': 'Món cần ít nhất một size đang bán.',
  'SIZE_NAME_REQUIRED': 'Nhập tên size (ví dụ S, M, L).',
  'SIZE_NAME_DUPLICATE': 'Tên size bị trùng. Đổi thành tên khác.',
  'LAST_SIZE': 'Đây là size cuối cùng đang bán của món.',
  'PRICE_INVALID': 'Giá bán phải lớn hơn 0đ.',
  'PRICE_UNCHANGED': 'Giá chưa thay đổi.',
  'CATEGORY_NOT_FOUND': 'Không tìm thấy nhóm món này.',
  'CATEGORY_NAME_REQUIRED': 'Nhập tên nhóm món.',
  'CATEGORY_DUPLICATE': 'Tên nhóm món đã có tại quán. Nhập tên khác.',
  'CATEGORY_ORDER_INVALID': 'Thứ tự nhóm món không hợp lệ. Đang tải lại.',
  'ITEM_IS_DRAFT': 'Món còn là bản nháp. Hãy mở bán món trước.',
  'RECIPE_EMPTY': 'Công thức cần ít nhất một nguyên liệu.',
  'RECIPE_UNCHANGED': 'Công thức chưa thay đổi so với bản hiện tại.',
  'INGREDIENT_NOT_FOUND': 'Nguyên liệu này không còn trong kho. Đang tải lại.',
  'INGREDIENT_DUPLICATE':
      'Một nguyên liệu chỉ xuất hiện một lần trong công thức.',
  'QTY_INVALID': 'Định lượng phải là số nguyên lớn hơn 0.',
  'EFFECTIVE_INVALID': 'Ngày áp dụng không hợp lệ (tối đa 1 năm tới).',
  'RECIPE_VERSION_NOT_FOUND': 'Không tìm thấy phiên bản công thức này.',
  'RECIPE_VERSION_NOT_SCHEDULED': 'Phiên bản này đã áp dụng hoặc đã hủy.',
  'PRICE_CHANGE_NOT_FOUND': 'Không tìm thấy lịch đổi giá này.',
  'PRICE_CHANGE_NOT_SCHEDULED': 'Lịch đổi giá này đã áp dụng hoặc đã hủy.',
  'COST_INVALID': 'Giá nguyên liệu không hợp lệ.',
  'SETTING_INVALID': 'Giá trị cài đặt không hợp lệ.',
  'TOPPING_NAME_REQUIRED': 'Nhập tên topping.',
  'TOPPING_DUPLICATE': 'Quán đã có topping tên này. Đặt tên khác.',
  'TOPPING_NOT_FOUND': 'Không tìm thấy topping này. Đang tải lại.',
  'TOPPING_LIMIT_INVALID':
      'Giới hạn topping không hợp lệ: số loại tối đa không vượt quá số topping đã chọn và mỗi loại ít nhất 1 phần.',
  'OPTION_INVALID': 'Thiết lập tùy chọn không hợp lệ. Tải lại rồi thử lại.',
  'OPTION_NOT_FOUND': 'Nhóm hoặc lựa chọn này không còn tồn tại. Đang tải lại.',
  'OPTION_GROUP_NAME_REQUIRED': 'Nhóm tùy chọn cần có tên.',
  'OPTION_GROUP_DUPLICATE': 'Có hai nhóm tùy chọn trùng tên.',
  'OPTION_CHOICE_REQUIRED': 'Mỗi nhóm cần ít nhất một lựa chọn.',
  'OPTION_CHOICE_NAME_REQUIRED': 'Có lựa chọn chưa đặt tên.',
  'OPTION_CHOICE_DUPLICATE': 'Một nhóm có hai lựa chọn trùng tên.',
  'OPTION_DEFAULT_REQUIRED':
      'Nhóm bắt buộc phải có đúng một lựa chọn mặc định; nhóm không bắt buộc có tối đa một.',
  'INGREDIENT_UNIT_MISMATCH':
      'Nguyên liệu ở quán nhận khác đơn vị (g, ml, cái). Chọn nguyên liệu cùng đơn vị.',
  'APP_API_MISSING':
      'Database chưa có hàm Thực đơn mới. Hãy cập nhật schema theo hướng dẫn HUONG_DAN_NHIEU_QUAN.md, sau đó tải lại.',
};

// ---------------------------------------------------------------------------
// Khung trang
// ---------------------------------------------------------------------------

/// Khung chung của các màn con: thanh trên (← Fore · tên quán), tiêu đề, nội dung cuộn
/// và vùng nút cố định ở đáy.
class MenuPage extends StatelessWidget {
  const MenuPage({
    super.key,
    required this.title,
    required this.children,
    this.eyebrow = 'SỔ TAY THỰC ĐƠN',
    this.subtitle,
    this.primary,
    this.secondary,
    this.onBack,
    this.showBack = true,
  });

  final String title;
  final String eyebrow;
  final String? subtitle;
  final List<Widget> children;
  final Widget? primary;
  final Widget? secondary;
  final VoidCallback? onBack;
  final bool showBack;

  @override
  Widget build(BuildContext context) => Scaffold(
        backgroundColor: AppColors.background,
        body: SafeArea(
          child: ContentWidth(
              child: Column(
            children: [
              MenuTopBar(
                  onBack: showBack
                      ? (onBack ?? () => Navigator.of(context).maybePop())
                      : null),
              Expanded(
                child: LazyListView(
                  padding: const EdgeInsets.fromLTRB(
                      AppSizes.pagePadding, 4, AppSizes.pagePadding, 24),
                  children: [
                    Text(eyebrow, style: AppTextStyles.micro),
                    const SizedBox(height: 4),
                    Text(title, style: AppTextStyles.display),
                    if (subtitle != null) ...[
                      const SizedBox(height: 4),
                      Text(subtitle!, style: AppTextStyles.caption),
                    ],
                    const SizedBox(height: 14),
                    ...children,
                  ],
                ),
              ),
              if (primary != null || secondary != null)
                DecoratedBox(
                  decoration: BoxDecoration(
                    color: AppColors.background,
                    border:
                        Border(top: BorderSide(color: AppColors.cardBorder)),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(
                        AppSizes.pagePadding, 10, AppSizes.pagePadding, 10),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (primary != null) primary!,
                        if (primary != null && secondary != null)
                          const SizedBox(height: 8),
                        if (secondary != null) secondary!,
                      ],
                    ),
                  ),
                ),
            ],
          )),
        ),
      );
}

class MenuTopBar extends StatelessWidget {
  const MenuTopBar({super.key, this.onBack});

  final VoidCallback? onBack;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.fromLTRB(8, 4, AppSizes.pagePadding, 4),
        child: Row(
          children: [
            if (onBack != null)
              IconButton(
                tooltip: 'Quay lại',
                onPressed: onBack,
                icon: const Icon(Icons.arrow_back_rounded),
                constraints:
                    const BoxConstraints.tightFor(width: 48, height: 48),
              )
            else
              const SizedBox(width: 8),
            Text(
              'Fore',
              style: TextStyle(
                fontFamily: AppFonts.display,
                fontSize: 22,
                fontWeight: FontWeight.w600,
                color: AppColors.brand,
              ),
            ),
            const Spacer(),
            Flexible(
              child: Text(
                menuShopName(context),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: AppTextStyles.caption,
              ),
            ),
          ],
        ),
      );
}

// ---------------------------------------------------------------------------
// Thành phần nhỏ
// ---------------------------------------------------------------------------

class MenuCard extends StatelessWidget {
  const MenuCard({
    super.key,
    required this.child,
    this.onTap,
    this.padding = const EdgeInsets.all(14),
    this.color,
    this.borderColor,
  });

  final Widget child;
  final VoidCallback? onTap;
  final EdgeInsetsGeometry padding;
  final Color? color;
  final Color? borderColor;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: 10),
        child: Material(
          color: color ?? AppColors.surface,
          borderRadius: BorderRadius.circular(AppSizes.radiusTile),
          child: InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(AppSizes.radiusTile),
            child: Ink(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(AppSizes.radiusTile),
                border: Border.all(color: borderColor ?? AppColors.cardBorder),
              ),
              padding: padding,
              child: child,
            ),
          ),
        ),
      );
}

enum BannerKind { info, warning, error, success }

/// Dải thông báo có tiêu đề + nội dung; luôn kèm biểu tượng, không chỉ dựa vào màu.
class MenuBanner extends StatelessWidget {
  const MenuBanner({
    super.key,
    required this.kind,
    required this.title,
    this.body,
    this.action,
  });

  final BannerKind kind;
  final String title;
  final String? body;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    final (bg, fg, icon) = switch (kind) {
      BannerKind.info => (
          AppColors.tint,
          AppColors.textPrimary,
          Icons.info_outline_rounded
        ),
      BannerKind.warning => (
          AppColors.statusAttentionTint,
          AppColors.statusAttention,
          Icons.warning_amber_rounded
        ),
      BannerKind.error => (
          AppColors.statusCriticalTint,
          AppColors.statusCritical,
          Icons.error_outline_rounded
        ),
      BannerKind.success => (
          AppColors.statusHealthyTint,
          AppColors.statusHealthy,
          Icons.check_circle_outline_rounded
        ),
    };
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(AppSizes.radiusTile),
        ),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(icon, size: 20, color: fg),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title,
                        style: TextStyle(
                            color: fg,
                            fontWeight: FontWeight.w700,
                            fontSize: 14)),
                    if (body != null) ...[
                      const SizedBox(height: 3),
                      Text(body!, style: AppTextStyles.body),
                    ],
                    if (action != null) ...[const SizedBox(height: 6), action!],
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Thẻ tối: "35.000 − 11.200 = 23.800đ  68%".
class MenuMarginHero extends StatelessWidget {
  const MenuMarginHero({
    super.key,
    required this.label,
    required this.price,
    required this.cost,
    this.note,
    this.lowMarginPct,
  });

  final String label;
  final int price;
  final int? cost;
  final String? note;
  final int? lowMarginPct;

  @override
  Widget build(BuildContext context) {
    final margin = cost == null ? null : price - cost!;
    final pct = cost == null || price <= 0 ? null : margin! * 100 / price;
    final low = pct != null && lowMarginPct != null && pct < lowMarginPct!;
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: AppColors.surfaceDark,
          borderRadius: BorderRadius.circular(AppSizes.radiusCard),
        ),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label.toUpperCase(),
                  style: const TextStyle(
                      color: AppColors.actionLime,
                      fontSize: AppFontSizes.s12,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.4)),
              const SizedBox(height: 8),
              if (cost == null) ...[
                Text(formatVnd(price),
                    style: const TextStyle(
                        color: Colors.white,
                        fontSize: 22,
                        fontFamily: AppFonts.display)),
                const SizedBox(height: 6),
                const Text(
                  'Vốn và lãi chưa xác định: công thức còn thiếu hoặc nguyên liệu chưa có giá.',
                  style: TextStyle(color: AppColors.onDarkMuted, fontSize: 12),
                ),
              ] else ...[
                Text('${formatThousands(price)} − ${formatThousands(cost!)} =',
                    style: const TextStyle(
                        color: AppColors.onDarkMuted,
                        fontSize: 15,
                        fontFeatures: [FontFeature.tabularFigures()])),
                const SizedBox(height: 2),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Expanded(
                      child: Text(formatVnd(margin!),
                          style: const TextStyle(
                              color: Colors.white,
                              fontSize: 32,
                              fontFamily: AppFonts.display,
                              fontFeatures: [FontFeature.tabularFigures()])),
                    ),
                    Text(
                      '${formatPct(pct!)}${low ? ' · Lãi thấp' : ''}',
                      style: TextStyle(
                          color: low
                              ? AppColors.onDarkWarning
                              : AppColors.actionLime,
                          fontWeight: FontWeight.w700,
                          fontSize: 14),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  note ??
                      'Lãi gộp ước tính. Giá vốn gồm nguyên liệu + bao bì. Chưa trừ thuê mặt bằng, nhân công, phí nền tảng.',
                  style: const TextStyle(
                      color: AppColors.onDarkMuted, fontSize: 12),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

/// Chọn một size bằng các ô: "S · 35.000đ".
class SizeTabs extends StatelessWidget {
  const SizeTabs({
    super.key,
    required this.labels,
    required this.selected,
    required this.onChanged,
  });

  final List<String> labels;
  final int selected;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: 10),
        child: Row(
          children: [
            for (var i = 0; i < labels.length; i++) ...[
              if (i > 0) const SizedBox(width: 8),
              Expanded(
                child: Semantics(
                  button: true,
                  selected: i == selected,
                  child: InkWell(
                    onTap: () => onChanged(i),
                    borderRadius: BorderRadius.circular(AppSizes.radius),
                    child: Ink(
                      height: 48,
                      decoration: BoxDecoration(
                        color:
                            i == selected ? AppColors.brand : AppColors.surface,
                        borderRadius: BorderRadius.circular(AppSizes.radius),
                        border: Border.all(
                            color: i == selected
                                ? AppColors.brand
                                : AppColors.border),
                      ),
                      child: Center(
                        child: Text(
                          labels[i],
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontWeight: FontWeight.w700,
                            fontSize: 14,
                            color: i == selected
                                ? AppColors.onInk
                                : AppColors.brand,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ],
        ),
      );
}

/// Chip chọn một giá trị (Nhóm món, Trạng thái bán...).
class OptionChip extends StatelessWidget {
  const OptionChip({
    super.key,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Semantics(
        button: true,
        selected: selected,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(AppSizes.radius),
          child: Ink(
            height: 48,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            decoration: BoxDecoration(
              color: selected ? AppColors.brand : AppColors.surface,
              borderRadius: BorderRadius.circular(AppSizes.radius),
              border: Border.all(
                  color: selected ? AppColors.brand : AppColors.border),
            ),
            child: Center(
              child: Text(
                selected ? '✓ $label' : label,
                style: TextStyle(
                  fontWeight: FontWeight.w700,
                  fontSize: 14,
                  color: selected ? AppColors.onInk : AppColors.brand,
                ),
              ),
            ),
          ),
        ),
      );
}

class MenuSkeleton extends StatelessWidget {
  const MenuSkeleton({super.key, this.rows = 4});

  final int rows;

  @override
  Widget build(BuildContext context) {
    Widget bar(double w, double h) => Container(
          width: w,
          height: h,
          decoration: BoxDecoration(
            color: AppColors.disabledFill,
            borderRadius: BorderRadius.circular(8),
          ),
        );
    return Semantics(
      label: 'Đang tải thực đơn',
      child: ExcludeSemantics(
        child: Column(
          children: [
            for (var i = 0; i < rows; i++)
              MenuCard(
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          bar(140, 14),
                          const SizedBox(height: 8),
                          bar(200, 11)
                        ],
                      ),
                    ),
                    bar(48, 28),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// Hộp xác nhận dạng bottom sheet với hai nút (chính + phụ).
Future<bool> confirmSheet(
  BuildContext context, {
  required String title,
  required String message,
  required String confirmLabel,
  String cancelLabel = 'Hủy',
  List<Widget> extra = const [],
}) async {
  final result = await showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    backgroundColor: AppColors.surface,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
    ),
    builder: (sheetContext) => SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: AppTextStyles.headline),
            const SizedBox(height: 8),
            Text(message, style: AppTextStyles.body),
            ...extra,
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: () => Navigator.of(sheetContext).pop(true),
                child: Text(confirmLabel),
              ),
            ),
            const SizedBox(height: 8),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton(
                onPressed: () => Navigator.of(sheetContext).pop(false),
                child: Text(cancelLabel),
              ),
            ),
          ],
        ),
      ),
    ),
  );
  return result ?? false;
}

/// Nút chính có trạng thái đang xử lý.
class MenuPrimaryButton extends StatelessWidget {
  const MenuPrimaryButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.loading = false,
  });

  final String label;
  final VoidCallback? onPressed;
  final bool loading;

  @override
  Widget build(BuildContext context) => SizedBox(
        width: double.infinity,
        child: FilledButton(
          onPressed: loading ? null : onPressed,
          child: loading
              ? SizedBox.square(
                  dimension: 18,
                  child: CircularProgressIndicator(
                      strokeWidth: 2, color: AppColors.onInk),
                )
              : Text(label),
        ),
      );
}

class MenuSecondaryButton extends StatelessWidget {
  const MenuSecondaryButton(
      {super.key, required this.label, required this.onPressed});

  final String label;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) => SizedBox(
        width: double.infinity,
        child: OutlinedButton(onPressed: onPressed, child: Text(label)),
      );
}

/// Một dòng trong danh sách thao tác của màn chi tiết: tiêu đề, mô tả, mũi tên.
class MenuActionRow extends StatelessWidget {
  const MenuActionRow({
    super.key,
    required this.icon,
    required this.title,
    this.subtitle,
    this.onTap,
  });

  final IconData icon;
  final String title;
  final String? subtitle;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) => MenuCard(
        onTap: onTap,
        child: Row(
          children: [
            Icon(icon, color: AppColors.brand),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: AppTextStyles.cardTitle),
                  if (subtitle != null)
                    Text(subtitle!, style: AppTextStyles.caption),
                ],
              ),
            ),
            if (onTap != null)
              Icon(Icons.chevron_right_rounded, color: AppColors.textSecondary),
          ],
        ),
      );
}

/// Chọn ngày + giờ áp dụng; bấm mở hộp chọn của hệ thống.
class DateTimeFields extends StatelessWidget {
  const DateTimeFields({
    super.key,
    required this.value,
    required this.onChanged,
    this.firstDate,
  });

  final DateTime value;
  final ValueChanged<DateTime> onChanged;
  final DateTime? firstDate;

  @override
  Widget build(BuildContext context) {
    final start = firstDate ?? DateTime.now();
    Future<void> pickDate() async {
      final picked = await showDatePicker(
        context: context,
        initialDate: value.isBefore(start) ? start : value,
        firstDate: DateTime(start.year, start.month, start.day),
        lastDate: DateTime.now().add(const Duration(days: 365)),
      );
      if (picked != null) {
        onChanged(DateTime(
            picked.year, picked.month, picked.day, value.hour, value.minute));
      }
    }

    Future<void> pickTime() async {
      final picked = await showTimePicker(
        context: context,
        initialTime: TimeOfDay(hour: value.hour, minute: value.minute),
      );
      if (picked != null) {
        onChanged(DateTime(
            value.year, value.month, value.day, picked.hour, picked.minute));
      }
    }

    Widget field(
            String label, String text, IconData icon, VoidCallback onTap) =>
        Expanded(
          child: InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(AppSizes.radius),
            child: Ink(
              height: 56,
              padding: const EdgeInsets.symmetric(horizontal: 14),
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(AppSizes.radius),
                border: Border.all(color: AppColors.border),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(label, style: AppTextStyles.micro),
                        Text(text, style: AppTextStyles.bodyStrong),
                      ],
                    ),
                  ),
                  Icon(icon, size: 18, color: AppColors.textSecondary),
                ],
              ),
            ),
          ),
        );

    return Row(
      children: [
        field('Ngày áp dụng', formatDmy(value), Icons.calendar_today_outlined,
            pickDate),
        const SizedBox(width: 10),
        field('Giờ áp dụng', formatHm(value), Icons.schedule_rounded, pickTime),
      ],
    );
  }
}

/// Chọn "Áp dụng ngay" hoặc "Hẹn ngày giờ".
class ApplyModePicker extends StatelessWidget {
  const ApplyModePicker({
    super.key,
    required this.immediate,
    required this.onChanged,
  });

  final bool immediate;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: 10),
        child: Row(
          children: [
            Expanded(
              child: OptionChip(
                label: 'Áp dụng ngay',
                selected: immediate,
                onTap: () => onChanged(true),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: OptionChip(
                label: 'Hẹn ngày giờ',
                selected: !immediate,
                onTap: () => onChanged(false),
              ),
            ),
          ],
        ),
      );
}
