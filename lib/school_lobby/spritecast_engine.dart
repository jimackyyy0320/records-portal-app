import 'dart:math' as math;
import 'package:flutter/material.dart';

import 'lobby_shop_service.dart';

/// SpriteCast-inspired 2.5D Pixel-Art Asset, Shadow, Seated-Occlusion & Ground Engine.
///
/// Integrates core game-art techniques from `Sunghwan0112/spritecast`:
/// 1. **Curated Pixel Palettes** (`ENDESGA-32` & `Sweetie-16`) with crisp 1px dark outlines
///    and 3-tone cel shading—zero blurry gradients or raw system emojis on pixel furniture.
/// 2. **5-Step Grounded Directional Shadows** (`10%–50%` alpha steps along a consistent light
///    vector, deepest directly under the prop base / feet and pale at the far cast edge).
/// 3. **Stepped Pixel Light Pools** (`light_style: "pixel"`): concentric dithered floor/desk
///    light pools cast by lamps and sunlit classroom windows.
/// 4. **Seated Front/Back Occlusion Splits** (`seat.py` principle): chair cushions/legs draw
///    under seated avatars while styled backrests/bolsters draw as a foreground front piece.
/// 5. **Natural Ground Detailing** (`ground.py` principle): Gaussian-clustered non-repeating
///    grass tufts & wildflowers, sunk reflective puddles with wet rims, quantized 1px wind
///    sway, and foreground foot-occlusion grass strips.
class SpriteCastPalette {
  SpriteCastPalette._();

  /// Exact ENDESGA-32 palette (`skills/spritecast/palettes/endesga32.hex`).
  static const List<Color> endesga32 = <Color>[
    Color(0xFFBE4A2F), // 0 terracotta
    Color(0xFFD77643), // 1 warm ochre
    Color(0xFFEAD4AA), // 2 cream highlight
    Color(0xFFE4A672), // 3 honey wood
    Color(0xFFB86F50), // 4 cedar wood
    Color(0xFF733E39), // 5 dark walnut
    Color(0xFF3E2731), // 6 espresso shadow
    Color(0xFFA22633), // 7 deep crimson
    Color(0xFFE43B44), // 8 bright crimson
    Color(0xFFF77622), // 9 tangerine
    Color(0xFFFEAE34), // 10 amber gold
    Color(0xFFFEE761), // 11 lemon glow
    Color(0xFF63C74D), // 12 leaf bright
    Color(0xFF3E8948), // 13 leaf mid
    Color(0xFF265C42), // 14 pine deep
    Color(0xFF193C3E), // 15 teal shadow
    Color(0xFF124E89), // 16 cobalt deep
    Color(0xFF0099DB), // 17 sky azure
    Color(0xFF2CE8F5), // 18 neon cyan
    Color(0xFFFFFFFF), // 19 pure white
    Color(0xFFC0CBDC), // 20 cool silver
    Color(0xFF8B9BB4), // 21 steel mid
    Color(0xFF5A6988), // 22 slate mid
    Color(0xFF3A4466), // 23 slate dark
    Color(0xFF262B44), // 24 midnight indigo
    Color(0xFF181425), // 25 pixel ink outline
    Color(0xFFFF0044), // 26 neon ruby
    Color(0xFF68386C), // 27 royal plum
    Color(0xFFB55088), // 28 berry rose
    Color(0xFFF6757A), // 29 sakura pink
    Color(0xFFE8B796), // 30 peach highlight
    Color(0xFFC28569), // 31 warm clay
  ];

  /// Exact Sweetie-16 palette (`skills/spritecast/palettes/sweetie16.hex`).
  static const List<Color> sweetie16 = <Color>[
    Color(0xFF1A1C2C), // 0 ink dark
    Color(0xFF5D275D), // 1 deep plum
    Color(0xFFB13E53), // 2 rose red
    Color(0xFFEF7D57), // 3 coral orange
    Color(0xFFFFCD75), // 4 warm sun
    Color(0xFFA7F070), // 5 spring green
    Color(0xFF38B764), // 6 emerald
    Color(0xFF257179), // 7 deep teal
    Color(0xFF29366F), // 8 navy
    Color(0xFF3B5DC9), // 9 royal blue
    Color(0xFF41A6F6), // 10 bright sky
    Color(0xFF73EFF7), // 11 ice cyan
    Color(0xFFF4F4F4), // 12 chalk white
    Color(0xFF94B0C2), // 13 frost grey
    Color(0xFF566C86), // 14 blue slate
    Color(0xFF333C57), // 15 shadow navy
  ];

  static const Color ink = Color(0xFF181425);
  static const Color shadowInk = Color(0xFF1A1C2C);
  static const Color cream = Color(0xFFEAD4AA);
  static const Color woodLight = Color(0xFFE4A672);
  static const Color woodMid = Color(0xFFB86F50);
  static const Color woodDark = Color(0xFF733E39);
  static const Color woodEdge = Color(0xFF3E2731);
}

/// Pure SpriteCast pixel-art drawing utilities for props, stepped shadows,
/// pixel light pools, seated chair splits, and natural ground layers.
class SpriteCastEngine {
  SpriteCastEngine._();

  /// Quantized 1-pixel wind-sway offset (`"sway": "leaves"` in SpriteCast).
  /// Returns `-1.0`, `0.0`, or `+1.0` scaled by [px] so foliage clumps shift by
  /// crisp whole pixels rather than blurry sub-pixel floats.
  static double windSwayPx(int animTick, int seed, {double px = 1.0}) {
    final phase = ((animTick * 0.09) + (seed * 0.73)) % (math.pi * 2);
    final s = math.sin(phase);
    if (s > 0.48) return px;
    if (s < -0.48) return -px;
    return 0.0;
  }

  /// Deterministic hash in `[0.0, 1.0)` for organic non-repeating placement.
  static double hash01(int a, int b) {
    var h = (a * 374761393) ^ (b * 668265263);
    h = (h ^ (h >> 13)) * 1274126177;
    h = h ^ (h >> 16);
    return (h & 0x7FFFFFFF) / 0x7FFFFFFF;
  }

  /// Draws a single crisp snapped pixel block at `(origin.dx + gx * px, origin.dy + gy * px)`.
  static void _pxRect(
    Canvas canvas,
    Offset origin,
    double gx,
    double gy,
    double gw,
    double gh,
    double px,
    Color color,
  ) {
    canvas.drawRect(
      Rect.fromLTWH(
        origin.dx + gx * px,
        origin.dy + gy * px,
        gw * px,
        gh * px,
      ),
      Paint()
        ..color = color
        ..isAntiAlias = false,
    );
  }

  /// SpriteCast 5-step grounded directional shadow (`10%–48%` quantized alpha bands).
  /// Deepest directly beneath the footprint and stepping outward along `(castDx, castDy)`.
  static void drawSteppedContactShadow(
    Canvas canvas,
    Rect baseFootprint, {
    double castDx = 6.0,
    double castDy = 4.0,
    double strength = 1.0,
    bool oval = false,
  }) {
    const stepAlphas = <double>[0.10, 0.14, 0.18, 0.24, 0.34];
    for (var i = 0; i < stepAlphas.length; i++) {
      final t = 1.0 - (i / (stepAlphas.length - 1));
      final dx = castDx * t;
      final dy = castDy * t;
      final inflate = (stepAlphas.length - 1 - i) * 1.2;
      final r = baseFootprint.shift(Offset(dx, dy)).inflate(inflate);
      final paint = Paint()
        ..color = SpriteCastPalette.shadowInk
            .withValues(alpha: (stepAlphas[i] * strength).clamp(0.0, 0.65))
        ..isAntiAlias = false;
      if (oval) {
        canvas.drawOval(r, paint);
      } else {
        canvas.drawRRect(
          RRect.fromRectAndRadius(r, const Radius.circular(3)),
          paint,
        );
      }
    }
  }

