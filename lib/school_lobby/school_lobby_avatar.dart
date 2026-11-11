import 'dart:async';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'lobby_data_service.dart';
import 'lobby_shop_service.dart';

/// Recycled from TinyFloor `character.ts` & `characters.json`:
/// 32x64 pixel frame dimensions, 48 frames per strip:
/// - Frames 0..23: Idle (6 frames per facing: right=0..5, up=6..11, left=12..17, down=18..23)
/// - Frames 24..47: Walk (6 frames per facing: right=24..29, up=30..35, left=36..41, down=42..47)
const double kCharFrameWidth = 32.0;
const double kCharFrameHeight = 64.0;
const int kCharFramesPerDirection = 6;

enum AvatarFacing {
  right, // index 0
  up, // index 1
  left, // index 2
  down, // index 3
}

int facingOrderIndex(AvatarFacing facing) {
  switch (facing) {
    case AvatarFacing.right:
      return 0;
    case AvatarFacing.up:
      return 1;
    case AvatarFacing.left:
      return 2;
    case AvatarFacing.down:
      return 3;
  }
}

/// Computes the frame index (0..47) in a TinyFloor 48-frame strip.
int computeCharacterFrameIndex({
  required AvatarFacing facing,
  required bool isWalking,
  required int stepFrame,
}) {
  final dirOffset = facingOrderIndex(facing) * kCharFramesPerDirection;
  final baseOffset = isWalking ? 24 : 0;
  return baseOffset + dirOffset + (stepFrame % kCharFramesPerDirection);
}

/// Bundled TinyFloor Preset Characters (`assets/school_lobby/characters/presets/*.png`).
const List<String> kBundledPresets = [
  'Adam',
  'Alex',
  'Amelia',
  'Ash',
  'Bob',
  'Dan',
  'Lucy',
  'Molly',
  'Bruce',
  'Samuel',
  'Edward',
  'Rob',
  'Roki',
  'Pier',
  'Josh',
  'Jenny',
];

