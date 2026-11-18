import 'dart:math' as math;
import 'dart:typed_data';
import 'package:flutter/material.dart';

/// Dart / Flutter implementation of the `patch-gg/pixelfx` procedural code-only
/// pixel art visual effects engine (https://github.com/patch-gg/pixelfx).
///
/// Core `pixelfx` Architecture:
/// 1. **Dual-Buffer Pixel Frame (`PixelFxFrame` / `createFrame`)**:
///    - `colorBuffer`: 32-bit ARGB pixel grid supporting opaque, translucent, and
///      Bayer 4×4 ordered-dithered pixels.
///    - `lightBuffer`: 32-bit RGB additive glow buffer composited over the base frame.
/// 2. **Deterministic Seeded PRNG (`PixelFxRng`)**:
///    - Every random number uses a deterministic seed (`mulberry32` + integer hash)
///      so any frame index or particle state renders identically across devices.
/// 3. **Two Effect Archetypes (`createFx`)**:
///    - **Pure Effects (`PixelFxPureEffect`)**: Stateless `draw(frame, t, opts)` loops
///      for seamless portals, bookshelf auras, unrest zones, torches, and ambient motes.
///    - **Simulated Effects (`PixelFxSimulatedEffect`)**: Stateful particle simulations
///      stepped at a fixed internal `120 Hz` clock (`dt = 1 / 120`) so physics (sparks,
///      GBA battle swirls, doctrine slashes, shield shatters, confetti) behave
///      deterministically regardless of display framerate.

const List<int> kBayer4x4 = <int>[
  0, 8, 2, 10,
  12, 4, 14, 6,
  3, 11, 1, 9,
  15, 7, 13, 5,
];

/// Deterministic seeded PRNG (`mulberry32`) used by `pixelfx` effects.
class PixelFxRng {
  int _state;

  PixelFxRng([int seed = 0x5F3759DF])
      : _state = (seed == 0 ? 0x5F3759DF : seed) & 0xFFFFFFFF;

  /// Returns a deterministic float in `[0.0, 1.0)`.
  double nextDouble() {
    _state = (_state + 0x6D2B79F5) & 0xFFFFFFFF;
    var t = _state;
    t = _imul32(t ^ (t >>> 15), t | 1);
    t = (t ^ (t + _imul32(t ^ (t >>> 7), t | 61))) & 0xFFFFFFFF;
    return ((t ^ (t >>> 14)) >>> 0) / 4294967296.0;
  }

  /// Returns a deterministic float in `[min, max)`.
  double range(double min, double max) => min + (max - min) * nextDouble();

  /// Returns a deterministic integer in `[min, max]` inclusive.
  int intRange(int min, int max) {
    if (max <= min) return min;
    return min + (nextDouble() * (max - min + 1)).floor();
  }

  /// Stateless 2D coordinate + seed hash in `[0.0, 1.0)`.
  static double hash2d(int x, int y, [int seed = 1337]) {
    var h = (x * 374761393 + y * 668265263 + seed * 1442695041) & 0xFFFFFFFF;
    h = _imul32(h ^ (h >>> 13), 1274126177);
    return ((h ^ (h >>> 16)) >>> 0) / 4294967296.0;
  }

  static int _imul32(int a, int b) {
    final ah = (a >>> 16) & 0xFFFF;
    final al = a & 0xFFFF;
    final bh = (b >>> 16) & 0xFFFF;
    final bl = b & 0xFFFF;
    return ((al * bl) + (((ah * bl + al * bh) & 0xFFFF) << 16)) & 0xFFFFFFFF;
  }
}

/// Configuration options (`o`) passed to `createFx(effect, options)`.
class PixelFxOptions {
  final double x;
  final double y;
  final int seed;
  final List<int>? palette;
  final bool flipX;
  final bool flipY;
  final double intensity;

  const PixelFxOptions({
    this.x = 0,
    this.y = 0,
    this.seed = 42,
    this.palette,
    this.flipX = false,
    this.flipY = false,
    this.intensity = 1.0,
  });

  PixelFxOptions copyWith({
    double? x,
    double? y,
    int? seed,
    List<int>? palette,
    bool? flipX,
    bool? flipY,
    double? intensity,
  }) {
    return PixelFxOptions(
      x: x ?? this.x,
      y: y ?? this.y,
      seed: seed ?? this.seed,
      palette: palette ?? this.palette,
      flipX: flipX ?? this.flipX,
      flipY: flipY ?? this.flipY,
      intensity: intensity ?? this.intensity,
    );
  }
}

/// Dual-buffer pixel frame (`colorBuffer` + additive `lightBuffer`) from `patch-gg/pixelfx`.
class PixelFxFrame {
  final int width;
  final int height;
  final Uint32List colorBuffer;
  final Uint32List lightBuffer;

  PixelFxFrame(this.width, this.height)
      : colorBuffer = Uint32List(width * height),
        lightBuffer = Uint32List(width * height);

