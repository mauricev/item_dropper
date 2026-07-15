import 'item_dropper_localizations.dart';

/// Helper methods for working with accessibility strings.
///
/// Uses [ItemDropperLocalizations] to build formatted labels for Semantics
/// widgets and live-region announcements used throughout the package.
class ItemDropperSemantics {
  // Re-export constants for convenience
  static final String singleSelectFieldLabel =
      ItemDropperLocalizations.english.singleSelectFieldLabel;
  static final String multiSelectFieldLabel =
      ItemDropperLocalizations.english.multiSelectFieldLabel;
  static final String selectedSuffix =
      ItemDropperLocalizations.english.selectedSuffix;
  static final String addItemPrefix =
      ItemDropperLocalizations.english.addItemPrefix;
  static final String addItemSuffix =
      ItemDropperLocalizations.english.addItemSuffix;

  // Helper methods for common patterns

  /// Creates a full "add item" label for the given search text.
  ///
  /// Example: formatAddItemLabel('Orange') → 'Add "Orange"'
  static String formatAddItemLabel(
    String searchText, {
    ItemDropperLocalizations? localizations,
  }) {
    final loc = localizations ?? ItemDropperLocalizations.english;
    return '${loc.addItemPrefix}$searchText${loc.addItemSuffix}';
  }

  /// Creates a selected chip label for the given item label.
  ///
  /// Example: formatSelectedChipLabel('Apple') → 'Apple, selected'
  static String formatSelectedChipLabel(
    String itemLabel, {
    ItemDropperLocalizations? localizations,
  }) {
    final loc = localizations ?? ItemDropperLocalizations.english;
    return '$itemLabel${loc.selectedSuffix}';
  }

  /// Checks if a label matches the "add item" pattern.
  ///
  /// Example: isAddItemLabel('Add "Orange"') → true
  /// Example: isAddItemLabel('Orange') → false
  static bool isAddItemLabel(
    String label, {
    ItemDropperLocalizations? localizations,
  }) {
    final loc = localizations ?? ItemDropperLocalizations.english;
    return label.startsWith(loc.addItemPrefix) &&
        label.endsWith(loc.addItemSuffix);
  }

  /// Extracts search text from an "add item" label.
  ///
  /// Example: extractSearchText('Add "Orange"') → 'Orange'
  /// Returns empty string if label doesn't match pattern.
  static String extractSearchTextFromAddItemLabel(
    String label, {
    ItemDropperLocalizations? localizations,
  }) {
    final loc = localizations ?? ItemDropperLocalizations.english;
    if (!isAddItemLabel(label, localizations: loc)) {
      return '';
    }
    // Remove 'Add "' prefix and '"' suffix
    return label.substring(
      loc.addItemPrefix.length,
      label.length - loc.addItemSuffix.length,
    );
  }

  // Live region announcements

  /// Creates announcement for item selection.
  ///
  /// Example: announceItemSelected('Apple') → 'Apple selected'
  static String announceItemSelected(
    String itemLabel, {
    ItemDropperLocalizations? localizations,
  }) {
    final loc = localizations ?? ItemDropperLocalizations.english;
    return '$itemLabel${loc.itemSelectedSuffix}';
  }

  /// Creates announcement for item removal.
  ///
  /// Example: announceItemRemoved('Apple') → 'Apple removed'
  static String announceItemRemoved(
    String itemLabel, {
    ItemDropperLocalizations? localizations,
  }) {
    final loc = localizations ?? ItemDropperLocalizations.english;
    return '$itemLabel${loc.itemRemovedSuffix}';
  }

  /// Creates announcement for maximum selection reached.
  ///
  /// Example: announceMaxSelectionReached(5) → 'Maximum 5 items selected'
  static String announceMaxSelectionReached(
    int maxCount, {
    ItemDropperLocalizations? localizations,
  }) {
    final loc = localizations ?? ItemDropperLocalizations.english;
    return '${loc.maxSelectionReachedPrefix}$maxCount${loc.maxSelectionReachedSuffix}';
  }

  /// Announcement for dropdown closed.
  static String announceDropdownClosed({
    ItemDropperLocalizations? localizations,
  }) {
    final loc = localizations ?? ItemDropperLocalizations.english;
    return loc.dropdownClosed;
  }
}
