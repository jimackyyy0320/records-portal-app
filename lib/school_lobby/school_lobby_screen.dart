import 'dart:async';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';

import '../models/portal_models.dart';
import 'lobby_data_service.dart';
import 'school_lobby_avatar.dart';
import 'school_lobby_config.dart';
import 'school_lobby_controls.dart';
import 'school_lobby_engine.dart';
import 'school_lobby_modals.dart';

/// Self-Contained 2D Pixel "Mini School Lobby" Screen for the MIS-SHS Learner App.
/// Recycles TinyFloor's avatar rendering, movement/A* pathfinding, and 3/4 floor/furniture atlas,
/// combined with Phase 2's Quest Counter, Student Badge System, Subject Reviewer Chests,
/// and Small Mystery Pop-Quiz Chests.
class SchoolLobbyScreen extends StatefulWidget {
  final UserSession session;

  const SchoolLobbyScreen({
    super.key,
    required this.session,
  });

  @override
  State<SchoolLobbyScreen> createState() => _SchoolLobbyScreenState();
}

class _SchoolLobbyScreenState extends State<SchoolLobbyScreen> {
  final FocusNode _keyboardFocusNode = FocusNode();
  final Set<LogicalKeyboardKey> _pressedKeys = <LogicalKeyboardKey>{};

  SchoolLobbyAssetBundle? _assets;
  LobbyAvatarLook _playerLook = const LobbyAvatarLook();
  ui.Image? _playerSheet;
  bool _loading = true;

  // Player state
  Offset _playerPos = kPlayerSpawnPoint;
  AvatarFacing _playerFacing = AvatarFacing.down;
  bool _playerIsWalking = false;

  // Movement inputs
  Offset _joystickVector = Offset.zero;
  List<Offset> _activePath = const [];
  Offset? _tapPulseTarget;
  double _tapPulseProgress = 1.0;

  // Camera state
  Offset _cameraCenter = kPlayerSpawnPoint;
  double _cameraZoom = 1.35;

  // Animation & Wave state
  int _animTick = 0;
  int _frameCounter = 0;
  double _waveBubbleProgress = 0.0;

  // Proximity state
  InteractiveZone? _highlightedZone;

  Timer? _gameLoopTimer;

  @override
  void initState() {
    super.initState();
    _initLobby();
  }

  Future<void> _initLobby() async {
    await LobbyDataService.instance.init(widget.session.id);
    final savedLook = await AvatarSpriteCache.instance.loadSavedLook(
      widget.session.id,
      isFaculty: widget.session.isFaculty,
    );
    final sheet =
        await AvatarSpriteCache.instance.resolveLookSpriteSheet(savedLook);
    final bundle = await SchoolLobbyAssetBundle.load();

    if (!mounted) return;
    setState(() {
      _playerLook = savedLook;
      _playerSheet = sheet;
      _assets = bundle;
      _loading = false;
    });

    // Start 60 FPS game loop (~16ms tick)
    _gameLoopTimer = Timer.periodic(
      const Duration(milliseconds: 16),
      (_) => _onGameTick(0.016),
    );
  }

  @override
  void dispose() {
    _gameLoopTimer?.cancel();
    _keyboardFocusNode.dispose();
    super.dispose();
  }

  Offset _readKeyboardVector() {
    var dx = 0.0;
    var dy = 0.0;
    if (_pressedKeys.contains(LogicalKeyboardKey.keyA) ||
        _pressedKeys.contains(LogicalKeyboardKey.arrowLeft)) {
      dx -= 1.0;
    }
    if (_pressedKeys.contains(LogicalKeyboardKey.keyD) ||
        _pressedKeys.contains(LogicalKeyboardKey.arrowRight)) {
      dx += 1.0;
    }
    if (_pressedKeys.contains(LogicalKeyboardKey.keyW) ||
        _pressedKeys.contains(LogicalKeyboardKey.arrowUp)) {
      dy -= 1.0;
    }
    if (_pressedKeys.contains(LogicalKeyboardKey.keyS) ||
        _pressedKeys.contains(LogicalKeyboardKey.arrowDown)) {
      dy += 1.0;
    }
    if (dx == 0.0 && dy == 0.0) return Offset.zero;
    final len = Offset(dx, dy).distance;
    return Offset(dx / len, dy / len);
  }

