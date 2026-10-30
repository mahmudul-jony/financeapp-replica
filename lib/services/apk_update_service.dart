import 'dart:async';
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';

class ApkUpdateService {
  static const MethodChannel _channel =
      MethodChannel('com.example.financeapp/app_updater');

  /// Downloads APK file to app cache directory with streaming progress support.
  Future<File?> downloadApk(
    String downloadUrl, {
    void Function(double progress)? onProgress,
  }) async {
    final client = http.Client();
    IOSink? sink;

    try {
      final tempDir = await getTemporaryDirectory();
      final apkFile = File('${tempDir.path}/financeapp_update.apk');

      // Delete any previous partial or old download
      if (await apkFile.exists()) {
        try {
          await apkFile.delete();
        } catch (_) {}
      }

      final request = http.Request('GET', Uri.parse(downloadUrl));
      request.headers['User-Agent'] = 'OneWallet';

      final response = await client.send(request).timeout(
            const Duration(seconds: 30),
          );

      if (response.statusCode != 200) {
        return null;
      }

      final totalBytes = response.contentLength ?? 0;
      int receivedBytes = 0;

      sink = apkFile.openWrite();

      await for (final chunk in response.stream) {
        sink.add(chunk);
        receivedBytes += chunk.length;

        if (totalBytes > 0 && onProgress != null) {
          final progress = (receivedBytes / totalBytes).clamp(0.0, 1.0);
          onProgress(progress);
        }
      }

      await sink.flush();
      await sink.close();
      sink = null;

      if (totalBytes > 0 && receivedBytes < totalBytes) {
        // Download was interrupted or incomplete
        try {
          await apkFile.delete();
        } catch (_) {}
        return null;
      }

      return apkFile;
    } catch (e) {
      return null;
    } finally {
      if (sink != null) {
        try {
          await sink.close();
        } catch (_) {}
      }
      client.close();
    }
  }

  /// Triggers Android Package Installer confirmation flow using FileProvider
  Future<void> installApk(File apkFile) async {
    if (!await apkFile.exists()) {
      throw Exception('APK file not found at: ${apkFile.path}');
    }

    try {
      final result = await _channel.invokeMethod<bool>(
        'installApk',
        {'filePath': apkFile.path},
      );

      if (result != true) {
        throw Exception('Failed to start package installer');
      }
    } on PlatformException catch (e) {
      throw Exception('Installation error: ${e.message}');
    }
  }
}
