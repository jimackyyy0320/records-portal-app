import 'dart:math' as math;
import 'dart:ui' as ui;
import 'package:flutter/material.dart';

import '../school_lobby_avatar.dart';
import '../spritecast_engine.dart';
import 'dungeon_combat.dart';
import 'dungeon_enemy_sprites.dart';
import 'dungeon_models.dart';
import 'dungeon_pixelfx_vfx.dart';

/// Lightweight particle burst element for dust puffs, sparks, bloodless silk shards,
/// crate splinters, and campfire embers (`craft-game-floors` VFX Floor).
class DungeonParticle {
  double x;
  double y;
  double vx;
  double vy;
  double size;
  Color color;
  double ageSec;
  final double lifeSec;
  final double gravityScale;

  DungeonParticle({
    required this.x,
    required this.y,
    required this.vx,
    required this.vy,
    required this.size,
    required this.color,
    this.ageSec = 0.0,
    this.lifeSec = 0.42,
    this.gravityScale = 0.6,
  });

  bool get isExpired => ageSec >= lifeSec;
  double get alpha => (1.0 - (ageSec / lifeSec)).clamp(0.0, 1.0);
}

/// Decoupled render descriptor for Part 4 enemies, Rival Mateo, and 7 Era Bosses
/// so [DungeonWorldPainter] renders them in the exact same pixel-perfect pass.
class DungeonEntityRenderSpec {
  final String id;
  final String archetypeId;
  final Rect hitbox;
  final int facing;
  final int hp;
  final int maxHp;
  final bool isBoss;
  final bool isShieldedFront;
  final bool isTelegraphing;
  final bool isStaggered;
  final double hitFlashTimer;
  final Color primaryColor;
  final Color accentColor;
  final double animPhase;
  final Offset? aimTelegraphEnd;
  final String aiStateName;
  final int bossPhase;
  final double stateTimer;
  final double vx;
  final double vy;
  final bool isFlying;
  final bool isRival;
  final String bossAttackName;

  const DungeonEntityRenderSpec({
    required this.id,
    required this.archetypeId,
    required this.hitbox,
    required this.facing,
    required this.hp,
    required this.maxHp,
    required this.primaryColor,
    required this.accentColor,
    this.isBoss = false,
    this.isShieldedFront = false,
    this.isTelegraphing = false,
    this.isStaggered = false,
    this.hitFlashTimer = 0.0,
    this.animPhase = 0.0,
    this.aimTelegraphEnd,
    this.aiStateName = 'patrol',
    this.bossPhase = 1,
    this.stateTimer = 0.0,
    this.vx = 0.0,
    this.vy = 0.0,
    this.isFlying = false,
    this.isRival = false,
    this.bossAttackName = 'dashThrust',
  });
}

/// 2D Platformer Follow Camera Rig (`craft-game-floors` `camera-rigs.md` + `2d-pixel-perfect`).
///
/// Features:
/// - `0.1 × 0.1` viewport deadzone so tiny micro-steps never jitter the frame
/// - Directional velocity look-ahead (`±38 px`) along horizontal travel
/// - Asymmetric damping (smooth horizontal glide, crisp vertical follow)
/// - Chamber boundary clamping + impulse-driven directional screenshake
/// - Visible tile viewport culling (`visibleTileBounds`) for 60 FPS mobile performance
class DungeonCameraRig {
  double x; // Camera top-left world X
  double y; // Camera top-left world Y
  double lookAheadX = 0.0;
  double shakeIntensity = 0.0;
  double _shakeTime = 0.0;

  DungeonCameraRig({this.x = 0.0, this.y = 0.0});

  /// Snaps camera cleanly to center on [player] upon entering a new chamber.
  void snapTo(
    DungeonPlayerPhysicsState player,
    DungeonChamberSpec spec,
  ) {
    lookAheadX = player.facing * 24.0;
    final desiredX = player.centerX + lookAheadX - kDungeonRefWidth * 0.5;
    final desiredY = player.centerY - kDungeonRefHeight * 0.54;
    x = _clampAxis(desiredX, spec.worldWidth, kDungeonRefWidth);
    y = _clampAxis(desiredY, spec.worldHeight, kDungeonRefHeight);
    shakeIntensity = 0.0;
  }

  /// Adds an impulse screenshake kick (takes max so strong boss hits dominate).
  void addShake(double intensity) {
    if (intensity > shakeIntensity) {
      shakeIntensity = intensity.clamp(0.0, 9.0);
    }
  }

  /// Smoothly updates camera follow, look-ahead, boundary clamping, and shake decay.
  void update({
    required double dt,
    required DungeonPlayerPhysicsState player,
    required DungeonChamberSpec spec,
  }) {
    final safeDt = dt.clamp(0.0, 0.05);
    _shakeTime += safeDt;

    // 1. Directional velocity look-ahead (`camera-rigs.md`: 0.5–1s ahead along velocity)
    final targetLookAhead = player.vx.abs() > 20.0
        ? (player.vx * 0.22).clamp(-42.0, 42.0)
        : player.facing * 20.0;
    lookAheadX += (targetLookAhead - lookAheadX) * math.min(1.0, safeDt * 4.8);

    final targetCenterX = player.centerX + lookAheadX;
    final targetCenterY = player.centerY - 8.0; // slight upward bias (player in lower-middle third)

    final curCenterX = x + kDungeonRefWidth * 0.5;
    final curCenterY = y + kDungeonRefHeight * 0.5;

    // 2. Deadzone (`0.1 × 0.1` of `320×180` reference viewport)
    const deadHalfW = kDungeonRefWidth * 0.05;
    const deadHalfH = kDungeonRefHeight * 0.05;
    var desiredX = x;
    var desiredY = y;

    if ((targetCenterX - curCenterX).abs() > deadHalfW) {
      final edgeX = targetCenterX > curCenterX
          ? targetCenterX - deadHalfW
          : targetCenterX + deadHalfW;
      desiredX = edgeX - kDungeonRefWidth * 0.5;
    }
    if ((targetCenterY - curCenterY).abs() > deadHalfH) {
      final edgeY = targetCenterY > curCenterY
          ? targetCenterY - deadHalfH
          : targetCenterY + deadHalfH;
      desiredY = edgeY - kDungeonRefHeight * 0.5;
    }

    // 3. Asymmetric damping (loose horizontal, crisp vertical for platforming!)
    x += (desiredX - x) * math.min(1.0, safeDt * 7.8);
    y += (desiredY - y) * math.min(1.0, safeDt * (player.vy > 140.0 ? 13.5 : 10.2));

    x = _clampAxis(x, spec.worldWidth, kDungeonRefWidth);
    y = _clampAxis(y, spec.worldHeight, kDungeonRefHeight);

    // 4. Exponential screenshake decay
    if (shakeIntensity > 0.05) {
      shakeIntensity *= math.pow(0.0012, safeDt).toDouble();
    } else {
      shakeIntensity = 0.0;
    }
  }

  /// Current pixel-snapped camera offset including active directional screenshake.
  Offset get snappedOffset {
    var sx = 0.0;
    var sy = 0.0;
    if (shakeIntensity > 0.05) {
      sx = math.sin(_shakeTime * 74.0) * shakeIntensity;
      sy = math.cos(_shakeTime * 91.0) * shakeIntensity * 0.72;
    }
    return Offset((x + sx).roundToDouble(), (y + sy).roundToDouble());
  }

  /// Returns inclusive `(minCol, maxCol, minRow, maxRow)` tile bounds currently visible
  /// inside the camera viewport (with a 1-tile safety margin for smooth scrolling).
  ({int minCol, int maxCol, int minRow, int maxRow}) visibleTileBounds(
    int cols,
    int rows,
  ) {
    if (cols <= 0 || rows <= 0) {
      return (minCol: 0, maxCol: -1, minRow: 0, maxRow: -1);
    }
    final minC = ((x / kDungeonTileSize).floor() - 1).clamp(0, cols - 1);
    final maxC = (((x + kDungeonRefWidth) / kDungeonTileSize).ceil() + 1)
        .clamp(0, cols - 1);
    final minR = ((y / kDungeonTileSize).floor() - 1).clamp(0, rows - 1);
    final maxR = (((y + kDungeonRefHeight) / kDungeonTileSize).ceil() + 1)
        .clamp(0, rows - 1);
    return (minCol: minC, maxCol: maxC, minRow: minR, maxRow: maxR);
  }

