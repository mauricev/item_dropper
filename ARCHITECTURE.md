# Item Dropper Package - Architecture & Implementation Overview

## Purpose

Flutter package providing single-select and multi-select dropdown widgets with search, keyboard
navigation, and rich customization options.

## Package Structure

```
packages/item_dropper/
├── lib/
│   ├── item_dropper.dart                      # Main library export
│   ├── item_dropper_single_select.dart        # Single-select widget
│   ├── item_dropper_multi_select.dart         # Multi-select widget
│   └── src/
│       ├── common/                            # Shared components
│       │   ├── item_dropper_item.dart         # Core data model
│       │   ├── item_dropper_constants.dart    # Shared UI constants
│       │   ├── item_dropper_with_overlay.dart # Overlay wrapper widget
│       │   ├── item_dropper_suffix_icons.dart # Clear/arrow buttons
│       │   └── measure_size.dart              # Size measurement utility
│       ├── multi/                             # Multi-select specific
│       │   ├── chip_measurement_helper.dart
│       │   ├── multi_select_constants.dart
│       │   ├── multi_select_focus_manager.dart
│       │   ├── multi_select_layout_calculator.dart
│       │   ├── multi_select_overlay_manager.dart
│       │   ├── multi_select_selection_manager.dart
│       │   └── smartwrap.dart                 # Custom wrap layout
│       └── utils/                             # Shared utilities
│           ├── dropdown_position_calculator.dart
│           ├── item_dropper_add_item_utils.dart
│           ├── item_dropper_filter_utils.dart
│           ├── item_dropper_keyboard_navigation.dart
│           └── item_dropper_render_utils.dart
```

## Core Data Model

### ItemDropperItem<T>

Generic dropdown item with rich metadata:

```dart
class ItemDropperItem<T> {
  final T value;              // The actual value
  final String label;          // Display text
  final bool isGroupHeader;    // Non-selectable section header
  final bool isDeletable;      // Can be deleted (right-click/long-press)
  final bool isEnabled;        // Can be selected
}
```

**Key Characteristics:**

- Type-safe generic value
- Group headers for visual organization (non-selectable)
- Deletable items with confirmation dialog
- Disabled items (rendered but not selectable)

## Main Widgets

### SingleItemDropper<T>

**Purpose:** Single-select dropdown with searchable list

**Key Features:**

- Text field input with live search
- Auto-select on exact match
- Clears invalid input on blur
- Keyboard navigation (arrow keys, enter, escape)
- Optional "add item" functionality
- Custom popup item builders

**State Management:**

- `DropdownInteractionState` enum (idle/editing)
- Tracks whether user is actively typing vs has selection
- Debounced scroll-to-match on search
- Squelch flag to prevent circular updates

**Focus Behavior:**

- Shows overlay on focus
- Hides overlay on blur
- Auto-clears invalid text when losing focus

### MultiItemDropper<T>

**Purpose:** Multi-select dropdown with chip-based display

**Key Features:**

- Selected items shown as removable chips
- Integrated search field
- Smart wrap layout (chips wrap, search field flexible)
- Max selection limit support
- Chip measurement for consistent sizing
- Manual focus management to prevent overlay closure

**State Management:**

- Manager pattern (SelectionManager, FocusManager, OverlayManager)
- Centralized rebuild mechanism with scheduling flag
- Internal change tracking to prevent parent-triggered rebuilds
- Extensive caching (filtered items, decorations, measurements)

**Layout System:**

- Custom `SmartWrapWithFlexibleLast` render object
- Chips wrap naturally, last child (TextField) takes remaining width
- Chip dimensions measured once, cached for performance
- TextField padding calculated to align text with chip text

## Architecture Patterns

### 1. Overlay-Based Rendering

**Components:**

- `OverlayPortal` - Flutter's overlay API
- `CompositedTransformFollower` - Positions overlay relative to input field
- `LayerLink` - Connects input field to overlay
- `ItemDropperWithOverlay` - Shared wrapper widget

**Flow:**

