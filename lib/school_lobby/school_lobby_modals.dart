import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:webview_flutter/webview_flutter.dart';

import '../services/api_service.dart';
import '../utils/reviewer_outline_extractor.dart';
import 'lobby_agency_agents.dart';
import 'lobby_audio_service.dart';
import 'lobby_data_service.dart';
import 'lobby_moderation_service.dart';
import 'lobby_presence_service.dart';
import 'school_lobby_config.dart';

/// Opens the Anime Receptionist / Quest Counter Modal (Feature 1).
Future<void> showQuestCounterModal({
  required BuildContext context,
  required bool isFaculty,
  required String userName,
}) async {
  await showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (ctx) => _QuestCounterModalSheet(
      isFaculty: isFaculty,
      userName: userName,
    ),
  );
}

/// Opens the Teacher "+ Post an Activity" form modal directly.
Future<void> showPostActivityModal({
  required BuildContext context,
  required String postedBy,
}) async {
  await showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (ctx) => _PostActivitySheet(postedBy: postedBy),
  );
}

/// Opens the Student "My Badges / Achievements" Drawer (Feature 1.3).
Future<void> showMyBadgesModal({
  required BuildContext context,
}) async {
  await showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (ctx) => const _MyBadgesDrawerSheet(),
  );
}

/// Opens a Subject-Labeled Large Treasure Chest Reviewer Vault Modal (Feature 2).
Future<void> showSubjectChestModal({
  required BuildContext context,
  required String chestId,
  required bool isFaculty,
}) async {
  await showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (ctx) => _SubjectChestModalSheet(
      chestId: chestId,
      isFaculty: isFaculty,
    ),
  );
}

/// Opens an AI Subject Teacher Dialogue & Daily Exam Modal (`msitarzewski/agency-agents` + Feature 3).
Future<void> showSmallMysteryChestModal({
  required BuildContext context,
  required String smallChestId,
  required String smallChestLabel,
  String playerName = 'Scholar',
}) async {
  await showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (ctx) => _SmallMysteryChestQuizSheet(
      smallChestId: smallChestId,
      smallChestLabel: smallChestLabel,
      playerName: playerName,
    ),
  );
}

/// Opens the Teacher's Corner Advisory Modal.
Future<void> showTeacherCornerModal({
  required BuildContext context,
  required bool isFaculty,
  required String userName,
}) async {
  await showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (ctx) => _TeacherCornerSheet(
      isFaculty: isFaculty,
      userName: userName,
    ),
  );
}

/// Opens the School Bulletin Board Modal.
Future<void> showBulletinBoardModal({
  required BuildContext context,
}) async {
  await showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (ctx) => const _BulletinBoardSheet(),
  );
}

/// Opens the Student Rest Spot Picker (`🪑 Sit`, `😪 Nap`, `🛌 Sleep`, or `🚶 Stand Up`),
/// plus shortcuts to **🎨 Decorate My Table Space** (at the student's Personal Classroom Table)
/// and **💬 Open Group Study Chat (`💭`)** (at any Group Study & Chat Space)!
Future<PlayerRestState?> showRestSpotActionModal({
  required BuildContext context,
  required String spotLabel,
  required PlayerRestState currentState,
  bool canSleepFlat = true,
  bool isPersonalClassroomTable = false,
  bool isGroupStudySpace = false,
  VoidCallback? onDecorateTable,
  VoidCallback? onOpenGroupChat,
}) async {
  return showModalBottomSheet<PlayerRestState>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (ctx) => _RestSpotPickerSheet(
      spotLabel: spotLabel,
      currentState: currentState,
      canSleepFlat: canSleepFlat,
      isPersonalClassroomTable: isPersonalClassroomTable,
      isGroupStudySpace: isGroupStudySpace,
      onDecorateTable: onDecorateTable,
      onOpenGroupChat: onOpenGroupChat,
    ),
  );
}

/// Opens the Cloud Thought Bubble Composer & Classmate Chat Modal (`💭`).
Future<String?> showThoughtBubbleComposerModal({
  required BuildContext context,
  required String playerName,
  required bool isFaculty,
  required LobbyRoomId currentRoom,
  LobbyPeerStudent? nearbyPeer,
  String? currentThought,
}) async {
  return showModalBottomSheet<String>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (ctx) => _ThoughtBubbleComposerSheet(
      playerName: playerName,
      isFaculty: isFaculty,
      currentRoom: currentRoom,
      nearbyPeer: nearbyPeer,
      currentThought: currentThought,
    ),
  );
}

// ═══════════════════════════════════════════════════════════════════════════
//  REST SPOT PICKER (`🪑 SIT`, `😪 NAP`, `🛌 SLEEP`)
// ═══════════════════════════════════════════════════════════════════════════

class _RestSpotPickerSheet extends StatelessWidget {
  final String spotLabel;
  final PlayerRestState currentState;
  final bool canSleepFlat;
  final bool isPersonalClassroomTable;
  final bool isGroupStudySpace;
  final VoidCallback? onDecorateTable;
  final VoidCallback? onOpenGroupChat;