  double _clampAxis(double val, double worldLen, double viewLen) {
    if (worldLen <= viewLen) {
      return (worldLen - viewLen) * 0.5;
    }
    return val.clamp(0.0, worldLen - viewLen);
  }
}

/// Computes the 4-bit cardinal Rule-Tile auto-tiling neighbor mask (`create-tile-palette-or-rule-tiles`):
/// - bit 0 (`1`): solid neighbor directly North
/// - bit 1 (`2`): solid neighbor directly East
/// - bit 2 (`4`): solid neighbor directly South
/// - bit 3 (`8`): solid neighbor directly West
int computeSolidNeighborMask(
  DungeonChamberRuntime chamber,
  int col,
  int row,
) {
  var mask = 0;
  if (_isAutoTileConnector(chamber, col, row - 1)) mask |= 1; // N
  if (_isAutoTileConnector(chamber, col + 1, row)) mask |= 2; // E
  if (_isAutoTileConnector(chamber, col, row + 1)) mask |= 4; // S
  if (_isAutoTileConnector(chamber, col - 1, row)) mask |= 8; // W
  return mask;
}

bool _isAutoTileConnector(DungeonChamberRuntime chamber, int col, int row) {
  final t = chamber.effectiveTileAt(col, row);
  return t == DungeonTileType.solidStone ||
      t == DungeonTileType.mossyStone ||
      t == DungeonTileType.secretWall;
}

/// Computes the TinyFloor 48-frame sprite strip index (`0..47`) for rendering
/// the student's custom School Lobby avatar inside the 2D action-platformer dungeon.
///
/// Dungeon-only gear (cape, forged weapon, shoulder armor crest) is composited
/// strictly by [DungeonWorldPainter] and never modifies the student's School Lobby look.
int computeDungeonHeroAvatarFrameIndex(
  DungeonPlayerPhysicsState player,
  double worldTimeSec,
) {
  final AvatarFacing facing;
  if (player.isOnLadder) {
    facing = AvatarFacing.up;
  } else {
    facing = player.facing >= 0 ? AvatarFacing.right : AvatarFacing.left;
  }

  final isMoving = player.isOnLadder
      ? player.vy.abs() > 8.0
      : (player.isDashing || !player.isGrounded || player.vx.abs() > 14.0);

  int stepFrame;
  if (player.isOnLadder) {
    stepFrame = isMoving ? (worldTimeSec * 9.0).floor() : 0;
  } else if (player.isDashing) {
    stepFrame = 2; // Dynamic forward lunge stride
  } else if (!player.isGrounded) {
    stepFrame = player.vy < 0.0 ? 1 : 4; // Rising vs falling mid-air pose
  } else if (isMoving) {
    stepFrame = (player.runAnimTime * 1.4).floor();
  } else {
    stepFrame = (worldTimeSec * 4.0).floor();
  }

  return computeCharacterFrameIndex(
    facing: facing,
    isWalking: isMoving,
    stepFrame: stepFrame.abs() % kCharFramesPerDirection,
  );
}

/// Pixel-Perfect `320×180` 2D Action-Platformer Dungeon Renderer integrating:
/// - 4-layer era-shifting parallax backdrops (Acts I–VII)
/// - 16-neighbor cardinal Rule-Tile auto-tiling with ashlar seams, mossy caps & stalactites
/// - Crisp SpriteCast pixel art for all 19 tile types (zero system emojis!)
/// - Terraria-style cavern darkness + flickering torchlight & orbiting Umalo lantern
/// - Student's custom School Lobby character sprite (`playerAvatarSheet`) with dungeon-only
///   cape, forged blade, armor trim, dash ghosts, grapple silk line, Bind cocoon & Parry dome
/// - Crescent slash arcs, 5 Silk Skill visuals, enemies/bosses, loot drops, particles & floating numbers!
class DungeonWorldPainter extends CustomPainter {
  final DungeonChamberRuntime chamber;
  final DungeonPlayerPhysicsState player;
  final DungeonCombatEngine combat;
  final DungeonProgressSave progress;
  final DungeonCameraRig camera;
  final double worldTimeSec;
  final List<DungeonEntityRenderSpec> entities;
  final List<DungeonParticle> particles;
  final Offset? highlightedGrappleAnchor;

  /// Student's composite 48-frame School Lobby avatar sheet (`AvatarSpriteCache`).
  /// When provided, the student plays Story Mode as their exact custom character
  /// while dungeon-only cape/weapon/armor overlays never affect School Lobby.
  final ui.Image? playerAvatarSheet;

  /// Dual-buffer `pixelfx` combat, parry, crit & floor-shockwave VFX manager.
  final DungeonPixelfxVfxManager? pixelfxVfx;

  // Pre-allocated static brushes & bounded TextPainter cache for zero-allocation 60 FPS rendering!
  static final Paint _fill = Paint()
    ..style = PaintingStyle.fill
    ..isAntiAlias = false;
  static final Paint _stroke = Paint()
    ..style = PaintingStyle.stroke
    ..isAntiAlias = false;
  static final Paint _imgPaint = Paint()..filterQuality = FilterQuality.none;
  static final Map<String, TextPainter> _textCache = <String, TextPainter>{};

  const DungeonWorldPainter({
    super.repaint,
    required this.chamber,
    required this.player,
    required this.combat,
    required this.progress,
    required this.camera,
    required this.worldTimeSec,
    this.entities = const <DungeonEntityRenderSpec>[],
    this.particles = const <DungeonParticle>[],
    this.highlightedGrappleAnchor,
    this.playerAvatarSheet,
    this.pixelfxVfx,
  });

  static void _drawFilledRect(Canvas canvas, Rect rect, Color color) {
    _fill.color = color;
    canvas.drawRect(rect, _fill);
  }

  static void _drawFilledCircle(Canvas canvas, Offset center, double radius, Color color) {
    _fill.color = color;
    canvas.drawCircle(center, radius, _fill);
  }

  static void _drawStrokedCircle(
    Canvas canvas,
    Offset center,
    double radius,
    Color color,
    double strokeWidth,
  ) {
    _stroke
      ..color = color
      ..strokeWidth = strokeWidth;
    canvas.drawCircle(center, radius, _stroke);
  }

