/// APK ডাউনলোড এবং Android প্যাকেজ ইনস্টলার দিয়ে আপডেট করার সার্ভিস।
///
/// গিঠব রিলিজ থেকে APK অ্যাসেট ডাউনলোড করে অ্যাপের ডকুমেন্টস ডিরেক্টরিতে সংরক্ষণ করে,
/// তারপরে সিস্টেমের প্যাকেজ ইনস্টলার দিয়ে ইনস্টল করাস্থাপন করে।
import 'dart:io';

import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'package:open_file_plus/open_file_plus.dart';

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

  /// ডাউনলোড করা APK ফাইলটি Android প্যাকেজ ইনস্টলার দিয়ে খোলা করে।
  ///
  /// ইউজারকে ইনস্টলেশনের জন্য কনফার্ম করতে হবে (সাইলেন্ট ইনস্টল নয়)।
  Future<void> installApk(File apkFile) async {
    await OpenFile.open(apkFile.path);
  }
}
