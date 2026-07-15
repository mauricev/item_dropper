typedef ItemDropperValueEquals<T> = bool Function(T current, T incoming);

/// Shared helper for controlled widgets that mirror parent-owned values.
class ControlledValueSync {
  const ControlledValueSync._();

  /// Returns true when an incoming widget value represents an external update
  /// that should be copied into internal state.
  static bool shouldSync<T>({
    required T current,
    required T incoming,
    required ItemDropperValueEquals<T> equals,
  }) {
    return !equals(current, incoming);
  }
}
