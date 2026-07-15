import 'package:flutter/material.dart';

import '../common/item_dropper_constants.dart';
import '../common/item_dropper_item.dart';

/// Renderable content for a positioned dropdown overlay.
abstract class ItemDropperOverlayContent<T> {
  const ItemDropperOverlayContent();

  bool get isEmpty;

  double maxHeightFor(double requestedMaxHeight);

  Widget build(BuildContext context, ScrollController scrollController);
}

class ItemDropperListOverlayContent<T> extends ItemDropperOverlayContent<T> {
  final List<ItemDropperItem<T>> items;
  final bool Function(ItemDropperItem<T>) isSelected;
  final Widget Function(BuildContext, ItemDropperItem<T>, bool) builder;
  final bool showScrollbar;
  final double scrollbarThickness;
  final double itemHeight;

  const ItemDropperListOverlayContent({
    required this.items,
    required this.isSelected,
    required this.builder,
    required this.itemHeight,
    this.showScrollbar = true,
    this.scrollbarThickness = ItemDropperConstants.kDefaultScrollbarThickness,
  });

  @override
  bool get isEmpty => items.isEmpty;

  @override
  double maxHeightFor(double requestedMaxHeight) {
    final int maxVisibleItems = (requestedMaxHeight / itemHeight).floor();
    final int actualVisibleItems = maxVisibleItems < items.length
        ? maxVisibleItems
        : items.length;

    return actualVisibleItems * itemHeight;
  }

  @override
  Widget build(BuildContext context, ScrollController scrollController) {
    return Scrollbar(
      controller: scrollController,
      thumbVisibility: showScrollbar,
      thickness: scrollbarThickness,
      child: ListView.builder(
        controller: scrollController,
        padding: EdgeInsets.zero,
        itemCount: items.length,
        itemExtent: itemHeight,
        itemBuilder: (c, i) {
          final item = items[i];
          return builder(context, item, isSelected(item));
        },
      ),
    );
  }
}

class ItemDropperWidgetOverlayContent<T> extends ItemDropperOverlayContent<T> {
  final Widget child;
  final double? maxHeight;

  const ItemDropperWidgetOverlayContent({required this.child, this.maxHeight});

  @override
  bool get isEmpty => false;

  @override
  double maxHeightFor(double requestedMaxHeight) {
    return maxHeight ?? requestedMaxHeight;
  }

  @override
  Widget build(BuildContext context, ScrollController scrollController) {
    return child;
  }
}