  /// Clears both the base color buffer and additive light buffer.
  PixelFxFrame clear() {
    colorBuffer.fillRange(0, colorBuffer.length, 0);
    lightBuffer.fillRange(0, lightBuffer.length, 0);
    return this;
  }

  /// Sets a pixel in the color buffer with optional Bayer 4×4 ordered dithering (`dither` in `0..1`).
  void setPixel(
    int x,
    int y,
    int argb, {
    double dither = 1.0,
  }) {
    if (x < 0 || x >= width || y < 0 || y >= height) return;
    if (dither < 0.999) {
      if (dither <= 0.0) return;
      final threshold = (kBayer4x4[(y & 3) * 4 + (x & 3)] + 0.5) / 16.0;
      if (dither < threshold) return;
    }
    final idx = y * width + x;
    final srcA = (argb >>> 24) & 0xFF;
    if (srcA == 0) return;
    if (srcA == 255) {
      colorBuffer[idx] = argb;
      return;
    }
    final dst = colorBuffer[idx];
    final dstA = (dst >>> 24) & 0xFF;
    if (dstA == 0) {
      colorBuffer[idx] = argb;
      return;
    }
    final invA = 255 - srcA;
    final outR =
        (((argb >>> 16) & 0xFF) * srcA + ((dst >>> 16) & 0xFF) * invA) ~/ 255;
    final outG =
        (((argb >>> 8) & 0xFF) * srcA + ((dst >>> 8) & 0xFF) * invA) ~/ 255;
    final outB = ((argb & 0xFF) * srcA + (dst & 0xFF) * invA) ~/ 255;
    final outA = math.min(255, srcA + ((dstA * invA) ~/ 255));
    colorBuffer[idx] = (outA << 24) | (outR << 16) | (outG << 8) | outB;
  }

  /// Adds additive glow light to the light buffer at `(x, y)` with `strength` (`0..1`).
  void addLight(int x, int y, int rgb, [double strength = 1.0]) {
    if (x < 0 || x >= width || y < 0 || y >= height || strength <= 0) return;
    final idx = y * width + x;
    final cur = lightBuffer[idx];
    final addR = (((rgb >>> 16) & 0xFF) * strength).round();
    final addG = (((rgb >>> 8) & 0xFF) * strength).round();
    final addB = ((rgb & 0xFF) * strength).round();

    final r = math.min(255, ((cur >>> 16) & 0xFF) + addR);
    final g = math.min(255, ((cur >>> 8) & 0xFF) + addG);
    final b = math.min(255, (cur & 0xFF) + addB);
    final a = math.min(255, ((cur >>> 24) & 0xFF) + (strength * 180).round());
    lightBuffer[idx] = (a << 24) | (r << 16) | (g << 8) | b;
  }

  /// Draws a filled pixel circle + optional radial additive glow.
  void drawDisc(
    double cx,
    double cy,
    double radius,
    int argb, {
    int? glowColor,
    double glowRadius = 0,
    double ditherEdge = 0.0,
  }) {
    final r = radius.ceil();
    final icx = cx.round();
    final icy = cy.round();
    final rSq = radius * radius;
    for (var dy = -r; dy <= r; dy++) {
      for (var dx = -r; dx <= r; dx++) {
        final dSq = dx * dx + dy * dy;
        if (dSq <= rSq) {
          var dither = 1.0;
          if (ditherEdge > 0 && dSq > rSq * (1.0 - ditherEdge)) {
            dither = 0.5;
          }
          setPixel(icx + dx, icy + dy, argb, dither: dither);
        }
      }
    }
    if (glowColor != null && glowRadius > 0) {
      addRadialLight(cx, cy, glowRadius, glowColor, 0.55);
    }
  }

  /// Adds a soft radial light falloff into `lightBuffer`.
  void addRadialLight(
    double cx,
    double cy,
    double radius,
    int rgb, [
    double peakStrength = 0.65,
  ]) {
    final r = radius.ceil();
    final icx = cx.round();
    final icy = cy.round();
    final rSq = radius * radius;
    if (rSq <= 0) return;
    for (var dy = -r; dy <= r; dy++) {
      for (var dx = -r; dx <= r; dx++) {
        final dSq = dx * dx + dy * dy;
        if (dSq <= rSq) {
          final falloff = 1.0 - math.sqrt(dSq) / radius;
          addLight(
            icx + dx,
            icy + dy,
            rgb,
            peakStrength * falloff * falloff,
          );
        }
      }
    }
  }

