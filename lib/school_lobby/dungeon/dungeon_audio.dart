import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';
import 'package:flutter/services.dart';

import '../lobby_audio_service.dart';
import 'dungeon_combat.dart';
import 'dungeon_physics.dart';

/// All 22 procedural sound-effect cues for the 2D Action-Platformer Dungeon (`craft-game-floors` Game Audio Floor).
enum DungeonSfxCue {
  jump,
  wallJump,
  land,
  silkDash,
  grappleZip,
  pogoBounce,
  slashLight,
  slashFinisher,
  enemyHit,
  shieldClang,
  parryGoldenClang,
  projectileDeflect,
  skillCast,
  silkBindHeal,
  crateShatter,
  crystalMine,
  secretDiscovered,
  gateUnlock,
  lootPickup,
  playerHurt,
  bossTelegraphHorn,
  victoryFanfare,
}

enum _SynthWave { sine, square, triangle, noise }

class _SynthVoiceSegment {
  final double startHz;
  final double endHz;
  final int durationMs;
  final _SynthWave wave;
  final double volume;
  final double harmonicHz;

  const _SynthVoiceSegment({
    required this.startHz,
    required this.endHz,
    required this.durationMs,
    this.wave = _SynthWave.triangle,
    this.volume = 0.36,
    this.harmonicHz = 0.0,
  });
}

/// Multi-waveform procedural 16-bit PCM WAV synthesizer & SFX dispatcher for
/// **Chronicles of the Sovereign: Silk & Charter**.
class DungeonAudioService {
  DungeonAudioService._();
  static final DungeonAudioService instance = DungeonAudioService._();

  static const MethodChannel _deviceBridge =
      MethodChannel('com.recordsportal.app/device_bridge');

  final Map<DungeonSfxCue, Uint8List> _cache = <DungeonSfxCue, Uint8List>{};
  int _playedCount = 0;

  int get playedCount => _playedCount;

  bool get _isRunningInTest {
    try {
      return Platform.environment.containsKey('FLUTTER_TEST');
    } catch (_) {
      return false;
    }
  }

  /// Synthesizes a valid 16-bit Mono PCM RIFF `.wav` buffer for [cue].
  static Uint8List synthesizeCueWav(
    DungeonSfxCue cue, {
    int sampleRate = 22050,
  }) {
    final segments = _recipeForCue(cue);
    var totalSamples = 0;
    for (final s in segments) {
      totalSamples += math.max<int>(1, (sampleRate * s.durationMs / 1000).round());
    }
    final dataSize = totalSamples * 2;
    final fileSize = 36 + dataSize;
    final buf = ByteData(44 + dataSize);

    buf.setUint8(0, 0x52); // R
    buf.setUint8(1, 0x49); // I
    buf.setUint8(2, 0x46); // F
    buf.setUint8(3, 0x46); // F
    buf.setUint32(4, fileSize, Endian.little);
    buf.setUint8(8, 0x57); // W
    buf.setUint8(9, 0x41); // A
    buf.setUint8(10, 0x56); // V
    buf.setUint8(11, 0x45); // E
    buf.setUint8(12, 0x66); // f
    buf.setUint8(13, 0x6D); // m
    buf.setUint8(14, 0x74); // t
    buf.setUint8(15, 0x20); // ' '
    buf.setUint32(16, 16, Endian.little);
    buf.setUint16(20, 1, Endian.little);
    buf.setUint16(22, 1, Endian.little);
    buf.setUint32(24, sampleRate, Endian.little);
    buf.setUint32(28, sampleRate * 2, Endian.little);
    buf.setUint16(32, 2, Endian.little);
    buf.setUint16(34, 16, Endian.little);
    buf.setUint8(36, 0x64); // d
    buf.setUint8(37, 0x61); // a
    buf.setUint8(38, 0x74); // t
    buf.setUint8(39, 0x61); // a
    buf.setUint32(40, dataSize, Endian.little);

    var writeIdx = 0;
    var phase = 0.0;
    var harmPhase = 0.0;
    var lcg = 0x5DEECE66D ^ cue.index;

    for (final seg in segments) {
      final count =
          math.max<int>(1, (sampleRate * seg.durationMs / 1000).round());
      for (var i = 0; i < count; i++) {
        final p = i / count;
        final freq = seg.startHz + (seg.endHz - seg.startHz) * p;
        final env = p < 0.08
            ? (p / 0.08)
            : math.pow(1.0 - ((p - 0.08) / 0.92), 1.65).toDouble();

        phase += (2.0 * math.pi * freq) / sampleRate;
        double sample;
        switch (seg.wave) {
          case _SynthWave.sine:
            sample = math.sin(phase);
            break;
          case _SynthWave.square:
            sample = math.sin(phase) >= 0.0 ? 0.72 : -0.72;
            break;
          case _SynthWave.triangle:
            sample = (2.0 / math.pi) * math.asin(math.sin(phase));
            break;
          case _SynthWave.noise:
            lcg = (lcg * 1103515245 + 12345) & 0x7FFFFFFF;
            final white = (lcg / 0x3FFFFFFF) - 1.0;
            sample = white * 0.62 + math.sin(phase) * 0.38;
            break;
        }

        if (seg.harmonicHz > 0.0) {
          harmPhase += (2.0 * math.pi * seg.harmonicHz) / sampleRate;
          sample = sample * 0.65 + math.sin(harmPhase) * 0.35;
        }

        final pcm = (sample * env * seg.volume * 32767.0)
            .round()
            .clamp(-32768, 32767);
        buf.setInt16(44 + writeIdx * 2, pcm, Endian.little);
        writeIdx++;
      }
    }
    return buf.buffer.asUint8List();
  }