/// Expanded Bundled Custom Layer Options (`assets/school_lobby/characters/parts/<group>/<id>.png`).
const Map<String, List<Map<String, String>>> kBundledCustomParts = {
  'body': [
    {'id': '1', 'label': 'Warm Tan', 'hex': '#bf8b78'},
    {'id': '2', 'label': 'Fair Peach', 'hex': '#ffcbb0'},
    {'id': '3', 'label': 'Golden Sun', 'hex': '#ffb893'},
    {'id': '4', 'label': 'Rich Bronze', 'hex': '#bb845c'},
    {'id': '5', 'label': 'Olive Sand', 'hex': '#cdb57a'},
    {'id': '6', 'label': 'Porcelain', 'hex': '#d4cabb'},
    {'id': '7', 'label': 'Honey Glow', 'hex': '#f0ae80'},
    {'id': '8', 'label': 'Rose Quartz', 'hex': '#e6b8d7'},
    {'id': '9', 'label': 'Cool Mist', 'hex': '#bab8d7'},
  ],
  'eyes': [
    {'id': '1', 'label': 'Espresso', 'hex': '#674d49'},
    {'id': '2', 'label': 'Emerald', 'hex': '#568d61'},
    {'id': '3', 'label': 'Hazel', 'hex': '#959d58'},
    {'id': '4', 'label': 'Slate', 'hex': '#6c6e85'},
    {'id': '5', 'label': 'Amber', 'hex': '#956020'},
    {'id': '6', 'label': 'Ocean Blue', 'hex': '#3b7aa2'},
    {'id': '7', 'label': 'Sky Cyan', 'hex': '#5ed6f2'},
  ],
  'outfit': [
    {'id': '1-1', 'label': 'Violet Hoodie', 'hex': '#805e8e'},
    {'id': '1-2', 'label': 'Sky Uniform', 'hex': '#a6b6e9'},
    {'id': '1-3', 'label': 'Khaki Vest', 'hex': '#bfa690'},
    {'id': '1-4', 'label': 'Crimson Jacket', 'hex': '#d93232'},
    {'id': '1-5', 'label': 'Forest Hoodie', 'hex': '#3e6d5e'},
    {'id': '2-1', 'label': 'Maroon Cardigan', 'hex': '#a2394b'},
    {'id': '2-2', 'label': 'Burgundy Blazer', 'hex': '#90444c'},
    {'id': '3-1', 'label': 'Navy Scholar', 'hex': '#565972'},
    {'id': '4-1', 'label': 'Emerald Sweater', 'hex': '#578468'},
    {'id': '5-1', 'label': 'Slate Coat', 'hex': '#6c6e85'},
    {'id': '7-1', 'label': 'Indigo Tunic', 'hex': '#6c6e85'},
    {'id': '7-4', 'label': 'Rose Dress', 'hex': '#bb718a'},
    {'id': '10-1', 'label': 'Silver Varsity', 'hex': '#9094aa'},
    {'id': '10-2', 'label': 'Cobalt Varsity', 'hex': '#6c95b7'},
    {'id': '11-1', 'label': 'Lavender Knit', 'hex': '#be9fcc'},
    {'id': '11-3', 'label': 'Lilac Pullover', 'hex': '#beb6cc'},
    {'id': '14-1', 'label': 'Denim Jacket', 'hex': '#647e99'},
    {'id': '15-1', 'label': 'Crisp White Shirt', 'hex': '#ebf3ff'},
    {'id': '16-1', 'label': 'Amber Tracksuit', 'hex': '#f5aa14'},
    {'id': '17-1', 'label': 'Teal Windbreaker', 'hex': '#4b9296'},
    {'id': '18-1', 'label': 'Terracotta Coat', 'hex': '#c37759'},
    {'id': '19-1', 'label': 'Royal Polo', 'hex': '#4280dd'},
    {'id': '20-1', 'label': 'Midnight Suit', 'hex': '#4d5988'},
    {'id': '24-1', 'label': 'Cerulean Tee', 'hex': '#0092e3'},
    {'id': '25-1', 'label': 'Azure Hoodie', 'hex': '#0092e3'},
    {'id': '31-1', 'label': 'Academy Blazer', 'hex': '#335789'},
  ],
  'hair': [
    {'id': 'none', 'label': 'None', 'hex': '#334155'},
    {'id': '1-1', 'label': 'Auburn Short', 'hex': '#ab6736'},
    {'id': '1-3', 'label': 'Chestnut Short', 'hex': '#724a40'},
    {'id': '2-4', 'label': 'Dark Tousled', 'hex': '#674d49'},
    {'id': '3-1', 'label': 'Golden Wave', 'hex': '#cc9659'},
    {'id': '4-3', 'label': 'Side Sweep', 'hex': '#724a40'},
    {'id': '5-4', 'label': 'Espresso Taper', 'hex': '#674d49'},
    {'id': '6-5', 'label': 'Silver Spike', 'hex': '#a2a2a0'},
    {'id': '9-1', 'label': 'Honey Bob', 'hex': '#b37b3f'},
    {'id': '10-2', 'label': 'Mocha Long', 'hex': '#8a6552'},
    {'id': '12-2', 'label': 'Caramel Part', 'hex': '#957350'},
    {'id': '12-7', 'label': 'Midnight Part', 'hex': '#566279'},
    {'id': '15-2', 'label': 'Walnut Twin', 'hex': '#8a6552'},
    {'id': '16-7', 'label': 'Indigo Curly', 'hex': '#566279'},
    {'id': '17-4', 'label': 'Classic Dark', 'hex': '#674d49'},
    {'id': '18-2', 'label': 'Breeze Cut', 'hex': '#957350'},
    {'id': '19-5', 'label': 'Ash Fringe', 'hex': '#898887'},
    {'id': '20-4', 'label': 'Scholar Fade', 'hex': '#674d49'},
    {'id': '21-7', 'label': 'Stealth Messy', 'hex': '#566279'},
    {'id': '22-1', 'label': 'Golden Pomp', 'hex': '#b37b3f'},
    {'id': '23-1', 'label': 'Sunburst Wavy', 'hex': '#b37b3f'},
    {'id': '24-1', 'label': 'Amber Curls', 'hex': '#b37b3f'},
    {'id': '25-1', 'label': 'Copper Ponytail', 'hex': '#ab6736'},
    {'id': '26-1', 'label': 'Golden bangs', 'hex': '#b37b3f'},
    {'id': '27-1', 'label': 'Sakura Pink', 'hex': '#e88dad'},
    {'id': '28-4', 'label': 'Cobalt Shag', 'hex': '#4280dd'},
    {'id': '29-4', 'label': 'Sky Anime Cut', 'hex': '#50a7e8'},
  ],
  'face': [
    {'id': 'none', 'label': 'None', 'hex': '#334155'},
    {'id': '7-1', 'label': 'Dapper Stache', 'hex': '#51506f'},
    {'id': '12-1', 'label': 'Full Beard', 'hex': '#8a6552'},
    {'id': '13-1', 'label': 'Goatee Trim', 'hex': '#6f5449'},
    {'id': '16-1', 'label': 'Chin Strap', 'hex': '#795237'},
    {'id': '17-1', 'label': 'Face Mask', 'hex': '#ffffff'},
  ],
  'glasses': [
    {'id': 'none', 'label': 'None', 'hex': '#334155'},
    {'id': '15-1', 'label': 'Charcoal Frames', 'hex': '#58616f'},
    {'id': '15-2', 'label': 'Ruby Frames', 'hex': '#c7405a'},
    {'id': '15-3', 'label': 'Violet Frames', 'hex': '#b81ea4'},
    {'id': '15-4', 'label': 'Cyan Frames', 'hex': '#40a2c7'},
    {'id': '15-5', 'label': 'Emerald Frames', 'hex': '#1eb82f'},
    {'id': '15-6', 'label': 'Clear Lenses', 'hex': '#c6ecff'},
  ],
  'hat': [
    {'id': 'none', 'label': 'None', 'hex': '#334155'},
    {'id': '1-1', 'label': 'Red Cap', 'hex': '#e63f38'},
    {'id': '1-4', 'label': 'Ocean Cap', 'hex': '#3682a7'},
    {'id': '2-1', 'label': 'Gold Beanie', 'hex': '#f8d239'},
    {'id': '4-1', 'label': 'Crimson Beret', 'hex': '#e63f38'},
    {'id': '4-2', 'label': 'Azure Beret', 'hex': '#4995e3'},
    {'id': '5-1', 'label': 'Lime Visor', 'hex': '#9bc246'},
    {'id': '6-1', 'label': 'Scholar Fedora', 'hex': '#6c6e85'},
    {'id': '8-1', 'label': 'Ranger Hat', 'hex': '#c37759'},
    {'id': '9-1', 'label': 'Sun Hat', 'hex': '#c6a755'},
    {'id': '10-1', 'label': 'Silver Crown', 'hex': '#b9c3d5'},
    {'id': '11-1', 'label': 'Winter Knit', 'hex': '#676e8d'},
    {'id': '18-1', 'label': 'Bunny Ears', 'hex': '#ebe4f2'},
    {'id': '19-1', 'label': 'Headband', 'hex': '#e63f38'},
  ],
  'gloves': [
    {'id': 'none', 'label': 'None', 'hex': '#334155'},
    {'id': '14-1', 'label': 'White Gloves', 'hex': '#f4eae2'},
    {'id': '14-2', 'label': 'Mint Gloves', 'hex': '#c8e9d9'},
    {'id': '14-3', 'label': 'Lilac Gloves', 'hex': '#c8a7d9'},
    {'id': '14-4', 'label': 'Leather Mitts', 'hex': '#b7723c'},
  ],
  'bag': [
    {'id': 'none', 'label': 'None', 'hex': '#334155'},
    {'id': '3-1', 'label': 'Leather Pack', 'hex': '#8a6d58'},
    {'id': '3-2', 'label': 'Sand Pack', 'hex': '#bda766'},
    {'id': '3-3', 'label': 'Emerald Pack', 'hex': '#74b453'},
    {'id': '3-4', 'label': 'Teal Pack', 'hex': '#3cb074'},
    {'id': '3-5', 'label': 'Crimson Pack', 'hex': '#e63f38'},
    {'id': '3-6', 'label': 'Cobalt Pack', 'hex': '#4995e3'},
    {'id': '3-7', 'label': 'Rose Pack', 'hex': '#e88dad'},
    {'id': '3-8', 'label': 'Slate Pack', 'hex': '#9da3b7'},
    {'id': '3-9', 'label': 'Violet Pack', 'hex': '#8555c5'},
    {'id': '3-10', 'label': 'Sky Pack', 'hex': '#50a7e8'},
  ],
};

