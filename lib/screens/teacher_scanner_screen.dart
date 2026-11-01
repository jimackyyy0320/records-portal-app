import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:nfc_manager/nfc_manager.dart';
import 'package:nfc_manager_ndef/nfc_manager_ndef.dart';
import 'package:ndef_record/ndef_record.dart';

import '../config/app_config.dart';
import '../models/portal_models.dart';
import '../services/api_service.dart';
import '../services/device_bridge_service.dart';
import '../services/local_database.dart';
import '../services/sync_manager.dart';
import '../theme/portal_theme.dart';

/// Seamless, offline-first QR + NFC Classroom Scanner built around the exact 3-step UX:
/// 1. Select Mode first (Attendance -> `Attendance Log` | Recitation -> `Recitation_Log` w/ Points_Awarded = 1)
/// 2. Select Subject (loaded from Sheet `12DvradQOqCeswwKMtdx7jaIKDRjMUuxWRRD_p1WBCQQ` -> "Reference" Column C)
/// 3. Editable Timestamp bar right above the scanner (ticks live by default, tap to pin/edit custom date & time)
///
/// Includes:
/// - Global 1.5-second (1500ms) anti-burst lag time for both NFC and QR scans
/// - Native Android lifecycle-safe NFC Reader Mode + Camera/NFC Permission Setup
class TeacherScannerScreen extends StatefulWidget {
  /// 1.5-second (1500ms) anti-burst lag time across both QR and NFC scans.
  static const int scanLagDurationMs = 1500;

  final UserSession session;
  final List<SubjectItem> facultySubjects;
  final String? initialSubjectCode;

  const TeacherScannerScreen({
    super.key,
    required this.session,
    this.facultySubjects = const [],
    this.initialSubjectCode,
  });

  @override
  State<TeacherScannerScreen> createState() => _TeacherScannerScreenState();
}

