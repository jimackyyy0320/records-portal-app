import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:intl/intl.dart';

import '../config/app_config.dart';
import '../models/portal_models.dart';
import '../services/api_service.dart';
import '../theme/portal_theme.dart';

/// Decodes a `data:image/...;base64,...` string safely into bytes.
Uint8List? decodeDataUrlBytes(String? dataUrl) {
  if (dataUrl == null || dataUrl.isEmpty) return null;
  try {
    final commaIdx = dataUrl.indexOf(',');
    final b64 = commaIdx >= 0 ? dataUrl.substring(commaIdx + 1) : dataUrl;
    return base64Decode(b64.replaceAll(RegExp(r'\s+'), ''));
  } catch (_) {
    return null;
  }
}

/// Ruled parchment background replicating `body` CSS in `index.html`,
/// with built-in support for full-screen loading transitions.
class ParchmentScaffold extends StatelessWidget {
  final Widget child;
  final Widget? topBanner;
  final Widget? topNavigationBar;
  final Widget? floatingActionButton;
  final bool isLoading;
  final String loadingMessage;
  final String? loadingSubtitle;

  const ParchmentScaffold({
    super.key,
    required this.child,
    this.topBanner,
    this.topNavigationBar,
    this.floatingActionButton,
    this.isLoading = false,
    this.loadingMessage = 'LOADING RECORDS...',
    this.loadingSubtitle,
  });

