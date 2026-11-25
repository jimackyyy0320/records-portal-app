import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import '../spritecast_engine.dart';
import 'dungeon_models.dart';

/// Multi-layer historical Philippine architectural parallax backdrop & volumetric god-ray painter
/// (`using-unity` `craft-game-floors` `game-shell.md` 2D parallax + `vfx.md` ambient motes).
///
/// Renders distinct, recognizable Filipino architectural heritage for every Era (Acts I–VII):
/// - **Act I (1521)**: Limestone sea-karsts, stilted *Bahay Kubo* watchtowers & *Balangay* prows.
/// - **Act II (Spanish Intramuros)**: *Bahay na Bato* stone arcades, glowing *Capiz* lattice windows & *San Agustin* belltowers.
/// - **Act III (1899 Malolos)**: *Barasoain Church* curved gable pediment, rose window & tricolor stained-glass nave arches.
/// - **Act IV (1935 Commonwealth)**: *Metropolitan Theater* stepped Art-Deco sunburst reliefs, fluted columns & steel river-truss spans.
/// - **Act V (1942–1945 WWII)**: *Corregidor Malinta* concrete tunnel ribs, artillery casemates, ruined arches & sweeping sky searchlights.
/// - **Act VI (Martial Law)**: Brutalist concrete towers, barred clerestory corridors, hanging loudspeakers & crimson watch-beams.
/// - **Act VII (1987 Sovereign Rotunda)**: Marble Corinthian colonnades, fluttering golden-yellow banners & *Three Stars and a Sun* stained-glass dome.
class DungeonArchitecturalBackdropPainter {
  DungeonArchitecturalBackdropPainter._();

  static final Paint _fill = Paint()
    ..style = PaintingStyle.fill
    ..isAntiAlias = false;
  static final Paint _stroke = Paint()
    ..style = PaintingStyle.stroke
    ..isAntiAlias = false;
  static final Paint _rayPaint = Paint()
    ..style = PaintingStyle.fill
    ..blendMode = BlendMode.plus;

  /// Paints the complete 4-layer `320×180` architectural backdrop + volumetric skylight god-rays.
  static void paintBackdrop({
    required Canvas canvas,
    required DungeonEraTheme theme,
    required Offset cameraOffset,
    required double worldTimeSec,
    required int animTick,
    bool enableVolumetricRays = true,
  }) {
    final p = SpriteCastPalette.endesga32;

    // LAYER 0: Smooth pixel-banded atmospheric sky / cavern vault (6 bands + celestial disc)
    for (var b = 0; b < 6; b++) {
      final col = Color.lerp(theme.skyTop, theme.skyBottom, b / 5.0)!;
      _fill.color = col;
      canvas.drawRect(
        Rect.fromLTWH(0.0, b * 30.0, kDungeonRefWidth, 31.0),
        _fill,
      );
    }
    _paintCelestialBody(canvas, theme, cameraOffset, worldTimeSec);

    // LAYER 1 & LAYER 2: Era-Authentic Far Skyline (`0.14x`) & Mid Colonnade (`0.36x`)
    switch (theme.actNumber) {
      case 1:
        _paintAct1PreColonialBarangay(canvas, theme, cameraOffset, animTick, p);
        break;
      case 2:
        _paintAct2IntramurosBahayNaBato(canvas, theme, cameraOffset, worldTimeSec, p);
        break;
      case 3:
        _paintAct3BarasoainMalolos(canvas, theme, cameraOffset, worldTimeSec, p);
        break;
      case 4:
        _paintAct4CommonwealthArtDeco(canvas, theme, cameraOffset, worldTimeSec, p);
        break;
      case 5:
        _paintAct5WartimeCorregidor(canvas, theme, cameraOffset, worldTimeSec, p);
        break;
      case 6:
        _paintAct6ObsidianPrecinct(canvas, theme, cameraOffset, worldTimeSec, p);
        break;
      case 7:
      default:
        _paintAct7SovereignRotunda(canvas, theme, cameraOffset, worldTimeSec, p);
        break;
    }

    // LAYER 3: Volumetric Diagonal Architectural God-Rays & Illuminated Dust Motes (`vfx.md`)
    if (enableVolumetricRays) {
      _paintVolumetricGodRaysAndMotes(canvas, theme, cameraOffset, worldTimeSec);
    }
  }

