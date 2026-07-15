import 'package:item_dropper/src/common/item_dropper_common.dart';

class MultiSelectHighlightPolicyResult {
  final bool clearHighlights;
  final int? hoverIndex;
  final bool hideOverlay;

  const MultiSelectHighlightPolicyResult({
    required this.clearHighlights,
    required this.hoverIndex,
    required this.hideOverlay,
  });
}

/// Determines how highlight state should be retained after selection changes.
class MultiSelectHighlightPolicy {
  const MultiSelectHighlightPolicy();

  MultiSelectHighlightPolicyResult afterSelectionChange({
    required bool wasKeyboardActive,
    required int previousHoverIndex,
    required int remainingFilteredItemCount,
  }) {
    if (remainingFilteredItemCount == 0) {
      return const MultiSelectHighlightPolicyResult(
        clearHighlights: true,
        hoverIndex: null,
        hideOverlay: true,
      );
    }

    if (wasKeyboardActive) {
      return const MultiSelectHighlightPolicyResult(
        clearHighlights: true,
        hoverIndex: null,
        hideOverlay: false,
      );
    }

    if (previousHoverIndex >= 0 &&
        previousHoverIndex < remainingFilteredItemCount) {
      return MultiSelectHighlightPolicyResult(
        clearHighlights: false,
        hoverIndex: previousHoverIndex,
        hideOverlay: false,
      );
    }

    return const MultiSelectHighlightPolicyResult(
      clearHighlights: true,
      hoverIndex: null,
      hideOverlay: false,
    );
  }

  bool isKeyboardActive(int keyboardHighlightIndex) {
    return keyboardHighlightIndex != ItemDropperConstants.kNoHighlight;
  }
}
