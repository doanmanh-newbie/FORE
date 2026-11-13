import 'package:flutter/widgets.dart';

/// Giữ nội dung ở bề rộng dễ đọc trên màn rộng (máy tính bảng ở quầy), căn giữa.
/// Trên điện thoại không có tác dụng.
class ContentWidth extends StatelessWidget {
  const ContentWidth({super.key, required this.child, this.maxWidth = 720});

  final Widget child;
  final double maxWidth;

  @override
  Widget build(BuildContext context) => Align(
        alignment: Alignment.topCenter,
        // Ôm theo chiều cao của con: nếu không, đặt trong thanh đáy sẽ chiếm hết màn hình.
        heightFactor: 1,
        child: ConstrainedBox(
          constraints: BoxConstraints(maxWidth: maxWidth),
          child: child,
        ),
      );
}
