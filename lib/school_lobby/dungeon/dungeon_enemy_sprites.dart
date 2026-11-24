import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../spritecast_engine.dart';
import 'dungeon_renderer.dart';

/// Metadata for an exported `patch-gg/pixelfx` sprite sheet (`assets/school_lobby/dungeon_sprites/`).
class PixelfxSheetSpec {
  final String key;
  final String assetPath;
  final int frames;
  final int frameWidth;
  final int frameHeight;
  final double pivotX;
  final double pivotY;
  final int columns;
  final double fps;
  final bool loop;

  const PixelfxSheetSpec({
    required this.key,
    required this.assetPath,
    required this.frames,
    required this.frameWidth,
    required this.frameHeight,
    required this.pivotX,
    required this.pivotY,
    required this.columns,
    required this.fps,
    required this.loop,
  });

  /// Computes the exact source frame rectangle inside the sprite sheet grid.
  Rect frameRect(int frameIndex) {
    final safeIdx = loop
        ? (frameIndex % frames + frames) % frames
        : frameIndex.clamp(0, frames - 1);
    final col = safeIdx % columns;
    final row = safeIdx ~/ columns;
    return Rect.fromLTWH(
      (col * frameWidth).toDouble(),
      (row * frameHeight).toDouble(),
      frameWidth.toDouble(),
      frameHeight.toDouble(),
    );
  }
}

/// Asynchronous loader and nearest-neighbor renderer for exported `pixelfx` sprite sheets.
///
/// Safe in headless `flutter test` environments: if sheets are not yet decoded,
/// [DungeonEnemySpritePainter] seamlessly renders multi-part pixel-art anatomy fallbacks.
class DungeonPixelfxSheetCache {
  DungeonPixelfxSheetCache._();

  static final DungeonPixelfxSheetCache instance = DungeonPixelfxSheetCache._();

  static const Map<String, PixelfxSheetSpec> kSpecs = <String, PixelfxSheetSpec>{
    'bat': PixelfxSheetSpec(
      key: 'bat',
      assetPath: 'assets/school_lobby/dungeon_sprites/bat.png',
      frames: 16,
      frameWidth: 56,
      frameHeight: 48,
      pivotX: 28.0,
      pivotY: 24.0,
      columns: 4,
      fps: 12.0,
      loop: true,
    ),
    'wisp': PixelfxSheetSpec(
      key: 'wisp',
      assetPath: 'assets/school_lobby/dungeon_sprites/wisp.png',
      frames: 24,
      frameWidth: 56,
      frameHeight: 64,
      pivotX: 28.0,
      pivotY: 38.0,
      columns: 6,
      fps: 12.0,
      loop: true,
    ),
    'eyeball': PixelfxSheetSpec(
      key: 'eyeball',
      assetPath: 'assets/school_lobby/dungeon_sprites/eyeball.png',
      frames: 24,
      frameWidth: 64,
      frameHeight: 68,
      pivotX: 32.0,
      pivotY: 30.0,
      columns: 6,
      fps: 12.0,
      loop: true,
    ),
    'ghost': PixelfxSheetSpec(
      key: 'ghost',
      assetPath: 'assets/school_lobby/dungeon_sprites/ghost.png',
      frames: 24,
      frameWidth: 56,
      frameHeight: 60,
      pivotX: 28.0,
      pivotY: 42.0,
      columns: 6,
      fps: 12.0,
      loop: true,
    ),
    'sword_slash': PixelfxSheetSpec(
      key: 'sword_slash',
      assetPath: 'assets/school_lobby/dungeon_sprites/sword_slash.png',
      frames: 10,
      frameWidth: 136,
      frameHeight: 104,
      pivotX: 80.0,
      pivotY: 60.0,
      columns: 3,
      fps: 18.0,
      loop: false,
    ),
    'parry': PixelfxSheetSpec(
      key: 'parry',
      assetPath: 'assets/school_lobby/dungeon_sprites/parry.png',
      frames: 13,
      frameWidth: 200,
      frameHeight: 112,
      pivotX: 100.0,
      pivotY: 62.0,
      columns: 3,
      fps: 18.0,
      loop: false,
    ),
    'crit_hit': PixelfxSheetSpec(
      key: 'crit_hit',
      assetPath: 'assets/school_lobby/dungeon_sprites/crit_hit.png',
      frames: 12,
      frameWidth: 216,
      frameHeight: 136,
      pivotX: 98.0,
      pivotY: 74.0,
      columns: 3,
      fps: 16.0,
      loop: false,
    ),
    'sunburst': PixelfxSheetSpec(
      key: 'sunburst',
      assetPath: 'assets/school_lobby/dungeon_sprites/sunburst.png',
      frames: 48,
      frameWidth: 128,
      frameHeight: 128,
      pivotX: 64.0,
      pivotY: 64.0,
      columns: 7,
      fps: 12.0,
      loop: true,
    ),
  };

  final Map<String, ui.Image> _images = <String, ui.Image>{};
  Future<void>? _preloadFuture;

  ui.Image? getImage(String key) => _images[key];
  PixelfxSheetSpec? specFor(String key) => kSpecs[key];

  bool get isReady => _images.length == kSpecs.length;

  /// Allows deterministic injection in widget/unit tests.
  void injectForTest(String key, ui.Image image) {
    _images[key] = image;
  }

  /// Decodes all 8 `pixelfx` sprite sheets once into GPU-ready [ui.Image] textures.
  Future<void> preloadAll() {
    if (isReady) return Future<void>.value();
    return _preloadFuture ??= _doPreload();
  }

  Future<void> _doPreload() async {
    for (final entry in kSpecs.entries) {
      if (_images.containsKey(entry.key)) continue;
      try {
        final data = await rootBundle.load(entry.value.assetPath);
        final bytes = data.buffer.asUint8List();
        if (bytes.isEmpty) continue;
        final codec = await ui.instantiateImageCodec(bytes);
        final frame = await codec.getNextFrame();
        _images[entry.key] = frame.image;
      } catch (_) {
        // Safe fallback in headless tests or missing asset environments.
      }
    }
    _preloadFuture = null;
  }

  /// Draws a single frame from a loaded `pixelfx` sprite sheet anchored at `(worldX, worldY)`
  /// with crisp nearest-neighbor pixel filtering, optional horizontal flip, and white hit-flash.
  bool drawSheetFrame({
    required Canvas canvas,
    required Paint reusablePaint,
    required String key,
    required double worldX,
    required double worldY,
    required int frameIndex,
    double scale = 0.55,
    bool flipX = false,
    double rotationRad = 0.0,
    double opacity = 1.0,
    bool whiteFlash = false,
    BlendMode blendMode = BlendMode.srcOver,
  }) {
    final img = _images[key];
    final spec = kSpecs[key];
    if (img == null || spec == null) return false;
    // Validate dimensions match at least 1 frame so 1x1 test stubs can also exercise code paths safely
    final src = img.width >= spec.frameWidth && img.height >= spec.frameHeight
        ? spec.frameRect(frameIndex)
        : Rect.fromLTWH(0, 0, img.width.toDouble(), img.height.toDouble());

    final dst = Rect.fromLTWH(
      -spec.pivotX * scale,
      -spec.pivotY * scale,
      spec.frameWidth * scale,
      spec.frameHeight * scale,
    );

    reusablePaint
      ..style = PaintingStyle.fill
      ..filterQuality = FilterQuality.none
      ..blendMode = blendMode
      ..color = Color.fromRGBO(255, 255, 255, opacity.clamp(0.0, 1.0))
      ..colorFilter = whiteFlash
          ? const ColorFilter.mode(Colors.white, BlendMode.srcATop)
          : null;

    canvas.save();
    canvas.translate(worldX, worldY);
    if (rotationRad != 0.0) {
      canvas.rotate(rotationRad);
    }
    if (flipX) {
      canvas.scale(-1.0, 1.0);
    }
    canvas.drawImageRect(img, src, dst, reusablePaint);
    canvas.restore();

    reusablePaint
      ..colorFilter = null
      ..blendMode = BlendMode.srcOver;
    return true;
  }
}

/// Bespoke multi-part pixel-art character & boss sprite renderer (`pixelfx` + `SpriteCast` craft).
///
/// Replaces all placeholder geometric boxes with **22 unique, readable character silhouettes**
/// featuring headgear, armor/robes, articulated limbs, signature weapons, 4-state combat poses
/// (`patrol`, `windup`, `attack`, `recover`/`staggered`), and multi-phase boss evolutions.
class DungeonEnemySpritePainter {
  DungeonEnemySpritePainter._();

  // Pre-allocated reusable Paint instances for zero per-frame GC churn!
  static final Paint _fill = Paint()..style = PaintingStyle.fill;
  static final Paint _stroke = Paint()
    ..style = PaintingStyle.stroke
    ..strokeCap = StrokeCap.square;
  static final Paint _imgPaint = Paint()..filterQuality = FilterQuality.none;

