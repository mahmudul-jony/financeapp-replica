import 'package:flutter/material.dart';

import '../services/update_service.dart';
import '../services/apk_update_service.dart';
import '../models/update_info.dart';

class UpdateProvider extends ChangeNotifier {
  final UpdateService _updateService = UpdateService();
  final ApkUpdateService _apkUpdateService = ApkUpdateService();

  UpdateInfo _updateInfo = UpdateInfo.initial();
  DateTime? _lastCheckTime;

  bool _isDownloading = false;
  double _downloadProgress = 0.0;
  String? _downloadError;

  UpdateInfo get updateInfo => _updateInfo;

  bool get isLoading => _updateInfo.status == UpdateStatus.loading;
  bool get isUpdateAvailable => _updateInfo.isUpdateAvailable;
  bool get hasError => _updateInfo.status == UpdateStatus.error;
  bool get noUpdate => _updateInfo.status == UpdateStatus.noUpdate;

  bool get isDownloading => _isDownloading;
  double get downloadProgress => _downloadProgress;
  String? get downloadError => _downloadError;

  /// Checks for newer releases from GitHub.
  /// Set [silent] to true when checking in background/lifecycle resume to prevent UI flicker.
  Future<void> checkForUpdates({bool silent = false, bool force = false}) async {
    // Never interrupt an active APK download
    if (_isDownloading) return;

    final now = DateTime.now();
    if (!force && _lastCheckTime != null && now.difference(_lastCheckTime!).inSeconds < 15) {
      return; // Throttled to prevent rapid duplicate calls
    }
    _lastCheckTime = now;

    if (!silent && _updateInfo.status == UpdateStatus.initial) {
      _updateInfo = UpdateInfo.loading();
      notifyListeners();
    }

    try {
      final result = await _updateService.checkForUpdates();
      _updateInfo = result;
      _downloadError = null;
    } catch (e) {
      if (!silent) {
        _updateInfo = UpdateInfo.error(_updateInfo.currentVersion, e.toString());
      }
    } finally {
      notifyListeners();
    }
  }

  /// Downloads the release APK with live progress tracking and triggers Android's package installer.
  Future<void> downloadAndInstallUpdate() async {
    final info = _updateInfo;
    if (!info.isUpdateAvailable || info.apkDownloadUrl == null || _isDownloading) return;

    _isDownloading = true;
    _downloadProgress = 0.0;
    _downloadError = null;
    notifyListeners();

    try {
      final apkFile = await _apkUpdateService.downloadApk(
        info.apkDownloadUrl!,
        onProgress: (progress) {
          _downloadProgress = progress;
          notifyListeners();
        },
      );

      if (apkFile == null) {
        _downloadError = 'ডাউনলোড সম্পন্ন হতে পারেনি। অনুগ্রহ করে ইন্টারনেট সংযোগ চেক করুন।';
        _isDownloading = false;
        _downloadProgress = 0.0;
        notifyListeners();
        return;
      }

      _downloadProgress = 1.0;
      notifyListeners();

      await _apkUpdateService.installApk(apkFile);
    } catch (e) {
      _downloadError = 'ইনস্টলার শুরু করা সম্ভব হয়নি: $e';
    } finally {
      _isDownloading = false;
      _downloadProgress = 0.0;
      notifyListeners();
    }
  }
}
