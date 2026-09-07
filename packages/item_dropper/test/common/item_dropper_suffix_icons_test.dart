import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:item_dropper/src/common/item_dropper_suffix_icons.dart';

void main() {
  testWidgets('closes the dropdown when Tab leaves the final suffix button', (
    tester,
  ) async {
    var tabExitCount = 0;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Column(
            children: [
              const TextField(),
              ItemDropperSuffixIcons(
                isDropdownShowing: true,
                enabled: true,
                onClearPressed: () {},
                onArrowPressed: () {},
                onTabExit: () => tabExitCount++,
              ),
              const TextField(),
            ],
          ),
        ),
      ),
    );

    // Move through the preceding field, clear button, and arrow button.
    await tester.sendKeyEvent(LogicalKeyboardKey.tab);
    await tester.sendKeyEvent(LogicalKeyboardKey.tab);
    await tester.sendKeyEvent(LogicalKeyboardKey.tab);
    expect(tabExitCount, 0);

    // The next Tab leaves the dropdown control.
    await tester.sendKeyEvent(LogicalKeyboardKey.tab);
    expect(tabExitCount, 1);
  });
}