  /// Renders a complete enemy, Rival Mateo, or Multi-Phase Era Boss onto [canvas].
  static void paintEntity({
    required Canvas canvas,
    required DungeonEntityRenderSpec e,
    required double worldTimeSec,
    required int animTick,
    DungeonPixelfxSheetCache? sheetCache,
  }) {
    final cache = sheetCache ?? DungeonPixelfxSheetCache.instance;
    final hb = e.hitbox;

    // 1. Aim telegraph sightline for marksmen / snipers / bosses
    if (e.aimTelegraphEnd != null) {
      final pulse = 0.55 + 0.45 * math.sin(worldTimeSec * 28.0);
      _stroke
        ..color = SpriteCastPalette.endesga32[26].withValues(alpha: 0.32 * pulse)
        ..strokeWidth = 2.6;
      canvas.drawLine(hb.center, e.aimTelegraphEnd!, _stroke);
      _stroke
        ..color = SpriteCastPalette.endesga32[19].withValues(alpha: 0.78 * pulse)
        ..strokeWidth = 0.9;
      canvas.drawLine(hb.center, e.aimTelegraphEnd!, _stroke);
    }

    // 2. Stepped contact shadow underneath grounded & low-hovering characters
    SpriteCastEngine.drawSteppedContactShadow(
      canvas,
      Rect.fromCenter(
        center: Offset(hb.center.dx, hb.bottom + (e.isFlying ? 6.0 : 0.5)),
        width: hb.width * (e.isFlying ? 0.72 : 1.05),
        height: e.isBoss ? 4.2 : 3.2,
      ),
      castDx: 1.5,
      castDy: 1.0,
      strength: e.isFlying ? 0.38 : 0.72,
      oval: true,
    );

    // 3. Compute common animation drivers from AI state
    final isWindup = e.isTelegraphing || e.aiStateName == 'windup';
    final isAttack = e.aiStateName == 'attack';
    final isRecover = e.aiStateName == 'recover';
    final isPhaseShift = e.aiStateName == 'phaseShift';
    final isFlashing = e.hitFlashTimer > 0.0;

    final walkSpeed = e.vx.abs() > 4.0 ? (e.animPhase * 8.5) : (worldTimeSec * 3.2);
    final stride = e.vx.abs() > 4.0 ? math.sin(walkSpeed) : 0.0;
    final breathe = math.sin(worldTimeSec * 4.2 + hb.left * 0.05) * 0.6;
    final crouch = isWindup
        ? 2.0
        : (e.isStaggered ? 3.0 : (isRecover ? 1.2 : 0.0));
    final lungeX = isAttack
        ? 2.5
        : (isWindup ? -1.5 : 0.0);

    final rig = _PxRig(
      canvas: canvas,
      originX: hb.center.dx + e.facing * lungeX,
      feetY: hb.bottom,
      facing: e.facing >= 0 ? 1 : -1,
      isFlashing: isFlashing,
      isWindup: isWindup,
      windupPulse: 0.5 + 0.5 * math.sin(worldTimeSec * 26.0),
    );

    // 4. Boss Phase 2 / Phase 3 background aura & phaseShift roar ring
    if (e.isBoss && (e.bossPhase >= 2 || isPhaseShift)) {
      _paintBossPhaseAura(canvas, e, worldTimeSec, cache);
    }

    // 5. Dispatch to bespoke character anatomy for all 22 archetypes!
    switch (e.archetypeId) {
      case 'barangay_scout':
        _paintBarangayScout(rig, e, stride, breathe, crouch, isWindup, isAttack);
        break;
      case 'cave_alimaong':
        _paintCaveAlimaong(canvas, rig, e, worldTimeSec, isWindup, isAttack, cache);
        break;
      case 'raider_leaper':
        _paintRaiderLeaper(rig, e, stride, crouch, isWindup, isAttack, worldTimeSec);
        break;
      case 'guardia_lancer':
        _paintGuardiaLancer(rig, e, stride, crouch, isWindup, isAttack);
        break;
      case 'intramuros_musketeer':
        _paintIntramurosMusketeer(rig, e, stride, crouch, isWindup, isAttack, worldTimeSec);
        break;
      case 'belltower_bat':
        _paintBelltowerBat(canvas, rig, e, worldTimeSec, isWindup, isAttack, cache);
        break;
      case 'malolos_swordsman':
        _paintMalolosSwordsman(rig, e, stride, crouch, isWindup, isAttack, worldTimeSec);
        break;
      case 'tribunal_acolyte':
        _paintTribunalAcolyte(canvas, rig, e, worldTimeSec, isWindup, isAttack, cache);
        break;
      case 'deco_automaton':
        _paintDecoAutomaton(rig, e, stride, crouch, isWindup, isAttack, worldTimeSec);
        break;
      case 'skybridge_sniper':
        _paintSkybridgeSniper(rig, e, stride, crouch, isWindup, isAttack, worldTimeSec);
        break;
      case 'bunker_mortar':
        _paintBunkerMortar(rig, e, isWindup, isAttack, worldTimeSec);
        break;
      case 'imperial_commando':
        _paintImperialCommando(rig, e, stride, crouch, isWindup, isAttack);
        break;
      case 'censor_drone':
        _paintCensorDrone(canvas, rig, e, worldTimeSec, isWindup, isAttack, cache);
        break;
      case 'iron_juggernaut':
        _paintIronJuggernaut(rig, e, stride, crouch, isWindup, isAttack, worldTimeSec);
        break;
      case 'rival_mateo':
        _paintRivalMateo(canvas, rig, e, stride, crouch, isWindup, isAttack, worldTimeSec);
        break;
      case 'boss_datu_makisig':
        _paintBossDatuMakisig(rig, e, stride, crouch, isWindup, isAttack, worldTimeSec);
        break;
      case 'boss_valdes':
        _paintBossValdes(rig, e, stride, crouch, isWindup, isAttack, worldTimeSec);
        break;
      case 'boss_calderon':
        _paintBossCalderon(rig, e, crouch, isWindup, isAttack, worldTimeSec);
        break;
      case 'boss_commonwealth_warden':
        _paintBossCommonwealthWarden(rig, e, stride, crouch, isWindup, isAttack, worldTimeSec);
        break;
      case 'boss_imperial_commander':
        _paintBossImperialCommander(rig, e, stride, crouch, isWindup, isAttack, worldTimeSec);
        break;
      case 'boss_iron_censor':
        _paintBossIronCensor(rig, e, stride, crouch, isWindup, isAttack, worldTimeSec);
        break;
      case 'boss_sovereign_guardian':
        _paintBossSovereignGuardian(
          canvas,
          rig,
          e,
          stride,
          crouch,
          isWindup,
          isAttack,
          worldTimeSec,
          cache,
        );
        break;
      default:
        _paintBarangayScout(rig, e, stride, breathe, crouch, isWindup, isAttack);
        break;
    }

    // 6. Crisp telegraph glint & staggered Counter-Break stars + compact HP bar
    _paintEntityStatusOverlays(canvas, e, worldTimeSec);
  }

  // ═══════════════════════════════════════════════════════════════════════════
  //  BOSS PHASE AURAS & STATUS OVERLAYS
  // ═══════════════════════════════════════════════════════════════════════════

  static void _paintBossPhaseAura(
    Canvas canvas,
    DungeonEntityRenderSpec e,
    double worldTimeSec,
    DungeonPixelfxSheetCache cache,
  ) {
    final hb = e.hitbox;
    final pulse = 0.65 + 0.35 * math.sin(worldTimeSec * 9.0);
    final auraCol = e.bossPhase >= 3
        ? SpriteCastPalette.endesga32[11]
        : e.accentColor;

    // Soft additive ground & torso halo
    _fill
      ..blendMode = BlendMode.plus
      ..color = auraCol.withValues(alpha: 0.16 * pulse);
    canvas.drawCircle(hb.center, hb.height * 0.68, _fill);
    _fill.blendMode = BlendMode.srcOver;

    // Rising phase embers around boss silhouette
    for (var i = 0; i < 4; i++) {
      final t = (worldTimeSec * 1.8 + i * 0.25) % 1.0;
      final ox = math.sin(worldTimeSec * 4.0 + i * 1.9) * (hb.width * 0.55);
      final oy = hb.bottom - t * (hb.height + 8.0);
      _fill.color = auraCol.withValues(alpha: (1.0 - t) * 0.85);
      canvas.drawRect(Rect.fromCenter(center: Offset(hb.center.dx + ox, oy), width: 2.0, height: 2.0), _fill);
    }

    if (e.aiStateName == 'phaseShift') {
      final ringR = hb.width * (0.7 + 0.8 * ((worldTimeSec * 3.0) % 1.0));
      _stroke
        ..color = SpriteCastPalette.endesga32[19].withValues(alpha: 0.75)
        ..strokeWidth = 1.6;
      canvas.drawCircle(hb.center, ringR, _stroke);
    }
  }

  static void _paintEntityStatusOverlays(
    Canvas canvas,
    DungeonEntityRenderSpec e,
    double worldTimeSec,
  ) {
    final hb = e.hitbox;
    final topY = hb.top - (e.isBoss ? 7.0 : 4.0);

    // Unmistakable crimson-gold 4-point telegraph spark before strike!
    if (e.isTelegraphing) {
      final cx = hb.center.dx;
      final cy = topY - 4.0;
      final flare = 1.0 + 0.35 * math.sin(worldTimeSec * 30.0);
      _fill.color = SpriteCastPalette.endesga32[26];
      canvas.drawRect(Rect.fromCenter(center: Offset(cx, cy), width: 7.0 * flare, height: 2.0), _fill);
      canvas.drawRect(Rect.fromCenter(center: Offset(cx, cy), width: 2.0, height: 7.0 * flare), _fill);
      _fill.color = SpriteCastPalette.endesga32[19];
      canvas.drawRect(Rect.fromCenter(center: Offset(cx, cy), width: 2.2, height: 2.2), _fill);
    }

    // Staggered golden Charter stars (signals Constitutional Counter-Break!)
    if (e.isStaggered) {
      for (var s = 0; s < 3; s++) {
        final angle = worldTimeSec * 6.5 + s * (math.pi * 2 / 3);
        final sx = hb.center.dx + math.cos(angle) * (hb.width * 0.45 + 3.0);
        final sy = topY - 3.0 + math.sin(angle) * 2.5;
        _fill.color = SpriteCastPalette.ink;
        canvas.drawRect(Rect.fromCenter(center: Offset(sx, sy), width: 4.2, height: 4.2), _fill);
        _fill.color = SpriteCastPalette.endesga32[11];
        canvas.drawRect(Rect.fromCenter(center: Offset(sx, sy), width: 2.6, height: 2.6), _fill);
      }
    }

    // Compact pixel HP bar above damaged non-boss enemies
    if (!e.isBoss && e.hp < e.maxHp && e.maxHp > 0) {
      final frac = (e.hp / e.maxHp).clamp(0.0, 1.0);
      final barW = math.max(12.0, hb.width + 2.0);
      final barRect = Rect.fromLTWH(hb.center.dx - barW * 0.5, topY - 2.0, barW, 3.0);
      _fill.color = SpriteCastPalette.ink;
      canvas.drawRect(barRect, _fill);
      _fill.color = SpriteCastPalette.endesga32[6];
      canvas.drawRect(Rect.fromLTWH(barRect.left + 0.6, barRect.top + 0.6, barRect.width - 1.2, 1.8), _fill);
      _fill.color = SpriteCastPalette.endesga32[8];
      canvas.drawRect(Rect.fromLTWH(barRect.left + 0.6, barRect.top + 0.6, (barRect.width - 1.2) * frac, 1.8), _fill);
    }
  }

  // ═══════════════════════════════════════════════════════════════════════════
  //  14 UNIQUE REGULAR ENEMIES + RIVAL MATEO
  // ═══════════════════════════════════════════════════════════════════════════

