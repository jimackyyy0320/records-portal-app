import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';

import 'lobby_audio_service.dart';
import 'school_lobby_config.dart';

/// Bilingual (English / Tagalog / Cebuano) Profanity Filter & Teacher Moderation Service
/// for the MIS-SHS 2D School Campus.
class LobbyModerationService extends ChangeNotifier {
  LobbyModerationService._();
  static final LobbyModerationService instance = LobbyModerationService._();

  /// Word-boundary profanity list covering common English, Tagalog, and Cebuano/Bisaya slurs.
  static final List<RegExp> _profanityPatterns = <String>[
    r'\bfuck(?:ing|er|ed|s)?\b',
    r'\bshit(?:ty|s)?\b',
    r'\bbitch(?:es)?\b',
    r'\basshole(?:s)?\b',
    r'\bbastard(?:s)?\b',
    r'\bdickhead\b',
    r'\bpussy\b',
    r'\bcunt\b',
    r'\bslut\b',
    r'\bwhore\b',
    r'\bputang\s*ina\b',
    r'\bputangina(?:mo)?\b',
    r'\bputa\b',
    r'\bgago\b',
    r'\bgaga\b',
    r'\btanga\b',
    r'\bbobo\b',
    r'\btarantado\b',
    r'\bulol\b',
    r'\bkupal\b',
    r'\bpunyeta\b',
    r'\bleche\b',
    r'\bhindot\b',
    r'\bkantot\b',
    r'\bpakshet\b',
    r'\byawa(?:a)?\b',
    r'\bpiste(?:ha)?\b',
    r'\bkayat(?:a)?\b',
    r'\bbuang\b',
    r'\bbogo\b',
    r'\biloy\s*mo\b',
  ].map((p) => RegExp(p, caseSensitive: false)).toList();

  final Set<LobbyRoomId> _mutedRooms = <LobbyRoomId>{};
  String? _activeAnnouncement;
  String _announcementSender = 'Faculty';
  int _announcementTimestampMs = 0;
  int _announcementUntilMs = 0;

  Set<LobbyRoomId> get mutedRooms => Set<LobbyRoomId>.unmodifiable(_mutedRooms);

  String? get activeAnnouncement {
    if (_activeAnnouncement == null || _activeAnnouncement!.isEmpty) {
      return null;
    }
    if (DateTime.now().millisecondsSinceEpoch >= _announcementUntilMs) {
      return null;
    }
    return _activeAnnouncement;
  }

  String get announcementSender => _announcementSender;
  int get announcementTimestampMs => _announcementTimestampMs;

  bool isRoomChatMuted(LobbyRoomId room) => _mutedRooms.contains(room);

  String get mutedRoomsCsv => _mutedRooms.map((r) => r.name).join(',');

  /// Returns `true` if [rawText] contains any blocked profanity.
  bool containsProfanity(String rawText) {
    if (rawText.trim().isEmpty) return false;
    for (final pattern in _profanityPatterns) {
      if (pattern.hasMatch(rawText)) return true;
    }
    return false;
  }

  /// Replaces any profanity in [rawText] with `***` while keeping clean words intact.
  String sanitizeText(String rawText) {
    var result = rawText;
    for (final pattern in _profanityPatterns) {
      result = result.replaceAllMapped(
        pattern,
        (m) => '*' * m.group(0)!.length.clamp(3, 6),
      );
    }
    return result;
  }

  void toggleRoomMute(LobbyRoomId room) {
    if (_mutedRooms.contains(room)) {
      _mutedRooms.remove(room);
    } else {
      _mutedRooms.add(room);
    }
    notifyListeners();
  }

  void setRoomMute(LobbyRoomId room, bool muted) {
    if (muted) {
      _mutedRooms.add(room);
    } else {
      _mutedRooms.remove(room);
    }
    notifyListeners();
  }

  void broadcastAnnouncement(
    String message, {
    required String senderName,
    int durationMs = 60000,
  }) {
    final cleaned = sanitizeText(message.trim());
    final now = DateTime.now().millisecondsSinceEpoch;
    _announcementTimestampMs = now;
    if (cleaned.isEmpty) {
      _activeAnnouncement = null;
      _announcementUntilMs = 0;
    } else {
      _activeAnnouncement = cleaned;
      _announcementSender = senderName;
      _announcementUntilMs = now + durationMs;
    }
    notifyListeners();
  }

  /// Applies moderation state received from a Faculty member over `LobbyPresenceService`.
  void applyRemoteFacultyModeration({
    required String mutedRoomsCsv,
    String? announcementText,
    String? announcementSender,
    int? announcementTsMs,
  }) {
    var changed = false;
    final parsedRooms = <LobbyRoomId>{};
    if (mutedRoomsCsv.trim().isNotEmpty) {
      for (final part in mutedRoomsCsv.split(',')) {
        final clean = part.trim();
        for (final r in LobbyRoomId.values) {
          if (r.name == clean) {
            parsedRooms.add(r);
          }
        }
      }
    }
    if (_mutedRooms.length != parsedRooms.length ||
        !_mutedRooms.containsAll(parsedRooms)) {
      _mutedRooms
        ..clear()
        ..addAll(parsedRooms);
      changed = true;
    }

    if (announcementTsMs != null &&
        announcementTsMs > _announcementTimestampMs) {
      _announcementTimestampMs = announcementTsMs;
      if (announcementText != null && announcementText.trim().isNotEmpty) {
        _activeAnnouncement = sanitizeText(announcementText.trim());
        _announcementSender = announcementSender ?? 'Teacher';
        _announcementUntilMs =
            DateTime.now().millisecondsSinceEpoch + 60000;
      } else {
        _activeAnnouncement = null;
        _announcementUntilMs = 0;
      }
      changed = true;
    }

    if (changed) {
      notifyListeners();
    }
  }
}

