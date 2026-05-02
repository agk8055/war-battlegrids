import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'map_selection_screen.dart';
import 'bluetooth_lobby_screen.dart';
import 'online_lobby_screen.dart';
import '../../core/enums/connection_type.dart';
import '../../providers/turn_provider.dart';

// ─────────────────────────────────────────────────────────────────────────────
//  Painters (shared aesthetic from profile screen)
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

// ─────────────────────────────────────────────────────────────────────────────
//  _StonePanel
// ─────────────────────────────────────────────────────────────────────────────
class _StonePanel extends StatelessWidget {
  final Widget child;
  final Color accentColor;
  final EdgeInsetsGeometry padding;
  final bool isEnabled;

  const _StonePanel({
    required this.child,
    required this.accentColor,
    this.padding = const EdgeInsets.all(20),
    this.isEnabled = true,
  });

  @override
  Widget build(BuildContext context) {
    final ornamentColor = isEnabled ? accentColor.withValues(alpha: 0.5) : Colors.white10;
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: isEnabled 
            ? [const Color(0xFF1A1510), const Color(0xFF0F0D0A)]
            : [const Color(0xFF0F0D0A), const Color(0xFF0A0804)],
        ),
        border: Border.all(
          color: isEnabled ? accentColor.withValues(alpha: 0.28) : Colors.white10, 
          width: 1.2
        ),
        boxShadow: isEnabled ? [
          BoxShadow(color: Colors.black.withValues(alpha: 0.55), blurRadius: 18, offset: const Offset(0, 6)),
          BoxShadow(color: accentColor.withValues(alpha: 0.06), blurRadius: 24, spreadRadius: 2),
        ] : null,
      ),
      child: Stack(
        children: [
          Positioned.fill(
            child: CustomPaint(painter: _HatchPainter(color: Colors.white.withValues(alpha: 0.018))),
          ),
          ..._corners(ornamentColor),
          Padding(padding: padding, child: Center(child: child)),
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
                  child: Image.asset('assets/icons/border-edge.png', color: color)))),
      Positioned(
          top: 0,
          right: 0,
          child: Transform(
              alignment: Alignment.center,
              transform: Matrix4.rotationZ(math.pi),
              child: SizedBox(
                  width: sz,
                  height: sz,
                  child: Image.asset('assets/icons/border-edge.png', color: color)))),
      Positioned(
          bottom: 0,
          left: 0,
          child: SizedBox(
              width: sz,
              height: sz,
              child: Image.asset('assets/icons/border-edge.png', color: color))),
      Positioned(
          bottom: 0,
          right: 0,
          child: Transform(
              alignment: Alignment.center,
              transform: Matrix4.rotationZ(-math.pi / 2),
              child: SizedBox(
                  width: sz,
                  height: sz,
                  child: Image.asset('assets/icons/border-edge.png', color: color)))),
    ];
  }
}

// ─────────────────────────────────────────────────────────────────────────────
//  Press-scale button wrapper
// ─────────────────────────────────────────────────────────────────────────────
class _AnimatedPressButton extends StatefulWidget {
  final Widget child;
  final VoidCallback onTap;
  final bool isEnabled;

  const _AnimatedPressButton({
    required this.child, 
    required this.onTap, 
    this.isEnabled = true
  });

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
      onTapDown: widget.isEnabled ? (_) => _ctrl.forward() : null,
      onTapUp: widget.isEnabled ? (_) { _ctrl.reverse(); widget.onTap(); } : null,
      onTapCancel: widget.isEnabled ? () => _ctrl.reverse() : null,
      child: ScaleTransition(scale: _scale, child: widget.child),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
//  Multiplayer Mode Selection Screen
// ─────────────────────────────────────────────────────────────────────────────
class MultiplayerModeSelectionScreen extends ConsumerWidget {
  const MultiplayerModeSelectionScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final primary = Theme.of(context).colorScheme.primary;

    final List<Map<String, dynamic>> modes = [
      {
        'title': 'ON-DEVICE',
        'subtitle': 'Local same-screen play',
        'icon': Icons.phonelink_setup_rounded,
        'enabled': true,
        'onTap': () {
          ref.read(connectionTypeProvider.notifier).setConnectionType(ConnectionType.local);
          Navigator.push(
            context,
            MaterialPageRoute(
              settings: const RouteSettings(name: '/map_selection'),
              builder: (context) => const MapSelectionScreen(),
            ),
          );
        },
      },
      {
        'title': 'BLUETOOTH',
        'subtitle': 'Nearby connection',
        'icon': Icons.bluetooth_audio_rounded,
        'enabled': true,
        'onTap': () {
          Navigator.push(
            context,
            MaterialPageRoute(
              settings: const RouteSettings(name: '/bluetooth_lobby'),
              builder: (context) => const BluetoothLobbyScreen(),
            ),
          );
        },
      },
      {
        'title': 'ONLINE',
        'subtitle': 'Global battlefield',
        'icon': Icons.public_rounded,
        'enabled': true,
        'onTap': () {
          Navigator.push(
            context,
            MaterialPageRoute(
              settings: const RouteSettings(name: '/online_lobby'),
              builder: (context) => const OnlineLobbyScreen(),
            ),
          );
        },
      },
    ];

