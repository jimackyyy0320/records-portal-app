import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:webview_flutter/webview_flutter.dart';

import 'lobby_audio_service.dart';

/// Represents a curated Radio Garden / Campus FM live station on the Campus Radio Base.
class LobbyRadioStation {
  final String id;
  final String title;
  final String location;
  final String genre;
  final String emoji;
  final String radioGardenUrl;
  final String streamUrl;

  const LobbyRadioStation({
    required this.id,
    required this.title,
    required this.location,
    required this.genre,
    required this.emoji,
    required this.radioGardenUrl,
    required this.streamUrl,
  });
}

/// Manages the **📻 MIS-SHS Campus Radio Base (Powered by Radio Garden)** with a strict
/// **1-hour (`3,600s`) channel change cooldown** synced across the campus.
class LobbyRadioService extends ChangeNotifier {
  LobbyRadioService._();
  static final LobbyRadioService instance = LobbyRadioService._();

  /// Channel can only be changed once per hour (3,600,000 ms).
  static const int kChannelChangeCooldownMs = 60 * 60 * 1000;

  static const String _kPrefStationId = 'lobby_radio_station_id_v1';
  static const String _kPrefChangedAtMs = 'lobby_radio_changed_at_ms_v1';
  static const String _kPrefChangedBy = 'lobby_radio_changed_by_v1';

  static const List<LobbyRadioStation> kStations = <LobbyRadioStation>[
    LobbyRadioStation(
      id: 'rg_lofi_study',
      title: 'Lofi Study & Chill Beats FM',
      location: 'Global Study Lounge • Radio Garden',
      genre: '24/7 Lofi Hip-Hop & Exam Focus',
      emoji: '🎧',
      radioGardenUrl: 'https://radio.garden/visit/tokyo/pTJbQ1aM',
      streamUrl: 'https://ice1.somafm.com/groovesalad-128-mp3',
    ),
    LobbyRadioStation(
      id: 'rg_manila_opm',
      title: 'Manila Campus OPM & Acoustic',
      location: 'Metro Manila, Philippines • Radio Garden',
      genre: 'Pinoy Pop, Indie & Acoustic Ballads',
      emoji: '🇵🇭',
      radioGardenUrl: 'https://radio.garden/visit/manila/segments',
      streamUrl: 'https://ice1.somafm.com/lush-128-mp3',
    ),
    LobbyRadioStation(
      id: 'rg_cebu_fm',
      title: 'Queen City Cebu Campus FM',
      location: 'Cebu City, Philippines • Radio Garden',
      genre: 'Vispop, Bisrock & Student Requests',
      emoji: '🌴',
      radioGardenUrl: 'https://radio.garden/visit/cebu-city/segments',
      streamUrl: 'https://ice1.somafm.com/indiepop-128-mp3',
    ),
    LobbyRadioStation(
      id: 'rg_classical_reading',
      title: 'Classical Piano & Library Focus',
      location: 'London / Vienna • Radio Garden',
      genre: 'Instrumental Piano & Strings for Reading',
      emoji: '🎻',
      radioGardenUrl: 'https://radio.garden/visit/vienna/segments',
      streamUrl: 'https://ice1.somafm.com/dronezone-128-mp3',
    ),
    LobbyRadioStation(
      id: 'rg_canteen_jazz',
      title: 'Rainy Canteen Bossa & Jazz Café',
      location: 'Paris / Tokyo Café • Radio Garden',
      genre: 'Smooth Coffeehouse Jazz & Bossa Nova',
      emoji: '☕',
      radioGardenUrl: 'https://radio.garden/visit/paris/segments',
      streamUrl: 'https://ice1.somafm.com/secretagent-128-mp3',
    ),
    LobbyRadioStation(
      id: 'rg_anime_synth',
      title: 'Akihabara Anime & City Pop FM',
      location: 'Tokyo, Japan • Radio Garden',
      genre: 'Anime OSTs, Synthwave & J-Pop',
      emoji: '🌸',
      radioGardenUrl: 'https://radio.garden/visit/tokyo/segments',
      streamUrl: 'https://ice1.somafm.com/defcon-128-mp3',
    ),
  ];

