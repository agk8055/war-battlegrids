import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../campaign/models/kingdom_model.dart';
import '../../campaign/data/battle_configs.dart';
import 'game_screen.dart';

class PreBattleScreen extends ConsumerStatefulWidget {
  final KingdomModel kingdom;

  const PreBattleScreen({super.key, required this.kingdom});

  @override
  ConsumerState<PreBattleScreen> createState() => _PreBattleScreenState();
}

class _PreBattleScreenState extends ConsumerState<PreBattleScreen> {
  @override
  void initState() {
    super.initState();
    // Automatically transition to game after a short delay
    Future.delayed(const Duration(seconds: 3), () {
      if (mounted) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (context) => const GameScreen()),
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final battleConfig = kBattleConfigs[widget.kingdom.id];

    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          // Background Banner
          Positioned.fill(
            child: Opacity(
              opacity: 0.3,
              child: Image.asset(
                widget.kingdom.bannerAsset,
                fit: BoxFit.cover,
              ),
            ),
          ),

          // Content
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            bottom: 250, // Push up to avoid overlap with bottom info
            child: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    widget.kingdom.name.toUpperCase(),
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 42,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 8,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    "BATTLEFRONT",
                    style: TextStyle(
                      color: Colors.blueAccent.withValues(alpha: 0.8),
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 4,
                    ),
                  ),
                ],
              ),
            ),
          ),

          // Bottom Loading Area & Insight
          Positioned(
            bottom: 40,
            left: 60,
            right: 60,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (battleConfig?.insight != null) ...[
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 20),
                    decoration: BoxDecoration(
                      color: Colors.black54,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.white10),
                    ),
                    child: Column(
                      children: [
                        Text(
                          "TACTICAL INSIGHT",
                          style: TextStyle(
                            color: Colors.blueAccent[100],
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 2,
                          ),
                        ),
                        const SizedBox(height: 12),
                        Text(
                          battleConfig!.insight!,
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            color: Colors.white70,
                            fontSize: 14,
                            fontStyle: FontStyle.italic,
                            height: 1.5,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 40),
                ],
                Text(
                  "ESTABLISHING FRONT LINES...",
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.5),
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 4,
                  ),
                ),
                const SizedBox(height: 16),
                const SizedBox(
                  width: 300,
                  child: LinearProgressIndicator(
                    backgroundColor: Colors.white10,
                    color: Colors.blueAccent,
                    minHeight: 2,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
