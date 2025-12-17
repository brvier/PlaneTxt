import 'dart:io';

import 'package:device_info_plus/device_info_plus.dart';
import 'package:permission_handler/permission_handler.dart';

class PermissionHelper {
  static Future<bool> requestStoragePermission() async {
    // For Android 11+ (API 30+), we need to request MANAGE_EXTERNAL_STORAGE
    if (Platform.isAndroid) {
      // Check if we're on Android 11+ (API 30+)
      final androidInfo = await DeviceInfoPlugin().androidInfo;
      if (androidInfo.version.sdkInt >= 30) {
        return await requestManageExternalStoragePermission();
      }
    }

    // For older Android versions or other platforms, use regular storage permission
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
        return await hasManageExternalStoragePermission();
      }
    }
    return await Permission.storage.isGranted;
  }

  static Future<bool> hasManageExternalStoragePermission() async {
    return await Permission.manageExternalStorage.isGranted;
  }
}