  AvatarFacing _facingFromVector(Offset v, AvatarFacing fallback) {
    if (v.distanceSquared < 0.001) return fallback;
    if (v.dx.abs() >= v.dy.abs()) {
      return v.dx >= 0 ? AvatarFacing.right : AvatarFacing.left;
    } else {
      return v.dy >= 0 ? AvatarFacing.down : AvatarFacing.up;
    }
  }

  /// Recycled from TinyFloor `MovementManager.ts` (`moveBy`):
  /// Resolves X and Y axis collisions independently so the player slides smoothly along walls/desks.
  Offset _moveWithSlidingCollision(
      Offset current, Offset delta, List<Rect> solids) {
    var nextX = (current.dx + delta.dx)
        .clamp(38.0, kLobbyWorldWidth - 38.0);
    var nextY = (current.dy + delta.dy)
        .clamp(90.0, kLobbyWorldHeight - 30.0);

    bool collidesAt(double x, double y) {
      final footBox = Rect.fromCenter(
        center: Offset(x, y),
        width: kPlayerHalfWidth * 1.9,
        height: kPlayerHalfWidth * 1.5,
      );
      for (final s in solids) {
        if (footBox.overlaps(s)) return true;
      }
      return false;
    }

    if (collidesAt(nextX, current.dy)) {
      nextX = current.dx;
    }
    if (collidesAt(nextX, nextY)) {
      nextY = current.dy;
    }
    return Offset(nextX, nextY);
  }

  void _onGameTick(double dt) {
    if (!mounted || _loading) return;

    final service = LobbyDataService.instance;
    final chests = service.subjectChests;
    final solids = buildLobbySolids(chests);

    // 1. Determine movement vector: Keyboard / Joystick overrides Tap-to-Walk path
    final kbVec = _readKeyboardVector();
    final manualVec =
        _joystickVector != Offset.zero ? _joystickVector : kbVec;

    var moveDelta = Offset.zero;
    var walking = false;

    if (manualVec != Offset.zero) {
      _activePath = const [];
      moveDelta = manualVec * (kPlayerMoveSpeed * dt);
      _playerFacing = _facingFromVector(manualVec, _playerFacing);
      walking = true;
    } else if (_activePath.isNotEmpty) {
      final target = _activePath.first;
      final toTarget = target - _playerPos;
      final dist = toTarget.distance;
      final stepDist = kPlayerMoveSpeed * dt;

      if (dist <= stepDist + 2.0) {
        _playerPos = _moveWithSlidingCollision(_playerPos, toTarget, solids);
        _activePath = _activePath.sublist(1);
        walking = _activePath.isNotEmpty;
      } else {
        final dir = toTarget / dist;
        moveDelta = dir * stepDist;
        _playerFacing = _facingFromVector(dir, _playerFacing);
        walking = true;
      }
    }

    if (moveDelta != Offset.zero) {
      final prev = _playerPos;
      _playerPos = _moveWithSlidingCollision(_playerPos, moveDelta, solids);
      if ((_playerPos - prev).distanceSquared < 0.05 &&
          _activePath.isNotEmpty) {
        // Reached an obstacle along path; clear remaining waypoints
        _activePath = const [];
        walking = false;
      }
    }

    _playerIsWalking = walking;

    // 2. Smooth camera follow (`CameraRig.ts` lerp = 0.14)
    _cameraCenter = Offset.lerp(_cameraCenter, _playerPos, 0.14) ?? _playerPos;

    // 3. Advance 10 FPS sprite animation counter & visual effects
    _frameCounter++;
    if (_frameCounter % 6 == 0) {
      _animTick++;
    }
    if (_tapPulseProgress < 1.0) {
      _tapPulseProgress = (_tapPulseProgress + dt * 2.2).clamp(0.0, 1.0);
    }
    if (_waveBubbleProgress > 0.0) {
      _waveBubbleProgress = (_waveBubbleProgress + dt * 0.9).clamp(0.0, 1.0);
      if (_waveBubbleProgress >= 1.0) {
        _waveBubbleProgress = 0.0;
      }
    }

    // 4. Update nearest InteractiveZone within radius (`ProximityManager.ts`)
    final allZones = buildActiveInteractiveZones(chests);
    InteractiveZone? nearest;
    var bestDist = 999999.0;
    for (final z in allZones) {
      final d = (_playerPos - z.center).distance;
      if (d <= z.radius && d < bestDist) {
        bestDist = d;
        nearest = z;
      }
    }
    _highlightedZone = nearest;

    setState(() {});
  }

