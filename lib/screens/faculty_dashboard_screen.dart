import 'dart:async';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import '../models/portal_models.dart';
import '../services/api_service.dart';
import '../services/sync_manager.dart';
import '../theme/portal_theme.dart';
import '../widgets/common_widgets.dart';
import 'student_dashboard_screen.dart';
import 'teacher_scanner_screen.dart';

/// Full Faculty LMS Dashboard replicating `#subject-screen`, `#faculty-dashboard`,
/// `#fac-utilities` (Morning/Afternoon Attendance PNG Generator), `#edit-modal`,
/// and individual student drill-down from `index.html`, plus quick access to the
/// offline-first QR & NFC Classroom Scanner.
class FacultyDashboardScreen extends StatefulWidget {
  final UserSession session;
  final List<AnnouncementItem> announcements;
  final VoidCallback onLogout;

  const FacultyDashboardScreen({
    super.key,
    required this.session,
    required this.announcements,
    required this.onLogout,
  });

  @override
  State<FacultyDashboardScreen> createState() => _FacultyDashboardScreenState();
}

class _FacultyDashboardScreenState extends State<FacultyDashboardScreen> {
  SubjectItem? _activeSubject;
  List<List<dynamic>> _rosterData = const [];
  Map<String, String> _studentAvatars = const {};
  bool _loadingRoster = false;
  int _rosterViewTab = 0; // 0: Overview Table, 1: Student Cards
  String? _viewedStudentId;

  DateTime _amReportDate = DateTime.now();
  DateTime _pmReportDate = DateTime.now();
  bool _generatingReport = false;

  Timer? _autoRefreshTimer;

  @override
  void dispose() {
    _autoRefreshTimer?.cancel();
    super.dispose();
  }

