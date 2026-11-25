import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';
import 'package:flutter/services.dart';

import '../lobby_audio_service.dart';
import 'dungeon_combat.dart';
import 'dungeon_physics.dart';

/// All 22 procedural sound-effect cues for the 2D Action-Platformer Dungeon
/// (`craft-game-floors` `game-audio.md`: low-pass filtered ADSR, 5ms cosine de-click, ±6% pitch humanization).
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

/// 5 Multi-Voice Seamless Looping Background Music Tracks across all 7 Historical Acts!
enum DungeonBgmTrack {
  sanctuaryHearth, // Title Screen & Campfire Bench Sanctuaries (peaceful Rondalla arpeggio)
  ancientAndColonial, // Acts I–III: Barangay Grottoes, Intramuros & Barasoain Crypt
  commonwealthAndWartime, // Acts IV–VI: Art-Deco Viaduct, Corregidor Bunkers & Obsidian Precinct
  bossAndSiegeBattle, // Multi-Phase Era Bosses & Rival Mateo Duels (driving heroic tempo!)
  sovereignHymnFinale, // Act VII Ascension & 1987 Sovereign Altar Victory
}

enum _SynthWave { sine, softPulse, triangle, warmNoise }

class _SynthVoiceSegment {
  final double startHz;
  final double endHz;
  final int durationMs;
  final _SynthWave wave;
  final double volume;
  final double harmonicHz;
  final double lowPassAlpha; // 0.12 (deep warm) .. 0.85 (bright)

  const _SynthVoiceSegment({
    required this.startHz,
    required this.endHz,
    required this.durationMs,
    this.wave = _SynthWave.triangle,
    this.volume = 0.36,
    this.harmonicHz = 0.0,
    this.lowPassAlpha = 0.45,
  });
}

/// Multi-voice Looping Background Music & Smooth Low-Pass Filtered ADSR SFX Engine
/// for **Chronicles of the Sovereign** (`using-unity` `craft-game-floors` `game-audio.md`).
class DungeonAudioService {
  DungeonAudioService._();
  static final DungeonAudioService instance = DungeonAudioService._();

  static const MethodChannel _deviceBridge =
      MethodChannel('com.recordsportal.app/device_bridge');

  static const List<double> _kPitchVariants = <double>[0.94, 1.00, 1.06];

  final Map<String, Uint8List> _sfxVariantCache = <String, Uint8List>{};
  final Map<DungeonBgmTrack, Uint8List> _bgmLoopCache =
      <DungeonBgmTrack, Uint8List>{};

  int _playedCount = 0;
  int _variantCursor = 0;
  double _musicVolume = 0.72;
  double _sfxVolume = 0.85;
  bool _isBgmDucked = false;
  DungeonBgmTrack? _activeBgmTrack;

  int get playedCount => _playedCount;
  DungeonBgmTrack? get activeBgmTrack => _activeBgmTrack;
  bool get isBgmDucked => _isBgmDucked;
  double get musicVolume => _musicVolume;
  double get sfxVolume => _sfxVolume;

  /// Effective BGM output gain (`-6 dB` = `0.5x` ducking when paused or inside menus/modals!).
  double get effectiveBgmVolume => LobbyAudioService.instance.isMuted
      ? 0.0
      : (_musicVolume * (_isBgmDucked ? 0.50 : 1.0)).clamp(0.0, 1.0);

  double get effectiveSfxVolume => LobbyAudioService.instance.isMuted
      ? 0.0
      : _sfxVolume.clamp(0.0, 1.0);

  bool get _isRunningInTest {
    try {
      return Platform.environment.containsKey('FLUTTER_TEST');
    } catch (_) {
      return false;
    }
  }

  /// Writes standard 44-byte 16-bit Mono PCM RIFF/WAVE header.
  static void _writeWavHeader(ByteData buf, int sampleRate, int dataSize) {
    final fileSize = 36 + dataSize;
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
  }

