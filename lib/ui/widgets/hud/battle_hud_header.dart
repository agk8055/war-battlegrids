import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/enums/game_mode.dart';
import '../../../core/enums/turn.dart';
import '../../../providers/simulation_provider.dart';
import '../../../providers/game_settings_provider.dart';
import '../../../providers/bluetooth_provider.dart';
import '../../../campaign/campaign_manager.dart';
import '../../../campaign/data/kingdoms_data.dart';
import 'score_panel.dart';

class BattleHudHeader extends ConsumerWidget {
  final VoidCallback onPausePressed;

  const BattleHudHeader({
    super.key,
    required this.onPausePressed,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final simulationState = ref.watch(simulationProvider);
    final settings = ref.watch(gameSettingsProvider);
    final campaignState = ref.watch(campaignProvider);
    final bluetoothState = ref.watch(bluetoothProvider);

    final isMultiplayer = settings.mode == GameMode.multiplayer;
    final isBluetooth = bluetoothState.status == BluetoothStatus.connected;

    // In same-device multiplayer, treat it like 'Host' so P1 is Left, P2 is Right
    final bool effectiveIsHost =
        isMultiplayer ? (!isBluetooth || bluetoothState.isHost) : true;

    final selectedKingdom = campaignState.selectedKingdomId != null
        ? kKingdoms.firstWhere((k) => k.id == campaignState.selectedKingdomId)
        : null;

    final String p1Name;
    final String p1Symbol;
    final int p1ColorVal;

    final String p2Name;
    final String p2Symbol;
    final int p2ColorVal;

    if (isMultiplayer) {
      if (effectiveIsHost) {
        p1Name = settings.player1Name;
        p1Symbol = settings.player1Symbol;
        p1ColorVal = settings.player1Color;

        p2Name = settings.player2Name;
        p2Symbol = settings.player2Symbol;
        p2ColorVal = settings.player2Color;
      } else {
        // Joiner: Host goes Left, Joiner goes Right
        p1Name = settings.player2Name;
        p1Symbol = settings.player2Symbol;
        p1ColorVal = settings.player2Color;

        p2Name = settings.player1Name;
        p2Symbol = settings.player1Symbol;
        p2ColorVal = settings.player1Color;
      }
    } else {
      p1Name = settings.player1Name;
      p1Symbol = settings.player1Symbol;
      p1ColorVal = settings.player1Color;

      p2Name = selectedKingdom?.name ?? "AI";
      p2Symbol = selectedKingdom?.symbolAsset ?? 'assets/icons/eagle.png';
      p2ColorVal =
          selectedKingdom?.primaryColor.toARGB32() ?? Colors.red.toARGB32();
    }

    final p1Color = Color(p1ColorVal);
    final p2Color = Color(p2ColorVal);

    final p1IsActive = simulationState.currentTurn == Turn.player;
    final p1Score = simulationState.playerScore;
    final p1KingdomAttackUnlocked = simulationState.playerKingdomAttackUnlocked;
    final p1ActiveWinCondition = simulationState.playerActiveWinCondition;

    final p2IsActive = simulationState.currentTurn == Turn.ai;
    final p2Score = simulationState.aiScore;
    final p2KingdomAttackUnlocked = simulationState.aiKingdomAttackUnlocked;
    final p2ActiveWinCondition = simulationState.aiActiveWinCondition;

    return SafeArea(
      bottom: false,
      left: false,
      right: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 0, 12, 0),
        child: CustomPaint(
          painter: _HudFramePainter(
            p1Color: p1Color,
            p2Color: p2Color,
            p1IsActive: p1IsActive,
          ),
          child: Container(
            // Stone-dark HUD background with subtle warm depth
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: const [
                  Color(0xFF161410),
                  Color(0xFF0C0B09),
                ],
              ),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                // ── LEFT KINGDOM PANEL ────────────────────────────────
                Expanded(
                  flex: 3,
                  child: ScorePanel(
                    title: p1Name,
                    symbolAsset: p1Symbol,
                    points: p1Score,
                    color: p1Color,
                    kingdomAttackUnlocked: p1KingdomAttackUnlocked,
                    activeWinCondition: p1ActiveWinCondition,
                    isActiveTurn: p1IsActive,
                  ),
                ),

                // ── CENTER COMMAND SEAL ───────────────────────────────
                _CenterCommandSeal(
                  onPausePressed: onPausePressed,
                  p1IsActive: p1IsActive,
                  p1Color: p1Color,
                  p2Color: p2Color,
                ),

                // ── RIGHT KINGDOM PANEL ───────────────────────────────
                Expanded(
                  flex: 3,
                  child: ScorePanel(
                    title: p2Name,
                    symbolAsset: p2Symbol,
                    points: p2Score,
                    color: p2Color,
                    kingdomAttackUnlocked: p2KingdomAttackUnlocked,
                    activeWinCondition: p2ActiveWinCondition,
                    alignment: CrossAxisAlignment.end,
                    isActiveTurn: p2IsActive,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// CENTER COMMAND SEAL — pause button styled as a war seal / command crest
// ─────────────────────────────────────────────────────────────────────────────
class _CenterCommandSeal extends StatefulWidget {
  final VoidCallback onPausePressed;
  final bool p1IsActive;
  final Color p1Color;
  final Color p2Color;

  const _CenterCommandSeal({
    required this.onPausePressed,
    required this.p1IsActive,
    required this.p1Color,
    required this.p2Color,
  });

  @override
  State<_CenterCommandSeal> createState() => _CenterCommandSealState();
}

class _CenterCommandSealState extends State<_CenterCommandSeal> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    // Active faction color leaks into the center divider
    final activeFactionColor =
        widget.p1IsActive ? widget.p1Color : widget.p2Color;

    return GestureDetector(
      onTapDown: (_) => setState(() => _pressed = true),
      onTapUp: (_) {
        setState(() => _pressed = false);
        widget.onPausePressed();
      },
      onTapCancel: () => setState(() => _pressed = false),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 120),
        transform: Matrix4.translationValues(0.0, _pressed ? 2.0 : 0.0, 0.0),
        width: 44,
        height: 44,
        child: CustomPaint(
          painter: _SealPainter(
            color: activeFactionColor,
            isPressed: _pressed,
          ),
          child: Center(
            child: Icon(
              Icons.pause,
              color: _pressed
                  ? activeFactionColor
                  : const Color(0xFFAA9977),
              size: 18,
            ),
          ),
        ),
      ),
    );
  }
}

class _SealPainter extends CustomPainter {
  final Color color;
  final bool isPressed;

  _SealPainter({required this.color, required this.isPressed});

  @override
  void paint(Canvas canvas, Size size) {
    const b = 10.0;
    final w = size.width;
    final h = size.height;

    final path = Path()
      ..moveTo(b, 0)
      ..lineTo(w - b, 0)
      ..lineTo(w, b)
      ..lineTo(w, h - b)
      ..lineTo(w - b, h)
      ..lineTo(b, h)
      ..lineTo(0, h - b)
      ..lineTo(0, b)
      ..close();

    // Background fill
    canvas.drawPath(
      path,
      Paint()
        ..color = isPressed
            ? color.withValues(alpha: 0.20)
            : const Color(0xFF1A1710),
    );

    // Border
    canvas.drawPath(
      path,
      Paint()
        ..color = color.withValues(alpha: isPressed ? 0.9 : 0.45)
        ..strokeWidth = isPressed ? 2.0 : 1.5
        ..style = PaintingStyle.stroke,
    );

    // Inner accent line (double-engraved border)
    const inset = 3.5;
    final innerPath = Path()
      ..moveTo(b + inset, inset)
      ..lineTo(w - b - inset, inset)
      ..lineTo(w - inset, b + inset)
      ..lineTo(w - inset, h - b - inset)
      ..lineTo(w - b - inset, h - inset)
      ..lineTo(b + inset, h - inset)
      ..lineTo(inset, h - b - inset)
      ..lineTo(inset, b + inset)
      ..close();

    canvas.drawPath(
      innerPath,
      Paint()
        ..color = color.withValues(alpha: isPressed ? 0.35 : 0.12)
        ..strokeWidth = 0.7
        ..style = PaintingStyle.stroke,
    );

    // Hard torch-light shadow (bottom-right edge offset line)
    if (!isPressed) {
      canvas.drawPath(
        path,
        Paint()
          ..color = Colors.black.withValues(alpha: 0.6)
          ..strokeWidth = 1.0
          ..style = PaintingStyle.stroke
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 2),
      );
    }
  }

  @override
  bool shouldRepaint(_SealPainter old) =>
      old.color != color || old.isPressed != isPressed;
}

// ─────────────────────────────────────────────────────────────────────────────
// HUD FRAME PAINTER — outer engraved frame for the entire header bar
// Uses bevel-cut corners; colored stripe on each side matches faction color
// ─────────────────────────────────────────────────────────────────────────────
class _HudFramePainter extends CustomPainter {
  final Color p1Color;
  final Color p2Color;
  final bool p1IsActive;

