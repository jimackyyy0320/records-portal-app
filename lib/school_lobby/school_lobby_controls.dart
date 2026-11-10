import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'school_lobby_config.dart';

/// Bottom-Left Virtual D-Pad / Analog Joystick for mobile Android APK touchscreens.
/// Emits a normalized 2D movement vector (`dx, dy` in `-1..1`).
class SchoolLobbyVirtualJoystick extends StatefulWidget {
  final ValueChanged<Offset> onVectorChanged;

  const SchoolLobbyVirtualJoystick({
    super.key,
    required this.onVectorChanged,
  });

  @override
  State<SchoolLobbyVirtualJoystick> createState() =>
      _SchoolLobbyVirtualJoystickState();
}

class _SchoolLobbyVirtualJoystickState
    extends State<SchoolLobbyVirtualJoystick> {
  static const double _baseRadius = 56.0;
  static const double _knobRadius = 23.0;
  static const double _maxTravel = _baseRadius - _knobRadius + 6.0;

  Offset _knobOffset = Offset.zero;
  bool _isDragging = false;

  void _updateFromLocalPosition(Offset localPos) {
    const center = Offset(_baseRadius, _baseRadius);
    final delta = localPos - center;
    final dist = delta.distance;

    Offset clampedDelta = delta;
    if (dist > _maxTravel && dist > 0) {
      clampedDelta = (delta / dist) * _maxTravel;
    }

    setState(() {
      _knobOffset = clampedDelta;
      _isDragging = true;
    });

    final norm = Offset(
      (clampedDelta.dx / _maxTravel).clamp(-1.0, 1.0),
      (clampedDelta.dy / _maxTravel).clamp(-1.0, 1.0),
    );
    if (norm.distance < 0.14) {
      widget.onVectorChanged(Offset.zero);
    } else {
      widget.onVectorChanged(norm);
    }
  }

  void _resetJoystick() {
    setState(() {
      _knobOffset = Offset.zero;
      _isDragging = false;
    });
    widget.onVectorChanged(Offset.zero);
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onPanStart: (d) {
        HapticFeedback.selectionClick();
        _updateFromLocalPosition(d.localPosition);
      },
      onPanUpdate: (d) => _updateFromLocalPosition(d.localPosition),
      onPanEnd: (_) => _resetJoystick(),
      onPanCancel: _resetJoystick,
      child: SizedBox(
        width: _baseRadius * 2,
        height: _baseRadius * 2,
        child: CustomPaint(
          painter: _JoystickPainter(
            knobOffset: _knobOffset,
            isDragging: _isDragging,
          ),
        ),
      ),
    );
  }
}

class _JoystickPainter extends CustomPainter {
  final Offset knobOffset;
  final bool isDragging;

  const _JoystickPainter({
    required this.knobOffset,
    required this.isDragging,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final baseRadius = size.width / 2;

    // Outer translucent dark glass base
    canvas.drawCircle(
      center,
      baseRadius,
      Paint()
        ..color =
            const Color(0xFF0F172A).withOpacity(isDragging ? 0.80 : 0.62),
    );
    canvas.drawCircle(
      center,
      baseRadius - 1.5,
      Paint()
        ..color = isDragging
            ? const Color(0xFF38BDF8).withOpacity(0.85)
            : Colors.white.withOpacity(0.24)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.0,
    );

    // Subtle D-pad directional chevrons
    final arrowPaint = Paint()
      ..color = Colors.white.withOpacity(0.32)
      ..strokeWidth = 2.0
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    const d = 38.0;
    // Up chevron
    canvas.drawLine(center + const Offset(-5, -d + 4),
        center + const Offset(0, -d), arrowPaint);
    canvas.drawLine(center + const Offset(5, -d + 4),
        center + const Offset(0, -d), arrowPaint);
    // Down chevron
    canvas.drawLine(center + const Offset(-5, d - 4),
        center + const Offset(0, d), arrowPaint);
    canvas.drawLine(center + const Offset(5, d - 4),
        center + const Offset(0, d), arrowPaint);
    // Left chevron
    canvas.drawLine(center + const Offset(-d + 4, -5),
        center + const Offset(-d, 0), arrowPaint);
    canvas.drawLine(center + const Offset(-d + 4, 5),
        center + const Offset(-d, 0), arrowPaint);
    // Right chevron
    canvas.drawLine(center + const Offset(d - 4, -5),
        center + const Offset(d, 0), arrowPaint);
    canvas.drawLine(center + const Offset(d - 4, 5),
        center + const Offset(d, 0), arrowPaint);

    // Inner thumb stick knob
    final knobCenter = center + knobOffset;
    canvas.drawCircle(
      knobCenter + const Offset(0, 3),
      23,
      Paint()..color = Colors.black.withOpacity(0.42),
    );
    canvas.drawCircle(
      knobCenter,
      22,
      Paint()
        ..color = isDragging
            ? const Color(0xFF0284C7)
            : const Color(0xFF1E293B).withOpacity(0.95),
    );
    canvas.drawCircle(
      knobCenter,
      22,
      Paint()
        ..color = isDragging
            ? const Color(0xFF7DD3FC)
            : Colors.white.withOpacity(0.45)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.0,
    );
    canvas.drawCircle(
      knobCenter,
      5,
      Paint()..color = Colors.white.withOpacity(0.85),
    );
  }

  @override
  bool shouldRepaint(covariant _JoystickPainter oldDelegate) =>
      oldDelegate.knobOffset != knobOffset ||
      oldDelegate.isDragging != isDragging;
}

/// Bottom-Right On-Screen "Interact" Button + Rest Controls (`🪑 Sit`, `😪 Nap`, `🛌 Sleep`),
/// Thought Bubble (`💭`), Wave (`👋`), & Zoom (`+`/`-`) Cluster.
class SchoolLobbyInteractCluster extends StatelessWidget {
  final InteractiveZone? activeZone;
  final PlayerRestState playerRestState;
  final VoidCallback onInteract;
  final VoidCallback onWave;
  final VoidCallback? onThoughtBubble;
  final ValueChanged<PlayerRestState>? onChangeRestState;
  final VoidCallback onZoomIn;
  final VoidCallback onZoomOut;