/// Represents a Student or Teacher's chosen pixel avatar look (Preset OR Custom Layered).
class LobbyAvatarLook {
  final bool isPreset;
  final String presetName;
  final String body;
  final String eyes;
  final String outfit;
  final String hair;
  final String face;
  final String glasses;
  final String hat;
  final String gloves;
  final String bag;

  const LobbyAvatarLook({
    this.isPreset = true,
    this.presetName = 'Adam',
    this.body = '2',
    this.eyes = '1',
    this.outfit = '1-2',
    this.hair = '17-4',
    this.face = 'none',
    this.glasses = 'none',
    this.hat = 'none',
    this.gloves = 'none',
    this.bag = '3-6',
  });

  LobbyAvatarLook copyWith({
    bool? isPreset,
    String? presetName,
    String? body,
    String? eyes,
    String? outfit,
    String? hair,
    String? face,
    String? glasses,
    String? hat,
    String? gloves,
    String? bag,
  }) {
    return LobbyAvatarLook(
      isPreset: isPreset ?? this.isPreset,
      presetName: presetName ?? this.presetName,
      body: body ?? this.body,
      eyes: eyes ?? this.eyes,
      outfit: outfit ?? this.outfit,
      hair: hair ?? this.hair,
      face: face ?? this.face,
      glasses: glasses ?? this.glasses,
      hat: hat ?? this.hat,
      gloves: gloves ?? this.gloves,
      bag: bag ?? this.bag,
    );
  }

  /// Serializes to TinyFloor look string format (`preset:Adam` or `body.2/eyes.1/...`).
  String toLookString() {
    if (isPreset) {
      return 'preset:$presetName';
    }
    final segments = <String>[
      'body.$body',
      'eyes.$eyes',
      'outfit.$outfit',
      if (hair != 'none' && hair.isNotEmpty) 'hair.$hair',
      if (face != 'none' && face.isNotEmpty) 'face.$face',
      if (glasses != 'none' && glasses.isNotEmpty) 'glasses.$glasses',
      if (hat != 'none' && hat.isNotEmpty) 'hat.$hat',
      if (gloves != 'none' && gloves.isNotEmpty) 'gloves.$gloves',
      if (bag != 'none' && bag.isNotEmpty) 'bag.$bag',
    ];
    return segments.join('/');
  }

  /// Parses a TinyFloor look string back into [LobbyAvatarLook].
  factory LobbyAvatarLook.fromLookString(String raw, {bool isFaculty = false}) {
    final trimmed = raw.trim();
    if (trimmed.isEmpty) {
      return LobbyAvatarLook(
        isPreset: true,
        presetName: isFaculty ? 'Edward' : 'Adam',
      );
    }
    if (trimmed.startsWith('preset:')) {
      final name = trimmed.substring('preset:'.length).trim();
      return LobbyAvatarLook(
        isPreset: true,
        presetName: kBundledPresets.contains(name) ? name : 'Adam',
      );
    }
    if (kBundledPresets.contains(trimmed)) {
      return LobbyAvatarLook(isPreset: true, presetName: trimmed);
    }

    var body = '2';
    var eyes = '1';
    var outfit = '1-2';
    var hair = '17-4';
    var face = 'none';
    var glasses = 'none';
    var hat = 'none';
    var gloves = 'none';
    var bag = 'none';

    for (final token in trimmed.split('/')) {
      final dot = token.indexOf('.');
      if (dot <= 0) continue;
      final group = token.substring(0, dot);
      final val = token.substring(dot + 1);
      switch (group) {
        case 'body':
          body = val;
          break;
        case 'eyes':
          eyes = val;
          break;
        case 'outfit':
          outfit = val;
          break;
        case 'hair':
          hair = val;
          break;
        case 'face':
          face = val;
          break;
        case 'glasses':
          glasses = val;
          break;
        case 'hat':
          hat = val;
          break;
        case 'gloves':
          gloves = val;
          break;
        case 'bag':
          bag = val;
          break;
      }
    }

    return LobbyAvatarLook(
      isPreset: false,
      presetName: 'Adam',
      body: body,
      eyes: eyes,
      outfit: outfit,
      hair: hair,
      face: face,
      glasses: glasses,
      hat: hat,
      gloves: gloves,
      bag: bag,
    );
  }

  /// Ordered asset paths to composite for this avatar look (`characterLayers` from `character.ts`).
  List<String> get assetLayerPaths {
    if (isPreset) {
      return ['assets/school_lobby/characters/presets/$presetName.png'];
    }
    return [
      'assets/school_lobby/characters/parts/body/$body.png',
      'assets/school_lobby/characters/parts/eyes/$eyes.png',
      'assets/school_lobby/characters/parts/outfit/$outfit.png',
      if (hair != 'none' && hair.isNotEmpty)
        'assets/school_lobby/characters/parts/hair/$hair.png',
      if (face != 'none' && face.isNotEmpty)
        'assets/school_lobby/characters/parts/face/$face.png',
      if (glasses != 'none' && glasses.isNotEmpty)
        'assets/school_lobby/characters/parts/glasses/$glasses.png',
      if (hat != 'none' && hat.isNotEmpty)
        'assets/school_lobby/characters/parts/hat/$hat.png',
      if (gloves != 'none' && gloves.isNotEmpty)
        'assets/school_lobby/characters/parts/gloves/$gloves.png',
      if (bag != 'none' && bag.isNotEmpty)
        'assets/school_lobby/characters/parts/bag/$bag.png',
    ];
  }
}

