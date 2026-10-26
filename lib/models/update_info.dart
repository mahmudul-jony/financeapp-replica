/// Model representing update check status and metadata.
enum UpdateStatus {
  initial,   // Check hasn't run yet
  loading,   // Checking in progress
  success,   // Check completed successfully
  noUpdate,  // Current version is up to date
  error,     // Network or response error
}

class UpdateInfo {
  final bool isUpdateAvailable;
  final String latestVersion;   // Latest GitHub release tag/version
  final String currentVersion;  // Currently installed version (e.g. "1.0.1+3")
  final String releaseUrl;      // GitHub release webpage URL
  final String? apkDownloadUrl; // Direct APK download URL
  final UpdateStatus status;
  final String? errorMessage;
  final String? releaseNotes;

  const UpdateInfo({
    required this.isUpdateAvailable,
    required this.latestVersion,
    required this.currentVersion,
    required this.releaseUrl,
    this.apkDownloadUrl,
    required this.status,
    this.errorMessage,
    this.releaseNotes,
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
