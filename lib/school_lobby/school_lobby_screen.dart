import 'dart:async';
import 'dart:math' as math;
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';

import '../models/portal_models.dart';
import '../theme/portal_theme.dart';
import 'lobby_data_service.dart';
import 'school_lobby_avatar.dart';
import 'school_lobby_config.dart';
import 'school_lobby_controls.dart';
import 'school_lobby_engine.dart';
import 'school_lobby_modals.dart';

/// Self-Contained 2D Pixel "Mini School Lobby" Screen for the MIS-SHS Learner App.
/// Recycles TinyFloor's avatar rendering, movement/A* pathfinding, and 3/4 floor/furniture atlas,
/// combined with Phase 2's Quest Counter, Student Badge System, Subject Reviewer Chests,
/// Small Mystery Pop-Quiz Chests, First-Time Avatar & Nickname Onboarding,
/// Full-Screen Portrait/Landscape Responsiveness, and Night/Day Dark Mode.
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
  String _playerNickname = '';
  ui.Image? _playerSheet;
  bool _loading = true;
  bool _onboardingPromptShown = false;

  // Player state
  Offset _playerPos = kPlayerSpawnPoint;
  AvatarFacing _playerFacing = AvatarFacing.down;
  bool _playerIsWalking = false;

  // Movement inputs
  Offset _joystickVector = Offset.zero;
  List<Offset> _activePath = const [];
  Offset? _tapPulseTarget;
  double _tapPulseProgress = 1.0;

  // Camera & Viewport state
  Offset _cameraCenter = kPlayerSpawnPoint;
  double _cameraZoom = 1.2;
  bool _userAdjustedZoom = false;
  Size _lastViewportSize = Size.zero;
  bool _showMiniMap = true;
  bool _forcedLandscape = false;

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
    _playerNickname = widget.session.name;
    // Allow students to play in either Portrait or Landscape on their phones
    SystemChrome.setPreferredOrientations(const [
      DeviceOrientation.portraitUp,
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
    ]);
    _initLobby();
  }

  Future<void> _initLobby() async {
    await LobbyDataService.instance.init(widget.session.id);
    final savedLook = await AvatarSpriteCache.instance.loadSavedLook(
      widget.session.id,
      isFaculty: widget.session.isFaculty,
    );
    final savedNickname = await AvatarSpriteCache.instance.loadSavedNickname(
      widget.session.id,
      fallbackName: widget.session.name,
    );
    final completedOnboarding =
        await AvatarSpriteCache.instance.hasCompletedOnboarding(widget.session.id);
    final sheet =
        await AvatarSpriteCache.instance.resolveLookSpriteSheet(savedLook);
    final bundle = await SchoolLobbyAssetBundle.load();

    if (!mounted) return;
    setState(() {
      _playerLook = savedLook;
      _playerNickname = savedNickname;
      _playerSheet = sheet;
      _assets = bundle;
      _loading = false;
    });

    // Start 60 FPS game loop (~16ms tick)
    _gameLoopTimer = Timer.periodic(
      const Duration(milliseconds: 16),
      (_) => _onGameTick(0.016),
    );

    // Trigger First-Time Avatar & Nickname Creation Onboarding if first entry!
    if (!completedOnboarding && !_onboardingPromptShown) {
      _onboardingPromptShown = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          _openAvatarCustomizer(isFirstTimeOnboarding: true);
        }
      });
    }
  }

  @override
  void dispose() {
    _gameLoopTimer?.cancel();
    _keyboardFocusNode.dispose();
    // Restore default orientation preferences when leaving the lobby
    SystemChrome.setPreferredOrientations(const []);
    super.dispose();
  }

  void _toggleOrientationLock(bool isCurrentlyLandscape) {
    HapticFeedback.selectionClick();
    if (isCurrentlyLandscape) {
      _forcedLandscape = false;
      SystemChrome.setPreferredOrientations(const [
        DeviceOrientation.portraitUp,
      ]);
    } else {
      _forcedLandscape = true;
      SystemChrome.setPreferredOrientations(const [
        DeviceOrientation.landscapeLeft,
        DeviceOrientation.landscapeRight,
      ]);
    }
    // Re-unlock auto rotation after a short delay if returning to free rotation
    Future.delayed(const Duration(seconds: 4), () {
      if (mounted && !_forcedLandscape) {
        SystemChrome.setPreferredOrientations(const [
          DeviceOrientation.portraitUp,
          DeviceOrientation.landscapeLeft,
          DeviceOrientation.landscapeRight,
        ]);
      }
    });
  }

  Offset _clampCameraToWorld(Offset target, Size viewportSize, double zoom) {
    if (viewportSize.isEmpty) return target;
    final halfViewW = (viewportSize.width / 2) / zoom;
    final halfViewH = (viewportSize.height / 2) / zoom;

    double clampedX;
    if (halfViewW * 2 >= kLobbyWorldWidth) {
      clampedX = kLobbyWorldWidth / 2;
    } else {
      clampedX = target.dx.clamp(halfViewW, kLobbyWorldWidth - halfViewW);
    }

    double clampedY;
    if (halfViewH * 2 >= kLobbyWorldHeight) {
      clampedY = kLobbyWorldHeight / 2;
    } else {
      clampedY = target.dy.clamp(halfViewH, kLobbyWorldHeight - halfViewH);
    }

    return Offset(clampedX, clampedY);
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

    // 2. Smooth camera follow (`CameraRig.ts` lerp = 0.14) clamped to world bounds
    final desiredCamera =
        _clampCameraToWorld(_playerPos, _lastViewportSize, _cameraZoom);
    _cameraCenter =
        Offset.lerp(_cameraCenter, desiredCamera, 0.16) ?? desiredCamera;

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

  Future<void> _openAvatarCustomizer({bool isFirstTimeOnboarding = false}) async {
    final equippedBadgeIcon =
        LobbyDataService.instance.progress.equippedBadge?.badgeIcon;
    final result = await showLobbyAvatarCustomizerModal(
      context: context,
      initialLook: _playerLook,
      initialNickname: _playerNickname,
      isFaculty: widget.session.isFaculty,
      equippedBadgeIcon: equippedBadgeIcon,
      isFirstTimeOnboarding: isFirstTimeOnboarding,
    );
    if (result != null && mounted) {
      await AvatarSpriteCache.instance.saveLook(widget.session.id, result.look);
      await AvatarSpriteCache.instance
          .saveNickname(widget.session.id, result.nickname);
      await AvatarSpriteCache.instance
          .markOnboardingCompleted(widget.session.id);

      final newSheet =
          await AvatarSpriteCache.instance.resolveLookSpriteSheet(result.look);
      if (mounted) {
        setState(() {
          _playerLook = result.look;
          _playerNickname = result.nickname;
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
          userName: _playerNickname,
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
          userName: _playerNickname,
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
                '🛋️ $_playerNickname is relaxing in the Student Study Lounge!'),
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
    final screenSize = MediaQuery.sizeOf(context);
    final isLandscape = screenSize.width > screenSize.height;

    // Auto-adapt camera zoom on screen rotation if the user hasn't manually pinched/zoomed
    if (_lastViewportSize != screenSize) {
      _lastViewportSize = screenSize;
      if (!_userAdjustedZoom) {
        final shortest = math.min(screenSize.width, screenSize.height);
        _cameraZoom = isLandscape
            ? (shortest < 420 ? 1.18 : 1.28)
            : (shortest < 380 ? 1.05 : 1.15);
      }
      _cameraCenter =
          _clampCameraToWorld(_playerPos, screenSize, _cameraZoom);
    }

    // Build cooldown map for the 8 Small Mystery Chests
    final nowMs = DateTime.now().millisecondsSinceEpoch;
    final smallChestRemainingSec = <String, int>{
      for (final z in INTERACTIVE_ZONES)
        if (z.kind == InteractiveZoneKind.smallMysteryChest)
          z.id: service.smallChestRemainingSeconds(z.id, nowMs),
    };

    return ListenableBuilder(
      listenable: ThemeController.instance,
      builder: (context, _) {
        final isDarkMode = ThemeController.instance.isDarkMode;

        return Scaffold(
          backgroundColor: const Color(0xFF090E1A),
          body: SizedBox.expand(
            child: KeyboardListener(
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
                          const CircularProgressIndicator(
                              color: Color(0xFF38BDF8)),
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
                      fit: StackFit.expand,
                      children: [
                        // 1. Full-Screen 2D Pixel Canvas (Tap-to-Walk + Camera Follow)
                        Positioned.fill(
                          child: LayoutBuilder(
                            builder: (context, constraints) {
                              final viewportSize = Size(
                                constraints.maxWidth,
                                constraints.maxHeight,
                              );
                              return GestureDetector(
                                behavior: HitTestBehavior.opaque,
                                onTapUp: (d) =>
                                    _handleCanvasTapUp(d, viewportSize),
                                child: CustomPaint(
                                  size: viewportSize,
                                  painter: SchoolLobbyCanvasPainter(
                                    assets: _assets!,
                                    playerSheet: _playerSheet,
                                    playerPos: _playerPos,
                                    playerFacing: _playerFacing,
                                    playerIsWalking: _playerIsWalking,
                                    animTick: _animTick,
                                    playerName: _playerNickname,
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
                                    smallChestRemainingSec:
                                        smallChestRemainingSec,
                                    isDarkMode: isDarkMode,
                                  ),
                                ),
                              );
                            },
                          ),
                        ),

                        // 2. Top HUD Bar (Explicitly Positioned so Stack always fills 100% of screen!)
                        Positioned(
                          top: 0,
                          left: 0,
                          right: 0,
                          child: SafeArea(
                            bottom: false,
                            child: Padding(
                              padding: const EdgeInsets.fromLTRB(10, 6, 10, 0),
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
                                          onTap: () =>
                                              Navigator.of(context).pop(),
                                        ),
                                        const SizedBox(width: 6),

                                        // Level & XP Status Pill
                                        _HudPillButton(
                                          icon: Icons.bolt_rounded,
                                          iconColor: const Color(0xFFFACC15),
                                          label:
                                              'LVL ${progress.level} • ${progress.xp} XP',
                                          borderColor: const Color(0xFFFACC15)
                                              .withOpacity(0.5),
                                          onTap: () => showMyBadgesModal(
                                              context: context),
                                        ),
                                        const SizedBox(width: 6),

                                        // "My Badges" Drawer Button
                                        _HudPillButton(
                                          icon:
                                              Icons.workspace_premium_rounded,
                                          iconColor: const Color(0xFF34D399),
                                          label: equippedBadgeIcon != null
                                              ? '$equippedBadgeIcon Badges (${progress.earnedBadges.length})'
                                              : 'Badges (${progress.earnedBadges.length})',
                                          borderColor: const Color(0xFF10B981)
                                              .withOpacity(0.55),
                                          onTap: () => showMyBadgesModal(
                                              context: context),
                                        ),
                                        const SizedBox(width: 6),

                                        // Teacher Quick "+ Post Activity" HUD Button
                                        if (widget.session.isFaculty) ...[
                                          _HudPillButton(
                                            icon: Icons.add_task_rounded,
                                            iconColor: const Color(0xFFF59E0B),
                                            label: '+ Post Activity',
                                            borderColor:
                                                const Color(0xFFF59E0B),
                                            onTap: () => showPostActivityModal(
                                              context: context,
                                              postedBy: _playerNickname,
                                            ),
                                          ),
                                          const SizedBox(width: 6),
                                        ],

                                        // "Customize Avatar & Nickname" Button
                                        _HudPillButton(
                                          icon: Icons
                                              .face_retouching_natural_rounded,
                                          iconColor: const Color(0xFF38BDF8),
                                          label: 'Avatar ($_playerNickname)',
                                          borderColor: const Color(0xFF38BDF8)
                                              .withOpacity(0.55),
                                          onTap: () => _openAvatarCustomizer(
                                            isFirstTimeOnboarding: false,
                                          ),
                                        ),
                                        const SizedBox(width: 6),

                                        // Dark Mode / Night Campus Toggle Pill
                                        _HudPillButton(
                                          icon: isDarkMode
                                              ? Icons.dark_mode_rounded
                                              : Icons.light_mode_rounded,
                                          iconColor: isDarkMode
                                              ? const Color(0xFFFACC15)
                                              : const Color(0xFFF59E0B),
                                          label: isDarkMode ? 'Night' : 'Day',
                                          borderColor: const Color(0xFFFACC15)
                                              .withOpacity(0.45),
                                          onTap: () => ThemeController.instance
                                              .toggleDarkMode(),
                                        ),
                                        const SizedBox(width: 6),

                                        // 1-Tap Portrait / Landscape Orientation Switcher
                                        _HudPillButton(
                                          icon: isLandscape
                                              ? Icons
                                                  .stay_current_portrait_rounded
                                              : Icons
                                                  .stay_current_landscape_rounded,
                                          iconColor: const Color(0xFFA78BFA),
                                          label: isLandscape
                                              ? 'Portrait'
                                              : 'Landscape',
                                          borderColor: const Color(0xFFA78BFA)
                                              .withOpacity(0.45),
                                          onTap: () => _toggleOrientationLock(
                                              isLandscape),
                                        ),
                                        const SizedBox(width: 6),

                                        // Mini-Map Toggle Pill
                                        _HudPillButton(
                                          icon: Icons.map_rounded,
                                          iconColor: _showMiniMap
                                              ? const Color(0xFF34D399)
                                              : Colors.white60,
                                          label: 'Map',
                                          borderColor: _showMiniMap
                                              ? const Color(0xFF34D399)
                                                  .withOpacity(0.5)
                                              : Colors.white24,
                                          onTap: () => setState(() {
                                            _showMiniMap = !_showMiniMap;
                                          }),
                                        ),
                                      ],
                                    ),
                                  ),

                                  // Active Zone Proximity Banner under Top HUD
                                  if (_highlightedZone != null) ...[
                                    const SizedBox(height: 6),
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 12, vertical: 6),
                                      decoration: BoxDecoration(
                                        color: const Color(0xFF0F172A)
                                            .withOpacity(0.90),
                                        borderRadius: BorderRadius.circular(12),
                                        border: Border.all(
                                          color: Color(
                                              _highlightedZone!.accentColor),
                                          width: 1.4,
                                        ),
                                      ),
                                      child: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Icon(
                                            Icons.place_rounded,
                                            color: Color(
                                                _highlightedZone!.accentColor),
                                            size: 15,
                                          ),
                                          const SizedBox(width: 6),
                                          Flexible(
                                            child: Text(
                                              '${_highlightedZone!.label} — ${_highlightedZone!.subtitle}',
                                              style: GoogleFonts.inter(
                                                color: Colors.white,
                                                fontSize: 11,
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
                        ),

                        // 3. Top-Right Compact Campus Mini-Map Radar
                        if (_showMiniMap)
                          Positioned(
                            top: isLandscape ? 54 : 62,
                            right: 12,
                            child: SafeArea(
                              bottom: false,
                              child: _LobbyMiniMapRadar(
                                playerPos: _playerPos,
                                subjectChests: service.subjectChests,
                                isCompact: !isLandscape && screenSize.width < 390,
                                onTapWorldPoint: (worldTarget) {
                                  final solids =
                                      buildLobbySolids(service.subjectChests);
                                  final nav = LobbyNavGrid(
                                    cols: kLobbyCols,
                                    rows: kLobbyRows,
                                    solids: solids,
                                  );
                                  final path =
                                      nav.findPath(_playerPos, worldTarget);
                                  setState(() {
                                    _tapPulseTarget = worldTarget;
                                    _tapPulseProgress = 0.0;
                                    if (path.isNotEmpty) {
                                      _activePath = path;
                                    }
                                  });
                                },
                              ),
                            ),
                          ),

                        // 4. Bottom-Left Virtual Touch Joystick (Mobile APK Controls)
                        Positioned(
                          left: isLandscape ? 20 : 12,
                          bottom: isLandscape ? 18 : 16,
                          child: SafeArea(
                            top: false,
                            child: Transform.scale(
                              scale:
                                  (!isLandscape && screenSize.width < 380)
                                      ? 0.88
                                      : 1.0,
                              alignment: Alignment.bottomLeft,
                              child: SchoolLobbyVirtualJoystick(
                                onVectorChanged: (vec) {
                                  _joystickVector = vec;
                                },
                              ),
                            ),
                          ),
                        ),

                        // 5. Bottom-Right On-Screen "Interact" Button + Wave & Zoom Cluster
                        Positioned(
                          right: isLandscape ? 18 : 12,
                          bottom: isLandscape ? 18 : 16,
                          child: SafeArea(
                            top: false,
                            child: Transform.scale(
                              scale:
                                  (!isLandscape && screenSize.width < 380)
                                      ? 0.90
                                      : 1.0,
                              alignment: Alignment.bottomRight,
                              child: SchoolLobbyInteractCluster(
                                activeZone: _highlightedZone,
                                onInteract: _triggerInteract,
                                onWave: _triggerWave,
                                onZoomIn: () => setState(() {
                                  _userAdjustedZoom = true;
                                  _cameraZoom =
                                      (_cameraZoom + 0.18).clamp(0.75, 2.2);
                                  _cameraCenter = _clampCameraToWorld(
                                    _playerPos,
                                    screenSize,
                                    _cameraZoom,
                                  );
                                }),
                                onZoomOut: () => setState(() {
                                  _userAdjustedZoom = true;
                                  _cameraZoom =
                                      (_cameraZoom - 0.18).clamp(0.75, 2.2);
                                  _cameraCenter = _clampCameraToWorld(
                                    _playerPos,
                                    screenSize,
                                    _cameraZoom,
                                  );
                                }),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
            ),
          ),
        );
      },
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
      color: const Color(0xFF0F172A).withOpacity(0.88),
      borderRadius: BorderRadius.circular(99),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(99),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 7),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(99),
            border: Border.all(color: borderColor, width: 1.25),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, color: iconColor, size: 15),
              const SizedBox(width: 5),
              Text(
                label,
                style: GoogleFonts.inter(
                  color: Colors.white,
                  fontSize: 11.5,
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

/// Interactive Mini-Map Radar of the expanded `48 x 34` (`1536 x 1088` px) School Campus.
/// Tapping anywhere on the mini-map auto-walks the player to that wing!
class _LobbyMiniMapRadar extends StatelessWidget {
  final Offset playerPos;
  final List<SubjectChest> subjectChests;
  final bool isCompact;
  final ValueChanged<Offset> onTapWorldPoint;

  const _LobbyMiniMapRadar({
    required this.playerPos,
    required this.subjectChests,
    required this.isCompact,
    required this.onTapWorldPoint,
  });

  @override
  Widget build(BuildContext context) {
    final mapW = isCompact ? 112.0 : 136.0;
    final mapH = mapW * (kLobbyWorldHeight / kLobbyWorldWidth);

    return GestureDetector(
      onTapDown: (d) {
        final wx =
            (d.localPosition.dx / mapW * kLobbyWorldWidth).clamp(48.0, kLobbyWorldWidth - 48.0);
        final wy =
            (d.localPosition.dy / mapH * kLobbyWorldHeight).clamp(96.0, kLobbyWorldHeight - 48.0);
        onTapWorldPoint(Offset(wx, wy));
      },
      child: Container(
        width: mapW,
        height: mapH,
        decoration: BoxDecoration(
          color: const Color(0xFF0F172A).withOpacity(0.86),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: const Color(0xFF38BDF8).withOpacity(0.55),
            width: 1.4,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.45),
              blurRadius: 8,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(8.5),
          child: CustomPaint(
            size: Size(mapW, mapH),
            painter: _MiniMapRadarPainter(
              playerPos: playerPos,
              subjectChests: subjectChests,
            ),
          ),
        ),
      ),
    );
  }
}

class _MiniMapRadarPainter extends CustomPainter {
  final Offset playerPos;
  final List<SubjectChest> subjectChests;

  const _MiniMapRadarPainter({
    required this.playerPos,
    required this.subjectChests,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final sx = size.width / kLobbyWorldWidth;
    final sy = size.height / kLobbyWorldHeight;

    // 1. Campus Zones
    // Bulletin Wing (Top-Left)
    canvas.drawRect(
      Rect.fromLTWH(44 * sx, 92 * sy, 460 * sx, 190 * sy),
      Paint()..color = const Color(0xFF38BDF8).withOpacity(0.28),
    );
    // Quest Counter (Top-Center)
    canvas.drawRect(
      Rect.fromLTWH(620 * sx, 92 * sy, 296 * sx, 170 * sy),
      Paint()..color = const Color(0xFFF59E0B).withOpacity(0.32),
    );
    // Teacher's Corner (Top-Right)
    canvas.drawRect(
      Rect.fromLTWH(1060 * sx, 92 * sy, 420 * sx, 190 * sy),
      Paint()..color = const Color(0xFFFBBF24).withOpacity(0.28),
    );
    // Student Lounge & Study Commons (Left & Center-Bottom)
    canvas.drawRect(
      Rect.fromLTWH(76 * sx, 430 * sy, 680 * sx, 560 * sy),
      Paint()..color = const Color(0xFF10B981).withOpacity(0.22),
    );
    // Reviewer Treasure Vault Sanctuary (Bottom-Right)
    canvas.drawRect(
      Rect.fromLTWH(880 * sx, 460 * sy, 580 * sx, 560 * sy),
      Paint()..color = const Color(0xFFA855F7).withOpacity(0.28),
    );

    // 2. Subject Chest dots
    for (var i = 0; i < subjectChests.length; i++) {
      final pos = subjectChestPosition(i);
      canvas.drawCircle(
        Offset(pos.dx * sx, pos.dy * sy),
        2.6,
        Paint()..color = Color(subjectChests[i].colorValue),
      );
    }

    // 3. Player glowing dot
    final px = (playerPos.dx * sx).clamp(4.0, size.width - 4.0);
    final py = (playerPos.dy * sy).clamp(4.0, size.height - 4.0);
    canvas.drawCircle(
      Offset(px, py),
      5.5,
      Paint()..color = const Color(0xFF38BDF8).withOpacity(0.38),
    );
    canvas.drawCircle(
      Offset(px, py),
      3.0,
      Paint()..color = Colors.white,
    );
  }

  @override
  bool shouldRepaint(covariant _MiniMapRadarPainter oldDelegate) =>
      oldDelegate.playerPos != playerPos ||
      oldDelegate.subjectChests.length != subjectChests.length;
}
