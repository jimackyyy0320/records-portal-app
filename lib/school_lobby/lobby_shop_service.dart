import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';

import 'lobby_audio_service.dart';
import 'lobby_data_service.dart';
import 'school_lobby_avatar.dart';

/// Represents a student's personalized Classroom Table Space decorations
/// (Chair color/style, Desk mat, Mini light/lamp, Picture frame, and Tabletop props).
class LobbyTableDecorConfig {
  final String chairStyle; // 'tan_classic', 'crimson_gaming', 'emerald_ergo', 'royal_gold', 'sakura_pastel', 'cyber_neon'
  final String deskMat; // 'oak_default', 'mint_pad', 'galaxy_mat', 'royal_velvet', 'lofi_grid'
  final String miniLight; // 'none', 'fairy_warm', 'banker_brass', 'neon_strip', 'starlight_lantern'
  final String deskFrame; // 'none', 'gold_cert', 'pixel_portrait', 'holo_plaque'
  final String deskProp; // 'none', 'textbooks_stack', 'zen_bonsai', 'gaming_laptop', 'trophy_mug'

  const LobbyTableDecorConfig({
    this.chairStyle = 'tan_classic',
    this.deskMat = 'oak_default',
    this.miniLight = 'none',
    this.deskFrame = 'none',
    this.deskProp = 'none',
  });

  LobbyTableDecorConfig copyWith({
    String? chairStyle,
    String? deskMat,
    String? miniLight,
    String? deskFrame,
    String? deskProp,
  }) {
    return LobbyTableDecorConfig(
      chairStyle: chairStyle ?? this.chairStyle,
      deskMat: deskMat ?? this.deskMat,
      miniLight: miniLight ?? this.miniLight,
      deskFrame: deskFrame ?? this.deskFrame,
      deskProp: deskProp ?? this.deskProp,
    );
  }

  Map<String, dynamic> toJson() => <String, dynamic>{
        'chairStyle': chairStyle,
        'deskMat': deskMat,
        'miniLight': miniLight,
        'deskFrame': deskFrame,
        'deskProp': deskProp,
      };

  factory LobbyTableDecorConfig.fromJson(Map<String, dynamic>? json) {
    if (json == null) return const LobbyTableDecorConfig();
    return LobbyTableDecorConfig(
      chairStyle: json['chairStyle']?.toString() ?? 'tan_classic',
      deskMat: json['deskMat']?.toString() ?? 'oak_default',
      miniLight: json['miniLight']?.toString() ?? 'none',
      deskFrame: json['deskFrame']?.toString() ?? 'none',
      deskProp: json['deskProp']?.toString() ?? 'none',
    );
  }

  String encodeCompact() =>
      '$chairStyle|$deskMat|$miniLight|$deskFrame|$deskProp';

  factory LobbyTableDecorConfig.decodeCompact(String? raw) {
    if (raw == null || raw.trim().isEmpty) {
      return const LobbyTableDecorConfig();
    }
    final parts = raw.split('|');
    if (parts.length < 5) return const LobbyTableDecorConfig();
    return LobbyTableDecorConfig(
      chairStyle: parts[0].isEmpty ? 'tan_classic' : parts[0],
      deskMat: parts[1].isEmpty ? 'oak_default' : parts[1],
      miniLight: parts[2].isEmpty ? 'none' : parts[2],
      deskFrame: parts[3].isEmpty ? 'none' : parts[3],
      deskProp: parts[4].isEmpty ? 'none' : parts[4],
    );
  }

  /// Primary chair color for rendering on the 2D Classroom canvas.
  Color get chairPrimaryColor {
    switch (chairStyle) {
      case 'crimson_gaming':
        return const Color(0xFFEF4444);
      case 'emerald_ergo':
        return const Color(0xFF10B981);
      case 'royal_gold':
        return const Color(0xFFF59E0B);
      case 'sakura_pastel':
        return const Color(0xFFF472B6);
      case 'cyber_neon':
        return const Color(0xFF06B6D4);
      default:
        return const Color(0xFFD9A066);
    }
  }

  /// Desk mat surface color for rendering on the student's Classroom desk.
  Color? get deskMatColor {
    switch (deskMat) {
      case 'mint_pad':
        return const Color(0xFF34D399);
      case 'galaxy_mat':
        return const Color(0xFF6366F1);
      case 'royal_velvet':
        return const Color(0xFFEC4899);
      case 'lofi_grid':
        return const Color(0xFF38BDF8);
      default:
        return null;
    }
  }
}

/// Represents a purchasable or starter cosmetic / table decor item in the MIS-SHS Campus Shop.
class ShopCosmeticItem {
  final String itemKey; // e.g. 'outfit:4-1', 'table_light:fairy_warm'
  final String category;
  final String partId;
  final String label;
  final String hexColor;
  final int xpCost;
  final bool isStarter;