  /// Synthesizes a smooth, low-pass filtered 16-bit Mono PCM RIFF `.wav` buffer for [cue]
  /// with 5ms cosine fade-in/out de-click guards and optional `pitchMultiplier` humanization!
  static Uint8List synthesizeCueWav(
    DungeonSfxCue cue, {
    int sampleRate = 22050,
    double pitchMultiplier = 1.0,
  }) {
    final segments = _recipeForCue(cue);
    var totalSamples = 0;
    for (final s in segments) {
      totalSamples +=
          math.max<int>(1, (sampleRate * s.durationMs / 1000).round());
    }
    final dataSize = totalSamples * 2;
    final buf = ByteData(44 + dataSize);
    _writeWavHeader(buf, sampleRate, dataSize);

    final declickSamples = math.max(1, (sampleRate * 0.005).round());
    var writeIdx = 0;
    var phase = 0.0;
    var harmPhase = 0.0;
    var lpState = 0.0;
    var lcg = 0x5DEECE66D ^ cue.index;

    for (final seg in segments) {
      final count =
          math.max<int>(1, (sampleRate * seg.durationMs / 1000).round());
      for (var i = 0; i < count; i++) {
        final p = i / count;
        final freq =
            (seg.startHz + (seg.endHz - seg.startHz) * p) * pitchMultiplier;

        // Smooth cosine attack + organic exponential decay (zero harsh discontinuities!)
        var env = p < 0.09
            ? 0.5 * (1.0 - math.cos(math.pi * (p / 0.09)))
            : math.pow(1.0 - ((p - 0.09) / 0.91), 1.55).toDouble();

        phase += (2.0 * math.pi * freq) / sampleRate;
        double sample;
        switch (seg.wave) {
          case _SynthWave.sine:
            sample = math.sin(phase);
            break;
          case _SynthWave.softPulse:
            // Band-limited warm pulse (fundamental + 3rd harmonic instead of harsh digital square!)
            sample = math.sin(phase) * 0.76 + math.sin(phase * 3.0) * 0.24;
            break;
          case _SynthWave.triangle:
            sample = (2.0 / math.pi) * math.asin(math.sin(phase));
            break;
          case _SynthWave.warmNoise:
            lcg = (lcg * 1103515245 + 12345) & 0x7FFFFFFF;
            final white = (lcg / 0x3FFFFFFF) - 1.0;
            sample = white * 0.48 + math.sin(phase) * 0.52;
            break;
        }

        if (seg.harmonicHz > 0.0) {
          harmPhase +=
              (2.0 * math.pi * seg.harmonicHz * pitchMultiplier) / sampleRate;
          sample = sample * 0.68 + math.sin(harmPhase) * 0.32;
        }

        // One-pole low-pass warmth filter!
        lpState += seg.lowPassAlpha * (sample - lpState);

        // Global 5ms cosine fade-in / fade-out across the entire buffer so start & end are 0!
        var globalDeclick = 1.0;
        if (writeIdx < declickSamples) {
          globalDeclick =
              0.5 * (1.0 - math.cos(math.pi * (writeIdx / declickSamples)));
        } else if (totalSamples - 1 - writeIdx < declickSamples) {
          final rem = totalSamples - 1 - writeIdx;
          globalDeclick =
              0.5 * (1.0 - math.cos(math.pi * (rem / declickSamples)));
        }

        final pcm = (lpState * env * globalDeclick * seg.volume * 32767.0)
            .round()
            .clamp(-32768, 32767);
        buf.setInt16(44 + writeIdx * 2, pcm, Endian.little);
        writeIdx++;
      }
    }
    return buf.buffer.asUint8List();
  }

