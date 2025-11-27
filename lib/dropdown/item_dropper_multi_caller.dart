import 'package:flutter/material.dart';
import 'item_dropper_common.dart';
import 'item_dropper_multi_select.dart';

Widget popupItemBuilderMulti<T>(BuildContext context, ItemDropperItem<T> item,
    bool isSelected) {
  return Text(item.label);
}

InputDecoration returnInputDecorationForMultiDropdown(String? hintText) {
  return InputDecoration(
    hintText: hintText,
    border: const OutlineInputBorder(
      borderRadius: BorderRadius.all(Radius.circular(8)),
    ),
  );
}

Widget multiDropDown<T>({
  required double width,
  required List<ItemDropperItem<T>> listItems,
  List<ItemDropperItem<T>>? initiallySelected,
  required Function(List<ItemDropperItem<T>>) onChanged,
  String? hintText,
  double? maxDropdownHeight,
  int? maxSelected,
  bool enabled = true,
}) {
  return MultiItemDropper<T>(
    width: width,
    items: listItems,
    selectedItems: initiallySelected ?? [],
    onChanged: onChanged,
    // popupItemBuilder: omitted to use default
    decoration: returnInputDecorationForMultiDropdown(hintText),
    textSize: 14,
    maxDropdownHeight: maxDropdownHeight ?? 200,
    maxSelected: maxSelected,
    enabled: enabled,
  );
}
