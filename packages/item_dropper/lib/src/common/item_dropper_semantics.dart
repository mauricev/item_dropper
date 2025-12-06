import 'semantics_consts.dart';

/// Helper methods for working with accessibility strings.
///
/// Uses constants from [SemanticsConsts] to build formatted labels
/// for Semantics widgets used throughout the item_dropper package.
class ItemDropperSemantics {
  // Re-export constants for convenience
  static const String singleSelectFieldLabel =
      SemanticsConsts.singleSelectFieldLabel;
  static const String multiSelectFieldLabel =
      SemanticsConsts.multiSelectFieldLabel;
  static const String selectedSuffix = SemanticsConsts.selectedSuffix;
  static const String addItemPrefix = SemanticsConsts.addItemPrefix;
  static const String addItemSuffix = SemanticsConsts.addItemSuffix;

  // Helper methods for common patterns

  /// Creates a full "add item" label for the given search text.
  /// 
  /// Example: formatAddItemLabel('Orange') → 'Add "Orange"'
  static String formatAddItemLabel(String searchText) {
    return '${SemanticsConsts.addItemPrefix}$searchText${SemanticsConsts.addItemSuffix}';
  }

  /// Creates a selected chip label for the given item label.
  ///
  /// Example: formatSelectedChipLabel('Apple') → 'Apple, selected'
  static String formatSelectedChipLabel(String itemLabel) {
    return '$itemLabel${SemanticsConsts.selectedSuffix}';
  }

  /// Checks if a label matches the "add item" pattern.
  ///
  /// Example: isAddItemLabel('Add "Orange"') → true
  /// Example: isAddItemLabel('Orange') → false
  static bool isAddItemLabel(String label) {
    return label.startsWith(SemanticsConsts.addItemPrefix) &&
        label.endsWith(SemanticsConsts.addItemSuffix);
  }

  /// Extracts search text from an "add item" label.
  ///
  /// Example: extractSearchText('Add "Orange"') → 'Orange'
  /// Returns empty string if label doesn't match pattern.
  static String extractSearchTextFromAddItemLabel(String label) {
    if (!isAddItemLabel(label)) {
      return '';
    }
    // Remove 'Add "' prefix and '"' suffix
    return label.substring(
      SemanticsConsts.addItemPrefix.length,
      label.length - SemanticsConsts.addItemSuffix.length,
    );
  }

  // Live region announcements

  /// Creates announcement for item selection.
  ///
  /// Example: announceItemSelected('Apple') → 'Apple selected'
  static String announceItemSelected(String itemLabel) {
    return '$itemLabel${SemanticsConsts.itemSelectedSuffix}';
  }

  /// Creates announcement for item removal.
  ///
  /// Example: announceItemRemoved('Apple') → 'Apple removed'
  static String announceItemRemoved(String itemLabel) {
    return '$itemLabel${SemanticsConsts.itemRemovedSuffix}';
  }

  /// Creates announcement for maximum selection reached.
  ///
  /// Example: announceMaxSelectionReached(5) → 'Maximum 5 items selected'
  static String announceMaxSelectionReached(int maxCount) {
    return '${SemanticsConsts.maxSelectionReachedPrefix}$maxCount${SemanticsConsts.maxSelectionReachedSuffix}';
  }

  /// Announcement for dropdown closed.
  static String get announceDropdownClosed => SemanticsConsts.dropdownClosed;
}