  /// Synthesizes a multi-voice, seamless zero-crossing loopable 16-bit Mono PCM `.wav`
  /// background music track (Rondalla/Kulintang lead + warm bass + atmospheric pad + soft pulse).
  static Uint8List synthesizeBgmLoopWav(
    DungeonBgmTrack track, {
    int sampleRate = 16000,
  }) {
    final spec = _bgmCompositionFor(track);
    final stepSamples = (sampleRate * spec.stepDurationSec).round();
    final totalSteps = spec.leadHz.length;
    final totalSamples = math.max(256, stepSamples * totalSteps);
    final dataSize = totalSamples * 2;
    final buf = ByteData(44 + dataSize);
    _writeWavHeader(buf, sampleRate, dataSize);

    final loopFadeSamples = math.min(totalSamples ~/ 8, (sampleRate * 0.025).round());
    var lpState = 0.0;

    for (var s = 0; s < totalSamples; s++) {
      final stepIdx = (s ~/ stepSamples) % totalSteps;
      final inStep = (s % stepSamples) / stepSamples;
      final t = s / sampleRate;

      final leadF = spec.leadHz[stepIdx];
      final bassF = spec.bassHz[stepIdx % spec.bassHz.length];
      final padF = spec.padHz[stepIdx % spec.padHz.length];

      // Voice 1: Plucked Rondalla / Kulintang melody with warm exponential decay
      double leadSample = 0.0;
      if (leadF > 0.0) {
        final pluckEnv = inStep < 0.06
            ? (inStep / 0.06)
            : math.exp(-3.4 * (inStep - 0.06));
        final w1 = math.sin(2.0 * math.pi * leadF * t);
        final w2 = math.sin(4.0 * math.pi * leadF * t) * 0.28;
        leadSample = (w1 + w2) * pluckEnv * 0.26;
      }

      // Voice 2: Deep warm bassline
      double bassSample = 0.0;
      if (bassF > 0.0) {
        final bassEnv = 0.35 + 0.65 * math.sin(math.pi * (1.0 - inStep * 0.65));
        bassSample = (2.0 / math.pi) *
            math.asin(math.sin(2.0 * math.pi * bassF * t)) *
            bassEnv *
            0.24;
      }

      // Voice 3: Breathing harmonic pad chord (root + fifth)
      final padSwell = 0.65 + 0.35 * math.sin(2.0 * math.pi * (s / totalSamples));
      final padSample = (math.sin(2.0 * math.pi * padF * t) * 0.6 +
              math.sin(2.0 * math.pi * padF * 1.498 * t) * 0.4) *
          padSwell *
          0.15;

      // Voice 4: Soft percussive heartbeat kick on battle/wartime tracks
      double drumSample = 0.0;
      if (spec.percussive && (stepIdx % 2 == 0) && inStep < 0.22) {
        final kp = inStep / 0.22;
        final kickHz = 115.0 - 65.0 * kp;
        drumSample = math.sin(2.0 * math.pi * kickHz * t) * (1.0 - kp) * 0.20;
      }

      final mixed = leadSample + bassSample + padSample + drumSample;
      lpState += spec.lowPassAlpha * (mixed - lpState);

      // Seamless loop boundary cosine taper so sample N-1 -> 0 never clicks!
      var seamGain = 1.0;
      if (s < loopFadeSamples) {
        seamGain = 0.5 * (1.0 - math.cos(math.pi * (s / loopFadeSamples)));
      } else if (totalSamples - 1 - s < loopFadeSamples) {
        final rem = totalSamples - 1 - s;
        seamGain = 0.5 * (1.0 - math.cos(math.pi * (rem / loopFadeSamples)));
      }

      final pcm = (lpState * seamGain * 32767.0).round().clamp(-32768, 32767);
      buf.setInt16(44 + s * 2, pcm, Endian.little);
    }

    return buf.buffer.asUint8List();
  }

