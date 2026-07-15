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
  /// [originalItems] - The original list of items (must not be empty)
  /// [localizations] - Optional localizations (defaults to English)
  ///
  /// The value for the add item is a placeholder taken from the first item in
  /// [originalItems], because Dart cannot synthesize an arbitrary unique [T].
  /// The [ItemDropperItem.isAddItem] flag identifies the sentinel; neither its
  /// value nor its localized label participates in identification.
  ///
  /// Throws [ArgumentError] if [originalItems] is empty. When using the add item
  /// feature, always ensure your items list has at least one item, or provide
  /// a default item for type reference.
  static ItemDropperItem<T> createAddItem<T>(
    String searchText,
    List<ItemDropperItem<T>> originalItems, {
    ItemDropperLocalizations? localizations,
  }) {
    if (originalItems.isEmpty) {
      throw ArgumentError(
        'Cannot create add item when originalItems is empty. '
        'The items list must contain at least one item to provide a type reference for T. '
        'If your list can be empty, provide a default item or disable the onAddItem feature.',
      );
    }

    final loc = localizations ?? ItemDropperLocalizations.english;
    // Use the first item's value as a type-compatible placeholder.
    final T addItemValue = originalItems.first.value;

    return ItemDropperItem<T>(
      value: addItemValue,
      label: '${loc.addItemPrefix}$searchText${loc.addItemSuffix}',
      isGroupHeader: false,
      isAddItem: true,
    );
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
