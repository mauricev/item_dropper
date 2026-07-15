import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:item_dropper/src/multi/smartwrap.dart';

void main() {
  group('SmartWrapWithFlexibleLast', () {
    testWidgets('vertically centers children within the same row', (
      tester,
    ) async {
      const shortKey = ValueKey('short');
      const tallKey = ValueKey('tall');
      const lastKey = ValueKey('last');

      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: Align(
              alignment: Alignment.topLeft,
              child: SizedBox(
                width: 300,
                child: SmartWrapWithFlexibleLast(
                  spacing: 10,
                  minRemainingWidthForSameRow: 10,
                  children: [
                    SizedBox(key: shortKey, width: 40, height: 20),
                    SizedBox(key: tallKey, width: 40, height: 60),
                    SizedBox(key: lastKey, width: 40, height: 20),
                  ],
                ),
              ),
            ),
          ),
        ),
      );

      final shortTop = tester.getTopLeft(find.byKey(shortKey)).dy;
      final tallTop = tester.getTopLeft(find.byKey(tallKey)).dy;
      final lastTop = tester.getTopLeft(find.byKey(lastKey)).dy;

      expect(shortTop, tallTop + 20);
      expect(lastTop, tallTop + 20);
    });

    testWidgets('vertically centers children in wrapped rows', (tester) async {
      const firstKey = ValueKey('first');
      const secondKey = ValueKey('second');
      const lastKey = ValueKey('last');

      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: Align(
              alignment: Alignment.topLeft,
              child: SizedBox(
                width: 90,
                child: SmartWrapWithFlexibleLast(
                  spacing: 10,
                  runSpacing: 5,
                  minRemainingWidthForSameRow: 30,
                  children: [
                    SizedBox(key: firstKey, width: 80, height: 20),
                    SizedBox(key: secondKey, width: 40, height: 60),
                    SizedBox(key: lastKey, width: 20, height: 20),
                  ],
                ),
              ),
            ),
          ),
        ),
      );

      final secondTop = tester.getTopLeft(find.byKey(secondKey)).dy;
      final lastTop = tester.getTopLeft(find.byKey(lastKey)).dy;

      expect(lastTop, secondTop + 20);
    });
  });
}