  @override
  void paint(Canvas canvas, Size size) {
    if (size.width <= 0 || size.height <= 0) return;

    final theme = dungeonThemeForAct(chamber.spec.actNumber);
    final animTick = (worldTimeSec * 24.0).round();

    // Scale `320×180` pixel-perfect reference frame cleanly to fill the widget viewport
    // (windowbox-free cover/fit scale keeping crisp 16:9 pixel proportions!)
    final scaleX = size.width / kDungeonRefWidth;
    final scaleY = size.height / kDungeonRefHeight;
    final scale = math.min(scaleX, scaleY);
    final viewW = kDungeonRefWidth * scale;
    final viewH = kDungeonRefHeight * scale;
    final offsetX = (size.width - viewW) * 0.5;
    final offsetY = (size.height - viewH) * 0.5;

    // Deep ink pillar/letterbox backdrop (`ENDESGA-32` ink)
    _drawFilledRect(canvas, Offset.zero & size, SpriteCastPalette.ink);

    canvas.save();
    canvas.translate(offsetX, offsetY);
    canvas.clipRect(Rect.fromLTWH(0, 0, viewW, viewH));
    canvas.scale(scale, scale);

    final cam = camera.snappedOffset;

    // PASS 1: 4-Layer Era Parallax Backdrop (`320×180` screen-space scrolled by camera)
    _paintEraParallaxBackdrop(canvas, theme, cam, animTick);

    // Transform into snapped world coordinates
    canvas.save();
    canvas.translate(-cam.dx, -cam.dy);

    final bounds = camera.visibleTileBounds(
      chamber.spec.cols,
      chamber.spec.rows,
    );

    // Collect visible light emitters during the tile pass for the Terraria lighting pass
    final lightEmitters = <({Offset pos, Color color, double radius})>[];

    // PASS 2: Background Interactive Props & Rule-Tiled Cavern Terrain
    for (var r = bounds.minRow; r <= bounds.maxRow; r++) {
      for (var c = bounds.minCol; c <= bounds.maxCol; c++) {
        final tile = chamber.effectiveTileAt(c, r);
        if (tile == DungeonTileType.empty) continue;
        final rect = Rect.fromLTWH(
          c * kDungeonTileSize,
          r * kDungeonTileSize,
          kDungeonTileSize,
          kDungeonTileSize,
        );

        switch (tile) {
          case DungeonTileType.solidStone:
          case DungeonTileType.mossyStone:
          case DungeonTileType.secretWall:
            _drawRuleTiledStone(
              canvas,
              rect: rect,
              col: c,
              row: r,
              tile: tile,
              theme: theme,
              animTick: animTick,
            );
            break;
          case DungeonTileType.oneWayBridge:
            _drawOneWayBridge(canvas, rect);
            break;
          case DungeonTileType.ladderVine:
            _drawLadderVine(canvas, rect, theme);
            break;
          case DungeonTileType.spikes:
            _drawSpikesTile(canvas, rect, c, r);
            break;
          case DungeonTileType.crumbleBlock:
            _drawCrumbleBlock(canvas, rect, c, r, theme);
            break;
          case DungeonTileType.pogoLantern:
            _drawPogoLantern(canvas, rect, theme, animTick);
            lightEmitters.add((
              pos: rect.center,
              color: theme.accentHighlight,
              radius: 34.0,
            ));
            break;
          case DungeonTileType.grappleRing:
            _drawGrappleRing(canvas, rect, animTick);
            break;
          case DungeonTileType.breakableCrate:
            _drawBreakableCrate(canvas, rect, c, r);
            break;
          case DungeonTileType.crystalVein:
            _drawCrystalVein(canvas, rect, c, r, theme, animTick);
            lightEmitters.add((
              pos: rect.center,
              color: SpriteCastPalette.endesga32[18],
              radius: 28.0,
            ));
            break;
          case DungeonTileType.switchPedestal:
            _drawSwitchPedestal(canvas, rect, c, r, animTick);
            break;
          case DungeonTileType.lockedGate:
            _drawLockedGate(canvas, rect, theme);
            break;
          case DungeonTileType.campfireBench:
            _drawCampfireBench(canvas, rect, animTick);
            lightEmitters.add((
              pos: Offset(rect.center.dx, rect.center.dy - 4.0),
              color: SpriteCastPalette.endesga32[10],
              radius: 64.0,
            ));
            break;
          case DungeonTileType.loreTablet:
            _drawLoreTablet(canvas, rect, theme, animTick);
            lightEmitters.add((
              pos: rect.center,
              color: SpriteCastPalette.endesga32[18],
              radius: 32.0,
            ));
            break;
          case DungeonTileType.treasureChest:
            _drawTreasureChest(canvas, rect, c, r);
            break;
          case DungeonTileType.roomPortal:
            _drawRoomPortal(canvas, rect, theme, animTick);
            break;
          case DungeonTileType.wallTorch:
            _drawWallTorch(canvas, rect, theme, animTick);
            lightEmitters.add((
              pos: Offset(rect.center.dx, rect.top + 5.0),
              color: theme.torchGlow,
              radius: 48.0,
            ));
            break;
          case DungeonTileType.empty:
            break;
        }
      }
    }

    // PASS 3: Loot Drops & Back-Plane `pixelfx` Floor Shockwaves
    _paintLootDrops(canvas, animTick);
    pixelfxVfx?.paintBack(canvas);

    // PASS 4: 22 Unique Pixel-Art Enemies, Rival Mateo & Multi-Phase Bosses
    for (final entity in entities) {
      _drawDungeonEntity(canvas, entity, animTick);
    }

    // PASS 5: Alon Hero + Dash Ghost Trail + Grapple Silk Line + Umalo Lantern Familiar
    _paintSilkGrappleLine(canvas);
    _paintDashAfterimages(canvas);
    _paintUmaloLanternFamiliar(canvas, theme, animTick, lightEmitters);
    _paintAlonHero(canvas, theme, animTick);

    // PASS 6: Active Slash Arcs, 5 Constitutional Silk Skill VFX & Projectiles
    _paintActiveSlashes(canvas);
    _paintActiveSkillEffects(canvas);
    _paintProjectiles(canvas);

    // PASS 7: Particle Bursts & Front-Plane `pixelfx` Dual-Buffer VFX
    _paintParticles(canvas);
    pixelfxVfx?.paintFront(canvas);

    // PASS 8: Terraria-Style Cavern Atmosphere & SpriteCast Stepped Pixel Light Pools
    _paintCavernLightingPass(canvas, cam, theme, lightEmitters, animTick);

    // PASS 9: Floating Combat Damage / Parry / Secret Popups (always crisp above darkness!)
    _paintFloatingCombatNumbers(canvas);

    canvas.restore(); // exit world space
    canvas.restore(); // exit virtual 320x180 viewport
  }

  // ═══════════════════════════════════════════════════════════════════════════
  //  PASS 1: 4-LAYER ERA PARALLAX BACKDROP
  // ═══════════════════════════════════════════════════════════════════════════

  void _paintEraParallaxBackdrop(
    Canvas canvas,
    DungeonEraTheme theme,
    Offset cam,
    int animTick,
  ) {
    // Layer 0: Banded pixel-art vertical sky/cavern gradient (4 crisp horizontal bands)
    for (var b = 0; b < 4; b++) {
      final col = Color.lerp(theme.skyTop, theme.skyBottom, b / 3.0)!;
      _drawFilledRect(canvas, Rect.fromLTWH(0, b * 45.0, kDungeonRefWidth, 46.0), col);
    }

    // Ambient distant stars / cavern spores (0.08x parallax)
    _fill.color = theme.accentHighlight.withValues(alpha: 0.35);
    for (var i = 0; i < 18; i++) {
      final baseX = SpriteCastEngine.hash01(i * 13, theme.actNumber) * 360.0;
      final baseY = SpriteCastEngine.hash01(i * 29, theme.actNumber + 5) * 140.0;
      final sx = ((baseX - cam.dx * 0.08) % 340.0 + 340.0) % 340.0 - 10.0;
      final sy = baseY + math.sin(worldTimeSec * 1.4 + i) * 3.0;
      canvas.drawRect(Rect.fromLTWH(sx.roundToDouble(), sy.roundToDouble(), 1.5, 1.5), _fill);
    }

    // Layer 1: Far Era Silhouettes (0.16x parallax)
    _fill.color = theme.parallaxFar;
    final farOffset = (cam.dx * 0.16) % 80.0;
    for (var i = -1; i < 6; i++) {
      final bx = i * 80.0 - farOffset;
      final pillarH = 72.0 + (i.abs() % 3) * 18.0;
      canvas.drawRect(
        Rect.fromLTWH(bx, kDungeonRefHeight - pillarH, 34.0, pillarH),
        _fill,
      );
      if (theme.actNumber == 2 || theme.actNumber == 3 || theme.actNumber == 7) {
        canvas.drawRect(
          Rect.fromLTWH(bx + 8.0, kDungeonRefHeight - pillarH - 18.0, 18.0, 18.0),
          _fill,
        );
        canvas.drawRect(
          Rect.fromLTWH(bx + 14.0, kDungeonRefHeight - pillarH - 28.0, 6.0, 10.0),
          _fill,
        );
      } else {
        canvas.drawRect(
          Rect.fromLTWH(bx + 26.0, 0.0, 22.0, 26.0 + (i.abs() % 2) * 14.0),
          _fill,
        );
      }
    }

    // Layer 2: Mid-Ground Ruined Pillars & Hanging Chains (0.38x parallax)
    _fill.color = theme.parallaxMid;
    final midOffset = (cam.dx * 0.38) % 96.0;
    for (var i = -1; i < 5; i++) {
      final px = i * 96.0 - midOffset;
      canvas.drawRect(
        Rect.fromLTWH(px + 12.0, 18.0, 14.0, kDungeonRefHeight - 18.0),
        _fill,
      );
      canvas.drawRect(
        Rect.fromLTWH(px + 4.0, 14.0, 30.0, 8.0),
        _fill,
      );
      final chainSway = SpriteCastEngine.windSwayPx(animTick, i * 19, px: 1.0);
      for (var cy = 22.0; cy < 84.0; cy += 6.0) {
        canvas.drawRect(
          Rect.fromLTWH(px + 56.0 + chainSway, cy, 2.0, 4.0),
          _fill,
        );
      }
    }
  }

