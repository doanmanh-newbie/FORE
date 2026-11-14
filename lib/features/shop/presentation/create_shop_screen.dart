import 'package:flutter/material.dart';
import 'package:fore/core/theme/theme_mode_toggle.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../../app/app_routes.dart';
import '../../../core/errors/app_failure.dart';
import '../../../core/errors/failure_messages.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/app_text_field.dart';
import '../../../core/widgets/fade_slide_in.dart';
import '../../../core/widgets/loading_button.dart';
import '../../auth/application/session_controller.dart';
import '../../shift/application/shift_controller.dart';
import '../domain/shop_repository.dart';

/// Chủ quán tạo quán của mình (hoặc thêm một quán nữa). Người tạo là chủ quán đó.
class CreateShopScreen extends StatefulWidget {
  const CreateShopScreen({super.key});

  @override
  State<CreateShopScreen> createState() => _CreateShopScreenState();
}

class _CreateShopScreenState extends State<CreateShopScreen> {
  final _shop = TextEditingController();
  final _owner = TextEditingController();
  bool _loading = false;
  String? _shopError;
  String? _ownerError;
  String? _formError;

  @override
  void initState() {
    super.initState();
    final state = context.read<SessionController>().state;
    if (state is SessionNeedsShop) _owner.text = state.user.displayName;
    if (state is SessionSignedIn) _owner.text = state.profile.fullName;
  }

  @override
  void dispose() {
    _shop.dispose();
    _owner.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final repo = context.read<ShopRepository>();
    final session = context.read<SessionController>();
    final shift = context.read<ShiftController>();
    final navigator = Navigator.of(context);

    setState(() {
      _shopError = _shop.text.trim().isEmpty ? 'Nhập tên quán.' : null;
      _ownerError =
          _owner.text.trim().isEmpty ? 'Nhập tên hiển thị của bạn.' : null;
      _formError = null;
    });
    if (_shopError != null || _ownerError != null) return;

    setState(() => _loading = true);
    try {
      await repo.createShop(
        shopName: _shop.text.trim(),
        ownerName: _owner.text.trim(),
      );
      final failure = await session.refreshAfterSignIn();
      if (failure != null) throw failure;
      shift.load();
      HapticFeedback.mediumImpact();
      if (!mounted) return;
      navigator.pushNamedAndRemoveUntil(AppRoutes.home, (_) => false);
    } on AppFailure catch (f) {
      if (mounted) setState(() => _formError = f.userMessage);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final canPop = Navigator.of(context).canPop();
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        automaticallyImplyLeading: canPop,
        actions: const [ThemeModeToggle()],
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(AppSizes.pagePadding),
          child: FadeSlideIn(
            child: Center(
                child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 480),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Text('Tạo quán của bạn', style: AppTextStyles.display),
                        const SizedBox(height: 8),
                        Text(
                          'Bạn sẽ là chủ quán. Sau đó thêm nhân viên chỉ bằng số điện thoại, '
                          'họ nhận thông báo trong ứng dụng và chấp nhận là vào quán.',
                          style: AppTextStyles.body,
                        ),
                        const SizedBox(height: 28),
                        AppTextField(
                          label: 'Tên quán',
                          controller: _shop,
                          hint: 'Ví dụ: Fore Coffee Nguyễn Huệ',
                          errorText: _shopError,
                          enabled: !_loading,
                          textInputAction: TextInputAction.next,
                        ),
                        const SizedBox(height: 16),
                        AppTextField(
                          label: 'Tên hiển thị của bạn',
                          controller: _owner,
                          hint: 'Ví dụ: Anh Minh',
                          errorText: _ownerError,
                          enabled: !_loading,
                          textInputAction: TextInputAction.done,
                          onSubmitted: _submit,
                        ),
                        if (_formError != null) ...[
                          const SizedBox(height: 12),
                          Text(
                            _formError!,
                            style: TextStyle(
                                color: AppColors.statusOff,
                                fontSize: AppFontSizes.s13),
                          ),
                        ],
                        const SizedBox(height: 24),
                        LoadingButton(
                          label: 'Tạo quán',
                          loadingLabel: 'Đang tạo quán',
                          loading: _loading,
                          onPressed: _submit,
                        ),
                      ],
                    ))),
          ),
        ),
      ),
    );
  }
}
