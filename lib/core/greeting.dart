/// Buổi trong ngày, để chào đúng lúc: "buổi sáng", "buổi trưa"...
String partOfDay(DateTime time) {
  final h = time.toLocal().hour;
  if (h >= 5 && h < 11) return 'buổi sáng';
  if (h >= 11 && h < 14) return 'buổi trưa';
  if (h >= 14 && h < 18) return 'buổi chiều';
  return 'buổi tối';
}

/// Tên gọi ngắn của người dùng: từ cuối của họ tên ("Nguyễn Văn An" -> "An").
String shortName(String fullName) {
  final parts = fullName.trim().split(RegExp(r'\s+'));
  return parts.isEmpty ? '' : parts.last;
}