  /// 1. `barangay_scout` — Putong headband + ribbons, rattan chestplate, bahag, kalasag buckler & sibat spear.
  static void _paintBarangayScout(
    _PxRig rig,
    DungeonEntityRenderSpec e,
    double stride,
    double breathe,
    double crouch,
    bool isWindup,
    bool isAttack,
  ) {
    final p = SpriteCastPalette.endesga32;
    rig.legs(stride: stride, crouch: crouch, legColor: p[3], bootColor: p[5]);
    // Bahag loincloth
    rig.box(-3.5, 6.5 - crouch, 7.0, 3.0, p[7], highlight: p[8]);
    // Rattan woven chestplate over bronze skin
    rig.box(-4.0, 11.5 - crouch + breathe * 0.4, 8.0, 5.5, p[4], highlight: p[10], shade: p[5]);
    // Head + fierce eyes + crimson Putong headband with trailing ribbon
    rig.box(-3.2, 16.5 - crouch, 6.5, 5.0, p[3], highlight: p[30], shade: p[4]);
    rig.box(-3.6, 17.2 - crouch, 7.2, 2.0, p[8], highlight: p[9], outline: true);
    rig.box(-6.5, 16.8 - crouch - stride * 0.6, 3.2, 1.6, p[7]); // ribbon tail
    rig.eye(1.2, 14.5 - crouch, isWindup ? p[26] : p[25]);
    // Kalasag wooden buckler on off-hand
    rig.box(-5.2, 10.5 - crouch, 3.2, 5.8, p[5], highlight: p[10]);
    // Bamboo-iron Sibat spear (pulls back on windup, thrusts forward on attack)
    final spearShift = isAttack ? 5.5 : (isWindup ? -4.0 : 0.0);
    rig.blade(-5.0 + spearShift, 9.5 - crouch, 9.5 + spearShift, 10.2 - crouch, 1.5, p[4], p[3]);
    rig.blade(8.5 + spearShift, 10.2 - crouch, 12.8 + spearShift, 10.2 - crouch, 2.2, p[20], p[19]);
  }

  /// 2. `cave_alimaong` — Genuine `pixelfx` Sprite Fusion soul-flame wisp + procedural spirit fallback.
  static void _paintCaveAlimaong(
    Canvas canvas,
    _PxRig rig,
    DungeonEntityRenderSpec e,
    double worldTimeSec,
    bool isWindup,
    bool isAttack,
    DungeonPixelfxSheetCache cache,
  ) {
    final p = SpriteCastPalette.endesga32;
    final frame = (worldTimeSec * 12.0).floor();
    final rot = isAttack ? (e.facing >= 0 ? 0.32 : -0.32) : 0.0;
    final scale = isWindup ? 0.54 : 0.46;

    final drewSheet = cache.drawSheetFrame(
      canvas: canvas,
      reusablePaint: _imgPaint,
      key: 'wisp',
      worldX: e.hitbox.center.dx,
      worldY: e.hitbox.center.dy + 2.0,
      frameIndex: frame,
      scale: scale,
      flipX: e.facing < 0,
      rotationRad: rot,
      whiteFlash: e.hitFlashTimer > 0.0,
    );

    if (!drewSheet) {
      // Multi-tongue soul-flame fallback when running headless tests without decoded assets
      final flick = math.sin(worldTimeSec * 16.0) * 1.6;
      rig.box(-3.5, 16.0 + flick, 2.8, 5.0, p[17], highlight: p[18]);
      rig.box(0.8, 17.0 - flick, 2.8, 5.5, p[17], highlight: p[18]);
      rig.box(-1.5, 19.5 + flick * 0.5, 3.4, 7.0, p[18], highlight: p[19]);
      rig.box(-5.0, 12.0, 10.0, 9.5, p[17], highlight: p[18], shade: p[16]);
      rig.box(-3.2, 10.2, 6.4, 6.0, p[19], outline: false);
      rig.eye(-1.2, 9.0, p[24]);
      rig.eye(1.8, 9.0, p[24]);
    }

    if (isAttack) {
      // Swooping cyan comet streak behind wisp
      rig.blade(-9.5, 6.0, -3.5, 6.0, 2.4, p[18], p[19]);
    }
  }

  /// 3. `raider_leaper` — Corsair bandana, agile wrap attire & twin curved Kris daggers.
  static void _paintRaiderLeaper(
    _PxRig rig,
    DungeonEntityRenderSpec e,
    double stride,
    double crouch,
    bool isWindup,
    bool isAttack,
    double worldTimeSec,
  ) {
    final p = SpriteCastPalette.endesga32;
    final spin = isAttack ? math.sin(worldTimeSec * 28.0) * 2.5 : 0.0;
    rig.legs(stride: isAttack ? 1.0 : stride, crouch: crouch + (isWindup ? 1.5 : 0.0), legColor: p[15], bootColor: p[4]);
    // Crimson waist sash + corsair vest
    rig.box(-4.2, 7.0 - crouch, 8.4, 2.4, p[8], highlight: p[10]);
    rig.box(-4.2, 12.0 - crouch, 8.4, 5.5, p[0], highlight: p[1], shade: p[5]);
    // Head + knotted pirate bandana + mask
    rig.box(-3.4, 17.0 - crouch, 6.8, 5.0, p[3], highlight: p[30]);
    rig.box(-3.8, 17.6 - crouch, 7.6, 2.4, p[7], highlight: p[8]);
    rig.box(-6.8, 16.5 - crouch, 3.0, 2.0, p[7]); // bandana knot tails
    rig.eye(1.4, 15.0 - crouch, p[11]);
    // Twin curved Kris daggers (coiled back on windup, crossed slash forward on leap!)
    if (isWindup) {
      rig.blade(-7.5, 11.5 - crouch, -2.5, 8.5 - crouch, 1.8, p[20], p[19]);
      rig.blade(1.5, 8.0 - crouch, 6.5, 5.5 - crouch, 1.8, p[20], p[19]);
    } else {
      rig.blade(2.5, 10.0 - crouch + spin, 9.8, 13.5 - crouch - spin, 1.9, p[20], p[19]);
      rig.blade(2.0, 8.0 - crouch - spin, 9.2, 5.5 - crouch + spin, 1.9, p[18], p[19]);
    }
  }

  /// 4. `guardia_lancer` — Crested Spanish steel Morion helm, cuirass, tall riveted pavise shield & halberd.
  static void _paintGuardiaLancer(
    _PxRig rig,
    DungeonEntityRenderSpec e,
    double stride,
    double crouch,
    bool isWindup,
    bool isAttack,
  ) {
    final p = SpriteCastPalette.endesga32;
    rig.legs(stride: stride * 0.7, crouch: crouch, legColor: p[23], bootColor: p[24]);
    // Steel-and-indigo cuirass with gold waist tassets
    rig.box(-4.8, 7.5 - crouch, 9.6, 2.8, p[7], highlight: p[10]);
    rig.box(-4.8, 13.5 - crouch, 9.6, 6.5, p[22], highlight: p[20], shade: p[23]);
    // Crested Spanish Morion helmet + scarlet plume
    rig.box(-4.0, 18.5 - crouch, 8.0, 4.8, p[3], shade: p[4]);
    rig.box(-5.0, 19.8 - crouch, 10.0, 2.8, p[21], highlight: p[20], shade: p[23]); // curved brim
    rig.box(-2.5, 22.2 - crouch, 5.0, 2.8, p[20], highlight: p[19]); // comb crest
    rig.box(-5.6, 21.6 - crouch, 3.0, 2.4, p[8], highlight: p[9]); // scarlet plume
    rig.eye(1.5, 16.5 - crouch, p[11]);

    // Halberd polearm (couched forward; thrusts far on attack)
    final thrust = isAttack ? 6.5 : (isWindup ? -3.5 : 0.0);
    rig.blade(-6.0 + thrust, 10.5 - crouch, 11.0 + thrust, 10.5 - crouch, 1.6, p[5], p[4]);
    rig.box(8.5 + thrust, 13.8 - crouch, 3.2, 5.2, p[20], highlight: p[19], shade: p[22]); // axe head
    rig.blade(11.0 + thrust, 10.5 - crouch, 14.8 + thrust, 10.5 - crouch, 1.8, p[20], p[19]); // spike

    // Tall riveted brass-trimmed Pavise Shield in front (`isShieldedFront`)
    if (e.isShieldedFront) {
      rig.box(3.2, 14.8 - crouch, 4.4, 13.5, p[23], highlight: p[10], shade: p[24]);
      rig.box(4.2, 11.2 - crouch, 2.4, 5.5, p[10], highlight: p[11], outline: false); // gold cross boss
    }
  }

  /// 5. `intramuros_musketeer` — Plumed wide-brim hat, crimson tunic, bandolier & braced matchlock arkabuz.
  static void _paintIntramurosMusketeer(
    _PxRig rig,
    DungeonEntityRenderSpec e,
    double stride,
    double crouch,
    bool isWindup,
    bool isAttack,
    double worldTimeSec,
  ) {
    final p = SpriteCastPalette.endesga32;
    rig.legs(stride: stride * 0.6, crouch: crouch, legColor: p[23], bootColor: p[6]);
    // Crimson musketeer coat + diagonal leather bandolier
    rig.box(-4.2, 12.8 - crouch, 8.4, 7.2, p[7], highlight: p[8], shade: p[6]);
    rig.blade(-3.2, 12.2 - crouch, 3.2, 6.8 - crouch, 1.6, p[4], p[10]); // ammo bandolier
    // Head + wide-brim Chambergo cavalier hat + white feather plume
    rig.box(-3.4, 17.5 - crouch, 6.8, 4.8, p[3], highlight: p[30]);
    rig.box(-6.0, 18.2 - crouch, 12.0, 2.0, p[6], highlight: p[5]); // wide brim
    rig.box(-3.6, 20.6 - crouch, 7.2, 2.8, p[6], highlight: p[7]); // hat crown
    rig.box(-5.8, 21.8 - crouch, 4.0, 2.2, p[19], shade: p[20]); // white plume
    rig.eye(1.4, 15.6 - crouch, isWindup ? p[26] : p[25]);

    // Braced long-barrel Arkabuz musket + matchcord spark / muzzle flash
    final recoil = isAttack ? -2.2 : 0.0;
    rig.box(-1.5 + recoil, 11.8 - crouch, 5.5, 2.6, p[5], highlight: p[4]); // wooden stock
    rig.blade(2.5 + recoil, 11.2 - crouch, 13.0 + recoil, 11.2 - crouch, 1.8, p[22], p[20]); // steel barrel
    if (isWindup) {
      final spark = 1.6 + 0.8 * math.sin(worldTimeSec * 35.0);
      rig.box(2.5, 13.5 - crouch, spark, spark, p[11], highlight: p[19], outline: false); // burning matchcord
    } else if (isAttack) {
      rig.box(12.2, 13.2 - crouch, 4.5, 4.2, p[10], highlight: p[19]); // muzzle blast!
    }
  }

