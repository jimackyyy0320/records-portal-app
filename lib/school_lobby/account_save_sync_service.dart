import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;

import 'package:shared_preferences/shared_preferences.dart';

import '../models/portal_models.dart';
import '../services/api_service.dart';
import '../services/local_database.dart';
import '../services/session_service.dart';
import 'lobby_data_service.dart';
import 'school_lobby_avatar.dart';
import 'sovereign_story_data.dart';

typedef CloudAccountLoadCallback = Future<
        ({bool accountDeleted, int revision, String? dataJson, bool reachable})>
    Function({required String userId, required bool isFaculty});

typedef CloudAccountSaveCallback
    = Future<({bool success, bool accountDeleted, int revision})> Function({
  required String userId,
  required String userName,
  required bool isFaculty,
  required int level,
  required int xp,
  required int sealsCount,
  required int revision,
  required String dataJson,
});

/// Permanent Google Sheets Account-Bound Progress Save & Cascade Deletion Service.
///
/// Guarantees two strict invariants:
/// 1. **Zero Progress Loss on APK Update / Reinstall / Device Switch**:
///    Every student's School Lobby RPG state, Custom Avatar Look & Nickname,
///    Chronicles of the Sovereign Dungeon Save, and Custom Button/Audio Settings
///    are unified under one monotonic `revision` envelope stored in the Master
///    Google Sheet's `Account Progress` tab. On cold start or login, cloud state
///    is hydrated and union-merged **before** local background saves can overwrite it.
/// 2. **Automatic Cascade Wipe When Deleted From Google Sheets**:
///    Whenever the Master Google Sheet reports `accountDeleted: true` (student row
///    deleted from `Credentials`), all local `SharedPreferences`, SQLite caches,
///    and active sessions for that Student ID are wiped immediately.
class AccountSaveSyncService {
  AccountSaveSyncService._();

  static final AccountSaveSyncService instance = AccountSaveSyncService._();

  static const String kLobbyProgressPrefix = 'mis_school_lobby_progress_v1_';
  static const String kSovereignSavePrefix = 'sovereign_rpg_save_v1_';
  static const String kAvatarLookPrefix = 'mis_lobby_avatar_look_';
  static const String kAvatarNicknamePrefix = 'mis_lobby_nickname_';
  static const String kAvatarOnboardedPrefix = 'mis_lobby_onboarded_v2_';
  static const String kDungeonSettingsPrefix = 'mis_dungeon_settings_v2_';
  static const String kAccountRevisionPrefix = 'mis_account_save_rev_';

  final StreamController<String> _accountDeletedController =
      StreamController<String>.broadcast();
  final Set<String> _hydratedUserIds = <String>{};
  UserSession? _lastKnownSession;
  bool _syncInFlight = false;

  /// Optional test hooks for deterministic unit/widget verification without live HTTP.
  CloudAccountLoadCallback? debugLoadOverride;
  CloudAccountSaveCallback? debugSaveOverride;

  /// Fires with `userId` whenever Google Sheets confirms the account was deleted.
  Stream<String> get accountDeletedStream => _accountDeletedController.stream;

  bool isHydratedForUser(String userId) =>
      _hydratedUserIds.contains(userId.trim());

  void resetForTesting() {
    _hydratedUserIds.clear();
    _lastKnownSession = null;
    _syncInFlight = false;
    debugLoadOverride = null;
    debugSaveOverride = null;
  }

