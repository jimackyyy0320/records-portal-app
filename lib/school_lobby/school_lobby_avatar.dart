import 'dart:async';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';

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

/// Bundled Custom Layer Options (`assets/school_lobby/characters/parts/<group>/<id>.png`).
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
    {'id': '6-1', 'label': 'Scholar Fedora', 'hex': '#6c6e85'},
    {'id': '9-1', 'label': 'Sun Hat', 'hex': '#c6a755'},
    {'id': '11-1', 'label': 'Winter Knit', 'hex': '#676e8d'},
  ],
  'bag': [
    {'id': 'none', 'label': 'None', 'hex': '#334155'},
    {'id': '3-1', 'label': 'Leather Pack', 'hex': '#8a6d58'},
    {'id': '3-3', 'label': 'Emerald Pack', 'hex': '#74b453'},
    {'id': '3-5', 'label': 'Crimson Pack', 'hex': '#e63f38'},
    {'id': '3-6', 'label': 'Cobalt Pack', 'hex': '#4995e3'},
    {'id': '3-7', 'label': 'Rose Pack', 'hex': '#e88dad'},
    {'id': '3-9', 'label': 'Violet Pack', 'hex': '#8555c5'},
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
  final String glasses;
  final String hat;
  final String bag;

  const LobbyAvatarLook({
    this.isPreset = true,
    this.presetName = 'Adam',
    this.body = '2',
    this.eyes = '1',
    this.outfit = '1-2',
    this.hair = '17-4',
    this.glasses = 'none',
    this.hat = 'none',
    this.bag = '3-6',
  });

  LobbyAvatarLook copyWith({
    bool? isPreset,
    String? presetName,
    String? body,
    String? eyes,
    String? outfit,
    String? hair,
    String? glasses,
    String? hat,
    String? bag,
  }) {
    return LobbyAvatarLook(
      isPreset: isPreset ?? this.isPreset,
      presetName: presetName ?? this.presetName,
      body: body ?? this.body,
      eyes: eyes ?? this.eyes,
      outfit: outfit ?? this.outfit,
      hair: hair ?? this.hair,
      glasses: glasses ?? this.glasses,
      hat: hat ?? this.hat,
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
      if (glasses != 'none' && glasses.isNotEmpty) 'glasses.$glasses',
      if (hat != 'none' && hat.isNotEmpty) 'hat.$hat',
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
    var glasses = 'none';
    var hat = 'none';
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
        case 'glasses':
          glasses = val;
          break;
        case 'hat':
          hat = val;
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
      glasses: glasses,
      hat: hat,
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
      if (glasses != 'none' && glasses.isNotEmpty)
        'assets/school_lobby/characters/parts/glasses/$glasses.png',
      if (hat != 'none' && hat.isNotEmpty)
        'assets/school_lobby/characters/parts/hat/$hat.png',
      if (bag != 'none' && bag.isNotEmpty)
        'assets/school_lobby/characters/parts/bag/$bag.png',
    ];
  }
}

/// Manages loading, compositing, and caching `ui.Image` sprite strips for presets & custom looks.
class AvatarSpriteCache {
  static final AvatarSpriteCache instance = AvatarSpriteCache._();
  AvatarSpriteCache._();

  final Map<String, ui.Image> _rawAssetCache = {};
  final Map<String, ui.Image> _compositedLookCache = {};

  static const String _kPrefPrefix = 'mis_lobby_avatar_look_';

  Future<LobbyAvatarLook> loadSavedLook(String userId,
      {required bool isFaculty}) async {
    final prefs = await SharedPreferences.getInstance();
    final key = '$_kPrefPrefix${userId.trim().isEmpty ? "guest" : userId.trim()}';
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
    final key = '$_kPrefPrefix${userId.trim().isEmpty ? "guest" : userId.trim()}';
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

/// Opens the mobile-friendly TinyFloor Character Customizer Modal.
Future<LobbyAvatarLook?> showLobbyAvatarCustomizerModal({
  required BuildContext context,
  required LobbyAvatarLook initialLook,
  required String userName,
  required bool isFaculty,
  String? equippedBadgeIcon,
}) {
  return showModalBottomSheet<LobbyAvatarLook>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (ctx) => _LobbyAvatarCustomizerSheet(
      initialLook: initialLook,
      userName: userName,
      isFaculty: isFaculty,
      equippedBadgeIcon: equippedBadgeIcon,
    ),
  );
}

class _LobbyAvatarCustomizerSheet extends StatefulWidget {
  final LobbyAvatarLook initialLook;
  final String userName;
  final bool isFaculty;
  final String? equippedBadgeIcon;