    return Scaffold(
      backgroundColor: const Color(0xFF0A0804),
      body: Stack(
        children: [
          // Ambient radial glow
          Positioned.fill(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: RadialGradient(
                  center: const Alignment(0, -0.4),
                  radius: 1.2,
                  colors: [primary.withValues(alpha: 0.08), Colors.transparent],
                ),
              ),
            ),
          ),
          SafeArea(
            child: Column(
              children: [
                const SizedBox(height: 16),
                _buildTopBar(context, primary),
                const SizedBox(height: 48),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24.0),
                  child: Row(
                    children: [
                      Container(width: 18, height: 1.5, color: primary.withValues(alpha: 0.5)),
                      const SizedBox(width: 8),
                      Text(
                        'CHOOSE YOUR BATTLEFRONT',
                        style: TextStyle(
                          color: primary,
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 2.8,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(child: Container(height: 1.5, color: primary.withValues(alpha: 0.5))),
                    ],
                  ),
                ),
                const SizedBox(height: 48),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: modes.map((mode) {
                        final bool isEnabled = mode['enabled'];
                        
                        return Expanded(
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 10.0),
                            child: _AnimatedPressButton(
                              isEnabled: isEnabled,
                              onTap: mode['onTap'],
                              child: AspectRatio(
                                aspectRatio: 0.7, // Vertical rectangle look
                                child: _StonePanel(
                                  isEnabled: isEnabled,
                                  accentColor: primary,
                                  padding: const EdgeInsets.all(12),
                                  child: FittedBox(
                                    fit: BoxFit.scaleDown,
                                    alignment: Alignment.center,
                                    child: Column(
                                      mainAxisAlignment: MainAxisAlignment.center,
                                      crossAxisAlignment: CrossAxisAlignment.center,
                                      children: [
                                        Container(
                                          padding: const EdgeInsets.all(8),
                                          decoration: BoxDecoration(
                                            shape: BoxShape.circle,
                                            color: isEnabled 
                                                ? primary.withValues(alpha: 0.1) 
                                                : Colors.white.withValues(alpha: 0.03),
                                            border: Border.all(
                                              color: isEnabled 
                                                  ? primary.withValues(alpha: 0.3) 
                                                  : Colors.white10,
                                            ),
                                          ),
                                          child: Icon(
                                            mode['icon'],
                                            size: 32,
                                            color: isEnabled 
                                                ? primary 
                                                : Colors.white.withValues(alpha: 0.2),
                                          ),
                                        ),
                                        const SizedBox(height: 16),
                                        Text(
                                          mode['title'],
                                          textAlign: TextAlign.center,
                                          style: GoogleFonts.sairaStencilOne(
                                            color: isEnabled ? primary : Colors.white.withValues(alpha: 0.2),
                                            fontSize: 18,
                                            letterSpacing: 1.5,
                                          ),
                                        ),
                                        const SizedBox(height: 4),
                                        Text(
                                          mode['subtitle'],
                                          textAlign: TextAlign.center,
                                          style: TextStyle(
                                            color: isEnabled 
                                                ? Colors.white.withValues(alpha: 0.5) 
                                                : Colors.white.withValues(alpha: 0.1),
                                            fontSize: 10,
                                            letterSpacing: 0.5,
                                          ),
                                        ),
                                        if (!isEnabled) ...[
                                          const SizedBox(height: 12),
                                          Container(
                                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                            decoration: BoxDecoration(
                                              color: Colors.white.withValues(alpha: 0.05),
                                              borderRadius: BorderRadius.circular(4),
                                              border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
                                            ),
                                            child: const Text(
                                              'SOON',
                                              style: TextStyle(
                                                color: Colors.white24,
                                                fontSize: 8,
                                                fontWeight: FontWeight.bold,
                                                letterSpacing: 1,
                                              ),
                                            ),
                                          ),
                                        ],
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                  ),
                ),
                const SizedBox(height: 80),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTopBar(BuildContext context, Color primary) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        children: [
          GestureDetector(
            onTap: () => Navigator.pop(context),
            child: Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.05),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: primary.withValues(alpha: 0.3), width: 1),
              ),
              child: Icon(Icons.chevron_left, color: primary, size: 22),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'BATTLE MODES',
                  style: TextStyle(
                    color: primary,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 3.5,
                  ),
                ),
                Text(
                  "Choose thy theatre of war",
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.35),
                    fontSize: 11,
                    letterSpacing: 1.2,
                    fontStyle: FontStyle.italic,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