  const SchoolLobbyInteractCluster({
    super.key,
    required this.activeZone,
    this.playerRestState = PlayerRestState.none,
    required this.onInteract,
    required this.onWave,
    this.onThoughtBubble,
    this.onChangeRestState,
    required this.onZoomIn,
    required this.onZoomOut,
  });

  IconData _iconForZone(InteractiveZone? zone) {
    if (zone == null) return Icons.touch_app_rounded;
    switch (zone.kind) {
      case InteractiveZoneKind.doorPortal:
        return Icons.door_front_door_rounded;
      case InteractiveZoneKind.restSpot:
        return Icons.chair_rounded;
      case InteractiveZoneKind.peerStudent:
        return Icons.chat_bubble_rounded;
      case InteractiveZoneKind.subjectChest:
      case InteractiveZoneKind.smallMysteryChest:
        return Icons.inventory_2_rounded;
      case InteractiveZoneKind.vendingMachine:
        return Icons.local_cafe_rounded;
      case InteractiveZoneKind.classroomPodium:
        return Icons.co_present_rounded;
      default:
        return Icons.auto_awesome_rounded;
    }
  }

  String _actionHintForZone(InteractiveZone zone) {
    switch (zone.kind) {
      case InteractiveZoneKind.doorPortal:
        return 'ENTER DOOR 🚪';
      case InteractiveZoneKind.restSpot:
        return 'SIT / NAP / SLEEP 🪑';
      case InteractiveZoneKind.peerStudent:
        return 'THOUGHT CHAT 💭';
      case InteractiveZoneKind.vendingMachine:
        return 'GET DRINK / SNACK 🥤';
      case InteractiveZoneKind.classroomPodium:
        return 'OPEN PODIUM 🎤';
      default:
        return 'INTERACT [E]';
    }
  }

  @override
  Widget build(BuildContext context) {
    final hasZone = activeZone != null;
    final accent = hasZone
        ? Color(activeZone!.accentColor)
        : const Color(0xFF64748B);

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        // Row 1: Camera Zoom + Wave + Thought Bubble
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            _MiniActionPill(
              icon: Icons.remove_rounded,
              tooltip: 'Zoom Out',
              onTap: onZoomOut,
            ),
            const SizedBox(width: 6),
            _MiniActionPill(
              icon: Icons.add_rounded,
              tooltip: 'Zoom In',
              onTap: onZoomIn,
            ),
            const SizedBox(width: 6),
            _MiniActionPill(
              icon: Icons.waving_hand_rounded,
              label: 'Wave',
              tooltip: 'Wave Emote',
              onTap: onWave,
            ),
            if (onThoughtBubble != null) ...[
              const SizedBox(width: 6),
              _MiniActionPill(
                icon: Icons.cloud_outlined,
                label: '💭 Think',
                accentColor: const Color(0xFF38BDF8),
                tooltip: 'Open Thought Bubble Chat',
                onTap: onThoughtBubble!,
              ),
            ],
          ],
        ),
        const SizedBox(height: 6),

