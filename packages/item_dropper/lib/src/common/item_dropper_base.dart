import 'package:flutter/material.dart';

import 'item_dropper_item.dart';
import 'item_dropper_localizations.dart';

/// Shared public contract for item dropper widgets.
///
/// [SingleItemDropper] and [MultiItemDropper] keep their specialized
/// selection APIs, but expose this common configuration surface for code that
/// can work with either widget type.
abstract class ItemDropperBase<T> extends StatefulWidget {
  const ItemDropperBase({super.key});

  List<ItemDropperItem<T>> get items;

  Widget Function(BuildContext, ItemDropperItem<T>, bool)? get popupItemBuilder;

  double get width;

  bool get enabled;

  String? get hintText;

  ItemDropperItem<T>? Function(String searchText)? get onAddItem;

  void Function(ItemDropperItem<T> item)? get onDeleteItem;

  GlobalKey? get inputKey;

  double get maxDropdownHeight;

  bool get showScrollbar;

  double get scrollbarThickness;

  double? get itemHeight;

  TextStyle? get popupTextStyle;

  TextStyle? get popupGroupHeaderStyle;

  TextStyle? get fieldTextStyle;

  BoxDecoration? get fieldDecoration;

  double? get elevation;

  bool get showDropdownPositionIcon;

  bool get showDeleteAllIcon;

  ItemDropperLocalizations? get localizations;
}