  /// SpriteCast stepped pixel light pool (`"light_style": "pixel"`).
  /// Uses discrete concentric pixel rings + checkerboard dithering along the outer ring
  /// so desk lamps and window sunbeams stay faithful to pixel art.
  static void drawSteppedPixelLightPool(
    Canvas canvas,
    Offset center, {
    required Color color,
    required double radius,
    double px = 2.0,
    double intensity = 1.0,
  }) {
    final steps = <({double frac, double alpha})>[
      (frac: 1.00, alpha: 0.08 * intensity),
      (frac: 0.76, alpha: 0.14 * intensity),
      (frac: 0.52, alpha: 0.22 * intensity),
      (frac: 0.28, alpha: 0.32 * intensity),
    ];
    for (final s in steps) {
      final rx = radius * s.frac;
      final ry = radius * s.frac * 0.72;
      final rect = Rect.fromCenter(center: center, width: rx * 2, height: ry * 2);
      canvas.drawOval(
        rect,
        Paint()
          ..color = color.withValues(alpha: s.alpha.clamp(0.0, 0.65))
          ..isAntiAlias = false,
      );
    }

    // Crisp pixel sparkle dither specks along the mid-ring
    final ditherPaint = Paint()
      ..color = color.withValues(alpha: (0.28 * intensity).clamp(0.0, 0.6))
      ..isAntiAlias = false;
    for (var i = 0; i < 8; i++) {
      final angle = (i * math.pi / 4) + 0.35;
      final sx = center.dx + math.cos(angle) * radius * 0.66;
      final sy = center.dy + math.sin(angle) * radius * 0.48;
      canvas.drawRect(Rect.fromLTWH(sx, sy, px, px), ditherPaint);
    }
  }

  /// Returns a `(light, mid, dark, accent)` 4-tone SpriteCast palette ramp for a chair style.
  static ({Color light, Color mid, Color dark, Color accent}) chairPalette(
    String chairStyle,
  ) {
    switch (chairStyle) {
      case 'crimson_gaming':
        return (
          light: SpriteCastPalette.endesga32[8], // bright crimson
          mid: SpriteCastPalette.endesga32[7], // deep crimson
          dark: SpriteCastPalette.endesga32[6], // espresso
          accent: SpriteCastPalette.endesga32[20], // cool silver stripe
        );
      case 'emerald_ergo':
        return (
          light: SpriteCastPalette.endesga32[12], // leaf bright
          mid: SpriteCastPalette.endesga32[13], // leaf mid
          dark: SpriteCastPalette.endesga32[14], // pine deep
          accent: SpriteCastPalette.endesga32[21], // steel mesh frame
        );
      case 'sakura_pastel':
        return (
          light: SpriteCastPalette.endesga32[29], // sakura pink
          mid: SpriteCastPalette.endesga32[28], // berry rose
          dark: SpriteCastPalette.endesga32[27], // royal plum
          accent: SpriteCastPalette.endesga32[2], // cream ribbon
        );
      case 'royal_gold':
        return (
          light: SpriteCastPalette.endesga32[11], // lemon glow
          mid: SpriteCastPalette.endesga32[10], // amber gold
          dark: SpriteCastPalette.endesga32[1], // warm ochre
          accent: SpriteCastPalette.endesga32[7], // crimson velvet piping
        );
      case 'cyber_neon':
        return (
          light: SpriteCastPalette.endesga32[22], // slate mid
          mid: SpriteCastPalette.endesga32[23], // slate dark
          dark: SpriteCastPalette.endesga32[24], // midnight indigo
          accent: SpriteCastPalette.endesga32[18], // neon cyan LED rail
        );
      default: // 'tan_classic'
        return (
          light: SpriteCastPalette.woodLight,
          mid: SpriteCastPalette.woodMid,
          dark: SpriteCastPalette.woodDark,
          accent: SpriteCastPalette.cream,
        );
    }
  }

  /// SpriteCast `seat.py` Layer 1 (UNDER seated character):
  /// Chair stepped shadow, metal/wood base legs, seat cushion, and armrests.
  static void drawPixelDeskChairBase(
    Canvas canvas,
    Offset chairCenter, {
    required String chairStyle,
    double px = 2.0,
  }) {
    final pal = chairPalette(chairStyle);
    final origin = Offset(chairCenter.dx - 9 * px, chairCenter.dy - 7 * px);

    // 5-step grounded contact shadow beneath the chair base
    drawSteppedContactShadow(
      canvas,
      Rect.fromCenter(
        center: Offset(chairCenter.dx, chairCenter.dy + 4 * px),
        width: 15 * px,
        height: 7 * px,
      ),
      castDx: 2.5 * px,
      castDy: 1.5 * px,
      strength: 0.78,
      oval: true,
    );

    // Chair legs / caster base
    if (chairStyle == 'crimson_gaming' ||
        chairStyle == 'emerald_ergo' ||
        chairStyle == 'cyber_neon' ||
        chairStyle == 'royal_gold') {
      // 5-star swivel pedestal base
      _pxRect(canvas, origin, 7, 10, 4, 3, px, SpriteCastPalette.ink);
      _pxRect(canvas, origin, 8, 10, 2, 2, px, SpriteCastPalette.endesga32[21]);
      _pxRect(canvas, origin, 3, 12, 12, 2, px, SpriteCastPalette.ink);
      _pxRect(canvas, origin, 4, 12, 10, 1, px, SpriteCastPalette.endesga32[22]);
      _pxRect(canvas, origin, 3, 13, 2, 1, px, SpriteCastPalette.endesga32[23]);
      _pxRect(canvas, origin, 13, 13, 2, 1, px, SpriteCastPalette.endesga32[23]);
    } else {
      // Four wooden/pastel legs
      _pxRect(canvas, origin, 3, 9, 2, 5, px, SpriteCastPalette.ink);
      _pxRect(canvas, origin, 13, 9, 2, 5, px, SpriteCastPalette.ink);
      _pxRect(canvas, origin, 3.5, 9.5, 1, 4, px, pal.dark);
      _pxRect(canvas, origin, 13.5, 9.5, 1, 4, px, pal.dark);
    }

    // Seat cushion outline + 3-tone cel fill
    _pxRect(canvas, origin, 2, 3, 14, 7, px, SpriteCastPalette.ink);
    _pxRect(canvas, origin, 3, 4, 12, 5, px, pal.mid);
    _pxRect(canvas, origin, 4, 4, 10, 2, px, pal.light);
    _pxRect(canvas, origin, 3, 8, 12, 1, px, pal.dark);

    // Side armrests for pro/ergo/cyber/royal chairs
    if (chairStyle != 'tan_classic') {
      _pxRect(canvas, origin, 1, 4, 2, 5, px, SpriteCastPalette.ink);
      _pxRect(canvas, origin, 15, 4, 2, 5, px, SpriteCastPalette.ink);
      _pxRect(canvas, origin, 1.5, 4.5, 1, 3.5, px, pal.accent);
      _pxRect(canvas, origin, 15.5, 4.5, 1, 3.5, px, pal.accent);
    }
  }

