import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../campaign/campaign_manager.dart';
import '../../../campaign/data/kingdoms_data.dart';
import '../../../campaign/models/kingdom_model.dart';
import '../../../core/constants/app_assets.dart';
import '../../../core/enums/connection_type.dart';
import '../../../core/enums/game_mode.dart';
import '../../../core/enums/turn.dart';
import '../../../core/models/battle_stats.dart';
import '../../../core/services/audio_service.dart';
import '../../../providers/bluetooth_provider.dart';
import '../../../providers/game_settings_provider.dart';
import '../../../providers/online_provider.dart';
import '../../../providers/turn_provider.dart';

/// Floating tactical analysis overlay displayed over the final board state.
/// Allows the player to freely pan and zoom the completed match board while
/// reviewing quick stats and having an explicit Back Button to return to stats.
class FinalMapOverlay extends ConsumerStatefulWidget {
  final BattleStats stats;
  final GameMode mode;
  final bool canRematch;
  final VoidCallback onBackToStats;
  final VoidCallback? onRematch;
  final VoidCallback onContinue;

  const FinalMapOverlay({
    super.key,
    required this.stats,
    required this.mode,
    required this.canRematch,
    required this.onBackToStats,
    this.onRematch,
    required this.onContinue,
  });

  @override
  ConsumerState<FinalMapOverlay> createState() => _FinalMapOverlayState();
}

