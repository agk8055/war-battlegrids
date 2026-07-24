import 'package:flame/game.dart';
import 'package:flame/events.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/material.dart';
import '../core/constants/app_assets.dart';
import '../../campaign/campaign_manager.dart';
import '../../campaign/data/battle_configs.dart';
import '../../providers/turn_provider.dart';
import '../../providers/simulation_provider.dart';
import '../../providers/game_settings_provider.dart';
import '../../providers/bluetooth_provider.dart';
import '../../simulation/ai/ai_strategy.dart';
import '../../campaign/data/kingdoms_data.dart';
import '../../campaign/models/kingdom_model.dart';
import '../../core/services/audio_service.dart';
import '../../simulation/board.dart';

import '../core/enums/turn.dart';
import '../core/enums/game_mode.dart';
import '../core/enums/game_phase.dart';
import 'board/board_component.dart';

import '../../providers/online_provider.dart';
import '../../core/enums/connection_type.dart';

// ... (other imports)

class KingdomGame extends FlameGame with ScaleDetector {
  final WidgetRef ref;
  late BoardComponent boardComponent;

  Board get simulationBoard => ref.read(simulationProvider).board;

  double _startScale = 1.0;

  KingdomGame(this.ref);

  @override
  Future<void> onLoad() async {
    images.prefix = ''; // Allow loading from any assets/ folder
    super.onLoad();

    // Start preloading SFX in background so we don't block the map rendering
    ref.read(audioServiceProvider).preloadSfx(AppAssets.defaultSfxList);

    final simulation = ref.read(simulationProvider);
    final settings = ref.read(gameSettingsProvider);
    final campaignState = ref.read(campaignProvider);
    final bluetoothState = ref.read(bluetoothProvider);
    final onlineState = ref.read(onlineProvider);
    final connectionType = ref.read(connectionTypeProvider);

    final isMultiplayer = settings.mode == GameMode.multiplayer;
    
    // In same-device multiplayer, we treat it like 'Host' so P1 is bottom, P2 is top.
    bool effectiveIsHost = true;
    if (connectionType == ConnectionType.bluetooth) {
      effectiveIsHost = bluetoothState.isHost;
    } else if (connectionType == ConnectionType.online) {
      effectiveIsHost = onlineState.isHost;
    }

    final selectedKingdom = campaignState.selectedKingdomId != null 
        ? kKingdoms.firstWhere((k) => k.id == campaignState.selectedKingdomId)
        : null;

    // In Simulation:
    // Bottom (y >= height/2) is Turn.player
    // Top (y < height/2) is Turn.ai
    
    final String bottomSymbol;
    final String topSymbol;
    final Color bottomColor;
    final Color topColor;

    if (isMultiplayer) {
      if (effectiveIsHost) {
        // Host device or Same-device: Local P1 is Bottom (Turn.player), Peer/P2 is Top (Turn.ai)
        bottomSymbol = settings.player1Symbol;
        topSymbol = settings.player2Symbol;
        bottomColor = Color(settings.player1Color);
        topColor = Color(settings.player2Color);
      } else {
        // Joiner device: Local P1 is mapped to Top (Turn.ai)
        // Peer P2 (Host) is mapped to Bottom (Turn.player)
        bottomSymbol = settings.player2Symbol; // Host symbol on joiner device
        topSymbol = settings.player1Symbol;    // Joiner symbol on joiner device
        bottomColor = Color(settings.player2Color);
        topColor = Color(settings.player1Color);
      }
    } else {
      // Single player
      bottomSymbol = settings.player1Symbol;
      topSymbol = selectedKingdom?.symbolAsset ?? AppAssets.eagle;
      bottomColor = Colors.blue;
      topColor = selectedKingdom?.primaryColor ?? Colors.red;
    }

    // Create the board visualization
    boardComponent = BoardComponent(
      simulationBoard: simulation.board,
      cellSize: 40.0,
      mapPath: settings.selectedMapPath,
      playerSymbol: bottomSymbol,    // Maps to Turn.player
      opponentSymbol: topSymbol,     // Maps to Turn.ai
      playerColor: bottomColor,
      opponentColor: topColor,
      onCellTapped: _handleCellTapped,
    );

    // Default 1.0 scale to maintain tappable tile sizes. (Rely on panning)
    final fitScale = 1.0;

    boardComponent.scale = Vector2.all(fitScale);
    _startScale = fitScale;

    // Center the properly scaled board loosely
    boardComponent.position = Vector2(
      (size.x - (boardComponent.size.x * fitScale)) / 2,
      (size.y - (boardComponent.size.y * fitScale)) / 2,
    );

    await add(boardComponent);

    // Re-center if the size changed after loading the map content
    boardComponent.position = Vector2(
      (size.x - (boardComponent.size.x * fitScale)) / 2,
      (size.y - (boardComponent.size.y * fitScale)) / 2,
    );
    
    // Ensure it's clamped immediately
    _clampPosition();
  }