  /// SpriteCast `seat.py` Layer 2 (`front.png` — OVER seated character when facing up):
  /// Renders the sculpted chair backrest & headrest/led/bow detail so seated students
  /// naturally tuck INTO their chair instead of floating flat on top!
  static void drawPixelDeskChairBackrestFront(
    Canvas canvas,
    Offset chairCenter, {
    required String chairStyle,
    double px = 2.0,
    int animTick = 0,
  }) {
    final pal = chairPalette(chairStyle);
    final origin = Offset(chairCenter.dx - 9 * px, chairCenter.dy - 7 * px);

    if (chairStyle == 'crimson_gaming' || chairStyle == 'cyber_neon') {
      // Tall racing bucket backrest with angled wing bolsters & headrest
      _pxRect(canvas, origin, 2, 4, 14, 9, px, SpriteCastPalette.ink);
      _pxRect(canvas, origin, 4, 2, 10, 3, px, SpriteCastPalette.ink);
      _pxRect(canvas, origin, 3, 5, 12, 7, px, pal.dark);
      _pxRect(canvas, origin, 5, 3, 8, 8, px, pal.mid);
      _pxRect(canvas, origin, 6, 3, 6, 2, px, pal.light);
      // Racing harness cutout + side LED/silver stripes
      _pxRect(canvas, origin, 7, 5, 4, 1, px, SpriteCastPalette.ink);
      final pulseAlpha = chairStyle == 'cyber_neon'
          ? (0.72 + 0.28 * math.sin(animTick * 0.2))
          : 1.0;
      final accentCol = pal.accent.withValues(alpha: pulseAlpha);
      _pxRect(canvas, origin, 3, 5, 1, 6, px, accentCol);
      _pxRect(canvas, origin, 14, 5, 1, 6, px, accentCol);
      if (chairStyle == 'cyber_neon') {
        _pxRect(canvas, origin, 6, 2, 6, 1, px, accentCol);
      }
    } else if (chairStyle == 'emerald_ergo') {
      // Sculpted ergonomic mesh backrest with lumbar bar & headrest
      _pxRect(canvas, origin, 3, 5, 12, 7, px, SpriteCastPalette.ink);
      _pxRect(canvas, origin, 5, 3, 8, 2, px, SpriteCastPalette.ink);
      _pxRect(canvas, origin, 6, 3.5, 6, 1, px, pal.light);
      _pxRect(canvas, origin, 4, 6, 10, 5, px, pal.mid);
      // Pixel mesh ventilation dots
      for (var gx = 5.0; gx <= 12.0; gx += 2.0) {
        _pxRect(canvas, origin, gx, 7, 1, 1, px, pal.dark);
        _pxRect(canvas, origin, gx + 1, 9, 1, 1, px, pal.dark);
      }
      // Metallic lumbar support bar
      _pxRect(canvas, origin, 4, 10, 10, 1, px, pal.accent);
    } else if (chairStyle == 'sakura_pastel') {
      // Rounded plush cushion backrest with cream ribbon bow
      _pxRect(canvas, origin, 3, 5, 12, 7, px, SpriteCastPalette.ink);
      _pxRect(canvas, origin, 4, 4, 10, 1, px, SpriteCastPalette.ink);
      _pxRect(canvas, origin, 4, 5, 10, 6, px, pal.mid);
      _pxRect(canvas, origin, 5, 5, 8, 2, px, pal.light);
      _pxRect(canvas, origin, 4, 10, 10, 1, px, pal.dark);
      // Cute pixel bow at top-center
      _pxRect(canvas, origin, 6, 4, 2, 2, px, pal.accent);
      _pxRect(canvas, origin, 10, 4, 2, 2, px, pal.accent);
      _pxRect(canvas, origin, 8, 4.5, 2, 1.5, px, SpriteCastPalette.endesga32[26]);
    } else if (chairStyle == 'royal_gold') {
      // Tufted executive crown backrest with gold trim & crimson center piping
      _pxRect(canvas, origin, 3, 4, 12, 8, px, SpriteCastPalette.ink);
      _pxRect(canvas, origin, 6, 3, 6, 1, px, SpriteCastPalette.ink);
      _pxRect(canvas, origin, 4, 5, 10, 6, px, pal.mid);
      _pxRect(canvas, origin, 5, 4, 8, 2, px, pal.light);
      _pxRect(canvas, origin, 5, 7, 8, 3, px, pal.accent);
      // Tufting gold buttons
      _pxRect(canvas, origin, 6, 8, 1, 1, px, pal.light);
      _pxRect(canvas, origin, 11, 8, 1, 1, px, pal.light);
    } else {
      // Classic Oak wooden slat backrest
      _pxRect(canvas, origin, 3, 6, 12, 6, px, SpriteCastPalette.ink);
      _pxRect(canvas, origin, 4, 7, 10, 4, px, pal.mid);
      _pxRect(canvas, origin, 4, 7, 10, 1, px, pal.light);
      _pxRect(canvas, origin, 4, 10, 10, 1, px, pal.dark);
      // Vertical wood slats
      _pxRect(canvas, origin, 6, 8, 1, 2, px, SpriteCastPalette.ink);
      _pxRect(canvas, origin, 11, 8, 1, 2, px, SpriteCastPalette.ink);
    }
  }

  /// Renders a crisp 2.5D pixel-art wooden desk body (used by the Live Desk Studio
  /// preview AND as an enhanced tabletop surface for Classroom personal desks).
  static void drawPixelDeskWoodSurface(
    Canvas canvas,
    Rect deskRect, {
    double px = 2.0,
    bool drawLegsAndShadow = true,
  }) {
    if (drawLegsAndShadow) {
      drawSteppedContactShadow(
        canvas,
        Rect.fromLTWH(
          deskRect.left + 2,
          deskRect.bottom - 2,
          deskRect.width - 4,
          12,
        ),
        castDx: 5,
        castDy: 4,
        strength: 0.85,
      );
      // Desk front apron & side legs
      final legH = 6 * px;
      canvas.drawRect(
        Rect.fromLTWH(deskRect.left + px, deskRect.bottom - px, deskRect.width - 2 * px, legH),
        Paint()..color = SpriteCastPalette.ink..isAntiAlias = false,
      );
      canvas.drawRect(
        Rect.fromLTWH(deskRect.left + 2 * px, deskRect.bottom, deskRect.width - 4 * px, legH - 2 * px),
        Paint()..color = SpriteCastPalette.woodDark..isAntiAlias = false,
      );
      // Recessed knee shadow
      canvas.drawRect(
        Rect.fromLTWH(deskRect.left + 6 * px, deskRect.bottom + 2 * px, deskRect.width - 12 * px, legH - 3 * px),
        Paint()..color = SpriteCastPalette.woodEdge..isAntiAlias = false,
      );
      // Drawer handle highlight on right pedestal
      canvas.drawRect(
        Rect.fromLTWH(deskRect.right - 5 * px, deskRect.bottom + 1.5 * px, 2 * px, px),
        Paint()..color = SpriteCastPalette.cream..isAntiAlias = false,
      );
    }

    // Top plank outer ink border
    canvas.drawRect(
      deskRect,
      Paint()..color = SpriteCastPalette.ink..isAntiAlias = false,
    );
    // Warm cedar surface
    final inner = deskRect.deflate(px);
    canvas.drawRect(
      inner,
      Paint()..color = SpriteCastPalette.woodMid..isAntiAlias = false,
    );
    // Top specular wood edge highlight
    canvas.drawRect(
      Rect.fromLTWH(inner.left, inner.top, inner.width, px),
      Paint()..color = SpriteCastPalette.woodLight..isAntiAlias = false,
    );
    // Bottom beveled front thickness
    canvas.drawRect(
      Rect.fromLTWH(inner.left, inner.bottom - 2 * px, inner.width, 2 * px),
      Paint()..color = SpriteCastPalette.woodDark..isAntiAlias = false,
    );
    // Subtle wood grain lines
    final grain = Paint()
      ..color = SpriteCastPalette.woodDark.withValues(alpha: 0.45)
      ..isAntiAlias = false;
    canvas.drawRect(
      Rect.fromLTWH(inner.left + 6 * px, inner.top + 4 * px, 18 * px, px * 0.6),
      grain,
    );
    canvas.drawRect(
      Rect.fromLTWH(inner.right - 22 * px, inner.top + 9 * px, 16 * px, px * 0.6),
      grain,
    );
  }

