import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:package_info_plus/package_info_plus.dart';

import '../models/update_info.dart';

class UpdateService {
  /// GitHub release API endpoint
  static const String _githubApiUrl =
      'https://api.github.com/repos/mahmudul-jony/financeapp-replica/releases/latest';

  /// Compares current installed version with the latest GitHub release
  Future<UpdateInfo> checkForUpdates() async {
    final packageInfo = await PackageInfo.fromPlatform();
    final currentVersionOnly = packageInfo.version.trim();
    final currentBuildOnly = packageInfo.buildNumber.trim();
    final currentFullVersion = currentBuildOnly.isNotEmpty
        ? '$currentVersionOnly+$currentBuildOnly'
        : currentVersionOnly;

    try {
      final response = await http.get(
        Uri.parse(_githubApiUrl),
        headers: {
          'Accept': 'application/vnd.github+json',
          'User-Agent': 'FinanceApp',
        },
      ).timeout(const Duration(seconds: 15));

      if (response.statusCode != 200) {
        return UpdateInfo.error(
          currentFullVersion,
          'GitHub API Error: HTTP ${response.statusCode}',
        );
      }

      final data = jsonDecode(response.body) as Map<String, dynamic>;

      final rawTagName = (data['tag_name'] as String? ?? '').trim();
      final releaseUrl = (data['html_url'] as String? ?? '').trim();
      final releaseBody = (data['body'] as String? ?? '').trim();

      // Find APK download URL from release assets
      String? apkDownloadUrl;
      final assets = data['assets'] as List<dynamic>? ?? [];
      for (final asset in assets) {
        if (asset is! Map<String, dynamic>) continue;
        final name = (asset['name'] as String? ?? '').toLowerCase();
        if (name.endsWith('.apk')) {
          apkDownloadUrl = asset['browser_download_url'] as String?;
          break;
        }
      }

      // Remove leading 'v' or 'V' prefix
      final latestFullVersion = rawTagName.startsWith(RegExp(r'^[vV]'))
          ? rawTagName.substring(1).trim()
          : rawTagName;

      if (latestFullVersion.isEmpty) {
        return UpdateInfo.noUpdate(currentFullVersion);
      }

      final bool isUpdateAvailable = isVersionNewer(
        latestStr: latestFullVersion,
        currentVersionStr: currentVersionOnly,
        currentBuildStr: currentBuildOnly,
      );

      if (!isUpdateAvailable) {
        return UpdateInfo.noUpdate(currentFullVersion);
      }

      return UpdateInfo(
        isUpdateAvailable: true,
        latestVersion: latestFullVersion,
        currentVersion: currentFullVersion,
        releaseUrl: releaseUrl,
        apkDownloadUrl: apkDownloadUrl,
        status: UpdateStatus.success,
        releaseNotes: releaseBody.isNotEmpty ? releaseBody : null,
      );
    } on FormatException catch (e) {
      return UpdateInfo.error(currentFullVersion, 'Invalid response format: ${e.message}');
    } catch (e) {
      return UpdateInfo.error(currentFullVersion, 'Network error: $e');
    }
  }

  /// Parses and compares semver and build number
  /// Returns true if latest version is strictly greater than current version
  static bool isVersionNewer({
    required String latestStr,
    required String currentVersionStr,
    String? currentBuildStr,
  }) {
    final latestParsed = _parseVersion(latestStr);
    final currentParsed = _parseVersion(
      currentBuildStr != null && currentBuildStr.isNotEmpty
          ? '$currentVersionStr+$currentBuildStr'
          : currentVersionStr,
    );

    return latestParsed.compareTo(currentParsed) > 0;
  }

  static _ParsedVersion _parseVersion(String versionString) {
    var raw = versionString.trim();
    if (raw.startsWith(RegExp(r'^[vV]'))) {
      raw = raw.substring(1).trim();
    }

    int build = 0;
    if (raw.contains('+')) {
      final parts = raw.split('+');
      raw = parts[0].trim();
      if (parts.length > 1) {
        build = int.tryParse(parts[1].trim()) ?? 0;
      }
    }

    final segments = raw.split('.');
    final parts = List<int>.generate(3, (i) {
      if (i < segments.length) {
        final match = RegExp(r'^\d+').firstMatch(segments[i].trim());
        if (match != null) {
          return int.tryParse(match.group(0)!) ?? 0;
        }
      }
      return 0;
    });

    return _ParsedVersion(parts: parts, buildNumber: build);
  }
}

class _ParsedVersion {
  final List<int> parts; // [major, minor, patch]
  final int buildNumber;

  const _ParsedVersion({required this.parts, required this.buildNumber});

  int compareTo(_ParsedVersion other) {
    for (int i = 0; i < 3; i++) {
      if (parts[i] > other.parts[i]) return 1;
      if (parts[i] < other.parts[i]) return -1;
    }
    if (buildNumber > other.buildNumber) return 1;
    if (buildNumber < other.buildNumber) return -1;
    return 0;
  }
}