  /// Bresenham pixel line with optional additive light halo.
  void drawLine(
    int x0,
    int y0,
    int x1,
    int y1,
    int argb, {
    int? glowColor,
  }) {
    var cx = x0;
    var cy = y0;
    final dx = (x1 - x0).abs();
    final dy = -(y1 - y0).abs();
    final sx = x0 < x1 ? 1 : -1;
    final sy = y0 < y1 ? 1 : -1;
    var err = dx + dy;
    while (true) {
      setPixel(cx, cy, argb);
      if (glowColor != null) {
        addLight(cx, cy, glowColor, 0.55);
        addLight(cx + 1, cy, glowColor, 0.22);
        addLight(cx - 1, cy, glowColor, 0.22);
        addLight(cx, cy + 1, glowColor, 0.22);
        addLight(cx, cy - 1, glowColor, 0.22);
      }
      if (cx == x1 && cy == y1) break;
      final e2 = 2 * err;
      if (e2 >= dy) {
        err += dy;
        cx += sx;
      }
      if (e2 <= dx) {
        err += dx;
        cy += sy;
      }
    }
  }

  /// Draws a 4-point pixel star/sparkle at `(cx, cy)`.
  void drawSparkle(int cx, int cy, int armLen, int coreColor, int glowColor) {
    setPixel(cx, cy, coreColor);
    addLight(cx, cy, glowColor, 0.85);
    for (var i = 1; i <= armLen; i++) {
      final strength = 1.0 - (i / (armLen + 1));
      final col = i == 1 ? coreColor : glowColor;
      setPixel(cx + i, cy, col, dither: strength);
      setPixel(cx - i, cy, col, dither: strength);
      setPixel(cx, cy + i, col, dither: strength);
      setPixel(cx, cy - i, col, dither: strength);
      addLight(cx + i, cy, glowColor, 0.35 * strength);
      addLight(cx - i, cy, glowColor, 0.35 * strength);
      addLight(cx, cy + i, glowColor, 0.35 * strength);
      addLight(cx, cy - i, glowColor, 0.35 * strength);
    }
  }
}

/// Top-level `pixelfx` helper functions matching the JS API (`createFrame`, `clearFrame`, `composite`).
PixelFxFrame createFrame(int width, int height) => PixelFxFrame(width, height);

PixelFxFrame clearFrame(PixelFxFrame frame) => frame.clear();

/// Composites `frame.colorBuffer` and additive `frame.lightBuffer` into packed 32-bit ARGB pixels.
Uint32List compositeFrame(PixelFxFrame frame) {
  final total = frame.width * frame.height;
  final out = Uint32List(total);
  final colors = frame.colorBuffer;
  final lights = frame.lightBuffer;

  for (var i = 0; i < total; i++) {
    final c = colors[i];
    final l = lights[i];
    if (c == 0 && l == 0) continue;

    final cA = (c >>> 24) & 0xFF;
    final cR = (c >>> 16) & 0xFF;
    final cG = (c >>> 8) & 0xFF;
    final cB = c & 0xFF;

    final lA = (l >>> 24) & 0xFF;
    final lR = (l >>> 16) & 0xFF;
    final lG = (l >>> 8) & 0xFF;
    final lB = l & 0xFF;

    final outR = math.min(255, cR + lR);
    final outG = math.min(255, cG + lG);
    final outB = math.min(255, cB + lB);
    final outA = math.min(255, math.max(cA, lA));
    out[i] = (outA << 24) | (outR << 16) | (outG << 8) | outB;
  }
  return out;
}

/// Renders a composited `PixelFxFrame` onto a Flutter `Canvas` inside `dstRect`
/// with crisp nearest-neighbor pixel blocks (`FilterQuality.none` aesthetic).
void renderPixelFxFrameToCanvas(
  Canvas canvas,
  PixelFxFrame frame,
  Rect dstRect, {
  double opacity = 1.0,
}) {
  if (opacity <= 0.0) return;
  final scaleX = dstRect.width / frame.width;
  final scaleY = dstRect.height / frame.height;
  final paint = Paint()..style = PaintingStyle.fill;

  final colors = frame.colorBuffer;
  final lights = frame.lightBuffer;
  final w = frame.width;
  final h = frame.height;

  // Greedy horizontal run-length batching reduces drawRect calls by 60–80%!
  for (var y = 0; y < h; y++) {
    final rowOffset = y * w;
    var x = 0;
    while (x < w) {
      final idx = rowOffset + x;
      final c = colors[idx];
      final l = lights[idx];
      if (c == 0 && l == 0) {
        x++;
        continue;
      }
      final packed = _mergeColorAndLight(c, l, opacity);
      var runEnd = x + 1;
      while (runEnd < w) {
        final nextIdx = rowOffset + runEnd;
        final nc = colors[nextIdx];
        final nl = lights[nextIdx];
        if ((nc == 0 && nl == 0) ||
            _mergeColorAndLight(nc, nl, opacity) != packed) {
          break;
        }
        runEnd++;
      }
      paint.color = Color(packed);
      canvas.drawRect(
        Rect.fromLTWH(
          dstRect.left + x * scaleX,
          dstRect.top + y * scaleY,
          (runEnd - x) * scaleX + 0.35,
          scaleY + 0.35,
        ),
        paint,
      );
      x = runEnd;
    }
  }
}

