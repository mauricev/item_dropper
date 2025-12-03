import 'package:flutter/material.dart';
import 'package:item_dropper/item_dropper.dart';

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
  BoxDecoration? selectedChipDecoration,
  Widget Function(BuildContext, ItemDropperItem<T>, bool)? popupItemBuilder,
  ItemDropperItem<T>? Function(String searchText)? onAddItem,
  void Function(ItemDropperItem<T> item)? onDeleteItem,
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
    selectedChipDecoration: selectedChipDecoration,
    onAddItem: onAddItem,
    onDeleteItem: onDeleteItem,
  );
}
