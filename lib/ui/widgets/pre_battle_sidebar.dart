import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../campaign/models/kingdom_model.dart';
import '../../campaign/data/battle_configs.dart';

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

    return Container(
      margin: const EdgeInsets.all(20),
      width: MediaQuery.of(context).size.width * 0.35,
      height: double.infinity,
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: Colors.grey[900],
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.white24, width: 2),
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
            flex: 2,
            child: Stack(
              children: [
                Positioned.fill(
                  child: Image.asset(
                    'assets/images/home_banner.png', // Placeholder
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
                  bottom: 20,
                  left: 20,
                  right: 20,
                  child: Text(
                    kingdom.name.toUpperCase(),
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 28,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 4,
                    ),
                  ),
                ),
              ],
            ),
          ),

          // Lore & Stats
          Expanded(
            flex: 3,
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    "LORE",
                    style: TextStyle(
                      color: Colors.blueAccent[100],
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
                      color: Colors.blueAccent[100],
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 2,
                    ),
                  ),
                  const SizedBox(height: 16),
                  _buildStatRow("Difficulty", "⭐" * kingdom.difficulty),
                  _buildStatRow("Board Size", "${battleConfig?.levelConfig.boardWidth}x${battleConfig?.levelConfig.boardHeight}"),
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
                    backgroundColor: Colors.blueAccent,
                    foregroundColor: Colors.white,
                    minimumSize: const Size(double.infinity, 56),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                  child: const Text(
                    "ENTER BATTLE",
                    style: TextStyle(fontWeight: FontWeight.bold, letterSpacing: 1.5),
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
