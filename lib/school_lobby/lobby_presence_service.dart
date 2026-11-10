import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

import '../models/portal_models.dart';
import '../services/api_service.dart';
import 'lobby_data_service.dart';
import 'school_lobby_avatar.dart';
import 'school_lobby_config.dart';

/// Represents a live remote Student or Teacher currently inside the 2D School Campus.
class RemoteLobbyPlayer {
  final String userId;
  String nickname;
  bool isFaculty;
  LobbyAvatarLook look;
  String? equippedBadgeIcon;
  LobbyRoomId room;

  /// Smoothly interpolated 60 FPS world position rendered on canvas.
  Offset currentPos;

  /// Latest authoritative target position received from the network.
  Offset targetPos;

  AvatarFacing facing;
  bool isWalking;
  PlayerRestState restState;

  /// Active cloud Thought Bubble text (`💭`) and its expiration timestamp.
  String? thoughtText;
  int thoughtUntilMs;

  /// Active wave emote (`👋`) expiration timestamp.
  int waveUntilMs;

  /// Last time (`millisecondsSinceEpoch`) we received a packet from this user.
  int lastSeenMs;

  /// Resolved 56-frame composite sprite sheet for this remote player's custom avatar.
  ui.Image? spriteSheet;
  String _resolvedLookSignature = '';
  bool _resolvingSprite = false;

  RemoteLobbyPlayer({
    required this.userId,
    required this.nickname,
    required this.isFaculty,
    required this.look,
    this.equippedBadgeIcon,
    required this.room,
    required this.currentPos,
    required this.targetPos,
    this.facing = AvatarFacing.down,
    this.isWalking = false,
    this.restState = PlayerRestState.none,
    this.thoughtText,
    this.thoughtUntilMs = 0,
    this.waveUntilMs = 0,
    required this.lastSeenMs,
    this.spriteSheet,
  });

  bool get hasActiveThought =>
      thoughtText != null &&
      thoughtText!.trim().isNotEmpty &&
      DateTime.now().millisecondsSinceEpoch < thoughtUntilMs;

  bool get isWaving => DateTime.now().millisecondsSinceEpoch < waveUntilMs;

  String get statusLabel {
    switch (restState) {
      case PlayerRestState.sitting:
        return '🪑 Sitting';
      case PlayerRestState.napping:
        return '😪 Napping';
      case PlayerRestState.sleeping:
        return '🛌 Sleeping';
      case PlayerRestState.none:
        return isWalking ? '🚶 Walking' : '🟢 Standing';
    }
  }

  /// Lazily resolves and caches the remote player's custom layered avatar sprite sheet.
  Future<void> ensureSpriteSheetLoaded(VoidCallback onResolved) async {
    final sig = look.toLookString();
    if (spriteSheet != null && _resolvedLookSignature == sig) return;
    if (_resolvingSprite) return;
    _resolvingSprite = true;
    try {
      final img = await AvatarSpriteCache.instance.resolveLookSpriteSheet(look);
      spriteSheet = img;
      _resolvedLookSignature = sig;
      onResolved();
    } catch (_) {
      // Ignore sprite load errors in headless tests
    } finally {
      _resolvingSprite = false;
    }
  }
}

/// Real-Time Multi-User Presence & Thought Bubble Sync Engine for the MIS-SHS 2D School Lobby.
///
/// Combines three layers so real students and teachers see each other live across phones
/// without needing any custom server setup or Google Apps Script redeployment:
/// 1. **Instant WebSocket Pub/Sub Stream (`wss://ntfy.sh/mis_shs_portal_lobby_live_v1/ws`)**
///    for sub-second (`~150-300ms`) movement, room transitions, rest states, and Thought Bubbles.
/// 2. **Fast HTTP JSON Polling Fallback (`https://ntfy.sh/mis_shs_portal_lobby_live_v1/json?poll=1`)**
///    every 3 seconds in case a school router throttles WebSockets.
/// 3. **Google Apps Script / Drive Presence Snapshot (`'999999002'`)** as a secondary discovery layer.
class LobbyPresenceService extends ChangeNotifier {
  LobbyPresenceService._();
  static final LobbyPresenceService instance = LobbyPresenceService._();

