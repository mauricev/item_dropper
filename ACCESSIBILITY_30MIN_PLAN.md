# Minimal Accessibility Implementation Plan (30 minutes)

## Status: PAUSED - Implementation Issues

We attempted to implement the minimal accessibility improvements but encountered challenges with the
code structure modifications. Here's what was attempted and what still needs to be done.

## What Needs to Be Done

### 1. Single-Select TextField ⏸️ IN PROGRESS

**File:** `packages/item_dropper/lib/item_dropper_single_select.dart:718`

**Current code:**

```dart
child: TextField(
  key: widget.inputKey ?? _internalFieldKey,
  // ... properties
)
```

**Should become:**

```dart
child: Semantics(
  label: 'Search dropdown',
  textField: true,
  child: TextField(
    key: widget.inputKey ?? _internalFieldKey,
    // ... properties
  ),
)
```

**Challenge:** Complex nested widget structure made the edit error-prone with parentheses matching
issues.

---

### 2. Multi-Select TextField ❌ NOT STARTED

**File:** `packages/item_dropper/lib/item_dropper_multi_select.dart` (around line 1009)

Same modification as single-select.

---

### 3. Multi-Select Chips (CRITICAL) ❌ NOT STARTED

**File:** `packages/item_dropper/lib/item_dropper_multi_select.dart:_buildChip()` method

**Current code:**

```dart
return LayoutBuilder(
  builder: (context, constraints) {
    return Container(
      decoration: effectiveDecoration,
      child: Row(
        children: [
          Text(item.label),
          GestureDetector(
            onTap: () => _removeChip(item),
            child: Icon(Icons.close),
          ),
        ],
      ),
    );
  },
)
```

**Should become:**

```dart
return LayoutBuilder(
  builder: (context, constraints) {
    return Semantics(
      label: '${item.label}, selected',
      button: true,
      enabled: widget.enabled,
      onTap: widget.enabled ? () => _removeChip(item) : null,
      excludeSemantics: true,  // CRITICAL: prevents double-reading
      child: Container(
        decoration: effectiveDecoration,
        child: Row(
          children: [
            Text(item.label),
            if (widget.enabled)
              GestureDetector(
                onTap: () => _removeChip(item),
                child: Icon(Icons.close),
              ),
          ],
        ),
      ),
    );
  },
)
```

**Why this is critical:** Without `excludeSemantics: true`, screen readers read "Apple" then "close
button" as two separate items, making navigation confusing.

---

### 4. Dropdown Items Selection State ❌ NOT STARTED

**File:** `packages/item_dropper/lib/src/utils/item_dropper_render_utils.dart:buildDropdownItem()`
method (around line 113)

**Current code:**

```dart
return InkWell(
  onTap: isEnabled && !isGroupHeader ? onTap : null,
  child: SizedBox(
    height: itemHeight ?? ItemDropperConstants.kDropdownItemHeight,
    child: ColoredBox(
      color: background ?? Colors.transparent,
      child: Align(
        alignment: Alignment.centerLeft,
        child: itemContent,
      ),
    ),
  ),
);
```

**Should become:**

```dart
return Semantics(
  label: item.label,
  button: !isGroupHeader,
  enabled: isEnabled,
  selected: isSelected,
  excludeSemantics: true,
  child: InkWell(
    onTap: isEnabled && !isGroupHeader ? onTap : null,
    child: SizedBox(
      height: itemHeight ?? ItemDropperConstants.kDropdownItemHeight,
      child: ColoredBox(
        color: background ?? Colors.transparent,
        child: Align(
          alignment: Alignment.centerLeft,
          child: itemContent,
        ),
      ),
    ),
  ),
);
```

---

## Estimated Time Remaining

- Single-select TextField: 5 min (retry with more care)
- Multi-select TextField: 5 min
- Multi-select chips: 10 min (most important)
- Dropdown items: 5 min
- Testing: 10 min

**Total: 35 minutes** (slightly over "30 minute" estimate due to retry)

---

## Impact vs Effort

| Change | Effort | Impact | Priority |
|--------|--------|--------|----------|
| Multi-select chips `excludeSemantics` | 10 min | **CRITICAL** | #1 |
| Dropdown items `selected` state | 5 min | **HIGH** | #2 |
| TextFields labels | 10 min | HIGH | #3 |

---

## Alternative Approach

Given the implementation challenges, we could:

**Option A:** Continue with manual code edits (35 min remaining)
**Option B:** Create a patch file that can be applied with `git apply` (5 min to create)
**Option C:** Skip this and document it for future work (0 min)
**Option D:** Focus on just the chips fix (#1) since it's most critical (10 min)

---

## Recommendation

Given the time spent, I recommend **Option D**: Just fix the multi-select chips with
`excludeSemantics: true`. This is:

- The most critical fix (prevents double-reading)
- Simplest to implement (one method)
- Highest impact for time spent

The other changes can be added later when we have fresh eyes and can be more careful with the code
structure.

---

## Value Assessment

**Current time spent:** ~45 minutes  
**Original estimate:** 30 minutes  
**Remaining value:** Moderate (helps screen reader users but fixes incomplete)

**Recommendation:** Either commit to Option D (10 more minutes for chips only) or move on to
document other high-priority items.

What would you like to do?
