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

  @override
  Widget build(BuildContext context) {
    return CompositedTransformTarget(
      link: widget.layerLink,
      child: OverlayPortal(
        controller: widget.overlayController,
        overlayChildBuilder: (context) =>
            Stack(
              children: [
                // Dismiss dropdown when clicking outside the text field AND outside the overlay
                // Defer dismiss check to allow child widgets (like InkWell) to handle taps first
                Positioned.fill(
                  child: Listener(
                    behavior: HitTestBehavior.translucent,
                    onPointerDown: (event) {
                      // Use the field's render box for dismissal detection
                      final RenderBox? renderBox =
                      widget.fieldKey.currentContext?.findRenderObject() as RenderBox?;
                      if (renderBox != null) {
                        final Offset fieldOffset = renderBox.localToGlobal(Offset.zero);
                        final Size fieldSize = renderBox.size;
                        final Rect fieldRect = fieldOffset & fieldSize;
                        final bool isOutsideField = !fieldRect.contains(event.position);
                        
                        // DEBUG: Track dismiss detection
                        debugPrint("DEBUG: Overlay click detected - isOutsideField=$isOutsideField, position=${event.position}, fieldRect=$fieldRect");
                        
                        if (isOutsideField) {
                          // FIX: Defer dismiss check to allow overlay items to handle taps first
                          // If an overlay item handles the tap, we shouldn't dismiss
                          WidgetsBinding.instance.addPostFrameCallback((_) {
                            // Check if overlay is still showing - if an item was tapped, it might have been handled
                            // Also check overlay bounds to be sure
                            final RenderBox? overlayRenderBox = 
                                _overlayKey.currentContext?.findRenderObject() as RenderBox?;
                            
                            debugPrint("DEBUG: Deferred dismiss check - overlayRenderBox=${overlayRenderBox != null}, overlayShowing=${widget.overlayController.isShowing}");
                            
                            if (overlayRenderBox != null) {
                              final Offset overlayOffset = overlayRenderBox.localToGlobal(Offset.zero);
                              final Size overlaySize = overlayRenderBox.size;
                              final Rect overlayRect = overlayOffset & overlaySize;
                              
                              debugPrint("DEBUG: Overlay bounds - offset=$overlayOffset, size=$overlaySize, rect=$overlayRect, clickPosition=${event.position}");
                              
                              if (overlayRect.contains(event.position)) {
                                debugPrint("DEBUG: Click is on overlay - NOT dismissing (blue border stays)");
                                return; // Don't dismiss - click is on overlay
                              }
                            }
                            
                            // If overlay is still showing after the tap, it means the tap wasn't handled by an item
                            // But we should still check bounds first (above)
                            debugPrint("DEBUG: Calling onDismiss() - THIS WILL CAUSE UNFOCUS (blue border disappears)");
                            widget.onDismiss();
                          });
                        }
                      }
                    },
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