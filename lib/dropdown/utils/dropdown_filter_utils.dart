import '../common/dropdown_item.dart';

/// Shared filtering behavior for dropdown items
class DropdownFilterUtils<T> {
  List<({String label, DropDownItem<T> item})> _normalizedItems = [];
  List<DropDownItem<T>>? _lastItemsRef;
  List<DropDownItem<T>>? _cachedFilteredItems;
  String _lastFilterInput = '';

  /// Initialize normalized items for fast filtering
  void initializeItems(List<DropDownItem<T>> items) {
    _lastItemsRef = items;
    _normalizedItems = items
        .map((item) => (label: item.label.trim().toLowerCase(), item: item))
        .toList(growable: false);
  }

  /// Get filtered items based on search text
  List<DropDownItem<T>> getFiltered(List<DropDownItem<T>> items,
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
    final List<DropDownItem<T>> filteredResult = _normalizedItems
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