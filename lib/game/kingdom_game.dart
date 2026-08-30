import 'dart:math' as math;
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
import '../../core/services/audio_service.dart';
import '../../simulation/board.dart';
import '../../simulation/rules.dart';

import '../core/enums/turn.dart';
import '../core/enums/game_mode.dart';
import '../core/enums/game_phase.dart';
import 'board/board_component.dart';

import '../../providers/online_provider.dart';
import '../../core/enums/connection_type.dart';

class KingdomGame extends FlameGame with ScaleDetector {
  final WidgetRef ref;
  final void Function(String message, Color color)? onToast;
  late BoardComponent boardComponent;

  Board get simulationBoard => ref.read(simulationProvider).board;

  double _startScale = 1.0;

  KingdomGame(this.ref, {this.onToast});

  @override
  Color backgroundColor() => const Color(0x00000000);

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
      bottomColor = Color(settings.player1Color);
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

    // Initial sync of board and siege overlay states
    syncBoard();
  }

  /// Synchronizes the visual board tiles and siege-restriction overlays with the simulation state.
  void syncBoard() {
    final sim = ref.read(simulationProvider);
    final settings = ref.read(gameSettingsProvider);
    final connectionType = ref.read(connectionTypeProvider);
    final bluetoothState = ref.read(bluetoothProvider);
    final onlineState = ref.read(onlineProvider);

    Turn effectiveTurn = Turn.player;
    bool attackUnlocked = sim.playerKingdomAttackUnlocked;

    if (settings.mode == GameMode.multiplayer) {
      if (connectionType == ConnectionType.bluetooth) {
        effectiveTurn = bluetoothState.isHost ? Turn.player : Turn.ai;
        attackUnlocked = bluetoothState.isHost
            ? sim.playerKingdomAttackUnlocked
            : sim.aiKingdomAttackUnlocked;
      } else if (connectionType == ConnectionType.online) {
        effectiveTurn = onlineState.isHost ? Turn.player : Turn.ai;
        attackUnlocked = onlineState.isHost
            ? sim.playerKingdomAttackUnlocked
            : sim.aiKingdomAttackUnlocked;
      } else {
        // Pass & Play (Same Device)
        effectiveTurn = sim.currentTurn;
        attackUnlocked = (sim.currentTurn == Turn.player)
            ? sim.playerKingdomAttackUnlocked
            : sim.aiKingdomAttackUnlocked;
      }
    } else {
      // Story Mode / Vs AI
      effectiveTurn = Turn.player;
      attackUnlocked = sim.playerKingdomAttackUnlocked;
    }

    final capturerColor = (sim.lastMovedTurn == Turn.ai)
        ? boardComponent.opponentColor
        : boardComponent.playerColor;

    final effectiveActiveCondition = (effectiveTurn == Turn.player)
        ? sim.playerActiveWinCondition
        : sim.aiActiveWinCondition;

    boardComponent.syncWithSimulation(
      sim.board,
      effectiveTurn: effectiveTurn,
      kingdomAttackUnlocked: attackUnlocked,
      activeCondition: effectiveActiveCondition,
      newLinkages: sim.lastNewLinkages,
      lastPlacedCoord: sim.lastPlacedCoord,
      capturedCells: sim.lastCapturedCells,
      capturerColor: capturerColor,
    );
  }

  void _handleCellTapped(int x, int y) {
    final notifier = ref.read(simulationProvider.notifier);
    final simulationState = ref.read(simulationProvider);
    final settings = ref.read(gameSettingsProvider);
    final connectionType = ref.read(connectionTypeProvider);
    final bluetoothState = ref.read(bluetoothProvider);
    final onlineState = ref.read(onlineProvider);
    final campaignState = ref.read(campaignProvider);

    // Prevent tap if game is over or drawn
    if (simulationState.currentPhase == GamePhase.gameOver ||
        simulationState.currentPhase == GamePhase.draw) {
      return;
    }
    
    // In story mode, prevent tap if it's AI turn and show toast
    if (settings.mode == GameMode.story && simulationState.currentTurn == Turn.ai) {
      final selectedKingdom = campaignState.selectedKingdomId != null
          ? kKingdoms.firstWhere((k) => k.id == campaignState.selectedKingdomId)
          : null;
      final aiColor = selectedKingdom?.primaryColor ?? Colors.redAccent;
      onToast?.call("Opponent is playing", aiColor);
      return;
    }

    // In remote multiplayer mode, prevent tap if it's not our turn and show toast
    if (connectionType == ConnectionType.bluetooth || connectionType == ConnectionType.online) {
      bool isOurTurn = false;
      if (connectionType == ConnectionType.bluetooth) {
        isOurTurn = (bluetoothState.isHost && simulationState.currentTurn == Turn.player) ||
                     (!bluetoothState.isHost && simulationState.currentTurn == Turn.ai);
      } else {
        isOurTurn = (onlineState.isHost && simulationState.currentTurn == Turn.player) ||
                     (!onlineState.isHost && simulationState.currentTurn == Turn.ai);
      }
      if (!isOurTurn) {
        final opponentColor = Color(settings.player2Color);
        onToast?.call("Opponent is playing", opponentColor);
        return;
      }
    }

    final result = notifier.placeUnit(x, y);

    if (result.$1) {
      if (result.$2) {
        ref.read(audioServiceProvider).playSfx(AppAssets.sfxCapture);
      } else {
        ref.read(audioServiceProvider).playSfx(AppAssets.sfxClick);
      }
      syncBoard();
      
      final currentSim = ref.read(simulationProvider);
      if (currentSim.currentPhase == GamePhase.gameOver ||
          currentSim.currentPhase == GamePhase.draw) {
        return;
      }

      if (settings.mode == GameMode.story) {
        _checkAITurn();
      }
    } else {
      // Check if tap failed specifically due to siege restrictions
      Turn effectiveTurn = Turn.player;
      bool attackUnlocked = simulationState.playerKingdomAttackUnlocked;
      int currentScore = simulationState.playerScore;
      int threshold = simulationState.config.playerKingdomAttackThreshold;

      if (settings.mode == GameMode.multiplayer) {
        if (connectionType == ConnectionType.bluetooth) {
          effectiveTurn = bluetoothState.isHost ? Turn.player : Turn.ai;
          attackUnlocked = bluetoothState.isHost
              ? simulationState.playerKingdomAttackUnlocked
              : simulationState.aiKingdomAttackUnlocked;
          currentScore = bluetoothState.isHost ? simulationState.playerScore : simulationState.aiScore;
          threshold = bluetoothState.isHost
              ? simulationState.config.playerKingdomAttackThreshold
              : simulationState.config.aiKingdomAttackThreshold;
        } else if (connectionType == ConnectionType.online) {
          effectiveTurn = onlineState.isHost ? Turn.player : Turn.ai;
          attackUnlocked = onlineState.isHost
              ? simulationState.playerKingdomAttackUnlocked
              : simulationState.aiKingdomAttackUnlocked;
          currentScore = onlineState.isHost ? simulationState.playerScore : simulationState.aiScore;
          threshold = onlineState.isHost
              ? simulationState.config.playerKingdomAttackThreshold
              : simulationState.config.aiKingdomAttackThreshold;
        } else {
          effectiveTurn = simulationState.currentTurn;
          attackUnlocked = (simulationState.currentTurn == Turn.player)
              ? simulationState.playerKingdomAttackUnlocked
              : simulationState.aiKingdomAttackUnlocked;
          currentScore = (simulationState.currentTurn == Turn.player)
              ? simulationState.playerScore
              : simulationState.aiScore;
          threshold = (simulationState.currentTurn == Turn.player)
              ? simulationState.config.playerKingdomAttackThreshold
              : simulationState.config.aiKingdomAttackThreshold;
        }
      }

      final effectiveActiveCondition = (effectiveTurn == Turn.player)
          ? simulationState.playerActiveWinCondition
          : simulationState.aiActiveWinCondition;

      final isSiegeBlocked = GameRules.isPlacementBlockedBySiege(
        simulationState.board,
        x,
        y,
        effectiveTurn,
        attackUnlocked,
        activeCondition: effectiveActiveCondition,
      );

      if (isSiegeBlocked) {
        final pointsRemaining = (threshold - currentScore).clamp(0, threshold);
        onToast?.call(
          "⚔ SIEGE LOCKED — Earn $pointsRemaining more Glory to breach!",
          const Color(0xFFD32F2F),
        );
      }
    }
  }

  void _checkAITurn() async {
    final simulationState = ref.read(simulationProvider);
    if (simulationState.currentPhase == GamePhase.gameOver ||
        simulationState.currentPhase == GamePhase.draw) {
      return;
    }

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

      final notifier = ref.read(simulationProvider.notifier);
      bool movePlaced = false;

      if (bestMove != null) {
        final result = notifier.placeUnit(bestMove.$1, bestMove.$2);
        if (result.$1) {
          movePlaced = true;
          if (result.$2) {
            ref.read(audioServiceProvider).playSfx(AppAssets.sfxCapture);
          } else {
            ref.read(audioServiceProvider).playSfx(AppAssets.sfxClick);
          }
          syncBoard();
        }
      }

      // If bestMove was null or invalid, attempt fallback moves so turn never hangs
      if (!movePlaced) {
        final currentSim = ref.read(simulationProvider);
        final candidates = currentSim.board.getRestrictedAvailableCells(
          radius: 2,
          allowZones: currentSim.aiKingdomAttackUnlocked,
        );
        
        for (final move in candidates) {
          final result = notifier.placeUnit(move.$1, move.$2);
          if (result.$1) {
            movePlaced = true;
            if (result.$2) {
              ref.read(audioServiceProvider).playSfx(AppAssets.sfxCapture);
            } else {
              ref.read(audioServiceProvider).playSfx(AppAssets.sfxClick);
            }
            syncBoard();
            break;
          }
        }
      }

      // If still no move could be placed, skip AI turn to advance the game
      if (!movePlaced) {
        notifier.skipTurn();
        syncBoard();
      }

      ref.read(aiStateProvider.notifier).setIdle();

      // After AI turn, check if the human player has any valid moves
      final afterAiSim = ref.read(simulationProvider);
      if (afterAiSim.currentPhase != GamePhase.gameOver &&
          afterAiSim.currentPhase != GamePhase.draw) {
        final playerCanMove = GameRules.hasValidMoves(
          afterAiSim.board,
          Turn.player,
          afterAiSim.playerKingdomAttackUnlocked,
        );
        final aiCanMove = GameRules.hasValidMoves(
          afterAiSim.board,
          Turn.ai,
          afterAiSim.aiKingdomAttackUnlocked,
        );

        if (!playerCanMove && !aiCanMove) {
          notifier.declareDraw();
          syncBoard();
        } else if (!playerCanMove && aiCanMove) {
          onToast?.call("No valid deployment tiles — Passing turn to AI", Colors.orangeAccent);
          notifier.skipTurn();
          syncBoard();
          _checkAITurn();
        }
      }
    }
  }

  /// Force a visual sync from the outside (useful if AI takes a turn)
  void forceSync() {
    syncBoard();
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
    const margin = 140.0;

    final minX = math.min(0.0, size.x - scaledWidth) - margin;
    final maxX = math.max(0.0, size.x - scaledWidth) + margin;
    boardComponent.x = boardComponent.x.clamp(minX, maxX);

    final minY = math.min(0.0, size.y - scaledHeight) - margin;
    final maxY = math.max(0.0, size.y - scaledHeight) + margin;
    boardComponent.y = boardComponent.y.clamp(minY, maxY);
  }
}
