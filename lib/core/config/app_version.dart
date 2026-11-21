/// Phiên bản app đang chạy. Build bản phát hành: `--dart-define=APP_VERSION=1.2.0+5`.
/// Không truyền thì là `dev` (bản chạy thử: không bị chặn bởi `min_version`).
const appVersion = String.fromEnvironment('APP_VERSION', defaultValue: 'dev');

/// So sánh hai phiên bản dạng `1.2.0` (bỏ phần `+build` và `-pre`).
/// Trả âm nếu `a < b`, 0 nếu bằng, dương nếu `a > b`; `null` nếu một bên không đọc được.
int? compareVersions(String a, String b) {
  final pa = _parse(a), pb = _parse(b);
  if (pa == null || pb == null) return null;
  for (var i = 0; i < 3; i++) {
    final d = pa[i].compareTo(pb[i]);
    if (d != 0) return d;
  }
  return 0;
}

List<int>? _parse(String v) {
  final core = v.trim().split('+').first.split('-').first;
  final parts = core.split('.');
  if (parts.isEmpty || parts.length > 3) return null;
  final nums = <int>[];
  for (final p in parts) {
    final n = int.tryParse(p);
    if (n == null || n < 0) return null;
    nums.add(n);
  }
  while (nums.length < 3) {
    nums.add(0);
  }
  return nums;
}
