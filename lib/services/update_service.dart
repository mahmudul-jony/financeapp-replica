/// GitHub Release-ভিত্তিক আপডেট চেক সার্ভিস।
///
/// `https://api.github.com/repos/mahmudul-jony/financeapp-replica/releases/latest`
/// এন্ডপয়েন্ট থেকে লেটেস্ট রিলিজের তথ্য সংগ্রহ করে।
///
/// শুধু versiòn-চেক ইমপ্লিমেন্ট করা হয়েছে। APK ডাউনলোড বা ইনস্টলেশন এখনই করা হয়নি।
import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:package_info_plus/package_info_plus.dart';

import '../models/update_info.dart';

class UpdateService {
  /// গিঠব রেলিজ API এন্ডপয়েন্ট
  static const String _githubApiUrl =
      'https://api.github.com/repos/mahmudul-jony/financeapp-replica/releases/latest';

  /// 앱ের বর্তমান ভার্সন ও গিঠব লেটেস্ট রিলিজের ভার্সন তুলনা করে আপডেট তথ্য রিটার্ন করে।
  Future<UpdateInfo> checkForUpdates() async {
    // ১. পাবস্পেক.yaml থেকে ইনস্টল করা App-এর ভার্সন সংগ্রহ (বিল্ড নম্বর ছাড়া)
    final packageInfo = await PackageInfo.fromPlatform();
    final currentVersion = packageInfo.version; // 예: "1.0.0" (বিল্ড নম্বর ছাড়া)
    // বিল্ড নম্বর (packageInfo.buildNumber) তুলনায় ব্যবহার করা হয়নি,
    // যাতে 1.0.0+1 এর "+1"-কে সরাসরি ট্যাগ ভার্সনের সাথে তুলনা করে ভুল সিদ্ধান্ত না নিতে হয়।

    try {
      // ২. গিঠব API থেকে লেটেস্ট রিলিজ সংগ্রহ
      final response = await http.get(
        Uri.parse(_githubApiUrl),
        headers: {
          'Accept': 'application/vnd.github+json',
          'User-Agent': 'FinanceApp',
        },
      ).timeout(const Duration(seconds: 15));

      if (response.statusCode != 200) {
        return UpdateInfo.error(
          currentVersion,
          'গিঠব API এরর: স্ট্যাটাস কোড ${response.statusCode}',
        );
      }

      final data = jsonDecode(response.body) as Map<String, dynamic>;

      // রিলিজ ট্যাগ ন্যામ (যেমন: "v1.0.1" বা "1.0.1")
      final tagName = (data['tag_name'] as String? ?? '').trim();
      // রিলিজ পেজ URL
      final releaseUrl = (data['html_url'] as String? ?? '');

      // APK অ্যাসেটের ডাউনলোড URL সংগ্রহ (যদি থাকে)
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

      // ট্যাগ থেকে 'v' প্রিফিক্স সরিয়ে শুধু ভার্সন 부분 নেওয়া
      final versionWithoutPrefix =
    tagName.startsWith('v') ? tagName.substring(1) : tagName;

final latestVersion = versionWithoutPrefix.split('+').first;

      // ৩. ভার্সন তুলনা (বিল্ড নম্বর berücksicht করা হবে না)
      final isUpdateAvailable = _isVersionNewer(latestVersion, currentVersion);

      if (!isUpdateAvailable) {
        return UpdateInfo.noUpdate(currentVersion);
      }

      return UpdateInfo(
        isUpdateAvailable: true,
        latestVersion: latestVersion,
        currentVersion: currentVersion,
        releaseUrl: releaseUrl,
        apkDownloadUrl: apkDownloadUrl,
        status: UpdateStatus.success,
      );
    } on FormatException catch (e) {
      return UpdateInfo.error(currentVersion, 'ইনভ্যালিড রেসপন্স: ${e.message}');
    } catch (e) {
      return UpdateInfo.error(currentVersion, 'নেটওয়ার্ক এরর: $e');
    }
  }

  /// দুটি সেমান্টিক ভার্সন String তুলনা করে `latest` বড় কি না চেক করে।
  ///
  /// শুধু major.minor.patch ডিবিসি ব্যবহার করে, বিল্ড নম্বর উপেক্ষা করে।
  /// উদাহরণ: "1.0.1" vs "1.0.0" → true; "1.0.0" vs "1.0.0" → false
  bool _isVersionNewer(String latest, String current) {
    // numeric portion-এ split,inton ? 0 : parsed
    final latestParts = _parseVersionParts(latest);
    final currentParts = _parseVersionParts(current);

    for (int i = 0; i < 3; i++) {
      final l = latestParts[i];
      final c = currentParts[i];
      if (l > c) return true;
      if (l < c) return false;
    }
    return false; // সমান হলে আপডেট প্রয়োজন নেই
  }

  /// "1.0.1"-ফরম্যাটের স্ট্রিংকে [int, int, int] লিস্টে রূপান্তর করে।
  /// অশুধু বা অপূর্ণ হলে ০ দিয়ে পূরণ করে।
  List<int> _parseVersionParts(String version) {
    final parts = version.split('.');
    return List.generate(3, (i) {
      if (i >= parts.length) return 0;
      return int.tryParse(parts[i].trim()) ?? 0;
    });
  }
}