  static void _paintCelestialBody(
    Canvas canvas,
    DungeonEraTheme theme,
    Offset cam,
    double worldTimeSec,
  ) {
    final p = SpriteCastPalette.endesga32;
    final cx = 248.0 - (cam.dx * 0.03) % 60.0;
    const cy = 34.0;
    final isGoldenDawn = theme.actNumber == 4 || theme.actNumber == 7;
    final bodyCol = isGoldenDawn ? p[11] : (theme.actNumber == 5 ? p[9] : p[20]);

    _rayPaint.shader = ui.Gradient.radial(
      Offset(cx, cy),
      32.0,
      <Color>[
        bodyCol.withValues(alpha: 0.30),
        bodyCol.withValues(alpha: 0.10),
        bodyCol.withValues(alpha: 0.0),
      ],
      const <double>[0.0, 0.55, 1.0],
    );
    canvas.drawCircle(Offset(cx, cy), 32.0, _rayPaint);
    _rayPaint.shader = null;

    _fill.color = bodyCol.withValues(alpha: 0.82);
    canvas.drawCircle(Offset(cx, cy), isGoldenDawn ? 11.0 : 9.0, _fill);
    if (isGoldenDawn) {
      _stroke
        ..color = p[11].withValues(alpha: 0.55)
        ..strokeWidth = 1.4;
      for (var i = 0; i < 8; i++) {
        final a = i * (math.pi / 4.0) + worldTimeSec * 0.08;
        canvas.drawLine(
          Offset(cx + math.cos(a) * 13.0, cy + math.sin(a) * 13.0),
          Offset(cx + math.cos(a) * 19.0, cy + math.sin(a) * 19.0),
          _stroke,
        );
      }
    }
  }

  static void _paintAct1PreColonialBarangay(
    Canvas canvas,
    DungeonEraTheme theme,
    Offset cam,
    int animTick,
    List<Color> p,
  ) {
    final farOff = (cam.dx * 0.14) % 96.0;
    _fill.color = theme.parallaxFar;
    for (var i = -1; i < 5; i++) {
      final bx = i * 96.0 - farOff;
      final h = 68.0 + (i.abs() % 3) * 20.0;
      canvas.drawRect(Rect.fromLTWH(bx + 8, kDungeonRefHeight - h, 44, h), _fill);
      canvas.drawRect(Rect.fromLTWH(bx + 16, kDungeonRefHeight - h - 16, 28, 16), _fill);
      canvas.drawRect(Rect.fromLTWH(bx + 60, kDungeonRefHeight - 28, 26, 6), _fill);
      canvas.drawRect(Rect.fromLTWH(bx + 68, kDungeonRefHeight - 46, 12, 16), _fill);
    }

    final midOff = (cam.dx * 0.34) % 112.0;
    for (var i = -1; i < 4; i++) {
      final hx = i * 112.0 - midOff;
      _fill.color = theme.parallaxMid;
      canvas.drawRect(Rect.fromLTWH(hx + 14, 96, 3, 84), _fill);
      canvas.drawRect(Rect.fromLTWH(hx + 45, 96, 3, 84), _fill);
      canvas.drawRect(Rect.fromLTWH(hx + 12, 114, 38, 3), _fill);
      canvas.drawRect(Rect.fromLTWH(hx + 12, 74, 38, 24), _fill);
      _fill.color = p[10].withValues(alpha: 0.55);
      canvas.drawRect(Rect.fromLTWH(hx + 25, 80, 12, 9), _fill);
      final roof = Path()
        ..moveTo(hx + 4, 76)
        ..lineTo(hx + 31, 48)
        ..lineTo(hx + 58, 76)
        ..close();
      _fill.color = theme.parallaxMid;
      canvas.drawPath(roof, _fill);
      final sway = SpriteCastEngine.windSwayPx(animTick, i * 13, px: 1.0);
      _stroke
        ..color = theme.parallaxMid
        ..strokeWidth = 1.4;
      canvas.drawLine(Offset(hx + 50, 96), Offset(hx + 112, 98 + sway), _stroke);
      for (var sx = 56.0; sx < 108.0; sx += 10.0) {
        canvas.drawRect(Rect.fromLTWH(hx + sx, 97 + sway, 6, 2), _fill);
      }
    }
  }