  static const String _kRelayTopic = 'mis_shs_portal_lobby_live_v1';
  static const String _kRelayHttpUrl = 'https://ntfy.sh/$_kRelayTopic';
  static const String _kRelayWsUrl =
      'wss://ntfy.sh/$_kRelayTopic/ws?since=25s';
  static const String _kCloudPresenceManifestId = '999999002';

  /// Players who haven't sent a heartbeat or movement packet in 42 seconds are pruned.
  static const int kPlayerTimeoutMs = 42000;

  /// Active remote players indexed by their unique `userId` + `_deviceInstanceId`.
  final Map<String, RemoteLobbyPlayer> _remotePlayers =
      <String, RemoteLobbyPlayer>{};

  /// Unique per-session suffix so even two phones logged into the same test ID can see each other!
  String _selfPeerKey = '';
  String _selfUserId = '';
  String _selfNickname = '';
  bool _selfIsFaculty = false;
  LobbyAvatarLook _selfLook = const LobbyAvatarLook();
  String? _selfBadgeIcon;
  LobbyRoomId _selfRoom = LobbyRoomId.mainLobby;
  Offset _selfPos = kPlayerSpawnPoint;
  AvatarFacing _selfFacing = AvatarFacing.down;
  bool _selfIsWalking = false;
  PlayerRestState _selfRestState = PlayerRestState.none;
  String? _selfThoughtText;
  int _selfThoughtUntilMs = 0;

  bool _isConnected = false;
  bool _isDisposedOrStopped = true;
  WebSocket? _ws;
  StreamSubscription<dynamic>? _wsSub;
  Timer? _heartbeatTimer;
  Timer? _httpPollTimer;
  Timer? _cloudSnapshotTimer;

  int _lastBroadcastMs = 0;
  Offset _lastBroadcastPos = Offset.zero;
  LobbyRoomId? _lastBroadcastRoom;
  PlayerRestState? _lastBroadcastRest;
  bool _lastBroadcastWalking = false;
  String? _lastBroadcastThought;
  int _lastPollTimestampSec = 0;

  /// Set to `false` during unit tests to avoid real network sockets.
  bool enableNetworkTransport = true;

  bool get isConnected => _isConnected;

  /// All currently active remote players across the entire 5-room campus.
  List<RemoteLobbyPlayer> get allRemotePlayers {
    final list = _remotePlayers.values.toList()
      ..sort((a, b) => a.nickname.compareTo(b.nickname));
    return list;
  }

  /// Total online count (including the local player).
  int get totalOnlineCount => _remotePlayers.length + 1;

  /// Remote players currently inside [room].
  List<RemoteLobbyPlayer> playersForRoom(LobbyRoomId room) {
    return _remotePlayers.values.where((p) => p.room == room).toList();
  }

