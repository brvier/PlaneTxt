import 'dart:io';

import 'package:device_info_plus/device_info_plus.dart';
import 'package:permission_handler/permission_handler.dart';

class PermissionHelper {
  /// Requests the permission needed to access user-selected folders/files.
  ///
  /// Note: This app reads/writes non-media files (e.g. `.md`). On Android 11+
  /// this generally requires the special "All files access" permission
  /// (`MANAGE_EXTERNAL_STORAGE`) when using raw filesystem paths.
  static Future<bool> requestStoragePermission() async {
    if (Platform.isAndroid) {
      final androidInfo = await DeviceInfoPlugin().androidInfo;

      // Android 11+ (API 30+): request "All files access".
      // (Android 13/14 media permissions do NOT grant access to arbitrary files.)
      if (androidInfo.version.sdkInt >= 30) {
        return requestManageExternalStoragePermission();
      }
    }

    // Android <= 10 (API 29-) or other platforms.
    if (await Permission.storage.isGranted) {
      return true;
    }

    final status = await Permission.storage.request();
    return status.isGranted;
  }

  static Future<bool> requestManageExternalStoragePermission() async {
    if (await Permission.manageExternalStorage.isGranted) {
      return true;
    }

    final status = await Permission.manageExternalStorage.request();
    return status.isGranted;
  }

  static Future<bool> hasStoragePermission() async {
    if (Platform.isAndroid) {
      final androidInfo = await DeviceInfoPlugin().androidInfo;

      if (androidInfo.version.sdkInt >= 30) {
        return hasManageExternalStoragePermission();
      }
    }

    return Permission.storage.isGranted;
  }

  static Future<bool> hasManageExternalStoragePermission() async {
    return Permission.manageExternalStorage.isGranted;
  }
}