  /// 6. `belltower_bat` — Genuine `pixelfx` 4-frame winged bat sprite sheet + articulated fallback.
  static void _paintBelltowerBat(
    Canvas canvas,
    _PxRig rig,
    DungeonEntityRenderSpec e,
    double worldTimeSec,
    bool isWindup,
    bool isAttack,
    DungeonPixelfxSheetCache cache,
  ) {
    final p = SpriteCastPalette.endesga32;
    final frame = (worldTimeSec * (isAttack ? 18.0 : 12.0)).floor();
    final drewSheet = cache.drawSheetFrame(
      canvas: canvas,
      reusablePaint: _imgPaint,
      key: 'bat',
      worldX: e.hitbox.center.dx,
      worldY: e.hitbox.center.dy,
      frameIndex: frame,
      scale: isWindup ? 0.62 : 0.56,
      flipX: e.facing < 0,
      whiteFlash: e.hitFlashTimer > 0.0,
    );

    if (!drewSheet) {
      final flap = math.sin(worldTimeSec * 18.0) * 5.0;
      rig.blade(-1.5, 7.0, -10.5, 9.0 + flap, 3.0, p[27], p[28]);
      rig.blade(1.5, 7.0, 10.5, 9.0 + flap, 3.0, p[27], p[28]);
      rig.box(-3.6, 9.5, 7.2, 7.5, p[24], highlight: p[27]);
      rig.box(-3.2, 12.2, 2.0, 3.0, p[27]); // left ear
      rig.box(1.2, 12.2, 2.0, 3.0, p[27]); // right ear
      rig.eye(-1.2, 7.5, p[26]);
      rig.eye(1.2, 7.5, p[26]);
    }
  }

  /// 7. `malolos_swordsman` — Woven Salakot, Rayadillo tunic, off-hand cape & curved officer sabre.
  static void _paintMalolosSwordsman(
    _PxRig rig,
    DungeonEntityRenderSpec e,
    double stride,
    double crouch,
    bool isWindup,
    bool isAttack,
    double worldTimeSec,
  ) {
    final p = SpriteCastPalette.endesga32;
    final wave = math.sin(worldTimeSec * 7.0) * 1.2;
    // Swept cobalt duelist half-cloak behind back shoulder
    rig.cape(topY: 13.5 - crouch, length: 8.5, sway: wave, color: p[16], shade: p[24]);
    rig.legs(stride: isAttack ? 1.2 : stride, crouch: crouch, legColor: p[20], bootColor: p[6]);
    // Striped Rayadillo revolutionary tunic + red sash
    rig.box(-4.0, 7.5 - crouch, 8.0, 2.2, p[8], highlight: p[9]);
    rig.box(-4.2, 13.0 - crouch, 8.4, 6.0, p[20], highlight: p[19], shade: p[21]);
    rig.box(-2.0, 12.6 - crouch, 1.2, 5.2, p[17], outline: false); // rayadillo stripe
    rig.box(1.0, 12.6 - crouch, 1.2, 5.2, p[17], outline: false);
    // Head + woven domed Salakot hat with golden finial spike
    rig.box(-3.4, 17.2 - crouch, 6.8, 4.6, p[3], highlight: p[30]);
    rig.box(-6.2, 18.2 - crouch, 12.4, 2.2, p[3], highlight: p[2], shade: p[4]); // domed salakot
    rig.box(-3.2, 19.8 - crouch, 6.4, 2.0, p[4], highlight: p[2]);
    rig.box(-0.8, 21.4 - crouch, 1.6, 2.0, p[10], highlight: p[11]); // brass finial
    rig.eye(1.4, 15.5 - crouch, p[25]);

    // Curved brass-hilted Sabre (fencer's coil -> gleaming thrust!)
    if (isWindup) {
      rig.blade(-2.0, 11.0 - crouch, -7.5, 16.5 - crouch, 1.8, p[20], p[19]);
      rig.box(-2.8, 11.8 - crouch, 2.4, 2.4, p[10]); // brass guard
    } else if (isAttack) {
      rig.box(3.5, 11.2 - crouch, 2.5, 2.5, p[10]);
      rig.blade(5.0, 10.2 - crouch, 15.5, 10.6 - crouch, 2.0, p[18], p[19]);
    } else {
      rig.box(2.8, 10.8 - crouch, 2.4, 2.4, p[10]);
      rig.blade(4.2, 10.0 - crouch, 11.2, 13.8 - crouch, 1.7, p[20], p[19]);
    }
  }

  /// 8. `tribunal_acolyte` — Genuine `pixelfx` cyan scholar robe + floating Charter Tome & 3 orbiting runes.
  static void _paintTribunalAcolyte(
    Canvas canvas,
    _PxRig rig,
    DungeonEntityRenderSpec e,
    double worldTimeSec,
    bool isWindup,
    bool isAttack,
    DungeonPixelfxSheetCache cache,
  ) {
    final p = SpriteCastPalette.endesga32;
    final frame = (worldTimeSec * 12.0).floor();
    final drewSheet = cache.drawSheetFrame(
      canvas: canvas,
      reusablePaint: _imgPaint,
      key: 'ghost',
      worldX: e.hitbox.center.dx,
      worldY: e.hitbox.bottom + 1.0,
      frameIndex: frame,
      scale: 0.46,
      flipX: e.facing < 0,
      whiteFlash: e.hitFlashTimer > 0.0,
    );

    if (!drewSheet) {
      final bob = math.sin(worldTimeSec * 4.5) * 1.4;
      rig.box(-4.8, 12.5 + bob, 9.6, 11.0, p[16], highlight: p[17], shade: p[24]);
      rig.box(-3.8, 17.5 + bob, 7.6, 5.8, p[17], highlight: p[18]);
      rig.eye(-1.2, 15.0 + bob, p[19]);
      rig.eye(1.4, 15.0 + bob, p[19]);
    }

    // Golden scholar stole + Levitating Open Charter Tome in front
    final bookBob = math.sin(worldTimeSec * 6.0) * 1.5;
    rig.box(4.8, 10.5 + bookBob, 5.4, 4.2, p[5], highlight: p[10]); // leather cover
    rig.box(5.4, 11.2 + bookBob, 4.2, 2.6, p[2], highlight: p[19], outline: false); // glowing pages

    // 3 Orbiting cyan-gold ink rune seals
    final orbitSpeed = isWindup || isAttack ? 8.5 : 3.6;
    final radius = isAttack ? 11.5 : 8.8;
    for (var i = 0; i < 3; i++) {
      final a = worldTimeSec * orbitSpeed + i * (math.pi * 2 / 3);
      final rx = e.hitbox.center.dx + math.cos(a) * radius;
      final ry = e.hitbox.center.dy - 2.0 + math.sin(a) * 4.2;
      _fill.color = SpriteCastPalette.ink;
      canvas.drawRect(Rect.fromCenter(center: Offset(rx, ry), width: 3.6, height: 3.6), _fill);
      _fill.color = i == 0 ? p[11] : p[18];
      canvas.drawRect(Rect.fromCenter(center: Offset(rx, ry), width: 2.0, height: 2.0), _fill);
    }
  }

  /// 9. `deco_automaton` — Art-Deco brass/cyan golem, spinning dorsal gear, piston legs & Deco tower shield.
  static void _paintDecoAutomaton(
    _PxRig rig,
    DungeonEntityRenderSpec e,
    double stride,
    double crouch,
    bool isWindup,
    bool isAttack,
    double worldTimeSec,
  ) {
    final p = SpriteCastPalette.endesga32;
    // Spinning dorsal brass clockwork gear behind back
    final gearSpin = worldTimeSec * (isWindup || isAttack ? 9.0 : 3.2);
    rig.gear(-4.2, 12.5 - crouch, 5.2, gearSpin, p[10], p[5]);

    rig.legs(stride: stride * 0.65, crouch: crouch, legColor: p[22], bootColor: p[10], thick: 3.0);
    // Stepped Art-Deco bronze-and-steel chassis + cyan reactor core
    rig.box(-5.6, 14.5 - crouch, 11.2, 9.5, p[22], highlight: p[20], shade: p[23]);
    rig.box(-3.4, 13.0 - crouch, 6.8, 6.2, p[10], highlight: p[11], shade: p[4]); // Deco brass chevron
    rig.box(-1.6, 11.5 - crouch, 3.2, 3.2, p[18], highlight: p[19]); // glowing cyan core
    // Flat-topped Art-Deco sentinel helm with neon-cyan visor slit
    rig.box(-4.2, 19.2 - crouch, 8.4, 5.2, p[21], highlight: p[20], shade: p[23]);
    rig.box(-1.2, 21.2 - crouch, 2.4, 2.4, p[10], highlight: p[11]); // sunburst crest fin
    rig.box(-2.8, 17.5 - crouch, 6.2, 1.8, isWindup ? p[26] : p[18], highlight: p[19], outline: false);

    // Pneumatic Deco lance punch
    final ext = isAttack ? 7.0 : (isWindup ? -2.5 : 0.0);
    rig.blade(2.0 + ext, 10.5 - crouch, 11.5 + ext, 10.5 - crouch, 2.4, p[18], p[19]);

    if (e.isShieldedFront) {
      rig.box(3.8, 15.6 - crouch, 4.8, 14.8, p[23], highlight: p[10], shade: p[24]);
      rig.box(4.8, 13.5 - crouch, 2.6, 9.0, p[18], highlight: p[19], outline: false);
    }
  }