class _FinalMapOverlayState extends ConsumerState<FinalMapOverlay>
    with SingleTickerProviderStateMixin {
  late AnimationController _fadeController;
  late Animation<double> _fadeAnim;

  @override
  void initState() {
    super.initState();
    _fadeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );
    _fadeAnim = CurvedAnimation(parent: _fadeController, curve: Curves.easeOut);
    _fadeController.forward();
  }

  @override
  void dispose() {
    _fadeController.dispose();
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

    final KingdomModel? currentKingdom = (widget.mode == GameMode.story &&
            campaignState.selectedKingdomId != null)
        ? kKingdoms.firstWhere((k) => k.id == campaignState.selectedKingdomId)
        : null;

    Color primaryColor;
    String outcomeHeader;

    if (isDraw) {
      outcomeHeader = "STALEMATE";
      primaryColor = const Color(0xFFFFB74D);
    } else if (isSameDevice) {
      final winnerName = widget.stats.winner == Turn.player
          ? settings.player1Name
          : settings.player2Name;
      outcomeHeader = "${winnerName.toUpperCase()} WON";
      primaryColor = widget.stats.winner == Turn.player
          ? Color(settings.player1Color)
          : Color(settings.player2Color);
    } else {
      if (isLocalPlayerWin) {
        outcomeHeader = "VICTORY";
        primaryColor = const Color(0xFF00E676);
      } else {
        outcomeHeader = "DEFEAT";
        primaryColor = const Color(0xFFFF5252);
      }
    }

    final p1Name = settings.player1Name.toUpperCase();
    final p1Symbol = settings.player1Symbol;
    final p1Color = Color(settings.player1Color);

    final String p2Name;
    final String p2Symbol;
    final Color p2Color;

    if (isMultiplayer) {
      p2Name = settings.player2Name.toUpperCase();
      p2Symbol = settings.player2Symbol;
      p2Color = Color(settings.player2Color);
    } else {
      p2Name = currentKingdom?.name.toUpperCase() ?? "ENEMY";
      p2Symbol = currentKingdom?.symbolAsset ?? AppAssets.eagle;
      p2Color = currentKingdom?.primaryColor ?? const Color(0xFFFF5252);
    }

    final continueLabel = isMultiplayer
        ? (isSameDevice ? "RETURN TO MENU" : "RETURN TO LOBBY")
        : (widget.mode == GameMode.story ? "CONTINUE" : "RETURN TO MAP");

    return FadeTransition(
      opacity: _fadeAnim,
      child: Stack(
        fit: StackFit.expand,
        children: [
          // 1. TOP BAR: Prominent Back Button & Match Summary
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: SafeArea(
              bottom: false,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                child: Center(
                  child: Container(
                    constraints: const BoxConstraints(maxWidth: 920),
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                    decoration: BoxDecoration(
                      color: const Color(0xFF13100C).withValues(alpha: 0.94),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: primaryColor.withValues(alpha: 0.45),
                        width: 1.2,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.65),
                          blurRadius: 18,
                          offset: const Offset(0, 4),
                        ),
                        BoxShadow(
                          color: primaryColor.withValues(alpha: 0.12),
                          blurRadius: 16,
                        ),
                      ],
                    ),
                    child: Row(
                      children: [
                        // Prominent Back Button (Takes user back to stats screen)
                        Material(
                          color: Colors.transparent,
                          child: InkWell(
                            onTap: () {
                              ref.read(audioServiceProvider).playSfx(AppAssets.sfxClick);
                              widget.onBackToStats();
                            },
                            borderRadius: BorderRadius.circular(8),
                            child: Container(
                              height: 36,
                              padding: const EdgeInsets.symmetric(horizontal: 10),
                              decoration: BoxDecoration(
                                color: const Color(0xFF4FC3F7).withValues(alpha: 0.15),
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(
                                  color: const Color(0xFF4FC3F7).withValues(alpha: 0.6),
                                  width: 1.1,
                                ),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Icon(
                                    Icons.arrow_back_ios_new_rounded,
                                    size: 14,
                                    color: Color(0xFF4FC3F7),
                                  ),
                                  const SizedBox(width: 5),
                                  Text(
                                    "BACK",
                                    style: GoogleFonts.sairaStencilOne(
                                      color: const Color(0xFF4FC3F7),
                                      fontSize: 11.5,
                                      fontWeight: FontWeight.bold,
                                      letterSpacing: 1.0,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),

                        // Title and quick stats
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Row(
                                children: [
                                  Flexible(
                                    child: Text(
                                      "FINAL MAP ANALYSIS",
                                      overflow: TextOverflow.ellipsis,
                                      style: GoogleFonts.sairaStencilOne(
                                        color: Colors.white,
                                        fontSize: 12.5,
                                        fontWeight: FontWeight.bold,
                                        letterSpacing: 1.2,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 6),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFF00E5FF).withValues(alpha: 0.15),
                                      borderRadius: BorderRadius.circular(4),
                                      border: Border.all(
                                        color: const Color(0xFF00E5FF).withValues(alpha: 0.4),
                                        width: 0.8,
                                      ),
                                    ),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: const [
                                        Icon(Icons.visibility_outlined, size: 9, color: Color(0xFF00E5FF)),
                                        SizedBox(width: 3),
                                        Text(
                                          "VIEW ONLY",
                                          style: TextStyle(
                                            color: Color(0xFF00E5FF),
                                            fontSize: 8,
                                            fontWeight: FontWeight.bold,
                                            letterSpacing: 0.6,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 2),
                              // Subtitle with commanders
                              SingleChildScrollView(
                                scrollDirection: Axis.horizontal,
                                child: Row(
                                  children: [
                                    Container(
                                      width: 12,
                                      height: 12,
                                      decoration: BoxDecoration(
                                        shape: BoxShape.circle,
                                        color: p1Color.withValues(alpha: 0.2),
                                        border: Border.all(color: p1Color.withValues(alpha: 0.8), width: 0.8),
                                      ),
                                      padding: const EdgeInsets.all(1.5),
                                      child: AppAssetImage(p1Symbol, color: p1Color),
                                    ),
                                    const SizedBox(width: 3),
                                    Text(
                                      "$p1Name: ${widget.stats.playerScore} pts",
                                      style: TextStyle(
                                        color: p1Color,
                                        fontSize: 9.5,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                    const SizedBox(width: 6),
                                    Text("•", style: TextStyle(color: Colors.white.withValues(alpha: 0.35), fontSize: 9.5)),
                                    const SizedBox(width: 6),
                                    Container(
                                      width: 12,
                                      height: 12,
                                      decoration: BoxDecoration(
                                        shape: BoxShape.circle,
                                        color: p2Color.withValues(alpha: 0.2),
                                        border: Border.all(color: p2Color.withValues(alpha: 0.8), width: 0.8),
                                      ),
                                      padding: const EdgeInsets.all(1.5),
                                      child: AppAssetImage(p2Symbol, color: p2Color),
                                    ),
                                    const SizedBox(width: 3),
                                    Text(
                                      "$p2Name: ${widget.stats.opponentScore} pts",
                                      style: TextStyle(
                                        color: p2Color,
                                        fontSize: 9.5,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                    const SizedBox(width: 6),
                                    Text("•", style: TextStyle(color: Colors.white.withValues(alpha: 0.35), fontSize: 9.5)),
                                    const SizedBox(width: 6),
                                    Text(
                                      "${widget.stats.totalTurns} Turns  (${widget.stats.formattedDuration})",
                                      style: TextStyle(
                                        color: Colors.white.withValues(alpha: 0.6),
                                        fontSize: 9.5,
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 8),

                        // Outcome Badge
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: primaryColor.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(color: primaryColor.withValues(alpha: 0.5), width: 1),
                          ),
                          child: Text(
                            outcomeHeader,
                            style: GoogleFonts.sairaStencilOne(
                              color: primaryColor,
                              fontSize: 10.5,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 1.0,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),

          // 2. BOTTOM BAR: Pan & Zoom Hint and Quick Actions
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: SafeArea(
              top: false,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                child: Center(
                  child: Container(
                    constraints: const BoxConstraints(maxWidth: 620),
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(
                      color: const Color(0xFF13100C).withValues(alpha: 0.94),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                        color: Colors.white.withValues(alpha: 0.15),
                        width: 1,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.7),
                          blurRadius: 20,
                          offset: const Offset(0, 6),
                        ),
                      ],
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // Interaction Helper Text
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.touch_app_outlined, size: 12, color: Colors.white.withValues(alpha: 0.45)),
                            const SizedBox(width: 5),
                            Text(
                              "Drag to move map  •  Pinch to zoom",
                              style: TextStyle(
                                color: Colors.white.withValues(alpha: 0.55),
                                fontSize: 9.5,
                                letterSpacing: 0.6,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 6),

                        // Action Buttons
                        Row(
                          children: [
                            // Back to Stats Button
                            Expanded(
                              flex: 4,
                              child: _buildFooterButton(
                                icon: Icons.analytics_outlined,
                                label: "BACK TO STATS",
                                color: const Color(0xFF4FC3F7),
                                backgroundColor: const Color(0xFF4FC3F7).withValues(alpha: 0.12),
                                borderColor: const Color(0xFF4FC3F7).withValues(alpha: 0.55),
                                onTap: () {
                                  ref.read(audioServiceProvider).playSfx(AppAssets.sfxClick);
                                  widget.onBackToStats();
                                },
                              ),
                            ),
                            const SizedBox(width: 6),

                            // Rematch Button (if eligible)
                            if (widget.canRematch && widget.onRematch != null) ...[
                              Expanded(
                                flex: 3,
                                child: _buildFooterButton(
                                  icon: Icons.refresh,
                                  label: "REMATCH",
                                  color: Colors.amberAccent,
                                  backgroundColor: Colors.amber.withValues(alpha: 0.12),
                                  borderColor: Colors.amberAccent.withValues(alpha: 0.55),
                                  onTap: () {
                                    ref.read(audioServiceProvider).playSfx(AppAssets.sfxClick);
                                    widget.onRematch!();
                                  },
                                ),
                              ),
                              const SizedBox(width: 6),
                            ],

                            // Continue / Exit Button
                            Expanded(
                              flex: 4,
                              child: _buildFooterButton(
                                icon: Icons.arrow_forward,
                                label: continueLabel,
                                color: Colors.black,
                                backgroundColor: primaryColor,
                                borderColor: primaryColor,
                                isPrimary: true,
                                onTap: () {
                                  ref.read(audioServiceProvider).playSfx(AppAssets.sfxClick);
                                  widget.onContinue();
                                },
                              ),
                            ),
                          ],
                        ),
                      ],
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

  Widget _buildFooterButton({
    required IconData icon,
    required String label,
    required Color color,
    required Color backgroundColor,
    required Color borderColor,
    required VoidCallback onTap,
    bool isPrimary = false,
  }) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Container(
        height: 38,
        padding: const EdgeInsets.symmetric(horizontal: 8),
        decoration: BoxDecoration(
          color: backgroundColor,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: borderColor, width: 1.1),
          boxShadow: isPrimary
              ? [
                  BoxShadow(
                    color: color.withValues(alpha: 0.3),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ]
              : [],
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          mainAxisSize: MainAxisSize.max,
          children: [
            Icon(icon, size: 14, color: color),
            const SizedBox(width: 4),
            Flexible(
              child: Text(
                label,
                overflow: TextOverflow.ellipsis,
                style: GoogleFonts.sairaStencilOne(
                  color: color,
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 0.8,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