  /// Starts live multiplayer presence for the current user session.
  Future<void> startPresence({
    required UserSession session,
    required String nickname,
    required LobbyAvatarLook look,
    required String? equippedBadgeIcon,
    required LobbyRoomId initialRoom,
    required Offset initialPos,
  }) async {
    stopPresence();
    _isDisposedOrStopped = false;

    final randomSuffix =
        (DateTime.now().microsecondsSinceEpoch % 90000 + 10000).toString();
    _selfUserId = session.id.trim();
    _selfPeerKey = '${_selfUserId}_$randomSuffix';
    _selfNickname = nickname.trim().isEmpty ? session.name : nickname.trim();
    _selfIsFaculty = session.isFaculty;
    _selfLook = look;
    _selfBadgeIcon = equippedBadgeIcon;
    _selfRoom = initialRoom;
    _selfPos = initialPos;
    _selfFacing = AvatarFacing.down;
    _selfIsWalking = false;
    _selfRestState = PlayerRestState.none;
    _lastPollTimestampSec =
        (DateTime.now().millisecondsSinceEpoch ~/ 1000) - 25;

    if (!enableNetworkTransport) return;

    // 1. Connect live WebSocket stream
    unawaited(_connectWebSocket());

    // 2. Broadcast immediate join + request all online peers to reply with their state
    unawaited(_broadcastPacket(type: 'hello_join', force: true));

    // 3. Start 6-second heartbeat & stale player pruning timer
    _heartbeatTimer = Timer.periodic(const Duration(seconds: 6), (_) {
      if (_isDisposedOrStopped) return;
      _pruneStalePlayers();
      unawaited(_broadcastPacket(type: 'heartbeat', force: true));
    });

    // 4. Start 3-second fast HTTP poll fallback (ensures real-time updates even if WS is blocked)
    _httpPollTimer = Timer.periodic(const Duration(seconds: 3), (_) {
      if (_isDisposedOrStopped) return;
      unawaited(_pollRelayHttp());
    });

    // 5. Pull initial cloud snapshot & schedule periodic cloud backup sync
    unawaited(_pullCloudPresenceSnapshot());
    _cloudSnapshotTimer = Timer.periodic(const Duration(seconds: 15), (_) {
      if (_isDisposedOrStopped) return;
      unawaited(_syncCloudPresenceSnapshot());
    });
  }

  /// Cleanly broadcasts a `'leave'` event and closes active timers/sockets when exiting the lobby.
  void stopPresence() {
    if (!_isDisposedOrStopped && enableNetworkTransport) {
      unawaited(_broadcastPacket(type: 'leave', force: true));
    }
    _isDisposedOrStopped = true;
    _isConnected = false;
    _heartbeatTimer?.cancel();
    _heartbeatTimer = null;
    _httpPollTimer?.cancel();
    _httpPollTimer = null;
    _cloudSnapshotTimer?.cancel();
    _cloudSnapshotTimer = null;
    _wsSub?.cancel();
    _wsSub = null;
    try {
      _ws?.close();
    } catch (_) {}
    _ws = null;
    _remotePlayers.clear();
  }

  /// Updates the local player's state and broadcasts to all online players if throttled conditions are met.
  void updateLocalPlayerState({
    String? nickname,
    LobbyAvatarLook? look,
    String? equippedBadgeIcon,
    LobbyRoomId? room,
    Offset? position,
    AvatarFacing? facing,
    bool? isWalking,
    PlayerRestState? restState,
    String? thoughtText,
    int? thoughtUntilMs,
    bool triggerWave = false,
    bool forceImmediateBroadcast = false,
  }) {
    if (nickname != null) _selfNickname = nickname;
    if (look != null) _selfLook = look;
    if (equippedBadgeIcon != null || equippedBadgeIcon == null) {
      _selfBadgeIcon = equippedBadgeIcon ?? _selfBadgeIcon;
    }
    if (room != null) _selfRoom = room;
    if (position != null) _selfPos = position;
    if (facing != null) _selfFacing = facing;
    if (isWalking != null) _selfIsWalking = isWalking;
    if (restState != null) _selfRestState = restState;
    if (thoughtText != null || thoughtUntilMs != null) {
      _selfThoughtText = thoughtText;
      _selfThoughtUntilMs = thoughtUntilMs ?? 0;
    }

    if (_isDisposedOrStopped || !enableNetworkTransport) return;

    final nowMs = DateTime.now().millisecondsSinceEpoch;
    final roomChanged = _lastBroadcastRoom != _selfRoom;
    final restChanged = _lastBroadcastRest != _selfRestState;
    final thoughtChanged = _lastBroadcastThought != _selfThoughtText;
    final stoppedWalking = _lastBroadcastWalking && !_selfIsWalking;
    final distMoved = (_selfPos - _lastBroadcastPos).distance;

    // Broadcast immediately on room change, rest state change, new Thought Bubble, wave, or stop;
    // otherwise throttle continuous walking updates to ~4.5 times/sec (every 220ms when moved >= 12px).
    final shouldSend = forceImmediateBroadcast ||
        triggerWave ||
        roomChanged ||
        restChanged ||
        thoughtChanged ||
        stoppedWalking ||
        (distMoved >= 12.0 && (nowMs - _lastBroadcastMs) >= 220);

    if (shouldSend) {
      _lastBroadcastMs = nowMs;
      _lastBroadcastPos = _selfPos;
      _lastBroadcastRoom = _selfRoom;
      _lastBroadcastRest = _selfRestState;
      _lastBroadcastWalking = _selfIsWalking;
      _lastBroadcastThought = _selfThoughtText;

      unawaited(
        _broadcastPacket(
          type: triggerWave
              ? 'wave'
              : (thoughtChanged &&
                      _selfThoughtText != null &&
                      _selfThoughtText!.isNotEmpty
                  ? 'thought'
                  : 'state'),
          force: true,
        ),
      );
    }
  }

