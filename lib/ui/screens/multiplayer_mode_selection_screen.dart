import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/constants/app_assets.dart';
import 'multiplayer_setup_screen.dart';
import 'bluetooth_lobby_screen.dart';
import 'online_lobby_screen.dart';
import '../../core/enums/connection_type.dart';
import '../../providers/turn_provider.dart';

// ─────────────────────────────────────────────────────────────────────────────
//  Tactical Grid Background Hatch Painter
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
//  Press-scale button wrapper
// ─────────────────────────────────────────────────────────────────────────────
class _AnimatedPressButton extends StatefulWidget {
  final Widget child;
  final VoidCallback onTap;
  final bool isEnabled;

  const _AnimatedPressButton({
    required this.child,
    required this.onTap,
    this.isEnabled = true,
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
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: widget.isEnabled ? (_) => _ctrl.forward() : null,
      onTapUp: widget.isEnabled
          ? (_) {
              _ctrl.reverse();
              widget.onTap();
            }
          : null,
      onTapCancel: widget.isEnabled ? () => _ctrl.reverse() : null,
      child: ScaleTransition(scale: _scale, child: widget.child),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
//  Multiplayer Mode Tile Card (Full Stretched Image, Wide Landscape Aspect)
// ─────────────────────────────────────────────────────────────────────────────
class _ModeCard extends StatelessWidget {
  final String title;
  final String tag;
  final String subtitle;
  final String imagePath;
  final IconData icon;
  final Color accentColor;
  final bool isEnabled;
  final VoidCallback onTap;

  const _ModeCard({
    required this.title,
    required this.tag,
    required this.subtitle,
    required this.imagePath,
    required this.icon,
    required this.accentColor,
    this.isEnabled = true,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    const borderRadius = BorderRadius.all(Radius.circular(16));

    return _AnimatedPressButton(
      isEnabled: isEnabled,
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          borderRadius: borderRadius,
          border: Border.all(
            color: isEnabled
                ? accentColor.withValues(alpha: 0.45)
                : Colors.white12,
            width: 1.5,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.7),
              blurRadius: 18,
              offset: const Offset(0, 6),
            ),
            if (isEnabled)
              BoxShadow(
                color: accentColor.withValues(alpha: 0.12),
                blurRadius: 20,
                spreadRadius: 1,
              ),
          ],
        ),
        child: ClipRRect(
          borderRadius: const BorderRadius.all(Radius.circular(14.5)),
          child: Stack(
            fit: StackFit.expand,
            children: [
              // 1. Full Tile Stretched Background Image
              AppAssetImage(
                imagePath,
                fit: BoxFit.cover,
                alignment: Alignment.center,
              ),

              // 2. Atmospheric Dark Scrim & Bottom Gradient
              DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    stops: const [0.0, 0.3, 0.6, 1.0],
                    colors: [
                      Colors.black.withValues(alpha: 0.65),
                      Colors.black.withValues(alpha: 0.2),
                      Colors.black.withValues(alpha: 0.65),
                      const Color(0xFF0A0804).withValues(alpha: 0.96),
                    ],
                  ),
                ),
              ),

              // 3. Tactical Grid Hatch Pattern
              Positioned.fill(
                child: CustomPaint(
                  painter: _HatchPainter(
                    color: Colors.white.withValues(alpha: 0.02),
                  ),
                ),
              ),

              // 4. Content Overlay
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 14.0, vertical: 10.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    // Top Bar: Glassmorphic Tag Badge & Status Dot
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 3.5,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.black.withValues(alpha: 0.65),
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(
                              color: isEnabled
                                  ? accentColor.withValues(alpha: 0.4)
                                  : Colors.white12,
                              width: 1,
                            ),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                icon,
                                size: 13,
                                color: isEnabled
                                    ? accentColor
                                    : Colors.white38,
                              ),
                              const SizedBox(width: 5),
                              Text(
                                tag,
                                style: TextStyle(
                                  color: isEnabled
                                      ? accentColor
                                      : Colors.white38,
                                  fontSize: 8.5,
                                  fontWeight: FontWeight.w700,
                                  letterSpacing: 1.1,
                                ),
                              ),
                            ],
                          ),
                        ),
                        // Glowing Corner Indicator Dot
                        Container(
                          width: 7,
                          height: 7,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: isEnabled
                                ? accentColor
                                : Colors.white24,
                            boxShadow: isEnabled
                                ? [
                                    BoxShadow(
                                      color: accentColor.withValues(alpha: 0.7),
                                      blurRadius: 6,
                                      spreadRadius: 1,
                                    ),
                                  ]
                                : null,
                          ),
                        ),
                      ],
                    ),

                    const Spacer(),

                    // Bottom Details: Title, Subtitle, Action Bar
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          title,
                          style: GoogleFonts.sairaStencilOne(
                            color: isEnabled ? accentColor : Colors.white38,
                            fontSize: 17,
                            letterSpacing: 1.5,
                            shadows: const [
                              Shadow(
                                color: Colors.black,
                                blurRadius: 8,
                                offset: Offset(0, 2),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          subtitle,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: isEnabled
                                ? Colors.white.withValues(alpha: 0.75)
                                : Colors.white24,
                            fontSize: 9.5,
                            letterSpacing: 0.2,
                          ),
                        ),
                        const SizedBox(height: 8),

                        // Action Bar
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.symmetric(vertical: 5.5),
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: isEnabled
                                  ? [
                                      accentColor.withValues(alpha: 0.28),
                                      accentColor.withValues(alpha: 0.12),
                                    ]
                                  : [Colors.white10, Colors.white10],
                            ),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                              color: isEnabled
                                  ? accentColor.withValues(alpha: 0.45)
                                  : Colors.white12,
                              width: 1,
                            ),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text(
                                isEnabled ? 'DEPLOY' : 'COMING SOON',
                                style: TextStyle(
                                  color: isEnabled ? accentColor : Colors.white38,
                                  fontSize: 9.5,
                                  fontWeight: FontWeight.bold,
                                  letterSpacing: 1.8,
                                ),
                              ),
                              if (isEnabled) ...[
                                const SizedBox(width: 5),
                                Icon(
                                  Icons.arrow_forward_rounded,
                                  color: accentColor,
                                  size: 11,
                                ),
                              ],
                            ],
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
//  Multiplayer Mode Selection Screen
// ─────────────────────────────────────────────────────────────────────────────
class MultiplayerModeSelectionScreen extends ConsumerStatefulWidget {
  const MultiplayerModeSelectionScreen({super.key});