  String _activeStationId = kStations.first.id;
  int _lastChangedAtMs = 0;
  String _lastChangedBy = 'Campus DJ';
  bool _isListeningLocally = false;
  bool _initialized = false;

  WebViewController? _streamWebViewController;

  String get activeStationId => _activeStationId;
  int get lastChangedAtMs => _lastChangedAtMs;
  String get lastChangedBy => _lastChangedBy;
  bool get isListeningLocally => _isListeningLocally;

  LobbyRadioStation get activeStation => kStations.firstWhere(
        (s) => s.id == _activeStationId,
        orElse: () => kStations.first,
      );

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
      final savedId = prefs.getString(_kPrefStationId);
      if (savedId != null && kStations.any((s) => s.id == savedId)) {
        _activeStationId = savedId;
      }
      _lastChangedAtMs = prefs.getInt(_kPrefChangedAtMs) ?? 0;
      _lastChangedBy = prefs.getString(_kPrefChangedBy) ?? 'Campus DJ';
    } catch (_) {}
    notifyListeners();
  }

  /// Resets state for deterministic unit testing.
  @visibleForTesting
  void resetForTesting() {
    _activeStationId = kStations.first.id;
    _lastChangedAtMs = 0;
    _lastChangedBy = 'Campus DJ';
    _isListeningLocally = false;
  }

  /// Returns `true` if the 1-hour (`3,600s`) channel lock has expired or hasn't been triggered yet.
  bool canChangeChannel({int? nowMs}) {
    if (_lastChangedAtMs <= 0) return true;
    final now = nowMs ?? DateTime.now().millisecondsSinceEpoch;
    return (now - _lastChangedAtMs) >= kChannelChangeCooldownMs;
  }

  /// Remaining seconds before any student/teacher can switch the Campus Radio channel again.
  int remainingCooldownSeconds({int? nowMs}) {
    if (_lastChangedAtMs <= 0) return 0;
    final now = nowMs ?? DateTime.now().millisecondsSinceEpoch;
    final elapsedMs = now - _lastChangedAtMs;
    if (elapsedMs >= kChannelChangeCooldownMs) return 0;
    return ((kChannelChangeCooldownMs - elapsedMs) / 1000).ceil();
  }

  /// Human-readable `MMm SSs` countdown string for the 1-hour channel lock.
  String formattedRemainingCooldown({int? nowMs}) {
    final rem = remainingCooldownSeconds(nowMs: nowMs);
    if (rem <= 0) return 'Ready to tune';
    final mins = rem ~/ 60;
    final secs = (rem % 60).toString().padLeft(2, '0');
    return '${mins}m ${secs}s';
  }

  /// Attempts to switch the Campus Radio Base to [stationId].
  /// Enforces the strict **1-hour (`3,600s`) cooldown** unless [fromRemoteSync] is true.
  Future<bool> changeStation(
    String stationId, {
    required String changedBy,
    int? nowMs,
    bool fromRemoteSync = false,
  }) async {
    if (!kStations.any((s) => s.id == stationId)) return false;
    final now = nowMs ?? DateTime.now().millisecondsSinceEpoch;

    if (!fromRemoteSync) {
      if (stationId == _activeStationId && _lastChangedAtMs > 0) {
        return true;
      }
      if (!canChangeChannel(nowMs: now)) {
        return false;
      }
    }

    _activeStationId = stationId;
    _lastChangedAtMs = now;
    _lastChangedBy = changedBy.trim().isEmpty ? 'Student DJ' : changedBy.trim();

    if (_isListeningLocally && !_isRunningInTest) {
      _syncAudioStreamWebView();
    }

    notifyListeners();
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_kPrefStationId, _activeStationId);
      await prefs.setInt(_kPrefChangedAtMs, _lastChangedAtMs);
      await prefs.setString(_kPrefChangedBy, _lastChangedBy);
    } catch (_) {}
    return true;
  }

  /// Applies a remote radio sync packet received from `LobbyPresenceService` if newer.
  void applyRemoteRadioSync({
    required String stationId,
    required int changedAtMs,
    required String changedBy,
  }) {
    if (stationId.isEmpty || changedAtMs <= _lastChangedAtMs) return;
    if (!kStations.any((s) => s.id == stationId)) return;
    unawaited(
      changeStation(
        stationId,
        changedBy: changedBy,
        nowMs: changedAtMs,
        fromRemoteSync: true,
      ),
    );
  }

  /// Toggles local audio playback of the active Campus Radio station on this device.
  void toggleLocalListening() {
    setLocalListening(!_isListeningLocally);
  }

  void setLocalListening(bool listen) {
    if (_isListeningLocally == listen) return;
    _isListeningLocally = listen;
    if (!_isRunningInTest) {
      _syncAudioStreamWebView();
    }
    notifyListeners();
  }

  void _syncAudioStreamWebView() {
    try {
      if (!_isListeningLocally) {
        _streamWebViewController?.loadHtmlString('<html><body></body></html>');
        return;
      }
      _streamWebViewController ??= WebViewController()
        ..setJavaScriptMode(JavaScriptMode.unrestricted);
      final station = activeStation;
      final html = '''
<!DOCTYPE html>
<html>
<head><meta name="viewport" content="width=device-width, initial-scale=1.0"></head>
<body style="margin:0;background:#0F172A;">
  <audio id="radioPlayer" autoplay loop crossorigin="anonymous" src="${station.streamUrl}"></audio>
  <script>
    var p = document.getElementById('radioPlayer');
    if (p) { p.volume = 0.75; p.play().catch(function(){}); }
  </script>
</body>
</html>
''';
      _streamWebViewController!.loadHtmlString(html);
    } catch (_) {}
  }
}

