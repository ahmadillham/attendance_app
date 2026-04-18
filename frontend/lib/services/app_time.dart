import 'package:flutter/material.dart';

/// Global time mocker service.
/// ─────────────────────────────────────────────
/// When [_mockDateTime] is null, all calls return real system time.
/// When set, all calls return the mock time instead.
///
/// Usage:
///   AppTime.now()        — replacement for DateTime.now()
///   AppTime.timeOfDay()  — replacement for TimeOfDay.now()
///   AppTime.setMock(dt)  — activate mock
///   AppTime.clearMock()  — deactivate mock
class AppTime {
  static DateTime? _mockDateTime;

  /// Returns mock time if set, otherwise real system time.
  static DateTime now() => _mockDateTime ?? DateTime.now();

  /// Returns TimeOfDay from mock or system clock.
  static TimeOfDay timeOfDay() {
    final dt = now();
    return TimeOfDay(hour: dt.hour, minute: dt.minute);
  }

  /// Whether time mocking is currently active.
  static bool get isMocked => _mockDateTime != null;

  /// The current mock value (null if not mocked).
  static DateTime? get mockValue => _mockDateTime;

  /// Set a mock date/time that replaces all system time calls.
  static void setMock(DateTime dateTime) {
    _mockDateTime = dateTime;
  }

  /// Clear the mock and revert to real system time.
  static void clearMock() {
    _mockDateTime = null;
  }
}