  void _openClassroomScanner({String? initialSubject}) {
    if (!widget.session.isFaculty) return;
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => TeacherScannerScreen(
          session: widget.session,
          facultySubjects: widget.session.subjects,
          initialSubjectCode: initialSubject ?? _activeSubject?.code,
        ),
      ),
    );
  }

  Future<void> _loadSubjectRoster(SubjectItem subj) async {
    setState(() {
      _activeSubject = subj;
      _viewedStudentId = null;
      _loadingRoster = true;
    });

    try {
      final matrix = await ApiService.instance.fetchSubjectRoster(subj.code);
      if (!mounted) return;
      setState(() {
        _rosterData = matrix;
        _loadingRoster = false;
      });
      _startSilentRosterRefresh();

      // Batch fetch student avatars for the Student Cards view
      final ids = <String>[];
      for (int r = 1; r < matrix.length; r++) {
        if (matrix[r].length > 1) {
          final sId = matrix[r][1].toString().trim();
          if (sId.isNotEmpty && sId != '-') ids.add(sId);
        }
      }
      if (ids.isNotEmpty) {
        final avatars = await ApiService.instance.getMultipleAvatars(ids);
        if (mounted) {
          setState(() => _studentAvatars = avatars);
        }
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loadingRoster = false;
        _activeSubject = null;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error fetching roster: $e')),
      );
    }
  }

  void _startSilentRosterRefresh() {
    _autoRefreshTimer?.cancel();
    _autoRefreshTimer = Timer.periodic(const Duration(seconds: 60), (_) async {
      final subj = _activeSubject;
      if (subj == null || _viewedStudentId != null || !mounted) return;
      try {
        final matrix = await ApiService.instance.fetchSubjectRoster(subj.code);
        if (mounted) setState(() => _rosterData = matrix);
      } catch (_) {}
    });
  }

  Future<void> _openEditScoreDialog({
    required int rowIndex,
    required int colIndex,
    required String headerName,
    required String currentVal,
    required String studentId,
  }) async {
    final ctrl = TextEditingController(
      text: currentVal == '-' ? '' : currentVal,
    );
    final savedVal = await showDialog<String>(
      context: context,
      builder: (ctx) => Dialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('Edit Score', style: PortalTheme.serif(size: 24)),
              const SizedBox(height: 6),
              Text(
                'EDITING: ${headerName.toUpperCase()}',
                style: PortalTheme.sans(
                  size: 11.5,
                  weight: FontWeight.w700,
                  letterSpacing: 1.0,
                  color: PortalColors.ink3,
                ),
              ),
              const SizedBox(height: 14),
              TextField(
                controller: ctrl,
                autofocus: true,
                textAlign: TextAlign.center,
                style: PortalTheme.sans(size: 18, weight: FontWeight.w600),
                decoration: InputDecoration(
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
              const SizedBox(height: 18),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.of(ctx).pop(),
                      child: const Text('Cancel'),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: PortalColors.gold,
                        foregroundColor: PortalColors.forest,
                      ),
                      onPressed: () => Navigator.of(ctx).pop(ctrl.text),
                      child: const Text('💾 Save'),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );

    if (savedVal == null || _activeSubject == null) return;

    try {
      final res = await ApiService.instance.updateCellData(
        subjectCode: _activeSubject!.code,
        rowIndex: rowIndex,
        colIndex: colIndex,
        newValue: savedVal,
        studentId: studentId,
      );
      if (res['success'] == true) {
        final refreshed = await ApiService.instance
            .fetchSubjectRoster(_activeSubject!.code);
        if (mounted) setState(() => _rosterData = refreshed);
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Save failed: ${res['message'] ?? "Unknown error"}'),
          ),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Save failed: $e')),
      );
    }
  }

  Future<void> _generateAttendancePng({required bool isMorning}) async {
    final date = isMorning ? _amReportDate : _pmReportDate;
    final dateStr = DateFormat('yyyy-MM-dd').format(date);

    setState(() => _generatingReport = true);
    try {
      final report =
          await ApiService.instance.fetchDailyAttendanceReport(dateStr);
      final targetBlock = (isMorning ? report['morning'] : report['afternoon']);
      final blockMap = targetBlock is Map
          ? Map<String, dynamic>.from(targetBlock)
          : <String, dynamic>{};
      final presentList = (blockMap['present'] as List?)
              ?.map((e) => e.toString())
              .toList() ??
          const <String>[];
      final absentList = (blockMap['absent'] as List?)
              ?.map((e) => e.toString())
              .toList() ??
          const <String>[];

      if (!mounted) return;
      await showDialog<void>(
        context: context,
        builder: (_) => _AttendanceReportPreviewDialog(
          isMorning: isMorning,
          date: date,
          dateStr: dateStr,
          present: presentList,
          absent: absentList,
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error generating report: $e')),
      );
    } finally {
      if (mounted) setState(() => _generatingReport = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    // Drill-down view for an individual student (with Evaluation Z-Score tab!)
    if (_viewedStudentId != null && _activeSubject != null) {
      return StudentDashboardScreen(
        session: widget.session,
        announcements: widget.announcements,
        onSessionUpdated: (_) {},
        onLogout: widget.onLogout,
        facultyViewedStudentId: _viewedStudentId,
        facultyFixedSubjectCode: _activeSubject!.code,
        onFacultyBackToRoster: () => setState(() => _viewedStudentId = null),
      );
    }

    return ParchmentScaffold(
      topBanner: widget.announcements.isNotEmpty
          ? AnnouncementMarqueeBanner(announcements: widget.announcements)
          : null,
      floatingActionButton: FloatingActionButton(
        tooltip: 'Logout',
        backgroundColor: PortalColors.burg,
        foregroundColor: Colors.white,
        onPressed: widget.onLogout,
        child: const Icon(Icons.logout_rounded),
      ),
      child: _activeSubject == null
          ? _buildSubjectSelectionHome()
          : _buildFacultyRosterLms(),
    );
  }

  Widget _buildScannerQuickCard({String? subjectCode}) {
    return ListenableBuilder(
      listenable: SyncManager.instance,
      builder: (context, _) {
        final sm = SyncManager.instance;
        return Container(
          margin: const EdgeInsets.only(bottom: 18),
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [PortalColors.forest, PortalColors.forestMid],
            ),
            borderRadius: BorderRadius.circular(20),
            boxShadow: const [
              BoxShadow(
                color: Color(0x281A3A2A),
                blurRadius: 18,
                offset: Offset(0, 6),
              ),
            ],
          ),
          child: Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: PortalColors.gold.withAlpha(46),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: const Icon(
                  Icons.qr_code_scanner_rounded,
                  color: PortalColors.gold,
                  size: 28,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'QR & NFC Classroom Scanner',
                      style: PortalTheme.serif(
                        size: 21,
                        color: Colors.white,
                      ),
                    ),
                    Text(
                      sm.pendingCount > 0
                          ? '${sm.pendingCount} offline scan(s) queued for automatic sync'
                          : 'Offline-first Attendance & Recitation (+1) batch scanner',
                      style: PortalTheme.sans(
                        size: 11.5,
                        color: Colors.white.withAlpha(210),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: PortalColors.gold,
                  foregroundColor: PortalColors.forest,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 11,
                  ),
                ),
                onPressed: () =>
                    _openClassroomScanner(initialSubject: subjectCode),
                child: Text(
                  'SCAN',
                  style: PortalTheme.sans(
                    size: 12,
                    weight: FontWeight.w800,
                    color: PortalColors.forest,
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildSubjectSelectionHome() {
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(18, 8, 18, 95),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 660),
          child: Column(
            children: [
              const PortalHeader(),
              _buildScannerQuickCard(),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(
                  horizontal: 24,
                  vertical: 34,
                ),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(22),
                  border: Border.all(color: PortalColors.rule),
                  boxShadow: const [
                    BoxShadow(
                      color: Color(0x1F1A3A2A),
                      blurRadius: 24,
                      offset: Offset(0, 8),
                    ),
                  ],
                ),
                child: Column(
                  children: [
                    Text(
                      'Select Subject',
                      style: PortalTheme.serif(size: 26, italic: true),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Welcome back, Professor ${widget.session.name}.',
                      textAlign: TextAlign.center,
                      style: PortalTheme.sans(
                        size: 13.5,
                        weight: FontWeight.w600,
                        color: PortalColors.ink3,
                      ),
                    ),
                    const SizedBox(height: 24),
                    Wrap(
                      spacing: 10,
                      runSpacing: 10,
                      alignment: WrapAlignment.center,
                      children: widget.session.subjects.map((subj) {
                        return ActionChip(
                          backgroundColor: PortalColors.parchment,
                          side: const BorderSide(
                            color: PortalColors.ruleMed,
                            width: 1.8,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(50),
                          ),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 18,
                            vertical: 11,
                          ),
                          label: Text(
                            subj.code.toUpperCase(),
                            style: PortalTheme.sans(
                              size: 13,
                              weight: FontWeight.w800,
                              letterSpacing: 1.5,
                              color: PortalColors.forest,
                            ),
                          ),
                          onPressed: () => _loadSubjectRoster(subj),
                        );
                      }).toList(),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildFacultyRosterLms() {
    final subj = _activeSubject!;
    return Column(
      children: [
        // Top LMS Header Bar
        Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
          color: PortalColors.forest,
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Faculty LMS',
                      style: PortalTheme.serif(size: 24, color: Colors.white),
                    ),
                    Text(
                      'Logged in as: ${widget.session.name}',
                      style: PortalTheme.sans(
                        size: 12,
                        color: PortalColors.gold,
                      ),
                    ),
                  ],
                ),
              ),
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: PortalColors.gold,
                  foregroundColor: PortalColors.forest,
                  visualDensity: VisualDensity.compact,
                ),
                onPressed: () =>
                    _openClassroomScanner(initialSubject: subj.code),
                icon: const Icon(Icons.qr_code_scanner_rounded, size: 17),
                label: const Text('Scan'),
              ),
            ],
          ),
        ),
        Expanded(
          child: _loadingRoster
              ? const Center(
                  child: CircularProgressIndicator(color: PortalColors.forest),
                )
              : SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 95),
                  child: Center(
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 960),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          // Generate Daily Attendance PNG Reports (#fac-utilities)
                          _buildReportGeneratorCard(),
                          const SizedBox(height: 18),

                          // Roster Title + Back button
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Expanded(
                                child: Text(
                                  '${subj.name} (${subj.code})',
                                  style: PortalTheme.serif(size: 26),
                                ),
                              ),
                              OutlinedButton(
                                onPressed: () {
                                  _autoRefreshTimer?.cancel();
                                  setState(() {
                                    _activeSubject = null;
                                    _rosterData = const [];
                                  });
                                },
                                child: const Text('← Subjects'),
                              ),
                            ],
                          ),
                          const SizedBox(height: 14),

                          // Overview Table vs Student Cards toggle
                          Center(
                            child: Container(
                              padding: const EdgeInsets.all(5),
                              decoration: BoxDecoration(
                                color: PortalColors.forestFaint,
                                borderRadius: BorderRadius.circular(16),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  _rosterTabBtn('🗂️ Overview Table', 0),
                                  _rosterTabBtn('👤 Student Cards', 1),
                                ],
                              ),
                            ),
                          ),
                          const SizedBox(height: 16),

                          if (_rosterViewTab == 0)
                            _buildOverviewTable()
                          else
                            _buildStudentCardsList(),
                        ],
                      ),
                    ),
                  ),
                ),
        ),
      ],
    );
  }

  Widget _rosterTabBtn(String label, int idx) {
    final active = _rosterViewTab == idx;
    return InkWell(
      borderRadius: BorderRadius.circular(12),
      onTap: () => setState(() => _rosterViewTab = idx),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          color: active ? PortalColors.forest : Colors.transparent,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Text(
          label.toUpperCase(),
          style: PortalTheme.sans(
            size: 11.5,
            weight: FontWeight.w700,
            color: active ? PortalColors.gold : PortalColors.ink3,
          ),
        ),
      ),
    );
  }

  Widget _buildReportGeneratorCard() {
    Widget sessionRow({
      required String label,
      required DateTime selectedDate,
      required VoidCallback onPickDate,
      required VoidCallback onGenerate,
      required bool goldStyle,
    }) {
      return Row(
        children: [
          Expanded(
            child: InkWell(
              borderRadius: BorderRadius.circular(10),
              onTap: onPickDate,
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 10,
                ),
                decoration: BoxDecoration(
                  border: Border.all(color: PortalColors.ruleMed, width: 1.5),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      label.toUpperCase(),
                      style: PortalTheme.sans(
                        size: 10,
                        weight: FontWeight.w800,
                        color: PortalColors.ink3,
                      ),
                    ),
                    Text(
                      DateFormat('yyyy-MM-dd').format(selectedDate),
                      style: PortalTheme.sans(
                        size: 14,
                        weight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(width: 10),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor:
                  goldStyle ? PortalColors.gold : PortalColors.forest,
              foregroundColor:
                  goldStyle ? PortalColors.forest : Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            ),
            onPressed: _generatingReport ? null : onGenerate,
            child: Text(
              goldStyle ? '📥 Afternoon PNG' : '📥 Morning PNG',
              style: PortalTheme.sans(
                size: 12,
                weight: FontWeight.w800,
                color: goldStyle ? PortalColors.forest : Colors.white,
              ),
            ),
          ),
        ],
      );
    }

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: PortalColors.rule),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Generate Reports',
            style: PortalTheme.serif(size: 22, italic: true),
          ),
          const SizedBox(height: 12),
          sessionRow(
            label: 'Morning Session (PKLP)',
            selectedDate: _amReportDate,
            onPickDate: () async {
              final d = await showDatePicker(
                context: context,
                initialDate: _amReportDate,
                firstDate: DateTime(2023),
                lastDate: DateTime(2035),
              );
              if (d != null) setState(() => _amReportDate = d);
            },
            onGenerate: () => _generateAttendancePng(isMorning: true),
            goldStyle: false,
          ),
          const SizedBox(height: 10),
          sessionRow(
            label: 'Afternoon Session (PGP)',
            selectedDate: _pmReportDate,
            onPickDate: () async {
              final d = await showDatePicker(
                context: context,
                initialDate: _pmReportDate,
                firstDate: DateTime(2023),
                lastDate: DateTime(2035),
              );
              if (d != null) setState(() => _pmReportDate = d);
            },
            onGenerate: () => _generateAttendancePng(isMorning: false),
            goldStyle: true,
          ),
        ],
      ),
    );
  }

  Widget _buildOverviewTable() {
    if (_rosterData.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Text(
            'No roster records found.',
            style: PortalTheme.sans(color: PortalColors.ink3),
          ),
        ),
      );
    }

    final headers = _rosterData.first;
    final rows = _rosterData.sublist(1);

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: PortalColors.rule),
      ),
      clipBehavior: Clip.antiAlias,
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: DataTable(
          headingRowColor: WidgetStateProperty.all(PortalColors.forest),
          headingTextStyle: PortalTheme.sans(
            size: 11,
            weight: FontWeight.w700,
            letterSpacing: 0.8,
            color: Colors.white,
          ),
          columns: headers
              .map(
                (h) => DataColumn(
                  label: Text(h.toString().toUpperCase()),
                ),
              )
              .toList(),
          rows: List<DataRow>.generate(rows.length, (idx) {
            final rIndex = idx + 1; // 1-based sheet data row index
            final row = rows[idx];
            final studentId =
                row.length > 1 ? row[1].toString().trim() : '';

            return DataRow(
              cells: List<DataCell>.generate(headers.length, (c) {
                final rawVal = c < row.length ? row[c].toString() : '';
                final display = rawVal.isEmpty ? '-' : rawVal;

                if (c == 2 && studentId.isNotEmpty && studentId != '-') {
                  return DataCell(
                    Text(
                      '📋 $display',
                      style: PortalTheme.sans(
                        size: 13,
                        weight: FontWeight.w700,
                        color: PortalColors.goldDark,
                      ),
                    ),
                    onTap: () => setState(() => _viewedStudentId = studentId),
                  );
                }

                if (c > 3 && studentId.isNotEmpty && studentId != '-') {
                  return DataCell(
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(display),
                        const SizedBox(width: 4),
                        const Icon(
                          Icons.edit_outlined,
                          size: 13,
                          color: PortalColors.ink3,
                        ),
                      ],
                    ),
                    onTap: () => _openEditScoreDialog(
                      rowIndex: rIndex,
                      colIndex: c,
                      headerName: headers[c].toString(),
                      currentVal: display,
                      studentId: studentId,
                    ),
                  );
                }

                return DataCell(Text(display));
              }),
            );
          }),
        ),
      ),
    );
  }

  Widget _buildStudentCardsList() {
    final rows = _rosterData.length > 1 ? _rosterData.sublist(1) : const [];
    return Column(
      children: rows.map((row) {
        final sId = row.length > 1 ? row[1].toString().trim() : '';
        final sName = row.length > 2 ? row[2].toString().trim() : '';
        if (sId.isEmpty || sId == '-') return const SizedBox.shrink();

        final avatarBytes = decodeDataUrlBytes(_studentAvatars[sId]);
        return Card(
          elevation: 0,
          margin: const EdgeInsets.only(bottom: 10),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: const BorderSide(color: PortalColors.ruleMed),
          ),
          child: ListTile(
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 16,
              vertical: 6,
            ),
            leading: CircleAvatar(
              radius: 22,
              backgroundColor: PortalColors.parchment,
              backgroundImage:
                  avatarBytes != null ? MemoryImage(avatarBytes) : null,
              child: avatarBytes == null
                  ? const Text('🎓', style: TextStyle(fontSize: 20))
                  : null,
            ),
            title: Text(
              sName,
              style: PortalTheme.sans(
                size: 14.5,
                weight: FontWeight.w700,
                color: PortalColors.forest,
              ),
            ),
            subtitle: Text(
              sId,
              style: PortalTheme.sans(
                size: 11.5,
                weight: FontWeight.w600,
                color: PortalColors.ink3,
              ),
            ),
            trailing: const Icon(
              Icons.arrow_forward_rounded,
              color: PortalColors.goldDark,
            ),
            onTap: () => setState(() => _viewedStudentId = sId),
          ),
        );
      }).toList(),
    );
  }
}

