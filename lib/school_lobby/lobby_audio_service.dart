import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:webview_flutter/webview_flutter.dart';

/// Retro 2D RPG Sound Effects Synthesizer & Audio Engine for the MIS-SHS School Lobby.
///
/// Generates authentic 16-bit PCM RIFF `.wav` audio waveforms in memory and plays
/// polyphonic WebAudio / WAV cues alongside tactile system feedback without requiring
/// external native audio plugins.
class LobbyAudioService extends ChangeNotifier {
  LobbyAudioService._();
  static final LobbyAudioService instance = LobbyAudioService._();

  static const String _kPrefsMuteKey = 'lobby_sfx_muted_v1';

  bool _isMuted = false;
  bool _initialized = false;
  int _lastFootstepMs = 0;
  int _playedSfxCount = 0;

  WebViewController? _audioWebViewController;
  bool _webViewReady = false;

  bool get isMuted => _isMuted;
  int get playedSfxCount => _playedSfxCount;

  /// Exposes the underlying headless WebViewController if needed by the host widget tree.
  WebViewController? get audioWebViewController => _audioWebViewController;

  bool get _isRunningInTest {
    try {
      return Platform.environment.containsKey('FLUTTER_TEST');
    } catch (_) {
      return false;
    }
  }

  Future<void> initialize() async {
    if (_initialized) return;
    _initialized = true;
    try {
      final prefs = await SharedPreferences.getInstance();
      _isMuted = prefs.getBool(_kPrefsMuteKey) ?? false;
    } catch (_) {}

    if (!_isRunningInTest) {
      _initHeadlessAudioWebView();
    }
    notifyListeners();
  }

  void _initHeadlessAudioWebView() {
    try {
      final ctrl = WebViewController()
        ..setJavaScriptMode(JavaScriptMode.unrestricted)
        ..setNavigationDelegate(
          NavigationDelegate(
            onPageFinished: (_) {
              _webViewReady = true;
            },
          ),
        )
        ..loadHtmlString(_kSynthesizerHtml);
      _audioWebViewController = ctrl;
    } catch (_) {
      // Platform WebView not available in desktop/test harness; fallback to SystemSound.
    }
  }

  Future<void> toggleMute() async {
    await setMuted(!_isMuted);
  }