/// Opens the **📻 MIS-SHS Campus Radio Base (Powered by Radio Garden)** Modal.
/// Enforces the 1-hour (`3,600s`) channel switch lock and includes an interactive Radio Garden Globe tab.
Future<void> showCampusRadioModal({
  required BuildContext context,
  required String playerName,
  required VoidCallback onStationBroadcastChanged,
}) async {
  await showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (ctx) => _CampusRadioModalSheet(
      playerName: playerName,
      onStationBroadcastChanged: onStationBroadcastChanged,
    ),
  );
}

class _CampusRadioModalSheet extends StatefulWidget {
  final String playerName;
  final VoidCallback onStationBroadcastChanged;

  const _CampusRadioModalSheet({
    required this.playerName,
    required this.onStationBroadcastChanged,
  });

  @override
  State<_CampusRadioModalSheet> createState() => _CampusRadioModalSheetState();
}

class _CampusRadioModalSheetState extends State<_CampusRadioModalSheet> {
  Timer? _countdownTimer;
  bool _showRadioGardenGlobe = false;
  WebViewController? _globeController;

  @override
  void initState() {
    super.initState();
    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _countdownTimer?.cancel();
    super.dispose();
  }

  void _openRadioGardenGlobeView(String url) {
    try {
      _globeController ??= WebViewController()
        ..setJavaScriptMode(JavaScriptMode.unrestricted);
      _globeController!.loadRequest(Uri.parse(url));
      setState(() => _showRadioGardenGlobe = true);
    } catch (_) {
      launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
    }
  }

