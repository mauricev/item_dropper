import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:item_dropper/item_dropper.dart';
import 'package:item_dropper/src/common/keyboard_navigation_manager.dart';

class _TrackingScrollController extends ScrollController {
  int clientChecks = 0;

  @override
  bool get hasClients {
    clientChecks++;
    return false;
  }
}

void main() {
  for (final key in [
    LogicalKeyboardKey.arrowDown,
    LogicalKeyboardKey.arrowUp,
  ]) {
    for (final disposeBeforeFrame in [false, true]) {
      testWidgets(
        '${key.keyLabel} checks live mounted state: disposed=$disposeBeforeFrame',
        (tester) async {
          late BuildContext ownerContext;
          await tester.pumpWidget(
            Builder(
              builder: (context) {
                ownerContext = context;
                return const SizedBox.shrink();
              },
            ),
          );
          final controller = _TrackingScrollController();
          addTearDown(controller.dispose);
          var mountedChecks = 0;
          final manager = KeyboardNavigationManager<int>(
            onRequestRebuild: tester.binding.scheduleFrame,
            onEscape: () {},
          );
          manager.handleKeyEvent(
            event: KeyDownEvent(
              physicalKey: key == LogicalKeyboardKey.arrowDown
                  ? PhysicalKeyboardKey.arrowDown
                  : PhysicalKeyboardKey.arrowUp,
              logicalKey: key,
              timeStamp: Duration.zero,
            ),
            filteredItems: const [
              ItemDropperItem<int>(value: 1, label: 'One'),
              ItemDropperItem<int>(value: 2, label: 'Two'),
            ],
            scrollController: controller,
            isMounted: () {
              mountedChecks++;
              return ownerContext.mounted;
            },
            isDropdownOpen: true,
          );
          expect(mountedChecks, 0);
          expect(controller.clientChecks, 0);
          if (disposeBeforeFrame) {
            await tester.pumpWidget(const SizedBox.shrink());
          } else {
            await tester.pump();
          }
          expect(ownerContext.mounted, !disposeBeforeFrame);
          expect(mountedChecks, 1);
          expect(controller.clientChecks, disposeBeforeFrame ? 0 : 1);
          expect(tester.takeException(), isNull);
        },
      );
    }
  }
}
