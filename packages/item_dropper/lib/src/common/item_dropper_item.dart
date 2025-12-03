/// Callback type for dropdown item selection
typedef ItemDropperItemCallback<T> = void Function(ItemDropperItem<T>? selected);

/// Generic dropdown item with value and display label
class ItemDropperItem<T> {
  final T value;
  final String label;
  /// Whether this item is a group header (non-selectable label).
  /// Group headers are displayed but cannot be selected.
  final bool isGroupHeader;
  final bool isDeletable;
  /// Whether this item is enabled (selectable) in the dropdown.
  /// Disabled items are rendered but cannot be selected.
  final bool isEnabled;

  const ItemDropperItem({
    required this.value, 
    required this.label,
    this.isGroupHeader = false,
    this.isDeletable = false,
    this.isEnabled = true,
  });
}