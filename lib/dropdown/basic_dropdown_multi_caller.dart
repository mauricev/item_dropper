import 'package:flutter/material.dart';
import 'basic_dropdown_common.dart';
import 'basic_dropdown_multi_select.dart';

Widget popupItemBuilderMulti<T>(BuildContext context, DropDownItem<T> item,
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
  required List<DropDownItem<T>> listItems,
  List<DropDownItem<T>>? initiallySelected,
  required Function(List<DropDownItem<T>>) onChanged,
  String? hintText,
  double? maxDropdownHeight,
  bool enabled = true,
}) {
  return MultiSearchDropdown<T>(
    width: width,
    items: listItems,
    selectedItems: initiallySelected ?? [],
    onChanged: onChanged,
    // popupItemBuilder: omitted to use default
    decoration: returnInputDecorationForMultiDropdown(hintText),
    textSize: 14,
    maxDropdownHeight: maxDropdownHeight ?? 200,
    enabled: enabled,
  );
}
