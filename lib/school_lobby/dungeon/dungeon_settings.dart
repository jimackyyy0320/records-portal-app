import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../account_save_sync_service.dart';
import '../spritecast_engine.dart';

/// Action identifiers for keyboard remapping & touch button layout customization.
class DungeonBindAction {
  static const String moveLeft = 'moveLeft';
  static const String moveRight = 'moveRight';
  static const String moveUp = 'moveUp';
  static const String moveDown = 'moveDown';
  static const String jump = 'jump';
  static const String slash = 'slash';
  static const String dash = 'dash';
  static const String skill = 'skill';
  static const String hook = 'hook';
  static const String bind = 'bind';
  static const String interact = 'interact';
  static const String openMap = 'openMap';

  static const List<String> allKeyboardActions = <String>[
    moveLeft,
    moveRight,
    moveUp,
    moveDown,
    jump,
    slash,
    dash,
    skill,
    hook,
    bind,
    interact,
    openMap,
  ];

  static const List<String> allTouchControlIds = <String>[
    'joystick',
    slash,
    jump,
    dash,
    skill,
    hook,
    bind,
  ];

  static String labelFor(String action) {
    switch (action) {
      case moveLeft:
        return 'Move Left';
      case moveRight:
        return 'Move Right';
      case moveUp:
        return 'Aim Up / Climb';
      case moveDown:
        return 'Aim Down / Pogo';
      case jump:
        return 'Jump';
      case slash:
        return 'Melee Slash';
      case dash:
        return 'Silk Dash';
      case skill:
        return 'Silk Skill';
      case hook:
        return 'Grapple Hook';
      case bind:
        return 'Silk Bind (Hold)';
      case interact:
        return 'Interact / Talk';
      case openMap:
        return 'World Map';
      case 'joystick':
        return '360° Joystick';
      default:
        return action;
    }
  }
}

/// Per-account customizable controls, touch button coordinates, keybinds, audio mixer,
/// and visual comfort settings (synced permanently to Google Sheets via [AccountSaveSyncService]).
class DungeonControlAndSettingsProfile {
  /// Normalized `[0.0..1.0]` screen center positions for custom-dragged touch controls.
  /// Empty map means use the spacious ergonomic arc default layout.
  final Map<String, Offset> customTouchPositions;
  final double buttonScale; // 0.75 .. 1.35
  final double buttonOpacity; // 0.35 .. 1.00
  final double joystickDeadzone; // 0.08 .. 0.30
  final bool mirrorLeftRight;

  /// Action -> `LogicalKeyboardKey.keyId`.
  final Map<String, int> keyBindings;

  /// Audio & Game-Feel Settings
  final double musicVolume; // 0.0 .. 1.0
  final double sfxVolume; // 0.0 .. 1.0
  final double screenShakeScale; // 0.0 .. 1.0
  final bool hitStopEnabled;
  final bool highGlowQuality;
  final bool hapticsEnabled;

  DungeonControlAndSettingsProfile({
    Map<String, Offset>? customTouchPositions,
    this.buttonScale = 1.0,
    this.buttonOpacity = 0.86,
    this.joystickDeadzone = 0.14,
    this.mirrorLeftRight = false,
    Map<String, int>? keyBindings,
    this.musicVolume = 0.72,
    this.sfxVolume = 0.85,
    this.screenShakeScale = 1.0,
    this.hitStopEnabled = true,
    this.highGlowQuality = true,
    this.hapticsEnabled = true,
  })  : customTouchPositions =
            customTouchPositions ?? const <String, Offset>{},
        keyBindings = keyBindings ?? defaultKeyBindings();

  static Map<String, int> defaultKeyBindings() => <String, int>{
        DungeonBindAction.moveLeft: LogicalKeyboardKey.keyA.keyId,
        DungeonBindAction.moveRight: LogicalKeyboardKey.keyD.keyId,
        DungeonBindAction.moveUp: LogicalKeyboardKey.keyW.keyId,
        DungeonBindAction.moveDown: LogicalKeyboardKey.keyS.keyId,
        DungeonBindAction.jump: LogicalKeyboardKey.space.keyId,
        DungeonBindAction.slash: LogicalKeyboardKey.keyJ.keyId,
        DungeonBindAction.dash: LogicalKeyboardKey.keyK.keyId,
        DungeonBindAction.skill: LogicalKeyboardKey.keyL.keyId,
        DungeonBindAction.hook: LogicalKeyboardKey.keyG.keyId,
        DungeonBindAction.bind: LogicalKeyboardKey.keyH.keyId,
        DungeonBindAction.interact: LogicalKeyboardKey.keyE.keyId,
        DungeonBindAction.openMap: LogicalKeyboardKey.keyM.keyId,
      };

