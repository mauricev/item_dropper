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
  TextStyle? fieldTextStyle,
  TextStyle? popupTextStyle,
  TextStyle? popupGroupHeaderStyle,
  Widget Function(BuildContext, ItemDropperItem<T>, bool)? popupItemBuilder,
  String? debugId, // Temporary debug identifier
}) {
  return MultiItemDropper<T>(
    width: width,
    items: listItems,
    selectedItems: initiallySelected ?? [],
    onChanged: onChanged,
    popupItemBuilder: popupItemBuilder,
    fieldTextStyle: fieldTextStyle,
    popupTextStyle: popupTextStyle,
    popupGroupHeaderStyle: popupGroupHeaderStyle,
    maxDropdownHeight: maxDropdownHeight ?? 200,
    maxSelected: maxSelected,
    enabled: enabled,
    debugId: debugId, // Pass through debug ID
  );
}
