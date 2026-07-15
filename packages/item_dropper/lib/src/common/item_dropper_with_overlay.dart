import 'package:flutter/material.dart';

/// Shared widget that wraps dropdown input fields with overlay functionality
class ItemDropperWithOverlay extends StatefulWidget {
  final LayerLink layerLink;
  final OverlayPortalController overlayController;
  final GlobalKey fieldKey;
  final Widget inputField;
  final Widget overlay;
  final VoidCallback onDismiss;

  const ItemDropperWithOverlay({
    super.key,
    required this.layerLink,
    required this.overlayController,
    required this.fieldKey,
    required this.inputField,
    required this.overlay,
    required this.onDismiss,
  });

  @override
  State<ItemDropperWithOverlay> createState() => _ItemDropperWithOverlayState();
}

class _ItemDropperWithOverlayState extends State<ItemDropperWithOverlay> {
  /// Check if a pointer event occurred outside the field bounds
  bool _isClickOutsideField(PointerDownEvent event) {
    final RenderBox? renderBox =
        widget.fieldKey.currentContext?.findRenderObject() as RenderBox?;

    if (renderBox == null) return false;

    final Offset fieldOffset = renderBox.localToGlobal(Offset.zero);
    final Size fieldSize = renderBox.size;
    final Rect fieldRect = fieldOffset & fieldSize;

    return !fieldRect.contains(event.position);
  }

  /// Handle pointer down events for dismissal logic
  void _handlePointerDown(PointerDownEvent event) {
    // Current behavior dismisses for any overlay-portal click outside the field.
    if (_isClickOutsideField(event)) {
      widget.onDismiss();
      return;
    }
  }

  @override
  Widget build(BuildContext context) {
    return CompositedTransformTarget(
      link: widget.layerLink,
      child: OverlayPortal(
        controller: widget.overlayController,
        overlayChildBuilder: (context) => Stack(
          children: [
            // Listener uses translucent behavior to allow child widgets to handle taps first
            Positioned.fill(
              child: Listener(
                behavior: HitTestBehavior.translucent,
                onPointerDown: _handlePointerDown,
              ),
            ),
            CompositedTransformFollower(
              link: widget.layerLink,
              showWhenUnlinked: false,
              offset: const Offset(0.0, 0.0), // Position relative to target
              child: widget.overlay,
            ),
          ],
        ),
        child: widget.inputField,
      ),
    );
  }
}