  /// 10. `skybridge_sniper` — Wind-swept trenchcoat, glowing ruby mono-scope & precision bipod rifle.
  static void _paintSkybridgeSniper(
    _PxRig rig,
    DungeonEntityRenderSpec e,
    double stride,
    double crouch,
    bool isWindup,
    bool isAttack,
    double worldTimeSec,
  ) {
    final p = SpriteCastPalette.endesga32;
    final kneeDrop = crouch + (isWindup ? 2.2 : 0.0);
    rig.cape(topY: 11.5 - kneeDrop, length: 8.5, sway: math.sin(worldTimeSec * 8.0) * 1.8, color: p[16], shade: p[24]);
    rig.legs(stride: stride * 0.6, crouch: kneeDrop, legColor: p[23], bootColor: p[24]);
    rig.box(-4.0, 12.8 - kneeDrop, 8.0, 6.8, p[16], highlight: p[17], shade: p[23]);
    // Marksman cap + ruby mono-scope visor
    rig.box(-3.4, 17.2 - kneeDrop, 6.8, 4.8, p[23], highlight: p[22]);
    rig.box(-3.8, 18.6 - kneeDrop, 8.6, 2.0, p[24], highlight: p[16]); // peaked visor cap
    rig.box(0.8, 16.2 - kneeDrop, 3.2, 2.2, p[26], highlight: p[19]); // glowing ruby scope eye!

    // Long Sky-Bridge precision sniper rifle + muzzle brake
    final kick = isAttack ? -2.5 : 0.0;
    rig.box(-2.0 + kick, 11.8 - kneeDrop, 5.5, 2.4, p[5], highlight: p[4]);
    rig.blade(2.5 + kick, 11.0 - kneeDrop, 15.2 + kick, 11.0 - kneeDrop, 1.7, p[21], p[20]);
    rig.blade(9.5 + kick, 11.0 - kneeDrop, 11.0 + kick, 7.2 - kneeDrop, 1.1, p[22], p[21]); // bipod leg
    if (isAttack) {
      rig.box(14.5, 12.8 - kneeDrop, 4.2, 3.6, p[26], highlight: p[19]);
    }
  }

  /// 11. `bunker_mortar` — Sandbagged wheeled steel artillery carriage, helmeted gunner & recoiling howitzer tube.
  static void _paintBunkerMortar(
    _PxRig rig,
    DungeonEntityRenderSpec e,
    bool isWindup,
    bool isAttack,
    double worldTimeSec,
  ) {
    final p = SpriteCastPalette.endesga32;
    // Helmeted loader crouching behind the mortar breech
    rig.box(-7.5, 9.5, 5.5, 6.0, p[14], highlight: p[13], shade: p[15]);
    rig.box(-7.8, 13.0, 6.2, 3.6, p[13], highlight: p[12], shade: p[14]); // dome helmet

    // Riveted steel gun carriage + spoked wheel
    rig.box(-5.0, 6.5, 10.0, 4.5, p[23], highlight: p[22], shade: p[24]);
    rig.gear(-1.0, 4.2, 3.8, 0.4, p[22], p[24]);

    // Elevating angled howitzer cannon barrel (recoils down-back on fire!)
    final recoil = isAttack ? -2.8 : (isWindup ? -1.0 : 0.0);
    rig.blade(-2.5 + recoil, 6.5, 6.8 + recoil, 14.8 + recoil * 0.4, 3.8, p[22], p[20]);
    rig.box(4.8 + recoil, 16.2 + recoil * 0.4, 3.6, 3.2, p[10], highlight: p[11]); // brass muzzle ring

    // Stacked olive-ochre sandbag fortification at front base
    rig.box(2.2, 4.2, 6.4, 3.8, p[4], highlight: p[3], shade: p[5]);
    rig.box(3.0, 7.2, 5.2, 3.2, p[3], highlight: p[2], shade: p[4]);

    if (isWindup) {
      final fuse = 1.5 + 0.8 * math.sin(worldTimeSec * 32.0);
      rig.box(-3.2, 9.5, fuse, fuse, p[9], highlight: p[11], outline: false);
    } else if (isAttack) {
      rig.box(6.2, 18.5, 5.5, 5.0, p[9], highlight: p[19]); // artillery blast!
    }
  }

  /// 12. `imperial_commando` — Combat dome helmet, dorsal field pack & two-handed bayonet lunge.
  static void _paintImperialCommando(
    _PxRig rig,
    DungeonEntityRenderSpec e,
    double stride,
    double crouch,
    bool isWindup,
    bool isAttack,
  ) {
    final p = SpriteCastPalette.endesga32;
    // Dorsal canvas field pack
    rig.box(-6.8, 13.0 - crouch, 3.6, 6.2, p[5], highlight: p[4], shade: p[6]);
    rig.legs(stride: isAttack ? 1.3 : stride, crouch: crouch, legColor: p[14], bootColor: p[6]);
    // Olive-slate combat tunic + web harness
    rig.box(-4.4, 13.0 - crouch, 8.8, 6.8, p[14], highlight: p[13], shade: p[15]);
    rig.box(-4.4, 8.2 - crouch, 8.8, 1.8, p[5], highlight: p[10]);
    // Rounded combat dome helmet + goggles
    rig.box(-3.5, 17.5 - crouch, 7.0, 4.6, p[3], shade: p[4]);
    rig.box(-4.4, 19.8 - crouch, 8.8, 3.6, p[15], highlight: p[14], shade: p[24]);
    rig.eye(1.5, 15.8 - crouch, p[8]);

    // Two-handed bayonet rifle charge
    final charge = isAttack ? 6.8 : (isWindup ? -3.0 : 0.0);
    rig.blade(-4.0 + charge, 10.0 - crouch, 9.2 + charge, 10.4 - crouch, 1.8, p[5], p[4]);
    rig.blade(8.8 + charge, 10.4 - crouch, 14.8 + charge, 10.6 - crouch, 2.0, p[20], p[19]); // gleaming bayonet!
  }

  /// 13. `censor_drone` — Genuine `pixelfx` obsidian-ruby eyeball + armor fins & crimson scan cone.
  static void _paintCensorDrone(
    Canvas canvas,
    _PxRig rig,
    DungeonEntityRenderSpec e,
    double worldTimeSec,
    bool isWindup,
    bool isAttack,
    DungeonPixelfxSheetCache cache,
  ) {
    final p = SpriteCastPalette.endesga32;
    final hb = e.hitbox;
    final dir = e.facing >= 0 ? 1.0 : -1.0;

    // Translucent crimson surveillance scan-cone projecting ahead
    final coneLen = isWindup || isAttack ? 26.0 : 18.0;
    final coneAlpha = isWindup ? 0.30 : 0.16;
    final conePath = Path()
      ..moveTo(hb.center.dx + dir * 4.0, hb.center.dy)
      ..lineTo(hb.center.dx + dir * coneLen, hb.center.dy - 7.5)
      ..lineTo(hb.center.dx + dir * coneLen, hb.center.dy + 8.5)
      ..close();
    _fill.color = p[26].withValues(alpha: coneAlpha);
    canvas.drawPath(conePath, _fill);

    final frame = (worldTimeSec * 12.0).floor();
    final drewSheet = cache.drawSheetFrame(
      canvas: canvas,
      reusablePaint: _imgPaint,
      key: 'eyeball',
      worldX: hb.center.dx,
      worldY: hb.center.dy,
      frameIndex: frame,
      scale: 0.44,
      flipX: e.facing < 0,
      whiteFlash: e.hitFlashTimer > 0.0,
    );

    if (!drewSheet) {
      rig.box(-6.0, 13.5, 12.0, 12.0, p[20], highlight: p[19], shade: p[22]);
      rig.box(-6.4, 14.2, 12.8, 3.2, p[24], highlight: p[22]); // upper steel lid
      rig.box(-0.5, 10.5, 4.6, 4.6, p[26], highlight: p[19]); // ruby iris
    }

    // Twin hovering obsidian stabilizer fins flanking the eye
    final finBob = math.sin(worldTimeSec * 7.5) * 1.2;
    rig.box(-8.5, 12.5 + finBob, 2.2, 6.5, p[24], highlight: p[22]);
    rig.box(6.5, 12.5 - finBob, 2.2, 6.5, p[24], highlight: p[26]);
  }

  /// 14. `iron_juggernaut` — Horned obsidian colossus, glowing furnace rib-grate, spiked pauldrons & war-maul!
  static void _paintIronJuggernaut(
    _PxRig rig,
    DungeonEntityRenderSpec e,
    double stride,
    double crouch,
    bool isWindup,
    bool isAttack,
    double worldTimeSec,
  ) {
    final p = SpriteCastPalette.endesga32;
    final furnaceGlow = 0.65 + 0.35 * math.sin(worldTimeSec * 10.0);

    rig.legs(stride: stride * 0.55, crouch: crouch, legColor: p[24], bootColor: p[25], thick: 3.8, spread: 4.2);
    // Colossal obsidian plate torso + glowing molten furnace grate
    rig.box(-7.5, 16.8 - crouch, 15.0, 11.5, p[24], highlight: p[22], shade: p[25]);
    rig.box(-3.6, 13.8 - crouch, 7.2, 5.2, Color.lerp(p[7], p[9], furnaceGlow)!, highlight: p[11]);
    // Spiked iron pauldrons
    rig.box(-9.5, 17.5 - crouch, 4.6, 4.5, p[23], highlight: p[21]);
    rig.box(4.9, 17.5 - crouch, 4.6, 4.5, p[23], highlight: p[21]);
    // Horned Great-Helm with narrow burning crimson visor
    rig.box(-4.8, 22.0 - crouch, 9.6, 5.8, p[23], highlight: p[21], shade: p[24]);
    rig.blade(-4.2, 20.5 - crouch, -7.8, 24.5 - crouch, 1.8, p[20], p[19]); // left horn
    rig.blade(4.2, 20.5 - crouch, 7.8, 24.5 - crouch, 1.8, p[20], p[19]); // right horn
    rig.box(-3.0, 19.6 - crouch, 6.4, 1.8, p[26], highlight: p[11], outline: false);

    // Massive Two-Handed Obsidian War-Maul (hoisted overhead on windup, slammed down on attack!)
    if (isWindup) {
      rig.blade(-1.0, 14.0 - crouch, -3.5, 27.0 - crouch, 2.2, p[5], p[4]);
      rig.box(-8.0, 30.5 - crouch, 9.0, 6.0, p[24], highlight: p[26], shade: p[25]);
    } else if (isAttack) {
      rig.blade(1.0, 11.0 - crouch, 13.5, 3.0, 2.2, p[5], p[4]);
      rig.box(10.5, 7.5, 9.5, 6.8, p[24], highlight: p[9], shade: p[25]);
    } else {
      rig.blade(-2.0, 11.0 - crouch, 9.5, 16.5 - crouch, 2.0, p[5], p[4]);
      rig.box(6.8, 20.2 - crouch, 8.2, 5.8, p[24], highlight: p[22], shade: p[25]);
    }

    if (e.isShieldedFront) {
      rig.box(5.2, 17.0 - crouch, 4.8, 15.5, p[24], highlight: p[26], shade: p[25]);
    }
  }

