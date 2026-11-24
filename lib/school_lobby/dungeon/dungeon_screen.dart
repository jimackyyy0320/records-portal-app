import 'dart:async';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart';

import '../../models/portal_models.dart';
import '../lobby_data_service.dart';
import '../school_lobby_avatar.dart';
import '../sovereign_story_data.dart';
import '../spritecast_engine.dart';
import 'dungeon_audio.dart';
import 'dungeon_combat.dart';
import 'dungeon_enemies.dart';
import 'dungeon_enemy_sprites.dart';
import 'dungeon_hud_and_menus.dart';
import 'dungeon_maps.dart';
import 'dungeon_models.dart';
import 'dungeon_physics.dart';
import 'dungeon_pixelfx_vfx.dart';
import 'dungeon_renderer.dart';

enum _DungeonShellMode {
  title,
  playing,
  benchModal,
  mapOverlay,
  paused,
  loreModal,
  defeated,
  altarVictory,
}

class _NearbyInteraction {
  final String kind; // 'bench' | 'portal' | 'chest' | 'lore'
  final String label;
  final int col;
  final int row;
  final DungeonRoomExit? exit;
  final String? refId;

  const _NearbyInteraction({
    required this.kind,
    required this.label,
    required this.col,
    required this.row,
    this.exit,
    this.refId,
  });
}

/// Complete Playable Silksong × Terraria 2D Action-Platformer Story Mode Shell!
///
/// Renders each student's custom **School Lobby character** (`playerLook`) with
/// dungeon-only cape, armor pauldron, and forged weapon (never shown in Virtual School),
/// across all 7 Historical Acts (35 interconnected chambers), 14+ enemy archetypes,
/// Rival Mateo duels, 7 multi-phase Era Bosses, Bahay-Pulungan Bench crafting,
/// Cartographer Fog-of-War Map, ergonomic mobile touch controls, keyboard controls,
/// and Google Sheets cloud save integration.
class SovereignDungeonScreen extends StatefulWidget {
  final UserSession session;
  final String playerNickname;
  final LobbyAvatarLook? playerLook;
  final bool startDirectlyInDungeon;

  const SovereignDungeonScreen({
    super.key,
    required this.session,
    required this.playerNickname,
    this.playerLook,
    this.startDirectlyInDungeon = false,
  });

  @override
  State<SovereignDungeonScreen> createState() => _SovereignDungeonScreenState();
}