  Future<void> _selectStation(LobbyRadioStation station) async {
    final radio = LobbyRadioService.instance;
    if (station.id == radio.activeStationId) {
      if (!radio.isListeningLocally) {
        radio.setLocalListening(true);
      }
      return;
    }

    if (!radio.canChangeChannel()) {
      HapticFeedback.vibrate();
      LobbyAudioService.instance.playQuizWrong();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            '⏳ Channel Lock Active! The Campus Radio channel can only be changed once per hour. Next tune available in ${radio.formattedRemainingCooldown()} (Last tuned by ${radio.lastChangedBy}).',
          ),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    final changed = await radio.changeStation(
      station.id,
      changedBy: widget.playerName,
    );
    if (!mounted) return;
    if (changed) {
      HapticFeedback.heavyImpact();
      LobbyAudioService.instance.playRadioTune();
      radio.setLocalListening(true);
      widget.onStationBroadcastChanged();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            '📻 Tuned Campus Radio to "${station.title}"! Channel locked for 1 hour.',
          ),
          backgroundColor: const Color(0xFF065F46),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final media = MediaQuery.of(context);

    return AnimatedBuilder(
      animation: LobbyRadioService.instance,
      builder: (context, _) {
        final radio = LobbyRadioService.instance;
        final current = radio.activeStation;
        final canChange = radio.canChangeChannel();
        final remSec = radio.remainingCooldownSeconds();

        return Container(
          height: media.size.height * 0.86,
          margin: const EdgeInsets.fromLTRB(12, 20, 12, 12),
          decoration: BoxDecoration(
            color: const Color(0xFF0F172A),
            borderRadius: BorderRadius.circular(26),
            border: Border.all(
              color: const Color(0xFF10B981).withValues(alpha: 0.65),
              width: 1.8,
            ),
          ),
          child: Column(
            children: [
              // Header
              Container(
                padding: const EdgeInsets.fromLTRB(18, 14, 12, 12),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      const Color(0xFF065F46).withValues(alpha: 0.55),
                      const Color(0xFF1E293B),
                    ],
                  ),
                  borderRadius:
                      const BorderRadius.vertical(top: Radius.circular(24)),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 44,
                      height: 44,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: const Color(0xFF10B981).withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: const Color(0xFF10B981)),
                      ),
                      child: const Text('📻', style: TextStyle(fontSize: 22)),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'CAMPUS RADIO BASE • RADIO GARDEN',
                            style: GoogleFonts.outfit(
                              color: Colors.white,
                              fontSize: 16.5,
                              fontWeight: FontWeight.w800,
                              letterSpacing: 0.4,
                            ),
                          ),
                          Text(
                            'Shared campus broadcast • Channel can only be changed once per hour (60 mins)',
                            style: GoogleFonts.inter(
                              color: Colors.white70,
                              fontSize: 11,
                            ),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      onPressed: () => Navigator.of(context).pop(),
                      icon: const Icon(Icons.close_rounded,
                          color: Colors.white70),
                    ),
                  ],
                ),
              ),

              // Active Station & 1-Hour Lock Status Banner
              Padding(
                padding: const EdgeInsets.fromLTRB(14, 10, 14, 8),
                child: Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: const Color(0xFF1E293B),
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(
                      color: radio.isListeningLocally
                          ? const Color(0xFF10B981)
                          : Colors.white12,
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Text(current.emoji,
                              style: const TextStyle(fontSize: 28)),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'NOW ON AIR: ${current.title}',
                                  style: GoogleFonts.outfit(
                                    color: const Color(0xFF6EE7B7),
                                    fontSize: 14.5,
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                                Text(
                                  '${current.location} • ${current.genre}',
                                  style: GoogleFonts.inter(
                                    color: Colors.white70,
                                    fontSize: 11.5,
                                  ),
                                ),
                                const SizedBox(height: 3),
                                Text(
                                  canChange
                                      ? '🟢 Channel Unlocked — You can tune a new station for the campus!'
                                      : '🔒 1-Hour Channel Lock: ${radio.formattedRemainingCooldown()} remaining (Tuned by ${radio.lastChangedBy})',
                                  style: GoogleFonts.inter(
                                    color: canChange
                                        ? const Color(0xFFFDE047)
                                        : const Color(0xFFFCA5A5),
                                    fontSize: 11,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      Row(
                        children: [
                          Expanded(
                            child: ElevatedButton.icon(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: radio.isListeningLocally
                                    ? const Color(0xFFEF4444)
                                    : const Color(0xFF10B981),
                                foregroundColor: Colors.white,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                              ),
                              onPressed: () {
                                HapticFeedback.selectionClick();
                                radio.toggleLocalListening();
                              },
                              icon: Icon(
                                radio.isListeningLocally
                                    ? Icons.stop_circle_outlined
                                    : Icons.headphones_rounded,
                                size: 18,
                              ),
                              label: Text(
                                radio.isListeningLocally
                                    ? 'Mute Local Speaker'
                                    : 'Listen Live Now',
                                style: GoogleFonts.outfit(
                                  fontWeight: FontWeight.w800,
                                  fontSize: 12.5,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          OutlinedButton.icon(
                            style: OutlinedButton.styleFrom(
                              foregroundColor: const Color(0xFF38BDF8),
                              side: const BorderSide(color: Color(0xFF38BDF8)),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                            onPressed: () {
                              if (_showRadioGardenGlobe) {
                                setState(() => _showRadioGardenGlobe = false);
                              } else {
                                _openRadioGardenGlobeView(
                                    current.radioGardenUrl);
                              }
                            },
                            icon: Icon(
                              _showRadioGardenGlobe
                                  ? Icons.list_rounded
                                  : Icons.public_rounded,
                              size: 17,
                            ),
                            label: Text(
                              _showRadioGardenGlobe
                                  ? 'Station List'
                                  : 'Radio Garden Globe',
                              style: const TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),

              // Body: Either Interactive Radio Garden Globe WebView or Curated Campus Station List
              Expanded(
                child: _showRadioGardenGlobe && _globeController != null
                    ? ClipRRect(
                        borderRadius: const BorderRadius.vertical(
                            bottom: Radius.circular(24)),
                        child: WebViewWidget(controller: _globeController!),
                      )
                    : ListView.separated(
                        padding: const EdgeInsets.fromLTRB(14, 4, 14, 16),
                        itemCount: LobbyRadioService.kStations.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 8),
                        itemBuilder: (context, idx) {
                          final st = LobbyRadioService.kStations[idx];
                          final isCurrent = st.id == current.id;
                          return Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: isCurrent
                                  ? const Color(0xFF065F46)
                                      .withValues(alpha: 0.38)
                                  : const Color(0xFF1E293B),
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(
                                color: isCurrent
                                    ? const Color(0xFF10B981)
                                    : Colors.white12,
                                width: isCurrent ? 1.8 : 1.0,
                              ),
                            ),
                            child: Row(
                              children: [
                                Text(st.emoji,
                                    style: const TextStyle(fontSize: 24)),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        st.title,
                                        style: GoogleFonts.outfit(
                                          color: Colors.white,
                                          fontSize: 14,
                                          fontWeight: FontWeight.w800,
                                        ),
                                      ),
                                      Text(
                                        '${st.location} • ${st.genre}',
                                        style: GoogleFonts.inter(
                                          color: Colors.white70,
                                          fontSize: 11.5,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(width: 8),
                                ElevatedButton(
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: isCurrent
                                        ? const Color(0xFF10B981)
                                        : (canChange
                                            ? const Color(0xFF0284C7)
                                            : Colors.white12),
                                    foregroundColor: Colors.white,
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 12, vertical: 8),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(10),
                                    ),
                                  ),
                                  onPressed: () => _selectStation(st),
                                  child: Text(
                                    isCurrent
                                        ? '📡 On Air'
                                        : (canChange
                                            ? 'Tune (1h Lock)'
                                            : '🔒 ${remSec ~/ 60}m'),
                                    style: GoogleFonts.outfit(
                                      fontSize: 11.5,
                                      fontWeight: FontWeight.w800,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          );
                        },
                      ),
              ),
            ],
          ),
        );
      },
    );
  }
}