  /// Default normalized `[0..1]` positions inside a landscape/mobile viewport
  /// with generous `18px+` clearance between every skill button!
  static Map<String, Offset> defaultNormalizedTouchPositions({
    bool mirrored = false,
  }) {
    final base = <String, Offset>{
      'joystick': const Offset(0.13, 0.78),
      DungeonBindAction.slash: const Offset(0.83, 0.82),
      DungeonBindAction.jump: const Offset(0.93, 0.72),
      DungeonBindAction.dash: const Offset(0.73, 0.84),
      DungeonBindAction.skill: const Offset(0.91, 0.52),
      DungeonBindAction.hook: const Offset(0.81, 0.56),
      DungeonBindAction.bind: const Offset(0.71, 0.65),
    };
    if (!mirrored) return base;
    return base.map((k, v) => MapEntry(k, Offset(1.0 - v.dx, v.dy)));
  }

  Offset normalizedTouchPos(String controlId) {
    final custom = customTouchPositions[controlId];
    if (custom != null) {
      return Offset(
        custom.dx.clamp(0.06, 0.94),
        custom.dy.clamp(0.18, 0.93),
      );
    }
    final defaults =
        defaultNormalizedTouchPositions(mirrored: mirrorLeftRight);
    return defaults[controlId] ?? const Offset(0.80, 0.80);
  }

  int keyIdFor(String action) {
    return keyBindings[action] ??
        defaultKeyBindings()[action] ??
        LogicalKeyboardKey.space.keyId;
  }

  bool matchesKey(String action, LogicalKeyboardKey key) {
    if (key.keyId == keyIdFor(action)) return true;
    // Always preserve arrow keys as secondary directional fallbacks unless rebound
    if (action == DungeonBindAction.moveLeft &&
        key == LogicalKeyboardKey.arrowLeft) {
      return true;
    }
    if (action == DungeonBindAction.moveRight &&
        key == LogicalKeyboardKey.arrowRight) {
      return true;
    }
    if (action == DungeonBindAction.moveUp &&
        key == LogicalKeyboardKey.arrowUp) {
      return true;
    }
    if (action == DungeonBindAction.moveDown &&
        key == LogicalKeyboardKey.arrowDown) {
      return true;
    }
    return false;
  }

  static String formatKeyLabel(int keyId) {
    final key = LogicalKeyboardKey.findKeyByKeyId(keyId);
    if (key == null) return 'KEY';
    if (key == LogicalKeyboardKey.space) return 'SPACE';
    if (key == LogicalKeyboardKey.arrowLeft) return 'LEFT';
    if (key == LogicalKeyboardKey.arrowRight) return 'RIGHT';
    if (key == LogicalKeyboardKey.arrowUp) return 'UP';
    if (key == LogicalKeyboardKey.arrowDown) return 'DOWN';
    if (key == LogicalKeyboardKey.shiftLeft ||
        key == LogicalKeyboardKey.shiftRight) {
      return 'SHIFT';
    }
    final label = key.keyLabel.trim();
    if (label.isNotEmpty) return label.toUpperCase();
    final debug = key.debugName ?? 'KEY';
    return debug.replaceAll('Key ', '').toUpperCase();
  }

