import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../spritecast_engine.dart';
import 'dungeon_enemy_sprites.dart';

class _VfxSheetBurst {
  final String sheetKey;
  final double x;
  final double y;
  final double scale;
  final bool flipX;
  final double rotationRad;
  final Color glowColor;
  final double durationSec;
  final BlendMode blendMode;
  double ageSec = 0.0;

  _VfxSheetBurst({
    required this.sheetKey,
    required this.x,
    required this.y,
    required this.scale,
    required this.flipX,
    required this.rotationRad,
    required this.glowColor,
    required this.durationSec,
    this.blendMode = BlendMode.srcOver,
  });

  bool get isExpired => ageSec >= durationSec;
  double get progress => (ageSec / durationSec).clamp(0.0, 1.0);
}

class _VfxSpark {
  double x;
  double y;
  double vx;
  double vy;
  final double? groundY;
  final Color color;
  final Color coreColor;
  final double lifeSec;
  double ageSec = 0.0;

  _VfxSpark({
    required this.x,
    required this.y,
    required this.vx,
    required this.vy,
    required this.color,
    required this.coreColor,
    required this.lifeSec,
    this.groundY,
  });

  bool get isExpired => ageSec >= lifeSec;
}

class _VfxDebrisBit {
  double x;
  double y;
  double vx;
  double vy;
  final double? groundY;
  final double width;
  final double height;
  final Color color;
  final Color shadeColor;
  final double lifeSec;
  double ageSec = 0.0;

  _VfxDebrisBit({
    required this.x,
    required this.y,
    required this.vx,
    required this.vy,
    required this.width,
    required this.height,
    required this.color,
    required this.shadeColor,
    required this.lifeSec,
    this.groundY,
  });

  bool get isExpired => ageSec >= lifeSec;
}

class _VfxFloorRing {
  final double x;
  final double y;
  final double maxRadiusX;
  final double maxRadiusY;
  final Color color;
  final double durationSec;
  double ageSec = 0.0;

  _VfxFloorRing({
    required this.x,
    required this.y,
    required this.maxRadiusX,
    required this.maxRadiusY,
    required this.color,
    required this.durationSec,
  });

  bool get isExpired => ageSec >= durationSec;

  /// `ease.outQuart`: fast outward punch, smooth linger (`pixelfx` SKILL.md rule).
  double get easedRadiusFactor {
    final u = (ageSec / durationSec).clamp(0.0, 1.0);
    final inv = 1.0 - u;
    return 1.0 - inv * inv * inv * inv;
  }

  double get alpha => (1.0 - (ageSec / durationSec)).clamp(0.0, 1.0);
}

/// Dual-buffer (`paintBack` + `paintFront` + additive glow) pixel-art VFX engine
/// powered by `patch-gg/pixelfx` sprite sheets and simulated particle physics.
///
/// Implements key `pixelfx` craft rules:
/// - **1-frame white hero flash** (`ageSec < 0.045s`) for punchy impact readability
/// - **Fast-in, slow-out** (`outQuart`) perspective floor shockwave rings split into
///   far-plane (`paintBack`, behind characters) and near-plane (`paintFront`, in front)
/// - **Speed-stretched floor-bouncing sparks** & **outlined tumbling debris bits**
/// - **Zero per-frame `Paint()` allocations** via pre-allocated static brushes
class DungeonPixelfxVfxManager {
  final List<_VfxSheetBurst> _bursts = <_VfxSheetBurst>[];
  final List<_VfxSpark> _sparks = <_VfxSpark>[];
  final List<_VfxDebrisBit> _bits = <_VfxDebrisBit>[];
  final List<_VfxFloorRing> _rings = <_VfxFloorRing>[];
  final math.Random _rng = math.Random(1987);

  static final Paint _fill = Paint()
    ..style = PaintingStyle.fill
    ..isAntiAlias = false;
  static final Paint _stroke = Paint()
    ..style = PaintingStyle.stroke
    ..strokeCap = StrokeCap.square
    ..isAntiAlias = false;
  static final Paint _glow = Paint()
    ..style = PaintingStyle.fill
    ..blendMode = BlendMode.plus;
  static final Paint _imgPaint = Paint()..filterQuality = FilterQuality.none;

  int get activeCount =>
      _bursts.length + _sparks.length + _bits.length + _rings.length;

  int get activeRingCount => _rings.length;
  int get activeBurstCount => _bursts.length;
  int get activeSparkCount => _sparks.length;

  void clear() {
    _bursts.clear();
    _sparks.clear();
    _bits.clear();
    _rings.clear();
  }

