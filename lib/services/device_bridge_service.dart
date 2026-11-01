import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';

class HardwareStatus {
  final bool cameraGranted;
  final bool nfcSupported;
  final bool nfcEnabled;
  final bool nfcReaderAttached;

  const HardwareStatus({
    required this.cameraGranted,
    required this.nfcSupported,
    required this.nfcEnabled,
    required this.nfcReaderAttached,
  });

  bool get isNfcReady => nfcSupported && nfcEnabled;

  factory HardwareStatus.fromMap(Map<dynamic, dynamic>? raw) {
    if (raw == null) {
      return const HardwareStatus(
        cameraGranted: false,
        nfcSupported: false,
        nfcEnabled: false,
        nfcReaderAttached: false,
      );
    }
    return HardwareStatus(
      cameraGranted: raw['cameraGranted'] == true,
      nfcSupported: raw['nfcSupported'] == true,
      nfcEnabled: raw['nfcEnabled'] == true,
      nfcReaderAttached: raw['nfcReaderAttached'] == true,
    );
  }
}

class NfcTagEvent {
  final String id;
  final String uid;
  final String source;

  const NfcTagEvent({
    required this.id,
    required this.uid,
    required this.source,
  });
}

class SavedTextFileResult {
  final String fileName;
  final String displayPath;
  final File tempShareFile;

  const SavedTextFileResult({
    required this.fileName,
    required this.displayPath,
    required this.tempShareFile,
  });
}

/// Unified native bridge to `MainActivity.kt` for:
/// 1. Lifecycle-safe Android NFC Reader Mode (immune to permission dialog pauses)
/// 2. Runtime Camera permission & Android NFC Settings deep-linking
/// 3. Zero-permission `.txt` Reviewer Outline saving straight to `Downloads/`
class DeviceBridgeService {
  DeviceBridgeService._() {
    _channel.setMethodCallHandler(_handleNativeCallback);
  }

  static final DeviceBridgeService instance = DeviceBridgeService._();

  static const MethodChannel _channel =
      MethodChannel('com.recordsportal.app/device_bridge');

  final StreamController<NfcTagEvent> _nfcController =
      StreamController<NfcTagEvent>.broadcast();
  final StreamController<HardwareStatus> _statusController =
      StreamController<HardwareStatus>.broadcast();

  Stream<NfcTagEvent> get nfcTagStream => _nfcController.stream;
  Stream<HardwareStatus> get hardwareStatusStream => _statusController.stream;

  bool get isAndroidNativeSupported => !kIsWeb && Platform.isAndroid;

  Future<dynamic> _handleNativeCallback(MethodCall call) async {
    switch (call.method) {
      case 'onNfcTagDiscovered':
        if (call.arguments is Map) {
          final map = Map<dynamic, dynamic>.from(call.arguments as Map);
          final id = map['id']?.toString().trim() ?? '';
          if (id.isNotEmpty) {
            _nfcController.add(
              NfcTagEvent(
                id: id,
                uid: map['uid']?.toString() ?? '',
                source: map['source']?.toString() ?? 'NFC',
              ),
            );
          }
        }
        break;
      case 'onHardwareStatusChanged':
        if (call.arguments is Map) {
          _statusController.add(
            HardwareStatus.fromMap(
              Map<dynamic, dynamic>.from(call.arguments as Map),
            ),
          );
        }
        break;
    }
  }

  Future<HardwareStatus> getHardwareStatus() async {
    if (!isAndroidNativeSupported) {
      return const HardwareStatus(
        cameraGranted: true,
        nfcSupported: false,
        nfcEnabled: false,
        nfcReaderAttached: false,
      );
    }
    try {
      final res =
          await _channel.invokeMapMethod<dynamic, dynamic>('getHardwareStatus');
      return HardwareStatus.fromMap(res);
    } catch (_) {
      return const HardwareStatus(
        cameraGranted: true,
        nfcSupported: false,
        nfcEnabled: false,
        nfcReaderAttached: false,
      );
    }
  }