  /// Converts a screen tap inside the canvas into world coordinates and computes an A* path
  /// (`Navigation.ts` + `MovementManager.ts`). Also triggers interaction if tapping directly
  /// on an already-in-range interactive zone!
  void _handleCanvasTapUp(TapUpDetails details, Size viewportSize) {
    _keyboardFocusNode.requestFocus();
    final local = details.localPosition;
    final worldX =
        (local.dx - viewportSize.width / 2) / _cameraZoom + _cameraCenter.dx;
    final worldY =
        (local.dy - viewportSize.height / 2) / _cameraZoom + _cameraCenter.dy;
    final worldTap = Offset(worldX, worldY);

    // If user tapped directly on the currently highlighted zone within range, open it immediately!
    if (_highlightedZone != null &&
        (worldTap - _highlightedZone!.center).distance <=
            _highlightedZone!.radius * 0.85) {
      _triggerInteract();
      return;
    }

    final chests = LobbyDataService.instance.subjectChests;
    final solids = buildLobbySolids(chests);
    final nav = LobbyNavGrid(
      cols: kLobbyCols,
      rows: kLobbyRows,
      solids: solids,
    );

    final path = nav.findPath(_playerPos, worldTap);
    setState(() {
      _tapPulseTarget = worldTap;
      _tapPulseProgress = 0.0;
      if (path.isNotEmpty) {
        _activePath = path;
      }
    });
  }

  Future<void> _openAvatarCustomizer() async {
    final equippedBadgeIcon =
        LobbyDataService.instance.progress.equippedBadge?.badgeIcon;
    final updated = await showLobbyAvatarCustomizerModal(
      context: context,
      initialLook: _playerLook,
      userName: widget.session.name,
      isFaculty: widget.session.isFaculty,
      equippedBadgeIcon: equippedBadgeIcon,
    );
    if (updated != null && mounted) {
      await AvatarSpriteCache.instance.saveLook(widget.session.id, updated);
      final newSheet =
          await AvatarSpriteCache.instance.resolveLookSpriteSheet(updated);
      if (mounted) {
        setState(() {
          _playerLook = updated;
          _playerSheet = newSheet;
        });
      }
    }
  }

  void _triggerWave() {
    HapticFeedback.lightImpact();
    setState(() {
      _waveBubbleProgress = 0.01;
    });
  }

