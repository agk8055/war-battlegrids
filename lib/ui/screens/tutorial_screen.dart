import 'dart:math' as math;
import 'package:flame/components.dart';
import 'package:flame/events.dart';
import 'package:flame/game.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../core/constants/app_assets.dart';
import '../../core/enums/cell_state.dart';
import '../../core/enums/turn.dart';
import '../../core/services/audio_service.dart';
import '../../core/utils/capture_utils.dart';
import '../../providers/game_settings_provider.dart';
import '../../simulation/board.dart';
import '../../simulation/rules.dart';
import '../widgets/overlays/capture_toast.dart';
import 'main_menu_screen.dart';
import '../../game/board/board_component.dart';

/// Tutorial step stages
enum TutorialStep {
  overview,
  deployment,
  flanking,
  siegeRules,
  victoryStrike,
  completed,
}

// ─────────────────────────────────────────────────────────────────────────────
//  Visual Beacon Indicator on the Flame Board
// ─────────────────────────────────────────────────────────────────────────────
class _TutorialBeaconComponent extends PositionComponent {
  final double cellSize;
  double _animationTime = 0.0;
  bool isTargetActive = false;

  final Paint _pulsePaint = Paint()
    ..color = const Color(0xFFFFD700)
    ..style = PaintingStyle.stroke
    ..strokeWidth = 2.5;

  final Paint _glowFillPaint = Paint()
    ..color = const Color(0x33FFD700)
    ..style = PaintingStyle.fill;

  _TutorialBeaconComponent({required this.cellSize}) {
    size = Vector2.all(cellSize);
    priority = 100;
  }

  void setTarget(int? gridX, int? gridY) {
    if (gridX != null && gridY != null) {
      position = Vector2(gridX * cellSize, gridY * cellSize);
      isTargetActive = true;
    } else {
      isTargetActive = false;
    }
  }

  @override
  void update(double dt) {
    super.update(dt);
    _animationTime += dt * 3.5;
  }

  @override
  void render(Canvas canvas) {
    if (!isTargetActive) return;
    super.render(canvas);

    final center = Offset(size.x / 2, size.y / 2);
    final pulseScale = 0.8 + 0.2 * math.sin(_animationTime);
    final ringRadius = (size.x / 2) * pulseScale;

    // Glowing background fill
    canvas.drawCircle(center, ringRadius, _glowFillPaint);

    // Outer pulse ring
    _pulsePaint.strokeWidth = 2.0 + math.sin(_animationTime) * 0.8;
    canvas.drawCircle(center, ringRadius, _pulsePaint);

    // Target crosshair corners
    final cornerLen = size.x * 0.22;
    final cornerPaint = Paint()
      ..color = const Color(0xFFFFD700)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3.0;

    // Top-Left
    canvas.drawLine(const Offset(2, 2), Offset(2 + cornerLen, 2), cornerPaint);
    canvas.drawLine(const Offset(2, 2), Offset(2, 2 + cornerLen), cornerPaint);

    // Top-Right
    canvas.drawLine(Offset(size.x - 2, 2), Offset(size.x - 2 - cornerLen, 2), cornerPaint);
    canvas.drawLine(Offset(size.x - 2, 2), Offset(size.x - 2, 2 + cornerLen), cornerPaint);

    // Bottom-Left
    canvas.drawLine(Offset(2, size.y - 2), Offset(2 + cornerLen, size.y - 2), cornerPaint);
    canvas.drawLine(Offset(2, size.y - 2), Offset(2, size.y - 2 - cornerLen), cornerPaint);

    // Bottom-Right
    canvas.drawLine(Offset(size.x - 2, size.y - 2), Offset(size.x - 2 - cornerLen, size.y - 2), cornerPaint);
    canvas.drawLine(Offset(size.x - 2, size.y - 2), Offset(size.x - 2, size.y - 2 + cornerLen), cornerPaint);
  }
}