  /// Renders a SpriteCast pixel-art Desk Mat on top of [deskRect].
  static void drawPixelDeskMat(
    Canvas canvas,
    Rect deskRect, {
    required String deskMat,
    double px = 2.0,
  }) {
    if (deskMat == 'oak_default' || deskMat == 'none') return;
    final matRect = Rect.fromLTWH(
      deskRect.left + 4 * px,
      deskRect.top + 3 * px,
      deskRect.width - 8 * px,
      deskRect.height - 7 * px,
    );

    Color baseCol;
    Color rimCol;
    Color stitchCol;
    switch (deskMat) {
      case 'mint_pad':
        baseCol = SpriteCastPalette.sweetie16[6]; // emerald
        rimCol = SpriteCastPalette.endesga32[14]; // pine deep
        stitchCol = SpriteCastPalette.sweetie16[5]; // spring green
        break;
      case 'galaxy_mat':
        baseCol = SpriteCastPalette.endesga32[24]; // midnight indigo
        rimCol = SpriteCastPalette.endesga32[25]; // ink
        stitchCol = SpriteCastPalette.endesga32[28]; // berry nebula
        break;
      case 'lofi_grid':
        baseCol = SpriteCastPalette.endesga32[16]; // cobalt blueprint
        rimCol = SpriteCastPalette.endesga32[24];
        stitchCol = SpriteCastPalette.endesga32[18]; // cyan grid
        break;
      case 'royal_velvet':
        baseCol = SpriteCastPalette.endesga32[7]; // crimson velvet
        rimCol = SpriteCastPalette.endesga32[6];
        stitchCol = SpriteCastPalette.endesga32[10]; // gold trim
        break;
      default:
        return;
    }

    // Crisp 1px ink border + fill
    canvas.drawRect(
      matRect,
      Paint()..color = SpriteCastPalette.ink..isAntiAlias = false,
    );
    final fill = matRect.deflate(px * 0.75);
    canvas.drawRect(fill, Paint()..color = baseCol..isAntiAlias = false);
    // Bottom shade edge
    canvas.drawRect(
      Rect.fromLTWH(fill.left, fill.bottom - px, fill.width, px),
      Paint()..color = rimCol..isAntiAlias = false,
    );

    // Style-specific pixel artwork on the mat
    if (deskMat == 'mint_pad') {
      // Stitched corner accents + cream label tag
      final sPaint = Paint()..color = stitchCol..isAntiAlias = false;
      for (var x = fill.left + px; x < fill.right - px; x += 3 * px) {
        canvas.drawRect(Rect.fromLTWH(x, fill.top + px * 0.5, px, px * 0.5), sPaint);
        canvas.drawRect(Rect.fromLTWH(x, fill.bottom - 1.5 * px, px, px * 0.5), sPaint);
      }
      canvas.drawRect(
        Rect.fromLTWH(fill.right - 5 * px, fill.bottom - 3 * px, 3 * px, 1.5 * px),
        Paint()..color = SpriteCastPalette.cream..isAntiAlias = false,
      );
    } else if (deskMat == 'galaxy_mat') {
      // Nebula cloud clusters + pixel stars
      canvas.drawRect(
        Rect.fromLTWH(fill.left + 4 * px, fill.top + 3 * px, 12 * px, 4 * px),
        Paint()..color = SpriteCastPalette.endesga32[27].withValues(alpha: 0.7)..isAntiAlias = false,
      );
      canvas.drawRect(
        Rect.fromLTWH(fill.right - 16 * px, fill.bottom - 6 * px, 10 * px, 3 * px),
        Paint()..color = SpriteCastPalette.endesga32[16].withValues(alpha: 0.65)..isAntiAlias = false,
      );
      final starCoords = <Offset>[
        Offset(fill.left + 6 * px, fill.top + 3 * px),
        Offset(fill.left + 14 * px, fill.top + 6 * px),
        Offset(fill.center.dx, fill.top + 2.5 * px),
        Offset(fill.right - 10 * px, fill.top + 5 * px),
        Offset(fill.right - 5 * px, fill.bottom - 4 * px),
        Offset(fill.left + 20 * px, fill.bottom - 3.5 * px),
      ];
      for (var i = 0; i < starCoords.length; i++) {
        final col = i.isEven
            ? SpriteCastPalette.endesga32[11]
            : SpriteCastPalette.endesga32[18];
        canvas.drawRect(
          Rect.fromLTWH(starCoords[i].dx, starCoords[i].dy, px, px),
          Paint()..color = col..isAntiAlias = false,
        );
      }
    } else if (deskMat == 'lofi_grid') {
      // Crisp cyan architectural grid lines
      final gridP = Paint()
        ..color = stitchCol.withValues(alpha: 0.42)
        ..isAntiAlias = false;
      for (var x = fill.left + 4 * px; x < fill.right - px; x += 4 * px) {
        canvas.drawRect(Rect.fromLTWH(x, fill.top, px * 0.5, fill.height), gridP);
      }
      for (var y = fill.top + 4 * px; y < fill.bottom - px; y += 4 * px) {
        canvas.drawRect(Rect.fromLTWH(fill.left, y, fill.width, px * 0.5), gridP);
      }
      // Corner crosshairs
      canvas.drawRect(
        Rect.fromLTWH(fill.left + px, fill.top + px, 2 * px, px * 0.6),
        Paint()..color = stitchCol..isAntiAlias = false,
      );
      canvas.drawRect(
        Rect.fromLTWH(fill.left + px, fill.top + px, px * 0.6, 2 * px),
        Paint()..color = stitchCol..isAntiAlias = false,
      );
    } else if (deskMat == 'royal_velvet') {
      // Gold embroidered inner frame + corner tassels
      final goldP = Paint()..color = stitchCol..isAntiAlias = false;
      canvas.drawRect(Rect.fromLTWH(fill.left + px, fill.top + px, fill.width - 2 * px, px * 0.7), goldP);
      canvas.drawRect(Rect.fromLTWH(fill.left + px, fill.bottom - 2 * px, fill.width - 2 * px, px * 0.7), goldP);
      canvas.drawRect(Rect.fromLTWH(fill.left + px, fill.top + px, px * 0.7, fill.height - 2.5 * px), goldP);
      canvas.drawRect(Rect.fromLTWH(fill.right - 1.7 * px, fill.top + px, px * 0.7, fill.height - 2.5 * px), goldP);
      // Tassels sticking out left/right edges
      canvas.drawRect(Rect.fromLTWH(matRect.left - px, fill.top + 2 * px, px, 2 * px), goldP);
      canvas.drawRect(Rect.fromLTWH(matRect.left - px, fill.bottom - 4 * px, px, 2 * px), goldP);
      canvas.drawRect(Rect.fromLTWH(matRect.right, fill.top + 2 * px, px, 2 * px), goldP);
      canvas.drawRect(Rect.fromLTWH(matRect.right, fill.bottom - 4 * px, px, 2 * px), goldP);
    }
  }

