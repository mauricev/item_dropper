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
  // GlobalKey to track overlay bounds for dismiss detection
  final GlobalKey _overlayKey = GlobalKey();

  /// Check if a pointer event occurred within the overlay bounds
  bool _isClickOnOverlay(PointerDownEvent event) {
    final RenderBox? overlayRenderBox =
        _overlayKey.currentContext?.findRenderObject() as RenderBox?;

    if (overlayRenderBox == null) return false;

    final RenderBox? fieldRenderBox =
        widget.fieldKey.currentContext?.findRenderObject() as RenderBox?;

    if (fieldRenderBox == null) return false;

    final Offset fieldGlobalPos = fieldRenderBox.localToGlobal(Offset.zero);
    final double fieldHeight = fieldRenderBox.size.height;
    final Offset estimatedOverlayPos = Offset(
      fieldGlobalPos.dx,
      fieldGlobalPos.dy + fieldHeight,
    );
    final Size overlaySize = overlayRenderBox.size;
    final Rect estimatedOverlayRect = estimatedOverlayPos & overlaySize;

    return estimatedOverlayRect.contains(event.position);
  }

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
    // Check if click is on overlay first - dismiss after item interaction
    if (_isClickOnOverlay(event)) {
      widget.onDismiss();
      return;
    }

    // Check if click is outside the field - dismiss immediately
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
            // Dismiss dropdown when clicking outside the text field AND outside the overlay
            // Listener uses translucent behavior to allow child widgets to handle taps first
            Positioned.fill(
              child: Listener(
                behavior: HitTestBehavior.translucent,
                onPointerDown: _handlePointerDown,
              ),
            ),
            CompositedTransformFollower(
              key: _overlayKey,
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