  static ({
    double stepDurationSec,
    double lowPassAlpha,
    bool percussive,
    List<double> leadHz,
    List<double> bassHz,
    List<double> padHz,
  }) _bgmCompositionFor(DungeonBgmTrack track) {
    switch (track) {
      case DungeonBgmTrack.sanctuaryHearth:
        // Warm F-major Kundiman / Sanctuary hearth arpeggio
        return (
          stepDurationSec: 0.34,
          lowPassAlpha: 0.34,
          percussive: false,
          leadHz: const <double>[
            349.23, 440.00, 523.25, 659.25, 587.33, 523.25, 440.00, 0.0,
            293.66, 349.23, 440.00, 523.25, 440.00, 392.00, 349.23, 0.0,
          ],
          bassHz: const <double>[174.61, 174.61, 146.83, 130.81],
          padHz: const <double>[261.63, 220.00, 196.00, 174.61],
        );

      case DungeonBgmTrack.ancientAndColonial:
        // Atmospheric D-minor / Kulintang cavern & Intramuros motif
        return (
          stepDurationSec: 0.28,
          lowPassAlpha: 0.38,
          percussive: false,
          leadHz: const <double>[
            293.66, 349.23, 440.00, 0.0, 466.16, 440.00, 349.23, 329.63,
            293.66, 0.0, 261.63, 293.66, 349.23, 329.63, 293.66, 0.0,
          ],
          bassHz: const <double>[146.83, 146.83, 116.54, 130.81],
          padHz: const <double>[220.00, 220.00, 174.61, 196.00],
        );

      case DungeonBgmTrack.commonwealthAndWartime:
        // Tense E-minor rhythmic pulse for Sky-Bridges, Corregidor & Precinct
        return (
          stepDurationSec: 0.24,
          lowPassAlpha: 0.42,
          percussive: true,
          leadHz: const <double>[
            329.63, 0.0, 392.00, 493.88, 440.00, 392.00, 369.99, 0.0,
            329.63, 392.00, 493.88, 587.33, 493.88, 440.00, 392.00, 0.0,
          ],
          bassHz: const <double>[164.81, 164.81, 130.81, 146.83],
          padHz: const <double>[246.94, 196.00, 220.00, 246.94],
        );

      case DungeonBgmTrack.bossAndSiegeBattle:
        // Driving A-minor heroic Boss & Siege ostinato!
        return (
          stepDurationSec: 0.19,
          lowPassAlpha: 0.50,
          percussive: true,
          leadHz: const <double>[
            440.00, 523.25, 659.25, 440.00, 587.33, 523.25, 493.88, 523.25,
            659.25, 783.99, 698.46, 659.25, 587.33, 523.25, 493.88, 440.00,
          ],
          bassHz: const <double>[110.00, 110.00, 130.81, 146.83, 110.00, 98.00, 87.31, 98.00],
          padHz: const <double>[220.00, 261.63, 293.66, 246.94],
        );

      case DungeonBgmTrack.sovereignHymnFinale:
        // Radiant C-major / G-major 1987 Constitutional Sovereignty Anthem!
        return (
          stepDurationSec: 0.28,
          lowPassAlpha: 0.44,
          percussive: true,
          leadHz: const <double>[
            523.25, 659.25, 783.99, 1046.50, 987.77, 783.99, 880.00, 783.99,
            698.46, 659.25, 587.33, 659.25, 783.99, 659.25, 523.25, 0.0,
          ],
          bassHz: const <double>[130.81, 196.00, 174.61, 196.00],
          padHz: const <double>[261.63, 329.63, 349.23, 392.00],
        );
    }
  }

  /// Selects the appropriate [DungeonBgmTrack] for the current chamber & combat state.
  static DungeonBgmTrack selectTrackForContext({
    required int actNumber,
    required bool isTitleOrSanctuary,
    required bool isBossOrRivalActive,
    required bool isFinaleVictory,
  }) {
    if (isFinaleVictory || actNumber >= 7 && !isBossOrRivalActive && !isTitleOrSanctuary) {
      return DungeonBgmTrack.sovereignHymnFinale;
    }
    if (isBossOrRivalActive) {
      return DungeonBgmTrack.bossAndSiegeBattle;
    }
    if (isTitleOrSanctuary) {
      return DungeonBgmTrack.sanctuaryHearth;
    }
    if (actNumber <= 3) {
      return DungeonBgmTrack.ancientAndColonial;
    }
    return DungeonBgmTrack.commonwealthAndWartime;
  }

  /// Updates user Music & SFX volume sliders and immediately pushes live BGM gain to native/web audio!
  void applyVolumes({
    required double musicVolume,
    required double sfxVolume,
  }) {
    _musicVolume = musicVolume.clamp(0.0, 1.0);
    _sfxVolume = sfxVolume.clamp(0.0, 1.0);
    _pushBgmVolumeToPlatform();
  }

  /// Applies `-6 dB` (`0.5x`) volume ducking when paused or browsing Bench/Map/Settings/NPC modals.
  void setBgmDucked(bool ducked) {
    if (_isBgmDucked == ducked) return;
    _isBgmDucked = ducked;
    _pushBgmVolumeToPlatform();
  }