  Future<void> setMuted(bool muted) async {
    if (_isMuted == muted) return;
    _isMuted = muted;
    notifyListeners();
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_kPrefsMuteKey, _isMuted);
    } catch (_) {}
  }

  /// Synthesizes a valid 16-bit Mono PCM RIFF `.wav` byte buffer from a sequence of notes.
  /// Used both for in-memory `<audio src="data:audio/wav;base64,...">` playback and unit test verification.
  static Uint8List synthesizeToneSequenceWav(
    List<double> frequenciesHz, {
    int noteDurationMs = 70,
    int sampleRate = 22050,
    double volume = 0.32,
  }) {
    final samplesPerNote =
        math.max(1, (sampleRate * noteDurationMs / 1000).round());
    final totalSamples = samplesPerNote * math.max(1, frequenciesHz.length);
    final dataSize = totalSamples * 2; // 16-bit mono = 2 bytes/sample
    final fileSize = 36 + dataSize;

    final buffer = ByteData(44 + dataSize);
    // RIFF header
    buffer.setUint8(0, 0x52); // 'R'
    buffer.setUint8(1, 0x49); // 'I'
    buffer.setUint8(2, 0x46); // 'F'
    buffer.setUint8(3, 0x46); // 'F'
    buffer.setUint32(4, fileSize, Endian.little);
    buffer.setUint8(8, 0x57); // 'W'
    buffer.setUint8(9, 0x41); // 'A'
    buffer.setUint8(10, 0x56); // 'V'
    buffer.setUint8(11, 0x45); // 'E'
    // fmt chunk
    buffer.setUint8(12, 0x66); // 'f'
    buffer.setUint8(13, 0x6D); // 'm'
    buffer.setUint8(14, 0x74); // 't'
    buffer.setUint8(15, 0x20); // ' '
    buffer.setUint32(16, 16, Endian.little); // PCM chunk size
    buffer.setUint16(20, 1, Endian.little); // AudioFormat = 1 (PCM)
    buffer.setUint16(22, 1, Endian.little); // NumChannels = 1
    buffer.setUint32(24, sampleRate, Endian.little);
    buffer.setUint32(28, sampleRate * 2, Endian.little); // ByteRate
    buffer.setUint16(32, 2, Endian.little); // BlockAlign
    buffer.setUint16(34, 16, Endian.little); // BitsPerSample
    // data chunk
    buffer.setUint8(36, 0x64); // 'd'
    buffer.setUint8(37, 0x61); // 'a'
    buffer.setUint8(38, 0x74); // 't'
    buffer.setUint8(39, 0x61); // 'a'
    buffer.setUint32(40, dataSize, Endian.little);

    var sampleIdx = 0;
    for (final freq in frequenciesHz) {
      for (var i = 0; i < samplesPerNote; i++) {
        final t = i / sampleRate;
        // Apply fast attack + exponential decay envelope for crisp retro RPG pluck
        final progress = i / samplesPerNote;
        final envelope = math.sin(progress * math.pi);
        final rawWave = freq <= 0 ? 0.0 : math.sin(2.0 * math.pi * freq * t);
        final sampleVal =
            (rawWave * envelope * volume * 32767.0).round().clamp(-32768, 32767);
        buffer.setInt16(44 + sampleIdx * 2, sampleVal, Endian.little);
        sampleIdx++;
      }
    }
    return buffer.buffer.asUint8List();
  }

  void _triggerSfx(
    List<double> notesHz, {
    int noteDurationMs = 65,
    bool playClick = true,
  }) {
    if (_isMuted) return;
    _playedSfxCount++;

    if (!_isRunningInTest) {
      if (playClick) {
        SystemSound.play(SystemSoundType.click);
      }
      if (_webViewReady && _audioWebViewController != null) {
        final wavBytes = synthesizeToneSequenceWav(
          notesHz,
          noteDurationMs: noteDurationMs,
        );
        final b64 = base64Encode(wavBytes);
        _audioWebViewController!
            .runJavaScript('window.playWavBase64 && window.playWavBase64("$b64");')
            .catchError((_) {});
      }
    }
  }

  /// Soft rhythmic footstep tap while walking (throttled to every 270ms).
  void playStep() {
    if (_isMuted) return;
    final now = DateTime.now().millisecondsSinceEpoch;
    if (now - _lastFootstepMs < 270) return;
    _lastFootstepMs = now;
    _triggerSfx(const [190.0], noteDurationMs: 28, playClick: false);
  }

  /// Room door transition portal chime.
  void playDoorTransition() {
    _triggerSfx(const [330.0, 440.0, 587.33], noteDurationMs: 65);
  }

  /// Sitting, napping, or sleeping on a chair/sofa/bench cushion.
  void playSitOrRest() {
    _triggerSfx(const [392.0, 329.63], noteDurationMs: 60);
  }

  /// Opening a Subject Reviewer Chest or Small Mystery Chest.
  void playChestOpen() {
    _triggerSfx(const [523.25, 659.25, 783.99, 1046.50], noteDurationMs: 65);
  }

  /// Answering a Pop-Quiz question or Quest Activity correctly!
  void playQuizCorrect() {
    _triggerSfx(
      const [523.25, 659.25, 783.99, 987.77, 1046.50],
      noteDurationMs: 70,
    );
  }

  /// Answering a Pop-Quiz question wrong or hitting a locked action.
  void playQuizWrong() {
    _triggerSfx(const [220.0, 174.61], noteDurationMs: 110);
  }

  /// Unlocking a new cosmetic item in the Campus Shop!
  void playShopPurchase() {
    _triggerSfx(const [783.99, 987.77, 1318.51], noteDurationMs: 75);
  }

  /// Waving (`👋`) at a classmate or teacher.
  void playWaveEmote() {
    _triggerSfx(const [587.33, 880.0], noteDurationMs: 55);
  }

  /// Popping a Cloud Thought Bubble (`💭`) above the avatar.
  void playBubblePop() {
    _triggerSfx(const [659.25, 987.77], noteDurationMs: 50);
  }

  /// Tuning the Campus Radio Base station.
  void playRadioTune() {
    _triggerSfx(const [440.0, 554.37, 659.25], noteDurationMs: 60);
  }

  static const String _kSynthesizerHtml = '''
<!DOCTYPE html>
<html>
<head><meta name="viewport" content="width=device-width, initial-scale=1.0"></head>
<body style="margin:0;background:transparent;">
<script>
  window.playWavBase64 = function(b64) {
    try {
      var audio = new Audio("data:audio/wav;base64," + b64);
      audio.volume = 0.65;
      var p = audio.play();
      if (p && p.catch) p.catch(function(){});
    } catch (e) {}
  };
</script>
</body>
</html>
''';
}
