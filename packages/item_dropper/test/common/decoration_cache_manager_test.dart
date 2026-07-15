import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:item_dropper/src/common/decoration_cache_manager.dart';

void main() {
  group('DecorationCacheManager', () {
    test('returns custom decoration without replacing it', () {
      final manager = DecorationCacheManager();
      const customDecoration = BoxDecoration(color: Colors.red);

      expect(
        manager.get(isFocused: false, customDecoration: customDecoration),
        same(customDecoration),
      );
    });

    test('reuses cached decoration when inputs do not change', () {
      final manager = DecorationCacheManager();

      final first = manager.get(isFocused: false);
      final second = manager.get(isFocused: false);

      expect(second, same(first));
    });

    test('rebuilds cached decoration when focus changes', () {
      final manager = DecorationCacheManager();

      final unfocused = manager.get(isFocused: false);
      final focused = manager.get(isFocused: true);

      expect(focused, isNot(same(unfocused)));
      expect(focused.border, isA<Border>());
    });

    test('rebuilds cached decoration when styling inputs change', () {
      final manager = DecorationCacheManager();

      final first = manager.get(
        isFocused: false,
        borderRadius: 8,
        borderWidth: 1,
        gradientEndColor: Colors.grey,
      );
      final second = manager.get(
        isFocused: false,
        borderRadius: 10,
        borderWidth: 1,
        gradientEndColor: Colors.grey,
      );

      expect(second, isNot(same(first)));
    });

    test('uses custom gradient end color', () {
      final manager = DecorationCacheManager();

      final decoration = manager.get(
        isFocused: false,
        gradientEndColor: const Color(0xFFE5E5E5),
      );

      final gradient = decoration.gradient as LinearGradient;
      expect(gradient.colors, [Colors.white, const Color(0xFFE5E5E5)]);
    });

    test('invalidate clears cache', () {
      final manager = DecorationCacheManager();

      final first = manager.get(isFocused: false);
      manager.invalidate();
      final second = manager.get(isFocused: false);

      expect(second, isNot(same(first)));
    });
  });
}