  const _RestSpotPickerSheet({
    required this.spotLabel,
    required this.currentState,
    required this.canSleepFlat,
    this.isPersonalClassroomTable = false,
    this.isGroupStudySpace = false,
    this.onDecorateTable,
    this.onOpenGroupChat,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.85,
      ),
      margin: const EdgeInsets.fromLTRB(12, 16, 12, 16),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: const Color(0xFF0F172A),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: isPersonalClassroomTable
              ? const Color(0xFFF59E0B)
              : (isGroupStudySpace
                  ? const Color(0xFF38BDF8)
                  : const Color(0xFF10B981).withOpacity(0.55)),
          width: 1.6,
        ),
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: (isPersonalClassroomTable
                            ? const Color(0xFFF59E0B)
                            : (isGroupStudySpace
                                ? const Color(0xFF38BDF8)
                                : const Color(0xFF10B981)))
                        .withOpacity(0.18),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: isPersonalClassroomTable
                          ? const Color(0xFFF59E0B)
                          : (isGroupStudySpace
                              ? const Color(0xFF38BDF8)
                              : const Color(0xFF10B981)),
                    ),
                  ),
                  child: Text(
                    isPersonalClassroomTable
                        ? '📌'
                        : (isGroupStudySpace ? '📚' : '🪑'),
                    style: const TextStyle(fontSize: 22),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        spotLabel,
                        style: GoogleFonts.outfit(
                          color: Colors.white,
                          fontSize: 17,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      Text(
                        isPersonalClassroomTable
                            ? 'Your Exclusive Personal Classroom Table — Sit, Nap, or Customize with Table Decor!'
                            : (isGroupStudySpace
                                ? 'Collaborative Group Study & Chat Space — Sit with classmates & share Thought Bubbles!'
                                : 'Choose how your avatar wants to rest here:'),
                        style: GoogleFonts.inter(
                          color: Colors.white70,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  onPressed: () => Navigator.of(context).pop(),
                  icon: const Icon(Icons.close_rounded, color: Colors.white70),
                ),
              ],
            ),
            const SizedBox(height: 14),
            Row(
              children: [
                Expanded(
                  child: _RestOptionCard(
                    emoji: '🪑',
                    title: 'Sit Down',
                    subtitle: 'Relax & study',
                    color: const Color(0xFF10B981),
                    isSelected: currentState == PlayerRestState.sitting,
                    onTap: () =>
                        Navigator.of(context).pop(PlayerRestState.sitting),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _RestOptionCard(
                    emoji: '😪',
                    title: 'Take a Nap',
                    subtitle: 'Power nap 💤',
                    color: const Color(0xFFA855F7),
                    isSelected: currentState == PlayerRestState.napping,
                    onTap: () =>
                        Navigator.of(context).pop(PlayerRestState.napping),
                  ),
                ),
                if (canSleepFlat) ...[
                  const SizedBox(width: 8),
                  Expanded(
                    child: _RestOptionCard(
                      emoji: '🛌',
                      title: 'Sleep',
                      subtitle: 'Sofa / Bench 💤',
                      color: const Color(0xFF6366F1),
                      isSelected: currentState == PlayerRestState.sleeping,
                      onTap: () =>
                          Navigator.of(context).pop(PlayerRestState.sleeping),
                    ),
                  ),
                ],
              ],
            ),
            if (isPersonalClassroomTable && onDecorateTable != null) ...[
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFF59E0B),
                    foregroundColor: const Color(0xFF0F172A),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  onPressed: () {
                    Navigator.of(context).pop();
                    onDecorateTable!();
                  },
                  icon: const Text('🎨', style: TextStyle(fontSize: 16)),
                  label: Text(
                    'Decorate My Table Space (Chair, Lights, Frames & Props)',
                    style: GoogleFonts.outfit(
                      fontWeight: FontWeight.w800,
                      fontSize: 13,
                    ),
                  ),
                ),
              ),
            ],
            if (isGroupStudySpace && onOpenGroupChat != null) ...[
              const SizedBox(height: 10),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF0284C7),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  onPressed: () {
                    Navigator.of(context).pop(PlayerRestState.sitting);
                    Future.delayed(const Duration(milliseconds: 180), () {
                      onOpenGroupChat!();
                    });
                  },
                  icon: const Text('💭', style: TextStyle(fontSize: 16)),
                  label: Text(
                    'Sit & Open Group Study Chat (💭)',
                    style: GoogleFonts.outfit(
                      fontWeight: FontWeight.w800,
                      fontSize: 13.5,
                    ),
                  ),
                ),
              ),
            ],
            if (currentState.isResting) ...[
              const SizedBox(height: 10),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    foregroundColor: const Color(0xFFFACC15),
                    side: const BorderSide(color: Color(0xFFFACC15)),
                  ),
                  onPressed: () =>
                      Navigator.of(context).pop(PlayerRestState.none),
                  icon: const Icon(Icons.directions_walk_rounded, size: 18),
                  label: const Text('Stand Up & Resume Walking'),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _RestOptionCard extends StatelessWidget {
  final String emoji;
  final String title;
  final String subtitle;
  final Color color;
  final bool isSelected;
  final VoidCallback onTap;

  const _RestOptionCard({
    required this.emoji,
    required this.title,
    required this.subtitle,
    required this.color,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: () {
        HapticFeedback.mediumImpact();
        onTap();
      },
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 8),
        decoration: BoxDecoration(
          color: isSelected
              ? color.withOpacity(0.24)
              : const Color(0xFF1E293B).withOpacity(0.85),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isSelected ? color : Colors.white12,
            width: isSelected ? 2.0 : 1.0,
          ),
        ),
        child: Column(
          children: [
            Text(emoji, style: const TextStyle(fontSize: 24)),
            const SizedBox(height: 6),
            Text(
              title,
              style: GoogleFonts.outfit(
                color: Colors.white,
                fontSize: 13.5,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              subtitle,
              textAlign: TextAlign.center,
              style: GoogleFonts.inter(
                color: Colors.white60,
                fontSize: 10.5,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════
//  THOUGHT BUBBLE COMPOSER & CLASSMATE CHAT MODAL (`💭`)
// ═══════════════════════════════════════════════════════════════════════════

class _ThoughtBubbleComposerSheet extends StatefulWidget {
  final String playerName;
  final bool isFaculty;
  final LobbyRoomId currentRoom;
  final LobbyPeerStudent? nearbyPeer;
  final String? currentThought;

  const _ThoughtBubbleComposerSheet({
    required this.playerName,
    required this.isFaculty,
    required this.currentRoom,
    this.nearbyPeer,
    this.currentThought,
  });

  @override
  State<_ThoughtBubbleComposerSheet> createState() =>
      _ThoughtBubbleComposerSheetState();
}

class _ThoughtBubbleComposerSheetState
    extends State<_ThoughtBubbleComposerSheet> {
  late final TextEditingController _textCtrl;

  static const List<String> _quickPrompts = [
    '📚 Reviewing for our quiz!',
    '👋 Hi classmate! Let\'s study together!',
    '💎 Checking the Google Drive Reviewer Chests!',
    '🍱 Heading to the Canteen for snacks!',
    '🌳 Chilling at the Campus Park!',
    '😪 Taking a quick power nap...',
    '💡 Ready for recitation today!',
    '🔥 Road to Level 10 Scholar!',
  ];

  @override
  void initState() {
    super.initState();
    _textCtrl = TextEditingController(text: widget.currentThought ?? '');
  }

  @override
  void dispose() {
    _textCtrl.dispose();
    super.dispose();
  }

  void _submitThought(String rawText) {
    final text = rawText.trim();
    if (text.isEmpty) {
      Navigator.of(context).pop('');
      return;
    }
    if (!widget.isFaculty &&
        LobbyModerationService.instance.isRoomChatMuted(widget.currentRoom)) {
      HapticFeedback.vibrate();
      LobbyAudioService.instance.playQuizWrong();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            '🔇 Room Thought Bubbles are currently muted by your Teacher.',
          ),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }
    final sanitized = LobbyModerationService.instance.sanitizeText(text);
    HapticFeedback.mediumImpact();
    LobbyAudioService.instance.playBubblePop();
    Navigator.of(context).pop(sanitized);
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;
    final peer = widget.nearbyPeer;

    return AnimatedBuilder(
      animation: LobbyDataService.instance,
      builder: (context, _) {
        final messages = LobbyDataService.instance.thoughtMessages;

        return Container(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.of(context).size.height * 0.86,
          ),
          margin: EdgeInsets.fromLTRB(12, 24, 12, 12 + bottomInset),
          decoration: BoxDecoration(
            color: const Color(0xFF0F172A),
            borderRadius: BorderRadius.circular(24),
            border: Border.all(
              color: const Color(0xFF38BDF8).withOpacity(0.55),
              width: 1.6,
            ),
          ),
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(18),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      width: 44,
                      height: 44,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: const Color(0xFF38BDF8).withOpacity(0.18),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: const Color(0xFF38BDF8)),
                      ),
                      child: const Text('💭', style: TextStyle(fontSize: 22)),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            peer != null
                                ? 'Thought Chat with ${peer.name}'
                                : 'Student Thought Bubble (💭)',
                            style: GoogleFonts.outfit(
                              color: Colors.white,
                              fontSize: 17,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          Text(
                            peer != null
                                ? '${peer.defaultThought}'
                                : 'Display a floating cloud thought bubble above your avatar to chat!',
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
                const SizedBox(height: 14),

                // Custom Thought Input
                TextField(
                  controller: _textCtrl,
                  maxLength: 56,
                  style: const TextStyle(color: Colors.white, fontSize: 14),
                  decoration: InputDecoration(
                    hintText: peer != null
                        ? 'Send a thought bubble to ${peer.name}...'
                        : 'What\'s on your mind, ${widget.playerName}?',
                    hintStyle: const TextStyle(color: Colors.white38),
                    counterStyle:
                        const TextStyle(color: Colors.white38, fontSize: 10),
                    filled: true,
                    fillColor: const Color(0xFF1E293B),
                    prefixIcon: const Icon(Icons.cloud_outlined,
                        color: Color(0xFF38BDF8)),
                    suffixIcon: _textCtrl.text.isNotEmpty
                        ? IconButton(
                            tooltip: 'Clear bubble',
                            onPressed: () {
                              _textCtrl.clear();
                              setState(() {});
                            },
                            icon: const Icon(Icons.clear_rounded,
                                color: Colors.white54),
                          )
                        : null,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide: BorderSide.none,
                    ),
                  ),
                  onChanged: (_) => setState(() {}),
                  onSubmitted: _submitThought,
                ),
                const SizedBox(height: 8),

                // Quick Preset Chips
                Text(
                  'QUICK CAMPUS THOUGHTS',
                  style: GoogleFonts.outfit(
                    color: Colors.white60,
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.7,
                  ),
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: _quickPrompts.map((prompt) {
                    return ActionChip(
                      backgroundColor: const Color(0xFF1E293B),
                      side: BorderSide(
                        color: const Color(0xFF38BDF8).withOpacity(0.35),
                      ),
                      label: Text(
                        prompt,
                        style: GoogleFonts.inter(
                          color: Colors.white,
                          fontSize: 11.5,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      onPressed: () => _submitThought(prompt),
                    );
                  }).toList(),
                ),
                const SizedBox(height: 14),

                // Action Buttons
                Row(
                  children: [
                    if (widget.currentThought != null &&
                        widget.currentThought!.isNotEmpty) ...[
                      OutlinedButton.icon(
                        style: OutlinedButton.styleFrom(
                          foregroundColor: Colors.white70,
                          side: const BorderSide(color: Colors.white24),
                          padding: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 12),
                        ),
                        onPressed: () => Navigator.of(context).pop(''),
                        icon: const Icon(Icons.visibility_off_outlined,
                            size: 16),
                        label: const Text('Hide'),
                      ),
                      const SizedBox(width: 8),
                    ],
                    Expanded(
                      child: ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF0284C7),
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 13),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                        ),
                        onPressed: () => _submitThought(_textCtrl.text),
                        icon: const Icon(Icons.send_rounded, size: 18),
                        label: Text(
                          peer != null
                              ? 'Share Thought with ${peer.name}'
                              : 'Show Thought Bubble Above Avatar',
                          style: GoogleFonts.outfit(
                            fontWeight: FontWeight.w800,
                            fontSize: 13.5,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),

                // Recent Room Thought Bubble Feed
                if (messages.isNotEmpty) ...[
                  const SizedBox(height: 16),
                  Text(
                    'RECENT THOUGHT BUBBLES IN CAMPUS (${messages.length})',
                    style: GoogleFonts.outfit(
                      color: Colors.white60,
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 0.7,
                    ),
                  ),
                  const SizedBox(height: 8),
                  ConstrainedBox(
                    constraints: const BoxConstraints(maxHeight: 160),
                    child: ListView.separated(
                      shrinkWrap: true,
                      itemCount: messages.length.clamp(0, 8),
                      separatorBuilder: (_, __) => const SizedBox(height: 6),
                      itemBuilder: (context, index) {
                        final msg = messages[index];
                        return Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 8),
                          decoration: BoxDecoration(
                            color: msg.isFromPeer
                                ? const Color(0xFF1E293B).withOpacity(0.75)
                                : const Color(0xFF0284C7).withOpacity(0.18),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: msg.isFromPeer
                                  ? Colors.white12
                                  : const Color(0xFF38BDF8).withOpacity(0.4),
                            ),
                          ),
                          child: Row(
                            children: [
                              const Text('💭', style: TextStyle(fontSize: 15)),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text.rich(
                                  TextSpan(
                                    children: [
                                      TextSpan(
                                        text: '${msg.senderName}: ',
                                        style: GoogleFonts.inter(
                                          color: const Color(0xFF38BDF8),
                                          fontWeight: FontWeight.w800,
                                          fontSize: 11.5,
                                        ),
                                      ),
                                      TextSpan(
                                        text: msg.text,
                                        style: GoogleFonts.inter(
                                          color: Colors.white,
                                          fontSize: 11.5,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                              const SizedBox(width: 6),
                              Text(
                                msg.roomName,
                                style: GoogleFonts.inter(
                                  color: Colors.white38,
                                  fontSize: 9.5,
                                ),
                              ),
                            ],
                          ),
                        );
                      },
                    ),
                  ),
                ],
              ],
            ),
          ),
        );
      },
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════
//  FEATURE 1: QUEST COUNTER & STUDENT BADGE SYSTEM
// ═══════════════════════════════════════════════════════════════════════════

class _QuestCounterModalSheet extends StatelessWidget {
  final bool isFaculty;
  final String userName;

  const _QuestCounterModalSheet({
    required this.isFaculty,
    required this.userName,
  });

  Future<void> _launchActivityUrl(
    BuildContext context,
    LobbyQuestActivity activity,
  ) async {
    await LobbyDataService.instance.markActivityLaunched(activity.id);
    final raw = activity.activityUrl.trim();
    if (raw.isNotEmpty) {
      final uri = Uri.tryParse(raw.startsWith('http') ? raw : 'https://$raw');
      if (uri != null) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      }
    }
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            '🚀 Launched "${activity.title}"! You can now click "Mark as Done" to claim +${activity.xpReward} XP & ${activity.badgeIcon} ${activity.badgeName}.',
          ),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  Future<void> _completeActivity(
    BuildContext context,
    LobbyQuestActivity activity,
  ) async {
    HapticFeedback.heavyImpact();
    final earnedBadge =
        await LobbyDataService.instance.completeActivity(activity);
    if (!context.mounted || earnedBadge == null) return;

    await showDialog<void>(
      context: context,
      builder: (ctx) => _BadgeCelebrationDialog(
        badge: earnedBadge,
        xpReward: activity.xpReward,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: LobbyDataService.instance,
      builder: (context, _) {
        final service = LobbyDataService.instance;
        final activities = service.activities;
        final progress = service.progress;

        return Container(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.of(context).size.height * 0.86,
          ),
          margin: const EdgeInsets.fromLTRB(12, 24, 12, 12),
          decoration: BoxDecoration(
            color: const Color(0xFF0F172A),
            borderRadius: BorderRadius.circular(24),
            border: Border.all(
              color: const Color(0xFFF59E0B).withOpacity(0.55),
              width: 1.6,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.6),
                blurRadius: 24,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // RPG Receptionist Dialogue Banner
              Container(
                padding: const EdgeInsets.fromLTRB(18, 16, 14, 14),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      const Color(0xFF78350F).withOpacity(0.55),
                      const Color(0xFF1E293B),
                    ],
                  ),
                  borderRadius: const BorderRadius.vertical(
                    top: Radius.circular(22),
                  ),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 46,
                      height: 46,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: const Color(0xFFF59E0B).withOpacity(0.2),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(
                          color: const Color(0xFFFACC15),
                          width: 1.5,
                        ),
                      ),
                      child: const Text('👩‍💼', style: TextStyle(fontSize: 24)),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Text(
                                'Aiko • Quest Counter',
                                style: GoogleFonts.outfit(
                                  color: const Color(0xFFFACC15),
                                  fontWeight: FontWeight.w800,
                                  fontSize: 16,
                                ),
                              ),
                              const SizedBox(width: 8),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 7, vertical: 2),
                                decoration: BoxDecoration(
                                  color:
                                      const Color(0xFF10B981).withOpacity(0.2),
                                  borderRadius: BorderRadius.circular(99),
                                ),
                                child: Text(
                                  'LVL ${progress.level} • ${progress.xp} XP',
                                  style: GoogleFonts.inter(
                                    color: const Color(0xFF34D399),
                                    fontSize: 10.5,
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 3),
                          Text(
                            isFaculty
                                ? '"Welcome, Teacher $userName! Post a new learning quest to reward students with XP & custom badges!"'
                                : '"Welcome, $userName! Showing active quests for your enrolled subjects!"',
                            style: GoogleFonts.inter(
                              color: Colors.white.withOpacity(0.85),
                              fontSize: 11.5,
                              fontStyle: FontStyle.italic,
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

              // Action Bar (Teacher "+ Manage Links" & "+ Post Activity" + Student "My Badges")
              Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                child: Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  alignment: WrapAlignment.spaceBetween,
                  children: [
                    Text(
                      'ENROLLED QUEST LINKS (${activities.length})',
                      style: GoogleFonts.outfit(
                        color: Colors.white70,
                        fontSize: 12,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0.8,
                      ),
                    ),
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        OutlinedButton.icon(
                          style: OutlinedButton.styleFrom(
                            foregroundColor: const Color(0xFF38BDF8),
                            side: const BorderSide(color: Color(0xFF38BDF8)),
                            padding: const EdgeInsets.symmetric(
                                horizontal: 10, vertical: 6),
                          ),
                          onPressed: () => showMyBadgesModal(context: context),
                          icon: const Icon(Icons.workspace_premium_rounded,
                              size: 15),
                          label: Text(
                            'Badges (${progress.earnedBadges.length})',
                            style: const TextStyle(
                                fontSize: 11, fontWeight: FontWeight.w700),
                          ),
                        ),
                        if (isFaculty) ...[
                          const SizedBox(width: 6),
                          OutlinedButton.icon(
                            style: OutlinedButton.styleFrom(
                              foregroundColor: const Color(0xFFFACC15),
                              side: const BorderSide(color: Color(0xFFFACC15)),
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 10, vertical: 6),
                            ),
                            onPressed: () {
                              Navigator.of(context).pop();
                              showTeacherLinkManagerModal(
                                context: context,
                                teacherName: userName,
                              );
                            },
                            icon: const Icon(Icons.link_rounded, size: 15),
                            label: const Text(
                              'Manage Links',
                              style: TextStyle(
                                  fontSize: 11, fontWeight: FontWeight.w800),
                            ),
                          ),
                          const SizedBox(width: 6),
                          ElevatedButton.icon(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFFF59E0B),
                              foregroundColor: const Color(0xFF0F172A),
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 10, vertical: 7),
                            ),
                            onPressed: () => showPostActivityModal(
                              context: context,
                              postedBy: userName,
                            ),
                            icon: const Icon(Icons.add_rounded, size: 16),
                            label: const Text(
                              '+ Post Activity',
                              style: TextStyle(
                                  fontSize: 11, fontWeight: FontWeight.w800),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ],
                ),
              ),

              // Quest List
              Flexible(
                child: activities.isEmpty
                    ? Padding(
                        padding: const EdgeInsets.all(24),
                        child: Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(20),
                          decoration: BoxDecoration(
                            color: const Color(0xFF1E293B).withOpacity(0.65),
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: Colors.white12),
                          ),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Text('🎯', style: TextStyle(fontSize: 34)),
                              const SizedBox(height: 8),
                              Text(
                                'No Active Quest Links Posted Yet',
                                style: GoogleFonts.outfit(
                                  color: Colors.white,
                                  fontSize: 15,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                isFaculty
                                    ? 'Tap "+ Post Activity" or "Manage Links" above to add an Activity Link that students can launch and Mark as Done (+XP & Badge).'
                                    : 'When your teacher posts an Activity Link for your enrolled subjects, it will appear here so you can launch it and Mark as Done to level up!',
                                textAlign: TextAlign.center,
                                style: GoogleFonts.inter(
                                  color: Colors.white60,
                                  fontSize: 12,
                                ),
                              ),
                            ],
                          ),
                        ),
                      )
                    : ListView.separated(
                        padding: const EdgeInsets.fromLTRB(16, 0, 16, 18),
                        shrinkWrap: true,
                        itemCount: activities.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 10),
                        itemBuilder: (context, index) {
                          final act = activities[index];
                          final isLaunched = progress.launchedActivityIds
                              .contains(act.id);
                          final isDone = progress.completedActivityIds
                              .contains(act.id);
                          final badgeColor = Color(act.badgeColor);

                          return Container(
                            padding: const EdgeInsets.all(14),
                            decoration: BoxDecoration(
                              color: const Color(0xFF1E293B).withOpacity(0.85),
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(
                                color: isDone
                                    ? const Color(0xFF10B981).withOpacity(0.6)
                                    : badgeColor.withOpacity(0.38),
                                width: 1.3,
                              ),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 8, vertical: 3),
                                      decoration: BoxDecoration(
                                        color: badgeColor.withOpacity(0.2),
                                        borderRadius: BorderRadius.circular(8),
                                        border: Border.all(color: badgeColor),
                                      ),
                                      child: Text(
                                        act.subject,
                                        style: GoogleFonts.outfit(
                                          color: Colors.white,
                                          fontSize: 10.5,
                                          fontWeight: FontWeight.w800,
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 8, vertical: 3),
                                      decoration: BoxDecoration(
                                        color: const Color(0xFFFACC15)
                                            .withOpacity(0.16),
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      child: Text(
                                        '+${act.xpReward} XP • ${act.badgeIcon} ${act.badgeName}',
                                        style: GoogleFonts.inter(
                                          color: const Color(0xFFFDE047),
                                          fontSize: 10.5,
                                          fontWeight: FontWeight.w700,
                                        ),
                                      ),
                                    ),
                                    const Spacer(),
                                    if (isDone)
                                      const Icon(
                                        Icons.check_circle_rounded,
                                        color: Color(0xFF34D399),
                                        size: 20,
                                      ),
                                    if (isFaculty) ...[
                                      const SizedBox(width: 6),
                                      InkWell(
                                        onTap: () => LobbyDataService.instance
                                            .deleteActivity(act.id),
                                        borderRadius: BorderRadius.circular(8),
                                        child: const Padding(
                                          padding: EdgeInsets.all(4),
                                          child: Icon(
                                            Icons.delete_outline_rounded,
                                            color: Colors.redAccent,
                                            size: 18,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ],
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  act.title,
                                  style: GoogleFonts.outfit(
                                    color: Colors.white,
                                    fontSize: 15,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                                const SizedBox(height: 3),
                                Text(
                                  'Posted by ${act.postedBy} • ${act.activityUrl}',
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: GoogleFonts.inter(
                                    color: Colors.white54,
                                    fontSize: 11,
                                  ),
                                ),
                                const SizedBox(height: 10),
                                Row(
                                  children: [
                                    Expanded(
                                      child: OutlinedButton.icon(
                                        style: OutlinedButton.styleFrom(
                                          foregroundColor:
                                              const Color(0xFF38BDF8),
                                          side: const BorderSide(
                                              color: Color(0xFF38BDF8)),
                                        ),
                                        onPressed: () =>
                                            _launchActivityUrl(context, act),
                                        icon: const Icon(
                                            Icons.open_in_new_rounded,
                                            size: 16),
                                        label: const Text(
                                          'Launch Activity',
                                          style: TextStyle(
                                              fontSize: 12,
                                              fontWeight: FontWeight.w700),
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 10),
                                    Expanded(
                                      child: ElevatedButton.icon(
                                        style: ElevatedButton.styleFrom(
                                          backgroundColor: isDone
                                              ? const Color(0xFF065F46)
                                              : (isLaunched
                                                  ? const Color(0xFF10B981)
                                                  : const Color(0xFF334155)),
                                          foregroundColor: Colors.white,
                                        ),
                                        onPressed: (!isDone && isLaunched)
                                            ? () =>
                                                _completeActivity(context, act)
                                            : null,
                                        icon: Icon(
                                          isDone
                                              ? Icons.verified_rounded
                                              : (isLaunched
                                                  ? Icons.task_alt_rounded
                                                  : Icons.lock_outline_rounded),
                                          size: 16,
                                        ),
                                        label: Text(
                                          isDone
                                              ? 'Completed'
                                              : (isLaunched
                                                  ? 'Mark as Done'
                                                  : 'Launch First'),
                                          style: const TextStyle(
                                              fontSize: 12,
                                              fontWeight: FontWeight.w800),
                                        ),
                                      ),
                                    ),
                                  ],
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

class _PostActivitySheet extends StatefulWidget {
  final String postedBy;

  const _PostActivitySheet({required this.postedBy});

  @override
  State<_PostActivitySheet> createState() => _PostActivitySheetState();
}

class _PostActivitySheetState extends State<_PostActivitySheet> {
  final _titleCtrl = TextEditingController();
  final _urlCtrl = TextEditingController(
      text: 'https://www.officialgazette.gov.ph/constitutions/1987-constitution/');
  final _xpCtrl = TextEditingController(text: '100');
  final _badgeNameCtrl = TextEditingController(text: 'Quiz Conqueror');

  String _selectedSubject = 'PGP';
  int _selectedPresetIdx = 1;

  @override
  void initState() {
    super.initState();
    final chests = LobbyDataService.instance.subjectChests;
    if (chests.isNotEmpty) {
      _selectedSubject = chests.first.subjectName;
    }
  }

  @override
  void dispose() {
    _titleCtrl.dispose();
    _urlCtrl.dispose();
    _xpCtrl.dispose();
    _badgeNameCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final title = _titleCtrl.text.trim();
    if (title.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter an activity title.')),
      );
      return;
    }
    final preset = kLobbyBadgePresets[_selectedPresetIdx];
    final xp = int.tryParse(_xpCtrl.text.trim()) ?? 100;

    await LobbyDataService.instance.postActivity(
      title: title,
      subject: _selectedSubject,
      activityUrl: _urlCtrl.text.trim(),
      xpReward: xp,
      badgeName: _badgeNameCtrl.text.trim().isEmpty
          ? preset.defaultTitle
          : _badgeNameCtrl.text.trim(),
      badgeIcon: preset.icon,
      badgeColor: preset.accentColor,
      postedBy: widget.postedBy,
    );

    if (mounted) {
      Navigator.of(context).pop();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('✅ Posted Quest "$title" ($_selectedSubject)!'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final subjectOptions = LobbyDataService.instance.subjectChests
        .map((c) => c.subjectName)
        .toSet()
        .toList();
    if (subjectOptions.isEmpty) {
      subjectOptions.addAll(['PGP', 'UCSP', 'PPG', 'PKLP TERM 2', 'PHILO']);
    }
    if (!subjectOptions.contains(_selectedSubject)) {
      _selectedSubject = subjectOptions.first;
    }

    final bottomInset = MediaQuery.of(context).viewInsets.bottom;

    return Container(
      margin: EdgeInsets.fromLTRB(12, 24, 12, 12 + bottomInset),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: const Color(0xFF0F172A),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: const Color(0xFFF59E0B), width: 1.5),
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text(
                  '⚔️ Post a Quest Activity',
                  style: GoogleFonts.outfit(
                    color: const Color(0xFFFACC15),
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const Spacer(),
                IconButton(
                  onPressed: () => Navigator.of(context).pop(),
                  icon: const Icon(Icons.close_rounded, color: Colors.white70),
                ),
              ],
            ),
            const SizedBox(height: 10),
            _buildTextField(
              controller: _titleCtrl,
              label: 'Activity Title',
              hint: 'e.g., Unit 2 Policy Analysis',
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  flex: 3,
                  child: DropdownButtonFormField<String>(
                    value: _selectedSubject,
                    dropdownColor: const Color(0xFF1E293B),
                    style: const TextStyle(color: Colors.white, fontSize: 13),
                    decoration: _inputDecoration('Subject Tag'),
                    items: subjectOptions
                        .map(
                          (s) => DropdownMenuItem(
                            value: s,
                            child: Text(s),
                          ),
                        )
                        .toList(),
                    onChanged: (v) {
                      if (v != null) setState(() => _selectedSubject = v);
                    },
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  flex: 2,
                  child: _buildTextField(
                    controller: _xpCtrl,
                    label: 'XP Reward',
                    hint: '100',
                    keyboardType: TextInputType.number,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            _buildTextField(
              controller: _urlCtrl,
              label: 'Activity URL / Link',
              hint: 'https://...',
            ),
            const SizedBox(height: 12),
            Text(
              'Select Pixel Badge Icon & Custom Title',
              style: GoogleFonts.inter(
                color: Colors.white70,
                fontSize: 12,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 8),
            SizedBox(
              height: 48,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: kLobbyBadgePresets.length,
                separatorBuilder: (_, __) => const SizedBox(width: 8),
                itemBuilder: (context, idx) {
                  final p = kLobbyBadgePresets[idx];
                  final selected = idx == _selectedPresetIdx;
                  return InkWell(
                    onTap: () {
                      setState(() {
                        _selectedPresetIdx = idx;
                        _badgeNameCtrl.text = p.defaultTitle;
                      });
                    },
                    borderRadius: BorderRadius.circular(12),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: selected
                            ? Color(p.accentColor).withOpacity(0.28)
                            : const Color(0xFF1E293B),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: selected
                              ? Color(p.accentColor)
                              : Colors.white24,
                          width: selected ? 2.0 : 1.0,
                        ),
                      ),
                      child: Text(
                        '${p.icon} ${p.defaultTitle}',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
            const SizedBox(height: 10),
            _buildTextField(
              controller: _badgeNameCtrl,
              label: 'Custom Badge Title',
              hint: 'e.g., Quiz Conqueror or Social Scientist',
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFF59E0B),
                  foregroundColor: const Color(0xFF0F172A),
                  padding: const EdgeInsets.symmetric(vertical: 13),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
                onPressed: _submit,
                icon: const Icon(Icons.publish_rounded),
                label: Text(
                  'Publish Activity to Quest Counter',
                  style: GoogleFonts.outfit(
                    fontWeight: FontWeight.w800,
                    fontSize: 15,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _BadgeCelebrationDialog extends StatelessWidget {
  final EarnedStudentBadge badge;
  final int xpReward;

  const _BadgeCelebrationDialog({
    required this.badge,
    required this.xpReward,
  });

  @override
  Widget build(BuildContext context) {
    final color = Color(badge.badgeColor);
    return Dialog(
      backgroundColor: const Color(0xFF0F172A),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(24),
        side: BorderSide(color: color, width: 2),
      ),
      child: Padding(
        padding: const EdgeInsets.all(22),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 76,
              height: 76,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: color.withOpacity(0.22),
                border: Border.all(color: color, width: 2.5),
                boxShadow: [
                  BoxShadow(
                    color: color.withOpacity(0.55),
                    blurRadius: 20,
                  ),
                ],
              ),
              child: Text(badge.badgeIcon, style: const TextStyle(fontSize: 38)),
            ),
            const SizedBox(height: 14),
            Text(
              '🎉 QUEST COMPLETED!',
              style: GoogleFonts.outfit(
                color: const Color(0xFFFACC15),
                fontSize: 19,
                fontWeight: FontWeight.w900,
                letterSpacing: 0.8,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              'You unlocked "${badge.badgeName}" (+$xpReward XP)!',
              textAlign: TextAlign.center,
              style: GoogleFonts.inter(
                color: Colors.white,
                fontSize: 14,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              'Equip this badge in "My Badges" to show ${badge.badgeIcon} next to your floating avatar nameplate!',
              textAlign: TextAlign.center,
              style: GoogleFonts.inter(
                color: Colors.white70,
                fontSize: 12,
              ),
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: color,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              onPressed: () => Navigator.of(context).pop(),
              child: const Text(
                'Awesome!',
                style: TextStyle(fontWeight: FontWeight.w800),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _MyBadgesDrawerSheet extends StatelessWidget {
  const _MyBadgesDrawerSheet();

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: LobbyDataService.instance,
      builder: (context, _) {
        final progress = LobbyDataService.instance.progress;
        final badges = progress.earnedBadges;
        final equippedId = progress.equippedBadge?.id;

        return Container(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.of(context).size.height * 0.78,
          ),
          margin: const EdgeInsets.fromLTRB(12, 24, 12, 12),
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: const Color(0xFF0F172A),
            borderRadius: BorderRadius.circular(24),
            border: Border.all(
              color: const Color(0xFF38BDF8).withOpacity(0.55),
              width: 1.6,
            ),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(Icons.workspace_premium_rounded,
                      color: Color(0xFFFACC15), size: 26),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'My Badges & Achievements',
                          style: GoogleFonts.outfit(
                            color: Colors.white,
                            fontSize: 18,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        Text(
                          'Level ${progress.level} Scholar • ${progress.xp} Total XP • Tap any badge to equip it on your nameplate!',
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
                    icon:
                        const Icon(Icons.close_rounded, color: Colors.white70),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              if (badges.isEmpty)
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    color: const Color(0xFF1E293B),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Column(
                    children: [
                      const Text('🛡️', style: TextStyle(fontSize: 36)),
                      const SizedBox(height: 8),
                      Text(
                        'No Badges Earned Yet',
                        style: GoogleFonts.outfit(
                          color: Colors.white,
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Visit the Reception / Quest Counter to launch & complete teacher activities and earn your first badge!',
                        textAlign: TextAlign.center,
                        style: GoogleFonts.inter(
                          color: Colors.white60,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                )
              else
                Flexible(
                  child: ListView.separated(
                    shrinkWrap: true,
                    itemCount: badges.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 10),
                    itemBuilder: (context, index) {
                      final b = badges[index];
                      final isEquipped = b.id == equippedId;
                      final color = Color(b.badgeColor);

                      return InkWell(
                        onTap: () =>
                            LobbyDataService.instance.equipBadge(b.id),
                        borderRadius: BorderRadius.circular(16),
                        child: Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: isEquipped
                                ? color.withOpacity(0.22)
                                : const Color(0xFF1E293B),
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(
                              color: isEquipped ? color : Colors.white24,
                              width: isEquipped ? 2.0 : 1.0,
                            ),
                          ),
                          child: Row(
                            children: [
                              Container(
                                width: 46,
                                height: 46,
                                alignment: Alignment.center,
                                decoration: BoxDecoration(
                                  color: color.withOpacity(0.2),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Text(
                                  b.badgeIcon,
                                  style: const TextStyle(fontSize: 24),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      b.badgeName,
                                      style: GoogleFonts.outfit(
                                        color: Colors.white,
                                        fontSize: 15,
                                        fontWeight: FontWeight.w800,
                                      ),
                                    ),
                                    Text(
                                      '${b.subject} • From "${b.sourceTitle}"',
                                      style: GoogleFonts.inter(
                                        color: Colors.white70,
                                        fontSize: 11.5,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 10, vertical: 5),
                                decoration: BoxDecoration(
                                  color: isEquipped
                                      ? const Color(0xFF10B981)
                                      : Colors.white12,
                                  borderRadius: BorderRadius.circular(99),
                                ),
                                child: Text(
                                  isEquipped ? '✓ Equipped' : 'Equip',
                                  style: GoogleFonts.inter(
                                    color: Colors.white,
                                    fontSize: 11,
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                              ),
                            ],
                          ),
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

// ═══════════════════════════════════════════════════════════════════════════
//  FEATURE 2: SUBJECT-LABELED LARGE TREASURE CHESTS (GOOGLE DRIVE VAULT)
// ═══════════════════════════════════════════════════════════════════════════

class _SubjectChestModalSheet extends StatelessWidget {
  final String chestId;
  final bool isFaculty;

  const _SubjectChestModalSheet({
    required this.chestId,
    required this.isFaculty,
  });

  Future<void> _openReviewerItem(
    BuildContext context,
    LobbyReviewerItem item,
    Color accentColor,
  ) async {
    await LobbyDataService.instance.markReviewerLaunched(item.id);

    // 1. If this is an HTML Reviewer from the Google Drive Reviewer Folder (`1EFX9aylAeSRmDWU7OeFIPa0llAMD8wC5`),
    //    stream it directly inside the In-App HTML Presentation Streamer!
    if (item.isFromDrive && item.isHtmlReviewer && item.driveFileId != null) {
      if (!context.mounted) return;
      await showDialog<void>(
        context: context,
        builder: (ctx) => _LobbyHtmlReviewerStreamerDialog(
          item: item,
          accentColor: accentColor,
        ),
      );
      return;
    }

    // 2. If it's a web link or Google Drive PPTX/PDF download URL, launch or show options
    final content = item.urlOrContent.trim();
    if (content.startsWith('http://') || content.startsWith('https://')) {
      final uri = Uri.tryParse(content);
      if (uri != null) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
        return;
      }
    }

    // 3. Otherwise show the built-in RPG Study Scroll Reader Dialog
    if (!context.mounted) return;
    await showDialog<void>(
      context: context,
      builder: (ctx) => Dialog(
        backgroundColor: const Color(0xFF0F172A),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: BorderSide(color: accentColor, width: 1.6),
        ),
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.of(ctx).size.height * 0.84,
            maxWidth: 520,
          ),
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding:
                          const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: accentColor.withOpacity(0.22),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        '${item.subject} • ${item.fileType}',
                        style: GoogleFonts.outfit(
                          color: Colors.white,
                          fontSize: 11,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                    const Spacer(),
                    IconButton(
                      onPressed: () => Navigator.of(ctx).pop(),
                      icon:
                          const Icon(Icons.close_rounded, color: Colors.white70),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  item.title,
                  style: GoogleFonts.outfit(
                    color: Colors.white,
                    fontSize: 17,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 8),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: const Color(0xFF1E293B),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Text(
                    item.urlOrContent,
                    style: GoogleFonts.inter(
                      color: Colors.white.withOpacity(0.92),
                      fontSize: 13,
                      height: 1.5,
                    ),
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  item.summary,
                  style: GoogleFonts.inter(
                    color: Colors.white60,
                    fontSize: 11.5,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _completeReviewerItem(
    BuildContext context,
    LobbyReviewerItem item,
  ) async {
    final earned = await LobbyDataService.instance.completeReviewer(item);
    if (earned == null || !context.mounted) return;
    HapticFeedback.heavyImpact();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        backgroundColor: const Color(0xFF065F46),
        behavior: SnackBarBehavior.floating,
        content: Text(
          '🎉 Reviewer Done! +${item.xpReward} XP added to your character progress!',
          style: const TextStyle(
              color: Colors.white, fontWeight: FontWeight.w800),
        ),
      ),
    );
  }

  Future<void> _openOutlineExtractorForDriveItem(
    BuildContext context,
    LobbyReviewerItem item,
    Color accentColor,
  ) async {
    if (item.driveFileId == null) return;
    await showDialog<void>(
      context: context,
      builder: (ctx) => _LobbyReviewerOutlineDialog(
        item: item,
        accentColor: accentColor,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: LobbyDataService.instance,
      builder: (context, _) {
        final service = LobbyDataService.instance;
        final chests = service.subjectChests;
        final chest = chests.firstWhere(
          (c) => c.id == chestId,
          orElse: () => chests.isNotEmpty
              ? chests.first
              : const SubjectChest(
                  id: 'empty',
                  subjectName: 'SUBJECT',
                  colorValue: 0xFF38BDF8,
                  reviewers: [],
                ),
        );
        final accent = Color(chest.colorValue);
        final driveCount =
            chest.reviewers.where((r) => r.isFromDrive).length;

        return Container(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.of(context).size.height * 0.86,
          ),
          margin: const EdgeInsets.fromLTRB(12, 24, 12, 12),
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: const Color(0xFF0F172A),
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: accent, width: 1.8),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: accent.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: accent),
                    ),
                    child: const Text('📦', style: TextStyle(fontSize: 22)),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '${chest.subjectName} Reviewer Chest',
                          style: GoogleFonts.outfit(
                            color: Colors.white,
                            fontSize: 18,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        Text(
                          chest.fullTitle.isNotEmpty
                              ? '${chest.fullTitle} • ${chest.reviewers.length} file(s) ($driveCount from Google Drive)'
                              : '${chest.reviewers.length} Reviewer file(s) ($driveCount from Google Drive)',
                          style: GoogleFonts.inter(
                            color: Colors.white70,
                            fontSize: 11.5,
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (service.isSyncingDriveReviewers)
                    const Padding(
                      padding: EdgeInsets.only(right: 8),
                      child: SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Color(0xFF38BDF8),
                        ),
                      ),
                    ),
                  IconButton(
                    onPressed: () => Navigator.of(context).pop(),
                    icon:
                        const Icon(Icons.close_rounded, color: Colors.white70),
                  ),
                ],
              ),
              if (isFaculty) ...[
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(
                      child: ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: accent,
                          foregroundColor: Colors.white,
                        ),
                        onPressed: () => showModalBottomSheet<void>(
                          context: context,
                          isScrollControlled: true,
                          backgroundColor: Colors.transparent,
                          builder: (_) =>
                              _AddReviewerToChestSheet(chest: chest),
                        ),
                        icon: const Icon(Icons.add_link_rounded, size: 17),
                        label: const Text(
                          '+ Add Reviewer Link',
                          style: TextStyle(
                              fontSize: 12, fontWeight: FontWeight.w800),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.white,
                        side: const BorderSide(color: Colors.white38),
                      ),
                      onPressed: () => showModalBottomSheet<void>(
                        context: context,
                        isScrollControlled: true,
                        backgroundColor: Colors.transparent,
                        builder: (_) =>
                            _AddOrRenameSubjectChestSheet(existingChest: chest),
                      ),
                      icon: const Icon(Icons.edit_rounded, size: 16),
                      label: const Text('Rename / Add Chest',
                          style: TextStyle(fontSize: 11.5)),
                    ),
                  ],
                ),
              ],
              const SizedBox(height: 12),
              Flexible(
                child: chest.reviewers.isEmpty
                    ? Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(22),
                        decoration: BoxDecoration(
                          color: const Color(0xFF1E293B).withOpacity(0.65),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: Colors.white12),
                        ),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Text('📦', style: TextStyle(fontSize: 34)),
                            const SizedBox(height: 8),
                            Text(
                              'No Reviewer Links in ${chest.subjectName} Yet',
                              style: GoogleFonts.outfit(
                                color: Colors.white,
                                fontSize: 15,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              isFaculty
                                  ? 'Tap "+ Add Reviewer Link" above to post a Reviewer URL or Study Notes that students can launch and Mark as Done (+XP).'
                                  : 'When your teacher posts a Reviewer Link for ${chest.subjectName}, you can launch it here and Mark as Done to level up your character!',
                              textAlign: TextAlign.center,
                              style: GoogleFonts.inter(
                                color: Colors.white60,
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                      )
                    : ListView.separated(
                        shrinkWrap: true,
                        itemCount: chest.reviewers.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 10),
                        itemBuilder: (context, index) {
                          final rev = chest.reviewers[index];
                          final isHtmlDrive =
                              rev.isFromDrive && rev.isHtmlReviewer;
                          final isLaunched = service.progress.launchedReviewerIds
                              .contains(rev.id);
                          final isDone = service.progress.completedReviewerIds
                              .contains(rev.id);

                          return Container(
                            padding: const EdgeInsets.all(14),
                            decoration: BoxDecoration(
                              color: const Color(0xFF1E293B),
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(
                                color: isDone
                                    ? const Color(0xFF10B981).withOpacity(0.65)
                                    : accent.withOpacity(0.45),
                                width: 1.3,
                              ),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Container(
                                      width: 40,
                                      height: 40,
                                      alignment: Alignment.center,
                                      decoration: BoxDecoration(
                                        color: accent.withOpacity(0.18),
                                        borderRadius: BorderRadius.circular(10),
                                      ),
                                      child: Text(
                                        isHtmlDrive
                                            ? '📺'
                                            : (rev.fileType == 'PDF' ||
                                                    rev.fileType == 'PPTX'
                                                ? '📄'
                                                : (rev.fileType == 'LINK'
                                                    ? '🔗'
                                                    : '📜')),
                                        style: const TextStyle(fontSize: 20),
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Row(
                                            children: [
                                              if (rev.weekGroup != null &&
                                                  rev.weekGroup!.isNotEmpty) ...[
                                                Container(
                                                  padding:
                                                      const EdgeInsets.symmetric(
                                                          horizontal: 6,
                                                          vertical: 2),
                                                  decoration: BoxDecoration(
                                                    color:
                                                        accent.withOpacity(0.22),
                                                    borderRadius:
                                                        BorderRadius.circular(6),
                                                  ),
                                                  child: Text(
                                                    rev.weekGroup!,
                                                    style: GoogleFonts.inter(
                                                      color: Colors.white,
                                                      fontSize: 9.5,
                                                      fontWeight:
                                                          FontWeight.w800,
                                                    ),
                                                  ),
                                                ),
                                                const SizedBox(width: 6),
                                              ],
                                              Expanded(
                                                child: Text(
                                                  rev.title,
                                                  style: GoogleFonts.outfit(
                                                    color: Colors.white,
                                                    fontSize: 14.5,
                                                    fontWeight: FontWeight.w700,
                                                  ),
                                                ),
                                              ),
                                              Container(
                                                padding:
                                                    const EdgeInsets.symmetric(
                                                        horizontal: 7,
                                                        vertical: 2),
                                                decoration: BoxDecoration(
                                                  color: const Color(0xFFFACC15)
                                                      .withOpacity(0.18),
                                                  borderRadius:
                                                      BorderRadius.circular(8),
                                                ),
                                                child: Text(
                                                  '+${rev.xpReward} XP',
                                                  style: GoogleFonts.inter(
                                                    color:
                                                        const Color(0xFFFDE047),
                                                    fontSize: 10,
                                                    fontWeight: FontWeight.w800,
                                                  ),
                                                ),
                                              ),
                                              if (isDone) ...[
                                                const SizedBox(width: 5),
                                                const Icon(
                                                  Icons.check_circle_rounded,
                                                  color: Color(0xFF34D399),
                                                  size: 18,
                                                ),
                                              ],
                                              if (isFaculty) ...[
                                                const SizedBox(width: 4),
                                                InkWell(
                                                  onTap: () => service
                                                      .deleteReviewerFromChest(
                                                    chestId: chest.id,
                                                    reviewerId: rev.id,
                                                  ),
                                                  borderRadius:
                                                      BorderRadius.circular(8),
                                                  child: const Padding(
                                                    padding: EdgeInsets.all(4),
                                                    child: Icon(
                                                      Icons
                                                          .delete_outline_rounded,
                                                      color: Colors.redAccent,
                                                      size: 18,
                                                    ),
                                                  ),
                                                ),
                                              ],
                                            ],
                                          ),
                                          const SizedBox(height: 3),
                                          Text(
                                            rev.summary,
                                            maxLines: 2,
                                            overflow: TextOverflow.ellipsis,
                                            style: GoogleFonts.inter(
                                              color: Colors.white70,
                                              fontSize: 11.5,
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
                                      child: OutlinedButton.icon(
                                        style: OutlinedButton.styleFrom(
                                          foregroundColor: accent,
                                          side: BorderSide(color: accent),
                                          padding: const EdgeInsets.symmetric(
                                              vertical: 8),
                                        ),
                                        onPressed: () => _openReviewerItem(
                                            context, rev, accent),
                                        icon: Icon(
                                          isHtmlDrive
                                              ? Icons.play_circle_fill_rounded
                                              : Icons.open_in_new_rounded,
                                          size: 15,
                                        ),
                                        label: Text(
                                          isHtmlDrive
                                              ? 'Stream Slides'
                                              : 'Launch Reviewer',
                                          style: const TextStyle(
                                              fontSize: 11.5,
                                              fontWeight: FontWeight.w800),
                                        ),
                                      ),
                                    ),
                                    if (isHtmlDrive) ...[
                                      const SizedBox(width: 6),
                                      OutlinedButton(
                                        style: OutlinedButton.styleFrom(
                                          foregroundColor:
                                              const Color(0xFF38BDF8),
                                          side: const BorderSide(
                                              color: Color(0xFF38BDF8)),
                                          padding: const EdgeInsets.symmetric(
                                              horizontal: 8, vertical: 8),
                                        ),
                                        onPressed: () =>
                                            _openOutlineExtractorForDriveItem(
                                                context, rev, accent),
                                        child: const Text(
                                          '.TXT',
                                          style: TextStyle(
                                              fontSize: 11,
                                              fontWeight: FontWeight.w800),
                                        ),
                                      ),
                                    ],
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: ElevatedButton.icon(
                                        style: ElevatedButton.styleFrom(
                                          backgroundColor: isDone
                                              ? const Color(0xFF065F46)
                                              : (isLaunched
                                                  ? const Color(0xFF10B981)
                                                  : const Color(0xFF334155)),
                                          foregroundColor: Colors.white,
                                          padding: const EdgeInsets.symmetric(
                                              vertical: 8),
                                        ),
                                        onPressed: (!isDone && isLaunched)
                                            ? () => _completeReviewerItem(
                                                context, rev)
                                            : null,
                                        icon: Icon(
                                          isDone
                                              ? Icons.verified_rounded
                                              : (isLaunched
                                                  ? Icons.task_alt_rounded
                                                  : Icons.lock_outline_rounded),
                                          size: 15,
                                        ),
                                        label: Text(
                                          isDone
                                              ? 'Completed'
                                              : (isLaunched
                                                  ? 'Mark as Done'
                                                  : 'Launch First'),
                                          style: const TextStyle(
                                              fontSize: 11.5,
                                              fontWeight: FontWeight.w800),
                                        ),
                                      ),
                                    ),
                                  ],
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

/// Streams a Google Drive `.html` Reviewer inside the School Lobby using `WebViewWidget`!
class _LobbyHtmlReviewerStreamerDialog extends StatefulWidget {
  final LobbyReviewerItem item;
  final Color accentColor;

  const _LobbyHtmlReviewerStreamerDialog({
    required this.item,
    required this.accentColor,
  });

  @override
  State<_LobbyHtmlReviewerStreamerDialog> createState() =>
      _LobbyHtmlReviewerStreamerDialogState();
}

class _LobbyHtmlReviewerStreamerDialogState
    extends State<_LobbyHtmlReviewerStreamerDialog> {
  WebViewController? _webController;
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadHtmlFromDrive();
  }

  Future<void> _loadHtmlFromDrive() async {
    try {
      final rawHtml = await ApiService.instance
          .fetchRawHtmlContent(widget.item.driveFileId!);
      final controller = WebViewController()
        ..setJavaScriptMode(JavaScriptMode.unrestricted)
        ..setBackgroundColor(const Color(0xFF0F172A))
        ..loadHtmlString(rawHtml);
      if (mounted) {
        setState(() {
          _webController = controller;
          _loading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = e.toString();
          _loading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog.fullscreen(
      backgroundColor: const Color(0xFF090E1A),
      child: SafeArea(
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: const Color(0xFF0F172A),
                border: Border(
                  bottom: BorderSide(
                      color: widget.accentColor.withOpacity(0.55), width: 1.5),
                ),
              ),
              child: Row(
                children: [
                  const Text('📺', style: TextStyle(fontSize: 20)),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          widget.item.title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: GoogleFonts.outfit(
                            color: Colors.white,
                            fontSize: 15,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        Text(
                          '${widget.item.subject} • MIS-SHS Interactive HTML Reviewer',
                          style: GoogleFonts.inter(
                            color: Colors.white60,
                            fontSize: 11,
                          ),
                        ),
                      ],
                    ),
                  ),
                  TextButton.icon(
                    onPressed: () => Navigator.of(context).pop(),
                    icon:
                        const Icon(Icons.close_rounded, color: Colors.white70),
                    label: const Text(
                      'Close',
                      style: TextStyle(
                          color: Colors.white, fontWeight: FontWeight.w700),
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: _loading
                  ? Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          CircularProgressIndicator(color: widget.accentColor),
                          const SizedBox(height: 12),
                          Text(
                            'Streaming HTML Reviewer from Google Drive...',
                            style: GoogleFonts.inter(color: Colors.white70),
                          ),
                        ],
                      ),
                    )
                  : _error != null
                      ? Center(
                          child: Padding(
                            padding: const EdgeInsets.all(24),
                            child: Text(
                              'Could not load HTML presentation: $_error',
                              style: const TextStyle(color: Colors.redAccent),
                            ),
                          ),
                        )
                      : WebViewWidget(controller: _webController!),
            ),
          ],
        ),
      ),
    );
  }
}

/// Extracts and displays the `.TXT` Study Outline from a Google Drive `.html` Reviewer!
class _LobbyReviewerOutlineDialog extends StatefulWidget {
  final LobbyReviewerItem item;
  final Color accentColor;

  const _LobbyReviewerOutlineDialog({
    required this.item,
    required this.accentColor,
  });

  @override
  State<_LobbyReviewerOutlineDialog> createState() =>
      _LobbyReviewerOutlineDialogState();
}

class _LobbyReviewerOutlineDialogState
    extends State<_LobbyReviewerOutlineDialog> {
  String _outlineText = '';
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _extract();
  }

  Future<void> _extract() async {
    try {
      final rawHtml = await ApiService.instance
          .fetchRawHtmlContent(widget.item.driveFileId!);
      final extracted = ReviewerOutlineExtractor.extractOutline(
        rawHtml: rawHtml,
        reviewerTitle: widget.item.title,
        subjectName: widget.item.subject,
      );
      if (mounted) {
        setState(() {
          _outlineText = extracted;
          _loading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _outlineText = 'Failed to extract study outline: $e';
          _loading = false;
        });
      }
    }
  }

  Future<void> _shareTxtFile() async {
    if (_outlineText.isEmpty) return;
    try {
      final dir = await getTemporaryDirectory();
      final cleanName =
          ReviewerOutlineExtractor.buildTxtFileName(widget.item.title);
      final file = File('${dir.path}/$cleanName');
      await file.writeAsString(_outlineText);
      await Share.shareXFiles([XFile(file.path)], text: widget.item.title);
    } catch (_) {
      await Clipboard.setData(ClipboardData(text: _outlineText));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: const Color(0xFF0F172A),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: BorderSide(color: widget.accentColor, width: 1.6),
      ),
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.80,
          maxWidth: 520,
        ),
        child: Padding(
          padding: const EdgeInsets.all(18),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Text('📝', style: TextStyle(fontSize: 20)),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      '${widget.item.title} • Study Outline (.TXT)',
                      style: GoogleFonts.outfit(
                        color: Colors.white,
                        fontSize: 15.5,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.of(context).pop(),
                    icon:
                        const Icon(Icons.close_rounded, color: Colors.white70),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Flexible(
                child: _loading
                    ? const Center(
                        child: Padding(
                          padding: EdgeInsets.all(32),
                          child: CircularProgressIndicator(),
                        ),
                      )
                    : Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: const Color(0xFF1E293B),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: SingleChildScrollView(
                          child: SelectableText(
                            _outlineText,
                            style: GoogleFonts.jetBrainsMono(
                              color: Colors.white.withOpacity(0.92),
                              fontSize: 11.5,
                              height: 1.45,
                            ),
                          ),
                        ),
                      ),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.white,
                        side: const BorderSide(color: Colors.white38),
                      ),
                      onPressed: _loading
                          ? null
                          : () async {
                              await Clipboard.setData(
                                  ClipboardData(text: _outlineText));
                              if (context.mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                      content: Text(
                                          '📋 Copied study outline to clipboard!')),
                                );
                              }
                            },
                      icon: const Icon(Icons.copy_rounded, size: 16),
                      label: const Text('Copy Text'),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: widget.accentColor,
                        foregroundColor: Colors.white,
                      ),
                      onPressed: _loading ? null : _shareTxtFile,
                      icon: const Icon(Icons.download_rounded, size: 16),
                      label: const Text('Save / Share .TXT'),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _AddReviewerToChestSheet extends StatefulWidget {
  final SubjectChest chest;

  const _AddReviewerToChestSheet({required this.chest});

  @override
  State<_AddReviewerToChestSheet> createState() =>
      _AddReviewerToChestSheetState();
}

class _AddReviewerToChestSheetState extends State<_AddReviewerToChestSheet> {
  final _titleCtrl = TextEditingController();
  final _contentCtrl = TextEditingController(text: 'https://');
  final _summaryCtrl = TextEditingController();
  final _xpCtrl = TextEditingController(text: '50');
  String _fileType = 'LINK';

  @override
  void dispose() {
    _titleCtrl.dispose();
    _contentCtrl.dispose();
    _summaryCtrl.dispose();
    _xpCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_titleCtrl.text.trim().isEmpty || _contentCtrl.text.trim().isEmpty) {
      return;
    }
    final xp = int.tryParse(_xpCtrl.text.trim()) ?? 50;
    await LobbyDataService.instance.addReviewerToChest(
      chestId: widget.chest.id,
      title: _titleCtrl.text.trim(),
      fileType: _fileType,
      urlOrContent: _contentCtrl.text.trim(),
      summary: _summaryCtrl.text.trim().isEmpty
          ? 'Teacher added reviewer link for ${widget.chest.subjectName}.'
          : _summaryCtrl.text.trim(),
      uploadedBy: 'Faculty',
      xpReward: xp,
    );
    if (mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;
    return Container(
      margin: EdgeInsets.fromLTRB(12, 24, 12, 12 + bottomInset),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: const Color(0xFF0F172A),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Color(widget.chest.colorValue)),
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '📦 Add Reviewer Link to ${widget.chest.subjectName} Chest',
              style: GoogleFonts.outfit(
                color: Colors.white,
                fontSize: 17,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 12),
            _buildTextField(
              controller: _titleCtrl,
              label: 'Reviewer Title',
              hint: 'e.g., Week 4 Legislative Branch Reviewer',
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  flex: 3,
                  child: DropdownButtonFormField<String>(
                    value: _fileType,
                    dropdownColor: const Color(0xFF1E293B),
                    style: const TextStyle(color: Colors.white, fontSize: 13),
                    decoration: _inputDecoration('Reviewer Type'),
                    items: const [
                      DropdownMenuItem(
                          value: 'LINK',
                          child: Text('Reviewer Web / Drive Link')),
                      DropdownMenuItem(
                          value: 'PDF', child: Text('PDF / Document Link')),
                      DropdownMenuItem(
                          value: 'NOTES',
                          child: Text('Study Notes (In-App Reader)')),
                    ],
                    onChanged: (v) {
                      if (v != null) setState(() => _fileType = v);
                    },
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  flex: 2,
                  child: _buildTextField(
                    controller: _xpCtrl,
                    label: 'XP Reward',
                    hint: '50',
                    keyboardType: TextInputType.number,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            _buildTextField(
              controller: _contentCtrl,
              label: _fileType == 'NOTES'
                  ? 'Study Notes Content'
                  : 'Reviewer URL Link',
              hint: _fileType == 'NOTES'
                  ? 'Paste key bullet points and definitions...'
                  : 'https://drive.google.com/...',
              maxLines: _fileType == 'NOTES' ? 4 : 1,
            ),
            const SizedBox(height: 10),
            _buildTextField(
              controller: _summaryCtrl,
              label: 'Short Description',
              hint: 'Brief summary shown in chest inventory',
            ),
            const SizedBox(height: 14),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Color(widget.chest.colorValue),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                ),
                onPressed: _save,
                icon: const Icon(Icons.cloud_upload_rounded, size: 18),
                label: const Text(
                  'Save & Sync Reviewer Link to Chest',
                  style: TextStyle(fontWeight: FontWeight.w800),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _AddOrRenameSubjectChestSheet extends StatefulWidget {
  final SubjectChest? existingChest;

  const _AddOrRenameSubjectChestSheet({this.existingChest});

  @override
  State<_AddOrRenameSubjectChestSheet> createState() =>
      _AddOrRenameSubjectChestSheetState();
}

class _AddOrRenameSubjectChestSheetState
    extends State<_AddOrRenameSubjectChestSheet> {
  late final TextEditingController _nameCtrl;
  int _selectedColor = 0xFF38BDF8;
  bool _createNew = false;

  static const List<int> _palette = [
    0xFF38BDF8,
    0xFFF59E0B,
    0xFFA855F7,
    0xFF10B981,
    0xFFEC4899,
    0xFFF97316,
  ];

  @override
  void initState() {
    super.initState();
    _nameCtrl =
        TextEditingController(text: widget.existingChest?.subjectName ?? '');
    _selectedColor = widget.existingChest?.colorValue ?? _palette.first;
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final name = _nameCtrl.text.trim();
    if (name.isEmpty) return;
    await LobbyDataService.instance.addOrRenameSubjectChest(
      existingChestId: _createNew ? null : widget.existingChest?.id,
      subjectName: name,
      colorValue: _selectedColor,
    );
    if (mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;
    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.86,
      ),
      margin: EdgeInsets.fromLTRB(12, 24, 12, 12 + bottomInset),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: const Color(0xFF0F172A),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Color(_selectedColor)),
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              _createNew
                  ? '📦 Add New Subject Chest to Map'
                  : '✏️ Rename Subject Chest',
              style: GoogleFonts.outfit(
                color: Colors.white,
                fontSize: 17,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 8),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text(
                'Create as a brand-new Subject Chest on the map',
                style: TextStyle(color: Colors.white70, fontSize: 12.5),
              ),
              value: _createNew,
              onChanged: (v) => setState(() {
                _createNew = v;
                if (v) _nameCtrl.clear();
              }),
            ),
            _buildTextField(
              controller: _nameCtrl,
              label: 'Subject Code (Floating Banner Label)',
              hint: 'e.g., PKLP, PPG, UCSP',
            ),
            const SizedBox(height: 12),
            Row(
              children: _palette.map((c) {
                final selected = c == _selectedColor;
                return Padding(
                  padding: const EdgeInsets.only(right: 10),
                  child: InkWell(
                    onTap: () => setState(() => _selectedColor = c),
                    child: Container(
                      width: 32,
                      height: 32,
                      decoration: BoxDecoration(
                        color: Color(c),
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: selected ? Colors.white : Colors.transparent,
                          width: 2.5,
                        ),
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Color(_selectedColor),
                  foregroundColor: Colors.white,
                ),
                onPressed: _submit,
                child: Text(_createNew ? 'Add Subject Chest' : 'Save Changes'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════
//  FEATURE 3: WALKING & TALKING AI SUBJECT TEACHERS (`msitarzewski/agency-agents`)
//  (`PKLP`, `PPG`, `UCSP` — LIVE STUDY CHAT + 24H EXAM ROTATION)
// ═══════════════════════════════════════════════════════════════════════════

class _SmallMysteryChestQuizSheet extends StatefulWidget {
  final String smallChestId;
  final String smallChestLabel;
  final String playerName;

  const _SmallMysteryChestQuizSheet({
    required this.smallChestId,
    required this.smallChestLabel,
    this.playerName = 'Scholar',
  });

  @override
  State<_SmallMysteryChestQuizSheet> createState() =>
      _SmallMysteryChestQuizSheetState();
}

class _SmallMysteryChestQuizSheetState
    extends State<_SmallMysteryChestQuizSheet> {
  late MiniQuizQuestion _question;
  int? _selectedOption;
  bool _answeredWrong = false;
  bool _answeredCorrect = false;
  int _activeTabIndex = 0; // 0 = 💬 Talk & Study Chat, 1 = 📝 Daily Exam (+25 XP)
  final TextEditingController _chatCtrl = TextEditingController();
  final ScrollController _chatScrollCtrl = ScrollController();

  @override
  void initState() {
    super.initState();
    _question = LobbyDataService.instance
        .pickRandomQuestionForSmallChest(widget.smallChestId);
    // Seed initial greeting in chat history
    LobbyAgencyAgentsService.instance.chatHistoryForAgent(
      widget.smallChestId,
      studentName:
          widget.playerName.trim().isEmpty ? 'Scholar' : widget.playerName,
    );
  }

  @override
  void dispose() {
    _chatCtrl.dispose();
    _chatScrollCtrl.dispose();
    super.dispose();
  }

  void _sendChatMessage(String rawText) {
    final clean = rawText.trim();
    if (clean.isEmpty) return;
    HapticFeedback.selectionClick();
    LobbyAgencyAgentsService.instance.sendStudentMessage(
      agentId: widget.smallChestId,
      studentMessage: clean,
      studentName:
          widget.playerName.trim().isEmpty ? 'Scholar' : widget.playerName,
    );
    _chatCtrl.clear();
    setState(() {});
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_chatScrollCtrl.hasClients) {
        _chatScrollCtrl.animateTo(
          _chatScrollCtrl.position.maxScrollExtent,
          duration: const Duration(milliseconds: 220),
          curve: Curves.easeOut,
        );
      }
    });
  }

  Future<void> _selectOption(int index) async {
    // Strictly lock the student's answer on the first click!
    if (_selectedOption != null) return;
    setState(() {
      _selectedOption = index;
    });

    final isCorrect =
        await LobbyDataService.instance.submitSmallChestQuizAnswer(
      smallChestId: widget.smallChestId,
      question: _question,
      selectedIndex: index,
    );

    if (!mounted) return;
    if (isCorrect) {
      HapticFeedback.heavyImpact();
      LobbyAudioService.instance.playQuizCorrect();
      setState(() {
        _answeredCorrect = true;
        _answeredWrong = false;
      });
    } else {
      HapticFeedback.vibrate();
      LobbyAudioService.instance.playQuizWrong();
      setState(() {
        _answeredWrong = true;
      });
    }
  }

  Widget _buildTabPill({
    required int index,
    required String label,
    required Color accentCol,
  }) {
    final selected = _activeTabIndex == index;
    return Expanded(
      child: InkWell(
        onTap: () {
          HapticFeedback.selectionClick();
          setState(() => _activeTabIndex = index);
        },
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 9, horizontal: 10),
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: selected
                ? accentCol.withValues(alpha: 0.26)
                : const Color(0xFF1E293B),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: selected ? accentCol : Colors.white12,
              width: selected ? 1.6 : 1.0,
            ),
          ),
          child: Text(
            label,
            style: GoogleFonts.outfit(
              color: selected ? Colors.white : Colors.white70,
              fontSize: 12.5,
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTalkAndStudyTab(
    BuildContext context, {
    required AiSubjectMentorNpc? mentor,
    required AgencyPersonaSpec? agencySpec,
    required Color accentCol,
  }) {
    final studentDisplayName =
        widget.playerName.trim().isEmpty ? 'Scholar' : widget.playerName;
    final history = LobbyAgencyAgentsService.instance.chatHistoryForAgent(
      widget.smallChestId,
      studentName: studentDisplayName,
    );
    final quickPrompts = LobbyAgencyAgentsService.instance
        .quickPromptsForAgent(widget.smallChestId);

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Agency-Agents Identity, Personality Vibe & Core Mission Banner
        if (agencySpec != null)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFF1E293B),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: accentCol.withValues(alpha: 0.45)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Text('🧠 ', style: TextStyle(fontSize: 14)),
                    Expanded(
                      child: Text(
                        'AGENCY PERSONA • ${agencySpec.subjectCode} SPECIALIST',
                        style: GoogleFonts.outfit(
                          color: const Color(0xFFFDE047),
                          fontSize: 11,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 0.6,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  agencySpec.personalityVibe,
                  style: GoogleFonts.inter(
                    color: Colors.white.withValues(alpha: 0.9),
                    fontSize: 11.5,
                    height: 1.35,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '🎯 Mission: ${agencySpec.coreMission}',
                  style: GoogleFonts.inter(
                    color: const Color(0xFF38BDF8),
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        const SizedBox(height: 10),

        // Quick Study Prompt Chips
        Text(
          'QUICK STUDY TOPICS (TAP TO ASK):',
          style: GoogleFonts.outfit(
            color: Colors.white60,
            fontSize: 10.5,
            fontWeight: FontWeight.w800,
            letterSpacing: 0.6,
          ),
        ),
        const SizedBox(height: 6),
        Wrap(
          spacing: 6,
          runSpacing: 6,
          children: quickPrompts.map((prompt) {
            return ActionChip(
              backgroundColor: const Color(0xFF1E293B),
              side: BorderSide(color: accentCol.withValues(alpha: 0.5)),
              label: Text(
                prompt,
                style: GoogleFonts.inter(
                  color: Colors.white,
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                ),
              ),
              onPressed: () => _sendChatMessage(prompt),
            );
          }).toList(),
        ),
        const SizedBox(height: 10),

        // Live Conversation Feed
        Container(
          constraints: const BoxConstraints(minHeight: 150, maxHeight: 230),
          width: double.infinity,
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: const Color(0xFF090E1A),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: Colors.white12),
          ),
          child: ListView.separated(
            controller: _chatScrollCtrl,
            shrinkWrap: true,
            itemCount: history.length,
            separatorBuilder: (_, __) => const SizedBox(height: 8),
            itemBuilder: (ctx, idx) {
              final msg = history[idx];
              final isAgent = msg.isTeacher;
              final senderLabel = isAgent
                  ? '🤖 ${mentor?.name ?? agencySpec?.name ?? 'AI Teacher'}'
                  : '🧑 $studentDisplayName';
              return Align(
                alignment:
                    isAgent ? Alignment.centerLeft : Alignment.centerRight,
                child: Container(
                  constraints: const BoxConstraints(maxWidth: 320),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
                  decoration: BoxDecoration(
                    color: isAgent
                        ? const Color(0xFF1E293B)
                        : accentCol.withValues(alpha: 0.28),
                    borderRadius: BorderRadius.circular(13),
                    border: Border.all(
                      color: isAgent
                          ? accentCol.withValues(alpha: 0.45)
                          : accentCol,
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        senderLabel,
                        style: GoogleFonts.outfit(
                          color: isAgent
                              ? const Color(0xFFFDE047)
                              : const Color(0xFF38BDF8),
                          fontSize: 10.5,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        msg.text,
                        style: GoogleFonts.inter(
                          color: Colors.white,
                          fontSize: 12,
                          height: 1.38,
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
        const SizedBox(height: 10),

        // Student Question / Chat Input Box
        Row(
          children: [
            Expanded(
              child: TextField(
                controller: _chatCtrl,
                style: GoogleFonts.inter(color: Colors.white, fontSize: 12.5),
                textInputAction: TextInputAction.send,
                onSubmitted: _sendChatMessage,
                decoration: InputDecoration(
                  hintText:
                      'Ask ${mentor?.name ?? 'your AI Teacher'} about ${mentor?.subjectCode ?? 'PKLP, PPG, or UCSP'}...',
                  hintStyle:
                      GoogleFonts.inter(color: Colors.white38, fontSize: 12),
                  filled: true,
                  fillColor: const Color(0xFF1E293B),
                  contentPadding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: Colors.white24),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: Colors.white24),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: accentCol, width: 1.5),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 8),
            ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: accentCol,
                foregroundColor: Colors.white,
                padding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              onPressed: () => _sendChatMessage(_chatCtrl.text),
              icon: const Icon(Icons.send_rounded, size: 16),
              label: Text(
                'Ask',
                style: GoogleFonts.outfit(
                  fontWeight: FontWeight.w800,
                  fontSize: 12.5,
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildDailyExamTab(
    BuildContext context, {
    required LobbyDataService service,
    required int remainingSec,
    required AiSubjectMentorNpc? mentor,
    required Color accentCol,
  }) {
    if (remainingSec > 0 && _selectedOption == null) {
      final formattedWait =
          service.smallChestFormattedCooldown(widget.smallChestId);
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: const Color(0xFF1E293B),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: accentCol.withValues(alpha: 0.45)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('⏳', style: TextStyle(fontSize: 32)),
            const SizedBox(height: 8),
            Text(
              'Daily Exam Cooldown ($formattedWait)',
              textAlign: TextAlign.center,
              style: GoogleFonts.outfit(
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              'You already completed this AI Teacher\'s 24-hour exam question! Switch to the "💬 Talk & Study Chat" tab above to keep asking study questions anytime, or talk to the other AI Teachers walking around the campus.',
              textAlign: TextAlign.center,
              style: GoogleFonts.inter(
                color: Colors.white70,
                fontSize: 12,
                height: 1.4,
              ),
            ),
            const SizedBox(height: 12),
            ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: accentCol,
                foregroundColor: Colors.white,
              ),
              onPressed: () => setState(() => _activeTabIndex = 0),
              icon: const Icon(Icons.chat_bubble_outline_rounded, size: 16),
              label: const Text('Back to Talk & Study Chat'),
            ),
          ],
        ),
      );
    }

    const letters = ['A', 'B', 'C', 'D'];
    final isLocked = _selectedOption != null;

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          _question.question,
          style: GoogleFonts.outfit(
            color: Colors.white,
            fontSize: 15.5,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          isLocked
              ? '🔒 Answer locked! Options cannot be changed after clicking.'
              : '⚠️ First click locks your answer for 24 hours — choose carefully!',
          style: GoogleFonts.inter(
            color: isLocked ? Colors.white54 : const Color(0xFFFDE047),
            fontSize: 11,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 12),
        ...List.generate(_question.options.length, (idx) {
          final isSelected = _selectedOption == idx;
          final isCorrectOption = idx == _question.correctIndex;

          Color borderColor = Colors.white24;
          Color bgColor = const Color(0xFF1E293B);
          if (isLocked && isCorrectOption) {
            borderColor = const Color(0xFF10B981);
            bgColor = const Color(0xFF065F46).withValues(alpha: 0.6);
          } else if (_answeredWrong && isSelected && !isCorrectOption) {
            borderColor = const Color(0xFFEF4444);
            bgColor = const Color(0xFF7F1D1D).withValues(alpha: 0.5);
          }

          return Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: InkWell(
              onTap: isLocked ? null : () => _selectOption(idx),
              borderRadius: BorderRadius.circular(14),
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                decoration: BoxDecoration(
                  color: bgColor,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: borderColor, width: 1.4),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 26,
                      height: 26,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: Colors.white12,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        letters[idx],
                        style: GoogleFonts.outfit(
                          color: const Color(0xFFFACC15),
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        _question.options[idx],
                        style: GoogleFonts.inter(
                          color: Colors.white,
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    if (isLocked && isSelected)
                      Icon(
                        isCorrectOption
                            ? Icons.check_circle_rounded
                            : Icons.cancel_rounded,
                        color: isCorrectOption
                            ? const Color(0xFF10B981)
                            : const Color(0xFFEF4444),
                        size: 18,
                      ),
                  ],
                ),
              ),
            ),
          );
        }),
        if (_answeredWrong && !_answeredCorrect) ...[
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFF7F1D1D).withValues(alpha: 0.45),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: const Color(0xFFEF4444)),
            ),
            child: Row(
              children: [
                const Icon(Icons.lock_clock_rounded,
                    color: Color(0xFFFCA5A5), size: 22),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Answer locked! The correct answer was ${letters[_question.correctIndex]} (${_question.options[_question.correctIndex]}). This AI Teacher\'s exam refreshes in 24 hours.',
                    style: GoogleFonts.inter(
                      color: Colors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                OutlinedButton(
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.white,
                    side: const BorderSide(color: Colors.white38),
                  ),
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('Close'),
                ),
              ],
            ),
          ),
        ],
        if (_answeredCorrect) ...[
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFF065F46).withValues(alpha: 0.45),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: const Color(0xFF10B981)),
            ),
            child: Row(
              children: [
                const Text('🎉', style: TextStyle(fontSize: 22)),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Correct! +${_question.xpReward} XP added to your profile & Shop Wallet! This AI Teacher\'s exam refreshes in 24 hours.',
                    style: GoogleFonts.inter(
                      color: Colors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF10B981),
                    foregroundColor: Colors.white,
                  ),
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('Claim'),
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final service = LobbyDataService.instance;
    final remainingSec =
        service.smallChestRemainingSeconds(widget.smallChestId);
    final mentor = findAiSubjectMentor(widget.smallChestId);
    final agencySpec = LobbyAgencyAgentsService.instance
        .runtimeStateForId(widget.smallChestId)
        ?.spec;
    final accentCol = Color(mentor?.accentColor ?? 0xFFA855F7);
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;

    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.90,
      ),
      margin: EdgeInsets.fromLTRB(12, 24, 12, 16 + bottomInset),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: const Color(0xFF0F172A),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: _answeredCorrect
              ? const Color(0xFF10B981)
              : (_answeredWrong ? const Color(0xFFEF4444) : accentCol),
          width: 1.8,
        ),
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 42,
                  height: 42,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: accentCol.withValues(alpha: 0.22),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: accentCol),
                  ),
                  child: const Text('🤖', style: TextStyle(fontSize: 22)),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        mentor != null
                            ? '${mentor.name} • ${mentor.roleTitle}'
                            : widget.smallChestLabel,
                        style: GoogleFonts.outfit(
                          color: Colors.white,
                          fontSize: 15.5,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      Text(
                        mentor != null
                            ? '📚 ${mentor.fullSubjectTitle} (+${_question.xpReward} XP)'
                            : '✨ ${_question.subject} EXAM ROTATION • +${_question.xpReward} XP',
                        style: GoogleFonts.inter(
                          color: const Color(0xFFFDE047),
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  onPressed: () => Navigator.of(context).pop(),
                  icon: const Icon(Icons.close_rounded, color: Colors.white70),
                ),
              ],
            ),
            const SizedBox(height: 10),

            // 2-Tab Selector: `💬 Talk & Study Chat` vs. `📝 Daily Exam (+25 XP)`
            Row(
              children: [
                _buildTabPill(
                  index: 0,
                  label: '💬 Talk & Study Chat',
                  accentCol: accentCol,
                ),
                const SizedBox(width: 8),
                _buildTabPill(
                  index: 1,
                  label: remainingSec > 0 && _selectedOption == null
                      ? '⏳ Daily Exam (Cooldown)'
                      : '📝 Daily Exam (+${_question.xpReward} XP)',
                  accentCol: accentCol,
                ),
              ],
            ),
            const SizedBox(height: 12),

            if (_activeTabIndex == 0)
              _buildTalkAndStudyTab(
                context,
                mentor: mentor,
                agencySpec: agencySpec,
                accentCol: accentCol,
              )
            else
              _buildDailyExamTab(
                context,
                service: service,
                remainingSec: remainingSec,
                mentor: mentor,
                accentCol: accentCol,
              ),
          ],
        ),
      ),
    );
  }
}

class _TeacherCornerSheet extends StatelessWidget {
  final bool isFaculty;
  final String userName;

  const _TeacherCornerSheet({
    required this.isFaculty,
    required this.userName,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.85,
      ),
      margin: const EdgeInsets.all(14),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFF0F172A),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: const Color(0xFFFACC15), width: 1.6),
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Text('🎓', style: TextStyle(fontSize: 28)),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        "Teacher's Advisory Corner",
                        style: GoogleFonts.outfit(
                          color: const Color(0xFFFACC15),
                          fontSize: 18,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      Text(
                        'Sir Jim Mark • PKLP, PPG & UCSP Faculty Desk',
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
                  icon: const Icon(Icons.close_rounded, color: Colors.white70),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              '"Keep exploring your enrolled Reviewer Chests and testing your mastery with the PKLP, PPG, and UCSP AI Subject Mentors! Remember: consistent preparation builds confidence."',
              style: GoogleFonts.inter(
                color: Colors.white.withOpacity(0.9),
                fontSize: 13,
                fontStyle: FontStyle.italic,
              ),
            ),
            if (isFaculty) ...[
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFF59E0B),
                    foregroundColor: const Color(0xFF0F172A),
                  ),
                  onPressed: () {
                    Navigator.of(context).pop();
                    showTeacherLinkManagerModal(
                      context: context,
                      teacherName: userName,
                    );
                  },
                  icon: const Icon(Icons.link_rounded),
                  label: const Text(
                    '🔗 Open Teacher Content & Link Manager',
                    style: TextStyle(fontWeight: FontWeight.w800),
                  ),
                ),
              ),
              const SizedBox(height: 8),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    foregroundColor: const Color(0xFFFACC15),
                    side: const BorderSide(color: Color(0xFFFACC15)),
                  ),
                  onPressed: () {
                    Navigator.of(context).pop();
                    showPostActivityModal(context: context, postedBy: userName);
                  },
                  icon: const Icon(Icons.add_task_rounded),
                  label: const Text(
                    '+ Quick Post Quest Activity',
                    style: TextStyle(fontWeight: FontWeight.w800),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _BulletinBoardSheet extends StatelessWidget {
  const _BulletinBoardSheet();

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.86,
      ),
      margin: const EdgeInsets.all(14),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFF0F172A),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: const Color(0xFF38BDF8), width: 1.6),
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Text('📌', style: TextStyle(fontSize: 26)),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'MIS-SHS School Lobby Guide & Bulletin',
                    style: GoogleFonts.outfit(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                IconButton(
                  onPressed: () => Navigator.of(context).pop(),
                  icon: const Icon(Icons.close_rounded, color: Colors.white70),
                ),
              ],
            ),
            const SizedBox(height: 10),
            const _GuideRow(
              icon: '🤖',
              title: 'PKLP, PPG & UCSP AI Subject Mentors (+25 XP)',
              desc:
                  'Talk to the 8 AI Subject Mentors around the Lobby! Each Mentor asks rotating exam questions for PKLP, PPG, or UCSP once every 24 hours.',
            ),
            const SizedBox(height: 8),
            const _GuideRow(
              icon: '📚',
              title: 'Group Study & Chat Spaces in Every Room',
              desc:
                  'Every campus room has a dedicated Group Study Table where multiple students can sit together and chat using Thought Bubbles (💭)!',
            ),
            const SizedBox(height: 8),
            const _GuideRow(
              icon: '📌',
              title: 'Your Personal Classroom Table & Table Decor Shop',
              desc:
                  'In the Class Room, Row 1 Center is your exclusive Personal Table! Buy Chair Colors, Mini Lights, Frames & Props in the Campus Shop to decorate it.',
            ),
            const SizedBox(height: 8),
            const _GuideRow(
              icon: '📦',
              title: 'Enrolled Subject Chests (Google Drive Sync)',
              desc:
                  'Only active subjects from the MIS Control Sheet that you are enrolled in appear in your Reviewer Vault!',
            ),
          ],
        ),
      ),
    );
  }
}

class _GuideRow extends StatelessWidget {
  final String icon;
  final String title;
  final String desc;

  const _GuideRow({
    required this.icon,
    required this.title,
    required this.desc,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(11),
      decoration: BoxDecoration(
        color: const Color(0xFF1E293B),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(icon, style: const TextStyle(fontSize: 20)),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: GoogleFonts.outfit(
                    color: Colors.white,
                    fontSize: 13.5,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  desc,
                  style: GoogleFonts.inter(
                    color: Colors.white70,
                    fontSize: 11.5,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

InputDecoration _inputDecoration(String label, {String? hint}) {
  return InputDecoration(
    labelText: label,
    hintText: hint,
    labelStyle: const TextStyle(color: Colors.white70, fontSize: 12.5),
    hintStyle: const TextStyle(color: Colors.white38, fontSize: 12.5),
    filled: true,
    fillColor: const Color(0xFF1E293B),
    contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
    border: OutlineInputBorder(
      borderRadius: BorderRadius.circular(12),
      borderSide: const BorderSide(color: Colors.white24),
    ),
    enabledBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(12),
      borderSide: const BorderSide(color: Colors.white24),
    ),
  );
}

Widget _buildTextField({
  required TextEditingController controller,
  required String label,
  required String hint,
  int maxLines = 1,
  TextInputType? keyboardType,
}) {
  return TextField(
    controller: controller,
    maxLines: maxLines,
    keyboardType: keyboardType,
    style: const TextStyle(color: Colors.white, fontSize: 13.5),
    decoration: _inputDecoration(label, hint: hint),
  );
}

// ═══════════════════════════════════════════════════════════════════════════
//  PHASE 4: UNIFIED TEACHER CONTENT & LINK MANAGER (REVIEWERS & ACTIVITIES)
// ═══════════════════════════════════════════════════════════════════════════

Future<void> showTeacherLinkManagerModal({
  required BuildContext context,
  required String teacherName,
}) async {
  await showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (ctx) => _TeacherLinkManagerSheet(teacherName: teacherName),
  );
}

class _TeacherLinkManagerSheet extends StatefulWidget {
  final String teacherName;

  const _TeacherLinkManagerSheet({required this.teacherName});

  @override
  State<_TeacherLinkManagerSheet> createState() =>
      _TeacherLinkManagerSheetState();
}

class _TeacherLinkManagerSheetState extends State<_TeacherLinkManagerSheet> {
  int _activeTab = 0; // 0 = Reviewer Links, 1 = Activity Links
  bool _isSyncingCloud = false;

  // Reviewer Link fields
  String? _selectedChestId;
  final _revTitleCtrl = TextEditingController();
  final _revUrlCtrl = TextEditingController(text: 'https://');
  final _revSummaryCtrl = TextEditingController();
  final _revXpCtrl = TextEditingController(text: '50');
  String _revType = 'LINK';

  // Activity Link fields
  String _actSubject = 'PGP';
  final _actTitleCtrl = TextEditingController();
  final _actUrlCtrl = TextEditingController(text: 'https://');
  final _actXpCtrl = TextEditingController(text: '100');
  final _actBadgeNameCtrl = TextEditingController(text: 'Quiz Conqueror');
  int _actPresetIdx = 1;

  @override
  void initState() {
    super.initState();
    final chests = LobbyDataService.instance.subjectChests;
    if (chests.isNotEmpty) {
      _selectedChestId = chests.first.id;
      _actSubject = chests.first.subjectName;
    }
  }

  @override
  void dispose() {
    _revTitleCtrl.dispose();
    _revUrlCtrl.dispose();
    _revSummaryCtrl.dispose();
    _revXpCtrl.dispose();
    _actTitleCtrl.dispose();
    _actUrlCtrl.dispose();
    _actXpCtrl.dispose();
    _actBadgeNameCtrl.dispose();
    super.dispose();
  }

  Future<void> _addReviewerLink() async {
    final title = _revTitleCtrl.text.trim();
    final url = _revUrlCtrl.text.trim();
    final chests = LobbyDataService.instance.subjectChests;
    final chestId =
        _selectedChestId ?? (chests.isNotEmpty ? chests.first.id : null);
    if (title.isEmpty || url.isEmpty || chestId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('Please enter a Reviewer Title and Link URL.')),
      );
      return;
    }
    final xp = int.tryParse(_revXpCtrl.text.trim()) ?? 50;
    await LobbyDataService.instance.addReviewerToChest(
      chestId: chestId,
      title: title,
      fileType: _revType,
      urlOrContent: url,
      summary: _revSummaryCtrl.text.trim().isEmpty
          ? 'Teacher added Reviewer Link (+$xp XP on completion).'
          : _revSummaryCtrl.text.trim(),
      uploadedBy: widget.teacherName,
      xpReward: xp,
    );
    _revTitleCtrl.clear();
    _revUrlCtrl.text = 'https://';
    _revSummaryCtrl.clear();
    if (!mounted) return;
    HapticFeedback.mediumImpact();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        backgroundColor: const Color(0xFF065F46),
        content: Text('✅ Added Reviewer Link "$title" (+$xp XP) & synced!'),
      ),
    );
  }

  Future<void> _addActivityLink() async {
    final title = _actTitleCtrl.text.trim();
    final url = _actUrlCtrl.text.trim();
    if (title.isEmpty || url.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('Please enter an Activity Title and Link URL.')),
      );
      return;
    }
    final xp = int.tryParse(_actXpCtrl.text.trim()) ?? 100;
    final preset = kLobbyBadgePresets[_actPresetIdx];
    await LobbyDataService.instance.postActivity(
      title: title,
      subject: _actSubject,
      activityUrl: url,
      xpReward: xp,
      badgeName: _actBadgeNameCtrl.text.trim().isEmpty
          ? preset.defaultTitle
          : _actBadgeNameCtrl.text.trim(),
      badgeIcon: preset.icon,
      badgeColor: preset.accentColor,
      postedBy: widget.teacherName,
    );
    _actTitleCtrl.clear();
    _actUrlCtrl.text = 'https://';
    if (!mounted) return;
    HapticFeedback.mediumImpact();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        backgroundColor: const Color(0xFF065F46),
        content: Text('✅ Posted Activity Link "$title" (+$xp XP) & synced!'),
      ),
    );
  }

  Future<void> _syncCloudNow() async {
    setState(() => _isSyncingCloud = true);
    await LobbyDataService.instance.pushCloudManifest();
    if (!mounted) return;
    setState(() => _isSyncingCloud = false);
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        backgroundColor: Color(0xFF0284C7),
        content: Text(
            '☁️ Synced all Reviewer & Activity Links to Google Drive Cloud!'),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;
    return AnimatedBuilder(
      animation: LobbyDataService.instance,
      builder: (context, _) {
        final service = LobbyDataService.instance;
        final chests = service.subjectChests;
        final activities = service.activities;

        if (chests.isNotEmpty &&
            (_selectedChestId == null ||
                !chests.any((c) => c.id == _selectedChestId))) {
          _selectedChestId = chests.first.id;
        }
        final subjectNames =
            chests.map((c) => c.subjectName).toSet().toList();
        if (subjectNames.isEmpty) {
          subjectNames.addAll(['PGP', 'UCSP', 'PPG', 'PKLP TERM 2', 'PHILO']);
        }
        if (!subjectNames.contains(_actSubject)) {
          _actSubject = subjectNames.first;
        }

        final totalReviewers = chests.fold<int>(
          0,
          (sum, c) => sum + c.reviewers.length,
        );

        return Container(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.of(context).size.height * 0.88,
          ),
          margin: EdgeInsets.fromLTRB(12, 24, 12, 12 + bottomInset),
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: const Color(0xFF0F172A),
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: const Color(0xFFFACC15), width: 1.8),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header
              Row(
                children: [
                  Container(
                    width: 42,
                    height: 42,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: const Color(0xFFFACC15).withOpacity(0.18),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: const Color(0xFFFACC15)),
                    ),
                    child: const Text('🔗', style: TextStyle(fontSize: 20)),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Teacher Content & Link Manager',
                          style: GoogleFonts.outfit(
                            color: Colors.white,
                            fontSize: 17.5,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        Text(
                          'Add Reviewer & Activity Links that students can Launch & Mark as Done (+XP)',
                          style: GoogleFonts.inter(
                            color: Colors.white70,
                            fontSize: 11,
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    tooltip: 'Sync to Cloud',
                    onPressed: _isSyncingCloud ? null : _syncCloudNow,
                    icon: _isSyncingCloud
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Color(0xFF38BDF8),
                            ),
                          )
                        : const Icon(
                            Icons.cloud_upload_rounded,
                            color: Color(0xFF38BDF8),
                          ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.of(context).pop(),
                    icon:
                        const Icon(Icons.close_rounded, color: Colors.white70),
                  ),
                ],
              ),
              const SizedBox(height: 12),

              // 2-Tab Selector
              Row(
                children: [
                  Expanded(
                    child: InkWell(
                      onTap: () => setState(() => _activeTab = 0),
                      borderRadius: BorderRadius.circular(12),
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 10),
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: _activeTab == 0
                              ? const Color(0xFF0284C7).withOpacity(0.28)
                              : const Color(0xFF1E293B),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: _activeTab == 0
                                ? const Color(0xFF38BDF8)
                                : Colors.white24,
                            width: _activeTab == 0 ? 1.8 : 1.0,
                          ),
                        ),
                        child: Text(
                          '📚 Reviewer Links ($totalReviewers)',
                          style: GoogleFonts.outfit(
                            color: Colors.white,
                            fontSize: 13,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: InkWell(
                      onTap: () => setState(() => _activeTab = 1),
                      borderRadius: BorderRadius.circular(12),
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 10),
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: _activeTab == 1
                              ? const Color(0xFFF59E0B).withOpacity(0.25)
                              : const Color(0xFF1E293B),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: _activeTab == 1
                                ? const Color(0xFFFACC15)
                                : Colors.white24,
                            width: _activeTab == 1 ? 1.8 : 1.0,
                          ),
                        ),
                        child: Text(
                          '🎯 Activity Links (${activities.length})',
                          style: GoogleFonts.outfit(
                            color: Colors.white,
                            fontSize: 13,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),

              // Scrollable Tab Body
              Flexible(
                child: SingleChildScrollView(
                  child: _activeTab == 0
                      ? _buildReviewerLinksTab(chests, service)
                      : _buildActivityLinksTab(
                          subjectNames, activities, service),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildReviewerLinksTab(
    List<SubjectChest> chests,
    LobbyDataService service,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: const Color(0xFF1E293B).withOpacity(0.75),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: const Color(0xFF38BDF8).withOpacity(0.4)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '➕ Add New Reviewer Link to Subject Chest',
                style: GoogleFonts.outfit(
                  color: const Color(0xFF38BDF8),
                  fontSize: 14,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(
                    flex: 3,
                    child: DropdownButtonFormField<String>(
                      value: _selectedChestId,
                      dropdownColor: const Color(0xFF1E293B),
                      style:
                          const TextStyle(color: Colors.white, fontSize: 12.5),
                      decoration: _inputDecoration('Subject Chest'),
                      items: chests
                          .map(
                            (c) => DropdownMenuItem(
                              value: c.id,
                              child: Text(c.subjectName),
                            ),
                          )
                          .toList(),
                      onChanged: (v) {
                        if (v != null) setState(() => _selectedChestId = v);
                      },
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    flex: 2,
                    child: _buildTextField(
                      controller: _revXpCtrl,
                      label: 'XP Reward',
                      hint: '50',
                      keyboardType: TextInputType.number,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              _buildTextField(
                controller: _revTitleCtrl,
                label: 'Reviewer Title',
                hint: 'e.g., Week 3 UCSP Cultural Relativism Slides',
              ),
              const SizedBox(height: 8),
              _buildTextField(
                controller: _revUrlCtrl,
                label: 'Reviewer URL Link (Google Drive / Canva / Docs / Web)',
                hint: 'https://drive.google.com/...',
              ),
              const SizedBox(height: 8),
              _buildTextField(
                controller: _revSummaryCtrl,
                label: 'Short Study Guide Note (Optional)',
                hint: 'Read before taking the Week 3 Quiz',
              ),
              const SizedBox(height: 10),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF0284C7),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 11),
                  ),
                  onPressed: _addReviewerLink,
                  icon: const Icon(Icons.add_link_rounded, size: 18),
                  label: const Text(
                    '+ Add Reviewer Link to Chest',
                    style: TextStyle(fontWeight: FontWeight.w800),
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),
        Text(
          'CURRENT REVIEWER LINKS BY SUBJECT CHEST',
          style: GoogleFonts.outfit(
            color: Colors.white70,
            fontSize: 11.5,
            fontWeight: FontWeight.w800,
            letterSpacing: 0.7,
          ),
        ),
        const SizedBox(height: 8),
        ...chests.map((chest) {
          final accent = Color(chest.colorValue);
          return Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFF1E293B),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: accent.withOpacity(0.45)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(
                        '📦 ${chest.subjectName}',
                        style: GoogleFonts.outfit(
                          color: Colors.white,
                          fontSize: 14,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const Spacer(),
                      Text(
                        '${chest.reviewers.length} link(s)',
                        style: GoogleFonts.inter(
                          color: Colors.white60,
                          fontSize: 11,
                        ),
                      ),
                    ],
                  ),
                  if (chest.reviewers.isEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 6),
                      child: Text(
                        'Empty — no Reviewer Links added yet.',
                        style: GoogleFonts.inter(
                          color: Colors.white54,
                          fontSize: 11.5,
                        ),
                      ),
                    )
                  else ...[
                    const SizedBox(height: 8),
                    ...chest.reviewers.map((rev) {
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 6),
                        child: Row(
                          children: [
                            const Icon(Icons.link_rounded,
                                color: Color(0xFF38BDF8), size: 16),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    '${rev.title} (+${rev.xpReward} XP)',
                                    style: GoogleFonts.inter(
                                      color: Colors.white,
                                      fontSize: 12.5,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                  Text(
                                    rev.urlOrContent,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: GoogleFonts.inter(
                                      color: Colors.white54,
                                      fontSize: 10.5,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            IconButton(
                              onPressed: () => service.deleteReviewerFromChest(
                                chestId: chest.id,
                                reviewerId: rev.id,
                              ),
                              icon: const Icon(
                                Icons.delete_outline_rounded,
                                color: Colors.redAccent,
                                size: 18,
                              ),
                            ),
                          ],
                        ),
                      );
                    }),
                  ],
                ],
              ),
            ),
          );
        }),
      ],
    );
  }

  Widget _buildActivityLinksTab(
    List<String> subjectNames,
    List<LobbyQuestActivity> activities,
    LobbyDataService service,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: const Color(0xFF1E293B).withOpacity(0.75),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: const Color(0xFFFACC15).withOpacity(0.4)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '➕ Post New Activity Link to Quest Counter',
                style: GoogleFonts.outfit(
                  color: const Color(0xFFFACC15),
                  fontSize: 14,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(
                    flex: 3,
                    child: DropdownButtonFormField<String>(
                      value: _actSubject,
                      dropdownColor: const Color(0xFF1E293B),
                      style:
                          const TextStyle(color: Colors.white, fontSize: 12.5),
                      decoration: _inputDecoration('Subject'),
                      items: subjectNames
                          .map(
                            (s) => DropdownMenuItem(
                              value: s,
                              child: Text(s),
                            ),
                          )
                          .toList(),
                      onChanged: (v) {
                        if (v != null) setState(() => _actSubject = v);
                      },
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    flex: 2,
                    child: _buildTextField(
                      controller: _actXpCtrl,
                      label: 'XP Reward',
                      hint: '100',
                      keyboardType: TextInputType.number,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              _buildTextField(
                controller: _actTitleCtrl,
                label: 'Activity / Task Title',
                hint: 'e.g., Week 3 Google Form Quiz / Worksheet',
              ),
              const SizedBox(height: 8),
              _buildTextField(
                controller: _actUrlCtrl,
                label: 'Activity URL Link (Google Forms / Quizizz / Docs)',
                hint: 'https://forms.gle/...',
              ),
              const SizedBox(height: 8),
              _buildTextField(
                controller: _actBadgeNameCtrl,
                label: 'Badge Reward Title',
                hint: 'e.g., Quiz Conqueror',
              ),
              const SizedBox(height: 10),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFF59E0B),
                    foregroundColor: const Color(0xFF0F172A),
                    padding: const EdgeInsets.symmetric(vertical: 11),
                  ),
                  onPressed: _addActivityLink,
                  icon: const Icon(Icons.publish_rounded, size: 18),
                  label: const Text(
                    '+ Post Activity Link to Quest Counter',
                    style: TextStyle(fontWeight: FontWeight.w800),
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),
        Text(
          'POSTED ACTIVITY LINKS (${activities.length})',
          style: GoogleFonts.outfit(
            color: Colors.white70,
            fontSize: 11.5,
            fontWeight: FontWeight.w800,
            letterSpacing: 0.7,
          ),
        ),
        const SizedBox(height: 8),
        if (activities.isEmpty)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: const Color(0xFF1E293B),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Text(
              'Empty — no Activity Links posted yet.',
              style: GoogleFonts.inter(color: Colors.white54, fontSize: 12),
            ),
          )
        else
          ...activities.map((act) {
            return Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFF1E293B),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                      color: Color(act.badgeColor).withOpacity(0.45)),
                ),
                child: Row(
                  children: [
                    Text(act.badgeIcon, style: const TextStyle(fontSize: 20)),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '[${act.subject}] ${act.title} (+${act.xpReward} XP)',
                            style: GoogleFonts.inter(
                              color: Colors.white,
                              fontSize: 12.5,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          Text(
                            act.activityUrl,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: GoogleFonts.inter(
                              color: Colors.white54,
                              fontSize: 10.5,
                            ),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      onPressed: () => service.deleteActivity(act.id),
                      icon: const Icon(
                        Icons.delete_outline_rounded,
                        color: Colors.redAccent,
                        size: 18,
                      ),
                    ),
                  ],
                ),
              ),
            );
          }),
      ],
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════
//  PHASE 4: CHARACTER PROGRESS & RANK MODAL + CANTEEN VENDING MODAL
// ═══════════════════════════════════════════════════════════════════════════

Future<void> showCharacterProgressModal({
  required BuildContext context,
  required String playerName,
  required bool isFaculty,
}) async {
  await showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (ctx) => _CharacterProgressSheet(
      playerName: playerName,
      isFaculty: isFaculty,
    ),
  );
}

class _CharacterProgressSheet extends StatelessWidget {
  final String playerName;
  final bool isFaculty;

  const _CharacterProgressSheet({
    required this.playerName,
    required this.isFaculty,
  });

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: LobbyDataService.instance,
      builder: (context, _) {
        final service = LobbyDataService.instance;
        final progress = service.progress;
        final totalReviewers = service.subjectChests.fold<int>(
          0,
          (sum, c) => sum + c.reviewers.length,
        );
        final totalActivities = service.activities.length;

        return ConstrainedBox(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.of(context).size.height * 0.88,
          ),
          child: SingleChildScrollView(
            padding: EdgeInsets.only(
              bottom: MediaQuery.of(context).viewInsets.bottom,
            ),
            child: Container(
              margin: const EdgeInsets.fromLTRB(12, 24, 12, 16),
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: const Color(0xFF0F172A),
                borderRadius: BorderRadius.circular(24),
                border: Border.all(color: const Color(0xFFFACC15), width: 1.8),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
              Row(
                children: [
                  Container(
                    width: 52,
                    height: 52,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: const Color(0xFFFACC15).withOpacity(0.18),
                      borderRadius: BorderRadius.circular(16),
                      border:
                          Border.all(color: const Color(0xFFFACC15), width: 1.6),
                    ),
                    child: Text(
                      progress.rankEmoji,
                      style: const TextStyle(fontSize: 28),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '$playerName • Level ${progress.level}',
                          style: GoogleFonts.outfit(
                            color: Colors.white,
                            fontSize: 18,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        Text(
                          '${progress.rankTitle} • ${progress.xp} Total XP',
                          style: GoogleFonts.inter(
                            color: const Color(0xFFFDE047),
                            fontSize: 12.5,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.of(context).pop(),
                    icon:
                        const Icon(Icons.close_rounded, color: Colors.white70),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              // XP Progress Bar
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: const Color(0xFF1E293B),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Progress to Level ${progress.level + 1}',
                          style: GoogleFonts.inter(
                            color: Colors.white,
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        Text(
                          '${progress.currentLevelXp} / 100 XP',
                          style: GoogleFonts.outfit(
                            color: const Color(0xFF38BDF8),
                            fontSize: 12.5,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(99),
                      child: LinearProgressIndicator(
                        value: (progress.currentLevelXp / 100.0).clamp(0.0, 1.0),
                        minHeight: 10,
                        backgroundColor: Colors.white12,
                        valueColor: const AlwaysStoppedAnimation<Color>(
                            Color(0xFF10B981)),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: _StatCard(
                      icon: '📚',
                      label: 'Reviewers Done',
                      value:
                          '${progress.completedReviewerIds.length} / $totalReviewers',
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _StatCard(
                      icon: '🎯',
                      label: 'Activities Done',
                      value:
                          '${progress.completedActivityIds.length} / $totalActivities',
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _StatCard(
                      icon: '🏅',
                      label: 'Badges Earned',
                      value: '${progress.earnedBadges.length}',
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(
                        foregroundColor: const Color(0xFF38BDF8),
                        side: const BorderSide(color: Color(0xFF38BDF8)),
                        padding: const EdgeInsets.symmetric(vertical: 11),
                      ),
                      onPressed: () {
                        Navigator.of(context).pop();
                        showMyBadgesModal(context: context);
                      },
                      icon: const Icon(Icons.workspace_premium_rounded,
                          size: 17),
                      label: const Text(
                        'My Badges',
                        style: TextStyle(fontWeight: FontWeight.w800),
                      ),
                    ),
                  ),
                  if (isFaculty) ...[
                    const SizedBox(width: 8),
                    Expanded(
                      child: ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFFF59E0B),
                          foregroundColor: const Color(0xFF0F172A),
                          padding: const EdgeInsets.symmetric(vertical: 11),
                        ),
                        onPressed: () {
                          Navigator.of(context).pop();
                          showTeacherLinkManagerModal(
                            context: context,
                            teacherName: playerName,
                          );
                        },
                        icon: const Icon(Icons.link_rounded, size: 17),
                        label: const Text(
                          'Manage Links',
                          style: TextStyle(fontWeight: FontWeight.w800),
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ],
          ),
            ),
          ),
        );
      },
    );
  }
}

class _StatCard extends StatelessWidget {
  final String icon;
  final String label;
  final String value;

  const _StatCard({
    required this.icon,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
      decoration: BoxDecoration(
        color: const Color(0xFF1E293B),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.white12),
      ),
      child: Column(
        children: [
          Text(icon, style: const TextStyle(fontSize: 20)),
          const SizedBox(height: 4),
          Text(
            value,
            style: GoogleFonts.outfit(
              color: Colors.white,
              fontSize: 15,
              fontWeight: FontWeight.w800,
            ),
          ),
          Text(
            label,
            textAlign: TextAlign.center,
            style: GoogleFonts.inter(
              color: Colors.white60,
              fontSize: 10.5,
            ),
          ),
        ],
      ),
    );
  }
}

Future<String?> showCanteenVendingModal({
  required BuildContext context,
}) async {
  const items = <Map<String, String>>[
    {'emoji': '🧋', 'name': 'Iced Wintermelon Milktea', 'tag': 'Chilled Drink'},
    {'emoji': '🥤', 'name': 'Fresh Calamansi Cooler', 'tag': 'Brain Booster'},
    {'emoji': '☕', 'name': 'Iced Caramel Macchiato', 'tag': 'Study Fuel'},
    {'emoji': '🍫', 'name': 'Crispy Choco Wafer Bar', 'tag': 'Sweet Snack'},
    {'emoji': '🥟', 'name': 'Steamed Siomai Cup (4pcs)', 'tag': 'Canteen Favorite'},
    {'emoji': '🥪', 'name': 'Toasted Clubhouse Sandwich', 'tag': 'Heavy Merienda'},
  ];

  return showModalBottomSheet<String>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (ctx) => ConstrainedBox(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(ctx).size.height * 0.86,
      ),
      child: SingleChildScrollView(
        child: Container(
          margin: const EdgeInsets.all(14),
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: const Color(0xFF0F172A),
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: const Color(0xFFFB923C), width: 1.8),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Text('🥤', style: TextStyle(fontSize: 26)),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'SHS Canteen Vending & Merienda Bar',
                          style: GoogleFonts.outfit(
                            color: Colors.white,
                            fontSize: 17,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        Text(
                          'Pick a drink or snack to enjoy at the Canteen tables!',
                          style: GoogleFonts.inter(
                            color: Colors.white70,
                            fontSize: 11.5,
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.of(ctx).pop(),
                    icon: const Icon(Icons.close_rounded, color: Colors.white70),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: items.map((item) {
                  final emoji = item['emoji']!;
                  final name = item['name']!;
                  final tag = item['tag']!;
                  return InkWell(
                    onTap: () =>
                        Navigator.of(ctx).pop('$emoji Enjoying $name! 😋'),
                    borderRadius: BorderRadius.circular(14),
                    child: Container(
                      width: (MediaQuery.of(ctx).size.width - 72) / 2,
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: const Color(0xFF1E293B),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(
                            color: const Color(0xFFFB923C).withOpacity(0.45)),
                      ),
                      child: Row(
                        children: [
                          Text(emoji, style: const TextStyle(fontSize: 22)),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  name,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: GoogleFonts.outfit(
                                    color: Colors.white,
                                    fontSize: 12,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                                Text(
                                  tag,
                                  style: GoogleFonts.inter(
                                    color: const Color(0xFFFDBA74),
                                    fontSize: 10,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                }).toList(),
              ),
            ],
          ),
        ),
      ),
    ),
  );
}

// ═══════════════════════════════════════════════════════════════════════════
//  LIVE MULTIPLAYER CAMPUS DIRECTORY MODAL (ONLINE STUDENTS & TEACHER)
// ═══════════════════════════════════════════════════════════════════════════

Future<void> showOnlinePlayersModal({
  required BuildContext context,
  required String selfNickname,
  required bool selfIsFaculty,
  required LobbyRoomId currentRoom,
  required bool showOfflineBots,
  required ValueChanged<bool> onToggleOfflineBots,
  required void Function(RemoteLobbyPlayer player) onJoinAndGuideToPlayer,
}) async {
  await showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (ctx) => _OnlinePlayersDirectorySheet(
      selfNickname: selfNickname,
      selfIsFaculty: selfIsFaculty,
      currentRoom: currentRoom,
      initialShowOfflineBots: showOfflineBots,
      onToggleOfflineBots: onToggleOfflineBots,
      onJoinAndGuideToPlayer: onJoinAndGuideToPlayer,
    ),
  );
}

class _OnlinePlayersDirectorySheet extends StatefulWidget {
  final String selfNickname;
  final bool selfIsFaculty;
  final LobbyRoomId currentRoom;
  final bool initialShowOfflineBots;
  final ValueChanged<bool> onToggleOfflineBots;
  final void Function(RemoteLobbyPlayer player) onJoinAndGuideToPlayer;

  const _OnlinePlayersDirectorySheet({
    required this.selfNickname,
    required this.selfIsFaculty,
    required this.currentRoom,
    required this.initialShowOfflineBots,
    required this.onToggleOfflineBots,
    required this.onJoinAndGuideToPlayer,
  });

  @override
  State<_OnlinePlayersDirectorySheet> createState() =>
      _OnlinePlayersDirectorySheetState();
}

class _OnlinePlayersDirectorySheetState
    extends State<_OnlinePlayersDirectorySheet> {
  late bool _showBots;

  @override
  void initState() {
    super.initState();
    _showBots = widget.initialShowOfflineBots;
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: LobbyPresenceService.instance,
      builder: (context, _) {
        final presence = LobbyPresenceService.instance;
        final remotes = presence.allRemotePlayers;
        final totalOnline = presence.totalOnlineCount;

        return Container(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.of(context).size.height * 0.82,
          ),
          margin: const EdgeInsets.fromLTRB(12, 24, 12, 16),
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: const Color(0xFF0F172A),
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: const Color(0xFF10B981), width: 1.8),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: const Color(0xFF10B981).withOpacity(0.18),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: const Color(0xFF10B981)),
                    ),
                    child: const Text('🟢', style: TextStyle(fontSize: 20)),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Live Campus Multiplayer ($totalOnline Online)',
                          style: GoogleFonts.outfit(
                            color: Colors.white,
                            fontSize: 17.5,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        Text(
                          'See real classmates & teachers across all 5 rooms and walk up to them!',
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
                    icon:
                        const Icon(Icons.close_rounded, color: Colors.white70),
                  ),
                ],
              ),
              const SizedBox(height: 12),

              // Local Player Card ("You")
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFF065F46).withOpacity(0.35),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                      color: const Color(0xFF10B981).withOpacity(0.65)),
                ),
                child: Row(
                  children: [
                    Text(
                      widget.selfIsFaculty ? '👑' : '🧑',
                      style: const TextStyle(fontSize: 22),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '${widget.selfNickname} (You)',
                            style: GoogleFonts.outfit(
                              color: Colors.white,
                              fontSize: 14,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          Text(
                            '${widget.currentRoom.iconEmoji} ${widget.currentRoom.title} • ⚡ Real-Time Stream (${presence.activeTransportCount} Active Channels)',
                            style: GoogleFonts.inter(
                              color: const Color(0xFF6EE7B7),
                              fontSize: 11.5,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 10),

              // Remote Players List
              Flexible(
                child: remotes.isEmpty
                    ? Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(18),
                        decoration: BoxDecoration(
                          color: const Color(0xFF1E293B).withOpacity(0.7),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: Colors.white12),
                        ),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Text('📡', style: TextStyle(fontSize: 30)),
                            const SizedBox(height: 6),
                            Text(
                              'Waiting for Other Students or Teachers to Enter',
                              textAlign: TextAlign.center,
                              style: GoogleFonts.outfit(
                                color: Colors.white,
                                fontSize: 14.5,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'As soon as another student or teacher opens the School Lobby on their phone, their custom avatar, nickname, and Thought Bubbles will appear live right here and on your map!',
                              textAlign: TextAlign.center,
                              style: GoogleFonts.inter(
                                color: Colors.white60,
                                fontSize: 11.5,
                              ),
                            ),
                          ],
                        ),
                      )
                    : ListView.separated(
                        shrinkWrap: true,
                        itemCount: remotes.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 8),
                        itemBuilder: (context, idx) {
                          final rp = remotes[idx];
                          final sameRoom = rp.room == widget.currentRoom;
                          return Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: const Color(0xFF1E293B),
                              borderRadius: BorderRadius.circular(14),
                              border: Border.all(
                                color: rp.isFaculty
                                    ? const Color(0xFFFACC15).withOpacity(0.65)
                                    : const Color(0xFF38BDF8).withOpacity(0.45),
                              ),
                            ),
                            child: Row(
                              children: [
                                Text(
                                  rp.equippedBadgeIcon ??
                                      (rp.isFaculty ? '👑' : '🟢'),
                                  style: const TextStyle(fontSize: 22),
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        '${rp.nickname} ${rp.isFaculty ? "[TEACHER]" : ""}',
                                        style: GoogleFonts.outfit(
                                          color: Colors.white,
                                          fontSize: 14,
                                          fontWeight: FontWeight.w800,
                                        ),
                                      ),
                                      Text(
                                        '${rp.room.iconEmoji} ${rp.room.shortLabel} • ${rp.statusLabel}',
                                        style: GoogleFonts.inter(
                                          color: Colors.white70,
                                          fontSize: 11.5,
                                        ),
                                      ),
                                      if (rp.hasActiveThought) ...[
                                        const SizedBox(height: 3),
                                        Text(
                                          '💭 "${rp.thoughtText}"',
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: GoogleFonts.inter(
                                            color: const Color(0xFF38BDF8),
                                            fontSize: 11,
                                            fontStyle: FontStyle.italic,
                                          ),
                                        ),
                                      ],
                                    ],
                                  ),
                                ),
                                const SizedBox(width: 8),
                                ElevatedButton(
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: sameRoom
                                        ? const Color(0xFF10B981)
                                        : const Color(0xFF0284C7),
                                    foregroundColor: Colors.white,
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 10, vertical: 8),
                                  ),
                                  onPressed: () {
                                    Navigator.of(context).pop();
                                    widget.onJoinAndGuideToPlayer(rp);
                                  },
                                  child: Text(
                                    sameRoom ? 'Walk To ➔' : 'Join Room 🚪',
                                    style: const TextStyle(
                                      fontSize: 11,
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
              const SizedBox(height: 10),
              SwitchListTile(
                dense: true,
                contentPadding: EdgeInsets.zero,
                activeColor: const Color(0xFF38BDF8),
                title: Text(
                  'Show Offline Practice Classmates on Map',
                  style: GoogleFonts.inter(
                    color: Colors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                subtitle: Text(
                  'Off by default so only real live online users & Aiko (Lobbyist) appear.',
                  style: GoogleFonts.inter(
                    color: Colors.white54,
                    fontSize: 10.5,
                  ),
                ),
                value: _showBots,
                onChanged: (val) {
                  setState(() => _showBots = val);
                  widget.onToggleOfflineBots(val);
                },
              ),
            ],
          ),
        );
      },
    );
  }
}