  /// Advances 60 FPS position interpolation for all remote players in the current room.
  /// Returns `true` if any remote player moved or animated this frame so the canvas can repaint.
  bool tickInterpolation(double dt, LobbyRoomId activeRoom) {
    var anyVisualChange = false;
    final nowMs = DateTime.now().millisecondsSinceEpoch;

    for (final p in _remotePlayers.values) {
      // Expire remote thought bubble if past timer
      if (p.thoughtText != null &&
          p.thoughtUntilMs > 0 &&
          nowMs >= p.thoughtUntilMs) {
        p.thoughtText = null;
        p.thoughtUntilMs = 0;
        if (p.room == activeRoom) anyVisualChange = true;
      }

      if (p.room != activeRoom) continue;

      final toTarget = p.targetPos - p.currentPos;
      final dist = toTarget.distance;
      if (dist > 1.5) {
        // Smoothly glide toward targetPos; speed up slightly if far behind
        final catchUpMultiplier = dist > 96.0 ? 1.85 : 1.12;
        final step = (kPlayerMoveSpeed * catchUpMultiplier) * dt;
        if (dist <= step) {
          p.currentPos = p.targetPos;
        } else {
          final dir = toTarget / dist;
          p.currentPos = p.currentPos + dir * step;
          if (dir.dx.abs() >= dir.dy.abs()) {
            p.facing = dir.dx >= 0 ? AvatarFacing.right : AvatarFacing.left;
          } else {
            p.facing = dir.dy >= 0 ? AvatarFacing.down : AvatarFacing.up;
          }
        }
        p.isWalking = dist > 3.0 && !p.restState.isResting;
        anyVisualChange = true;
      } else if (p.isWalking) {
        p.isWalking = false;
        anyVisualChange = true;
      }
    }
    return anyVisualChange;
  }

