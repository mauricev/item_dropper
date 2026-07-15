import 'package:flutter/foundation.dart';

typedef RebuildInvoker = void Function(VoidCallback update);

/// Coalesces rebuild requests without dropping updates requested during an
/// active rebuild callback.
class RebuildScheduler {
  bool _isRebuilding = false;
  final List<VoidCallback> _pendingUpdates = [];

  bool get isRebuilding => _isRebuilding;

  void request({
    required bool mounted,
    required RebuildInvoker rebuild,
    VoidCallback? update,
  }) {
    if (!mounted) {
      return;
    }

    if (_isRebuilding) {
      if (update != null) {
        _pendingUpdates.add(update);
      }
      return;
    }

    _isRebuilding = true;
    try {
      rebuild(() {
        update?.call();

        while (_pendingUpdates.isNotEmpty) {
          final pendingUpdate = _pendingUpdates.removeAt(0);
          pendingUpdate();
        }
      });
    } finally {
      _isRebuilding = false;
    }
  }
}