1. Input field wrapped with `CompositedTransformTarget`
2. Overlay rendered via `OverlayPortal` controller
3. `CompositedTransformFollower` positions overlay relative to input
4. Overlay renders globally (not clipped by scroll containers)

**Dismissal Logic:**

- Listener with `HitTestBehavior.translucent` detects clicks
- Checks if click is on overlay, outside field, or on field
- Dismisses appropriately based on click location

### 2. Smart Positioning

**`DropdownPositionCalculator`:**

- Uses screen coordinates (not local)
- Calculates available space above and below input
- Prefers showing below if space available
- Constrains height to fit viewport
- Accounts for keyboard insets (mobile)

**Key Logic:**

```dart
availableSpaceBelow = windowHeight - inputFieldBottom - viewInsets.bottom
availableSpaceAbove = inputFieldTop - padding.top
shouldShowBelow = availableSpaceBelow >= maxDropdownHeight
```

### 3. Filtering & Search

**`ItemDropperFilterUtils<T>`:**

**Features:**

- Pre-normalized labels (lowercase, trimmed) for fast searching
- Cached filter results (invalidated on search text change)
- Reference equality check before re-normalizing items
- Excludes already-selected items (multi-select)
- Group headers excluded from search results

**Performance:**

- O(1) cache lookup for repeated queries
- O(n) initial normalization, cached thereafter
- Set-based exclusion for O(1) selected item filtering

### 4. Keyboard Navigation

**`ItemDropperKeyboardNavigation`:**

**Features:**

- Arrow up/down navigation with wraparound
- Skips group headers automatically
- Scrolls viewport to keep highlighted item visible
- Separate keyboard highlight and mouse hover states
- Enter to select highlighted item

**State Management:**

- `_keyboardHighlightIndex` - Currently keyboard-highlighted item
- `_hoverIndex` - Currently mouse-hovered item
- Keyboard navigation clears hover, hover clears keyboard highlight

### 5. Multi-Select Manager Pattern

#### MultiSelectSelectionManager<T>

**Responsibility:** Track selected items

**Key Features:**

- Maintains both `List<ItemDropperItem<T>>` and `Set<T>` in sync
- O(1) lookup for "is item selected?" checks
- Max selection limit enforcement
- Callbacks on selection change

#### MultiSelectFocusManager

**Responsibility:** Manual focus state tracking

**Why Manual?** Prevents Flutter from losing focus when:

- Clicking overlay items
- Removing chips
- Performing selection operations

**Key Methods:**

- `gainFocus()` - User interaction requests focus
- `loseFocus()` - User explicitly unfocuses (Escape, click outside)
- `restoreFocusIfNeeded()` - Restore focus after operations

#### MultiSelectOverlayManager

**Responsibility:** Control overlay visibility

**Key Methods:**

- `showIfNeeded()` - Show if conditions met
- `hideIfNeeded()` - Hide overlay
- `showIfFocusedAndBelowMax()` - Conditional showing (used after chip removal)

#### ChipMeasurementHelper

**Responsibility:** Measure and cache chip dimensions

**Measurements:**

- `chipHeight` - Total chip height (for TextField sizing)
- `chipTextTop` - Text vertical position (for alignment)
- `wrapHeight` - Total height of chip+TextField area

**Why?** Ensures TextField text aligns perfectly with chip text

### 6. Custom Layout: SmartWrapWithFlexibleLast

**Purpose:** Wrap chips but make TextField flexible

**Behavior:**

- All children except last: Standard wrap behavior
- Last child (TextField):
    - If `>= minRemainingWidthForSameRow` available on current row: Use remaining width
    - Otherwise: Wrap to next row and take full width

**Implementation:**

- Custom `RenderBox` with `ContainerRenderObjectMixin`
- Implements both `performLayout()` and `computeDryLayout()`
- Handles spacing, runSpacing, and width constraints

## State Management Deep Dive

### Single-Select State

**Interaction States:**

```dart
enum DropdownInteractionState {
  idle,     // Not actively editing, selection shown
  editing,  // User actively typing to search
}
```

