import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';

import 'lobby_audio_service.dart';
import 'lobby_data_service.dart';
import 'school_lobby_avatar.dart';

/// Represents a purchasable or starter cosmetic item in the MIS-SHS Campus Shop.
class ShopCosmeticItem {
  final String itemKey; // e.g. 'outfit:4-1', 'hat:5-1', 'preset:Amelia'
  final String category; // 'outfit', 'hair', 'glasses', 'hat', 'bag', 'gloves', 'face', 'preset'
  final String partId; // e.g. '4-1', '5-1', 'Amelia'
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
}

/// Manages starter cosmetics, XP shop catalog pricing, unlock checks, and purchases.
class LobbyShopService {
  LobbyShopService._();
  static final LobbyShopService instance = LobbyShopService._();

  /// Basic starter cosmetics given to every student for free at account creation.
  /// Skin tones (`body:*`), eye colors (`eyes:*`), and `'none'` accessories are always free.
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

  /// Checks whether the current user has unlocked a specific part.
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

  /// Returns all shop items for a given category (`outfit`, `hair`, `glasses`, `hat`, `bag`, `gloves`, `face`, `preset`).
  List<ShopCosmeticItem> itemsForCategory(String category) {
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
}

/// Opens the RPG **🛍️ MIS-SHS Campus Cosmetics Shop** Modal where students exchange
/// earned XP (`availableXp = xp - spentXp`) for outfits, hairstyles, glasses, hats, bags, and presets.
Future<LobbyAvatarLook?> showCampusShopModal({
  required BuildContext context,
  required LobbyAvatarLook currentLook,
  required bool isFaculty,
}) {
  return showModalBottomSheet<LobbyAvatarLook>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (ctx) => _CampusShopModalSheet(
      initialLook: currentLook,
      isFaculty: isFaculty,
    ),
  );
}

class _CampusShopModalSheet extends StatefulWidget {
  final LobbyAvatarLook initialLook;
  final bool isFaculty;

  const _CampusShopModalSheet({
    required this.initialLook,
    required this.isFaculty,
  });

  @override
  State<_CampusShopModalSheet> createState() => _CampusShopModalSheetState();
}

class _CampusShopModalSheetState extends State<_CampusShopModalSheet> {
  late LobbyAvatarLook _equippedLook;
  late LobbyAvatarLook _previewLook;
  String _selectedCategory = 'outfit';
  AvatarFacing _previewFacing = AvatarFacing.down;

  static const List<Map<String, String>> _shopCategories = [
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
  }

  Color _parseHex(String hex) {
    final cleaned = hex.replaceAll('#', '');
    final val = int.tryParse('FF$cleaned', radix: 16) ?? 0xFF38BDF8;
    return Color(val);
  }

