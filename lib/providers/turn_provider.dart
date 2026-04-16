import 'dart:isolate';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../simulation/game_simulation.dart';
import '../simulation/ai/minimax.dart';

/// Represents the state of the AI's internal thinking process.
enum AIState { idle, thinking, error }

/// A provider that exposes the AI's current state so the UI can show a loader.
final aiStateProvider = NotifierProvider<AIStateNotifier, AIState>(() {
  return AIStateNotifier();
});

class AIStateNotifier extends Notifier<AIState> {
  @override
  AIState build() => AIState.idle;

  void setThinking() => state = AIState.thinking;
  void setIdle() => state = AIState.idle;
}

/// Helper function that runs inside the Dart Isolate.
/// It MUST be a top-level or static function to work in `compute`/`Isolate.run`.
(int, int)? _runMinimaxInIsolate(Map<String, dynamic> args) {
  // We need to re-construct the GameSimulation from serialized data 
  // or pass a deeply cloned instance if it doesn't contain non-sendable types.
  // GameSimulation and Board are pure Dart classes, so they CAN be sent across Isolate ports,
  // but to be extremely safe, we should pass the GameSimulation directly.
  final GameSimulation clonedSim = args['sim'] as GameSimulation;
  final int maxDepth = args['depth'] as int;

  // Run the heavy computation
  return MinimaxAI.getBestMove(clonedSim, maxDepth);
}

class AIManager {
  static Future<(int, int)?> calculateNextMove(GameSimulation currentSim, int difficultyDepth) async {
    // We clone the simulation here because Isolates require message passing.
    // The clone method in MinimaxAI is top-level accessible or we can use it directly.
    // Wait, MinimaxAI._cloneSimulation is private. Let's just pass the real one over the isolate port.
    // Dart Isolates will natively deep-copy purely synchronous object graphs via pass-by-value.
    
    final Map<String, dynamic> args = {
      'sim': currentSim, 
      'depth': difficultyDepth,
    };

    try {
      // Spawn Isolate and await result
      final result = await Isolate.run(() => _runMinimaxInIsolate(args));
      return result;
    } catch (e) {
      // print("AI Isolate Error: $e");
      return null;
    }
  }
}
