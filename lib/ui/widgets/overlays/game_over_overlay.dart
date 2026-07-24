import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'dart:ui';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../core/constants/app_assets.dart';
import '../../../core/enums/turn.dart';
import '../../../core/enums/game_mode.dart';
import '../../../providers/game_settings_provider.dart';
import '../../../providers/bluetooth_provider.dart';
import '../../../providers/online_provider.dart';
import '../../../core/enums/connection_type.dart';
import '../../../providers/turn_provider.dart';

class GameOverOverlay extends ConsumerStatefulWidget {
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
  ConsumerState<GameOverOverlay> createState() => _GameOverOverlayState();
}

class _GameOverOverlayState extends ConsumerState<GameOverOverlay>
    with TickerProviderStateMixin {
  late AnimationController _fadeController;
  late AnimationController _panelController;

  late Animation<double> _bgFade;
  late Animation<Offset> _panelSlide;
  late Animation<double> _panelFade;

  @override
  void initState() {
    super.initState();

    _fadeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    
    _panelController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );

    _bgFade = CurvedAnimation(parent: _fadeController, curve: Curves.easeIn);

    _panelSlide = Tween<Offset>(
      begin: const Offset(0, 0.08),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _panelController, curve: Curves.easeOutBack));
    
    _panelFade = CurvedAnimation(parent: _panelController, curve: Curves.easeIn);

    // Staggered entrance
    _fadeController.forward();
    Future.delayed(const Duration(milliseconds: 300), () {
      if (mounted) _panelController.forward();
    });
  }

  @override
  void dispose() {
    _fadeController.dispose();
    _panelController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final settings = ref.watch(gameSettingsProvider);
    final bluetoothState = ref.watch(bluetoothProvider);
    final onlineState = ref.watch(onlineProvider);
    final connectionType = ref.watch(connectionTypeProvider);

    final isMultiplayer = widget.mode == GameMode.multiplayer;
    
    // Determine if we are 'host' for visual mapping purposes
    bool isHost = true;
    if (connectionType == ConnectionType.bluetooth) {
      isHost = bluetoothState.isHost;
    } else if (connectionType == ConnectionType.online) {
      isHost = onlineState.isHost;
    }

    final isBluetooth = connectionType == ConnectionType.bluetooth;
    final isOnline = connectionType == ConnectionType.online;
    final isSameDevice = isMultiplayer && !isBluetooth && !isOnline;

    final isLocalPlayerWin = isMultiplayer
        ? (isHost ? widget.winner == Turn.player : widget.winner == Turn.ai)
        : (widget.winner == Turn.player);

    String title;
    String subtitle;
    Color accentColor;

    if (isSameDevice) {
      final winnerName = widget.winner == Turn.player
          ? settings.player1Name
          : settings.player2Name;
      title = "${winnerName.toUpperCase()} WINS";
      subtitle = widget.winner == Turn.player
          ? "The realm of ${settings.player1Name} has triumphed."
          : "The realm of ${settings.player2Name} has triumphed.";
      accentColor = widget.winner == Turn.player
          ? Color(settings.player1Color)
          : Color(settings.player2Color);
    } else {
      title = isLocalPlayerWin ? "VICTORY" : "DEFEAT";
      accentColor = isLocalPlayerWin
          ? const Color(0xFF4CAF50) // Emerald/Green for Victory
          : const Color(0xFFF44336); // Red for Defeat

      if (isMultiplayer) {
        subtitle = isLocalPlayerWin
            ? "You have claimed dominance over the battlefield."
            : "Your kingdom's siege defenses have been breached.";
      } else {
        subtitle = isLocalPlayerWin
            ? "The enemy kingdom has fallen to your blockade."
            : "Your kingdom's siege defenses have been breached.";
      }
    }

    final buttonLabel = isMultiplayer ? "RETURN TO LOBBY" : "RETURN TO MAP";

    return Positioned.fill(
      child: FadeTransition(
        opacity: _bgFade,
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 5.0, sigmaY: 5.0),
          child: Container(
            color: Colors.black.withValues(alpha: 0.8),
            child: Center(
              child: SlideTransition(
                position: _panelSlide,
                child: FadeTransition(
                  opacity: _panelFade,
                  child: Container(
                    width: 450,
                    padding: const EdgeInsets.symmetric(horizontal: 24),
                    child: _StonePanel(
                      accentColor: accentColor,
                      padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 40),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          _SectionLabel("BATTLE CONCLUDED", color: accentColor),
                          const SizedBox(height: 28),
                          FittedBox(
                            fit: BoxFit.scaleDown,
                            child: Text(
                              title,
                              textAlign: TextAlign.center,
                              style: GoogleFonts.sairaStencilOne(
                                fontSize: 52,
                                fontWeight: FontWeight.bold,
                                color: accentColor,
                                letterSpacing: 8.0,
                                shadows: [
                                  BoxShadow(
                                    color: accentColor.withValues(alpha: 0.4),
                                    blurRadius: 20,
                                    spreadRadius: 2,
                                  ),
                                ],
                              ),
                            ),
                          ),
                          const SizedBox(height: 16),
                          Text(
                            subtitle,
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: Colors.white.withValues(alpha: 0.5),
                              fontSize: 13,
                              fontStyle: FontStyle.italic,
                              letterSpacing: 0.5,
                              height: 1.5,
                            ),
                          ),
                          const SizedBox(height: 48),
                          _buildActionButton(
                            label: buttonLabel,
                            onPressed: widget.onReturnToMap,
                            color: accentColor,
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildActionButton({
    required String label,
    required VoidCallback onPressed,
    required Color color,
  }) {
    return _AnimatedPressButton(
      onTap: onPressed,
      accentColor: color,
      child: Container(
        height: 58,
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: color.withValues(alpha: 0.4), width: 1.5),
          boxShadow: [
            BoxShadow(
              color: color.withValues(alpha: 0.05),
              blurRadius: 12,
              spreadRadius: 2,
            ),
          ],
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.map_outlined, color: color, size: 20),
            const SizedBox(width: 14),
            Text(
              label,
              style: GoogleFonts.sairaStencilOne(
                color: Colors.white.withValues(alpha: 0.9),
                fontSize: 16,
                fontWeight: FontWeight.bold,
                letterSpacing: 2,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
//  Shared Aesthetic Components
// ─────────────────────────────────────────────────────────────────────────────

class _HatchPainter extends CustomPainter {
  final Color color;
  const _HatchPainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = 0.6;
    const spacing = 22.0;
    for (double i = -size.height; i < size.width + size.height; i += spacing) {
      canvas.drawLine(Offset(i, 0), Offset(i + size.height, size.height), paint);
    }
  }

  @override
  bool shouldRepaint(_HatchPainter old) => old.color != color;
}

class _StonePanel extends StatelessWidget {
  final Widget child;
  final Color accentColor;
  final EdgeInsetsGeometry padding;

  const _StonePanel({
    required this.child,
    required this.accentColor,
    this.padding = const EdgeInsets.all(20),
  });

  @override
  Widget build(BuildContext context) {
    final ornamentColor = accentColor.withValues(alpha: 0.5);
    return Container(
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF1A1510), Color(0xFF0F0D0A)],
        ),
        border: Border.all(color: accentColor.withValues(alpha: 0.28), width: 1.2),
        boxShadow: [
          BoxShadow(color: Colors.black.withValues(alpha: 0.55), blurRadius: 18, offset: const Offset(0, 6)),
          BoxShadow(color: accentColor.withValues(alpha: 0.06), blurRadius: 24, spreadRadius: 2),
        ],
      ),
      child: Stack(
        children: [
          Positioned.fill(
            child: CustomPaint(painter: _HatchPainter(color: Colors.white.withValues(alpha: 0.018))),
          ),
          ..._corners(ornamentColor),
          Padding(padding: padding, child: child),
        ],
      ),
    );
  }

  List<Widget> _corners(Color color) {
    const sz = 24.0;
    return [
      Positioned(
          top: 0,
          left: 0,
          child: Transform(
              alignment: Alignment.center,
              transform: Matrix4.rotationZ(math.pi / 2),
              child: SizedBox(
                  width: sz,
                  height: sz,
                  child: AppAssetImage(AppAssets.borderEdge, color: color)))),
      Positioned(
          top: 0,
          right: 0,
          child: Transform(
              alignment: Alignment.center,
              transform: Matrix4.rotationZ(math.pi),
              child: SizedBox(
                  width: sz,
                  height: sz,
                  child: AppAssetImage(AppAssets.borderEdge, color: color)))),
      Positioned(
          bottom: 0,
          left: 0,
          child: SizedBox(
              width: sz,
              height: sz,
              child: AppAssetImage(AppAssets.borderEdge, color: color))),
      Positioned(
          bottom: 0,
          right: 0,
          child: Transform(
              alignment: Alignment.center,
              transform: Matrix4.rotationZ(-math.pi / 2),
              child: SizedBox(
                  width: sz,
                  height: sz,
                  child: AppAssetImage(AppAssets.borderEdge, color: color)))),
    ];
  }
}

class _SectionLabel extends StatelessWidget {
  final String text;
  final Color color;
  const _SectionLabel(this.text, {required this.color});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(width: 18, height: 1.5, color: color.withValues(alpha: 0.5)),
        const SizedBox(width: 8),
        Text(text, style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.bold, letterSpacing: 2.8)),
        const SizedBox(width: 8),
        Expanded(child: Container(height: 1.5, color: color.withValues(alpha: 0.5))),
      ],
    );
  }
}

class _AnimatedPressButton extends StatefulWidget {
  final Widget child;
  final VoidCallback onTap;
  final Color accentColor;

  const _AnimatedPressButton({required this.child, required this.onTap, required this.accentColor});

  @override
  State<_AnimatedPressButton> createState() => _AnimatedPressButtonState();
}

class _AnimatedPressButtonState extends State<_AnimatedPressButton>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _scale;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 110),
      reverseDuration: const Duration(milliseconds: 180),
    );
    _scale = Tween<double>(begin: 1.0, end: 0.96)
        .animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeInOut));
  }

  @override
  void dispose() { _ctrl.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) => _ctrl.forward(),
      onTapUp: (_) { _ctrl.reverse(); widget.onTap(); },
      onTapCancel: () => _ctrl.reverse(),
      child: ScaleTransition(scale: _scale, child: widget.child),
    );
  }
}