  @override
  ConsumerState<MultiplayerModeSelectionScreen> createState() =>
      _MultiplayerModeSelectionScreenState();
}

class _MultiplayerModeSelectionScreenState
    extends ConsumerState<MultiplayerModeSelectionScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _fadeController;
  late Animation<double> _fadeAnim;

  @override
  void initState() {
    super.initState();
    _fadeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    );
    _fadeAnim = CurvedAnimation(
      parent: _fadeController,
      curve: Curves.easeOutCubic,
    );
    _fadeController.forward();
  }

  @override
  void dispose() {
    _fadeController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final primary = Theme.of(context).colorScheme.primary;

    final List<Map<String, dynamic>> modes = [
      {
        'title': 'ON-DEVICE',
        'tag': 'PASS & PLAY',
        'subtitle': 'Local shared-screen tactical duel for two commanders.',
        'image': AppAssets.onDevice,
        'icon': Icons.phonelink_setup_rounded,
        'enabled': true,
        'onTap': () {
          ref
              .read(connectionTypeProvider.notifier)
              .setConnectionType(ConnectionType.local);
          Navigator.push(
            context,
            MaterialPageRoute(
              settings: const RouteSettings(name: '/multiplayer_setup'),
              builder: (context) => const MultiplayerSetupScreen(),
            ),
          );
        },
      },
      {
        'title': 'BLUETOOTH',
        'tag': 'NEARBY P2P',
        'subtitle': 'Direct wireless link between nearby device commanders.',
        'image': AppAssets.bluetooth,
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
        'tag': 'GLOBAL REALM',
        'subtitle': 'Conquer online battlefields across worldwide rooms.',
        'image': AppAssets.online,
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
          // Ambient radial backdrop glow
          Positioned.fill(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: RadialGradient(
                  center: const Alignment(0, -0.4),
                  radius: 1.2,
                  colors: [
                    primary.withValues(alpha: 0.1),
                    Colors.transparent,
                  ],
                ),
              ),
            ),
          ),
          // Subtle tactical grid background
          Positioned.fill(
            child: CustomPaint(
              painter: _HatchPainter(
                color: Colors.white.withValues(alpha: 0.015),
              ),
            ),
          ),
          SafeArea(
            child: FadeTransition(
              opacity: _fadeAnim,
              child: Column(
                children: [
                  const SizedBox(height: 12),
                  _buildTopBar(context, primary),
                  const SizedBox(height: 14),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 24.0),
                    child: Row(
                      children: [
                        Container(
                          width: 20,
                          height: 1.5,
                          color: primary.withValues(alpha: 0.6),
                        ),
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
                        Expanded(
                          child: Container(
                            height: 1.5,
                            color: primary.withValues(alpha: 0.4),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 14),
                  Expanded(
                    child: Center(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 20),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: modes.map((mode) {
                            final bool isEnabled = mode['enabled'];

                            return Expanded(
                              child: Padding(
                                padding:
                                    const EdgeInsets.symmetric(horizontal: 8.0),
                                child: AspectRatio(
                                  aspectRatio: 1.42,
                                  child: _ModeCard(
                                    title: mode['title'],
                                    tag: mode['tag'],
                                    subtitle: mode['subtitle'],
                                    imagePath: mode['image'],
                                    icon: mode['icon'],
                                    accentColor: primary,
                                    isEnabled: isEnabled,
                                    onTap: mode['onTap'],
                                  ),
                                ),
                              ),
                            );
                          }).toList(),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                ],
              ),
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
                border: Border.all(
                  color: primary.withValues(alpha: 0.3),
                  width: 1,
                ),
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