  /// 15. `rival_mateo` — Spiky raven hair, cobalt-silver duelist coat, streaming cyan scarf & Kampilan katana!
  static void _paintRivalMateo(
    Canvas canvas,
    _PxRig rig,
    DungeonEntityRenderSpec e,
    double stride,
    double crouch,
    bool isWindup,
    bool isAttack,
    double worldTimeSec,
  ) {
    final p = SpriteCastPalette.endesga32;
    // Dash afterimage clones when Mateo lunges at high speed!
    if (e.vx.abs() > 85.0 || isAttack) {
      final dir = e.facing >= 0 ? 1.0 : -1.0;
      for (var g = 1; g <= 2; g++) {
        _fill.color = p[18].withValues(alpha: 0.24 / g);
        canvas.drawRect(
          e.hitbox.shift(Offset(-dir * g * 5.5, 0)),
          _fill,
        );
      }
    }

    // Long 4-segment streaming neon-cyan scarf!
    final scarfWave = math.sin(worldTimeSec * 12.0) * 1.8;
    for (var seg = 0; seg < 4; seg++) {
      rig.box(
        -3.5 - seg * 3.0,
        14.2 - crouch - seg * 0.6 + scarfWave * (seg * 0.35),
        3.6,
        2.2,
        seg.isEven ? p[18] : p[17],
        highlight: p[19],
      );
    }

    rig.legs(stride: isAttack ? 1.3 : stride, crouch: crouch, legColor: p[24], bootColor: p[20]);
    // Tailored cobalt-and-silver duelist coat
    rig.box(-4.2, 13.2 - crouch, 8.4, 7.2, p[16], highlight: p[17], shade: p[24]);
    rig.box(-1.6, 12.8 - crouch, 3.2, 6.2, p[20], highlight: p[19], outline: false); // silver lapel trim
    // Head + spiky raven-indigo hair + determined eyes
    rig.box(-3.6, 18.0 - crouch, 7.2, 5.2, p[3], highlight: p[30]);
    rig.box(-4.4, 20.5 - crouch, 8.8, 3.4, p[24], highlight: p[23]); // spiky hair crown
    rig.box(-5.6, 19.2 - crouch, 2.8, 2.2, p[24]); // back hair spikes
    rig.box(1.5, 21.2 - crouch, 3.2, 1.8, p[16]); // front bangs spike
    rig.eye(1.5, 16.0 - crouch, p[18]);

    // Poised silver-cyan Kampilan Katana
    if (isWindup) {
      // Iaido sheath-draw crouch!
      rig.blade(-9.5, 10.5 - crouch, 2.0, 9.5 - crouch, 1.8, p[18], p[19]);
    } else if (isAttack) {
      rig.blade(2.5, 10.5 - crouch, 17.0, 11.2 - crouch, 2.2, p[18], p[19]);
    } else {
      rig.blade(2.0, 9.8 - crouch, 12.5, 14.8 - crouch, 1.8, p[20], p[19]);
    }
  }

  // ═══════════════════════════════════════════════════════════════════════════
  //  ALL 7 MULTI-PHASE ERA BOSSES (SHOWPIECE PIXEL CHARACTERS)
  // ═══════════════════════════════════════════════════════════════════════════

  /// ACT I BOSS — `boss_datu_makisig` (22×26): Horned gold Putong, tattooed warrior-chief, royal cape & flaming Kampilan!
  static void _paintBossDatuMakisig(
    _PxRig rig,
    DungeonEntityRenderSpec e,
    double stride,
    double crouch,
    bool isWindup,
    bool isAttack,
    double worldTimeSec,
  ) {
    final p = SpriteCastPalette.endesga32;
    rig.cape(topY: 20.0 - crouch, length: 15.0, sway: math.sin(worldTimeSec * 6.5) * 2.2, color: p[7], shade: p[6]);
    rig.legs(stride: stride, crouch: crouch, legColor: p[3], bootColor: p[10], thick: 3.4, spread: 3.8, height: 7.5);
    // Crimson-and-gold royal bahag + tattooed warrior chest + golden armlets
    rig.box(-6.5, 10.5 - crouch, 13.0, 4.2, p[7], highlight: p[10], shade: p[6]);
    rig.box(-7.2, 19.5 - crouch, 14.4, 9.5, p[4], highlight: p[3], shade: p[5]);
    // Sacred cyan-gold Batok shoulder & chest tattoo markings
    rig.box(-6.2, 17.8 - crouch, 3.0, 1.6, p[18], outline: false);
    rig.box(3.2, 17.8 - crouch, 3.0, 1.6, p[18], outline: false);
    rig.box(-2.0, 15.5 - crouch, 4.0, 1.4, p[10], outline: false);
    // Noble head + Horned Golden Putong War-Crown!
    rig.box(-4.6, 25.0 - crouch, 9.2, 6.2, p[3], highlight: p[30], shade: p[4]);
    rig.box(-5.6, 26.8 - crouch, 11.2, 2.8, p[10], highlight: p[11], shade: p[9]);
    rig.blade(-4.8, 26.2 - crouch, -7.8, 30.5 - crouch, 2.0, p[10], p[11]); // left gold horn
    rig.blade(4.8, 26.2 - crouch, 7.8, 30.5 - crouch, 2.0, p[10], p[11]); // right gold horn
    rig.eye(2.0, 22.4 - crouch, e.bossPhase >= 2 ? p[11] : p[25]);

    // Giant carved Kampilan greatsword (ignites with blazing fire in Phase 2!)
    final bladeEdge = e.bossPhase >= 2 ? p[9] : p[20];
    final bladeCore = e.bossPhase >= 2 ? p[11] : p[19];
    if (isWindup) {
      rig.blade(-2.0, 16.5 - crouch, -11.5, 29.5 - crouch, 3.2, bladeEdge, bladeCore);
    } else if (isAttack) {
      rig.blade(3.5, 13.5 - crouch, 22.5, 11.5 - crouch, 3.6, bladeEdge, bladeCore);
    } else {
      rig.blade(3.0, 13.5 - crouch, 16.5, 23.5 - crouch, 3.0, bladeEdge, bladeCore);
    }
  }

  /// ACT II BOSS — `boss_valdes` (24×28): Gilded conquistador plate, scarlet plume, Lion Royal Shield & crackling rapier-lance!
  static void _paintBossValdes(
    _PxRig rig,
    DungeonEntityRenderSpec e,
    double stride,
    double crouch,
    bool isWindup,
    bool isAttack,
    double worldTimeSec,
  ) {
    final p = SpriteCastPalette.endesga32;
    rig.cape(topY: 21.5 - crouch, length: 16.5, sway: math.sin(worldTimeSec * 6.0) * 2.0, color: p[7], shade: p[24]);
    rig.legs(stride: stride * 0.8, crouch: crouch, legColor: p[22], bootColor: p[10], thick: 3.6, spread: 4.0, height: 8.0);
    // Gilded steel conquistador breastplate + crimson velvet tassets
    rig.box(-7.5, 11.2 - crouch, 15.0, 4.0, p[7], highlight: p[10]);
    rig.box(-7.8, 20.8 - crouch, 15.6, 10.2, p[21], highlight: p[19], shade: p[23]);
    rig.box(-3.2, 19.2 - crouch, 6.4, 7.2, p[10], highlight: p[11], outline: false); // gold filigree chest
    // Ornate Cabasset helmet + sweeping tall scarlet plume
    rig.box(-5.2, 26.8 - crouch, 10.4, 6.5, p[20], highlight: p[19], shade: p[22]);
    rig.box(-6.8, 24.5 - crouch, 13.6, 2.2, p[10], highlight: p[11]); // gilded brim
    rig.box(-6.5, 31.2 - crouch, 8.5, 4.8, p[8], highlight: p[9], shade: p[7]); // tall scarlet plume!
    rig.eye(2.2, 23.2 - crouch, p[26]);

    // Crackling amber-gold Rapier-Lance
    final reach = isAttack ? 9.5 : (isWindup ? -4.5 : 0.0);
    rig.box(3.5 + reach, 15.5 - crouch, 3.6, 4.4, p[10], highlight: p[11]); // bell guard
    rig.blade(5.5 + reach, 13.5 - crouch, 22.0 + reach, 13.5 - crouch, 2.4, p[10], p[19]);

    // Embossed Lion Royal Shield
    if (e.isShieldedFront) {
      rig.box(4.8, 19.5 - crouch, 5.6, 17.5, p[7], highlight: p[10], shade: p[6]);
      rig.box(6.0, 15.8 - crouch, 3.2, 8.5, p[11], highlight: p[19], outline: false);
    }
  }

  /// ACT III BOSS — `boss_calderon` (22×28): Levitating Malolos statesman, twin luminous parchment-scroll wings & Quill-Spear!
  static void _paintBossCalderon(
    _PxRig rig,
    DungeonEntityRenderSpec e,
    double crouch,
    bool isWindup,
    bool isAttack,
    double worldTimeSec,
  ) {
    final p = SpriteCastPalette.endesga32;
    final hover = math.sin(worldTimeSec * 4.5) * 2.2;
    final wingFlap = math.sin(worldTimeSec * 6.5) * 2.5;

    // Orbiting 1899 Malolos Golden Sun-Ring behind head
    rig.gear(0.0, 24.5 + hover, e.bossPhase >= 2 ? 9.5 : 7.2, worldTimeSec * 2.4, p[11], p[10]);

    // Twin unfurled luminous Parchment-Scroll Wings inscribed with cyan Charter runes!
    for (final side in const <double>[-1.0, 1.0]) {
      rig.box(side * 10.5 - 3.5, 22.5 + hover + side * wingFlap * 0.4, 7.0, 13.5, p[2], highlight: p[19], shade: p[3]);
      rig.box(side * 10.5 - 2.2, 19.5 + hover, 4.4, 1.4, p[18], outline: false);
      rig.box(side * 10.5 - 2.2, 16.5 + hover, 4.4, 1.4, p[18], outline: false);
    }

    // Floating indigo-and-gold 1899 statesman coat + sash
    rig.box(-6.0, 14.5 + hover - crouch, 12.0, 11.5, p[24], highlight: p[16], shade: p[25]);
    rig.blade(-4.5, 14.0 + hover - crouch, 4.5, 5.5 + hover - crouch, 2.2, p[10], p[11]); // republic sash
    rig.box(-4.4, 24.5 + hover - crouch, 8.8, 6.2, p[3], highlight: p[30]);
    rig.box(-4.8, 26.8 + hover - crouch, 9.6, 2.8, p[24], highlight: p[23]); // formal hair
    rig.eye(1.8, 21.8 + hover - crouch, p[18]);

    // Giant Golden Quill-Spear!
    final castShift = isAttack ? 6.5 : (isWindup ? -3.0 : 0.0);
    rig.blade(-4.0 + castShift, 12.5 + hover, 12.5 + castShift, 15.5 + hover, 2.2, p[10], p[11]);
    rig.blade(9.5 + castShift, 14.8 + hover, 19.5 + castShift, 17.2 + hover, 3.2, p[18], p[19]); // feather plume nib!
  }