  // ═══════════════════════════════════════════════════════════════════════════
  //  PASS 2: 16-NEIGHBOR RULE-TILE STONE & ALL 19 DUNGEON TILE SPRITES
  // ═══════════════════════════════════════════════════════════════════════════

  void _drawRuleTiledStone(
    Canvas canvas, {
    required Rect rect,
    required int col,
    required int row,
    required DungeonTileType tile,
    required DungeonEraTheme theme,
    required int animTick,
  }) {
    final mask = computeSolidNeighborMask(chamber, col, row);
    final openN = (mask & 1) == 0;
    final openE = (mask & 2) == 0;
    final openS = (mask & 4) == 0;
    final openW = (mask & 8) == 0;

    // Base fill
    _drawFilledRect(canvas, rect, theme.stoneMid);

    // Deterministic ashlar brick seams (breaks up flat tile repetition!)
    final h = SpriteCastEngine.hash01(col * 17 + 3, row * 31 + 7);
    final mortarCol = theme.stoneDark.withValues(alpha: 0.72);
    _drawFilledRect(canvas, Rect.fromLTWH(rect.left, rect.top + 7, 16, 1), mortarCol);
    final seamX = (row.isEven ? 7.0 : 12.0);
    _drawFilledRect(canvas, Rect.fromLTWH(rect.left + seamX, rect.top, 1, 7), mortarCol);
    _drawFilledRect(
      canvas,
      Rect.fromLTWH(rect.left + ((seamX + 6) % 14), rect.top + 8, 1, 8),
      mortarCol,
    );
    if (h > 0.72) {
      _drawFilledRect(
        canvas,
        Rect.fromLTWH(rect.left + 3, rect.top + 3, 3, 2),
        theme.stoneLight.withValues(alpha: 0.32),
      );
    }

    // Secret Wall subtle fracture hint (glows softly when Tarsier Lantern Sight charm is equipped!)
    if (tile == DungeonTileType.secretWall) {
      final hasSight = progress.hasCharmEquipped('tarsier_lantern');
      final crackColor = hasSight
          ? SpriteCastPalette.endesga32[11].withValues(alpha: 0.65)
          : SpriteCastPalette.ink.withValues(alpha: 0.55);
      _drawFilledRect(canvas, Rect.fromLTWH(rect.left + 4, rect.top + 3, 2, 5), crackColor);
      _drawFilledRect(canvas, Rect.fromLTWH(rect.left + 6, rect.top + 7, 4, 2), crackColor);
      _drawFilledRect(canvas, Rect.fromLTWH(rect.left + 9, rect.top + 9, 2, 4), crackColor);
    }

    // Exposed Cardinal Edges (Rule-Tile Auto-Tiling!)
    if (openN) {
      if (tile == DungeonTileType.mossyStone) {
        final sway = SpriteCastEngine.windSwayPx(animTick, col * 11 + row, px: 0.8);
        _drawFilledRect(canvas, Rect.fromLTWH(rect.left, rect.top, 16, 3), theme.mossOrTrim);
        _drawFilledRect(canvas, Rect.fromLTWH(rect.left + 2 + sway, rect.top + 3, 3, 2), theme.mossOrTrim);
        _drawFilledRect(canvas, Rect.fromLTWH(rect.left + 10, rect.top + 3, 4, 2), theme.mossOrTrim);
      } else {
        _drawFilledRect(canvas, Rect.fromLTWH(rect.left, rect.top + 1, 16, 2), theme.stoneLight);
      }
      _drawFilledRect(canvas, Rect.fromLTWH(rect.left, rect.top, 16, 1), SpriteCastPalette.ink);
    }

    if (openS) {
      _drawFilledRect(canvas, Rect.fromLTWH(rect.left, rect.bottom - 3, 16, 2), theme.stoneDark);
      _drawFilledRect(canvas, Rect.fromLTWH(rect.left, rect.bottom - 1, 16, 1), SpriteCastPalette.ink);
      if (h > 0.78) {
        _drawFilledRect(canvas, Rect.fromLTWH(rect.left + 6, rect.bottom, 4, 3), theme.stoneDark);
        _drawFilledRect(canvas, Rect.fromLTWH(rect.left + 7, rect.bottom + 3, 2, 2), SpriteCastPalette.ink);
      }
    }

    if (openW) {
      _drawFilledRect(canvas, Rect.fromLTWH(rect.left, rect.top, 1, 16), SpriteCastPalette.ink);
      _drawFilledRect(
        canvas,
        Rect.fromLTWH(rect.left + 1, rect.top + 1, 1, 14),
        theme.stoneLight.withValues(alpha: 0.45),
      );
    }

    if (openE) {
      _drawFilledRect(canvas, Rect.fromLTWH(rect.right - 1, rect.top, 1, 16), SpriteCastPalette.ink);
      _drawFilledRect(canvas, Rect.fromLTWH(rect.right - 2, rect.top + 1, 1, 14), theme.stoneDark);
    }
  }

  void _drawOneWayBridge(Canvas canvas, Rect r) {
    _drawFilledRect(canvas, Rect.fromLTWH(r.left, r.top, 16, 5), SpriteCastPalette.ink);
    _drawFilledRect(canvas, Rect.fromLTWH(r.left, r.top + 1, 16, 2), SpriteCastPalette.woodLight);
    _drawFilledRect(canvas, Rect.fromLTWH(r.left, r.top + 3, 16, 1), SpriteCastPalette.woodDark);
    _drawFilledRect(canvas, Rect.fromLTWH(r.left + 2, r.top + 5, 2, 3), SpriteCastPalette.woodEdge);
    _drawFilledRect(canvas, Rect.fromLTWH(r.right - 4, r.top + 5, 2, 3), SpriteCastPalette.woodEdge);
    _drawFilledRect(canvas, Rect.fromLTWH(r.left + 2, r.top + 1.5, 1.5, 1.5), SpriteCastPalette.endesga32[20]);
    _drawFilledRect(canvas, Rect.fromLTWH(r.right - 3.5, r.top + 1.5, 1.5, 1.5), SpriteCastPalette.endesga32[20]);
  }

  void _drawLadderVine(Canvas canvas, Rect r, DungeonEraTheme theme) {
    _drawFilledRect(canvas, Rect.fromLTWH(r.left + 3, r.top, 2, 16), SpriteCastPalette.woodDark);
    _drawFilledRect(canvas, Rect.fromLTWH(r.right - 5, r.top, 2, 16), SpriteCastPalette.woodDark);
    _drawFilledRect(canvas, Rect.fromLTWH(r.left + 3.5, r.top, 1, 16), SpriteCastPalette.woodLight);
    _drawFilledRect(canvas, Rect.fromLTWH(r.right - 4.5, r.top, 1, 16), SpriteCastPalette.woodLight);
    for (var y = 2.0; y < 16.0; y += 5.0) {
      _drawFilledRect(canvas, Rect.fromLTWH(r.left + 4, r.top + y, 8, 2), SpriteCastPalette.woodMid);
    }
  }

