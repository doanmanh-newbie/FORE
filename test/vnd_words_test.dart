import 'package:flutter_test/flutter_test.dart';
import 'package:fore/core/vnd_words.dart';

void main() {
  test('đọc số tiền thành chữ tiếng Việt', () {
    expect(vndInWords(0), 'Không đồng');
    expect(vndInWords(5), 'Năm đồng');
    expect(vndInWords(10), 'Mười đồng');
    expect(vndInWords(50), 'Năm mươi đồng');
    expect(vndInWords(1000), 'Một nghìn đồng');
    expect(vndInWords(15000), 'Mười lăm nghìn đồng');
    expect(vndInWords(21000), 'Hai mươi mốt nghìn đồng');
    expect(vndInWords(105000), 'Một trăm lẻ năm nghìn đồng');
    expect(vndInWords(500000), 'Năm trăm nghìn đồng');
    expect(vndInWords(1000000), 'Một triệu đồng');
    expect(vndInWords(1250000), 'Một triệu hai trăm năm mươi nghìn đồng');
    expect(vndInWords(1005000), 'Một triệu không trăm lẻ năm nghìn đồng');
    expect(vndInWords(100000000), 'Một trăm triệu đồng');
  });
}
