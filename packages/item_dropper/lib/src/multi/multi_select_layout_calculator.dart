/// Helper class for calculating layout dimensions in multi-select dropdown
class MultiSelectLayoutCalculator {
  /// Calculate TextField width based on available space and chip measurements
  static double calculateTextFieldWidth({
    required double availableWidth,
    required int selectedCount,
    required double chipSpacing,
    required double? totalChipWidth,
  }) {
    if (selectedCount == 0) {
      return availableWidth;
    }

    // Use measured chip widths - no estimates, no fallbacks
    final double? measuredTotalChipWidth = totalChipWidth;
    if (measuredTotalChipWidth == null) {
      return 0.0; // No measurement yet - don't render
    }

    // Calculate spacing:
    // - Between chips: (chipCount - 1) * spacing
    // - Between last chip and TextField: 1 * spacing (ALWAYS needed if we have chips)
    final double spacingBetweenChips = (selectedCount - 1) * chipSpacing;
    final double spacingBeforeTextField =
        chipSpacing; // Always need spacing before TextField if chips exist
    final double totalSpacing = spacingBetweenChips + spacingBeforeTextField;

    final double usedWidth = measuredTotalChipWidth + totalSpacing;
    final double remainingWidth = availableWidth - usedWidth;
    final double textFieldWidth = remainingWidth.clamp(100.0, availableWidth);

    return textFieldWidth;
  }

  /// Calculate TextField height to match chip height
  static double calculateTextFieldHeight({
    required double? fontSize,
    required double chipVerticalPadding,
  }) {
    // Calculate height to match chip: max(textLineHeight, 24px icon) + 12px padding
    // This matches the chip structure exactly
    final double textSize = fontSize ?? 10.0;
    final double textLineHeight = textSize * 1.2;
    const double iconHeight = 24.0;
    final double rowContentHeight = textLineHeight > iconHeight
        ? textLineHeight
        : iconHeight;
    final double verticalPadding =
        chipVerticalPadding * 2; // 6px top + 6px bottom = 12px
    return rowContentHeight + verticalPadding;
  }
}
