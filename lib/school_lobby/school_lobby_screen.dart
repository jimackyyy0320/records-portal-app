import 'dart:async';
import 'dart:math' as math;
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';

import '../models/portal_models.dart';
import '../theme/portal_theme.dart';
import 'lobby_data_service.dart';
import 'lobby_presence_service.dart';
import 'school_lobby_avatar.dart';
import 'school_lobby_config.dart';
import 'school_lobby_controls.dart';
import 'school_lobby_engine.dart';
import 'school_lobby_modals.dart';

/// Self-Contained 2D Pixel "Mini School Lobby" Screen for the MIS-SHS Learner App.
/// Includes:
/// - 5 Explorable Campus Rooms connected via Doors (`Main Lobby`, `Park`, `Class Room`, `Canteen`, `Faculty Room`)
/// - Student Rest States (`🪑 Sit`, `😪 Nap`, `🛌 Sleep`) on chairs, benches, sofas, desks & park lawns
/// - Real Google Drive Reviewer Folder (`1EFX9aylAeSRmDWU7OeFIPa0llAMD8wC5`) sync & HTML Streamer
/// - MIS Control Sheet (`Subject Enrollment`) Active vs. Finished filtering + strict Student Enrollment filtering
/// - Cloud Thought Bubbles (`💭`) for chatting with classmates across the campus
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

  // Room & Player state
  LobbyRoomId _currentRoom = LobbyRoomId.mainLobby;
  Offset _playerPos = kPlayerSpawnPoint;
  AvatarFacing _playerFacing = AvatarFacing.down;
  bool _playerIsWalking = false;
  PlayerRestState _playerRestState = PlayerRestState.none;

  // Thought Bubble state (`💭`)
  String? _playerThoughtText;
  int _playerThoughtUntilMs = 0;
  final Map<String, String> _activePeerThoughts = <String, String>{};

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
  bool _showOfflineBots = false;

  // Animation & Wave state
  int _animTick = 0;
  int _frameCounter = 0;
  double _waveBubbleProgress = 0.0;

  // Proximity state
  InteractiveZone? _highlightedZone;

  // Cached per-room collision & zone lists to avoid 60 FPS GC churn
  LobbyRoomId? _cachedRoomForSolids;
  int _cachedChestCountForSolids = -1;
  List<Rect> _cachedSolids = const [];
  List<InteractiveZone> _cachedZones = const [];

  Timer? _gameLoopTimer;

  @override
  void initState() {
    super.initState();
    _playerNickname = widget.session.name;
    SystemChrome.setPreferredOrientations(const [
      DeviceOrientation.portraitUp,
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
    ]);
    _initLobby();
  }

  Future<void> _initLobby() async {
    await LobbyDataService.instance.init(
      widget.session.id,
      session: widget.session,
    );
    // Asynchronously sync active subjects from MIS Control Sheet & Google Drive Reviewer Folder
    unawaited(
      LobbyDataService.instance.syncDriveReviewersForSession(widget.session),
    );

    final savedLook = await AvatarSpriteCache.instance.loadSavedLook(
      widget.session.id,
      isFaculty: widget.session.isFaculty,
    );
    final savedNickname = await AvatarSpriteCache.instance.loadSavedNickname(
      widget.session.id,
      fallbackName: widget.session.name,
    );
    final completedOnboarding = await AvatarSpriteCache.instance
        .hasCompletedOnboarding(widget.session.id);
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

    // Start live cross-device multiplayer presence & synchronization
    unawaited(
      LobbyPresenceService.instance.startPresence(
        session: widget.session,
        nickname: savedNickname,
        look: savedLook,
        equippedBadgeIcon:
            LobbyDataService.instance.progress.equippedBadge?.badgeIcon,
        initialRoom: _currentRoom,
        initialPos: _playerPos,
      ),
    );

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
    LobbyPresenceService.instance.stopPresence();
    _gameLoopTimer?.cancel();
    _keyboardFocusNode.dispose();
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

  void _enterRoom(LobbyRoomId targetRoom, {Offset? spawnOverride}) {
    HapticFeedback.mediumImpact();
    final spawn = spawnOverride ?? targetRoom.defaultSpawn;
    setState(() {
      _currentRoom = targetRoom;
      _playerPos = spawn;
      _playerFacing = AvatarFacing.down;
      _playerIsWalking = false;
      _playerRestState = PlayerRestState.none;
      _activePath = const [];
      _highlightedZone = null;
      _cameraCenter =
          _clampCameraToWorld(spawn, _lastViewportSize, _cameraZoom);
    });
    LobbyPresenceService.instance.updateLocalPlayerState(
      room: targetRoom,
      position: spawn,
      facing: AvatarFacing.down,
      isWalking: false,
      restState: PlayerRestState.none,
      forceImmediateBroadcast: true,
    );
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          '${targetRoom.iconEmoji} Entered ${targetRoom.title}!',
        ),
        behavior: SnackBarBehavior.floating,
        duration: const Duration(milliseconds: 1600),
      ),
    );
  }

  void _setPlayerRestState(
    PlayerRestState nextState, {
    LobbyRestSpot? snapToSpot,
  }) {
    HapticFeedback.selectionClick();
    setState(() {
      if (snapToSpot != null && nextState.isResting) {
        _playerPos = snapToSpot.position;
        _playerFacing = snapToSpot.facing;
      }
      _playerRestState = nextState;
      if (nextState.isResting) {
        _activePath = const [];
        _playerIsWalking = false;
      }
    });
    LobbyPresenceService.instance.updateLocalPlayerState(
      position: _playerPos,
      facing: _playerFacing,
      isWalking: _playerIsWalking,
      restState: _playerRestState,
      forceImmediateBroadcast: true,
    );
  }

  Future<void> _openThoughtBubbleModal({LobbyPeerStudent? peer}) async {
    // Check if there is a nearby live online player or peer student even if not explicitly passed
    LobbyPeerStudent? targetPeer = peer;
    if (targetPeer == null) {
      for (final rp in LobbyPresenceService.instance.playersForRoom(_currentRoom)) {
        if ((_playerPos - rp.currentPos).distance <= 140.0) {
          targetPeer = LobbyPeerStudent(
            id: 'live_${rp.userId}',
            name: rp.nickname,
            roleTag: rp.isFaculty ? 'Live Teacher 🟢' : 'Live Classmate 🟢',
            presetName: rp.look.presetName,
            room: _currentRoom,
            x: rp.currentPos.dx,
            y: rp.currentPos.dy,
            defaultThought:
                rp.thoughtText ?? 'Online in ${_currentRoom.shortLabel}',
            sampleReplies: const [],
          );
          break;
        }
      }
    }
    if (targetPeer == null && _showOfflineBots) {
      for (final p in peersForRoom(_currentRoom)) {
        if ((_playerPos - p.position).distance <= 120.0) {
          targetPeer = p;
          break;
        }
      }
    }

    final result = await showThoughtBubbleComposerModal(
      context: context,
      playerName: _playerNickname,
      isFaculty: widget.session.isFaculty,
      currentRoom: _currentRoom,
      nearbyPeer: targetPeer,
      currentThought: _playerThoughtText,
    );
    if (!mounted || result == null) return;

    if (result.trim().isEmpty) {
      setState(() {
        _playerThoughtText = null;
        _playerThoughtUntilMs = 0;
      });
      LobbyPresenceService.instance.updateLocalPlayerState(
        thoughtText: '',
        thoughtUntilMs: 0,
        forceImmediateBroadcast: true,
      );
      return;
    }

    final nowMs = DateTime.now().millisecondsSinceEpoch;
    final clean = result.trim();
    setState(() {
      _playerThoughtText = clean;
      _playerThoughtUntilMs = nowMs + 14000; // Visible for 14 seconds
    });

    LobbyPresenceService.instance.updateLocalPlayerState(
      thoughtText: clean,
      thoughtUntilMs: _playerThoughtUntilMs,
      forceImmediateBroadcast: true,
    );

    LobbyDataService.instance.recordThoughtBubble(
      senderName: _playerNickname,
      senderRole: widget.session.isFaculty ? 'Teacher' : 'Student',
      roomName: _currentRoom.shortLabel,
      text: clean,
      isFromPeer: false,
    );

    // If an offline practice classmate peer is nearby, let them respond with a friendly Thought Bubble!
    if (targetPeer != null && targetPeer.sampleReplies.isNotEmpty) {
      final peerObj = targetPeer;
      Future.delayed(const Duration(milliseconds: 900), () {
        if (!mounted) return;
        final reply = peerObj.sampleReplies[
            DateTime.now().second % peerObj.sampleReplies.length];
        setState(() {
          _activePeerThoughts[peerObj.id] = reply;
        });
        LobbyDataService.instance.recordThoughtBubble(
          senderName: peerObj.name,
          senderRole: peerObj.roleTag,
          roomName: _currentRoom.shortLabel,
          text: reply.replaceFirst('💭 ', ''),
          isFromPeer: true,
        );
      });
    }
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

  Offset _moveWithSlidingCollision(
      Offset current, Offset delta, List<Rect> solids) {
    var nextX = (current.dx + delta.dx).clamp(38.0, kLobbyWorldWidth - 38.0);
    var nextY = (current.dy + delta.dy).clamp(90.0, kLobbyWorldHeight - 30.0);

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

    if (_cachedRoomForSolids != _currentRoom ||
        _cachedChestCountForSolids != chests.length) {
      _cachedRoomForSolids = _currentRoom;
      _cachedChestCountForSolids = chests.length;
      _cachedSolids = buildLobbySolids(chests, room: _currentRoom);
      _cachedZones = buildActiveInteractiveZones(chests, room: _currentRoom);
    }
    final solids = _cachedSolids;

    // 1. Determine movement vector: Keyboard / Joystick overrides Tap-to-Walk path
    final kbVec = _readKeyboardVector();
    final manualVec =
        _joystickVector != Offset.zero ? _joystickVector : kbVec;

    var moveDelta = Offset.zero;
    var walking = false;

    if (manualVec != Offset.zero) {
      // Automatically stand up if the player was sitting/napping/sleeping
      if (_playerRestState.isResting) {
        _playerRestState = PlayerRestState.none;
      }
      _activePath = const [];
      moveDelta = manualVec * (kPlayerMoveSpeed * dt);
      _playerFacing = _facingFromVector(manualVec, _playerFacing);
      walking = true;
    } else if (_activePath.isNotEmpty) {
      if (_playerRestState.isResting) {
        _playerRestState = PlayerRestState.none;
      }
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
        _activePath = const [];
        walking = false;
      }
    }

    final wasWalking = _playerIsWalking;
    _playerIsWalking = walking;

    // 2. Smooth camera follow clamped to world bounds
    final desiredCamera =
        _clampCameraToWorld(_playerPos, _lastViewportSize, _cameraZoom);
    final prevCamera = _cameraCenter;
    _cameraCenter =
        Offset.lerp(_cameraCenter, desiredCamera, 0.16) ?? desiredCamera;
    final cameraMoved = (_cameraCenter - prevCamera).distanceSquared > 0.04;

    // 3. Advance 10 FPS sprite animation counter & visual effects
    _frameCounter++;
    var animChanged = false;
    if (_frameCounter % 6 == 0) {
      _animTick++;
      animChanged = true;
    }
    if (_tapPulseProgress < 1.0) {
      _tapPulseProgress = (_tapPulseProgress + dt * 2.2).clamp(0.0, 1.0);
      animChanged = true;
    }
    if (_waveBubbleProgress > 0.0) {
      _waveBubbleProgress = (_waveBubbleProgress + dt * 0.9).clamp(0.0, 1.0);
      if (_waveBubbleProgress >= 1.0) {
        _waveBubbleProgress = 0.0;
      }
      animChanged = true;
    }

    // Expire player Thought Bubble after timer
    if (_playerThoughtText != null &&
        _playerThoughtUntilMs > 0 &&
        DateTime.now().millisecondsSinceEpoch >= _playerThoughtUntilMs) {
      _playerThoughtText = null;
      _playerThoughtUntilMs = 0;
      animChanged = true;
    }

    // 3b. Advance 60 FPS remote player position interpolation & sync local player state
    final remoteMoved =
        LobbyPresenceService.instance.tickInterpolation(dt, _currentRoom);
    LobbyPresenceService.instance.updateLocalPlayerState(
      nickname: _playerNickname,
      look: _playerLook,
      equippedBadgeIcon: service.progress.equippedBadge?.badgeIcon,
      room: _currentRoom,
      position: _playerPos,
      facing: _playerFacing,
      isWalking: _playerIsWalking,
      restState: _playerRestState,
      thoughtText: _playerThoughtText,
      thoughtUntilMs: _playerThoughtUntilMs,
    );

    // 4. Update nearest InteractiveZone within radius in `_currentRoom`
    final allZones = _cachedZones;
    InteractiveZone? nearest;
    var bestDist = 999999.0;
    for (final z in allZones) {
      if (!_showOfflineBots && z.kind == InteractiveZoneKind.peerStudent) {
        continue;
      }
      final d = (_playerPos - z.center).distance;
      if (d <= z.radius && d < bestDist) {
        bestDist = d;
        nearest = z;
      }
    }

    // Also include live online players in `_currentRoom` as interactive proximity targets!
    for (final rp in LobbyPresenceService.instance.playersForRoom(_currentRoom)) {
      final d = (_playerPos - rp.currentPos).distance;
      if (d <= 115.0 && d < bestDist) {
        bestDist = d;
        nearest = InteractiveZone(
          id: 'zone_live_${rp.userId}',
          label: 'Chat with ${rp.nickname} 💭',
          subtitle: rp.isFaculty
              ? 'Live Online Teacher — Tap to send Thought Bubble!'
              : 'Live Online Classmate — Tap to send Thought Bubble!',
          kind: InteractiveZoneKind.peerStudent,
          x: rp.currentPos.dx,
          y: rp.currentPos.dy,
          radius: 115.0,
          accentColor: rp.isFaculty ? 0xFFFACC15 : 0xFF10B981,
          room: _currentRoom,
          peerStudentId: 'live_${rp.userId}',
        );
      }
    }

    final zoneChanged = _highlightedZone?.id != nearest?.id;
    _highlightedZone = nearest;

    if (walking ||
        wasWalking ||
        cameraMoved ||
        animChanged ||
        zoneChanged ||
        remoteMoved) {
      setState(() {});
    }
  }

  void _handleCanvasTapUp(TapUpDetails details, Size viewportSize) {
    _keyboardFocusNode.requestFocus();
    final local = details.localPosition;
    final worldX =
        (local.dx - viewportSize.width / 2) / _cameraZoom + _cameraCenter.dx;
    final worldY =
        (local.dy - viewportSize.height / 2) / _cameraZoom + _cameraCenter.dy;
    final worldTap = Offset(worldX, worldY);

    // If user tapped directly on the currently highlighted zone within range, trigger it immediately!
    if (_highlightedZone != null &&
        (worldTap - _highlightedZone!.center).distance <=
            _highlightedZone!.radius * 0.85) {
      _triggerInteract();
      return;
    }

    final chests = LobbyDataService.instance.subjectChests;
    final solids = buildLobbySolids(chests, room: _currentRoom);
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
        _playerRestState = PlayerRestState.none;
        _activePath = path;
      }
    });
  }

  Future<void> _openAvatarCustomizer(
      {bool isFirstTimeOnboarding = false}) async {
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
        LobbyPresenceService.instance.updateLocalPlayerState(
          nickname: result.nickname,
          look: result.look,
          equippedBadgeIcon: equippedBadgeIcon,
          forceImmediateBroadcast: true,
        );
      }
    }
  }

  void _triggerWave() {
    HapticFeedback.lightImpact();
    setState(() {
      _waveBubbleProgress = 0.01;
    });
    LobbyPresenceService.instance.updateLocalPlayerState(
      triggerWave: true,
      forceImmediateBroadcast: true,
    );
  }

  Future<void> _triggerInteract() async {
    final zone = _highlightedZone;
    if (zone == null) return;

    switch (zone.kind) {
      case InteractiveZoneKind.doorPortal:
        if (zone.targetRoom != null) {
          _enterRoom(zone.targetRoom!, spawnOverride: zone.targetSpawn);
        }
        break;
      case InteractiveZoneKind.restSpot:
        final spot = restSpotsForRoom(_currentRoom).firstWhere(
          (r) => r.id == zone.restSpotId,
          orElse: () => LobbyRestSpot(
            id: 'fallback',
            label: zone.label,
            room: _currentRoom,
            x: zone.x,
            y: zone.y,
          ),
        );
        final chosenRest = await showRestSpotActionModal(
          context: context,
          spotLabel: spot.label,
          currentState: _playerRestState,
          canSleepFlat: spot.canSleepFlat,
        );
        if (chosenRest != null && mounted) {
          _setPlayerRestState(chosenRest, snapToSpot: spot);
        }
        break;
      case InteractiveZoneKind.peerStudent:
        final pid = zone.peerStudentId ?? '';
        if (pid.startsWith('live_')) {
          final liveUid = pid.substring(5);
          final rpList = LobbyPresenceService.instance
              .playersForRoom(_currentRoom)
              .where((p) => p.userId == liveUid)
              .toList();
          if (rpList.isNotEmpty) {
            final rp = rpList.first;
            await _openThoughtBubbleModal(
              peer: LobbyPeerStudent(
                id: 'live_${rp.userId}',
                name: rp.nickname,
                roleTag:
                    rp.isFaculty ? 'Live Teacher 🟢' : 'Live Classmate 🟢',
                presetName: rp.look.presetName,
                room: _currentRoom,
                x: rp.currentPos.dx,
                y: rp.currentPos.dy,
                defaultThought:
                    rp.thoughtText ?? 'Online in ${_currentRoom.shortLabel}',
                sampleReplies: const [],
              ),
            );
            break;
          }
        }
        final peer = peersForRoom(_currentRoom).firstWhere(
          (p) => p.id == zone.peerStudentId,
          orElse: () => kLobbyPeerStudents.first,
        );
        await _openThoughtBubbleModal(peer: peer);
        break;
      case InteractiveZoneKind.questCounter:
        await showQuestCounterModal(
          context: context,
          isFaculty: widget.session.isFaculty,
          userName: _playerNickname,
        );
        break;
      case InteractiveZoneKind.subjectChest:
        if (zone.subjectChestId != null) {
          await showSubjectChestModal(
            context: context,
            chestId: zone.subjectChestId!,
            isFaculty: widget.session.isFaculty,
          );
        }
        break;
      case InteractiveZoneKind.smallMysteryChest:
        await showSmallMysteryChestModal(
          context: context,
          smallChestId: zone.id,
          smallChestLabel: zone.label,
        );
        break;
      case InteractiveZoneKind.teacherCorner:
        await showTeacherCornerModal(
          context: context,
          isFaculty: widget.session.isFaculty,
          userName: _playerNickname,
        );
        break;
      case InteractiveZoneKind.bulletinBoard:
        await showBulletinBoardModal(context: context);
        break;
      case InteractiveZoneKind.studentLounge:
        final chosenRest = await showRestSpotActionModal(
          context: context,
          spotLabel: 'Student Study Lounge',
          currentState: _playerRestState,
          canSleepFlat: true,
        );
        if (chosenRest != null && mounted) {
          _setPlayerRestState(chosenRest);
        }
        break;
      case InteractiveZoneKind.reviewerTreasureArea:
        _triggerWave();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              '💎 Walk up to any of your ${LobbyDataService.instance.subjectChests.length} enrolled Subject Chest(s) to open Reviewer Links!',
            ),
            behavior: SnackBarBehavior.floating,
            duration: const Duration(seconds: 2),
          ),
        );
        break;
      case InteractiveZoneKind.vendingMachine:
        final pickedItem = await showCanteenVendingModal(context: context);
        if (pickedItem != null && mounted) {
          HapticFeedback.mediumImpact();
          final nowMs = DateTime.now().millisecondsSinceEpoch;
          setState(() {
            _playerThoughtText = pickedItem;
            _playerThoughtUntilMs = nowMs + 12000;
          });
          LobbyPresenceService.instance.updateLocalPlayerState(
            thoughtText: pickedItem,
            thoughtUntilMs: nowMs + 12000,
            forceImmediateBroadcast: true,
          );
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(pickedItem),
              behavior: SnackBarBehavior.floating,
              duration: const Duration(seconds: 2),
            ),
          );
        }
        break;
      case InteractiveZoneKind.classroomPodium:
        if (widget.session.isFaculty) {
          await showTeacherLinkManagerModal(
            context: context,
            teacherName: _playerNickname,
          );
        } else {
          await showCharacterProgressModal(
            context: context,
            playerName: _playerNickname,
            isFaculty: false,
          );
        }
        break;
    }
  }

  void _guideToDestination(Offset target, String destinationName) {
    HapticFeedback.selectionClick();
    final chests = LobbyDataService.instance.subjectChests;
    final solids = buildLobbySolids(chests, room: _currentRoom);
    final nav = LobbyNavGrid(
      cols: kLobbyCols,
      rows: kLobbyRows,
      solids: solids,
    );
    final path = nav.findPath(_playerPos, target);
    setState(() {
      _tapPulseTarget = target;
      _tapPulseProgress = 0.0;
      if (path.isNotEmpty) {
        _playerRestState = PlayerRestState.none;
        _activePath = path;
      }
    });
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          '🧭 Guiding you along the walk path to $destinationName...',
        ),
        behavior: SnackBarBehavior.floating,
        duration: const Duration(milliseconds: 1600),
      ),
    );
  }

  void _showGuidedWayfinderMenu() {
    final chests = LobbyDataService.instance.subjectChests;
    final zones = buildActiveInteractiveZones(chests, room: _currentRoom);
    // Filter to primary destinations (doors, quest counter, chests, podium, vending, lounge)
    final destinations = zones
        .where((z) => z.kind != InteractiveZoneKind.restSpot)
        .toList();

    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(ctx).size.height * 0.78,
        ),
        margin: const EdgeInsets.all(14),
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: const Color(0xFF0F172A),
          borderRadius: BorderRadius.circular(24),
          border: Border.all(
            color: const Color(0xFFFACC15).withOpacity(0.75),
            width: 1.6,
          ),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Text('🧭', style: TextStyle(fontSize: 22)),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Campus Walk-Path Wayfinder (${_currentRoom.shortLabel})',
                        style: GoogleFonts.outfit(
                          color: Colors.white,
                          fontSize: 16.5,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      Text(
                        'Tap any station below and follow the Golden Guide Trail!',
                        style: GoogleFonts.inter(
                          color: Colors.white70,
                          fontSize: 11.5,
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  onPressed: () => Navigator.of(ctx).pop(),
                  icon: const Icon(Icons.close_rounded, color: Colors.white70),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Flexible(
              child: ListView.separated(
                shrinkWrap: true,
                itemCount: destinations.length,
                separatorBuilder: (_, __) => const SizedBox(height: 8),
                itemBuilder: (context, idx) {
                  final z = destinations[idx];
                  final accent = Color(z.accentColor);
                  return ListTile(
                    dense: true,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                      side: BorderSide(color: accent.withOpacity(0.55)),
                    ),
                    tileColor: const Color(0xFF1E293B),
                    leading: Icon(Icons.near_me_rounded, color: accent),
                    title: Text(
                      z.label,
                      style: GoogleFonts.outfit(
                        color: Colors.white,
                        fontSize: 13.5,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    subtitle: Text(
                      z.subtitle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.inter(
                        color: Colors.white60,
                        fontSize: 11,
                      ),
                    ),
                    trailing: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 5),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFACC15).withOpacity(0.20),
                        borderRadius: BorderRadius.circular(99),
                        border: Border.all(color: const Color(0xFFFACC15)),
                      ),
                      child: const Text(
                        'Guide Me ➔',
                        style: TextStyle(
                          color: Color(0xFFFDE047),
                          fontSize: 10.5,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                    onTap: () {
                      Navigator.of(ctx).pop();
                      _guideToDestination(z.center, z.label);
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showRoomQuickTravelMenu() {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        margin: const EdgeInsets.all(14),
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: const Color(0xFF0F172A),
          borderRadius: BorderRadius.circular(24),
          border: Border.all(
            color: const Color(0xFF38BDF8).withOpacity(0.55),
            width: 1.5,
          ),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Text('🚪', style: TextStyle(fontSize: 22)),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Campus Doors & Room Directory',
                    style: GoogleFonts.outfit(
                      color: Colors.white,
                      fontSize: 17,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                IconButton(
                  onPressed: () => Navigator.of(ctx).pop(),
                  icon: const Icon(Icons.close_rounded, color: Colors.white70),
                ),
              ],
            ),
            const SizedBox(height: 8),
            ...LobbyRoomId.values.map((room) {
              final isCurrent = room == _currentRoom;
              final accent = Color(room.accentColor);
              return Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: ListTile(
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                    side: BorderSide(
                      color: isCurrent ? accent : Colors.white12,
                      width: isCurrent ? 1.8 : 1.0,
                    ),
                  ),
                  tileColor: isCurrent
                      ? accent.withOpacity(0.20)
                      : const Color(0xFF1E293B),
                  leading:
                      Text(room.iconEmoji, style: const TextStyle(fontSize: 22)),
                  title: Text(
                    room.title,
                    style: GoogleFonts.outfit(
                      color: Colors.white,
                      fontWeight: FontWeight.w700,
                      fontSize: 14.5,
                    ),
                  ),
                  trailing: isCurrent
                      ? Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: accent,
                            borderRadius: BorderRadius.circular(99),
                          ),
                          child: const Text(
                            'Current Room',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 10.5,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        )
                      : const Icon(Icons.arrow_forward_ios_rounded,
                          color: Colors.white54, size: 15),
                  onTap: () {
                    Navigator.of(ctx).pop();
                    if (!isCurrent) {
                      _enterRoom(room);
                    }
                  },
                ),
              );
            }),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final service = LobbyDataService.instance;
    final progress = service.progress;
    final equippedBadgeIcon = progress.equippedBadge?.badgeIcon;
    final screenSize = MediaQuery.sizeOf(context);
    final isLandscape = screenSize.width > screenSize.height;

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

    final nowMs = DateTime.now().millisecondsSinceEpoch;
    final smallChestRemainingSec = <String, int>{
      for (final z in INTERACTIVE_ZONES)
        if (z.kind == InteractiveZoneKind.smallMysteryChest)
          z.id: service.smallChestRemainingSeconds(z.id, nowMs),
    };

    return ListenableBuilder(
      listenable: Listenable.merge([
        ThemeController.instance,
        service,
        LobbyPresenceService.instance,
      ]),
      builder: (context, _) {
        final isDarkMode = ThemeController.instance.isDarkMode;
        final remotePlayersInRoom =
            LobbyPresenceService.instance.playersForRoom(_currentRoom);

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
                            'Loading MIS-SHS 2D Pixel School Campus...',
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
                        // 1. Full-Screen 2D Pixel Canvas
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
                                    currentRoom: _currentRoom,
                                    playerRestState: _playerRestState,
                                    playerThoughtText: _playerThoughtText,
                                    activePeerThoughts: _activePeerThoughts,
                                    remotePlayers: remotePlayersInRoom,
                                    showOfflineClassmates: _showOfflineBots,
                                  ),
                                ),
                              );
                            },
                          ),
                        ),

                        // 2. Top HUD Bar
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

                                        // 1-Tap Campus Room Switcher / Doors Directory
                                        _HudPillButton(
                                          icon: Icons.door_front_door_rounded,
                                          iconColor:
                                              Color(_currentRoom.accentColor),
                                          label:
                                              '${_currentRoom.iconEmoji} ${_currentRoom.shortLabel} ▾',
                                          borderColor:
                                              Color(_currentRoom.accentColor)
                                                  .withOpacity(0.75),
                                          onTap: _showRoomQuickTravelMenu,
                                        ),
                                        const SizedBox(width: 6),

                                        // Live Multiplayer Online Players Directory Pill (`🟢 X Online`)
                                        _HudPillButton(
                                          icon: Icons.people_alt_rounded,
                                          iconColor: const Color(0xFF34D399),
                                          label:
                                              '🟢 ${LobbyPresenceService.instance.totalOnlineCount} Online',
                                          borderColor: const Color(0xFF10B981)
                                              .withOpacity(0.78),
                                          onTap: () => showOnlinePlayersModal(
                                            context: context,
                                            selfNickname: _playerNickname,
                                            selfIsFaculty:
                                                widget.session.isFaculty,
                                            currentRoom: _currentRoom,
                                            showOfflineBots: _showOfflineBots,
                                            onToggleOfflineBots: (val) {
                                              setState(() {
                                                _showOfflineBots = val;
                                              });
                                            },
                                            onJoinAndGuideToPlayer: (rp) {
                                              if (rp.room != _currentRoom) {
                                                _enterRoom(rp.room);
                                              }
                                              Future.delayed(
                                                  const Duration(
                                                      milliseconds: 120), () {
                                                if (mounted) {
                                                  _guideToDestination(
                                                    rp.currentPos,
                                                    rp.nickname,
                                                  );
                                                }
                                              });
                                            },
                                          ),
                                        ),
                                        const SizedBox(width: 6),

                                        // 1-Tap Guided Walk-Path Wayfinder Button
                                        _HudPillButton(
                                          icon: Icons.explore_rounded,
                                          iconColor: const Color(0xFFFACC15),
                                          label: '🧭 Guide',
                                          borderColor: const Color(0xFFFACC15)
                                              .withOpacity(0.65),
                                          onTap: _showGuidedWayfinderMenu,
                                        ),
                                        const SizedBox(width: 6),

                                        // Thought Bubble Chat Quick Button
                                        _HudPillButton(
                                          icon: Icons.cloud_outlined,
                                          iconColor: const Color(0xFF38BDF8),
                                          label: '💭 Thought Chat',
                                          borderColor: const Color(0xFF38BDF8)
                                              .withOpacity(0.55),
                                          onTap: () =>
                                              _openThoughtBubbleModal(),
                                        ),
                                        const SizedBox(width: 6),

                                        // Level, Rank & XP Character Progress Pill
                                        _HudPillButton(
                                          icon: Icons.bolt_rounded,
                                          iconColor: const Color(0xFFFACC15),
                                          label:
                                              '${progress.rankEmoji} LVL ${progress.level} • ${progress.xp} XP',
                                          borderColor: const Color(0xFFFACC15)
                                              .withOpacity(0.5),
                                          onTap: () =>
                                              showCharacterProgressModal(
                                            context: context,
                                            playerName: _playerNickname,
                                            isFaculty: widget.session.isFaculty,
                                          ),
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

                                        // Teacher Quick "Manage Links" & "+ Post Activity" HUD Buttons
                                        if (widget.session.isFaculty) ...[
                                          _HudPillButton(
                                            icon: Icons.link_rounded,
                                            iconColor: const Color(0xFFFACC15),
                                            label: '🔗 Manage Links',
                                            borderColor:
                                                const Color(0xFFFACC15),
                                            onTap: () =>
                                                showTeacherLinkManagerModal(
                                              context: context,
                                              teacherName: _playerNickname,
                                            ),
                                          ),
                                          const SizedBox(width: 6),
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
                                currentRoom: _currentRoom,
                                remotePlayers: remotePlayersInRoom,
                                isCompact:
                                    !isLandscape && screenSize.width < 390,
                                onTapWorldPoint: (worldTarget) {
                                  final solids = buildLobbySolids(
                                    service.subjectChests,
                                    room: _currentRoom,
                                  );
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
                                      _playerRestState = PlayerRestState.none;
                                      _activePath = path;
                                    }
                                  });
                                },
                              ),
                            ),
                          ),

                        // 4. Bottom-Left Virtual Touch Joystick
                        Positioned(
                          left: isLandscape ? 20 : 12,
                          bottom: isLandscape ? 18 : 16,
                          child: SafeArea(
                            top: false,
                            child: Transform.scale(
                              scale: (!isLandscape && screenSize.width < 380)
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

                        // 5. Bottom-Right On-Screen "Interact" + Sit/Nap/Sleep + Thought Bubble Cluster
                        Positioned(
                          right: isLandscape ? 18 : 12,
                          bottom: isLandscape ? 18 : 16,
                          child: SafeArea(
                            top: false,
                            child: Transform.scale(
                              scale: (!isLandscape && screenSize.width < 380)
                                  ? 0.88
                                  : 1.0,
                              alignment: Alignment.bottomRight,
                              child: SchoolLobbyInteractCluster(
                                activeZone: _highlightedZone,
                                playerRestState: _playerRestState,
                                onInteract: _triggerInteract,
                                onWave: _triggerWave,
                                onThoughtBubble: () =>
                                    _openThoughtBubbleModal(),
                                onChangeRestState: (nextState) =>
                                    _setPlayerRestState(nextState),
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

class _LobbyMiniMapRadar extends StatelessWidget {
  final Offset playerPos;
  final List<SubjectChest> subjectChests;
  final LobbyRoomId currentRoom;
  final List<RemoteLobbyPlayer> remotePlayers;
  final bool isCompact;
  final ValueChanged<Offset> onTapWorldPoint;

  const _LobbyMiniMapRadar({
    required this.playerPos,
    required this.subjectChests,
    required this.currentRoom,
    required this.remotePlayers,
    required this.isCompact,
    required this.onTapWorldPoint,
  });

  @override
  Widget build(BuildContext context) {
    final mapW = isCompact ? 112.0 : 136.0;
    final mapH = mapW * (kLobbyWorldHeight / kLobbyWorldWidth);

    return GestureDetector(
      onTapDown: (d) {
        final wx = (d.localPosition.dx / mapW * kLobbyWorldWidth)
            .clamp(48.0, kLobbyWorldWidth - 48.0);
        final wy = (d.localPosition.dy / mapH * kLobbyWorldHeight)
            .clamp(96.0, kLobbyWorldHeight - 48.0);
        onTapWorldPoint(Offset(wx, wy));
      },
      child: Container(
        width: mapW,
        height: mapH,
        decoration: BoxDecoration(
          color: const Color(0xFF0F172A).withOpacity(0.86),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: Color(currentRoom.accentColor).withOpacity(0.65),
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
              currentRoom: currentRoom,
              remotePlayers: remotePlayers,
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
  final LobbyRoomId currentRoom;
  final List<RemoteLobbyPlayer> remotePlayers;

  const _MiniMapRadarPainter({
    required this.playerPos,
    required this.subjectChests,
    required this.currentRoom,
    required this.remotePlayers,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final sx = size.width / kLobbyWorldWidth;
    final sy = size.height / kLobbyWorldHeight;

    if (currentRoom == LobbyRoomId.mainLobby) {
      canvas.drawRect(
        Rect.fromLTWH(44 * sx, 92 * sy, 460 * sx, 190 * sy),
        Paint()..color = const Color(0xFF38BDF8).withOpacity(0.28),
      );
      canvas.drawRect(
        Rect.fromLTWH(620 * sx, 92 * sy, 296 * sx, 170 * sy),
        Paint()..color = const Color(0xFFF59E0B).withOpacity(0.32),
      );
      canvas.drawRect(
        Rect.fromLTWH(1060 * sx, 92 * sy, 420 * sx, 190 * sy),
        Paint()..color = const Color(0xFFFBBF24).withOpacity(0.28),
      );
      canvas.drawRect(
        Rect.fromLTWH(76 * sx, 430 * sy, 680 * sx, 560 * sy),
        Paint()..color = const Color(0xFF10B981).withOpacity(0.22),
      );
      canvas.drawRect(
        Rect.fromLTWH(880 * sx, 460 * sy, 580 * sx, 560 * sy),
        Paint()..color = const Color(0xFFA855F7).withOpacity(0.28),
      );

      for (var i = 0; i < subjectChests.length; i++) {
        final pos = subjectChestPosition(i);
        canvas.drawCircle(
          Offset(pos.dx * sx, pos.dy * sy),
          2.6,
          Paint()..color = Color(subjectChests[i].colorValue),
        );
      }
    } else {
      // Sub-room radar tint
      canvas.drawRect(
        Rect.fromLTWH(40 * sx, 90 * sy, (kLobbyWorldWidth - 80) * sx,
            (kLobbyWorldHeight - 130) * sy),
        Paint()..color = Color(currentRoom.accentColor).withOpacity(0.22),
      );
    }

    // Draw guided walk paths on the Mini-Map Radar
    for (final seg in walkPathsForRoom(currentRoom)) {
      canvas.drawRect(
        Rect.fromLTWH(
          seg.rect.left * sx,
          seg.rect.top * sy,
          seg.rect.width * sx,
          seg.rect.height * sy,
        ),
        Paint()..color = const Color(0xFFFACC15).withOpacity(0.28),
      );
    }

    // Live Remote Players glowing green/gold dots on Mini-Map Radar
    for (final rp in remotePlayers) {
      final rpx = (rp.currentPos.dx * sx).clamp(4.0, size.width - 4.0);
      final rpy = (rp.currentPos.dy * sy).clamp(4.0, size.height - 4.0);
      final dotColor =
          rp.isFaculty ? const Color(0xFFFACC15) : const Color(0xFF34D399);
      canvas.drawCircle(
        Offset(rpx, rpy),
        4.6,
        Paint()..color = dotColor.withOpacity(0.45),
      );
      canvas.drawCircle(
        Offset(rpx, rpy),
        2.5,
        Paint()..color = dotColor,
      );
    }

    // Player glowing dot
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
      oldDelegate.currentRoom != currentRoom ||
      oldDelegate.subjectChests.length != subjectChests.length ||
      oldDelegate.remotePlayers.length != remotePlayers.length;
}