  /// ACT IV BOSS — `boss_commonwealth_warden` (26×30): Winged Art-Deco colossus, sunburst crown, clockwork halos & gavel-blade!
  static void _paintBossCommonwealthWarden(
    _PxRig rig,
    DungeonEntityRenderSpec e,
    double stride,
    double crouch,
    bool isWindup,
    bool isAttack,
    double worldTimeSec,
  ) {
    final p = SpriteCastPalette.endesga32;
    // Twin counter-rotating brass clockwork halo gears behind shoulders
    final spin = worldTimeSec * (e.bossPhase >= 2 ? 5.5 : 2.8);
    rig.gear(-8.5, 23.5 - crouch, 6.2, spin, p[10], p[4]);
    rig.gear(8.5, 23.5 - crouch, 6.2, -spin, p[10], p[4]);

    // Stepped geometric Art-Deco bronze wings
    rig.blade(-5.0, 19.0 - crouch, -15.5, 26.5 - crouch, 4.2, p[10], p[11]);
    rig.blade(5.0, 19.0 - crouch, 15.5, 26.5 - crouch, 4.2, p[10], p[11]);

    rig.legs(stride: stride * 0.7, crouch: crouch, legColor: p[22], bootColor: p[10], thick: 4.0, spread: 4.5, height: 8.5);
    // Art-Deco bronze-and-cobalt colossus chassis + glowing cyan chevron core
    rig.box(-8.5, 22.0 - crouch, 17.0, 13.5, p[16], highlight: p[20], shade: p[23]);
    rig.box(-5.2, 20.2 - crouch, 10.4, 9.2, p[10], highlight: p[11], shade: p[4]);
    rig.box(-2.6, 17.8 - crouch, 5.2, 4.8, p[18], highlight: p[19]);
    // Sunburst Art-Deco Helm
    rig.box(-5.2, 28.2 - crouch, 10.4, 6.8, p[20], highlight: p[19], shade: p[22]);
    rig.box(-1.6, 31.8 - crouch, 3.2, 4.2, p[11], highlight: p[19]); // central sunburst spire
    rig.box(-3.6, 25.4 - crouch, 7.6, 2.0, p[18], highlight: p[19], outline: false);

    // Seismic Constitutional Gavel-Greatsword
    if (isWindup) {
      rig.blade(0.0, 18.0 - crouch, -5.5, 33.5 - crouch, 2.8, p[10], p[11]);
      rig.box(-10.5, 36.5 - crouch, 10.5, 6.2, p[10], highlight: p[19], shade: p[4]);
    } else if (isAttack) {
      rig.blade(3.0, 14.5 - crouch, 19.5, 6.5, 2.8, p[18], p[19]);
      rig.box(16.0, 10.8, 10.5, 6.5, p[10], highlight: p[19], shade: p[4]);
    } else {
      rig.blade(2.5, 14.5 - crouch, 15.5, 23.5 - crouch, 2.6, p[10], p[11]);
      rig.box(12.2, 27.5 - crouch, 9.6, 5.8, p[10], highlight: p[18], shade: p[4]);
    }

    if (e.isShieldedFront) {
      rig.box(6.0, 20.5 - crouch, 5.5, 18.5, p[23], highlight: p[18], shade: p[24]);
    }
  }

  /// ACT V BOSS — `boss_imperial_commander` (24×28): Fortress general, battle greatcoat, twin dorsal mortar pods & heated sabre!
  static void _paintBossImperialCommander(
    _PxRig rig,
    DungeonEntityRenderSpec e,
    double stride,
    double crouch,
    bool isWindup,
    bool isAttack,
    double worldTimeSec,
  ) {
    final p = SpriteCastPalette.endesga32;
    rig.cape(topY: 21.0 - crouch, length: 16.5, sway: math.sin(worldTimeSec * 7.5) * 2.4, color: p[6], shade: p[25]);

    // Twin shoulder-mounted dorsal artillery mortar tubes!
    rig.blade(-5.5, 20.5 - crouch, -9.5, 28.5 - crouch, 3.4, p[23], p[21]);
    rig.blade(1.5, 20.5 - crouch, -1.5, 29.0 - crouch, 3.4, p[23], p[21]);
    if (e.bossPhase >= 2 || isWindup) {
      rig.box(-10.8, 30.2 - crouch, 3.2, 2.8, p[9], highlight: p[11]);
      rig.box(-2.8, 30.8 - crouch, 3.2, 2.8, p[9], highlight: p[11]);
    }

    rig.legs(stride: stride, crouch: crouch, legColor: p[6], bootColor: p[25], thick: 3.6, spread: 4.0, height: 8.0);
    // Armored crimson-lined fortress greatcoat + medals
    rig.box(-7.6, 20.8 - crouch, 15.2, 11.2, p[6], highlight: p[5], shade: p[25]);
    rig.box(-2.8, 19.5 - crouch, 5.6, 9.0, p[8], highlight: p[9], outline: false);
    // Peaked officer visor cap + glowing tactical eye
    rig.box(-4.6, 25.8 - crouch, 9.2, 5.6, p[3], shade: p[4]);
    rig.box(-5.6, 28.2 - crouch, 11.6, 3.2, p[6], highlight: p[8]);
    rig.box(-1.0, 27.6 - crouch, 2.4, 2.0, p[10], highlight: p[11]); // gold star insignia
    rig.eye(2.2, 23.2 - crouch, p[9]);

    // Superheated orange-edged Fortress Sabre!
    if (isWindup) {
      rig.blade(-2.5, 16.5 - crouch, -11.0, 27.5 - crouch, 2.8, p[9], p[11]);
    } else if (isAttack) {
      rig.blade(3.5, 14.0 - crouch, 22.5, 12.0 - crouch, 3.2, p[9], p[19]);
    } else {
      rig.blade(3.0, 13.5 - crouch, 17.5, 21.5 - crouch, 2.6, p[9], p[11]);
    }
  }

  /// ACT VI BOSS — `boss_iron_censor` (28×32): 3-Phase chained obsidian inquisitor, ruby cyclops mask & hovering Decree Monoliths!
  static void _paintBossIronCensor(
    _PxRig rig,
    DungeonEntityRenderSpec e,
    double stride,
    double crouch,
    bool isWindup,
    bool isAttack,
    double worldTimeSec,
  ) {
    final p = SpriteCastPalette.endesga32;
    rig.cape(topY: 24.5 - crouch, length: 19.5, sway: math.sin(worldTimeSec * 5.8) * 2.5, color: p[24], shade: p[25]);
    rig.legs(stride: stride * 0.6, crouch: crouch, legColor: p[24], bootColor: p[25], thick: 4.2, spread: 4.6, height: 8.5);

    // Chained obsidian inquisitor plate + glowing crimson censorship seal
    rig.box(-8.8, 23.5 - crouch, 17.6, 14.2, p[24], highlight: p[23], shade: p[25]);
    rig.blade(-7.5, 21.5 - crouch, 7.5, 12.5 - crouch, 1.8, p[21], p[20]); // crossed iron chains!
    rig.blade(-7.5, 12.5 - crouch, 7.5, 21.5 - crouch, 1.8, p[21], p[20]);
    rig.box(-2.8, 19.0 - crouch, 5.6, 5.6, p[26], highlight: p[19]); // blazing ruby core

    // Horned Iron Cyclops Mask with burning neon-ruby eye!
    rig.box(-5.5, 30.2 - crouch, 11.0, 7.2, p[23], highlight: p[21], shade: p[25]);
    rig.blade(-4.8, 29.5 - crouch, -8.5, 35.5 - crouch, 2.2, p[24], p[26]);
    rig.blade(4.8, 29.5 - crouch, 8.5, 35.5 - crouch, 2.2, p[24], p[26]);
    rig.box(-1.5, 27.6 - crouch, 4.6, 2.8, p[26], highlight: p[19]); // cyclops eye!

    // Hovering black-and-ruby Decree Monolith slabs (2 in Phase 1-2, 3 in Phase 3!)
    final slabCount = e.bossPhase >= 3 ? 3 : 2;
    for (var m = 0; m < slabCount; m++) {
      final bob = math.sin(worldTimeSec * 5.5 + m * 2.1) * 2.6;
      final mx = m == 0 ? 9.5 : (m == 1 ? -11.5 : 0.0);
      final my = (m == 2 ? 36.5 : 21.5) + bob - crouch;
      rig.box(mx, my, 4.6, 11.5, p[25], highlight: p[26], shade: p[24]);
      rig.box(mx + 1.2, my - 2.2, 2.2, 6.5, p[26], outline: false);
    }

    if (isAttack) {
      rig.blade(5.0, 16.0 - crouch, 24.0, 15.0 - crouch, 3.8, p[26], p[19]);
    }
  }

