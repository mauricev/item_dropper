import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';

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
                      // CRITICAL FIX: Check if click is on overlay FIRST, before doing anything else
                      // If it's on the overlay, return early to allow event to propagate to items
                      final RenderBox? overlayRenderBox = 
                          _overlayKey.currentContext?.findRenderObject() as RenderBox?;
                      
                      if (overlayRenderBox != null) {
                        final RenderBox? fieldRenderBox = widget.fieldKey.currentContext?.findRenderObject() as RenderBox?;
                        if (fieldRenderBox != null) {
                          final Offset fieldGlobalPos = fieldRenderBox.localToGlobal(Offset.zero);
                          final double fieldHeight = fieldRenderBox.size.height;
                          final Offset estimatedOverlayPos = Offset(fieldGlobalPos.dx, fieldGlobalPos.dy + fieldHeight);
                          final Size overlaySize = overlayRenderBox.size;
                          final Rect estimatedOverlayRect = estimatedOverlayPos & overlaySize;
                          
                          // If click is on overlay, return early to allow event to propagate to items
                          if (estimatedOverlayRect.contains(event.position)) {
                            return; // Don't handle - let items receive the event
                          }
                        }
                      }
                      // Use the field's render box for dismissal detection
                      final RenderBox? renderBox =
                      widget.fieldKey.currentContext?.findRenderObject() as RenderBox?;
                      if (renderBox != null) {
                        final Offset fieldOffset = renderBox.localToGlobal(Offset.zero);
                        final Size fieldSize = renderBox.size;
                        final Rect fieldRect = fieldOffset & fieldSize;
                        final bool isOutsideField = !fieldRect.contains(event.position);
                        
                        if (isOutsideField) {
                          // FIX: Defer dismiss check to allow overlay items to handle taps first
                          // If an overlay item handles the tap, we shouldn't dismiss
                          WidgetsBinding.instance.addPostFrameCallback((_) {
                            // Check if overlay is still showing - if an item was tapped, it might have been handled
                            // Also check overlay bounds to be sure
                            final RenderBox? overlayRenderBox = 
                                _overlayKey.currentContext?.findRenderObject() as RenderBox?;
                            
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
                                
                                // Check if click is within overlay bounds using estimated position
                                if (estimatedOverlayRect.contains(event.position)) {
                                  return; // Don't dismiss - click is on overlay
                                }
                              }
                            }
                            
                            // If overlay is still showing after the tap, it means the tap wasn't handled by an item
                            // But we should still check bounds first (above)
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