// ─────────────────────────────────────────────────────────────────────────────
//  Flame Game instance tailored for Tutorial
// ─────────────────────────────────────────────────────────────────────────────
class _TutorialGameInstance extends FlameGame with ScaleDetector {
  final Board simulationBoard;
  final String playerSymbol;
  final String opponentSymbol;
  final void Function(int x, int y) onCellTapped;

  late BoardComponent boardComponent;
  late _TutorialBeaconComponent beaconComponent;
  double _startScale = 1.0;

  _TutorialGameInstance({
    required this.simulationBoard,
    required this.playerSymbol,
    required this.opponentSymbol,
    required this.onCellTapped,
  });

  @override
  Future<void> onLoad() async {
    images.prefix = '';
    super.onLoad();

    boardComponent = BoardComponent(
      simulationBoard: simulationBoard,
      cellSize: 40.0,
      mapPath: AppAssets.northernForestMap,
      playerSymbol: playerSymbol,
      opponentSymbol: opponentSymbol,
      playerColor: const Color(0xFF2196F3),
      opponentColor: const Color(0xFFE53935),
      onCellTapped: onCellTapped,
    );

    const fitScale = 1.0;
    boardComponent.scale = Vector2.all(fitScale);
    _startScale = fitScale;

    await add(boardComponent);

    // Center board once component is added and measured
    boardComponent.position = Vector2(
      (size.x - (boardComponent.size.x * fitScale)) / 2,
      (size.y - (boardComponent.size.y * fitScale)) / 2,
    );

    // Add Beacon Component
    beaconComponent = _TutorialBeaconComponent(cellSize: 40.0);
    boardComponent.add(beaconComponent);

    _clampPosition();
    syncBoard();
  }

  @override
  void onGameResize(Vector2 size) {
    super.onGameResize(size);
    if (isLoaded) {
      _clampPosition();
    }
  }

  void setBeaconTarget(int? gridX, int? gridY) {
    beaconComponent.setTarget(gridX, gridY);
  }

  void syncBoard({
    bool kingdomAttackUnlocked = false,
    Set<((int, int), (int, int))>? newLinkages,
    (int, int)? lastPlacedCoord,
    List<(int, int)>? capturedCells,
    Color? capturerColor,
  }) {
    boardComponent.syncWithSimulation(
      simulationBoard,
      effectiveTurn: Turn.player,
      kingdomAttackUnlocked: kingdomAttackUnlocked,
      newLinkages: newLinkages,
      lastPlacedCoord: lastPlacedCoord,
      capturedCells: capturedCells,
      capturerColor: capturerColor,
    );
  }

  @override
  void onScaleStart(ScaleStartInfo info) {
    _startScale = boardComponent.scale.x;
  }

  @override
  void onScaleUpdate(ScaleUpdateInfo info) {
    final currentScale = _startScale * info.scale.global.x;
    final clampedScale = currentScale.clamp(0.65, 1.4);
    boardComponent.scale = Vector2.all(clampedScale);
    boardComponent.position += info.delta.global;
    _clampPosition();
  }

  void _clampPosition() {
    final scaledWidth = boardComponent.size.x * boardComponent.scale.x;
    final scaledHeight = boardComponent.size.y * boardComponent.scale.y;

    if (scaledWidth < size.x) {
      boardComponent.position.x = (size.x - scaledWidth) / 2;
    } else {
      boardComponent.position.x = boardComponent.position.x.clamp(size.x - scaledWidth, 0.0);
    }

    if (scaledHeight < size.y) {
      boardComponent.position.y = (size.y - scaledHeight) / 2;
    } else {
      boardComponent.position.y = boardComponent.position.y.clamp(size.y - scaledHeight, 0.0);
    }
  }
}

// ─────────────────────────────────────────────────────────────────────────────
//  Tutorial Screen
// ─────────────────────────────────────────────────────────────────────────────
class TutorialScreen extends ConsumerStatefulWidget {
  const TutorialScreen({super.key});

  @override
  ConsumerState<TutorialScreen> createState() => _TutorialScreenState();
}

