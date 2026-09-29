/// Callback type for dropdown item selection
typedef ItemDropperItemCallback<T> =
    void Function(ItemDropperItem<T>? selected);

/// Generic dropdown item with value and display label
class ItemDropperItem<T> {
  /// Value associated with this item.
  /// Internal add-action rows have no value; check [isAddItem] before reading.
  final T value;

  /// Text displayed for this item.
  final String label;

  /// Whether this item is a group header (non-selectable label).
  /// Group headers are displayed but cannot be selected.
  final bool isGroupHeader;

  /// Whether this item can be deleted through the dropdown UI.
  final bool isDeletable;

  /// Whether this item is enabled (selectable) in the dropdown.
  /// Disabled items are rendered but cannot be selected.
  final bool isEnabled;

  /// Whether this item is the internal "add item" sentinel row.
  ///
  /// Add rows represent actions and have no selectable [value]. Custom popup
  /// builders should render their [label] without reading [value].
  final bool isAddItem;

  const ItemDropperItem({
    required this.value,
    required this.label,
    this.isGroupHeader = false,
    this.isDeletable = false,
    this.isEnabled = true,
    this.isAddItem = false,
  });

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        other is ItemDropperItem<T> &&
            other.isAddItem == isAddItem &&
            (isAddItem || other.value == value) &&
            other.label == label &&
            other.isGroupHeader == isGroupHeader &&
            other.isDeletable == isDeletable &&
            other.isEnabled == isEnabled;
  }

  @override
  int get hashCode {
    return Object.hash(
      isAddItem ? null : value,
      label,
      isGroupHeader,
      isDeletable,
      isEnabled,
      isAddItem,
    );
  }
}
