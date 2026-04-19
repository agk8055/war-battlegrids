import 'package:flutter/material.dart';
import 'dart:ui';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/enums/turn.dart';
import '../../../core/enums/game_mode.dart';
import '../../../providers/game_settings_provider.dart';

class GameOverOverlay extends ConsumerWidget {
  final Turn winner;
  final GameMode mode;
  final VoidCallback onReturnToMap;

  const GameOverOverlay({
    super.key, 
    required this.winner,
    required this.mode,
    required this.onReturnToMap,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isPlayer1Win = winner == Turn.player;
    final isMultiplayer = mode == GameMode.multiplayer;
    final settings = ref.watch(gameSettingsProvider);

    String title;
    String subtitle;

    if (isMultiplayer) {
      final winnerName = isPlayer1Win ? settings.player1Name : settings.player2Name;
      title = "${winnerName.toUpperCase()} VICTORIOUS";
      subtitle = "The battle is won. $winnerName claims dominance.";
    } else {
      title = isPlayer1Win ? "VICTORY" : "DEFEAT";
      subtitle = isPlayer1Win 
          ? "The enemy kingdom has fallen to your blockade." 
          : "Your kingdom's siege defenses have been breached.";
    }
    
    return Positioned.fill(
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 5.0, sigmaY: 5.0),
        child: Container(
          color: Colors.black.withValues(alpha: 0.6),
          child: Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  title,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: isMultiplayer ? 48 : 64,
                    fontWeight: FontWeight.w900,
                    color: isPlayer1Win ? Colors.blueAccent : Colors.redAccent,
                    letterSpacing: isMultiplayer ? 4.0 : 8.0,
                    shadows: [
                      Shadow(
                        color: isPlayer1Win ? Colors.blue : Colors.red,
                        blurRadius: 20,
                      )
                    ]
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  subtitle,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 20,
                    color: Colors.white70,
                    fontStyle: FontStyle.italic,
                  ),
                ),
                const SizedBox(height: 48),
                ElevatedButton(
                  onPressed: onReturnToMap,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.white,
                    foregroundColor: Colors.black,
                    padding: const EdgeInsets.symmetric(horizontal: 48, vertical: 16),
                    textStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
                    elevation: 10,
                  ),
                  child: Text(isMultiplayer ? "RETURN TO MENU" : "RETURN TO MAP"),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
