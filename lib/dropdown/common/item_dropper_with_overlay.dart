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
                      debugPrint("DEBUG LAST ITEM: Listener onPointerDown received at ${event.position} - this is the dismiss handler");
                      debugPrint("DEBUG: Listener is intercepting event - HitTestBehavior.translucent should allow events to pass through");
                      debugPrint("DEBUG: Event details - kind=${event.kind}, buttons=${event.buttons}, position=${event.position}");
                      debugPrint("DEBUG: WARNING - Listener is receiving event BEFORE items. This may prevent items from receiving events.");
                      debugPrint("DEBUG: Stack order: Listener (Positioned.fill) is FIRST, CompositedTransformFollower (overlay) is SECOND");
                      debugPrint("DEBUG: In Stack, LAST child is on top, so overlay should be on top, but Listener may still intercept");
                      debugPrint("DEBUG: CRITICAL - Listener.onPointerDown is being called, which means it's in the hit test path");
                      debugPrint("DEBUG: Even with HitTestBehavior.translucent, handling onPointerDown may prevent children from receiving events");
                      debugPrint("DEBUG: The event should propagate to children AFTER this handler, but we're not seeing MouseRegion/InkWell events");
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
                          debugPrint("DEBUG: Click is outside field - deferring dismiss check to allow items to handle tap first");
                          // FIX: Defer dismiss check to allow overlay items to handle taps first
                          // If an overlay item handles the tap, we shouldn't dismiss
                          WidgetsBinding.instance.addPostFrameCallback((_) {
                            debugPrint("DEBUG: PostFrameCallback executing - checking if items handled the tap");
                            // Check if overlay is still showing - if an item was tapped, it might have been handled
                            // Also check overlay bounds to be sure
                            final RenderBox? overlayRenderBox = 
                                _overlayKey.currentContext?.findRenderObject() as RenderBox?;
                            
                            debugPrint("DEBUG: Deferred dismiss check - overlayRenderBox=${overlayRenderBox != null}, overlayShowing=${widget.overlayController.isShowing}");
                            
                            if (overlayRenderBox != null) {
                              final Size overlaySize = overlayRenderBox.size;
                              
                              // CompositedTransformFollower uses LayerLink coordinate system
                              // localToGlobal(Offset.zero) doesn't work correctly for RenderFollowerLayer
                              // We need to get the field position and add the field height
                              final RenderBox? fieldRenderBox = widget.fieldKey.currentContext?.findRenderObject() as RenderBox?;
                              
                              if (fieldRenderBox != null) {
                                final Offset fieldGlobalPos = fieldRenderBox.localToGlobal(Offset.zero);
                                final double fieldHeight = fieldRenderBox.size.height;
                                final Offset estimatedOverlayPos = Offset(fieldGlobalPos.dx, fieldGlobalPos.dy + fieldHeight);
                                final Rect estimatedOverlayRect = estimatedOverlayPos & overlaySize;
                                
                                debugPrint("DEBUG: Coordinate system check:");
                                debugPrint("DEBUG:   fieldGlobalPos=$fieldGlobalPos");
                                debugPrint("DEBUG:   fieldHeight=$fieldHeight");
                                debugPrint("DEBUG:   estimatedOverlayPos=$estimatedOverlayPos");
                                debugPrint("DEBUG:   overlaySize=$overlaySize");
                                debugPrint("DEBUG:   estimatedOverlayRect=$estimatedOverlayRect");
                                debugPrint("DEBUG:   event.position=${event.position}");
                                debugPrint("DEBUG:   estimatedOverlayRect.contains(event.position)=${estimatedOverlayRect.contains(event.position)}");
                                
                                // Also try the direct coordinate check (even though it might not work)
                                final Offset overlayOffset = overlayRenderBox.localToGlobal(Offset.zero);
                                final Offset clickInOverlayLocal = overlayRenderBox.globalToLocal(event.position);
                                debugPrint("DEBUG:   overlayOffset (localToGlobal)=$overlayOffset");
                                debugPrint("DEBUG:   clickInOverlayLocal (globalToLocal)=$clickInOverlayLocal");
                                debugPrint("DEBUG:   WARNING: If globalToLocal returns same as global, coordinate system issue");
                                
                                // Check if click is within overlay bounds using estimated position
                                if (estimatedOverlayRect.contains(event.position)) {
                                  debugPrint("DEBUG: Click IS on overlay (using estimated position) - NOT dismissing");
                                  return; // Don't dismiss - click is on overlay
                                } else {
                                  debugPrint("DEBUG: Click is NOT on overlay (using estimated position) - will dismiss");
                                }
                              } else {
                                debugPrint("DEBUG: fieldRenderBox is null - cannot check overlay bounds");
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