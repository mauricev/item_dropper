/// Constants for accessibility labels used in Semantics widgets.
/// 
/// These strings are announced by screen readers to help users
/// with visual impairments understand and navigate the UI.
class SemanticsConsts {
  // TextField labels

  /// Label for single-select search field.
  /// Screen reader announces: "Search dropdown, text field"
  static const String singleSelectFieldLabel = 'Search dropdown';

  /// Label for multi-select search field.
  /// Screen reader announces: "Search and add items, text field"
  static const String multiSelectFieldLabel = 'Search and add items';

  // Chip labels

  /// Suffix appended to chip labels.
  /// Example: "Apple" + ", selected" = "Apple, selected"
  static const String selectedSuffix = ', selected';

  // Add item labels

  /// Prefix for "add item" labels.
  /// Example: 'Add "' + "Orange" + '"' = 'Add "Orange"'
  static const String addItemPrefix = 'Add "';

  /// Suffix for "add item" labels.
  static const String addItemSuffix = '"';
}