  /// Renders a SpriteCast crisp pixel-art Mini Light + stepped pixel light pool.
  static void drawPixelMiniLight(
    Canvas canvas,
    Rect deskRect, {
    required String miniLight,
    double px = 2.0,
    int animTick = 0,
    bool isDarkMode = false,
  }) {
    if (miniLight == 'none') return;
    final lightBoost = isDarkMode ? 1.35 : 0.92;
    final twinkle = 0.84 + 0.16 * math.sin(animTick * 0.22);

    if (miniLight == 'fairy_warm') {
      // Draped copper wire along back edge of desk with 5 warm glowing pixel bulbs
      final wireY = deskRect.top + 1.5 * px;
      for (var i = 0; i < 5; i++) {
        final t = (i + 0.5) / 5.0;
        final bx = deskRect.left + 5 * px + t * (deskRect.width - 10 * px);
        final sag = ((i == 1 || i == 3) ? 1.5 : (i == 2 ? 2.0 : 0.5)) * px;
        final bulbPos = Offset(bx, wireY + sag);
        drawSteppedPixelLightPool(
          canvas,
          bulbPos,
          color: SpriteCastPalette.endesga32[11],
          radius: 8 * px,
          px: px,
          intensity: 0.75 * lightBoost * twinkle,
        );
        // Wire segment
        if (i < 4) {
          canvas.drawLine(
            bulbPos,
            Offset(
              deskRect.left + 5 * px + ((i + 1.5) / 5.0) * (deskRect.width - 10 * px),
              wireY + (((i + 1) == 1 || (i + 1) == 3) ? 1.5 : ((i + 1) == 2 ? 2.0 : 0.5)) * px,
            ),
            Paint()..color = SpriteCastPalette.woodDark..strokeWidth = px * 0.6,
          );
        }
        // Pixel bulb with ink rim
        canvas.drawRect(
          Rect.fromCenter(center: bulbPos, width: 2.8 * px, height: 2.8 * px),
          Paint()..color = SpriteCastPalette.ink..isAntiAlias = false,
        );
        canvas.drawRect(
          Rect.fromCenter(center: bulbPos, width: 1.8 * px, height: 1.8 * px),
          Paint()
            ..color = i.isEven
                ? SpriteCastPalette.endesga32[11]
                : SpriteCastPalette.endesga32[10]
            ..isAntiAlias = false,
        );
      }
      return;
    }

    if (miniLight == 'neon_strip') {
      // Sleek rear RGB LED light bar with stepped cyan/magenta pixel glow
      final barRect = Rect.fromLTWH(
        deskRect.left + 6 * px,
        deskRect.top + px,
        deskRect.width - 12 * px,
        2 * px,
      );
      drawSteppedPixelLightPool(
        canvas,
        Offset(deskRect.left + deskRect.width * 0.3, deskRect.top + 6 * px),
        color: SpriteCastPalette.endesga32[18],
        radius: 14 * px,
        px: px,
        intensity: 0.85 * lightBoost * twinkle,
      );
      drawSteppedPixelLightPool(
        canvas,
        Offset(deskRect.right - deskRect.width * 0.3, deskRect.top + 6 * px),
        color: SpriteCastPalette.endesga32[26],
        radius: 14 * px,
        px: px,
        intensity: 0.85 * lightBoost * twinkle,
      );
      canvas.drawRect(barRect, Paint()..color = SpriteCastPalette.ink..isAntiAlias = false);
      final halfW = (barRect.width - 2 * px) / 2;
      canvas.drawRect(
        Rect.fromLTWH(barRect.left + px, barRect.top + px * 0.5, halfW, px),
        Paint()..color = SpriteCastPalette.endesga32[18]..isAntiAlias = false,
      );
      canvas.drawRect(
        Rect.fromLTWH(barRect.left + px + halfW, barRect.top + px * 0.5, halfW, px),
        Paint()..color = SpriteCastPalette.endesga32[28]..isAntiAlias = false,
      );
      return;
    }

    // Left-corner lamps (`banker_brass` or `starlight_lantern`)
    final origin = Offset(deskRect.left + 3 * px, deskRect.top - 2 * px);
    if (miniLight == 'banker_brass') {
      // Warm stepped light pool falling across left desk quadrant
      drawSteppedPixelLightPool(
        canvas,
        Offset(origin.dx + 4.5 * px, origin.dy + 9 * px),
        color: SpriteCastPalette.endesga32[11],
        radius: 13 * px,
        px: px,
        intensity: 0.95 * lightBoost * twinkle,
      );
      // Contact shadow
      drawSteppedContactShadow(
        canvas,
        Rect.fromLTWH(origin.dx + 1 * px, origin.dy + 8 * px, 6 * px, 2.5 * px),
        castDx: 2 * px,
        castDy: 1 * px,
        strength: 0.65,
      );
      // Brass base
      _pxRect(canvas, origin, 1, 7, 6, 3, px, SpriteCastPalette.ink);
      _pxRect(canvas, origin, 2, 8, 4, 1, px, SpriteCastPalette.endesga32[10]);
      // Brass gooseneck stem
      _pxRect(canvas, origin, 3, 3, 2, 5, px, SpriteCastPalette.ink);
      _pxRect(canvas, origin, 3.5, 4, 1, 4, px, SpriteCastPalette.endesga32[10]);
      // Classic emerald glass shade
      _pxRect(canvas, origin, 0, 1, 8, 4, px, SpriteCastPalette.ink);
      _pxRect(canvas, origin, 1, 2, 6, 2, px, SpriteCastPalette.sweetie16[6]);
      _pxRect(canvas, origin, 2, 2, 4, 1, px, SpriteCastPalette.sweetie16[5]);
      // Warm glowing bulb underside
      _pxRect(canvas, origin, 2, 4, 4, 1, px, SpriteCastPalette.endesga32[11]);
    } else if (miniLight == 'starlight_lantern') {
      final bobY = math.sin(animTick * 0.16) > 0.35 ? -0.5 : 0.0;
      drawSteppedPixelLightPool(
        canvas,
        Offset(origin.dx + 4 * px, origin.dy + 6 * px),
        color: SpriteCastPalette.endesga32[18],
        radius: 14 * px,
        px: px,
        intensity: 0.98 * lightBoost * twinkle,
      );
      // Pedestal stand
      _pxRect(canvas, origin, 1, 8, 6, 2, px, SpriteCastPalette.ink);
      _pxRect(canvas, origin, 2, 8.5, 4, 1, px, SpriteCastPalette.endesga32[10]);
      // Crescent brass arch
      _pxRect(canvas, origin, 1, 2, 2, 7, px, SpriteCastPalette.ink);
      _pxRect(canvas, origin, 1.5, 2.5, 1, 6, px, SpriteCastPalette.endesga32[10]);
      _pxRect(canvas, origin, 2, 1, 4, 2, px, SpriteCastPalette.ink);
      _pxRect(canvas, origin, 2.5, 1.5, 3, 1, px, SpriteCastPalette.endesga32[11]);
      // Floating glowing starlight orb
      _pxRect(canvas, origin, 3, 3 + bobY, 4, 4, px, SpriteCastPalette.ink);
      _pxRect(canvas, origin, 3.5, 3.5 + bobY, 3, 3, px, SpriteCastPalette.endesga32[17]);
      _pxRect(canvas, origin, 4, 4 + bobY, 2, 2, px, SpriteCastPalette.endesga32[18]);
      _pxRect(canvas, origin, 4.5, 4.2 + bobY, 1, 1, px, SpriteCastPalette.endesga32[19]);
    }
  }

  /// Renders a SpriteCast crisp pixel-art Desk Frame / Plaque at top-center of [deskRect].
  static void drawPixelDeskFrame(
    Canvas canvas,
    Rect deskRect, {
    required String deskFrame,
    double px = 2.0,
    int animTick = 0,
  }) {
    if (deskFrame == 'none') return;
    final origin = Offset(deskRect.center.dx - 4 * px, deskRect.top - 1.5 * px);

    drawSteppedContactShadow(
      canvas,
      Rect.fromLTWH(origin.dx + px, origin.dy + 7 * px, 6 * px, 2 * px),
      castDx: 1.5 * px,
      castDy: 1 * px,
      strength: 0.6,
    );

    if (deskFrame == 'gold_cert') {
      // Gold-framed honor roll diploma on mini wooden easel
      _pxRect(canvas, origin, 0, 1, 8, 7, px, SpriteCastPalette.ink);
      _pxRect(canvas, origin, 1, 2, 6, 5, px, SpriteCastPalette.endesga32[10]);
      _pxRect(canvas, origin, 2, 3, 4, 3, px, SpriteCastPalette.cream);
      // Tiny ink script lines + red wax seal
      _pxRect(canvas, origin, 2.5, 3.5, 3, 0.6, px, SpriteCastPalette.woodDark);
      _pxRect(canvas, origin, 2.5, 4.6, 2, 0.6, px, SpriteCastPalette.woodDark);
      _pxRect(canvas, origin, 4.8, 4.7, 1.1, 1.1, px, SpriteCastPalette.endesga32[8]);
    } else if (deskFrame == 'pixel_portrait') {
      // Pastel framed class photo
      _pxRect(canvas, origin, 0, 1, 8, 7, px, SpriteCastPalette.ink);
      _pxRect(canvas, origin, 1, 2, 6, 5, px, SpriteCastPalette.woodLight);
      _pxRect(canvas, origin, 2, 3, 4, 3, px, SpriteCastPalette.endesga32[17]);
      // Mini pixel student portrait silhouette inside frame
      _pxRect(canvas, origin, 3.2, 3.3, 1.6, 1.4, px, SpriteCastPalette.endesga32[30]);
      _pxRect(canvas, origin, 3.0, 4.7, 2.0, 1.2, px, SpriteCastPalette.endesga32[7]);
    } else if (deskFrame == 'holo_plaque') {
      // Amethyst + cyan holographic scholar trophy plaque
      final shimmer = (animTick ~/ 8).isEven;
      _pxRect(canvas, origin, 1, 6, 6, 2, px, SpriteCastPalette.ink);
      _pxRect(canvas, origin, 2, 6.5, 4, 1, px, SpriteCastPalette.endesga32[22]);
      _pxRect(canvas, origin, 1, 0, 6, 7, px, SpriteCastPalette.ink);
      _pxRect(canvas, origin, 2, 1, 4, 5, px, SpriteCastPalette.endesga32[27]);
      _pxRect(
        canvas,
        origin,
        2.5,
        1.5,
        3,
        4,
        px,
        shimmer ? SpriteCastPalette.endesga32[18] : SpriteCastPalette.endesga32[17],
      );
      // Bright pixel star crest in center
      _pxRect(canvas, origin, 3.5, 2.5, 1, 2, px, SpriteCastPalette.endesga32[19]);
      _pxRect(canvas, origin, 3, 3, 2, 1, px, SpriteCastPalette.endesga32[19]);
    }
  }

