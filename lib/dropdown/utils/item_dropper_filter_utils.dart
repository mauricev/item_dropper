import '../common/item_dropper_item.dart';

/// Shared filtering behavior for dropdown items
class ItemDropperFilterUtils<T> {
  List<({String label, ItemDropperItem<T> item})> _normalizedItems = [];
  List<ItemDropperItem<T>>? _lastItemsRef;
  List<ItemDropperItem<T>>? _cachedFilteredItems;
  String _lastFilterInput = '';

  /// Initialize normalized items for fast filtering
  void initializeItems(List<ItemDropperItem<T>> items) {
    _lastItemsRef = items;
    _normalizedItems = items
        .map((item) => (label: item.label.trim().toLowerCase(), item: item))
        .toList(growable: false);
  }

  /// Get filtered items based on search text
  List<ItemDropperItem<T>> getFiltered(List<ItemDropperItem<T>> items,
      String searchText, {
        bool isUserEditing = false,
        Set<T>? excludeValues,
      }) {
    final String input = searchText.trim().toLowerCase();

    // Reinitialize if items reference changed
    if (!identical(_lastItemsRef, items)) {
      initializeItems(items);
      _cachedFilteredItems = null;
      _lastFilterInput = '';
    }

    // No filtering if not editing or empty input
    if (!isUserEditing || input.isEmpty) {
      if (excludeValues == null || excludeValues.isEmpty) {
        return items;
      }
      return items
          .where((item) => !excludeValues.contains(item.value))
          .toList();
    }

    // Return cached result if input hasn't changed
    if (_lastFilterInput == input && _cachedFilteredItems != null) {
      return _cachedFilteredItems!;
    }

    // Compute and cache filtered list
    final List<ItemDropperItem<T>> filteredResult = _normalizedItems
        .where((entry) =>
    entry.label.contains(input) &&
        (excludeValues == null || !excludeValues.contains(entry.item.value)))
        .map((entry) => entry.item)
        .toList(growable: false);

    _lastFilterInput = input;
    _cachedFilteredItems = filteredResult;
    return filteredResult;
  }

  /// Clear the filter cache
  void clearCache() {
    _cachedFilteredItems = null;
    _lastFilterInput = '';
  }
}