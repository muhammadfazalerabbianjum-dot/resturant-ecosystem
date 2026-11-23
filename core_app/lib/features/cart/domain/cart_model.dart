import 'package:freezed_annotation/freezed_annotation.dart';
import '../../menu/domain/menu_item_model.dart';
import '../../menu/domain/menu_modifier_model.dart';

part 'cart_model.freezed.dart';
part 'cart_model.g.dart';

@freezed
class CartItemModel with _$CartItemModel {
  const CartItemModel._(); // Allow getters

  const factory CartItemModel({
    required MenuItemModel item,
    @Default(1) int quantity,
    @Default([]) List<ModifierOption> selectedOptions,
  }) = _CartItemModel;

  int get unitPriceCents =>
      item.priceCents +
      selectedOptions.fold(0, (sum, opt) => sum + opt.upchargeCents);

  int get totalCents => unitPriceCents * quantity;

  factory CartItemModel.fromJson(Map<String, dynamic> json) =>
      _$CartItemModelFromJson(json);
}

@freezed
class CartModel with _$CartModel {
  const CartModel._(); // Allow getters

  const factory CartModel({@Default([]) List<CartItemModel> items}) =
      _CartModel;

  int get totalCents => items.fold(0, (sum, i) => sum + i.totalCents);

  factory CartModel.fromJson(Map<String, dynamic> json) =>
      _$CartModelFromJson(json);
}