  DungeonControlAndSettingsProfile copyWith({
    Map<String, Offset>? customTouchPositions,
    double? buttonScale,
    double? buttonOpacity,
    double? joystickDeadzone,
    bool? mirrorLeftRight,
    Map<String, int>? keyBindings,
    double? musicVolume,
    double? sfxVolume,
    double? screenShakeScale,
    bool? hitStopEnabled,
    bool? highGlowQuality,
    bool? hapticsEnabled,
  }) {
    return DungeonControlAndSettingsProfile(
      customTouchPositions: customTouchPositions ?? this.customTouchPositions,
      buttonScale: (buttonScale ?? this.buttonScale).clamp(0.75, 1.35),
      buttonOpacity: (buttonOpacity ?? this.buttonOpacity).clamp(0.35, 1.0),
      joystickDeadzone:
          (joystickDeadzone ?? this.joystickDeadzone).clamp(0.08, 0.30),
      mirrorLeftRight: mirrorLeftRight ?? this.mirrorLeftRight,
      keyBindings: keyBindings ?? this.keyBindings,
      musicVolume: (musicVolume ?? this.musicVolume).clamp(0.0, 1.0),
      sfxVolume: (sfxVolume ?? this.sfxVolume).clamp(0.0, 1.0),
      screenShakeScale:
          (screenShakeScale ?? this.screenShakeScale).clamp(0.0, 1.0),
      hitStopEnabled: hitStopEnabled ?? this.hitStopEnabled,
      highGlowQuality: highGlowQuality ?? this.highGlowQuality,
      hapticsEnabled: hapticsEnabled ?? this.hapticsEnabled,
    );
  }

  Map<String, dynamic> toJson() => <String, dynamic>{
        'customTouchPositions': customTouchPositions.map(
          (k, v) => MapEntry(k, <String, double>{'dx': v.dx, 'dy': v.dy}),
        ),
        'buttonScale': buttonScale,
        'buttonOpacity': buttonOpacity,
        'joystickDeadzone': joystickDeadzone,
        'mirrorLeftRight': mirrorLeftRight,
        'keyBindings': keyBindings,
        'musicVolume': musicVolume,
        'sfxVolume': sfxVolume,
        'screenShakeScale': screenShakeScale,
        'hitStopEnabled': hitStopEnabled,
        'highGlowQuality': highGlowQuality,
        'hapticsEnabled': hapticsEnabled,
      };

  factory DungeonControlAndSettingsProfile.fromJson(Map<String, dynamic> json) {
    final parsedTouch = <String, Offset>{};
    final rawTouch = json['customTouchPositions'];
    if (rawTouch is Map) {
      rawTouch.forEach((k, v) {
        if (v is Map) {
          final dx = (v['dx'] as num?)?.toDouble();
          final dy = (v['dy'] as num?)?.toDouble();
          if (dx != null && dy != null) {
            parsedTouch[k.toString()] = Offset(
              dx.clamp(0.06, 0.94),
              dy.clamp(0.18, 0.93),
            );
          }
        }
      });
    }

    final parsedKeys = defaultKeyBindings();
    final rawKeys = json['keyBindings'];
    if (rawKeys is Map) {
      rawKeys.forEach((k, v) {
        if (v is num) {
          parsedKeys[k.toString()] = v.toInt();
        }
      });
    }

    return DungeonControlAndSettingsProfile(
      customTouchPositions: parsedTouch,
      buttonScale: ((json['buttonScale'] as num?)?.toDouble() ?? 1.0)
          .clamp(0.75, 1.35),
      buttonOpacity: ((json['buttonOpacity'] as num?)?.toDouble() ?? 0.86)
          .clamp(0.35, 1.0),
      joystickDeadzone:
          ((json['joystickDeadzone'] as num?)?.toDouble() ?? 0.14)
              .clamp(0.08, 0.30),
      mirrorLeftRight: json['mirrorLeftRight'] == true,
      keyBindings: parsedKeys,
      musicVolume: ((json['musicVolume'] as num?)?.toDouble() ?? 0.72)
          .clamp(0.0, 1.0),
      sfxVolume:
          ((json['sfxVolume'] as num?)?.toDouble() ?? 0.85).clamp(0.0, 1.0),
      screenShakeScale:
          ((json['screenShakeScale'] as num?)?.toDouble() ?? 1.0)
              .clamp(0.0, 1.0),
      hitStopEnabled: json['hitStopEnabled'] != false,
      highGlowQuality: json['highGlowQuality'] != false,
      hapticsEnabled: json['hapticsEnabled'] != false,
    );
  }