  const ShopCosmeticItem({
    required this.itemKey,
    required this.category,
    required this.partId,
    required this.label,
    required this.hexColor,
    required this.xpCost,
    required this.isStarter,
  });

  bool get isTableDecor => category.startsWith('table_');
}

/// Manages starter cosmetics, Table Space materials, XP shop catalog pricing, unlock checks, and purchases.
class LobbyShopService {
  LobbyShopService._();
  static final LobbyShopService instance = LobbyShopService._();

  /// Basic starter cosmetics & default table materials given to every student for free.
  static const Set<String> kStarterUnlockedCosmetics = <String>{
    'preset:Adam',
    'preset:Alex',
    'outfit:1-1', // Sky Polo Shirt (Basic Uniform)
    'outfit:1-2', // Mint Polo Shirt (Basic Uniform)
    'hair:none',
    'hair:1-1', // Short Black
    'hair:17-4', // Ponytail Auburn
    'face:none',
    'glasses:none',
    'hat:none',
    'gloves:none',
    'bag:none',
    // Default Classroom Table Space materials:
    'table_chair:tan_classic',
    'table_mat:oak_default',
    'table_light:none',
    'table_frame:none',
    'table_prop:none',
  };

  /// Catalog of purchasable Classroom Table Space materials & decorations.
  static const Map<String, List<Map<String, dynamic>>> kTableDecorCatalog = {
    'table_chair': [
      {
        'id': 'tan_classic',
        'label': '🪑 Classic Oak Chair',
        'hex': '#D9A066',
        'cost': 0,
      },
      {
        'id': 'crimson_gaming',
        'label': '🏎️ Crimson Pro Gaming Chair',
        'hex': '#EF4444',
        'cost': 60,
      },
      {
        'id': 'emerald_ergo',
        'label': '🌿 Emerald Ergonomic Mesh Chair',
        'hex': '#10B981',
        'cost': 65,
      },
      {
        'id': 'sakura_pastel',
        'label': '🌸 Sakura Plush Cushion Chair',
        'hex': '#F472B6',
        'cost': 75,
      },
      {
        'id': 'royal_gold',
        'label': '👑 Royal Gold Executive Chair',
        'hex': '#F59E0B',
        'cost': 90,
      },
      {
        'id': 'cyber_neon',
        'label': '⚡ Cyber Neon LED Chair',
        'hex': '#06B6D4',
        'cost': 110,
      },
    ],
    'table_light': [
      {
        'id': 'none',
        'label': 'No Desk Light',
        'hex': '#64748B',
        'cost': 0,
      },
      {
        'id': 'fairy_warm',
        'label': '✨ Warm Pixie Fairy String Lights',
        'hex': '#FDE047',
        'cost': 50,
      },
      {
        'id': 'banker_brass',
        'label': '🏮 Vintage Scholar Brass Lamp',
        'hex': '#10B981',
        'cost': 65,
      },
      {
        'id': 'neon_strip',
        'label': '🌈 RGB Cyber Desk Glow Strip',
        'hex': '#EC4899',
        'cost': 85,
      },
      {
        'id': 'starlight_lantern',
        'label': '🌟 Floating Starlight Study Orb',
        'hex': '#38BDF8',
        'cost': 95,
      },
    ],
    'table_frame': [
      {
        'id': 'none',
        'label': 'No Desk Frame',
        'hex': '#64748B',
        'cost': 0,
      },
      {
        'id': 'gold_cert',
        'label': '🖼️ Golden Honor Roll Frame',
        'hex': '#FACC15',
        'cost': 45,
      },
      {
        'id': 'pixel_portrait',
        'label': '📸 Class Memories Photo Frame',
        'hex': '#38BDF8',
        'cost': 55,
      },
      {
        'id': 'holo_plaque',
        'label': '🏆 Holographic Scholar Plaque',
        'hex': '#A855F7',
        'cost': 80,
      },
    ],
    'table_mat': [
      {
        'id': 'oak_default',
        'label': '🪵 Natural Polished Wood',
        'hex': '#B47846',
        'cost': 0,
      },
      {
        'id': 'mint_pad',
        'label': '🟩 Mint Matcha Desk Pad',
        'hex': '#34D399',
        'cost': 40,
      },
      {
        'id': 'galaxy_mat',
        'label': '🌌 Midnight Nebula Desk Mat',
        'hex': '#6366F1',
        'cost': 55,
      },
      {
        'id': 'lofi_grid',
        'label': '📐 Blueprint Pixel Grid Pad',
        'hex': '#38BDF8',
        'cost': 65,
      },
      {
        'id': 'royal_velvet',
        'label': '🌺 Velvet Crimson Desk Runner',
        'hex': '#EC4899',
        'cost': 70,
      },
    ],
    'table_prop': [
      {
        'id': 'none',
        'label': 'Clean Desk Surface',
        'hex': '#64748B',
        'cost': 0,
      },
      {
        'id': 'textbooks_stack',
        'label': '📚 PKLP, PPG & UCSP Reviewer Stack',
        'hex': '#F97316',
        'cost': 35,
      },
      {
        'id': 'zen_bonsai',
        'label': '🪴 Mini Zen Bonsai & Pen Holder',
        'hex': '#22C55E',
        'cost': 60,
      },
      {
        'id': 'gaming_laptop',
        'label': '💻 RGB Study Laptop & Notebook',
        'hex': '#38BDF8',
        'cost': 95,
      },
      {
        'id': 'trophy_mug',
        'label': '🏆 Golden Debate Trophy & Cocoa Mug',
        'hex': '#FACC15',
        'cost': 110,
      },
    ],
  };

