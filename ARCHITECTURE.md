# Item Dropper Architecture

## Purpose

Item Dropper is a Flutter package providing searchable single-select and multi-select dropdowns.
Both widgets support keyboard navigation, accessibility, custom rendering, add/delete callbacks,
and automatic popup positioning.

## Public API

The package entrypoint is `packages/item_dropper/lib/item_dropper.dart`. It exports:

- `SingleItemDropper<T>`
- `MultiItemDropper<T>`
- `ItemDropperItem<T>` and `ItemDropperItemCallback<T>`
- `ItemDropperLocalizations`
- `ItemDropperBase<T>`, the common widget configuration contract
- `SingleItemDropperDependencies<T>` and `MultiItemDropperDependencies<T>` for dependency injection

`ItemDropperItem<T>` is an immutable value object. Equality and `hashCode` include its value, label,
and all state flags. The `isAddItem` flag identifies internally generated add-item rows; labels and
placeholder values are not used to identify those rows.

## Source Layout

```text
packages/item_dropper/lib/
|-- item_dropper.dart
|-- item_dropper_single_select.dart
|-- item_dropper_multi_select.dart
`-- src/
    |-- common/
    |   |-- item_dropper_base.dart
    |   |-- item_dropper_dependencies.dart
    |   |-- item_dropper_item.dart
    |   |-- item_dropper_localizations.dart
    |   |-- item_dropper_with_overlay.dart
    |   |-- keyboard_navigation_manager.dart
    |   |-- decoration_cache_manager.dart
    |   |-- controlled_value_sync.dart
    |   `-- rebuild_scheduler.dart
    |-- multi/
    |   |-- multi_select_selection_manager.dart
    |   |-- multi_select_focus_manager.dart
    |   |-- multi_select_filter_controller.dart
    |   |-- multi_select_chip_layout_controller.dart
    |   |-- multi_select_chip_focus_node_controller.dart
    |   |-- multi_select_highlight_policy.dart
    |   `-- smartwrap.dart
    `-- utils/
        |-- item_dropper_filter_utils.dart
        |-- item_dropper_keyboard_navigation.dart
        |-- item_dropper_add_item_utils.dart
        |-- item_dropper_selection_handler.dart
        |-- item_dropper_layout_utils.dart
        |-- item_dropper_dropdown_item_renderer.dart
        |-- item_dropper_popup_item_builder.dart
        |-- item_dropper_overlay_builder.dart
        |-- item_dropper_overlay_content.dart
        `-- dropdown_position_calculator.dart
```

The multi-select implementation is kept in one library rather than using Dart `part` files. Private
extensions in `item_dropper_multi_select.dart` group helpers, handlers, and builders while extracted
controllers own independently testable state and policy.

## Shared Widget Contract

`ItemDropperBase<T>` contains the configuration shared by single- and multi-select widgets. It lets
code accept either widget without erasing their specialized selection APIs:

- Single-select exposes `selectedItem` and a nullable-item `onChanged` callback.
- Multi-select exposes `selectedItems`, a list callback, chip styling, and `maxSelected`.

Both concrete widgets remain directly constructible and retain their existing named parameters.

## Dependency Injection

Each widget accepts an optional dependency factory object. Production code normally uses the
default factories. Tests can subclass a factory and replace a manager or controller without global
state or runtime patching.

The state objects resolve dependencies once in `initState` and retain ownership of disposal. Factory
objects create filtering, keyboard, focus, selection, decoration, chip-layout, highlight, and live
region collaborators as appropriate for each widget.

## Single-Select Responsibilities

The single-select state coordinates:

- text editing and controlled selection synchronization;
- filtering and add-item row creation;
- focus, overlay visibility, and scroll positioning;
- keyboard/hover highlighting;
- selection submission through one shared candidate path.

Programmatic text changes use `_withSquelch` to prevent `TextEditingController` notifications from
being interpreted as user input. `ControlledValueSync` separately decides whether an incoming
controlled value differs from current internal state.

## Multi-Select Responsibilities

The multi-select state acts as coordinator while focused collaborators own narrower concerns:

- `MultiSelectSelectionManager<T>` owns selected items and selected-value lookup.
- `MultiSelectFocusManager<T>` coordinates the text field and chip focus.
- `MultiSelectFilterController<T>` owns filtered-item calculation and memoization.
- `MultiSelectChipLayoutController` owns deferred chip and container measurements.
- `MultiSelectChipFocusNodeController` owns chip `FocusNode` creation and disposal.
- `MultiSelectHighlightPolicy` decides highlight retention after selection changes.
- `DecorationCacheManager` caches field decoration by visual state.
- `RebuildScheduler` coalesces nested rebuild requests without dropping queued updates.

Selection updates are applied internally, emitted to the parent, and compared with incoming
`selectedItems` through `ControlledValueSync`. Add-item sentinels are never inserted into selected
state, even though their generic placeholder value may match a real item.

## Filtering and Add Items

`ItemDropperFilterUtils<T>` normalizes labels and caches search results. Multi-select filtering also
excludes selected values. `MultiSelectFilterController<T>` adds a second cache keyed by search text
and selected count for the composed multi-select result.

When `onAddItem` is available and no exact match exists, `ItemDropperAddItemUtils` prepends an
explicit add-item sentinel. `ItemDropperSelectionHandler` recognizes only `item.isAddItem`, extracts
the localized search text from its display label, invokes the callback, and routes the returned real
item back through normal selection handling.

## Keyboard Navigation

Keyboard ownership is split by role:

- `KeyboardNavigationManager<T>` owns hover/highlight state and dispatches key actions.
- `ItemDropperKeyboardNavigation` contains stateless predicates, index navigation, and scrolling.

Both widgets share the same Space/Enter predicate for opening a closed dropdown. Navigation skips
group headers and disabled items, and scrolling keeps the highlighted item visible.

## Overlay Architecture

`ItemDropperWithOverlay` wraps the field in an `OverlayPortal` and a
`CompositedTransformTarget`. `ItemDropperOverlayBuilder` positions popup content using a linked
`CompositedTransformFollower` and `DropdownPositionCalculator`.

Overlay content is polymorphic:

- `ItemDropperListOverlayContent<T>` renders item lists with optional scrollbars.
- `ItemDropperWidgetOverlayContent<T>` renders arbitrary informational or asynchronous content.

New overlay content types can implement `ItemDropperOverlayContent<T>` without changing the
positioning builder. This keeps viewport positioning and Material chrome independent from the
content being displayed.

The rendering pipeline is divided into focused utilities:

```text
ItemDropperOverlayBuilder
`-- ItemDropperOverlayContent
    `-- ItemDropperDropdownItemRenderer
        `-- ItemDropperPopupItemBuilder or popupItemBuilder
```

