import 'dart:async';
import 'package:flutter/material.dart';

/// Manages live region announcements for screen readers.
/// 
/// Live regions allow screen readers to announce messages without requiring
/// user navigation. This is useful for providing confirmation feedback when
/// actions complete (e.g., "Apple selected", "Maximum 5 items reached").
/// 
/// Messages are automatically cleared after 1 second to prevent stale
/// announcements from being read later.
class LiveRegionManager {
  String? _message;
  Timer? _clearTimer;

  /// Callback invoked when the message changes, triggering a rebuild.
  final VoidCallback onUpdate;

  /// Creates a [LiveRegionManager].
  /// 
  /// [onUpdate] is called when a message is announced or cleared, allowing
  /// the parent widget to rebuild and show/hide the live region.
  LiveRegionManager({required this.onUpdate});

  /// Announces a message to screen readers.
  /// 
  /// The message will be read immediately by VoiceOver/TalkBack and
  /// automatically cleared after 1 second.
  /// 
  /// Example:
  /// ```dart
  /// liveRegionManager.announce('Apple selected');
  /// ```
  void announce(String message) {
    _message = message;
    onUpdate(); // Trigger rebuild to show message

    // Clear message after 1 second
    _clearTimer?.cancel();
    _clearTimer = Timer(const Duration(seconds: 1), () {
      _message = null;
      onUpdate(); // Trigger rebuild to hide message
    });
  }

  /// Builds the live region widget.
  /// 
  /// Returns a [Semantics] widget with `liveRegion: true` when there's a
  /// message to announce, or an empty widget when there's no message.
  /// 
  /// The text is styled with fontSize: 0 and height: 0 to make it invisible
  /// while still being announced by screen readers.
  Widget build() {
    if (_message == null) {
      return const SizedBox.shrink();
    }

    return Semantics(
      liveRegion: true,
      child: Text(
        _message!,
        style: const TextStyle(fontSize: 0, height: 0),
      ),
    );
  }

  /// Disposes the manager and cancels any pending timers.
  /// 
  /// Should be called in the parent widget's dispose method.
  void dispose() {
    _clearTimer?.cancel();
  }
}