  static void _paintAct2IntramurosBahayNaBato(
    Canvas canvas,
    DungeonEraTheme theme,
    Offset cam,
    double worldTimeSec,
    List<Color> p,
  ) {
    final farOff = (cam.dx * 0.14) % 120.0;
    _fill.color = theme.parallaxFar;
    for (var i = -1; i < 4; i++) {
      final bx = i * 120.0 - farOff;
      canvas.drawRect(Rect.fromLTWH(bx, 108, 120, 72), _fill);
      for (var m = 0.0; m < 120.0; m += 14.0) {
        canvas.drawRect(Rect.fromLTWH(bx + m, 102, 8, 6), _fill);
      }
      canvas.drawOval(Rect.fromLTWH(bx + 36, 56, 44, 34), _fill);
      canvas.drawRect(Rect.fromLTWH(bx + 22, 48, 16, 60), _fill);
      canvas.drawRect(Rect.fromLTWH(bx + 78, 48, 16, 60), _fill);
      canvas.drawRect(Rect.fromLTWH(bx + 29, 38, 2, 10), _fill);
      canvas.drawRect(Rect.fromLTWH(bx + 85, 38, 2, 10), _fill);
    }

    final midOff = (cam.dx * 0.35) % 104.0;
    final lanternFlicker = 0.78 + 0.22 * math.sin(worldTimeSec * 8.0);
    for (var i = -1; i < 5; i++) {
      final hx = i * 104.0 - midOff;
      _fill.color = theme.parallaxMid;
      final roof = Path()
        ..moveTo(hx + 2, 46)
        ..lineTo(hx + 16, 30)
        ..lineTo(hx + 80, 30)
        ..lineTo(hx + 94, 46)
        ..close();
      canvas.drawPath(roof, _fill);
      canvas.drawRect(Rect.fromLTWH(hx + 6, 46, 84, 42), _fill);
      canvas.drawRect(Rect.fromLTWH(hx + 10, 88, 76, 92), _fill);

      _fill.color = SpriteCastPalette.ink.withValues(alpha: 0.55);
      canvas.drawRect(Rect.fromLTWH(hx + 34, 116, 28, 64), _fill);
      canvas.drawOval(Rect.fromLTWH(hx + 34, 104, 28, 24), _fill);

      for (var w = 0; w < 3; w++) {
        final wx = hx + 15.0 + w * 24.0;
        _fill.color = p[10].withValues(alpha: 0.48 * lanternFlicker);
        canvas.drawRect(Rect.fromLTWH(wx, 54, 16, 20), _fill);
        _fill.color = p[11].withValues(alpha: 0.55 * lanternFlicker);
        canvas.drawRect(Rect.fromLTWH(wx + 2, 56, 5, 7), _fill);
        canvas.drawRect(Rect.fromLTWH(wx + 9, 65, 5, 7), _fill);
        _fill.color = theme.parallaxMid;
        canvas.drawRect(Rect.fromLTWH(wx + 7.5, 54, 1.2, 20), _fill);
        canvas.drawRect(Rect.fromLTWH(wx, 63.5, 16, 1.2), _fill);
      }

      _fill.color = p[11].withValues(alpha: 0.80 * lanternFlicker);
      canvas.drawRect(Rect.fromLTWH(hx + 95, 78, 4, 6), _fill);
    }
  }

