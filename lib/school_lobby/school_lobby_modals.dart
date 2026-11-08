import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:url_launcher/url_launcher.dart';

import 'lobby_data_service.dart';
import 'school_lobby_avatar.dart';

/// Launches an external or internal URL safely from a Quest or Reviewer item.
Future<void> _launchResourceUrl(BuildContext context, String rawUrl) async {
  final trimmed = rawUrl.trim();
  if (trimmed.isEmpty) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Activity opened! You can now mark it as done.'),
        behavior: SnackBarBehavior.floating,
      ),
    );
    return;
  }
  final normalized =
      trimmed.startsWith('http://') || trimmed.startsWith('https://')
          ? trimmed
          : 'https://$trimmed';
  final uri = Uri.tryParse(normalized);
  if (uri != null) {
    try {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
      return;
    } catch (_) {}
  }
  if (context.mounted) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Opened resource: $trimmed'),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }
}

/// Celebratory RPG Achievement & XP Toast / Dialog when a Student unlocks a Badge!
Future<void> showAchievementCelebrationDialog({
  required BuildContext context,
  required LobbyBadge badge,
  required int xpEarned,
}) {
  HapticFeedback.heavyImpact();
  return showDialog<void>(
    context: context,
    builder: (ctx) => Dialog(
      backgroundColor: Colors.transparent,
      child: Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [Color(0xFF1E1B4B), Color(0xFF0F172A)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: const Color(0xFFFACC15), width: 2.2),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFFFACC15).withOpacity(0.35),
              blurRadius: 28,
              spreadRadius: 2,
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
              decoration: BoxDecoration(
                color: const Color(0xFFFACC15).withOpacity(0.2),
                borderRadius: BorderRadius.circular(99),
                border: Border.all(color: const Color(0xFFFACC15)),
              ),
              child: Text(
                '✨ ACHIEVEMENT UNLOCKED ✨',
                style: GoogleFonts.outfit(
                  color: const Color(0xFFFDE047),
                  fontSize: 11.5,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 1.0,
                ),
              ),
            ),
            const SizedBox(height: 16),
            Container(
              width: 78,
              height: 78,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: const Color(0xFFFACC15).withOpacity(0.16),
                border: Border.all(color: const Color(0xFFFACC15), width: 2),
              ),
              child: Text(
                badge.badgeIcon,
                style: const TextStyle(fontSize: 40),
              ),
            ),
            const SizedBox(height: 14),
            Text(
              badge.badgeName,
              textAlign: TextAlign.center,
              style: GoogleFonts.outfit(
                color: Colors.white,
                fontSize: 21,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              '+$xpEarned XP • ${badge.subject}',
              style: GoogleFonts.inter(
                color: const Color(0xFF34D399),
                fontSize: 13.5,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              badge.description,
              textAlign: TextAlign.center,
              style: GoogleFonts.inter(
                color: Colors.white70,
                fontSize: 12.5,
              ),
            ),
            const SizedBox(height: 20),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => Navigator.of(ctx).pop(),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.white70,
                      side: const BorderSide(color: Colors.white24),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: const Text('Awesome!'),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () async {
                      await LobbyDataService.instance.equipBadge(badge.id);
                      if (ctx.mounted) Navigator.of(ctx).pop();
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFFACC15),
                      foregroundColor: Colors.black,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    icon: const Icon(Icons.auto_awesome_rounded, size: 16),
                    label: Text(
                      'Equip Badge',
                      style: GoogleFonts.inter(fontWeight: FontWeight.w800),
                    ),
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

// =============================================================================
// FEATURE 1: RECEPTION / QUEST COUNTER MODAL & TEACHER "+ POST AN ACTIVITY"
// =============================================================================

Future<void> showQuestCounterModal({
  required BuildContext context,
  required bool isFaculty,
  required String userName,
}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (ctx) => _QuestCounterSheet(
      isFaculty: isFaculty,
      userName: userName,
    ),
  );
}

class _QuestCounterSheet extends StatelessWidget {
  final bool isFaculty;
  final String userName;

  const _QuestCounterSheet({
    required this.isFaculty,
    required this.userName,
  });

  @override
  Widget build(BuildContext context) {
    final service = LobbyDataService.instance;
    final media = MediaQuery.of(context);

    return AnimatedBuilder(
      animation: service,
      builder: (context, _) {
        final activities = service.activities;
        final progress = service.progress;

        return Container(
          height: media.size.height * 0.85,
          decoration: BoxDecoration(
            color: const Color(0xFF0F172A),
            borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
            border: Border.all(
              color: const Color(0xFFF59E0B).withOpacity(0.45),
              width: 1.5,
            ),
          ),
          child: Column(
            children: [
              const SizedBox(height: 10),
              Container(
                width: 44,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.white24,
                  borderRadius: BorderRadius.circular(99),
                ),
              ),

              // RPG Anime Receptionist Dialogue Banner
              Container(
                margin: const EdgeInsets.fromLTRB(16, 14, 16, 10),
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF2E1065), Color(0xFF1E293B)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(
                      color: const Color(0xFFFACC15).withOpacity(0.55)),
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(4),
                      decoration: BoxDecoration(
                        color: const Color(0xFF0F172A),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: const Color(0xFFFACC15)),
                      ),
                      child: const PixelAvatarPreview(
                        look: LobbyAvatarLook(
                            isPreset: true, presetName: 'Amelia'),
                        facing: AvatarFacing.down,
                        animateWalk: false,
                        scale: 1.25,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 8, vertical: 2),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFFACC15),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Text(
                                  'AIRA • QUEST RECEPTIONIST',
                                  style: GoogleFonts.outfit(
                                    color: Colors.black,
                                    fontSize: 10,
                                    fontWeight: FontWeight.w900,
                                    letterSpacing: 0.5,
                                  ),
                                ),
                              ),
                              const Spacer(),
                              IconButton(
                                visualDensity: VisualDensity.compact,
                                onPressed: () => Navigator.of(context).pop(),
                                icon: const Icon(Icons.close_rounded,
                                    color: Colors.white70, size: 20),
                              ),
                            ],
                          ),
                          const SizedBox(height: 4),
                          Text(
                            isFaculty
                                ? '"Welcome back, Teacher $userName! Post a new learning quest below and assign a custom pixel badge & XP reward for your students!"'
                                : '"Welcome to the Quest Counter, $userName! Launch an activity from the board below, then click Mark as Done to claim your XP and Badge!"',
                            style: GoogleFonts.inter(
                              color: Colors.white.withOpacity(0.92),
                              fontSize: 12,
                              height: 1.35,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              // Action Bar (Teacher "+ Post an Activity" OR Student XP/Badge summary)
              Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 18, vertical: 4),
                child: Row(
                  children: [
                    Text(
                      'ACTIVE QUEST BOARD (${activities.length})',
                      style: GoogleFonts.outfit(
                        color: const Color(0xFFFDE047),
                        fontSize: 13.5,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0.7,
                      ),
                    ),
                    const Spacer(),
                    if (isFaculty)
                      ElevatedButton.icon(
                        onPressed: () => showPostActivityModal(
                          context: context,
                          postedBy: userName,
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFFF59E0B),
                          foregroundColor: Colors.black,
                          visualDensity: VisualDensity.compact,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                        icon: const Icon(Icons.add_circle_rounded, size: 17),
                        label: Text(
                          '+ Post an Activity',
                          style: GoogleFonts.inter(
                            fontWeight: FontWeight.w800,
                            fontSize: 12,
                          ),
                        ),
                      )
                    else
                      TextButton.icon(
                        onPressed: () => showMyBadgesModal(context: context),
                        icon: const Icon(Icons.workspace_premium_rounded,
                            color: Color(0xFFFACC15), size: 18),
                        label: Text(
                          'My Badges (${progress.earnedBadges.length})',
                          style: GoogleFonts.inter(
                            color: const Color(0xFFFACC15),
                            fontWeight: FontWeight.w700,
                            fontSize: 12,
                          ),
                        ),
                      ),
                  ],
                ),
              ),

              // Quest Cards List
              Expanded(
                child: activities.isEmpty
                    ? Center(
                        child: Text(
                          'No quests posted yet.',
                          style: GoogleFonts.inter(color: Colors.white54),
                        ),
                      )
                    : ListView.separated(
                        padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                        itemCount: activities.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 12),
                        itemBuilder: (context, index) {
                          final act = activities[index];
                          final isLaunched =
                              progress.launchedActivityIds.contains(act.id);
                          final isCompleted =
                              progress.completedActivityIds.contains(act.id);

                          return Container(
                            padding: const EdgeInsets.all(14),
                            decoration: BoxDecoration(
                              color: isCompleted
                                  ? const Color(0xFF064E3B).withOpacity(0.35)
                                  : const Color(0xFF1E293B),
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(
                                color: isCompleted
                                    ? const Color(0xFF10B981)
                                    : Colors.white.withOpacity(0.12),
                                width: isCompleted ? 1.6 : 1.0,
                              ),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    // Badge Icon Box
                                    Container(
                                      width: 46,
                                      height: 46,
                                      alignment: Alignment.center,
                                      decoration: BoxDecoration(
                                        color: const Color(0xFF0F172A),
                                        borderRadius: BorderRadius.circular(12),
                                        border: Border.all(
                                          color: const Color(0xFFFACC15)
                                              .withOpacity(0.55),
                                        ),
                                      ),
                                      child: Text(
                                        act.badgeIcon,
                                        style: const TextStyle(fontSize: 24),
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Wrap(
                                            spacing: 6,
                                            runSpacing: 4,
                                            crossAxisAlignment:
                                                WrapCrossAlignment.center,
                                            children: [
                                              Container(
                                                padding:
                                                    const EdgeInsets.symmetric(
                                                        horizontal: 8,
                                                        vertical: 2),
                                                decoration: BoxDecoration(
                                                  color: const Color(0xFF38BDF8)
                                                      .withOpacity(0.2),
                                                  borderRadius:
                                                      BorderRadius.circular(6),
                                                ),
                                                child: Text(
                                                  act.subject,
                                                  style: GoogleFonts.inter(
                                                    color:
                                                        const Color(0xFF38BDF8),
                                                    fontSize: 10.5,
                                                    fontWeight: FontWeight.w800,
                                                  ),
                                                ),
                                              ),
                                              Container(
                                                padding:
                                                    const EdgeInsets.symmetric(
                                                        horizontal: 8,
                                                        vertical: 2),
                                                decoration: BoxDecoration(
                                                  color: const Color(0xFF10B981)
                                                      .withOpacity(0.2),
                                                  borderRadius:
                                                      BorderRadius.circular(6),
                                                ),
                                                child: Text(
                                                  '+${act.xpReward} XP',
                                                  style: GoogleFonts.inter(
                                                    color:
                                                        const Color(0xFF34D399),
                                                    fontSize: 10.5,
                                                    fontWeight: FontWeight.w800,
                                                  ),
                                                ),
                                              ),
                                              Container(
                                                padding:
                                                    const EdgeInsets.symmetric(
                                                        horizontal: 8,
                                                        vertical: 2),
                                                decoration: BoxDecoration(
                                                  color: const Color(0xFFFACC15)
                                                      .withOpacity(0.18),
                                                  borderRadius:
                                                      BorderRadius.circular(6),
                                                ),
                                                child: Text(
                                                  'Badge: ${act.badgeIcon} ${act.badgeName}',
                                                  style: GoogleFonts.inter(
                                                    color:
                                                        const Color(0xFFFDE047),
                                                    fontSize: 10.5,
                                                    fontWeight: FontWeight.w700,
                                                  ),
                                                ),
                                              ),
                                            ],
                                          ),
                                          const SizedBox(height: 6),
                                          Text(
                                            act.title,
                                            style: GoogleFonts.outfit(
                                              color: Colors.white,
                                              fontSize: 15.5,
                                              fontWeight: FontWeight.w700,
                                            ),
                                          ),
                                          if (act.activityUrl.isNotEmpty) ...[
                                            const SizedBox(height: 2),
                                            Text(
                                              act.activityUrl,
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                              style: GoogleFonts.inter(
                                                color: Colors.white38,
                                                fontSize: 11,
                                              ),
                                            ),
                                          ],
                                        ],
                                      ),
                                    ),
                                    if (isFaculty)
                                      IconButton(
                                        tooltip: 'Delete Quest',
                                        onPressed: () =>
                                            service.deleteActivity(act.id),
                                        icon: const Icon(
                                          Icons.delete_outline_rounded,
                                          color: Colors.redAccent,
                                          size: 20,
                                        ),
                                      ),
                                  ],
                                ),
                                const SizedBox(height: 12),

                                // Student / Teacher Action Buttons
                                Row(
                                  children: [
                                    Expanded(
                                      child: OutlinedButton.icon(
                                        onPressed: () async {
                                          await service
                                              .markActivityLaunched(act.id);
                                          if (context.mounted) {
                                            await _launchResourceUrl(
                                                context, act.activityUrl);
                                          }
                                        },
                                        style: OutlinedButton.styleFrom(
                                          foregroundColor:
                                              const Color(0xFF38BDF8),
                                          side: const BorderSide(
                                              color: Color(0xFF38BDF8)),
                                          shape: RoundedRectangleBorder(
                                            borderRadius:
                                                BorderRadius.circular(10),
                                          ),
                                        ),
                                        icon: const Icon(
                                            Icons.open_in_new_rounded,
                                            size: 16),
                                        label: Text(
                                          'Launch Activity',
                                          style: GoogleFonts.inter(
                                            fontWeight: FontWeight.w700,
                                            fontSize: 12,
                                          ),
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 10),
                                    Expanded(
                                      child: ElevatedButton.icon(
                                        onPressed: isCompleted
                                            ? null
                                            : (isLaunched
                                                ? () async {
                                                    final badge = await service
                                                        .completeActivity(act);
                                                    if (badge != null &&
                                                        context.mounted) {
                                                      await showAchievementCelebrationDialog(
                                                        context: context,
                                                        badge: badge,
                                                        xpEarned: act.xpReward,
                                                      );
                                                    }
                                                  }
                                                : null),
                                        style: ElevatedButton.styleFrom(
                                          backgroundColor: isCompleted
                                              ? const Color(0xFF059669)
                                              : const Color(0xFF10B981),
                                          disabledBackgroundColor: isCompleted
                                              ? const Color(0xFF059669)
                                                  .withOpacity(0.5)
                                              : Colors.white10,
                                          foregroundColor: Colors.white,
                                          shape: RoundedRectangleBorder(
                                            borderRadius:
                                                BorderRadius.circular(10),
                                          ),
                                        ),
                                        icon: Icon(
                                          isCompleted
                                              ? Icons.verified_rounded
                                              : (isLaunched
                                                  ? Icons.check_circle_rounded
                                                  : Icons.lock_outline_rounded),
                                          size: 16,
                                        ),
                                        label: Text(
                                          isCompleted
                                              ? 'Completed ✓'
                                              : (isLaunched
                                                  ? 'Mark as Done'
                                                  : 'Launch First'),
                                          style: GoogleFonts.inter(
                                            fontWeight: FontWeight.w800,
                                            fontSize: 12,
                                          ),
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

/// Teacher Modal Form to "+ Post an Activity" with Title, Subject, URL, XP Reward,
/// and Selectable Pixel Badge Icon + Badge Title.
Future<void> showPostActivityModal({
  required BuildContext context,
  required String postedBy,
}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (ctx) => _PostActivityFormSheet(postedBy: postedBy),
  );
}

class _PostActivityFormSheet extends StatefulWidget {
  final String postedBy;

  const _PostActivityFormSheet({required this.postedBy});

  @override
  State<_PostActivityFormSheet> createState() => _PostActivityFormSheetState();
}

class _PostActivityFormSheetState extends State<_PostActivityFormSheet> {
  final _titleCtrl = TextEditingController();
  final _urlCtrl = TextEditingController();
  final _xpCtrl = TextEditingController(text: '100');
  final _badgeNameCtrl = TextEditingController(text: 'Quiz Conqueror');

  late String _selectedSubject;
  String _selectedBadgeIcon = kSelectableBadgeIcons.first['icon']!;

  @override
  void initState() {
    super.initState();
    final subjects = LobbyDataService.instance.subjectNames;
    _selectedSubject = subjects.isNotEmpty ? subjects.first : 'PPG';
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
    final badgeName = _badgeNameCtrl.text.trim();
    if (title.isEmpty || badgeName.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please enter an Activity Title and Badge Name.'),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    final xp = int.tryParse(_xpCtrl.text.trim()) ?? 100;
    await LobbyDataService.instance.postActivity(
      title: title,
      subject: _selectedSubject,
      activityUrl: _urlCtrl.text.trim(),
      xpReward: xp.clamp(10, 5000),
      badgeName: badgeName,
      badgeIcon: _selectedBadgeIcon,
      postedBy: widget.postedBy,
    );

    if (mounted) {
      Navigator.of(context).pop();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Posted "$title" to the School Lobby Quest Counter!'),
          backgroundColor: const Color(0xFF10B981),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final subjects = LobbyDataService.instance.subjectNames;
    final subjectOptions =
        subjects.isNotEmpty ? subjects : ['UCSP', 'PPG', 'PHILO', 'KASAYSAYAN'];

    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: Container(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.88,
        ),
        padding: const EdgeInsets.fromLTRB(20, 14, 20, 20),
        decoration: BoxDecoration(
          color: const Color(0xFF0F172A),
          borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
          border: Border.all(color: const Color(0xFFF59E0B).withOpacity(0.5)),
        ),
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  const Icon(Icons.post_add_rounded,
                      color: Color(0xFFF59E0B), size: 24),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'POST AN ACTIVITY (QUEST COUNTER)',
                      style: GoogleFonts.outfit(
                        color: Colors.white,
                        fontSize: 17,
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
              const SizedBox(height: 12),

              _buildFieldLabel('Activity Title'),
              TextField(
                controller: _titleCtrl,
                style: const TextStyle(color: Colors.white),
                decoration: _inputDecoration('e.g., Unit 2 Policy Analysis'),
              ),
              const SizedBox(height: 12),

              Row(
                children: [
                  Expanded(
                    flex: 3,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildFieldLabel('Subject Tag'),
                        DropdownButtonFormField<String>(
                          value: subjectOptions.contains(_selectedSubject)
                              ? _selectedSubject
                              : subjectOptions.first,
                          dropdownColor: const Color(0xFF1E293B),
                          style: const TextStyle(color: Colors.white),
                          decoration: _inputDecoration('Select subject'),
                          items: subjectOptions
                              .map((s) => DropdownMenuItem(
                                    value: s,
                                    child: Text(s),
                                  ))
                              .toList(),
                          onChanged: (val) {
                            if (val != null) {
                              setState(() => _selectedSubject = val);
                            }
                          },
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    flex: 2,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildFieldLabel('XP Reward'),
                        TextField(
                          controller: _xpCtrl,
                          keyboardType: TextInputType.number,
                          style: const TextStyle(color: Colors.white),
                          decoration: _inputDecoration('100'),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),

              _buildFieldLabel('Activity URL (Google Form, Drive, or Link)'),
              TextField(
                controller: _urlCtrl,
                style: const TextStyle(color: Colors.white),
                decoration:
                    _inputDecoration('https://docs.google.com/forms/...'),
              ),
              const SizedBox(height: 12),

              _buildFieldLabel('Custom Badge Title'),
              TextField(
                controller: _badgeNameCtrl,
                style: const TextStyle(color: Colors.white),
                decoration: _inputDecoration(
                    'e.g., Quiz Conqueror or Social Scientist'),
              ),
              const SizedBox(height: 12),

              _buildFieldLabel('Select Pixel / RPG Badge Icon'),
              const SizedBox(height: 6),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: kSelectableBadgeIcons.map((item) {
                  final icon = item['icon']!;
                  final selected = _selectedBadgeIcon == icon;
                  return InkWell(
                    onTap: () => setState(() => _selectedBadgeIcon = icon),
                    borderRadius: BorderRadius.circular(12),
                    child: Container(
                      width: 48,
                      height: 48,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: selected
                            ? const Color(0xFFFACC15).withOpacity(0.22)
                            : const Color(0xFF1E293B),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: selected
                              ? const Color(0xFFFACC15)
                              : Colors.white12,
                          width: selected ? 2 : 1,
                        ),
                      ),
                      child: Text(icon, style: const TextStyle(fontSize: 24)),
                    ),
                  );
                }).toList(),
              ),
              const SizedBox(height: 20),

              SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton.icon(
                  onPressed: _submit,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFF59E0B),
                    foregroundColor: Colors.black,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  icon: const Icon(Icons.publish_rounded),
                  label: Text(
                    'PUBLISH QUEST & BADGE',
                    style: GoogleFonts.outfit(
                      fontWeight: FontWeight.w900,
                      fontSize: 15,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildFieldLabel(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Text(
        text,
        style: GoogleFonts.inter(
          color: Colors.white70,
          fontSize: 12,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }

  InputDecoration _inputDecoration(String hint) {
    return InputDecoration(
      hintText: hint,
      hintStyle: const TextStyle(color: Colors.white30, fontSize: 13),
      filled: true,
      fillColor: const Color(0xFF1E293B),
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: Colors.white12),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: Colors.white12),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: Color(0xFFF59E0B)),
      ),
    );
  }
}

// =============================================================================
// STUDENT "MY BADGES / ACHIEVEMENTS" HUD DRAWER MODAL
// =============================================================================

Future<void> showMyBadgesModal({required BuildContext context}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (ctx) => const _MyBadgesSheet(),
  );
}

class _MyBadgesSheet extends StatelessWidget {
  const _MyBadgesSheet();

  @override
  Widget build(BuildContext context) {
    final service = LobbyDataService.instance;
    final media = MediaQuery.of(context);

    return AnimatedBuilder(
      animation: service,
      builder: (context, _) {
        final progress = service.progress;
        final badges = progress.earnedBadges;
        final equippedId = progress.equippedBadgeId;

        return Container(
          height: media.size.height * 0.78,
          decoration: BoxDecoration(
            color: const Color(0xFF0F172A),
            borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
            border: Border.all(
              color: const Color(0xFFFACC15).withOpacity(0.45),
              width: 1.5,
            ),
          ),
          child: Column(
            children: [
              const SizedBox(height: 10),
              Container(
                width: 44,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.white24,
                  borderRadius: BorderRadius.circular(99),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 14, 14, 8),
                child: Row(
                  children: [
                    const Icon(Icons.workspace_premium_rounded,
                        color: Color(0xFFFACC15), size: 26),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'MY BADGES & ACHIEVEMENTS',
                            style: GoogleFonts.outfit(
                              color: Colors.white,
                              fontSize: 17,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          Text(
                            'Equip any earned badge to display next to your avatar nameplate!',
                            style: GoogleFonts.inter(
                              color: Colors.white60,
                              fontSize: 12,
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

              // Level, XP & Treasure Hunter Milestone Card
              Container(
                margin: const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: const Color(0xFF1E293B),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: Colors.white12),
                ),
                child: Column(
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 10, vertical: 6),
                          decoration: BoxDecoration(
                            color: const Color(0xFF38BDF8).withOpacity(0.2),
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: const Color(0xFF38BDF8)),
                          ),
                          child: Text(
                            'LVL ${progress.level}',
                            style: GoogleFonts.outfit(
                              color: const Color(0xFF38BDF8),
                              fontWeight: FontWeight.w900,
                              fontSize: 14,
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(
                                    'Total XP: ${progress.xp}',
                                    style: GoogleFonts.inter(
                                      color: Colors.white,
                                      fontWeight: FontWeight.w700,
                                      fontSize: 12.5,
                                    ),
                                  ),
                                  Text(
                                    '${progress.xpIntoCurrentLevel}/100 XP to next level',
                                    style: GoogleFonts.inter(
                                      color: Colors.white54,
                                      fontSize: 11,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 6),
                              ClipRRect(
                                borderRadius: BorderRadius.circular(99),
                                child: LinearProgressIndicator(
                                  value: progress.xpIntoCurrentLevel / 100.0,
                                  minHeight: 7,
                                  backgroundColor: const Color(0xFF0F172A),
                                  valueColor: const AlwaysStoppedAnimation(
                                      Color(0xFF34D399)),
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
                        const Text('🏆', style: TextStyle(fontSize: 16)),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'Treasure Hunter Progress (Mini Mystery Chests): '
                            '${progress.smallChestCorrectCount}/${LobbyDataService.kTreasureHunterTarget}',
                            style: GoogleFonts.inter(
                              color: const Color(0xFFFDE047),
                              fontSize: 11.5,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              // Earned Badges List
              Expanded(
                child: badges.isEmpty
                    ? Center(
                        child: Padding(
                          padding: const EdgeInsets.all(28.0),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Text('🛡️', style: TextStyle(fontSize: 42)),
                              const SizedBox(height: 10),
                              Text(
                                'No Badges Earned Yet',
                                style: GoogleFonts.outfit(
                                  color: Colors.white,
                                  fontSize: 16,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                'Visit the Reception Quest Counter or solve 5 Small Mystery Chests around the lobby to unlock your first badge!',
                                textAlign: TextAlign.center,
                                style: GoogleFonts.inter(
                                  color: Colors.white54,
                                  fontSize: 12.5,
                                ),
                              ),
                            ],
                          ),
                        ),
                      )
                    : ListView.separated(
                        padding: const EdgeInsets.fromLTRB(18, 8, 18, 24),
                        itemCount: badges.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 10),
                        itemBuilder: (context, index) {
                          final b = badges[index];
                          final isEquipped = equippedId == b.id;
                          return Container(
                            padding: const EdgeInsets.all(14),
                            decoration: BoxDecoration(
                              color: isEquipped
                                  ? const Color(0xFFFACC15).withOpacity(0.14)
                                  : const Color(0xFF1E293B),
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(
                                color: isEquipped
                                    ? const Color(0xFFFACC15)
                                    : Colors.white12,
                                width: isEquipped ? 1.8 : 1.0,
                              ),
                            ),
                            child: Row(
                              children: [
                                Container(
                                  width: 50,
                                  height: 50,
                                  alignment: Alignment.center,
                                  decoration: BoxDecoration(
                                    color: const Color(0xFF0F172A),
                                    borderRadius: BorderRadius.circular(14),
                                    border: Border.all(
                                        color: const Color(0xFFFACC15)
                                            .withOpacity(0.5)),
                                  ),
                                  child: Text(
                                    b.badgeIcon,
                                    style: const TextStyle(fontSize: 26),
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
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
                                        b.description,
                                        style: GoogleFonts.inter(
                                          color: Colors.white60,
                                          fontSize: 11.5,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(width: 8),
                                ElevatedButton(
                                  onPressed: () => service.equipBadge(
                                      isEquipped ? null : b.id),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: isEquipped
                                        ? const Color(0xFFFACC15)
                                        : const Color(0xFF334155),
                                    foregroundColor: isEquipped
                                        ? Colors.black
                                        : Colors.white,
                                    visualDensity: VisualDensity.compact,
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(10),
                                    ),
                                  ),
                                  child: Text(
                                    isEquipped ? 'Equipped ★' : 'Equip',
                                    style: GoogleFonts.inter(
                                      fontWeight: FontWeight.w800,
                                      fontSize: 11.5,
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

// =============================================================================
// FEATURE 2: SUBJECT-LABELED LARGE TREASURE CHEST MODAL (REVIEWER VAULT)
// =============================================================================

Future<void> showSubjectChestModal({
  required BuildContext context,
  required String chestId,
  required bool isFaculty,
}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (ctx) => _SubjectChestModalSheet(
      chestId: chestId,
      isFaculty: isFaculty,
    ),
  );
}

class _SubjectChestModalSheet extends StatelessWidget {
  final String chestId;
  final bool isFaculty;

  const _SubjectChestModalSheet({
    required this.chestId,
    required this.isFaculty,
  });

  @override
  Widget build(BuildContext context) {
    final service = LobbyDataService.instance;
    final media = MediaQuery.of(context);

    return AnimatedBuilder(
      animation: service,
      builder: (context, _) {
        final chest = service.getChestById(chestId);
        if (chest == null) {
          return const SizedBox.shrink();
        }
        final subjectColor = Color(chest.colorValue);

        return Container(
          height: media.size.height * 0.85,
          decoration: BoxDecoration(
            color: const Color(0xFF0F172A),
            borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
            border: Border.all(color: subjectColor.withOpacity(0.65), width: 1.8),
          ),
          child: Column(
            children: [
              const SizedBox(height: 10),
              Container(
                width: 44,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.white24,
                  borderRadius: BorderRadius.circular(99),
                ),
              ),

              // RPG Inventory Header: "[Subject Name] Reviewer Chest"
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 14, 14, 10),
                child: Row(
                  children: [
                    Container(
                      width: 46,
                      height: 46,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: subjectColor.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: subjectColor, width: 1.6),
                      ),
                      child: const Text('📦', style: TextStyle(fontSize: 24)),
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
                            '${chest.reviewers.length} Reviewer Scroll(s) • ${chest.totalQuestions} Quiz Questions in Pool',
                            style: GoogleFonts.inter(
                              color: Colors.white60,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ),
                    if (isFaculty)
                      IconButton(
                        tooltip: 'Rename Subject Chest',
                        onPressed: () =>
                            _showRenameChestDialog(context, chest),
                        icon: const Icon(Icons.edit_rounded,
                            color: Colors.white70, size: 20),
                      ),
                    IconButton(
                      onPressed: () => Navigator.of(context).pop(),
                      icon: const Icon(Icons.close_rounded,
                          color: Colors.white70),
                    ),
                  ],
                ),
              ),

              // Teacher Action Bar: "+ Add Reviewer"
              if (isFaculty)
                Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 18, vertical: 4),
                  child: Row(
                    children: [
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: () => _showAddReviewerSheet(
                            context: context,
                            chest: chest,
                          ),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: subjectColor,
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          icon: const Icon(Icons.add_box_rounded, size: 18),
                          label: Text(
                            '+ Add Reviewer to ${chest.subjectName} Chest',
                            style: GoogleFonts.inter(
                              fontWeight: FontWeight.w800,
                              fontSize: 12.5,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

              // Reviewer Inventory Items
              Expanded(
                child: chest.reviewers.isEmpty
                    ? Center(
                        child: Text(
                          'This Subject Chest is empty. ${isFaculty ? "Tap + Add Reviewer above!" : "Check back soon!"}',
                          style: GoogleFonts.inter(color: Colors.white54),
                        ),
                      )
                    : ListView.separated(
                        padding: const EdgeInsets.fromLTRB(18, 10, 18, 24),
                        itemCount: chest.reviewers.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 12),
                        itemBuilder: (context, index) {
                          final rev = chest.reviewers[index];
                          return Container(
                            padding: const EdgeInsets.all(14),
                            decoration: BoxDecoration(
                              color: const Color(0xFF1E293B),
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(
                                color: subjectColor.withOpacity(0.35),
                              ),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    const Text('📜',
                                        style: TextStyle(fontSize: 22)),
                                    const SizedBox(width: 10),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            rev.title,
                                            style: GoogleFonts.outfit(
                                              color: Colors.white,
                                              fontSize: 15.5,
                                              fontWeight: FontWeight.w800,
                                            ),
                                          ),
                                          Text(
                                            '${rev.questions.length} Pop-Quiz Question(s) linked to Small Mystery Chests',
                                            style: GoogleFonts.inter(
                                              color: const Color(0xFFA855F7),
                                              fontSize: 11,
                                              fontWeight: FontWeight.w700,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  rev.studyNotes,
                                  maxLines: 3,
                                  overflow: TextOverflow.ellipsis,
                                  style: GoogleFonts.inter(
                                    color: Colors.white70,
                                    fontSize: 12,
                                    height: 1.4,
                                  ),
                                ),
                                const SizedBox(height: 12),
                                Wrap(
                                  spacing: 8,
                                  runSpacing: 8,
                                  children: [
                                    ElevatedButton.icon(
                                      onPressed: () =>
                                          _showReviewerReaderDialog(
                                        context: context,
                                        chest: chest,
                                        reviewer: rev,
                                      ),
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: subjectColor,
                                        foregroundColor: Colors.white,
                                        visualDensity: VisualDensity.compact,
                                        shape: RoundedRectangleBorder(
                                          borderRadius:
                                              BorderRadius.circular(10),
                                        ),
                                      ),
                                      icon: const Icon(Icons.menu_book_rounded,
                                          size: 16),
                                      label: const Text('Read Study Notes'),
                                    ),
                                    if (rev.resourceUrl.isNotEmpty)
                                      OutlinedButton.icon(
                                        onPressed: () => _launchResourceUrl(
                                            context, rev.resourceUrl),
                                        style: OutlinedButton.styleFrom(
                                          foregroundColor:
                                              const Color(0xFF38BDF8),
                                          side: const BorderSide(
                                              color: Color(0xFF38BDF8)),
                                          visualDensity: VisualDensity.compact,
                                          shape: RoundedRectangleBorder(
                                            borderRadius:
                                                BorderRadius.circular(10),
                                          ),
                                        ),
                                        icon: const Icon(
                                            Icons.open_in_new_rounded,
                                            size: 15),
                                        label: const Text('Open Link'),
                                      ),
                                    if (isFaculty)
                                      OutlinedButton.icon(
                                        onPressed: () =>
                                            _showAddQuestionToReviewerSheet(
                                          context: context,
                                          chest: chest,
                                          reviewer: rev,
                                        ),
                                        style: OutlinedButton.styleFrom(
                                          foregroundColor:
                                              const Color(0xFFFACC15),
                                          side: const BorderSide(
                                              color: Color(0xFFFACC15)),
                                          visualDensity: VisualDensity.compact,
                                          shape: RoundedRectangleBorder(
                                            borderRadius:
                                                BorderRadius.circular(10),
                                          ),
                                        ),
                                        icon: const Icon(
                                            Icons.quiz_rounded,
                                            size: 15),
                                        label: const Text(
                                            '+ Add Question from this Reviewer'),
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

  void _showRenameChestDialog(BuildContext context, SubjectChest chest) {
    final ctrl = TextEditingController(text: chest.subjectName);
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1E293B),
        title: Text(
          'Rename Subject Chest',
          style: GoogleFonts.outfit(
              color: Colors.white, fontWeight: FontWeight.w800),
        ),
        content: TextField(
          controller: ctrl,
          style: const TextStyle(color: Colors.white),
          decoration: const InputDecoration(
            labelText: 'Subject Name (shown on floating banner)',
            labelStyle: TextStyle(color: Colors.white70),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              final next = ctrl.text.trim();
              if (next.isNotEmpty) {
                await LobbyDataService.instance.updateSubjectChest(
                  chestId: chest.id,
                  newSubjectName: next,
                );
              }
              if (ctx.mounted) Navigator.of(ctx).pop();
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }
}

void _showReviewerReaderDialog({
  required BuildContext context,
  required SubjectChest chest,
  required LobbyReviewerItem reviewer,
}) {
  showDialog<void>(
    context: context,
    builder: (ctx) => Dialog(
      backgroundColor: const Color(0xFF0F172A),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(22),
        side: BorderSide(color: Color(chest.colorValue), width: 1.8),
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxHeight: 500),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: Color(chest.colorValue),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      chest.subjectName,
                      style: GoogleFonts.inter(
                        color: Colors.white,
                        fontSize: 10.5,
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
              Text(
                reviewer.title,
                style: GoogleFonts.outfit(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const Divider(color: Colors.white12, height: 20),
              Expanded(
                child: SingleChildScrollView(
                  child: SelectableText(
                    reviewer.studyNotes,
                    style: GoogleFonts.inter(
                      color: Colors.white.withOpacity(0.9),
                      fontSize: 13.5,
                      height: 1.55,
                    ),
                  ),
                ),
              ),
              if (reviewer.resourceUrl.isNotEmpty) ...[
                const SizedBox(height: 14),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: () =>
                        _launchResourceUrl(context, reviewer.resourceUrl),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Color(chest.colorValue),
                      foregroundColor: Colors.white,
                    ),
                    icon: const Icon(Icons.open_in_new_rounded, size: 16),
                    label: const Text('Open Full Reviewer Module Link'),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    ),
  );
}

void _showAddReviewerSheet({
  required BuildContext context,
  required SubjectChest chest,
}) {
  final titleCtrl = TextEditingController();
  final notesCtrl = TextEditingController();
  final urlCtrl = TextEditingController();

  showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (ctx) => Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom),
      child: Container(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
        decoration: BoxDecoration(
          color: const Color(0xFF0F172A),
          borderRadius: const BorderRadius.vertical(top: Radius.circular(26)),
          border: Border.all(color: Color(chest.colorValue)),
        ),
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                '+ Add Reviewer to ${chest.subjectName} Chest',
                style: GoogleFonts.outfit(
                  color: Colors.white,
                  fontSize: 17,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: titleCtrl,
                style: const TextStyle(color: Colors.white),
                decoration: const InputDecoration(
                  labelText: 'Reviewer Title',
                  labelStyle: TextStyle(color: Colors.white70),
                  filled: true,
                  fillColor: Color(0xFF1E293B),
                ),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: notesCtrl,
                maxLines: 4,
                style: const TextStyle(color: Colors.white),
                decoration: const InputDecoration(
                  labelText: 'Study Notes / Outline Summary',
                  labelStyle: TextStyle(color: Colors.white70),
                  filled: true,
                  fillColor: Color(0xFF1E293B),
                ),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: urlCtrl,
                style: const TextStyle(color: Colors.white),
                decoration: const InputDecoration(
                  labelText: 'Optional Module / Drive Link URL',
                  labelStyle: TextStyle(color: Colors.white70),
                  filled: true,
                  fillColor: Color(0xFF1E293B),
                ),
              ),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                height: 48,
                child: ElevatedButton.icon(
                  onPressed: () async {
                    if (titleCtrl.text.trim().isEmpty) return;
                    await LobbyDataService.instance.addReviewerToChest(
                      chestId: chest.id,
                      title: titleCtrl.text.trim(),
                      studyNotes: notesCtrl.text.trim().isEmpty
                          ? 'Key concepts and outline notes for ${titleCtrl.text.trim()}.'
                          : notesCtrl.text.trim(),
                      resourceUrl: urlCtrl.text.trim(),
                    );
                    if (ctx.mounted) Navigator.of(ctx).pop();
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Color(chest.colorValue),
                    foregroundColor: Colors.white,
                  ),
                  icon: const Icon(Icons.save_rounded),
                  label: const Text('Save Reviewer to Chest'),
                ),
              ),
            ],
          ),
        ),
      ),
    ),
  );
}

/// Teacher Helper inside Reviewer Modal: "+ Add Question from this Reviewer"
/// Supports both Single Question Builder AND Quick JSONPaste for the Shared Question Pool.
void _showAddQuestionToReviewerSheet({
  required BuildContext context,
  required SubjectChest chest,
  required LobbyReviewerItem reviewer,
}) {
  showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (ctx) => _AddQuestionsSheet(
      chest: chest,
      reviewer: reviewer,
    ),
  );
}

class _AddQuestionsSheet extends StatefulWidget {
  final SubjectChest chest;
  final LobbyReviewerItem reviewer;

  const _AddQuestionsSheet({
    required this.chest,
    required this.reviewer,
  });

  @override
  State<_AddQuestionsSheet> createState() => _AddQuestionsSheetState();
}

class _AddQuestionsSheetState extends State<_AddQuestionsSheet> {
  bool _isJsonMode = false;
  final _qTextCtrl = TextEditingController();
  final _opt0Ctrl = TextEditingController();
  final _opt1Ctrl = TextEditingController();
  final _opt2Ctrl = TextEditingController();
  final _opt3Ctrl = TextEditingController();
  final _jsonPasteCtrl = TextEditingController();
  int _correctIdx = 0;

  @override
  void dispose() {
    _qTextCtrl.dispose();
    _opt0Ctrl.dispose();
    _opt1Ctrl.dispose();
    _opt2Ctrl.dispose();
    _opt3Ctrl.dispose();
    _jsonPasteCtrl.dispose();
    super.dispose();
  }

  Future<void> _submitSingle() async {
    final qText = _qTextCtrl.text.trim();
    final options = [
      _opt0Ctrl.text.trim(),
      _opt1Ctrl.text.trim(),
      _opt2Ctrl.text.trim(),
      _opt3Ctrl.text.trim(),
    ].where((e) => e.isNotEmpty).toList();

    if (qText.isEmpty || options.length < 2) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Enter a question and at least 2 answer choices.'),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    final q = ReviewerQuestion(
      id: 'q_${DateTime.now().millisecondsSinceEpoch}',
      questionText: qText,
      options: options,
      correctIndex: _correctIdx.clamp(0, options.length - 1),
      subject: widget.chest.subjectName,
      reviewerTitle: widget.reviewer.title,
    );

    await LobbyDataService.instance.addQuestionsToReviewer(
      chestId: widget.chest.id,
      reviewerId: widget.reviewer.id,
      newQuestions: [q],
    );

    if (mounted) {
      Navigator.of(context).pop();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content:
              Text('Added question to Small Mystery Chest Question Pool!'),
          backgroundColor: Color(0xFF10B981),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  Future<void> _submitJsonBatch() async {
    final raw = _jsonPasteCtrl.text.trim();
    if (raw.isEmpty) return;

    final parsed = <ReviewerQuestion>[];
    try {
      final decoded = jsonDecode(raw);
      if (decoded is List) {
        for (final item in decoded) {
          if (item is Map) {
            parsed.add(
              ReviewerQuestion.fromJson(Map<String, dynamic>.from(item)),
            );
          }
        }
      }
    } catch (_) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
              'Invalid JSON format. Expected: [{"questionText":"...","options":["A","B"],"correctIndex":0}]'),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    if (parsed.isEmpty) return;
    await LobbyDataService.instance.addQuestionsToReviewer(
      chestId: widget.chest.id,
      reviewerId: widget.reviewer.id,
      newQuestions: parsed,
    );
    if (mounted) {
      Navigator.of(context).pop();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content:
              Text('Imported ${parsed.length} question(s) into the Pool!'),
          backgroundColor: const Color(0xFF10B981),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: Container(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
        decoration: BoxDecoration(
          color: const Color(0xFF0F172A),
          borderRadius: const BorderRadius.vertical(top: Radius.circular(26)),
          border: Border.all(color: const Color(0xFFFACC15)),
        ),
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      '+ Add Question (${widget.chest.subjectName})',
                      style: GoogleFonts.outfit(
                        color: Colors.white,
                        fontSize: 16.5,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                  TextButton(
                    onPressed: () => setState(() => _isJsonMode = !_isJsonMode),
                    child: Text(
                      _isJsonMode ? 'Single Form' : 'Paste JSON Batch',
                      style: const TextStyle(color: Color(0xFF38BDF8)),
                    ),
                  ),
                ],
              ),
              Text(
                'Reviewer: ${widget.reviewer.title}',
                style: GoogleFonts.inter(color: Colors.white54, fontSize: 12),
              ),
              const SizedBox(height: 12),
              if (_isJsonMode) ...[
                TextField(
                  controller: _jsonPasteCtrl,
                  maxLines: 6,
                  style: const TextStyle(color: Colors.white, fontSize: 12),
                  decoration: const InputDecoration(
                    hintText:
                        '[{"questionText": "Question?", "options": ["A", "B", "C", "D"], "correctIndex": 0}]',
                    hintStyle: TextStyle(color: Colors.white30),
                    filled: true,
                    fillColor: Color(0xFF1E293B),
                  ),
                ),
                const SizedBox(height: 14),
                SizedBox(
                  width: double.infinity,
                  height: 46,
                  child: ElevatedButton.icon(
                    onPressed: _submitJsonBatch,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFFACC15),
                      foregroundColor: Colors.black,
                    ),
                    icon: const Icon(Icons.upload_rounded),
                    label: const Text('Import Questions JSON'),
                  ),
                ),
              ] else ...[
                TextField(
                  controller: _qTextCtrl,
                  maxLines: 2,
                  style: const TextStyle(color: Colors.white),
                  decoration: const InputDecoration(
                    labelText: 'Question Text',
                    labelStyle: TextStyle(color: Colors.white70),
                    filled: true,
                    fillColor: Color(0xFF1E293B),
                  ),
                ),
                const SizedBox(height: 10),
                ...List.generate(4, (i) {
                  final ctrls = [_opt0Ctrl, _opt1Ctrl, _opt2Ctrl, _opt3Ctrl];
                  final labels = ['Option A', 'Option B', 'Option C', 'Option D'];
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Row(
                      children: [
                        Radio<int>(
                          value: i,
                          groupValue: _correctIdx,
                          activeColor: const Color(0xFF10B981),
                          onChanged: (v) =>
                              setState(() => _correctIdx = v ?? 0),
                        ),
                        Expanded(
                          child: TextField(
                            controller: ctrls[i],
                            style: const TextStyle(color: Colors.white),
                            decoration: InputDecoration(
                              labelText:
                                  '${labels[i]}${_correctIdx == i ? " (Correct Answer)" : ""}',
                              labelStyle: TextStyle(
                                color: _correctIdx == i
                                    ? const Color(0xFF34D399)
                                    : Colors.white60,
                              ),
                              filled: true,
                              fillColor: const Color(0xFF1E293B),
                              isDense: true,
                            ),
                          ),
                        ),
                      ],
                    ),
                  );
                }),
                const SizedBox(height: 10),
                SizedBox(
                  width: double.infinity,
                  height: 46,
                  child: ElevatedButton.icon(
                    onPressed: _submitSingle,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF10B981),
                      foregroundColor: Colors.white,
                    ),
                    icon: const Icon(Icons.add_task_rounded),
                    label: const Text('Add Question to Mystery Chest Pool'),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    ),
  );
}

// =============================================================================
// FEATURE 3: SMALL MYSTERY CHEST POP-QUIZ MODAL (+20 XP & 2-MIN COOLDOWN)
// =============================================================================

Future<void> showSmallMysteryChestModal({
  required BuildContext context,
  required String smallChestId,
  required String smallChestLabel,
}) {
  return showDialog<void>(
    context: context,
    builder: (ctx) => _SmallMysteryChestDialog(
      smallChestId: smallChestId,
      smallChestLabel: smallChestLabel,
    ),
  );
}

class _SmallMysteryChestDialog extends StatefulWidget {
  final String smallChestId;
  final String smallChestLabel;

  const _SmallMysteryChestDialog({
    required this.smallChestId,
    required this.smallChestLabel,
  });

  @override
  State<_SmallMysteryChestDialog> createState() =>
      _SmallMysteryChestDialogState();
}

class _SmallMysteryChestDialogState extends State<_SmallMysteryChestDialog> {
  ReviewerQuestion? _question;
  int? _selectedIndex;
  bool _resolved = false;
  bool _wasCorrect = false;
  LobbyBadge? _unlockedTreasureBadge;

  @override
  void initState() {
    super.initState();
    final service = LobbyDataService.instance;
    if (!service.isSmallChestOnCooldown(widget.smallChestId)) {
      _question = service.drawRandomMysteryQuestion();
    }
  }

  Future<void> _selectOption(int index) async {
    if (_resolved || _question == null) return;
    final correct = index == _question!.correctIndex;
    HapticFeedback.mediumImpact();

    LobbyBadge? badge;
    if (correct) {
      badge = await LobbyDataService.instance.recordSmallChestSuccess(
        smallChestId: widget.smallChestId,
        question: _question!,
      );
    }

    if (mounted) {
      setState(() {
        _selectedIndex = index;
        _resolved = true;
        _wasCorrect = correct;
        _unlockedTreasureBadge = badge;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final service = LobbyDataService.instance;
    final remainingSec =
        service.smallChestRemainingSeconds(widget.smallChestId);

    // If already on cooldown before answering in this session
    if (!_resolved && remainingSec > 0) {
      final mins = remainingSec ~/ 60;
      final secs = (remainingSec % 60).toString().padLeft(2, '0');
      return Dialog(
        backgroundColor: const Color(0xFF0F172A),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(22),
          side: const BorderSide(color: Color(0xFFA855F7), width: 1.6),
        ),
        child: Padding(
          padding: const EdgeInsets.all(22),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('⏳', style: TextStyle(fontSize: 40)),
              const SizedBox(height: 10),
              Text(
                'CHEST RECHARGING',
                style: GoogleFonts.outfit(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                'This Mystery Chest was recently opened!\nCooldown remaining: $mins:$secs',
                textAlign: TextAlign.center,
                style: GoogleFonts.inter(color: Colors.white70, fontSize: 13),
              ),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('Got it'),
              ),
            ],
          ),
        ),
      );
    }

    final q = _question;
    if (q == null) {
      return Dialog(
        backgroundColor: const Color(0xFF0F172A),
        child: Padding(
          padding: const EdgeInsets.all(22),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'No questions in the Reviewer Pool yet!',
                style: GoogleFonts.outfit(color: Colors.white, fontSize: 16),
              ),
              const SizedBox(height: 12),
              ElevatedButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('Close'),
              ),
            ],
          ),
        ),
      );
    }

    return Dialog(
      backgroundColor: Colors.transparent,
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [Color(0xFF2E1065), Color(0xFF0F172A)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(24),
          border: Border.all(
            color: _resolved
                ? (_wasCorrect
                    ? const Color(0xFF10B981)
                    : const Color(0xFFEF4444))
                : const Color(0xFFA855F7),
            width: 2.0,
          ),
        ),
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              // Header: Chest Challenge! + Subject/Reviewer origin tag
              Row(
                children: [
                  Text(
                    _resolved && _wasCorrect ? '🔓' : '✨',
                    style: const TextStyle(fontSize: 22),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'CHEST CHALLENGE!',
                      style: GoogleFonts.outfit(
                        color: const Color(0xFFFDE047),
                        fontSize: 16,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 0.7,
                      ),
                    ),
                  ),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: const Color(0xFF10B981).withOpacity(0.2),
                      borderRadius: BorderRadius.circular(99),
                      border: Border.all(color: const Color(0xFF10B981)),
                    ),
                    child: Text(
                      '+20 XP',
                      style: GoogleFonts.inter(
                        color: const Color(0xFF34D399),
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),

              // Origin Tag: Subject & Reviewer Title
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: Colors.black.withOpacity(0.35),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.white12),
                ),
                child: Text(
                  '📚 ${q.subject} • ${q.reviewerTitle}',
                  style: GoogleFonts.inter(
                    color: const Color(0xFF38BDF8),
                    fontSize: 11.5,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              const SizedBox(height: 14),

              // Question Prompt
              Text(
                q.questionText,
                style: GoogleFonts.outfit(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  height: 1.35,
                ),
              ),
              const SizedBox(height: 14),

              // Options
              ...List.generate(q.options.length, (i) {
                final isSelected = _selectedIndex == i;
                final isCorrectOpt = i == q.correctIndex;
                Color bgColor = const Color(0xFF1E293B);
                Color borderColor = Colors.white12;

                if (_resolved) {
                  if (isCorrectOpt) {
                    bgColor = const Color(0xFF065F46);
                    borderColor = const Color(0xFF10B981);
                  } else if (isSelected && !isCorrectOpt) {
                    bgColor = const Color(0xFF7F1D1D);
                    borderColor = const Color(0xFFEF4444);
                  }
                }

                final letter = String.fromCharCode(65 + i);
                return Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: InkWell(
                    onTap: _resolved ? null : () => _selectOption(i),
                    borderRadius: BorderRadius.circular(12),
                    child: Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 11),
                      decoration: BoxDecoration(
                        color: bgColor,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: borderColor, width: 1.5),
                      ),
                      child: Row(
                        children: [
                          Container(
                            width: 24,
                            height: 24,
                            alignment: Alignment.center,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: Colors.black.withOpacity(0.35),
                            ),
                            child: Text(
                              letter,
                              style: GoogleFonts.inter(
                                color: Colors.white,
                                fontSize: 11.5,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              q.options[i],
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

              // Reward / Result Banner
              if (_resolved) ...[
                const SizedBox(height: 8),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: _wasCorrect
                        ? const Color(0xFF10B981).withOpacity(0.18)
                        : const Color(0xFFEF4444).withOpacity(0.18),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Column(
                    children: [
                      Text(
                        _wasCorrect
                            ? '🎉 CHEST OPENED! +20 BONUS XP AWARDED!'
                            : '❌ Not quite! Try another chest or study the ${q.subject} Reviewer Chest!',
                        textAlign: TextAlign.center,
                        style: GoogleFonts.inter(
                          color: _wasCorrect
                              ? const Color(0xFF34D399)
                              : const Color(0xFFFCA5A5),
                          fontWeight: FontWeight.w800,
                          fontSize: 12.5,
                        ),
                      ),
                      if (_wasCorrect) ...[
                        const SizedBox(height: 4),
                        Text(
                          'Treasure Hunter Progress: ${service.progress.smallChestCorrectCount}/${LobbyDataService.kTreasureHunterTarget} • Chest on 2-min cooldown',
                          textAlign: TextAlign.center,
                          style: GoogleFonts.inter(
                            color: Colors.white70,
                            fontSize: 11,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () async {
                      final badge = _unlockedTreasureBadge;
                      Navigator.of(context).pop();
                      if (badge != null && context.mounted) {
                        await showAchievementCelebrationDialog(
                          context: context,
                          badge: badge,
                          xpEarned: 20,
                        );
                      }
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFFACC15),
                      foregroundColor: Colors.black,
                    ),
                    child: Text(
                      'Continue Exploring',
                      style: GoogleFonts.inter(fontWeight: FontWeight.w800),
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

// =============================================================================
// TEACHER'S CORNER / SUBJECT CHEST MANAGER & BULLETIN BOARD MODALS
// =============================================================================

Future<void> showTeacherCornerModal({
  required BuildContext context,
  required bool isFaculty,
  required String userName,
}) {
  return showModalBottomSheet<void>(
    context: context,
    backgroundColor: Colors.transparent,
    isScrollControlled: true,
    builder: (ctx) {
      final service = LobbyDataService.instance;
      return AnimatedBuilder(
        animation: service,
        builder: (context, _) {
          final chests = service.subjectChests;
          return Container(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
            decoration: BoxDecoration(
              color: const Color(0xFF0F172A),
              borderRadius:
                  const BorderRadius.vertical(top: Radius.circular(26)),
              border: Border.all(color: const Color(0xFFEAB308)),
            ),
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.school_rounded,
                          color: Color(0xFFFACC15), size: 24),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          "TEACHER'S CORNER & SUBJECT VAULT MANAGER",
                          style: GoogleFonts.outfit(
                            color: Colors.white,
                            fontSize: 16.5,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                      IconButton(
                        onPressed: () => Navigator.of(ctx).pop(),
                        icon: const Icon(Icons.close_rounded,
                            color: Colors.white70),
                      ),
                    ],
                  ),
                  Text(
                    isFaculty
                        ? 'Faculty Access granted! You can post new Quest Counter activities or add/rename Subject Chests in the Reviewer Treasure Corner.'
                        : 'Faculty Advisory Desk — Walk to the Reviewer Treasure Corner (bottom-right) to open the Subject Chests for UCSP, PPG, PHILO, and KASAYSAYAN!',
                    style:
                        GoogleFonts.inter(color: Colors.white70, fontSize: 12.5),
                  ),
                  const SizedBox(height: 14),
                  if (isFaculty) ...[
                    Row(
                      children: [
                        Expanded(
                          child: ElevatedButton.icon(
                            onPressed: () {
                              Navigator.of(ctx).pop();
                              showPostActivityModal(
                                context: context,
                                postedBy: userName,
                              );
                            },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFFF59E0B),
                              foregroundColor: Colors.black,
                            ),
                            icon: const Icon(Icons.post_add_rounded, size: 18),
                            label: const Text('+ Post Quest Activity'),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: ElevatedButton.icon(
                            onPressed: () =>
                                _showAddSubjectChestDialog(context),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF10B981),
                              foregroundColor: Colors.white,
                            ),
                            icon: const Icon(Icons.add_box_rounded, size: 18),
                            label: const Text('+ Add Subject Chest'),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),
                  ],
                  Text(
                    'SUBJECT CHESTS ON MAP (${chests.length})',
                    style: GoogleFonts.outfit(
                      color: const Color(0xFFFDE047),
                      fontSize: 13,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 8),
                  ...chests.map(
                    (c) => ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: CircleAvatar(
                        backgroundColor: Color(c.colorValue),
                        child: const Text('📦'),
                      ),
                      title: Text(
                        '${c.subjectName} Reviewer Chest',
                        style: GoogleFonts.inter(
                            color: Colors.white, fontWeight: FontWeight.w700),
                      ),
                      subtitle: Text(
                        '${c.reviewers.length} Reviewer(s) • ${c.totalQuestions} Quiz Questions',
                        style: GoogleFonts.inter(
                            color: Colors.white54, fontSize: 12),
                      ),
                      trailing: TextButton(
                        onPressed: () {
                          Navigator.of(ctx).pop();
                          showSubjectChestModal(
                            context: context,
                            chestId: c.id,
                            isFaculty: isFaculty,
                          );
                        },
                        child: const Text('Open Chest →'),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      );
    },
  );
}

void _showAddSubjectChestDialog(BuildContext context) {
  final ctrl = TextEditingController();
  final palette = [
    0xFF10B981,
    0xFF3B82F6,
    0xFFA855F7,
    0xFFF59E0B,
    0xFFEC4899,
    0xFF06B6D4,
  ];
  var pickedColor = palette.first;

  showDialog<void>(
    context: context,
    builder: (ctx) => StatefulBuilder(
      builder: (ctx, setDialogState) => AlertDialog(
        backgroundColor: const Color(0xFF1E293B),
        title: Text(
          '+ Add Subject Treasure Chest',
          style: GoogleFonts.outfit(
              color: Colors.white, fontWeight: FontWeight.w800),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TextField(
              controller: ctrl,
              style: const TextStyle(color: Colors.white),
              decoration: const InputDecoration(
                labelText: 'Subject Code (e.g., MIL, CPAR, PR2)',
                labelStyle: TextStyle(color: Colors.white70),
              ),
            ),
            const SizedBox(height: 14),
            const Text('Banner Color:',
                style: TextStyle(color: Colors.white70, fontSize: 12)),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              children: palette.map((hex) {
                final sel = pickedColor == hex;
                return GestureDetector(
                  onTap: () => setDialogState(() => pickedColor = hex),
                  child: Container(
                    width: 30,
                    height: 30,
                    decoration: BoxDecoration(
                      color: Color(hex),
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: sel ? Colors.white : Colors.transparent,
                        width: 2.5,
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              if (ctrl.text.trim().isNotEmpty) {
                await LobbyDataService.instance.addSubjectChest(
                  subjectName: ctrl.text.trim(),
                  colorValue: pickedColor,
                );
              }
              if (ctx.mounted) Navigator.of(ctx).pop();
            },
            child: const Text('Create Chest'),
          ),
        ],
      ),
    ),
  );
}

Future<void> showBulletinBoardModal({required BuildContext context}) {
  final service = LobbyDataService.instance;
  return showDialog<void>(
    context: context,
    builder: (ctx) => Dialog(
      backgroundColor: const Color(0xFF0F172A),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(22),
        side: const BorderSide(color: Color(0xFF38BDF8), width: 1.6),
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Text('📌', style: TextStyle(fontSize: 22)),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'MIS-SHS BULLETIN BOARD',
                    style: GoogleFonts.outfit(
                      color: Colors.white,
                      fontSize: 17,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                IconButton(
                  onPressed: () => Navigator.of(ctx).pop(),
                  icon: const Icon(Icons.close_rounded, color: Colors.white70),
                ),
              ],
            ),
            const Divider(color: Colors.white12),
            Text(
              '• Welcome to the MIS-SHS 2D Pixel School Lobby!\n'
              '• Visit the Reception Quest Counter (top-center) to complete posted activities and unlock custom Badges.\n'
              '• Explore the Reviewer Treasure Corner (bottom-right) for UCSP, PPG, PHILO, and KASAYSAYAN Reviewer Chests.\n'
              '• Solve 5 Small Mystery Chests (✨ ? QUIZ) around the room to earn the 🏆 Treasure Hunter badge!\n'
              '• Active Quests on Board: ${service.activities.length} | Total Quiz Pool: ${service.allReviewerQuestions.length} Qs',
              style: GoogleFonts.inter(
                color: Colors.white.withOpacity(0.88),
                fontSize: 13,
                height: 1.5,
              ),
            ),
          ],
        ),
      ),
    ),
  );
}