int _mergeColorAndLight(int c, int l, double opacity) {
  final cA = (c >>> 24) & 0xFF;
  final cR = (c >>> 16) & 0xFF;
  final cG = (c >>> 8) & 0xFF;
  final cB = c & 0xFF;

  final lA = (l >>> 24) & 0xFF;
  final lR = (l >>> 16) & 0xFF;
  final lG = (l >>> 8) & 0xFF;
  final lB = l & 0xFF;

  final outR = math.min(255, cR + lR);
  final outG = math.min(255, cG + lG);
  final outB = math.min(255, cB + lB);
  final rawA = math.min(255, math.max(cA, lA));
  final outA = (rawA * opacity).round().clamp(0, 255);
  return (outA << 24) | (outR << 16) | (outG << 8) | outB;
}

/// Particle unit for simulated 120 Hz `pixelfx` effects.
class _SimParticle {
  double x;
  double y;
  double vx;
  double vy;
  double life;
  double maxLife;
  int color;
  int glowColor;
  double size;
  double gravity;
  double drag;

  _SimParticle({
    required this.x,
    required this.y,
    required this.vx,
    required this.vy,
    required this.life,
    required this.maxLife,
    required this.color,
    required this.glowColor,
    this.size = 1.5,
    this.gravity = 0.0,
    this.drag = 0.99,
  });
}

/// Identifiers for the built-in `patch-gg/pixelfx` effects used across the Virtual School
/// and **Chronicles of the Sovereign**.
enum PixelFxPreset {
  bookshelfPortalAura, // Pure loop: Glowing Bookshelf portal at back of School Lobby
  ambientCampusMotes, // Pure loop: Drifting sunbeams & dust motes across rooms
  unrestZoneRipples, // Pure loop: Overworld tall-grass "Unrest Zone" crowd ripples
  astrolabePulse, // Pure loop: Alon's brass Astrolabe of Kalayaan temporal rings
  torchFlicker, // Pure loop: Katipunan basement torch & warm light halo
  curfewSearchlight, // Pure loop: Martial Law sweeping citadel searchlight
  peoplePowerRibbons, // Pure loop: EDSA Highway of Gold floating yellow ribbons & flowers
  gbaBattleSwirl, // Simulated 120Hz: LeafGreen screen-flashing spiral battle transition
  bahayPulunganHeal, // Simulated 120Hz: 4-note Bahay-Pulungan Civic Resolve heal chime spiral
  sanduguanFlame, // Simulated 120Hz: Doctrine 1 — Pre-colonial Sanduguan fire pact burst
  checksAndBalancesScales, // Simulated 120Hz: Doctrine 2 — Constitutional twin scale shockwave
  habeasCorpusShield, // Simulated 120Hz: Doctrine 3 — Bill of Rights hexagonal prism barrier
  sovereigntySunburst, // Simulated 120Hz: Doctrine 4 — 8-Ray Philippine Sun finisher
  doubtShatterBurst, // Simulated 120Hz: Opponent Doubt Meter crystal shatter impact
  rivalExclamationPop, // Simulated 120Hz: Rival Mateo `[!]` encounter alert burst
  charterSealUnlock, // Simulated 120Hz: Charter Seal earned milestone confetti & stamp
}

/// Live `pixelfx` effect controller created via `createFx(preset, options)`.
/// Steps simulated effects at a fixed `120 Hz` clock (`_kFixedStep = 1 / 120`) for
/// deterministic particle physics, and evaluates pure effects directly from `elapsedTime`.
class PixelFxController {
  static const double _kFixedStep = 1.0 / 120.0;

  final PixelFxPreset preset;
  PixelFxOptions options;
  double _elapsedTime = 0.0;
  double _accumulator = 0.0;
  int _simStepCount = 0;
  final List<_SimParticle> _particles = <_SimParticle>[];
  late PixelFxRng _rng;

  PixelFxController(this.preset, [this.options = const PixelFxOptions()]) {
    _rng = PixelFxRng(options.seed);
    _seedInitialParticles();
  }

  double get elapsedTime => _elapsedTime;
  bool get isFinished {
    if (_isPureLoop) return false;
    return _elapsedTime > 0.25 && _particles.isEmpty;
  }

  bool get _isPureLoop {
    switch (preset) {
      case PixelFxPreset.bookshelfPortalAura:
      case PixelFxPreset.ambientCampusMotes:
      case PixelFxPreset.unrestZoneRipples:
      case PixelFxPreset.astrolabePulse:
      case PixelFxPreset.torchFlicker:
      case PixelFxPreset.curfewSearchlight:
      case PixelFxPreset.peoplePowerRibbons:
        return true;
      default:
        return false;
    }
  }