  void _drawSpikesTile(Canvas canvas, Rect r, int col, int row) {
    for (var i = 0; i < 3; i++) {
      final bx = r.left + 1.0 + i * 5.0;
      _drawFilledRect(canvas, Rect.fromLTWH(bx, r.bottom - 4, 4, 4), SpriteCastPalette.ink);
      _drawFilledRect(canvas, Rect.fromLTWH(bx + 1, r.bottom - 8, 2, 6), SpriteCastPalette.endesga32[22]);
      _drawFilledRect(canvas, Rect.fromLTWH(bx + 1.5, r.bottom - 11, 1, 4), SpriteCastPalette.endesga32[20]);
      _drawFilledRect(canvas, Rect.fromLTWH(bx + 1.5, r.bottom - 12, 1, 1.5), SpriteCastPalette.endesga32[19]);
    }
  }

  void _drawCrumbleBlock(Canvas canvas, Rect r, int col, int row, DungeonEraTheme theme) {
    final st = chamber.crumbleBlocks['${col}_$row'];
    final jitterX = (st != null && st.shakeTimer > 0.0)
        ? math.sin(worldTimeSec * 68.0) * 1.6
        : 0.0;
    final shifted = r.shift(Offset(jitterX, 0));
    _drawFilledRect(canvas, shifted, SpriteCastPalette.ink);
    _drawFilledRect(canvas, shifted.deflate(1), SpriteCastPalette.woodMid);
    _drawFilledRect(canvas, Rect.fromLTWH(shifted.left + 1, shifted.top + 1, 14, 2), SpriteCastPalette.cream);
    _drawFilledRect(canvas, Rect.fromLTWH(shifted.left + 4, shifted.top + 4, 2, 6), SpriteCastPalette.ink);
    _drawFilledRect(canvas, Rect.fromLTWH(shifted.left + 9, shifted.top + 6, 3, 5), SpriteCastPalette.ink);
  }

  void _drawPogoLantern(Canvas canvas, Rect r, DungeonEraTheme theme, int animTick) {
    final bob = math.sin(worldTimeSec * 3.2 + r.left) * 1.2;
    final cy = r.center.dy + bob;
    _drawFilledRect(canvas, Rect.fromLTWH(r.center.dx - 0.5, r.top, 1.5, 4), SpriteCastPalette.endesga32[22]);
    _drawFilledRect(canvas, Rect.fromCenter(center: Offset(r.center.dx, cy), width: 10, height: 10), SpriteCastPalette.ink);
    _drawFilledRect(canvas, Rect.fromCenter(center: Offset(r.center.dx, cy), width: 8, height: 8), SpriteCastPalette.endesga32[10]);
    _drawFilledRect(canvas, Rect.fromCenter(center: Offset(r.center.dx, cy), width: 5, height: 5), SpriteCastPalette.endesga32[11]);
    _drawFilledRect(canvas, Rect.fromCenter(center: Offset(r.center.dx, cy), width: 2.5, height: 2.5), SpriteCastPalette.endesga32[19]);
  }

  void _drawGrappleRing(Canvas canvas, Rect r, int animTick) {
    final isHighlighted = highlightedGrappleAnchor != null &&
        (highlightedGrappleAnchor! - r.center).distance < 10.0;
    final ringCol = isHighlighted
        ? SpriteCastPalette.endesga32[18]
        : SpriteCastPalette.endesga32[10];
    _drawFilledCircle(canvas, r.center, 5.5, SpriteCastPalette.ink);
    _drawStrokedCircle(canvas, r.center, 4.2, ringCol, 2.0);
    if (isHighlighted) {
      final pulse = 6.5 + math.sin(worldTimeSec * 8.0) * 1.8;
      _drawStrokedCircle(
        canvas,
        r.center,
        pulse,
        SpriteCastPalette.endesga32[18].withValues(alpha: 0.65),
        1.0,
      );
    }
  }

  void _drawBreakableCrate(Canvas canvas, Rect r, int col, int row) {
    final br = chamber.breakables['${col}_$row'];
    final flash = br != null && br.hitFlashTimer > 0.0;
    final box = Rect.fromLTWH(r.left + 1, r.top + 2, 14, 14);
    _drawFilledRect(canvas, box, SpriteCastPalette.ink);
    _drawFilledRect(
      canvas,
      box.deflate(1),
      flash ? SpriteCastPalette.endesga32[19] : SpriteCastPalette.woodMid,
    );
    if (!flash) {
      _drawFilledRect(canvas, Rect.fromLTWH(box.left + 1, box.top + 1, 12, 2), SpriteCastPalette.woodLight);
      _drawFilledRect(canvas, Rect.fromLTWH(box.left + 2, box.top + 6, 10, 2), SpriteCastPalette.woodDark);
      _drawFilledRect(canvas, Rect.fromLTWH(box.left + 6, box.top + 2, 2, 10), SpriteCastPalette.woodDark);
    }
  }

  void _drawCrystalVein(
    Canvas canvas,
    Rect r,
    int col,
    int row,
    DungeonEraTheme theme,
    int animTick,
  ) {
    final br = chamber.breakables['${col}_$row'];
    final hp = br?.hp ?? 3;
    final shimmer = (animTick ~/ 8).isEven;
    final colMain = shimmer
        ? SpriteCastPalette.endesga32[18]
        : SpriteCastPalette.endesga32[17];
    if (hp >= 1) {
      _drawFilledRect(canvas, Rect.fromLTWH(r.left + 5, r.bottom - 11, 5, 11), SpriteCastPalette.ink);
      _drawFilledRect(canvas, Rect.fromLTWH(r.left + 6, r.bottom - 10, 3, 9), colMain);
      _drawFilledRect(canvas, Rect.fromLTWH(r.left + 6.5, r.bottom - 9, 1, 4), SpriteCastPalette.endesga32[19]);
    }
    if (hp >= 2) {
      _drawFilledRect(canvas, Rect.fromLTWH(r.left + 1, r.bottom - 7, 4, 7), SpriteCastPalette.ink);
      _drawFilledRect(canvas, Rect.fromLTWH(r.left + 2, r.bottom - 6, 2, 5), SpriteCastPalette.endesga32[17]);
    }
    if (hp >= 3) {
      _drawFilledRect(canvas, Rect.fromLTWH(r.left + 10, r.bottom - 8, 5, 8), SpriteCastPalette.ink);
      _drawFilledRect(canvas, Rect.fromLTWH(r.left + 11, r.bottom - 7, 3, 6), colMain);
    }
  }

  void _drawSwitchPedestal(Canvas canvas, Rect r, int col, int row, int animTick) {
    final br = chamber.breakables['${col}_$row'];
    final active = (br?.brokenOrTriggered ?? false) || chamber.roomGateUnlocked;
    _drawFilledRect(canvas, Rect.fromLTWH(r.left + 3, r.bottom - 12, 10, 12), SpriteCastPalette.ink);
    _drawFilledRect(canvas, Rect.fromLTWH(r.left + 4, r.bottom - 11, 8, 10), SpriteCastPalette.endesga32[22]);
    _drawFilledRect(
      canvas,
      Rect.fromLTWH(r.left + 5, r.top + 1, 6, 5),
      active ? SpriteCastPalette.endesga32[18] : SpriteCastPalette.endesga32[8],
    );
  }

  void _drawLockedGate(Canvas canvas, Rect r, DungeonEraTheme theme) {
    _drawFilledRect(canvas, Rect.fromLTWH(r.left + 1, r.top, 14, 16), SpriteCastPalette.ink);
    for (var bx = 3.0; bx <= 11.0; bx += 4.0) {
      _drawFilledRect(canvas, Rect.fromLTWH(r.left + bx, r.top, 2, 16), SpriteCastPalette.endesga32[21]);
    }
    _drawFilledRect(canvas, Rect.fromLTWH(r.left + 2, r.top + 6, 12, 3), SpriteCastPalette.endesga32[10]);
  }

