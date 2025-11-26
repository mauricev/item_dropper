/// Callback type for dropdown item selection
typedef DropDownItemCallback<T> = void Function(DropDownItem<T>? selected);

/// Generic dropdown item with value and display label
class DropDownItem<T> {
  final T value;
  final String label;

  const DropDownItem({required this.value, required this.label});
}