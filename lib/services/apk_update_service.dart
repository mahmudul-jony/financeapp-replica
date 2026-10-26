/// APK ডাউনলোড এবং Android প্যাকেজ ইনস্টলার দিয়ে আপডেট করার সার্ভিস।
///
/// গিঠব রিলিজ থেকে APK অ্যাসেট ডাউনলোড করে অ্যাপের ডকুমেন্টস ডিরেক্টরিতে সংরক্ষণ করে,
/// তারপরে সিস্টেমের প্যাকেজ ইনস্টলার দিয়ে ইনস্টল করার জন্য উ proclamery করার জন্য তৈরি।
import 'dart:io';

import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'package:url_launcher/url_launcher.dart';

class ApkUpdateService {
  /// APK ফাইল ডাউনলোড করে অ্যাপের ডকুমেন্টস ডিরেক্টরিতে সংরক্ষণ করে।
  ///
  /// সফল হলে ডাউনলোড করা ফাইলের `File` অবজেক্ট রিটার্ন করে, অন্যথায় `null`।
  Future<File?> downloadApk(String downloadUrl) async {
    try {
      final dir = await getApplicationDocumentsDirectory();
      final apkFile = File('${dir.path}/financeapp_update.apk');

      final response = await http.get(Uri.parse(downloadUrl)).timeout(
        const Duration(seconds: 30),
      );

      if (response.statusCode == 200) {
        await apkFile.writeAsBytes(response.bodyBytes);
        return apkFile;
      }

      return null;
    } catch (e) {
      return null;
    }
  }

  /// ডাউনলোড করা APK ফাইলটি Android প্যাকেজ ইনস্টলার দিয়েOpened কনফার্ম করার প্রক্রিয়া শুরু করে।
  ///
  /// `url_launcher` 6.x API-তে `canLaunchUrl`/`launchUrl` ব্যবহার করতে হয়,
  /// যাতে deprecated warning এড়িয়ে যাওয়া যায় এবং সেরা কম্প্যাটিবিলিটি বজায় রাখা হয়。
  Future<void> installApk(File apkFile) async {
    final Uri fileUri = Uri.file(apkFile.path);

    if (await canLaunchUrl(fileUri)) {
      await launchUrl(fileUri);
    } else {
      throw Exception('APK ফাইল খোলার জন্য URLs লঞ্চ করা সম্ভব নেই');
    }
  }
}