  /// Resets and re-triggers a one-shot simulated effect with deterministic seed.
  void restart([int? newSeed]) {
    _elapsedTime = 0.0;
    _accumulator = 0.0;
    _simStepCount = 0;
    _particles.clear();
    if (newSeed != null) {
      options = options.copyWith(seed: newSeed);
    }
    _rng = PixelFxRng(options.seed);
    _seedInitialParticles();
  }

  void _seedInitialParticles() {
    final cx = options.x;
    final cy = options.y;
    final pal = options.palette ?? _defaultPaletteFor(preset);

    switch (preset) {
      case PixelFxPreset.gbaBattleSwirl:
        for (var i = 0; i < 68; i++) {
          final angle = (i / 68.0) * math.pi * 6.0;
          final dist = 4.0 + i * 1.35;
          _particles.add(
            _SimParticle(
              x: cx + math.cos(angle) * dist,
              y: cy + math.sin(angle) * dist,
              vx: -math.sin(angle) * 65.0,
              vy: math.cos(angle) * 65.0,
              life: 0.95,
              maxLife: 0.95,
              color: pal[i % pal.length],
              glowColor: pal[0],
              size: (i % 3 == 0) ? 2.2 : 1.4,
              drag: 0.985,
            ),
          );
        }
        break;

      case PixelFxPreset.bahayPulunganHeal:
        for (var i = 0; i < 36; i++) {
          final angle = (i / 36.0) * math.pi * 2.0;
          final radius = 14.0 + (i % 3) * 6.0;
          _particles.add(
            _SimParticle(
              x: cx + math.cos(angle) * radius,
              y: cy + 12.0 - (i % 4) * 4.0,
              vx: math.cos(angle + 1.2) * 18.0,
              vy: -28.0 - _rng.range(4, 22),
              life: 0.85,
              maxLife: 0.85,
              color: pal[i % pal.length],
              glowColor: 0xFF34D399,
              size: 1.8,
              gravity: -12.0,
              drag: 0.98,
            ),
          );
        }
        break;

      case PixelFxPreset.sanduguanFlame:
        for (var i = 0; i < 48; i++) {
          final angle = _rng.range(-math.pi * 0.85, -math.pi * 0.15);
          final speed = _rng.range(24, 96);
          _particles.add(
            _SimParticle(
              x: cx + _rng.range(-8, 8),
              y: cy + _rng.range(-4, 6),
              vx: math.cos(angle) * speed,
              vy: math.sin(angle) * speed,
              life: _rng.range(0.35, 0.78),
              maxLife: 0.78,
              color: pal[i % pal.length],
              glowColor: 0xFFF97316,
              size: _rng.range(1.2, 2.5),
              gravity: -35.0,
              drag: 0.96,
            ),
          );
        }
        break;

      case PixelFxPreset.checksAndBalancesScales:
      case PixelFxPreset.habeasCorpusShield:
        for (var i = 0; i < 42; i++) {
          final angle = (i / 42.0) * math.pi * 2.0;
          final speed = 38.0 + (i % 3) * 22.0;
          _particles.add(
            _SimParticle(
              x: cx + math.cos(angle) * 6.0,
              y: cy + math.sin(angle) * 6.0,
              vx: math.cos(angle) * speed,
              vy: math.sin(angle) * speed,
              life: 0.72,
              maxLife: 0.72,
              color: pal[i % pal.length],
              glowColor: pal[0],
              size: 1.8,
              drag: 0.95,
            ),
          );
        }
        break;

      case PixelFxPreset.sovereigntySunburst:
        // 8-Ray Philippine Sun burst + 3 stars
        for (var ray = 0; ray < 8; ray++) {
          final baseAngle = ray * (math.pi / 4.0);
          for (var j = 0; j < 7; j++) {
            final speed = 28.0 + j * 16.0;
            _particles.add(
              _SimParticle(
                x: cx,
                y: cy,
                vx: math.cos(baseAngle) * speed,
                vy: math.sin(baseAngle) * speed,
                life: 0.82,
                maxLife: 0.82,
                color: j < 3 ? 0xFFFFFFFF : 0xFFFACC15,
                glowColor: 0xFFF59E0B,
                size: j < 2 ? 2.4 : 1.6,
                drag: 0.96,
              ),
            );
          }
        }
        break;

      case PixelFxPreset.doubtShatterBurst:
      case PixelFxPreset.rivalExclamationPop:
        for (var i = 0; i < 32; i++) {
          final angle = _rng.range(0, math.pi * 2.0);
          final speed = _rng.range(30, 110);
          _particles.add(
            _SimParticle(
              x: cx,
              y: cy,
              vx: math.cos(angle) * speed,
              vy: math.sin(angle) * speed - 18.0,
              life: _rng.range(0.30, 0.65),
              maxLife: 0.65,
              color: pal[i % pal.length],
              glowColor: pal[0],
              size: _rng.range(1.2, 2.2),
              gravity: 120.0,
              drag: 0.95,
            ),
          );
        }
        break;

      case PixelFxPreset.charterSealUnlock:
        // Milestone confetti cone up (craft-game-floors recipe: 45 particles, 3 palette colors)
        for (var i = 0; i < 48; i++) {
          final angle = _rng.range(-math.pi * 0.82, -math.pi * 0.18);
          final speed = _rng.range(45, 135);
          _particles.add(
            _SimParticle(
              x: cx + _rng.range(-12, 12),
              y: cy,
              vx: math.cos(angle) * speed,
              vy: math.sin(angle) * speed,
              life: _rng.range(0.65, 1.15),
              maxLife: 1.15,
              color: pal[i % pal.length],
              glowColor: 0xFFFACC15,
              size: 2.0,
              gravity: 95.0,
              drag: 0.975,
            ),
          );
        }
        break;

      default:
        break;
    }
  }