  /// Processes a decoded presence JSON payload (used by WS, HTTP poll, Cloud Snapshot, and unit tests).
  void handleIncomingPresencePayload(
    Map<String, dynamic> data, {
    bool isFromLiveStream = true,
  }) {
    final peerKey = (data['peerKey'] ?? '').toString().trim();
    if (peerKey.isEmpty || peerKey == _selfPeerKey) return;

    final type = (data['type'] ?? 'state').toString();
    if (type == 'leave') {
      if (_remotePlayers.remove(peerKey) != null) {
        notifyListeners();
      }
      return;
    }

    final nowMs = DateTime.now().millisecondsSinceEpoch;
    final sentAtMs = (data['ts'] is num) ? (data['ts'] as num).toInt() : nowMs;
    if ((nowMs - sentAtMs).abs() > 120000 && !isFromLiveStream) {
      return; // Ignore stale cloud snapshots older than 2 minutes
    }

    final userId = (data['userId'] ?? peerKey).toString();
    final nickname = (data['nickname'] ?? 'Student').toString();
    final isFaculty = data['isFaculty'] == true;
    final lookStr = (data['look'] ?? 'preset:1').toString();
    final look = LobbyAvatarLook.fromLookString(lookStr);
    final badgeIcon = data['badgeIcon']?.toString();
    final roomName = (data['room'] ?? 'mainLobby').toString();
    final room = LobbyRoomId.values.firstWhere(
      (r) => r.name == roomName,
      orElse: () => LobbyRoomId.mainLobby,
    );
    final x = (data['x'] is num)
        ? (data['x'] as num).toDouble()
        : kPlayerSpawnPoint.dx;
    final y = (data['y'] is num)
        ? (data['y'] as num).toDouble()
        : kPlayerSpawnPoint.dy;
    final facingName = (data['facing'] ?? 'down').toString();
    final facing = AvatarFacing.values.firstWhere(
      (f) => f.name == facingName,
      orElse: () => AvatarFacing.down,
    );
    final isWalking = data['isWalking'] == true;
    final restName = (data['rest'] ?? 'none').toString();
    final restState = PlayerRestState.values.firstWhere(
      (r) => r.name == restName,
      orElse: () => PlayerRestState.none,
    );
    final thoughtText = data['thought']?.toString();

    final existing = _remotePlayers[peerKey];
    if (existing == null) {
      final created = RemoteLobbyPlayer(
        userId: userId,
        nickname: nickname,
        isFaculty: isFaculty,
        look: look,
        equippedBadgeIcon:
            (badgeIcon != null && badgeIcon.isNotEmpty) ? badgeIcon : null,
        room: room,
        currentPos: Offset(x, y),
        targetPos: Offset(x, y),
        facing: facing,
        isWalking: isWalking,
        restState: restState,
        thoughtText: (thoughtText != null && thoughtText.trim().isNotEmpty)
            ? thoughtText.trim()
            : null,
        thoughtUntilMs: (thoughtText != null && thoughtText.trim().isNotEmpty)
            ? nowMs + 14000
            : 0,
        waveUntilMs: type == 'wave' ? nowMs + 2200 : 0,
        lastSeenMs: nowMs,
      );
      _remotePlayers[peerKey] = created;
      if (thoughtText != null && thoughtText.trim().isNotEmpty) {
        LobbyDataService.instance.recordThoughtBubble(
          senderName: nickname,
          senderRole: isFaculty ? 'Teacher' : 'Student',
          roomName: room.shortLabel,
          text: thoughtText.trim().replaceFirst('💭 ', ''),
          isFromPeer: true,
        );
      }
      if (enableNetworkTransport) {
        unawaited(created.ensureSpriteSheetLoaded(notifyListeners));
      }
    } else {
      final switchedRoom = existing.room != room;
      existing.nickname = nickname;
      existing.isFaculty = isFaculty;
      existing.look = look;
      existing.equippedBadgeIcon =
          (badgeIcon != null && badgeIcon.isNotEmpty) ? badgeIcon : null;
      existing.room = room;
      existing.targetPos = Offset(x, y);
      // If the player switched rooms or teleported > 280px, snap immediately
      if (switchedRoom ||
          (existing.currentPos - existing.targetPos).distance > 280.0) {
        existing.currentPos = Offset(x, y);
      }
      existing.facing = facing;
      existing.isWalking = isWalking;
      existing.restState = restState;
      existing.lastSeenMs = nowMs;

      if (type == 'wave') {
        existing.waveUntilMs = nowMs + 2200;
      }
      if (thoughtText != null && thoughtText.trim().isNotEmpty) {
        final cleanThought = thoughtText.trim();
        if (existing.thoughtText != cleanThought) {
          existing.thoughtText = cleanThought;
          existing.thoughtUntilMs = nowMs + 14000;
          // Also record into the shared Thought Bubble Chat history!
          LobbyDataService.instance.recordThoughtBubble(
            senderName: nickname,
            senderRole: isFaculty ? 'Teacher' : 'Student',
            roomName: room.shortLabel,
            text: cleanThought.replaceFirst('💭 ', ''),
            isFromPeer: true,
          );
        }
      } else if (thoughtText != null && thoughtText.isEmpty) {
        existing.thoughtText = null;
        existing.thoughtUntilMs = 0;
      }

      if (enableNetworkTransport) {
        unawaited(existing.ensureSpriteSheetLoaded(notifyListeners));
      }
    }

    // If a new user just joined (`hello_join`), immediately reply with our current state
    // so they see us on their screen right away!
    if (type == 'hello_join' &&
        isFromLiveStream &&
        !_isDisposedOrStopped &&
        enableNetworkTransport) {
      unawaited(_broadcastPacket(type: 'hello_reply', force: true));
    }

    notifyListeners();
  }

