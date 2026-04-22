import 'dart:isolate';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../simulation/game_simulation.dart';
import '../simulation/ai/rule_engine.dart';
import '../simulation/ai/ai_strategy.dart';

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

/// Provider to track if we are in multiplayer mode.
final multiplayerModeProvider = NotifierProvider<MultiplayerModeNotifier, bool>(() {
  return MultiplayerModeNotifier();
});

class MultiplayerModeNotifier extends Notifier<bool> {
  @override
  bool build() => false;

  @override
  set state(bool value) => super.state = value;
}

/// Helper function that runs inside the Dart Isolate.
/// It MUST be a top-level or static function to work in `compute`/`Isolate.run`.
(int, int)? _runMinimaxInIsolate(Map<String, dynamic> args) {
  final GameSimulation clonedSim = args['sim'] as GameSimulation;
  final AIStrategy strategy = args['strategy'] as AIStrategy;

  // Run the heavy computation
  return RuleEngine.getBestMove(clonedSim, strategy);
}

class AIManager {
  static Future<(int, int)?> calculateNextMove(GameSimulation currentSim, AIStrategy strategy) async {
    final Map<String, dynamic> args = {
      'sim': currentSim, 
      'strategy': strategy,
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
