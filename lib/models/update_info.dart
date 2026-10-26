/// আপডেট情報ের মডেল ক্লাস।
///
/// GitHub Release API থেকে প্রাপ্ত তথ্য এবং ইনস্টল করা App-এর ভার্সন کےその בבסিসে
/// আপডেটের availability নিরূপণ করে। APK ডাউনলোড বা ইনস্টলেশন এখনই ইমপ্লিমেন্ট করা হয়নি।
enum UpdateStatus {
  initial,   // এখনও চেক করা হয়নি
  loading,   // চেক চলছে
  success,   // সফলভাবে চেক completed (আপডেট আছে বা নেই)
  noUpdate,  // আপডেট পাওয়া যায়নি (বর্তমান ভার্সনই লেটেস্ট)
  error,     // নেটওয়ার্ক বা রেসপন্স এরর
}

class UpdateInfo {
  final bool isUpdateAvailable; // নতুন ভার্সন আছে কিনা
  final String latestVersion;   // গিঠব লেটেস্ট রিলিজ ট্যাগ ভার্সন (v prefix ছাড়া)
  final String currentVersion;  // ইনস্টল করা App-এর ভার্সন (build number ছাড়া)
  final String releaseUrl;      // GitHub রিলিজ পেজ URL (html_url)
  final String? apkDownloadUrl; // APK অ্যাসেটের ডাউনলোড URL (যদি থাকে)
  final UpdateStatus status;    // বর্তমান স্ট্যাটাস
  final String? errorMessage;   // এরর মেসেজ (status == error হলে)

  const UpdateInfo({
    required this.isUpdateAvailable,
    required this.latestVersion,
    required this.currentVersion,
    required this.releaseUrl,
    this.apkDownloadUrl,
    required this.status,
    this.errorMessage,
  });

  factory UpdateInfo.initial() => const UpdateInfo(
        isUpdateAvailable: false,
        latestVersion: '',
        currentVersion: '',
        releaseUrl: '',
        status: UpdateStatus.initial,
      );

  factory UpdateInfo.loading() => const UpdateInfo(
        isUpdateAvailable: false,
        latestVersion: '',
        currentVersion: '',
        releaseUrl: '',
        status: UpdateStatus.loading,
      );

  factory UpdateInfo.noUpdate(String currentVersion) => UpdateInfo(
        isUpdateAvailable: false,
        latestVersion: '',
        currentVersion: currentVersion,
        releaseUrl: '',
        status: UpdateStatus.noUpdate,
      );

  factory UpdateInfo.error(String currentVersion, String errorMessage) =>
      UpdateInfo(
        isUpdateAvailable: false,
        latestVersion: '',
        currentVersion: currentVersion,
        releaseUrl: '',
        status: UpdateStatus.error,
        errorMessage: errorMessage,
      );
}
