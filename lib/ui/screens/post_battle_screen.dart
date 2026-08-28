import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../core/constants/app_assets.dart';
import '../../core/models/battle_stats.dart';
import '../../campaign/campaign_manager.dart';
import '../../campaign/data/kingdoms_data.dart';
import '../../campaign/models/kingdom_model.dart';
import '../../providers/game_settings_provider.dart';
import '../../providers/bluetooth_provider.dart';
import '../../providers/online_provider.dart';
import '../../providers/turn_provider.dart';
import '../../core/enums/game_mode.dart';
import '../../core/enums/connection_type.dart';
import '../../core/enums/turn.dart';
import '../../core/services/audio_service.dart';

class PostBattleScreen extends ConsumerStatefulWidget {
  final BattleStats stats;
  final GameMode mode;
  final VoidCallback onContinue;
  final VoidCallback? onRematch;
  final VoidCallback? onViewMap;

  const PostBattleScreen({
    super.key,
    required this.stats,
    required this.mode,
    required this.onContinue,
    this.onRematch,
    this.onViewMap,
  });

  @override
  ConsumerState<PostBattleScreen> createState() => _PostBattleScreenState();
}

class _PostBattleScreenState extends ConsumerState<PostBattleScreen>
    with TickerProviderStateMixin {
  late AnimationController _fadeController;
  late AnimationController _slideController;
  late AnimationController _pulseController;
  late AnimationController _progressController;

  late Animation<double> _fadeAnim;
  late Animation<Offset> _slideAnim;
  late Animation<double> _pulseAnim;
  late Animation<double> _progressAnim;

  @override
  void initState() {
    super.initState();

    _fadeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );

    _slideController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 550),
    );

    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2000),
    )..repeat(reverse: true);

    _progressController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    );

    _fadeAnim = CurvedAnimation(parent: _fadeController, curve: Curves.easeIn);
    _slideAnim = Tween<Offset>(
      begin: const Offset(0, 0.04),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _slideController, curve: Curves.easeOutCubic));
    _pulseAnim = Tween<double>(begin: 0.96, end: 1.04)
        .animate(CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut));
    _progressAnim = CurvedAnimation(parent: _progressController, curve: Curves.easeOutQuart);

    _fadeController.forward();
    _slideController.forward();
    Future.delayed(const Duration(milliseconds: 300), () {
      if (mounted) _progressController.forward();
    });
  }

  @override
  void dispose() {
    _fadeController.dispose();
    _slideController.dispose();
    _pulseController.dispose();
    _progressController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final settings = ref.watch(gameSettingsProvider);
    final bluetoothState = ref.watch(bluetoothProvider);
    final onlineState = ref.watch(onlineProvider);
    final connectionType = ref.watch(connectionTypeProvider);
    final campaignState = ref.watch(campaignProvider);

    final isMultiplayer = widget.mode == GameMode.multiplayer;
    bool isHost = true;
    if (connectionType == ConnectionType.bluetooth) {
      isHost = bluetoothState.isHost;
    } else if (connectionType == ConnectionType.online) {
      isHost = onlineState.isHost;
    }

    final isBluetooth = connectionType == ConnectionType.bluetooth;
    final isOnline = connectionType == ConnectionType.online;
    final isSameDevice = isMultiplayer && !isBluetooth && !isOnline;

    final isLocalPlayerWin = isMultiplayer
        ? (isHost ? widget.stats.winner == Turn.player : widget.stats.winner == Turn.ai)
        : (widget.stats.winner == Turn.player);

    final isDraw = widget.stats.isDraw;

    // Kingdom in story mode
    final KingdomModel? currentKingdom = (widget.mode == GameMode.story &&
            campaignState.selectedKingdomId != null)
        ? kKingdoms.firstWhere((k) => k.id == campaignState.selectedKingdomId)
        : null;

    // Primary Colors & Titles
    Color primaryColor;
    String outcomeHeader;

    if (isDraw) {
      outcomeHeader = "STALEMATE OF STEEL";
      primaryColor = const Color(0xFFFFB74D); // Amber
    } else if (isSameDevice) {
      final winnerName = widget.stats.winner == Turn.player
          ? settings.player1Name
          : settings.player2Name;
      outcomeHeader = "${winnerName.toUpperCase()} VICTORIOUS";
      primaryColor = widget.stats.winner == Turn.player
          ? Color(settings.player1Color)
          : Color(settings.player2Color);
    } else {
      if (isLocalPlayerWin) {
        outcomeHeader = "YOU ARE THE VICTOR";
        primaryColor = const Color(0xFF00E676); // Emerald Green
      } else {
        outcomeHeader = "DEFEAT ON THE FIELD";
        primaryColor = const Color(0xFFFF5252); // Crimson Red
      }
    }

    // Player 1 (You / Host / Bottom)
    final p1Name = settings.player1Name.toUpperCase();
    final p1Symbol = settings.player1Symbol;
    final p1Color = Color(settings.player1Color);

    // Player 2 (Opponent / AI / Peer)
    final String p2Name;
    final String p2Symbol;
    final Color p2Color;

    if (isMultiplayer) {
      p2Name = settings.player2Name.toUpperCase();
      p2Symbol = settings.player2Symbol;
      p2Color = Color(settings.player2Color);
    } else {
      p2Name = currentKingdom?.name.toUpperCase() ?? "ENEMY REALM";
      p2Symbol = currentKingdom?.symbolAsset ?? AppAssets.eagle;
      p2Color = currentKingdom?.primaryColor ?? const Color(0xFFFF5252);
    }

    // Continue action label
    final continueLabel = isMultiplayer
        ? (isSameDevice ? "RETURN TO MENU" : "RETURN TO LOBBY")
        : (widget.mode == GameMode.story ? "CONTINUE" : "RETURN TO MAP");

    // XP Breakdown calculations
    final winBonus = isLocalPlayerWin ? 2500 : (isDraw ? 800 : 400);
    final captureBonus = widget.stats.playerCapturedUnits * 150;
    final comboBonus = widget.stats.playerMaxCombo * 200;
    final territoryBonus = (widget.stats.playerTerritoryPercent * 15).toInt();
    final siegeBonus = widget.stats.playerSiegeBreached ? 500 : 0;
    final totalHonorXp = winBonus + captureBonus + comboBonus + territoryBonus + siegeBonus;

    return Scaffold(
      backgroundColor: const Color(0xFF0B0907),
      body: Stack(
        children: [
          // Background ambient gradient
          Positioned.fill(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: RadialGradient(
                  center: const Alignment(0, -0.3),
                  radius: 1.2,
                  colors: [
                    primaryColor.withValues(alpha: 0.14),
                    const Color(0xFF0B0907),
                  ],
                ),
              ),
            ),
          ),

          // Story Mode Artwork Backdrop
          if (currentKingdom?.bannerAsset != null)
            Positioned.fill(
              child: Opacity(
                opacity: 0.08,
                child: AppAssetImage(
                  currentKingdom!.bannerAsset,
                  fit: BoxFit.cover,
                ),
              ),
            ),

          SafeArea(
            child: FadeTransition(
              opacity: _fadeAnim,
              child: SlideTransition(
                position: _slideAnim,
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    final isNarrow = constraints.maxWidth < 750;
                    return Center(
                      child: SingleChildScrollView(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                        child: Container(
                          constraints: const BoxConstraints(maxWidth: 920),
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                              colors: [
                                Color(0xFF191510),
                                Color(0xFF0F0D0A),
                              ],
                            ),
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(
                              color: primaryColor.withValues(alpha: 0.35),
                              width: 1.2,
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: 0.65),
                                blurRadius: 28,
                                offset: const Offset(0, 8),
                              ),
                              BoxShadow(
                                color: primaryColor.withValues(alpha: 0.08),
                                blurRadius: 30,
                                spreadRadius: 2,
                              ),
                            ],
                          ),
                          child: Stack(
                            children: [
                              // Hatching
                              Positioned.fill(
                                child: ClipRRect(
                                  borderRadius: BorderRadius.circular(16),
                                  child: CustomPaint(
                                    painter: _HatchPainter(
                                      color: Colors.white.withValues(alpha: 0.015),
                                    ),
                                  ),
                                ),
                              ),
                              // Content
                              Padding(
                                padding: const EdgeInsets.all(16),
                                child: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  crossAxisAlignment: CrossAxisAlignment.stretch,
                                  children: [
                                    // 1. Compact Header Bar
                                    _buildCompactHeader(
                                      outcomeHeader: outcomeHeader,
                                      primaryColor: primaryColor,
                                      symbol: p1Symbol,
                                      currentKingdom: currentKingdom,
                                      isLocalPlayerWin: isLocalPlayerWin,
                                    ),
                                    const SizedBox(height: 12),

                                    // 2. Main 2-Column Dashboard
                                    if (isNarrow) ...[
                                      _buildLeftSummarySection(
                                        primaryColor: primaryColor,
                                        winBonus: winBonus,
                                        captureBonus: captureBonus,
                                        comboBonus: comboBonus,
                                        territoryBonus: territoryBonus,
                                        siegeBonus: siegeBonus,
                                        totalHonorXp: totalHonorXp,
                                        campaign: campaignState,
                                        isWin: isLocalPlayerWin,
                                      ),
                                      const SizedBox(height: 12),
                                      _buildRightHeadToHeadCard(
                                        p1Name: p1Name,
                                        p1Symbol: p1Symbol,
                                        p1Color: p1Color,
                                        p2Name: p2Name,
                                        p2Symbol: p2Symbol,
                                        p2Color: p2Color,
                                        primaryColor: primaryColor,
                                        continueLabel: continueLabel,
                                      ),
                                    ] else ...[
                                      Row(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          // Left 52% - Match Summary & XP Breakdown
                                          Expanded(
                                            flex: 52,
                                            child: _buildLeftSummarySection(
                                              primaryColor: primaryColor,
                                              winBonus: winBonus,
                                              captureBonus: captureBonus,
                                              comboBonus: comboBonus,
                                              territoryBonus: territoryBonus,
                                              siegeBonus: siegeBonus,
                                              totalHonorXp: totalHonorXp,
                                              campaign: campaignState,
                                              isWin: isLocalPlayerWin,
                                            ),
                                          ),
                                          const SizedBox(width: 12),
                                          // Right 48% - Head-to-Head Stats (Player vs Opponent) & Actions
                                          Expanded(
                                            flex: 48,
                                            child: _buildRightHeadToHeadCard(
                                              p1Name: p1Name,
                                              p1Symbol: p1Symbol,
                                              p1Color: p1Color,
                                              p2Name: p2Name,
                                              p2Symbol: p2Symbol,
                                              p2Color: p2Color,
                                              primaryColor: primaryColor,
                                              continueLabel: continueLabel,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ],
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ───────────────────────────────────────────────────────────────────────────
  //  1. Compact Header Bar
  // ───────────────────────────────────────────────────────────────────────────
  Widget _buildCompactHeader({
    required String outcomeHeader,
    required Color primaryColor,
    required String symbol,
    required KingdomModel? currentKingdom,
    required bool isLocalPlayerWin,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: const Color(0xFF13100C),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: primaryColor.withValues(alpha: 0.25), width: 1),
      ),
      child: Row(
        children: [
          // Logo / Sigil Icon badge
          Container(
            width: 36,
            height: 36,
            padding: const EdgeInsets.all(7),
            decoration: BoxDecoration(
              color: primaryColor.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: primaryColor.withValues(alpha: 0.4)),
            ),
            child: AppAssetImage(symbol, color: primaryColor),
          ),
          const SizedBox(width: 10),

          // Outcome Banner Pill
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(
              color: primaryColor.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(6),
              border: Border.all(color: primaryColor.withValues(alpha: 0.5), width: 1),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                AnimatedBuilder(
                  animation: _pulseAnim,
                  builder: (_, __) => Transform.scale(
                    scale: _pulseAnim.value,
                    child: Icon(
                      isLocalPlayerWin ? Icons.workspace_premium : Icons.shield_outlined,
                      color: primaryColor,
                      size: 15,
                    ),
                  ),
                ),
                const SizedBox(width: 6),
                Text(
                  outcomeHeader,
                  style: GoogleFonts.sairaStencilOne(
                    color: primaryColor,
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 1.4,
                  ),
                ),
              ],
            ),
          ),

          const Spacer(),

          // Metadata Tags (Pills)
          Wrap(
            spacing: 6,
            runSpacing: 4,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              _buildHeaderPill(
                Icons.castle_outlined,
                currentKingdom?.name.toUpperCase() ??
                    (widget.mode == GameMode.multiplayer ? "MULTIPLAYER" : "SKIRMISH"),
              ),
              _buildHeaderPill(Icons.timer_outlined, widget.stats.formattedDuration),
              _buildHeaderPill(Icons.swap_horiz, "${widget.stats.totalTurns} TURNS"),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildHeaderPill(IconData icon, String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: Colors.white.withValues(alpha: 0.12)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: Colors.white70),
          const SizedBox(width: 4),
          Text(
            label,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 10,
              fontWeight: FontWeight.bold,
              letterSpacing: 0.8,
            ),
          ),
        ],
      ),
    );
  }

  // ───────────────────────────────────────────────────────────────────────────
  //  2. Left Section (XP Breakdown + Rewards/Badges + Total XP Bar)
  // ───────────────────────────────────────────────────────────────────────────
  Widget _buildLeftSummarySection({
    required Color primaryColor,
    required int winBonus,
    required int captureBonus,
    required int comboBonus,
    required int territoryBonus,
    required int siegeBonus,
    required int totalHonorXp,
    required CampaignState campaign,
    required bool isWin,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Section Title
        Row(
          children: [
            Container(width: 3.5, height: 13, color: primaryColor),
            const SizedBox(width: 7),
            Text(
              "MATCH SUMMARY",
              style: GoogleFonts.sairaStencilOne(
                color: Colors.white,
                fontSize: 13,
                letterSpacing: 1.8,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),

        // SubCard with Breakdown & Rewards
        _buildSubCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                "HONOR / XP BREAKDOWN",
                style: TextStyle(
                  color: primaryColor,
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1.4,
                ),
              ),
              const SizedBox(height: 8),
              _buildXpRow("Victory Achieved", "+$winBonus", isHighlighted: isWin),
              _buildXpRow(
                "Captured Units (${widget.stats.playerCapturedUnits})",
                "+$captureBonus",
              ),
              _buildXpRow(
                "Max Strike Combo (x${widget.stats.playerMaxCombo})",
                "+$comboBonus",
              ),
              _buildXpRow(
                "Territory Dom. (${widget.stats.playerTerritoryPercent.toStringAsFixed(0)}%)",
                "+$territoryBonus",
              ),
              if (widget.stats.playerSiegeBreached)
                _buildXpRow("Siege Breached", "+$siegeBonus", isHighlighted: true),
              _buildXpRow(
                "Combat Duration (${widget.stats.formattedDuration})",
                "+${widget.stats.playerMoves * 20}",
              ),

              const Divider(color: Colors.white12, height: 14),

              // Tactical Resolution Row
              Row(
                children: [
                  Icon(Icons.flag_outlined, size: 13, color: primaryColor),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      widget.stats.winConditionDescription,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 10.5,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 8),

              // Rewards & Badges Chips
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: [
                  _buildRewardBadge(
                    iconText: "🪙",
                    label: "+$totalHonorXp",
                    sublabel: "HONOR",
                    borderColor: Colors.amber,
                  ),
                  if (widget.mode == GameMode.story && isWin)
                    _buildRewardBadge(
                      iconText: "👑",
                      label: "REALM",
                      sublabel: "CONQUERED",
                      borderColor: primaryColor,
                    ),
                  ...widget.stats.earnedBadges.take(3).map((badge) {
                    return _buildRewardBadge(
                      iconText: badge.icon,
                      label: badge.title.split(' ').first.toUpperCase(),
                      sublabel: "BADGE",
                      borderColor: primaryColor,
                    );
                  }),
                ],
              ),
            ],
          ),
        ),

        const SizedBox(height: 8),

        // Total Honor XP Bar Card
        _buildSubCard(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          child: Column(
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    "TOTAL HONOR XP",
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.7),
                      fontSize: 9.5,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 1.5,
                    ),
                  ),
                  Text(
                    "+$totalHonorXp XP",
                    style: GoogleFonts.sairaStencilOne(
                      color: primaryColor,
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 5),
              AnimatedBuilder(
                animation: _progressAnim,
                builder: (_, __) {
                  final progress = (0.78 * _progressAnim.value).clamp(0.0, 1.0);
                  return ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: Container(
                      height: 5,
                      color: Colors.white.withValues(alpha: 0.08),
                      child: Row(
                        children: [
                          Expanded(
                            flex: (progress * 100).toInt(),
                            child: Container(
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  colors: [
                                    primaryColor.withValues(alpha: 0.7),
                                    primaryColor,
                                  ],
                                ),
                              ),
                            ),
                          ),
                          Expanded(
                            flex: ((1 - progress) * 100).toInt(),
                            child: const SizedBox(),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
              const SizedBox(height: 4),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    widget.mode == GameMode.story
                        ? "CONQUEST PROGRESS"
                        : "RANK: BATTLEMASTER",
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.4),
                      fontSize: 8.5,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  Text(
                    widget.mode == GameMode.story
                        ? "${campaign.conqueredKingdomIds.length} / ${kKingdoms.length} REALMS"
                        : "TIER IV",
                    style: TextStyle(
                      color: primaryColor,
                      fontSize: 8.5,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildSubCard({
    required Widget child,
    EdgeInsetsGeometry padding = const EdgeInsets.all(11),
  }) {
    return Container(
      padding: padding,
      decoration: BoxDecoration(
        color: const Color(0xFF13100C),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.white.withValues(alpha: 0.08), width: 1),
      ),
      child: child,
    );
  }

  Widget _buildXpRow(String label, String value, {bool isHighlighted = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(
              color: isHighlighted ? Colors.white : Colors.white.withValues(alpha: 0.75),
              fontSize: 10.5,
              fontWeight: isHighlighted ? FontWeight.w600 : FontWeight.normal,
            ),
          ),
          Text(
            value,
            style: TextStyle(
              color: isHighlighted ? const Color(0xFF00E676) : Colors.white.withValues(alpha: 0.9),
              fontSize: 10.5,
              fontWeight: FontWeight.bold,
              letterSpacing: 0.5,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRewardBadge({
    required String iconText,
    required String label,
    required String sublabel,
    required Color borderColor,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 4),
      decoration: BoxDecoration(
        color: borderColor.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: borderColor.withValues(alpha: 0.4), width: 1),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(iconText, style: const TextStyle(fontSize: 13)),
          const SizedBox(width: 4),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                label,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 8.5,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 0.5,
                ),
              ),
              Text(
                sublabel,
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.45),
                  fontSize: 6.5,
                  letterSpacing: 0.5,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ───────────────────────────────────────────────────────────────────────────
  //  3. Right Section: Head-to-Head Stats (Player vs Opponent) & Action Buttons
  // ───────────────────────────────────────────────────────────────────────────
  Widget _buildRightHeadToHeadCard({
    required String p1Name,
    required String p1Symbol,
    required Color p1Color,
    required String p2Name,
    required String p2Symbol,
    required Color p2Color,
    required Color primaryColor,
    required String continueLabel,
  }) {
    final isP1Winner = widget.stats.winner == Turn.player;
    final isP2Winner = widget.stats.winner == Turn.ai;

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFF13100C),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.white.withValues(alpha: 0.1), width: 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Dual Commander Header (Player vs Opponent)
          Row(
            children: [
              // Player 1
              Expanded(
                child: _buildCommanderSummaryTile(
                  name: p1Name,
                  symbol: p1Symbol,
                  color: p1Color,
                  isWinner: isP1Winner,
                  isLeft: true,
                ),
              ),
              // VS Badge
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.5),
                  borderRadius: BorderRadius.circular(4),
                  border: Border.all(color: primaryColor.withValues(alpha: 0.3)),
                ),
                child: Text(
                  "VS",
                  style: GoogleFonts.sairaStencilOne(
                    color: primaryColor,
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              // Player 2 / Opponent
              Expanded(
                child: _buildCommanderSummaryTile(
                  name: p2Name,
                  symbol: p2Symbol,
                  color: p2Color,
                  isWinner: isP2Winner,
                  isLeft: false,
                ),
              ),
            ],
          ),

          const SizedBox(height: 8),
          const Divider(color: Colors.white12, height: 1),
          const SizedBox(height: 8),

          // Comparative Stat Rows (Player vs Opponent)
          _buildComparisonRow(
            label: "CAPTURE SCORE",
            p1Val: "${widget.stats.playerScore}",
            p2Val: "${widget.stats.opponentScore}",
            p1Color: p1Color,
            p2Color: p2Color,
            ratio: _calcRatio(widget.stats.playerScore, widget.stats.opponentScore),
          ),
          _buildComparisonRow(
            label: "CAPTURED UNITS",
            p1Val: "${widget.stats.playerCapturedUnits}",
            p2Val: "${widget.stats.opponentCapturedUnits}",
            p1Color: p1Color,
            p2Color: p2Color,
            ratio: _calcRatio(widget.stats.playerCapturedUnits, widget.stats.opponentCapturedUnits),
          ),
          _buildComparisonRow(
            label: "UNITS DEPLOYED",
            p1Val: "${widget.stats.playerMoves}",
            p2Val: "${widget.stats.opponentMoves}",
            p1Color: p1Color,
            p2Color: p2Color,
            ratio: _calcRatio(widget.stats.playerMoves, widget.stats.opponentMoves),
          ),
          _buildComparisonRow(
            label: "MAX STRIKE COMBO",
            p1Val: "x${widget.stats.playerMaxCombo}",
            p2Val: "x${widget.stats.opponentMaxCombo}",
            p1Color: p1Color,
            p2Color: p2Color,
            ratio: _calcRatio(widget.stats.playerMaxCombo, widget.stats.opponentMaxCombo),
          ),
          _buildComparisonRow(
            label: "TERRITORY CONTROL",
            p1Val: "${widget.stats.playerTerritoryPercent.toStringAsFixed(0)}%",
            p2Val: "${widget.stats.opponentTerritoryPercent.toStringAsFixed(0)}%",
            p1Color: p1Color,
            p2Color: p2Color,
            ratio: widget.stats.playerTerritoryPercent / 100.0,
          ),
          _buildComparisonRow(
            label: "SIEGE ASSAULT",
            p1Val: widget.stats.playerSiegeBreached ? "ACTIVE" : "LOCKED",
            p2Val: widget.stats.opponentSiegeBreached ? "ACTIVE" : "LOCKED",
            p1Color: widget.stats.playerSiegeBreached ? const Color(0xFF00E676) : Colors.white60,
            p2Color: widget.stats.opponentSiegeBreached ? const Color(0xFF00E676) : Colors.white60,
            showBar: false,
          ),

          const SizedBox(height: 12),

          // Action Buttons: Rematch / View Final Map (Secondary row) + Continue / Return (Primary button)
          if (widget.onRematch != null || widget.onViewMap != null) ...[
            Row(
              children: [
                // Rematch button
                if (widget.onRematch != null) ...[
                  Expanded(
                    child: _AnimatedPressButton(
                      onTap: () {
                        ref.read(audioServiceProvider).playSfx(AppAssets.sfxClick);
                        widget.onRematch!();
                      },
                      accentColor: Colors.amberAccent,
                      child: Container(
                        height: 38,
                        decoration: BoxDecoration(
                          color: Colors.amber.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: Colors.amberAccent.withValues(alpha: 0.55),
                            width: 1.2,
                          ),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(Icons.refresh, color: Colors.amberAccent, size: 15),
                            const SizedBox(width: 4),
                            Flexible(
                              child: Text(
                                "REMATCH",
                                overflow: TextOverflow.ellipsis,
                                style: GoogleFonts.sairaStencilOne(
                                  color: Colors.amberAccent,
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold,
                                  letterSpacing: 0.8,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
                if (widget.onRematch != null && widget.onViewMap != null)
                  const SizedBox(width: 8),
                // View Final Map button
                if (widget.onViewMap != null) ...[
                  Expanded(
                    child: _AnimatedPressButton(
                      onTap: () {
                        ref.read(audioServiceProvider).playSfx(AppAssets.sfxClick);
                        widget.onViewMap!();
                      },
                      accentColor: const Color(0xFF4FC3F7),
                      child: Container(
                        height: 38,
                        decoration: BoxDecoration(
                          color: const Color(0xFF4FC3F7).withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: const Color(0xFF4FC3F7).withValues(alpha: 0.55),
                            width: 1.2,
                          ),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(Icons.map_outlined, color: Color(0xFF4FC3F7), size: 15),
                            const SizedBox(width: 4),
                            Flexible(
                              child: Text(
                                "VIEW MAP",
                                overflow: TextOverflow.ellipsis,
                                style: GoogleFonts.sairaStencilOne(
                                  color: const Color(0xFF4FC3F7),
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold,
                                  letterSpacing: 0.8,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ],
            ),
            const SizedBox(height: 8),
          ],

          // Primary CONTINUE / RETURN TO MAP button
          _AnimatedPressButton(
            onTap: () {
              ref.read(audioServiceProvider).playSfx(AppAssets.sfxClick);
              widget.onContinue();
            },
            accentColor: primaryColor,
            child: Container(
              height: 40,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    primaryColor.withValues(alpha: 0.85),
                    primaryColor,
                  ],
                ),
                borderRadius: BorderRadius.circular(8),
                boxShadow: [
                  BoxShadow(
                    color: primaryColor.withValues(alpha: 0.3),
                    blurRadius: 10,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Flexible(
                    child: Text(
                      continueLabel,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.sairaStencilOne(
                        color: Colors.black,
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 1.2,
                      ),
                    ),
                  ),
                  const SizedBox(width: 5),
                  const Icon(Icons.arrow_forward, color: Colors.black, size: 14),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCommanderSummaryTile({
    required String name,
    required String symbol,
    required Color color,
    required bool isWinner,
    required bool isLeft,
  }) {
    return Row(
      mainAxisAlignment: isLeft ? MainAxisAlignment.start : MainAxisAlignment.end,
      children: [
        if (!isLeft) ...[
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  name,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.sairaStencilOne(
                    color: isWinner ? color : Colors.white70,
                    fontSize: 11.5,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text(
                  isWinner ? "VICTOR" : "OPPONENT",
                  style: TextStyle(
                    color: color.withValues(alpha: 0.7),
                    fontSize: 8,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 1.0,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
        ],
        Container(
          width: 34,
          height: 34,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: color.withValues(alpha: 0.15),
            border: Border.all(color: color.withValues(alpha: 0.6), width: 1.2),
            boxShadow: isWinner
                ? [BoxShadow(color: color.withValues(alpha: 0.3), blurRadius: 8)]
                : [],
          ),
          padding: const EdgeInsets.all(7),
          child: AppAssetImage(symbol, color: color),
        ),
        if (isLeft) ...[
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.sairaStencilOne(
                    color: isWinner ? color : Colors.white70,
                    fontSize: 11.5,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text(
                  isWinner ? "VICTOR" : "PLAYER",
                  style: TextStyle(
                    color: color.withValues(alpha: 0.7),
                    fontSize: 8,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 1.0,
                  ),
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }

  double _calcRatio(int v1, int v2) {
    if (v1 == 0 && v2 == 0) return 0.5;
    return v1 / (v1 + v2);
  }

  Widget _buildComparisonRow({
    required String label,
    required String p1Val,
    required String p2Val,
    required Color p1Color,
    required Color p2Color,
    double ratio = 0.5,
    bool showBar = true,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2.5),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                p1Val,
                style: TextStyle(
                  color: p1Color,
                  fontSize: 10.5,
                  fontWeight: FontWeight.bold,
                ),
              ),
              Text(
                label,
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.45),
                  fontSize: 8.5,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 1.2,
                ),
              ),
              Text(
                p2Val,
                style: TextStyle(
                  color: p2Color,
                  fontSize: 10.5,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          if (showBar) ...[
            const SizedBox(height: 3),
            ClipRRect(
              borderRadius: BorderRadius.circular(2),
              child: Container(
                height: 3.5,
                color: Colors.white.withValues(alpha: 0.06),
                child: Row(
                  children: [
                    Expanded(
                      flex: (ratio.clamp(0.05, 0.95) * 100).toInt(),
                      child: Container(color: p1Color.withValues(alpha: 0.75)),
                    ),
                    Container(width: 1.5, color: Colors.black),
                    Expanded(
                      flex: ((1 - ratio.clamp(0.05, 0.95)) * 100).toInt(),
                      child: Container(color: p2Color.withValues(alpha: 0.75)),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
//  Hatch Painter & Animated Button
// ─────────────────────────────────────────────────────────────────────────────
class _HatchPainter extends CustomPainter {
  final Color color;
  const _HatchPainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = 0.6;
    const spacing = 22.0;
    for (double i = -size.height; i < size.width + size.height; i += spacing) {
      canvas.drawLine(Offset(i, 0), Offset(i + size.height, size.height), paint);
    }
  }

  @override
  bool shouldRepaint(_HatchPainter old) => old.color != color;
}

class _AnimatedPressButton extends StatefulWidget {
  final Widget child;
  final VoidCallback onTap;
  final Color accentColor;

  const _AnimatedPressButton({
    required this.child,
    required this.onTap,
    required this.accentColor,
  });

  @override
  State<_AnimatedPressButton> createState() => _AnimatedPressButtonState();
}

class _AnimatedPressButtonState extends State<_AnimatedPressButton>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _scale;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 100),
      reverseDuration: const Duration(milliseconds: 160),
    );
    _scale = Tween<double>(begin: 1.0, end: 0.96)
        .animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeInOut));
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) => _ctrl.forward(),
      onTapUp: (_) {
        _ctrl.reverse();
        widget.onTap();
      },
      onTapCancel: () => _ctrl.reverse(),
      child: ScaleTransition(scale: _scale, child: widget.child),
    );
  }
}
