import '../common/item_dropper_item.dart';

/// Utility functions for comparing and handling ItemDropperItem lists
class ItemDropperItemsUtils {
  /// Threshold retained for compatibility with existing performance docs.
  static const int kListComparisonThreshold = 10;

  /// Finds [item] while preserving duplicate-instance position when possible.
  ///
  /// Identity is preferred because two rows may intentionally share a value.
  /// A value-and-role fallback supports equivalent items reconstructed by a
  /// filtering or mapping step without confusing normal rows, group headers,
  /// and add-item sentinels that reuse the same value.
  static int findItemIndex<T>(
    List<ItemDropperItem<T>> items,
    ItemDropperItem<T> item,
  ) {
    final identityIndex = items.indexWhere(
      (candidate) => identical(candidate, item),
    );
    if (identityIndex >= 0) {
      return identityIndex;
    }

    return items.indexWhere(
      (candidate) =>
          candidate.value == item.value &&
          candidate.isAddItem == item.isAddItem &&
          candidate.isGroupHeader == item.isGroupHeader,
    );
  }

  /// Check if two item lists are equal (by value)
  ///
  /// Optimized for performance: early returns and efficient Set-based comparison
  /// Time complexity: O(n) where n is the length of the lists
  ///
  /// Returns true if both lists contain the same items (by value), false otherwise.
  /// Handles null lists (treats null as empty list).
  static bool areItemsEqual<T>(
    List<ItemDropperItem<T>>? a,
    List<ItemDropperItem<T>> b,
  ) {
    // Handle null
    if (a == null) return b.isEmpty;

    // Fast path: reference equality
    if (identical(a, b)) return true;

    // Fast path: length check (O(1))
    if (a.length != b.length) return false;

    // Fast path: empty lists
    if (a.isEmpty) return true;

    final valueCounts = <T, int>{};

    for (final item in a) {
      valueCounts[item.value] = (valueCounts[item.value] ?? 0) + 1;
    }

    for (final item in b) {
      final count = valueCounts[item.value];
      if (count == null) {
        return false;
      }

      if (count == 1) {
        valueCounts.remove(item.value);
      } else {
        valueCounts[item.value] = count - 1;
      }
    }

    return valueCounts.isEmpty;
  }

  /// Check if items list has changed between old and new widget
  ///
  /// Uses fast path checks (reference equality, length) before doing
  /// expensive deep comparison.
  ///
  /// Returns true if items have changed, false otherwise.
  static bool hasItemsChanged<T>(
    List<ItemDropperItem<T>> oldItems,
    List<ItemDropperItem<T>> newItems,
  ) {
    // Fast path: check reference equality first (O(1))
    if (identical(newItems, oldItems)) return false;

    // Fast path: check length (O(1))
    if (newItems.length != oldItems.length) return true;

    // Only do expensive comparison if reference changed but length is same
    return !areItemsEqual(newItems, oldItems);
  }
}
