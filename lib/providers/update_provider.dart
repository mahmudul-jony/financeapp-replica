// আপডেট চেকের স্টেট ম্যানেজমেন্ট প্রোভাইডার।
//
// FinanceProvider- এর প্যাটার্ন অনুসরণ করে তৈরি। বিল্ড মেথদের মধ্যে
// context.watch<UpdateProvider>() এবং বাটন ক্লিক/ফাংশন কলের জন্য
// context.read<UpdateProvider>() ব্যবহার করা উচিত।
import 'package:flutter/material.dart';

import '../services/update_service.dart';
import '../services/apk_update_service.dart';
import '../models/update_info.dart';

class UpdateProvider extends ChangeNotifier {
  final UpdateService _updateService = UpdateService();
  final ApkUpdateService _apkUpdateService = ApkUpdateService();

  UpdateInfo _updateInfo = UpdateInfo.initial();

  bool _isDownloading = false;
  double _downloadProgress = 0.0;

  UpdateInfo get updateInfo => _updateInfo;

  bool get isLoading => _updateInfo.status == UpdateStatus.loading;
  bool get isUpdateAvailable => _updateInfo.isUpdateAvailable;
  bool get hasError => _updateInfo.status == UpdateStatus.error;
  bool get noUpdate => _updateInfo.status == UpdateStatus.noUpdate;

  bool get isDownloading => _isDownloading;
  double get downloadProgress => _downloadProgress;

  /// গিঠব থেকে লেটেস্ট রিলিজ চেক করে আপডেট তথ্য আপডেট করে।
  Future<void> checkForUpdates() async {
    _updateInfo = UpdateInfo.loading();
    notifyListeners();

    _updateInfo = await _updateService.checkForUpdates();
    notifyListeners();
  }

  /// লেটেস্ট রিলিজ থেকে APK ডাউনলোড করে এবং Android প্যাকেজ ইনস্টলার দিয়ে ইনস্টল করার প্রক্রিয়া শুরু করে।
  Future<void> downloadAndInstallUpdate() async {
    final info = _updateInfo;
    if (!info.isUpdateAvailable || info.apkDownloadUrl == null) return;

    _isDownloading = true;
    _downloadProgress = 0.0;
    notifyListeners();

    try {
      final apkFile = await _apkUpdateService.downloadApk(info.apkDownloadUrl!);
      if (apkFile == null) {
        _isDownloading = false;
        _downloadProgress = 0.0;
        notifyListeners();
        return;
      }

      _downloadProgress = 1.0;
      notifyListeners();

      await _apkUpdateService.installApk(apkFile);
    } catch (e) {
      // ডাউনলোড বা ইনস্টলেশন এরর হলে শুধু স্টেট রিসেট করা হয়, UI-তে এরর দেখানোর জন্য UpdateInfo পরিবর্তন করা হয় না
    } finally {
      _isDownloading = false;
      _downloadProgress = 0.0;
      notifyListeners();
    }
  }
}
