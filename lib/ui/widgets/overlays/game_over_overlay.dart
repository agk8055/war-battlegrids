import 'package:flutter/material.dart';
import 'dart:ui';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/enums/turn.dart';
import '../../../core/enums/game_mode.dart';
import '../../../providers/game_settings_provider.dart';
import '../../../providers/bluetooth_provider.dart';

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
    final isMultiplayer = mode == GameMode.multiplayer;
    final isHost = ref.watch(bluetoothProvider).isHost;
    
    // In multiplayer: Turn.player is Host, Turn.ai is Joiner
    final isLocalPlayerWin = isMultiplayer 
        ? (isHost ? winner == Turn.player : winner == Turn.ai)
        : (winner == Turn.player);

    String title;
    String subtitle;

    if (isMultiplayer) {
      title = isLocalPlayerWin ? "VICTORY" : "DEFEAT";
      subtitle = isLocalPlayerWin 
          ? "You have claimed dominance over the battlefield." 
          : "Your kingdom's siege defenses have been breached.";
    } else {
      title = isLocalPlayerWin ? "VICTORY" : "DEFEAT";
      subtitle = isLocalPlayerWin 
          ? "The enemy kingdom has fallen to your blockade." 
          : "Your kingdom's siege defenses have been breached.";
    }
    
    final settings = ref.watch(gameSettingsProvider);
    final accentColor = isLocalPlayerWin ? Color(settings.player1Color) : Color(settings.player2Color);
    final glowColor = accentColor.withValues(alpha: 0.5);

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
                    fontSize: 64,
                    fontWeight: FontWeight.w900,
                    color: accentColor,
                    letterSpacing: 8.0,
                    shadows: [
                      Shadow(
                        color: glowColor,
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
