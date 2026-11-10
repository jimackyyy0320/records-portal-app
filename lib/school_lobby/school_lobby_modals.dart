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
import 'lobby_data_service.dart';
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

/// Opens a Small Mystery Chest Pop-Quiz Modal (Feature 3).
Future<void> showSmallMysteryChestModal({
  required BuildContext context,
  required String smallChestId,
  required String smallChestLabel,
}) async {
  await showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (ctx) => _SmallMysteryChestQuizSheet(
      smallChestId: smallChestId,
      smallChestLabel: smallChestLabel,
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

/// Opens the Student Rest Spot Picker (`🪑 Sit`, `😪 Nap`, `🛌 Sleep`, or `🚶 Stand Up`).
Future<PlayerRestState?> showRestSpotActionModal({
  required BuildContext context,
  required String spotLabel,
  required PlayerRestState currentState,
  bool canSleepFlat = true,
}) async {
  return showModalBottomSheet<PlayerRestState>(
    context: context,
    backgroundColor: Colors.transparent,
    builder: (ctx) => _RestSpotPickerSheet(
      spotLabel: spotLabel,
      currentState: currentState,
      canSleepFlat: canSleepFlat,
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

  const _RestSpotPickerSheet({
    required this.spotLabel,
    required this.currentState,
    required this.canSleepFlat,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.fromLTRB(12, 16, 12, 16),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: const Color(0xFF0F172A),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: const Color(0xFF10B981).withOpacity(0.55),
          width: 1.6,
        ),
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
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: const Color(0xFF10B981)),
                ),
                child: const Text('🪑', style: TextStyle(fontSize: 22)),
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
                      'Choose how your avatar wants to rest here:',
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
              const SizedBox(width: 8),
              Expanded(
                child: _RestOptionCard(
                  emoji: '🛌',
                  title: 'Sleep',
                  subtitle: canSleepFlat ? 'Deep sleep 💤' : 'Desk sleep 💤',
                  color: const Color(0xFF6366F1),
                  isSelected: currentState == PlayerRestState.sleeping,
                  onTap: () =>
                      Navigator.of(context).pop(PlayerRestState.sleeping),
                ),
              ),
            ],
          ),
          if (currentState.isResting) ...[
            const SizedBox(height: 12),
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
    HapticFeedback.mediumImpact();
    Navigator.of(context).pop(text);
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

              // Action Bar (Teacher "+ Post an Activity" + Student "My Badges")
              Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                child: Row(
                  children: [
                    Text(
                      'ENROLLED QUESTS (${activities.length})',
                      style: GoogleFonts.outfit(
                        color: Colors.white70,
                        fontSize: 12,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0.8,
                      ),
                    ),
                    const Spacer(),
                    OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(
                        foregroundColor: const Color(0xFF38BDF8),
                        side: const BorderSide(color: Color(0xFF38BDF8)),
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 6),
                      ),
                      onPressed: () => showMyBadgesModal(context: context),
                      icon: const Icon(Icons.workspace_premium_rounded,
                          size: 16),
                      label: Text(
                        'My Badges (${progress.earnedBadges.length})',
                        style: const TextStyle(
                            fontSize: 11.5, fontWeight: FontWeight.w700),
                      ),
                    ),
                    if (isFaculty) ...[
                      const SizedBox(width: 8),
                      ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFFF59E0B),
                          foregroundColor: const Color(0xFF0F172A),
                          padding: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 8),
                        ),
                        onPressed: () => showPostActivityModal(
                          context: context,
                          postedBy: userName,
                        ),
                        icon: const Icon(Icons.add_rounded, size: 17),
                        label: const Text(
                          '+ Post an Activity',
                          style: TextStyle(
                              fontSize: 11.5, fontWeight: FontWeight.w800),
                        ),
                      ),
                    ],
                  ],
                ),
              ),

              // Quest List
              Flexible(
                child: activities.isEmpty
                    ? Padding(
                        padding: const EdgeInsets.all(24),
                        child: Text(
                          'No active quests posted for your enrolled subjects yet.',
                          style: GoogleFonts.inter(color: Colors.white60),
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
    // 1. If this is an HTML Reviewer from the Google Drive Reviewer Folder (`1EFX9aylAeSRmDWU7OeFIPa0llAMD8wC5`),
    //    stream it directly inside the In-App HTML Presentation Streamer!
    if (item.isFromDrive && item.isHtmlReviewer && item.driveFileId != null) {
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
    await showDialog<void>(
      context: context,
      builder: (ctx) => Dialog(
        backgroundColor: const Color(0xFF0F172A),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: BorderSide(color: accentColor, width: 1.6),
        ),
        child: Padding(
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
                        icon: const Icon(Icons.upload_file_rounded, size: 17),
                        label: const Text(
                          '+ Upload Reviewer',
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
                child: ListView.separated(
                  shrinkWrap: true,
                  itemCount: chest.reviewers.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 10),
                  itemBuilder: (context, index) {
                    final rev = chest.reviewers[index];
                    final isHtmlDrive = rev.isFromDrive && rev.isHtmlReviewer;

                    return InkWell(
                      onTap: () => _openReviewerItem(context, rev, accent),
                      borderRadius: BorderRadius.circular(16),
                      child: Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: const Color(0xFF1E293B),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: accent.withOpacity(0.45),
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
                                                color: accent.withOpacity(0.22),
                                                borderRadius:
                                                    BorderRadius.circular(6),
                                              ),
                                              child: Text(
                                                rev.weekGroup!,
                                                style: GoogleFonts.inter(
                                                  color: Colors.white,
                                                  fontSize: 9.5,
                                                  fontWeight: FontWeight.w800,
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
                            if (isHtmlDrive) ...[
                              const SizedBox(height: 10),
                              Row(
                                children: [
                                  Expanded(
                                    child: ElevatedButton.icon(
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: accent,
                                        foregroundColor: Colors.white,
                                        padding: const EdgeInsets.symmetric(
                                            vertical: 8),
                                      ),
                                      onPressed: () => _openReviewerItem(
                                          context, rev, accent),
                                      icon: const Icon(
                                          Icons.play_circle_fill_rounded,
                                          size: 16),
                                      label: const Text(
                                        'Stream HTML Slides',
                                        style: TextStyle(
                                            fontSize: 11.5,
                                            fontWeight: FontWeight.w800),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: OutlinedButton.icon(
                                      style: OutlinedButton.styleFrom(
                                        foregroundColor:
                                            const Color(0xFF38BDF8),
                                        side: const BorderSide(
                                            color: Color(0xFF38BDF8)),
                                        padding: const EdgeInsets.symmetric(
                                            vertical: 8),
                                      ),
                                      onPressed: () =>
                                          _openOutlineExtractorForDriveItem(
                                              context, rev, accent),
                                      icon: const Icon(
                                          Icons.description_outlined,
                                          size: 16),
                                      label: const Text(
                                        'Extract .TXT Outline',
                                        style: TextStyle(
                                            fontSize: 11.5,
                                            fontWeight: FontWeight.w700),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ],
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
  final _contentCtrl = TextEditingController();
  final _summaryCtrl = TextEditingController();
  String _fileType = 'NOTES';

  @override
  void dispose() {
    _titleCtrl.dispose();
    _contentCtrl.dispose();
    _summaryCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_titleCtrl.text.trim().isEmpty || _contentCtrl.text.trim().isEmpty) {
      return;
    }
    await LobbyDataService.instance.addReviewerToChest(
      chestId: widget.chest.id,
      title: _titleCtrl.text.trim(),
      fileType: _fileType,
      urlOrContent: _contentCtrl.text.trim(),
      summary: _summaryCtrl.text.trim().isEmpty
          ? 'Teacher uploaded reviewer for ${widget.chest.subjectName}.'
          : _summaryCtrl.text.trim(),
      uploadedBy: 'Faculty',
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
              '📦 Add Reviewer to ${widget.chest.subjectName} Chest',
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
            DropdownButtonFormField<String>(
              value: _fileType,
              dropdownColor: const Color(0xFF1E293B),
              style: const TextStyle(color: Colors.white),
              decoration: _inputDecoration('Reviewer Type'),
              items: const [
                DropdownMenuItem(
                    value: 'NOTES', child: Text('Study Notes (In-App Reader)')),
                DropdownMenuItem(
                    value: 'PDF', child: Text('PDF / Drive Document Link')),
                DropdownMenuItem(value: 'LINK', child: Text('External Web Link')),
              ],
              onChanged: (v) {
                if (v != null) setState(() => _fileType = v);
              },
            ),
            const SizedBox(height: 10),
            _buildTextField(
              controller: _contentCtrl,
              label: _fileType == 'NOTES'
                  ? 'Study Notes Content'
                  : 'Document / Reviewer URL',
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
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Color(widget.chest.colorValue),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                ),
                onPressed: _save,
                child: const Text(
                  'Save Reviewer to Chest',
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
      margin: EdgeInsets.fromLTRB(12, 24, 12, 12 + bottomInset),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: const Color(0xFF0F172A),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Color(_selectedColor)),
      ),
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
            hint: 'e.g., PGP, UCSP, PPG, PKLP TERM 2, PHILO',
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
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════
//  FEATURE 3: SMALL MYSTERY CHESTS (POP-QUIZ + 2-MINUTE COOLDOWN)
// ═══════════════════════════════════════════════════════════════════════════

class _SmallMysteryChestQuizSheet extends StatefulWidget {
  final String smallChestId;
  final String smallChestLabel;

  const _SmallMysteryChestQuizSheet({
    required this.smallChestId,
    required this.smallChestLabel,
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

  @override
  void initState() {
    super.initState();
    _question = LobbyDataService.instance
        .pickRandomQuestionForSmallChest(widget.smallChestId);
  }

  Future<void> _selectOption(int index) async {
    if (_answeredCorrect) return;
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
      setState(() {
        _answeredCorrect = true;
        _answeredWrong = false;
      });
    } else {
      HapticFeedback.vibrate();
      setState(() {
        _answeredWrong = true;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final service = LobbyDataService.instance;
    final remainingSec =
        service.smallChestRemainingSeconds(widget.smallChestId);

    if (remainingSec > 0 && !_answeredCorrect) {
      final mins = remainingSec ~/ 60;
      final secs = (remainingSec % 60).toString().padLeft(2, '0');
      return Container(
        margin: const EdgeInsets.all(16),
        padding: const EdgeInsets.all(22),
        decoration: BoxDecoration(
          color: const Color(0xFF0F172A),
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: Colors.white24),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('⏳', style: TextStyle(fontSize: 40)),
            const SizedBox(height: 10),
            Text(
              'Chest Recharging ($mins:$secs)',
              style: GoogleFonts.outfit(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              'This Small Mystery Chest is on its 2-minute cooldown. Explore the other Mystery Chests around the lobby while you wait!',
              textAlign: TextAlign.center,
              style: GoogleFonts.inter(color: Colors.white70, fontSize: 12.5),
            ),
            const SizedBox(height: 14),
            OutlinedButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Got it'),
            ),
          ],
        ),
      );
    }

    const letters = ['A', 'B', 'C', 'D'];

    return Container(
      margin: const EdgeInsets.fromLTRB(12, 24, 12, 16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFF0F172A),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: _answeredCorrect
              ? const Color(0xFF10B981)
              : const Color(0xFFA855F7),
          width: 1.8,
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: const Color(0xFFA855F7).withOpacity(0.22),
                  borderRadius: BorderRadius.circular(99),
                  border: Border.all(color: const Color(0xFFA855F7)),
                ),
                child: Text(
                  '✨ ${_question.subject} POP-QUIZ • +${_question.xpReward} XP',
                  style: GoogleFonts.outfit(
                    color: const Color(0xFFFDE047),
                    fontSize: 11.5,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              const Spacer(),
              IconButton(
                onPressed: () => Navigator.of(context).pop(),
                icon: const Icon(Icons.close_rounded, color: Colors.white70),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            _question.question,
            style: GoogleFonts.outfit(
              color: Colors.white,
              fontSize: 16.5,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 14),
          ...List.generate(_question.options.length, (idx) {
            final isSelected = _selectedOption == idx;
            final isCorrectOption = idx == _question.correctIndex;

            Color borderColor = Colors.white24;
            Color bgColor = const Color(0xFF1E293B);
            if (_answeredCorrect && isCorrectOption) {
              borderColor = const Color(0xFF10B981);
              bgColor = const Color(0xFF065F46).withOpacity(0.6);
            } else if (_answeredWrong && isSelected && !isCorrectOption) {
              borderColor = const Color(0xFFEF4444);
              bgColor = const Color(0xFF7F1D1D).withOpacity(0.5);
            }

            return Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: InkWell(
                onTap: () => _selectOption(idx),
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
                    ],
                  ),
                ),
              ),
            );
          }),
          if (_answeredWrong && !_answeredCorrect) ...[
            const SizedBox(height: 6),
            Row(
              children: [
                const Icon(Icons.error_outline_rounded,
                    color: Color(0xFFF87171), size: 18),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    'Not quite! Try another option or draw a new question.',
                    style: GoogleFonts.inter(
                      color: const Color(0xFFF87171),
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                TextButton(
                  onPressed: () {
                    setState(() {
                      _question = service
                          .pickRandomQuestionForSmallChest(widget.smallChestId);
                      _selectedOption = null;
                      _answeredWrong = false;
                    });
                  },
                  child: const Text('New Question'),
                ),
              ],
            ),
          ],
          if (_answeredCorrect) ...[
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFF065F46).withOpacity(0.45),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: const Color(0xFF10B981)),
              ),
              child: Row(
                children: [
                  const Text('🎉', style: TextStyle(fontSize: 22)),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'Correct! +${_question.xpReward} XP added to your profile! This chest will recharge in 2 minutes.',
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
      margin: const EdgeInsets.all(14),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFF0F172A),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: const Color(0xFFFACC15), width: 1.6),
      ),
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
                      'Sir Jim Mark • Social Science & Humanities Faculty Desk',
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
            '"Keep exploring your enrolled Reviewer Chests and testing your mastery on the Small Mystery Chests! Remember: consistent preparation builds confidence."',
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
                  showPostActivityModal(context: context, postedBy: userName);
                },
                icon: const Icon(Icons.add_task_rounded),
                label: const Text(
                  '+ Post New Quest Activity',
                  style: TextStyle(fontWeight: FontWeight.w800),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _BulletinBoardSheet extends StatelessWidget {
  const _BulletinBoardSheet();

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.all(14),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFF0F172A),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: const Color(0xFF38BDF8), width: 1.6),
      ),
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
            icon: '🚪',
            title: 'Campus Doors (Park, Class Room, Canteen, Faculty)',
            desc:
                'Walk up to any glowing Door or tap the Room Switcher pill in the top HUD to explore all 5 campus rooms!',
          ),
          const SizedBox(height: 8),
          const _GuideRow(
            icon: '🪑',
            title: 'Sit, Nap, or Sleep Anywhere',
            desc:
                'Walk near any sofa, bench, classroom desk, or park lawn—or tap the Sit / Nap / Sleep buttons in the bottom-right corner!',
          ),
          const SizedBox(height: 8),
          const _GuideRow(
            icon: '💭',
            title: 'Student Thought Bubbles',
            desc:
                'Approach any classmate or tap "💭 Think" to pop a cloud Thought Bubble above your avatar and chat!',
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
