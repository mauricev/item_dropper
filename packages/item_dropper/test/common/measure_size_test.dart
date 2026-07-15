import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:item_dropper/src/common/measure_size.dart';

void main() {
  testWidgets('does not measure after being disposed', (tester) async {
    final key = GlobalKey<MeasureSizeState>();
    var measurementCount = 0;

    await tester.pumpWidget(
      MaterialApp(
        home: MeasureSize(
          key: key,
          onChange: (_) => measurementCount++,
          child: const SizedBox(width: 100, height: 40),
        ),
      ),
    );

    expect(measurementCount, 1);

    final state = key.currentState!;
    state.build(state.context);
    await tester.pumpWidget(const SizedBox.shrink());

    expect(measurementCount, 1);
    expect(tester.takeException(), isNull);
  });
}