  static String buildItemKey(String category, String partId) =>
      '$category:$partId';

  /// Returns the XP price for a given category and part ID (`0` if starter/free).
  int costForCosmetic(String category, String partId) {
    if (category == 'body' || category == 'eyes' || partId == 'none') {
      return 0;
    }
    final key = buildItemKey(category, partId);
    if (kStarterUnlockedCosmetics.contains(key)) {
      return 0;
    }
    if (kTableDecorCatalog.containsKey(category)) {
      for (final entry in kTableDecorCatalog[category]!) {
        if (entry['id'] == partId) {
          return (entry['cost'] as num?)?.toInt() ?? 50;
        }
      }
    }
    switch (category) {
      case 'face':
        return 45;
      case 'hair':
        return 50;
      case 'gloves':
        return 55;
      case 'glasses':
        return 60;
      case 'outfit':
        return 75;
      case 'hat':
        return 90;
      case 'bag':
        return 100;
      case 'preset':
        return 120;
      default:
        return 60;
    }
  }

  /// Checks whether the current user has unlocked a specific part or table decoration.
  bool isCosmeticUnlocked(
    String category,
    String partId, {
    bool isFaculty = false,
  }) {
    if (isFaculty) return true;
    if (category == 'body' || category == 'eyes' || partId == 'none') {
      return true;
    }
    final key = buildItemKey(category, partId);
    if (kStarterUnlockedCosmetics.contains(key)) {
      return true;
    }
    return LobbyDataService.instance.progress.unlockedCosmetics.contains(key);
  }

  /// Checks whether a preset character is unlocked.
  bool isPresetUnlocked(String presetName, {bool isFaculty = false}) {
    return isCosmeticUnlocked('preset', presetName, isFaculty: isFaculty);
  }

  /// Ensures a [LobbyAvatarLook] only uses unlocked cosmetics for the student,
  /// falling back to starter defaults for any locked parts.
  LobbyAvatarLook sanitizeLookForUnlocked(
    LobbyAvatarLook look, {
    bool isFaculty = false,
  }) {
    if (isFaculty) return look;
    if (look.isPreset) {
      final safePreset = isPresetUnlocked(look.presetName, isFaculty: isFaculty)
          ? look.presetName
          : 'Adam';
      return look.copyWith(isPreset: true, presetName: safePreset);
    }
    return look.copyWith(
      isPreset: false,
      outfit: isCosmeticUnlocked('outfit', look.outfit, isFaculty: isFaculty)
          ? look.outfit
          : '1-1',
      hair: isCosmeticUnlocked('hair', look.hair, isFaculty: isFaculty)
          ? look.hair
          : '1-1',
      face: isCosmeticUnlocked('face', look.face, isFaculty: isFaculty)
          ? look.face
          : 'none',
      glasses: isCosmeticUnlocked('glasses', look.glasses, isFaculty: isFaculty)
          ? look.glasses
          : 'none',
      hat: isCosmeticUnlocked('hat', look.hat, isFaculty: isFaculty)
          ? look.hat
          : 'none',
      gloves: isCosmeticUnlocked('gloves', look.gloves, isFaculty: isFaculty)
          ? look.gloves
          : 'none',
      bag: isCosmeticUnlocked('bag', look.bag, isFaculty: isFaculty)
          ? look.bag
          : 'none',
    );
  }