/// Returned when a user saves their Avatar Look + Avatar Nickname.
class LobbyAvatarCustomizationResult {
  final LobbyAvatarLook look;
  final String nickname;

  const LobbyAvatarCustomizationResult({
    required this.look,
    required this.nickname,
  });
}

/// Manages loading, compositing, and caching `ui.Image` sprite strips, plus saving
/// the user's Avatar Look, Avatar Nickname, and First-Time Onboarding state.
class AvatarSpriteCache {
  static final AvatarSpriteCache instance = AvatarSpriteCache._();
  AvatarSpriteCache._();

  final Map<String, ui.Image> _rawAssetCache = {};
  final Map<String, ui.Image> _compositedLookCache = {};

  static const String _kPrefLookPrefix = 'mis_lobby_avatar_look_';
  static const String _kPrefNicknamePrefix = 'mis_lobby_nickname_';
  static const String _kPrefOnboardedPrefix = 'mis_lobby_onboarded_v2_';

  String _cleanUserId(String userId) =>
      userId.trim().isEmpty ? 'guest' : userId.trim();

  /// Checks whether this user has completed their First-Time Avatar & Nickname setup.
  Future<bool> hasCompletedOnboarding(String userId) async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool('$_kPrefOnboardedPrefix${_cleanUserId(userId)}') ??
        false;
  }

  /// Marks First-Time Avatar & Nickname onboarding as completed for [userId].
  Future<void> markOnboardingCompleted(String userId) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('$_kPrefOnboardedPrefix${_cleanUserId(userId)}', true);
  }

  /// Loads the user's saved Avatar Nickname (defaults to a friendly short version of [fallbackName]).
  Future<String> loadSavedNickname(String userId,
      {required String fallbackName}) async {
    final prefs = await SharedPreferences.getInstance();
    final saved = prefs.getString('$_kPrefNicknamePrefix${_cleanUserId(userId)}');
    if (saved != null && saved.trim().isNotEmpty) {
      return saved.trim();
    }
    final cleanFallback = fallbackName.trim();
    if (cleanFallback.isEmpty) return 'Learner';
    final firstWord = cleanFallback.split(RegExp(r'\s+')).first;
    return firstWord.replaceAll(',', '');
  }

  /// Saves the user's chosen Avatar Nickname.
  Future<void> saveNickname(String userId, String nickname) async {
    final prefs = await SharedPreferences.getInstance();
    final trimmed = nickname.trim();
    if (trimmed.isNotEmpty) {
      await prefs.setString(
          '$_kPrefNicknamePrefix${_cleanUserId(userId)}', trimmed);
    }
  }

  Future<LobbyAvatarLook> loadSavedLook(String userId,
      {required bool isFaculty}) async {
    final prefs = await SharedPreferences.getInstance();
    final key = '$_kPrefLookPrefix${_cleanUserId(userId)}';
    final saved = prefs.getString(key);
    if (saved == null || saved.isEmpty) {
      return LobbyAvatarLook(
        isPreset: true,
        presetName: isFaculty ? 'Edward' : 'Adam',
      );
    }
    return LobbyAvatarLook.fromLookString(saved, isFaculty: isFaculty);
  }

  Future<void> saveLook(String userId, LobbyAvatarLook look) async {
    final prefs = await SharedPreferences.getInstance();
    final key = '$_kPrefLookPrefix${_cleanUserId(userId)}';
    await prefs.setString(key, look.toLookString());
  }

  Future<ui.Image> loadRawAssetImage(String assetPath) async {
    final cached = _rawAssetCache[assetPath];
    if (cached != null) return cached;

    final data = await rootBundle.load(assetPath);
    final codec = await ui.instantiateImageCodec(data.buffer.asUint8List());
    final frame = await codec.getNextFrame();
    _rawAssetCache[assetPath] = frame.image;
    return frame.image;
  }

  /// Resolves (and composites if multi-layered) the 48-frame `1536x64` sprite strip for [look].
  Future<ui.Image> resolveLookSpriteSheet(LobbyAvatarLook look) async {
    final key = look.toLookString();
    final existing = _compositedLookCache[key];
    if (existing != null) return existing;

    final paths = look.assetLayerPaths;
    if (paths.length == 1) {
      final single = await loadRawAssetImage(paths.first);
      _compositedLookCache[key] = single;
      return single;
    }

    final layers = <ui.Image>[];
    for (final p in paths) {
      try {
        final img = await loadRawAssetImage(p);
        layers.add(img);
      } catch (_) {
        // Ignore missing optional layer
      }
    }

    if (layers.isEmpty) {
      return loadRawAssetImage(
          'assets/school_lobby/characters/presets/Adam.png');
    }

    final width = layers.first.width;
    final height = layers.first.height;
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);
    final paint = Paint()..filterQuality = FilterQuality.none;

    for (final layer in layers) {
      canvas.drawImage(layer, Offset.zero, paint);
    }

    final picture = recorder.endRecording();
    final composited = await picture.toImage(width, height);
    _compositedLookCache[key] = composited;
    return composited;
  }
}

/// Renders an animated `32x64` pixel character preview widget inside modals/HUD.
class PixelAvatarPreview extends StatefulWidget {
  final LobbyAvatarLook look;
  final AvatarFacing facing;
  final bool animateWalk;
  final double scale;

