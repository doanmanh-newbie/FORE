import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/design/colors.dart';
import '../../../core/design/typography.dart';
import 'menu_image_service.dart';
import 'menu_models.dart';
import 'menu_store.dart';
import 'menu_widgets.dart';

/// Ảnh nhỏ của món; chưa có ảnh hoặc tải lỗi thì hiện hình ly trung tính.
class MenuThumb extends StatelessWidget {
  const MenuThumb({super.key, required this.path, this.size = 56, this.bytes});

  final String? path;
  final double size;

  /// Ảnh đang xem trước (chưa lưu) ưu tiên hơn ảnh đã đăng.
  final Uint8List? bytes;

  String? _url(BuildContext context) {
    try {
      return context.read<MenuImageService>().publicUrl(path);
    } on ProviderNotFoundException {
      return null;
    }
  }

  @override
  Widget build(BuildContext context) {
    final placeholder = ColoredBox(
      color: AppColors.tint,
      child: Center(
        child: Icon(Icons.local_cafe_outlined,
            size: size * 0.45, color: AppColors.textSecondary),
      ),
    );
    final url = bytes == null ? _url(context) : null;
    // Giải mã đúng cỡ ô hiển thị thay vì nguyên ảnh gốc.
    final decodePx = (size * MediaQuery.devicePixelRatioOf(context)).round();
    return Semantics(
      label: 'Ảnh món',
      image: true,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(size >= 120 ? 20 : 12),
        child: SizedBox.square(
          dimension: size,
          child: bytes != null
              ? Image.memory(bytes!, fit: BoxFit.cover, cacheWidth: decodePx)
              : url == null
                  ? placeholder
                  : Image.network(
                      url,
                      fit: BoxFit.cover,
                      cacheWidth: decodePx,
                      errorBuilder: (_, __, ___) => placeholder,
                      loadingBuilder: (_, child, progress) =>
                          progress == null ? child : placeholder,
                    ),
        ),
      ),
    );
  }
}

enum _ImageStep { idle, picked, uploading, failed }

/// Thêm, đổi hoặc gỡ ảnh món. Ảnh chỉ thay đổi sau khi lưu thành công.
class MenuImagePage extends StatefulWidget {
  const MenuImagePage({super.key, required this.detail});

  final ItemDetail detail;

  @override
  State<MenuImagePage> createState() => _MenuImagePageState();
}

class _MenuImagePageState extends State<MenuImagePage> {
  _ImageStep _step = _ImageStep.idle;
  PickedMenuImage? _picked;
  Object? _error;
  bool _permissionDenied = false;
  int _attempt = 0;

