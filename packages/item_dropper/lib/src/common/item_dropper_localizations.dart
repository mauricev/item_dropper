/// Localization strings for item_dropper widgets.
///
/// Provides all user-facing text that can be translated.
/// Pass an instance of this class to [SingleItemDropper] or [MultiItemDropper]
/// to customize the displayed text.
class ItemDropperLocalizations {
  /// Text for the "Add" item prefix (e.g., "Add" in "Add \"Orange\"")
  final String addItemPrefix;

  /// Text for the "Add" item suffix (e.g., "\"" in "Add \"Orange\"")
  final String addItemSuffix;

  /// Message shown when no search results are found
  final String noResultsFound;

  /// Message shown when maximum selection limit is reached (multi-select)
  final String maxSelectionReached;

  /// Title for delete confirmation dialog (e.g., "Delete \"Apple\"?")
  /// Use "{label}" as a placeholder for the item label
  final String deleteDialogTitle;

  /// Content text for delete confirmation dialog
  final String deleteDialogContent;

  /// Cancel button text in delete dialog
  final String deleteDialogCancel;

  /// Delete button text in delete dialog
  final String deleteDialogDelete;

  /// Screen reader label for single-select search field
  final String singleSelectFieldLabel;

  /// Screen reader label for multi-select search field
  final String multiSelectFieldLabel;

  /// Suffix for selected chip labels (e.g., ", selected")
  final String selectedSuffix;

  /// Suffix for item selected announcement (e.g., " selected")
  final String itemSelectedSuffix;

  /// Suffix for item removed announcement (e.g., " removed")
  final String itemRemovedSuffix;

  /// Prefix for max selection reached announcement (e.g., "Maximum ")
  final String maxSelectionReachedPrefix;

  /// Suffix for max selection reached announcement (e.g., " items selected")
  final String maxSelectionReachedSuffix;

  /// Announcement when dropdown closes
  final String dropdownClosed;

  /// Message shown in overlay when maximum allowed items is reached (multi-select)
  final String maxItemsReachedOverlay;

  const ItemDropperLocalizations({
    this.addItemPrefix = 'Add "',
    this.addItemSuffix = '"',
    this.noResultsFound = 'No results found',
    this.maxSelectionReached = 'Reached maximum allowed items',
    this.deleteDialogTitle = 'Delete "{label}"?',
    this.deleteDialogContent = 'This will remove the item from the list.',
    this.deleteDialogCancel = 'Cancel',
    this.deleteDialogDelete = 'Delete',
    this.singleSelectFieldLabel = 'Search dropdown',
    this.multiSelectFieldLabel = 'Search and add items',
    this.selectedSuffix = ', selected',
    this.itemSelectedSuffix = ' selected',
    this.itemRemovedSuffix = ' removed',
    this.maxSelectionReachedPrefix = 'Maximum ',
    this.maxSelectionReachedSuffix = ' items selected',
    this.dropdownClosed = 'Dropdown closed',
    this.maxItemsReachedOverlay = 'Reached maximum allowed items',
  });

  /// Default English localizations
  static const ItemDropperLocalizations english = ItemDropperLocalizations();
}