  const PixelAvatarPreview({
    super.key,
    required this.look,
    this.facing = AvatarFacing.down,
    this.animateWalk = false,
    this.scale = 2.6,
  });

  @override
  State<PixelAvatarPreview> createState() => _PixelAvatarPreviewState();
}

class _PixelAvatarPreviewState extends State<PixelAvatarPreview> {
  ui.Image? _sheet;
  int _stepFrame = 0;
  Timer? _animTimer;

  @override
  void initState() {
    super.initState();
    _loadSheet();
    _animTimer = Timer.periodic(const Duration(milliseconds: 110), (_) {
      if (mounted) {
        setState(() {
          _stepFrame = (_stepFrame + 1) % kCharFramesPerDirection;
        });
      }
    });
  }

  @override
  void didUpdateWidget(covariant PixelAvatarPreview oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.look.toLookString() != widget.look.toLookString()) {
      _loadSheet();
    }
  }

  Future<void> _loadSheet() async {
    try {
      final sheet =
          await AvatarSpriteCache.instance.resolveLookSpriteSheet(widget.look);
      if (mounted) {
        setState(() => _sheet = sheet);
      }
    } catch (_) {}
  }

  @override
  void dispose() {
    _animTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: kCharFrameWidth * widget.scale,
      height: kCharFrameHeight * widget.scale,
      child: _sheet == null
          ? const Center(
              child: SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            )
          : CustomPaint(
              painter: _SingleFrameAvatarPainter(
                sheet: _sheet!,
                frameIndex: computeCharacterFrameIndex(
                  facing: widget.facing,
                  isWalking: widget.animateWalk,
                  stepFrame: _stepFrame,
                ),
              ),
            ),
    );
  }
}

class _SingleFrameAvatarPainter extends CustomPainter {
  final ui.Image sheet;
  final int frameIndex;

  const _SingleFrameAvatarPainter({
    required this.sheet,
    required this.frameIndex,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final src = Rect.fromLTWH(
      frameIndex * kCharFrameWidth,
      0,
      kCharFrameWidth,
      kCharFrameHeight,
    );
    final dst = Rect.fromLTWH(0, 0, size.width, size.height);
    final paint = Paint()..filterQuality = FilterQuality.none;
    canvas.drawImageRect(sheet, src, dst, paint);
  }

  @override
  bool shouldRepaint(covariant _SingleFrameAvatarPainter oldDelegate) {
    return oldDelegate.sheet != sheet || oldDelegate.frameIndex != frameIndex;
  }
}

/// Opens the mobile-friendly TinyFloor Character + Nickname Customizer Modal.
/// Supports both **First-Time Entry Onboarding** (`isFirstTimeOnboarding: true`)
/// and anytime wardrobe editing, adapting cleanly to Portrait & Landscape screens.
Future<LobbyAvatarCustomizationResult?> showLobbyAvatarCustomizerModal({
  required BuildContext context,
  required LobbyAvatarLook initialLook,
  required String initialNickname,
  required bool isFaculty,
  String? equippedBadgeIcon,
  bool isFirstTimeOnboarding = false,
}) {
  return showModalBottomSheet<LobbyAvatarCustomizationResult>(
    context: context,
    isScrollControlled: true,
    isDismissible: !isFirstTimeOnboarding,
    enableDrag: !isFirstTimeOnboarding,
    backgroundColor: Colors.transparent,
    builder: (ctx) => _LobbyAvatarCustomizerSheet(
      initialLook: initialLook,
      initialNickname: initialNickname,
      isFaculty: isFaculty,
      equippedBadgeIcon: equippedBadgeIcon,
      isFirstTimeOnboarding: isFirstTimeOnboarding,
    ),
  );
}

class _LobbyAvatarCustomizerSheet extends StatefulWidget {
  final LobbyAvatarLook initialLook;
  final String initialNickname;
  final bool isFaculty;
  final String? equippedBadgeIcon;
  final bool isFirstTimeOnboarding;

  const _LobbyAvatarCustomizerSheet({
    required this.initialLook,
    required this.initialNickname,
    required this.isFaculty,
    this.equippedBadgeIcon,
    required this.isFirstTimeOnboarding,
  });

  @override
  State<_LobbyAvatarCustomizerSheet> createState() =>
      _LobbyAvatarCustomizerSheetState();
}

class _LobbyAvatarCustomizerSheetState
    extends State<_LobbyAvatarCustomizerSheet> {
  late LobbyAvatarLook _look;
  late final TextEditingController _nicknameCtrl;
  AvatarFacing _previewFacing = AvatarFacing.down;
  bool _previewWalking = true;
  String _selectedPartCategory = 'outfit';

  @override
  void initState() {
    super.initState();
    _look = LobbyShopService.instance.sanitizeLookForUnlocked(
      widget.initialLook,
      isFaculty: widget.isFaculty,
    );
    _nicknameCtrl = TextEditingController(text: widget.initialNickname);
  }

  @override
  void dispose() {
    _nicknameCtrl.dispose();
    super.dispose();
  }

  void _rotateFacing() {
    setState(() {
      switch (_previewFacing) {
        case AvatarFacing.down:
          _previewFacing = AvatarFacing.right;
          break;
        case AvatarFacing.right:
          _previewFacing = AvatarFacing.up;
          break;
        case AvatarFacing.up:
          _previewFacing = AvatarFacing.left;
          break;
        case AvatarFacing.left:
          _previewFacing = AvatarFacing.down;
          break;
      }
    });
  }

  Color _parseHex(String hex) {
    final cleaned = hex.replaceAll('#', '');
    final val = int.tryParse('FF$cleaned', radix: 16) ?? 0xFF38BDF8;
    return Color(val);
  }

  String _currentPartValue(String category) {
    switch (category) {
      case 'body':
        return _look.body;
      case 'eyes':
        return _look.eyes;
      case 'outfit':
        return _look.outfit;
      case 'hair':
        return _look.hair;
      case 'face':
        return _look.face;
      case 'glasses':
        return _look.glasses;
      case 'hat':
        return _look.hat;
      case 'gloves':
        return _look.gloves;
      case 'bag':
        return _look.bag;
      default:
        return '';
    }
  }

  void _selectPartValue(String category, String id) {
    final unlocked = LobbyShopService.instance.isCosmeticUnlocked(
      category,
      id,
      isFaculty: widget.isFaculty,
    );
    if (!unlocked) {
      final cost = LobbyShopService.instance.costForCosmetic(category, id);
      HapticFeedback.vibrate();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            '🔒 Locked Cosmetic ($cost XP)! Earn XP from Quests, Reviewers & Mini Chests and unlock it in the 🛍️ Campus Cosmetics Shop!',
          ),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }
    setState(() {
      _look = _look.copyWith(
        isPreset: false,
        body: category == 'body' ? id : _look.body,
        eyes: category == 'eyes' ? id : _look.eyes,
        outfit: category == 'outfit' ? id : _look.outfit,
        hair: category == 'hair' ? id : _look.hair,
        face: category == 'face' ? id : _look.face,
        glasses: category == 'glasses' ? id : _look.glasses,
        hat: category == 'hat' ? id : _look.hat,
        gloves: category == 'gloves' ? id : _look.gloves,
        bag: category == 'bag' ? id : _look.bag,
      );
    });
  }

