# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [0.0.1] - 2024-12-06

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

[0.0.1]: https://github.com/mauricev/item_dropper/releases/tag/v0.0.1