  static void _paintAct3BarasoainMalolos(
    Canvas canvas,
    DungeonEraTheme theme,
    Offset cam,
    double worldTimeSec,
    List<Color> p,
  ) {
    final farOff = (cam.dx * 0.15) % 136.0;
    _fill.color = theme.parallaxFar;
    for (var i = -1; i < 4; i++) {
      final bx = i * 136.0 - farOff;
      canvas.drawRect(Rect.fromLTWH(bx + 18, 62, 68, 118), _fill);
      canvas.drawOval(Rect.fromLTWH(bx + 26, 38, 52, 44), _fill);
      _fill.color = p[18].withValues(alpha: 0.38);
      canvas.drawCircle(Offset(bx + 52, 58), 8.5, _fill);
      _fill.color = theme.parallaxFar;
      canvas.drawRect(Rect.fromLTWH(bx, 46, 20, 134), _fill);
      canvas.drawRect(Rect.fromLTWH(bx + 3, 28, 14, 18), _fill);
    }

    final midOff = (cam.dx * 0.36) % 88.0;
    final shimmer = 0.80 + 0.20 * math.sin(worldTimeSec * 3.5);
    for (var i = -1; i < 5; i++) {
      final px = i * 88.0 - midOff;
      _fill.color = theme.parallaxMid;
      canvas.drawRect(Rect.fromLTWH(px, 10, 88, 14), _fill);
      canvas.drawRect(Rect.fromLTWH(px + 8, 24, 16, 156), _fill);

      final glassCol = (i.abs() % 3 == 0)
          ? p[17]
          : ((i.abs() % 3 == 1) ? p[8] : p[10]);
      _fill.color = glassCol.withValues(alpha: 0.34 * shimmer);
      canvas.drawRect(Rect.fromLTWH(px + 38, 42, 24, 58), _fill);
      canvas.drawOval(Rect.fromLTWH(px + 38, 30, 24, 24), _fill);
      _fill.color = p[11].withValues(alpha: 0.52 * shimmer);
      canvas.drawCircle(Offset(px + 50, 56), 5.0, _fill);
    }
  }

  static void _paintAct4CommonwealthArtDeco(
    Canvas canvas,
    DungeonEraTheme theme,
    Offset cam,
    double worldTimeSec,
    List<Color> p,
  ) {
    final farOff = (cam.dx * 0.15) % 128.0;
    for (var i = -1; i < 4; i++) {
      final bx = i * 128.0 - farOff;
      _fill.color = theme.parallaxFar;
      canvas.drawRect(Rect.fromLTWH(bx + 12, 58, 76, 122), _fill);
      canvas.drawRect(Rect.fromLTWH(bx + 24, 40, 52, 18), _fill);
      canvas.drawRect(Rect.fromLTWH(bx + 36, 26, 28, 14), _fill);
      _fill.color = p[10].withValues(alpha: 0.36);
      canvas.drawOval(Rect.fromLTWH(bx + 34, 48, 32, 32), _fill);
      _fill.color = p[18].withValues(alpha: 0.32);
      canvas.drawRect(Rect.fromLTWH(bx + 47, 30, 6, 48), _fill);
    }

    final midOff = (cam.dx * 0.38) % 96.0;
    for (var i = -1; i < 5; i++) {
      final px = i * 96.0 - midOff;
      _fill.color = theme.parallaxMid;
      canvas.drawRect(Rect.fromLTWH(px + 10, 22, 18, 158), _fill);
      canvas.drawRect(Rect.fromLTWH(px + 6, 16, 26, 8), _fill);
      canvas.drawRect(Rect.fromLTWH(px, 28, 96, 6), _fill);
      _stroke
        ..color = theme.parallaxMid
        ..strokeWidth = 2.0;
      canvas.drawLine(Offset(px + 28, 34), Offset(px + 96, 68), _stroke);
      canvas.drawLine(Offset(px + 28, 68), Offset(px + 96, 34), _stroke);
      _fill.color = p[10].withValues(alpha: 0.42);
      canvas.drawRect(Rect.fromLTWH(px + 15, 44, 8, 18), _fill);
    }
  }