  /// Hydrates & union-merges the student's permanent save from Google Sheets (`Account Progress`),
  /// or wipes all local data immediately if the account was deleted from the Master Sheet.
  Future<({bool ok, bool accountDeleted})> hydrateFromGoogleSheets(
    UserSession session,
  ) async {
    final cleanId = session.id.trim();
    if (cleanId.isEmpty || cleanId == 'guest') {
      return (ok: false, accountDeleted: false);
    }
    _lastKnownSession = session;

    final loader = debugLoadOverride ?? ApiService.instance.loadAccountProgress;
    final cloudRes = await loader(
      userId: cleanId,
      isFaculty: session.isFaculty,
    );

    // 1. Account was deleted from Google Sheets -> cascade-wipe all local progress & session!
    if (cloudRes.accountDeleted) {
      await wipeAllLocalAccountData(cleanId);
      await SessionService.instance.clearSession();
      _accountDeletedController.add(cleanId);
      return (ok: false, accountDeleted: true);
    }

    if (!cloudRes.reachable) {
      // Offline launch: keep local cached progress safely without marking cloud-overwritable
      return (ok: false, accountDeleted: false);
    }

    final prefs = await SharedPreferences.getInstance();
    final localRev = prefs.getInt('$kAccountRevisionPrefix$cleanId') ?? 0;

    // 2. Cloud row exists -> non-destructively union-merge ALL 4 domains into local storage!
    if (cloudRes.dataJson != null && cloudRes.dataJson!.trim().isNotEmpty) {
      try {
        final rawDecoded = jsonDecode(cloudRes.dataJson!);
        if (rawDecoded is Map) {
          final cloudMap = Map<String, dynamic>.from(rawDecoded);
          await applyUnifiedCloudMerge(
            userId: cleanId,
            isFaculty: session.isFaculty,
            cloudMap: cloudMap,
            cloudRevision: cloudRes.revision,
          );
        }
      } catch (_) {}
      _hydratedUserIds.add(cleanId);
      return (ok: true, accountDeleted: false);
    }

    // 3. Cloud row is empty (new student or pre-v2 local data) -> mark hydrated & seed Google Sheet if local progress exists!
    _hydratedUserIds.add(cleanId);
    final hasExistingLocal =
        prefs.containsKey('$kLobbyProgressPrefix$cleanId') ||
            prefs.containsKey('$kSovereignSavePrefix$cleanId') ||
            prefs.containsKey('$kAvatarLookPrefix$cleanId') ||
            localRev > 0;
    if (hasExistingLocal) {
      await pushUnifiedAccountSave(userId: cleanId, session: session);
    }
    return (ok: true, accountDeleted: false);
  }