  /// Synchronizes the looping background soundtrack with the active Dungeon Act / Boss state.
  void syncDungeonBgm({
    required int actNumber,
    required bool isTitleOrSanctuary,
    required bool isBossOrRivalActive,
    bool isFinaleVictory = false,
  }) {
    final desired = selectTrackForContext(
      actNumber: actNumber,
      isTitleOrSanctuary: isTitleOrSanctuary,
      isBossOrRivalActive: isBossOrRivalActive,
      isFinaleVictory: isFinaleVictory,
    );
    if (_activeBgmTrack == desired) {
      _pushBgmVolumeToPlatform();
      return;
    }
    _activeBgmTrack = desired;
    if (_isRunningInTest) return;

    final vol = effectiveBgmVolume;
    final wav = _bgmLoopCache.putIfAbsent(
      desired,
      () => synthesizeBgmLoopWav(desired),
    );
    _deviceBridge
        .invokeMethod<bool>('startLoopingBgmWav', <String, dynamic>{
          'bytes': wav,
          'volume': vol,
        })
        .catchError((_) => false);

    final webCtrl = LobbyAudioService.instance.audioWebViewController;
    if (webCtrl != null) {
      final b64 = base64Encode(wav);
      webCtrl
          .runJavaScript(
            'window.startLoopBgmBase64 && window.startLoopBgmBase64("$b64", $vol);',
          )
          .catchError((_) {});
    }
  }

  void _pushBgmVolumeToPlatform() {
    if (_activeBgmTrack == null || _isRunningInTest) return;
    final vol = effectiveBgmVolume;
    _deviceBridge
        .invokeMethod<bool>('setBgmVolume', <String, dynamic>{'volume': vol})
        .catchError((_) => false);
    final webCtrl = LobbyAudioService.instance.audioWebViewController;
    if (webCtrl != null) {
      webCtrl
          .runJavaScript('window.setLoopBgmVolume && window.setLoopBgmVolume($vol);')
          .catchError((_) {});
    }
  }

  /// Stops looping dungeon BGM cleanly when returning to the School Lobby.
  void stopBgm() {
    _activeBgmTrack = null;
    _isBgmDucked = false;
    if (_isRunningInTest) return;
    _deviceBridge.invokeMethod<bool>('stopLoopingBgm').catchError((_) => false);
    final webCtrl = LobbyAudioService.instance.audioWebViewController;
    if (webCtrl != null) {
      webCtrl
          .runJavaScript('window.stopLoopBgm && window.stopLoopBgm();')
          .catchError((_) {});
    }
  }

