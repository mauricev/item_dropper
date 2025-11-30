import '../common/item_dropper_item.dart';

/// Shared utilities for "add item" functionality in dropdowns
class ItemDropperAddItemUtils {
  /// Check if an item is the special "add" item
  static bool isAddItem<T>(
    ItemDropperItem<T> item,
    List<ItemDropperItem<T>> originalItems,
  ) {
    // Check label pattern: must start with 'Add "' and end with '"'
    if (!item.label.startsWith('Add "') || !item.label.endsWith('"')) {
      return false;
    }
    // Also verify it's not in the original items list (safety check)
    // Check both value and label to be safe
    final bool notInOriginalList = !originalItems.any((originalItem) => 
        originalItem.value == item.value && originalItem.label == item.label);
    return notInOriginalList;
  }
  
  /// Extract search text from add item label
  /// Label format: 'Add "search text"'
  static String extractSearchTextFromAddItem<T>(ItemDropperItem<T> item) {
    if (item.label.startsWith('Add "') && item.label.endsWith('"')) {
      return item.label.substring(5, item.label.length - 1);
    }
    return '';
  }
  
  /// Create an "add item" for the given search text
  static ItemDropperItem<T> createAddItem<T>(
    String searchText,
    List<ItemDropperItem<T>> originalItems,
  ) {
    // For the value, use a template that won't match existing items
    // Since we detect by label pattern, the exact value doesn't matter
    T addItemValue;
    if (originalItems.isNotEmpty) {
      // Use first item's value as template (won't match since we check label pattern)
      addItemValue = originalItems.first.value;
    } else {
      // Fallback: try to cast searchText (works for String types)
      addItemValue = searchText as T;
    }
    
    return ItemDropperItem<T>(
      value: addItemValue,
      label: 'Add "$searchText"',
      isGroupHeader: false,
    );
  }
  
  /// Add "add item" to filtered list if conditions are met
  static List<ItemDropperItem<T>> addAddItemIfNeeded<T>({
    required List<ItemDropperItem<T>> filteredItems,
    required String searchText,
    required List<ItemDropperItem<T>> originalItems,
    required bool Function() hasOnAddItemCallback,
  }) {
    // Add "add item" row if search text exists, callback is provided, and there's no exact match
    final String trimmedSearchText = searchText.trim();
    if (trimmedSearchText.isNotEmpty && hasOnAddItemCallback()) {
      // Check if there's an exact match (case-insensitive)
      final bool hasExactMatch = originalItems.any((item) => 
          !item.isGroupHeader &&
          item.label.trim().toLowerCase() == trimmedSearchText.toLowerCase());
      
      // Show add item if there's no exact match (even if there are partial matches)
      if (!hasExactMatch) {
        final addItem = createAddItem(trimmedSearchText, originalItems);
        return [addItem, ...filteredItems];
      }
    }
    return filteredItems;
  }
}

