import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:item_dropper/src/common/item_dropper_constants.dart';
import 'package:item_dropper/src/utils/item_dropper_layout_utils.dart';

void main() {
  group('ItemDropperLayoutUtils.calculateEffectiveItemHeight', () {
    test('uses explicit item height when provided', () {
      expect(
        ItemDropperLayoutUtils.calculateEffectiveItemHeight(
          itemHeight: 42,
          popupTextStyle: const TextStyle(fontSize: 18, height: 2),
        ),
        42,
      );
    });

    test(
      'calculates height from popup text style font size and line height',
      () {
        expect(
          ItemDropperLayoutUtils.calculateEffectiveItemHeight(
            itemHeight: null,
            popupTextStyle: const TextStyle(fontSize: 20, height: 1.5),
          ),
          46,
        );
      },
    );

    test('uses shared dropdown defaults when popup style is null', () {
      const expected =
          (ItemDropperConstants.kDropdownItemFontSize *
              ItemDropperConstants.kDropdownItemLineHeightMultiplier) +
          (ItemDropperConstants.kDropdownItemVerticalPadding * 2);

      expect(
        ItemDropperLayoutUtils.calculateEffectiveItemHeight(
          itemHeight: null,
          popupTextStyle: null,
        ),
        expected,
      );
    });

    test('falls back to default font size when style omits it', () {
      const expected =
          (ItemDropperConstants.kDropdownItemFontSize * 2) +
          (ItemDropperConstants.kDropdownItemVerticalPadding * 2);

      expect(
        ItemDropperLayoutUtils.calculateEffectiveItemHeight(
          itemHeight: null,
          popupTextStyle: const TextStyle(height: 2),
        ),
        expected,
      );
    });
  });
}