  /// Renders a SpriteCast crisp pixel-art Tabletop Prop on the right side of [deskRect].
  static void drawPixelDeskProp(
    Canvas canvas,
    Rect deskRect, {
    required String deskProp,
    double px = 2.0,
    int animTick = 0,
  }) {
    if (deskProp == 'none') return;
    final origin = Offset(deskRect.right - 12 * px, deskRect.top - 1.5 * px);

    drawSteppedContactShadow(
      canvas,
      Rect.fromLTWH(origin.dx + px, origin.dy + 7 * px, 8 * px, 2.5 * px),
      castDx: 2 * px,
      castDy: 1 * px,
      strength: 0.65,
    );

    if (deskProp == 'textbooks_stack') {
      // 3 stacked bound SHS textbooks (cobalt, crimson, emerald) + cream pages + bookmark
      // Bottom book (cobalt)
      _pxRect(canvas, origin, 0, 6, 9, 3, px, SpriteCastPalette.ink);
      _pxRect(canvas, origin, 1, 6.5, 7, 2, px, SpriteCastPalette.endesga32[16]);
      _pxRect(canvas, origin, 7, 7, 1, 1, px, SpriteCastPalette.cream);
      // Middle book (crimson, slightly offset)
      _pxRect(canvas, origin, 1, 4, 8, 3, px, SpriteCastPalette.ink);
      _pxRect(canvas, origin, 2, 4.5, 6, 2, px, SpriteCastPalette.endesga32[8]);
      _pxRect(canvas, origin, 7, 5, 1, 1, px, SpriteCastPalette.cream);
      // Top book (emerald + gold bookmark ribbon)
      _pxRect(canvas, origin, 0.5, 2, 7.5, 3, px, SpriteCastPalette.ink);
      _pxRect(canvas, origin, 1.5, 2.5, 5.5, 2, px, SpriteCastPalette.endesga32[13]);
      _pxRect(canvas, origin, 2, 2.5, 4.5, 0.7, px, SpriteCastPalette.endesga32[12]);
      _pxRect(canvas, origin, 5, 4.5, 1, 2.5, px, SpriteCastPalette.endesga32[11]);
    } else if (deskProp == 'zen_bonsai') {
      // Glazed terracotta pot + gnarled trunk + quantized wind-swaying 3-tone foliage!
      final sway = windSwayPx(animTick, 42, px: 0.45);
      // Pot
      _pxRect(canvas, origin, 2, 6, 6, 3, px, SpriteCastPalette.ink);
      _pxRect(canvas, origin, 3, 6.5, 4, 2, px, SpriteCastPalette.endesga32[0]);
      _pxRect(canvas, origin, 2.5, 6, 5, 1, px, SpriteCastPalette.endesga32[1]);
      // Soil & gnarled trunk
      _pxRect(canvas, origin, 4, 3.5, 2, 3, px, SpriteCastPalette.ink);
      _pxRect(canvas, origin, 4.5, 4, 1, 2.5, px, SpriteCastPalette.woodDark);
      // Canopy clumps (quantized pixel wind sway)
      _pxRect(canvas, origin, 1 + sway, 1, 8, 4, px, SpriteCastPalette.ink);
      _pxRect(canvas, origin, 2 + sway, 0, 6, 2, px, SpriteCastPalette.ink);
      _pxRect(canvas, origin, 2 + sway, 1.5, 6, 2.5, px, SpriteCastPalette.endesga32[14]);
      _pxRect(canvas, origin, 2.5 + sway, 1, 5, 2, px, SpriteCastPalette.endesga32[13]);
      _pxRect(canvas, origin, 3 + sway, 0.5, 3.5, 1.2, px, SpriteCastPalette.endesga32[12]);
      // Tiny sakura blossom dot
      _pxRect(canvas, origin, 6 + sway, 1.5, 1, 1, px, SpriteCastPalette.endesga32[29]);
    } else if (deskProp == 'gaming_laptop') {
      // Open angled study laptop with illuminated RGB keyboard & bright screen
      // Screen lid
      _pxRect(canvas, origin, 1, 0, 8, 6, px, SpriteCastPalette.ink);
      _pxRect(canvas, origin, 2, 1, 6, 4, px, SpriteCastPalette.endesga32[24]);
      _pxRect(canvas, origin, 2.4, 1.4, 5.2, 3.2, px, SpriteCastPalette.endesga32[17]);
      // Mini code/reviewer bars on screen
      _pxRect(canvas, origin, 2.8, 2.0, 3.2, 0.7, px, SpriteCastPalette.endesga32[19]);
      _pxRect(canvas, origin, 2.8, 3.1, 4.0, 0.7, px, SpriteCastPalette.endesga32[11]);
      // Keyboard base
      _pxRect(canvas, origin, 0, 5.5, 10, 3.5, px, SpriteCastPalette.ink);
      _pxRect(canvas, origin, 1, 6.2, 8, 2.2, px, SpriteCastPalette.endesga32[22]);
      // Glowing cyan/pink keycap strip
      _pxRect(canvas, origin, 1.8, 6.7, 3, 0.8, px, SpriteCastPalette.endesga32[18]);
      _pxRect(canvas, origin, 5.2, 6.7, 3, 0.8, px, SpriteCastPalette.endesga32[29]);
    } else if (deskProp == 'trophy_mug') {
      // Golden debate trophy cup + steaming ceramic cocoa mug
      // Trophy (left)
      _pxRect(canvas, origin, 0.5, 1, 5, 5, px, SpriteCastPalette.ink);
      _pxRect(canvas, origin, 1.5, 1.5, 3, 3.2, px, SpriteCastPalette.endesga32[10]);
      _pxRect(canvas, origin, 2, 1.8, 1.2, 2, px, SpriteCastPalette.endesga32[11]);
      _pxRect(canvas, origin, 1, 6, 4, 2.5, px, SpriteCastPalette.ink);
      _pxRect(canvas, origin, 1.8, 6.5, 2.4, 1.5, px, SpriteCastPalette.woodDark);
      // Cocoa mug (right)
      _pxRect(canvas, origin, 6, 4.5, 4, 4, px, SpriteCastPalette.ink);
      _pxRect(canvas, origin, 6.6, 5, 2.8, 3, px, SpriteCastPalette.endesga32[19]);
      _pxRect(canvas, origin, 6.8, 5.2, 2.4, 1, px, SpriteCastPalette.woodDark); // hot cocoa
      _pxRect(canvas, origin, 9.5, 5.5, 1, 2, px, SpriteCastPalette.ink); // handle
      // Animated rising pixel steam wisps
      final steamPhase = (animTick ~/ 10) % 3;
      final steamColor = SpriteCastPalette.endesga32[19].withValues(alpha: 0.72);
      _pxRect(canvas, origin, 7.2, 3.2 - steamPhase * 0.6, 0.9, 0.9, px, steamColor);
      _pxRect(canvas, origin, 8.3, 2.4 - ((steamPhase + 1) % 3) * 0.5, 0.9, 0.9, px, steamColor);
    }
  }