  static List<_SynthVoiceSegment> _recipeForCue(DungeonSfxCue cue) {
    switch (cue) {
      case DungeonSfxCue.jump:
        return const [
          _SynthVoiceSegment(startHz: 240, endHz: 520, durationMs: 75, wave: _SynthWave.triangle, volume: 0.34),
        ];
      case DungeonSfxCue.wallJump:
        return const [
          _SynthVoiceSegment(startHz: 310, endHz: 660, durationMs: 80, wave: _SynthWave.triangle, volume: 0.36),
        ];
      case DungeonSfxCue.land:
        return const [
          _SynthVoiceSegment(startHz: 140, endHz: 68, durationMs: 55, wave: _SynthWave.noise, volume: 0.28),
        ];
      case DungeonSfxCue.silkDash:
        return const [
          _SynthVoiceSegment(startHz: 1240, endHz: 360, durationMs: 110, wave: _SynthWave.noise, volume: 0.36),
        ];
      case DungeonSfxCue.grappleZip:
        return const [
          _SynthVoiceSegment(startHz: 360, endHz: 1120, durationMs: 95, wave: _SynthWave.triangle, volume: 0.38),
        ];
      case DungeonSfxCue.pogoBounce:
        return const [
          _SynthVoiceSegment(startHz: 460, endHz: 940, durationMs: 85, wave: _SynthWave.triangle, harmonicHz: 1380, volume: 0.40),
        ];
      case DungeonSfxCue.slashLight:
        return const [
          _SynthVoiceSegment(startHz: 960, endHz: 290, durationMs: 72, wave: _SynthWave.noise, volume: 0.38),
        ];
      case DungeonSfxCue.slashFinisher:
        return const [
          _SynthVoiceSegment(startHz: 1180, endHz: 260, durationMs: 105, wave: _SynthWave.noise, harmonicHz: 880, volume: 0.45),
        ];
      case DungeonSfxCue.enemyHit:
        return const [
          _SynthVoiceSegment(startHz: 190, endHz: 68, durationMs: 78, wave: _SynthWave.noise, volume: 0.48),
        ];
      case DungeonSfxCue.shieldClang:
        return const [
          _SynthVoiceSegment(startHz: 920, endHz: 780, durationMs: 90, wave: _SynthWave.square, harmonicHz: 1420, volume: 0.34),
        ];
      case DungeonSfxCue.parryGoldenClang:
        return const [
          _SynthVoiceSegment(startHz: 1174, endHz: 1174, durationMs: 130, wave: _SynthWave.triangle, harmonicHz: 1760, volume: 0.50),
          _SynthVoiceSegment(startHz: 1568, endHz: 1568, durationMs: 140, wave: _SynthWave.sine, harmonicHz: 2349, volume: 0.38),
        ];
      case DungeonSfxCue.projectileDeflect:
        return const [
          _SynthVoiceSegment(startHz: 680, endHz: 1320, durationMs: 85, wave: _SynthWave.triangle, harmonicHz: 1046, volume: 0.42),
        ];
      case DungeonSfxCue.skillCast:
        return const [
          _SynthVoiceSegment(startHz: 392, endHz: 587, durationMs: 75, wave: _SynthWave.triangle, volume: 0.42),
          _SynthVoiceSegment(startHz: 587, endHz: 988, durationMs: 110, wave: _SynthWave.square, harmonicHz: 1174, volume: 0.36),
        ];
      case DungeonSfxCue.silkBindHeal:
        return const [
          _SynthVoiceSegment(startHz: 523, endHz: 523, durationMs: 65, wave: _SynthWave.sine, volume: 0.38),
          _SynthVoiceSegment(startHz: 659, endHz: 659, durationMs: 65, wave: _SynthWave.sine, volume: 0.38),
          _SynthVoiceSegment(startHz: 784, endHz: 784, durationMs: 65, wave: _SynthWave.sine, volume: 0.40),
          _SynthVoiceSegment(startHz: 1046, endHz: 1046, durationMs: 120, wave: _SynthWave.sine, harmonicHz: 1568, volume: 0.42),
        ];
      case DungeonSfxCue.crateShatter:
        return const [
          _SynthVoiceSegment(startHz: 260, endHz: 85, durationMs: 95, wave: _SynthWave.noise, volume: 0.40),
        ];
      case DungeonSfxCue.crystalMine:
        return const [
          _SynthVoiceSegment(startHz: 1318, endHz: 1568, durationMs: 70, wave: _SynthWave.triangle, harmonicHz: 2093, volume: 0.36),
        ];
      case DungeonSfxCue.secretDiscovered:
        return const [
          _SynthVoiceSegment(startHz: 587, endHz: 587, durationMs: 70, wave: _SynthWave.triangle, volume: 0.38),
          _SynthVoiceSegment(startHz: 659, endHz: 659, durationMs: 70, wave: _SynthWave.triangle, volume: 0.38),
          _SynthVoiceSegment(startHz: 784, endHz: 784, durationMs: 75, wave: _SynthWave.triangle, volume: 0.40),
          _SynthVoiceSegment(startHz: 1175, endHz: 1175, durationMs: 150, wave: _SynthWave.sine, harmonicHz: 1760, volume: 0.44),
        ];
      case DungeonSfxCue.gateUnlock:
        return const [
          _SynthVoiceSegment(startHz: 220, endHz: 165, durationMs: 90, wave: _SynthWave.square, volume: 0.35),
          _SynthVoiceSegment(startHz: 440, endHz: 660, durationMs: 120, wave: _SynthWave.triangle, volume: 0.38),
        ];
      case DungeonSfxCue.lootPickup:
        return const [
          _SynthVoiceSegment(startHz: 880, endHz: 1318, durationMs: 65, wave: _SynthWave.sine, volume: 0.34),
        ];
      case DungeonSfxCue.playerHurt:
        return const [
          _SynthVoiceSegment(startHz: 240, endHz: 82, durationMs: 130, wave: _SynthWave.square, volume: 0.44),
        ];
      case DungeonSfxCue.bossTelegraphHorn:
        return const [
          _SynthVoiceSegment(startHz: 146.8, endHz: 110.0, durationMs: 190, wave: _SynthWave.square, harmonicHz: 220.0, volume: 0.42),
        ];
      case DungeonSfxCue.victoryFanfare:
        return const [
          _SynthVoiceSegment(startHz: 523.25, endHz: 523.25, durationMs: 85, wave: _SynthWave.triangle, volume: 0.40),
          _SynthVoiceSegment(startHz: 659.25, endHz: 659.25, durationMs: 85, wave: _SynthWave.triangle, volume: 0.40),
          _SynthVoiceSegment(startHz: 783.99, endHz: 783.99, durationMs: 85, wave: _SynthWave.triangle, volume: 0.42),
          _SynthVoiceSegment(startHz: 987.77, endHz: 987.77, durationMs: 95, wave: _SynthWave.triangle, volume: 0.42),
          _SynthVoiceSegment(startHz: 1046.50, endHz: 1046.50, durationMs: 210, wave: _SynthWave.sine, harmonicHz: 1567.98, volume: 0.46),
        ];
    }
  }

