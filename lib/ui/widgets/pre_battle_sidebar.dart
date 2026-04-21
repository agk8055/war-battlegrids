import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../campaign/models/kingdom_model.dart';
import '../../campaign/data/battle_configs.dart';
import '../../campaign/campaign_manager.dart';

class PreBattleSidebar extends ConsumerWidget {
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
  Widget build(BuildContext context, WidgetRef ref) {
    final battleConfig = kBattleConfigs[kingdom.id];
    final campaignState = ref.watch(campaignProvider);
    final bool isConquered = campaignState.isConquered(kingdom.id);
    const Color customYellow = Color(0xFFFCB103);

    return Container(
      margin: const EdgeInsets.all(20),
      width: MediaQuery.of(context).size.width * 0.35,
      height: double.infinity,
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: Colors.grey[900],
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: isConquered ? customYellow.withValues(alpha: 0.3) : Colors.white24, width: 2),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.6),
            blurRadius: 30,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Header with Kingdom Banner/Image
          Expanded(
            flex: 3, // Increased flex for more vertical space
            child: Stack(
              children: [
                Positioned.fill(
                  child: Image.asset(
                    kingdom.bannerAsset,
                    fit: BoxFit.cover,
                    opacity: const AlwaysStoppedAnimation(0.3),
                  ),
                ),
                Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [Colors.transparent, Colors.grey[900]!],
                    ),
                  ),
                ),
                Positioned(
                  bottom: 16, // Adjusted bottom offset
                  left: 20,
                  right: 20,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      FittedBox(
                        fit: BoxFit.scaleDown,
                        alignment: Alignment.centerLeft,
                        child: Text(
                          kingdom.name.toUpperCase(),
                          maxLines: 1,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 28,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 4,
                          ),
                        ),
                      ),
                      if (isConquered) ...[
                        const SizedBox(height: 6), // Reduced gap
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2), // Compact padding
                          decoration: BoxDecoration(
                            color: customYellow,
                            borderRadius: BorderRadius.circular(4),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: 0.3),
                                blurRadius: 4,
                                offset: const Offset(0, 2),
                              ),
                            ],
                          ),
                          child: const Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.stars, color: Colors.black, size: 10), // Smaller icon
                              SizedBox(width: 4),
                              Text(
                                "CONQUERED",
                                style: TextStyle(
                                  color: Colors.black,
                                  fontSize: 9, // Smaller font
                                  fontWeight: FontWeight.bold,
                                  letterSpacing: 0.5,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ),

          // Lore & Stats
          Expanded(
            flex: 4, // Balanced flex for content
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    "LORE",
                    style: TextStyle(
                      color: isConquered ? customYellow : Colors.blueAccent[100],
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 2,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    kingdom.lore,
                    style: TextStyle(
                      color: Colors.grey[400],
                      fontSize: 14,
                      fontStyle: FontStyle.italic,
                      height: 1.5,
                    ),
                  ),
                  const SizedBox(height: 32),
                  Text(
                    "INTELLIGENCE",
                    style: TextStyle(
                      color: isConquered ? customYellow : Colors.blueAccent[100],
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 2,
                    ),
                  ),
                  const SizedBox(height: 16),
                  _buildStatRow("Status", isConquered ? "Conquered" : "Active"),
                  _buildStatRow("Difficulty", "⭐" * kingdom.difficulty),
                  _buildStatRow("Map", battleConfig?.mapPath.replaceAll('.tmx', '').replaceAll('_', ' ').toUpperCase() ?? "Unknown"),
                  _buildStatRow("AI Intellect", battleConfig?.aiStrategy.displayName ?? "Novice"),
                ],
              ),
            ),
          ),

          // Actions
          Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              children: [
                ElevatedButton(
                  onPressed: onEnterBattle,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: isConquered ? customYellow : Colors.blueAccent,
                    foregroundColor: isConquered ? Colors.black : Colors.white,
                    minimumSize: const Size(double.infinity, 56),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                  child: Text(
                    isConquered ? "REPLAY BATTLE" : "ENTER BATTLE",
                    style: const TextStyle(fontWeight: FontWeight.bold, letterSpacing: 1.5),
                  ),
                ),
                const SizedBox(height: 12),
                OutlinedButton(
                  onPressed: onWithdraw,
                  style: OutlinedButton.styleFrom(
                    side: const BorderSide(color: Colors.white38),
                    foregroundColor: Colors.white70,
                    minimumSize: const Size(double.infinity, 56),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                  child: const Text("WITHDRAW"),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(color: Colors.white54, fontSize: 13)),
          Text(value, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13)),
        ],
      ),
    );
  }
}