  void step(double dt) {
    final safeDt = dt.clamp(0.0, 0.05);
    if (safeDt <= 0.0) return;

    for (var i = _bursts.length - 1; i >= 0; i--) {
      _bursts[i].ageSec += safeDt;
      if (_bursts[i].isExpired) _bursts.removeAt(i);
    }

    for (var i = _rings.length - 1; i >= 0; i--) {
      _rings[i].ageSec += safeDt;
      if (_rings[i].isExpired) _rings.removeAt(i);
    }

    for (var i = _sparks.length - 1; i >= 0; i--) {
      final s = _sparks[i];
      s.ageSec += safeDt;
      if (s.isExpired) {
        _sparks.removeAt(i);
        continue;
      }
      s.vy += 380.0 * safeDt;
      s.x += s.vx * safeDt;
      s.y += s.vy * safeDt;
      // Floor bounce (`pixelfx` `src/core/sim.js` spark bounce!)
      if (s.groundY != null && s.y >= s.groundY! && s.vy > 0.0) {
        s.y = s.groundY!;
        s.vy = -s.vy * 0.46;
        s.vx *= 0.72;
      }
    }

    for (var i = _bits.length - 1; i >= 0; i--) {
      final b = _bits[i];
      b.ageSec += safeDt;
      if (b.isExpired) {
        _bits.removeAt(i);
        continue;
      }
      b.vy += 440.0 * safeDt;
      b.x += b.vx * safeDt;
      b.y += b.vy * safeDt;
      if (b.groundY != null && b.y >= b.groundY! && b.vy > 0.0) {
        b.y = b.groundY!;
        b.vy = -b.vy * 0.32;
        b.vx *= 0.58;
      }
    }
  }

  // ═══════════════════════════════════════════════════════════════════════════
  //  SPAWNERS FOR MELEE, PARRY, CRIT, SHOCKWAVES, SHATTERS & PICKUPS
  // ═══════════════════════════════════════════════════════════════════════════

  void spawnSlashArc({
    required double x,
    required double y,
    required int facing,
    double rotationRad = 0.0,
    bool isFinisher = false,
    Color? glowColor,
  }) {
    _trimPool(_bursts, 20);
    _bursts.add(
      _VfxSheetBurst(
        sheetKey: 'sword_slash',
        x: x,
        y: y,
        scale: isFinisher ? 0.34 : 0.26,
        flipX: facing < 0,
        rotationRad: rotationRad,
        glowColor: glowColor ?? SpriteCastPalette.endesga32[18],
        durationSec: isFinisher ? 0.30 : 0.22,
      ),
    );
    if (isFinisher) {
      _spawnSparkFan(
        x: x + facing * 10.0,
        y: y,
        count: 6,
        color: glowColor ?? SpriteCastPalette.endesga32[11],
        minSpeed: 45.0,
        maxSpeed: 115.0,
      );
    }
  }

  void spawnHitImpact({
    required double x,
    required double y,
    required Color color,
    bool isCritOrKill = false,
    double? groundY,
  }) {
    if (isCritOrKill) {
      _trimPool(_bursts, 20);
      _bursts.add(
        _VfxSheetBurst(
          sheetKey: 'crit_hit',
          x: x,
          y: y,
          scale: 0.28,
          flipX: _rng.nextBool(),
          rotationRad: 0.0,
          glowColor: color,
          durationSec: 0.42,
        ),
      );
    }
    _spawnSparkFan(
      x: x,
      y: y,
      count: isCritOrKill ? 12 : 7,
      color: color,
      minSpeed: 55.0,
      maxSpeed: isCritOrKill ? 155.0 : 110.0,
      groundY: groundY,
    );
  }

  void spawnGoldenParry({
    required double x,
    required double y,
    double? groundY,
  }) {
    _trimPool(_bursts, 20);
    _bursts.add(
      _VfxSheetBurst(
        sheetKey: 'parry',
        x: x,
        y: y,
        scale: 0.32,
        flipX: false,
        rotationRad: 0.0,
        glowColor: SpriteCastPalette.endesga32[11],
        durationSec: 0.46,
      ),
    );
    spawnFloorShockwave(
      x: x,
      groundY: groundY ?? (y + 8.0),
      color: SpriteCastPalette.endesga32[11],
      maxRadiusX: 30.0,
    );
    _spawnSparkFan(
      x: x,
      y: y,
      count: 14,
      color: SpriteCastPalette.endesga32[11],
      minSpeed: 70.0,
      maxSpeed: 165.0,
      groundY: groundY,
    );
  }

  void spawnFloorShockwave({
    required double x,
    required double groundY,
    required Color color,
    double maxRadiusX = 36.0,
  }) {
    _trimPool(_rings, 10);
    _rings.add(
      _VfxFloorRing(
        x: x,
        y: groundY,
        maxRadiusX: maxRadiusX,
        maxRadiusY: math.max(3.5, maxRadiusX * 0.22),
        color: color,
        durationSec: 0.42,
      ),
    );
  }