class _AttendanceReportPreviewDialog extends StatefulWidget {
  final bool isMorning;
  final DateTime date;
  final String dateStr;
  final List<String> present;
  final List<String> absent;

  const _AttendanceReportPreviewDialog({
    required this.isMorning,
    required this.date,
    required this.dateStr,
    required this.present,
    required this.absent,
  });

  @override
  State<_AttendanceReportPreviewDialog> createState() =>
      _AttendanceReportPreviewDialogState();
}

class _AttendanceReportPreviewDialogState
    extends State<_AttendanceReportPreviewDialog> {
  final GlobalKey _canvasKey = GlobalKey();
  bool _saving = false;

  Future<void> _exportPng() async {
    setState(() => _saving = true);
    try {
      final boundary = _canvasKey.currentContext?.findRenderObject()
          as RenderRepaintBoundary?;
      if (boundary == null) return;
      final ui.Image image = await boundary.toImage(pixelRatio: 2.5);
      final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
      if (byteData == null) return;
      final bytes = byteData.buffer.asUint8List();

      final dir = await getTemporaryDirectory();
      final sessionLabel = widget.isMorning ? 'Morning' : 'Afternoon';
      final file = File(
        '${dir.path}/Grade11_${sessionLabel}_Attendance_${widget.dateStr}.png',
      );
      await file.writeAsBytes(bytes);
      await Share.shareXFiles([XFile(file.path)]);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final fullDate = DateFormat('EEEE, MMMM d, yyyy').format(widget.date);

    return Dialog(
      insetPadding: const EdgeInsets.all(16),
      backgroundColor: Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 680),
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              RepaintBoundary(
                key: _canvasKey,
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    color: PortalColors.parchment,
                    border: Border.all(color: PortalColors.forest, width: 10),
                  ),
                  child: Column(
                    children: [
                      Text(
                        'GRADE 11 Daily Attendance Report',
                        textAlign: TextAlign.center,
                        style: PortalTheme.serif(size: 28),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        widget.isMorning
                            ? 'MORNING SESSION'
                            : 'AFTERNOON SESSION',
                        style: PortalTheme.sans(
                          size: 15,
                          weight: FontWeight.w800,
                          letterSpacing: 1.5,
                          color: PortalColors.forest,
                        ),
                      ),
                      Text(
                        fullDate.toUpperCase(),
                        style: PortalTheme.sans(
                          size: 12,
                          weight: FontWeight.w700,
                          letterSpacing: 1.4,
                          color: PortalColors.goldDark,
                        ),
                      ),
                      const Divider(height: 24),
                      Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: PortalColors.rule),
                        ),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(
                              child: _reportColumn(
                                header: 'PRESENT (${widget.present.length})',
                                bg: PortalColors.emeraldBg,
                                fg: PortalColors.emerald,
                                items: widget.present,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: _reportColumn(
                                header: 'ABSENT (${widget.absent.length})',
                                bg: PortalColors.burgBg,
                                fg: PortalColors.burg,
                                items: widget.absent,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 14),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.of(context).pop(),
                      child: const Text('Close'),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: PortalColors.forest,
                        foregroundColor: Colors.white,
                      ),
                      onPressed: _saving ? null : _exportPng,
                      icon: const Icon(Icons.download_rounded, size: 18),
                      label: Text(_saving ? 'Rendering...' : 'Save / Share PNG'),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _reportColumn({
    required String header,
    required Color bg,
    required Color fg,
    required List<String> items,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(vertical: 6),
          decoration: BoxDecoration(
            color: bg,
            borderRadius: BorderRadius.circular(6),
          ),
          alignment: Alignment.center,
          child: Text(
            header,
            style: PortalTheme.sans(
              size: 11.5,
              weight: FontWeight.w800,
              color: fg,
            ),
          ),
        ),
        const SizedBox(height: 8),
        if (items.isEmpty)
          Text(
            'None recorded',
            textAlign: TextAlign.center,
            style: PortalTheme.sans(size: 12, color: PortalColors.ink3),
          )
        else
          ...items.map(
            (n) => Padding(
              padding: const EdgeInsets.symmetric(vertical: 3),
              child: Text(n, style: PortalTheme.sans(size: 12.5)),
            ),
          ),
      ],
    );
  }
}
