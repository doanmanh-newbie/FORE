import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Tùy chọn hiển thị tab "Thêm" của chủ quán, lưu trên thiết bị: mục ghim và chế độ gọn.
/// Không phải dữ liệu quán nên không đi qua database.
class MorePrefs extends ChangeNotifier {
  MorePrefs._(this._store, List<String> pinned, this._compact)
      : _pinned = List.of(pinned);

  /// Bản chỉ nằm trong bộ nhớ (dùng khi chưa đọc xong hoặc trong test).
  factory MorePrefs.memory({List<String>? pinned, bool compact = false}) =>
      MorePrefs._(null, pinned ?? defaultPinned, compact);

  static Future<MorePrefs> load([SharedPreferences? store]) async {
    final s = store ?? await SharedPreferences.getInstance();
    return MorePrefs._(
      s,
      s.getStringList(_pinKey) ?? defaultPinned,
      s.getBool(_compactKey) ?? false,
    );
  }

  static const maxPinned = 3;
  static const defaultPinned = ['team', 'suppliers', 'orders'];
  static const _pinKey = 'more.pinned.v1';
  static const _compactKey = 'more.compact.v1';

  final SharedPreferences? _store;
  final List<String> _pinned;
  bool _compact;

  List<String> get pinned => List.unmodifiable(_pinned);
  bool get compact => _compact;

  bool isPinned(String id) => _pinned.contains(id);

  /// Ghim hoặc bỏ ghim. Trả `false` nếu đã đủ [maxPinned] mục và đang muốn ghim thêm.
  Future<bool> togglePin(String id) async {
    if (_pinned.remove(id)) {
      await _store?.setStringList(_pinKey, _pinned);
      notifyListeners();
      return true;
    }
    if (_pinned.length >= maxPinned) return false;
    _pinned.add(id);
    await _store?.setStringList(_pinKey, _pinned);
    notifyListeners();
    return true;
  }

  Future<void> setCompact(bool value) async {
    if (_compact == value) return;
    _compact = value;
    await _store?.setBool(_compactKey, value);
    notifyListeners();
  }
}

/// Bỏ dấu tiếng Việt và hạ chữ thường để tìm kiếm "nhan su" ra "Nhân sự".
String foldVietnamese(String input) {
  const groups = {
    'a': 'àáạảãâầấậẩẫăằắặẳẵ',
    'e': 'èéẹẻẽêềếệểễ',
    'i': 'ìíịỉĩ',
    'o': 'òóọỏõôồốộổỗơờớợởỡ',
    'u': 'ùúụủũưừứựửữ',
    'y': 'ỳýỵỷỹ',
    'd': 'đ',
  };
  final out = StringBuffer();
  for (final rune in input.toLowerCase().runes) {
    final ch = String.fromCharCode(rune);
    var mapped = ch;
    for (final e in groups.entries) {
      if (e.value.contains(ch)) {
        mapped = e.key;
        break;
      }
    }
    out.write(mapped);
  }
  return out.toString();
}