`ItemDropperRenderUtils` remains only as a narrow compatibility facade for internal callers. New
code should use the focused utilities directly.

## Positioning and Dismissal

`DropdownPositionCalculator` measures available viewport space above and below the field, accounts
for insets, chooses a direction, and constrains popup height. The follower offset therefore works for
both above-field and below-field placement.

The overlay wrapper dismisses from outside pointer events without trying to estimate the popup's
screen rectangle. This avoids embedding a below-field assumption in dismissal behavior.

## Multi-Select Layout

`SmartWrapWithFlexibleLast` is a custom render object used for chips plus the trailing text field.
Normal children take their intrinsic widths; the last child takes the remaining width when enough
space exists or wraps to a full-width next row. Children with different heights are vertically
centered within each row.

`MultiSelectChipLayoutController` records the latest pending measurement request. Rapid rebuilds
therefore replace stale measurement inputs instead of losing the measurement and leaving chip height
unset.

## Caching and Equality

The package uses several bounded caches:

- normalized labels and filter results;
- composed multi-select filter results;
- field decorations keyed by focus/custom decoration state;
- measured chip geometry.

List comparison counts values rather than comparing only distinct-value sets, so duplicate
multiplicity is preserved. `ItemDropperItem` value equality makes comparisons deterministic across
newly constructed equivalent item instances.

## Accessibility and Localization

`ItemDropperLocalizations` is the source of user-facing and semantic strings. Internal semantic
formatting helpers delegate to it rather than maintaining a second constants system. Live-region
managers announce selection, removal, dropdown, and maximum-selection state changes.

## Testing

Tests are organized around public widget behavior and extracted responsibilities:

- widget tests cover single- and multi-select workflows;
- common tests cover equality, rebuild scheduling, controlled synchronization, and decorations;
- manager/controller tests cover multi-select state ownership;
- utility tests cover filtering, equality, add items, layout, rendering, and keyboard behavior;
- render-object tests verify SmartWrap row placement and vertical centering.

Run package verification from `packages/item_dropper`:

```bash
flutter test --no-pub
flutter analyze --no-pub
```

API documentation is generated with `dart doc`. The `doc/api` directory is intentionally ignored;
pub.dev regenerates the same documentation from exported source declarations when a release is
published.

## Design Constraints

- Keep public widget constructor changes additive unless a breaking release is intentional.
- Keep implementation utilities under `lib/src`; only export deliberate public contracts.
- Prefer focused controllers or policies when state has independent invariants and tests.
- Keep overlay positioning independent from overlay content.
- Treat add-item rows as explicit sentinels, never as ordinary values or label patterns.
- Preserve selected-item order while using value sets for fast membership checks.
