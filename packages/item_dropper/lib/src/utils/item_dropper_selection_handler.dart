import '../common/item_dropper_item.dart';
import '../common/item_dropper_localizations.dart';
import 'item_dropper_add_item_utils.dart';

/// Shared handler for processing add item selections in dropdown widgets.
/// 
/// This utility consolidates the common pattern of:
/// 1. Checking if an item is an "add item"
/// 2. Extracting search text
/// 3. Calling the onAddItem callback
/// 4. Handling the newly created item
/// 
/// Example usage:
/// ```dart
/// final result = ItemDropperSelectionHandler.handleAddItemIfNeeded(
///   item: selectedItem,
///   originalItems: widget.items,
///   onAddItem: widget.onAddItem,
///   onItemCreated: (newItem) {
///     // Handle the new item (select it, update UI, etc.)
///   },
/// );
/// 
/// if (result.handled) {
///   return; // Add item was handled, don't process as normal item
/// }
/// ```
/// Result of add item handling attempt
class AddItemResult<T> {
  /// Whether the add item was handled
  final bool handled;
  
  /// The newly created item (if handled and created successfully)
  final ItemDropperItem<T>? newItem;
  
  AddItemResult({required this.handled, this.newItem});
}

/// Shared handler for processing add item selections in dropdown widgets.
/// 
/// This utility consolidates the common pattern of:
/// 1. Checking if an item is an "add item"
/// 2. Extracting search text
/// 3. Calling the onAddItem callback
/// 4. Handling the newly created item
/// 
/// Example usage:
/// ```dart
/// final result = ItemDropperSelectionHandler.handleAddItemIfNeeded(
///   item: selectedItem,
///   originalItems: widget.items,
///   onAddItem: widget.onAddItem,
///   onItemCreated: (newItem) {
///     // Handle the new item (select it, update UI, etc.)
///   },
/// );
/// 
/// if (result.handled) {
///   return; // Add item was handled, don't process as normal item
/// }
/// ```
class ItemDropperSelectionHandler {
  
  /// Handles add item selection if the item is an add item.
  /// 
  /// Returns [AddItemResult] indicating whether the add item was handled
  /// and the newly created item (if any).
  /// 
  /// Parameters:
  ///   - [item]: The item to check and potentially handle as add item
  ///   - [originalItems]: The original list of items (used to verify add item)
  ///   - [onAddItem]: Callback to create new item (null if add item feature disabled)
  ///   - [onItemCreated]: Callback invoked when a new item is successfully created
  /// 
  /// Returns [AddItemResult.handled = true] if the item was an add item and was handled,
  /// [AddItemResult.handled = false] otherwise.
  static AddItemResult<T> handleAddItemIfNeeded<T>({
    required ItemDropperItem<T> item,
    required List<ItemDropperItem<T>> originalItems,
    required ItemDropperItem<T>? Function(String)? onAddItem,
    required void Function(ItemDropperItem<T>) onItemCreated,
    ItemDropperLocalizations? localizations,
  }) {
    // Check if this is an add item
    if (!ItemDropperAddItemUtils.isAddItem(item, originalItems, localizations: localizations)) {
      return AddItemResult<T>(handled: false);
    }
    
    // Extract search text and create new item
    final String searchText = ItemDropperAddItemUtils
        .extractSearchTextFromAddItem(item, localizations: localizations);
    
    if (searchText.isNotEmpty && onAddItem != null) {
      final ItemDropperItem<T>? newItem = onAddItem(searchText);
      
      if (newItem != null) {
        // Invoke callback to handle the new item (select it, update UI, etc.)
        onItemCreated(newItem);
        return AddItemResult<T>(handled: true, newItem: newItem);
      }
    }
    
    // Add item was detected but creation failed or callback not provided
    return AddItemResult<T>(handled: true);
  }
}