**Selection Logic:**

1. User types → enters `editing` state
2. Exact match + not editing → auto-select
3. Blur → clear invalid input, return to `idle`
4. Invalid input while selected → clear selection

**Update Prevention:**

- `_squelchOnChanged` flag prevents circular updates
- Used when programmatically setting text field value

### Multi-Select State

**Rebuild Management:**

**Problem:** Selection changes can trigger cascading rebuilds:

1. Internal selection change
2. Notify parent via `onChanged`
3. Parent updates `selectedItems` prop
4. Widget receives new props via `didUpdateWidget`
5. Triggers another rebuild ❌

**Solution:**

```dart
// Flag to track internal changes
bool _isInternalSelectionChange = false;

// Mark internal changes
_isInternalSelectionChange = true;
_requestRebuild(() => updateSelection());
notifyParent();
_isInternalSelectionChange = false;

// Skip rebuild if we caused the change
didUpdateWidget() {
  if (!_isInternalSelectionChange && itemsChanged) {
    syncAndRebuild();
  }
}
```

**Rebuild Scheduling:**

```dart
bool _rebuildScheduled = false;

_requestRebuild([stateUpdate]) {
  if (_rebuildScheduled) return; // Ignore if already rebuilding
  
  _rebuildScheduled = true;
  setState(() => stateUpdate?.call());
  
  postFrameCallback(() => _rebuildScheduled = false);
}
```

Prevents multiple rebuild requests from queueing up.

**Unified Selection Change:**

```dart
_handleSelectionChange({
  required stateUpdate,
  postRebuildCallback,
}) {
  _isInternalSelectionChange = true;
  _requestRebuild(stateUpdate);
  
  postFrameCallback(() {
    notifyParent();
    _isInternalSelectionChange = false;
    postRebuildCallback?.call(); // Focus restoration, overlay updates
  });
}
```

Consolidates: rebuild + parent notification + cleanup + optional post-actions.

### Caching Strategy

**Multi-Select Caches:**

1. **Filtered Items Cache:**
    - Invalidated when: Search text changes, selected items change
    - Key: `(searchText, selectedCount)`

2. **Decoration Cache:**
    - Invalidated when: Focus state changes
    - Key: `isFocused` boolean
    - Prevents BoxDecoration recreation on every build

