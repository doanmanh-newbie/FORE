import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fore/features/owner/menu/menu_image_view.dart';
import 'package:fore/features/owner/menu/menu_models.dart';

void main() {
  test('đọc topping và nhóm tùy chọn của món', () {
    final extras = ItemExtras.fromJson({
      'item_id': 'i1',
      'topping_max_kinds': 2,
      'topping_max_portions': 1,
      'toppings': [
        {
          'id': 't1',
          'name': 'Trân châu',
          'price': 5000,
          'active': true,
          'ingredient_id': 'g1',
          'ingredient_name': 'Trân châu khô',
          'unit': 'g',
          'qty': 30,
          'unit_cost': 60,
          'cost': 1800,
          'cost_known': true,
          'selected': true,
        },
        {
          'id': 't2',
          'name': 'Kem sữa',
          'price': 8000,
          'active': false,
          'cost': 0,
          'cost_known': true,
          'selected': true,
        },
      ],
      'groups': [
        {
          'id': 'g1',
          'name': 'Mức đá',
          'required': true,
          'choices': [
            {'id': 'c1', 'name': 'Ít', 'is_default': false, 'price_delta': 0},
            {'id': 'c2', 'name': 'Bình thường', 'is_default': true, 'price_delta': 0},
          ],
        },
      ],
    });
    // Topping đang tạm ngừng không được tính là bán kèm dù còn đánh dấu.
    expect(extras.selectedToppings.map((t) => t.name), ['Trân châu']);
    expect(extras.toppings.first.cost, 1800);
    expect(extras.toppings.first.hasRecipe, isTrue);
    expect(extras.toppings.last.hasRecipe, isFalse);
    expect(extras.groups.single.defaultChoice?.name, 'Bình thường');
  });

  test('nhóm tùy chọn nháp xuất đúng JSON cho database', () {
    final group = DraftOptionGroup(
      name: ' Mức đường ',
      choices: [
        DraftOptionChoice(name: 'Ít'),
        DraftOptionChoice(
            name: 'Thêm', isDefault: true, ingredientId: 'ing', qty: 10),
      ],
    );
    final json = group.toJson();
    expect(json['name'], 'Mức đường');
    expect(json['required'], true);
    expect(json.containsKey('id'), isFalse);
    final choices = json['choices'] as List;
    expect((choices[1] as Map)['qty'], 10);
    expect((choices[0] as Map)['ingredient_id'], isNull);
  });

  test('xem trước sao chép: đếm nguyên liệu khớp', () {
    final p = CopyPreview.fromJson({
      'name_taken': true,
      'category': 'Cà phê',
      'category_exists': false,
      'sizes': [
        {'name': 'S', 'price': 35000}
      ],
      'lines': [
        {
          'ingredient_id': 'a',
          'name': 'Sữa',
          'unit': 'ml',
          'qty': 140,
          'sizes': ['S'],
          'match_id': 'x',
          'match_name': 'Sữa tươi',
        },
        {
          'ingredient_id': 'b',
          'name': 'Ly',
          'unit': 'piece',
          'qty': 1,
          'sizes': ['S'],
        },
      ],
      'dest_ingredients': [
        {'id': 'x', 'name': 'Sữa tươi', 'unit': 'ml'}
      ],
      'topping_count': 1,
      'option_group_count': 0,
    });
    expect(p.nameTaken, isTrue);
    expect(p.matchedCount, 1);
    expect(p.lines.length, 2);
    expect(p.sizes.single.price, 35000);
  });

  test('kết quả sao chép đọc đủ trường mới', () {
    final r = CopyResult.fromJson({
      'item_id': 'n',
      'copied_lines': 3,
      'skipped_ingredients': ['Đá'],
      'copied_toppings': 1,
      'skipped_toppings': ['Kem'],
      'copied_option_groups': 2,
    });
    expect(r.skippedIngredients, ['Đá']);
    expect(r.copiedToppings, 1);
    expect(r.skippedToppings, ['Kem']);
    expect(r.copiedOptionGroups, 2);
  });

  testWidgets('chưa có ảnh thì hiện hình ly trung tính', (tester) async {
    await tester.pumpWidget(const MaterialApp(
      home: Scaffold(body: MenuThumb(path: null)),
    ));
    expect(find.byIcon(Icons.local_cafe_outlined), findsOneWidget);
  });
}