  /// Applies a non-destructive union merge of cloud + local state across:
  /// - School Lobby RPG Progress (`StudentLobbyProgress`)
  /// - Chronicles of the Sovereign Campaign & Dungeon Save (`SovereignCampaignSave`)
  /// - Custom Avatar Look & Nickname (`LobbyAvatarLook`)
  /// - Custom Button Layout & Audio/Graphics Settings (`mis_dungeon_settings_v2_`)
  Future<void> applyUnifiedCloudMerge({
    required String userId,
    required bool isFaculty,
    required Map<String, dynamic> cloudMap,
    int cloudRevision = 1,
  }) async {
    final cleanId = userId.trim();
    final prefs = await SharedPreferences.getInstance();
    final localRev = prefs.getInt('$kAccountRevisionPrefix$cleanId') ?? 0;
    final cloudWinsTie = cloudRevision >= localRev;

    // A. Load local Lobby & Campaign saves
    StudentLobbyProgress localLobby = const StudentLobbyProgress();
    final rawLocalLobby = prefs.getString('$kLobbyProgressPrefix$cleanId');
    if (rawLocalLobby != null && rawLocalLobby.isNotEmpty) {
      try {
        localLobby = StudentLobbyProgress.fromJson(
          Map<String, dynamic>.from(jsonDecode(rawLocalLobby) as Map),
        );
      } catch (_) {}
    }
    final localCampaign = await SovereignCampaignSave.load(cleanId);

    // Support both v2 envelope (`lobbyProgress` sub-map) and v1 root-level `StudentLobbyProgress`
    final lobbySourceMap = cloudMap['lobbyProgress'] is Map
        ? Map<String, dynamic>.from(cloudMap['lobbyProgress'] as Map)
        : cloudMap;
    final mergePayload = <String, dynamic>{
      ...lobbySourceMap,
      if (cloudMap['sovereignCampaign'] is Map)
        'sovereignCampaign': cloudMap['sovereignCampaign'],
    };

    final merged = LobbyDataService.mergeCloudPayload(
      localProgress: localLobby,
      localCampaign: localCampaign,
      cloudPayload: mergePayload,
    );

    await prefs.setString(
      '$kLobbyProgressPrefix$cleanId',
      jsonEncode(merged.progress.toJson()),
    );
    if (merged.campaign != null) {
      await merged.campaign!.persist(cleanId);
    }

    // B. Custom Avatar Look, Nickname & Onboarding Flag (survives APK reinstalls!)
    final cloudLookStr = cloudMap['avatarLook']?.toString().trim() ?? '';
    final localLookStr = prefs.getString('$kAvatarLookPrefix$cleanId') ?? '';
    if (cloudLookStr.isNotEmpty && (localLookStr.isEmpty || cloudWinsTie)) {
      final parsedLook =
          LobbyAvatarLook.fromLookString(cloudLookStr, isFaculty: isFaculty);
      await prefs.setString(
        '$kAvatarLookPrefix$cleanId',
        parsedLook.toLookString(),
      );
    }
    final cloudNick = cloudMap['avatarNickname']?.toString().trim() ?? '';
    final localNick = prefs.getString('$kAvatarNicknamePrefix$cleanId') ?? '';
    if (cloudNick.isNotEmpty && (localNick.isEmpty || cloudWinsTie)) {
      await prefs.setString('$kAvatarNicknamePrefix$cleanId', cloudNick);
    }
    if (cloudMap['avatarOnboarded'] == true) {
      await prefs.setBool('$kAvatarOnboardedPrefix$cleanId', true);
    }

    // C. Custom Control Layout & Audio/Visual Settings (`mis_dungeon_settings_v2_`)
    if (cloudMap['dungeonSettings'] is Map) {
      final localSettingsStr =
          prefs.getString('$kDungeonSettingsPrefix$cleanId');
      if (localSettingsStr == null || localSettingsStr.isEmpty || cloudWinsTie) {
        await prefs.setString(
          '$kDungeonSettingsPrefix$cleanId',
          jsonEncode(cloudMap['dungeonSettings']),
        );
      }
    }

    // D. Advance local monotonic revision & refresh in-memory LobbyDataService if active!
    final nextRev = math.max(localRev, cloudRevision);
    await prefs.setInt('$kAccountRevisionPrefix$cleanId', nextRev);
    await LobbyDataService.instance.reloadFromLocalPrefsIfActive(cleanId);
  }