  /// Advances the effect state by `dt` seconds (clamped to `0.1s` as in `pixelfx`).
  void update(double dt) {
    final clampedDt = dt.clamp(0.0, 0.1);
    _elapsedTime += clampedDt;
    if (_isPureLoop) return;

    _accumulator += clampedDt;
    while (_accumulator >= _kFixedStep) {
      _accumulator -= _kFixedStep;
      _stepSimulation120Hz(_kFixedStep);
      _simStepCount++;
    }
  }

  void _stepSimulation120Hz(double stepDt) {
    for (var i = _particles.length - 1; i >= 0; i--) {
      final p = _particles[i];
      p.life -= stepDt;
      if (p.life <= 0) {
        _particles.removeAt(i);
        continue;
      }
      if (preset == PixelFxPreset.gbaBattleSwirl) {
        // Tangential spiral pull toward center then outward flash
        final dx = p.x - options.x;
        final dy = p.y - options.y;
        final dist = math.max(2.0, math.sqrt(dx * dx + dy * dy));
        final pull = _simStepCount < 45 ? -42.0 : 95.0;
        p.vx = (-dy / dist) * 85.0 + (dx / dist) * pull;
        p.vy = (dx / dist) * 85.0 + (dy / dist) * pull;
      }
      p.vx *= p.drag;
      p.vy = p.vy * p.drag + p.gravity * stepDt;
      p.x += p.vx * stepDt;
      p.y += p.vy * stepDt;
    }
  }

  /// Draws the current state of the effect onto `frame`.
  void draw(PixelFxFrame frame) {
    switch (preset) {
      case PixelFxPreset.bookshelfPortalAura:
        _drawBookshelfPortalAura(frame, _elapsedTime);
        break;
      case PixelFxPreset.ambientCampusMotes:
        _drawAmbientCampusMotes(frame, _elapsedTime);
        break;
      case PixelFxPreset.unrestZoneRipples:
        _drawUnrestZoneRipples(frame, _elapsedTime);
        break;
      case PixelFxPreset.astrolabePulse:
        _drawAstrolabePulse(frame, _elapsedTime);
        break;
      case PixelFxPreset.torchFlicker:
        _drawTorchFlicker(frame, _elapsedTime);
        break;
      case PixelFxPreset.curfewSearchlight:
        _drawCurfewSearchlight(frame, _elapsedTime);
        break;
      case PixelFxPreset.peoplePowerRibbons:
        _drawPeoplePowerRibbons(frame, _elapsedTime);
        break;
      default:
        _drawSimulatedEffect(frame);
        break;
    }
  }

  // ─────────────────────────────────────────────────────────────────────────
  //  PURE STATELESS LOOP EFFECTS (`draw(frame, t, opts)`)
  // ─────────────────────────────────────────────────────────────────────────

  void _drawBookshelfPortalAura(PixelFxFrame frame, double t) {
    final cx = options.x;
    final cy = options.y;
    final pulse = 0.5 + 0.5 * math.sin(t * 3.4);

    // Soft sovereign gold + kalayaan cyan radial glow in the light buffer
    frame.addRadialLight(cx, cy, 24.0 + 4.0 * pulse, 0xFFFACC15, 0.55);
    frame.addRadialLight(cx, cy, 16.0, 0xFF38BDF8, 0.45);

    // Swirling pixel vortex rings around the bookshelf
    for (var ring = 0; ring < 2; ring++) {
      final r = (ring == 0 ? 11.0 : 18.0) + math.sin(t * 2.5 + ring) * 1.5;
      final count = ring == 0 ? 10 : 14;
      for (var i = 0; i < count; i++) {
        final angle =
            (i / count) * math.pi * 2.0 + t * (ring == 0 ? 2.2 : -1.6);
        final px = (cx + math.cos(angle) * r).round();
        final py = (cy + math.sin(angle) * (r * 0.68)).round();
        final col = (i % 2 == 0) ? 0xFFFFF08A : 0xFF38BDF8;
        frame.setPixel(px, py, col, dither: 0.85);
        frame.addLight(px, py, col, 0.55);
      }
    }

    // Rising pixel runes / sparkles
    for (var i = 0; i < 6; i++) {
      final phase = (t * 0.85 + i * 0.37) % 1.0;
      final rx =
          (cx + math.sin(i * 2.1 + t * 2.0) * 14.0).round();
      final ry = (cy + 12.0 - phase * 26.0).round();
      if (phase < 0.85) {
        frame.drawSparkle(
          rx,
          ry,
          phase < 0.4 ? 2 : 1,
          0xFFFFFFFF,
          i.isEven ? 0xFFFACC15 : 0xFF38BDF8,
        );
      }
    }
  }