class _SovereignDungeonScreenState extends State<SovereignDungeonScreen>
    with SingleTickerProviderStateMixin {
  final FocusNode _focusNode = FocusNode();
  late final Ticker _ticker;
  Duration _lastTick = Duration.zero;
  double _worldTimeSec = 0.0;

  // Core Engine Modules
  final DungeonPhysicsEngine _physics = DungeonPhysicsEngine();
  final DungeonCombatEngine _combat = DungeonCombatEngine();
  final DungeonEnemyManager _enemyManager = DungeonEnemyManager();
  final DungeonCameraRig _camera = DungeonCameraRig();
  final DungeonPixelfxVfxManager _pixelfxVfx = DungeonPixelfxVfxManager();
  final List<DungeonParticle> _particles = <DungeonParticle>[];
  final math.Random _rng = math.Random(1898);

  // Campaign & Live World State
  _DungeonShellMode _shellMode = _DungeonShellMode.title;
  SovereignCampaignSave _campaignSave = const SovereignCampaignSave();
  DungeonProgressSave _progress = const DungeonProgressSave();
  late DungeonChamberRuntime _chamber;
  late DungeonPlayerPhysicsState _player;

  // Custom Student School Lobby Character Sheet (dungeon-only gear composited on top!)
  LobbyAvatarLook _playerLook = const LobbyAvatarLook();
  ui.Image? _playerAvatarSheet;

  // Context UI State
  _NearbyInteraction? _nearbyInteract;
  Offset? _highlightedGrapple;
  DungeonLoreTabletSpec? _activeLoreTablet;
  String? _toastMessage;
  double _toastTimer = 0.0;

  // Cinematic Silksong-Style Boss Arena Intro Title Banner State
  static const double _kBossIntroDuration = 2.2;
  String? _bossIntroEraTag;
  String? _bossIntroTitle;
  String? _bossIntroSubtitle;
  double _bossIntroTimer = 0.0;

  // Unified Keyboard + Mobile Touch Input State
  final Set<LogicalKeyboardKey> _heldKeys = <LogicalKeyboardKey>{};
  double _touchMoveX = 0.0;
  double _touchMoveY = 0.0;
  bool _touchJumpHeld = false;
  bool _touchBindHeld = false;

  // One-shot buffered edge inputs consumed on next simulation frame
  bool _queuedJumpPress = false;
  bool _queuedJumpRelease = false;
  bool _queuedDashPress = false;
  bool _queuedSlashPress = false;
  bool _queuedSkillPress = false;
  bool _queuedGrapplePress = false;
  bool _queuedInteractPress = false;

  @override
  void initState() {
    super.initState();
    _shellMode = widget.startDirectlyInDungeon
        ? _DungeonShellMode.playing
        : _DungeonShellMode.title;
    _playerLook = widget.playerLook ?? const LobbyAvatarLook();

    // Initialize default Act I chamber immediately so first frame never stalls
    _loadChamber(
      chamberId: _progress.checkpointChamberId,
      spawnCol: _progress.checkpointCol,
      spawnRow: _progress.checkpointRow,
      restoreFullVitals: true,
    );

    _ticker = createTicker(_onTick)..start();
    _bootstrapAsyncState();
  }

  Future<void> _bootstrapAsyncState() async {
    // 1. Load persisted Story Mode & Dungeon Save
    final loadedCampaign = await SovereignCampaignSave.load(widget.session.id);
    if (!mounted) return;
    _campaignSave = loadedCampaign;
    _progress = loadedCampaign.dungeonProgress;

    // 2. Preload `pixelfx` sprite sheets & student's custom School Lobby character sprite sheet
    try {
      await DungeonPixelfxSheetCache.instance.preloadAll();
    } catch (_) {}
    try {
      final look = widget.playerLook ??
          await AvatarSpriteCache.instance.loadSavedLook(
            widget.session.id,
            isFaculty: widget.session.isFaculty,
          );
      final sheet = await AvatarSpriteCache.instance.resolveLookSpriteSheet(look);
      if (mounted) {
        setState(() {
          _playerLook = look;
          _playerAvatarSheet = sheet;
        });
      }
    } catch (_) {
      // Headless unit tests or missing asset bundles cleanly fall back to procedural hero
    }

    if (!mounted) return;
    setState(() {
      _loadChamber(
        chamberId: _progress.checkpointChamberId,
        spawnCol: _progress.checkpointCol,
        spawnRow: _progress.checkpointRow,
        restoreFullVitals: true,
      );
    });
  }

  @override
  void dispose() {
    _ticker.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  // ═══════════════════════════════════════════════════════════════════════════
  //  CHAMBER LOADING, TRANSITIONS & SAVE PERSISTENCE
  // ═══════════════════════════════════════════════════════════════════════════

  void _loadChamber({
    required String chamberId,
    required int spawnCol,
    required int spawnRow,
    bool restoreFullVitals = false,
  }) {
    final spec = lookupDungeonChamber(chamberId);
    _chamber = DungeonChamberRuntime(spec);

    // Restore already-unlocked switches/gates & broken secret walls from save!
    if (_progress.unlockedGateChamberIds.contains(spec.id)) {
      _chamber.roomGateUnlocked = true;
    }
    for (final secretKey in _progress.brokenSecretKeys) {
      if (secretKey.startsWith('${spec.id}:')) {
        final coordKey = secretKey.substring(spec.id.length + 1);
        final br = _chamber.breakables[coordKey];
        if (br != null) {
          br.hp = 0;
          br.brokenOrTriggered = true;
        }
      }
    }

    final maxResolve = _progress.effectiveMaxResolveMasks;
    final maxSilk = _progress.effectiveMaxSilk;
    final prevHp = restoreFullVitals
        ? maxResolve
        : ((_shellMode == _DungeonShellMode.playing)
            ? _player.resolveHp.clamp(1, maxResolve)
            : maxResolve);
    final prevSilk = restoreFullVitals
        ? maxSilk * 0.5
        : _player.civicSilk.clamp(0.0, maxSilk);

    _player = DungeonPlayerPhysicsState(
      x: spawnCol * kDungeonTileSize + 2.0,
      y: (spawnRow + 1) * kDungeonTileSize - 15.0,
      facing: 1,
      isGrounded: true,
      resolveHp: prevHp,
      maxResolveHp: maxResolve,
      civicSilk: prevSilk,
      maxCivicSilk: maxSilk,
    );

    _combat.resetRoomCombat();
    _particles.clear();
    _pixelfxVfx.clear();

    final bossAlreadyDefeated =
        spec.bossId != null && _progress.defeatedBossIds.contains(spec.bossId);
    _enemyManager.spawnForChamber(
      spec,
      bossAlreadyDefeated: bossAlreadyDefeated,
      defeatedIds: _progress.defeatedBossIds,
    );
    _camera.snapTo(_player, spec);

    // Trigger Silksong-style Boss Arena Intro Title Banner on undefeated Boss / Rival chamber!
    final liveBoss = _enemyManager.activeBoss;
    if (liveBoss != null) {
      final act = actSpecForNumber(spec.actNumber);
      _bossIntroEraTag = liveBoss.archetype.isRival
          ? 'RIVAL DUEL • ${act.eraYearLabel.toUpperCase()}'
          : 'ACT ${act.actNumber} ERA BOSS • ${act.eraYearLabel.toUpperCase()}';
      _bossIntroTitle = liveBoss.archetype.displayName.toUpperCase();
      _bossIntroSubtitle = liveBoss.archetype.subtitle.toUpperCase();
      _bossIntroTimer = _kBossIntroDuration;
    } else {
      _bossIntroTimer = 0.0;
      _bossIntroTitle = null;
      _bossIntroSubtitle = null;
      _bossIntroEraTag = null;
    }

    if (!_progress.discoveredChamberIds.contains(spec.id)) {
      _progress = _progress.copyWith(
        discoveredChamberIds: <String>{..._progress.discoveredChamberIds, spec.id},
      );
      unawaited(_persistProgress());
    }
  }

  Future<void> _persistProgress() async {
    final highestAct = _progress.discoveredChamberIds.fold<int>(
      _campaignSave.currentActNumber,
      (acc, cid) => math.max(acc, lookupDungeonChamber(cid).actNumber),
    );
    _campaignSave = _campaignSave.copyWith(
      currentActNumber: highestAct,
      defeatedEntityIds: <String>{
        ..._campaignSave.defeatedEntityIds,
        ..._progress.defeatedBossIds,
      },
      completedAltarEnding: _campaignSave.completedAltarEnding ||
          _progress.defeatedBossIds.contains('boss_sovereign_guardian'),
      dungeonProgress: _progress,
    );
    await _campaignSave.persist(widget.session.id);
    // Sync XP & bundled SovereignCampaignSave (including dungeonProgress) to cloud!
    try {
      await LobbyDataService.instance.awardDungeonXp(0);
    } catch (_) {}
  }

  void _showToast(String msg, {double duration = 2.4}) {
    _toastMessage = msg;
    _toastTimer = duration;
  }

  // ═══════════════════════════════════════════════════════════════════════════
  //  60 FPS FIXED-TIMESTEP GAME LOOP
  // ═══════════════════════════════════════════════════════════════════════════

  void _onTick(Duration elapsed) {
    if (_lastTick == Duration.zero) {
      _lastTick = elapsed;
      return;
    }
    final rawDt = ((elapsed - _lastTick).inMicroseconds / 1000000.0).clamp(0.0, 0.05);
    _lastTick = elapsed;

    if (_shellMode != _DungeonShellMode.playing) return;

    _worldTimeSec += rawDt;
    if (_toastTimer > 0.0) {
      _toastTimer = math.max(0.0, _toastTimer - rawDt);
      if (_toastTimer <= 0.0) _toastMessage = null;
    }
    if (_bossIntroTimer > 0.0) {
      _bossIntroTimer = math.max(0.0, _bossIntroTimer - rawDt);
      if (_bossIntroTimer <= 0.0) _bossIntroTitle = null;
    }

    // 1. Sample unified Keyboard + Mobile Touch Input
    final input = _consumeCurrentFrameInput();

    // 2. Apply Hit-Stop freeze scale (dramatic Silksong impact freeze!)
    final simDt = _combat.hitStop.applyToDt(rawDt);

    // 3. Step Fixed-Timestep 2D Platformer Physics
    final physEvents = _physics.step(
      dt: simDt,
      player: _player,
      chamber: _chamber,
      input: input,
      hasDoubleJumpCharm: _progress.hasCharmEquipped('double_pogo_boots'),
      hasMagnetCharm: _progress.hasCharmEquipped('magnet_shard'),
      hasStalwartWardCharm: _progress.hasCharmEquipped('charter_ward'),
    );
    _handlePhysicsEvents(physEvents);

    // 4. Step 4-Way Combat, Silk Skills, Projectiles & Breakables
    final combatEvents = _combat.step(
      dt: simDt,
      player: _player,
      chamber: _chamber,
      input: input,
      progress: _progress,
      physicsEngine: _physics,
      targets: _enemyManager.aliveCombatTargets,
    );

    // 5. Step All 14 Enemy Archetypes, Rival Mateo & 7 Multi-Phase Era Bosses
    final enemyEvents = _enemyManager.step(
      dt: simDt,
      player: _player,
      chamber: _chamber,
      combat: _combat,
      progress: _progress,
      combatEventsOut: combatEvents,
    );
    _handleCombatEvents(combatEvents);
    _handleEnemyEvents(enemyEvents);

    // 6. Update Grapple Highlight, Nearby Interactable Prompt, Particles & Camera
    _highlightedGrapple = _physics.findBestGrappleAnchor(_player, _chamber, input);
    _nearbyInteract = _detectNearbyInteraction();
    if (input.interactJustPressed && _nearbyInteract != null) {
      _executeInteraction(_nearbyInteract!);
    }

    _stepParticles(rawDt);
    _pixelfxVfx.step(rawDt);
    _camera.update(dt: rawDt, player: _player, spec: _chamber.spec);

    // 7. Check Player Defeat -> Respawn at Sanctuary Bench screen
    if (_player.resolveHp <= 0 && _shellMode == _DungeonShellMode.playing) {
      DungeonAudioService.instance.play(DungeonSfxCue.playerHurt);
      _shellMode = _DungeonShellMode.defeated;
    }

    if (mounted) {
      setState(() {});
    }
  }

  DungeonPlayerInput _consumeCurrentFrameInput() {
    var mx = _touchMoveX;
    var my = _touchMoveY;
    if (_heldKeys.contains(LogicalKeyboardKey.keyA) ||
        _heldKeys.contains(LogicalKeyboardKey.arrowLeft)) {
      mx = -1.0;
    } else if (_heldKeys.contains(LogicalKeyboardKey.keyD) ||
        _heldKeys.contains(LogicalKeyboardKey.arrowRight)) {
      mx = 1.0;
    }
    if (_heldKeys.contains(LogicalKeyboardKey.keyW) ||
        _heldKeys.contains(LogicalKeyboardKey.arrowUp)) {
      my = -1.0;
    } else if (_heldKeys.contains(LogicalKeyboardKey.keyS) ||
        _heldKeys.contains(LogicalKeyboardKey.arrowDown)) {
      my = 1.0;
    }

    final jumpHeld = _touchJumpHeld ||
        _heldKeys.contains(LogicalKeyboardKey.space) ||
        _heldKeys.contains(LogicalKeyboardKey.keyZ);
    final healHeld = _touchBindHeld ||
        _heldKeys.contains(LogicalKeyboardKey.keyH) ||
        _heldKeys.contains(LogicalKeyboardKey.keyQ);

    final snapshot = DungeonPlayerInput(
      moveX: mx,
      moveY: my,
      jumpHeld: jumpHeld,
      jumpJustPressed: _queuedJumpPress,
      jumpJustReleased: _queuedJumpRelease,
      dashJustPressed: _queuedDashPress,
      slashJustPressed: _queuedSlashPress,
      skillJustPressed: _queuedSkillPress,
      grappleJustPressed: _queuedGrapplePress,
      healHeld: healHeld,
      interactJustPressed: _queuedInteractPress,
    );

    _queuedJumpPress = false;
    _queuedJumpRelease = false;
    _queuedDashPress = false;
    _queuedSlashPress = false;
    _queuedSkillPress = false;
    _queuedGrapplePress = false;
    _queuedInteractPress = false;
    return snapshot;
  }

  // ═══════════════════════════════════════════════════════════════════════════
  //  EVENT HANDLERS (SFX, PARTICLES, LOOT, BOSS SEALS & CLOUD REWARDS)
  // ═══════════════════════════════════════════════════════════════════════════

  void _handlePhysicsEvents(List<DungeonPhysicsEvent> events) {
    for (final ev in events) {
      switch (ev.kind) {
        case DungeonPhysicsEventKind.jumped:
        case DungeonPhysicsEventKind.doubleJumped:
          DungeonAudioService.instance.play(DungeonSfxCue.jump);
          _emitBurst(ev.x, ev.y, SpriteCastPalette.endesga32[2], count: 5);
          break;
        case DungeonPhysicsEventKind.wallJumped:
          DungeonAudioService.instance.play(DungeonSfxCue.wallJump);
          _emitBurst(ev.x, ev.y, SpriteCastPalette.endesga32[20], count: 6);
          break;
        case DungeonPhysicsEventKind.landed:
          DungeonAudioService.instance.play(DungeonSfxCue.land);
          _emitBurst(ev.x, ev.y, SpriteCastPalette.endesga32[2], count: 4);
          _pixelfxVfx.spawnFloorShockwave(
            x: ev.x,
            groundY: ev.y,
            color: SpriteCastPalette.endesga32[2],
            maxRadiusX: 14.0,
          );
          break;
        case DungeonPhysicsEventKind.dashed:
          DungeonAudioService.instance.play(DungeonSfxCue.silkDash);
          _emitBurst(ev.x, ev.y, SpriteCastPalette.endesga32[18], count: 8);
          break;
        case DungeonPhysicsEventKind.pogoBounced:
          DungeonAudioService.instance.play(DungeonSfxCue.pogoBounce);
          _emitBurst(ev.x, ev.y, SpriteCastPalette.endesga32[11], count: 7);
          _pixelfxVfx.spawnFloorShockwave(
            x: ev.x,
            groundY: ev.y,
            color: SpriteCastPalette.endesga32[11],
            maxRadiusX: 20.0,
          );
          break;
        case DungeonPhysicsEventKind.grappleStarted:
          DungeonAudioService.instance.play(DungeonSfxCue.grappleZip);
          break;
        case DungeonPhysicsEventKind.grappleReleased:
          break;
        case DungeonPhysicsEventKind.hazardHit:
          DungeonAudioService.instance.play(DungeonSfxCue.playerHurt);
          _camera.addShake(4.2);
          _emitBurst(ev.x, ev.y, SpriteCastPalette.endesga32[8], count: 9);
          break;
        case DungeonPhysicsEventKind.crumbleCollapsed:
          DungeonAudioService.instance.play(DungeonSfxCue.crateShatter);
          _emitBurst(ev.x, ev.y, SpriteCastPalette.woodMid, count: 6);
          break;
        case DungeonPhysicsEventKind.lootCollected:
          DungeonAudioService.instance.play(DungeonSfxCue.lootPickup);
          Color burstColor = SpriteCastPalette.endesga32[11];
          if (ev.lootKind == DungeonLootKind.archipelagoShard && ev.amount > 0) {
            _progress = _progress.copyWith(
              archipelagoShards: _progress.archipelagoShards + ev.amount,
            );
          } else if (ev.lootKind == DungeonLootKind.resolveOrb) {
            burstColor = SpriteCastPalette.endesga32[12];
            _combat.floatingNumbers.add(
              FloatingCombatNumber(
                text: '+${math.max(1, ev.amount)} HP',
                color: burstColor,
                x: ev.x,
                y: ev.y - 6.0,
              ),
            );
          } else if (ev.lootKind == DungeonLootKind.silkMote) {
            burstColor = SpriteCastPalette.endesga32[18];
            _combat.floatingNumbers.add(
              FloatingCombatNumber(
                text: '+${ev.amount} SILK',
                color: burstColor,
                x: ev.x,
                y: ev.y - 6.0,
              ),
            );
          }
          _emitBurst(ev.x, ev.y, burstColor, count: 6);
          _pixelfxVfx.spawnPickupSparkle(x: ev.x, y: ev.y, color: burstColor);
          break;
      }
    }
  }

  void _handleCombatEvents(List<DungeonCombatEvent> events) {
    for (final ev in events) {
      if (ev.shakeIntensity > 0.0) _camera.addShake(ev.shakeIntensity);
      switch (ev.kind) {
        case DungeonCombatEventKind.slashSwung:
          DungeonAudioService.instance.play(
            ev.value >= 2 ? DungeonSfxCue.slashFinisher : DungeonSfxCue.slashLight,
          );
          if (ev.value >= 2) {
            _pixelfxVfx.spawnSlashArc(
              x: ev.x,
              y: ev.y,
              facing: _player.facing,
              isFinisher: true,
              glowColor: _progress.bladeTier.slashArcColor,
            );
          }
          break;
        case DungeonCombatEventKind.enemyHit:
          DungeonAudioService.instance.play(DungeonSfxCue.enemyHit);
          _emitBurst(ev.x, ev.y, SpriteCastPalette.endesga32[11], count: 7);
          _pixelfxVfx.spawnHitImpact(
            x: ev.x,
            y: ev.y,
            color: _progress.bladeTier.slashArcColor,
            isCritOrKill: ev.value >= 26,
          );
          break;
        case DungeonCombatEventKind.enemyBlockedByShield:
          DungeonAudioService.instance.play(DungeonSfxCue.shieldClang);
          _emitBurst(ev.x, ev.y, SpriteCastPalette.endesga32[20], count: 6);
          _pixelfxVfx.spawnHitImpact(
            x: ev.x,
            y: ev.y,
            color: SpriteCastPalette.endesga32[20],
          );
          break;
        case DungeonCombatEventKind.enemyDefeated:
          DungeonAudioService.instance.play(DungeonSfxCue.enemyHit);
          _emitBurst(ev.x, ev.y, SpriteCastPalette.endesga32[9], count: 12);
          _pixelfxVfx.spawnHitImpact(
            x: ev.x,
            y: ev.y,
            color: SpriteCastPalette.endesga32[11],
            isCritOrKill: true,
          );
          _pixelfxVfx.spawnDebrisShatter(
            x: ev.x,
            y: ev.y,
            color: SpriteCastPalette.endesga32[9],
            shadeColor: SpriteCastPalette.endesga32[7],
            count: 7,
          );
          break;
        case DungeonCombatEventKind.skillCast:
          DungeonAudioService.instance.play(DungeonSfxCue.skillCast);
          _emitBurst(ev.x, ev.y, SpriteCastPalette.endesga32[18], count: 10);
          _pixelfxVfx.spawnFloorShockwave(
            x: ev.x,
            groundY: _player.bottom,
            color: SpriteCastPalette.endesga32[18],
            maxRadiusX: 34.0,
          );
          break;
        case DungeonCombatEventKind.parrySuccess:
          DungeonAudioService.instance.play(DungeonSfxCue.parryGoldenClang);
          HapticFeedback.heavyImpact();
          _emitBurst(ev.x, ev.y, SpriteCastPalette.endesga32[11], count: 14);
          _pixelfxVfx.spawnGoldenParry(
            x: ev.x,
            y: ev.y,
            groundY: _player.bottom,
          );
          break;
        case DungeonCombatEventKind.bindStarted:
          _emitBurst(ev.x, ev.y, SpriteCastPalette.endesga32[12], count: 5);
          break;
        case DungeonCombatEventKind.bindCompleted:
          DungeonAudioService.instance.play(DungeonSfxCue.silkBindHeal);
          _emitBurst(ev.x, ev.y, SpriteCastPalette.endesga32[12], count: 12);
          _pixelfxVfx.spawnFloorShockwave(
            x: ev.x,
            groundY: _player.bottom,
            color: SpriteCastPalette.endesga32[12],
            maxRadiusX: 28.0,
          );
          break;
        case DungeonCombatEventKind.bindInterrupted:
          break;
        case DungeonCombatEventKind.projectileDeflected:
          DungeonAudioService.instance.play(DungeonSfxCue.projectileDeflect);
          _emitBurst(ev.x, ev.y, SpriteCastPalette.endesga32[18], count: 8);
          _pixelfxVfx.spawnGoldenParry(x: ev.x, y: ev.y);
          break;
        case DungeonCombatEventKind.playerDamaged:
          DungeonAudioService.instance.play(DungeonSfxCue.playerHurt);
          HapticFeedback.mediumImpact();
          _emitBurst(ev.x, ev.y, SpriteCastPalette.endesga32[8], count: 10);
          _pixelfxVfx.spawnHitImpact(
            x: ev.x,
            y: ev.y,
            color: SpriteCastPalette.endesga32[8],
            isCritOrKill: true,
          );
          break;
        case DungeonCombatEventKind.crateBroken:
          DungeonAudioService.instance.play(DungeonSfxCue.crateShatter);
          _emitBurst(ev.x, ev.y, SpriteCastPalette.woodLight, count: 8);
          _pixelfxVfx.spawnDebrisShatter(
            x: ev.x,
            y: ev.y,
            color: SpriteCastPalette.woodLight,
            shadeColor: SpriteCastPalette.woodDark,
            count: 9,
          );
          break;
        case DungeonCombatEventKind.crystalMined:
          DungeonAudioService.instance.play(DungeonSfxCue.crystalMine);
          _emitBurst(ev.x, ev.y, SpriteCastPalette.endesga32[18], count: 8);
          _pixelfxVfx.spawnDebrisShatter(
            x: ev.x,
            y: ev.y,
            color: SpriteCastPalette.endesga32[18],
            shadeColor: SpriteCastPalette.endesga32[16],
            count: 8,
          );
          break;
        case DungeonCombatEventKind.secretWallBroken:
          if (ev.value > 0) {
            DungeonAudioService.instance.play(DungeonSfxCue.secretDiscovered);
            _emitBurst(ev.x, ev.y, SpriteCastPalette.endesga32[11], count: 14);
            _pixelfxVfx.spawnHitImpact(
              x: ev.x,
              y: ev.y,
              color: SpriteCastPalette.endesga32[11],
              isCritOrKill: true,
            );
            _pixelfxVfx.spawnDebrisShatter(
              x: ev.x,
              y: ev.y,
              color: SpriteCastPalette.endesga32[22],
              shadeColor: SpriteCastPalette.endesga32[24],
              count: 12,
            );
            _showToast('SECRET PASSAGE DISCOVERED!');
          }
          if (ev.tileKey != null) {
            // `dungeon_combat.dart` already formats `tileKey` as `${chamber.spec.id}:col_row`
            final normalizedKey = ev.tileKey!.contains(':')
                ? ev.tileKey!
                : '${_chamber.spec.id}:${ev.tileKey}';
            _progress = _progress.copyWith(
              brokenSecretKeys: <String>{
                ..._progress.brokenSecretKeys,
                normalizedKey,
              },
            );
            if (ev.value > 0) {
              unawaited(_persistProgress());
            }
          }
          break;
        case DungeonCombatEventKind.gateUnlocked:
          DungeonAudioService.instance.play(DungeonSfxCue.gateUnlock);
          _showToast('CHARTER GATE UNLOCKED!');
          _progress = _progress.copyWith(
            unlockedGateChamberIds: <String>{
              ..._progress.unlockedGateChamberIds,
              _chamber.spec.id,
            },
          );
          unawaited(_persistProgress());
          break;
        case DungeonCombatEventKind.pogoLanternStruck:
          DungeonAudioService.instance.play(DungeonSfxCue.pogoBounce);
          _emitBurst(ev.x, ev.y, SpriteCastPalette.endesga32[11], count: 7);
          break;
      }
    }
  }

  void _handleEnemyEvents(List<DungeonEnemyEvent> events) {
    for (final ev in events) {
      if (ev.sfx != null) DungeonAudioService.instance.play(ev.sfx!);
      if (ev.shakeIntensity > 0.0) _camera.addShake(ev.shakeIntensity);

      if (ev.kind == DungeonEnemyEventKind.enemyAttacked &&
          ev.shakeIntensity >= 2.2) {
        _pixelfxVfx.spawnFloorShockwave(
          x: ev.x,
          groundY: ev.y + 8.0,
          color: SpriteCastPalette.endesga32[9],
          maxRadiusX: 38.0,
        );
      } else if (ev.kind == DungeonEnemyEventKind.bossPhaseChanged &&
          ev.message != null) {
        _showToast(ev.message!, duration: 2.2);
        _emitBurst(ev.x, ev.y, SpriteCastPalette.endesga32[9], count: 16);
        _pixelfxVfx.spawnHitImpact(
          x: ev.x,
          y: ev.y,
          color: SpriteCastPalette.endesga32[9],
          isCritOrKill: true,
        );
        _pixelfxVfx.spawnFloorShockwave(
          x: ev.x,
          groundY: ev.y + 12.0,
          color: SpriteCastPalette.endesga32[11],
          maxRadiusX: 48.0,
        );
      } else if (ev.kind == DungeonEnemyEventKind.bossStaggered) {
        _showToast('STAGGERED! TAP THE CONSTITUTIONAL COUNTER-BREAK!', duration: 3.4);
        _emitBurst(ev.x, ev.y, SpriteCastPalette.endesga32[11], count: 16);
        _pixelfxVfx.spawnGoldenParry(x: ev.x, y: ev.y, groundY: ev.y + 12.0);
      } else if (ev.kind == DungeonEnemyEventKind.counterBreakSucceeded) {
        _pixelfxVfx.spawnHitImpact(
          x: ev.x,
          y: ev.y,
          color: SpriteCastPalette.endesga32[11],
          isCritOrKill: true,
        );
        _pixelfxVfx.spawnFloorShockwave(
          x: ev.x,
          groundY: ev.y + 12.0,
          color: SpriteCastPalette.endesga32[18],
          maxRadiusX: 52.0,
        );
      } else if (ev.kind == DungeonEnemyEventKind.bossDefeated) {
        _emitBurst(ev.x, ev.y, SpriteCastPalette.endesga32[11], count: 24);
        _pixelfxVfx.spawnGoldenParry(x: ev.x, y: ev.y, groundY: ev.y + 12.0);
        _pixelfxVfx.spawnDebrisShatter(
          x: ev.x,
          y: ev.y,
          color: SpriteCastPalette.endesga32[11],
          shadeColor: SpriteCastPalette.endesga32[10],
          count: 14,
        );
        unawaited(_onBossVanquished(ev));
      }
    }
  }

  Future<void> _onBossVanquished(DungeonEnemyEvent ev) async {
    final bossId = ev.archetypeId;
    final act = actSpecForNumber(_chamber.spec.actNumber);
    final isActEraBoss = act.bossId == bossId;

    // Rival Mateo encounters track defeat by spawn entityId (`a2_c4_rival_mateo`, `a5_c4_mateo_bunker`)
    // so defeating Mateo in Act II neither awards Act II's Charter Seal prematurely nor skips his Act V rematch!
    if (!isActEraBoss) {
      final nextDefeated = <String>{..._progress.defeatedBossIds, ev.entityId};
      _progress = _progress.copyWith(defeatedBossIds: nextDefeated);
      await _persistProgress();
      try {
        await LobbyDataService.instance.awardDungeonXp(95);
      } catch (_) {}
      if (!mounted) return;
      setState(() {
        _showToast('RIVAL MATEO BESTED! +95 PORTAL XP!', duration: 3.4);
      });
      return;
    }

    final nextSkills = Set<DungeonSilkSkillId>.from(_progress.unlockedSkills);
    String skillBanner = '';
    if (act.unlockedSkillOnClear != null) {
      if (nextSkills.add(act.unlockedSkillOnClear!)) {
        skillBanner =
            ' • UNLOCKED ${silkSkillSpecFor(act.unlockedSkillOnClear!).name.toUpperCase()}!';
      }
    }

    final nextDefeated = <String>{..._progress.defeatedBossIds, bossId};
    _progress = _progress.copyWith(
      defeatedBossIds: nextDefeated,
      unlockedSkills: nextSkills,
    );
    await _persistProgress();

    // Award Charter Seal Portal XP & Badge!
    final totalEraSeals = kDungeonActWorlds
        .where((a) => nextDefeated.contains(a.bossId))
        .length;
    final clearedFinalBoss = bossId == 'boss_sovereign_guardian';

    try {
      await LobbyDataService.instance.awardSovereignCharterSealReward(
        sealId: 'act${act.actNumber}_seal',
        sealName: act.charterSealName,
        sealIcon: clearedFinalBoss ? '👑' : '⚖️',
        sealColor: 0xFFFEAE34,
        totalSealsEarned: totalEraSeals,
        completedAllSevenAltar: clearedFinalBoss,
      );
    } catch (_) {}

    if (!mounted) return;
    setState(() {
      _showToast('${act.charterSealName.toUpperCase()} EARNED!$skillBanner', duration: 3.8);
      if (clearedFinalBoss) {
        _shellMode = _DungeonShellMode.altarVictory;
      }
    });
  }

  void _emitBurst(double x, double y, Color color, {int count = 6}) {
    if (_particles.length > 90) {
      _particles.removeRange(0, math.min(count, _particles.length));
    }
    for (var i = 0; i < count; i++) {
      final angle = _rng.nextDouble() * math.pi * 2.0;
      final spd = 28.0 + _rng.nextDouble() * 88.0;
      _particles.add(
        DungeonParticle(
          x: x,
          y: y,
          vx: math.cos(angle) * spd,
          vy: math.sin(angle) * spd - 24.0,
          size: 1.8 + _rng.nextDouble() * 1.8,
          color: color,
          lifeSec: 0.25 + _rng.nextDouble() * 0.28,
        ),
      );
    }
  }

  void _stepParticles(double dt) {
    for (var i = _particles.length - 1; i >= 0; i--) {
      final p = _particles[i];
      p.ageSec += dt;
      if (p.isExpired) {
        _particles.removeAt(i);
        continue;
      }
      p.vy += 320.0 * p.gravityScale * dt;
      p.x += p.vx * dt;
      p.y += p.vy * dt;
    }
  }

  // ═══════════════════════════════════════════════════════════════════════════
  //  INTERACTABLES: BENCH, PORTAL, CHEST & SALIGANG TALA LORE TABLET
  // ═══════════════════════════════════════════════════════════════════════════

  _NearbyInteraction? _detectNearbyInteraction() {
    final pCol = (_player.centerX / kDungeonTileSize).floor();
    final pRow = (_player.centerY / kDungeonTileSize).floor();

    // 1. Check Room Exits first (portals 'P')
    for (final ex in _chamber.spec.exits) {
      if ((ex.col - pCol).abs() <= 1 && (ex.row - pRow).abs() <= 2) {
        final bossBlocking = ex.requiresBossDefeat &&
            _chamber.spec.bossId != null &&
            !_progress.defeatedBossIds.contains(_chamber.spec.bossId);
        return _NearbyInteraction(
          kind: 'portal',
          label: bossBlocking ? 'DEFEAT BOSS TO UNLOCK' : ex.label,
          col: ex.col,
          row: ex.row,
          exit: ex,
        );
      }
    }

    // 2. Scan nearby tiles for Campfire Bench ('B'), Chest ('K'), or Lore Tablet ('L')
    for (var r = pRow - 1; r <= pRow + 1; r++) {
      for (var c = pCol - 1; c <= pCol + 1; c++) {
        final t = _chamber.effectiveTileAt(c, r);
        if (t == DungeonTileType.campfireBench) {
          return _NearbyInteraction(
            kind: 'bench',
            label: 'REST & FORGE AT BENCH',
            col: c,
            row: r,
          );
        }
        if (t == DungeonTileType.treasureChest) {
          final chestKey = '${_chamber.spec.id}:${c}_$r';
          if (!_progress.openedChestIds.contains(chestKey)) {
            return _NearbyInteraction(
              kind: 'chest',
              label: 'OPEN RELIC CHEST',
              col: c,
              row: r,
              refId: chestKey,
            );
          }
        }
        if (t == DungeonTileType.loreTablet) {
          final loreId = _chamber.spec.loreTabletIds.isNotEmpty
              ? _chamber.spec.loreTabletIds.first
              : null;
          if (loreId != null) {
            return _NearbyInteraction(
              kind: 'lore',
              label: 'READ SALIGANG TALA',
              col: c,
              row: r,
              refId: loreId,
            );
          }
        }
      }
    }
    return null;
  }

  void _executeInteraction(_NearbyInteraction inter) {
    switch (inter.kind) {
      case 'bench':
        DungeonAudioService.instance.play(DungeonSfxCue.silkBindHeal);
        _player.resolveHp = _progress.effectiveMaxResolveMasks;
        _player.maxResolveHp = _progress.effectiveMaxResolveMasks;
        _player.civicSilk = _progress.effectiveMaxSilk;
        _player.maxCivicSilk = _progress.effectiveMaxSilk;
        _progress = _progress.copyWith(
          checkpointChamberId: _chamber.spec.id,
          checkpointCol: inter.col,
          checkpointRow: inter.row,
        );
        unawaited(_persistProgress());
        setState(() => _shellMode = _DungeonShellMode.benchModal);
        break;

      case 'portal':
        final ex = inter.exit;
        if (ex == null) return;
        if (ex.requiresBossDefeat &&
            _chamber.spec.bossId != null &&
            !_progress.defeatedBossIds.contains(_chamber.spec.bossId)) {
          DungeonAudioService.instance.play(DungeonSfxCue.shieldClang);
          _showToast('Vanquish the Era Boss to open this portal!');
          return;
        }
        DungeonAudioService.instance.play(DungeonSfxCue.gateUnlock);
        _loadChamber(
          chamberId: ex.targetRoomId,
          spawnCol: ex.targetSpawnCol,
          spawnRow: ex.targetSpawnRow,
        );
        _showToast(_chamber.spec.title, duration: 2.0);
        break;

      case 'chest':
        final chestKey = inter.refId;
        if (chestKey == null || _progress.openedChestIds.contains(chestKey)) return;
        final rewardId = _chamber.spec.chestRewardIds.isNotEmpty
            ? _chamber.spec.chestRewardIds.first
            : null;
        final reward = rewardId != null ? kDungeonChestRewards[rewardId] : null;
        final nextCharms = Set<String>.from(_progress.unlockedCharmIds);
        if (reward?.unlockCharmId != null) nextCharms.add(reward!.unlockCharmId!);
        _progress = _progress.copyWith(
          archipelagoShards: _progress.archipelagoShards + (reward?.shards ?? 35),
          unlockedCharmIds: nextCharms,
          bonusMaxResolveMasks: math.min(
            4,
            _progress.bonusMaxResolveMasks +
                ((reward?.grantsResolveMaskShard ?? false) ? 1 : 0),
          ),
          bonusMaxSilk: math.min(
            60,
            _progress.bonusMaxSilk +
                ((reward?.grantsSilkSpoolBoost ?? false) ? 15 : 0),
          ),
          elixirCount: math.min(
            DungeonBenchLogic.kMaxElixirs,
            _progress.elixirCount + (reward?.bonusElixirs ?? 0),
          ),
          openedChestIds: <String>{..._progress.openedChestIds, chestKey},
        );
        _player.maxResolveHp = _progress.effectiveMaxResolveMasks;
        _player.maxCivicSilk = _progress.effectiveMaxSilk;
        DungeonAudioService.instance.play(DungeonSfxCue.victoryFanfare);
        _emitBurst(
          inter.col * kDungeonTileSize + 8,
          inter.row * kDungeonTileSize + 8,
          SpriteCastPalette.endesga32[11],
          count: 16,
        );
        _showToast(reward != null ? '${reward.title}: ${reward.description}' : '+35 Shards!', duration: 3.4);
        unawaited(_persistProgress());
        break;

      case 'lore':
        final lore = inter.refId != null ? kDungeonLoreTablets[inter.refId] : null;
        if (lore != null) {
          DungeonAudioService.instance.play(DungeonSfxCue.secretDiscovered);
          setState(() {
            _activeLoreTablet = lore;
            _shellMode = _DungeonShellMode.loreModal;
          });
        }
        break;
    }
  }

  void _drinkResolveElixir() {
    if (_progress.elixirCount <= 0 || _player.resolveHp >= _player.maxResolveHp) {
      return;
    }
    DungeonAudioService.instance.play(DungeonSfxCue.silkBindHeal);
    setState(() {
      _progress = _progress.copyWith(elixirCount: _progress.elixirCount - 1);
      _player.resolveHp = math.min(_player.maxResolveHp, _player.resolveHp + 3);
      _emitBurst(_player.centerX, _player.centerY, SpriteCastPalette.endesga32[12], count: 12);
      _showToast('ELIXIR RESTORED +3 RESOLVE!', duration: 1.6);
    });
    unawaited(_persistProgress());
  }

  void _handleKeyEvent(KeyEvent event) {
    final key = event.logicalKey;
    if (event is KeyDownEvent) {
      final wasHeld = _heldKeys.contains(key);
      _heldKeys.add(key);
      if (wasHeld) return;

      if (key == LogicalKeyboardKey.escape) {
        setState(() {
          _shellMode = _shellMode == _DungeonShellMode.playing
              ? _DungeonShellMode.paused
              : _DungeonShellMode.playing;
        });
        return;
      }
      if (key == LogicalKeyboardKey.keyM &&
          (_shellMode == _DungeonShellMode.playing ||
              _shellMode == _DungeonShellMode.mapOverlay)) {
        setState(() {
          _shellMode = _shellMode == _DungeonShellMode.mapOverlay
              ? _DungeonShellMode.playing
              : _DungeonShellMode.mapOverlay;
        });
        return;
      }
      if (_shellMode != _DungeonShellMode.playing) return;

      if (key == LogicalKeyboardKey.space || key == LogicalKeyboardKey.keyZ) {
        _queuedJumpPress = true;
      } else if (key == LogicalKeyboardKey.keyK || key == LogicalKeyboardKey.keyC) {
        _queuedDashPress = true;
      } else if (key == LogicalKeyboardKey.keyJ || key == LogicalKeyboardKey.keyX) {
        _queuedSlashPress = true;
      } else if (key == LogicalKeyboardKey.keyL || key == LogicalKeyboardKey.keyV) {
        _queuedSkillPress = true;
      } else if (key == LogicalKeyboardKey.keyG || key == LogicalKeyboardKey.keyF) {
        _queuedGrapplePress = true;
      } else if (key == LogicalKeyboardKey.keyE) {
        _queuedInteractPress = true;
      }
    } else if (event is KeyUpEvent) {
      _heldKeys.remove(key);
      if (key == LogicalKeyboardKey.space || key == LogicalKeyboardKey.keyZ) {
        _queuedJumpRelease = true;
      }
    }
  }

  // ═══════════════════════════════════════════════════════════════════════════
  //  UI SHELL BUILDER
  // ═══════════════════════════════════════════════════════════════════════════

  @override
  Widget build(BuildContext context) {
    final counterBreak = _enemyManager.activeCounterBreakPrompt;

    return KeyboardListener(
      focusNode: _focusNode,
      autofocus: true,
      onKeyEvent: _handleKeyEvent,
      child: Scaffold(
        backgroundColor: SpriteCastPalette.ink,
        body: Stack(
          fit: StackFit.expand,
          children: [
            // 1. Live 320×180 Pixel-Perfect Dungeon Canvas (Student's Custom Avatar!)
            if (_shellMode != _DungeonShellMode.title)
              RepaintBoundary(
                child: CustomPaint(
                  size: Size.infinite,
                  painter: DungeonWorldPainter(
                    chamber: _chamber,
                    player: _player,
                    combat: _combat,
                    progress: _progress,
                    camera: _camera,
                    worldTimeSec: _worldTimeSec,
                    entities: _enemyManager.buildRenderSpecs(),
                    particles: _particles,
                    highlightedGrappleAnchor: _highlightedGrapple,
                    playerAvatarSheet: _playerAvatarSheet,
                    pixelfxVfx: _pixelfxVfx,
                  ),
                ),
              ),

            // 1b. Cinematic Silksong-Style Boss Arena Intro Title Banner!
            if (_shellMode == _DungeonShellMode.playing &&
                _bossIntroTitle != null &&
                _bossIntroTimer > 0.0)
              IgnorePointer(
                child: DungeonBossIntroBanner(
                  eraTag: _bossIntroEraTag ?? 'ERA BOSS ENCOUNTER',
                  bossTitle: _bossIntroTitle!,
                  bossSubtitle: _bossIntroSubtitle ?? '',
                  remainingSec: _bossIntroTimer,
                  totalSec: _kBossIntroDuration,
                ),
              ),

            // 2. Title & Act Select Screen
            if (_shellMode == _DungeonShellMode.title) _buildTitleOverlay(),

            // 3. Diegetic Top HUD + Active Boss Bar
            if (_shellMode == _DungeonShellMode.playing)
              Align(
                alignment: Alignment.topCenter,
                child: DungeonDiegeticHud(
                  player: _player,
                  progress: _progress,
                  chamber: _chamber.spec,
                  activeBoss: _enemyManager.activeBoss,
                  onOpenMap: () => setState(() => _shellMode = _DungeonShellMode.mapOverlay),
                  onTogglePause: () => setState(() => _shellMode = _DungeonShellMode.paused),
                  onUseElixir: _drinkResolveElixir,
                ),
              ),

            // 4. Toast Banner (Secrets, Seals, Chamber Names)
            if (_shellMode == _DungeonShellMode.playing && _toastMessage != null)
              Positioned(
                top: 96,
                left: 16,
                right: 16,
                child: IgnorePointer(
                  child: Center(
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: SpriteCastPalette.ink.withValues(alpha: 0.90),
                        border: Border.all(
                          color: SpriteCastPalette.endesga32[11],
                          width: 1.4,
                        ),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        _toastMessage!,
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          color: Color(0xFFFEE761),
                          fontSize: 11,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ),
                  ),
                ),
              ),

            // 5. Staggered Constitutional Counter-Break 1-Tap Overlay!
            if (_shellMode == _DungeonShellMode.playing && counterBreak != null)
              Positioned(
                left: 0,
                right: 0,
                bottom: 138,
                child: Center(
                  child: DungeonCounterBreakOverlay(
                    prompt: counterBreak,
                    onChooseOption: (idx) {
                      final ev = _enemyManager.resolveCounterBreak(
                        chosenOptionIndex: idx,
                        player: _player,
                        combat: _combat,
                        progress: _progress,
                      );
                      if (ev != null) {
                        _handleEnemyEvents(<DungeonEnemyEvent>[ev]);
                        if (ev.kind == DungeonEnemyEventKind.counterBreakSucceeded) {
                          unawaited(LobbyDataService.instance.awardDungeonXp(75));
                        }
                      }
                      setState(() {});
                    },
                  ),
                ),
              ),

            // 6. Ergonomic Mobile Touch Controls (Left D-Pad + Right Silksong Arc)
            if (_shellMode == _DungeonShellMode.playing)
              _buildMobileTouchControls(),

            // 7. Bahay-Pulungan Bench Sanctuary Modal
            if (_shellMode == _DungeonShellMode.benchModal)
              DungeonBenchSanctuaryModal(
                initialProgress: _progress,
                currentChamberId: _chamber.spec.id,
                currentActNumber: _chamber.spec.actNumber,
                onProgressChanged: (updated) {
                  setState(() {
                    _progress = updated;
                    _player.maxResolveHp = updated.effectiveMaxResolveMasks;
                    _player.resolveHp =
                        _player.resolveHp.clamp(1, _player.maxResolveHp);
                    _player.maxCivicSilk = updated.effectiveMaxSilk;
                  });
                  unawaited(_persistProgress());
                },
                onAwardPortalXp: (xp) =>
                    unawaited(LobbyDataService.instance.awardDungeonXp(xp)),
                onFastTravelToBench: (benchChamberId) {
                  final spec = lookupDungeonChamber(benchChamberId);
                  _loadChamber(
                    chamberId: spec.id,
                    spawnCol: spec.defaultSpawnCol,
                    spawnRow: spec.defaultSpawnRow,
                    restoreFullVitals: true,
                  );
                  setState(() => _shellMode = _DungeonShellMode.playing);
                  _showToast('WARPED TO ${spec.title.toUpperCase()}');
                },
                onClose: () => setState(() => _shellMode = _DungeonShellMode.playing),
              ),

            // 8. Standalone Cartographer World Map Overlay
            if (_shellMode == _DungeonShellMode.mapOverlay)
              DungeonBenchSanctuaryModal(
                initialProgress: _progress,
                currentChamberId: _chamber.spec.id,
                currentActNumber: _chamber.spec.actNumber,
                initialTabIndex: 3,
                onProgressChanged: (updated) {
                  setState(() => _progress = updated);
                  unawaited(_persistProgress());
                },
                onFastTravelToBench: (benchChamberId) {
                  final spec = lookupDungeonChamber(benchChamberId);
                  _loadChamber(
                    chamberId: spec.id,
                    spawnCol: spec.defaultSpawnCol,
                    spawnRow: spec.defaultSpawnRow,
                    restoreFullVitals: true,
                  );
                  setState(() => _shellMode = _DungeonShellMode.playing);
                },
                onClose: () => setState(() => _shellMode = _DungeonShellMode.playing),
              ),

            // 9. Lore Tablet Modal
            if (_shellMode == _DungeonShellMode.loreModal &&
                _activeLoreTablet != null)
              _buildLoreTabletOverlay(_activeLoreTablet!),

            // 10. Pause Menu
            if (_shellMode == _DungeonShellMode.paused) _buildPauseOverlay(),

            // 11. Defeated -> Rise at Sanctuary Bench Overlay
            if (_shellMode == _DungeonShellMode.defeated) _buildDefeatedOverlay(),

            // 12. Altar of the 1987 Charter Victory Finale
            if (_shellMode == _DungeonShellMode.altarVictory)
              _buildAltarVictoryOverlay(),
          ],
        ),
      ),
    );
  }

  Widget _buildTitleOverlay() {
    final sealsCount = kDungeonActWorlds
        .where((a) => _progress.defeatedBossIds.contains(a.bossId))
        .length;

    return SafeArea(
      child: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Container(
            constraints: const BoxConstraints(maxWidth: 680),
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: const Color(0xFF1F2238),
              border: Border.all(
                color: SpriteCastPalette.endesga32[10],
                width: 2.2,
              ),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    // Student's Custom School Lobby Character Preview!
                    Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        color: SpriteCastPalette.ink,
                        border: Border.all(color: SpriteCastPalette.endesga32[18]),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: PixelAvatarPreview(
                        look: _playerLook,
                        facing: AvatarFacing.right,
                        animateWalk: true,
                        scale: 1.35,
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'CHRONICLES OF THE SOVEREIGN',
                            style: TextStyle(
                              color: Color(0xFFFEE761),
                              fontSize: 17,
                              fontWeight: FontWeight.w900,
                              letterSpacing: 1.0,
                            ),
                          ),
                          const SizedBox(height: 3),
                          Text(
                            'Hero: ${widget.playerNickname} • 2D Action-Platformer Dungeon',
                            style: const TextStyle(
                              color: Color(0xFF2CE8F5),
                              fontSize: 11,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Wrap(
                            spacing: 8,
                            runSpacing: 4,
                            children: [
                              _StatChip('SEALS $sealsCount/7', const Color(0xFFFEAE34)),
                              _StatChip(
                                'MAP ${_progress.discoveredChamberIds.length}/35',
                                const Color(0xFF2CE8F5),
                              ),
                              _StatChip(
                                _progress.bladeTier.displayName.toUpperCase(),
                                _progress.bladeTier.slashArcColor,
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                Row(
                  children: [
                    Expanded(
                      child: ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: SpriteCastPalette.endesga32[10],
                          foregroundColor: SpriteCastPalette.ink,
                          padding: const EdgeInsets.symmetric(vertical: 12),
                        ),
                        onPressed: () {
                          _loadChamber(
                            chamberId: _progress.checkpointChamberId,
                            spawnCol: _progress.checkpointCol,
                            spawnRow: _progress.checkpointRow,
                            restoreFullVitals: true,
                          );
                          setState(() => _shellMode = _DungeonShellMode.playing);
                        },
                        icon: const Icon(Icons.play_arrow_rounded),
                        label: const Text(
                          'CONTINUE AT SANCTUARY BENCH',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(
                        foregroundColor: const Color(0xFFEAD4AA),
                        side: const BorderSide(color: Color(0xFF5A6988)),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 12,
                        ),
                      ),
                      onPressed: () => Navigator.of(context).pop(),
                      icon: const Icon(Icons.school_rounded, size: 16),
                      label: const Text(
                        'SCHOOL',
                        style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                const Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    'SELECT HISTORICAL DUNGEON ACT (7 BIOMES • 35 CHAMBERS)',
                    style: TextStyle(
                      color: Color(0xFFC0CBDC),
                      fontSize: 10,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
                const SizedBox(height: 6),
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: kDungeonActWorlds.map((act) {
                    final unlocked = act.actNumber == 1 ||
                        _progress.defeatedBossIds.contains(
                          actSpecForNumber(act.actNumber - 1).bossId,
                        ) ||
                        _progress.discoveredChamberIds.contains(act.entryChamberId);
                    final cleared = _progress.defeatedBossIds.contains(act.bossId);
                    return ActionChip(
                      backgroundColor: cleared
                          ? SpriteCastPalette.endesga32[14]
                          : (unlocked
                              ? const Color(0xFF262B44)
                              : SpriteCastPalette.ink),
                      side: BorderSide(
                        color: cleared
                            ? SpriteCastPalette.endesga32[11]
                            : (unlocked
                                ? SpriteCastPalette.endesga32[18]
                                : SpriteCastPalette.endesga32[23]),
                      ),
                      label: Text(
                        'ACT ${act.actNumber}: ${act.eraYear}${cleared ? ' ✓' : ''}',
                        style: TextStyle(
                          color: unlocked ? Colors.white : const Color(0xFF5A6988),
                          fontSize: 10,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      onPressed: unlocked
                          ? () {
                              final entry = lookupDungeonChamber(act.entryChamberId);
                              _loadChamber(
                                chamberId: entry.id,
                                spawnCol: entry.defaultSpawnCol,
                                spawnRow: entry.defaultSpawnRow,
                                restoreFullVitals: true,
                              );
                              setState(() => _shellMode = _DungeonShellMode.playing);
                              _showToast('ACT ${act.actNumber}: ${act.title.toUpperCase()}');
                            }
                          : null,
                    );
                  }).toList(),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildMobileTouchControls() {
    final activeSkill = silkSkillSpecFor(_progress.activeSkill);
    final canGrapple = _highlightedGrapple != null;

    return SafeArea(
      top: false,
      child: Align(
        alignment: Alignment.bottomCenter,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 0, 12, 10),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              // Left Thumb: 360° Virtual Analog Joystick Wheel
              // (Smooth analog sprint, diagonal up-slash, downward pogo & ladder climb!)
              DungeonVirtualJoystickWheel(
                size: 124,
                onChanged: (vec) {
                  _touchMoveX = vec.dx;
                  _touchMoveY = vec.dy;
                },
              ),

              // Center Dynamic Context INTERACT Button (Bench / Portal / Chest / Lore!)
              Expanded(
                child: _nearbyInteract != null
                    ? Center(
                        child: Padding(
                          padding: const EdgeInsets.only(bottom: 12),
                          child: ElevatedButton.icon(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: SpriteCastPalette.endesga32[10],
                              foregroundColor: SpriteCastPalette.ink,
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 8,
                              ),
                            ),
                            onPressed: () => _queuedInteractPress = true,
                            icon: const Icon(Icons.touch_app_rounded, size: 15),
                            label: Text(
                              _nearbyInteract!.label,
                              style: const TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                          ),
                        ),
                      )
                    : const SizedBox.shrink(),
              ),

              // Right Thumb: Silksong Ergonomic Action Button Arc
              SizedBox(
                width: 162,
                height: 124,
                child: Stack(
                  children: [
                    // BIND (Hold-to-Heal) — Top Left
                    Positioned(
                      left: 0,
                      top: 6,
                      child: _TouchHoldButton(
                        size: 42,
                        label: 'BIND',
                        color: SpriteCastPalette.endesga32[12],
                        onChanged: (down) => _touchBindHeld = down,
                      ),
                    ),
                    // GRAPPLE — Top Center
                    Positioned(
                      left: 52,
                      top: 0,
                      child: _TouchTapButton(
                        size: 42,
                        label: 'HOOK',
                        color: canGrapple
                            ? SpriteCastPalette.endesga32[18]
                            : SpriteCastPalette.endesga32[22],
                        onTapDown: () => _queuedGrapplePress = true,
                      ),
                    ),
                    // SILK SKILL — Top Right
                    Positioned(
                      right: 4,
                      top: 10,
                      child: _TouchTapButton(
                        size: 44,
                        label: 'SKILL',
                        color: activeSkill.fxColor,
                        onTapDown: () => _queuedSkillPress = true,
                      ),
                    ),
                    // DASH — Bottom Left
                    Positioned(
                      left: 4,
                      bottom: 10,
                      child: _TouchTapButton(
                        size: 44,
                        label: 'DASH',
                        color: SpriteCastPalette.endesga32[10],
                        onTapDown: () => _queuedDashPress = true,
                      ),
                    ),
                    // SLASH — Primary Center-Bottom
                    Positioned(
                      left: 56,
                      bottom: 4,
                      child: _TouchTapButton(
                        size: 52,
                        label: 'SLASH',
                        color: SpriteCastPalette.endesga32[8],
                        onTapDown: () => _queuedSlashPress = true,
                      ),
                    ),
                    // JUMP — Bottom Right (variable jump hold!)
                    Positioned(
                      right: 0,
                      bottom: 16,
                      child: _TouchHoldButton(
                        size: 50,
                        label: 'JUMP',
                        color: SpriteCastPalette.endesga32[18],
                        onChanged: (down) {
                          _touchJumpHeld = down;
                          if (down) {
                            _queuedJumpPress = true;
                          } else {
                            _queuedJumpRelease = true;
                          }
                        },
                      ),
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

  Widget _buildLoreTabletOverlay(DungeonLoreTabletSpec lore) {
    return Material(
      color: SpriteCastPalette.ink.withValues(alpha: 0.86),
      child: Center(
        child: Container(
          constraints: const BoxConstraints(maxWidth: 460),
          margin: const EdgeInsets.all(16),
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: const Color(0xFF1F2238),
            border: Border.all(color: SpriteCastPalette.endesga32[18], width: 2),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                lore.eraTag.toUpperCase(),
                style: const TextStyle(
                  color: Color(0xFF2CE8F5),
                  fontSize: 10,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                lore.title,
                style: const TextStyle(
                  color: Color(0xFFFEE761),
                  fontSize: 16,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 10),
              Text(
                lore.body,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 12,
                  height: 1.45,
                ),
              ),
              const SizedBox(height: 10),
              Text(
                lore.constitutionLink,
                style: const TextStyle(
                  color: Color(0xFF63C74D),
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 14),
              Align(
                alignment: Alignment.centerRight,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: SpriteCastPalette.endesga32[18],
                    foregroundColor: SpriteCastPalette.ink,
                  ),
                  onPressed: () => setState(() => _shellMode = _DungeonShellMode.playing),
                  child: const Text(
                    'CONTINUE',
                    style: TextStyle(fontWeight: FontWeight.w900),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPauseOverlay() {
    return Material(
      color: SpriteCastPalette.ink.withValues(alpha: 0.85),
      child: Center(
        child: Container(
          width: 300,
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: const Color(0xFF1F2238),
            border: Border.all(color: SpriteCastPalette.endesga32[10], width: 2),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'CHRONICLES PAUSED',
                style: TextStyle(
                  color: Color(0xFFFEE761),
                  fontSize: 15,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 14),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: SpriteCastPalette.endesga32[10],
                    foregroundColor: SpriteCastPalette.ink,
                  ),
                  onPressed: () => setState(() => _shellMode = _DungeonShellMode.playing),
                  child: const Text('RESUME ADVENTURE', style: TextStyle(fontWeight: FontWeight.w900)),
                ),
              ),
              const SizedBox(height: 8),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton(
                  style: OutlinedButton.styleFrom(foregroundColor: Colors.white),
                  onPressed: () => setState(() => _shellMode = _DungeonShellMode.title),
                  child: const Text('ACT SELECT / TITLE'),
                ),
              ),
              const SizedBox(height: 8),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton(
                  style: OutlinedButton.styleFrom(foregroundColor: const Color(0xFFEAD4AA)),
                  onPressed: () async {
                    await _persistProgress();
                    if (mounted) Navigator.of(context).pop();
                  },
                  child: const Text('SAVE & RETURN TO SCHOOL'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDefeatedOverlay() {
    return Material(
      color: SpriteCastPalette.ink.withValues(alpha: 0.90),
      child: Center(
        child: Container(
          width: 340,
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: const Color(0xFF261823),
            border: Border.all(color: SpriteCastPalette.endesga32[8], width: 2),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'RESOLVE SHATTERED',
                style: TextStyle(
                  color: Color(0xFFE43B44),
                  fontSize: 17,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'Your Archipelago Shards, Charms, and Charter Seals remain safe. Rekindle at your last Bahay-Pulungan Sanctuary Bench!',
                textAlign: TextAlign.center,
                style: TextStyle(color: Color(0xFFEAD4AA), fontSize: 11),
              ),
              const SizedBox(height: 16),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: SpriteCastPalette.endesga32[10],
                  foregroundColor: SpriteCastPalette.ink,
                ),
                onPressed: () {
                  _loadChamber(
                    chamberId: _progress.checkpointChamberId,
                    spawnCol: _progress.checkpointCol,
                    spawnRow: _progress.checkpointRow,
                    restoreFullVitals: true,
                  );
                  setState(() => _shellMode = _DungeonShellMode.playing);
                },
                child: const Text(
                  'RISE AT SANCTUARY BENCH',
                  style: TextStyle(fontWeight: FontWeight.w900),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildAltarVictoryOverlay() {
    return Material(
      color: SpriteCastPalette.ink.withValues(alpha: 0.92),
      child: Center(
        child: Container(
          constraints: const BoxConstraints(maxWidth: 460),
          margin: const EdgeInsets.all(16),
          padding: const EdgeInsets.all(22),
          decoration: BoxDecoration(
            color: const Color(0xFF1F2238),
            border: Border.all(color: SpriteCastPalette.endesga32[11], width: 2.5),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.workspace_premium_rounded,
                color: Color(0xFFFEE761),
                size: 46,
              ),
              const SizedBox(height: 8),
              const Text(
                'SOVEREIGNTY CROWNED — 1987 CHARTER RESTORED!',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Color(0xFFFEE761),
                  fontSize: 16,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 10),
              Text(
                '${widget.playerNickname}, you conquered all 7 Historical Era Dungeons, forged ${_progress.bladeTier.displayName}, and earned the Master Historian Crown + +200 Portal XP!',
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.white, fontSize: 12),
              ),
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: SpriteCastPalette.endesga32[10],
                      foregroundColor: SpriteCastPalette.ink,
                    ),
                    onPressed: () =>
                        setState(() => _shellMode = _DungeonShellMode.playing),
                    child: const Text(
                      'KEEP EXPLORING',
                      style: TextStyle(fontWeight: FontWeight.w900),
                    ),
                  ),
                  const SizedBox(width: 10),
                  OutlinedButton(
                    style: OutlinedButton.styleFrom(
                      foregroundColor: const Color(0xFFEAD4AA),
                    ),
                    onPressed: () async {
                      await _persistProgress();
                      if (mounted) Navigator.of(context).pop();
                    },
                    child: const Text('RETURN TO SCHOOL'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _StatChip extends StatelessWidget {
  final String label;
  final Color color;
  const _StatChip(this.label, this.color);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.16),
        border: Border.all(color: color),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontSize: 9,
          fontWeight: FontWeight.w900,
        ),
      ),
    );
  }
}

class _TouchTapButton extends StatelessWidget {
  final double size;
  final String label;
  final Color color;
  final VoidCallback onTapDown;

  const _TouchTapButton({
    required this.size,
    required this.label,
    required this.color,
    required this.onTapDown,
  });

  @override
  Widget build(BuildContext context) {
    return Listener(
      onPointerDown: (_) => onTapDown(),
      child: Container(
        width: size,
        height: size,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: SpriteCastPalette.ink.withValues(alpha: 0.72),
          border: Border.all(color: color, width: 2.0),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: color,
            fontSize: 9,
            fontWeight: FontWeight.w900,
          ),
        ),
      ),
    );
  }
}

/// Multi-touch-safe 360° Virtual Analog Joystick Wheel (`craft-game-floors` UI Floor).
///
/// Tracks a single dedicated `pointer` ID via [Listener] so holding & swirling
/// the left thumb never conflicts with simultaneous right-thumb `SLASH` / `JUMP` / `DASH` taps.
class DungeonVirtualJoystickWheel extends StatefulWidget {
  final double size;
  final double deadzone;
  final ValueChanged<Offset> onChanged;

  const DungeonVirtualJoystickWheel({
    super.key,
    this.size = 124.0,
    this.deadzone = 0.14,
    required this.onChanged,
  });

  @override
  State<DungeonVirtualJoystickWheel> createState() =>
      _DungeonVirtualJoystickWheelState();
}

class _DungeonVirtualJoystickWheelState
    extends State<DungeonVirtualJoystickWheel> {
  int? _activePointerId;
  Offset _knobOffset = Offset.zero; // px from wheel center
  Offset _outputVector = Offset.zero; // normalized [-1..1] after deadzone

  double get _maxKnobRadius => widget.size * 0.31;

  void _updateFromLocalPosition(Offset localPos) {
    final center = Offset(widget.size * 0.5, widget.size * 0.5);
    final rawDelta = localPos - center;
    final dist = rawDelta.distance;
    final maxR = _maxKnobRadius;

    final clampedDelta = dist <= maxR || dist == 0.0
        ? rawDelta
        : Offset(rawDelta.dx / dist * maxR, rawDelta.dy / dist * maxR);

    final normMag = (clampedDelta.distance / maxR).clamp(0.0, 1.0);
    Offset nextVec = Offset.zero;
    if (normMag > widget.deadzone && dist > 0.0) {
      final rescaled =
          ((normMag - widget.deadzone) / (1.0 - widget.deadzone)).clamp(0.0, 1.0);
      nextVec = Offset(
        (rawDelta.dx / dist) * rescaled,
        (rawDelta.dy / dist) * rescaled,
      );
    }

    setState(() {
      _knobOffset = clampedDelta;
      _outputVector = nextVec;
    });
    widget.onChanged(nextVec);
  }

  void _resetStick() {
    if (_activePointerId == null && _knobOffset == Offset.zero) return;
    setState(() {
      _activePointerId = null;
      _knobOffset = Offset.zero;
      _outputVector = Offset.zero;
    });
    widget.onChanged(Offset.zero);
  }

  @override
  Widget build(BuildContext context) {
    return Listener(
      behavior: HitTestBehavior.opaque,
      onPointerDown: (event) {
        if (_activePointerId != null) return;
        _activePointerId = event.pointer;
        _updateFromLocalPosition(event.localPosition);
      },
      onPointerMove: (event) {
        if (event.pointer != _activePointerId) return;
        _updateFromLocalPosition(event.localPosition);
      },
      onPointerUp: (event) {
        if (event.pointer != _activePointerId) return;
        _resetStick();
      },
      onPointerCancel: (event) {
        if (event.pointer != _activePointerId) return;
        _resetStick();
      },
      child: SizedBox(
        width: widget.size,
        height: widget.size,
        child: CustomPaint(
          painter: _JoystickWheelPainter(
            knobOffset: _knobOffset,
            outputVector: _outputVector,
            isActive: _activePointerId != null,
          ),
        ),
      ),
    );
  }
}

class _JoystickWheelPainter extends CustomPainter {
  final Offset knobOffset;
  final Offset outputVector;
  final bool isActive;

  const _JoystickWheelPainter({
    required this.knobOffset,
    required this.outputVector,
    required this.isActive,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width * 0.5, size.height * 0.5);
    final outerR = size.width * 0.46;
    final innerTrackR = size.width * 0.31;

    // 1. Recessed obsidian outer wheel well + beveled brass/slate rim
    canvas.drawCircle(
      center,
      outerR,
      Paint()..color = SpriteCastPalette.ink.withValues(alpha: 0.74),
    );
    canvas.drawCircle(
      center,
      outerR,
      Paint()
        ..color = isActive
            ? SpriteCastPalette.endesga32[10]
            : SpriteCastPalette.endesga32[22]
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.2,
    );
    canvas.drawCircle(
      center,
      innerTrackR,
      Paint()
        ..color = SpriteCastPalette.endesga32[23].withValues(alpha: 0.65)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.2,
    );

    // 2. Crisp 8-way compass ticks around the rim
    final tickPaint = Paint()
      ..color = SpriteCastPalette.endesga32[21].withValues(alpha: 0.55)
      ..strokeWidth = 1.4;
    for (var i = 0; i < 8; i++) {
      final a = i * (math.pi / 4.0);
      final r0 = (i.isEven ? outerR - 6.5 : outerR - 4.5);
      canvas.drawLine(
        Offset(center.dx + math.cos(a) * r0, center.dy + math.sin(a) * r0),
        Offset(
          center.dx + math.cos(a) * (outerR - 1.8),
          center.dy + math.sin(a) * (outerR - 1.8),
        ),
        tickPaint,
      );
    }

    // 3. Directional Aim Rim Arc (Gold/Emerald Up-Slash, Crimson/Amber Down-Pogo, Cyan Run!)
    if (outputVector.distance > 0.05) {
      final angle = math.atan2(outputVector.dy, outputVector.dx);
      final Color aimColor;
      if (outputVector.dy < -0.55) {
        aimColor = SpriteCastPalette.endesga32[12]; // Up-Slash / Climb
      } else if (outputVector.dy > 0.55) {
        aimColor = SpriteCastPalette.endesga32[9]; // Downward Pogo-Slash
      } else {
        aimColor = SpriteCastPalette.endesga32[18]; // Horizontal Sprint
      }

      canvas.drawArc(
        Rect.fromCircle(center: center, radius: outerR - 1.0),
        angle - 0.52,
        1.04,
        false,
        Paint()
          ..color = aimColor
          ..style = PaintingStyle.stroke
          ..strokeWidth = 3.2
          ..strokeCap = StrokeCap.round,
      );

      // Subtle silk tether from center to thumb puck
      canvas.drawLine(
        center,
        center + knobOffset,
        Paint()
          ..color = aimColor.withValues(alpha: 0.55)
          ..strokeWidth = 2.4,
      );
    }

    // 4. Spring-Centered Beveled Thumb Puck + Sovereign Star Emblem
    final puckCenter = center + knobOffset;
    final puckR = size.width * 0.175;
    // Drop shadow
    canvas.drawCircle(
      puckCenter + const Offset(0, 2.0),
      puckR + 1.0,
      Paint()..color = SpriteCastPalette.ink.withValues(alpha: 0.75),
    );
    // Puck body + crisp border
    canvas.drawCircle(
      puckCenter,
      puckR,
      Paint()
        ..color = isActive
            ? const Color(0xFF262B44)
            : const Color(0xFF1F2238),
    );
    canvas.drawCircle(
      puckCenter,
      puckR,
      Paint()
        ..color = isActive
            ? SpriteCastPalette.endesga32[18]
            : SpriteCastPalette.endesga32[10]
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.0,
    );
    // Inner Sovereign diamond/star core
    final starCol = isActive
        ? SpriteCastPalette.endesga32[11]
        : SpriteCastPalette.endesga32[2];
    final diamond = Path()
      ..moveTo(puckCenter.dx, puckCenter.dy - 5.5)
      ..lineTo(puckCenter.dx + 5.5, puckCenter.dy)
      ..lineTo(puckCenter.dx, puckCenter.dy + 5.5)
      ..lineTo(puckCenter.dx - 5.5, puckCenter.dy)
      ..close();
    canvas.drawPath(diamond, Paint()..color = starCol);
  }

  @override
  bool shouldRepaint(covariant _JoystickWheelPainter oldDelegate) {
    return oldDelegate.knobOffset != knobOffset ||
        oldDelegate.isActive != isActive;
  }
}

class _TouchHoldButton extends StatelessWidget {
  final double size;
  final String label;
  final Color color;
  final ValueChanged<bool> onChanged;

  const _TouchHoldButton({
    required this.size,
    required this.label,
    required this.color,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Listener(
      onPointerDown: (_) => onChanged(true),
      onPointerUp: (_) => onChanged(false),
      onPointerCancel: (_) => onChanged(false),
      child: Container(
        width: size,
        height: size,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: SpriteCastPalette.ink.withValues(alpha: 0.72),
          border: Border.all(color: color, width: 2.0),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: color,
            fontSize: 9,
            fontWeight: FontWeight.w900,
          ),
        ),
      ),
    );
  }
}

/// Dramatic Silksong-style Boss Arena Intro Title Banner (`craft-game-floors` UI Floor).
///
/// Appears briefly (`2.2s`) upon stepping into an undefeated Boss or Rival Arena,
/// framing the viewport with non-blocking letterbox heraldry and gilded rule lines.
class DungeonBossIntroBanner extends StatelessWidget {
  final String eraTag;
  final String bossTitle;
  final String bossSubtitle;
  final double remainingSec;
  final double totalSec;

  const DungeonBossIntroBanner({
    super.key,
    required this.eraTag,
    required this.bossTitle,
    required this.bossSubtitle,
    this.remainingSec = 1.5,
    this.totalSec = 2.2,
  });

  @override
  Widget build(BuildContext context) {
    final elapsed = (totalSec - remainingSec).clamp(0.0, totalSec);
    final fadeIn = (elapsed / 0.28).clamp(0.0, 1.0);
    final fadeOut = (remainingSec / 0.42).clamp(0.0, 1.0);
    final opacity = math.min(fadeIn, fadeOut).clamp(0.0, 1.0);

    return Opacity(
      opacity: opacity,
      child: Stack(
        fit: StackFit.expand,
        children: [
          // Subtle top & bottom cinema framing bars
          Align(
            alignment: Alignment.topCenter,
            child: Container(
              height: 18,
              color: SpriteCastPalette.ink.withValues(alpha: 0.72),
            ),
          ),
          Align(
            alignment: Alignment.bottomCenter,
            child: Container(
              height: 18,
              color: SpriteCastPalette.ink.withValues(alpha: 0.72),
            ),
          ),
          // Center-lower heraldic title plaque
          Align(
            alignment: const Alignment(0.0, 0.34),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 460),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 18,
                    vertical: 10,
                  ),
                  decoration: BoxDecoration(
                    color: SpriteCastPalette.ink.withValues(alpha: 0.88),
                    border: Border.symmetric(
                      horizontal: BorderSide(
                        color: SpriteCastPalette.endesga32[10],
                        width: 2.0,
                      ),
                    ),
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        eraTag,
                        textAlign: TextAlign.center,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: SpriteCastPalette.endesga32[18],
                          fontSize: 9.5,
                          letterSpacing: 1.6,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        bossTitle,
                        textAlign: TextAlign.center,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: SpriteCastPalette.endesga32[11],
                          fontSize: 17,
                          letterSpacing: 1.4,
                          fontWeight: FontWeight.w900,
                          shadows: const [
                            Shadow(
                              color: Colors.black,
                              offset: Offset(1.5, 1.5),
                            ),
                          ],
                        ),
                      ),
                      if (bossSubtitle.isNotEmpty) ...[
                        const SizedBox(height: 3),
                        Container(
                          width: 140,
                          height: 1.2,
                          color: SpriteCastPalette.endesga32[10]
                              .withValues(alpha: 0.75),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          bossSubtitle,
                          textAlign: TextAlign.center,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: SpriteCastPalette.endesga32[2],
                            fontSize: 10.5,
                            letterSpacing: 1.1,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
