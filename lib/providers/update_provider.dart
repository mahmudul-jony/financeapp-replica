// আপডেট চেকের স্টেট ম্যানেজমেন্ট প্রোভাইডার।
//
// FinanceProvider- এর প্যাটার্ন অনুসরণ করে তৈরি। বিল্ড মেথদের মধ্যে
// context.watch<UpdateProvider>() এবং বাটন ক্লিক/ফাংশন কলের জন্য
// context.read<UpdateProvider>() ব্যবহার করা উচিত।
import 'package:flutter/material.dart';

import '../services/update_service.dart';
import '../models/update_info.dart';

class UpdateProvider extends ChangeNotifier {
  final UpdateService _updateService = UpdateService();

  UpdateInfo _updateInfo = UpdateInfo.initial();

  UpdateInfo get updateInfo => _updateInfo;

  bool get isLoading => _updateInfo.status == UpdateStatus.loading;
  bool get isUpdateAvailable => _updateInfo.isUpdateAvailable;
  bool get hasError => _updateInfo.status == UpdateStatus.error;
  bool get noUpdate => _updateInfo.status == UpdateStatus.noUpdate;

  /// গিঠব থেকে লেটেস্ট রিলিজ চেক করে আপডেট তথ্য আপডেট করে।
  Future<void> checkForUpdates() async {
    _updateInfo = UpdateInfo.loading();
    notifyListeners();

    _updateInfo = await _updateService.checkForUpdates();
    notifyListeners();
  }
}
