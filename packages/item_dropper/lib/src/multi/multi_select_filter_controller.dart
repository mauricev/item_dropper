import '../common/item_dropper_item.dart';
import '../common/item_dropper_localizations.dart';
import '../utils/item_dropper_add_item_utils.dart';
import '../utils/item_dropper_filter_utils.dart';

/// Owns filtered-item calculation and memoization for multi-select dropdowns.
class MultiSelectFilterController<T> {
  final ItemDropperFilterUtils<T> _filterUtils;

  List<ItemDropperItem<T>>? _cachedFilteredItems;
  String _lastSearchText = '';
  int _lastSelectedCount = -1;

  MultiSelectFilterController({ItemDropperFilterUtils<T>? filterUtils})
    : _filterUtils = filterUtils ?? ItemDropperFilterUtils<T>();

  void initializeItems(List<ItemDropperItem<T>> items) {
    _filterUtils.initializeItems(items);
    invalidate();
  }

  void clearFilterCache() {
    _filterUtils.clearCache();
    invalidate();
  }

  void invalidate() {
    _cachedFilteredItems = null;
    _lastSearchText = '';
    _lastSelectedCount = -1;
  }

  List<ItemDropperItem<T>> filteredItems({
    required List<ItemDropperItem<T>> items,
    required String searchText,
    required int selectedCount,
    required Set<T> selectedValues,
    required bool hasOnAddItemCallback,
    required ItemDropperLocalizations localizations,
  }) {
    if (_cachedFilteredItems != null &&
        _lastSearchText == searchText &&
        _lastSelectedCount == selectedCount) {
      return _cachedFilteredItems!;
    }

    final result = _filterUtils.getFiltered(
      items,
      searchText,
      isUserEditing: true,
      excludeValues: selectedValues,
    );

    final filteredWithAdd = ItemDropperAddItemUtils.addAddItemIfNeeded<T>(
      filteredItems: result,
      searchText: searchText,
      originalItems: items,
      hasOnAddItemCallback: () => hasOnAddItemCallback,
      localizations: localizations,
    );

    _cachedFilteredItems = filteredWithAdd;
    _lastSearchText = searchText;
    _lastSelectedCount = selectedCount;

    return filteredWithAdd;
  }
}
