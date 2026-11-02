import 'package:flutter/foundation.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:url_launcher/url_launcher.dart';

import 'supabase_service.dart';

class AppUpdateRequirement {
  const AppUpdateRequirement({
    required this.isRequired,
    required this.currentVersion,
    required this.minimumVersion,
    required this.storeUrl,
    required this.message,
  });

  const AppUpdateRequirement.notRequired({
    this.currentVersion = '',
    this.minimumVersion = '',
  })  : isRequired = false,
        storeUrl = '',
        message = '';

  final bool isRequired;
  final String currentVersion;
  final String minimumVersion;
  final String storeUrl;
  final String message;
}

class AppUpdateService {
  AppUpdateService._();

  static final AppUpdateService instance = AppUpdateService._();

  Future<AppUpdateRequirement> check() async {
    try {
      final packageInfo = await PackageInfo.fromPlatform();
      final row = await SupabaseService()
          .client
          .from('app_update_policy')
          .select(
            'minimum_version, minimum_build, android_store_url, '
            'ios_store_url, web_update_url, message',
          )
          .eq('id', 'global')
          .maybeSingle();

      if (row == null) return const AppUpdateRequirement.notRequired();

      final minimumVersion = row['minimum_version']?.toString().trim() ?? '';
      final minimumBuild = _asInt(row['minimum_build']) ?? 0;
      if (minimumVersion.isEmpty) {
        return AppUpdateRequirement.notRequired(
          currentVersion: packageInfo.version,
        );
      }

      final versionTooOld = _compareVersions(packageInfo.version, minimumVersion) < 0;
      final sameVersionWithOldBuild =
          _compareVersions(packageInfo.version, minimumVersion) == 0 &&
              int.tryParse(packageInfo.buildNumber) != null &&
              int.parse(packageInfo.buildNumber) < minimumBuild;
      final isRequired = versionTooOld || sameVersionWithOldBuild;

      return AppUpdateRequirement(
        isRequired: isRequired,
        currentVersion: '${packageInfo.version}+${packageInfo.buildNumber}',
        minimumVersion: minimumVersion,
        storeUrl: _storeUrl(row),
        message: row['message']?.toString().trim().isNotEmpty == true
            ? row['message'].toString().trim()
            : 'يوجد إصدار جديد إلزامي من التطبيق. حدّث التطبيق للمتابعة.',
      );
    } catch (error, stack) {
      // A temporary network failure must not log users out or lock them out.
      // The next app resume checks the policy again.
      debugPrint('[AppUpdate] check skipped: $error');
      debugPrintStack(stackTrace: stack);
      return const AppUpdateRequirement.notRequired();
    }
  }

  String _storeUrl(Map<String, dynamic> row) {
    if (kIsWeb) return row['web_update_url']?.toString() ?? '';
    if (defaultTargetPlatform == TargetPlatform.iOS) {
      return row['ios_store_url']?.toString() ?? '';
    }
    return row['android_store_url']?.toString() ?? '';
  }

  static int? _asInt(dynamic value) {
    if (value is num) return value.toInt();
    return int.tryParse(value?.toString() ?? '');
  }

  static int _compareVersions(String left, String right) {
    final leftParts = _versionParts(left);
    final rightParts = _versionParts(right);
    final length = leftParts.length > rightParts.length
        ? leftParts.length
        : rightParts.length;
    for (var index = 0; index < length; index++) {
      final leftPart = index < leftParts.length ? leftParts[index] : 0;
      final rightPart = index < rightParts.length ? rightParts[index] : 0;
      if (leftPart != rightPart) return leftPart.compareTo(rightPart);
    }
    return 0;
  }

  static List<int> _versionParts(String version) => version
      .split('.')
      .map((part) => int.tryParse(part.replaceAll(RegExp(r'[^0-9]'), '')) ?? 0)
      .toList(growable: false);

  static Future<bool> openStore(String url) async {
    final uri = Uri.tryParse(url);
    if (uri == null || !uri.hasScheme) return false;
    return launchUrl(uri, mode: LaunchMode.externalApplication);
  }
}
