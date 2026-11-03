import 'package:image_picker/image_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Persists the image-picker request context and recovers files returned after
/// Android recreates the app Activity while the external picker is open.
class ImagePickerRecovery {
  ImagePickerRecovery._();

  static const String _pendingContextKey = 'image_picker_pending_context';
  static const String _recoveredPrefix = 'image_picker_recovered_';

  static String _recoveredKey(String context) => '$_recoveredPrefix$context';

  static Future<T> launch<T>({
    required String context,
    required Future<T> Function() picker,
  }) async {
    SharedPreferences? preferences;
    try {
      preferences = await SharedPreferences.getInstance();
      await preferences.setString(_pendingContextKey, context);
    } catch (_) {
      // Picking should remain available if local preference storage fails.
    }

    try {
      return await picker();
    } finally {
      try {
        if (preferences != null &&
            preferences.getString(_pendingContextKey) == context) {
          await preferences.remove(_pendingContextKey);
        }
      } catch (_) {
        // A cleanup failure must not discard a successful picker result.
      }
    }
  }

  /// Must be called after Flutter/plugin initialization and before runApp.
  /// This captures image_picker's Android lost-data result even when the app
  /// restarts onto its normal startup route instead of the originating page.
  static Future<void> captureLostDataAtStartup() async {
    try {
      final preferences = await SharedPreferences.getInstance();
      final context = preferences.getString(_pendingContextKey);
      if (context == null || context.isEmpty) return;

      final response = await ImagePicker().retrieveLostData();
      if (response.isEmpty) {
        await preferences.remove(_pendingContextKey);
        return;
      }

      final files = response.files ?? const <XFile>[];
      if (files.isNotEmpty) {
        await preferences.setStringList(
          _recoveredKey(context),
          files.map((file) => file.path).toList(growable: false),
        );
      }
      await preferences.remove(_pendingContextKey);
    } catch (_) {
      // Leave the context marker in place so the originating screen can retry.
    }
  }

  static Future<List<XFile>> retrieve(String context) async {
    final preferences = await SharedPreferences.getInstance();
    final recoveredPaths = preferences.getStringList(_recoveredKey(context));
    if (recoveredPaths != null) {
      await preferences.remove(_recoveredKey(context));
      return recoveredPaths
          .where((path) => path.trim().isNotEmpty)
          .map((path) => XFile(path))
          .toList(growable: false);
    }

    if (preferences.getString(_pendingContextKey) != context) {
      return const <XFile>[];
    }

    final response = await ImagePicker().retrieveLostData();
    await preferences.remove(_pendingContextKey);
    if (response.isEmpty) return const <XFile>[];
    return response.files ?? const <XFile>[];
  }
}
