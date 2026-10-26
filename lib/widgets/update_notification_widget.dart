import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

import 'package:financeapp/app_constants.dart';
import 'package:financeapp/models/update_info.dart';
import 'package:financeapp/providers/update_provider.dart';

class UpdateNotificationWidget extends StatelessWidget {
  const UpdateNotificationWidget({super.key});

  @override
  Widget build(BuildContext context) {
    final updateProvider = context.watch<UpdateProvider>();
    final info = updateProvider.updateInfo;

    // Silent on initial, loading, or when no update is found
    if (info.status == UpdateStatus.initial ||
        info.status == UpdateStatus.loading ||
        info.status == UpdateStatus.noUpdate) {
      return const SizedBox.shrink();
    }

    if (info.status == UpdateStatus.error) {
      // Keep errors non-intrusive or hidden unless explicitly needed
      return const SizedBox.shrink();
    }

    if (info.status == UpdateStatus.success && info.isUpdateAvailable) {
      return _buildUpdateAvailable(context, info, updateProvider);
    }

    return const SizedBox.shrink();
  }

  Widget _buildUpdateAvailable(
    BuildContext context,
    UpdateInfo info,
    UpdateProvider updateProvider,
  ) {
    final isDownloading = updateProvider.isDownloading;
    final progress = updateProvider.downloadProgress;
    final downloadError = updateProvider.downloadError;
    final percent = (progress * 100).toInt();

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
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
                Icons.system_update_rounded,
                color: AppColors.primaryPurple,
                size: 22,
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
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: AppColors.primaryPurple,
                  borderRadius: AppRadius.borderRadiusSmall,
                ),
                child: Text(
                  'v${info.latestVersion}',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
          AppSpacing.smallVerticalGap,
          Text(
            'বর্তমান: ${info.currentVersion} → নতুন: ${info.latestVersion}',
            style: AppTypography.caption.copyWith(
              color: AppColors.secondaryText,
            ),
          ),
          if (info.releaseNotes != null && info.releaseNotes!.isNotEmpty) ...[
            AppSpacing.smallVerticalGap,
            Text(
              info.releaseNotes!,
              style: AppTypography.caption.copyWith(
                color: AppColors.primaryText,
                fontStyle: FontStyle.italic,
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ],
          if (downloadError != null) ...[
            AppSpacing.smallVerticalGap,
            Text(
              downloadError,
              style: AppTypography.caption.copyWith(
                color: AppColors.expenseAlertText,
              ),
            ),
          ],
          AppSpacing.elementGap,
          if (isDownloading) ...[
            LinearProgressIndicator(
              value: progress > 0 ? progress : null,
              backgroundColor: AppColors.borderGrey,
              color: AppColors.primaryPurple,
            ),
            AppSpacing.smallVerticalGap,
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'ডাউনলোড হচ্ছে...',
                  style: AppTypography.caption.copyWith(
                    color: AppColors.secondaryText,
                  ),
                ),
                Text(
                  '$percent%',
                  style: AppTypography.caption.copyWith(
                    color: AppColors.primaryPurple,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            AppSpacing.smallVerticalGap,
          ],
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: isDownloading
                  ? null
                  : () async {
                      if (info.apkDownloadUrl != null) {
                        updateProvider.downloadAndInstallUpdate();
                      } else {
                        // Fallback to browser if direct APK asset is not attached
                        final uri = Uri.parse(info.releaseUrl);
                        if (await canLaunchUrl(uri)) {
                          await launchUrl(uri, mode: LaunchMode.externalApplication);
                        }
                      }
                    },
              icon: Icon(
                isDownloading ? Icons.downloading_rounded : Icons.update_rounded,
                size: 18,
                color: Colors.white,
              ),
              label: Text(
                isDownloading
                    ? 'ডাউনলোড চলছে ($percent%)...'
                    : 'আপডেট ইনস্টল করুন',
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w600,
                  fontSize: 14,
                ),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primaryPurple,
                shape: RoundedRectangleBorder(
                  borderRadius: AppRadius.borderRadiusMedium,
                ),
                padding: const EdgeInsets.symmetric(vertical: 12),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
