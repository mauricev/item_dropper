import '../common/item_dropper_item.dart';
import '../common/item_dropper_localizations.dart';

/// Shared utilities for "add item" functionality in dropdowns
class ItemDropperAddItemUtils {
  /// Check if an item is the special "add" item.
  static bool isAddItem<T>(ItemDropperItem<T> item) => item.isAddItem;

  /// Extract search text from add item label
  /// Label format: '{prefix}search text{suffix}'
  static String extractSearchTextFromAddItem<T>(
    ItemDropperItem<T> item, {
    ItemDropperLocalizations? localizations,
  }) {
    final loc = localizations ?? ItemDropperLocalizations.english;
    final prefix = loc.addItemPrefix;
    final suffix = loc.addItemSuffix;
    if (!item.label.startsWith(prefix) || !item.label.endsWith(suffix)) {
      return '';
    }
    return item.label.substring(
      prefix.length,
      item.label.length - suffix.length,
    );
  }

  /// Create an "add item" for the given search text
  ///
  /// [searchText] - The search text entered by the user
  /// [originalItems] - Retained for compatibility; may be empty.
  /// [localizations] - Optional localizations (defaults to English).
  ///
  /// This row represents an action, not a selected value. Check [isAddItem]
  /// before accessing its value, including in custom popup builders.
  static ItemDropperItem<T> createAddItem<T>(
    String searchText,
    List<ItemDropperItem<T>> originalItems, {
    ItemDropperLocalizations? localizations,
  }) {
    final loc = localizations ?? ItemDropperLocalizations.english;
    return _AddItem<T>('${loc.addItemPrefix}$searchText${loc.addItemSuffix}');
  }

  /// Add "add item" to filtered list if conditions are met
  static List<ItemDropperItem<T>> addAddItemIfNeeded<T>({
    required List<ItemDropperItem<T>> filteredItems,
    required String searchText,
    required List<ItemDropperItem<T>> originalItems,
    required bool Function() hasOnAddItemCallback,
    ItemDropperLocalizations? localizations,
  }) {
    // Add "add item" row if search text exists, callback is provided, and there's no exact match
    final String trimmedSearchText = searchText.trim();
    if (trimmedSearchText.isNotEmpty && hasOnAddItemCallback()) {
      // Check if there's an exact match (case-insensitive)
      final bool hasExactMatch = originalItems.any(
        (item) =>
            !item.isGroupHeader &&
            item.label.trim().toLowerCase() == trimmedSearchText.toLowerCase(),
      );

      // Show add item if there's no exact match (even if there are partial matches)
      if (!hasExactMatch) {
        final addItem = createAddItem(
          trimmedSearchText,
          originalItems,
          localizations: localizations,
        );
        return [addItem, ...filteredItems];
      }
    }
    return filteredItems;
  }
}

/// A UI action with no fabricated value of the caller's generic type.
class _AddItem<T> implements ItemDropperItem<T> {
  const _AddItem(this.label);

  @override
  final String label;
  @override
  T get value => throw StateError('Add-item action rows have no item value.');
  @override
  bool get isGroupHeader => false;
  @override
  bool get isDeletable => false;
  @override
  bool get isEnabled => true;
  @override
  bool get isAddItem => true;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ItemDropperItem<T> &&
          other.isAddItem &&
          other.label == label &&
          !other.isGroupHeader &&
          !other.isDeletable &&
          other.isEnabled;

  @override
  int get hashCode => Object.hash(null, label, false, false, true, true);
}