  void _drawCampfireBench(Canvas canvas, Rect r, int animTick) {
    _drawFilledRect(canvas, Rect.fromLTWH(r.left - 4, r.bottom - 8, 15, 8), SpriteCastPalette.ink);
    _drawFilledRect(canvas, Rect.fromLTWH(r.left - 3, r.bottom - 7, 13, 2), SpriteCastPalette.woodLight);
    _drawFilledRect(canvas, Rect.fromLTWH(r.left - 3, r.bottom - 4, 13, 2), SpriteCastPalette.woodMid);
    final flick = (animTick ~/ 4) % 3;
    _drawFilledRect(canvas, Rect.fromLTWH(r.right - 4, r.bottom - 3, 7, 3), SpriteCastPalette.woodDark);
    _drawFilledRect(
      canvas,
      Rect.fromLTWH(r.right - 3, r.bottom - 8 - flick * 0.8, 5, 6),
      SpriteCastPalette.endesga32[9],
    );
    _drawFilledRect(
      canvas,
      Rect.fromLTWH(r.right - 2, r.bottom - 6 - flick * 0.5, 3, 4),
      SpriteCastPalette.endesga32[11],
    );
  }

  void _drawLoreTablet(Canvas canvas, Rect r, DungeonEraTheme theme, int animTick) {
    final pulse = 0.65 + 0.35 * math.sin(worldTimeSec * 3.5);
    _drawFilledRect(canvas, Rect.fromLTWH(r.left + 2, r.top + 1, 12, 15), SpriteCastPalette.ink);
    _drawFilledRect(canvas, Rect.fromLTWH(r.left + 3, r.top + 2, 10, 13), SpriteCastPalette.endesga32[23]);
    final runeCol = SpriteCastPalette.endesga32[18].withValues(alpha: pulse);
    _drawFilledRect(canvas, Rect.fromLTWH(r.left + 5, r.top + 4, 6, 1.5), runeCol);
    _drawFilledRect(canvas, Rect.fromLTWH(r.left + 5, r.top + 7, 5, 1.5), runeCol);
    _drawFilledRect(canvas, Rect.fromLTWH(r.left + 5, r.top + 10, 6, 1.5), runeCol);
  }

  void _drawTreasureChest(Canvas canvas, Rect r, int col, int row) {
    final chestKey = '${chamber.spec.id}:${col}_$row';
    final opened = progress.openedChestIds.contains(chestKey);
    _drawFilledRect(canvas, Rect.fromLTWH(r.left + 1, r.bottom - 11, 14, 11), SpriteCastPalette.ink);
    _drawFilledRect(canvas, Rect.fromLTWH(r.left + 2, r.bottom - 10, 12, 9), SpriteCastPalette.woodMid);
    _drawFilledRect(
      canvas,
      Rect.fromLTWH(r.left + 2, r.bottom - 10, 12, 2),
      opened ? SpriteCastPalette.woodDark : SpriteCastPalette.endesga32[10],
    );
    _drawFilledRect(
      canvas,
      Rect.fromLTWH(r.left + 6.5, r.bottom - 7, 3, 3),
      opened ? SpriteCastPalette.endesga32[22] : SpriteCastPalette.endesga32[11],
    );
  }

  void _drawRoomPortal(Canvas canvas, Rect r, DungeonEraTheme theme, int animTick) {
    final glow = 0.55 + 0.45 * math.sin(worldTimeSec * 4.0);
    _drawFilledRect(canvas, Rect.fromLTWH(r.left + 1, r.top - 4, 14, 20), SpriteCastPalette.ink);
    _drawFilledRect(
      canvas,
      Rect.fromLTWH(r.left + 3, r.top - 2, 10, 18),
      theme.accentHighlight.withValues(alpha: 0.35 + 0.30 * glow),
    );
    _drawFilledRect(
      canvas,
      Rect.fromLTWH(r.left + 5, r.top + 1, 6, 15),
      SpriteCastPalette.endesga32[19].withValues(alpha: 0.45 * glow),
    );
  }

  void _drawWallTorch(Canvas canvas, Rect r, DungeonEraTheme theme, int animTick) {
    final flick = (animTick ~/ 5) % 2;
    _drawFilledRect(canvas, Rect.fromLTWH(r.center.dx - 1.5, r.top + 6, 3, 7), SpriteCastPalette.woodDark);
    _drawFilledRect(canvas, Rect.fromLTWH(r.center.dx - 2.5, r.top + 2 - flick, 5, 5), theme.torchGlow);
    _drawFilledRect(
      canvas,
      Rect.fromLTWH(r.center.dx - 1.2, r.top + 3.5 - flick * 0.5, 2.4, 2.8),
      SpriteCastPalette.endesga32[19],
    );
  }

  // ═══════════════════════════════════════════════════════════════════════════
  //  PASS 3–7: LOOT, ENTITIES, ALON HERO, UMALO, SLASHES, SKILLS & PARTICLES
  // ═══════════════════════════════════════════════════════════════════════════

  void _paintLootDrops(Canvas canvas, int animTick) {
    for (final drop in chamber.lootDrops) {
      if (drop.collected) continue;
      final bob = math.sin(worldTimeSec * 6.0 + drop.x) * 1.2;
      final pos = Offset(drop.x, drop.y + bob);
      Color col;
      switch (drop.kind) {
        case DungeonLootKind.archipelagoShard:
          col = SpriteCastPalette.endesga32[11];
          break;
        case DungeonLootKind.resolveOrb:
          col = SpriteCastPalette.endesga32[8];
          break;
        case DungeonLootKind.silkMote:
          col = SpriteCastPalette.endesga32[18];
          break;
        case DungeonLootKind.relicFragment:
          col = SpriteCastPalette.endesga32[29];
          break;
      }
      _drawFilledRect(canvas, Rect.fromCenter(center: pos, width: 5.5, height: 5.5), SpriteCastPalette.ink);
      _drawFilledRect(canvas, Rect.fromCenter(center: pos, width: 3.5, height: 3.5), col);
      _drawFilledRect(canvas, Rect.fromLTWH(pos.dx - 1, pos.dy - 1, 1.2, 1.2), SpriteCastPalette.endesga32[19]);
    }
  }

  void _drawDungeonEntity(
    Canvas canvas,
    DungeonEntityRenderSpec e,
    int animTick,
  ) {
    DungeonEnemySpritePainter.paintEntity(
      canvas: canvas,
      e: e,
      worldTimeSec: worldTimeSec,
      animTick: animTick,
    );
  }

  void _paintSilkGrappleLine(Canvas canvas) {
    if (!player.grappleActive) return;
    _stroke
      ..color = SpriteCastPalette.endesga32[18]
      ..strokeWidth = 1.6;
    canvas.drawLine(
      Offset(player.centerX, player.centerY),
      Offset(player.grappleTargetX, player.grappleTargetY),
      _stroke,
    );
    _drawFilledCircle(
      canvas,
      Offset(player.grappleTargetX, player.grappleTargetY),
      3.0,
      SpriteCastPalette.endesga32[19],
    );
  }

  void _paintDashAfterimages(Canvas canvas) {
    final sheet = playerAvatarSheet;
    for (final ghost in player.afterimages) {
      final a = (ghost.alpha * 0.55).clamp(0.0, 0.55);
      if (sheet != null && sheet.width >= kCharFrameWidth * 48) {
        final frameIdx = computeCharacterFrameIndex(
          facing: ghost.facing >= 0 ? AvatarFacing.right : AvatarFacing.left,
          isWalking: true,
          stepFrame: 2,
        );
        final src = Rect.fromLTWH(
          frameIdx * kCharFrameWidth,
          0,
          kCharFrameWidth,
          kCharFrameHeight,
        );
        const drawH = 26.0;
        const drawW = drawH * (kCharFrameWidth / kCharFrameHeight);
        final dst = Rect.fromLTWH(
          ghost.x + player.width * 0.5 - drawW * 0.5,
          ghost.y + player.height - drawH + 1.5,
          drawW,
          drawH,
        );
        _imgPaint
          ..colorFilter = ColorFilter.mode(
            SpriteCastPalette.endesga32[18].withValues(alpha: a),
            BlendMode.srcATop,
          )
          ..color = Color.fromRGBO(255, 255, 255, a);
        canvas.drawImageRect(sheet, src, dst, _imgPaint);
        _imgPaint
          ..colorFilter = null
          ..color = Colors.white;
      } else {
        _drawFilledRect(
          canvas,
          Rect.fromLTWH(ghost.x, ghost.y, player.width, player.height),
          SpriteCastPalette.endesga32[18].withValues(alpha: a),
        );
      }
    }
  }

