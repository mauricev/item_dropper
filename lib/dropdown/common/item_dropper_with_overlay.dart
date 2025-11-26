import 'package:flutter/material.dart';
import '../common/item_dropper_constants.dart';

/// Shared widget that wraps dropdown input fields with overlay functionality
class ItemDropperWithOverlay extends StatelessWidget {
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
  Widget build(BuildContext context) {
    return CompositedTransformTarget(
      link: layerLink,
      child: OverlayPortal(
        controller: overlayController,
        overlayChildBuilder: (context) =>
            Stack(
              children: [
                // Dismiss dropdown when clicking outside the text field
                Positioned.fill(
                  child: Listener(
                    behavior: HitTestBehavior.translucent,
                    onPointerDown: (event) {
                      // Use the field's render box for dismissal detection
                      final RenderBox? renderBox =
                      fieldKey.currentContext?.findRenderObject() as RenderBox?;
                      if (renderBox != null) {
                        final Offset offset = renderBox.localToGlobal(
                            Offset.zero);
                        final Size size = renderBox.size;
                        final Rect fieldRect = offset & size;
                        if (!fieldRect.contains(event.position)) {
                          onDismiss();
                        }
                      }
                    },
                  ),
                ),
                CompositedTransformFollower(
                  link: layerLink,
                  showWhenUnlinked: false,
                  offset: const Offset(0.0, 0.0), // Position relative to target
                  child: overlay,
                ),
              ],
            ),
        child: inputField,
      ),
    );
  }
}