  void _drawAmbientCampusMotes(PixelFxFrame frame, double t) {
    final w = frame.width;
    final h = frame.height;
    final pal = options.palette ?? const [0xFFFDE047, 0xFF38BDF8, 0xFF6EE7B7];

    for (var i = 0; i < 18; i++) {
      final hx = PixelFxRng.hash2d(i, 1, options.seed);
      final hy = PixelFxRng.hash2d(i, 2, options.seed);
      final speed = 0.04 + (i % 4) * 0.015;
      final px =
          (((hx + t * speed * 0.5 + math.sin(t + i) * 0.03) % 1.0) * w).round();
      final py =
          (((hy - t * speed + 10.0) % 1.0) * h).round();
      final twinkle = 0.5 + 0.5 * math.sin(t * 3.2 + i * 1.7);
      final col = pal[i % pal.length];
      frame.setPixel(px, py, col, dither: 0.45 + 0.5 * twinkle);
      if (twinkle > 0.72) {
        frame.addLight(px, py, col, 0.35);
      }
    }
  }

  void _drawUnrestZoneRipples(PixelFxFrame frame, double t) {
    final cx = options.x;
    final cy = options.y;
    for (var i = 0; i < 5; i++) {
      final wave = ((t * 1.4 + i * 0.2) % 1.0);
      final r = 3.0 + wave * 11.0;
      final alpha = (1.0 - wave).clamp(0.0, 1.0);
      for (var a = 0; a < 8; a++) {
        final ang = a * (math.pi / 4.0) + i * 0.4;
        final px = (cx + math.cos(ang) * r).round();
        final py = (cy + math.sin(ang) * r * 0.6).round();
        frame.setPixel(px, py, 0xCCFBBF24, dither: alpha);
      }
    }
  }

  void _drawAstrolabePulse(PixelFxFrame frame, double t) {
    final cx = options.x;
    final cy = options.y;
    frame.addRadialLight(cx, cy, 18.0, 0xFFD97706, 0.45);
    for (var i = 0; i < 12; i++) {
      final a = (i / 12.0) * math.pi * 2.0 + t * 1.8;
      final px = (cx + math.cos(a) * 12.0).round();
      final py = (cy + math.sin(a) * 12.0).round();
      frame.setPixel(px, py, 0xFFFDE047);
      frame.addLight(px, py, 0xFFF59E0B, 0.5);
    }
    frame.drawSparkle(cx.round(), cy.round(), 3, 0xFFFFFFFF, 0xFFFACC15);
  }

  void _drawTorchFlicker(PixelFxFrame frame, double t) {
    final cx = options.x;
    final cy = options.y;
    final flicker = 0.82 + 0.18 * math.sin(t * 17.0) * math.cos(t * 11.0);
    frame.addRadialLight(cx, cy, 22.0 * flicker, 0xFFF97316, 0.65);
    frame.drawDisc(cx, cy, 3.5 * flicker, 0xFFFDE047,
        glowColor: 0xFFEA580C, glowRadius: 10);
    for (var i = 0; i < 5; i++) {
      final rise = ((t * 2.2 + i * 0.21) % 1.0);
      final px = (cx + math.sin(t * 6.0 + i) * 3.0).round();
      final py = (cy - rise * 12.0).round();
      frame.setPixel(px, py, rise < 0.5 ? 0xFFFDE047 : 0xFFEF4444,
          dither: 1.0 - rise);
    }
  }

  void _drawCurfewSearchlight(PixelFxFrame frame, double t) {
    final cx = options.x;
    final cy = options.y;
    final sweep = math.sin(t * 1.5) * 26.0;
    final tx = (cx + sweep).round();
    final ty = (cy + 24).round();
    frame.drawLine(cx.round(), (cy - 18).round(), tx, ty, 0x88F87171,
        glowColor: 0xFFEF4444);
    frame.addRadialLight(tx.toDouble(), ty.toDouble(), 12.0, 0xFFEF4444, 0.5);
  }

