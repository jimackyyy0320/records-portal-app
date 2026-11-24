import 'dart:math' as math;
import 'package:flutter/material.dart';

import '../spritecast_engine.dart';
import 'dungeon_combat.dart';
import 'dungeon_models.dart';

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

/// Pixel-Perfect `320×180` 2D Action-Platformer Dungeon Renderer integrating:
/// - 4-layer era-shifting parallax backdrops (Acts I–VII)
/// - 16-neighbor cardinal Rule-Tile auto-tiling with ashlar seams, mossy caps & stalactites
/// - Crisp SpriteCast pixel art for all 19 tile types (zero system emojis!)
/// - Terraria-style cavern darkness + flickering torchlight & orbiting Umalo lantern
/// - Animated Silksong Alon hero (cape, squash-stretch, dash ghosts, grapple silk line, Bind cocoon, Parry dome)
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
  });

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
    canvas.drawRect(
      Offset.zero & size,
      Paint()..color = SpriteCastPalette.ink,
    );

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

    // PASS 3: Loot Drops (Bouncing Shards, Resolve Orbs, Silk Motes)
    _paintLootDrops(canvas, animTick);

    // PASS 4: Enemies & Multi-Phase Bosses (with Telegraphs, Shields & Stagger Stars)
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

    // PASS 7: Particle Bursts (Sparks, Dust, Crate Splinters, Embers)
    _paintParticles(canvas);

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
      canvas.drawRect(
        Rect.fromLTWH(0, b * 45.0, kDungeonRefWidth, 46.0),
        Paint()..color = col..isAntiAlias = false,
      );
    }

    // Ambient distant stars / cavern spores (0.08x parallax)
    final sporePaint = Paint()
      ..color = theme.accentHighlight.withValues(alpha: 0.35)
      ..isAntiAlias = false;
    for (var i = 0; i < 18; i++) {
      final baseX = SpriteCastEngine.hash01(i * 13, theme.actNumber) * 360.0;
      final baseY = SpriteCastEngine.hash01(i * 29, theme.actNumber + 5) * 140.0;
      final sx = ((baseX - cam.dx * 0.08) % 340.0 + 340.0) % 340.0 - 10.0;
      final sy = baseY + math.sin(worldTimeSec * 1.4 + i) * 3.0;
      canvas.drawRect(Rect.fromLTWH(sx.roundToDouble(), sy.roundToDouble(), 1.5, 1.5), sporePaint);
    }

    // Layer 1: Far Era Silhouettes (0.16x parallax)
    final farPaint = Paint()..color = theme.parallaxFar..isAntiAlias = false;
    final farOffset = (cam.dx * 0.16) % 80.0;
    for (var i = -1; i < 6; i++) {
      final bx = i * 80.0 - farOffset;
      final pillarH = 72.0 + (i.abs() % 3) * 18.0;
      // Distant cavern arches / gothic towers / bridge silhouettes
      canvas.drawRect(
        Rect.fromLTWH(bx, kDungeonRefHeight - pillarH, 34.0, pillarH),
        farPaint,
      );
      if (theme.actNumber == 2 || theme.actNumber == 3 || theme.actNumber == 7) {
        // Pointed belltower / Barasoain arch spire silhouette
        canvas.drawRect(
          Rect.fromLTWH(bx + 8.0, kDungeonRefHeight - pillarH - 18.0, 18.0, 18.0),
          farPaint,
        );
        canvas.drawRect(
          Rect.fromLTWH(bx + 14.0, kDungeonRefHeight - pillarH - 28.0, 6.0, 10.0),
          farPaint,
        );
      } else {
        // Stalactite / cavern ridge ceiling silhouette
        canvas.drawRect(
          Rect.fromLTWH(bx + 26.0, 0.0, 22.0, 26.0 + (i.abs() % 2) * 14.0),
          farPaint,
        );
      }
    }

    // Layer 2: Mid-Ground Ruined Pillars & Hanging Chains (0.38x parallax)
    final midPaint = Paint()..color = theme.parallaxMid..isAntiAlias = false;
    final midOffset = (cam.dx * 0.38) % 96.0;
    for (var i = -1; i < 5; i++) {
      final px = i * 96.0 - midOffset;
      // Ruined vertical column
      canvas.drawRect(
        Rect.fromLTWH(px + 12.0, 18.0, 14.0, kDungeonRefHeight - 18.0),
        midPaint,
      );
      // Horizontal ruined lintel
      canvas.drawRect(
        Rect.fromLTWH(px + 4.0, 14.0, 30.0, 8.0),
        midPaint,
      );
      // Hanging iron chain with subtle wind sway
      final chainSway = SpriteCastEngine.windSwayPx(animTick, i * 19, px: 1.0);
      for (var cy = 22.0; cy < 84.0; cy += 6.0) {
        canvas.drawRect(
          Rect.fromLTWH(px + 56.0 + chainSway, cy, 2.0, 4.0),
          midPaint,
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
    canvas.drawRect(
      rect,
      Paint()..color = theme.stoneMid..isAntiAlias = false,
    );

    // Deterministic ashlar brick seams (breaks up flat tile repetition!)
    final h = SpriteCastEngine.hash01(col * 17 + 3, row * 31 + 7);
    final mortarPaint = Paint()
      ..color = theme.stoneDark.withValues(alpha: 0.72)
      ..isAntiAlias = false;
    canvas.drawRect(Rect.fromLTWH(rect.left, rect.top + 7, 16, 1), mortarPaint);
    final seamX = (row.isEven ? 7.0 : 12.0);
    canvas.drawRect(Rect.fromLTWH(rect.left + seamX, rect.top, 1, 7), mortarPaint);
    canvas.drawRect(
      Rect.fromLTWH(rect.left + ((seamX + 6) % 14), rect.top + 8, 1, 8),
      mortarPaint,
    );
    if (h > 0.72) {
      canvas.drawRect(
        Rect.fromLTWH(rect.left + 3, rect.top + 3, 3, 2),
        Paint()..color = theme.stoneLight.withValues(alpha: 0.32)..isAntiAlias = false,
      );
    }

    // Secret Wall subtle fracture hint (glows softly when Tarsier Lantern Sight charm is equipped!)
    if (tile == DungeonTileType.secretWall) {
      final hasSight = progress.hasCharmEquipped('tarsier_lantern');
      final crackColor = hasSight
          ? SpriteCastPalette.endesga32[11].withValues(alpha: 0.65)
          : SpriteCastPalette.ink.withValues(alpha: 0.55);
      canvas.drawRect(Rect.fromLTWH(rect.left + 4, rect.top + 3, 2, 5), Paint()..color = crackColor);
      canvas.drawRect(Rect.fromLTWH(rect.left + 6, rect.top + 7, 4, 2), Paint()..color = crackColor);
      canvas.drawRect(Rect.fromLTWH(rect.left + 9, rect.top + 9, 2, 4), Paint()..color = crackColor);
    }

    // Exposed Cardinal Edges (Rule-Tile Auto-Tiling!)
    if (openN) {
      if (tile == DungeonTileType.mossyStone) {
        final sway = SpriteCastEngine.windSwayPx(animTick, col * 11 + row, px: 0.8);
        canvas.drawRect(
          Rect.fromLTWH(rect.left, rect.top, 16, 3),
          Paint()..color = theme.mossOrTrim..isAntiAlias = false,
        );
        canvas.drawRect(
          Rect.fromLTWH(rect.left + 2 + sway, rect.top + 3, 3, 2),
          Paint()..color = theme.mossOrTrim..isAntiAlias = false,
        );
        canvas.drawRect(
          Rect.fromLTWH(rect.left + 10, rect.top + 3, 4, 2),
          Paint()..color = theme.mossOrTrim..isAntiAlias = false,
        );
      } else {
        canvas.drawRect(
          Rect.fromLTWH(rect.left, rect.top + 1, 16, 2),
          Paint()..color = theme.stoneLight..isAntiAlias = false,
        );
      }
      canvas.drawRect(
        Rect.fromLTWH(rect.left, rect.top, 16, 1),
        Paint()..color = SpriteCastPalette.ink..isAntiAlias = false,
      );
    }

    if (openS) {
      canvas.drawRect(
        Rect.fromLTWH(rect.left, rect.bottom - 3, 16, 2),
        Paint()..color = theme.stoneDark..isAntiAlias = false,
      );
      canvas.drawRect(
        Rect.fromLTWH(rect.left, rect.bottom - 1, 16, 1),
        Paint()..color = SpriteCastPalette.ink..isAntiAlias = false,
      );
      // Hanging cavern stalactite nub on occasional exposed ceilings
      if (h > 0.78) {
        canvas.drawRect(
          Rect.fromLTWH(rect.left + 6, rect.bottom, 4, 3),
          Paint()..color = theme.stoneDark..isAntiAlias = false,
        );
        canvas.drawRect(
          Rect.fromLTWH(rect.left + 7, rect.bottom + 3, 2, 2),
          Paint()..color = SpriteCastPalette.ink..isAntiAlias = false,
        );
      }
    }

    if (openW) {
      canvas.drawRect(
        Rect.fromLTWH(rect.left, rect.top, 1, 16),
        Paint()..color = SpriteCastPalette.ink..isAntiAlias = false,
      );
      canvas.drawRect(
        Rect.fromLTWH(rect.left + 1, rect.top + 1, 1, 14),
        Paint()..color = theme.stoneLight.withValues(alpha: 0.45)..isAntiAlias = false,
      );
    }

    if (openE) {
      canvas.drawRect(
        Rect.fromLTWH(rect.right - 1, rect.top, 1, 16),
        Paint()..color = SpriteCastPalette.ink..isAntiAlias = false,
      );
      canvas.drawRect(
        Rect.fromLTWH(rect.right - 2, rect.top + 1, 1, 14),
        Paint()..color = theme.stoneDark..isAntiAlias = false,
      );
    }
  }

  void _drawOneWayBridge(Canvas canvas, Rect r) {
    // Beveled cedar wooden bridge plank with underside shadow & iron bolts
    canvas.drawRect(Rect.fromLTWH(r.left, r.top, 16, 5), Paint()..color = SpriteCastPalette.ink);
    canvas.drawRect(Rect.fromLTWH(r.left, r.top + 1, 16, 2), Paint()..color = SpriteCastPalette.woodLight);
    canvas.drawRect(Rect.fromLTWH(r.left, r.top + 3, 16, 1), Paint()..color = SpriteCastPalette.woodDark);
    // Support joists
    canvas.drawRect(Rect.fromLTWH(r.left + 2, r.top + 5, 2, 3), Paint()..color = SpriteCastPalette.woodEdge);
    canvas.drawRect(Rect.fromLTWH(r.right - 4, r.top + 5, 2, 3), Paint()..color = SpriteCastPalette.woodEdge);
    // Iron bolt studs
    canvas.drawRect(Rect.fromLTWH(r.left + 2, r.top + 1.5, 1.5, 1.5), Paint()..color = SpriteCastPalette.endesga32[20]);
    canvas.drawRect(Rect.fromLTWH(r.right - 3.5, r.top + 1.5, 1.5, 1.5), Paint()..color = SpriteCastPalette.endesga32[20]);
  }

  void _drawLadderVine(Canvas canvas, Rect r, DungeonEraTheme theme) {
    // Dual bamboo rails + cross rungs
    canvas.drawRect(Rect.fromLTWH(r.left + 3, r.top, 2, 16), Paint()..color = SpriteCastPalette.woodDark);
    canvas.drawRect(Rect.fromLTWH(r.right - 5, r.top, 2, 16), Paint()..color = SpriteCastPalette.woodDark);
    canvas.drawRect(Rect.fromLTWH(r.left + 3.5, r.top, 1, 16), Paint()..color = SpriteCastPalette.woodLight);
    canvas.drawRect(Rect.fromLTWH(r.right - 4.5, r.top, 1, 16), Paint()..color = SpriteCastPalette.woodLight);
    for (var y = 2.0; y < 16.0; y += 5.0) {
      canvas.drawRect(Rect.fromLTWH(r.left + 4, r.top + y, 8, 2), Paint()..color = SpriteCastPalette.woodMid);
    }
  }

  void _drawSpikesTile(Canvas canvas, Rect r, int col, int row) {
    // 3 razor-sharp pixel iron spikes with metallic sheen tips
    for (var i = 0; i < 3; i++) {
      final bx = r.left + 1.0 + i * 5.0;
      canvas.drawRect(Rect.fromLTWH(bx, r.bottom - 4, 4, 4), Paint()..color = SpriteCastPalette.ink);
      canvas.drawRect(Rect.fromLTWH(bx + 1, r.bottom - 8, 2, 6), Paint()..color = SpriteCastPalette.endesga32[22]);
      canvas.drawRect(Rect.fromLTWH(bx + 1.5, r.bottom - 11, 1, 4), Paint()..color = SpriteCastPalette.endesga32[20]);
      canvas.drawRect(Rect.fromLTWH(bx + 1.5, r.bottom - 12, 1, 1.5), Paint()..color = SpriteCastPalette.endesga32[19]);
    }
  }

  void _drawCrumbleBlock(Canvas canvas, Rect r, int col, int row, DungeonEraTheme theme) {
    final st = chamber.crumbleBlocks['${col}_$row'];
    final jitterX = (st != null && st.shakeTimer > 0.0)
        ? math.sin(worldTimeSec * 68.0) * 1.6
        : 0.0;
    final shifted = r.shift(Offset(jitterX, 0));
    canvas.drawRect(shifted, Paint()..color = SpriteCastPalette.ink);
    canvas.drawRect(shifted.deflate(1), Paint()..color = SpriteCastPalette.woodMid);
    canvas.drawRect(
      Rect.fromLTWH(shifted.left + 1, shifted.top + 1, 14, 2),
      Paint()..color = SpriteCastPalette.cream,
    );
    // Diagonal stress cracks
    canvas.drawRect(Rect.fromLTWH(shifted.left + 4, shifted.top + 4, 2, 6), Paint()..color = SpriteCastPalette.ink);
    canvas.drawRect(Rect.fromLTWH(shifted.left + 9, shifted.top + 6, 3, 5), Paint()..color = SpriteCastPalette.ink);
  }

  void _drawPogoLantern(Canvas canvas, Rect r, DungeonEraTheme theme, int animTick) {
    final bob = math.sin(worldTimeSec * 3.2 + r.left) * 1.2;
    final cy = r.center.dy + bob;
    // Hanging iron chain
    canvas.drawRect(Rect.fromLTWH(r.center.dx - 0.5, r.top, 1.5, 4), Paint()..color = SpriteCastPalette.endesga32[22]);
    // Outer brass/iron ring
    canvas.drawRect(
      Rect.fromCenter(center: Offset(r.center.dx, cy), width: 10, height: 10),
      Paint()..color = SpriteCastPalette.ink,
    );
    canvas.drawRect(
      Rect.fromCenter(center: Offset(r.center.dx, cy), width: 8, height: 8),
      Paint()..color = SpriteCastPalette.endesga32[10],
    );
    // Glowing inner core (signals pogo-bounceable!)
    canvas.drawRect(
      Rect.fromCenter(center: Offset(r.center.dx, cy), width: 5, height: 5),
      Paint()..color = SpriteCastPalette.endesga32[11],
    );
    canvas.drawRect(
      Rect.fromCenter(center: Offset(r.center.dx, cy), width: 2.5, height: 2.5),
      Paint()..color = SpriteCastPalette.endesga32[19],
    );
  }

  void _drawGrappleRing(Canvas canvas, Rect r, int animTick) {
    final isHighlighted = highlightedGrappleAnchor != null &&
        (highlightedGrappleAnchor! - r.center).distance < 10.0;
    final ringCol = isHighlighted
        ? SpriteCastPalette.endesga32[18]
        : SpriteCastPalette.endesga32[10];
    // Ornate brass grapple anchor ring
    canvas.drawCircle(r.center, 5.5, Paint()..color = SpriteCastPalette.ink);
    canvas.drawCircle(
      r.center,
      4.2,
      Paint()
        ..color = ringCol
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.0,
    );
    if (isHighlighted) {
      final pulse = 6.5 + math.sin(worldTimeSec * 8.0) * 1.8;
      canvas.drawCircle(
        r.center,
        pulse,
        Paint()
          ..color = SpriteCastPalette.endesga32[18].withValues(alpha: 0.65)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.0,
      );
    }
  }

  void _drawBreakableCrate(Canvas canvas, Rect r, int col, int row) {
    final br = chamber.breakables['${col}_$row'];
    final flash = br != null && br.hitFlashTimer > 0.0;
    final box = Rect.fromLTWH(r.left + 1, r.top + 2, 14, 14);
    canvas.drawRect(box, Paint()..color = SpriteCastPalette.ink);
    canvas.drawRect(
      box.deflate(1),
      Paint()..color = flash ? SpriteCastPalette.endesga32[19] : SpriteCastPalette.woodMid,
    );
    if (!flash) {
      canvas.drawRect(Rect.fromLTWH(box.left + 1, box.top + 1, 12, 2), Paint()..color = SpriteCastPalette.woodLight);
      canvas.drawRect(Rect.fromLTWH(box.left + 2, box.top + 6, 10, 2), Paint()..color = SpriteCastPalette.woodDark);
      // Cross brace
      canvas.drawRect(Rect.fromLTWH(box.left + 6, box.top + 2, 2, 10), Paint()..color = SpriteCastPalette.woodDark);
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
    // Draw 1..3 jagged crystal shards proportional to remaining ore HP
    if (hp >= 1) {
      canvas.drawRect(Rect.fromLTWH(r.left + 5, r.bottom - 11, 5, 11), Paint()..color = SpriteCastPalette.ink);
      canvas.drawRect(Rect.fromLTWH(r.left + 6, r.bottom - 10, 3, 9), Paint()..color = colMain);
      canvas.drawRect(Rect.fromLTWH(r.left + 6.5, r.bottom - 9, 1, 4), Paint()..color = SpriteCastPalette.endesga32[19]);
    }
    if (hp >= 2) {
      canvas.drawRect(Rect.fromLTWH(r.left + 1, r.bottom - 7, 4, 7), Paint()..color = SpriteCastPalette.ink);
      canvas.drawRect(Rect.fromLTWH(r.left + 2, r.bottom - 6, 2, 5), Paint()..color = SpriteCastPalette.endesga32[17]);
    }
    if (hp >= 3) {
      canvas.drawRect(Rect.fromLTWH(r.left + 10, r.bottom - 8, 5, 8), Paint()..color = SpriteCastPalette.ink);
      canvas.drawRect(Rect.fromLTWH(r.left + 11, r.bottom - 7, 3, 6), Paint()..color = colMain);
    }
  }

  void _drawSwitchPedestal(Canvas canvas, Rect r, int col, int row, int animTick) {
    final br = chamber.breakables['${col}_$row'];
    final active = (br?.brokenOrTriggered ?? false) || chamber.roomGateUnlocked;
    canvas.drawRect(Rect.fromLTWH(r.left + 3, r.bottom - 12, 10, 12), Paint()..color = SpriteCastPalette.ink);
    canvas.drawRect(Rect.fromLTWH(r.left + 4, r.bottom - 11, 8, 10), Paint()..color = SpriteCastPalette.endesga32[22]);
    // Crystal orb switch cap
    canvas.drawRect(
      Rect.fromLTWH(r.left + 5, r.top + 1, 6, 5),
      Paint()
        ..color = active
            ? SpriteCastPalette.endesga32[18]
            : SpriteCastPalette.endesga32[8],
    );
  }

  void _drawLockedGate(Canvas canvas, Rect r, DungeonEraTheme theme) {
    canvas.drawRect(Rect.fromLTWH(r.left + 1, r.top, 14, 16), Paint()..color = SpriteCastPalette.ink);
    for (var bx = 3.0; bx <= 11.0; bx += 4.0) {
      canvas.drawRect(Rect.fromLTWH(r.left + bx, r.top, 2, 16), Paint()..color = SpriteCastPalette.endesga32[21]);
    }
    canvas.drawRect(Rect.fromLTWH(r.left + 2, r.top + 6, 12, 3), Paint()..color = SpriteCastPalette.endesga32[10]);
  }

  void _drawCampfireBench(Canvas canvas, Rect r, int animTick) {
    // Iconic Bahay-Pulungan Sanctuary Bench + crackling pixel campfire!
    // Wooden bench on left half
    canvas.drawRect(Rect.fromLTWH(r.left - 4, r.bottom - 8, 15, 8), Paint()..color = SpriteCastPalette.ink);
    canvas.drawRect(Rect.fromLTWH(r.left - 3, r.bottom - 7, 13, 2), Paint()..color = SpriteCastPalette.woodLight);
    canvas.drawRect(Rect.fromLTWH(r.left - 3, r.bottom - 4, 13, 2), Paint()..color = SpriteCastPalette.woodMid);
    // Campfire logs & animated 3-tone pixel flame on right
    final flick = (animTick ~/ 4) % 3;
    canvas.drawRect(Rect.fromLTWH(r.right - 4, r.bottom - 3, 7, 3), Paint()..color = SpriteCastPalette.woodDark);
    canvas.drawRect(
      Rect.fromLTWH(r.right - 3, r.bottom - 8 - flick * 0.8, 5, 6),
      Paint()..color = SpriteCastPalette.endesga32[9],
    );
    canvas.drawRect(
      Rect.fromLTWH(r.right - 2, r.bottom - 6 - flick * 0.5, 3, 4),
      Paint()..color = SpriteCastPalette.endesga32[11],
    );
  }

  void _drawLoreTablet(Canvas canvas, Rect r, DungeonEraTheme theme, int animTick) {
    final pulse = 0.65 + 0.35 * math.sin(worldTimeSec * 3.5);
    canvas.drawRect(Rect.fromLTWH(r.left + 2, r.top + 1, 12, 15), Paint()..color = SpriteCastPalette.ink);
    canvas.drawRect(Rect.fromLTWH(r.left + 3, r.top + 2, 10, 13), Paint()..color = SpriteCastPalette.endesga32[23]);
    // Glowing Baybayin / Constitutional rune lines
    final runeCol = SpriteCastPalette.endesga32[18].withValues(alpha: pulse);
    canvas.drawRect(Rect.fromLTWH(r.left + 5, r.top + 4, 6, 1.5), Paint()..color = runeCol);
    canvas.drawRect(Rect.fromLTWH(r.left + 5, r.top + 7, 5, 1.5), Paint()..color = runeCol);
    canvas.drawRect(Rect.fromLTWH(r.left + 5, r.top + 10, 6, 1.5), Paint()..color = runeCol);
  }

  void _drawTreasureChest(Canvas canvas, Rect r, int col, int row) {
    final chestKey = '${chamber.spec.id}:${col}_$row';
    final opened = progress.openedChestIds.contains(chestKey);
    canvas.drawRect(Rect.fromLTWH(r.left + 1, r.bottom - 11, 14, 11), Paint()..color = SpriteCastPalette.ink);
    canvas.drawRect(Rect.fromLTWH(r.left + 2, r.bottom - 10, 12, 9), Paint()..color = SpriteCastPalette.woodMid);
    canvas.drawRect(
      Rect.fromLTWH(r.left + 2, r.bottom - 10, 12, 2),
      Paint()..color = opened ? SpriteCastPalette.woodDark : SpriteCastPalette.endesga32[10],
    );
    canvas.drawRect(
      Rect.fromLTWH(r.left + 6.5, r.bottom - 7, 3, 3),
      Paint()..color = opened ? SpriteCastPalette.endesga32[22] : SpriteCastPalette.endesga32[11],
    );
  }

  void _drawRoomPortal(Canvas canvas, Rect r, DungeonEraTheme theme, int animTick) {
    final glow = 0.55 + 0.45 * math.sin(worldTimeSec * 4.0);
    canvas.drawRect(Rect.fromLTWH(r.left + 1, r.top - 4, 14, 20), Paint()..color = SpriteCastPalette.ink);
    canvas.drawRect(
      Rect.fromLTWH(r.left + 3, r.top - 2, 10, 18),
      Paint()..color = theme.accentHighlight.withValues(alpha: 0.35 + 0.30 * glow),
    );
    canvas.drawRect(
      Rect.fromLTWH(r.left + 5, r.top + 1, 6, 15),
      Paint()..color = SpriteCastPalette.endesga32[19].withValues(alpha: 0.45 * glow),
    );
  }

  void _drawWallTorch(Canvas canvas, Rect r, DungeonEraTheme theme, int animTick) {
    final flick = (animTick ~/ 5) % 2;
    canvas.drawRect(Rect.fromLTWH(r.center.dx - 1.5, r.top + 6, 3, 7), Paint()..color = SpriteCastPalette.woodDark);
    canvas.drawRect(
      Rect.fromLTWH(r.center.dx - 2.5, r.top + 2 - flick, 5, 5),
      Paint()..color = theme.torchGlow,
    );
    canvas.drawRect(
      Rect.fromLTWH(r.center.dx - 1.2, r.top + 3.5 - flick * 0.5, 2.4, 2.8),
      Paint()..color = SpriteCastPalette.endesga32[19],
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
      canvas.drawRect(
        Rect.fromCenter(center: pos, width: 5.5, height: 5.5),
        Paint()..color = SpriteCastPalette.ink,
      );
      canvas.drawRect(
        Rect.fromCenter(center: pos, width: 3.5, height: 3.5),
        Paint()..color = col,
      );
      canvas.drawRect(
        Rect.fromLTWH(pos.dx - 1, pos.dy - 1, 1.2, 1.2),
        Paint()..color = SpriteCastPalette.endesga32[19],
      );
    }
  }

  void _drawDungeonEntity(
    Canvas canvas,
    DungeonEntityRenderSpec e,
    int animTick,
  ) {
    final hb = e.hitbox;
    final bob = math.sin(e.animPhase * 4.0) * (e.isBoss ? 1.4 : 0.9);
    final drawRect = hb.shift(Offset(0, bob));

    // Aim telegraph laser line for marksmen / bosses before firing
    if (e.aimTelegraphEnd != null) {
      canvas.drawLine(
        hb.center,
        e.aimTelegraphEnd!,
        Paint()
          ..color = SpriteCastPalette.endesga32[26].withValues(alpha: 0.72)
          ..strokeWidth = 1.2,
      );
    }

    // Contact shadow beneath grounded entities
    SpriteCastEngine.drawSteppedContactShadow(
      canvas,
      Rect.fromCenter(
        center: Offset(hb.center.dx, hb.bottom + 0.5),
        width: hb.width * 0.9,
        height: 3.5,
      ),
      castDx: 1.5,
      castDy: 1.0,
      strength: 0.7,
      oval: true,
    );

    final isFlashing = e.hitFlashTimer > 0.0;
    final bodyColor = isFlashing
        ? SpriteCastPalette.endesga32[19]
        : (e.isTelegraphing
            ? Color.lerp(e.primaryColor, SpriteCastPalette.endesga32[11], 0.55)!
            : e.primaryColor);

    // Crisp 1px ink outline silhouette + shaded torso + head/crest
    canvas.drawRect(drawRect.inflate(1.0), Paint()..color = SpriteCastPalette.ink);
    canvas.drawRect(drawRect, Paint()..color = bodyColor);
    // Accent shoulder/helm band
    canvas.drawRect(
      Rect.fromLTWH(drawRect.left + 1, drawRect.top + 1, drawRect.width - 2, drawRect.height * 0.30),
      Paint()..color = isFlashing ? SpriteCastPalette.endesga32[19] : e.accentColor,
    );
    // Glowing eyes facing Alon
    final eyeX = e.facing >= 0 ? drawRect.right - 4.0 : drawRect.left + 2.0;
    canvas.drawRect(
      Rect.fromLTWH(eyeX, drawRect.top + 3.0, 2.0, 2.0),
      Paint()..color = e.isTelegraphing ? SpriteCastPalette.endesga32[26] : SpriteCastPalette.endesga32[11],
    );

    // Front shield indicator (signals to pogo or dash behind!)
    if (e.isShieldedFront) {
      final sx = e.facing >= 0 ? drawRect.right : drawRect.left - 3.0;
      canvas.drawRect(
        Rect.fromLTWH(sx, drawRect.top + 2.0, 3.0, drawRect.height - 3.0),
        Paint()..color = SpriteCastPalette.endesga32[20],
      );
    }

    // Telegraph warning exclamation glint above enemy before strike!
    if (e.isTelegraphing) {
      canvas.drawRect(
        Rect.fromCenter(center: Offset(drawRect.center.dx, drawRect.top - 6.0), width: 3, height: 6),
        Paint()..color = SpriteCastPalette.endesga32[26],
      );
    }

    // Staggered golden halo stars (signals Constitutional Counter-Break!)
    if (e.isStaggered) {
      for (var s = 0; s < 3; s++) {
        final angle = worldTimeSec * 6.0 + s * (math.pi * 2 / 3);
        final sx = drawRect.center.dx + math.cos(angle) * 7.0;
        final sy = drawRect.top - 5.0 + math.sin(angle) * 2.5;
        canvas.drawRect(
          Rect.fromCenter(center: Offset(sx, sy), width: 2.5, height: 2.5),
          Paint()..color = SpriteCastPalette.endesga32[11],
        );
      }
    }

    // Compact HP bar above damaged non-boss enemies
    if (!e.isBoss && e.hp < e.maxHp && e.maxHp > 0) {
      final frac = (e.hp / e.maxHp).clamp(0.0, 1.0);
      final barRect = Rect.fromLTWH(drawRect.left, drawRect.top - 4.5, drawRect.width, 2.5);
      canvas.drawRect(barRect, Paint()..color = SpriteCastPalette.ink);
      canvas.drawRect(
        Rect.fromLTWH(barRect.left + 0.5, barRect.top + 0.5, (barRect.width - 1) * frac, 1.5),
        Paint()..color = SpriteCastPalette.endesga32[8],
      );
    }
  }

  void _paintSilkGrappleLine(Canvas canvas) {
    if (!player.grappleActive) return;
    canvas.drawLine(
      Offset(player.centerX, player.centerY),
      Offset(player.grappleTargetX, player.grappleTargetY),
      Paint()
        ..color = SpriteCastPalette.endesga32[18]
        ..strokeWidth = 1.6,
    );
    canvas.drawCircle(
      Offset(player.grappleTargetX, player.grappleTargetY),
      3.0,
      Paint()..color = SpriteCastPalette.endesga32[19],
    );
  }

  void _paintDashAfterimages(Canvas canvas) {
    for (final ghost in player.afterimages) {
      canvas.drawRect(
        Rect.fromLTWH(ghost.x, ghost.y, player.width, player.height),
        Paint()
          ..color = SpriteCastPalette.endesga32[18]
              .withValues(alpha: (ghost.alpha * 0.55).clamp(0.0, 0.55)),
      );
    }
  }

  void _paintUmaloLanternFamiliar(
    Canvas canvas,
    DungeonEraTheme theme,
    int animTick,
    List<({Offset pos, Color color, double radius})> lightEmitters,
  ) {
    // Orbiting Tarsier familiar trailing smoothly behind Alon's shoulder
    final ux = player.centerX - player.facing * 11.0;
    final uy = player.y - 5.0 + math.sin(worldTimeSec * 4.4) * 2.2;
    final pos = Offset(ux, uy);

    canvas.drawRect(
      Rect.fromCenter(center: pos, width: 6.5, height: 6.5),
      Paint()..color = SpriteCastPalette.ink,
    );
    canvas.drawRect(
      Rect.fromCenter(center: pos, width: 4.5, height: 4.5),
      Paint()..color = SpriteCastPalette.woodLight,
    );
    // Big bright Tarsier eyes + glowing lantern pixel
    canvas.drawRect(
      Rect.fromLTWH(pos.dx + (player.facing > 0 ? 0.5 : -2.0), pos.dy - 1.0, 1.5, 1.5),
      Paint()..color = SpriteCastPalette.endesga32[11],
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
    // Invulnerability flicker after damage (never hides during Silk Dash)
    if (player.invulnTimer > 0.0 && !player.isDashing && (animTick % 4 < 2)) {
      return;
    }

    final cx = player.centerX;
    final bottomY = player.bottom;

    // Grounded contact shadow when near floor
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

    // 1. Flowing Silksong crimson/era cape trailing opposite velocity
    final capeSway = math.sin(worldTimeSec * 9.0) * 1.4 - (player.vx * 0.015).clamp(-3.5, 3.5);
    final capePath = Path()
      ..moveTo(-f * 2.0, -h + 5.0 + breathY)
      ..lineTo(-f * 8.5 + capeSway, -3.5)
      ..lineTo(-f * 3.5 + capeSway * 0.5, -2.0)
      ..lineTo(f * 1.0, -h + 7.0 + breathY)
      ..close();
    canvas.drawPath(capePath, Paint()..color = SpriteCastPalette.endesga32[8]);
    canvas.drawPath(
      capePath,
      Paint()
        ..color = SpriteCastPalette.ink
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.0,
    );

    // 2. Crisp dark-ink outline torso + boots
    canvas.drawRect(
      Rect.fromLTWH(-w * 0.5 - 0.5, -h + breathY, w + 1.0, h - 1.0),
      Paint()..color = SpriteCastPalette.ink,
    );
    // Tunic / Barong attire
    canvas.drawRect(
      Rect.fromLTWH(-w * 0.42, -h + 5.5 + breathY, w * 0.84, 5.5),
      Paint()..color = SpriteCastPalette.endesga32[2],
    );
    // Animated running legs
    canvas.drawRect(
      Rect.fromLTWH(-3.2 + stride * 0.5, -3.5, 2.4, 3.5),
      Paint()..color = SpriteCastPalette.endesga32[24],
    );
    canvas.drawRect(
      Rect.fromLTWH(0.8 - stride * 0.5, -3.5, 2.4, 3.5),
      Paint()..color = SpriteCastPalette.endesga32[24],
    );

    // 3. Head, hair crest & focused eyes
    canvas.drawRect(
      Rect.fromLTWH(-4.0, -h + 0.8 + breathY, 8.0, 5.0),
      Paint()..color = SpriteCastPalette.endesga32[30],
    );
    // Hair + golden salakot/headband accent
    canvas.drawRect(
      Rect.fromLTWH(-4.4, -h - 0.4 + breathY, 8.8, 2.4),
      Paint()..color = SpriteCastPalette.endesga32[25],
    );
    canvas.drawRect(
      Rect.fromLTWH(-4.0, -h + 1.4 + breathY, 8.0, 1.0),
      Paint()..color = theme.accentHighlight,
    );
    // Crisp eyes pointing in facing direction
    canvas.drawRect(
      Rect.fromLTWH(f > 0 ? 1.2 : -3.0, -h + 3.0 + breathY, 1.5, 1.5),
      Paint()..color = SpriteCastPalette.ink,
    );

    // 4. Held Needle/Bolo Blade at Alon's side (colored by Blade Tier!)
    canvas.drawRect(
      Rect.fromLTWH(f > 0 ? 3.5 : -9.5, -7.0 + breathY, 6.0, 1.8),
      Paint()..color = progress.bladeTier.slashArcColor,
    );

    canvas.restore();

    // 5. Active Silk Bind golden healing thread cocoon
    if (combat.isChannelingBind) {
      final p = combat.bindProgress;
      canvas.drawCircle(
        Offset(cx, player.centerY),
        10.0 + (1.0 - p) * 6.0,
        Paint()
          ..color = SpriteCastPalette.endesga32[12].withValues(alpha: 0.78)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.8,
      );
    }

    // 6. Active Habeas Aegis Parry Dome!
    if (combat.isParryActive) {
      canvas.drawCircle(
        Offset(cx, player.centerY),
        13.0,
        Paint()
          ..color = SpriteCastPalette.endesga32[12].withValues(alpha: 0.28),
      );
      canvas.drawCircle(
        Offset(cx, player.centerY),
        13.0,
        Paint()
          ..color = SpriteCastPalette.endesga32[11]
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.6,
      );
    }
  }

  void _paintActiveSlashes(Canvas canvas) {
    for (final slash in combat.activeSlashes) {
      final hb = slash.worldHitbox(player);
      final alpha = (1.0 - slash.progress * 0.85).clamp(0.15, 1.0);
      final outerPaint = Paint()
        ..color = slash.arcColor.withValues(alpha: alpha)
        ..style = PaintingStyle.stroke
        ..strokeWidth = slash.comboStep == 2 ? 4.2 : 2.8;
      final corePaint = Paint()
        ..color = SpriteCastPalette.endesga32[19].withValues(alpha: alpha)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.4;

      double startAngle;
      const sweepAngle = math.pi * 0.82;
      switch (slash.direction) {
        case DungeonSlashDirection.right:
          startAngle = -math.pi * 0.41;
          break;
        case DungeonSlashDirection.left:
          startAngle = math.pi - math.pi * 0.41;
          break;
        case DungeonSlashDirection.up:
          startAngle = -math.pi * 0.91;
          break;
        case DungeonSlashDirection.down:
          startAngle = math.pi * 0.09;
          break;
      }
      canvas.drawArc(hb, startAngle, sweepAngle, false, outerPaint);
      canvas.drawArc(hb.deflate(2.0), startAngle, sweepAngle, false, corePaint);
    }
  }

  void _paintActiveSkillEffects(Canvas canvas) {
    for (final fx in combat.activeSkills) {
      final hb = fx.worldHitbox(player);
      final alpha = (1.0 - fx.progress * 0.75).clamp(0.15, 1.0);
      if (fx.skillId == DungeonSilkSkillId.scalesTempest ||
          fx.skillId == DungeonSilkSkillId.habeasAegis) {
        final r = fx.radiusOrLength * (0.65 + 0.35 * fx.progress);
        canvas.drawCircle(
          hb.center,
          r,
          Paint()
            ..color = fx.color.withValues(alpha: alpha * 0.25),
        );
        canvas.drawCircle(
          hb.center,
          r,
          Paint()
            ..color = fx.color.withValues(alpha: alpha)
            ..style = PaintingStyle.stroke
            ..strokeWidth = 2.6,
        );
        canvas.drawCircle(
          hb.center,
          r * 0.72,
          Paint()
            ..color = SpriteCastPalette.endesga32[19].withValues(alpha: alpha * 0.8)
            ..style = PaintingStyle.stroke
            ..strokeWidth = 1.2,
        );
      } else if (fx.skillId == DungeonSilkSkillId.sovereignSunburst) {
        canvas.drawRect(hb, Paint()..color = fx.color.withValues(alpha: alpha * 0.85));
        canvas.drawRect(
          Rect.fromLTWH(hb.left, hb.center.dy - 5.0, hb.width, 10.0),
          Paint()..color = SpriteCastPalette.endesga32[19].withValues(alpha: alpha),
        );
      } else {
        // Sanduguan Thread blazing lance trail
        canvas.drawRect(hb, Paint()..color = fx.color.withValues(alpha: alpha * 0.75));
        canvas.drawRect(
          Rect.fromLTWH(hb.left, hb.center.dy - 2.5, hb.width, 5.0),
          Paint()..color = SpriteCastPalette.endesga32[11].withValues(alpha: alpha),
        );
      }
    }
  }

  void _paintProjectiles(Canvas canvas) {
    for (final p in combat.projectiles) {
      if (p.expired) continue;
      canvas.drawCircle(Offset(p.x, p.y), p.radius + 1.0, Paint()..color = SpriteCastPalette.ink);
      canvas.drawCircle(Offset(p.x, p.y), p.radius, Paint()..color = p.color);
      canvas.drawCircle(Offset(p.x, p.y), p.radius * 0.45, Paint()..color = SpriteCastPalette.endesga32[19]);
    }
  }

  void _paintParticles(Canvas canvas) {
    for (final pt in particles) {
      if (pt.isExpired) continue;
      canvas.drawRect(
        Rect.fromCenter(center: Offset(pt.x, pt.y), width: pt.size, height: pt.size),
        Paint()
          ..color = pt.color.withValues(alpha: pt.alpha)
          ..isAntiAlias = false,
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
      // Subtle atmospheric cavern veil
      canvas.drawRect(
        Rect.fromLTWH(cam.dx, cam.dy, kDungeonRefWidth, kDungeonRefHeight),
        Paint()
          ..color = SpriteCastPalette.ink.withValues(alpha: darkness * 0.55)
          ..isAntiAlias = false,
      );
    }

    // SpriteCast stepped pixel light pools radiating from torches, benches & Umalo!
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
    for (final numItem in combat.floatingNumbers) {
      if (numItem.isExpired) continue;
      final tp = TextPainter(
        text: TextSpan(
          text: numItem.text,
          style: TextStyle(
            color: numItem.color.withValues(alpha: numItem.opacity),
            fontSize: numItem.isCritical ? 8.5 : 7.0,
            fontWeight: FontWeight.w900,
            shadows: const [
              Shadow(color: SpriteCastPalette.ink, offset: Offset(1, 1)),
            ],
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      tp.paint(canvas, Offset(numItem.x - tp.width * 0.5, numItem.y - tp.height * 0.5));
    }
  }

  @override
  bool shouldRepaint(covariant DungeonWorldPainter oldDelegate) => true;
}
