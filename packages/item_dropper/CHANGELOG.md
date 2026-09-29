# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

### Fixed

- Refresh single-select text and multi-select chips when the parent updates a
  selected item's label or properties without changing its value. Explicit
  single-select choices also retain and report the updated item contents.
- Detect in-place item-list changes on parent rebuilds in both dropdowns using
  saved snapshots, refreshing search caches for additions, removals, reordering,
  and replaced row labels or properties.
- Open the single-select popup from its arrow button even when the field already
  has focus and no focus-change event occurs.
- Check live widget mount state before deferred keyboard scrolling instead of
  retaining the mount state from when the key event was handled.
- Use the effective rendered row height for keyboard scrolling in both dropdowns
  and for single-select search scrolling and selected-item centering, including
  heights derived from `popupTextStyle`.
- Apply parent changes to multi-select `maxSelected`, including removing the
  limit with null. Lowering the limit preserves existing selections while
  preventing further additions until the selection is below the new limit.
- Synchronize multi-select chip keyboard focus and dispose obsolete chip focus
  nodes after parent-driven selection changes.
- Honor popup `elevation` in both dropdowns, including multi-select information
  overlays, and pass multi-select `showScrollbar` and `scrollbarThickness` through
  to the popup renderer. Parent updates apply while the popup is open; defaults
  remain elevation `4.0`, persistent scrollbar visibility, and thickness `6.0`.
- Wire single-select item deletion to right-click and long-press confirmation,
  clearing the selection and text when the selected item is deleted.
- Allow creating the first item from an empty single- or multi-select dropdown.
  Add-action rows no longer borrow a placeholder value from an existing item.
- Clear single-select text when the parent clears `selectedItem`, and preserve
  internal selection across parent rebuilds when `selectedItem` is omitted.
  Explicit `selectedItem: null` now means controlled and empty.
- Select a clicked single-select item directly, including when its label is a
  shorter prefix of the previous selection (for example, `Chanin 543C` → `chanin`).

### Changed

- Centralize suffix-icon dimensions in shared dropdown constants and remove
  duplicated documentation, stale comments, and redundant control flow.

## [0.0.5] - 2026-09-07

### Fixed

- Close an open dropdown when Tab moves focus past its final suffix button.
- Keep the multi-select dropdown arrow in sync after closing the menu.

## [0.0.4] - 2026-07-15
- Several bugs were fixed; several deficiencies in architecture were addressed.

## [0.0.3] - 2026-04-26
- Fixed clear button hit testing for dropdown suffix icons.

## [0.0.2] - 2025-12-19
- Fixed items for pub.dev.

## [0.0.1] - 2025-12-08


### Added

#### Core Widgets

- `SingleItemDropper<T>` - Single-select dropdown with search functionality
- `MultiItemDropper<T>` - Multi-select dropdown with chip-based display
- `ItemDropperItem<T>` - Generic item model supporting any value type

#### Features

- Real-time search and filtering for both widgets
- Full keyboard navigation (arrow keys, Enter, Escape)
- Group headers for organizing items
- Add new items on-the-fly with `onAddItem` callback
- Delete items from the list with `onDeleteItem` callback
- Smart dropdown positioning (automatically positions above or below based on screen space)
- Max selection limit for multi-select widget
- Disabled state support for both widgets

#### Customization

- Custom text styles for field, popup items, and group headers
- Custom decorations for field container and selected chips
- Custom popup item builder for complete rendering control
- Configurable dimensions (width, height, elevation)
- Scrollbar customization (visibility and thickness)
- Optional mobile keyboard display

#### Accessibility

- Screen reader support with semantic labels
- Live region announcements for selections
- Keyboard-only navigation support
- ARIA-compliant widget structure

#### Performance Optimizations

- Cached filtering results for fast search
- Decoration caching to prevent unnecessary rebuilds
- Smart rebuild throttling
- O(1) selection lookups with Set-based storage
- Debounced scroll animations

#### Architecture

- Manager pattern for clean separation of concerns
- `KeyboardNavigationManager` for unified keyboard handling
- `DecorationCacheManager` for efficient styling
- `LiveRegionManager` for accessibility announcements
- `MultiSelectFocusManager` for focus state tracking
- `MultiSelectOverlayManager` for overlay lifecycle
- `MultiSelectSelectionManager` for selection state

### Fixed

- None (initial release)

### Changed

- None (initial release)

### Deprecated

- None (initial release)

### Removed

- None (initial release)

### Security

- None (initial release)

---

## Future Releases

See [GitHub Issues](https://github.com/mauricev/item_dropper/issues) for planned features
and bug reports.

[0.0.5]: https://github.com/mauricev/item_dropper/releases/tag/v0.0.5
[0.0.4]: https://github.com/mauricev/item_dropper/releases/tag/v0.0.4
[0.0.3]: https://github.com/mauricev/item_dropper/releases/tag/v0.0.3
[0.0.2]: https://github.com/mauricev/item_dropper/releases/tag/v0.0.2
[0.0.1]: https://github.com/mauricev/item_dropper/releases/tag/v0.0.1