  void _handleCellTapped(int x, int y) {
    final notifier = ref.read(simulationProvider.notifier);
    final simulationState = ref.read(simulationProvider);
    final settings = ref.read(gameSettingsProvider);
    final connectionType = ref.read(connectionTypeProvider);
    final bluetoothState = ref.read(bluetoothProvider);
    final onlineState = ref.read(onlineProvider);

    // Prevent tap if game is over or AI is thinking
    if (simulationState.currentPhase == GamePhase.gameOver) return;
    
    // In story mode, prevent tap if it's AI turn
    if (settings.mode == GameMode.story && simulationState.currentTurn == Turn.ai) {
      return;
    }

    // In remote multiplayer mode, prevent tap if it's not our turn
    if (connectionType == ConnectionType.bluetooth || connectionType == ConnectionType.online) {
      bool isOurTurn = false;
      if (connectionType == ConnectionType.bluetooth) {
        isOurTurn = (bluetoothState.isHost && simulationState.currentTurn == Turn.player) ||
                     (!bluetoothState.isHost && simulationState.currentTurn == Turn.ai);
      } else {
        isOurTurn = (onlineState.isHost && simulationState.currentTurn == Turn.player) ||
                     (!onlineState.isHost && simulationState.currentTurn == Turn.ai);
      }
      if (!isOurTurn) return;
    }

    final result = notifier.placeUnit(x, y);

    if (result.$1) {
      if (result.$2) {
        ref.read(audioServiceProvider).playSfx(AppAssets.sfxCapture);
      } else {
        ref.read(audioServiceProvider).playSfx(AppAssets.sfxClick);
      }
      boardComponent.syncWithSimulation(ref.read(simulationProvider).board);
      
      if (settings.mode == GameMode.story) {
        _checkAITurn();
      }
    }
  }

  void _checkAITurn() async {
    final simulationState = ref.read(simulationProvider);
    if (simulationState.currentPhase == GamePhase.gameOver) return;

    if (simulationState.currentTurn == Turn.ai) {
      // Set UI to thinking state
      ref.read(aiStateProvider.notifier).setThinking();

      // Get AI strategy from battle config
      final campaignState = ref.read(campaignProvider);
      final kingdomId = campaignState.selectedKingdomId;
      final strategy = (kingdomId != null) 
          ? (kBattleConfigs[kingdomId]?.aiStrategy ?? AIStrategy.fromType(AIStrategyType.basic)) 
          : AIStrategy.fromType(AIStrategyType.basic);

      // Offload AI calculation to Background Isolate
      final bestMove = await AIManager.calculateNextMove(simulationState, strategy);

      // Add a slight artificial delay so the AI doesn't feel instantaneous, giving the player a moment to process the board.
      await Future.delayed(const Duration(milliseconds: 600));

      if (bestMove != null) {
        final notifier = ref.read(simulationProvider.notifier);
        final result = notifier.placeUnit(bestMove.$1, bestMove.$2);
        if (result.$1) {
          if (result.$2) {
            ref.read(audioServiceProvider).playSfx(AppAssets.sfxCapture);
          } else {
            ref.read(audioServiceProvider).playSfx(AppAssets.sfxClick);
          }
          boardComponent.syncWithSimulation(ref.read(simulationProvider).board);
        }
      } else {
        // AI has no moves, skip turn to prevent game from getting stuck
        ref.read(simulationProvider.notifier).skipTurn();
      }

      ref.read(aiStateProvider.notifier).setIdle();
    }
  }

  /// Force a visual sync from the outside (useful if AI takes a turn)
  void forceSync() {
    boardComponent.syncWithSimulation(ref.read(simulationProvider).board);
  }

  @override
  void onScaleStart(ScaleStartInfo info) {
    _startScale = boardComponent.scale.x;
  }

  @override
  void onScaleUpdate(ScaleUpdateInfo info) {
    // 1. Panning
    boardComponent.position += info.delta.global;

    // 2. Zooming (pinch)
    if (info.pointerCount > 1) {
      // Calculate the new scale, clamped to reasonable bounds
      double newScale = _startScale * info.scale.global.x;
      newScale = newScale.clamp(0.5, 4.0); // Slightly more zoom freedom
      boardComponent.scale = Vector2.all(newScale);
    }

    // 3. Clamping - Ensure board doesn't fly off screen
    _clampPosition();
  }

  void _clampPosition() {
    final scaledWidth = boardComponent.width * boardComponent.scale.x;
    final scaledHeight = boardComponent.height * boardComponent.scale.y;

    // X-Axis Clamping
    if (scaledWidth > size.x) {
      // Board is wider than screen: clamp between (size.x - scaledWidth) and 0
      boardComponent.x = boardComponent.x.clamp(size.x - scaledWidth, 0);
    } else {
      // Board is narrower: keep it centered or at least within view
      boardComponent.x = boardComponent.x.clamp(0, size.x - scaledWidth);
    }

    // Y-Axis Clamping
    if (scaledHeight > size.y) {
      // Board is taller than screen
      boardComponent.y = boardComponent.y.clamp(size.y - scaledHeight, 0);
    } else {
      // Board is shorter
      boardComponent.y = boardComponent.y.clamp(0, size.y - scaledHeight);
    }
  }
}
