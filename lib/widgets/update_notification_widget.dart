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

    // Silent on initial, loading, no update, or error
    if (info.status == UpdateStatus.initial ||
        info.status == UpdateStatus.loading ||
        info.status == UpdateStatus.noUpdate ||
        info.status == UpdateStatus.error) {
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
    final percent = (progress * 100).toInt();

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: AppColors.primaryPurple.withValues(alpha: 0.2),
          width: 1.2,
        ),
        boxShadow: [
          BoxShadow(
            color: AppColors.primaryPurple.withValues(alpha: 0.08),
            blurRadius: 14,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 1. Title: New version available / নতুন ভার্সন উপলব্ধ
          const Row(
            children: [
              Icon(
                Icons.system_update_rounded,
                color: AppColors.primaryPurple,
                size: 20,
              ),
              SizedBox(width: 8),
              Text(
                'New version available',
                style: TextStyle(
                  color: AppColors.primaryText,
                  fontSize: 15,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),

          // 2. Current & New version line
          Text(
            'Current: ${info.currentVersion}  →  New: ${info.latestVersion}',
            style: const TextStyle(
              color: AppColors.secondaryText,
              fontSize: 13,
              fontWeight: FontWeight.w500,
            ),
          ),

          // Progress indicator while downloading
          if (isDownloading) ...[
            const SizedBox(height: 10),
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: progress > 0 ? progress : null,
                backgroundColor: AppColors.borderGrey,
                color: AppColors.primaryPurple,
                minHeight: 6,
              ),
            ),
          ],

          const SizedBox(height: 12),

          // 3. Right-aligned button: Update Now
          Align(
            alignment: Alignment.centerRight,
            child: ElevatedButton(
              onPressed: isDownloading
                  ? null
                  : () async {
                      if (info.apkDownloadUrl != null) {
                        updateProvider.downloadAndInstallUpdate();
                      } else {
                        final uri = Uri.parse(info.releaseUrl);
                        if (await canLaunchUrl(uri)) {
                          await launchUrl(uri, mode: LaunchMode.externalApplication);
                        }
                      }
                    },
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primaryPurple,
                foregroundColor: Colors.white,
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
                visualDensity: VisualDensity.compact,
              ),
              child: Text(
                isDownloading ? 'Downloading ($percent%)...' : 'Update Now',
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 13,
                  color: Colors.white,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