  void play(DungeonSfxCue cue) {
    if (LobbyAudioService.instance.isMuted) return;
    _playedCount++;
    if (_isRunningInTest) return;

    final wav = _cache.putIfAbsent(cue, () => synthesizeCueWav(cue));
    _deviceBridge
        .invokeMethod<bool>('playWavBytes', <String, dynamic>{'bytes': wav})
        .catchError((_) => false);
  }

  void handlePhysicsEvents(List<DungeonPhysicsEvent> events) {
    for (final e in events) {
      switch (e.kind) {
        case DungeonPhysicsEventKind.jumped:
        case DungeonPhysicsEventKind.doubleJumped:
          play(DungeonSfxCue.jump);
          break;
        case DungeonPhysicsEventKind.wallJumped:
          play(DungeonSfxCue.wallJump);
          break;
        case DungeonPhysicsEventKind.landed:
          if (e.intensity >= 0.45) play(DungeonSfxCue.land);
          break;
        case DungeonPhysicsEventKind.dashed:
          play(DungeonSfxCue.silkDash);
          break;
        case DungeonPhysicsEventKind.pogoBounced:
          play(DungeonSfxCue.pogoBounce);
          break;
        case DungeonPhysicsEventKind.grappleStarted:
          play(DungeonSfxCue.grappleZip);
          break;
        case DungeonPhysicsEventKind.hazardHit:
          play(DungeonSfxCue.playerHurt);
          break;
        case DungeonPhysicsEventKind.lootCollected:
          play(DungeonSfxCue.lootPickup);
          break;
        case DungeonPhysicsEventKind.grappleReleased:
        case DungeonPhysicsEventKind.crumbleCollapsed:
          break;
      }
    }
  }