  static void _paintAct5WartimeCorregidor(
    Canvas canvas,
    DungeonEraTheme theme,
    Offset cam,
    double worldTimeSec,
    List<Color> p,
  ) {
    for (var s = 0; s < 2; s++) {
      final baseX = 70.0 + s * 165.0;
      final sweep = math.sin(worldTimeSec * (0.7 + s * 0.35) + s * 2.0) * 58.0;
      final beam = Path()
        ..moveTo(baseX - 4, kDungeonRefHeight)
        ..lineTo(baseX + 4, kDungeonRefHeight)
        ..lineTo(baseX + sweep + 26, 0)
        ..lineTo(baseX + sweep - 26, 0)
        ..close();
      _rayPaint.shader = ui.Gradient.linear(
        Offset(baseX, kDungeonRefHeight),
        Offset(baseX + sweep, 0),
        <Color>[
          p[11].withValues(alpha: 0.22),
          p[2].withValues(alpha: 0.10),
          p[2].withValues(alpha: 0.0),
        ],
        const <double>[0.0, 0.55, 1.0],
      );
      canvas.drawPath(beam, _rayPaint);
      _rayPaint.shader = null;
    }

    final farOff = (cam.dx * 0.14) % 110.0;
    _fill.color = theme.parallaxFar;
    for (var i = -1; i < 4; i++) {
      final bx = i * 110.0 - farOff;
      canvas.drawRect(Rect.fromLTWH(bx + 6, 78, 52, 102), _fill);
      canvas.drawRect(Rect.fromLTWH(bx + 6, 62, 18, 16), _fill);
      canvas.drawRect(Rect.fromLTWH(bx + 36, 68, 22, 10), _fill);
    }

    final midOff = (cam.dx * 0.36) % 92.0;
    for (var i = -1; i < 5; i++) {
      final px = i * 92.0 - midOff;
      _fill.color = theme.parallaxMid;
      canvas.drawRect(Rect.fromLTWH(px + 8, 12, 16, 168), _fill);
      canvas.drawRect(Rect.fromLTWH(px, 8, 92, 12), _fill);
      canvas.drawRect(Rect.fromLTWH(px + 24, 20, 14, 10), _fill);
      canvas.drawRect(Rect.fromLTWH(px + 78, 20, 14, 10), _fill);
      _fill.color = p[9].withValues(alpha: 0.72);
      canvas.drawRect(Rect.fromLTWH(px + 52, 20, 4, 5), _fill);
    }
  }

  static void _paintAct6ObsidianPrecinct(
    Canvas canvas,
    DungeonEraTheme theme,
    Offset cam,
    double worldTimeSec,
    List<Color> p,
  ) {
    final farOff = (cam.dx * 0.14) % 116.0;
    for (var i = -1; i < 4; i++) {
      final bx = i * 116.0 - farOff;
      _fill.color = theme.parallaxFar;
      canvas.drawRect(Rect.fromLTWH(bx + 10, 34, 58, 146), _fill);
      canvas.drawRect(Rect.fromLTWH(bx + 80, 48, 22, 14), _fill);
      canvas.drawRect(Rect.fromLTWH(bx + 84, 62, 3, 118), _fill);
      canvas.drawRect(Rect.fromLTWH(bx + 95, 62, 3, 118), _fill);
      final blink = 0.45 + 0.55 * (0.5 + 0.5 * math.sin(worldTimeSec * 5.0 + i));
      _fill.color = p[26].withValues(alpha: 0.75 * blink);
      canvas.drawRect(Rect.fromLTWH(bx + 89, 52, 4, 4), _fill);
    }

    final midOff = (cam.dx * 0.36) % 96.0;
    for (var i = -1; i < 5; i++) {
      final px = i * 96.0 - midOff;
      _fill.color = theme.parallaxMid;
      canvas.drawRect(Rect.fromLTWH(px + 8, 0, 20, 180), _fill);
      canvas.drawRect(Rect.fromLTWH(px + 28, 22, 68, 10), _fill);
      for (var bar = 36.0; bar < 88.0; bar += 10.0) {
        canvas.drawRect(Rect.fromLTWH(px + bar, 6, 2, 16), _fill);
      }
    }
  }