  void _paintUmaloLanternFamiliar(
    Canvas canvas,
    DungeonEraTheme theme,
    int animTick,
    List<({Offset pos, Color color, double radius})> lightEmitters,
  ) {
    final ux = player.centerX - player.facing * 11.0;
    final uy = player.y - 5.0 + math.sin(worldTimeSec * 4.4) * 2.2;
    final pos = Offset(ux, uy);

    _drawFilledRect(canvas, Rect.fromCenter(center: pos, width: 6.5, height: 6.5), SpriteCastPalette.ink);
    _drawFilledRect(canvas, Rect.fromCenter(center: pos, width: 4.5, height: 4.5), SpriteCastPalette.woodLight);
    _drawFilledRect(
      canvas,
      Rect.fromLTWH(pos.dx + (player.facing > 0 ? 0.5 : -2.0), pos.dy - 1.0, 1.5, 1.5),
      SpriteCastPalette.endesga32[11],
    );

    final lanternRadius =
        progress.hasCharmEquipped('tarsier_lantern') ? 82.0 : 56.0;
    lightEmitters.add((
      pos: pos,
      color: SpriteCastPalette.endesga32[11],
      radius: lanternRadius,
    ));
  }

  void _paintAlonHero(Canvas canvas, DungeonEraTheme theme, int animTick) {
    if (player.invulnTimer > 0.0 && !player.isDashing && (animTick % 4 < 2)) {
      return;
    }

    final cx = player.centerX;
    final bottomY = player.bottom;

    if (player.isGrounded) {
      SpriteCastEngine.drawSteppedContactShadow(
        canvas,
        Rect.fromCenter(center: Offset(cx, bottomY), width: 10, height: 3),
        castDx: 1.5,
        castDy: 1.0,
        strength: 0.72,
        oval: true,
      );
    }

    canvas.save();
    canvas.translate(cx, bottomY);
    canvas.scale(player.squashX, player.squashY);

    final w = player.width;
    final h = player.height;
    final f = player.facing.toDouble();
    final breathY = player.isGrounded && player.vx.abs() < 10.0
        ? math.sin(worldTimeSec * 3.1) * 0.5
        : 0.0;
    final stride = player.isGrounded && player.vx.abs() > 15.0
        ? math.sin(player.runAnimTime) * 2.2
        : 0.0;

    // 1. Dungeon-Only Flowing Silksong Cape trailing opposite velocity
    final capeSway = math.sin(worldTimeSec * 9.0) * 1.4 - (player.vx * 0.015).clamp(-3.5, 3.5);
    final capePath = Path()
      ..moveTo(-f * 2.0, -h + 4.5 + breathY)
      ..lineTo(-f * 9.0 + capeSway, -3.0)
      ..lineTo(-f * 3.5 + capeSway * 0.5, -1.8)
      ..lineTo(f * 1.0, -h + 6.5 + breathY)
      ..close();
    _fill.color = SpriteCastPalette.endesga32[8];
    canvas.drawPath(capePath, _fill);
    _stroke
      ..color = SpriteCastPalette.ink
      ..strokeWidth = 1.0;
    canvas.drawPath(capePath, _stroke);

    // 2. Playable Hero Sprite: Student's Custom School Lobby Character when loaded,
    //    or crisp SpriteCast fallback silhouette while loading / in headless tests.
    final sheet = playerAvatarSheet;
    if (sheet != null && sheet.width >= kCharFrameWidth * 48) {
      final frameIdx = computeDungeonHeroAvatarFrameIndex(player, worldTimeSec);
      final src = Rect.fromLTWH(
        frameIdx * kCharFrameWidth,
        0,
        kCharFrameWidth,
        kCharFrameHeight,
      );
      const drawH = 26.0;
      const drawW = drawH * (kCharFrameWidth / kCharFrameHeight);
      final dst = Rect.fromLTWH(
        -drawW * 0.5,
        -drawH + 1.5 + breathY * 0.5,
        drawW,
        drawH,
      );
      _imgPaint
        ..colorFilter = null
        ..color = Colors.white;
      canvas.drawImageRect(sheet, src, dst, _imgPaint);
    } else {
      _drawFilledRect(canvas, Rect.fromLTWH(-w * 0.5 - 0.5, -h + breathY, w + 1.0, h - 1.0), SpriteCastPalette.ink);
      _drawFilledRect(canvas, Rect.fromLTWH(-w * 0.42, -h + 5.5 + breathY, w * 0.84, 5.5), SpriteCastPalette.endesga32[2]);
      _drawFilledRect(canvas, Rect.fromLTWH(-3.2 + stride * 0.5, -3.5, 2.4, 3.5), SpriteCastPalette.endesga32[24]);
      _drawFilledRect(canvas, Rect.fromLTWH(0.8 - stride * 0.5, -3.5, 2.4, 3.5), SpriteCastPalette.endesga32[24]);
      _drawFilledRect(canvas, Rect.fromLTWH(-4.0, -h + 0.8 + breathY, 8.0, 5.0), SpriteCastPalette.endesga32[30]);
      _drawFilledRect(canvas, Rect.fromLTWH(-4.4, -h - 0.4 + breathY, 8.8, 2.4), SpriteCastPalette.endesga32[25]);
      _drawFilledRect(canvas, Rect.fromLTWH(-4.0, -h + 1.4 + breathY, 8.0, 1.0), theme.accentHighlight);
      _drawFilledRect(canvas, Rect.fromLTWH(f > 0 ? 1.2 : -3.0, -h + 3.0 + breathY, 1.5, 1.5), SpriteCastPalette.ink);
    }

    // 3. Dungeon-Only Shoulder Armor Pauldron & Constitutional Crest (never shown in School Lobby!)
    if (!player.isOnLadder) {
      final hasUpgradedArmor =
          progress.bladeTier.index >= 1 || progress.hasCharmEquipped('sovereign_heart');
      final pauldronColor = progress.bladeTier.index >= 3
          ? SpriteCastPalette.endesga32[10]
          : (hasUpgradedArmor
              ? SpriteCastPalette.endesga32[20]
              : SpriteCastPalette.woodLight);
      final px = f > 0 ? -3.8 : 0.6;
      _drawFilledRect(canvas, Rect.fromLTWH(px - 0.5, -9.8 + breathY, 3.8, 2.8), SpriteCastPalette.ink);
      _drawFilledRect(canvas, Rect.fromLTWH(px, -9.3 + breathY, 2.8, 1.8), pauldronColor);

      // 4. Dungeon-Only Forged Melee Weapon (Bamboo Spear -> Sovereign Blade)
      final bladeLen = 6.0 + progress.bladeTier.index * 1.1;
      final bladeX = f > 0 ? 3.2 : -3.2 - bladeLen;
      _drawFilledRect(canvas, Rect.fromLTWH(bladeX - 0.5, -7.5 + breathY, bladeLen + 1.0, 2.6), SpriteCastPalette.ink);
      _drawFilledRect(canvas, Rect.fromLTWH(bladeX, -7.0 + breathY, bladeLen, 1.6), progress.bladeTier.slashArcColor);
      _drawFilledRect(canvas, Rect.fromLTWH(f > 0 ? 2.6 : -4.0, -8.0 + breathY, 1.4, 3.6), SpriteCastPalette.endesga32[10]);
    }

    canvas.restore();

    // 5. Active Silk Bind golden healing thread cocoon
    if (combat.isChannelingBind) {
      final p = combat.bindProgress;
      _drawStrokedCircle(
        canvas,
        Offset(cx, player.centerY),
        10.0 + (1.0 - p) * 6.0,
        SpriteCastPalette.endesga32[12].withValues(alpha: 0.78),
        1.8,
      );
    }

    // 6. Active Habeas Aegis Parry Dome!
    if (combat.isParryActive) {
      _drawFilledCircle(
        canvas,
        Offset(cx, player.centerY),
        13.0,
        SpriteCastPalette.endesga32[12].withValues(alpha: 0.28),
      );
      _drawStrokedCircle(
        canvas,
        Offset(cx, player.centerY),
        13.0,
        SpriteCastPalette.endesga32[11],
        1.6,
      );
    }
  }

