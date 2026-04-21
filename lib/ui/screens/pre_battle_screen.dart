import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../campaign/models/kingdom_model.dart';
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
    Future.delayed(const Duration(seconds: 2), () {
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
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          // Background Banner
          Positioned.fill(
            child: Opacity(
              opacity: 0.3,
              child: Image.asset(
                'assets/images/home_banner.png',
                fit: BoxFit.cover,
              ),
            ),
          ),

          // Bottom Loading Area
          Positioned(
            bottom: 64,
            left: 0,
            right: 0,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const SizedBox(
                  width: 240,
                  child: LinearProgressIndicator(
                    backgroundColor: Colors.white10,
                    color: Colors.blueAccent,
                    minHeight: 2,
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  "ESTABLISHING FRONT LINES...",
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.5),
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 4,
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
