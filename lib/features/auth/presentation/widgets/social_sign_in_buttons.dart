import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../../../../core/config/app_config.dart';
import '../../../../core/design/colors.dart';
import '../../../../core/design/spacing.dart';
import '../../../../core/design/typography.dart';
import '../../domain/auth_repository.dart';

/// Nhà cung cấp hiện nút: Google mặc định (tắt bằng `GOOGLE_LOGIN=false`), Facebook khi bật cờ
/// `FACEBOOK_LOGIN`. Bản debug luôn hiện cả hai để xem giao diện.
List<SocialProvider> availableSocialProviders() => [
      if (kDebugMode || AppConfig.googleLoginEnabled)
        SocialProvider.google,
      if (kDebugMode || AppConfig.facebookLoginEnabled) SocialProvider.facebook,
    ];

/// Dải "hoặc" + nút Google / Facebook dưới form đăng nhập chủ quán.
/// Một nhà cung cấp thì nút kéo hết chiều ngang; hai thì chia đôi.
class SocialSignInButtons extends StatelessWidget {
  const SocialSignInButtons({
    super.key,
    required this.onPressed,
    this.loading,
    this.enabled = true,
    this.providers,
  });

  final ValueChanged<SocialProvider> onPressed;

  /// Nhà cung cấp đang chờ (nút đó hiện vòng quay).
  final SocialProvider? loading;
  final bool enabled;

  /// Mặc định [availableSocialProviders].
  final List<SocialProvider>? providers;

  @override
  Widget build(BuildContext context) {
    final list = providers ?? availableSocialProviders();
    if (list.isEmpty) return const SizedBox.shrink();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            const Expanded(child: Divider()),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: AppGaps.md),
              child: Text('hoặc tiếp tục với',
                  style: AppTextStyles.caption
                      .copyWith(color: AppColors.textSecondary)),
            ),
            const Expanded(child: Divider()),
          ],
        ),
        const SizedBox(height: AppGaps.lg),
        Row(
          children: [
            for (var i = 0; i < list.length; i++) ...[
              if (i > 0) const SizedBox(width: AppGaps.md),
              Expanded(
                child: _SocialButton(
                  provider: list[i],
                  loading: loading == list[i],
                  onPressed: enabled ? () => onPressed(list[i]) : null,
                ),
              ),
            ],
          ],
        ),
      ],
    );
  }
}

class _SocialButton extends StatelessWidget {
  const _SocialButton({
    required this.provider,
    required this.loading,
    required this.onPressed,
  });

  final SocialProvider provider;
  final bool loading;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: 'Đăng nhập bằng ${provider.label}',
      excludeSemantics: true,
      child: OutlinedButton(
        onPressed: loading ? null : onPressed,
        style: OutlinedButton.styleFrom(
          minimumSize: const Size(0, 50),
          padding: const EdgeInsets.symmetric(horizontal: 12),
          backgroundColor: AppColors.surface,
          foregroundColor: AppColors.textPrimary,
          side: BorderSide(color: AppColors.border),
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          textStyle: const TextStyle(
            fontFamily: AppFonts.body,
            fontSize: 15,
            fontWeight: FontWeight.w600,
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox.square(
              dimension: 20,
              child: loading
                  ? const CircularProgressIndicator(strokeWidth: 2.2)
                  : SocialLogo(provider),
            ),
            const SizedBox(width: 10),
            Flexible(
              child: Text(
                provider.label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(color: AppColors.textPrimary),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Logo nhà cung cấp, vẽ bằng vector (không cần file ảnh).
class SocialLogo extends StatelessWidget {
  const SocialLogo(this.provider, {super.key, this.size = 20});

  final SocialProvider provider;
  final double size;

  static const _google = '''
<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 48 48">
<path fill="#EA4335" d="M24 9.5c3.54 0 6.71 1.22 9.21 3.6l6.85-6.85C35.9 2.38 30.47 0 24 0 14.62 0 6.51 5.38 2.56 13.22l7.98 6.19C12.43 13.72 17.74 9.5 24 9.5z"/>
<path fill="#4285F4" d="M46.98 24.55c0-1.57-.15-3.09-.38-4.55H24v9.02h12.94c-.58 2.96-2.26 5.48-4.78 7.18l7.73 6c4.51-4.18 7.09-10.36 7.09-17.65z"/>
<path fill="#FBBC05" d="M10.53 28.59c-.48-1.45-.76-2.99-.76-4.59s.27-3.14.76-4.59l-7.98-6.19C.92 16.46 0 20.12 0 24c0 3.88.92 7.54 2.56 10.78l7.97-6.19z"/>
<path fill="#34A853" d="M24 48c6.48 0 11.93-2.13 15.89-5.81l-7.73-6c-2.15 1.45-4.92 2.3-8.16 2.3-6.26 0-11.57-4.22-13.47-9.91l-7.98 6.19C6.51 42.62 14.62 48 24 48z"/>
</svg>''';

  static const _facebook = '''
<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 48 48">
<circle cx="24" cy="24" r="24" fill="#1877F2"/>
<path fill="#FFFFFF" d="M33.3 30.9l1.06-6.9h-6.62v-4.48c0-1.89.92-3.73 3.89-3.73h3.01v-5.88s-2.73-.47-5.34-.47c-5.45 0-9.02 3.3-9.02 9.29V24h-6.06v6.9h6.06V48c1.22.19 2.46.29 3.73.29s2.51-.1 3.73-.29V30.9h5.56z"/>
</svg>''';

  @override
  Widget build(BuildContext context) => SvgPicture.string(
        provider == SocialProvider.google ? _google : _facebook,
        width: size,
        height: size,
      );
}