  static Future<DungeonControlAndSettingsProfile> load(String userId) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs
          .getString('${AccountSaveSyncService.kDungeonSettingsPrefix}$userId');
      if (raw != null && raw.isNotEmpty) {
        final decoded = jsonDecode(raw);
        if (decoded is Map<String, dynamic>) {
          return DungeonControlAndSettingsProfile.fromJson(decoded);
        }
      }
    } catch (_) {}
    return DungeonControlAndSettingsProfile();
  }

  Future<void> persist(String userId) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(
        '${AccountSaveSyncService.kDungeonSettingsPrefix}$userId',
        jsonEncode(toJson()),
      );
      AccountSaveSyncService.instance.scheduleActiveAccountSync();
    } catch (_) {}
  }
}

/// Interactive 3-Tab Settings & Button Remapping Studio:
/// 1. **TOUCH MAPPER** — Drag-and-drop every touch button & joystick anywhere + Scale/Opacity/Deadzone/Mirror
/// 2. **KEYBINDS** — Click any action and press any keyboard key to remap (auto-swaps conflicts)
/// 3. **AUDIO & FX** — Music Volume, SFX Volume, Screen-Shake, Hit-Stop, Volumetric Lighting & Haptics
class DungeonSettingsStudioModal extends StatefulWidget {
  final DungeonControlAndSettingsProfile initialProfile;
  final ValueChanged<DungeonControlAndSettingsProfile> onChanged;
  final VoidCallback onClose;

  const DungeonSettingsStudioModal({
    super.key,
    required this.initialProfile,
    required this.onChanged,
    required this.onClose,
  });

  @override
  State<DungeonSettingsStudioModal> createState() =>
      _DungeonSettingsStudioModalState();
}