        // Row 2: Quick Sit / Nap / Sleep Controls (so students can Sit, Nap, or Sleep anywhere or on seats!)
        if (onChangeRestState != null) ...[
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (playerRestState.isResting) ...[
                _MiniActionPill(
                  icon: Icons.directions_walk_rounded,
                  label: 'Stand Up',
                  accentColor: const Color(0xFFF59E0B),
                  tooltip: 'Stand up and resume walking',
                  onTap: () => onChangeRestState!(PlayerRestState.none),
                ),
                const SizedBox(width: 6),
              ],
              _MiniActionPill(
                icon: Icons.event_seat_rounded,
                label: '🪑 Sit',
                isSelected: playerRestState == PlayerRestState.sitting,
                accentColor: const Color(0xFF10B981),
                tooltip: 'Sit down',
                onTap: () => onChangeRestState!(
                  playerRestState == PlayerRestState.sitting
                      ? PlayerRestState.none
                      : PlayerRestState.sitting,
                ),
              ),
              const SizedBox(width: 5),
              _MiniActionPill(
                icon: Icons.bedtime_outlined,
                label: '😪 Nap',
                isSelected: playerRestState == PlayerRestState.napping,
                accentColor: const Color(0xFFA855F7),
                tooltip: 'Take a nap',
                onTap: () => onChangeRestState!(
                  playerRestState == PlayerRestState.napping
                      ? PlayerRestState.none
                      : PlayerRestState.napping,
                ),
              ),
              const SizedBox(width: 5),
              _MiniActionPill(
                icon: Icons.hotel_rounded,
                label: '🛌 Sleep',
                isSelected: playerRestState == PlayerRestState.sleeping,
                accentColor: const Color(0xFF6366F1),
                tooltip: 'Lie down and sleep',
                onTap: () => onChangeRestState!(
                  playerRestState == PlayerRestState.sleeping
                      ? PlayerRestState.none
                      : PlayerRestState.sleeping,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
        ],

        // Row 3: Main Contextual "Interact" Button
        AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          curve: Curves.easeOutCubic,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            gradient: hasZone
                ? LinearGradient(
                    colors: [
                      accent,
                      Color.lerp(accent, const Color(0xFF0F172A), 0.35)!,
                    ],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  )
                : null,
            color: hasZone ? null : const Color(0xFF0F172A).withOpacity(0.75),
            border: Border.all(
              color: hasZone
                  ? Colors.white.withOpacity(0.85)
                  : Colors.white.withOpacity(0.18),
              width: hasZone ? 2.0 : 1.2,
            ),
            boxShadow: hasZone
                ? [
                    BoxShadow(
                      color: accent.withOpacity(0.55),
                      blurRadius: 16,
                      spreadRadius: 1,
                      offset: const Offset(0, 4),
                    ),
                  ]
                : [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.35),
                      blurRadius: 8,
                      offset: const Offset(0, 3),
                    ),
                  ],
          ),
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              borderRadius: BorderRadius.circular(20),
              onTap: hasZone
                  ? () {
                      HapticFeedback.mediumImpact();
                      onInteract();
                    }
                  : null,
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 11,
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      _iconForZone(activeZone),
                      color: hasZone ? Colors.white : Colors.white54,
                      size: 21,
                    ),
                    const SizedBox(width: 9),
                    ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 165),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            hasZone
                                ? _actionHintForZone(activeZone!)
                                : 'WALK NEAR A ZONE',
                            style: GoogleFonts.outfit(
                              color: hasZone ? Colors.white : Colors.white54,
                              fontWeight: FontWeight.w800,
                              fontSize: 12.5,
                              letterSpacing: 0.6,
                            ),
                          ),
                          Text(
                            hasZone
                                ? activeZone!.label
                                : 'Doors, Chests, Seats or Peers',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: GoogleFonts.inter(
                              color: hasZone
                                  ? Colors.white.withOpacity(0.92)
                                  : Colors.white38,
                              fontSize: 10.5,
                              fontWeight: FontWeight.w600,
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
      ],
    );
  }
}

class _MiniActionPill extends StatelessWidget {
  final IconData icon;
  final String? label;
  final String tooltip;
  final bool isSelected;
  final Color? accentColor;
  final VoidCallback onTap;

  const _MiniActionPill({
    required this.icon,
    this.label,
    required this.tooltip,
    this.isSelected = false,
    this.accentColor,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final activeColor = accentColor ?? const Color(0xFF38BDF8);
    return Tooltip(
      message: tooltip,
      child: Material(
        color: isSelected
            ? activeColor.withOpacity(0.92)
            : const Color(0xFF0F172A).withOpacity(0.84),
        borderRadius: BorderRadius.circular(14),
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: () {
            HapticFeedback.selectionClick();
            onTap();
          },
          child: Container(
            padding: EdgeInsets.symmetric(
              horizontal: label != null ? 9 : 8,
              vertical: 7,
            ),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: isSelected
                    ? Colors.white.withOpacity(0.9)
                    : (accentColor != null
                        ? activeColor.withOpacity(0.55)
                        : Colors.white.withOpacity(0.22)),
                width: isSelected ? 1.5 : 1.1,
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (label == null || !label!.contains(RegExp(r'[\u{1F300}-\u{1FAFF}]', unicode: true))) ...[
                  Icon(icon, color: Colors.white, size: 15),
                  if (label != null) const SizedBox(width: 4),
                ],
                if (label != null)
                  Text(
                    label!,
                    style: GoogleFonts.inter(
                      color: Colors.white,
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