3. **Chip Measurements Cache:**
    - Measured once after first chip renders
    - Never invalidated (chip dimensions don't change)

4. **Filter Utils Cache:**
    - Normalized labels cached
    - Filtered results cached per search text

## Rendering Pipeline

### Multi-Select Input Field Build

```
_buildInputField()
  └─> Container (with decoration)
       └─> SmartWrapWithFlexibleLast
            ├─> Chip 1 (_buildChip)
            ├─> Chip 2 (_buildChip)
            ├─> ...
            └─> TextField (_buildTextFieldChip)
```

**Chip Build:**

- First chip gets GlobalKey for measurement
- LayoutBuilder triggers measurement post-build
- Measurement updates state → TextField padding recalculated

**TextField Build:**

- Height matches measured chip height
- Padding calculated to align text with chip text
- Width is flexible (determined by SmartWrap)

### Overlay Build

```
_buildDropdownOverlay()
  └─> ItemDropperRenderUtils.buildDropdownOverlay()
       └─> CompositedTransformFollower
            └─> Material (elevation)
                 └─> ConstrainedBox (maxHeight)
                      └─> Scrollbar
                           └─> ListView.builder
                                └─> buildDropdownItemWithHover()
                                     └─> MouseRegion
                                          └─> buildDropdownItem()
                                               └─> InkWell
                                                    └─> ColoredBox
                                                         └─> customBuilder()
```

**Item Builder Chain:**

1. `buildDropdownItemWithHover()` - Adds mouse region
2. `buildDropdownItem()` - Adds InkWell, ColoredBox
3. `customBuilder()` - User's custom builder or default

**Default Builder Features:**

- Group headers: Bold, reduced opacity, separator line
- Normal items: Standard text, selection background
- Disabled items: Greyed out text
- Deletable items: Delete icon on right

## Performance Optimizations

### 1. Caching

- **Filtered items:** Cached per search text
- **Decorations:** Cached per focus state
- **Measurements:** Cached after first measurement
- **Normalized labels:** Pre-computed, cached per items list

### 2. Set-Based Lookups

- Multi-select maintains `Set<T>` alongside `List<ItemDropperItem<T>>`
- `isSelected()` checks: O(1) instead of O(n)

### 3. Reference Equality Checks

- `identical(newItems, oldItems)` before expensive comparisons
- Fast path for unchanged item lists

### 4. Rebuild Throttling

- Single `_rebuildScheduled` flag prevents cascading rebuilds
- Internal change tracking prevents parent-triggered rebuilds

### 5. Stable Keys

- `ValueKey` on chips prevents recreation when order changes
- Width-based key on overlay preserves scroll position during height changes

### 6. Lazy Measurement

- Chips measured once after render, not during build
- Post-frame callbacks for measurements to avoid build-time side effects

### 7. Efficient List Comparison

- Small lists (<= threshold): Simple iteration
- Large lists: Set-based comparison
- Early returns for length mismatches

## Notable Features

### 1. Group Headers

- Visual organization of items
- Non-selectable
- Bold styling with separator line
- Excluded from search results
- Skipped during keyboard navigation

### 2. Add Item Functionality

- `onAddItem` callback receives search text
- Returns new `ItemDropperItem` to add
- Special "Add [search text]" row shown when no matches
- Auto-selects newly created item

### 3. Delete Functionality

- Items marked `isDeletable: true` can be deleted
- Right-click (desktop) or long-press (mobile)
- Shows confirmation dialog
- Removes from selection if selected
- Parent notified via `onDeleteItem` callback

### 4. Max Selection Limit

- Multi-select supports `maxSelected` parameter
- Prevents selection when limit reached
- Auto-hides overlay when limit reached
- Shows overlay again when item removed

### 5. Disabled State

- Entire widget can be disabled via `enabled` parameter
- Individual items can be disabled via `isEnabled: false`
- Disabled styling: Grey text, no hover effects
- Disabled items in list are non-clickable

### 6. Custom Styling

- `fieldTextStyle` - Input field text style
- `popupTextStyle` - Dropdown item text style
- `popupGroupHeaderStyle` - Group header text style
- `fieldDecoration` - Input field container decoration
- `selectedChipDecoration` - Multi-select chip decoration (multi-select only)
- `itemHeight` - Dropdown item height override

### 7. Focus Management

- Manual focus state (multi-select)
- Prevents overlay closure during interactions
- Restores focus after operations
- Escape key to unfocus
- Click outside to unfocus

### 8. Keyboard Navigation

- Arrow up/down with wraparound
- Enter to select
- Escape to close (single-select) or unfocus (multi-select)
- Auto-scroll to keep highlighted item visible
- Skips group headers

### 9. Scrollbar Control

- `showScrollbar` - Toggle visibility
- `scrollbarThickness` - Control thickness
- Thumb always visible when `showScrollbar: true`

### 10. Empty State

- Multi-select shows "No items found" when search returns empty
- Only shown when actively searching (not on initial empty)
- Matches field width exactly

## Edge Cases Handled

### Multi-Select Specific

1. **Chip Removal While at Max:**
    - Overlay shows again after removal
    - Search field becomes active
    - Handled by `showIfFocusedAndBelowMax()`

2. **Focus Loss Prevention:**
    - Overlay clicks don't unfocus field
    - Chip removal refocuses field
    - Selection changes preserve focus

3. **Layout Changes:**
    - Chips wrapping doesn't cause overlay flash
    - Uses measured wrap height for positioning
    - Stable keys preserve scroll position

4. **Parent Update Loops:**
    - `_isInternalSelectionChange` flag prevents rebuild loops
    - Rebuild scheduling prevents cascading rebuilds

5. **Text Alignment:**
    - TextField text aligns with chip text
    - Uses measured chip text position
    - Fallback calculation if measurement fails

### Single-Select Specific

1. **Selection vs Editing:**
    - Auto-select only when not actively editing
    - Preserves user's typing flow

2. **Invalid Input:**
    - Clears on blur
    - Clears selection if partially deleted

3. **Scroll Position:**
    - Auto-scrolls to match on search
    - Resets to start on blur
    - Centers selected item when opening

## Common Patterns

### Safe setState

```dart
void _safeSetState(void Function() fn) {
  if (mounted) {
    setState(fn);
  }
}
```

Used throughout to prevent "setState called after dispose" errors.

### Post-Frame Callbacks

```dart
WidgetsBinding.instance.addPostFrameCallback((_) {
  if (!mounted) return;
  // Perform action after build completes
});
```

Used for:

- Measurements (after render)
- Scroll animations (after layout)
- Focus operations (after state changes)

### Squelch Pattern

```dart
bool _squelching = false;

void _withSquelch(void Function() action) {
  _squelching = true;
  try {
    action();
  } finally {
    _squelching = false;
  }
}

// In listener:
if (_squelching) return;
```

Prevents circular updates when programmatically changing values.

## Testing Considerations

### Testable via GlobalKey

Both widgets accept optional `inputKey` parameter:

```dart
final key = GlobalKey();
SingleItemDropper(inputKey: key, ...);

// Later:
final context = key.currentContext;
final box = context.findRenderObject() as RenderBox;
```

Allows tests to:

- Find the input field
- Measure dimensions
- Access context for tap testing
- Control focus programmatically

### Widget Testing Challenges

- Overlay renders outside widget tree (needs `pumpAndSettle()`)
- Focus management may require explicit `tester.testTextInput.register()`
- Measurements happen post-frame (need multiple pumps)

## Future Enhancement Areas

Based on the architecture:

1. **Animation Support:**
    - Chip addition/removal animations
    - Overlay show/hide transitions
    - Currently instant changes

2. **Accessibility:**
    - Screen reader announcements
    - Semantic labels for chips
    - ARIA-like attributes

3. **Virtual Scrolling:**
    - For very large item lists
    - Currently renders all items

4. **Multi-Column Layout:**
    - Dropdown items in multiple columns
    - Better use of horizontal space

5. **Drag-to-Reorder:**
    - Reorder chips via drag (multi-select)
    - Would need ReorderableList integration

6. **Async Search:**
    - Support for remote data loading
    - Loading indicators
    - Debounced API calls

## Dependencies

**External:**

- `flutter/material.dart` - Material design widgets
- `flutter/services.dart` - Keyboard input handling
- `flutter/rendering.dart` - Custom render objects

**No external pub dependencies** - Pure Flutter implementation

## Design Decisions

### Why Manual Focus Management (Multi-Select)?

Flutter's default focus behavior would unfocus the field when clicking overlay items, causing the
overlay to close immediately. Manual tracking allows us to maintain "logical focus" separate from
Flutter's focus system.

### Why SmartWrap Instead of Standard Wrap?

Standard Wrap doesn't support making the last child flexible. We need the TextField to take
remaining width on the current row or full width on a new row. This requires custom layout logic.

### Why Both List and Set for Selection?

- List preserves selection order (for display)
- Set enables O(1) `isSelected()` checks (performance)

### Why Separate RenderUtils Class?

Shared between single and multi-select widgets. Reduces code duplication and ensures consistent
behavior.

### Why Cache Decorations?

BoxDecoration creation is relatively expensive when done on every build (60 fps). Caching with
invalidation on state change is more efficient.

### Why Separate Managers?

Separation of concerns. Each manager handles one aspect:

- Selection state
- Focus state
- Overlay visibility

Makes the main widget less cluttered and easier to test/modify.

---

## Quick Reference

**Starting a new session?** Read this document first to understand the architecture, then dive into
specific files as needed.

**Making changes?** Pay attention to:

- Rebuild management in multi-select
- Cache invalidation
- Focus state handling
- Post-frame callback usage