class _DungeonSettingsStudioModalState
    extends State<DungeonSettingsStudioModal> {
  late DungeonControlAndSettingsProfile _profile;
  final FocusNode _captureFocusNode = FocusNode();
  int _tabIndex = 0; // 0 = Touch Mapper, 1 = Keybinds, 2 = Audio & FX
  String? _listeningAction;
  String _selectedControlId = DungeonBindAction.slash;

  @override
  void initState() {
    super.initState();
    _profile = widget.initialProfile;
  }

  @override
  void dispose() {
    _captureFocusNode.dispose();
    super.dispose();
  }

  void _apply(DungeonControlAndSettingsProfile next) {
    setState(() => _profile = next);
    widget.onChanged(next);
  }

  void _onCaptureKey(KeyEvent event) {
    if (_listeningAction == null || event is! KeyDownEvent) return;
    final key = event.logicalKey;
    if (key == LogicalKeyboardKey.escape) {
      setState(() => _listeningAction = null);
      return;
    }
    final targetAction = _listeningAction!;
    final updated = Map<String, int>.from(_profile.keyBindings);
    final prevKeyForTarget = _profile.keyIdFor(targetAction);

    // Auto-swap if another action already uses this key!
    for (final entry in updated.entries.toList()) {
      if (entry.key != targetAction && entry.value == key.keyId) {
        updated[entry.key] = prevKeyForTarget;
      }
    }
    updated[targetAction] = key.keyId;
    _listeningAction = null;
    _apply(_profile.copyWith(keyBindings: updated));
  }

  @override
  Widget build(BuildContext context) {
    return KeyboardListener(
      focusNode: _captureFocusNode,
      autofocus: true,
      onKeyEvent: _onCaptureKey,
      child: Material(
        color: SpriteCastPalette.ink.withValues(alpha: 0.92),
        child: SafeArea(
          child: Center(
            child: Container(
              constraints: const BoxConstraints(maxWidth: 680, maxHeight: 500),
              margin: const EdgeInsets.all(12),
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: const Color(0xFF171B2E),
                border: Border.all(
                  color: SpriteCastPalette.endesga32[10],
                  width: 2.0,
                ),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Material(
                type: MaterialType.transparency,
                child: Column(
                  children: [
                  // Header Row
                  Row(
                    children: [
                      const Icon(
                        Icons.tune_rounded,
                        color: Color(0xFFFEE761),
                        size: 20,
                      ),
                      const SizedBox(width: 8),
                      const Expanded(
                        child: Text(
                          'SOVEREIGN CONTROLS, BUTTON MAPPER & AUDIO STUDIO',
                          style: TextStyle(
                            color: Color(0xFFFEE761),
                            fontSize: 13,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 0.6,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close_rounded, color: Colors.white),
                        tooltip: 'Save & Close',
                        onPressed: widget.onClose,
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  // 3 Studio Tabs
                  Row(
                    children: [
                      _buildTabChip(0, Icons.touch_app_rounded, 'TOUCH LAYOUT'),
                      const SizedBox(width: 6),
                      _buildTabChip(1, Icons.keyboard_rounded, 'KEYBINDS'),
                      const SizedBox(width: 6),
                      _buildTabChip(2, Icons.graphic_eq_rounded, 'AUDIO & FX'),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Expanded(
                    child: _tabIndex == 0
                        ? _buildTouchMapperTab()
                        : (_tabIndex == 1
                            ? _buildKeybindsTab()
                            : _buildAudioAndVisualsTab()),
                  ),
                ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTabChip(int index, IconData icon, String label) {
    final selected = _tabIndex == index;
    return Expanded(
      child: InkWell(
        onTap: () => setState(() {
          _tabIndex = index;
          _listeningAction = null;
        }),
        borderRadius: BorderRadius.circular(8),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 6),
          decoration: BoxDecoration(
            color: selected ? const Color(0xFF283152) : const Color(0xFF101322),
            border: Border.all(
              color: selected
                  ? SpriteCastPalette.endesga32[18]
                  : const Color(0xFF2F3858),
              width: 1.5,
            ),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                icon,
                size: 14,
                color: selected
                    ? const Color(0xFF2CE8F5)
                    : const Color(0xFF8B9BB4),
              ),
              const SizedBox(width: 5),
              Flexible(
                child: Text(
                  label,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: selected ? Colors.white : const Color(0xFF8B9BB4),
                    fontSize: 10.5,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ─────────────────────── TAB 0: DRAG-AND-DROP TOUCH MAPPER ───────────────────────

  Widget _buildTouchMapperTab() {
    return Column(
      children: [
        Row(
          children: [
            const Expanded(
              child: Text(
                'Drag any button on the canvas below to customize your mobile layout!',
                style: TextStyle(color: Color(0xFFC0CBDC), fontSize: 11),
              ),
            ),
            TextButton.icon(
              onPressed: () {
                _apply(
                  _profile.copyWith(
                    customTouchPositions: <String, Offset>{},
                    buttonScale: 1.0,
                    buttonOpacity: 0.86,
                    joystickDeadzone: 0.14,
                    mirrorLeftRight: false,
                  ),
                );
              },
              icon: const Icon(Icons.restart_alt_rounded, size: 15),
              label: const Text(
                'RESET DEFAULT',
                style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.w800),
              ),
            ),
          ],
        ),
        const SizedBox(height: 4),
        // Interactive Drag-and-Drop Mini Viewport!
        Expanded(
          child: LayoutBuilder(
            builder: (context, constraints) {
              final w = constraints.maxWidth;
              final h = constraints.maxHeight;
              return Container(
                decoration: BoxDecoration(
                  color: const Color(0xFF0C0F1C),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: const Color(0xFF344063)),
                ),
                child: Stack(
                  clipBehavior: Clip.hardEdge,
                  children: [
                    // Subtle grid guide lines
                    Positioned.fill(
                      child: CustomPaint(painter: _MapperGridGuidePainter()),
                    ),
                    for (final id in DungeonBindAction.allTouchControlIds)
                      _buildDraggablePreviewNode(id, w, h),
                  ],
                ),
              );
            },
          ),
        ),
        const SizedBox(height: 8),
        // Compact Ergonomic Sliders + Left-Handed Mirror Toggle
        Wrap(
          spacing: 12,
          runSpacing: 4,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            _CompactSlider(
              label: 'SIZE ${(100 * _profile.buttonScale).round()}%',
              value: _profile.buttonScale,
              min: 0.75,
              max: 1.35,
              onChanged: (v) => _apply(_profile.copyWith(buttonScale: v)),
            ),
            _CompactSlider(
              label: 'OPACITY ${(100 * _profile.buttonOpacity).round()}%',
              value: _profile.buttonOpacity,
              min: 0.35,
              max: 1.0,
              onChanged: (v) => _apply(_profile.copyWith(buttonOpacity: v)),
            ),
            _CompactSlider(
              label: 'DEADZONE ${(100 * _profile.joystickDeadzone).round()}%',
              value: _profile.joystickDeadzone,
              min: 0.08,
              max: 0.30,
              onChanged: (v) => _apply(_profile.copyWith(joystickDeadzone: v)),
            ),
            FilterChip(
              label: const Text(
                'LEFT-HANDED MIRROR',
                style: TextStyle(fontSize: 10, fontWeight: FontWeight.w800),
              ),
              selected: _profile.mirrorLeftRight,
              selectedColor: const Color(0xFF28506E),
              checkmarkColor: const Color(0xFF2CE8F5),
              labelStyle: const TextStyle(color: Colors.white),
              backgroundColor: const Color(0xFF1A2036),
              onSelected: (val) => _apply(
                _profile.copyWith(
                  mirrorLeftRight: val,
                  customTouchPositions: <String, Offset>{},
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildDraggablePreviewNode(String id, double canvasW, double canvasH) {
    final norm = _profile.normalizedTouchPos(id);
    final isJoystick = id == 'joystick';
    final baseDia = isJoystick
        ? 68.0
        : (id == DungeonBindAction.slash
            ? 42.0
            : (id == DungeonBindAction.jump ? 40.0 : 34.0));
    final dia = baseDia * _profile.buttonScale;
    final left = (norm.dx * canvasW - dia * 0.5).clamp(2.0, canvasW - dia - 2.0);
    final top = (norm.dy * canvasH - dia * 0.5).clamp(2.0, canvasH - dia - 2.0);
    final selected = _selectedControlId == id;

    Color accent;
    switch (id) {
      case 'joystick':
        accent = SpriteCastPalette.endesga32[10];
        break;
      case DungeonBindAction.slash:
        accent = SpriteCastPalette.endesga32[8];
        break;
      case DungeonBindAction.jump:
        accent = SpriteCastPalette.endesga32[18];
        break;
      case DungeonBindAction.dash:
        accent = SpriteCastPalette.endesga32[10];
        break;
      case DungeonBindAction.skill:
        accent = SpriteCastPalette.endesga32[11];
        break;
      case DungeonBindAction.hook:
        accent = SpriteCastPalette.endesga32[17];
        break;
      default:
        accent = SpriteCastPalette.endesga32[12];
        break;
    }

    return Positioned(
      left: left,
      top: top,
      child: GestureDetector(
        key: ValueKey<String>('mapper_node_$id'),
        onPanStart: (_) => setState(() => _selectedControlId = id),
        onPanUpdate: (details) {
          final nextCenterX =
              ((left + dia * 0.5 + details.delta.dx) / canvasW).clamp(0.06, 0.94);
          final nextCenterY =
              ((top + dia * 0.5 + details.delta.dy) / canvasH).clamp(0.18, 0.93);
          final nextMap =
              Map<String, Offset>.from(_profile.customTouchPositions);
          nextMap[id] = Offset(nextCenterX, nextCenterY);
          _apply(_profile.copyWith(customTouchPositions: nextMap));
        },
        child: Opacity(
          opacity: _profile.buttonOpacity,
          child: Container(
            width: dia,
            height: dia,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: const Color(0xFF181D33),
              border: Border.all(
                color: selected ? Colors.white : accent,
                width: selected ? 2.6 : 1.8,
              ),
              boxShadow: selected
                  ? [
                      BoxShadow(
                        color: accent.withValues(alpha: 0.55),
                        blurRadius: 10,
                      ),
                    ]
                  : null,
            ),
            child: Text(
              isJoystick ? 'STICK' : id.toUpperCase(),
              textAlign: TextAlign.center,
              style: TextStyle(
                color: accent,
                fontSize: isJoystick ? 9.5 : 8.5,
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
        ),
      ),
    );
  }

  // ───────────────────────── TAB 1: KEYBOARD REMAPPER ─────────────────────────

  Widget _buildKeybindsTab() {
    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                _listeningAction != null
                    ? 'PRESS ANY KEY FOR "${DungeonBindAction.labelFor(_listeningAction!).toUpperCase()}" (ESC to cancel)...'
                    : 'Tap any keybind badge to remap it. Conflicts swap automatically!',
                style: TextStyle(
                  color: _listeningAction != null
                      ? const Color(0xFFFEE761)
                      : const Color(0xFFC0CBDC),
                  fontSize: 11,
                  fontWeight: _listeningAction != null
                      ? FontWeight.w900
                      : FontWeight.w500,
                ),
              ),
            ),
            TextButton.icon(
              onPressed: () {
                _listeningAction = null;
                _apply(
                  _profile.copyWith(
                    keyBindings:
                        DungeonControlAndSettingsProfile.defaultKeyBindings(),
                  ),
                );
              },
              icon: const Icon(Icons.restore_rounded, size: 15),
              label: const Text(
                'DEFAULT KEYS',
                style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.w800),
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        Expanded(
          child: GridView.builder(
            gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
              maxCrossAxisExtent: 310,
              mainAxisExtent: 42,
              crossAxisSpacing: 8,
              mainAxisSpacing: 6,
            ),
            itemCount: DungeonBindAction.allKeyboardActions.length,
            itemBuilder: (context, idx) {
              final action = DungeonBindAction.allKeyboardActions[idx];
              final isListening = _listeningAction == action;
              final keyLabel = DungeonControlAndSettingsProfile.formatKeyLabel(
                _profile.keyIdFor(action),
              );
              return InkWell(
                key: ValueKey<String>('keybind_row_$action'),
                onTap: () {
                  setState(() => _listeningAction = action);
                  _captureFocusNode.requestFocus();
                },
                borderRadius: BorderRadius.circular(8),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10),
                  decoration: BoxDecoration(
                    color: isListening
                        ? const Color(0xFF332D19)
                        : const Color(0xFF101425),
                    border: Border.all(
                      color: isListening
                          ? const Color(0xFFFEE761)
                          : const Color(0xFF2A3352),
                    ),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          DungeonBindAction.labelFor(action),
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 11.5,
                            fontWeight: FontWeight.w700,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: isListening
                              ? const Color(0xFFFEE761)
                              : const Color(0xFF222A46),
                          borderRadius: BorderRadius.circular(5),
                        ),
                        child: Text(
                          isListening ? 'PRESS KEY...' : keyLabel,
                          style: TextStyle(
                            color: isListening
                                ? SpriteCastPalette.ink
                                : const Color(0xFF2CE8F5),
                            fontSize: 10,
                            fontWeight: FontWeight.w900,
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
    );
  }

  // ────────────────────── TAB 2: AUDIO MIXER & VISUALS ──────────────────────

  Widget _buildAudioAndVisualsTab() {
    return ListView(
      children: [
        _FullSettingSliderTile(
          icon: Icons.music_note_rounded,
          title: 'Background Music Volume',
          subtitle: 'Looping Era & Boss Orchestral-Rondalla Soundtrack',
          value: _profile.musicVolume,
          onChanged: (v) => _apply(_profile.copyWith(musicVolume: v)),
        ),
        const SizedBox(height: 8),
        _FullSettingSliderTile(
          icon: Icons.volume_up_rounded,
          title: 'Sound Effects (SFX) Volume',
          subtitle: 'Smooth Low-Pass Filtered Combat, Footstep & UI Cues',
          value: _profile.sfxVolume,
          onChanged: (v) => _apply(_profile.copyWith(sfxVolume: v)),
        ),
        const SizedBox(height: 8),
        _FullSettingSliderTile(
          icon: Icons.vibration_rounded,
          title: 'Camera Screen-Shake Scale',
          subtitle: 'Directional impact recoil during finishers & boss slams',
          value: _profile.screenShakeScale,
          onChanged: (v) => _apply(_profile.copyWith(screenShakeScale: v)),
        ),
        const SizedBox(height: 8),
        SwitchListTile(
          dense: true,
          contentPadding: const EdgeInsets.symmetric(horizontal: 10),
          tileColor: const Color(0xFF101425),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          title: const Text(
            'Volumetric God-Rays & Additive Bloom',
            style: TextStyle(
              color: Colors.white,
              fontSize: 12,
              fontWeight: FontWeight.w800,
            ),
          ),
          subtitle: const Text(
            'Enables architectural sunbeams, dust motes, and torch bloom halos',
            style: TextStyle(color: Color(0xFF8B9BB4), fontSize: 10.5),
          ),
          value: _profile.highGlowQuality,
          onChanged: (v) => _apply(_profile.copyWith(highGlowQuality: v)),
        ),
        const SizedBox(height: 6),
        SwitchListTile(
          dense: true,
          contentPadding: const EdgeInsets.symmetric(horizontal: 10),
          tileColor: const Color(0xFF101425),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          title: const Text(
            'Combat Hit-Stop Impact Freeze',
            style: TextStyle(
              color: Colors.white,
              fontSize: 12,
              fontWeight: FontWeight.w800,
            ),
          ),
          subtitle: const Text(
            'Brief crisp impact pause on heavy cleaves, parries, and counter-breaks',
            style: TextStyle(color: Color(0xFF8B9BB4), fontSize: 10.5),
          ),
          value: _profile.hitStopEnabled,
          onChanged: (v) => _apply(_profile.copyWith(hitStopEnabled: v)),
        ),
        const SizedBox(height: 6),
        SwitchListTile(
          dense: true,
          contentPadding: const EdgeInsets.symmetric(horizontal: 10),
          tileColor: const Color(0xFF101425),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          title: const Text(
            'Tactile Haptic Feedback',
            style: TextStyle(
              color: Colors.white,
              fontSize: 12,
              fontWeight: FontWeight.w800,
            ),
          ),
          subtitle: const Text(
            'Subtle vibration pulse on golden parries and heavy hits',
            style: TextStyle(color: Color(0xFF8B9BB4), fontSize: 10.5),
          ),
          value: _profile.hapticsEnabled,
          onChanged: (v) => _apply(_profile.copyWith(hapticsEnabled: v)),
        ),
      ],
    );
  }
}

class _MapperGridGuidePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final p = Paint()
      ..color = const Color(0x188B9BB4)
      ..strokeWidth = 1.0;
    for (var i = 1; i < 6; i++) {
      final x = size.width * (i / 6.0);
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), p);
    }
    for (var j = 1; j < 4; j++) {
      final y = size.height * (j / 4.0);
      canvas.drawLine(Offset(0, y), Offset(size.width, y), p);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _CompactSlider extends StatelessWidget {
  final String label;
  final double value;
  final double min;
  final double max;
  final ValueChanged<double> onChanged;

  const _CompactSlider({
    required this.label,
    required this.value,
    required this.min,
    required this.max,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 156,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            label,
            style: const TextStyle(
              color: Color(0xFFEAD4AA),
              fontSize: 9.5,
              fontWeight: FontWeight.w800,
            ),
          ),
          SliderTheme(
            data: SliderTheme.of(context).copyWith(
              trackHeight: 3.0,
              thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 6.0),
              overlayShape: const RoundSliderOverlayShape(overlayRadius: 12.0),
            ),
            child: Slider(
              value: value.clamp(min, max),
              min: min,
              max: max,
              activeColor: const Color(0xFF2CE8F5),
              inactiveColor: const Color(0xFF2B3354),
              onChanged: onChanged,
            ),
          ),
        ],
      ),
    );
  }
}

class _FullSettingSliderTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final double value;
  final ValueChanged<double> onChanged;

  const _FullSettingSliderTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.value,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 4),
      decoration: BoxDecoration(
        color: const Color(0xFF101425),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFF252E4C)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: const Color(0xFFFEE761), size: 16),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              Text(
                '${(value * 100).round()}%',
                style: const TextStyle(
                  color: Color(0xFF2CE8F5),
                  fontSize: 11,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ],
          ),
          Text(
            subtitle,
            style: const TextStyle(color: Color(0xFF8B9BB4), fontSize: 10),
          ),
          Slider(
            value: value.clamp(0.0, 1.0),
            min: 0.0,
            max: 1.0,
            activeColor: const Color(0xFF2CE8F5),
            inactiveColor: const Color(0xFF2B3354),
            onChanged: onChanged,
          ),
        ],
      ),
    );
  }
}