  void handleCombatEvents(List<DungeonCombatEvent> events) {
    for (final e in events) {
      switch (e.kind) {
        case DungeonCombatEventKind.slashSwung:
          play(e.value == 2
              ? DungeonSfxCue.slashFinisher
              : DungeonSfxCue.slashLight);
          break;
        case DungeonCombatEventKind.enemyHit:
        case DungeonCombatEventKind.enemyDefeated:
          play(DungeonSfxCue.enemyHit);
          break;
        case DungeonCombatEventKind.enemyBlockedByShield:
          play(DungeonSfxCue.shieldClang);
          break;
        case DungeonCombatEventKind.skillCast:
          play(DungeonSfxCue.skillCast);
          break;
        case DungeonCombatEventKind.parrySuccess:
          play(DungeonSfxCue.parryGoldenClang);
          break;
        case DungeonCombatEventKind.bindCompleted:
          play(DungeonSfxCue.silkBindHeal);
          break;
        case DungeonCombatEventKind.projectileDeflected:
          play(DungeonSfxCue.projectileDeflect);
          break;
        case DungeonCombatEventKind.playerDamaged:
        case DungeonCombatEventKind.bindInterrupted:
          play(DungeonSfxCue.playerHurt);
          break;
        case DungeonCombatEventKind.crateBroken:
          play(DungeonSfxCue.crateShatter);
          break;
        case DungeonCombatEventKind.crystalMined:
          play(DungeonSfxCue.crystalMine);
          break;
        case DungeonCombatEventKind.secretWallBroken:
          play(DungeonSfxCue.secretDiscovered);
          break;
        case DungeonCombatEventKind.gateUnlocked:
          play(DungeonSfxCue.gateUnlock);
          break;
        case DungeonCombatEventKind.pogoLanternStruck:
          play(DungeonSfxCue.pogoBounce);
          break;
        case DungeonCombatEventKind.bindStarted:
          break;
      }
    }
  }
}
