import 'package:flutter/material.dart';
import 'common/item_dropper_common.dart';
import 'item_dropper_single_select.dart';

Widget popupItemBuilder<T>(BuildContext context, ItemDropperItem<T> item,
    bool isSelected) {
  return Container(
    color: isSelected ? Colors.grey.shade200 : null,
    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
    child: Text(item.label),
  );
}

InputDecoration returnInputDecorationForDropdown(String? hintText) {
  return InputDecoration(
    hintText: hintText,
    border: const OutlineInputBorder(
      borderRadius: BorderRadius.all(Radius.circular(8)),
    ),
  );
}

Widget dropDown<T>({
  required double width,
  required List<ItemDropperItem<T>> listItems,
  ItemDropperItem<T>? initiallySelected,
  required Function(ItemDropperItem<T>?) onChanged,
  String? hintText,
  bool showKeyboard = false,
  double? maxDropdownHeight,
  bool enabled = true,
  TextStyle? fieldTextStyle,
  TextStyle? popupTextStyle,
  TextStyle? popupGroupHeaderStyle,
  Widget Function(BuildContext, ItemDropperItem<T>, bool)? popupItemBuilder,
  ItemDropperItem<T>? Function(String searchText)? onAddItem,
}) {
  return SingleItemDropper<T>(
    width: width,
    items: listItems,
    selectedItem: initiallySelected,
    onChanged: onChanged,
    popupItemBuilder: popupItemBuilder,
    showKeyboard: showKeyboard,
    fieldTextStyle: fieldTextStyle,
    popupTextStyle: popupTextStyle,
    popupGroupHeaderStyle: popupGroupHeaderStyle,
    maxDropdownHeight: maxDropdownHeight ?? 200,
    enabled: enabled,
    onAddItem: onAddItem,
  );
}
