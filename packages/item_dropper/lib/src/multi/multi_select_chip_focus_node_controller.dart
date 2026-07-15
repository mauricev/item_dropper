import 'package:flutter/widgets.dart';

/// Owns the FocusNodes used by selected-item chips.
class MultiSelectChipFocusNodeController {
  final Map<int, FocusNode> _nodesByIndex = {};

  int get count => _nodesByIndex.length;

  bool containsIndex(int index) => _nodesByIndex.containsKey(index);

  FocusNode nodeForIndex(int index, {required bool enabled}) {
    final node = _nodesByIndex.putIfAbsent(
      index,
      () => FocusNode(skipTraversal: false, canRequestFocus: enabled),
    );

    if (node.canRequestFocus != enabled) {
      node.canRequestFocus = enabled;
    }

    return node;
  }

  void retainIndices(Iterable<int> indices) {
    final retainedIndices = indices.toSet();
    final removedIndices = _nodesByIndex.keys
        .where((index) => !retainedIndices.contains(index))
        .toList();

    for (final index in removedIndices) {
      _nodesByIndex.remove(index)?.dispose();
    }
  }

  void dispose() {
    for (final node in _nodesByIndex.values) {
      node.dispose();
    }
    _nodesByIndex.clear();
  }
}
