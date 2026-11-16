/// Nhận ra lỗi mạng trong các kiểu lỗi khác nhau của từng nền tảng.
///
/// Gói http bản mới đổi lỗi mạng thành `ClientException` (không còn là
/// `SocketException`); trên web là lỗi XMLHttpRequest. Nhận ra qua chữ trong lỗi.
bool looksLikeNetworkError(Object e) {
  final text = e.toString().toLowerCase();
  return text.contains('socketexception') ||
      text.contains('clientexception') ||
      text.contains('failed host lookup') ||
      text.contains('network is unreachable') ||
      text.contains('xmlhttprequest error');
}