  Map<String, dynamic> _buildSelfPayload({required String type}) {
    final nowMs = DateTime.now().millisecondsSinceEpoch;
    final activeThought = (_selfThoughtText != null &&
            _selfThoughtText!.isNotEmpty &&
            nowMs < _selfThoughtUntilMs)
        ? _selfThoughtText
        : '';
    return <String, dynamic>{
      'app': 'mis_shs_lobby_v1',
      'type': type,
      'peerKey': _selfPeerKey,
      'userId': _selfUserId,
      'nickname': _selfNickname,
      'isFaculty': _selfIsFaculty,
      'look': _selfLook.toLookString(),
      'badgeIcon': _selfBadgeIcon ?? '',
      'room': _selfRoom.name,
      'x': _selfPos.dx.round(),
      'y': _selfPos.dy.round(),
      'facing': _selfFacing.name,
      'isWalking': _selfIsWalking,
      'rest': _selfRestState.name,
      'thought': activeThought,
      'ts': nowMs,
    };
  }

  Future<void> _broadcastPacket({
    required String type,
    bool force = false,
  }) async {
    if (_selfPeerKey.isEmpty || !enableNetworkTransport) return;
    final payload = _buildSelfPayload(type: type);
    final encoded = jsonEncode(payload);
    try {
      await http
          .post(
            Uri.parse(_kRelayHttpUrl),
            headers: const {'Content-Type': 'text/plain; charset=utf-8'},
            body: encoded,
          )
          .timeout(const Duration(seconds: 4));
      if (!_isConnected && !_isDisposedOrStopped) {
        _isConnected = true;
        notifyListeners();
      }
    } catch (_) {
      // Ignore transient network hiccups
    }
  }

  Future<void> _connectWebSocket() async {
    if (_isDisposedOrStopped || !enableNetworkTransport) return;
    try {
      final socket = await WebSocket.connect(_kRelayWsUrl)
          .timeout(const Duration(seconds: 6));
      if (_isDisposedOrStopped) {
        await socket.close();
        return;
      }
      _ws = socket;
      _isConnected = true;
      notifyListeners();

      _wsSub = socket.listen(
        (rawEvent) {
          _handleRawRelayEnvelope(rawEvent.toString());
        },
        onError: (_) => _scheduleWebSocketReconnect(),
        onDone: _scheduleWebSocketReconnect,
        cancelOnError: true,
      );
    } catch (_) {
      _scheduleWebSocketReconnect();
    }
  }

  void _scheduleWebSocketReconnect() {
    if (_isDisposedOrStopped || !enableNetworkTransport) return;
    _wsSub?.cancel();
    _wsSub = null;
    try {
      _ws?.close();
    } catch (_) {}
    _ws = null;
    Future.delayed(const Duration(seconds: 4), () {
      if (!_isDisposedOrStopped) {
        unawaited(_connectWebSocket());
      }
    });
  }

  Future<void> _pollRelayHttp() async {
    if (_isDisposedOrStopped || !enableNetworkTransport) return;
    try {
      final sinceSec = _lastPollTimestampSec > 0
          ? _lastPollTimestampSec
          : (DateTime.now().millisecondsSinceEpoch ~/ 1000) - 15;
      final uri = Uri.parse('$_kRelayHttpUrl/json?poll=1&since=$sinceSec');
      final resp = await http.get(uri).timeout(const Duration(seconds: 4));
      if (resp.statusCode == 200 && resp.body.trim().isNotEmpty) {
        final lines = const LineSplitter().convert(resp.body);
        for (final line in lines) {
          _handleRawRelayEnvelope(line);
        }
        _isConnected = true;
      }
    } catch (_) {
      // Ignore transient poll errors
    }
  }