  Future<bool> requestCameraPermission() async {
    if (!isAndroidNativeSupported) return true;
    try {
      final granted =
          await _channel.invokeMethod<bool>('requestCameraPermission');
      return granted == true;
    } catch (_) {
      return false;
    }
  }

  Future<HardwareStatus> setNfcReaderActive(bool active) async {
    if (!isAndroidNativeSupported) {
      return const HardwareStatus(
        cameraGranted: true,
        nfcSupported: false,
        nfcEnabled: false,
        nfcReaderAttached: false,
      );
    }
    try {
      final res = await _channel.invokeMapMethod<dynamic, dynamic>(
        'setNfcReaderActive',
        {'active': active},
      );
      final status = HardwareStatus.fromMap(res);
      _statusController.add(status);
      return status;
    } catch (_) {
      return getHardwareStatus();
    }
  }

  Future<bool> openNfcSettings() async {
    if (!isAndroidNativeSupported) return false;
    try {
      final ok = await _channel.invokeMethod<bool>('openNfcSettings');
      return ok == true;
    } catch (_) {
      return false;
    }
  }

  Future<bool> openAppSettings() async {
    if (!isAndroidNativeSupported) return false;
    try {
      final ok = await _channel.invokeMethod<bool>('openAppSettings');
      return ok == true;
    } catch (_) {
      return false;
    }
  }

  Future<SavedTextFileResult> saveTextToDownloads({
    required String fileName,
    required String content,
  }) async {
    final safeName = fileName
        .replaceAll(RegExp(r'[^A-Za-z0-9._ -]'), '_')
        .trim();
    final normalizedName = safeName.isEmpty
        ? 'Reviewer_Outline.txt'
        : (safeName.toLowerCase().endsWith('.txt')
            ? safeName
            : '$safeName.txt');

    final tempDir = await getTemporaryDirectory();
    final tempFile = File('${tempDir.path}/$normalizedName');
    await tempFile.writeAsString(content, flush: true);

    if (isAndroidNativeSupported) {
      try {
        final res = await _channel.invokeMapMethod<dynamic, dynamic>(
          'saveTextToDownloads',
          {
            'fileName': normalizedName,
            'content': content,
          },
        );
        final displayPath =
            res?['displayPath']?.toString() ?? 'Downloads/$normalizedName';
        return SavedTextFileResult(
          fileName: normalizedName,
          displayPath: displayPath,
          tempShareFile: tempFile,
        );
      } catch (_) {
        // Fall back to temporary file path if MediaStore is unavailable
      }
    }

    return SavedTextFileResult(
      fileName: normalizedName,
      displayPath: tempFile.path,
      tempShareFile: tempFile,
    );
  }

  Future<SavedTextFileResult> saveBytesToDownloads({
    required String fileName,
    required Uint8List bytes,
    String mimeType = 'image/png',
  }) async {
    final safeName =
        fileName.replaceAll(RegExp(r'[^A-Za-z0-9._ -]'), '_').trim();
    final normalizedName = safeName.isEmpty ? 'MIS_QR_Pass.png' : safeName;

    final tempDir = await getTemporaryDirectory();
    final tempFile = File('${tempDir.path}/$normalizedName');
    await tempFile.writeAsBytes(bytes, flush: true);

    if (isAndroidNativeSupported) {
      try {
        final res = await _channel.invokeMapMethod<dynamic, dynamic>(
          'saveBytesToDownloads',
          {
            'fileName': normalizedName,
            'mimeType': mimeType,
            'bytes': bytes,
          },
        );
        final displayPath =
            res?['displayPath']?.toString() ?? 'Downloads/$normalizedName';
        return SavedTextFileResult(
          fileName: normalizedName,
          displayPath: displayPath,
          tempShareFile: tempFile,
        );
      } catch (_) {}
    }

    return SavedTextFileResult(
      fileName: normalizedName,
      displayPath: tempFile.path,
      tempShareFile: tempFile,
    );
  }
}
