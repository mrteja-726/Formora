import 'package:flutter/services.dart';

class DesktopAutofillService {
  static const MethodChannel _channel = MethodChannel('formora/autofill');

  /// Checks if macOS Accessibility permissions are trusted.
  /// On Windows, always returns true.
  static Future<bool> isAccessibilityTrusted() async {
    try {
      final bool? trusted = await _channel.invokeMethod<bool>('isAccessibilityTrusted');
      return trusted ?? true;
    } on PlatformException catch (_) {
      return true; // Fallback to true if not supported
    }
  }

  /// Retrieves details of the currently focused control/element from the OS.
  static Future<Map<String, dynamic>?> getFocusedElement() async {
    try {
      final Map<dynamic, dynamic>? element =
          await _channel.invokeMethod<Map<dynamic, dynamic>>('getFocusedElement');
      if (element == null) return null;
      return Map<String, dynamic>.from(element);
    } on PlatformException catch (_) {
      return null;
    }
  }

  /// Triggers OS-level autofill on the focused element with the given value.
  static Future<bool> triggerAutofill(String value) async {
    try {
      final bool? success = await _channel.invokeMethod<bool>('triggerAutofill', {
        'value': value,
      });
      return success ?? false;
    } on PlatformException catch (_) {
      return false;
    }
  }
}