/// Opens the **🛡️ Teacher Campus Moderation & Broadcast Console** Modal.
Future<void> showTeacherModerationModal({
  required BuildContext context,
  required String teacherName,
  required LobbyRoomId currentRoom,
  required VoidCallback onModerationChanged,
}) async {
  await showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (ctx) => _TeacherModerationSheet(
      teacherName: teacherName,
      currentRoom: currentRoom,
      onModerationChanged: onModerationChanged,
    ),
  );
}

class _TeacherModerationSheet extends StatefulWidget {
  final String teacherName;
  final LobbyRoomId currentRoom;
  final VoidCallback onModerationChanged;

  const _TeacherModerationSheet({
    required this.teacherName,
    required this.currentRoom,
    required this.onModerationChanged,
  });

  @override
  State<_TeacherModerationSheet> createState() =>
      _TeacherModerationSheetState();
}

class _TeacherModerationSheetState extends State<_TeacherModerationSheet> {
  final TextEditingController _announceCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    _announceCtrl.text =
        LobbyModerationService.instance.activeAnnouncement ?? '';
  }

  @override
  void dispose() {
    _announceCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;
    return AnimatedBuilder(
      animation: LobbyModerationService.instance,
      builder: (context, _) {
        final mod = LobbyModerationService.instance;
        return Container(
          margin: EdgeInsets.fromLTRB(12, 24, 12, 14 + bottomInset),
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: const Color(0xFF0F172A),
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: const Color(0xFFFACC15), width: 1.8),
          ),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Text('🛡️', style: TextStyle(fontSize: 24)),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Faculty Moderation & Broadcast HUD',
                            style: GoogleFonts.outfit(
                              color: const Color(0xFFFACC15),
                              fontSize: 17,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          Text(
                            'Mute student Thought Bubbles per room or broadcast a live banner across all 5 rooms.',
                            style: GoogleFonts.inter(
                              color: Colors.white70,
                              fontSize: 11.5,
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
                const SizedBox(height: 12),
                Text(
                  'ROOM THOUGHT BUBBLE MUTE CONTROLS',
                  style: GoogleFonts.outfit(
                    color: Colors.white60,
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.6,
                  ),
                ),
                const SizedBox(height: 6),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: LobbyRoomId.values.map((room) {
                    final muted = mod.isRoomChatMuted(room);
                    return FilterChip(
                      selected: muted,
                      selectedColor: const Color(0xFFEF4444),
                      backgroundColor: const Color(0xFF1E293B),
                      checkmarkColor: Colors.white,
                      label: Text(
                        '${muted ? "🔇" : "💬"} ${room.shortLabel}',
                        style: GoogleFonts.inter(
                          color: Colors.white,
                          fontSize: 11.5,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      onSelected: (val) {
                        HapticFeedback.selectionClick();
                        mod.setRoomMute(room, val);
                        widget.onModerationChanged();
                      },
                    );
                  }).toList(),
                ),
                const SizedBox(height: 14),
                Text(
                  'CAMPUS-WIDE ANNOUNCEMENT BANNER (📢)',
                  style: GoogleFonts.outfit(
                    color: Colors.white60,
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.6,
                  ),
                ),
                const SizedBox(height: 6),
                TextField(
                  controller: _announceCtrl,
                  maxLength: 90,
                  style: const TextStyle(color: Colors.white, fontSize: 13.5),
                  decoration: InputDecoration(
                    hintText:
                        'e.g., Everyone please proceed to the Classroom for our PGP Review!',
                    hintStyle: const TextStyle(color: Colors.white38),
                    filled: true,
                    fillColor: const Color(0xFF1E293B),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide.none,
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    if (mod.activeAnnouncement != null) ...[
                      OutlinedButton(
                        style: OutlinedButton.styleFrom(
                          foregroundColor: Colors.white70,
                          side: const BorderSide(color: Colors.white24),
                        ),
                        onPressed: () {
                          _announceCtrl.clear();
                          mod.broadcastAnnouncement(
                            '',
                            senderName: widget.teacherName,
                          );
                          widget.onModerationChanged();
                        },
                        child: const Text('Clear Banner'),
                      ),
                      const SizedBox(width: 8),
                    ],
                    Expanded(
                      child: ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFFFACC15),
                          foregroundColor: Colors.black,
                        ),
                        onPressed: () {
                          HapticFeedback.heavyImpact();
                          LobbyAudioService.instance.playChestOpen();
                          mod.broadcastAnnouncement(
                            _announceCtrl.text,
                            senderName: widget.teacherName,
                          );
                          widget.onModerationChanged();
                          Navigator.of(context).pop();
                        },
                        icon: const Icon(Icons.campaign_rounded, size: 18),
                        label: Text(
                          'Broadcast to All 5 Rooms',
                          style: GoogleFonts.outfit(
                            fontWeight: FontWeight.w900,
                            fontSize: 13,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
