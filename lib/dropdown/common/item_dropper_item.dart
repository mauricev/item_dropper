/// Callback type for dropdown item selection
typedef ItemDropperItemCallback<T> = void Function(ItemDropperItem<T>? selected);

/// Generic dropdown item with value and display label
class ItemDropperItem<T> {
  final T value;
  final String label;

  const ItemDropperItem({required this.value, required this.label});
}