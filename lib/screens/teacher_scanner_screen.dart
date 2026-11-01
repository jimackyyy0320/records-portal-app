import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:nfc_manager/nfc_manager.dart';
import 'package:nfc_manager/nfc_manager_android.dart' as nfc_android;
import 'package:nfc_manager_ndef/nfc_manager_ndef.dart';

import '../config/app_config.dart';
import '../models/portal_models.dart';
import '../services/api_service.dart';
import '../services/local_database.dart';
import '../services/sync_manager.dart';
import '../theme/portal_theme.dart';

/// Seamless, offline-first QR + NFC Classroom Scanner built around the exact 3-step UX:
/// 1. Select Mode first (Attendance -> `Attendance Log` | Recitation -> `Recitation_Log` w/ Points_Awarded = 1)
/// 2. Select Subject (loaded from Sheet `12DvradQOqCeswwKMtdx7jaIKDRjMUuxWRRD_p1WBCQQ` -> "Reference" Column C)
/// 3. Editable Timestamp bar right above the scanner (ticks live by default, tap to pin/edit custom date & time)
class TeacherScannerScreen extends StatefulWidget {
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

class _TeacherScannerScreenState extends State<TeacherScannerScreen> {
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

  // Camera QR Scanner
  MobileScannerController? _cameraController;
  bool _cameraEnabled = true;

  // Hardware NFC Reader
  bool _nfcSupportedAndEnabled = false;
  bool _nfcSessionActive = false;
  String _nfcStatusHint = 'Checking NFC...';

  // Rapid-fire session state & feedback banner
  int _sessionScanCount = 0;
  List<ScanLogEntry> _recentScans = [];
  String? _bannerText;
  String? _bannerSubtitle;
  bool _bannerIsDuplicate = false;
  Timer? _bannerDismissTimer;
  bool _duplicateDialogOpen = false;
  final Map<String, int> _inMemoryCooldownMs = {};

  static final DateFormat _sheetTimestampFormat =
      DateFormat('yyyy-MM-dd HH:mm:ss');

  bool get _hasFacultyAccess => widget.session.isFaculty;

