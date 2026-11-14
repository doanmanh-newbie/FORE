/// Đọc số tiền thành chữ tiếng Việt: 500000 -> "Năm trăm nghìn đồng".
///
/// Dùng để người nhập tiền nhìn thấy ngay mình có gõ thừa/thiếu số 0 hay không.
String vndInWords(int amount) {
  if (amount <= 0) return 'Không đồng';
  const units = ['', 'nghìn', 'triệu', 'tỷ'];

  // Tách thành các nhóm ba chữ số, từ nhỏ đến lớn.
  final groups = <int>[];
  var rest = amount;
  while (rest > 0) {
    groups.add(rest % 1000);
    rest ~/= 1000;
  }

  final parts = <String>[];
  var started = false; // đã đọc nhóm lớn hơn chưa (để đọc "không trăm")
  for (var i = groups.length - 1; i >= 0; i--) {
    final g = groups[i];
    if (g == 0) continue;
    parts.add(_readGroup(g, pad: started));
    if (units[i].isNotEmpty) parts.add(units[i]);
    started = true;
  }
  final text = '${parts.join(' ')} đồng';
  return text[0].toUpperCase() + text.substring(1);
}

const _digits = [
  'không',
  'một',
  'hai',
  'ba',
  'bốn',
  'năm',
  'sáu',
  'bảy',
  'tám',
  'chín',
];

String _readGroup(int n, {required bool pad}) {
  final h = n ~/ 100;
  final t = (n % 100) ~/ 10;
  final u = n % 10;
  final words = <String>[];

  if (h > 0 || pad) words.add('${_digits[h]} trăm');

  if (t > 1) {
    words.add('${_digits[t]} mươi');
    if (u == 1) {
      words.add('mốt');
    } else if (u == 5) {
      words.add('lăm');
    } else if (u > 0) {
      words.add(_digits[u]);
    }
  } else if (t == 1) {
    words.add('mười');
    if (u == 5) {
      words.add('lăm');
    } else if (u > 0) {
      words.add(_digits[u]);
    }
  } else if (u > 0) {
    // hàng chục bằng 0: "lẻ" khi có hàng trăm đứng trước
    if (h > 0 || pad) words.add('lẻ');
    words.add(_digits[u]);
  }
  return words.join(' ');
}
