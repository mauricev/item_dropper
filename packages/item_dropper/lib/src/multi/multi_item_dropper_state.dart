part of '../../item_dropper_multi_select.dart';

// State management and helper methods
extension _MultiItemDropperStateHelpers<T> on _MultiItemDropperState<T> {
  void _clearHighlights() {
    _keyboardNavManager.clearHighlights();
  }
}