  _HudFramePainter({
    required this.p1Color,
    required this.p2Color,
    required this.p1IsActive,
  });

  @override
  void paint(Canvas canvas, Size size) {
    const b = 10.0; // bevel size
    final w = size.width;
    final h = size.height;

    // Full outer bevel path
    final outerPath = Path()
      ..moveTo(b, 0)
      ..lineTo(w - b, 0)
      ..lineTo(w, b)
      ..lineTo(w, h - b)
      ..lineTo(w - b, h)
      ..lineTo(b, h)
      ..lineTo(0, h - b)
      ..lineTo(0, b)
      ..close();

    // Dark base shadow (depth)
    canvas.drawPath(
      outerPath,
      Paint()
        ..color = Colors.black.withValues(alpha: 0.55)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8),
    );

    // Top edge — neutral stone color
    canvas.drawLine(
      const Offset(b, 0),
      Offset(w - b, 0),
      Paint()
        ..color = const Color(0xFF3A3328)
        ..strokeWidth = 1.0,
    );

    // Bottom edge — darker groove
    canvas.drawLine(
      Offset(b, h),
      Offset(w - b, h),
      Paint()
        ..color = const Color(0xFF1A1610)
        ..strokeWidth = 1.0,
    );

    // Left faction stripe — P1 color
    final p1Active = p1IsActive;
    canvas.drawLine(
      Offset(0, b),
      Offset(0, h - b),
      Paint()
        ..color = p1Color.withValues(alpha: p1Active ? 0.85 : 0.30)
        ..strokeWidth = p1Active ? 2.5 : 1.5,
    );