  void _triggerInteract() {
    final zone = _highlightedZone;
    if (zone == null) return;

    switch (zone.kind) {
      case InteractiveZoneKind.questCounter:
        showQuestCounterModal(
          context: context,
          isFaculty: widget.session.isFaculty,
          userName: widget.session.name,
        );
        break;
      case InteractiveZoneKind.subjectChest:
        if (zone.subjectChestId != null) {
          showSubjectChestModal(
            context: context,
            chestId: zone.subjectChestId!,
            isFaculty: widget.session.isFaculty,
          );
        }
        break;
      case InteractiveZoneKind.smallMysteryChest:
        showSmallMysteryChestModal(
          context: context,
          smallChestId: zone.id,
          smallChestLabel: zone.label,
        );
        break;
      case InteractiveZoneKind.teacherCorner:
        showTeacherCornerModal(
          context: context,
          isFaculty: widget.session.isFaculty,
          userName: widget.session.name,
        );
        break;
      case InteractiveZoneKind.bulletinBoard:
        showBulletinBoardModal(context: context);
        break;
      case InteractiveZoneKind.studentLounge:
      case InteractiveZoneKind.reviewerTreasureArea:
        _triggerWave();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
                '🛋️ ${widget.session.name} is relaxing in the Student Study Lounge!'),
            behavior: SnackBarBehavior.floating,
            duration: const Duration(seconds: 2),
          ),
        );
        break;
    }
  }

  @override
  Widget build(BuildContext context) {
    final service = LobbyDataService.instance;
    final progress = service.progress;
    final equippedBadgeIcon = progress.equippedBadge?.badgeIcon;

    // Build cooldown map for the 4 Small Mystery Chests
    final nowMs = DateTime.now().millisecondsSinceEpoch;
    final smallChestRemainingSec = <String, int>{
      for (final z in INTERACTIVE_ZONES)
        if (z.kind == InteractiveZoneKind.smallMysteryChest)
          z.id: service.smallChestRemainingSeconds(z.id, nowMs),
    };

    return Scaffold(
      backgroundColor: const Color(0xFF090E1A),
      body: KeyboardListener(
        focusNode: _keyboardFocusNode,
        autofocus: true,
        onKeyEvent: (event) {
          if (event is KeyDownEvent) {
            _pressedKeys.add(event.logicalKey);
            if (event.logicalKey == LogicalKeyboardKey.keyE ||
                event.logicalKey == LogicalKeyboardKey.space) {
              _triggerInteract();
            }
          } else if (event is KeyUpEvent) {
            _pressedKeys.remove(event.logicalKey);
          }
        },
        child: _loading || _assets == null
            ? Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const CircularProgressIndicator(color: Color(0xFF38BDF8)),
                    const SizedBox(height: 14),
                    Text(
                      'Loading MIS-SHS 2D Pixel School Lobby...',
                      style: GoogleFonts.outfit(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              )
            : Stack(
                children: [
                  // 1. Interactive 2D Pixel Canvas (Tap-to-Walk + Camera Follow)
                  Positioned.fill(
                    child: LayoutBuilder(
                      builder: (context, constraints) {
                        final viewportSize = Size(
                            constraints.maxWidth, constraints.maxHeight);
                        return GestureDetector(
                          behavior: HitTestBehavior.opaque,
                          onTapUp: (d) => _handleCanvasTapUp(d, viewportSize),
                          child: CustomPaint(
                            size: viewportSize,
                            painter: SchoolLobbyCanvasPainter(
                              assets: _assets!,
                              playerSheet: _playerSheet,
                              playerPos: _playerPos,
                              playerFacing: _playerFacing,
                              playerIsWalking: _playerIsWalking,
                              animTick: _animTick,
                              playerName: widget.session.name,
                              isFaculty: widget.session.isFaculty,
                              equippedBadgeIcon: equippedBadgeIcon,
                              waveBubbleProgress: _waveBubbleProgress,
                              cameraCenter: _cameraCenter,
                              cameraZoom: _cameraZoom,
                              activePath: _activePath,
                              tapPulseTarget: _tapPulseTarget,
                              tapPulseProgress: _tapPulseProgress,
                              highlightedZone: _highlightedZone,
                              subjectChests: service.subjectChests,
                              smallChestRemainingSec: smallChestRemainingSec,
                            ),
                          ),
                        );
                      },
                    ),
                  ),

                  // 2. Top HUD Bar ("Back to App", XP/Level Pill, "My Badges", Teacher "+ Post Activity", "Avatar")
                  SafeArea(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          SingleChildScrollView(
                            scrollDirection: Axis.horizontal,
                            child: Row(
                              children: [
                                // "Back to App" Button
                                _HudPillButton(
                                  icon: Icons.arrow_back_rounded,
                                  label: 'Back to App',
                                  borderColor: Colors.white24,
                                  onTap: () => Navigator.of(context).pop(),
                                ),
                                const SizedBox(width: 8),

                                // Level & XP / Role Status Pill
                                _HudPillButton(
                                  icon: Icons.bolt_rounded,
                                  iconColor: const Color(0xFFFACC15),
                                  label:
                                      'LVL ${progress.level} • ${progress.xp} XP',
                                  borderColor:
                                      const Color(0xFFFACC15).withOpacity(0.5),
                                  onTap: () =>
                                      showMyBadgesModal(context: context),
                                ),
                                const SizedBox(width: 8),

                                // "My Badges" Drawer Button
                                _HudPillButton(
                                  icon: Icons.workspace_premium_rounded,
                                  iconColor: const Color(0xFF34D399),
                                  label: equippedBadgeIcon != null
                                      ? '$equippedBadgeIcon Badges (${progress.earnedBadges.length})'
                                      : 'My Badges (${progress.earnedBadges.length})',
                                  borderColor:
                                      const Color(0xFF10B981).withOpacity(0.55),
                                  onTap: () =>
                                      showMyBadgesModal(context: context),
                                ),
                                const SizedBox(width: 8),

                                // Teacher Quick "+ Post Activity" HUD Button
                                if (widget.session.isFaculty) ...[
                                  _HudPillButton(
                                    icon: Icons.add_task_rounded,
                                    iconColor: const Color(0xFFF59E0B),
                                    label: '+ Post Activity',
                                    borderColor: const Color(0xFFF59E0B),
                                    onTap: () => showPostActivityModal(
                                      context: context,
                                      postedBy: widget.session.name,
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                ],

                                // "Customize Avatar" Button
                                _HudPillButton(
                                  icon: Icons.face_retouching_natural_rounded,
                                  iconColor: const Color(0xFF38BDF8),
                                  label: 'Avatar',
                                  borderColor:
                                      const Color(0xFF38BDF8).withOpacity(0.55),
                                  onTap: _openAvatarCustomizer,
                                ),
                              ],
                            ),
                          ),

                          // Active Zone Proximity Banner under Top HUD
                          if (_highlightedZone != null) ...[
                            const SizedBox(height: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 12, vertical: 6),
                              decoration: BoxDecoration(
                                color:
                                    const Color(0xFF0F172A).withOpacity(0.88),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color: Color(_highlightedZone!.accentColor),
                                  width: 1.4,
                                ),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    Icons.place_rounded,
                                    color:
                                        Color(_highlightedZone!.accentColor),
                                    size: 16,
                                  ),
                                  const SizedBox(width: 6),
                                  Flexible(
                                    child: Text(
                                      '${_highlightedZone!.label} — ${_highlightedZone!.subtitle}',
                                      style: GoogleFonts.inter(
                                        color: Colors.white,
                                        fontSize: 11.5,
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),

                  // 3. Bottom-Left Virtual Touch Joystick (Mobile APK Controls)
                  Positioned(
                    left: 18,
                    bottom: 22,
                    child: SafeArea(
                      top: false,
                      child: SchoolLobbyVirtualJoystick(
                        onVectorChanged: (vec) {
                          _joystickVector = vec;
                        },
                      ),
                    ),
                  ),

                  // 4. Bottom-Right On-Screen "Interact" Button + Wave & Zoom Cluster
                  Positioned(
                    right: 16,
                    bottom: 22,
                    child: SafeArea(
                      top: false,
                      child: SchoolLobbyInteractCluster(
                        activeZone: _highlightedZone,
                        onInteract: _triggerInteract,
                        onWave: _triggerWave,
                        onZoomIn: () => setState(() {
                          _cameraZoom = (_cameraZoom + 0.2).clamp(0.85, 2.2);
                        }),
                        onZoomOut: () => setState(() {
                          _cameraZoom = (_cameraZoom - 0.2).clamp(0.85, 2.2);
                        }),
                      ),
                    ),
                  ),
                ],
              ),
      ),
    );
  }
}

class _HudPillButton extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String label;
  final Color borderColor;
  final VoidCallback onTap;

  const _HudPillButton({
    required this.icon,
    this.iconColor = Colors.white,
    required this.label,
    required this.borderColor,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: const Color(0xFF0F172A).withOpacity(0.86),
      borderRadius: BorderRadius.circular(99),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(99),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(99),
            border: Border.all(color: borderColor, width: 1.3),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, color: iconColor, size: 16),
              const SizedBox(width: 6),
              Text(
                label,
                style: GoogleFonts.inter(
                  color: Colors.white,
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