class _TutorialScreenState extends ConsumerState<TutorialScreen> with TickerProviderStateMixin {
  late Board _board;
  _TutorialGameInstance? _game;
  TutorialStep _currentStep = TutorialStep.overview;

  late AnimationController _fadeController;
  late Animation<double> _fadeAnim;

  int _playerScore = 0;
  bool _kingdomAttackUnlocked = false;

  // Target coordinates for interactive phases
  (int, int)? _currentTarget;

  @override
  void initState() {
    super.initState();
    _fadeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    );
    _fadeAnim = CurvedAnimation(parent: _fadeController, curve: Curves.easeIn);
    _fadeController.forward();

    _initTutorialBoard();
  }

  void _initTutorialBoard() {
    _board = Board(width: 15, height: 15);
    _board.setPlayableArea(3, 3, 11, 11);

    final settings = ref.read(gameSettingsProvider);
    _game = _TutorialGameInstance(
      simulationBoard: _board,
      playerSymbol: settings.player1Symbol,
      opponentSymbol: settings.player2Symbol.isNotEmpty ? settings.player2Symbol : AppAssets.eagle,
      onCellTapped: _handleUserTap,
    );

    // Audio theme
    ref.read(audioServiceProvider).playMainTheme();
  }

  @override
  void dispose() {
    _fadeController.dispose();
    super.dispose();
  }

  void _advanceToStep(TutorialStep step) {
    setState(() {
      _currentStep = step;
      _fadeController.reset();
      _fadeController.forward();
    });

    switch (step) {
      case TutorialStep.overview:
        _currentTarget = null;
        _game?.setBeaconTarget(null, null);
        break;

      case TutorialStep.deployment:
        _currentTarget = (7, 7);
        _game?.setBeaconTarget(7, 7);
        break;

      case TutorialStep.flanking:
        // Set up flanking demonstration board state
        // Friendly surrounding pieces at (7, 7), (6, 6), (7, 5), waiting for final strike at (8, 6)
        _board.setCell(7, 6, CellState.ai); // Encircled enemy piece
        _board.setCell(6, 6, CellState.player);
        _board.setCell(7, 5, CellState.player);
        _board.setCell(7, 7, CellState.player);

        _currentTarget = (8, 6);
        _game?.setBeaconTarget(8, 6);
        _game?.syncBoard(kingdomAttackUnlocked: _kingdomAttackUnlocked);
        break;

      case TutorialStep.siegeRules:
        _currentTarget = null;
        _game?.setBeaconTarget(null, null);
        _game?.syncBoard(kingdomAttackUnlocked: false);
        break;

      case TutorialStep.victoryStrike:
        // Set up near-victory blockade scenario surrounding the Citadel (7..8, 3)
        _kingdomAttackUnlocked = true;
        _board.setCell(6, 3, CellState.player);
        _board.setCell(6, 4, CellState.player);
        _board.setCell(7, 4, CellState.player);
        _board.setCell(8, 4, CellState.player);
        _board.setCell(9, 4, CellState.player);

        // Final decisive placement at (9, 3) connecting the siege line to the boundary/palace
        _currentTarget = (9, 3);
        _game?.setBeaconTarget(9, 3);
        _game?.syncBoard(kingdomAttackUnlocked: true);
        break;

      case TutorialStep.completed:
        _currentTarget = null;
        _game?.setBeaconTarget(null, null);
        break;
    }
  }

  void _handleUserTap(int x, int y) async {
    if (_currentTarget == null) return;

    if (x == _currentTarget!.$1 && y == _currentTarget!.$2) {
      // Correct tile tapped!
      if (_currentStep == TutorialStep.deployment) {
        _board.setCell(x, y, CellState.player);
        ref.read(audioServiceProvider).playSfx(AppAssets.sfxClick);
        _game?.syncBoard(kingdomAttackUnlocked: _kingdomAttackUnlocked);
        _game?.setBeaconTarget(null, null);

        // AI places a response move after short delay
        await Future.delayed(const Duration(milliseconds: 450));
        if (!mounted) return;
        _board.setCell(7, 6, CellState.ai);
        ref.read(audioServiceProvider).playSfx(AppAssets.sfxClick);
        _game?.syncBoard(kingdomAttackUnlocked: _kingdomAttackUnlocked);

        await Future.delayed(const Duration(milliseconds: 500));
        if (mounted) {
          _advanceToStep(TutorialStep.flanking);
        }
      } else if (_currentStep == TutorialStep.flanking) {
        _board.setCell(x, y, CellState.player);

        final captureResult = CaptureUtils.getCapturedUnits(_board, (x, y), Turn.player);
        if (captureResult.capturedCells.isNotEmpty) {
          for (final cell in captureResult.capturedCells) {
            _board.setCell(cell.$1, cell.$2, CellState.capturedGrid);
          }
          _board.linkages.addAll(captureResult.linkages);
        }

        ref.read(audioServiceProvider).playSfx(AppAssets.sfxCapture);
        _playerScore += 100;

        _game?.syncBoard(
          kingdomAttackUnlocked: _kingdomAttackUnlocked,
          newLinkages: captureResult.linkages,
          lastPlacedCoord: (x, y),
          capturedCells: captureResult.capturedCells,
          capturerColor: const Color(0xFF2196F3),
        );
        _game?.setBeaconTarget(null, null);

        CaptureToast.showCapture(
          context: context,
          capturerName: ref.read(gameSettingsProvider).player1Name,
          capturerColor: const Color(0xFF2196F3),
          unitsCaptured: 1,
          pointsGained: 100,
        );

        await Future.delayed(const Duration(milliseconds: 1200));
        if (mounted) {
          _advanceToStep(TutorialStep.siegeRules);
        }
      } else if (_currentStep == TutorialStep.victoryStrike) {
        _board.setCell(x, y, CellState.player);

        final winResult = GameRules.checkWinCondition(_board, Turn.player, kingdomAttackUnlocked: true);
        Set<((int, int), (int, int))> winLinkages = {};
        if (winResult.isWin && winResult.blockage != null) {
          winLinkages = CaptureUtils.getLinkagesFromBlockage(winResult.blockage!);
          _board.linkages.addAll(winLinkages);
        }

        ref.read(audioServiceProvider).playSfx(AppAssets.sfxCapture);
        _game?.syncBoard(
          kingdomAttackUnlocked: true,
          newLinkages: winLinkages,
          lastPlacedCoord: (x, y),
          capturerColor: const Color(0xFF2196F3),
        );
        _game?.setBeaconTarget(null, null);

        await Future.delayed(const Duration(milliseconds: 800));
        if (mounted) {
          _advanceToStep(TutorialStep.completed);
        }
      }
    } else {
      // Tap on non-target cell
      CaptureToast.show(
        context,
        "Commander, deploy your unit on the highlighted target!",
        const Color(0xFFFCB103),
      );
    }
  }

  Future<void> _finishTutorialAndGoHome() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('is_first_run', false);
    await prefs.setBool('has_completed_tutorial', true);

    if (!mounted) return;

    Navigator.of(context).pushReplacement(
      PageRouteBuilder(
        pageBuilder: (context, animation, secondaryAnimation) => const GameHomeScreen(),
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          return FadeTransition(opacity: animation, child: child);
        },
        transitionDuration: const Duration(milliseconds: 600),
      ),
    );
  }

  void _showSkipDialog() {
    final primary = Theme.of(context).colorScheme.primary;
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF14120E),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
          side: BorderSide(color: primary.withValues(alpha: 0.4), width: 1.2),
        ),
        title: Row(
          children: [
            Icon(Icons.flag_rounded, color: primary, size: 24),
            const SizedBox(width: 10),
            Text(
              'SKIP COMBAT DRILL?',
              style: GoogleFonts.sairaStencilOne(
                color: primary,
                fontSize: 16,
                letterSpacing: 2.0,
              ),
            ),
          ],
        ),
        content: const Text(
          'Are you ready to enter the War Room directly? You can always replay this tutorial anytime from the Settings menu.',
          style: TextStyle(color: Colors.white70, fontSize: 13, height: 1.4),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('STAY IN DRILL', style: TextStyle(color: Colors.white60)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: primary,
              foregroundColor: Colors.black,
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
            ),
            onPressed: () {
              Navigator.pop(context);
              _finishTutorialAndGoHome();
            },
            child: const Text('SKIP TO WAR ROOM', style: TextStyle(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final primary = Theme.of(context).colorScheme.primary;

    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          // 1. Flame Game View (15x15 Northern Forest Map)
          if (_game != null) GameWidget(game: _game!),

          // 2. Top Bar with Title, Score & Skip Button
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: SafeArea(
              bottom: false,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Colors.black.withValues(alpha: 0.85),
                      Colors.transparent,
                    ],
                  ),
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: primary.withValues(alpha: 0.15),
                        border: Border.all(color: primary.withValues(alpha: 0.5), width: 1),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.school_rounded, color: primary, size: 16),
                          const SizedBox(width: 6),
                          Text(
                            'CADET ACADEMY',
                            style: TextStyle(
                              color: primary,
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 2.0,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const Spacer(),

                    // Glory Points Indicator
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.black54,
                        border: Border.all(color: Colors.white24, width: 1),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.military_tech_rounded, color: Color(0xFFFFD700), size: 16),
                          const SizedBox(width: 4),
                          Text(
                            'GLORY: $_playerScore',
                            style: const TextStyle(
                              color: Color(0xFFFFD700),
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 1.2,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 14),

                    // Skip Button
                    GestureDetector(
                      onTap: _showSkipDialog,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.08),
                          border: Border.all(color: Colors.white30, width: 1),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: const [
                            Text(
                              'SKIP TUTORIAL',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                                letterSpacing: 1.5,
                              ),
                            ),
                            SizedBox(width: 4),
                            Icon(Icons.fast_forward_rounded, color: Colors.white70, size: 14),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),

          // 3. Step Guidance Card (Bottom-Left Overlay)
          Positioned(
            left: 8,
            bottom: 8,
            child: ConstrainedBox(
              constraints: BoxConstraints(
                maxWidth: math.min(MediaQuery.of(context).size.width * 0.42, 350.0),
                minWidth: 260.0,
              ),
              child: FadeTransition(
                opacity: _fadeAnim,
                child: _buildGuidanceCard(primary),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildGuidanceCard(Color primary) {
    switch (_currentStep) {
      case TutorialStep.overview:
        return _ParchmentNotification(
          stepBadge: 'STAGE 1 OF 5',
          title: 'THE WAR FRONTIER',
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Welcome, Commander! You are commanding the Southern Citadel (Blue). The Enemy Stronghold lies in the North (Red).\n'
                'Deploy battalions across the contested grid, flank and capture enemy troops, and siege their kingdom.',
                style: GoogleFonts.outfit(
                  color: const Color(0xFF2C1A0D),
                  fontSize: 10.5,
                  fontWeight: FontWeight.w600,
                  height: 1.3,
                ),
              ),
              const SizedBox(height: 8),
              Align(
                alignment: Alignment.centerRight,
                child: ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF8A2109),
                    foregroundColor: const Color(0xFFFFF8E7),
                    elevation: 3,
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(6),
                      side: const BorderSide(color: Color(0xFFFFD700), width: 1.0),
                    ),
                  ),
                  onPressed: () => _advanceToStep(TutorialStep.deployment),
                  icon: const Icon(Icons.arrow_forward_rounded, size: 14, color: Color(0xFFFFD700)),
                  label: Text(
                    'START DEPLOYMENT',
                    style: GoogleFonts.sairaStencilOne(
                      fontSize: 10.0,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 1.0,
                      color: const Color(0xFFFFF8E7),
                    ),
                  ),
                ),
              ),
            ],
          ),
        );

      case TutorialStep.deployment:
        return _ParchmentNotification(
          stepBadge: 'STAGE 2 OF 5',
          title: 'TROOP DEPLOYMENT',
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Battles proceed in alternating turns. Tap the highlighted golden beacon at the frontline to position your vanguard unit.',
                style: GoogleFonts.outfit(
                  color: const Color(0xFF2C1A0D),
                  fontSize: 10.5,
                  fontWeight: FontWeight.w600,
                  height: 1.3,
                ),
              ),
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
                decoration: BoxDecoration(
                  color: const Color(0xFF7A4A21).withValues(alpha: 0.14),
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: const Color(0xFF8B4513).withValues(alpha: 0.35), width: 1),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 8,
                      height: 8,
                      decoration: const BoxDecoration(
                        color: Color(0xFFD97706),
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        'Tap the glowing tile on the board to deploy',
                        style: GoogleFonts.outfit(
                          color: const Color(0xFF6B2208),
                          fontSize: 9.5,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );

      case TutorialStep.flanking:
        return _ParchmentNotification(
          stepBadge: 'STAGE 3 OF 5',
          title: 'FLANKING & CAPTURE',
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'When you surround enemy units on orthogonal flanks, they are CAPTURED! Captures grant +100 Glory and forge unbreakable linkages.\n'
                'Strike the highlighted flank to capture the enemy unit!',
                style: GoogleFonts.outfit(
                  color: const Color(0xFF2C1A0D),
                  fontSize: 10.5,
                  fontWeight: FontWeight.w600,
                  height: 1.3,
                ),
              ),
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
                decoration: BoxDecoration(
                  color: const Color(0xFF7A4A21).withValues(alpha: 0.14),
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: const Color(0xFF8B4513).withValues(alpha: 0.35), width: 1),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.military_tech_rounded, color: Color(0xFFB45309), size: 14),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        'Deploy at golden target to Capture (+100 Glory)',
                        style: GoogleFonts.outfit(
                          color: const Color(0xFF6B2208),
                          fontSize: 9.5,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );

      case TutorialStep.siegeRules:
        return _ParchmentNotification(
          stepBadge: 'STAGE 4 OF 5',
          title: 'SIEGE RESTRAINTS',
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Strongholds are protected by Siege Restraints (indicated by red circular warnings). '
                'You cannot place units that complete premature winning blockages around the citadel until you earn enough Glory to unlock Kingdom Attack.',
                style: GoogleFonts.outfit(
                  color: const Color(0xFF2C1A0D),
                  fontSize: 10.5,
                  fontWeight: FontWeight.w600,
                  height: 1.3,
                ),
              ),
              const SizedBox(height: 8),
              Align(
                alignment: Alignment.centerRight,
                child: ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF8A2109),
                    foregroundColor: const Color(0xFFFFF8E7),
                    elevation: 3,
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(6),
                      side: const BorderSide(color: Color(0xFFFFD700), width: 1.0),
                    ),
                  ),
                  onPressed: () => _advanceToStep(TutorialStep.victoryStrike),
                  icon: const Icon(Icons.bolt_rounded, size: 14, color: Color(0xFFFFD700)),
                  label: Text(
                    'ASSAULT THE CITADEL',
                    style: GoogleFonts.sairaStencilOne(
                      fontSize: 10.0,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 1.0,
                      color: const Color(0xFFFFF8E7),
                    ),
                  ),
                ),
              ),
            ],
          ),
        );

      case TutorialStep.victoryStrike:
        return _ParchmentNotification(
          stepBadge: 'STAGE 5 OF 5',
          title: 'DELIVERING VICTORY',
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Kingdom Attack is unlocked! Completing a connected blockade or encircling the opponent Citadel results in total victory.\n'
                'Deploy your battalion at the highlighted gate to complete the winning blockade!',
                style: GoogleFonts.outfit(
                  color: const Color(0xFF2C1A0D),
                  fontSize: 10.5,
                  fontWeight: FontWeight.w600,
                  height: 1.3,
                ),
              ),
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
                decoration: BoxDecoration(
                  color: const Color(0xFF7A4A21).withValues(alpha: 0.14),
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: const Color(0xFF8B4513).withValues(alpha: 0.35), width: 1),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.stars_rounded, color: Color(0xFFB45309), size: 14),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        'Deploy at the golden target to achieve Victory!',
                        style: GoogleFonts.outfit(
                          color: const Color(0xFF6B2208),
                          fontSize: 9.5,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );

      case TutorialStep.completed:
        return _ParchmentNotification(
          stepBadge: 'VICTORY',
          title: 'DRILL COMPLETED',
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Magnificent tactics, Commander! You have mastered Deployment, Encirclement, Siege Restraints, and Kingdom Conquest.\n'
                'The realm awaits your command in Campaign and Multiplayer warfare!',
                textAlign: TextAlign.center,
                style: GoogleFonts.outfit(
                  color: const Color(0xFF2C1A0D),
                  fontSize: 10.5,
                  fontWeight: FontWeight.w600,
                  height: 1.3,
                ),
              ),
              const SizedBox(height: 10),
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF8A2109),
                  foregroundColor: const Color(0xFFFFF8E7),
                  elevation: 4,
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                    side: const BorderSide(color: Color(0xFFFFD700), width: 1.2),
                  ),
                ),
                onPressed: _finishTutorialAndGoHome,
                icon: const Icon(Icons.military_tech_rounded, size: 16, color: Color(0xFFFFD700)),
                label: Text(
                  'ENTER THE WAR ROOM',
                  style: GoogleFonts.sairaStencilOne(
                    fontSize: 11.0,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 1.2,
                    color: const Color(0xFFFFF8E7),
                  ),
                ),
              ),
            ],
          ),
        );
    }
  }
}