    // Right faction stripe — P2 color
    canvas.drawLine(
      Offset(w, b),
      Offset(w, h - b),
      Paint()
        ..color = p2Color.withValues(alpha: !p1Active ? 0.85 : 0.30)
        ..strokeWidth = !p1Active ? 2.5 : 1.5,
    );

    // Bevel corner marks — engraved bracket dots
    _drawBevelCorners(canvas, size, b);
  }

  void _drawBevelCorners(Canvas canvas, Size size, double b) {
    final w = size.width;
    final h = size.height;
    final paint = Paint()
      ..color = const Color(0xFF4A4030)
      ..strokeWidth = 1.0
      ..style = PaintingStyle.stroke;

    // Top-left
    canvas.drawLine(Offset(0, b), Offset(b, 0), paint);
    // Top-right
    canvas.drawLine(Offset(w - b, 0), Offset(w, b), paint);
    // Bottom-left
    canvas.drawLine(Offset(0, h - b), Offset(b, h), paint);
    // Bottom-right
    canvas.drawLine(Offset(w - b, h), Offset(w, h - b), paint);
  }

  @override
  bool shouldRepaint(_HudFramePainter old) =>
      old.p1Color != p1Color ||
      old.p2Color != p2Color ||
      old.p1IsActive != p1IsActive;
}