  /// ACT VII FINALE BOSS — `boss_sovereign_guardian` (30×34):
  /// Genuine `pixelfx` 48-frame rotating `sunburst` halo, 3 orbiting Philippine stars,
  /// unfurling radiant wings across Phases 1–3, and blazing Sovereign Sun-Spear!
  static void _paintBossSovereignGuardian(
    Canvas canvas,
    _PxRig rig,
    DungeonEntityRenderSpec e,
    double stride,
    double crouch,
    bool isWindup,
    bool isAttack,
    double worldTimeSec,
    DungeonPixelfxSheetCache cache,
  ) {
    final p = SpriteCastPalette.endesga32;
    final hb = e.hitbox;
    final hover = math.sin(worldTimeSec * 4.2) * 1.8;

    // 1. Genuine `pixelfx` 48-frame golden `sunburst` halo behind the Sovereign Guardian!
    final sunScale = e.bossPhase >= 3 ? 0.56 : (e.bossPhase == 2 ? 0.46 : 0.38);
    final drewSun = cache.drawSheetFrame(
      canvas: canvas,
      reusablePaint: _imgPaint,
      key: 'sunburst',
      worldX: hb.center.dx,
      worldY: hb.center.dy - 4.0 + hover,
      frameIndex: (worldTimeSec * 12.0).floor(),
      scale: sunScale,
      opacity: 0.92,
      blendMode: BlendMode.plus,
    );
    if (!drewSun) {
      rig.gear(0.0, 22.0 + hover, 13.0, worldTimeSec * 2.2, p[11], p[10]);
    }

    // 2. Unfurling Feathered Golden-Ivory Wings (grow broader across Phases 1 -> 2 -> 3!)
    final wingSpan = e.bossPhase >= 3 ? 21.0 : (e.bossPhase == 2 ? 17.5 : 14.0);
    final flap = math.sin(worldTimeSec * 6.0) * 3.0;
    for (final s in const <double>[-1.0, 1.0]) {
      rig.blade(s * 4.5, 22.5 + hover, s * wingSpan, 31.5 + hover + flap, 4.6, p[10], p[11]);
      rig.blade(s * 4.5, 19.5 + hover, s * (wingSpan - 2.5), 24.5 + hover + flap * 0.6, 3.8, p[11], p[19]);
      if (e.bossPhase >= 2) {
        rig.blade(s * 4.0, 16.5 + hover, s * (wingSpan - 5.0), 17.5 + hover + flap * 0.3, 3.2, p[18], p[19]);
      }
    }

    // 3. Royal Philippine Tricolor Mantle (Azure, Crimson & Gold)
    rig.cape(topY: 24.0 + hover - crouch, length: 20.0, sway: math.sin(worldTimeSec * 6.5) * 2.2, color: p[16], shade: p[7]);
    rig.legs(stride: stride * 0.6, crouch: crouch, legColor: p[20], bootColor: p[10], thick: 4.0, spread: 4.5, height: 8.5);

    // 4. Radiant Golden-and-Ivory Sovereign Armor + 8-Ray Sun Breastplate
    rig.box(-8.5, 24.5 + hover - crouch, 17.0, 14.5, p[10], highlight: p[11], shade: p[9]);
    rig.box(-5.2, 22.5 + hover - crouch, 10.4, 10.5, p[19], highlight: p[11], shade: p[20]);
    rig.box(-2.4, 19.5 + hover - crouch, 4.8, 4.8, p[11], highlight: p[19]); // blazing sun heart!

    // 5. Crowned 1987 Sovereign Helm
    rig.box(-5.4, 31.2 + hover - crouch, 10.8, 7.0, p[10], highlight: p[19], shade: p[9]);
    rig.box(-6.8, 33.0 + hover - crouch, 13.6, 2.6, p[11], highlight: p[19]); // royal crown band
    rig.box(-1.6, 36.8 + hover - crouch, 3.2, 4.2, p[19], highlight: p[11]); // central crown spire
    rig.box(-3.6, 28.4 + hover - crouch, 7.6, 2.0, p[18], highlight: p[19], outline: false);

    // 6. 3 Orbiting Golden Stars (Luzon, Visayas, Mindanao!)
    for (var star = 0; star < 3; star++) {
      final a = worldTimeSec * 3.8 + star * (math.pi * 2 / 3);
      final sx = hb.center.dx + math.cos(a) * 18.0;
      final sy = hb.top - 2.0 + hover + math.sin(a) * 5.0;
      _fill.color = SpriteCastPalette.ink;
      canvas.drawRect(Rect.fromCenter(center: Offset(sx, sy), width: 4.6, height: 4.6), _fill);
      _fill.color = p[11];
      canvas.drawRect(Rect.fromCenter(center: Offset(sx, sy), width: 3.0, height: 3.0), _fill);
    }

    // 7. Blazing Sovereign Sun-Spear!
    if (isWindup) {
      rig.blade(-4.0, 20.0 + hover - crouch, -14.5, 34.5 + hover - crouch, 3.2, p[11], p[19]);
    } else if (isAttack) {
      rig.blade(2.5, 17.5 + hover - crouch, 26.5, 16.5 + hover - crouch, 3.8, p[11], p[19]);
    } else {
      rig.blade(-3.5, 14.5 + hover - crouch, 20.5, 26.5 + hover - crouch, 3.0, p[10], p[19]);
    }
  }
}

/// Zero-allocation local coordinate pixel-art body builder (`originX`, `feetY`, `facing`).
///
/// Automatically mirrors horizontal coordinates when `facing < 0`, draws `1px` dark-ink
/// outlines (`pixelfx` `Grid.outline` craft), top-left highlights, and 1-frame white hit-flashes.
class _PxRig {
  final Canvas canvas;
  final double originX;
  final double feetY;
  final int facing;
  final bool isFlashing;
  final bool isWindup;
  final double windupPulse;

  static final Paint _p = Paint()..style = PaintingStyle.fill;
  static final Paint _s = Paint()
    ..style = PaintingStyle.stroke
    ..strokeCap = StrokeCap.square;

  const _PxRig({
    required this.canvas,
    required this.originX,
    required this.feetY,
    required this.facing,
    required this.isFlashing,
    required this.isWindup,
    required this.windupPulse,
  });

  Color _tint(Color c) {
    if (isFlashing) return SpriteCastPalette.endesga32[19];
    if (isWindup) {
      return Color.lerp(c, SpriteCastPalette.endesga32[11], 0.32 * windupPulse)!;
    }
    return c;
  }

  /// Draws a pixel-snapped rectangle where [localLeft] is relative to [originX] (facing right)
  /// and [topAboveFeet] is distance above [feetY]. Automatically flips horizontally when `facing < 0`.
  void box(
    double localLeft,
    double topAboveFeet,
    double width,
    double height,
    Color fill, {
    Color? highlight,
    Color? shade,
    bool outline = true,
  }) {
    final worldLeft = facing >= 0
        ? originX + localLeft
        : originX - localLeft - width;
    final worldTop = feetY - topAboveFeet;
    final r = Rect.fromLTWH(worldLeft, worldTop, width, height);

    if (outline) {
      _p.color = isFlashing ? SpriteCastPalette.endesga32[19] : SpriteCastPalette.ink;
      canvas.drawRect(r.inflate(0.9), _p);
    }
    _p.color = _tint(fill);
    canvas.drawRect(r, _p);

    if (!isFlashing && shade != null && height >= 3.0) {
      _p.color = _tint(shade);
      canvas.drawRect(Rect.fromLTWH(r.left, r.bottom - 1.2, r.width, 1.2), _p);
    }
    if (!isFlashing && highlight != null && height >= 2.4) {
      _p.color = _tint(highlight);
      canvas.drawRect(Rect.fromLTWH(r.left, r.top, r.width * 0.78, 1.1), _p);
    }
  }

  /// Draws a crisp pixel eye dot facing the player.
  void eye(double localX, double aboveFeet, Color color) {
    box(localX, aboveFeet, 1.8, 1.8, color, outline: false);
  }

  /// Draws an outlined weapon shaft or blade from `(x0, y0)` to `(x1, y1)` in local feet-up coordinates.
  void blade(
    double x0,
    double y0,
    double x1,
    double y1,
    double thickness,
    Color edgeColor,
    Color coreColor,
  ) {
    final p0 = Offset(originX + facing * x0, feetY - y0);
    final p1 = Offset(originX + facing * x1, feetY - y1);
    _s
      ..color = isFlashing ? SpriteCastPalette.endesga32[19] : SpriteCastPalette.ink
      ..strokeWidth = thickness + 1.6;
    canvas.drawLine(p0, p1, _s);
    _s
      ..color = _tint(edgeColor)
      ..strokeWidth = thickness;
    canvas.drawLine(p0, p1, _s);
    _s
      ..color = _tint(coreColor)
      ..strokeWidth = math.max(0.8, thickness * 0.48);
    canvas.drawLine(p0, p1, _s);
  }

  /// Draws two articulated pixel legs + boots with stride & crouch animation.
  void legs({
    required double stride,
    required double crouch,
    required Color legColor,
    required Color bootColor,
    double thick = 2.4,
    double spread = 2.4,
    double height = 5.5,
  }) {
    final h = math.max(2.5, height - crouch * 0.5);
    final backX = -spread - stride * 2.0;
    final frontX = spread - thick + stride * 2.0;
    final backLift = stride < 0 ? (-stride * 1.4) : 0.0;
    final frontLift = stride > 0 ? (stride * 1.4) : 0.0;

    box(backX, h + backLift, thick, h, legColor);
    box(backX - 0.3, 2.0 + backLift, thick + 1.0, 2.0, bootColor);

    box(frontX, h + frontLift, thick, h, legColor, highlight: legColor);
    box(frontX - 0.2, 2.0 + frontLift, thick + 1.2, 2.0, bootColor);
  }

  /// Draws a 3-segment billowing cape or long coat-tail behind the character.
  void cape({
    required double topY,
    required double length,
    required double sway,
    required Color color,
    required Color shade,
  }) {
    final segH = length / 3.0;
    for (var i = 0; i < 3; i++) {
      box(
        -5.5 - i * 1.4 - sway * (i * 0.35),
        topY - i * (segH - 0.8),
        4.6 + i * 0.6,
        segH + 1.0,
        i == 2 ? shade : color,
        shade: shade,
      );
    }
  }

  /// Draws a rotating clockwork gear / sacred sun-ring at `(localX, aboveFeet)`.
  void gear(
    double localX,
    double aboveFeet,
    double radius,
    double angleRad,
    Color rimColor,
    Color spokeColor,
  ) {
    final c = Offset(originX + facing * localX, feetY - aboveFeet);
    _s
      ..color = isFlashing ? SpriteCastPalette.endesga32[19] : SpriteCastPalette.ink
      ..strokeWidth = 2.8;
    canvas.drawCircle(c, radius, _s);
    for (var k = 0; k < 4; k++) {
      final a = angleRad + k * (math.pi / 4);
      final dx = math.cos(a) * (radius + 1.6);
      final dy = math.sin(a) * (radius + 1.6);
      _s
        ..color = _tint(spokeColor)
        ..strokeWidth = 1.6;
      canvas.drawLine(c - Offset(dx, dy), c + Offset(dx, dy), _s);
    }
    _s
      ..color = _tint(rimColor)
      ..strokeWidth = 1.5;
    canvas.drawCircle(c, radius, _s);
  }
}