  Future<void> _pick(MenuImageSource source) async {
    final service = context.read<MenuImageService>();
    setState(() => _permissionDenied = false);
    try {
      final image = await service.pick(source);
      if (image == null || !mounted) return;
      setState(() {
        _picked = image;
        _step = _ImageStep.picked;
        _error = null;
      });
    } on MenuImagePermissionDenied {
      if (mounted) setState(() => _permissionDenied = true);
    } catch (error) {
      if (mounted) {
        setState(() {
          _error = error;
        });
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(menuErrorMessage(error))));
      }
    }
  }

  Future<void> _upload() async {
    final image = _picked;
    if (image == null) return;
    final service = context.read<MenuImageService>();
    final store = context.read<MenuStore>();
    final shopId = menuShopId(context);
    final attempt = ++_attempt;
    setState(() {
      _step = _ImageStep.uploading;
      _error = null;
    });
    try {
      final path = await service.upload(
          shopId: shopId, itemId: widget.detail.id, image: image);
      if (attempt != _attempt) return; // đã hủy
      await store.setImage(widget.detail.id, path);
      if (!mounted || attempt != _attempt) return;
      Navigator.of(context).pop(true);
    } catch (error) {
      if (!mounted || attempt != _attempt) return;
      setState(() {
        _step = _ImageStep.failed;
        _error = error;
      });
    }
  }

  void _cancelUpload() {
    _attempt++;
    setState(() => _step = _ImageStep.picked);
  }

  Future<void> _remove() async {
    final ok = await confirmSheet(
      context,
      title: 'Gỡ ảnh hiện tại?',
      message:
          'Gỡ ảnh không xóa món, giá hoặc công thức. Món sẽ hiện hình ly trung tính.',
      confirmLabel: 'Gỡ ảnh',
      cancelLabel: 'Giữ ảnh',
    );
    if (!ok || !mounted) return;
    final store = context.read<MenuStore>();
    final done = await menuGuard<bool>(context, () async {
      await store.setImage(widget.detail.id, null);
      return true;
    });
    if (done == true && mounted) Navigator.of(context).pop(true);
  }

  @override
  Widget build(BuildContext context) {
    final detail = widget.detail;
    final picked = _picked;
    final uploading = _step == _ImageStep.uploading;
    final failed = _step == _ImageStep.failed;
    final hasImage = (detail.imagePath ?? '').isNotEmpty;

    if (picked != null && _step != _ImageStep.idle) {
      return MenuPage(
        title: uploading
            ? 'Đang tải ảnh'
            : failed
                ? 'Tải ảnh thất bại'
                : 'Xem trước ảnh',
        subtitle: failed
            ? '${detail.name} · Ảnh mới chưa được lưu'
            : '${detail.name} · Ảnh không bắt buộc',
        showBack: !uploading,
        primary: MenuPrimaryButton(
          label: uploading
              ? 'Đang tải · Chưa thể lưu'
              : failed
                  ? 'Thử tải lại'
                  : 'Dùng ảnh này',
          loading: uploading,
          onPressed: _upload,
        ),
        secondary: MenuSecondaryButton(
          label: uploading
              ? 'Hủy tải · Giữ bản soạn'
              : failed
                  ? 'Tiếp tục không dùng ảnh mới'
                  : 'Chọn ảnh khác',
          onPressed: uploading
              ? _cancelUpload
              : failed
                  ? () => Navigator.of(context).pop(false)
                  : () => setState(() => _step = _ImageStep.idle),
        ),
        children: [
          if (failed)
            MenuBanner(
              kind: BannerKind.error,
              title: 'Không tải được ảnh',
              body:
                  '${menuErrorMessage(_error ?? '')} Không cần chọn ảnh lại. Ảnh đang công bố vẫn giữ nguyên.',
            ),
          Center(
            child: MenuThumb(path: null, bytes: picked.bytes, size: 220),
          ),
          const SizedBox(height: 8),
          Text(
            uploading
                ? 'Chờ tải xong để lưu. Ảnh đang công bố chưa thay đổi.'
                : 'Ảnh được hiển thị cắt vuông ở giữa. Ảnh chỉ thay đổi sau khi lưu.',
            textAlign: TextAlign.center,
            style: AppTextStyles.caption,
          ),
          if (failed)
            Padding(
              padding: const EdgeInsets.only(top: 6),
              child: TextButton(
                onPressed: () => setState(() => _step = _ImageStep.idle),
                child: const Text('Chọn ảnh khác'),
              ),
            ),
        ],
      );
    }

    return MenuPage(
      title: 'Ảnh món',
      subtitle: '${detail.name} · Ảnh không bắt buộc',
      secondary: MenuSecondaryButton(
        label: 'Hủy · Về chi tiết món',
        onPressed: () => Navigator.of(context).pop(false),
      ),
      children: [
        Text('Ảnh hiện tại', style: AppTextStyles.cardTitle),
        const SizedBox(height: 8),
        Center(child: MenuThumb(path: detail.imagePath, size: 180)),
        const SizedBox(height: 6),
        Text(
          hasImage ? 'Ảnh đang hiển thị trong thực đơn.' : 'Chưa có ảnh · Hình đồ uống minh họa trung tính.',
          textAlign: TextAlign.center,
          style: AppTextStyles.caption,
        ),
        const SizedBox(height: 14),
        MenuActionRow(
          icon: Icons.photo_library_outlined,
          title: 'Chọn từ thư viện',
          subtitle: 'Chọn ảnh có sẵn trên thiết bị',
          onTap: () => _pick(MenuImageSource.gallery),
        ),
        MenuActionRow(
          icon: Icons.photo_camera_outlined,
          title: 'Chụp ảnh',
          subtitle: 'Dùng camera của thiết bị',
          onTap: () => _pick(MenuImageSource.camera),
        ),
        if (hasImage)
          MenuActionRow(
            icon: Icons.hide_image_outlined,
            title: 'Gỡ ảnh hiện tại',
            subtitle: 'Gỡ ảnh không xóa món, giá hoặc công thức.',
            onTap: _remove,
          ),
        if (_permissionDenied)
          const MenuBanner(
            kind: BannerKind.warning,
            title: 'Chưa có quyền truy cập',
            body:
                'Mở Cài đặt thiết bị để cấp quyền ảnh/camera cho Fore, hoặc tiếp tục không có ảnh.',
          ),
      ],
    );
  }
}
