/// Shared UI constants for dropdown components
class ItemDropperConstants {
  // Layout constants
  static const double kDropdownItemHeight = 30.0;
  static const double kDropdownMargin = 4.0;
  static const double kDropdownElevation = 4.0;
  static const double kDropdownFontSize = 12.0;
  static const double kDropdownMaxHeightDivisor = 2.0;
  static const double kSelectedItemBackgroundAlpha = 0.12;
  static const int kNoHighlight = -1;

  // Scroll constants
  static const double kDefaultFallbackItemPadding = 16.0;
  static const double kFallbackItemTextMultiplier = 1.2;
  static const int kMaxScrollRetries = 10;
  static const Duration kScrollAnimationDuration = Duration(milliseconds: 200);
  static const Duration kScrollDebounceDelay = Duration(milliseconds: 150);
  static const double kCenteringDivisor = 2.0;
}