  void spawnDebrisShatter({
    required double x,
    required double y,
    required Color color,
    Color? shadeColor,
    int count = 8,
    double? groundY,
  }) {
    _trimPool(_bits, 56);
    final shade = shadeColor ?? SpriteCastPalette.woodDark;
    for (var i = 0; i < count; i++) {
      final angle = -math.pi * 0.15 - _rng.nextDouble() * math.pi * 0.70;
      final spd = 45.0 + _rng.nextDouble() * 95.0;
      _bits.add(
        _VfxDebrisBit(
          x: x + (_rng.nextDouble() - 0.5) * 8.0,
          y: y + (_rng.nextDouble() - 0.5) * 8.0,
          vx: math.cos(angle) * spd * (_rng.nextBool() ? 1.0 : -1.0),
          vy: math.sin(angle) * spd - 35.0,
          width: 2.2 + _rng.nextDouble() * 1.8,
          height: 2.0 + _rng.nextDouble() * 1.6,
          color: color,
          shadeColor: shade,
          lifeSec: 0.36 + _rng.nextDouble() * 0.26,
          groundY: groundY,
        ),
      );
    }
  }

  void spawnPickupSparkle({
    required double x,
    required double y,
    required Color color,
  }) {
    _spawnSparkFan(
      x: x,
      y: y,
      count: 6,
      color: color,
      minSpeed: 28.0,
      maxSpeed: 68.0,
    );
  }

  void _spawnSparkFan({
    required double x,
    required double y,
    required int count,
    required Color color,
    required double minSpeed,
    required double maxSpeed,
    double? groundY,
  }) {
    _trimPool(_sparks, 84);
    for (var i = 0; i < count; i++) {
      final angle = _rng.nextDouble() * math.pi * 2.0;
      final spd = minSpeed + _rng.nextDouble() * (maxSpeed - minSpeed);
      _sparks.add(
        _VfxSpark(
          x: x,
          y: y,
          vx: math.cos(angle) * spd,
          vy: math.sin(angle) * spd - 32.0,
          color: color,
          coreColor: SpriteCastPalette.endesga32[19],
          lifeSec: 0.22 + _rng.nextDouble() * 0.24,
          groundY: groundY,
        ),
      );
    }
  }

  void _trimPool<T>(List<T> list, int cap) {
    if (list.length > cap) {
      list.removeRange(0, list.length - cap);
    }
  }

  // ═══════════════════════════════════════════════════════════════════════════
  //  DUAL-PLANE RENDERING (`paintBack` BEHIND ENTITIES, `paintFront` IN FRONT)
  // ═══════════════════════════════════════════════════════════════════════════

  /// Draws the far/back arc of tilted-plane floor shockwave rings & ground light pools
  /// *behind* enemies, bosses, and Alon (`pixelfx` `draw(frame, "back")` layer).
  void paintBack(Canvas canvas, {DungeonPixelfxSheetCache? sheetCache}) {
    for (final ring in _rings) {
      if (ring.isExpired) continue;
      final k = ring.easedRadiusFactor;
      final rx = ring.maxRadiusX * k;
      final ry = ring.maxRadiusY * k;
      final rect = Rect.fromCenter(center: Offset(ring.x, ring.y), width: rx * 2, height: ry * 2);

      // Soft additive ground glow pool
      _glow.color = ring.color.withValues(alpha: 0.16 * ring.alpha);
      canvas.drawOval(rect.inflate(2.0), _glow);

      // Far half-ellipse (`pi` -> `2*pi`) behind characters' feet
      _stroke
        ..color = ring.color.withValues(alpha: 0.72 * ring.alpha)
        ..strokeWidth = 1.6;
      canvas.drawArc(rect, math.pi, math.pi, false, _stroke);
    }
  }

