import 'dart:convert';
import 'dart:math';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Stores a per-account random proof in platform secure storage.
class StaffDeviceTrustStore {
  StaffDeviceTrustStore([FlutterSecureStorage? storage])
      : _storage = storage ?? const FlutterSecureStorage();

  final FlutterSecureStorage _storage;

  Future<String?> readSecret(String userId) => _storage.read(key: _key(userId));

  Future<String> createSecret(String userId) async {
    final random = Random.secure();
    final bytes = List<int>.generate(32, (_) => random.nextInt(256));
    final secret = base64Url.encode(bytes).replaceAll('=', '');
    await _storage.write(key: _key(userId), value: secret);
    return secret;
  }

  Future<void> clearSecret(String userId) => _storage.delete(key: _key(userId));

  String _key(String userId) => 'fore.staff_device.v1.$userId';
}
