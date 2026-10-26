/// নতুন ভার্সন উপলব্ধ হলে UI-তে দেখানোর জন্য উইজেট।
///
/// বিদ্যমান স্ক্রিন বা ফাংশনালিটিতে অপ্রয়োজনীয় পরিবর্তন না করে এইウィজেটটি
/// যেকোনো স্ক্রিনে যোগ করা যায়। `UpdateProvider`-এর মাধ্যমে `context.watch`
/// ব্যবহার করে স্টেট derive করা হয়।
///
/// PROJECT_RULES অনুযায়ী: কালার বা টেক্সট স্টাইল হার্ডকোড করা হয়নি,
/// `AppColors`, `AppTypography`, `AppSpacing` ব্যবহার করা হয়েছে।
import 'package:flutter/material.dart';

import 'package:financeapp/app_constants.dart';
import 'package:financeapp/models/update_info.dart';
import 'package:financeapp/providers/update_provider.dart';
import 'package:provider/provider.dart';

class UpdateNotificationWidget extends StatelessWidget {
  const UpdateNotificationWidget({super.key});

  @override
  Widget build(BuildContext context) {
    final updateProvider = context.watch<UpdateProvider>();
    final info = updateProvider.updateInfo;

    switch (info.status) {
      case UpdateStatus.loading:
        return _buildLoading();
      case UpdateStatus.error:
        return _buildError(context, info.errorMessage ?? 'আপডেট জানা যায়নি');
      case UpdateStatus.initial:
      case UpdateStatus.noUpdate:
        return const SizedBox.shrink();
      case UpdateStatus.success:
        if (!info.isUpdateAvailable) return const SizedBox.shrink();
        return _buildUpdateAvailable(context, info, updateProvider);
    }
  }

  /// লোডিং স্ট্যাটের জন্য ছোট ইন্ডিকেটর
  Widget _buildLoading() {
    return const SizedBox(
      height: 24,
      child: Center(
        child: SizedBox(
          width: 16,
          height: 16,
          child: CircularProgressIndicator(strokeWidth: 2),
        ),
      ),
    );
  }

  /// এরর স্ট্যাটের জন্য মেসেজ
  Widget _buildError(BuildContext context, String message) {
    return Container(
      margin: AppSpacing.screenPaddingInsets,
      padding: AppSpacing.elementPaddingInsets,
      decoration: BoxDecoration(
        color: AppColors.expenseAlertBackground,
        borderRadius: AppRadius.borderRadiusMedium,
        border: Border.all(color: AppColors.borderGrey),
      ),
      child: Row(
        children: [
          const Icon(
            Icons.error_outline,
            color: AppColors.expenseAlertText,
            size: 18,
          ),
          AppSpacing.horizontalGap,
          Expanded(
            child: Text(
              'আপডেট চেক করতে সমস্যা হয়েছে: $message',
              style: AppTypography.caption.copyWith(
                color: AppColors.expenseAlertText,
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }

  /// নতুন ভার্সন উপলব্ধ থাকলে নোটিফিকেশন কার্ড
  Widget _buildUpdateAvailable(
    BuildContext context,
    UpdateInfo info,
    UpdateProvider updateProvider,
  ) {
    final isDownloading = updateProvider.isDownloading;
    final progress = updateProvider.downloadProgress;

    return Container(
      margin: AppSpacing.screenPaddingInsets,
      padding: AppSpacing.elementPaddingInsets,
      decoration: BoxDecoration(
        color: AppColors.softLightPurple,
        borderRadius: AppRadius.borderRadiusLarge,
        border: Border.all(color: AppColors.borderGrey),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(
                Icons.update,
                color: AppColors.primaryPurple,
                size: 20,
              ),
              AppSpacing.horizontalGap,
              Expanded(
                child: Text(
                  'নতুন ভার্সন উপলব্ধ!',
                  style: AppTypography.subTitle.copyWith(
                    color: AppColors.primaryPurple,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
          AppSpacing.smallVerticalGap,
          Text(
            'বর্তমান: ${info.currentVersion} → নতুন: ${info.latestVersion}',
            style: AppTypography.body.copyWith(
              color: AppColors.primaryText,
              fontSize: 14,
            ),
          ),
          AppSpacing.largeVerticalGap,
          if (isDownloading) ...[
            LinearProgressIndicator(
              value: progress,
              backgroundColor: AppColors.borderGrey,
              color: AppColors.primaryPurple,
            ),
            AppSpacing.smallVerticalGap,
            Text(
              'ডাউনলোড করা হচ্ছে...',
              style: AppTypography.caption.copyWith(
                color: AppColors.secondaryText,
              ),
            ),
            AppSpacing.largeVerticalGap,
          ],
          SizedBox(
            width: double.infinity,
            child: OutlinedButton(
              onPressed: isDownloading
                  ? null
                  : () {
                      updateProvider.downloadAndInstallUpdate();
                    },
              style: OutlinedButton.styleFrom(
                foregroundColor: AppColors.primaryPurple,
                side: const BorderSide(color: AppColors.primaryPurple),
                shape: RoundedRectangleBorder(
                  borderRadius: AppRadius.borderRadiusMedium,
                ),
                padding: const EdgeInsets.symmetric(vertical: 10),
              ),
              child: Text(
                isDownloading ? 'ডাউনলোড চলছে...' : 'আপডেট ডাউনলোড করুন',
                style: AppTypography.body.copyWith(
                  color: AppColors.primaryPurple,
                  fontSize: 14,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
