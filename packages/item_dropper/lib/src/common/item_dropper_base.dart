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

  /// Items displayed by the dropdown.
  List<ItemDropperItem<T>> get items;

  /// Optional custom builder for popup rows.
  Widget Function(BuildContext, ItemDropperItem<T>, bool)? get popupItemBuilder;

  /// Width of the dropdown field.
  double get width;

  /// Whether the widget accepts interaction.
  bool get enabled;

  /// Placeholder shown when the field has no value or search text.
  String? get hintText;

  /// Creates an item from search text when add-item support is enabled.
  ItemDropperItem<T>? Function(String searchText)? get onAddItem;

  /// Deletes an item when deletion support is enabled.
  void Function(ItemDropperItem<T> item)? get onDeleteItem;

  /// Optional key for accessing the input field.
  GlobalKey? get inputKey;

  /// Maximum height available to the popup.
  double get maxDropdownHeight;

  /// Whether the popup displays a vertical scrollbar.
  bool get showScrollbar;

  /// Thickness of the popup scrollbar.
  double get scrollbarThickness;

  /// Fixed popup-row height, or `null` to derive it from text style.
  double? get itemHeight;

  /// Text style used by normal popup rows.
  TextStyle? get popupTextStyle;

  /// Text style used by group-header popup rows.
  TextStyle? get popupGroupHeaderStyle;

  /// Text style used by the input field.
  TextStyle? get fieldTextStyle;

  /// Optional decoration for the input field container.
  BoxDecoration? get fieldDecoration;

  /// Material elevation of the popup.
  double? get elevation;

  /// Whether the field displays its dropdown-position icon.
  bool get showDropdownPositionIcon;

  /// Whether the field displays its clear icon.
  bool get showDeleteAllIcon;

  /// Localized strings used by the widget, or `null` for English defaults.
  ItemDropperLocalizations? get localizations;
}