  /// Draws the near/front arc of floor shockwave rings, 1-frame white hero flashes,
  /// exported `pixelfx` sprite-sheet bursts, speed-stretched sparks, and debris bits.
  void paintFront(Canvas canvas, {DungeonPixelfxSheetCache? sheetCache}) {
    final cache = sheetCache ?? DungeonPixelfxSheetCache.instance;

    // 1. Near half-ellipse (`0` -> `pi`) of floor shockwaves in front of characters' feet!
    for (final ring in _rings) {
      if (ring.isExpired) continue;
      final k = ring.easedRadiusFactor;
      final rx = ring.maxRadiusX * k;
      final ry = ring.maxRadiusY * k;
      final rect = Rect.fromCenter(center: Offset(ring.x, ring.y), width: rx * 2, height: ry * 2);

      _stroke
        ..color = SpriteCastPalette.ink.withValues(alpha: 0.65 * ring.alpha)
        ..strokeWidth = 3.2;
      canvas.drawArc(rect, 0.0, math.pi, false, _stroke);
      _stroke
        ..color = ring.color.withValues(alpha: 0.92 * ring.alpha)
        ..strokeWidth = 1.8;
      canvas.drawArc(rect, 0.0, math.pi, false, _stroke);
      _stroke
        ..color = SpriteCastPalette.endesga32[19].withValues(alpha: 0.75 * ring.alpha)
        ..strokeWidth = 0.9;
      canvas.drawArc(rect, 0.12, math.pi - 0.24, false, _stroke);
    }

    // 2. Exported `pixelfx` one-shot sprite-sheet bursts + 1-frame white hero punch!
    for (final b in _bursts) {
      if (b.isExpired) continue;
      final spec = cache.specFor(b.sheetKey);
      final frameIdx = spec != null
          ? (b.progress * spec.frames).floor().clamp(0, spec.frames - 1)
          : 0;

      // 1-frame white-hot hero flash (`pixelfx` rule: punchy contact frame!)
      if (b.ageSec < 0.045) {
        _glow.color = SpriteCastPalette.endesga32[19].withValues(alpha: 0.65);
        canvas.drawCircle(Offset(b.x, b.y), 9.0, _glow);
      }

      // Soft additive color flare behind sheet
      final fade = (1.0 - b.progress).clamp(0.0, 1.0);
      _glow.color = b.glowColor.withValues(alpha: 0.24 * fade);
      canvas.drawCircle(Offset(b.x, b.y), 14.0 * (0.7 + 0.3 * b.progress), _glow);

      final drew = cache.drawSheetFrame(
        canvas: canvas,
        reusablePaint: _imgPaint,
        key: b.sheetKey,
        worldX: b.x,
        worldY: b.y,
        frameIndex: frameIdx,
        scale: b.scale,
        flipX: b.flipX,
        rotationRad: b.rotationRad,
        opacity: (1.15 - b.progress * 0.65).clamp(0.0, 1.0),
        blendMode: b.blendMode,
      );

      if (!drew) {
        // Crisp procedural starburst fallback when running headless tests without decoded PNGs
        final r = (b.sheetKey == 'parry' ? 14.0 : 11.0) * (0.4 + 0.6 * b.progress);
        _stroke
          ..color = b.glowColor.withValues(alpha: fade)
          ..strokeWidth = 2.0;
        canvas.drawCircle(Offset(b.x, b.y), r, _stroke);
        _stroke
          ..color = SpriteCastPalette.endesga32[19].withValues(alpha: fade)
          ..strokeWidth = 1.2;
        canvas.drawLine(Offset(b.x - r, b.y), Offset(b.x + r, b.y), _stroke);
        canvas.drawLine(Offset(b.x, b.y - r), Offset(b.x, b.y + r), _stroke);
      }
    }

    // 3. Tumbling 1px-outlined debris bits (stone chips, crate splinters, charter shards)
    for (final bit in _bits) {
      if (bit.isExpired) continue;
      final a = (1.0 - bit.ageSec / bit.lifeSec).clamp(0.0, 1.0);
      final r = Rect.fromCenter(center: Offset(bit.x, bit.y), width: bit.width, height: bit.height);
      _fill.color = SpriteCastPalette.ink.withValues(alpha: a);
      canvas.drawRect(r.inflate(0.8), _fill);
      _fill.color = (bit.ageSec * 18.0).floor().isEven
          ? bit.color.withValues(alpha: a)
          : bit.shadeColor.withValues(alpha: a);
      canvas.drawRect(r, _fill);
    }

    // 4. Speed-stretched floor-bouncing sparks (`pixelfx` `Particles` craft!)
    for (final s in _sparks) {
      if (s.isExpired) continue;
      final u = (s.ageSec / s.lifeSec).clamp(0.0, 1.0);
      final a = (1.0 - u).clamp(0.0, 1.0);
      final speed = math.sqrt(s.vx * s.vx + s.vy * s.vy);
      if (speed > 12.0) {
        final stretch = (speed * 0.032).clamp(1.6, 6.2);
        final dx = (s.vx / speed) * stretch;
        final dy = (s.vy / speed) * stretch;
        _stroke
          ..color = s.color.withValues(alpha: a)
          ..strokeWidth = 1.6;
        canvas.drawLine(Offset(s.x - dx, s.y - dy), Offset(s.x, s.y), _stroke);
      }
      _fill.color = (u < 0.35 ? s.coreColor : s.color).withValues(alpha: a);
      canvas.drawRect(Rect.fromCenter(center: Offset(s.x, s.y), width: 1.8, height: 1.8), _fill);
    }
  }
}
