import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../../core/design/colors.dart';
import '../../../core/design/typography.dart';
import '../../../core/format.dart';
import 'menu_format.dart';
import 'menu_models.dart';
import 'menu_recipe_views.dart';
import 'menu_store.dart';
import 'menu_widgets.dart';

part 'menu_extras_topping_picker.dart';
part 'menu_extras_topping_manager.dart';
part 'menu_extras_topping_edit.dart';
part 'menu_extras_options_setup.dart';
part 'menu_extras_options_preview.dart';

/// Giá các size, ví dụ "S 35.000đ · M 42.000đ".
String _sizePrices(ItemDetail d) => [
      for (final s in d.activeSizes) '${s.name} ${formatVnd(s.price)}',
    ].join(' · ');

// ---------------------------------------------------------------------------
// Chọn topping bán kèm cho món
// ---------------------------------------------------------------------------