  /// Ensures a [LobbyTableDecorConfig] only uses unlocked table items.
  LobbyTableDecorConfig sanitizeTableDecorForUnlocked(
    LobbyTableDecorConfig decor, {
    bool isFaculty = false,
  }) {
    if (isFaculty) return decor;
    return LobbyTableDecorConfig(
      chairStyle: isCosmeticUnlocked('table_chair', decor.chairStyle,
              isFaculty: isFaculty)
          ? decor.chairStyle
          : 'tan_classic',
      deskMat:
          isCosmeticUnlocked('table_mat', decor.deskMat, isFaculty: isFaculty)
              ? decor.deskMat
              : 'oak_default',
      miniLight: isCosmeticUnlocked('table_light', decor.miniLight,
              isFaculty: isFaculty)
          ? decor.miniLight
          : 'none',
      deskFrame: isCosmeticUnlocked('table_frame', decor.deskFrame,
              isFaculty: isFaculty)
          ? decor.deskFrame
          : 'none',
      deskProp:
          isCosmeticUnlocked('table_prop', decor.deskProp, isFaculty: isFaculty)
              ? decor.deskProp
              : 'none',
    );
  }

  /// Returns all shop items for a given category (`outfit`, `hair`, `glasses`, `hat`, `bag`, `gloves`, `face`, `preset`, or `table_*`).
  List<ShopCosmeticItem> itemsForCategory(String category) {
    if (kTableDecorCatalog.containsKey(category)) {
      return kTableDecorCatalog[category]!.map((m) {
        final id = m['id']!.toString();
        final label = m['label']!.toString();
        final hex = m['hex']?.toString() ?? '#38BDF8';
        final cost = (m['cost'] as num?)?.toInt() ?? 0;
        final key = buildItemKey(category, id);
        return ShopCosmeticItem(
          itemKey: key,
          category: category,
          partId: id,
          label: label,
          hexColor: hex,
          xpCost: cost,
          isStarter: cost == 0,
        );
      }).toList();
    }

    if (category == 'preset') {
      return kBundledPresets.map((name) {
        final key = buildItemKey('preset', name);
        final cost = costForCosmetic('preset', name);
        return ShopCosmeticItem(
          itemKey: key,
          category: 'preset',
          partId: name,
          label: '$name (Full Character)',
          hexColor: '#38BDF8',
          xpCost: cost,
          isStarter: cost == 0,
        );
      }).toList();
    }

    final rawList = kBundledCustomParts[category] ?? const [];
    return rawList.where((m) => m['id'] != 'none').map((m) {
      final id = m['id']!;
      final label = m['label']!;
      final hex = m['hex'] ?? '#38BDF8';
      final key = buildItemKey(category, id);
      final cost = costForCosmetic(category, id);
      return ShopCosmeticItem(
        itemKey: key,
        category: category,
        partId: id,
        label: label,
        hexColor: hex,
        xpCost: cost,
        isStarter: cost == 0,
      );
    }).toList();
  }

  /// Applies [item] onto [baseLook] for live preview or equipping.
  LobbyAvatarLook applyItemToLook(
    LobbyAvatarLook baseLook,
    ShopCosmeticItem item,
  ) {
    if (item.isTableDecor) return baseLook;
    if (item.category == 'preset') {
      return baseLook.copyWith(isPreset: true, presetName: item.partId);
    }
    return baseLook.copyWith(
      isPreset: false,
      outfit: item.category == 'outfit' ? item.partId : baseLook.outfit,
      hair: item.category == 'hair' ? item.partId : baseLook.hair,
      face: item.category == 'face' ? item.partId : baseLook.face,
      glasses: item.category == 'glasses' ? item.partId : baseLook.glasses,
      hat: item.category == 'hat' ? item.partId : baseLook.hat,
      gloves: item.category == 'gloves' ? item.partId : baseLook.gloves,
      bag: item.category == 'bag' ? item.partId : baseLook.bag,
    );
  }

  /// Applies a table decor [item] onto [baseDecor] for live preview or equipping.
  LobbyTableDecorConfig applyItemToTableDecor(
    LobbyTableDecorConfig baseDecor,
    ShopCosmeticItem item,
  ) {
    switch (item.category) {
      case 'table_chair':
        return baseDecor.copyWith(chairStyle: item.partId);
      case 'table_mat':
        return baseDecor.copyWith(deskMat: item.partId);
      case 'table_light':
        return baseDecor.copyWith(miniLight: item.partId);
      case 'table_frame':
        return baseDecor.copyWith(deskFrame: item.partId);
      case 'table_prop':
        return baseDecor.copyWith(deskProp: item.partId);
      default:
        return baseDecor;
    }
  }
}

