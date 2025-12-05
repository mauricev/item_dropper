import 'package:flutter/foundation.dart';
import '../common/item_dropper_item.dart';

/// Manages selection state for multi-select dropdown
class MultiSelectSelectionManager<T> {
  final int? maxSelected;
  final VoidCallback onSelectionChanged;
  final VoidCallback? onFilterCacheInvalidated;

  List<ItemDropperItem<T>> _selected = [];
  Set<T> _selectedValues = {};

  MultiSelectSelectionManager({
    this.maxSelected,
    required this.onSelectionChanged,
    this.onFilterCacheInvalidated,
  });

  /// Get current selected items
  List<ItemDropperItem<T>> get selected => List.unmodifiable(_selected);

  /// Get selected values as a Set for O(1) lookups
  Set<T> get selectedValues => Set.unmodifiable(_selectedValues);

  /// Get count of selected items
  int get selectedCount => _selected.length;

  /// Check if an item is selected
  bool isSelected(ItemDropperItem<T> item) {
    return _selectedValues.contains(item.value);
  }

  /// Check if maxSelected limit has been reached
  bool isMaxReached() {
    return maxSelected != null && _selected.length >= maxSelected!;
  }

  /// Check if below maxSelected limit (or no limit set)
  bool isBelowMax() {
    return maxSelected == null || _selected.length < maxSelected!;
  }

  /// Add an item to the selection (keeps both List and Set in sync)
  void addItem(ItemDropperItem<T> item) {
    if (!_selectedValues.contains(item.value)) {
      _selected.add(item);
      _selectedValues.add(item.value);
      onSelectionChanged();
      onFilterCacheInvalidated?.call();
    }
  }

  /// Remove an item from the selection (keeps both List and Set in sync)
  void removeItem(T value) {
    if (_selectedValues.contains(value)) {
      _selected.removeWhere((item) => item.value == value);
      _selectedValues.remove(value);
      onSelectionChanged();
      onFilterCacheInvalidated?.call();
    }
  }

  /// Sync selected items from external source (keeps both List and Set in sync)
  void syncItems(List<ItemDropperItem<T>> items) {
    _selected = List.from(items);
    _selectedValues = _selected.map((item) => item.value).toSet();
  }

  /// Clear all selections
  void clear() {
    if (_selected.isNotEmpty) {
      _selected.clear();
      _selectedValues.clear();
      onSelectionChanged();
      onFilterCacheInvalidated?.call();
    }
  }
}
