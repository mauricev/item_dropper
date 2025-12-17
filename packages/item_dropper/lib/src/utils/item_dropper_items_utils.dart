import '../common/item_dropper_item.dart';

/// Utility functions for comparing and handling ItemDropperItem lists
class ItemDropperItemsUtils {
  /// Threshold for using simple iteration vs Set-based comparison
  /// For small lists, simple iteration is more cache-friendly
  static const int kListComparisonThreshold = 10;

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

    // For small lists, use simple iteration (more cache-friendly)
    if (a.length <= kListComparisonThreshold) {
      final Set<T> bValues = b.map((item) => item.value).toSet();
      return a.every((item) => bValues.contains(item.value));
    }

    // For larger lists, use Set-based comparison
    final Set<T> aValues = a.map((item) => item.value).toSet();
    final Set<T> bValues = b.map((item) => item.value).toSet();

    // If lengths are equal and all a values are in b, then all b values must be in a
    // (since Set length equals list length when there are no duplicates)
    return aValues.length == bValues.length &&
        aValues.every((value) => bValues.contains(value));
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