  static void _paintAct7SovereignRotunda(
    Canvas canvas,
    DungeonEraTheme theme,
    Offset cam,
    double worldTimeSec,
    List<Color> p,
  ) {
    final farOff = (cam.dx * 0.12) % 160.0;
    for (var i = -1; i < 3; i++) {
      final bx = i * 160.0 - farOff;
      _fill.color = theme.parallaxFar;
      canvas.drawOval(Rect.fromLTWH(bx + 24, 24, 112, 96), _fill);
      canvas.drawRect(Rect.fromLTWH(bx + 16, 72, 128, 108), _fill);

      final cx = bx + 80.0;
      const cy = 66.0;
      _fill.color = p[16].withValues(alpha: 0.45);
      canvas.drawCircle(Offset(cx, cy), 20.0, _fill);
      _fill.color = p[11].withValues(alpha: 0.72);
      canvas.drawCircle(Offset(cx, cy), 7.5, _fill);
      for (var s = 0; s < 3; s++) {
        final a = worldTimeSec * 0.6 + s * (math.pi * 2 / 3);
        _fill.color = p[11].withValues(alpha: 0.85);
        canvas.drawRect(
          Rect.fromCenter(
            center: Offset(cx + math.cos(a) * 13.5, cy + math.sin(a) * 13.5),
            width: 3.2,
            height: 3.2,
          ),
          _fill,
        );
      }
    }

    final midOff = (cam.dx * 0.36) % 92.0;
    final wave = math.sin(worldTimeSec * 4.5) * 2.0;
    for (var i = -1; i < 5; i++) {
      final px = i * 92.0 - midOff;
      _fill.color = theme.parallaxMid;
      canvas.drawRect(Rect.fromLTWH(px, 8, 92, 10), _fill);
      canvas.drawRect(Rect.fromLTWH(px + 10, 18, 16, 162), _fill);
      canvas.drawRect(Rect.fromLTWH(px + 7, 18, 22, 5), _fill);
      _fill.color = p[10].withValues(alpha: 0.55);
      canvas.drawRect(Rect.fromLTWH(px + 30 + wave * 0.4, 18, 8, 44), _fill);
      _fill.color = p[11].withValues(alpha: 0.65);
      canvas.drawRect(Rect.fromLTWH(px + 32 + wave * 0.7, 22, 4, 34), _fill);
    }
  }

  static void _paintVolumetricGodRaysAndMotes(
    Canvas canvas,
    DungeonEraTheme theme,
    Offset cam,
    double worldTimeSec,
  ) {
    final p = SpriteCastPalette.endesga32;
    final Color rayCol;
    switch (theme.actNumber) {
      case 1:
        rayCol = p[18];
        break;
      case 2:
        rayCol = p[10];
        break;
      case 3:
        rayCol = p[11];
        break;
      case 4:
        rayCol = p[11];
        break;
      case 5:
        rayCol = p[9];
        break;
      case 6:
        rayCol = p[26];
        break;
      case 7:
      default:
        rayCol = p[11];
        break;
    }

    final coreCol = Color.lerp(rayCol, Colors.white, 0.55)!;
    final rayOff = (cam.dx * 0.24) % 128.0;
    final breathe = 0.82 + 0.18 * math.sin(worldTimeSec * 1.8);

    for (var i = 0; i < 4; i++) {
      final topX = i * 128.0 - rayOff - 16.0;
      const topW = 24.0;
      const botSlant = 46.0;
      final path = Path()
        ..moveTo(topX, 0)
        ..lineTo(topX + topW, 0)
        ..lineTo(topX + topW * 1.75 + botSlant, kDungeonRefHeight)
        ..lineTo(topX - topW * 0.25 + botSlant, kDungeonRefHeight)
        ..close();

      _rayPaint.shader = ui.Gradient.linear(
        Offset(topX + topW * 0.5, 0),
        Offset(topX + topW * 0.75 + botSlant, kDungeonRefHeight),
        <Color>[
          coreCol.withValues(alpha: 0.16 * breathe),
          rayCol.withValues(alpha: 0.08 * breathe),
          rayCol.withValues(alpha: 0.0),
        ],
        const <double>[0.0, 0.58, 1.0],
      );
      canvas.drawPath(path, _rayPaint);
    }
    _rayPaint.shader = null;

    for (var m = 0; m < 18; m++) {
      final baseX = SpriteCastEngine.hash01(m * 19 + 3, theme.actNumber) * 340.0;
      final baseY = SpriteCastEngine.hash01(m * 37 + 11, theme.actNumber + 7) * 165.0;
      final sx =
          ((baseX - cam.dx * 0.20 + worldTimeSec * (3.5 + (m % 3))) % 340.0 + 340.0) %
                  340.0 -
              10.0;
      final sy = baseY + math.sin(worldTimeSec * 1.6 + m * 1.3) * 4.5;
      final twinkle = 0.45 + 0.55 * math.sin(worldTimeSec * 3.2 + m * 2.1);
      _rayPaint.color = coreCol.withValues(alpha: 0.34 * twinkle);
      final sz = (m % 3 == 0) ? 2.0 : 1.4;
      canvas.drawRect(Rect.fromLTWH(sx, sy, sz, sz), _rayPaint);
    }
  }
}
