/// Callback type for dropdown item selection
typedef ItemDropperItemCallback<T> = void Function(ItemDropperItem<T>? selected);

/// Generic dropdown item with value and display label
class ItemDropperItem<T> {
  final T value;
  final String label;
  /// Whether this item is a group header (non-selectable label).
  /// Group headers are displayed but cannot be selected.
  final bool isGroupHeader;

  const ItemDropperItem({
    required this.value, 
    required this.label,
    this.isGroupHeader = false,
  });
}