  void _handleRawRelayEnvelope(String rawLine) {
    final trimmed = rawLine.trim();
    if (trimmed.isEmpty) return;
    try {
      final envelope = jsonDecode(trimmed);
      if (envelope is! Map<String, dynamic>) return;
      if (envelope['time'] is num) {
        final t = (envelope['time'] as num).toInt();
        if (t > _lastPollTimestampSec) {
          _lastPollTimestampSec = t;
        }
      }
      final msgStr = envelope['message']?.toString();
      if (msgStr == null || !msgStr.startsWith('{')) return;
      final inner = jsonDecode(msgStr);
      if (inner is Map<String, dynamic> &&
          inner['app'] == 'mis_shs_lobby_v1') {
        handleIncomingPresencePayload(inner, isFromLiveStream: true);
      }
    } catch (_) {
      // Ignore non-JSON keepalive lines
    }
  }

  Future<void> _pullCloudPresenceSnapshot() async {
    if (_isDisposedOrStopped || !enableNetworkTransport) return;
    try {
      final dataUrl =
          await ApiService.instance.getStudentAvatar(_kCloudPresenceManifestId);
      if (dataUrl == null || !dataUrl.contains(',')) return;
      final b64 = dataUrl.split(',').last.trim();
      final jsonStr = utf8.decode(base64Decode(b64));
      final decoded = jsonDecode(jsonStr);
      if (decoded is Map<String, dynamic> && decoded['players'] is List) {
        for (final item in (decoded['players'] as List)) {
          if (item is Map) {
            handleIncomingPresencePayload(
              Map<String, dynamic>.from(item),
              isFromLiveStream: false,
            );
          }
        }
      }
    } catch (_) {}
  }

  Future<void> _syncCloudPresenceSnapshot() async {
    if (_isDisposedOrStopped || !enableNetworkTransport) return;
    try {
      await _pullCloudPresenceSnapshot();
      final nowMs = DateTime.now().millisecondsSinceEpoch;
      final activeList = <Map<String, dynamic>>[
        _buildSelfPayload(type: 'snapshot'),
        for (final e in _remotePlayers.entries)
          if (nowMs - e.value.lastSeenMs <= kPlayerTimeoutMs)
            <String, dynamic>{
              'app': 'mis_shs_lobby_v1',
              'type': 'snapshot',
              'peerKey': e.key,
              'userId': e.value.userId,
              'nickname': e.value.nickname,
              'isFaculty': e.value.isFaculty,
              'look': e.value.look.toLookString(),
              'badgeIcon': e.value.equippedBadgeIcon ?? '',
              'room': e.value.room.name,
              'x': e.value.targetPos.dx.round(),
              'y': e.value.targetPos.dy.round(),
              'facing': e.value.facing.name,
              'isWalking': e.value.isWalking,
              'rest': e.value.restState.name,
              'thought': e.value.hasActiveThought ? e.value.thoughtText : '',
              'ts': e.value.lastSeenMs,
            },
      ];
      final b64 = base64Encode(
        utf8.encode(jsonEncode({'players': activeList, 'updatedAtMs': nowMs})),
      );
      await ApiService.instance.uploadStudentAvatar(
        id: _kCloudPresenceManifestId,
        dataUrl: 'data:image/png;base64,$b64',
      );
    } catch (_) {}
  }

  void _pruneStalePlayers() {
    final nowMs = DateTime.now().millisecondsSinceEpoch;
    final staleKeys = _remotePlayers.entries
        .where((e) => (nowMs - e.value.lastSeenMs) > kPlayerTimeoutMs)
        .map((e) => e.key)
        .toList();
    if (staleKeys.isNotEmpty) {
      for (final k in staleKeys) {
        _remotePlayers.remove(k);
      }
      notifyListeners();
    }
  }
}
