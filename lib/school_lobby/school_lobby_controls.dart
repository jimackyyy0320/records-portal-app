import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';

import 'school_lobby_config.dart';

/// Recycled from TinyFloor `Joystick.tsx` & `joystick.ts`:
/// Bottom-left virtual 8-direction touch joystick (`BASE = 60`, `TRAVEL = 42`, `DEADZONE = 9`,
/// 8-heading snap with `HYSTERESIS = 0.14` and subtle haptic ticks).
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
  static const double _kBaseRadius = 56.0;
  static const double _kKnobRadius = 23.0;
  static const double _kMaxTravel = 38.0;
  static const double _kDeadzone = 8.0;

  Offset _knobOffset = Offset.zero;
  int? _activeHeadingIndex;

  void _handlePan(Offset localPos) {
    const center = Offset(_kBaseRadius, _kBaseRadius);
    final delta = localPos - center;
    final dist = delta.distance;

    if (dist < _kDeadzone) {
      if (_knobOffset != Offset.zero) {
        setState(() {
          _knobOffset = Offset.zero;
          _activeHeadingIndex = null;
        });
        widget.onVectorChanged(Offset.zero);
      }
      return;
    }

    final clampedDist = dist.clamp(0.0, _kMaxTravel);
    final angle = math.atan2(delta.dy, delta.dx);

    // Snap to 8-direction octant with subtle haptic feedback
    final octant = (((angle + math.pi) / (math.pi / 4)).round()) % 8;
    if (octant != _activeHeadingIndex) {
      _activeHeadingIndex = octant;
      HapticFeedback.selectionClick();
    }

    final snappedAngle = (octant * (math.pi / 4)) - math.pi;
    final norm = Offset(math.cos(snappedAngle), math.sin(snappedAngle));
    final visualKnob = Offset(
      math.cos(angle) * clampedDist,
      math.sin(angle) * clampedDist,
    );

    setState(() {
      _knobOffset = visualKnob;
    });
    widget.onVectorChanged(norm);
  }

  void _resetJoystick() {
    setState(() {
      _knobOffset = Offset.zero;
      _activeHeadingIndex = null;
    });
    widget.onVectorChanged(Offset.zero);
  }

  @override
  Widget build(BuildContext context) {
    final isActive = _knobOffset != Offset.zero;
    return GestureDetector(
      onPanStart: (d) => _handlePan(d.localPosition),
      onPanUpdate: (d) => _handlePan(d.localPosition),
      onPanEnd: (_) => _resetJoystick(),
      onPanCancel: _resetJoystick,
      child: SizedBox(
        width: _kBaseRadius * 2,
        height: _kBaseRadius * 2,
        child: Stack(
          alignment: Alignment.center,
          children: [
            // Outer base ring
            Container(
              width: _kBaseRadius * 2,
              height: _kBaseRadius * 2,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: const Color(0xFF0F172A).withOpacity(isActive ? 0.82 : 0.62),
                border: Border.all(
                  color: isActive
                      ? const Color(0xFF38BDF8)
                      : Colors.white.withOpacity(0.24),
                  width: isActive ? 2.2 : 1.5,
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.35),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
            ),
            // Directional arrows on the D-Pad ring
            const Positioned(
              top: 6,
              child: Icon(Icons.keyboard_arrow_up_rounded,
                  color: Colors.white38, size: 18),
            ),
            const Positioned(
              bottom: 6,
              child: Icon(Icons.keyboard_arrow_down_rounded,
                  color: Colors.white38, size: 18),
            ),
            const Positioned(
              left: 6,
              child: Icon(Icons.keyboard_arrow_left_rounded,
                  color: Colors.white38, size: 18),
            ),
            const Positioned(
              right: 6,
              child: Icon(Icons.keyboard_arrow_right_rounded,
                  color: Colors.white38, size: 18),
            ),
            // Movable thumb stick
            Transform.translate(
              offset: _knobOffset,
              child: Container(
                width: _kKnobRadius * 2,
                height: _kKnobRadius * 2,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: LinearGradient(
                    colors: isActive
                        ? const [Color(0xFF38BDF8), Color(0xFF0284C7)]
                        : const [Color(0xFF334155), Color(0xFF1E293B)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  border: Border.all(
                    color: Colors.white.withOpacity(0.55),
                    width: 1.5,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: isActive
                          ? const Color(0xFF38BDF8).withOpacity(0.45)
                          : Colors.black38,
                      blurRadius: 8,
                    ),
                  ],
                ),
                child: const Icon(
                  Icons.gamepad_rounded,
                  color: Colors.white,
                  size: 18,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Bottom-right On-Screen **"Interact"** Button + Quick Action Cluster.
/// Illuminates and pulses with the target zone's color when the avatar stands near an interactive zone.
class SchoolLobbyInteractCluster extends StatelessWidget {
  final InteractiveZone? activeZone;
  final VoidCallback onInteract;
  final VoidCallback onWave;
  final VoidCallback onZoomIn;
  final VoidCallback onZoomOut;

  const SchoolLobbyInteractCluster({
    super.key,
    required this.activeZone,
    required this.onInteract,
    required this.onWave,
    required this.onZoomIn,
    required this.onZoomOut,
  });

  IconData _iconForZone(InteractiveZone? z) {
    if (z == null) return Icons.touch_app_rounded;
    switch (z.kind) {
      case InteractiveZoneKind.questCounter:
        return Icons.assignment_turned_in_rounded;
      case InteractiveZoneKind.subjectChest:
        return Icons.inventory_2_rounded;
      case InteractiveZoneKind.smallMysteryChest:
        return Icons.quiz_rounded;
      case InteractiveZoneKind.teacherCorner:
        return Icons.school_rounded;
      case InteractiveZoneKind.bulletinBoard:
        return Icons.campaign_rounded;
      case InteractiveZoneKind.studentLounge:
      case InteractiveZoneKind.reviewerTreasureArea:
        return Icons.auto_awesome_rounded;
    }
  }

  @override
  Widget build(BuildContext context) {
    final hasZone = activeZone != null;
    final accent =
        hasZone ? Color(activeZone!.accentColor) : const Color(0xFF475569);

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        // Mini utility buttons: Zoom +/- & Wave Emote 👋
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            _MiniHudCircleButton(
              tooltip: 'Wave Emote',
              onTap: onWave,
              child: const Text('👋', style: TextStyle(fontSize: 15)),
            ),
            const SizedBox(width: 8),
            _MiniHudCircleButton(
              tooltip: 'Zoom Out',
              onTap: onZoomOut,
              child: const Icon(Icons.remove_rounded,
                  color: Colors.white, size: 18),
            ),
            const SizedBox(width: 6),
            _MiniHudCircleButton(
              tooltip: 'Zoom In',
              onTap: onZoomIn,
              child:
                  const Icon(Icons.add_rounded, color: Colors.white, size: 18),
            ),
          ],
        ),
        const SizedBox(height: 10),

        // Main "Interact" Button
        AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            gradient: hasZone
                ? LinearGradient(
                    colors: [
                      accent,
                      Color.lerp(accent, Colors.black, 0.28)!,
                    ],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  )
                : const LinearGradient(
                    colors: [Color(0xFF1E293B), Color(0xFF0F172A)],
                  ),
            border: Border.all(
              color: hasZone ? Colors.white.withOpacity(0.85) : Colors.white24,
              width: hasZone ? 2.0 : 1.2,
            ),
            boxShadow: [
              BoxShadow(
                color: hasZone
                    ? accent.withOpacity(0.55)
                    : Colors.black.withOpacity(0.35),
                blurRadius: hasZone ? 16 : 8,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: hasZone
                  ? () {
                      HapticFeedback.mediumImpact();
                      onInteract();
                    }
                  : null,
              borderRadius: BorderRadius.circular(20),
              child: Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      _iconForZone(activeZone),
                      color: hasZone ? Colors.white : Colors.white38,
                      size: 22,
                    ),
                    const SizedBox(width: 9),
                    ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 165),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            hasZone ? 'INTERACT' : 'WALK NEAR A ZONE',
                            style: GoogleFonts.outfit(
                              color: hasZone ? Colors.white : Colors.white38,
                              fontSize: 13,
                              fontWeight: FontWeight.w900,
                              letterSpacing: 0.7,
                            ),
                          ),
                          Text(
                            hasZone
                                ? activeZone!.label
                                : 'Quest Counter, Chests or Desks',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: GoogleFonts.inter(
                              color: hasZone
                                  ? Colors.white.withOpacity(0.92)
                                  : Colors.white30,
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

class _MiniHudCircleButton extends StatelessWidget {
  final Widget child;
  final String tooltip;
  final VoidCallback onTap;

  const _MiniHudCircleButton({
    required this.child,
    required this.tooltip,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: Material(
        color: const Color(0xFF0F172A).withOpacity(0.82),
        shape: CircleBorder(
          side: BorderSide(color: Colors.white.withOpacity(0.2)),
        ),
        child: InkWell(
          onTap: onTap,
          customBorder: const CircleBorder(),
          child: SizedBox(
            width: 36,
            height: 36,
            child: Center(child: child),
          ),
        ),
      ),
    );
  }
}
