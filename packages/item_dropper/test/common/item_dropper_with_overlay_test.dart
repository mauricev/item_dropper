import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:item_dropper/src/common/item_dropper_with_overlay.dart';

void main() {
  group('ItemDropperWithOverlay', () {
    testWidgets('does not dismiss when tapping inside field', (tester) async {
      var dismissCount = 0;

      await tester.pumpWidget(_OverlayHarness(onDismiss: () => dismissCount++));
      await tester.pump();

      await tester.tapAt(const Offset(20, 20));
      await tester.pump();

      expect(dismissCount, 0);
    });

    testWidgets('dismisses when tapping outside field', (tester) async {
      var dismissCount = 0;

      await tester.pumpWidget(_OverlayHarness(onDismiss: () => dismissCount++));
      await tester.pump();

      await tester.tapAt(const Offset(200, 200));
      await tester.pump();

      expect(dismissCount, 1);
    });
  });
}

class _OverlayHarness extends StatefulWidget {
  final VoidCallback onDismiss;

  const _OverlayHarness({required this.onDismiss});

  @override
  State<_OverlayHarness> createState() => _OverlayHarnessState();
}

class _OverlayHarnessState extends State<_OverlayHarness> {
  final OverlayPortalController _controller = OverlayPortalController();
  final LayerLink _layerLink = LayerLink();
  final GlobalKey _fieldKey = GlobalKey();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _controller.show();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: Scaffold(
        body: ItemDropperWithOverlay(
          layerLink: _layerLink,
          overlayController: _controller,
          fieldKey: _fieldKey,
          onDismiss: widget.onDismiss,
          inputField: SizedBox(
            key: _fieldKey,
            width: 100,
            height: 40,
            child: const Text('Field'),
          ),
          overlay: const SizedBox(
            width: 100,
            height: 40,
            child: Text('Overlay'),
          ),
        ),
      ),
    );
  }
}