  /// Builds & pushes the complete unified account save envelope to Google Sheets (`Account Progress`).
  Future<bool> pushUnifiedAccountSave({
    required String userId,
    UserSession? session,
    bool allowBeforeHydration = false,
  }) async {
    final cleanId = userId.trim();
    if (cleanId.isEmpty || cleanId == 'guest') return false;
    if (_syncInFlight) return false;

    final resolvedSession = session ??
        (_lastKnownSession?.id.trim() == cleanId ? _lastKnownSession : null) ??
        await SessionService.instance.restoreSession();
    final isFaculty = resolvedSession?.id.trim() == cleanId
        ? resolvedSession!.isFaculty
        : false;
    final userName = resolvedSession?.id.trim() == cleanId
        ? resolvedSession!.name
        : cleanId;

    // Never overwrite a student's cloud save with fresh post-install defaults before hydrating first!
    if (!_hydratedUserIds.contains(cleanId) && !allowBeforeHydration) {
      if (resolvedSession != null && resolvedSession.id.trim() == cleanId) {
        final hyd = await hydrateFromGoogleSheets(resolvedSession);
        if (hyd.accountDeleted) return false;
      }
    }

    _syncInFlight = true;
    try {
      final prefs = await SharedPreferences.getInstance();
      final nextRev = (prefs.getInt('$kAccountRevisionPrefix$cleanId') ?? 0) + 1;

      StudentLobbyProgress lobbyProg = const StudentLobbyProgress();
      final rawLobby = prefs.getString('$kLobbyProgressPrefix$cleanId');
      if (rawLobby != null && rawLobby.isNotEmpty) {
        try {
          lobbyProg = StudentLobbyProgress.fromJson(
            Map<String, dynamic>.from(jsonDecode(rawLobby) as Map),
          );
        } catch (_) {}
      }

      final campaignSave = await SovereignCampaignSave.load(cleanId);
      final avatarLookStr = prefs.getString('$kAvatarLookPrefix$cleanId') ?? '';
      final avatarNick =
          prefs.getString('$kAvatarNicknamePrefix$cleanId') ?? '';
      final avatarOnboarded =
          prefs.getBool('$kAvatarOnboardedPrefix$cleanId') ?? false;

      Map<String, dynamic>? settingsMap;
      final rawSettings = prefs.getString('$kDungeonSettingsPrefix$cleanId');
      if (rawSettings != null && rawSettings.isNotEmpty) {
        try {
          final dec = jsonDecode(rawSettings);
          if (dec is Map) settingsMap = Map<String, dynamic>.from(dec);
        } catch (_) {}
      }

      final unifiedEnvelope = <String, dynamic>{
        'schemaVersion': 2,
        'userId': cleanId,
        'userName': userName,
        'isFaculty': isFaculty,
        'revision': nextRev,
        'updatedAtMs': DateTime.now().millisecondsSinceEpoch,
        // Keep root-level Lobby fields too so older v1 clients can still parse if needed!
        ...lobbyProg.toJson(),
        'lobbyProgress': lobbyProg.toJson(),
        'sovereignCampaign': campaignSave.toJson(),
        if (avatarLookStr.isNotEmpty) 'avatarLook': avatarLookStr,
        if (avatarNick.isNotEmpty) 'avatarNickname': avatarNick,
        'avatarOnboarded': avatarOnboarded,
        if (settingsMap != null) 'dungeonSettings': settingsMap,
      };

      final sealsCount = campaignSave.dungeonProgress.defeatedBossIds
          .where((id) => id.startsWith('boss_'))
          .length;

      final saver = debugSaveOverride ?? ApiService.instance.saveAccountProgress;
      final res = await saver(
        userId: cleanId,
        userName: userName,
        isFaculty: isFaculty,
        level: lobbyProg.level,
        xp: lobbyProg.xp,
        sealsCount: sealsCount,
        revision: nextRev,
        dataJson: jsonEncode(unifiedEnvelope),
      );

      if (res.accountDeleted) {
        await wipeAllLocalAccountData(cleanId);
        await SessionService.instance.clearSession();
        _accountDeletedController.add(cleanId);
        return false;
      }

      if (res.success) {
        await prefs.setInt(
          '$kAccountRevisionPrefix$cleanId',
          math.max(nextRev, res.revision),
        );
        return true;
      }
      return false;
    } finally {
      _syncInFlight = false;
    }
  }

  /// Flushes the currently signed-in user's save immediately (called on app pause/backgrounding).
  Future<void> flushActiveAccountSave() async {
    final session =
        _lastKnownSession ?? await SessionService.instance.restoreSession();
    if (session == null || session.id.trim().isEmpty) return;
    await pushUnifiedAccountSave(userId: session.id, session: session);
  }

  /// Permanently erases ALL local progress, avatar looks, dungeon saves, custom keybinds,
  /// and cached portal records for [userId] when deleted from Google Sheets!
  Future<void> wipeAllLocalAccountData(String userId) async {
    final cleanId = userId.trim();
    if (cleanId.isEmpty) return;
    _hydratedUserIds.remove(cleanId);
    if (_lastKnownSession?.id.trim() == cleanId) {
      _lastKnownSession = null;
    }

    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('$kLobbyProgressPrefix$cleanId');
    await prefs.remove('$kSovereignSavePrefix$cleanId');
    await prefs.remove('$kAvatarLookPrefix$cleanId');
    await prefs.remove('$kAvatarNicknamePrefix$cleanId');
    await prefs.remove('$kAvatarOnboardedPrefix$cleanId');
    await prefs.remove('$kDungeonSettingsPrefix$cleanId');
    await prefs.remove('$kAccountRevisionPrefix$cleanId');

    await LobbyDataService.instance.clearInMemoryUserProgressIfMatching(cleanId);
    try {
      await LocalDatabase.instance.clearCache();
    } catch (_) {}
  }
}