  /// Renders a complete, cohesive SpriteCast 2.5D Personal Classroom Desk
  /// (desk mat, mini light + stepped pixel pool, frame, tabletop prop, and crisp owner plate).
  static void drawPersonalDeskOverlay(
    Canvas canvas, {
    required Rect deskRect,
    required LobbyTableDecorConfig decor,
    required String ownerLabel,
    required bool isLocalOwner,
    double px = 2.0,
    int animTick = 0,
    bool isDarkMode = false,
  }) {
    // 1. Desk mat
    drawPixelDeskMat(canvas, deskRect, deskMat: decor.deskMat, px: px);

    // 2. Mini light + SpriteCast stepped pixel light pool
    drawPixelMiniLight(
      canvas,
      deskRect,
      miniLight: decor.miniLight,
      px: px,
      animTick: animTick,
      isDarkMode: isDarkMode,
    );

    // 3. Desk frame
    drawPixelDeskFrame(
      canvas,
      deskRect,
      deskFrame: decor.deskFrame,
      px: px,
      animTick: animTick,
    );

    // 4. Tabletop prop
    drawPixelDeskProp(
      canvas,
      deskRect,
      deskProp: decor.deskProp,
      px: px,
      animTick: animTick,
    );

    // 5. Crisp pixel nameplate tucked neatly at top edge of the desk
    if (ownerLabel.trim().isNotEmpty) {
      final tp = TextPainter(
        text: TextSpan(
          text: ownerLabel,
          style: TextStyle(
            color: isLocalOwner
                ? SpriteCastPalette.endesga32[11]
                : SpriteCastPalette.endesga32[20],
            fontSize: 8.5,
            fontWeight: FontWeight.w900,
            letterSpacing: 0.2,
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      final badgeRect = RRect.fromRectAndRadius(
        Rect.fromCenter(
          center: Offset(deskRect.center.dx, deskRect.top - 10),
          width: tp.width + 12,
          height: tp.height + 5,
        ),
        const Radius.circular(6),
      );
      canvas.drawRRect(
        badgeRect,
        Paint()..color = SpriteCastPalette.ink.withValues(alpha: 0.88),
      );
      canvas.drawRRect(
        badgeRect,
        Paint()
          ..color = isLocalOwner
              ? SpriteCastPalette.endesga32[10]
              : SpriteCastPalette.endesga32[17].withValues(alpha: 0.75)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.3,
      );
      tp.paint(
        canvas,
        Offset(
          badgeRect.center.dx - tp.width / 2,
          badgeRect.center.dy - tp.height / 2,
        ),
      );
    }
  }

  /// SpriteCast `ground.py` natural meadow ground overlay:
  /// Renders Gaussian-clustered non-repeating grass tufts, clovers, wildflowers,
  /// sunk rainwater puddles (with dark wet rim & dimmed sky reflection), and
  /// scattered gravel pebbles so outdoor maps never look like a rigid tile grid!
  static void drawSpriteCastMeadowDetails(
    Canvas canvas,
    Rect bounds, {
    required int animTick,
    bool isDarkMode = false,
    List<Rect> excludedPaths = const <Rect>[],
  }) {
    // 1. Sunk rainwater puddles (`ground.py`: dark wet rim, dimmed sky reflection, no bright glass-dome lip)
    final puddleCenters = <Offset>[
      Offset(bounds.left + bounds.width * 0.22, bounds.top + bounds.height * 0.34),
      Offset(bounds.left + bounds.width * 0.78, bounds.top + bounds.height * 0.62),
      Offset(bounds.left + bounds.width * 0.36, bounds.top + bounds.height * 0.78),
    ];
    for (var i = 0; i < puddleCenters.length; i++) {
      final c = puddleCenters[i];
      if (excludedPaths.any((r) => r.inflate(22).contains(c))) continue;
      drawSunkRainPuddle(
        canvas,
        c,
        radiusX: 22.0 + (i * 5.0),
        radiusY: 11.0 + (i * 2.5),
        animTick: animTick,
        isDarkMode: isDarkMode,
      );
    }

    // 2. Gaussian-clustered grass tufts & wildflowers (skipping paved paths & puddles)
    final grassDark = isDarkMode
        ? SpriteCastPalette.endesga32[15]
        : SpriteCastPalette.endesga32[14];
    final grassMid = isDarkMode
        ? SpriteCastPalette.endesga32[14]
        : SpriteCastPalette.endesga32[13];
    final grassLight = isDarkMode
        ? SpriteCastPalette.endesga32[13]
        : SpriteCastPalette.endesga32[12];
    final sway = windSwayPx(animTick, 17, px: 1.0);

    const clusterCenters = <Offset>[
      Offset(0.14, 0.24),
      Offset(0.28, 0.56),
      Offset(0.44, 0.26),
      Offset(0.68, 0.24),
      Offset(0.84, 0.44),
      Offset(0.18, 0.80),
      Offset(0.58, 0.78),
      Offset(0.86, 0.82),
    ];

    for (var ci = 0; ci < clusterCenters.length; ci++) {
      final cc = Offset(
        bounds.left + clusterCenters[ci].dx * bounds.width,
        bounds.top + clusterCenters[ci].dy * bounds.height,
      );
      for (var k = 0; k < 14; k++) {
        // Box-Muller-like deterministic Gaussian spread around each meadow clump
        final u1 = (hash01(ci * 31 + k, 11) + hash01(ci * 17 + k, 23)) - 1.0;
        final u2 = (hash01(ci * 19 + k, 37) + hash01(ci * 29 + k, 53)) - 1.0;
        final pt = Offset(cc.dx + u1 * 88.0, cc.dy + u2 * 64.0);
        if (!bounds.deflate(24).contains(pt)) continue;
        if (excludedPaths.any((r) => r.inflate(8).contains(pt))) continue;

        final bladeSway = (k % 3 == 0) ? sway : 0.0;
        // Ground shadow pixel under tuft
        canvas.drawRect(
          Rect.fromLTWH(pt.dx - 3, pt.dy + 2, 8, 2),
          Paint()
            ..color = grassDark.withValues(alpha: 0.45)
            ..isAntiAlias = false,
        );
        // 3-blade pixel grass tuft
        canvas.drawRect(
          Rect.fromLTWH(pt.dx - 2 + bladeSway, pt.dy - 3, 2, 5),
          Paint()..color = grassMid..isAntiAlias = false,
        );
        canvas.drawRect(
          Rect.fromLTWH(pt.dx + bladeSway, pt.dy - 5, 2, 7),
          Paint()..color = grassLight..isAntiAlias = false,
        );
        canvas.drawRect(
          Rect.fromLTWH(pt.dx + 2 + bladeSway, pt.dy - 2, 2, 4),
          Paint()..color = grassMid..isAntiAlias = false,
        );

        // Occasional ENDESGA wildflower blossom (cream, amber, sakura)
        if (k % 5 == 0) {
          final flowerCol = (ci + k) % 3 == 0
              ? SpriteCastPalette.endesga32[11]
              : ((ci + k) % 3 == 1
                  ? SpriteCastPalette.endesga32[29]
                  : SpriteCastPalette.endesga32[2]);
          canvas.drawRect(
            Rect.fromLTWH(pt.dx + bladeSway, pt.dy - 6, 2.5, 2.5),
            Paint()..color = flowerCol..isAntiAlias = false,
          );
        }
      }
    }
  }

  /// SpriteCast sunk rainwater puddle: dark wet earth rim, deep reflective interior,
  /// dimmed sky reflection strip, and zero swelling bright glass lip.
  static void drawSunkRainPuddle(
    Canvas canvas,
    Offset center, {
    required double radiusX,
    required double radiusY,
    required int animTick,
    bool isDarkMode = false,
  }) {
    // 1. Soft wet earth outer rim (sunk into ground)
    canvas.drawOval(
      Rect.fromCenter(center: center, width: radiusX * 2 + 6, height: radiusY * 2 + 4),
      Paint()
        ..color = SpriteCastPalette.endesga32[15].withValues(alpha: 0.42)
        ..isAntiAlias = false,
    );
    // 2. Dark recessed water body
    canvas.drawOval(
      Rect.fromCenter(center: center, width: radiusX * 2, height: radiusY * 2),
      Paint()
        ..color = (isDarkMode
                ? SpriteCastPalette.endesga32[24]
                : SpriteCastPalette.endesga32[16])
            .withValues(alpha: 0.65)
        ..isAntiAlias = false,
    );
    // 3. Dimmed sky reflection strip inside the deeper center
    final shimmerShift = ((animTick ~/ 14) % 2) * 2.0;
    canvas.drawRect(
      Rect.fromCenter(
        center: Offset(center.dx - 3 + shimmerShift, center.dy - 1),
        width: radiusX * 0.85,
        height: 2.0,
      ),
      Paint()
        ..color = SpriteCastPalette.endesga32[17].withValues(alpha: isDarkMode ? 0.25 : 0.42)
        ..isAntiAlias = false,
    );
  }

  /// SpriteCast `"feet in the grass"` foreground strip drawn OVER a walking character's
  /// lower boots when stepping through outdoor grass or Civic Unrest tall grass.
  static void drawFootOcclusionGrassStrip(
    Canvas canvas,
    Offset feetPos, {
    required int animTick,
    Color? primaryColor,
    Color? highlightColor,
    double px = 2.0,
  }) {
    final mid = primaryColor ?? SpriteCastPalette.endesga32[13];
    final hi = highlightColor ?? SpriteCastPalette.endesga32[12];
    final sway = windSwayPx(animTick, feetPos.dx.round(), px: px * 0.4);
    for (var i = -2; i <= 2; i++) {
      final bx = feetPos.dx + i * (2.6 * px) + sway;
      final h = (i.abs() == 1 ? 3.5 : 2.6) * px;
      canvas.drawRect(
        Rect.fromLTWH(bx, feetPos.dy - h + px, px, h),
        Paint()..color = i.isEven ? mid : hi..isAntiAlias = false,
      );
    }
  }

  /// Renders stepped SpriteCast diagonal sunlit window shafts onto indoor school floors.
  static void drawSteppedWindowSunbeam(
    Canvas canvas,
    Offset windowFloorTopLeft, {
    double width = 84,
    double length = 110,
    bool isDarkMode = false,
  }) {
    final beamColor = isDarkMode
        ? SpriteCastPalette.endesga32[17] // cool moonlight
        : SpriteCastPalette.endesga32[11]; // warm daylight
    final baseAlpha = isDarkMode ? 0.05 : 0.09;
    for (var step = 0; step < 3; step++) {
      final frac = 1.0 - step * 0.24;
      final offset = step * 8.0;
      final path = Path()
        ..moveTo(windowFloorTopLeft.dx + offset, windowFloorTopLeft.dy)
        ..lineTo(windowFloorTopLeft.dx + width * frac + offset, windowFloorTopLeft.dy)
        ..lineTo(
          windowFloorTopLeft.dx + width * frac + 26 + offset,
          windowFloorTopLeft.dy + length * frac,
        )
        ..lineTo(
          windowFloorTopLeft.dx + 26 + offset,
          windowFloorTopLeft.dy + length * frac,
        )
        ..close();
      canvas.drawPath(
        path,
        Paint()
          ..color = beamColor.withValues(alpha: baseAlpha)
          ..isAntiAlias = false,
      );
    }
  }
}

/// Interactive zoomed-in SpriteCast 2.5D Personal Desk Studio preview widget
/// used inside the XP Market (`lobby_shop_service.dart`) so students can design
/// their own desk with live lighting, pixel props, and day/night preview!
class SpriteCastDeskStudioPreview extends StatelessWidget {
  final LobbyTableDecorConfig decor;
  final String ownerLabel;
  final bool nightPreview;
  final int animTick;

  const SpriteCastDeskStudioPreview({
    super.key,
    required this.decor,
    required this.ownerLabel,
    this.nightPreview = false,
    this.animTick = 0,
  });

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      size: const Size(188, 128),
      painter: _SpriteCastDeskStudioPainter(
        decor: decor,
        ownerLabel: ownerLabel,
        nightPreview: nightPreview,
        animTick: animTick,
      ),
    );
  }
}

class _SpriteCastDeskStudioPainter extends CustomPainter {
  final LobbyTableDecorConfig decor;
  final String ownerLabel;
  final bool nightPreview;
  final int animTick;