  void _paintActiveSlashes(Canvas canvas) {
    final cache = DungeonPixelfxSheetCache.instance;
    for (final slash in combat.activeSlashes) {
      final hb = slash.worldHitbox(player);
      final alpha = (1.0 - slash.progress * 0.85).clamp(0.15, 1.0);

      double startAngle;
      double sheetRot = 0.0;
      bool sheetFlipX = false;
      const sweepAngle = math.pi * 0.82;
      switch (slash.direction) {
        case DungeonSlashDirection.right:
          startAngle = -math.pi * 0.41;
          sheetFlipX = false;
          break;
        case DungeonSlashDirection.left:
          startAngle = math.pi - math.pi * 0.41;
          sheetFlipX = true;
          break;
        case DungeonSlashDirection.up:
          startAngle = -math.pi * 0.91;
          sheetRot = -math.pi * 0.5;
          break;
        case DungeonSlashDirection.down:
          startAngle = math.pi * 0.09;
          sheetRot = math.pi * 0.5;
          break;
      }

      // Layer 1: Exported `pixelfx` `sword_slash.png` frame when loaded
      cache.drawSheetFrame(
        canvas: canvas,
        reusablePaint: _imgPaint,
        key: 'sword_slash',
        worldX: hb.center.dx,
        worldY: hb.center.dy,
        frameIndex: (slash.progress * 7.0).floor().clamp(0, 6),
        scale: slash.comboStep == 2 ? 0.34 : 0.27,
        flipX: sheetFlipX,
        rotationRad: sheetRot,
        opacity: alpha,
      );

      // Layer 2: Forged-blade-colored outer crescent + hot white core!
      _stroke
        ..color = slash.arcColor.withValues(alpha: alpha)
        ..strokeWidth = slash.comboStep == 2 ? 4.2 : 2.8;
      canvas.drawArc(hb, startAngle, sweepAngle, false, _stroke);

      _stroke
        ..color = SpriteCastPalette.endesga32[19].withValues(alpha: alpha)
        ..strokeWidth = 1.4;
      canvas.drawArc(hb.deflate(2.0), startAngle, sweepAngle, false, _stroke);
    }
  }

  void _paintActiveSkillEffects(Canvas canvas) {
    final cache = DungeonPixelfxSheetCache.instance;
    for (final fx in combat.activeSkills) {
      final hb = fx.worldHitbox(player);
      final alpha = (1.0 - fx.progress * 0.75).clamp(0.15, 1.0);
      if (fx.skillId == DungeonSilkSkillId.scalesTempest ||
          fx.skillId == DungeonSilkSkillId.habeasAegis) {
        final r = fx.radiusOrLength * (0.65 + 0.35 * fx.progress);
        _drawFilledCircle(canvas, hb.center, r, fx.color.withValues(alpha: alpha * 0.25));
        _drawStrokedCircle(canvas, hb.center, r, fx.color.withValues(alpha: alpha), 2.6);
        _drawStrokedCircle(
          canvas,
          hb.center,
          r * 0.72,
          SpriteCastPalette.endesga32[19].withValues(alpha: alpha * 0.8),
          1.2,
        );
      } else if (fx.skillId == DungeonSilkSkillId.sovereignSunburst) {
        _drawFilledRect(canvas, hb, fx.color.withValues(alpha: alpha * 0.85));
        _drawFilledRect(
          canvas,
          Rect.fromLTWH(hb.left, hb.center.dy - 5.0, hb.width, 10.0),
          SpriteCastPalette.endesga32[19].withValues(alpha: alpha),
        );
        cache.drawSheetFrame(
          canvas: canvas,
          reusablePaint: _imgPaint,
          key: 'sunburst',
          worldX: player.centerX,
          worldY: player.centerY,
          frameIndex: (fx.progress * 24.0).floor(),
          scale: 0.42,
          opacity: alpha,
          blendMode: BlendMode.plus,
        );
      } else {
        _drawFilledRect(canvas, hb, fx.color.withValues(alpha: alpha * 0.75));
        _drawFilledRect(
          canvas,
          Rect.fromLTWH(hb.left, hb.center.dy - 2.5, hb.width, 5.0),
          SpriteCastPalette.endesga32[11].withValues(alpha: alpha),
        );
      }
    }
  }

  void _paintProjectiles(Canvas canvas) {
    for (final p in combat.projectiles) {
      if (p.expired) continue;
      final center = Offset(p.x, p.y);
      _drawFilledCircle(canvas, center, p.radius + 1.0, SpriteCastPalette.ink);
      _drawFilledCircle(canvas, center, p.radius, p.color);
      _drawFilledCircle(canvas, center, p.radius * 0.45, SpriteCastPalette.endesga32[19]);
    }
  }

  void _paintParticles(Canvas canvas) {
    for (final pt in particles) {
      if (pt.isExpired) continue;
      _drawFilledRect(
        canvas,
        Rect.fromCenter(center: Offset(pt.x, pt.y), width: pt.size, height: pt.size),
        pt.color.withValues(alpha: pt.alpha),
      );
    }
  }

  // ═══════════════════════════════════════════════════════════════════════════
  //  PASS 8–9: TERRARIA DYNAMIC CAVERN LIGHTING & FLOATING COMBAT NUMBERS
  // ═══════════════════════════════════════════════════════════════════════════

  void _paintCavernLightingPass(
    Canvas canvas,
    Offset cam,
    DungeonEraTheme theme,
    List<({Offset pos, Color color, double radius})> emitters,
    int animTick,
  ) {
    final darkness = (theme.cavernDarknessAlpha +
            (chamber.spec.isDarkCavern ? 0.16 : 0.0))
        .clamp(0.0, 0.68);
    if (darkness > 0.05) {
      _drawFilledRect(
        canvas,
        Rect.fromLTWH(cam.dx, cam.dy, kDungeonRefWidth, kDungeonRefHeight),
        SpriteCastPalette.ink.withValues(alpha: darkness * 0.55),
      );
    }

    final flicker = 0.92 + 0.08 * math.sin(worldTimeSec * 14.0);
    for (final em in emitters) {
      SpriteCastEngine.drawSteppedPixelLightPool(
        canvas,
        em.pos,
        color: em.color,
        radius: em.radius * flicker,
        px: 2.0,
        intensity: 0.72,
      );
    }
  }

  void _paintFloatingCombatNumbers(Canvas canvas) {
    if (_textCache.length > 64) {
      _textCache.clear();
    }
    for (final numItem in combat.floatingNumbers) {
      if (numItem.isExpired) continue;
      final alphaStep = (numItem.opacity * 5.0).round().clamp(1, 5);
      final cacheKey =
          '${numItem.text}|${numItem.isCritical}|${numItem.color.hashCode}|$alphaStep';
      final tp = _textCache.putIfAbsent(cacheKey, () {
        return TextPainter(
          text: TextSpan(
            text: numItem.text,
            style: TextStyle(
              color: numItem.color.withValues(alpha: alphaStep / 5.0),
              fontSize: numItem.isCritical ? 8.5 : 7.0,
              fontWeight: FontWeight.w900,
              shadows: const [
                Shadow(color: SpriteCastPalette.ink, offset: Offset(1, 1)),
              ],
            ),
          ),
          textDirection: TextDirection.ltr,
        )..layout();
      });
      tp.paint(canvas, Offset(numItem.x - tp.width * 0.5, numItem.y - tp.height * 0.5));
    }
  }

  @override
  bool shouldRepaint(covariant DungeonWorldPainter oldDelegate) => true;
}