// ─────────────────────────────────────────────────────────────────────────────
//  _ParchmentNotification (Parchment Poster Theme)
// ─────────────────────────────────────────────────────────────────────────────
class _ParchmentNotification extends StatelessWidget {
  final String title;
  final String? stepBadge;
  final Widget child;

  const _ParchmentNotification({
    required this.title,
    this.stepBadge,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.65),
            blurRadius: 18,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Stack(
        children: [
          // 1. Background Poster
          Positioned.fill(
            child: Image.asset(
              AppAssets.tutorialPoster,
              fit: BoxFit.fill,
              errorBuilder: (context, error, stackTrace) => Container(
                decoration: BoxDecoration(
                  color: const Color(0xFFDFBE89),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFF6E431F), width: 2),
                ),
              ),
            ),
          ),

          // 2. Poster Inner Safe Content
          Padding(
            padding: const EdgeInsets.only(
              left: 32,
              right: 32,
              top: 23,
              bottom: 16,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Top Header Plaque aligned with poster banner
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      if (stepBadge != null) ...[
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
                          decoration: BoxDecoration(
                            color: const Color(0xFF8B4513).withValues(alpha: 0.4),
                            borderRadius: BorderRadius.circular(4),
                            border: Border.all(color: const Color(0xFFFFD700).withValues(alpha: 0.8), width: 0.8),
                          ),
                          child: Text(
                            stepBadge!,
                            style: const TextStyle(
                              color: Color(0xFFFFE082),
                              fontSize: 8.0,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 1.0,
                            ),
                          ),
                        ),
                        const SizedBox(width: 6),
                      ],
                      Flexible(
                        child: Text(
                          title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          textAlign: TextAlign.center,
                          style: GoogleFonts.sairaStencilOne(
                            color: const Color(0xFFFFF6E0),
                            fontSize: 11.5,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 1.2,
                            shadows: const [
                              Shadow(color: Colors.black87, offset: Offset(1, 1), blurRadius: 3),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 8),
                // Parchment Content
                child,
              ],
            ),
          ),
        ],
      ),
    );
  }
}

