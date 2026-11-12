import 'dart:typed_data';

import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

enum MenuImageSource { gallery, camera }

/// Ảnh vừa chọn, còn nằm trên máy.
class PickedMenuImage {
  const PickedMenuImage({required this.bytes, required this.name});

  final Uint8List bytes;
  final String name;
}

/// Chưa được cấp quyền thư viện ảnh / camera.
class MenuImagePermissionDenied implements Exception {
  const MenuImagePermissionDenied();

  @override
  String toString() => 'MenuImagePermissionDenied';
}

/// Chọn ảnh từ máy và đưa lên kho ảnh món (Supabase Storage, bucket `menu-images`).
/// Tách thành giao diện để test không cần plugin thật.
abstract interface class MenuImageService {
  /// `null` khi người dùng đóng hộp chọn mà không chọn.
  Future<PickedMenuImage?> pick(MenuImageSource source);

  /// Trả về đường dẫn trong bucket để lưu vào `menu_items.image_path`.
  Future<String> upload({
    required String shopId,
    required String itemId,
    required PickedMenuImage image,
  });

  String? publicUrl(String? path);
}

class SupabaseMenuImageService implements MenuImageService {
  SupabaseMenuImageService(this._client, {ImagePicker? picker})
      : _picker = picker ?? ImagePicker();

  static const bucket = 'menu-images';

  final SupabaseClient _client;
  final ImagePicker _picker;

  @override
  Future<PickedMenuImage?> pick(MenuImageSource source) async {
    try {
      final file = await _picker.pickImage(
        source: source == MenuImageSource.camera
            ? ImageSource.camera
            : ImageSource.gallery,
        maxWidth: 1024,
        maxHeight: 1024,
        imageQuality: 85,
      );
      if (file == null) return null;
      return PickedMenuImage(bytes: await file.readAsBytes(), name: file.name);
    } on PlatformException catch (error) {
      if (error.code.contains('access_denied') ||
          error.code.contains('permission')) {
        throw const MenuImagePermissionDenied();
      }
      rethrow;
    }
  }

  @override
  Future<String> upload({
    required String shopId,
    required String itemId,
    required PickedMenuImage image,
  }) async {
    final path = '$shopId/$itemId-${DateTime.now().millisecondsSinceEpoch}.jpg';
    await _client.storage.from(bucket).uploadBinary(
          path,
          image.bytes,
          fileOptions: const FileOptions(contentType: 'image/jpeg'),
        );
    return path;
  }

  @override
  String? publicUrl(String? path) =>
      path == null || path.isEmpty ? null : _client.storage.from(bucket).getPublicUrl(path);
}
