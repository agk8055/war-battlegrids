import 'package:flutter/material.dart';
import 'dart:ui';
import '../../../core/enums/turn.dart';

class GameOverOverlay extends StatelessWidget {
  final Turn winner;
  final VoidCallback onReturnToMap;

  const GameOverOverlay({
    super.key, 
    required this.winner,
    required this.onReturnToMap,
  });

  @override
  Widget build(BuildContext context) {
    final isPlayerWin = winner == Turn.player;
    
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
                  isPlayerWin ? "VICTORY" : "DEFEAT",
                  style: TextStyle(
                    fontSize: 64,
                    fontWeight: FontWeight.w900,
                    color: isPlayerWin ? Colors.blueAccent : Colors.redAccent,
                    letterSpacing: 8.0,
                    shadows: [
                      Shadow(
                        color: isPlayerWin ? Colors.blue : Colors.red,
                        blurRadius: 20,
                      )
                    ]
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  isPlayerWin 
                      ? "The enemy kingdom has fallen to your blockade." 
                      : "Your kingdom's siege defenses have been breached.",
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
                  child: const Text("RETURN TO MAP"),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
