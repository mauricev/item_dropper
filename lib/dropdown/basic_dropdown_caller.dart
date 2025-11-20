import 'package:flutter/material.dart';
import 'basic_dropdown_common.dart';
import 'basic_dropdown_single_select.dart';

Widget popupItemBuilder(
    BuildContext context, DropDownItem item, bool isSelected) {
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

Widget dropDown(
    {required double width,
    required List<DropDownItem> listItems,
    DropDownItem? initiallySelected,
    required Function(DropDownItem?) onChanged,
    String? hintText,
    bool showKeyboard = false,
    double? maxDropdownHeight,
    bool enabled = true}) {
  return SearchDropdown<dynamic>(
    width: width,
    items: listItems,
    selectedItem: initiallySelected,
    onChanged: onChanged,
    popupItemBuilder: popupItemBuilder,
    decoration: returnInputDecorationForDropdown(hintText),
    showKeyboard: showKeyboard,
    textSize: 10,
    maxDropdownHeight: maxDropdownHeight ?? 200,
    enabled: enabled,
  );
}