  bool _isItemEquipped(ShopCosmeticItem item) {
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
      setState(() {
        _equippedLook = shop.applyItemToLook(_equippedLook, item);
        _previewLook = _equippedLook;
      });
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
            '🔒 Need ${item.xpCost} XP to unlock "${item.label}" (You have $availableXp Available XP). Complete Quests, Reviewers, or Mystery Chests to earn more XP!',
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
      setState(() {
        _equippedLook = shop.applyItemToLook(_equippedLook, item);
        _previewLook = _equippedLook;
      });
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
          margin: const EdgeInsets.fromLTRB(10, 20, 10, 10),
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
              // Header
              Container(
                padding: const EdgeInsets.fromLTRB(18, 14, 12, 12),
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
                      width: 44,
                      height: 44,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: const Color(0xFFF59E0B).withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: const Color(0xFFFACC15)),
                      ),
                      child: const Text('🛍️', style: TextStyle(fontSize: 22)),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'MIS-SHS CAMPUS COSMETICS SHOP',
                            style: GoogleFonts.outfit(
                              color: Colors.white,
                              fontSize: 16.5,
                              fontWeight: FontWeight.w800,
                              letterSpacing: 0.4,
                            ),
                          ),
                          Text(
                            'Exchange earned XP for outfits, hairstyles, glasses, hats & bags! (Your Level ${progress.level} Rank never drops)',
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

              // Live Avatar Try-On & Wallet Banner
              Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
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
                        scale: 1.85,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 10, vertical: 5),
                              decoration: BoxDecoration(
                                color: const Color(0xFFF59E0B)
                                    .withValues(alpha: 0.2),
                                borderRadius: BorderRadius.circular(99),
                                border:
                                    Border.all(color: const Color(0xFFFACC15)),
                              ),
                              child: Text(
                                widget.isFaculty
                                    ? '👑 Teacher Pass • All Unlocked'
                                    : '✨ Available Shop Wallet: $availableXp XP',
                                style: GoogleFonts.outfit(
                                  color: const Color(0xFFFDE047),
                                  fontSize: 12.5,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              'Total Lifetime XP: ${progress.xp} XP • Spent: ${progress.spentXp} XP',
                              style: GoogleFonts.inter(
                                color: Colors.white70,
                                fontSize: 11,
                              ),
                            ),
                            const SizedBox(height: 6),
                            Row(
                              children: [
                                OutlinedButton.icon(
                                  onPressed: () {
                                    setState(() {
                                      _previewFacing = AvatarFacing.values[
                                          (_previewFacing.index + 1) %
                                              AvatarFacing.values.length];
                                    });
                                  },
                                  style: OutlinedButton.styleFrom(
                                    foregroundColor: Colors.white,
                                    side:
                                        const BorderSide(color: Colors.white24),
                                    visualDensity: VisualDensity.compact,
                                  ),
                                  icon: const Icon(Icons.rotate_right_rounded,
                                      size: 14),
                                  label: const Text('Turn',
                                      style: TextStyle(fontSize: 11)),
                                ),
                                const SizedBox(width: 8),
                                ElevatedButton.icon(
                                  onPressed: () => Navigator.of(context)
                                      .pop(_equippedLook),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: const Color(0xFF10B981),
                                    foregroundColor: Colors.white,
                                    visualDensity: VisualDensity.compact,
                                  ),
                                  icon: const Icon(Icons.check_circle_rounded,
                                      size: 14),
                                  label: const Text('Save & Wear',
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

              // Category Filter Tabs
              SizedBox(
                height: 38,
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
                      onSelected: (_) =>
                          setState(() => _selectedCategory = cat['key']!),
                      selectedColor: const Color(0xFFFACC15),
                      backgroundColor: const Color(0xFF1E293B),
                      labelStyle: GoogleFonts.inter(
                        color: isSelected ? Colors.black : Colors.white70,
                        fontWeight: FontWeight.w800,
                        fontSize: 11.5,
                      ),
                    );
                  },
                ),
              ),
              const SizedBox(height: 8),

              // Shop Grid
              Expanded(
                child: GridView.builder(
                  padding: const EdgeInsets.fromLTRB(14, 4, 14, 14),
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 2,
                    mainAxisSpacing: 10,
                    crossAxisSpacing: 10,
                    childAspectRatio: 1.55,
                  ),
                  itemCount: items.length,
                  itemBuilder: (context, index) {
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
                        // Tapping card previews the item on the avatar
                        HapticFeedback.selectionClick();
                        setState(() {
                          _previewLook = LobbyShopService.instance
                              .applyItemToLook(_previewLook, item);
                        });
                      },
                      borderRadius: BorderRadius.circular(16),
                      child: Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: equipped
                              ? const Color(0xFF065F46).withValues(alpha: 0.45)
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
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
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
                                        color: Colors.white54, width: 1),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    item.label,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: GoogleFonts.outfit(
                                      color: Colors.white,
                                      fontSize: 12.5,
                                      fontWeight: FontWeight.w800,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            Text(
                              item.isStarter
                                  ? '✅ Starter Cosmetic (Free)'
                                  : (unlocked
                                      ? '🔓 Unlocked in Wardrobe'
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
                                  foregroundColor: (!unlocked && canAfford)
                                      ? Colors.black
                                      : Colors.white,
                                  padding: EdgeInsets.zero,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                ),
                                onPressed: () => _handleBuyOrEquip(item),
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
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