  @override
  void initState() {
    super.initState();
    if (!_hasFacultyAccess) {
      _loadingBootstrap = false;
      return;
    }

    _cameraController = MobileScannerController(
      formats: const [
        BarcodeFormat.qrCode,
        BarcodeFormat.code128,
        BarcodeFormat.code39,
      ],
      detectionSpeed: DetectionSpeed.normal,
      facing: CameraFacing.back,
      torchEnabled: false,
    );

    _clockTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted && _customPinnedTimestamp == null) {
        setState(() => _liveClock = DateTime.now());
      }
    });

    _loadSubjectsAndRecentScans();
    _startContinuousNfcListener();
  }

  @override
  void dispose() {
    _clockTimer?.cancel();
    _bannerDismissTimer?.cancel();
    _cameraController?.dispose();
    if (_nfcSessionActive) {
      NfcManager.instance.stopSession().catchError((_) {});
    }
    super.dispose();
  }

  DateTime get _effectiveTimestamp => _customPinnedTimestamp ?? _liveClock;

  String get _formattedTimestamp =>
      _sheetTimestampFormat.format(_effectiveTimestamp);

  Future<void> _loadSubjectsAndRecentScans() async {
    // 1. Load cached "Reference" Column C subjects immediately (<10ms offline-ready)
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

    // 2. Refresh from Google Sheet "Reference" Column C in background when online
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

  // ─────────────────────────────────────────────────────────────
  //  STEP 3: EDITABLE TIMESTAMP DIALOG (DATE + TIME + SECONDS)
  // ─────────────────────────────────────────────────────────────

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
  //  HARDWARE NFC CONTINUOUS READER (NDEF + ANDROID TAG UID)
  // ─────────────────────────────────────────────────────────────

  Future<void> _startContinuousNfcListener() async {
    if (!Platform.isAndroid && !Platform.isIOS) {
      setState(() => _nfcStatusHint = 'NFC unavailable on this platform');
      return;
    }
    try {
      final availability = await NfcManager.instance.checkAvailability();
      if (!mounted) return;
      if (availability != NfcAvailability.enabled) {
        setState(() {
          _nfcSupportedAndEnabled = false;
          _nfcStatusHint = availability == NfcAvailability.disabled
              ? 'NFC is turned off in Android Settings'
              : 'No NFC hardware on device';
        });
        return;
      }

      setState(() {
        _nfcSupportedAndEnabled = true;
        _nfcSessionActive = true;
        _nfcStatusHint = 'NFC Active — Tap student card anytime';
      });

      await NfcManager.instance.startSession(
        pollingOptions: const {
          NfcPollingOption.iso14443,
          NfcPollingOption.iso15693,
        },
        onDiscovered: (NfcTag tag) async {
          final extractedId = await _extractStudentIdFromNfcTag(tag);
          if (extractedId != null && extractedId.trim().isNotEmpty) {
            await _recordScannedStudent(extractedId, sourceLabel: 'NFC');
          }
          // Intentionally keep NFC session open for rapid back-to-back classroom taps!
        },
      );
    } catch (e) {
      if (mounted) {
        setState(() {
          _nfcSessionActive = false;
          _nfcStatusHint = 'NFC error: $e';
        });
      }
    }
  }

  Future<String?> _extractStudentIdFromNfcTag(NfcTag tag) async {
    // 1. Prefer NDEF Text / URI / MIME payload when written on the card
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

    // 2. Fallback to Android hardware NFC Tag UID (ISO14443 / Mifare / ISO15693)
    if (Platform.isAndroid) {
      final uidBytes = nfc_android.NfcTagAndroid.from(tag)?.id;
      if (uidBytes != null && uidBytes.isNotEmpty) {
        return uidBytes
            .map((b) => b.toRadixString(16).padLeft(2, '0'))
            .join(':')
            .toUpperCase();
      }
    }
    return null;
  }

  String _decodeNdefRecordPayload(NdefRecord record) {
    final payload = record.payload;
    if (payload.isEmpty) return '';

    // NFC Well-Known Text Record ('T' == 0x54)
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

    // NFC Well-Known URI Record ('U' == 0x55)
    if (record.type.length == 1 && record.type[0] == 0x55 && payload.length > 1) {
      return utf8.decode(payload.sublist(1), allowMalformed: true).trim();
    }

    return utf8.decode(payload, allowMalformed: true).trim();
  }

  // ─────────────────────────────────────────────────────────────
  //  CAMERA QR CODE HANDLER & SHARED RECORDING PIPELINE
  // ─────────────────────────────────────────────────────────────

  void _onCameraBarcodeDetected(BarcodeCapture capture) {
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
    // Support JSON or URL-encoded QR codes if used (e.g., ?id=2026-001 or {"id":"..."})
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

    final studentId = rawStudentId.trim();
    if (studentId.isEmpty) return;

    final subject = _selectedSubject?.trim() ?? '';
    if (subject.isEmpty) {
      _flashBanner(
        title: 'Select a Subject first (Step 2)',
        subtitle: 'Choose a subject before scanning.',
        isDuplicate: true,
      );
      return;
    }

    // Hardware camera-frame anti-burst guard ONLY for 30fps live video ('QR')
    // so a single wave doesn't fire 20 video frames at once.
    // Discrete NFC taps and Manual ID entry have zero cooldown for Recitation.
    final frameKey = '${_selectedMode.wireValue}|$subject|$studentId';
    final nowMs = DateTime.now().millisecondsSinceEpoch;
    if (sourceLabel == 'QR') {
      final prevMs = _inMemoryCooldownMs[frameKey];
      if (prevMs != null && (nowMs - prevMs) < 1200) {
        return;
      }
      _inMemoryCooldownMs[frameKey] = nowMs;
    }

    final timestampStr = _formattedTimestamp;
    final datePrefix = timestampStr.length >= 10
        ? timestampStr.substring(0, 10)
        : DateFormat('yyyy-MM-dd').format(_effectiveTimestamp);
    final studentName = _studentDirectory[studentId];
    bool isOverrideAttendance = false;

    // For Attendance ONLY: check if student already has an attendance scan
    // for this Subject on this class date, warn Faculty, and offer Override access.
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
          // Brief camera frame guard right after closing the dialog
          _inMemoryCooldownMs[frameKey] =
              DateTime.now().millisecondsSinceEpoch + 600;
          _duplicateDialogOpen = false;
        }

        if (!approvedOverride) {
          if (mounted) {
            _flashBanner(
              title: 'Skipped Duplicate ($studentId)',
              subtitle: '$subject • Already logged at ${existingAttendance.first.timestamp}',
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
    _bannerDismissTimer = Timer(const Duration(milliseconds: 2400), () {
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
    _inMemoryCooldownMs
        .remove('${entry.scanType.wireValue}|${entry.subject}|${entry.studentId}');
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
                  style: PortalTheme.serif(size: 26, color: PortalColors.forest),
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

    return Scaffold(
      backgroundColor: PortalColors.parchment,
      appBar: AppBar(
        backgroundColor: PortalColors.forest,
        foregroundColor: Colors.white,
        title: Text(
          'Classroom Scanner',
          style: PortalTheme.serif(size: 23, color: Colors.white),
        ),
        actions: [
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
            // ─────────────────────────────────────────────────────
            //  SETUP CONTROLS: 1. MODE -> 2. SUBJECT -> 3. TIMESTAMP
            // ─────────────────────────────────────────────────────
            Container(
              width: double.infinity,
              padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
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
                          size: 11,
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
                  const SizedBox(height: 8),
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
                  const SizedBox(height: 12),

                  // STEP 2: Select Subject (from "Reference" Column C)
                  Row(
                    children: [
                      _stepBadge('2'),
                      const SizedBox(width: 6),
                      Text(
                        'SUBJECT (REFERENCE COL C)',
                        style: PortalTheme.sans(
                          size: 11,
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
                  const SizedBox(height: 6),
                  SizedBox(
                    height: 38,
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
                            size: 12.5,
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
                  const SizedBox(height: 10),

                  // STEP 3: Editable Timestamp Bar Above the Scanner
                  InkWell(
                    borderRadius: BorderRadius.circular(12),
                    onTap: _editTimestamp,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 9,
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
                                    size: 14,
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
                  if (_cameraEnabled && _cameraController != null)
                    MobileScanner(
                      controller: _cameraController!,
                      onDetect: _onCameraBarcodeDetected,
                      errorBuilder: (context, error) => Container(
                        color: PortalColors.forestDark,
                        alignment: Alignment.center,
                        padding: const EdgeInsets.all(24),
                        child: Text(
                          'Camera unavailable (${error.errorCode.name}).\nNFC & Manual ID scanning remain active.',
                          textAlign: TextAlign.center,
                          style: PortalTheme.sans(color: Colors.white),
                        ),
                      ),
                    )
                  else
                    Container(
                      color: PortalColors.forestDark,
                      alignment: Alignment.center,
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
                            style: PortalTheme.sans(
                              size: 12.5,
                              color: Colors.white70,
                            ),
                          ),
                        ],
                      ),
                    ),

                  // QR Reticle Frame
                  if (_cameraEnabled)
                    IgnorePointer(
                      child: Center(
                        child: Container(
                          width: 210,
                          height: 210,
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(22),
                            border: Border.all(
                              color: _selectedMode == ScanMode.recitation
                                  ? PortalColors.gold
                                  : Colors.white,
                              width: 3,
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
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 5,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.black.withAlpha(158),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.nfc_rounded,
                                size: 15,
                                color: _nfcSupportedAndEnabled
                                    ? PortalColors.gold
                                    : Colors.white54,
                              ),
                              const SizedBox(width: 5),
                              Text(
                                _nfcSupportedAndEnabled
                                    ? 'QR + NFC Ready'
                                    : 'QR Ready (NFC Off)',
                                style: PortalTheme.sans(
                                  size: 11,
                                  weight: FontWeight.w700,
                                  color: Colors.white,
                                ),
                              ),
                            ],
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
                        if (_cameraEnabled) ...[
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
                              child: Text(
                                'Point camera at QR code or tap student NFC card to begin.',
                                textAlign: TextAlign.center,
                                style: PortalTheme.sans(
                                  size: 12.5,
                                  color: PortalColors.ink3,
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
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
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
                      size: 13.5,
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