  void _saveAndClose() {
    final cleanNick = _nicknameCtrl.text.trim().isEmpty
        ? widget.initialNickname
        : _nicknameCtrl.text.trim();
    Navigator.of(context).pop(
      LobbyAvatarCustomizationResult(
        look: _look,
        nickname: cleanNick,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final media = MediaQuery.of(context);
    final isLandscape = media.size.width > media.size.height;

    return PopScope(
      canPop: !widget.isFirstTimeOnboarding,
      child: Padding(
        padding: EdgeInsets.only(bottom: media.viewInsets.bottom),
        child: Container(
          height: media.size.height * (isLandscape ? 0.94 : 0.88),
          decoration: BoxDecoration(
            color: const Color(0xFF0F172A),
            borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
            border: Border.all(
              color: widget.isFirstTimeOnboarding
                  ? const Color(0xFFFACC15).withOpacity(0.6)
                  : Colors.white.withOpacity(0.16),
              width: 1.6,
            ),
          ),
          child: Column(
            children: [
              const SizedBox(height: 8),
              Container(
                width: 44,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.white24,
                  borderRadius: BorderRadius.circular(99),
                ),
              ),
              // Header
              Padding(
                padding: const EdgeInsets.fromLTRB(18, 10, 14, 6),
                child: Row(
                  children: [
                    Icon(
                      widget.isFirstTimeOnboarding
                          ? Icons.auto_awesome_rounded
                          : Icons.face_retouching_natural_rounded,
                      color: widget.isFirstTimeOnboarding
                          ? const Color(0xFFFACC15)
                          : const Color(0xFF38BDF8),
                      size: 24,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            widget.isFirstTimeOnboarding
                                ? 'WELCOME! CREATE YOUR AVATAR & NICKNAME'
                                : 'PIXEL AVATAR & NICKNAME WARDROBE',
                            style: GoogleFonts.outfit(
                              color: Colors.white,
                              fontSize: isLandscape ? 15.5 : 16.5,
                              fontWeight: FontWeight.w800,
                              letterSpacing: 0.5,
                            ),
                          ),
                          Text(
                            widget.isFirstTimeOnboarding
                                ? 'Choose your nickname and character look before entering the School Lobby!'
                                : 'Update your floating nameplate nickname or customize your pixel look',
                            style: GoogleFonts.inter(
                              color: Colors.white60,
                              fontSize: 11.5,
                            ),
                          ),
                        ],
                      ),
                    ),
                    if (!widget.isFirstTimeOnboarding)
                      IconButton(
                        onPressed: () => Navigator.of(context).pop(),
                        icon: const Icon(Icons.close_rounded,
                            color: Colors.white70),
                      ),
                  ],
                ),
              ),

              // Body: Adapts between Landscape (2-column split) and Portrait (vertical stack)
              Expanded(
                child: isLandscape
                    ? Row(
                        children: [
                          SizedBox(
                            width: media.size.width * 0.38,
                            child: SingleChildScrollView(
                              padding:
                                  const EdgeInsets.symmetric(horizontal: 14),
                              child: Column(
                                children: [
                                  _buildPreviewAndNicknameCard(compact: true),
                                  const SizedBox(height: 10),
                                  _buildSaveButton(),
                                ],
                              ),
                            ),
                          ),
                          Expanded(
                            child: Column(
                              children: [
                                _buildModeSwitcherRow(),
                                Expanded(
                                  child: _look.isPreset
                                      ? _buildPresetGrid(crossAxisCount: 4)
                                      : _buildCustomPartsEditor(),
                                ),
                              ],
                            ),
                          ),
                        ],
                      )
                    : Column(
                        children: [
                          Padding(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 16, vertical: 4),
                            child:
                                _buildPreviewAndNicknameCard(compact: false),
                          ),
                          _buildModeSwitcherRow(),
                          Expanded(
                            child: _look.isPreset
                                ? _buildPresetGrid(crossAxisCount: 4)
                                : _buildCustomPartsEditor(),
                          ),
                          SafeArea(
                            top: false,
                            child: Padding(
                              padding:
                                  const EdgeInsets.fromLTRB(16, 6, 16, 12),
                              child: _buildSaveButton(),
                            ),
                          ),
                        ],
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPreviewAndNicknameCard({required bool compact}) {
    final displayNick = _nicknameCtrl.text.trim().isEmpty
        ? widget.initialNickname
        : _nicknameCtrl.text.trim();

    return Container(
      padding: EdgeInsets.all(compact ? 10 : 12),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF1E293B), Color(0xFF0F172A)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFF38BDF8).withOpacity(0.32)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              // Avatar + Floating Nameplate Preview
              Expanded(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.black.withOpacity(0.78),
                        borderRadius: BorderRadius.circular(99),
                        border: Border.all(
                          color: widget.isFaculty
                              ? const Color(0xFFFACC15)
                              : const Color(0xFF38BDF8),
                          width: 1.2,
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (widget.equippedBadgeIcon != null &&
                              widget.equippedBadgeIcon!.isNotEmpty) ...[
                            Text(
                              widget.equippedBadgeIcon!,
                              style: const TextStyle(fontSize: 12),
                            ),
                            const SizedBox(width: 4),
                          ],
                          Flexible(
                            child: Text(
                              displayNick,
                              overflow: TextOverflow.ellipsis,
                              style: GoogleFonts.inter(
                                color: Colors.white,
                                fontSize: 11,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ),
                          const SizedBox(width: 5),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 5, vertical: 1),
                            decoration: BoxDecoration(
                              color: widget.isFaculty
                                  ? const Color(0xFFFACC15)
                                  : const Color(0xFF10B981),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              widget.isFaculty ? 'Teacher' : 'Student',
                              style: GoogleFonts.inter(
                                color: widget.isFaculty
                                    ? Colors.black
                                    : Colors.white,
                                fontSize: 9,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 4),
                    PixelAvatarPreview(
                      look: _look,
                      facing: _previewFacing,
                      animateWalk: _previewWalking,
                      scale: compact ? 1.75 : 2.0,
                    ),
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  OutlinedButton.icon(
                    onPressed: _rotateFacing,
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.white,
                      side: const BorderSide(color: Colors.white24),
                      visualDensity: VisualDensity.compact,
                    ),
                    icon: const Icon(Icons.rotate_right_rounded, size: 15),
                    label: const Text('Rotate', style: TextStyle(fontSize: 12)),
                  ),
                  const SizedBox(height: 6),
                  OutlinedButton.icon(
                    onPressed: () =>
                        setState(() => _previewWalking = !_previewWalking),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: const Color(0xFF38BDF8),
                      side: const BorderSide(color: Color(0xFF38BDF8)),
                      visualDensity: VisualDensity.compact,
                    ),
                    icon: Icon(
                      _previewWalking
                          ? Icons.directions_walk_rounded
                          : Icons.accessibility_new_rounded,
                      size: 15,
                    ),
                    label: Text(
                      _previewWalking ? 'Walking' : 'Idle',
                      style: const TextStyle(fontSize: 12),
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 8),
          // Avatar Nickname Input Field
          TextField(
            controller: _nicknameCtrl,
            maxLength: 18,
            onChanged: (_) => setState(() {}),
            style: GoogleFonts.inter(
              color: Colors.white,
              fontSize: 13.5,
              fontWeight: FontWeight.w700,
            ),
            decoration: InputDecoration(
              counterText: '',
              prefixIcon: const Icon(Icons.badge_rounded,
                  color: Color(0xFFFACC15), size: 18),
              labelText: 'Avatar Nickname (shown above your character)',
              labelStyle:
                  const TextStyle(color: Colors.white70, fontSize: 12),
              hintText: 'Enter your lobby nickname...',
              hintStyle: const TextStyle(color: Colors.white30, fontSize: 12),
              filled: true,
              fillColor: const Color(0xFF0F172A),
              isDense: true,
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
                borderSide: const BorderSide(color: Color(0xFFFACC15)),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildModeSwitcherRow() {
    final availableXp = LobbyDataService.instance.progress.availableXp;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      child: Row(
        children: [
          Expanded(
            child: _buildModeTab(
              label: 'Starter & Presets',
              selected: _look.isPreset,
              onTap: () =>
                  setState(() => _look = _look.copyWith(isPreset: true)),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: _buildModeTab(
              label: 'Layered Wardrobe',
              selected: !_look.isPreset,
              onTap: () =>
                  setState(() => _look = _look.copyWith(isPreset: false)),
            ),
          ),
          if (!widget.isFirstTimeOnboarding) ...[
            const SizedBox(width: 8),
            ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFF59E0B),
                foregroundColor: Colors.black,
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              onPressed: () async {
                final updated = await showCampusShopModal(
                  context: context,
                  currentLook: _look,
                  isFaculty: widget.isFaculty,
                );
                if (updated != null && mounted) {
                  setState(() => _look = updated);
                }
              },
              icon: const Text('🛍️', style: TextStyle(fontSize: 13)),
              label: Text(
                'Shop ($availableXp XP)',
                style: GoogleFonts.outfit(
                  fontSize: 11.5,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildSaveButton() {
    return SizedBox(
      width: double.infinity,
      height: 48,
      child: ElevatedButton.icon(
        onPressed: _saveAndClose,
        style: ElevatedButton.styleFrom(
          backgroundColor: widget.isFirstTimeOnboarding
              ? const Color(0xFFFACC15)
              : const Color(0xFF10B981),
          foregroundColor:
              widget.isFirstTimeOnboarding ? Colors.black : Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
        ),
        icon: Icon(widget.isFirstTimeOnboarding
            ? Icons.sports_esports_rounded
            : Icons.check_circle_rounded),
        label: Text(
          widget.isFirstTimeOnboarding
              ? 'ENTER SCHOOL LOBBY!'
              : 'SAVE NICKNAME & AVATAR',
          style: GoogleFonts.outfit(
            fontWeight: FontWeight.w900,
            fontSize: 14.5,
            letterSpacing: 0.5,
          ),
        ),
      ),
    );
  }

  Widget _buildModeTab({
    required String label,
    required bool selected,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 9),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: selected
              ? const Color(0xFF38BDF8).withOpacity(0.2)
              : Colors.white.withOpacity(0.04),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: selected ? const Color(0xFF38BDF8) : Colors.white12,
            width: 1.4,
          ),
        ),
        child: Text(
          label,
          style: GoogleFonts.inter(
            color: selected ? const Color(0xFF38BDF8) : Colors.white70,
            fontWeight: FontWeight.w700,
            fontSize: 12,
          ),
        ),
      ),
    );
  }

  Widget _buildPresetGrid({required int crossAxisCount}) {
    return GridView.builder(
      padding: const EdgeInsets.fromLTRB(16, 6, 16, 12),
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: crossAxisCount,
        mainAxisSpacing: 8,
        crossAxisSpacing: 8,
        childAspectRatio: 0.78,
      ),
      itemCount: kBundledPresets.length,
      itemBuilder: (context, index) {
        final name = kBundledPresets[index];
        final isSelected = _look.isPreset && _look.presetName == name;
        final isUnlocked = LobbyShopService.instance.isPresetUnlocked(
          name,
          isFaculty: widget.isFaculty,
        );
        final cost = LobbyShopService.instance.costForCosmetic('preset', name);
        return InkWell(
          onTap: () {
            if (!isUnlocked) {
              HapticFeedback.vibrate();
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(
                    '🔒 Preset "$name" is locked ($cost XP). Unlock it in the 🛍️ Campus Cosmetics Shop using your earned XP!',
                  ),
                  behavior: SnackBarBehavior.floating,
                ),
              );
              return;
            }
            setState(() {
              _look = _look.copyWith(isPreset: true, presetName: name);
            });
          },
          borderRadius: BorderRadius.circular(14),
          child: Container(
            decoration: BoxDecoration(
              color: isSelected
                  ? const Color(0xFF38BDF8).withValues(alpha: 0.18)
                  : Colors.white.withValues(alpha: 0.04),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: isSelected
                    ? const Color(0xFF38BDF8)
                    : (isUnlocked
                        ? Colors.white24
                        : Colors.amber.withValues(alpha: 0.3)),
                width: isSelected ? 2 : 1,
              ),
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Opacity(
                  opacity: isUnlocked ? 1.0 : 0.45,
                  child: PixelAvatarPreview(
                    look: LobbyAvatarLook(isPreset: true, presetName: name),
                    facing: AvatarFacing.down,
                    animateWalk: false,
                    scale: 1.05,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  isUnlocked ? name : '🔒 $name ($cost XP)',
                  textAlign: TextAlign.center,
                  style: GoogleFonts.inter(
                    color: isSelected
                        ? const Color(0xFF38BDF8)
                        : (isUnlocked ? Colors.white : const Color(0xFFFDE047)),
                    fontSize: isUnlocked ? 11 : 9.5,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildCustomPartsEditor() {
    final categories = [
      {'key': 'body', 'label': 'Skin'},
      {'key': 'eyes', 'label': 'Eyes'},
      {'key': 'outfit', 'label': 'Outfit'},
      {'key': 'hair', 'label': 'Hair'},
      {'key': 'face', 'label': 'Facial'},
      {'key': 'glasses', 'label': 'Glasses'},
      {'key': 'hat', 'label': 'Hat'},
      {'key': 'gloves', 'label': 'Gloves'},
      {'key': 'bag', 'label': 'Bag'},
    ];
    final options = kBundledCustomParts[_selectedPartCategory] ?? const [];
    final currentVal = _currentPartValue(_selectedPartCategory);

    return Column(
      children: [
        SizedBox(
          height: 38,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            itemCount: categories.length,
            separatorBuilder: (_, __) => const SizedBox(width: 8),
            itemBuilder: (context, i) {
              final cat = categories[i];
              final isCat = _selectedPartCategory == cat['key'];
              return ChoiceChip(
                label: Text(cat['label']!),
                selected: isCat,
                onSelected: (_) =>
                    setState(() => _selectedPartCategory = cat['key']!),
                selectedColor: const Color(0xFF38BDF8),
                backgroundColor: const Color(0xFF1E293B),
                labelStyle: GoogleFonts.inter(
                  color: isCat ? Colors.black : Colors.white70,
                  fontWeight: FontWeight.w700,
                  fontSize: 11.5,
                ),
              );
            },
          ),
        ),
        const SizedBox(height: 6),
        Expanded(
          child: GridView.builder(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 3,
              mainAxisSpacing: 8,
              crossAxisSpacing: 8,
              childAspectRatio: 2.35,
            ),
            itemCount: options.length,
            itemBuilder: (context, index) {
              final opt = options[index];
              final id = opt['id']!;
              final label = opt['label']!;
              final hex = opt['hex'] ?? '#38BDF8';
              final selected = currentVal == id;
              final unlocked = LobbyShopService.instance.isCosmeticUnlocked(
                _selectedPartCategory,
                id,
                isFaculty: widget.isFaculty,
              );
              final cost = LobbyShopService.instance
                  .costForCosmetic(_selectedPartCategory, id);
              return InkWell(
                onTap: () => _selectPartValue(_selectedPartCategory, id),
                borderRadius: BorderRadius.circular(12),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10),
                  decoration: BoxDecoration(
                    color: selected
                        ? const Color(0xFF38BDF8).withValues(alpha: 0.2)
                        : Colors.white.withValues(alpha: 0.05),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: selected
                          ? const Color(0xFF38BDF8)
                          : (unlocked
                              ? Colors.white24
                              : Colors.amber.withValues(alpha: 0.3)),
                      width: selected ? 1.8 : 1,
                    ),
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 13,
                        height: 13,
                        decoration: BoxDecoration(
                          color: _parseHex(hex),
                          shape: BoxShape.circle,
                          border: Border.all(color: Colors.white38, width: 1),
                        ),
                      ),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          unlocked ? label : '🔒 $label ($cost XP)',
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: GoogleFonts.inter(
                            color: unlocked
                                ? Colors.white
                                : const Color(0xFFFDE047),
                            fontSize: 10,
                            fontWeight:
                                selected ? FontWeight.w800 : FontWeight.w600,
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
}