  static List<_SynthVoiceSegment> _recipeForCue(DungeonSfxCue cue) {
    switch (cue) {
      case DungeonSfxCue.jump:
        return const [
          _SynthVoiceSegment(
            startHz: 240,
            endHz: 510,
            durationMs: 78,
            wave: _SynthWave.triangle,
            volume: 0.34,
            lowPassAlpha: 0.42,
          ),
        ];
      case DungeonSfxCue.wallJump:
        return const [
          _SynthVoiceSegment(
            startHz: 310,
            endHz: 650,
            durationMs: 82,
            wave: _SynthWave.triangle,
            volume: 0.36,
            lowPassAlpha: 0.44,
          ),
        ];
      case DungeonSfxCue.land:
        return const [
          _SynthVoiceSegment(
            startHz: 135,
            endHz: 64,
            durationMs: 58,
            wave: _SynthWave.warmNoise,
            volume: 0.26,
            lowPassAlpha: 0.24,
          ),
        ];
      case DungeonSfxCue.silkDash:
        return const [
          _SynthVoiceSegment(
            startHz: 980,
            endHz: 340,
            durationMs: 112,
            wave: _SynthWave.warmNoise,
            harmonicHz: 660,
            volume: 0.34,
            lowPassAlpha: 0.36,
          ),
        ];
      case DungeonSfxCue.grappleZip:
        return const [
          _SynthVoiceSegment(
            startHz: 360,
            endHz: 1080,
            durationMs: 95,
            wave: _SynthWave.triangle,
            volume: 0.36,
            lowPassAlpha: 0.48,
          ),
        ];
      case DungeonSfxCue.pogoBounce:
        return const [
          _SynthVoiceSegment(
            startHz: 460,
            endHz: 920,
            durationMs: 88,
            wave: _SynthWave.triangle,
            harmonicHz: 1380,
            volume: 0.38,
            lowPassAlpha: 0.50,
          ),
        ];
      case DungeonSfxCue.slashLight:
        return const [
          _SynthVoiceSegment(
            startHz: 840,
            endHz: 260,
            durationMs: 76,
            wave: _SynthWave.warmNoise,
            harmonicHz: 520,
            volume: 0.35,
            lowPassAlpha: 0.38,
          ),
        ];
      case DungeonSfxCue.slashFinisher:
        return const [
          _SynthVoiceSegment(
            startHz: 960,
            endHz: 210,
            durationMs: 118,
            wave: _SynthWave.warmNoise,
            harmonicHz: 740,
            volume: 0.44,
            lowPassAlpha: 0.42,
          ),
        ];
      case DungeonSfxCue.enemyHit:
        return const [
          _SynthVoiceSegment(
            startHz: 210,
            endHz: 72,
            durationMs: 82,
            wave: _SynthWave.warmNoise,
            harmonicHz: 145,
            volume: 0.44,
            lowPassAlpha: 0.32,
          ),
        ];
      case DungeonSfxCue.shieldClang:
        return const [
          _SynthVoiceSegment(
            startHz: 880,
            endHz: 740,
            durationMs: 92,
            wave: _SynthWave.softPulse,
            harmonicHz: 1320,
            volume: 0.34,
            lowPassAlpha: 0.52,
          ),
        ];
      case DungeonSfxCue.parryGoldenClang:
        return const [
          _SynthVoiceSegment(
            startHz: 1174,
            endHz: 1174,
            durationMs: 130,
            wave: _SynthWave.triangle,
            harmonicHz: 1760,
            volume: 0.46,
            lowPassAlpha: 0.60,
          ),
          _SynthVoiceSegment(
            startHz: 1568,
            endHz: 1568,
            durationMs: 145,
            wave: _SynthWave.sine,
            harmonicHz: 2349,
            volume: 0.36,
            lowPassAlpha: 0.62,
          ),
        ];
      case DungeonSfxCue.projectileDeflect:
        return const [
          _SynthVoiceSegment(
            startHz: 680,
            endHz: 1320,
            durationMs: 86,
            wave: _SynthWave.triangle,
            harmonicHz: 1046,
            volume: 0.38,
            lowPassAlpha: 0.52,
          ),
        ];
      case DungeonSfxCue.skillCast:
        return const [
          _SynthVoiceSegment(
            startHz: 392,
            endHz: 587,
            durationMs: 78,
            wave: _SynthWave.triangle,
            volume: 0.38,
            lowPassAlpha: 0.46,
          ),
          _SynthVoiceSegment(
            startHz: 587,
            endHz: 988,
            durationMs: 115,
            wave: _SynthWave.softPulse,
            harmonicHz: 1174,
            volume: 0.34,
            lowPassAlpha: 0.48,
          ),
        ];
      case DungeonSfxCue.silkBindHeal:
        return const [
          _SynthVoiceSegment(startHz: 523, endHz: 523, durationMs: 68, wave: _SynthWave.sine, volume: 0.36, lowPassAlpha: 0.55),
          _SynthVoiceSegment(startHz: 659, endHz: 659, durationMs: 68, wave: _SynthWave.sine, volume: 0.36, lowPassAlpha: 0.55),
          _SynthVoiceSegment(startHz: 784, endHz: 784, durationMs: 68, wave: _SynthWave.sine, volume: 0.38, lowPassAlpha: 0.58),
          _SynthVoiceSegment(startHz: 1046, endHz: 1046, durationMs: 130, wave: _SynthWave.sine, harmonicHz: 1568, volume: 0.40, lowPassAlpha: 0.62),
        ];
      case DungeonSfxCue.crateShatter:
        return const [
          _SynthVoiceSegment(
            startHz: 250,
            endHz: 82,
            durationMs: 96,
            wave: _SynthWave.warmNoise,
            volume: 0.38,
            lowPassAlpha: 0.28,
          ),
        ];
      case DungeonSfxCue.crystalMine:
        return const [
          _SynthVoiceSegment(
            startHz: 1318,
            endHz: 1568,
            durationMs: 75,
            wave: _SynthWave.triangle,
            harmonicHz: 2093,
            volume: 0.34,
            lowPassAlpha: 0.58,
          ),
        ];
      case DungeonSfxCue.secretDiscovered:
        return const [
          _SynthVoiceSegment(startHz: 587, endHz: 587, durationMs: 72, wave: _SynthWave.triangle, volume: 0.36, lowPassAlpha: 0.52),
          _SynthVoiceSegment(startHz: 659, endHz: 659, durationMs: 72, wave: _SynthWave.triangle, volume: 0.36, lowPassAlpha: 0.52),
          _SynthVoiceSegment(startHz: 784, endHz: 784, durationMs: 78, wave: _SynthWave.triangle, volume: 0.38, lowPassAlpha: 0.54),
          _SynthVoiceSegment(startHz: 1175, endHz: 1175, durationMs: 155, wave: _SynthWave.sine, harmonicHz: 1760, volume: 0.42, lowPassAlpha: 0.60),
        ];
      case DungeonSfxCue.gateUnlock:
        return const [
          _SynthVoiceSegment(startHz: 220, endHz: 165, durationMs: 92, wave: _SynthWave.softPulse, volume: 0.33, lowPassAlpha: 0.36),
          _SynthVoiceSegment(startHz: 440, endHz: 660, durationMs: 125, wave: _SynthWave.triangle, volume: 0.36, lowPassAlpha: 0.48),
        ];
      case DungeonSfxCue.lootPickup:
        return const [
          _SynthVoiceSegment(
            startHz: 880,
            endHz: 1318,
            durationMs: 68,
            wave: _SynthWave.sine,
            volume: 0.32,
            lowPassAlpha: 0.58,
          ),
        ];
      case DungeonSfxCue.playerHurt:
        return const [
          _SynthVoiceSegment(
            startHz: 230,
            endHz: 80,
            durationMs: 132,
            wave: _SynthWave.softPulse,
            volume: 0.40,
            lowPassAlpha: 0.32,
          ),
        ];
      case DungeonSfxCue.bossTelegraphHorn:
        return const [
          _SynthVoiceSegment(
            startHz: 146.8,
            endHz: 110.0,
            durationMs: 195,
            wave: _SynthWave.softPulse,
            harmonicHz: 220.0,
            volume: 0.40,
            lowPassAlpha: 0.34,
          ),
        ];
      case DungeonSfxCue.victoryFanfare:
        return const [
          _SynthVoiceSegment(startHz: 523.25, endHz: 523.25, durationMs: 85, wave: _SynthWave.triangle, volume: 0.38, lowPassAlpha: 0.52),
          _SynthVoiceSegment(startHz: 659.25, endHz: 659.25, durationMs: 85, wave: _SynthWave.triangle, volume: 0.38, lowPassAlpha: 0.52),
          _SynthVoiceSegment(startHz: 783.99, endHz: 783.99, durationMs: 85, wave: _SynthWave.triangle, volume: 0.40, lowPassAlpha: 0.54),
          _SynthVoiceSegment(startHz: 987.77, endHz: 987.77, durationMs: 95, wave: _SynthWave.triangle, volume: 0.40, lowPassAlpha: 0.56),
          _SynthVoiceSegment(startHz: 1046.50, endHz: 1046.50, durationMs: 215, wave: _SynthWave.sine, harmonicHz: 1567.98, volume: 0.44, lowPassAlpha: 0.62),
        ];
    }
  }

  /// Plays [cue] using 3 cached `±6%` pitch-humanized variants and the user's [sfxVolume].
  void play(DungeonSfxCue cue) {
    final vol = effectiveSfxVolume;
    if (vol <= 0.005) return;
    _playedCount++;
    if (_isRunningInTest) return;

    // Musical fanfares & chimes stay exact-pitch; action/combat cues humanize ±6%!
    final useFixedPitch = cue == DungeonSfxCue.victoryFanfare ||
        cue == DungeonSfxCue.secretDiscovered ||
        cue == DungeonSfxCue.silkBindHeal ||
        cue == DungeonSfxCue.parryGoldenClang;
    final variantIdx = useFixedPitch ? 1 : (_variantCursor++ % _kPitchVariants.length);
    final pitch = _kPitchVariants[variantIdx];
    final cacheKey = '${cue.name}_$variantIdx';
    final wav = _sfxVariantCache.putIfAbsent(
      cacheKey,
      () => synthesizeCueWav(cue, pitchMultiplier: pitch),
    );
    _deviceBridge
        .invokeMethod<bool>('playWavBytes', <String, dynamic>{
          'bytes': wav,
          'volume': vol,
        })
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