  @override
  Widget build(BuildContext context) {
    return PortalLoadingOverlay(
      visible: isLoading,
      message: loadingMessage,
      subtitle: loadingSubtitle,
      child: Scaffold(
        backgroundColor: PortalColors.parchment,
        floatingActionButton: floatingActionButton,
        body: CustomPaint(
          painter: _ParchmentLinesPainter(),
          child: SafeArea(
            child: Column(
              children: [
                if (topBanner != null) topBanner!,
                if (topNavigationBar != null) topNavigationBar!,
                Expanded(child: child),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _ParchmentLinesPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = const Color(0x0E1A3A2A)
      ..strokeWidth = 1;
    for (double y = 28; y < size.height; y += 28) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), paint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

/// Top scrolling announcement marquee matching `#top-banner` in `index.html`.
class AnnouncementMarqueeBanner extends StatefulWidget {
  final List<AnnouncementItem> announcements;

  const AnnouncementMarqueeBanner({super.key, required this.announcements});

  @override
  State<AnnouncementMarqueeBanner> createState() =>
      _AnnouncementMarqueeBannerState();
}

class _AnnouncementMarqueeBannerState extends State<AnnouncementMarqueeBanner>
    with SingleTickerProviderStateMixin {
  late final ScrollController _scrollController;
  Timer? _tickTimer;

  @override
  void initState() {
    super.initState();
    _scrollController = ScrollController();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _tickTimer = Timer.periodic(const Duration(milliseconds: 35), (_) {
        if (!_scrollController.hasClients) return;
        final maxScroll = _scrollController.position.maxScrollExtent;
        if (maxScroll <= 0) return;
        final next = _scrollController.offset + 1.2;
        if (next >= maxScroll) {
          _scrollController.jumpTo(0);
        } else {
          _scrollController.jumpTo(next);
        }
      });
    });
  }

  @override
  void dispose() {
    _tickTimer?.cancel();
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.announcements.isEmpty) return const SizedBox.shrink();
    final isUrgent = widget.announcements.first.degree == 'URGENT';
    final combined = widget.announcements
        .map((a) => '[${a.date}] ${a.message}')
        .join('     •     ');

    return Container(
      height: 36,
      width: double.infinity,
      color: isUrgent ? PortalColors.burg : PortalColors.gold,
      child: ListView.builder(
        controller: _scrollController,
        scrollDirection: Axis.horizontal,
        physics: const NeverScrollableScrollPhysics(),
        itemBuilder: (context, index) => Center(
          child: Padding(
            padding: const EdgeInsets.only(right: 80),
            child: Text(
              combined.toUpperCase(),
              style: PortalTheme.sans(
                size: 11.5,
                weight: FontWeight.w700,
                letterSpacing: 1.0,
                color: isUrgent ? Colors.white : PortalColors.forest,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Official Magtanggol Integrated School circular logo badge.
class SchoolLogoBadge extends StatelessWidget {
  final double size;
  final double borderWidth;
  final Color borderColor;
  final bool showShadow;

  const SchoolLogoBadge({
    super.key,
    this.size = 72,
    this.borderWidth = 3,
    this.borderColor = PortalColors.goldPale,
    this.showShadow = true,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: Colors.white,
        shape: BoxShape.circle,
        border: Border.all(
          color: borderColor,
          width: borderWidth,
        ),
        boxShadow: showShadow
            ? const [
                BoxShadow(
                  color: Color(0x281A3A2A),
                  blurRadius: 16,
                  offset: Offset(0, 6),
                ),
              ]
            : null,
      ),
      clipBehavior: Clip.antiAlias,
      child: Padding(
        padding: EdgeInsets.all(size * 0.025),
        child: Image.asset(
          AppConfig.schoolLogoAsset,
          fit: BoxFit.contain,
          filterQuality: FilterQuality.high,
          errorBuilder: (_, __, ___) => Container(
            color: PortalColors.forest,
            alignment: Alignment.center,
            child: Icon(
              Icons.school_rounded,
              color: PortalColors.gold,
              size: size * 0.48,
            ),
          ),
        ),
      ),
    );
  }
}

/// Portal Crest + Live Clock Header matching `.portal-header` in `index.html`.
class PortalHeader extends StatefulWidget {
  final VoidCallback? onOpenSettings;
  final bool compact;

  const PortalHeader({
    super.key,
    this.onOpenSettings,
    this.compact = false,
  });

  @override
  State<PortalHeader> createState() => _PortalHeaderState();
}

class _PortalHeaderState extends State<PortalHeader>
    with SingleTickerProviderStateMixin {
  late Timer _clockTimer;
  DateTime _now = DateTime.now();
  late final AnimationController _orbitController;

  @override
  void initState() {
    super.initState();
    _orbitController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 12),
    )..repeat();
    _clockTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() => _now = DateTime.now());
    });
  }

  @override
  void dispose() {
    _clockTimer.cancel();
    _orbitController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final timeStr = DateFormat('h:mm:ss a').format(_now);
    final dateStr = DateFormat('MMM d, yyyy').format(_now).toUpperCase();

    return Padding(
      padding: EdgeInsets.only(
        top: widget.compact ? 8 : 14,
        bottom: widget.compact ? 14 : 24,
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              if (widget.onOpenSettings != null)
                IconButton(
                  tooltip: 'Backend Endpoint Settings',
                  onPressed: widget.onOpenSettings,
                  icon: const Icon(
                    Icons.settings_ethernet_rounded,
                    color: PortalColors.forest,
                    size: 22,
                  ),
                )
              else
                const SizedBox(width: 40),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    timeStr,
                    style: PortalTheme.sans(
                      size: 15,
                      weight: FontWeight.w700,
                      color: PortalColors.forest,
                    ),
                  ),
                  Text(
                    dateStr,
                    style: PortalTheme.sans(
                      size: 10,
                      weight: FontWeight.w600,
                      letterSpacing: 1.0,
                      color: PortalColors.ink3,
                    ),
                  ),
                ],
              ),
            ],
          ),
          if (!widget.compact) ...[
            const SizedBox(height: 6),
            SizedBox(
              width: 98,
              height: 98,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  RotationTransition(
                    turns: _orbitController,
                    child: CustomPaint(
                      size: const Size(98, 98),
                      painter: _DashedOrbitPainter(),
                    ),
                  ),
                  const SchoolLogoBadge(
                    size: 80,
                    borderWidth: 3.5,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            RichText(
              textAlign: TextAlign.center,
              text: TextSpan(
                style: PortalTheme.serif(size: 33, weight: FontWeight.w700),
                children: [
                  const TextSpan(text: 'MIS-SHS '),
                  TextSpan(
                    text: 'Learner App',
                    style: PortalTheme.serif(
                      size: 33,
                      weight: FontWeight.w700,
                      italic: true,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 3),
            Text(
              'Magtanggol Integrated School • Science City of Muñoz',
              textAlign: TextAlign.center,
              style: PortalTheme.sans(
                size: 12.5,
                weight: FontWeight.w600,
                color: PortalColors.ink3,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _DashedOrbitPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = PortalColors.gold.withAlpha(122)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;
    final radius = size.width / 2 - 2;
    final center = Offset(size.width / 2, size.height / 2);
    const dashCount = 24;
    const sweep = (2 * math.pi) / (dashCount * 2);
    for (int i = 0; i < dashCount; i++) {
      canvas.drawArc(
        Rect.fromCircle(center: center, radius: radius),
        i * 2 * sweep,
        sweep,
        false,
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

/// Retro TV Maintenance Screen matching `#maintenance-screen` in `index.html`.
class MaintenanceTvView extends StatelessWidget {
  final VoidCallback onRetry;
  final VoidCallback? onFacultyBypass;

  const MaintenanceTvView({
    super.key,
    required this.onRetry,
    this.onFacultyBypass,
  });

  @override
  Widget build(BuildContext context) {
    final barColors = [
      Colors.white,
      const Color(0xFFFFE60A),
      const Color(0xFF0AFFD9),
      const Color(0xFF10EA00),
      const Color(0xFFFF0AFE),
      const Color(0xFFED0014),
      const Color(0xFF002FC6),
    ];

    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('Portal Offline', style: PortalTheme.serif(size: 32)),
            const SizedBox(height: 6),
            Text(
              'The system is currently closed or under maintenance.',
              textAlign: TextAlign.center,
              style: PortalTheme.sans(color: PortalColors.ink3),
            ),
            const SizedBox(height: 28),
            Container(
              width: 260,
              height: 150,
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: PortalColors.forest,
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: PortalColors.ink, width: 2.5),
                boxShadow: const [
                  BoxShadow(
                    color: Color(0x281A3A2A),
                    blurRadius: 20,
                    offset: Offset(0, 10),
                  ),
                ],
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(10),
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    Row(
                      children: barColors
                          .map(
                            (c) => Expanded(child: Container(color: c)),
                          )
                          .toList(),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 5,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.black,
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        'OFFLINE',
                        style: PortalTheme.sans(
                          size: 13,
                          weight: FontWeight.w800,
                          letterSpacing: 2.5,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),
            OutlinedButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh_rounded),
              label: const Text('Check Status Again'),
            ),
            if (onFacultyBypass != null) ...[
              const SizedBox(height: 8),
              TextButton.icon(
                onPressed: onFacultyBypass,
                icon: const Icon(Icons.lock_person_rounded, size: 18),
                label: const Text('Faculty Sign-In'),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// Doughnut Chart replicating `#attendanceChart` in `index.html`.
class AttendanceDoughnutChart extends StatelessWidget {
  final int present;
  final int absent;

  const AttendanceDoughnutChart({
    super.key,
    required this.present,
    required this.absent,
  });

  @override
  Widget build(BuildContext context) {
    final total = present + absent;
    if (total <= 0) return const SizedBox.shrink();

    return Column(
      children: [
        SizedBox(
          width: 170,
          height: 170,
          child: TweenAnimationBuilder<double>(
            tween: Tween(begin: 0, end: 1),
            duration: const Duration(milliseconds: 550),
            curve: Curves.easeOutCubic,
            builder: (context, anim, _) {
              return CustomPaint(
                painter: _DoughnutPainter(
                  present: present,
                  absent: absent,
                  progress: anim,
                ),
                child: Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        '${((present / total) * 100).round()}%',
                        style: PortalTheme.serif(size: 28),
                      ),
                      Text(
                        'Attendance',
                        style: PortalTheme.sans(
                          size: 11,
                          weight: FontWeight.w600,
                          color: PortalColors.ink3,
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
        const SizedBox(height: 12),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            _legendDot(PortalColors.emerald, 'Present ($present)'),
            const SizedBox(width: 18),
            _legendDot(PortalColors.burg, 'Absent ($absent)'),
          ],
        ),
      ],
    );
  }

  Widget _legendDot(Color color, String label) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 10,
          height: 10,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 6),
        Text(
          label,
          style: PortalTheme.sans(
            size: 12,
            weight: FontWeight.w600,
            color: PortalColors.ink2,
          ),
        ),
      ],
    );
  }
}

class _DoughnutPainter extends CustomPainter {
  final int present;
  final int absent;
  final double progress;

  _DoughnutPainter({
    required this.present,
    required this.absent,
    required this.progress,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final total = present + absent;
    if (total == 0) return;

    const stroke = 24.0;
    final rect = Rect.fromCircle(
      center: Offset(size.width / 2, size.height / 2),
      radius: (size.width - stroke) / 2,
    );

    final presSweep = (present / total) * 2 * math.pi * progress;
    final absSweep = (absent / total) * 2 * math.pi * progress;

    final presPaint = Paint()
      ..color = PortalColors.emerald
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke;

    final absPaint = Paint()
      ..color = PortalColors.burg
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke;

    if (presSweep > 0) {
      canvas.drawArc(rect, -math.pi / 2, presSweep, false, presPaint);
    }
    if (absSweep > 0) {
      canvas.drawArc(
        rect,
        -math.pi / 2 + presSweep,
        absSweep,
        false,
        absPaint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _DoughnutPainter old) =>
      old.present != present ||
      old.absent != absent ||
      old.progress != progress;
}

/// Gold Bar Chart replicating `#dailyProgressChart` in `index.html`.
class DailyProgressBarChart extends StatelessWidget {
  final List<DailyProgressItem> items;

  const DailyProgressBarChart({super.key, required this.items});

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) return const SizedBox.shrink();

    double maxVal = 10;
    for (final it in items) {
      if (it.numericScore > maxVal) maxVal = it.numericScore;
      final ms = double.tryParse(it.maxScore ?? '');
      if (ms != null && ms > maxVal) maxVal = ms;
    }

    return Container(
      height: 190,
      padding: const EdgeInsets.fromLTRB(12, 16, 12, 8),
      decoration: BoxDecoration(
        color: PortalColors.parchment.withAlpha(115),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: PortalColors.rule),
      ),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: items.map((item) {
            final ratio =
                maxVal > 0 ? (item.numericScore / maxVal).clamp(0.0, 1.0) : 0.0;
            return Container(
              width: 56,
              margin: const EdgeInsets.symmetric(horizontal: 5),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  Text(
                    item.isMissing ? '-' : item.score!,
                    style: PortalTheme.sans(
                      size: 10,
                      weight: FontWeight.w700,
                      color: PortalColors.forest,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Expanded(
                    child: Align(
                      alignment: Alignment.bottomCenter,
                      child: FractionallySizedBox(
                        heightFactor: ratio == 0 ? 0.03 : ratio,
                        child: Container(
                          width: 26,
                          decoration: BoxDecoration(
                            color: item.isMissing
                                ? PortalColors.ruleMed
                                : PortalColors.gold,
                            borderRadius: BorderRadius.circular(5),
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    item.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.center,
                    style: PortalTheme.sans(
                      size: 9.5,
                      weight: FontWeight.w600,
                      color: PortalColors.ink3,
                    ),
                  ),
                ],
              ),
            );
          }).toList(),
        ),
      ),
    );
  }
}

/// Student Class Schedule Floating Timer & In-Class Lock Overlay
/// replicating `runScheduleLoop()` in `index.html`.
class StudentScheduleOverlay extends StatefulWidget {
  final List<ClassScheduleItem> schedule;
  final Widget child;

  const StudentScheduleOverlay({
    super.key,
    required this.schedule,
    required this.child,
  });

  @override
  State<StudentScheduleOverlay> createState() => _StudentScheduleOverlayState();
}

class _StudentScheduleOverlayState extends State<StudentScheduleOverlay> {
  Timer? _timer;
  bool _minimized = false;
  bool _inClassWarningActive = false;
  int _lastDismissedMs = 0;
  String _nextSubject = 'No more classes today';
  String _countdown = '--:--:--';
  Offset _badgeOffset = const Offset(16, 90);

  @override
  void initState() {
    super.initState();
    _evaluateSchedule();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      _evaluateSchedule();
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  DateTime? _parseTimeToday(String raw) {
    if (raw.trim().isEmpty) return null;
    final lower = raw.toLowerCase();
    final isPm = lower.contains('pm');
    final isAm = lower.contains('am');
    final clean = lower.replaceAll(RegExp(r'am|pm'), '').trim();
    final parts = clean.split(':');
    if (parts.length < 2) return null;
    int? h = int.tryParse(parts[0].trim());
    int? m = int.tryParse(parts[1].replaceAll(RegExp(r'[^0-9]'), ''));
    if (h == null || m == null) return null;
    if (isPm && h < 12) h += 12;
    if (isAm && h == 12) h = 0;
    final now = DateTime.now();
    return DateTime(now.year, now.month, now.day, h, m);
  }

  void _evaluateSchedule() {
    if (!mounted || widget.schedule.isEmpty) return;
    final now = DateTime.now();
    const days = [
      'Monday',
      'Tuesday',
      'Wednesday',
      'Thursday',
      'Friday',
      'Saturday',
      'Sunday',
    ];
    final todayStr = days[now.weekday - 1];

    bool inClass = false;
    String? upcomingSubj;
    Duration? minDiff;

    for (final s in widget.schedule) {
      if (s.day.toLowerCase() == todayStr.toLowerCase()) {
        final tIn = _parseTimeToday(s.timeIn);
        final tOut = _parseTimeToday(s.timeOut);
        if (tIn == null || tOut == null) continue;
        if (!now.isBefore(tIn) && !now.isAfter(tOut)) {
          inClass = true;
          break;
        }
        if (tIn.isAfter(now)) {
          final diff = tIn.difference(now);
          if (minDiff == null || diff < minDiff) {
            minDiff = diff;
            upcomingSubj = s.subjectCode;
          }
        }
      }
    }

    setState(() {
      if (inClass) {
        if (DateTime.now().millisecondsSinceEpoch - _lastDismissedMs > 10000) {
          _inClassWarningActive = true;
        }
      } else {
        _inClassWarningActive = false;
        if (upcomingSubj != null && minDiff != null) {
          _nextSubject = upcomingSubj;
          final hh = minDiff.inHours.toString().padLeft(2, '0');
          final mm = (minDiff.inMinutes % 60).toString().padLeft(2, '0');
          final ss = (minDiff.inSeconds % 60).toString().padLeft(2, '0');
          _countdown = '$hh:$mm:$ss';
        } else {
          _nextSubject = 'No more classes today';
          _countdown = '--:--:--';
        }
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    if (widget.schedule.isEmpty) return widget.child;

    return Stack(
      children: [
        widget.child,
        if (!_inClassWarningActive)
          Positioned(
            right: _badgeOffset.dx,
            top: _badgeOffset.dy,
            child: GestureDetector(
              onPanUpdate: (d) {
                setState(() {
                  _badgeOffset = Offset(
                    (_badgeOffset.dx - d.delta.dx).clamp(8.0, 260.0),
                    (_badgeOffset.dy + d.delta.dy).clamp(16.0, 560.0),
                  );
                });
              },
              onTap: _minimized
                  ? () => setState(() => _minimized = false)
                  : null,
              child: Material(
                color: Colors.transparent,
                child: _minimized
                    ? Container(
                        width: 48,
                        height: 48,
                        decoration: BoxDecoration(
                          color: Colors.white,
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: PortalColors.forest,
                            width: 2.5,
                          ),
                          boxShadow: const [
                            BoxShadow(
                              color: Color(0x281A3A2A),
                              blurRadius: 12,
                            ),
                          ],
                        ),
                        alignment: Alignment.center,
                        child: const Text('⏱️', style: TextStyle(fontSize: 20)),
                      )
                    : Container(
                        width: 195,
                        decoration: BoxDecoration(
                          color: Colors.white.withAlpha(245),
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(
                            color: PortalColors.forest,
                            width: 2,
                          ),
                          boxShadow: const [
                            BoxShadow(
                              color: Color(0x281A3A2A),
                              blurRadius: 16,
                              offset: Offset(0, 6),
                            ),
                          ],
                        ),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 10,
                                vertical: 6,
                              ),
                              decoration: const BoxDecoration(
                                color: PortalColors.forest,
                                borderRadius: BorderRadius.vertical(
                                  top: Radius.circular(11),
                                ),
                              ),
                              child: Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(
                                    'NEXT CLASS',
                                    style: PortalTheme.sans(
                                      size: 10.5,
                                      weight: FontWeight.w800,
                                      letterSpacing: 1.0,
                                      color: PortalColors.gold,
                                    ),
                                  ),
                                  InkWell(
                                    onTap: () =>
                                        setState(() => _minimized = true),
                                    child: const Icon(
                                      Icons.remove_rounded,
                                      size: 16,
                                      color: Colors.white,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            Padding(
                              padding: const EdgeInsets.all(12),
                              child: Column(
                                children: [
                                  Text(
                                    'STARTS IN',
                                    style: PortalTheme.sans(
                                      size: 10,
                                      weight: FontWeight.w600,
                                      color: PortalColors.ink3,
                                    ),
                                  ),
                                  Text(
                                    _countdown,
                                    style: PortalTheme.serif(
                                      size: 26,
                                      color: PortalColors.burg,
                                    ),
                                  ),
                                  Text(
                                    _nextSubject,
                                    textAlign: TextAlign.center,
                                    style: PortalTheme.sans(
                                      size: 12,
                                      weight: FontWeight.w700,
                                      color: PortalColors.forest,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
              ),
            ),
          ),
        if (_inClassWarningActive)
          Container(
            color: Colors.black.withAlpha(217),
            alignment: Alignment.center,
            padding: const EdgeInsets.all(24),
            child: Container(
              constraints: const BoxConstraints(maxWidth: 380),
              padding: const EdgeInsets.all(28),
              decoration: BoxDecoration(
                color: PortalColors.burgBg,
                borderRadius: BorderRadius.circular(22),
                border: Border.all(color: PortalColors.burg, width: 2),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text('📵', style: TextStyle(fontSize: 44)),
                  const SizedBox(height: 12),
                  Text(
                    'Class is in Session',
                    textAlign: TextAlign.center,
                    style: PortalTheme.serif(size: 30, color: PortalColors.burg),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    'Please put your phone away and focus on the lecture. The portal will resume shortly.',
                    textAlign: TextAlign.center,
                    style: PortalTheme.sans(size: 14, color: PortalColors.ink),
                  ),
                  const SizedBox(height: 22),
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton(
                      onPressed: () {
                        setState(() {
                          _inClassWarningActive = false;
                          _lastDismissedMs =
                              DateTime.now().millisecondsSinceEpoch;
                        });
                      },
                      child: const Text('I Understand'),
                    ),
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }
}

/// Interactive circular pinch/pan avatar cropper dialog replicating Cropper.js.
class AvatarCropDialog extends StatefulWidget {
  final Uint8List imageBytes;

  const AvatarCropDialog({super.key, required this.imageBytes});

  @override
  State<AvatarCropDialog> createState() => _AvatarCropDialogState();
}

class _AvatarCropDialogState extends State<AvatarCropDialog> {
  final GlobalKey _boundaryKey = GlobalKey();
  bool _exporting = false;

  Future<void> _exportCropped() async {
    setState(() => _exporting = true);
    try {
      final boundary = _boundaryKey.currentContext?.findRenderObject()
          as RenderRepaintBoundary?;
      if (boundary == null) return;
      final ui.Image img = await boundary.toImage(pixelRatio: 1.2);
      final byteData = await img.toByteData(format: ui.ImageByteFormat.png);
      if (byteData == null) return;
      final b64 = base64Encode(byteData.buffer.asUint8List());
      final dataUrl = 'data:image/png;base64,$b64';
      if (mounted) Navigator.of(context).pop(dataUrl);
    } finally {
      if (mounted) setState(() => _exporting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
      child: Padding(
        padding: const EdgeInsets.all(22),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('Adjust Photo', style: PortalTheme.serif(size: 24)),
            const SizedBox(height: 6),
            Text(
              'Pinch and drag to position your avatar.',
              style: PortalTheme.sans(size: 12, color: PortalColors.ink3),
            ),
            const SizedBox(height: 16),
            ClipOval(
              child: RepaintBoundary(
                key: _boundaryKey,
                child: Container(
                  width: 250,
                  height: 250,
                  color: PortalColors.parchmentDk,
                  child: InteractiveViewer(
                    minScale: 1.0,
                    maxScale: 4.0,
                    child: Image.memory(
                      widget.imageBytes,
                      fit: BoxFit.cover,
                      width: 250,
                      height: 250,
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 20),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed:
                        _exporting ? null : () => Navigator.of(context).pop(),
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
                    onPressed: _exporting ? null : _exportCropped,
                    child: Text(_exporting ? 'Saving...' : '✂️ Save Avatar'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// Modal dialog to configure & test the deployed Apps Script `/exec` URL.
class BackendConfigDialog extends StatefulWidget {
  const BackendConfigDialog({super.key});

  @override
  State<BackendConfigDialog> createState() => _BackendConfigDialogState();
}

class _BackendConfigDialogState extends State<BackendConfigDialog> {
  final TextEditingController _urlCtrl = TextEditingController();
  bool _testing = false;
  String? _statusMsg;
  bool _statusOk = false;

  @override
  void initState() {
    super.initState();
    AppConfig.getScriptUrl().then((url) {
      if (mounted) {
        _urlCtrl.text = AppConfig.isConfiguredUrl(url) ? url : '';
      }
    });
  }

  @override
  void dispose() {
    _urlCtrl.dispose();
    super.dispose();
  }

  Future<void> _saveAndTest() async {
    final raw = _urlCtrl.text.trim();
    if (!raw.startsWith('https://script.google.com/macros/s/')) {
      setState(() {
        _statusOk = false;
        _statusMsg =
            'Enter a valid https://script.google.com/macros/s/.../exec URL.';
      });
      return;
    }
    setState(() {
      _testing = true;
      _statusMsg = null;
    });
    await AppConfig.setScriptUrl(raw);
    try {
      final res = await ApiService.instance.postAction('ping');
      if (res['success'] == true) {
        setState(() {
          _statusOk = true;
          _statusMsg = 'Connected to Apps Script backend!';
        });
      } else {
        setState(() {
          _statusOk = false;
          _statusMsg = res['message']?.toString() ?? 'Unexpected response.';
        });
      }
    } catch (e) {
      setState(() {
        _statusOk = false;
        _statusMsg = e.toString();
      });
    } finally {
      if (mounted) setState(() => _testing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('Apps Script Endpoint', style: PortalTheme.serif(size: 24)),
            const SizedBox(height: 6),
            Text(
              'Paste your deployed code.gs Web App (/exec) URL ("Who has access: Anyone").',
              style: PortalTheme.sans(size: 12.5, color: PortalColors.ink3),
            ),
            const SizedBox(height: 14),
            TextField(
              controller: _urlCtrl,
              autocorrect: false,
              enableSuggestions: false,
              maxLines: 3,
              minLines: 2,
              style: PortalTheme.sans(size: 12.5),
              decoration: InputDecoration(
                hintText: 'https://script.google.com/macros/s/.../exec',
                filled: true,
                fillColor: PortalColors.parchment,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: PortalColors.ruleMed),
                ),
              ),
            ),
            if (_statusMsg != null) ...[
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color:
                      _statusOk ? PortalColors.emeraldBg : PortalColors.burgBg,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  _statusMsg!,
                  style: PortalTheme.sans(
                    size: 12,
                    weight: FontWeight.w600,
                    color: _statusOk ? PortalColors.emerald : PortalColors.burg,
                  ),
                ),
              ),
            ],
            const SizedBox(height: 18),
            Align(
              alignment: Alignment.centerRight,
              child: TextButton.icon(
                onPressed: _testing
                    ? null
                    : () async {
                        await AppConfig.resetScriptUrlToDefault();
                        if (!mounted) return;
                        setState(() {
                          _urlCtrl.text = AppConfig.defaultScriptUrl;
                          _statusOk = true;
                          _statusMsg = 'Restored default Apps Script endpoint.';
                        });
                      },
                icon: const Icon(Icons.restore_rounded, size: 16),
                label: const Text('Restore Default Endpoint'),
              ),
            ),
            const SizedBox(height: 6),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => Navigator.of(context).pop(_statusOk),
                    child: const Text('Close'),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: PortalColors.forest,
                      foregroundColor: Colors.white,
                    ),
                    onPressed: _testing ? null : _saveAndTest,
                    child: Text(_testing ? 'Testing...' : 'Save & Test'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// Smooth scholarly page transition (fade + subtle upward slide).
class PortalPageRoute<T> extends PageRouteBuilder<T> {
  PortalPageRoute({required WidgetBuilder builder, super.settings})
      : super(
          transitionDuration: const Duration(milliseconds: 300),
          reverseTransitionDuration: const Duration(milliseconds: 240),
          pageBuilder: (context, animation, secondaryAnimation) =>
              builder(context),
          transitionsBuilder: (context, animation, secondaryAnimation, child) {
            final curved = CurvedAnimation(
              parent: animation,
              curve: Curves.easeOutCubic,
              reverseCurve: Curves.easeInCubic,
            );
            return FadeTransition(
              opacity: curved,
              child: SlideTransition(
                position: Tween<Offset>(
                  begin: const Offset(0, 0.035),
                  end: Offset.zero,
                ).animate(curved),
                child: child,
              ),
            );
          },
        );
}

/// Animated Forest & Antique Gold crest loading indicator used across login
/// and page-to-page transitions.
class PortalLoadingView extends StatefulWidget {
  final String message;
  final String? subtitle;
  final bool darkBackdrop;

  const PortalLoadingView({
    super.key,
    required this.message,
    this.subtitle,
    this.darkBackdrop = true,
  });

  @override
  State<PortalLoadingView> createState() => _PortalLoadingViewState();
}

class _PortalLoadingViewState extends State<PortalLoadingView>
    with SingleTickerProviderStateMixin {
  late final AnimationController _orbitCtrl;

  @override
  void initState() {
    super.initState();
    _orbitCtrl = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 8),
    )..repeat();
  }

  @override
  void dispose() {
    _orbitCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final fgPrimary = widget.darkBackdrop ? Colors.white : PortalColors.forest;
    final fgSecondary =
        widget.darkBackdrop ? Colors.white70 : PortalColors.ink3;

    return Center(
      child: Container(
        constraints: const BoxConstraints(maxWidth: 310),
        margin: const EdgeInsets.symmetric(horizontal: 28),
        padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 30),
        decoration: BoxDecoration(
          color: widget.darkBackdrop
              ? PortalColors.forestDark.withAlpha(242)
              : Colors.white,
          borderRadius: BorderRadius.circular(26),
          border: Border.all(
            color: PortalColors.gold.withAlpha(widget.darkBackdrop ? 130 : 180),
            width: 1.8,
          ),
          boxShadow: const [
            BoxShadow(
              color: Color(0x4009150E),
              blurRadius: 32,
              offset: Offset(0, 14),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              width: 84,
              height: 84,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  RotationTransition(
                    turns: _orbitCtrl,
                    child: CustomPaint(
                      size: const Size(84, 84),
                      painter: _DashedOrbitPainter(),
                    ),
                  ),
                  const SchoolLogoBadge(
                    size: 66,
                    borderWidth: 3,
                    showShadow: false,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            Text(
              AppConfig.appName,
              textAlign: TextAlign.center,
              style: PortalTheme.serif(
                size: 22,
                italic: true,
                color: fgPrimary,
              ),
            ),
            const SizedBox(height: 12),
            ClipRRect(
              borderRadius: BorderRadius.circular(6),
              child: const SizedBox(
                width: 150,
                height: 4,
                child: LinearProgressIndicator(
                  color: PortalColors.gold,
                  backgroundColor: Color(0x33C9A84C),
                ),
              ),
            ),
            const SizedBox(height: 14),
            Text(
              widget.message.toUpperCase(),
              textAlign: TextAlign.center,
              style: PortalTheme.sans(
                size: 11.5,
                weight: FontWeight.w800,
                letterSpacing: 1.4,
                color: PortalColors.gold,
              ),
            ),
            if (widget.subtitle != null &&
                widget.subtitle!.trim().isNotEmpty) ...[
              const SizedBox(height: 5),
              Text(
                widget.subtitle!,
                textAlign: TextAlign.center,
                style: PortalTheme.sans(
                  size: 12,
                  color: fgSecondary,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// Full-screen modal loading overlay + imperative helper `PortalLoadingOverlay.run(...)`.
class PortalLoadingOverlay extends StatelessWidget {
  final bool visible;
  final String message;
  final String? subtitle;
  final Widget child;

  const PortalLoadingOverlay({
    super.key,
    required this.visible,
    required this.message,
    this.subtitle,
    required this.child,
  });

  /// Shows a non-dismissible full-screen loading dialog while [task] executes.
  static Future<T> run<T>(
    BuildContext context, {
    required String message,
    String? subtitle,
    required Future<T> Function() task,
  }) async {
    showDialog<void>(
      context: context,
      barrierDismissible: false,
      barrierColor: const Color(0xB80D1F16),
      builder: (_) => PopScope(
        canPop: false,
        child: BackdropFilter(
          filter: ui.ImageFilter.blur(sigmaX: 5, sigmaY: 5),
          child: Material(
            type: MaterialType.transparency,
            child: PortalLoadingView(
              message: message,
              subtitle: subtitle,
            ),
          ),
        ),
      ),
    );
    try {
      return await task();
    } finally {
      if (context.mounted) {
        Navigator.of(context, rootNavigator: true).pop();
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        child,
        if (visible)
          Positioned.fill(
            child: AbsorbPointer(
              child: BackdropFilter(
                filter: ui.ImageFilter.blur(sigmaX: 5, sigmaY: 5),
                child: Container(
                  color: const Color(0xB80D1F16),
                  child: Material(
                    type: MaterialType.transparency,
                    child: PortalLoadingView(
                      message: message,
                      subtitle: subtitle,
                    ),
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }
}

/// Shared logout confirmation modal with smooth transition feedback.
Future<void> confirmAndLogout(
  BuildContext context,
  FutureOr<void> Function() onLogout,
) async {
  final confirmed = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      backgroundColor: Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
      title: Text(
        'Sign Out of Portal?',
        style: PortalTheme.serif(size: 24, color: PortalColors.forest),
      ),
      content: Text(
        'You will be returned to the login screen. Any queued offline scans remain safely stored on this device.',
        style: PortalTheme.sans(size: 13.5, color: PortalColors.ink2),
      ),
      actions: [
        OutlinedButton(
          onPressed: () => Navigator.of(ctx).pop(false),
          child: const Text('Stay Signed In'),
        ),
        ElevatedButton.icon(
          style: ElevatedButton.styleFrom(
            backgroundColor: PortalColors.burg,
            foregroundColor: Colors.white,
          ),
          onPressed: () => Navigator.of(ctx).pop(true),
          icon: const Icon(Icons.logout_rounded, size: 16),
          label: const Text('Sign Out'),
        ),
      ],
    ),
  );

  if (confirmed != true || !context.mounted) return;

  await PortalLoadingOverlay.run(
    context,
    message: 'Signing Out...',
    subtitle: 'Closing your active portal session',
    task: () async {
      await Future<void>.delayed(const Duration(milliseconds: 280));
      await onLogout();
    },
  );
}
