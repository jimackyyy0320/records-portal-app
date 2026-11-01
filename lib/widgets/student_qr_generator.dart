import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:share_plus/share_plus.dart';

import '../services/device_bridge_service.dart';
import '../theme/portal_theme.dart';
import 'common_widgets.dart';

/// Pure-local Student ID QR Code Generator (100% independent of Google Drive).
class StudentQrGenerator {
  StudentQrGenerator._();

  /// Encodes the exact trimmed Student ID expected by the Faculty Classroom Scanner
  /// (`Attendance Log` & `Recitation_Log` Column C).
  static String normalizePayload(String studentId) {
    final trimmed = studentId.trim();
    if (trimmed.isEmpty) {
      throw ArgumentError('Student ID cannot be empty when generating QR pass.');
    }
    return trimmed;
  }

  /// Builds a clean PNG filename for saving/sharing a generated Student QR Pass.
  static String buildQrFileName(String studentId) {
    final clean = studentId
        .trim()
        .replaceAll(RegExp(r'[^A-Za-z0-9._-]'), '_')
        .replaceAll(RegExp(r'_+'), '_');
    final safe = clean.isEmpty ? 'Learner' : clean;
    return 'MIS_SHS_QR_$safe.png';
  }
}

/// Official in-app MIS-SHS Student QR Pass generator & PNG card exporter.
class StudentQrPassDialog extends StatefulWidget {
  final String studentId;
  final String? studentName;

  const StudentQrPassDialog({
    super.key,
    required this.studentId,
    this.studentName,
  });

  static Future<void> show(
    BuildContext context, {
    required String studentId,
    String? studentName,
  }) {
    return showDialog<void>(
      context: context,
      builder: (_) => StudentQrPassDialog(
        studentId: studentId,
        studentName: studentName,
      ),
    );
  }

  @override
  State<StudentQrPassDialog> createState() => _StudentQrPassDialogState();
}

class _StudentQrPassDialogState extends State<StudentQrPassDialog> {
  final GlobalKey _cardBoundaryKey = GlobalKey();
  bool _busy = false;
  String? _savedBanner;

  late final String _qrPayload =
      StudentQrGenerator.normalizePayload(widget.studentId);

  Future<Uint8List?> _capturePassPngBytes() async {
    final boundary = _cardBoundaryKey.currentContext?.findRenderObject()
        as RenderRepaintBoundary?;
    if (boundary == null) return null;
    final ui.Image image = await boundary.toImage(pixelRatio: 3.0);
    final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
    return byteData?.buffer.asUint8List();
  }

  Future<void> _saveToDownloads() async {
    setState(() => _busy = true);
    try {
      final bytes = await _capturePassPngBytes();
      if (bytes == null) return;
      final saved = await DeviceBridgeService.instance.saveBytesToDownloads(
        fileName: StudentQrGenerator.buildQrFileName(_qrPayload),
        bytes: bytes,
      );
      if (!mounted) return;
      setState(() => _savedBanner = 'Saved to ${saved.displayPath}');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('✅ QR Pass saved to ${saved.displayPath}')),
      );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _sharePass() async {
    setState(() => _busy = true);
    try {
      final bytes = await _capturePassPngBytes();
      if (bytes == null) return;
      final saved = await DeviceBridgeService.instance.saveBytesToDownloads(
        fileName: StudentQrGenerator.buildQrFileName(_qrPayload),
        bytes: bytes,
      );
      await Share.shareXFiles(
        [XFile(saved.tempShareFile.path, mimeType: 'image/png')],
        text: 'MIS-SHS Learner QR Pass — ID: $_qrPayload',
      );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final displayName = widget.studentName?.trim();
    final hasDistinctName =
        displayName != null && displayName.isNotEmpty && displayName != _qrPayload;

    return Dialog(
      insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
      backgroundColor: Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(26)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 380),
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 18),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Printable / Shareable Official QR Pass Card
              RepaintBoundary(
                key: _cardBoundaryKey,
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.fromLTRB(20, 20, 20, 20),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [PortalColors.forest, PortalColors.forestDark],
                    ),
                    borderRadius: BorderRadius.circular(22),
                    border: Border.all(color: PortalColors.gold, width: 2),
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const SchoolLogoBadge(
                            size: 40,
                            borderWidth: 2,
                            showShadow: false,
                          ),
                          const SizedBox(width: 10),
                          Flexible(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'MIS-SHS LEARNER APP',
                                  style: PortalTheme.sans(
                                    size: 11.5,
                                    weight: FontWeight.w800,
                                    letterSpacing: 1.1,
                                    color: PortalColors.gold,
                                  ),
                                ),
                                Text(
                                  'Official Student QR Pass',
                                  style: PortalTheme.serif(
                                    size: 17,
                                    color: Colors.white,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),

                      // Crisp White Quiet-Zone Frame for Instant Camera Scanning
                      Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(18),
                          boxShadow: const [
                            BoxShadow(
                              color: Color(0x33000000),
                              blurRadius: 12,
                              offset: Offset(0, 4),
                            ),
                          ],
                        ),
                        child: QrImageView(
                          data: _qrPayload,
                          version: QrVersions.auto,
                          size: 205,
                          gapless: true,
                          errorCorrectionLevel: QrErrorCorrectLevel.H,
                          backgroundColor: Colors.white,
                          eyeStyle: const QrEyeStyle(
                            eyeShape: QrEyeShape.square,
                            color: PortalColors.forestDark,
                          ),
                          dataModuleStyle: const QrDataModuleStyle(
                            dataModuleShape: QrDataModuleShape.square,
                            color: PortalColors.forestDark,
                          ),
                        ),
                      ),
                      const SizedBox(height: 14),

                      if (hasDistinctName) ...[
                        Text(
                          displayName,
                          textAlign: TextAlign.center,
                          style: PortalTheme.serif(
                            size: 20,
                            weight: FontWeight.w700,
                            color: Colors.white,
                          ),
                        ),
                        const SizedBox(height: 6),
                      ],

                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 5,
                        ),
                        decoration: BoxDecoration(
                          color: PortalColors.gold,
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          'STUDENT ID: $_qrPayload',
                          style: PortalTheme.sans(
                            size: 12,
                            weight: FontWeight.w800,
                            letterSpacing: 0.8,
                            color: PortalColors.forestDark,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              if (_savedBanner != null) ...[
                const SizedBox(height: 10),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 7,
                  ),
                  decoration: BoxDecoration(
                    color: PortalColors.emeraldBg,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    '✅ $_savedBanner',
                    textAlign: TextAlign.center,
                    style: PortalTheme.sans(
                      size: 11.5,
                      weight: FontWeight.w700,
                      color: PortalColors.emerald,
                    ),
                  ),
                ),
              ],

              const SizedBox(height: 14),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 11,
                        ),
                      ),
                      onPressed: _busy ? null : _saveToDownloads,
                      child: const Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.download_rounded, size: 16),
                          SizedBox(width: 6),
                          Flexible(
                            child: Text(
                              'Save PNG',
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: PortalColors.gold,
                        foregroundColor: PortalColors.forestDark,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 11,
                        ),
                      ),
                      onPressed: _busy ? null : _sharePass,
                      child: const Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.ios_share_rounded, size: 16),
                          SizedBox(width: 6),
                          Flexible(
                            child: Text(
                              'Share',
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              SizedBox(
                width: double.infinity,
                child: TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: Text(
                    'Close',
                    style: PortalTheme.sans(
                      size: 13,
                      weight: FontWeight.w700,
                      color: PortalColors.ink3,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