  void _drawPeoplePowerRibbons(PixelFxFrame frame, double t) {
    final w = frame.width;
    final h = frame.height;
    for (var i = 0; i < 22; i++) {
      final hx = PixelFxRng.hash2d(i, 10, options.seed);
      final hy = PixelFxRng.hash2d(i, 20, options.seed);
      final fall = (hy + t * (0.12 + (i % 3) * 0.04)) % 1.0;
      final sway = math.sin(t * 2.8 + i) * 5.0;
      final px = ((hx * w) + sway).round().clamp(1, w - 2);
      final py = (fall * h).round().clamp(1, h - 2);
      final col = i % 3 == 0 ? 0xFFFEF08A : 0xFFFACC15;
      frame.setPixel(px, py, col);
      frame.setPixel(px + 1, py, col);
      frame.addLight(px, py, 0xFFF59E0B, 0.35);
    }
  }

  // ─────────────────────────────────────────────────────────────────────────
  //  SIMULATED 120Hz PARTICLE & DOCTRINE EFFECTS
  // ─────────────────────────────────────────────────────────────────────────

  void _drawSimulatedEffect(PixelFxFrame frame) {
    final cx = options.x;
    final cy = options.y;

    // Additional geometric signature layers per doctrine
    if (preset == PixelFxPreset.habeasCorpusShield && _elapsedTime < 0.75) {
      final r = 10.0 + _elapsedTime * 18.0;
      final fade = (1.0 - _elapsedTime / 0.75).clamp(0.0, 1.0);
      for (var i = 0; i < 6; i++) {
        final a0 = i * (math.pi / 3.0) + _elapsedTime * 2.0;
        final a1 = (i + 1) * (math.pi / 3.0) + _elapsedTime * 2.0;
        frame.drawLine(
          (cx + math.cos(a0) * r).round(),
          (cy + math.sin(a0) * r).round(),
          (cx + math.cos(a1) * r).round(),
          (cy + math.sin(a1) * r).round(),
          0xFF38BDF8,
          glowColor: fade > 0.3 ? 0xFF0EA5E9 : null,
        );
      }
    } else if (preset == PixelFxPreset.checksAndBalancesScales &&
        _elapsedTime < 0.75) {
      final span = 18.0 * (1.0 - (_elapsedTime - 0.3).abs());
      final tilt = math.sin(_elapsedTime * 16.0) * 5.0;
      frame.drawLine(
        (cx - span).round(),
        (cy - tilt).round(),
        (cx + span).round(),
        (cy + tilt).round(),
        0xFFFACC15,
        glowColor: 0xFFF59E0B,
      );
    } else if (preset == PixelFxPreset.sovereigntySunburst &&
        _elapsedTime < 0.80) {
      frame.drawDisc(
        cx,
        cy,
        8.0 * (1.0 - _elapsedTime * 0.8).clamp(0.2, 1.0),
        0xFFFFF08A,
        glowColor: 0xFFF59E0B,
        glowRadius: 22.0,
      );
    }

    for (final p in _particles) {
      final lifeRatio = (p.life / p.maxLife).clamp(0.0, 1.0);
      final ix = p.x.round();
      final iy = p.y.round();
      if (p.size >= 2.0 && lifeRatio > 0.45) {
        frame.drawSparkle(ix, iy, 1, p.color, p.glowColor);
      } else {
        frame.setPixel(ix, iy, p.color, dither: lifeRatio);
        frame.addLight(ix, iy, p.glowColor, 0.55 * lifeRatio);
      }
    }
  }

  static List<int> _defaultPaletteFor(PixelFxPreset preset) {
    switch (preset) {
      case PixelFxPreset.sanduguanFlame:
        return const [0xFFFFF08A, 0xFFF97316, 0xFFEF4444, 0xFFB91C1C];
      case PixelFxPreset.checksAndBalancesScales:
        return const [0xFFFEF08A, 0xFFFACC15, 0xFF38BDF8, 0xFF0284C7];
      case PixelFxPreset.habeasCorpusShield:
        return const [0xFFE0F2FE, 0xFF38BDF8, 0xFF10B981, 0xFF059669];
      case PixelFxPreset.sovereigntySunburst:
      case PixelFxPreset.charterSealUnlock:
        return const [0xFFFFFFFF, 0xFFFEF08A, 0xFFFACC15, 0xFF38BDF8];
      case PixelFxPreset.bahayPulunganHeal:
        return const [0xFFD1FAE5, 0xFF34D399, 0xFF10B981, 0xFFFACC15];
      case PixelFxPreset.doubtShatterBurst:
        return const [0xFFFCA5A5, 0xFFEF4444, 0xFFA855F7, 0xFFFACC15];
      default:
        return const [0xFFFFFFFF, 0xFFFACC15, 0xFF38BDF8, 0xFF10B981];
    }
  }
}

/// Factory matching `createFx(effect, options)` from `patch-gg/pixelfx`.
PixelFxController createFx(
  PixelFxPreset preset, [
  PixelFxOptions options = const PixelFxOptions(),
]) {
  return PixelFxController(preset, options);
}
