import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/constants/app_assets.dart';
import '../../campaign/models/kingdom_model.dart';
import '../../campaign/data/battle_configs.dart';
import '../../providers/game_settings_provider.dart';
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
    Future.microtask(() {
      if (mounted) {
        ref.read(gameSettingsProvider.notifier).restoreCampaignSettings();
      }
    });
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
              child: AppAssetImage(
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
            bottom: 60,
            left: 40,
            right: 40,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (battleConfig?.insight != null) ...[
                  Text(
                    battleConfig!.insight!,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: Colors.white70,
                      fontSize: 16,
                      fontStyle: FontStyle.italic,
                      height: 1.5,
                    ),
                  ),
                  const SizedBox(height: 40),
                ],
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