  const _SpriteCastDeskStudioPainter({
    required this.decor,
    required this.ownerLabel,
    required this.nightPreview,
    required this.animTick,
  });

  @override
  void paint(Canvas canvas, Size size) {
    // Cozy pixel classroom floor planks backdrop
    final bgTop = nightPreview
        ? const Color(0xFF13192D)
        : const Color(0xFF2B2436);
    final bgFloor = nightPreview
        ? const Color(0xFF1A2238)
        : const Color(0xFF4A3832);
    final plankLine = nightPreview
        ? const Color(0xFF111626)
        : const Color(0xFF3A2B26);

    canvas.drawRRect(
      RRect.fromRectAndRadius(Offset.zero & size, const Radius.circular(14)),
      Paint()..color = bgFloor,
    );
    canvas.save();
    canvas.clipRRect(
      RRect.fromRectAndRadius(Offset.zero & size, const Radius.circular(14)),
    );
    // Subtle top wall trim
    canvas.drawRect(
      Rect.fromLTWH(0, 0, size.width, 20),
      Paint()..color = bgTop,
    );
    // Horizontal pixel floor planks
    for (var y = 20.0; y < size.height; y += 12.0) {
      canvas.drawRect(
        Rect.fromLTWH(0, y, size.width, 1.5),
        Paint()..color = plankLine,
      );
    }

    if (!nightPreview) {
      SpriteCastEngine.drawSteppedWindowSunbeam(
        canvas,
        const Offset(18, 20),
        width: 48,
        length: 76,
      );
    }

    const px = 2.4;
    final deskRect = Rect.fromCenter(
      center: Offset(size.width * 0.5, size.height * 0.44),
      width: 136,
      height: 54,
    );
    final chairCenter = Offset(size.width * 0.5, size.height * 0.80);

    // 1. Crisp 2.5D wooden desk surface + legs + stepped shadow
    SpriteCastEngine.drawPixelDeskWoodSurface(
      canvas,
      deskRect,
      px: px,
      drawLegsAndShadow: true,
    );

    // 2. Desk mat, mini light + pixel glow, desk frame, tabletop prop, nameplate
    SpriteCastEngine.drawPersonalDeskOverlay(
      canvas,
      deskRect: deskRect,
      decor: decor,
      ownerLabel: ownerLabel,
      isLocalOwner: true,
      px: px,
      animTick: animTick,
      isDarkMode: nightPreview,
    );

    // 3. Chair base + front backrest (SpriteCast `seat.py` layered chair)
    SpriteCastEngine.drawPixelDeskChairBase(
      canvas,
      chairCenter,
      chairStyle: decor.chairStyle,
      px: px,
    );
    SpriteCastEngine.drawPixelDeskChairBackrestFront(
      canvas,
      chairCenter,
      chairStyle: decor.chairStyle,
      px: px,
      animTick: animTick,
    );

    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant _SpriteCastDeskStudioPainter oldDelegate) {
    return oldDelegate.decor.encodeCompact() != decor.encodeCompact() ||
        oldDelegate.nightPreview != nightPreview ||
        oldDelegate.ownerLabel != ownerLabel ||
        oldDelegate.animTick != animTick;
  }
}

/// Crisp pixel-art thumbnail widget for every Desk Studio item card inside the XP Market.
class SpriteCastDeskItemThumbnail extends StatelessWidget {
  final String category;
  final String partId;
  final double size;

  const SpriteCastDeskItemThumbnail({
    super.key,
    required this.category,
    required this.partId,
    this.size = 44,
  });

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      size: Size(size, size),
      painter: _SpriteCastItemThumbPainter(category: category, partId: partId),
    );
  }
}

class _SpriteCastItemThumbPainter extends CustomPainter {
  final String category;
  final String partId;

  const _SpriteCastItemThumbPainter({
    required this.category,
    required this.partId,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final bg = RRect.fromRectAndRadius(
      Offset.zero & size,
      const Radius.circular(10),
    );
    canvas.drawRRect(bg, Paint()..color = const Color(0xFF0B1120));
    canvas.drawRRect(
      bg,
      Paint()
        ..color = Colors.white12
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.0,
    );
    canvas.save();
    canvas.clipRRect(bg);

    final center = Offset(size.width / 2, size.height / 2);
    if (category == 'table_chair') {
      SpriteCastEngine.drawPixelDeskChairBase(
        canvas,
        Offset(center.dx, center.dy + 2),
        chairStyle: partId,
        px: 1.8,
      );
      SpriteCastEngine.drawPixelDeskChairBackrestFront(
        canvas,
        Offset(center.dx, center.dy + 2),
        chairStyle: partId,
        px: 1.8,
      );
    } else if (category == 'table_mat') {
      final miniDesk = Rect.fromCenter(center: center, width: 34, height: 22);
      SpriteCastEngine.drawPixelDeskWoodSurface(
        canvas,
        miniDesk,
        px: 1.2,
        drawLegsAndShadow: false,
      );
      SpriteCastEngine.drawPixelDeskMat(
        canvas,
        miniDesk,
        deskMat: partId,
        px: 1.2,
      );
    } else if (category == 'table_light') {
      if (partId == 'none') {
        _drawNoneSlash(canvas, center);
      } else {
        final miniDesk = Rect.fromCenter(
          center: Offset(center.dx + 4, center.dy + 5),
          width: 34,
          height: 22,
        );
        SpriteCastEngine.drawPixelMiniLight(
          canvas,
          miniDesk,
          miniLight: partId,
          px: 1.8,
          isDarkMode: true,
        );
      }
    } else if (category == 'table_frame') {
      if (partId == 'none') {
        _drawNoneSlash(canvas, center);
      } else {
        final miniDesk = Rect.fromCenter(
          center: Offset(center.dx, center.dy + 6),
          width: 34,
          height: 20,
        );
        SpriteCastEngine.drawPixelDeskFrame(
          canvas,
          miniDesk,
          deskFrame: partId,
          px: 2.2,
        );
      }
    } else if (category == 'table_prop') {
      if (partId == 'none') {
        _drawNoneSlash(canvas, center);
      } else {
        final miniDesk = Rect.fromCenter(
          center: Offset(center.dx - 4, center.dy + 5),
          width: 34,
          height: 20,
        );
        SpriteCastEngine.drawPixelDeskProp(
          canvas,
          miniDesk,
          deskProp: partId,
          px: 2.0,
        );
      }
    }
    canvas.restore();
  }

  void _drawNoneSlash(Canvas canvas, Offset c) {
    final p = Paint()
      ..color = Colors.white30
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.6;
    canvas.drawCircle(c, 9, p);
    canvas.drawLine(Offset(c.dx - 6, c.dy + 6), Offset(c.dx + 6, c.dy - 6), p);
  }

  @override
  bool shouldRepaint(covariant _SpriteCastItemThumbPainter oldDelegate) {
    return oldDelegate.category != category || oldDelegate.partId != partId;
  }
}