  const _LobbyAvatarCustomizerSheet({
    required this.initialLook,
    required this.userName,
    required this.isFaculty,
    this.equippedBadgeIcon,
  });

  @override
  State<_LobbyAvatarCustomizerSheet> createState() =>
      _LobbyAvatarCustomizerSheetState();
}

class _LobbyAvatarCustomizerSheetState
    extends State<_LobbyAvatarCustomizerSheet> {
  late LobbyAvatarLook _look;
  AvatarFacing _previewFacing = AvatarFacing.down;
  bool _previewWalking = true;
  String _selectedPartCategory = 'outfit';

  @override
  void initState() {
    super.initState();
    _look = widget.initialLook;
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
      case 'glasses':
        return _look.glasses;
      case 'hat':
        return _look.hat;
      case 'bag':
        return _look.bag;
      default:
        return '';
    }
  }

  void _selectPartValue(String category, String id) {
    setState(() {
      _look = _look.copyWith(
        isPreset: false,
        body: category == 'body' ? id : _look.body,
        eyes: category == 'eyes' ? id : _look.eyes,
        outfit: category == 'outfit' ? id : _look.outfit,
        hair: category == 'hair' ? id : _look.hair,
        glasses: category == 'glasses' ? id : _look.glasses,
        hat: category == 'hat' ? id : _look.hat,
        bag: category == 'bag' ? id : _look.bag,
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    final media = MediaQuery.of(context);
    return Container(
      height: media.size.height * 0.84,
      decoration: BoxDecoration(
        color: const Color(0xFF0F172A),
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
        border: Border.all(color: Colors.white.withOpacity(0.14)),
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
          // Header
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 14, 16, 8),
            child: Row(
              children: [
                const Icon(Icons.face_retouching_natural_rounded,
                    color: Color(0xFF38BDF8), size: 24),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'PIXEL AVATAR WARDROBE',
                        style: GoogleFonts.outfit(
                          color: Colors.white,
                          fontSize: 17,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 0.6,
                        ),
                      ),
                      Text(
                        'Pick a character preset or customize your layered look',
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
                  icon: const Icon(Icons.close_rounded, color: Colors.white70),
                ),
              ],
            ),
          ),

          // Live Stage Preview with Floating Nameplate
          Container(
            margin: const EdgeInsets.symmetric(horizontal: 18, vertical: 6),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF1E293B), Color(0xFF0F172A)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: const Color(0xFF38BDF8).withOpacity(0.3)),
            ),
            child: Row(
              children: [
                // Avatar + Floating Nameplate Preview
                Expanded(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Floating Nameplate Preview
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: Colors.black.withOpacity(0.75),
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
                                widget.userName,
                                overflow: TextOverflow.ellipsis,
                                style: GoogleFonts.inter(
                                  color: Colors.white,
                                  fontSize: 11,
                                  fontWeight: FontWeight.w700,
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
                      const SizedBox(height: 6),
                      PixelAvatarPreview(
                        look: _look,
                        facing: _previewFacing,
                        animateWalk: _previewWalking,
                        scale: 2.2,
                      ),
                    ],
                  ),
                ),
                // Controls for preview
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
                      icon: const Icon(Icons.rotate_right_rounded, size: 16),
                      label: const Text('Rotate'),
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
                        size: 16,
                      ),
                      label: Text(_previewWalking ? 'Walking' : 'Idle'),
                    ),
                  ],
                ),
              ],
            ),
          ),

          // Mode Switcher: Presets vs Custom Layers
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 6),
            child: Row(
              children: [
                Expanded(
                  child: _buildModeTab(
                    label: 'Preset Characters (16)',
                    selected: _look.isPreset,
                    onTap: () => setState(() => _look = _look.copyWith(isPreset: true)),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _buildModeTab(
                    label: 'Custom Layered Mix',
                    selected: !_look.isPreset,
                    onTap: () =>
                        setState(() => _look = _look.copyWith(isPreset: false)),
                  ),
                ),
              ],
            ),
          ),

          // Selector Area
          Expanded(
            child: _look.isPreset ? _buildPresetGrid() : _buildCustomPartsEditor(),
          ),

          // Save Bar
          SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(18, 8, 18, 14),
              child: SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton.icon(
                  onPressed: () => Navigator.of(context).pop(_look),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF10B981),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  icon: const Icon(Icons.check_circle_rounded),
                  label: Text(
                    'SAVE & EQUIP AVATAR',
                    style: GoogleFonts.outfit(
                      fontWeight: FontWeight.w800,
                      fontSize: 15,
                      letterSpacing: 0.5,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
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
        padding: const EdgeInsets.symmetric(vertical: 10),
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
            fontSize: 12.5,
          ),
        ),
      ),
    );
  }

  Widget _buildPresetGrid() {
    return GridView.builder(
      padding: const EdgeInsets.fromLTRB(18, 8, 18, 12),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 4,
        mainAxisSpacing: 10,
        crossAxisSpacing: 10,
        childAspectRatio: 0.78,
      ),
      itemCount: kBundledPresets.length,
      itemBuilder: (context, index) {
        final name = kBundledPresets[index];
        final isSelected = _look.isPreset && _look.presetName == name;
        return InkWell(
          onTap: () => setState(() {
            _look = _look.copyWith(isPreset: true, presetName: name);
          }),
          borderRadius: BorderRadius.circular(14),
          child: Container(
            decoration: BoxDecoration(
              color: isSelected
                  ? const Color(0xFF38BDF8).withOpacity(0.18)
                  : Colors.white.withOpacity(0.04),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: isSelected ? const Color(0xFF38BDF8) : Colors.white12,
                width: isSelected ? 2 : 1,
              ),
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                PixelAvatarPreview(
                  look: LobbyAvatarLook(isPreset: true, presetName: name),
                  facing: AvatarFacing.down,
                  animateWalk: false,
                  scale: 1.15,
                ),
                const SizedBox(height: 4),
                Text(
                  name,
                  style: GoogleFonts.inter(
                    color: isSelected ? const Color(0xFF38BDF8) : Colors.white,
                    fontSize: 11.5,
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
      {'key': 'glasses', 'label': 'Glasses'},
      {'key': 'hat', 'label': 'Hat'},
      {'key': 'bag', 'label': 'Bag'},
    ];
    final options = kBundledCustomParts[_selectedPartCategory] ?? const [];
    final currentVal = _currentPartValue(_selectedPartCategory);

    return Column(
      children: [
        SizedBox(
          height: 40,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 18),
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
                  fontSize: 12,
                ),
              );
            },
          ),
        ),
        const SizedBox(height: 8),
        Expanded(
          child: GridView.builder(
            padding: const EdgeInsets.fromLTRB(18, 4, 18, 12),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 3,
              mainAxisSpacing: 8,
              crossAxisSpacing: 8,
              childAspectRatio: 2.3,
            ),
            itemCount: options.length,
            itemBuilder: (context, index) {
              final opt = options[index];
              final id = opt['id']!;
              final label = opt['label']!;
              final hex = opt['hex'] ?? '#38BDF8';
              final selected = currentVal == id;
              return InkWell(
                onTap: () => _selectPartValue(_selectedPartCategory, id),
                borderRadius: BorderRadius.circular(12),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10),
                  decoration: BoxDecoration(
                    color: selected
                        ? const Color(0xFF38BDF8).withOpacity(0.2)
                        : Colors.white.withOpacity(0.05),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color:
                          selected ? const Color(0xFF38BDF8) : Colors.white12,
                      width: selected ? 1.8 : 1,
                    ),
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 14,
                        height: 14,
                        decoration: BoxDecoration(
                          color: _parseHex(hex),
                          shape: BoxShape.circle,
                          border: Border.all(color: Colors.white38, width: 1),
                        ),
                      ),
                      const SizedBox(width: 7),
                      Expanded(
                        child: Text(
                          label,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: GoogleFonts.inter(
                            color: Colors.white,
                            fontSize: 11,
                            fontWeight:
                                selected ? FontWeight.w800 : FontWeight.w500,
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