class _TeacherScannerScreenState extends State<TeacherScannerScreen>
    with WidgetsBindingObserver {
  static const int _scanLagDurationMs =
      TeacherScannerScreen.scanLagDurationMs;

  // Step 1: Select Attendance or Recitation first
  ScanMode _selectedMode = ScanMode.attendance;

  // Step 2: Select Subject (from "Reference" Column C)
  List<String> _subjects = [];
  String? _selectedSubject;
  Map<String, String> _studentDirectory = {};
  bool _loadingBootstrap = true;

  // Step 3: Live vs Custom Edited Timestamp above the scanner
  DateTime _liveClock = DateTime.now();
  DateTime? _customPinnedTimestamp;
  Timer? _clockTimer;

  // Camera QR Scanner & Hardware Permissions
  MobileScannerController? _cameraController;
  bool _cameraEnabled = true;
  HardwareStatus _hwStatus = const HardwareStatus(
    cameraGranted: false,
    nfcSupported: false,
    nfcEnabled: false,
    nfcReaderAttached: false,
  );
  bool _checkingHardware = true;

  // Native NFC Bridge & iOS fallback
  StreamSubscription<NfcTagEvent>? _androidNfcSub;
  StreamSubscription<HardwareStatus>? _hwStatusSub;
  bool _iosNfcSessionActive = false;
  String _nfcStatusHint = 'Checking NFC hardware...';

  // 1.5s Anti-Burst Cooldown state
  int _cooldownUntilEpochMs = 0;
  int _cooldownRemainingMs = 0;
  Timer? _cooldownTickTimer;

  // Rapid-fire session state & feedback banner
  int _sessionScanCount = 0;
  List<ScanLogEntry> _recentScans = [];
  String? _bannerText;
  String? _bannerSubtitle;
  bool _bannerIsDuplicate = false;
  Timer? _bannerDismissTimer;
  bool _duplicateDialogOpen = false;

  static final DateFormat _sheetTimestampFormat =
      DateFormat('yyyy-MM-dd HH:mm:ss');

  bool get _hasFacultyAccess => widget.session.isFaculty;

  bool get _isCoolingDown => _cooldownRemainingMs > 0;

  @override
  void initState() {
    super.initState();
    if (!_hasFacultyAccess) {
      _loadingBootstrap = false;
      _checkingHardware = false;
      return;
    }

    WidgetsBinding.instance.addObserver(this);

    _clockTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted && _customPinnedTimestamp == null) {
        setState(() => _liveClock = DateTime.now());
      }
    });

    _loadSubjectsAndRecentScans();
    _initializeScannerHardware();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (!_hasFacultyAccess) return;
    if (state == AppLifecycleState.resumed) {
      // Re-arm Android NFC Reader Mode & refresh permission states upon returning
      // from phone NFC Settings or system permission prompts.
      _refreshAndArmHardware();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _clockTimer?.cancel();
    _cooldownTickTimer?.cancel();
    _bannerDismissTimer?.cancel();
    _androidNfcSub?.cancel();
    _hwStatusSub?.cancel();
    _cameraController?.dispose();
    if (!kIsWeb && Platform.isAndroid) {
      DeviceBridgeService.instance.setNfcReaderActive(false);
    } else if (_iosNfcSessionActive) {
      NfcManager.instance.stopSession().catchError((_) {});
    }
    super.dispose();
  }

  DateTime get _effectiveTimestamp => _customPinnedTimestamp ?? _liveClock;

  String get _formattedTimestamp =>
      _sheetTimestampFormat.format(_effectiveTimestamp);

  // ─────────────────────────────────────────────────────────────
  //  CAMERA + NFC PERMISSION & HARDWARE INTEGRATION
  // ─────────────────────────────────────────────────────────────

  void _ensureCameraController() {
    _cameraController ??= MobileScannerController(
      formats: const [
        BarcodeFormat.qrCode,
        BarcodeFormat.code128,
        BarcodeFormat.code39,
      ],
      detectionSpeed: DetectionSpeed.normal,
      facing: CameraFacing.back,
      torchEnabled: false,
    );
  }

  Future<void> _initializeScannerHardware() async {
    if (!kIsWeb && Platform.isAndroid) {
      _hwStatusSub =
          DeviceBridgeService.instance.hardwareStatusStream.listen((status) {
        if (!mounted) return;
        _applyHardwareStatus(status);
      });

      _androidNfcSub =
          DeviceBridgeService.instance.nfcTagStream.listen((tagEvent) {
        if (!mounted) return;
        final cleaned = _sanitizeScannedId(tagEvent.id);
        if (cleaned.isNotEmpty) {
          _recordScannedStudent(cleaned, sourceLabel: 'NFC');
        }
      });

      final initial = await DeviceBridgeService.instance.getHardwareStatus();
      if (!mounted) return;

      // Request Camera permission cleanly upfront if not yet granted so NFC
      // Reader Mode attaches right after the dialog resumes!
      bool camGranted = initial.cameraGranted;
      if (!camGranted) {
        camGranted = await DeviceBridgeService.instance.requestCameraPermission();
      }
      if (!mounted) return;

      final armedStatus =
          await DeviceBridgeService.instance.setNfcReaderActive(true);
      if (!mounted) return;
      _applyHardwareStatus(
        HardwareStatus(
          cameraGranted: camGranted || armedStatus.cameraGranted,
          nfcSupported: armedStatus.nfcSupported,
          nfcEnabled: armedStatus.nfcEnabled,
          nfcReaderAttached: armedStatus.nfcReaderAttached,
        ),
      );
      setState(() => _checkingHardware = false);
      return;
    }

    // Non-Android fallback (iOS)
    _ensureCameraController();
    setState(() {
      _hwStatus = const HardwareStatus(
        cameraGranted: true,
        nfcSupported: false,
        nfcEnabled: false,
        nfcReaderAttached: false,
      );
      _checkingHardware = false;
    });
    _startIosFallbackNfcListener();
  }

  Future<void> _refreshAndArmHardware() async {
    if (kIsWeb || !Platform.isAndroid) return;
    final status = await DeviceBridgeService.instance.setNfcReaderActive(true);
    if (!mounted) return;
    _applyHardwareStatus(status);
  }

  void _applyHardwareStatus(HardwareStatus status) {
    if (status.cameraGranted) {
      _ensureCameraController();
    }
    String nfcHint;
    if (!status.nfcSupported) {
      nfcHint = 'No NFC hardware detected on this phone';
    } else if (!status.nfcEnabled) {
      nfcHint = 'NFC is turned OFF — Tap Setup to enable in Settings';
    } else {
      nfcHint = 'NFC Reader Active — Hold student card behind phone';
    }
    setState(() {
      _hwStatus = status;
      _nfcStatusHint = nfcHint;
    });
  }

  Future<void> _requestCameraPermissionManual() async {
    final granted = await DeviceBridgeService.instance.requestCameraPermission();
    if (!mounted) return;
    if (!granted) {
      await DeviceBridgeService.instance.openAppSettings();
    } else {
      await _refreshAndArmHardware();
    }
  }

  Future<void> _startIosFallbackNfcListener() async {
    if (kIsWeb || !Platform.isIOS) {
      if (mounted) {
        setState(() => _nfcStatusHint = 'NFC unavailable on this platform');
      }
      return;
    }
    try {
      final availability = await NfcManager.instance.checkAvailability();
      if (!mounted) return;
      if (availability != NfcAvailability.enabled) {
        setState(() {
          _nfcStatusHint = availability == NfcAvailability.disabled
              ? 'NFC is disabled on this device'
              : 'No NFC hardware on device';
        });
        return;
      }
      setState(() {
        _iosNfcSessionActive = true;
        _hwStatus = const HardwareStatus(
          cameraGranted: true,
          nfcSupported: true,
          nfcEnabled: true,
          nfcReaderAttached: true,
        );
        _nfcStatusHint = 'NFC Active — Tap student card anytime';
      });

      await NfcManager.instance.startSession(
        pollingOptions: const {
          NfcPollingOption.iso14443,
          NfcPollingOption.iso15693,
        },
        onDiscovered: (NfcTag tag) async {
          final extractedId = await _extractStudentIdFromIosNfcTag(tag);
          if (extractedId != null && extractedId.trim().isNotEmpty) {
            await _recordScannedStudent(extractedId, sourceLabel: 'NFC');
          }
        },
      );
    } catch (e) {
      if (mounted) {
        setState(() {
          _iosNfcSessionActive = false;
          _nfcStatusHint = 'NFC error: $e';
        });
      }
    }
  }

  Future<String?> _extractStudentIdFromIosNfcTag(NfcTag tag) async {
    try {
      final ndef = Ndef.from(tag);
      NdefMessage? msg = ndef?.cachedMessage;
      if (msg == null && ndef != null) {
        try {
          msg = await ndef.read();
        } catch (_) {}
      }
      if (msg != null && msg.records.isNotEmpty) {
        for (final rec in msg.records) {
          final decoded = _decodeNdefRecordPayload(rec);
          if (decoded.isNotEmpty) return _sanitizeScannedId(decoded);
        }
      }
    } catch (_) {}
    return null;
  }

  String _decodeNdefRecordPayload(NdefRecord record) {
    final payload = record.payload;
    if (payload.isEmpty) return '';
    if (record.type.length == 1 && record.type[0] == 0x54) {
      final statusByte = payload[0];
      final langLen = statusByte & 0x3F;
      final start = 1 + langLen;
      if (payload.length <= start) return '';
      final isUtf16 = (statusByte & 0x80) != 0;
      return isUtf16
          ? String.fromCharCodes(payload.sublist(start)).trim()
          : utf8.decode(payload.sublist(start), allowMalformed: true).trim();
    }
    if (record.type.length == 1 &&
        record.type[0] == 0x55 &&
        payload.length > 1) {
      return utf8.decode(payload.sublist(1), allowMalformed: true).trim();
    }
    return utf8.decode(payload, allowMalformed: true).trim();
  }

  // ─────────────────────────────────────────────────────────────
  //  1.5-SECOND ANTI-BURST LAG TIMER (QR + NFC)
  // ─────────────────────────────────────────────────────────────

  void _startScanLagCooldown() {
    final now = DateTime.now().millisecondsSinceEpoch;
    _cooldownUntilEpochMs = now + _scanLagDurationMs;
    _cooldownRemainingMs = _scanLagDurationMs;
    _cooldownTickTimer?.cancel();
    _cooldownTickTimer = Timer.periodic(const Duration(milliseconds: 100), (t) {
      if (!mounted) {
        t.cancel();
        return;
      }
      final left =
          _cooldownUntilEpochMs - DateTime.now().millisecondsSinceEpoch;
      if (left <= 0) {
        t.cancel();
        setState(() => _cooldownRemainingMs = 0);
      } else {
        setState(() => _cooldownRemainingMs = left);
      }
    });
  }

  void _clearScanLagCooldown() {
    _cooldownTickTimer?.cancel();
    _cooldownUntilEpochMs = 0;
    if (mounted) {
      setState(() => _cooldownRemainingMs = 0);
    }
  }

  // ─────────────────────────────────────────────────────────────
  //  SUBJECT BOOTSTRAP & EDITABLE TIMESTAMP
  // ─────────────────────────────────────────────────────────────

  Future<void> _loadSubjectsAndRecentScans() async {
    final cached = await LocalDatabase.instance.getCachedReferenceBootstrap();
    final recent = await LocalDatabase.instance.getRecentScans(limit: 30);

    final merged = _mergeSubjectLists(
      referenceSubjects: cached.subjects,
      facultySubjects: widget.facultySubjects,
    );

    if (mounted) {
      setState(() {
        _subjects = merged;
        _studentDirectory = cached.students;
        _recentScans = recent;
        _selectedSubject = _resolveInitialSubject(merged);
        _loadingBootstrap = false;
      });
    }

    final fresh = await ApiService.instance.fetchScannerBootstrap(
      sessionOverride: widget.session,
    );
    if (!mounted) return;
    if (fresh.subjects.isNotEmpty || fresh.students.isNotEmpty) {
      final updatedSubjects = _mergeSubjectLists(
        referenceSubjects: fresh.subjects,
        facultySubjects: widget.facultySubjects,
      );
      setState(() {
        if (updatedSubjects.isNotEmpty) {
          _subjects = updatedSubjects;
          if (_selectedSubject == null ||
              !_subjects.contains(_selectedSubject)) {
            _selectedSubject = _resolveInitialSubject(updatedSubjects);
          }
        }
        if (fresh.students.isNotEmpty) {
          _studentDirectory = {..._studentDirectory, ...fresh.students};
        }
      });
    }
  }

  List<String> _mergeSubjectLists({
    required List<String> referenceSubjects,
    required List<SubjectItem> facultySubjects,
  }) {
    if (referenceSubjects.isNotEmpty) {
      return referenceSubjects;
    }
    final fromFac = facultySubjects
        .map((s) => s.code.trim())
        .where((s) => s.isNotEmpty)
        .toList();
    if (fromFac.isNotEmpty) return fromFac;
    return List<String>.from(AppConfig.fallbackSubjects);
  }

  String? _resolveInitialSubject(List<String> available) {
    if (available.isEmpty) return null;
    if (widget.initialSubjectCode != null) {
      final match = available.where(
        (s) => s.toUpperCase() == widget.initialSubjectCode!.toUpperCase(),
      );
      if (match.isNotEmpty) return match.first;
    }
    return available.first;
  }

  Future<void> _editTimestamp() async {
    final base = _effectiveTimestamp;
    final pickedDate = await showDatePicker(
      context: context,
      initialDate: base,
      firstDate: DateTime(2020),
      lastDate: DateTime(2035),
      helpText: 'Select Scan Log Date',
    );
    if (pickedDate == null || !mounted) return;

    final pickedTime = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(base),
      helpText: 'Select Scan Log Time',
    );
    if (pickedTime == null || !mounted) return;

    setState(() {
      _customPinnedTimestamp = DateTime(
        pickedDate.year,
        pickedDate.month,
        pickedDate.day,
        pickedTime.hour,
        pickedTime.minute,
        0,
      );
    });
  }

  void _resetTimestampToLive() {
    setState(() {
      _customPinnedTimestamp = null;
      _liveClock = DateTime.now();
    });
  }

  // ─────────────────────────────────────────────────────────────
  //  SHARED QR + NFC + MANUAL RECORDING PIPELINE
  // ─────────────────────────────────────────────────────────────

  void _onCameraBarcodeDetected(BarcodeCapture capture) {
    if (_duplicateDialogOpen) return;
    if (DateTime.now().millisecondsSinceEpoch < _cooldownUntilEpochMs) return;

    for (final barcode in capture.barcodes) {
      final raw = barcode.rawValue;
      if (raw != null && raw.trim().isNotEmpty) {
        _recordScannedStudent(_sanitizeScannedId(raw), sourceLabel: 'QR');
        break;
      }
    }
  }

  String _sanitizeScannedId(String raw) {
    String clean = raw.trim();
    if (clean.startsWith('{') && clean.endsWith('}')) {
      try {
        final decoded = jsonDecode(clean);
        if (decoded is Map) {
          final idVal =
              decoded['studentId'] ?? decoded['Student_ID'] ?? decoded['id'];
          if (idVal != null) return idVal.toString().trim();
        }
      } catch (_) {}
    }
    final uri = Uri.tryParse(clean);
    if (uri != null && uri.hasScheme) {
      final qId = uri.queryParameters['id'] ?? uri.queryParameters['studentId'];
      if (qId != null && qId.trim().isNotEmpty) return qId.trim();
    }
    return clean;
  }

  Future<void> _recordScannedStudent(
    String rawStudentId, {
    required String sourceLabel,
  }) async {
    if (!_hasFacultyAccess || _duplicateDialogOpen) return;

    // Enforce global 1.5-second anti-burst lag time for QR and NFC scans
    final nowMs = DateTime.now().millisecondsSinceEpoch;
    if ((sourceLabel == 'QR' || sourceLabel == 'NFC') &&
        nowMs < _cooldownUntilEpochMs) {
      return;
    }

    final studentId = rawStudentId.trim();
    if (studentId.isEmpty) return;

    final subject = _selectedSubject?.trim() ?? '';
    if (subject.isEmpty) {
      _startScanLagCooldown();
      _flashBanner(
        title: 'Select a Subject first (Step 2)',
        subtitle: 'Choose a subject before scanning.',
        isDuplicate: true,
      );
      return;
    }

    // Lock scanner immediately so burst frames/taps while writing SQLite are ignored
    if (sourceLabel == 'QR' || sourceLabel == 'NFC') {
      _startScanLagCooldown();
    }

    final timestampStr = _formattedTimestamp;
    final datePrefix = timestampStr.length >= 10
        ? timestampStr.substring(0, 10)
        : DateFormat('yyyy-MM-dd').format(_effectiveTimestamp);
    final studentName = _studentDirectory[studentId];
    bool isOverrideAttendance = false;

    // Attendance duplicate check with Faculty Override option
    if (_selectedMode == ScanMode.attendance) {
      final existingAttendance =
          await LocalDatabase.instance.findAttendanceScansForSubjectDate(
        subject: subject,
        studentId: studentId,
        datePrefix: datePrefix,
      );
      if (existingAttendance.isNotEmpty) {
        HapticFeedback.heavyImpact();
        _duplicateDialogOpen = true;
        bool approvedOverride = false;
        try {
          if (mounted) {
            approvedOverride = await _promptDuplicateAttendanceOverride(
              studentId: studentId,
              studentName: studentName,
              subject: subject,
              existingScans: existingAttendance,
            );
          }
        } finally {
          _duplicateDialogOpen = false;
          // Start a fresh 1.5s lag window after closing the duplicate dialog
          _startScanLagCooldown();
        }

        if (!approvedOverride) {
          if (mounted) {
            _flashBanner(
              title: 'Skipped Duplicate ($studentId)',
              subtitle:
                  '$subject • Already logged at ${existingAttendance.first.timestamp}',
              isDuplicate: true,
            );
          }
          return;
        }
        isOverrideAttendance = true;
      }
    }

    final entry = ScanLogEntry.create(
      mode: _selectedMode,
      timestamp: timestampStr,
      studentId: studentId,
      studentName: studentName,
      subject: subject,
    );

    // 1. Write immediately to offline SQLite database
    await LocalDatabase.instance.insertScan(entry);

    // 2. Count total Recitation points in this subject today (multiple scans allowed!)
    int recitationCountToday = 1;
    if (_selectedMode == ScanMode.recitation) {
      recitationCountToday =
          await LocalDatabase.instance.countRecitationScansForSubjectDate(
        subject: subject,
        studentId: studentId,
        datePrefix: datePrefix,
      );
    }

    // 3. Tactile & acoustic feedback for fast eyes-free scanning
    HapticFeedback.mediumImpact();
    SystemSound.play(SystemSoundType.click);

    // 4. Trigger SyncManager (batches & syncs when online; queues WorkManager when offline)
    SyncManager.instance.onNewScanQueued();

    if (!mounted) return;
    setState(() {
      _sessionScanCount++;
      _recentScans = [entry, ..._recentScans.take(29)];
    });

    final displayTitle = studentName != null && studentName.isNotEmpty
        ? '$studentName ($studentId)'
        : 'ID: $studentId';
    final modeTag = _selectedMode == ScanMode.recitation
        ? 'Recitation +1 Pt (#$recitationCountToday today • $sourceLabel)'
        : (isOverrideAttendance
            ? 'Attendance Override Logged ($sourceLabel)'
            : 'Attendance Logged ($sourceLabel)');
    _flashBanner(
      title: '✅ $displayTitle',
      subtitle: '$subject • $modeTag • ${entry.timestamp}',
      isDuplicate: false,
    );
  }

  Future<bool> _promptDuplicateAttendanceOverride({
    required String studentId,
    required String? studentName,
    required String subject,
    required List<ScanLogEntry> existingScans,
  }) async {
    final latest = existingScans.first;
    final res = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
        title: Row(
          children: [
            const Icon(
              Icons.warning_amber_rounded,
              color: PortalColors.burg,
              size: 26,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                'Duplicate Attendance',
                style: PortalTheme.serif(size: 22, color: PortalColors.burg),
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              studentName != null && studentName.isNotEmpty
                  ? '$studentName ($studentId)'
                  : 'Student ID: $studentId',
              style: PortalTheme.sans(
                size: 14.5,
                weight: FontWeight.w800,
                color: PortalColors.forest,
              ),
            ),
            const SizedBox(height: 8),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: PortalColors.burgBg,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: PortalColors.burgBorder),
              ),
              child: Text(
                'Already scanned ${existingScans.length} time(s) for $subject.\nLast scan: ${latest.timestamp}',
                style: PortalTheme.sans(
                  size: 12.5,
                  weight: FontWeight.w600,
                  color: PortalColors.burg,
                ),
              ),
            ),
            const SizedBox(height: 10),
            Text(
              'Do you want to skip this duplicate or use Faculty Override to log an additional attendance entry?',
              style: PortalTheme.sans(size: 12.5, color: PortalColors.ink2),
            ),
          ],
        ),
        actions: [
          OutlinedButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Skip Scan'),
          ),
          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              backgroundColor: PortalColors.burg,
              foregroundColor: Colors.white,
            ),
            onPressed: () => Navigator.of(ctx).pop(true),
            icon: const Icon(Icons.lock_open_rounded, size: 16),
            label: const Text('Override & Log'),
          ),
        ],
      ),
    );
    return res == true;
  }

  void _flashBanner({
    required String title,
    required String subtitle,
    required bool isDuplicate,
  }) {
    _bannerDismissTimer?.cancel();
    setState(() {
      _bannerText = title;
      _bannerSubtitle = subtitle;
      _bannerIsDuplicate = isDuplicate;
    });
    _bannerDismissTimer = Timer(const Duration(milliseconds: 2500), () {
      if (mounted) {
        setState(() => _bannerText = null);
      }
    });
  }

  Future<void> _undoScan(ScanLogEntry entry) async {
    if (entry.syncStatus == 'synced') {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('This scan has already synced to Google Sheets.'),
        ),
      );
      return;
    }
    await LocalDatabase.instance.deleteScan(entry.logId);
    _clearScanLagCooldown();
    await SyncManager.instance.refreshPendingCount();
    final updated = await LocalDatabase.instance.getRecentScans(limit: 30);
    if (mounted) {
      setState(() {
        if (_sessionScanCount > 0) _sessionScanCount--;
        _recentScans = updated;
      });
    }
  }

  Future<void> _promptManualStudentId() async {
    final ctrl = TextEditingController();
    final entered = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text('Manual Student ID', style: PortalTheme.serif(size: 24)),
        content: TextField(
          controller: ctrl,
          autofocus: true,
          decoration: InputDecoration(
            hintText: 'Enter Student ID',
            filled: true,
            fillColor: PortalColors.parchment,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
          onSubmitted: (v) => Navigator.of(ctx).pop(v.trim()),
        ),
        actions: [
          OutlinedButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: PortalColors.forest,
              foregroundColor: Colors.white,
            ),
            onPressed: () => Navigator.of(ctx).pop(ctrl.text.trim()),
            child: const Text('Log Scan'),
          ),
        ],
      ),
    );
    if (entered != null && entered.isNotEmpty) {
      await _recordScannedStudent(entered, sourceLabel: 'Manual');
    }
  }

  Future<void> _promptCustomSubject() async {
    final ctrl = TextEditingController();
    final added = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text('Add / Enter Subject', style: PortalTheme.serif(size: 22)),
        content: TextField(
          controller: ctrl,
          autofocus: true,
          textCapitalization: TextCapitalization.characters,
          decoration: InputDecoration(
            hintText: 'e.g. PKLP, PGP, PHILO',
            filled: true,
            fillColor: PortalColors.parchment,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        ),
        actions: [
          OutlinedButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: PortalColors.forest,
              foregroundColor: Colors.white,
            ),
            onPressed: () => Navigator.of(ctx).pop(ctrl.text.trim()),
            child: const Text('Select'),
          ),
        ],
      ),
    );
    if (added != null && added.isNotEmpty && mounted) {
      setState(() {
        if (!_subjects.contains(added)) {
          _subjects = [..._subjects, added];
        }
        _selectedSubject = added;
      });
    }
  }

  void _openPermissionsSetupSheet() {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) => _ScannerPermissionsSetupSheet(
        initialStatus: _hwStatus,
        onRefreshRequested: _refreshAndArmHardware,
      ),
    ).then((_) => _refreshAndArmHardware());
  }

  void _openSyncQueueDrawer() {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) => const _OfflineSyncQueueSheet(),
    ).then((_) async {
      final updated = await LocalDatabase.instance.getRecentScans(limit: 30);
      if (mounted) setState(() => _recentScans = updated);
    });
  }

  @override
  Widget build(BuildContext context) {
    if (!_hasFacultyAccess) {
      return Scaffold(
        backgroundColor: PortalColors.parchment,
        appBar: AppBar(
          backgroundColor: PortalColors.forest,
          foregroundColor: Colors.white,
          title: Text(
            'Access Restricted',
            style: PortalTheme.serif(size: 22, color: Colors.white),
          ),
        ),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(28),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(
                  Icons.lock_person_rounded,
                  size: 56,
                  color: PortalColors.burg,
                ),
                const SizedBox(height: 14),
                Text(
                  'Faculty Access Required',
                  style:
                      PortalTheme.serif(size: 26, color: PortalColors.forest),
                ),
                const SizedBox(height: 8),
                Text(
                  'Only authenticated Faculty accounts are authorized to scan student Attendance and Recitations.',
                  textAlign: TextAlign.center,
                  style: PortalTheme.sans(size: 13.5, color: PortalColors.ink2),
                ),
                const SizedBox(height: 20),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: PortalColors.forest,
                    foregroundColor: Colors.white,
                  ),
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('Return'),
                ),
              ],
            ),
          ),
        ),
      );
    }

    final isPinnedTime = _customPinnedTimestamp != null;
    final needsAttention =
        !_hwStatus.cameraGranted || (_hwStatus.nfcSupported && !_hwStatus.nfcEnabled);

    return Scaffold(
      backgroundColor: PortalColors.parchment,
      appBar: AppBar(
        backgroundColor: PortalColors.forest,
        foregroundColor: Colors.white,
        title: Text(
          'Classroom Scanner',
          style: PortalTheme.serif(size: 22, color: Colors.white),
        ),
        actions: [
          IconButton(
            tooltip: 'Camera & NFC Permission Setup',
            onPressed: _openPermissionsSetupSheet,
            icon: Stack(
              clipBehavior: Clip.none,
              children: [
                const Icon(Icons.tune_rounded, color: Colors.white),
                if (needsAttention)
                  Positioned(
                    right: -2,
                    top: -2,
                    child: Container(
                      width: 9,
                      height: 9,
                      decoration: const BoxDecoration(
                        color: PortalColors.gold,
                        shape: BoxShape.circle,
                      ),
                    ),
                  ),
              ],
            ),
          ),
          ListenableBuilder(
            listenable: SyncManager.instance,
            builder: (context, _) {
              final sm = SyncManager.instance;
              final pending = sm.pendingCount;
              final badgeColor = !sm.isOnline
                  ? PortalColors.gold
                  : (pending > 0 ? PortalColors.goldPale : PortalColors.emeraldBg);
              final textColor = !sm.isOnline
                  ? PortalColors.forest
                  : (pending > 0 ? PortalColors.forest : PortalColors.emerald);
              final label = sm.isSyncing
                  ? 'Syncing...'
                  : (!sm.isOnline
                      ? 'Offline ($pending)'
                      : (pending > 0 ? '$pending Queued' : 'Synced'));

              return Padding(
                padding: const EdgeInsets.only(right: 10),
                child: InkWell(
                  borderRadius: BorderRadius.circular(20),
                  onTap: _openSyncQueueDrawer,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 11,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: badgeColor,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          !sm.isOnline
                              ? Icons.cloud_off_rounded
                              : (sm.isSyncing
                                  ? Icons.sync_rounded
                                  : Icons.cloud_done_rounded),
                          size: 15,
                          color: textColor,
                        ),
                        const SizedBox(width: 5),
                        Text(
                          label,
                          style: PortalTheme.sans(
                            size: 11.5,
                            weight: FontWeight.w800,
                            color: textColor,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            // Optional 1-tap NFC / Permission Alert Strip if NFC is turned off on phone
            if (!_checkingHardware && needsAttention)
              InkWell(
                onTap: _openPermissionsSetupSheet,
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 8,
                  ),
                  color: PortalColors.goldPale,
                  child: Row(
                    children: [
                      const Icon(
                        Icons.nfc_rounded,
                        size: 17,
                        color: PortalColors.forest,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          !_hwStatus.cameraGranted
                              ? 'Camera permission is required for QR scanning. Tap to grant.'
                              : 'Phone NFC is currently OFF. Tap here to enable NFC for card taps.',
                          style: PortalTheme.sans(
                            size: 11.5,
                            weight: FontWeight.w700,
                            color: PortalColors.forest,
                          ),
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 9,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: PortalColors.forest,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          'SETUP',
                          style: PortalTheme.sans(
                            size: 10,
                            weight: FontWeight.w800,
                            color: PortalColors.gold,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),

            // ─────────────────────────────────────────────────────
            //  SETUP CONTROLS: 1. MODE -> 2. SUBJECT -> 3. TIMESTAMP
            // ─────────────────────────────────────────────────────
            Container(
              width: double.infinity,
              padding: const EdgeInsets.fromLTRB(14, 10, 14, 10),
              decoration: const BoxDecoration(
                color: Colors.white,
                border: Border(bottom: BorderSide(color: PortalColors.ruleMed)),
                boxShadow: [
                  BoxShadow(
                    color: Color(0x141A3A2A),
                    blurRadius: 10,
                    offset: Offset(0, 3),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // STEP 1: Select Attendance or Recitation First
                  Row(
                    children: [
                      _stepBadge('1'),
                      const SizedBox(width: 6),
                      Text(
                        'SCAN TYPE',
                        style: PortalTheme.sans(
                          size: 10.5,
                          weight: FontWeight.w800,
                          letterSpacing: 1.1,
                          color: PortalColors.ink3,
                        ),
                      ),
                      const Spacer(),
                      Text(
                        'Tab: ${_selectedMode.targetSheetTab}',
                        style: PortalTheme.sans(
                          size: 10.5,
                          weight: FontWeight.w600,
                          color: PortalColors.ink3,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      Expanded(
                        child: _modeSelectorButton(
                          mode: ScanMode.attendance,
                          icon: Icons.how_to_reg_rounded,
                          title: 'Attendance',
                          subtitle: 'Attendance Log',
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: _modeSelectorButton(
                          mode: ScanMode.recitation,
                          icon: Icons.record_voice_over_rounded,
                          title: 'Recitation',
                          subtitle: 'Always +1 Point',
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),

                  // STEP 2: Select Subject (from "Reference" Column C)
                  Row(
                    children: [
                      _stepBadge('2'),
                      const SizedBox(width: 6),
                      Text(
                        'SUBJECT (REFERENCE COL C)',
                        style: PortalTheme.sans(
                          size: 10.5,
                          weight: FontWeight.w800,
                          letterSpacing: 1.1,
                          color: PortalColors.ink3,
                        ),
                      ),
                      const Spacer(),
                      InkWell(
                        onTap: _loadSubjectsAndRecentScans,
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 4),
                          child: Icon(
                            Icons.refresh_rounded,
                            size: 17,
                            color: _loadingBootstrap
                                ? PortalColors.gold
                                : PortalColors.forest,
                          ),
                        ),
                      ),
                      const SizedBox(width: 4),
                      InkWell(
                        onTap: _promptCustomSubject,
                        child: Text(
                          '+ Custom',
                          style: PortalTheme.sans(
                            size: 11,
                            weight: FontWeight.w700,
                            color: PortalColors.forest,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 5),
                  SizedBox(
                    height: 36,
                    child: ListView.separated(
                      scrollDirection: Axis.horizontal,
                      itemCount: _subjects.length,
                      separatorBuilder: (_, __) => const SizedBox(width: 8),
                      itemBuilder: (context, idx) {
                        final subj = _subjects[idx];
                        final selected = _selectedSubject == subj;
                        return ChoiceChip(
                          label: Text(subj),
                          selected: selected,
                          selectedColor: PortalColors.forest,
                          backgroundColor: PortalColors.parchment,
                          checkmarkColor: PortalColors.gold,
                          labelStyle: PortalTheme.sans(
                            size: 12,
                            weight: FontWeight.w800,
                            color: selected
                                ? PortalColors.gold
                                : PortalColors.forest,
                          ),
                          onSelected: (_) =>
                              setState(() => _selectedSubject = subj),
                        );
                      },
                    ),
                  ),
                  const SizedBox(height: 8),

                  // STEP 3: Editable Timestamp Bar Above the Scanner
                  InkWell(
                    borderRadius: BorderRadius.circular(12),
                    onTap: _editTimestamp,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 8,
                      ),
                      decoration: BoxDecoration(
                        color: isPinnedTime
                            ? PortalColors.goldPale
                            : PortalColors.parchment,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: isPinnedTime
                              ? PortalColors.goldDark
                              : PortalColors.ruleMed,
                        ),
                      ),
                      child: Row(
                        children: [
                          _stepBadge('3'),
                          const SizedBox(width: 8),
                          Icon(
                            isPinnedTime
                                ? Icons.push_pin_rounded
                                : Icons.access_time_filled_rounded,
                            size: 16,
                            color: isPinnedTime
                                ? PortalColors.goldDark
                                : PortalColors.forest,
                          ),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  isPinnedTime
                                      ? 'CUSTOM TIMESTAMP (PINNED)'
                                      : 'LIVE SCAN TIMESTAMP',
                                  style: PortalTheme.sans(
                                    size: 9.5,
                                    weight: FontWeight.w800,
                                    letterSpacing: 0.9,
                                    color: isPinnedTime
                                        ? PortalColors.goldDark
                                        : PortalColors.ink3,
                                  ),
                                ),
                                Text(
                                  _formattedTimestamp,
                                  style: PortalTheme.sans(
                                    size: 13.5,
                                    weight: FontWeight.w800,
                                    color: PortalColors.forest,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          if (isPinnedTime)
                            TextButton(
                              style: TextButton.styleFrom(
                                visualDensity: VisualDensity.compact,
                                foregroundColor: PortalColors.burg,
                              ),
                              onPressed: _resetTimestampToLive,
                              child: const Text('Use Live'),
                            ),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 5,
                            ),
                            decoration: BoxDecoration(
                              color: PortalColors.forest,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              '✏️ Edit',
                              style: PortalTheme.sans(
                                size: 11,
                                weight: FontWeight.w700,
                                color: PortalColors.gold,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // ─────────────────────────────────────────────────────
            //  DUAL CAMERA QR + HARDWARE NFC VIEWFINDER
            // ─────────────────────────────────────────────────────
            Expanded(
              flex: 6,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  if (_checkingHardware)
                    Container(
                      color: PortalColors.forestDark,
                      alignment: Alignment.center,
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const CircularProgressIndicator(
                            color: PortalColors.gold,
                          ),
                          const SizedBox(height: 12),
                          Text(
                            'INITIALIZING CAMERA & NFC READER...',
                            style: PortalTheme.sans(
                              size: 11.5,
                              weight: FontWeight.w700,
                              letterSpacing: 1.3,
                              color: Colors.white70,
                            ),
                          ),
                        ],
                      ),
                    )
                  else if (!_hwStatus.cameraGranted)
                    Container(
                      color: PortalColors.forestDark,
                      alignment: Alignment.center,
                      padding: const EdgeInsets.all(24),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(
                            Icons.camera_enhance_rounded,
                            color: PortalColors.gold,
                            size: 48,
                          ),
                          const SizedBox(height: 10),
                          Text(
                            'Camera Permission Needed',
                            style: PortalTheme.serif(
                              size: 22,
                              color: Colors.white,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            'Grant camera access for QR scanning, or continue scanning via NFC card tap & Manual ID.',
                            textAlign: TextAlign.center,
                            style: PortalTheme.sans(
                              size: 12.5,
                              color: Colors.white70,
                            ),
                          ),
                          const SizedBox(height: 14),
                          ElevatedButton.icon(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: PortalColors.gold,
                              foregroundColor: PortalColors.forest,
                            ),
                            onPressed: _requestCameraPermissionManual,
                            icon: const Icon(Icons.verified_user_rounded, size: 17),
                            label: const Text('Grant Camera Permission'),
                          ),
                        ],
                      ),
                    )
                  else if (_cameraEnabled && _cameraController != null)
                    MobileScanner(
                      controller: _cameraController!,
                      onDetect: _onCameraBarcodeDetected,
                      errorBuilder: (context, error) => Container(
                        color: PortalColors.forestDark,
                        alignment: Alignment.center,
                        padding: const EdgeInsets.all(24),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              'Camera unavailable (${error.errorCode.name}).\nNFC & Manual ID scanning remain active.',
                              textAlign: TextAlign.center,
                              style: PortalTheme.sans(color: Colors.white),
                            ),
                            const SizedBox(height: 12),
                            OutlinedButton(
                              style: OutlinedButton.styleFrom(
                                foregroundColor: PortalColors.gold,
                                side: const BorderSide(color: PortalColors.gold),
                              ),
                              onPressed: _openPermissionsSetupSheet,
                              child: const Text('Open Scanner Setup'),
                            ),
                          ],
                        ),
                      ),
                    )
                  else
                    Container(
                      color: PortalColors.forestDark,
                      alignment: Alignment.center,
                      padding: const EdgeInsets.symmetric(horizontal: 24),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(
                            Icons.nfc_rounded,
                            color: PortalColors.gold,
                            size: 56,
                          ),
                          const SizedBox(height: 10),
                          Text(
                            'Camera Paused — NFC Reader Mode',
                            style: PortalTheme.serif(
                              size: 22,
                              color: Colors.white,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            _nfcStatusHint,
                            textAlign: TextAlign.center,
                            style: PortalTheme.sans(
                              size: 12.5,
                              color: Colors.white70,
                            ),
                          ),
                        ],
                      ),
                    ),

                  // QR Reticle Frame (pulses Gold during 1.5s cooldown)
                  if (_cameraEnabled && _hwStatus.cameraGranted)
                    IgnorePointer(
                      child: Center(
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 220),
                          width: 205,
                          height: 205,
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(24),
                            color: _isCoolingDown
                                ? Colors.black.withAlpha(75)
                                : Colors.transparent,
                            border: Border.all(
                              color: _isCoolingDown
                                  ? PortalColors.gold
                                  : (_selectedMode == ScanMode.recitation
                                      ? PortalColors.gold
                                      : Colors.white),
                              width: 3,
                            ),
                          ),
                          alignment: Alignment.center,
                          child: _isCoolingDown
                              ? Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 14,
                                    vertical: 8,
                                  ),
                                  decoration: BoxDecoration(
                                    color: Colors.black.withAlpha(185),
                                    borderRadius: BorderRadius.circular(16),
                                  ),
                                  child: Column(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      const Icon(
                                        Icons.hourglass_bottom_rounded,
                                        color: PortalColors.gold,
                                        size: 22,
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        'Next scan in ${(_cooldownRemainingMs / 1000).toStringAsFixed(1)}s',
                                        style: PortalTheme.sans(
                                          size: 12,
                                          weight: FontWeight.w800,
                                          color: Colors.white,
                                        ),
                                      ),
                                      const SizedBox(height: 6),
                                      SizedBox(
                                        width: 110,
                                        height: 4,
                                        child: ClipRRect(
                                          borderRadius:
                                              BorderRadius.circular(4),
                                          child: LinearProgressIndicator(
                                            value: (_cooldownRemainingMs /
                                                    _scanLagDurationMs)
                                                .clamp(0.0, 1.0),
                                            color: PortalColors.gold,
                                            backgroundColor: Colors.white24,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                )
                              : null,
                        ),
                      ),
                    ),

                  // 1.5s Cooldown indicator when Camera is paused (NFC-only mode)
                  if ((!_cameraEnabled || !_hwStatus.cameraGranted) &&
                      _isCoolingDown)
                    Positioned(
                      top: 56,
                      left: 24,
                      right: 24,
                      child: Center(
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 14,
                            vertical: 7,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.black.withAlpha(190),
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(color: PortalColors.gold),
                          ),
                          child: Text(
                            '⏳ Anti-burst lag: Ready in ${(_cooldownRemainingMs / 1000).toStringAsFixed(1)}s',
                            style: PortalTheme.sans(
                              size: 11.5,
                              weight: FontWeight.w800,
                              color: PortalColors.gold,
                            ),
                          ),
                        ),
                      ),
                    ),

                  // Quick Camera / Torch / NFC / Manual Toolbar
                  Positioned(
                    top: 10,
                    left: 12,
                    right: 12,
                    child: Row(
                      children: [
                        InkWell(
                          borderRadius: BorderRadius.circular(20),
                          onTap: _openPermissionsSetupSheet,
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 6,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.black.withAlpha(168),
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(
                                color: _hwStatus.isNfcReady
                                    ? PortalColors.gold.withAlpha(140)
                                    : Colors.white24,
                              ),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  Icons.nfc_rounded,
                                  size: 15,
                                  color: _hwStatus.isNfcReady
                                      ? PortalColors.gold
                                      : Colors.amberAccent,
                                ),
                                const SizedBox(width: 5),
                                Text(
                                  _hwStatus.isNfcReady
                                      ? 'QR + NFC Active'
                                      : (_hwStatus.nfcSupported
                                          ? 'Enable NFC →'
                                          : 'QR Active'),
                                  style: PortalTheme.sans(
                                    size: 11,
                                    weight: FontWeight.w700,
                                    color: Colors.white,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                        const Spacer(),
                        _scannerOverlayIconBtn(
                          icon: _cameraEnabled
                              ? Icons.videocam_rounded
                              : Icons.videocam_off_rounded,
                          tooltip: 'Toggle Camera',
                          onTap: () =>
                              setState(() => _cameraEnabled = !_cameraEnabled),
                        ),
                        const SizedBox(width: 6),
                        if (_cameraEnabled && _hwStatus.cameraGranted) ...[
                          _scannerOverlayIconBtn(
                            icon: Icons.flashlight_on_rounded,
                            tooltip: 'Toggle Torch',
                            onTap: () => _cameraController?.toggleTorch(),
                          ),
                          const SizedBox(width: 6),
                          _scannerOverlayIconBtn(
                            icon: Icons.cameraswitch_rounded,
                            tooltip: 'Switch Camera',
                            onTap: () => _cameraController?.switchCamera(),
                          ),
                          const SizedBox(width: 6),
                        ],
                        _scannerOverlayIconBtn(
                          icon: Icons.keyboard_alt_outlined,
                          tooltip: 'Manual Student ID',
                          onTap: _promptManualStudentId,
                        ),
                      ],
                    ),
                  ),

                  // Instant Non-Blocking Scan Confirmation Toast Banner
                  if (_bannerText != null)
                    Positioned(
                      bottom: 12,
                      left: 14,
                      right: 14,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 12,
                        ),
                        decoration: BoxDecoration(
                          color: _bannerIsDuplicate
                              ? const Color(0xFF6E470B)
                              : PortalColors.emerald,
                          borderRadius: BorderRadius.circular(16),
                          boxShadow: const [
                            BoxShadow(
                              color: Colors.black38,
                              blurRadius: 14,
                              offset: Offset(0, 4),
                            ),
                          ],
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              _bannerText!,
                              style: PortalTheme.sans(
                                size: 14.5,
                                weight: FontWeight.w800,
                                color: Colors.white,
                              ),
                            ),
                            if (_bannerSubtitle != null)
                              Text(
                                _bannerSubtitle!,
                                style: PortalTheme.sans(
                                  size: 11.5,
                                  color: Colors.white.withAlpha(230),
                                ),
                              ),
                          ],
                        ),
                      ),
                    ),
                ],
              ),
            ),

            // ─────────────────────────────────────────────────────
            //  RECENT SCANS FEED (WITH 1-TAP UNDO & LIVE SYNC STATUS)
            // ─────────────────────────────────────────────────────
            Expanded(
              flex: 4,
              child: Container(
                color: Colors.white,
                child: Column(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 8,
                      ),
                      decoration: const BoxDecoration(
                        color: PortalColors.parchment,
                        border: Border(
                          bottom: BorderSide(color: PortalColors.rule),
                        ),
                      ),
                      child: Row(
                        children: [
                          Text(
                            'RECENT SCANS ($_sessionScanCount THIS SESSION)',
                            style: PortalTheme.sans(
                              size: 11,
                              weight: FontWeight.w800,
                              letterSpacing: 1.0,
                              color: PortalColors.forest,
                            ),
                          ),
                          const Spacer(),
                          InkWell(
                            onTap: _openSyncQueueDrawer,
                            child: Text(
                              'Manage Sync Queue →',
                              style: PortalTheme.sans(
                                size: 11.5,
                                weight: FontWeight.w700,
                                color: PortalColors.goldDark,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    Expanded(
                      child: _recentScans.isEmpty
                          ? Center(
                              child: Padding(
                                padding:
                                    const EdgeInsets.symmetric(horizontal: 24),
                                child: Text(
                                  'Point camera at QR pass or tap student NFC card (1.5s anti-burst protection active).',
                                  textAlign: TextAlign.center,
                                  style: PortalTheme.sans(
                                    size: 12.5,
                                    color: PortalColors.ink3,
                                  ),
                                ),
                              ),
                            )
                          : ListView.separated(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 6,
                              ),
                              itemCount: _recentScans.length,
                              separatorBuilder: (_, __) =>
                                  const Divider(height: 1),
                              itemBuilder: (context, index) {
                                final item = _recentScans[index];
                                final isSynced = item.syncStatus == 'synced';
                                final isRec =
                                    item.scanType == ScanMode.recitation;
                                final title = item.studentName != null &&
                                        item.studentName!.isNotEmpty
                                    ? '${item.studentName} (${item.studentId})'
                                    : item.studentId;

                                return ListTile(
                                  dense: true,
                                  contentPadding: const EdgeInsets.symmetric(
                                    horizontal: 4,
                                  ),
                                  leading: CircleAvatar(
                                    radius: 16,
                                    backgroundColor: isRec
                                        ? PortalColors.goldPale
                                        : PortalColors.emeraldBg,
                                    child: Text(
                                      isRec ? '+1' : 'P',
                                      style: PortalTheme.sans(
                                        size: 11.5,
                                        weight: FontWeight.w800,
                                        color: isRec
                                            ? PortalColors.goldDark
                                            : PortalColors.emerald,
                                      ),
                                    ),
                                  ),
                                  title: Text(
                                    title,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: PortalTheme.sans(
                                      size: 13,
                                      weight: FontWeight.w700,
                                      color: PortalColors.forest,
                                    ),
                                  ),
                                  subtitle: Text(
                                    '${item.subject} • ${item.scanType.displayLabel} • ${item.timestamp}',
                                    style: PortalTheme.sans(
                                      size: 11,
                                      color: PortalColors.ink3,
                                    ),
                                  ),
                                  trailing: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(
                                        isSynced
                                            ? Icons.check_circle_rounded
                                            : Icons.schedule_rounded,
                                        size: 16,
                                        color: isSynced
                                            ? PortalColors.emerald
                                            : PortalColors.goldDark,
                                      ),
                                      if (!isSynced) ...[
                                        const SizedBox(width: 4),
                                        IconButton(
                                          tooltip: 'Undo Scan',
                                          visualDensity: VisualDensity.compact,
                                          icon: const Icon(
                                            Icons.undo_rounded,
                                            size: 18,
                                            color: PortalColors.burg,
                                          ),
                                          onPressed: () => _undoScan(item),
                                        ),
                                      ],
                                    ],
                                  ),
                                );
                              },
                            ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _stepBadge(String numStr) {
    return Container(
      width: 18,
      height: 18,
      alignment: Alignment.center,
      decoration: const BoxDecoration(
        color: PortalColors.forest,
        shape: BoxShape.circle,
      ),
      child: Text(
        numStr,
        style: PortalTheme.sans(
          size: 10.5,
          weight: FontWeight.w800,
          color: PortalColors.gold,
        ),
      ),
    );
  }

  Widget _modeSelectorButton({
    required ScanMode mode,
    required IconData icon,
    required String title,
    required String subtitle,
  }) {
    final active = _selectedMode == mode;
    return InkWell(
      borderRadius: BorderRadius.circular(14),
      onTap: () => setState(() => _selectedMode = mode),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
        decoration: BoxDecoration(
          color: active ? PortalColors.forest : PortalColors.parchment,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: active ? PortalColors.forest : PortalColors.ruleMed,
            width: 1.6,
          ),
        ),
        child: Row(
          children: [
            Icon(
              icon,
              size: 20,
              color: active ? PortalColors.gold : PortalColors.forest,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: PortalTheme.sans(
                      size: 13,
                      weight: FontWeight.w800,
                      color: active ? Colors.white : PortalColors.forest,
                    ),
                  ),
                  Text(
                    subtitle,
                    style: PortalTheme.sans(
                      size: 10,
                      weight: FontWeight.w600,
                      color: active ? PortalColors.gold : PortalColors.ink3,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _scannerOverlayIconBtn({
    required IconData icon,
    required String tooltip,
    required VoidCallback onTap,
  }) {
    return Material(
      color: Colors.black.withAlpha(148),
      shape: const CircleBorder(),
      child: IconButton(
        tooltip: tooltip,
        visualDensity: VisualDensity.compact,
        icon: Icon(icon, color: Colors.white, size: 19),
        onPressed: onTap,
      ),
    );
  }
}

/// Interactive Camera & Hardware NFC Permission Setup Bottom Sheet.
class _ScannerPermissionsSetupSheet extends StatefulWidget {
  final HardwareStatus initialStatus;
  final Future<void> Function() onRefreshRequested;

  const _ScannerPermissionsSetupSheet({
    required this.initialStatus,
    required this.onRefreshRequested,
  });

  @override
  State<_ScannerPermissionsSetupSheet> createState() =>
      _ScannerPermissionsSetupSheetState();
}

class _ScannerPermissionsSetupSheetState
    extends State<_ScannerPermissionsSetupSheet> with WidgetsBindingObserver {
  late HardwareStatus _status = widget.initialStatus;
  StreamSubscription<HardwareStatus>? _sub;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _sub = DeviceBridgeService.instance.hardwareStatusStream.listen((s) {
      if (mounted) setState(() => _status = s);
    });
    _refreshStatus();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _refreshStatus();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _sub?.cancel();
    super.dispose();
  }

  Future<void> _refreshStatus() async {
    await widget.onRefreshRequested();
    final latest = await DeviceBridgeService.instance.getHardwareStatus();
    if (mounted) setState(() => _status = latest);
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(22, 18, 22, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                const Icon(
                  Icons.security_update_good_rounded,
                  color: PortalColors.forest,
                  size: 26,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Scanner Permissions & NFC Setup',
                    style: PortalTheme.serif(size: 23),
                  ),
                ),
                IconButton(
                  onPressed: () => Navigator.of(context).pop(),
                  icon: const Icon(Icons.close_rounded),
                ),
              ],
            ),
            Text(
              'Configure your phone hardware once for seamless QR & NFC scanning.',
              style: PortalTheme.sans(size: 12.5, color: PortalColors.ink3),
            ),
            const SizedBox(height: 16),

            // 1. Camera QR Permission Card
            _permissionTile(
              icon: Icons.qr_code_scanner_rounded,
              title: 'Camera Access (QR Scanner)',
              statusLabel: _status.cameraGranted ? 'GRANTED' : 'REQUIRED',
              statusOk: _status.cameraGranted,
              description: _status.cameraGranted
                  ? 'Camera permission is active for QR & barcode student passes.'
                  : 'Allow camera access so the scanner can read student QR codes.',
              actionButton: _status.cameraGranted
                  ? null
                  : ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: PortalColors.forest,
                        foregroundColor: Colors.white,
                      ),
                      onPressed: () async {
                        final ok = await DeviceBridgeService.instance
                            .requestCameraPermission();
                        if (!ok) {
                          await DeviceBridgeService.instance.openAppSettings();
                        }
                        await _refreshStatus();
                      },
                      child: const Text('Grant Camera'),
                    ),
            ),
            const SizedBox(height: 12),

            // 2. NFC Hardware Integration Card
            _permissionTile(
              icon: Icons.nfc_rounded,
              title: 'NFC Reader (Student Smart Cards)',
              statusLabel: !_status.nfcSupported
                  ? 'NO NFC CHIP'
                  : (_status.nfcEnabled ? 'ACTIVE' : 'TURNED OFF'),
              statusOk: _status.isNfcReady,
              description: !_status.nfcSupported
                  ? 'This phone does not report built-in NFC hardware. QR & Manual ID scanning remain available.'
                  : (_status.nfcEnabled
                      ? 'Foreground NFC Reader Mode (NFC-A/B/F/V & NDEF/UID) is live! Hold cards near the back of your phone.'
                      : 'NFC is currently switched off in your phone settings. Turn it on to scan NFC cards.'),
              actionButton: !_status.nfcSupported
                  ? null
                  : (_status.nfcEnabled
                      ? OutlinedButton(
                          onPressed: _refreshStatus,
                          child: const Text('Re-Sync'),
                        )
                      : ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: PortalColors.gold,
                            foregroundColor: PortalColors.forest,
                          ),
                          onPressed: () async {
                            await DeviceBridgeService.instance
                                .openNfcSettings();
                          },
                          child: const Text('Turn On NFC'),
                        )),
            ),
            const SizedBox(height: 14),

            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: PortalColors.parchment,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: PortalColors.ruleMed),
              ),
              child: Row(
                children: [
                  const Icon(
                    Icons.timer_outlined,
                    size: 18,
                    color: PortalColors.forest,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      '1.5-Second Anti-Burst Protection is active on both NFC and QR scans to prevent accidental double reads.',
                      style: PortalTheme.sans(
                        size: 11.5,
                        weight: FontWeight.w600,
                        color: PortalColors.ink2,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () =>
                        DeviceBridgeService.instance.openAppSettings(),
                    icon: const Icon(Icons.settings_outlined, size: 17),
                    label: const Text('Phone App Settings'),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: PortalColors.forest,
                      foregroundColor: Colors.white,
                    ),
                    onPressed: () => Navigator.of(context).pop(),
                    child: const Text('Done'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _permissionTile({
    required IconData icon,
    required String title,
    required String statusLabel,
    required bool statusOk,
    required String description,
    Widget? actionButton,
  }) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: statusOk ? PortalColors.emeraldBorder : PortalColors.ruleMed,
          width: 1.5,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: PortalColors.forest, size: 22),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  title,
                  style: PortalTheme.sans(
                    size: 13.5,
                    weight: FontWeight.w800,
                    color: PortalColors.forest,
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
                decoration: BoxDecoration(
                  color:
                      statusOk ? PortalColors.emeraldBg : PortalColors.goldPale,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  statusLabel,
                  style: PortalTheme.sans(
                    size: 10,
                    weight: FontWeight.w800,
                    color: statusOk
                        ? PortalColors.emerald
                        : PortalColors.goldDark,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Row(
            children: [
              Expanded(
                child: Text(
                  description,
                  style: PortalTheme.sans(size: 12, color: PortalColors.ink2),
                ),
              ),
              if (actionButton != null) ...[
                const SizedBox(width: 10),
                actionButton,
              ],
            ],
          ),
        ],
      ),
    );
  }
}

class _OfflineSyncQueueSheet extends StatefulWidget {
  const _OfflineSyncQueueSheet();

  @override
  State<_OfflineSyncQueueSheet> createState() => _OfflineSyncQueueSheetState();
}

class _OfflineSyncQueueSheetState extends State<_OfflineSyncQueueSheet> {
  List<ScanLogEntry> _logs = [];

  @override
  void initState() {
    super.initState();
    _reload();
  }

  Future<void> _reload() async {
    final rows = await LocalDatabase.instance.getRecentScans(limit: 100);
    if (mounted) setState(() => _logs = rows);
  }

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.65,
      minChildSize: 0.4,
      maxChildSize: 0.9,
      builder: (context, scrollCtrl) {
        return Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('Offline Scan Queue', style: PortalTheme.serif(size: 24)),
                  IconButton(
                    onPressed: () => Navigator.of(context).pop(),
                    icon: const Icon(Icons.close_rounded),
                  ),
                ],
              ),
              ListenableBuilder(
                listenable: SyncManager.instance,
                builder: (context, _) {
                  final sm = SyncManager.instance;
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text(
                        sm.isOnline
                            ? 'Connection: Online • Pending Batch Rows: ${sm.pendingCount}'
                            : 'Connection: Offline — Scans safely stored in SQLite (${sm.pendingCount} pending)',
                        style: PortalTheme.sans(
                          size: 12.5,
                          weight: FontWeight.w600,
                          color: sm.isOnline
                              ? PortalColors.emerald
                              : PortalColors.burg,
                        ),
                      ),
                      if (sm.lastError != null) ...[
                        const SizedBox(height: 4),
                        Text(
                          sm.lastError!,
                          style: PortalTheme.sans(
                            size: 11.5,
                            color: PortalColors.burg,
                          ),
                        ),
                      ],
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                            child: ElevatedButton.icon(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: PortalColors.forest,
                                foregroundColor: Colors.white,
                              ),
                              onPressed: sm.isSyncing
                                  ? null
                                  : () async {
                                      await sm.syncNow();
                                      await _reload();
                                    },
                              icon: const Icon(Icons.sync_rounded, size: 18),
                              label: Text(
                                sm.isSyncing
                                    ? 'Syncing Batch...'
                                    : 'Sync Pending Now',
                              ),
                            ),
                          ),
                          const SizedBox(width: 10),
                          OutlinedButton(
                            onPressed: () async {
                              await LocalDatabase.instance.clearSyncedHistory();
                              await _reload();
                            },
                            child: const Text('Clear Synced'),
                          ),
                        ],
                      ),
                    ],
                  );
                },
              ),
              const SizedBox(height: 12),
              const Divider(),
              Expanded(
                child: _logs.isEmpty
                    ? Center(
                        child: Text(
                          'Queue is empty.',
                          style: PortalTheme.sans(color: PortalColors.ink3),
                        ),
                      )
                    : ListView.separated(
                        controller: scrollCtrl,
                        itemCount: _logs.length,
                        separatorBuilder: (_, __) => const Divider(height: 1),
                        itemBuilder: (context, idx) {
                          final item = _logs[idx];
                          return ListTile(
                            dense: true,
                            title: Text(
                              '${item.studentId} • ${item.subject} (${item.scanType.displayLabel})',
                              style: PortalTheme.sans(
                                size: 13,
                                weight: FontWeight.w700,
                              ),
                            ),
                            subtitle: Text(
                              'Log_ID: ${item.logId}\n${item.timestamp}',
                              style: PortalTheme.sans(
                                size: 11,
                                color: PortalColors.ink3,
                              ),
                            ),
                            trailing: Text(
                              item.syncStatus.toUpperCase(),
                              style: PortalTheme.sans(
                                size: 11,
                                weight: FontWeight.w800,
                                color: item.syncStatus == 'synced'
                                    ? PortalColors.emerald
                                    : (item.syncStatus == 'failed'
                                        ? PortalColors.burg
                                        : PortalColors.goldDark),
                              ),
                            ),
                          );
                        },
                      ),
              ),
            ],
          ),
        );
      },
    );
  }
}
