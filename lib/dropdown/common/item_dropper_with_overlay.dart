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
                            debugPrint("DEBUG: Click is on overlay - allowing event to propagate to items (not handling in Listener)");
                            return; // Don't handle - let items receive the event
                          }
                        }
                      }
                      
                      debugPrint("DEBUG LAST ITEM: Listener onPointerDown received at ${event.position} - this is the dismiss handler");
                      
                      // DEBUG: Check which items are actually at this click position
                      if (overlayRenderBox != null) {
                        final Offset clickInOverlayLocal = overlayRenderBox.globalToLocal(event.position);
                        debugPrint("DEBUG: Click in overlay local coordinates (from globalToLocal): $clickInOverlayLocal");
                        debugPrint("DEBUG: Overlay size: ${overlayRenderBox.size}");
                        debugPrint("DEBUG: Checking if click is within overlay bounds: dx=${clickInOverlayLocal.dx >= 0 && clickInOverlayLocal.dx <= overlayRenderBox.size.width}, dy=${clickInOverlayLocal.dy >= 0 && clickInOverlayLocal.dy <= overlayRenderBox.size.height}");
                        
                        // CRITICAL: globalToLocal is broken for CompositedTransformFollower
                        // Calculate local coordinates manually using field position
                        // FIX: Due to double CompositedTransformFollower wrapping, the actual overlay position
                        // is at the FIELD position (not field + height) because the outer follower has offset (0,0)
                        final RenderBox? fieldRenderBox = widget.fieldKey.currentContext?.findRenderObject() as RenderBox?;
                        if (fieldRenderBox != null) {
                          final Offset fieldGlobalPos = fieldRenderBox.localToGlobal(Offset.zero);
                          final double fieldHeight = fieldRenderBox.size.height;
                          final Offset estimatedOverlayPos = Offset(fieldGlobalPos.dx, fieldGlobalPos.dy + fieldHeight);
                          
                          // Calculate correct local coordinates
                          final Offset correctLocalCoords = Offset(
                            event.position.dx - estimatedOverlayPos.dx,
                            event.position.dy - estimatedOverlayPos.dy,
                          );
                          debugPrint("DEBUG: Correct local coordinates (manual calc): $correctLocalCoords");
                          debugPrint("DEBUG: Correct local within bounds: dx=${correctLocalCoords.dx >= 0 && correctLocalCoords.dx <= overlayRenderBox.size.width}, dy=${correctLocalCoords.dy >= 0 && correctLocalCoords.dy <= overlayRenderBox.size.height}");
                          
                          // Try hit test with CORRECT local coordinates
                          if (correctLocalCoords.dx >= 0 && correctLocalCoords.dx <= overlayRenderBox.size.width &&
                              correctLocalCoords.dy >= 0 && correctLocalCoords.dy <= overlayRenderBox.size.height) {
                            // DEBUG: Check what item should be at this Y position
                            // Items are 30px tall, overlay starts at estimatedOverlayPos
                            final double itemHeight = 30.0;
                            final int expectedItemIndex = (correctLocalCoords.dy / itemHeight).floor();
                            debugPrint("DEBUG: Expected item index at y=${correctLocalCoords.dy}: $expectedItemIndex (itemHeight=$itemHeight)");
                            
                            // Try to find the ListView within the overlay
                            // CRITICAL: The child position calculation is wrong because overlayRenderBox.localToGlobal returns (0,0)
                            // We need to calculate it manually
                            overlayRenderBox.visitChildren((child) {
                              debugPrint("DEBUG: Overlay child: ${child.runtimeType}");
                              if (child is RenderBox) {
                                // Get child's global position
                                final Offset childGlobalPos = child.localToGlobal(Offset.zero);
                                // Calculate child's position relative to overlay using estimated overlay position
                                final Offset childLocalPos = childGlobalPos - estimatedOverlayPos;
                                debugPrint("DEBUG:   Child global position: $childGlobalPos");
                                debugPrint("DEBUG:   Estimated overlay position: $estimatedOverlayPos");
                                debugPrint("DEBUG:   Child position in overlay (manual calc): $childLocalPos, size: ${child.size}");
                                
                                // Try hit test on child with corrected coordinates
                                final Offset childLocalCoords = correctLocalCoords - childLocalPos;
                                debugPrint("DEBUG:   Hit test coords for child: $childLocalCoords (correctLocalCoords=$correctLocalCoords - childLocalPos=$childLocalPos)");
                                if (childLocalCoords.dx >= 0 && childLocalCoords.dx <= child.size.width &&
                                    childLocalCoords.dy >= 0 && childLocalCoords.dy <= child.size.height) {
                                  final BoxHitTestResult childResult = BoxHitTestResult();
                                  child.hitTest(childResult, position: childLocalCoords);
                                  debugPrint("DEBUG:   Hit test on child at $childLocalCoords: ${childResult.path.length} targets found");
                                  if (childResult.path.length > 0) {
                                    int i = 0;
                                    for (final entry in childResult.path) {
                                      if (i < 5) {
                                        debugPrint("DEBUG:     Child hit target $i: ${entry.target.runtimeType}");
                                        i++;
                                      } else {
                                        break;
                                      }
                                    }
                                  }
                                } else {
                                  debugPrint("DEBUG:   Hit test coords outside child bounds");
                                }
                              }
                            });
                            
                            final BoxHitTestResult result = BoxHitTestResult();
                            overlayRenderBox.hitTest(result, position: correctLocalCoords);
                            debugPrint("DEBUG: Hit test with CORRECT coords - ${result.path.length} targets found");
                            int i = 0;
                            for (final entry in result.path) {
                              if (i < 10) {
                                debugPrint("DEBUG:   Hit target $i: ${entry.target.runtimeType}");
                                i++;
                              } else {
                                break;
                              }
                            }
                          } else {
                            debugPrint("DEBUG: Correct local coords are outside overlay bounds - cannot hit test");
                          }
                        }
                        
                        // Also try with broken globalToLocal for comparison
                        final BoxHitTestResult brokenResult = BoxHitTestResult();
                        overlayRenderBox.hitTest(brokenResult, position: clickInOverlayLocal);
                        debugPrint("DEBUG: Hit test with BROKEN globalToLocal coords - ${brokenResult.path.length} targets found");
                      }
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