/// Opens the RPG **🛍️ MIS-SHS Campus Shop (Wardrobe & Classroom Table Decor)** Modal
/// where students exchange earned XP (`availableXp = xp - spentXp`) for outfits, hairstyles,
/// glasses, hats, bags, presets, AND personal Classroom Table Space decorations!
Future<LobbyAvatarLook?> showCampusShopModal({
  required BuildContext context,
  required LobbyAvatarLook currentLook,
  required bool isFaculty,
  String? initialCategory,
}) {
  return showModalBottomSheet<LobbyAvatarLook>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (ctx) => _CampusShopModalSheet(
      initialLook: currentLook,
      isFaculty: isFaculty,
      initialCategory: initialCategory ?? 'table_chair',
    ),
  );
}

class _CampusShopModalSheet extends StatefulWidget {
  final LobbyAvatarLook initialLook;
  final bool isFaculty;
  final String initialCategory;

  const _CampusShopModalSheet({
    required this.initialLook,
    required this.isFaculty,
    this.initialCategory = 'table_chair',
  });

  @override
  State<_CampusShopModalSheet> createState() => _CampusShopModalSheetState();
}

class _CampusShopModalSheetState extends State<_CampusShopModalSheet> {
  late LobbyAvatarLook _equippedLook;
  late LobbyAvatarLook _previewLook;
  late LobbyTableDecorConfig _equippedTableDecor;
  late LobbyTableDecorConfig _previewTableDecor;
  late String _selectedCategory;
  AvatarFacing _previewFacing = AvatarFacing.down;

  static const List<Map<String, String>> _shopCategories = [
    {'key': 'table_chair', 'label': '🪑 Chair Styles'},
    {'key': 'table_light', 'label': '💡 Mini Lights'},
    {'key': 'table_frame', 'label': '🖼️ Desk Frames'},
    {'key': 'table_mat', 'label': '🟩 Desk Mats'},
    {'key': 'table_prop', 'label': '📚 Table Props'},
    {'key': 'outfit', 'label': '👕 Outfits (75 XP)'},
    {'key': 'hair', 'label': '💇 Hairstyles (50 XP)'},
    {'key': 'glasses', 'label': '🕶️ Glasses (60 XP)'},
    {'key': 'hat', 'label': '🧢 Hats & Caps (90 XP)'},
    {'key': 'bag', 'label': '🎒 Bags (100 XP)'},
    {'key': 'gloves', 'label': '🧤 Gloves (55 XP)'},
    {'key': 'face', 'label': '😊 Facial (45 XP)'},
    {'key': 'preset', 'label': '🌟 Presets (120 XP)'},
  ];

  @override
  void initState() {
    super.initState();
    _equippedLook = widget.initialLook;
    _previewLook = widget.initialLook;
    _equippedTableDecor = LobbyDataService.instance.progress.tableDecor;
    _previewTableDecor = _equippedTableDecor;
    _selectedCategory = widget.initialCategory;
  }

  Color _parseHex(String hex) {
    final cleaned = hex.replaceAll('#', '');
    final val = int.tryParse('FF$cleaned', radix: 16) ?? 0xFF38BDF8;
    return Color(val);
  }

  bool _isItemEquipped(ShopCosmeticItem item) {
    if (item.isTableDecor) {
      switch (item.category) {
        case 'table_chair':
          return _equippedTableDecor.chairStyle == item.partId;
        case 'table_mat':
          return _equippedTableDecor.deskMat == item.partId;
        case 'table_light':
          return _equippedTableDecor.miniLight == item.partId;
        case 'table_frame':
          return _equippedTableDecor.deskFrame == item.partId;
        case 'table_prop':
          return _equippedTableDecor.deskProp == item.partId;
        default:
          return false;
      }
    }
    if (item.category == 'preset') {
      return _equippedLook.isPreset && _equippedLook.presetName == item.partId;
    }
    if (_equippedLook.isPreset) return false;
    switch (item.category) {
      case 'outfit':
        return _equippedLook.outfit == item.partId;
      case 'hair':
        return _equippedLook.hair == item.partId;
      case 'face':
        return _equippedLook.face == item.partId;
      case 'glasses':
        return _equippedLook.glasses == item.partId;
      case 'hat':
        return _equippedLook.hat == item.partId;
      case 'gloves':
        return _equippedLook.gloves == item.partId;
      case 'bag':
        return _equippedLook.bag == item.partId;
      default:
        return false;
    }
  }

