import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fore/core/design/colors.dart';

double _luminance(Color color) {
  double channel(double srgb) {
    return srgb <= 0.04045
        ? srgb / 12.92
        : ((srgb + 0.055) / 1.055) *
            ((srgb + 0.055) / 1.055) *
            ((srgb + 0.055) / 1.055);
  }

  return 0.2126 * channel(color.r) +
      0.7152 * channel(color.g) +
      0.0722 * channel(color.b);
}

double _contrast(Color foreground, Color background) {
  final values = [_luminance(foreground), _luminance(background)]
    ..sort((a, b) => b.compareTo(a));
  return (values.first + 0.05) / (values.last + 0.05);
}

void main() {
  test('các cặp chữ thường trong design system đạt tương phản 4.5:1', () {
    final pairs = <String, (Color, Color)>{
      'chữ chính trên nền': (AppColors.textPrimary, AppColors.background),
      'chữ chính trên thẻ': (AppColors.textPrimary, AppColors.surface),
      'chữ phụ trên nền': (AppColors.textSecondary, AppColors.background),
      'chữ phụ trên thẻ': (AppColors.textSecondary, AppColors.surface),
      'trạng thái ổn': (AppColors.statusHealthy, AppColors.statusHealthyTint),
      'trạng thái chú ý': (
        AppColors.statusAttention,
        AppColors.statusAttentionTint
      ),
      'trạng thái lệch nhiều': (
        AppColors.statusCritical,
        AppColors.statusCriticalTint
      ),
      'nút tối': (AppColors.surface, AppColors.brand),
    };

    for (final entry in pairs.entries) {
      expect(
        _contrast(entry.value.$1, entry.value.$2),
        greaterThanOrEqualTo(4.5),
        reason: '${entry.key} phải đạt WCAG AA cho chữ thường',
      );
    }
  });
}
