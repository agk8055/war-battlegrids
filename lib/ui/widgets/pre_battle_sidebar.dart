import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../core/constants/app_assets.dart';
import '../../core/services/audio_service.dart';
import '../../campaign/models/kingdom_model.dart';
import '../../campaign/models/battle_config.dart';
import '../../campaign/data/battle_configs.dart';
import '../../campaign/campaign_manager.dart';

/// Redesigned Pre-Battle War Scroll Sidebar matching [AppAssets.battleBanner]
class PreBattleSidebar extends ConsumerStatefulWidget {
  final KingdomModel kingdom;
  final VoidCallback onEnterBattle;
  final VoidCallback onWithdraw;
  final bool isRight;

  const PreBattleSidebar({
    super.key,
    required this.kingdom,
    required this.onEnterBattle,
    required this.onWithdraw,
    this.isRight = true,
  });

  @override
  ConsumerState<PreBattleSidebar> createState() => _PreBattleSidebarState();
}

class _PreBattleSidebarState extends ConsumerState<PreBattleSidebar> with SingleTickerProviderStateMixin {
  late AnimationController _animController;
  late Animation<Offset> _slideAnim;
  late Animation<double> _fadeAnim;

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 350),
    );

    _slideAnim = Tween<Offset>(
      begin: const Offset(0.35, 0.0),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _animController,
      curve: Curves.easeOutCubic,
    ));

    _fadeAnim = CurvedAnimation(
      parent: _animController,
      curve: Curves.easeOut,
    );

    _animController.forward();
  }

  @override
  void didUpdateWidget(covariant PreBattleSidebar oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.kingdom.id != widget.kingdom.id) {
      _animController.forward(from: 0.2);
    }
  }

  @override
  void dispose() {
    _animController.dispose();
    super.dispose();
  }

  void _playClick() {
    try {
      ref.read(audioServiceProvider).playSfx(AppAssets.sfxClick);
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    final battleConfig = kBattleConfigs[widget.kingdom.id];
    final campaignState = ref.watch(campaignProvider);
    final bool isConquered = campaignState.isConquered(widget.kingdom.id);

    final screenSize = MediaQuery.of(context).size;
    final sidebarWidth = math.min(math.max(screenSize.width * 0.36, 320.0), 400.0);

    return SlideTransition(
      position: _slideAnim,
      child: FadeTransition(
        opacity: _fadeAnim,
        child: Container(
          width: sidebarWidth,
          height: double.infinity,
          margin: const EdgeInsets.only(right: 10, top: 10, bottom: 10),
          decoration: BoxDecoration(
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.65),
                blurRadius: 36,
                spreadRadius: 4,
                offset: const Offset(-8, 8),
              ),
            ],
          ),
          child: Stack(
            fit: StackFit.expand,
            children: [
              // 1. Parchment Banner Background
              Positioned.fill(
                child: AppAssetImage(
                  AppAssets.battleBanner,
                  fit: BoxFit.fill,
                ),
              ),

              // 2. Safely Inset Content framed strictly inside the safe parchment area
              Positioned.fill(
                child: Padding(
                  padding: const EdgeInsets.only(
                    top: 40.0,
                    bottom: 54.0,
                    left: 50.0,
                    right: 50.0,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // Header Row with Crest, Kingdom Title & Close Button
                      _buildHeader(isConquered),

                      const SizedBox(height: 8),

                      // Ornamental Divider
                      _buildOrnamentalDivider(),

                      const SizedBox(height: 8),

                      // Middle Body: Scrollable Dispatch Lore, Tactical Insight & Intel
                      Expanded(
                        child: SingleChildScrollView(
                          physics: const BouncingScrollPhysics(),
                          padding: EdgeInsets.zero,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              // War Decree / Lore Section
                              _buildLoreSection(isConquered),

                              // Tactical Insight Box (if available)
                              if (battleConfig?.insight != null) ...[
                                const SizedBox(height: 10),
                                _buildInsightBox(battleConfig!.insight!),
                              ],

                              const SizedBox(height: 10),

                              // Battle Intel Grid
                              _buildIntelSection(battleConfig, isConquered),
                              
                              const SizedBox(height: 6),
                            ],
                          ),
                        ),
                      ),

                      const SizedBox(height: 8),

                      // Action Buttons at the Bottom
                      _buildActionButtons(isConquered),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader(bool isConquered) {
    const Color darkSepia = Color(0xFF2C1607);
    const Color deepGold = Color(0xFFB57E10);

    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        // Heraldic Sigil Crest
        Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: const Color(0xFF331D0B),
            border: Border.all(
              color: isConquered ? const Color(0xFFFCB103) : const Color(0xFFB8860B),
              width: 2.0,
            ),
            boxShadow: [
              BoxShadow(
                color: (isConquered ? const Color(0xFFFCB103) : const Color(0xFF8B2500)).withValues(alpha: 0.35),
                blurRadius: 8,
                spreadRadius: 1,
              ),
              const BoxShadow(
                color: Color(0x66000000),
                blurRadius: 4,
                offset: Offset(0, 2),
              ),
            ],
          ),
          padding: const EdgeInsets.all(6),
          child: AppAssetImage(
            widget.kingdom.symbolAsset,
            fit: BoxFit.contain,
            color: isConquered ? const Color(0xFFFFD700) : const Color(0xFFE8D3B9),
          ),
        ),
        const SizedBox(width: 8),

        // Kingdom Name & Status Badge
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                widget.kingdom.name.toUpperCase(),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: GoogleFonts.sairaStencilOne(
                  fontSize: 17,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1.5,
                  color: darkSepia,
                  shadows: [
                    Shadow(
                      color: Colors.white.withValues(alpha: 0.6),
                      offset: const Offset(0, 1),
                      blurRadius: 1,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 3),
              // Status Badge
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: isConquered
                        ? [const Color(0xFFE5A910), const Color(0xFFB87800)]
                        : [const Color(0xFF9E2424), const Color(0xFF6B1212)],
                  ),
                  borderRadius: BorderRadius.circular(3),
                  border: Border.all(
                    color: isConquered ? const Color(0xFFFFE082) : const Color(0xFFE57373),
                    width: 0.8,
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      isConquered ? Icons.workspace_premium_rounded : Icons.shield_rounded,
                      color: isConquered ? const Color(0xFF1E1005) : Colors.white,
                      size: 9.5,
                    ),
                    const SizedBox(width: 3),
                    Text(
                      isConquered ? "CONQUERED" : "HOSTILE STRONGHOLD",
                      style: GoogleFonts.sairaStencilOne(
                        fontSize: 8.5,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 0.8,
                        color: isConquered ? const Color(0xFF1E1005) : Colors.white,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),

        // Close / Dismiss Wax Seal Button
        GestureDetector(
          onTap: () {
            _playClick();
            widget.onWithdraw();
          },
          child: Container(
            width: 28,
            height: 28,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: const Color(0xFF3B200E),
              border: Border.all(
                color: deepGold.withValues(alpha: 0.8),
                width: 1.2,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.25),
                  blurRadius: 3,
                  offset: const Offset(0, 1.5),
                ),
              ],
            ),
            child: const Center(
              child: Icon(
                Icons.close_rounded,
                color: Color(0xFFE8D3B9),
                size: 15,
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildOrnamentalDivider() {
    return Row(
      children: [
        Expanded(
          child: Container(
            height: 1.2,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  Colors.transparent,
                  const Color(0xFF8A5A29).withValues(alpha: 0.5),
                ],
              ),
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 6.0),
          child: const Text(
            "⚔",
            style: TextStyle(
              color: Color(0xFF7A4A1C),
              fontSize: 11,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        Expanded(
          child: Container(
            height: 1.2,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  const Color(0xFF8A5A29).withValues(alpha: 0.5),
                  Colors.transparent,
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildLoreSection(bool isConquered) {
    const Color headerInk = Color(0xFF4A280D);
    const Color bodyInk = Color(0xFF331E0C);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 10.0, vertical: 8.0),
      decoration: BoxDecoration(
        color: const Color(0xFF42240E).withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(
          color: const Color(0xFF7A4F23).withValues(alpha: 0.2),
          width: 0.8,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(
                Icons.auto_stories_rounded,
                size: 12,
                color: headerInk,
              ),
              const SizedBox(width: 5),
              Text(
                "WAR DISPATCH",
                style: GoogleFonts.sairaStencilOne(
                  fontSize: 10.5,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1.2,
                  color: headerInk,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            widget.kingdom.lore,
            style: GoogleFonts.outfit(
              color: bodyInk,
              fontSize: 12,
              height: 1.38,
              fontWeight: FontWeight.w500,
              fontStyle: FontStyle.italic,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInsightBox(String insight) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 6.0),
      decoration: BoxDecoration(
        color: const Color(0xFF8C541B).withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(5),
        border: Border.all(
          color: const Color(0xFFB57E10).withValues(alpha: 0.35),
          width: 0.8,
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Padding(
            padding: EdgeInsets.only(top: 1.0),
            child: Icon(
              Icons.lightbulb_outline_rounded,
              size: 13,
              color: Color(0xFF7A480D),
            ),
          ),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              insight,
              style: GoogleFonts.outfit(
                color: const Color(0xFF3D230A),
                fontSize: 11.5,
                height: 1.3,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildIntelSection(BattleConfig? battleConfig, bool isConquered) {
    const Color headerInk = Color(0xFF4A280D);

    final mapDisplayName = battleConfig?.mapPath
            .replaceAll('.tmx', '')
            .replaceAll('_', ' ')
            .toUpperCase() ??
        "UNEXPLORED";

    final aiIntellect = battleConfig?.aiStrategy.displayName ?? "Standard";

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 10.0, vertical: 8.0),
      decoration: BoxDecoration(
        color: const Color(0xFF42240E).withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(
          color: const Color(0xFF7A4F23).withValues(alpha: 0.2),
          width: 0.8,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(
                Icons.radar_rounded,
                size: 12,
                color: headerInk,
              ),
              const SizedBox(width: 5),
              Text(
                "TACTICAL INTEL",
                style: GoogleFonts.sairaStencilOne(
                  fontSize: 10.5,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1.2,
                  color: headerInk,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          _buildIntelItem(
            icon: Icons.star_rounded,
            label: "Threat Level",
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: List.generate(
                5,
                (index) => Icon(
                  Icons.star_rounded,
                  size: 13,
                  color: index < widget.kingdom.difficulty
                      ? const Color(0xFFD48806)
                      : const Color(0xFFB59A7A),
                ),
              ),
            ),
          ),
          const SizedBox(height: 4),
          _buildIntelItem(
            icon: Icons.map_outlined,
            label: "Battleground",
            child: Text(
              mapDisplayName,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: GoogleFonts.outfit(
                color: const Color(0xFF2C1607),
                fontSize: 11.5,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          const SizedBox(height: 4),
          _buildIntelItem(
            icon: Icons.psychology_outlined,
            label: "Enemy Intellect",
            child: Text(
              aiIntellect,
              style: GoogleFonts.outfit(
                color: const Color(0xFF2C1607),
                fontSize: 11.5,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          if (battleConfig?.levelConfig != null) ...[
            const SizedBox(height: 4),
            _buildIntelItem(
              icon: Icons.grid_4x4_rounded,
              label: "Grid Territory",
              child: Text(
                "${battleConfig!.levelConfig.boardWidth} × ${battleConfig.levelConfig.boardHeight} Tiles",
                style: GoogleFonts.outfit(
                  color: const Color(0xFF2C1607),
                  fontSize: 11.5,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildIntelItem({
    required IconData icon,
    required String label,
    required Widget child,
  }) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 12, color: const Color(0xFF7A4A1C)),
            const SizedBox(width: 5),
            Text(
              label,
              style: GoogleFonts.outfit(
                color: const Color(0xFF5E3A1A),
                fontSize: 11,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
        child,
      ],
    );
  }

  Widget _buildActionButtons(bool isConquered) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4.0),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Primary Battle Button
          GestureDetector(
            onTap: () {
              _playClick();
              widget.onEnterBattle();
            },
            child: Container(
              height: 42,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: isConquered
                      ? [const Color(0xFFEBA612), const Color(0xFF9E6500)]
                      : [const Color(0xFFB52424), const Color(0xFF7A1010)],
                ),
                borderRadius: BorderRadius.circular(6),
                border: Border.all(
                  color: isConquered ? const Color(0xFFFFEB99) : const Color(0xFFFF9E9E),
                  width: 1.2,
                ),
                boxShadow: [
                  BoxShadow(
                    color: (isConquered ? const Color(0xFFE5A910) : const Color(0xFF9E2424)).withValues(alpha: 0.4),
                    blurRadius: 8,
                    offset: const Offset(0, 3),
                  ),
                  const BoxShadow(
                    color: Colors.black38,
                    blurRadius: 3,
                    offset: Offset(0, 1.5),
                  ),
                ],
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    isConquered ? Icons.replay_rounded : Icons.sports_kabaddi_rounded,
                    color: isConquered ? const Color(0xFF1E1005) : Colors.white,
                    size: 16,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    isConquered ? "REPLAY BATTLE" : "MARCH TO WAR",
                    style: GoogleFonts.sairaStencilOne(
                      fontSize: 12.5,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 1.5,
                      color: isConquered ? const Color(0xFF1E1005) : Colors.white,
                    ),
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 6),

          // Withdraw / Retreat Button
          GestureDetector(
            onTap: () {
              _playClick();
              widget.onWithdraw();
            },
            child: Container(
              height: 32,
              decoration: BoxDecoration(
                color: const Color(0xFF2C1607).withValues(alpha: 0.07),
                borderRadius: BorderRadius.circular(6),
                border: Border.all(
                  color: const Color(0xFF6B3E19).withValues(alpha: 0.35),
                  width: 1.0,
                ),
              ),
              child: Center(
                child: Text(
                  "WITHDRAW",
                  style: GoogleFonts.sairaStencilOne(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 1.2,
                    color: const Color(0xFF4A280D),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