  Future<void> _handleBuyOrEquip(ShopCosmeticItem item) async {
    final shop = LobbyShopService.instance;
    final unlocked = shop.isCosmeticUnlocked(
      item.category,
      item.partId,
      isFaculty: widget.isFaculty,
    );

    if (unlocked) {
      HapticFeedback.selectionClick();
      LobbyAudioService.instance.playSitOrRest();
      if (item.isTableDecor) {
        final nextDecor =
            shop.applyItemToTableDecor(_equippedTableDecor, item);
        setState(() {
          _equippedTableDecor = nextDecor;
          _previewTableDecor = nextDecor;
        });
        await LobbyDataService.instance.updateTableDecor(nextDecor);
      } else {
        setState(() {
          _equippedLook = shop.applyItemToLook(_equippedLook, item);
          _previewLook = _equippedLook;
        });
      }
      return;
    }

    final availableXp = LobbyDataService.instance.progress.availableXp;
    if (availableXp < item.xpCost) {
      HapticFeedback.vibrate();
      LobbyAudioService.instance.playQuizWrong();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            '🔒 Need ${item.xpCost} XP to unlock "${item.label}" (You have $availableXp Available XP). Answer AI Subject Mentor questions or complete Quests to earn XP!',
          ),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    final ok = await LobbyDataService.instance.purchaseShopCosmetic(
      itemKey: item.itemKey,
      costXp: item.xpCost,
    );
    if (!mounted) return;
    if (ok) {
      HapticFeedback.heavyImpact();
      LobbyAudioService.instance.playShopPurchase();
      if (item.isTableDecor) {
        final nextDecor =
            shop.applyItemToTableDecor(_equippedTableDecor, item);
        setState(() {
          _equippedTableDecor = nextDecor;
          _previewTableDecor = nextDecor;
        });
        await LobbyDataService.instance.updateTableDecor(nextDecor);
      } else {
        setState(() {
          _equippedLook = shop.applyItemToLook(_equippedLook, item);
          _previewLook = _equippedLook;
        });
      }
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            '🛍️ Unlocked & Equipped "${item.label}" for ${item.xpCost} XP!',
          ),
          backgroundColor: const Color(0xFF065F46),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  Widget _buildTableDecorMiniPreview(LobbyTableDecorConfig decor) {
    final chairColor = decor.chairPrimaryColor;
    final matColor = decor.deskMatColor ?? const Color(0xFFB47846);
    return Container(
      width: 92,
      height: 82,
      decoration: BoxDecoration(
        color: const Color(0xFF0F172A),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFFACC15).withValues(alpha: 0.5)),
      ),
      child: Stack(
        alignment: Alignment.center,
        children: [
          // Chair backrest & cushion
          Positioned(
            bottom: 8,
            child: Container(
              width: 34,
              height: 22,
              decoration: BoxDecoration(
                color: chairColor,
                borderRadius: BorderRadius.circular(6),
                border: Border.all(color: Colors.white70, width: 1.2),
              ),
            ),
          ),
          // Desk surface
          Positioned(
            top: 16,
            child: Container(
              width: 68,
              height: 36,
              decoration: BoxDecoration(
                color: const Color(0xFF8B5A2B),
                borderRadius: BorderRadius.circular(7),
                border: Border.all(color: const Color(0xFF5C3A1B), width: 1.5),
              ),
              child: Center(
                child: Container(
                  width: 54,
                  height: 24,
                  decoration: BoxDecoration(
                    color: matColor.withValues(alpha: 0.85),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      if (decor.miniLight != 'none')
                        const Text('💡', style: TextStyle(fontSize: 12)),
                      if (decor.deskFrame != 'none')
                        const Text('🖼️', style: TextStyle(fontSize: 12)),
                      if (decor.deskProp != 'none')
                        Text(
                          decor.deskProp == 'zen_bonsai'
                              ? '🪴'
                              : (decor.deskProp == 'gaming_laptop'
                                  ? '💻'
                                  : (decor.deskProp == 'trophy_mug'
                                      ? '🏆'
                                      : '📚')),
                          style: const TextStyle(fontSize: 12),
                        ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final media = MediaQuery.of(context);
    final items = LobbyShopService.instance.itemsForCategory(_selectedCategory);

    return AnimatedBuilder(
      animation: LobbyDataService.instance,
      builder: (context, _) {
        final progress = LobbyDataService.instance.progress;
        final availableXp = progress.availableXp;

        return Container(
          height: media.size.height * 0.88,
          margin: const EdgeInsets.fromLTRB(10, 16, 10, 10),
          decoration: BoxDecoration(
            color: const Color(0xFF0F172A),
            borderRadius: BorderRadius.circular(26),
            border: Border.all(
              color: const Color(0xFFF59E0B).withValues(alpha: 0.65),
              width: 1.8,
            ),
          ),
          child: Column(
            children: [
              // Compact Fixed Top Title Bar
              Container(
                padding: const EdgeInsets.fromLTRB(16, 12, 10, 10),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      const Color(0xFF78350F).withValues(alpha: 0.55),
                      const Color(0xFF1E293B),
                    ],
                  ),
                  borderRadius:
                      const BorderRadius.vertical(top: Radius.circular(24)),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 40,
                      height: 40,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: const Color(0xFFF59E0B).withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: const Color(0xFFFACC15)),
                      ),
                      child: const Text('🛍️', style: TextStyle(fontSize: 20)),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'CAMPUS SHOP • WARDROBE & TABLE DECOR',
                            style: GoogleFonts.outfit(
                              color: Colors.white,
                              fontSize: 15.5,
                              fontWeight: FontWeight.w800,
                              letterSpacing: 0.3,
                            ),
                          ),
                          Text(
                            'Shopkeeper Mina: "Decorate your Classroom Table Space or unlock new outfits with XP!"',
                            style: GoogleFonts.inter(
                              color: Colors.white70,
                              fontSize: 11,
                            ),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      onPressed: () =>
                          Navigator.of(context).pop(_equippedLook),
                      icon: const Icon(Icons.close_rounded,
                          color: Colors.white70),
                    ),
                  ],
                ),
              ),

              // Unified Scrollable Body (Scrolls smoothly in both Portrait and Landscape!)
              Expanded(
                child: CustomScrollView(
                  physics: const BouncingScrollPhysics(),
                  slivers: [
                    SliverToBoxAdapter(
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(14, 10, 14, 8),
                        child: Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: const Color(0xFF1E293B),
                            borderRadius: BorderRadius.circular(18),
                            border: Border.all(color: Colors.white12),
                          ),
                          child: Row(
                            children: [
                              PixelAvatarPreview(
                                look: _previewLook,
                                facing: _previewFacing,
                                animateWalk: true,
                                scale: 1.65,
                              ),
                              const SizedBox(width: 8),
                              _buildTableDecorMiniPreview(_previewTableDecor),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 10, vertical: 4),
                                      decoration: BoxDecoration(
                                        color: const Color(0xFFF59E0B)
                                            .withValues(alpha: 0.2),
                                        borderRadius: BorderRadius.circular(99),
                                        border: Border.all(
                                            color: const Color(0xFFFACC15)),
                                      ),
                                      child: Text(
                                        widget.isFaculty
                                            ? '👑 Teacher Pass • All Unlocked'
                                            : '✨ Wallet: $availableXp XP',
                                        style: GoogleFonts.outfit(
                                          color: const Color(0xFFFDE047),
                                          fontSize: 12,
                                          fontWeight: FontWeight.w800,
                                        ),
                                      ),
                                    ),
                                    const SizedBox(height: 5),
                                    Text(
                                      'Lifetime XP: ${progress.xp} • Spent: ${progress.spentXp} XP',
                                      style: GoogleFonts.inter(
                                        color: Colors.white70,
                                        fontSize: 10.5,
                                      ),
                                    ),
                                    const SizedBox(height: 6),
                                    Wrap(
                                      spacing: 6,
                                      runSpacing: 6,
                                      children: [
                                        OutlinedButton.icon(
                                          onPressed: () {
                                            setState(() {
                                              _previewFacing =
                                                  AvatarFacing.values[
                                                      (_previewFacing.index +
                                                              1) %
                                                          AvatarFacing
                                                              .values.length];
                                            });
                                          },
                                          style: OutlinedButton.styleFrom(
                                            foregroundColor: Colors.white,
                                            side: const BorderSide(
                                                color: Colors.white24),
                                            visualDensity:
                                                VisualDensity.compact,
                                          ),
                                          icon: const Icon(
                                              Icons.rotate_right_rounded,
                                              size: 14),
                                          label: const Text('Turn',
                                              style: TextStyle(fontSize: 11)),
                                        ),
                                        ElevatedButton.icon(
                                          onPressed: () => Navigator.of(context)
                                              .pop(_equippedLook),
                                          style: ElevatedButton.styleFrom(
                                            backgroundColor:
                                                const Color(0xFF10B981),
                                            foregroundColor: Colors.white,
                                            visualDensity:
                                                VisualDensity.compact,
                                          ),
                                          icon: const Icon(
                                              Icons.check_circle_rounded,
                                              size: 14),
                                          label: const Text('Done',
                                              style: TextStyle(
                                                  fontSize: 11,
                                                  fontWeight: FontWeight.w800)),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                    SliverToBoxAdapter(
                      child: SizedBox(
                        height: 40,
                        child: ListView.separated(
                          scrollDirection: Axis.horizontal,
                          padding: const EdgeInsets.symmetric(horizontal: 14),
                          itemCount: _shopCategories.length,
                          separatorBuilder: (_, __) => const SizedBox(width: 8),
                          itemBuilder: (context, index) {
                            final cat = _shopCategories[index];
                            final isSelected = _selectedCategory == cat['key'];
                            return ChoiceChip(
                              label: Text(cat['label']!),
                              selected: isSelected,
                              onSelected: (_) => setState(
                                  () => _selectedCategory = cat['key']!),
                              selectedColor: const Color(0xFFFACC15),
                              backgroundColor: const Color(0xFF1E293B),
                              labelStyle: GoogleFonts.inter(
                                color:
                                    isSelected ? Colors.black : Colors.white70,
                                fontWeight: FontWeight.w800,
                                fontSize: 11.5,
                              ),
                            );
                          },
                        ),
                      ),
                    ),
                    SliverPadding(
                      padding: const EdgeInsets.fromLTRB(14, 10, 14, 18),
                      sliver: SliverGrid(
                        gridDelegate:
                            const SliverGridDelegateWithMaxCrossAxisExtent(
                          maxCrossAxisExtent: 240,
                          mainAxisSpacing: 10,
                          crossAxisSpacing: 10,
                          childAspectRatio: 1.48,
                        ),
                        delegate: SliverChildBuilderDelegate(
                          (context, index) {
                            final item = items[index];
                            final unlocked = LobbyShopService.instance
                                .isCosmeticUnlocked(
                                  item.category,
                                  item.partId,
                                  isFaculty: widget.isFaculty,
                                );
                            final equipped = _isItemEquipped(item);
                            final canAfford = availableXp >= item.xpCost;

                            return InkWell(
                              onTap: () {
                                HapticFeedback.selectionClick();
                                setState(() {
                                  if (item.isTableDecor) {
                                    _previewTableDecor = LobbyShopService
                                        .instance
                                        .applyItemToTableDecor(
                                            _previewTableDecor, item);
                                  } else {
                                    _previewLook = LobbyShopService.instance
                                        .applyItemToLook(_previewLook, item);
                                  }
                                });
                              },
                              borderRadius: BorderRadius.circular(16),
                              child: Container(
                                padding: const EdgeInsets.all(10),
                                decoration: BoxDecoration(
                                  color: equipped
                                      ? const Color(0xFF065F46)
                                          .withValues(alpha: 0.45)
                                      : const Color(0xFF1E293B),
                                  borderRadius: BorderRadius.circular(16),
                                  border: Border.all(
                                    color: equipped
                                        ? const Color(0xFF10B981)
                                        : (unlocked
                                            ? const Color(0xFF38BDF8)
                                                .withValues(alpha: 0.45)
                                            : Colors.white12),
                                    width: equipped ? 1.8 : 1.1,
                                  ),
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceBetween,
                                  children: [
                                    Row(
                                      children: [
                                        Container(
                                          width: 16,
                                          height: 16,
                                          decoration: BoxDecoration(
                                            color: _parseHex(item.hexColor),
                                            shape: BoxShape.circle,
                                            border: Border.all(
                                                color: Colors.white54,
                                                width: 1),
                                          ),
                                        ),
                                        const SizedBox(width: 8),
                                        Expanded(
                                          child: Text(
                                            item.label,
                                            maxLines: 2,
                                            overflow: TextOverflow.ellipsis,
                                            style: GoogleFonts.outfit(
                                              color: Colors.white,
                                              fontSize: 12,
                                              fontWeight: FontWeight.w800,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                    Text(
                                      item.isStarter
                                          ? '✅ Starter Item (Free)'
                                          : (unlocked
                                              ? '🔓 Unlocked'
                                              : '🔒 Price: ${item.xpCost} XP'),
                                      style: GoogleFonts.inter(
                                        color: unlocked
                                            ? const Color(0xFF6EE7B7)
                                            : (canAfford
                                                ? const Color(0xFFFDE047)
                                                : Colors.white54),
                                        fontSize: 10.5,
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                    SizedBox(
                                      width: double.infinity,
                                      height: 30,
                                      child: ElevatedButton(
                                        style: ElevatedButton.styleFrom(
                                          backgroundColor: equipped
                                              ? const Color(0xFF10B981)
                                              : (unlocked
                                                  ? const Color(0xFF0284C7)
                                                  : (canAfford
                                                      ? const Color(0xFFF59E0B)
                                                      : Colors.white12)),
                                          foregroundColor:
                                              (!unlocked && canAfford)
                                                  ? Colors.black
                                                  : Colors.white,
                                          padding: EdgeInsets.zero,
                                          shape: RoundedRectangleBorder(
                                            borderRadius:
                                                BorderRadius.circular(10),
                                          ),
                                        ),
                                        onPressed: () =>
                                            _handleBuyOrEquip(item),
                                        child: Text(
                                          equipped
                                              ? '✓ Equipped'
                                              : (unlocked
                                                  ? 'Equip Now'
                                                  : 'Buy (${item.xpCost} XP)'),
                                          style: GoogleFonts.outfit(
                                            fontSize: 11.5,
                                            fontWeight: FontWeight.w800,
                                          ),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            );
                          },
                          childCount: items.length,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
