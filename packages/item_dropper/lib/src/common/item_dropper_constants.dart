/// Shared UI constants for dropdown components
class ItemDropperConstants {
  // Layout constants
  static const double kDropdownItemHeight = 30.0;
  static const double kDropdownMargin = 4.0;
  static const double kDropdownElevation = 4.0;
  static const double kDropdownFontSize = 12.0;
  static const double kSelectedItemBackgroundAlpha = 0.12;
  static const int kNoHighlight = -1;

  // Scroll constants
  static const double kDefaultFallbackItemPadding = 16.0;
  static const double kFallbackItemTextMultiplier = 1.2;
  static const int kMaxScrollRetries = 10;
  static const Duration kScrollAnimationDuration = Duration(milliseconds: 200);
  static const Duration kScrollDebounceDelay = Duration(milliseconds: 150);
  static const double kCenteringDivisor = 2.0;

  // Dropdown item styling constants
  static const double kDropdownItemFontSize = 10.0;
  static const double kDropdownItemHorizontalPadding = 12.0;
  static const double kDropdownItemVerticalPadding = 8.0;
  static const double kDropdownGroupHeaderVerticalPadding = 6.0;
  static const int kDropdownGroupHeaderAlpha = 200;
  static const double kDropdownSeparatorWidth = 1.0;
  static const double kDropdownDeleteIconSize = 16.0;
  static const double kDropdownTextToDeleteIconSpacing = 8.0;
}