import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../core/constants/app_assets.dart';
import '../../core/enums/connection_type.dart';
import '../../core/enums/game_mode.dart';
import '../../core/services/audio_service.dart';
import '../../providers/bluetooth_provider.dart';
import '../../providers/game_settings_provider.dart';
import '../../providers/simulation_provider.dart';
import '../../providers/turn_provider.dart';
import 'game_screen.dart';
import 'map_selection_screen.dart';

// ─────────────────────────────────────────────────────────────────────────────
//  Decorative Painter – subtle diagonal hatch lines (parchment feel)
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
//  Stone Panel
// ─────────────────────────────────────────────────────────────────────────────
class _StonePanel extends StatelessWidget {
  final Widget child;
  final Color accentColor;
  final EdgeInsetsGeometry padding;

  const _StonePanel({
    required this.child,
    required this.accentColor,
    this.padding = const EdgeInsets.all(16),
  });

  @override
  Widget build(BuildContext context) {
    final ornamentColor = accentColor.withValues(alpha: 0.55);
    final r = BorderRadius.circular(16);
    return Container(
      decoration: BoxDecoration(
        borderRadius: r,
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color(0xFF1C1610),
            Color(0xFF0D0B08),
          ],
        ),
        border: Border.all(color: accentColor.withValues(alpha: 0.32), width: 1.4),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.65),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
          BoxShadow(
            color: accentColor.withValues(alpha: 0.1),
            blurRadius: 24,
            spreadRadius: 1,
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: r,
        child: Stack(
          children: [
            Positioned.fill(
              child: CustomPaint(
                painter: _HatchPainter(
                  color: Colors.white.withValues(alpha: 0.02),
                ),
              ),
            ),
            ..._corners(ornamentColor),
            Padding(padding: padding, child: child),
          ],
        ),
      ),
    );
  }

  List<Widget> _corners(Color color) {
    const sz = 20.0;
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
            child: AppAssetImage(AppAssets.borderEdge, color: color),
          ),
        ),
      ),
      Positioned(
        top: 0,
        right: 0,
        child: Transform(
          alignment: Alignment.center,
          transform: Matrix4.rotationZ(math.pi),
          child: SizedBox(
            width: sz,
            height: sz,
            child: AppAssetImage(AppAssets.borderEdge, color: color),
          ),
        ),
      ),
      Positioned(
        bottom: 0,
        left: 0,
        child: SizedBox(
          width: sz,
          height: sz,
          child: AppAssetImage(AppAssets.borderEdge, color: color),
        ),
      ),
      Positioned(
        bottom: 0,
        right: 0,
        child: Transform(
          alignment: Alignment.center,
          transform: Matrix4.rotationZ(-math.pi / 2),
          child: SizedBox(
            width: sz,
            height: sz,
            child: AppAssetImage(AppAssets.borderEdge, color: color),
          ),
        ),
      ),
    ];
  }
}

// ─────────────────────────────────────────────────────────────────────────────
//  Section Label
// ─────────────────────────────────────────────────────────────────────────────
class _SectionLabel extends StatelessWidget {
  final String text;
  final Color color;
  final Widget? trailing;

  const _SectionLabel(this.text, {required this.color, this.trailing});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(width: 14, height: 2, color: color.withValues(alpha: 0.6)),
        const SizedBox(width: 8),
        Text(
          text,
          style: TextStyle(
            color: color,
            fontSize: 10.5,
            fontWeight: FontWeight.bold,
            letterSpacing: 2.2,
          ),
        ),
        const SizedBox(width: 8),
        Expanded(child: Container(height: 1.5, color: color.withValues(alpha: 0.3))),
        if (trailing != null) ...[
          const SizedBox(width: 8),
          trailing!,
        ],
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
//  Bluetooth Lobby Screen
// ─────────────────────────────────────────────────────────────────────────────
class BluetoothLobbyScreen extends ConsumerStatefulWidget {
  const BluetoothLobbyScreen({super.key});

  @override
  ConsumerState<BluetoothLobbyScreen> createState() => _BluetoothLobbyScreenState();
}

class _BluetoothLobbyScreenState extends ConsumerState<BluetoothLobbyScreen>
    with TickerProviderStateMixin {
  bool _isHosting = false;
  bool _isJoining = false;
  final TextEditingController _thresholdController = TextEditingController();

  final List<String> _availableSigils = AppAssets.availableSymbols;

  final List<Color> _availableColors = const [
    Color(0xFF1E88E5), // Royal Blue
    Color(0xFFE53935), // Crimson Red
    Color(0xFF43A047), // Emerald Green
    Color(0xFFFB8C00), // Amber Flame
    Color(0xFF8E24AA), // Imperial Purple
    Color(0xFFFDD835), // Solar Gold
    Color(0xFF00ACC1), // Mystic Cyan
    Color(0xFFD81B60), // Rose Valkyrie
  ];

  // Animation controllers
  late AnimationController _fadeController;
  late AnimationController _slideController;
  late AnimationController _pulseController;
  late Animation<double> _fadeAnim;
  late Animation<Offset> _slideAnim;
  late Animation<double> _pulseAnim;

  @override
  void initState() {
    super.initState();
    final bluetoothState = ref.read(bluetoothProvider);
    _isHosting = bluetoothState.isHost && bluetoothState.status != BluetoothStatus.idle;
    _isJoining = !bluetoothState.isHost && bluetoothState.status != BluetoothStatus.idle;
    _thresholdController.text = '${bluetoothState.kingdomAttackThreshold}';

    _fadeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 650),
    );
    _slideController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2200),
    )..repeat(reverse: true);

    _fadeAnim = CurvedAnimation(parent: _fadeController, curve: Curves.easeIn);
    _slideAnim = Tween<Offset>(
      begin: const Offset(0, 0.06),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _slideController, curve: Curves.easeOutCubic));

    _pulseAnim = Tween<double>(begin: 0.92, end: 1.05).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );

    Future.delayed(const Duration(milliseconds: 80), () {
      if (mounted) {
        _fadeController.forward();
        _slideController.forward();
      }
    });
  }

  @override
  void dispose() {
    _thresholdController.dispose();
    _fadeController.dispose();
    _slideController.dispose();
    _pulseController.dispose();
    super.dispose();
  }

  void _playClickSound() {
    ref.read(audioServiceProvider).playSfx(AppAssets.sfxClick);
  }

  String _getSigilTitle(String path) {
    final name = path.split('/').last.split('.').first;
    switch (name) {
      case 'fire':
        return 'Flame Sovereign';
      case 'tiger':
        return 'Fierce Vanguard';
      case 'flash':
        return 'Storm Striker';
      case 'hacker':
        return 'Shadow Strategist';
      case 'lion':
        return 'High Monarch';
      case 'wolf':
        return 'Pack Alpha';
      case 'bull':
        return 'Iron Juggernaut';
      case 'shuriken':
        return 'Silent Blade';
      default:
        return 'House Champion';
    }
  }

  String _getMapImage(String? path) {
    if (path == null) return AppAssets.northernForest;
    if (path.contains('northern_forest')) return AppAssets.northernForest;
    if (path.contains('desert')) return AppAssets.pyramid;
    if (path.contains('25x25')) return AppAssets.grasslandArmy;
    if (path.contains('icelands')) return AppAssets.winterCastle;
    return AppAssets.northernForest;
  }

  void _handleHost() {
    _playClickSound();
    setState(() {
      _isHosting = true;
      _isJoining = false;
    });
    ref.read(bluetoothProvider.notifier).startHosting();
  }

  void _handleJoin() {
    _playClickSound();
    setState(() {
      _isJoining = true;
      _isHosting = false;
    });
    ref.read(bluetoothProvider.notifier).startScanning();
  }

  void _setThreshold(int val) {
    _playClickSound();
    final clamped = val.clamp(10, 500);
    setState(() {
      _thresholdController.text = '$clamped';
    });
    ref.read(bluetoothProvider.notifier).updateSettings(threshold: clamped);
  }

  void _startGame() {
    if (!mounted) return;
    _playClickSound();

    ref.read(connectionTypeProvider.notifier).setConnectionType(ConnectionType.bluetooth);
    ref.read(gameSettingsProvider.notifier).setMode(GameMode.multiplayer);
    ref.read(simulationProvider.notifier).reset();

    ref.read(bluetoothProvider.notifier).setGameStarted(true);

    if (ref.read(bluetoothProvider).isHost) {
      ref.read(bluetoothProvider.notifier).sendStartGame();
    }

    Navigator.of(context).pushReplacement(
      PageRouteBuilder(
        settings: const RouteSettings(name: '/game'),
        pageBuilder: (_, animation, __) => const GameScreen(),
        transitionsBuilder: (_, animation, __, child) {
          return FadeTransition(
            opacity: CurvedAnimation(parent: animation, curve: Curves.easeIn),
            child: child,
          );
        },
        transitionDuration: const Duration(milliseconds: 500),
      ),
    );
  }

  Future<bool> _onWillPop() async {
    final bluetoothState = ref.read(bluetoothProvider);
    if (bluetoothState.status == BluetoothStatus.connected ||
        bluetoothState.status == BluetoothStatus.connecting) {
      final confirm = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          backgroundColor: const Color(0xFF14100C),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: BorderSide(color: Colors.redAccent.withValues(alpha: 0.4), width: 1.4),
          ),
          title: Text(
            'ABANDON REALM?',
            style: GoogleFonts.sairaStencilOne(
              color: Colors.redAccent,
              fontSize: 16,
              letterSpacing: 2,
            ),
          ),
          content: const Text(
            'Leaving now will close the war room and disconnect you from your opponent.',
            style: TextStyle(color: Colors.white70, fontSize: 13),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('STAY', style: TextStyle(color: Colors.white54, fontWeight: FontWeight.bold)),
            ),
            TextButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text('LEAVE', style: TextStyle(color: Colors.redAccent, fontWeight: FontWeight.bold)),
            ),
          ],
        ),
      );
      if (confirm == true) {
        ref.read(bluetoothProvider.notifier).disconnect();
        return true;
      }
      return false;
    }

    if (bluetoothState.status != BluetoothStatus.idle) {
      ref.read(bluetoothProvider.notifier).disconnect();
    }
    return true;
  }

  // ───────────────────────────────────────────────────────────────────────────
  //  Build
  // ───────────────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    final bluetoothState = ref.watch(bluetoothProvider);
    final theme = Theme.of(context);
    final primary = theme.colorScheme.primary;

    final p1Color = Color(bluetoothState.player1Color);
    final p2Color = Color(bluetoothState.player2Color);

    ref.listen(bluetoothProvider, (previous, next) {
      if (!mounted) return;

      if (next.status == BluetoothStatus.idle && previous?.status == BluetoothStatus.connected) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Your opponent has disconnected'),
            backgroundColor: Colors.redAccent,
          ),
        );
        setState(() {
          _isHosting = false;
          _isJoining = false;
        });
      }

      if (next.status == BluetoothStatus.failed && previous?.status != BluetoothStatus.failed) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Connection failed or permission denied'),
            backgroundColor: Colors.redAccent,
          ),
        );
      }

      if (next.gameStarted && !(previous?.gameStarted ?? false) && !next.isHost) {
        _startGame();
      }

      if (next.kingdomAttackThreshold != previous?.kingdomAttackThreshold) {
        if (_thresholdController.text != '${next.kingdomAttackThreshold}') {
          _thresholdController.text = '${next.kingdomAttackThreshold}';
        }
      }
    });

    final bool inRoomView = bluetoothState.status == BluetoothStatus.connected;

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) async {
        if (didPop) return;
        final navigator = Navigator.of(context);
        final shouldPop = await _onWillPop();
        if (shouldPop && mounted) {
          navigator.pop();
        }
      },
      child: Scaffold(
        backgroundColor: const Color(0xFF090704),
        body: Stack(
          children: [
            // Ambient dynamic glow
            Positioned.fill(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: RadialGradient(
                    center: const Alignment(-0.5, -0.6),
                    radius: 1.2,
                    colors: [
                      p1Color.withValues(alpha: 0.12),
                      Colors.transparent,
                    ],
                  ),
                ),
              ),
            ),
            Positioned.fill(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: RadialGradient(
                    center: const Alignment(0.5, 0.6),
                    radius: 1.2,
                    colors: [
                      p2Color.withValues(alpha: 0.12),
                      Colors.transparent,
                    ],
                  ),
                ),
              ),
            ),

            // Content
            SafeArea(
              child: FadeTransition(
                opacity: _fadeAnim,
                child: SlideTransition(
                  position: _slideAnim,
                  child: Column(
                    children: [
                      _buildAppBar(primary, inRoomView),
                      Expanded(
                        child: SingleChildScrollView(
                          physics: const BouncingScrollPhysics(),
                          padding: const EdgeInsets.fromLTRB(14, 4, 14, 28),
                          child: Center(
                            child: ConstrainedBox(
                              constraints: const BoxConstraints(maxWidth: 1000),
                              child: Column(
                                children: [
                                  if (!_isHosting && !_isJoining && !inRoomView)
                                    _buildModeSelectionView(bluetoothState, primary)
                                  else if (_isJoining && !inRoomView)
                                    _buildScanningView(bluetoothState, primary)
                                  else if (_isHosting && !inRoomView)
                                    _buildHostWaitingView(bluetoothState, primary)
                                  else
                                    _buildInRoomView(bluetoothState, primary, p1Color, p2Color),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ───────────────────────────────────────────────────────────────────────────
  //  App Bar
  // ───────────────────────────────────────────────────────────────────────────
  Widget _buildAppBar(Color primary, bool inRoomView) {
    final bluetoothState = ref.watch(bluetoothProvider);

    String statusBadgeText;
    Color statusBadgeColor;
    IconData statusIcon;

    switch (bluetoothState.status) {
      case BluetoothStatus.connected:
        statusBadgeText = 'CONNECTED';
        statusBadgeColor = const Color(0xFF43A047);
        statusIcon = Icons.bluetooth_connected;
        break;
      case BluetoothStatus.connecting:
        statusBadgeText = 'CONNECTING';
        statusBadgeColor = Colors.orange;
        statusIcon = Icons.bluetooth_searching;
        break;
      case BluetoothStatus.scanning:
        statusBadgeText = bluetoothState.isHost ? 'BROADCASTING' : 'SCANNING';
        statusBadgeColor = primary;
        statusIcon = bluetoothState.isHost ? Icons.wifi_tethering_rounded : Icons.radar;
        break;
      case BluetoothStatus.failed:
        statusBadgeText = 'FAILED';
        statusBadgeColor = Colors.redAccent;
        statusIcon = Icons.bluetooth_disabled;
        break;
      case BluetoothStatus.idle:
        statusBadgeText = 'STANDBY';
        statusBadgeColor = primary.withValues(alpha: 0.7);
        statusIcon = Icons.bluetooth;
        break;
    }

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
      child: Row(
        children: [
          _AnimatedPressButton(
            onTap: () async {
              _playClickSound();
              if (inRoomView) {
                if (await _onWillPop() && mounted) {
                  setState(() {
                    _isHosting = false;
                    _isJoining = false;
                  });
                }
              } else if (_isJoining || _isHosting) {
                ref.read(bluetoothProvider.notifier).disconnect();
                setState(() {
                  _isJoining = false;
                  _isHosting = false;
                });
              } else {
                Navigator.pop(context);
              }
            },
            accentColor: primary,
            child: Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.05),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: primary.withValues(alpha: 0.35),
                  width: 1,
                ),
              ),
              child: Icon(Icons.chevron_left, color: primary, size: 22),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'WAR COUNCIL',
                  style: GoogleFonts.sairaStencilOne(
                    color: primary,
                    fontSize: 19,
                    letterSpacing: 2.5,
                  ),
                ),
                Text(
                  inRoomView
                      ? 'Bluetooth Realm Chamber · Local Combat Duel'
                      : 'Bluetooth Multiplayer · Proximity War Duel',
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.45),
                    fontSize: 10.5,
                    letterSpacing: 1.1,
                    fontStyle: FontStyle.italic,
                  ),
                ),
              ],
            ),
          ),
          // Status Badge
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: statusBadgeColor.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: statusBadgeColor.withValues(alpha: 0.4),
                width: 1,
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  statusIcon,
                  color: statusBadgeColor,
                  size: 14,
                ),
                const SizedBox(width: 5),
                Text(
                  statusBadgeText,
                  style: TextStyle(
                    color: statusBadgeColor,
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 1.2,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ───────────────────────────────────────────────────────────────────────────
  //  View 1: Mode Selection (Host vs Join)
  // ───────────────────────────────────────────────────────────────────────────
  Widget _buildModeSelectionView(BluetoothState bluetoothState, Color primary) {
    final settings = ref.watch(gameSettingsProvider);

    return Column(
      children: [
        const SizedBox(height: 12),
        // Your Kingdom Banner
        _StonePanel(
          accentColor: primary,
          padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 18),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.shield, color: primary, size: 16),
              const SizedBox(width: 10),
              Text(
                'YOUR KINGDOM: ${settings.player1Name.toUpperCase()}',
                style: GoogleFonts.sairaStencilOne(
                  color: primary,
                  fontSize: 13,
                  letterSpacing: 2,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 24),

        // Host & Join Cards Row (or Vertical on small screens)
        LayoutBuilder(
          builder: (context, constraints) {
            final isNarrow = constraints.maxWidth < 650;
            final hostCard = _buildModeCard(
              title: 'HOST REALM',
              subtitle: 'Broadcast a proximity war signal and summon nearby commanders',
              icon: Icons.wifi_tethering_rounded,
              accentColor: primary,
              isEnabled: true,
              onTap: _handleHost,
            );

            final joinCard = _buildModeCard(
              title: 'JOIN REALM',
              subtitle: 'Scan local ether for active warlords and nearby battlegrounds',
              icon: Icons.radar_rounded,
              accentColor: const Color(0xFFFB8C00),
              isEnabled: true,
              onTap: _handleJoin,
            );

            if (isNarrow) {
              return Column(
                children: [
                  hostCard,
                  const SizedBox(height: 16),
                  joinCard,
                ],
              );
            }

            return Row(
              children: [
                Expanded(child: hostCard),
                const SizedBox(width: 16),
                Expanded(child: joinCard),
              ],
            );
          },
        ),
      ],
    );
  }

  Widget _buildModeCard({
    required String title,
    required String subtitle,
    required IconData icon,
    required Color accentColor,
    required bool isEnabled,
    required VoidCallback? onTap,
  }) {
    final effectiveColor = isEnabled ? accentColor : Colors.white24;

    return Opacity(
      opacity: isEnabled ? 1.0 : 0.5,
      child: _AnimatedPressButton(
        onTap: isEnabled ? (onTap ?? () {}) : () {},
        accentColor: effectiveColor,
        isEnabled: isEnabled,
        child: _StonePanel(
          accentColor: effectiveColor,
          padding: const EdgeInsets.all(22),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: effectiveColor.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: effectiveColor.withValues(alpha: 0.4), width: 1.2),
                    ),
                    child: Icon(icon, color: effectiveColor, size: 26),
                  ),
                  Icon(
                    isEnabled ? Icons.chevron_right : Icons.lock_outline,
                    color: effectiveColor.withValues(alpha: 0.6),
                    size: 22,
                  ),
                ],
              ),
              const SizedBox(height: 20),
              Text(
                title,
                style: GoogleFonts.sairaStencilOne(
                  color: effectiveColor,
                  fontSize: 17,
                  letterSpacing: 2,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                subtitle,
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.55),
                  fontSize: 11.5,
                  height: 1.35,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ───────────────────────────────────────────────────────────────────────────
  //  View 2: Scanning & Nearby Device List (Join View)
  // ───────────────────────────────────────────────────────────────────────────
  Widget _buildScanningView(BluetoothState bluetoothState, Color primary) {
    final devices = bluetoothState.discoveredDevices;

    return Column(
      children: [
        const SizedBox(height: 12),
        _StonePanel(
          accentColor: primary,
          padding: const EdgeInsets.all(20),
          child: Column(
            children: [
              _SectionLabel('NEARBY BATTLEGROUNDS', color: primary),
              const SizedBox(height: 16),
              if (devices.isEmpty) ...[
                const SizedBox(height: 16),
                AnimatedBuilder(
                  animation: _pulseAnim,
                  builder: (context, child) {
                    return Container(
                      width: 68,
                      height: 68,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: primary.withValues(alpha: 0.05),
                        border: Border.all(
                          color: primary.withValues(alpha: 0.35 * _pulseAnim.value),
                          width: 1.6,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: primary.withValues(alpha: 0.2 * _pulseAnim.value),
                            blurRadius: 18,
                            spreadRadius: 1,
                          ),
                        ],
                      ),
                      child: Icon(
                        Icons.radar,
                        color: primary.withValues(alpha: 0.7 * _pulseAnim.value),
                        size: 32,
                      ),
                    );
                  },
                ),
                const SizedBox(height: 20),
                Text(
                  'SCANNING LOCAL REALMS...',
                  style: GoogleFonts.sairaStencilOne(
                    color: primary,
                    fontSize: 14,
                    letterSpacing: 1.5,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  'Seeking nearby hosts broadcasting a battle challenge.\nEnsure your rival is hosting in the War Council.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.45),
                    fontSize: 11,
                    height: 1.4,
                    fontStyle: FontStyle.italic,
                  ),
                ),
                const SizedBox(height: 16),
              ] else ...[
                Text(
                  'Found active war beacons nearby. Tap to infiltrate realm.',
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.5),
                    fontSize: 11,
                    fontStyle: FontStyle.italic,
                  ),
                ),
                const SizedBox(height: 16),
                ListView.separated(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: devices.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 10),
                  itemBuilder: (context, index) {
                    final device = devices[index];
                    return _AnimatedPressButton(
                      onTap: () {
                        _playClickSound();
                        ref.read(bluetoothProvider.notifier).connectToDevice(device);
                      },
                      accentColor: primary,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                        decoration: BoxDecoration(
                          color: primary.withValues(alpha: 0.08),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: primary.withValues(alpha: 0.35),
                            width: 1.2,
                          ),
                        ),
                        child: Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: primary.withValues(alpha: 0.15),
                                shape: BoxShape.circle,
                              ),
                              child: Icon(Icons.bluetooth_searching, color: primary, size: 18),
                            ),
                            const SizedBox(width: 14),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    device.name.toUpperCase(),
                                    style: GoogleFonts.sairaStencilOne(
                                      color: Colors.white,
                                      fontSize: 14,
                                      letterSpacing: 1.2,
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    'Proximity War Signal Ready · Tap to Duel',
                                    style: TextStyle(
                                      color: primary.withValues(alpha: 0.8),
                                      fontSize: 10,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                              decoration: BoxDecoration(
                                color: primary.withValues(alpha: 0.2),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(Icons.login, color: primary, size: 12),
                                  const SizedBox(width: 4),
                                  Text(
                                    'JOIN',
                                    style: TextStyle(
                                      color: primary,
                                      fontSize: 10,
                                      fontWeight: FontWeight.bold,
                                      letterSpacing: 1,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ],
            ],
          ),
        ),
        const SizedBox(height: 18),
        TextButton(
          onPressed: () {
            _playClickSound();
            ref.read(bluetoothProvider.notifier).disconnect();
            setState(() {
              _isJoining = false;
            });
          },
          child: Text(
            'BACK TO WAR COUNCIL',
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.4),
              fontSize: 10,
              fontWeight: FontWeight.bold,
              letterSpacing: 1.8,
            ),
          ),
        ),
      ],
    );
  }

  // ───────────────────────────────────────────────────────────────────────────
  //  View 3: Host Waiting View (Advertising)
  // ───────────────────────────────────────────────────────────────────────────
  Widget _buildHostWaitingView(BluetoothState bluetoothState, Color primary) {
    return Column(
      children: [
        const SizedBox(height: 12),
        _StonePanel(
          accentColor: primary,
          padding: const EdgeInsets.all(24),
          child: Column(
            children: [
              _SectionLabel('BROADCASTING WAR SIGNAL', color: primary),
              const SizedBox(height: 24),
              AnimatedBuilder(
                animation: _pulseAnim,
                builder: (context, child) {
                  return Container(
                    width: 74,
                    height: 74,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: primary.withValues(alpha: 0.06),
                      border: Border.all(
                        color: primary.withValues(alpha: 0.4 * _pulseAnim.value),
                        width: 1.8,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: primary.withValues(alpha: 0.25 * _pulseAnim.value),
                          blurRadius: 22,
                          spreadRadius: 2,
                        ),
                      ],
                    ),
                    child: Icon(
                      Icons.wifi_tethering_rounded,
                      color: primary.withValues(alpha: 0.8 * _pulseAnim.value),
                      size: 36,
                    ),
                  );
                },
              ),
              const SizedBox(height: 20),
              Text(
                'AWAITING CHALLENGER...',
                style: GoogleFonts.sairaStencilOne(
                  color: primary,
                  fontSize: 16,
                  letterSpacing: 1.8,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'War signal transmitted across local airwaves.\nInstruct your rival to tap "Join Realm" on their device.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.5),
                  fontSize: 11.5,
                  height: 1.4,
                  fontStyle: FontStyle.italic,
                ),
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: 24,
                height: 24,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  valueColor: AlwaysStoppedAnimation<Color>(primary.withValues(alpha: 0.7)),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 18),
        TextButton(
          onPressed: () {
            _playClickSound();
            ref.read(bluetoothProvider.notifier).disconnect();
            setState(() {
              _isHosting = false;
            });
          },
          child: Text(
            'CANCEL BROADCAST',
            style: TextStyle(
              color: Colors.redAccent.withValues(alpha: 0.6),
              fontSize: 10,
              fontWeight: FontWeight.bold,
              letterSpacing: 1.8,
            ),
          ),
        ),
      ],
    );
  }

  // ───────────────────────────────────────────────────────────────────────────
  //  View 4: In-Room Connected View
  // ───────────────────────────────────────────────────────────────────────────
  Widget _buildInRoomView(
    BluetoothState bluetoothState,
    Color primary,
    Color p1Color,
    Color p2Color,
  ) {
    return Column(
      children: [
        // Realm Header & Status Banner
        _buildConnectionHeaderCard(bluetoothState, primary),
        const SizedBox(height: 18),

        // Side by Side Player Cards
        _buildSideBySideCardsRow(bluetoothState, primary, p1Color, p2Color),
        const SizedBox(height: 18),

        // Half-width Row: Siege Conditions Tile + Select Map Tile
        _buildSettingsAndMapRow(bluetoothState, primary),
        const SizedBox(height: 22),

        // Battle Start / Waiting Action
        _buildStartBattleSection(bluetoothState, primary),
        const SizedBox(height: 14),

        // Cancel / Leave Realm
        Center(
          child: TextButton(
            onPressed: () async {
              if (await _onWillPop() && mounted) {
                setState(() {
                  _isHosting = false;
                  _isJoining = false;
                });
              }
            },
            child: Text(
              'ABANDON REALM COUNCIL',
              style: TextStyle(
                color: Colors.redAccent.withValues(alpha: 0.6),
                fontSize: 10,
                fontWeight: FontWeight.bold,
                letterSpacing: 2,
              ),
            ),
          ),
        ),
        const SizedBox(height: 12),
      ],
    );
  }

  // ───────────────────────────────────────────────────────────────────────────
  //  Connection Header Card
  // ───────────────────────────────────────────────────────────────────────────
  Widget _buildConnectionHeaderCard(BluetoothState state, Color primary) {
    final peerName = state.peerKingdomName ?? state.connectedDevice?.name ?? 'WARLORD';

    return _StonePanel(
      accentColor: primary,
      padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 18),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 9,
            height: 9,
            decoration: BoxDecoration(
              color: const Color(0xFF43A047),
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF43A047).withValues(alpha: 0.7),
                  blurRadius: 8,
                  spreadRadius: 1.5,
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          Flexible(
            child: Text(
              'WARLORD ENGAGED: ${peerName.toUpperCase()}',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: const Color(0xFF43A047),
                fontWeight: FontWeight.bold,
                fontSize: 11.5,
                letterSpacing: 1.5,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ───────────────────────────────────────────────────────────────────────────
  //  Side by Side Player Cards Row
  // ───────────────────────────────────────────────────────────────────────────
  Widget _buildSideBySideCardsRow(
    BluetoothState state,
    Color primary,
    Color p1Color,
    Color p2Color,
  ) {
    final settings = ref.watch(gameSettingsProvider);
    final isHost = state.isHost;

    final p1Name = isHost ? settings.player1Name : (state.peerKingdomName ?? 'HOST');
    final p2Name = isHost ? (state.peerKingdomName ?? 'GUEST') : settings.player1Name;

    return LayoutBuilder(
      builder: (context, constraints) {
        final isCompact = constraints.maxWidth < 600;

        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Left Card (Player 1 / Host)
            Expanded(
              child: _buildCommanderCard(
                playerNum: 1,
                tag: isHost ? 'HOST (YOU)' : 'HOST',
                commanderName: p1Name,
                playerColor: p1Color,
                currentSigil: state.player1Symbol,
                unavailableSigil: state.player2Symbol,
                unavailableColor: p2Color,
                isCompact: isCompact,
                isEditable: isHost,
                onSigilSelected: (s) {
                  _playClickSound();
                  ref.read(bluetoothProvider.notifier).updateSettings(p1Symbol: s);
                },
                onColorSelected: (c) {
                  _playClickSound();
                  ref.read(bluetoothProvider.notifier).updateSettings(p1Color: c.toARGB32());
                },
                primaryColor: primary,
              ),
            ),
            const SizedBox(width: 8),

            // Center VS Badge
            _buildCenterVersusPill(primary, isCompact),

            const SizedBox(width: 8),

            // Right Card (Player 2 / Challenger)
            Expanded(
              child: _buildCommanderCard(
                playerNum: 2,
                tag: isHost ? 'CHALLENGER' : 'GUEST (YOU)',
                commanderName: p2Name,
                playerColor: p2Color,
                currentSigil: state.player2Symbol,
                unavailableSigil: state.player1Symbol,
                unavailableColor: p1Color,
                isCompact: isCompact,
                isEditable: isHost,
                onSigilSelected: (s) {
                  _playClickSound();
                  ref.read(bluetoothProvider.notifier).updateSettings(p2Symbol: s);
                },
                onColorSelected: (c) {
                  _playClickSound();
                  ref.read(bluetoothProvider.notifier).updateSettings(p2Color: c.toARGB32());
                },
                primaryColor: primary,
              ),
            ),
          ],
        );
      },
    );
  }

  // ───────────────────────────────────────────────────────────────────────────
  //  Center VS Pill
  // ───────────────────────────────────────────────────────────────────────────
  Widget _buildCenterVersusPill(Color primary, bool isCompact) {
    return Padding(
      padding: EdgeInsets.only(top: isCompact ? 100 : 120),
      child: Container(
        padding: EdgeInsets.symmetric(
          horizontal: isCompact ? 6 : 10,
          vertical: isCompact ? 12 : 16,
        ),
        decoration: BoxDecoration(
          color: const Color(0xFF18130E),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: primary.withValues(alpha: 0.4),
            width: 1.2,
          ),
          boxShadow: [
            BoxShadow(
              color: primary.withValues(alpha: 0.25),
              blurRadius: 12,
              spreadRadius: 1,
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.sports_kabaddi,
              color: primary.withValues(alpha: 0.9),
              size: isCompact ? 16 : 20,
            ),
            const SizedBox(height: 4),
            Text(
              'VS',
              style: GoogleFonts.sairaStencilOne(
                color: primary,
                fontSize: isCompact ? 11 : 13,
                letterSpacing: 1.5,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ───────────────────────────────────────────────────────────────────────────
  //  Commander Card Component
  // ───────────────────────────────────────────────────────────────────────────
  Widget _buildCommanderCard({
    required int playerNum,
    required String tag,
    required String commanderName,
    required Color playerColor,
    required String currentSigil,
    required String unavailableSigil,
    required Color unavailableColor,
    required bool isCompact,
    required bool isEditable,
    required Function(String) onSigilSelected,
    required Function(Color) onColorSelected,
    required Color primaryColor,
  }) {
    final titleLore = _getSigilTitle(currentSigil);

    return AnimatedContainer(
      duration: const Duration(milliseconds: 250),
      curve: Curves.easeOutCubic,
      child: _StonePanel(
        accentColor: playerColor,
        padding: EdgeInsets.all(isCompact ? 10 : 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            // Top Badge
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                  decoration: BoxDecoration(
                    color: playerColor.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(5),
                    border: Border.all(
                      color: playerColor.withValues(alpha: 0.4),
                      width: 1,
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        playerNum == 1 ? Icons.shield : Icons.shield_outlined,
                        color: playerColor,
                        size: 11,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        isCompact ? 'P$playerNum' : tag,
                        style: TextStyle(
                          color: playerColor,
                          fontSize: 9,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 1.2,
                        ),
                      ),
                    ],
                  ),
                ),
                Flexible(
                  child: Text(
                    titleLore.toUpperCase(),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.45),
                      fontSize: 8.5,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 1.1,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),

            // Hero Sigil Crest
            _buildHeroCrest(
              sigil: currentSigil,
              playerColor: playerColor,
              isCompact: isCompact,
              onTap: isEditable
                  ? () => _showSigilPickerSheet(
                        currentSigil: currentSigil,
                        unavailableSigil: unavailableSigil,
                        onSigilSelected: onSigilSelected,
                        accentColor: playerColor,
                      )
                  : null,
            ),

            const SizedBox(height: 12),

            // Commander Name Banner
            Text(
              'COMMANDER',
              style: TextStyle(
                color: playerColor.withValues(alpha: 0.8),
                fontSize: 8.5,
                fontWeight: FontWeight.bold,
                letterSpacing: 1.5,
              ),
            ),
            const SizedBox(height: 4),
            Container(
              width: double.infinity,
              padding: EdgeInsets.symmetric(vertical: isCompact ? 6 : 8, horizontal: 6),
              decoration: BoxDecoration(
                color: playerColor.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: playerColor.withValues(alpha: 0.35), width: 1.2),
              ),
              child: Text(
                commanderName.toUpperCase(),
                textAlign: TextAlign.center,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: GoogleFonts.sairaStencilOne(
                  color: Colors.white,
                  fontSize: isCompact ? 13 : 15,
                  letterSpacing: 1.2,
                ),
              ),
            ),

            const SizedBox(height: 12),
            Container(height: 1, color: playerColor.withValues(alpha: 0.15)),
            const SizedBox(height: 10),

            // Sigil Row Header
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'SIGIL',
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.5),
                    fontSize: 8.5,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 1.5,
                  ),
                ),
                if (isEditable)
                  GestureDetector(
                    onTap: () => _showSigilPickerSheet(
                      currentSigil: currentSigil,
                      unavailableSigil: unavailableSigil,
                      onSigilSelected: onSigilSelected,
                      accentColor: playerColor,
                    ),
                    child: Text(
                      'ALL',
                      style: TextStyle(
                        color: playerColor,
                        fontSize: 8.5,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 1,
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 6),
            _buildSigilQuickBar(
              currentSigil: currentSigil,
              unavailableSigil: unavailableSigil,
              onSigilSelected: onSigilSelected,
              accentColor: playerColor,
              isCompact: isCompact,
              isEditable: isEditable,
            ),

            const SizedBox(height: 12),

            // Colour Row Header
            Align(
              alignment: Alignment.centerLeft,
              child: Text(
                'COLOUR',
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.5),
                  fontSize: 8.5,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1.5,
                ),
              ),
            ),
            const SizedBox(height: 6),
            _buildColorQuickBar(
              currentColor: playerColor,
              unavailableColor: unavailableColor,
              onColorSelected: onColorSelected,
              isCompact: isCompact,
              isEditable: isEditable,
            ),
          ],
        ),
      ),
    );
  }

  // ───────────────────────────────────────────────────────────────────────────
  //  Hero Crest Component
  // ───────────────────────────────────────────────────────────────────────────
  Widget _buildHeroCrest({
    required String sigil,
    required Color playerColor,
    required bool isCompact,
    VoidCallback? onTap,
  }) {
    final crestSize = isCompact ? 56.0 : 70.0;
    return GestureDetector(
      onTap: onTap != null
          ? () {
              _playClickSound();
              onTap();
            }
          : null,
      child: Stack(
        alignment: Alignment.center,
        children: [
          AnimatedBuilder(
            animation: _pulseAnim,
            builder: (context, child) {
              return Container(
                width: (crestSize + 8) * _pulseAnim.value,
                height: (crestSize + 8) * _pulseAnim.value,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: playerColor.withValues(alpha: 0.15 * _pulseAnim.value),
                    width: 1.2,
                  ),
                ),
              );
            },
          ),
          Container(
            width: crestSize + 4,
            height: crestSize + 4,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: playerColor.withValues(alpha: 0.35),
                  blurRadius: 16,
                  spreadRadius: 1,
                ),
              ],
            ),
          ),
          Container(
            width: crestSize,
            height: crestSize,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: RadialGradient(
                colors: [
                  playerColor.withValues(alpha: 0.28),
                  const Color(0xFF14100C),
                ],
              ),
              border: Border.all(
                color: playerColor.withValues(alpha: 0.8),
                width: 1.8,
              ),
            ),
            padding: EdgeInsets.all(isCompact ? 9 : 12),
            child: AppAssetImage(
              sigil,
              color: playerColor,
            ),
          ),
          if (onTap != null)
            Positioned(
              bottom: 0,
              right: 0,
              child: Container(
                width: isCompact ? 16 : 18,
                height: isCompact ? 16 : 18,
                decoration: BoxDecoration(
                  color: playerColor,
                  shape: BoxShape.circle,
                  border: Border.all(color: const Color(0xFF0D0B08), width: 1.2),
                ),
                child: const Icon(Icons.touch_app, size: 9, color: Colors.black),
              ),
            ),
        ],
      ),
    );
  }

  // ───────────────────────────────────────────────────────────────────────────
  //  Sigil Quick Bar
  // ───────────────────────────────────────────────────────────────────────────
  Widget _buildSigilQuickBar({
    required String currentSigil,
    required String unavailableSigil,
    required Function(String) onSigilSelected,
    required Color accentColor,
    required bool isCompact,
    required bool isEditable,
  }) {
    final barHeight = isCompact ? 38.0 : 44.0;
    final itemWidth = isCompact ? 36.0 : 42.0;

    return SizedBox(
      height: barHeight,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        itemCount: _availableSigils.length,
        physics: const BouncingScrollPhysics(),
        itemBuilder: (context, index) {
          final sigil = _availableSigils[index];
          final isSelected = sigil == currentSigil;
          final isUnavailable = sigil == unavailableSigil;

          return GestureDetector(
            onTap: (!isEditable || isUnavailable) ? null : () => onSigilSelected(sigil),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              curve: Curves.easeOutCubic,
              width: itemWidth,
              margin: const EdgeInsets.only(right: 6),
              decoration: BoxDecoration(
                gradient: isSelected
                    ? LinearGradient(
                        colors: [
                          accentColor.withValues(alpha: 0.35),
                          accentColor.withValues(alpha: 0.12),
                        ],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      )
                    : null,
                color: isSelected ? null : Colors.white.withValues(alpha: 0.04),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: isSelected
                      ? accentColor
                      : isUnavailable
                          ? Colors.white.withValues(alpha: 0.05)
                          : Colors.white.withValues(alpha: 0.12),
                  width: isSelected ? 1.6 : 1,
                ),
                boxShadow: isSelected
                    ? [
                        BoxShadow(
                          color: accentColor.withValues(alpha: 0.35),
                          blurRadius: 8,
                          spreadRadius: 1,
                        ),
                      ]
                    : [],
              ),
              padding: EdgeInsets.all(isCompact ? 6 : 7),
              child: AnimatedOpacity(
                duration: const Duration(milliseconds: 180),
                opacity: isUnavailable ? 0.18 : 1.0,
                child: AppAssetImage(
                  sigil,
                  color: isSelected ? accentColor : Colors.white.withValues(alpha: 0.6),
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  // ───────────────────────────────────────────────────────────────────────────
  //  Color Quick Bar
  // ───────────────────────────────────────────────────────────────────────────
  Widget _buildColorQuickBar({
    required Color currentColor,
    required Color unavailableColor,
    required Function(Color) onColorSelected,
    required bool isCompact,
    required bool isEditable,
  }) {
    final sz = isCompact ? 22.0 : 26.0;
    return SizedBox(
      height: sz + 4,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        itemCount: _availableColors.length,
        physics: const BouncingScrollPhysics(),
        itemBuilder: (context, index) {
          final color = _availableColors[index];
          final isSelected = color.toARGB32() == currentColor.toARGB32();
          final isUnavailable = color.toARGB32() == unavailableColor.toARGB32();

          return GestureDetector(
            onTap: (!isEditable || isUnavailable) ? null : () => onColorSelected(color),
            child: AnimatedOpacity(
              duration: const Duration(milliseconds: 180),
              opacity: isUnavailable ? 0.18 : 1.0,
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                curve: Curves.easeOutCubic,
                width: isSelected ? sz + 4 : sz,
                height: isSelected ? sz + 4 : sz,
                margin: const EdgeInsets.only(right: 8),
                decoration: BoxDecoration(
                  color: color,
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: isSelected ? Colors.white : Colors.white.withValues(alpha: 0.2),
                    width: isSelected ? 2.2 : 1,
                  ),
                  boxShadow: isSelected
                      ? [
                          BoxShadow(
                            color: color.withValues(alpha: 0.7),
                            blurRadius: 10,
                            spreadRadius: 1.5,
                          ),
                        ]
                      : [],
                ),
                child: isSelected
                    ? const Icon(Icons.check, size: 12, color: Colors.white)
                    : null,
              ),
            ),
          );
        },
      ),
    );
  }

  // ───────────────────────────────────────────────────────────────────────────
  //  Settings & Map Row (Siege Conditions & Select Map Side by Side)
  // ───────────────────────────────────────────────────────────────────────────
  Widget _buildSettingsAndMapRow(BluetoothState bluetoothState, Color primary) {
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Left Tile (50%): Siege Conditions
          Expanded(
            child: _buildSiegeSettingsCard(bluetoothState, primary),
          ),
          const SizedBox(width: 12),

          // Right Tile (50%): Select Map Tile
          Expanded(
            child: _buildMapSelectionTile(bluetoothState, primary),
          ),
        ],
      ),
    );
  }

  // ───────────────────────────────────────────────────────────────────────────
  //  Siege Conditions Card
  // ───────────────────────────────────────────────────────────────────────────
  Widget _buildSiegeSettingsCard(BluetoothState bluetoothState, Color primary) {
    final isHost = bluetoothState.isHost;

    return _StonePanel(
      accentColor: primary,
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _SectionLabel(
                'SIEGE CONDITIONS',
                color: primary,
                trailing: Icon(Icons.castle_outlined, color: primary.withValues(alpha: 0.7), size: 14),
              ),
              const SizedBox(height: 6),
              Text(
                'Glory points required to launch siege assault.',
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.5),
                  fontSize: 10,
                  fontStyle: FontStyle.italic,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // Steppers & Numeric Input
          Row(
            children: [
              Text(
                'THRESHOLD:',
                style: TextStyle(
                  color: primary.withValues(alpha: 0.85),
                  fontSize: 9,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1.2,
                ),
              ),
              const Spacer(),
              if (isHost) ...[
                _buildStepperButton(
                  icon: Icons.remove,
                  onTap: () => _setThreshold(bluetoothState.kingdomAttackThreshold - 5),
                  primary: primary,
                ),
                const SizedBox(width: 6),
                SizedBox(
                  width: 62,
                  child: TextField(
                    controller: _thresholdController,
                    keyboardType: TextInputType.number,
                    textAlign: TextAlign.center,
                    style: GoogleFonts.sairaStencilOne(
                      color: Colors.white,
                      fontSize: 14,
                    ),
                    decoration: InputDecoration(
                      isDense: true,
                      contentPadding: const EdgeInsets.symmetric(vertical: 6),
                      filled: true,
                      fillColor: primary.withValues(alpha: 0.08),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: BorderSide(color: primary.withValues(alpha: 0.35)),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: BorderSide(color: primary, width: 1.5),
                      ),
                    ),
                    onChanged: (val) {
                      final n = int.tryParse(val.trim());
                      if (n != null) {
                        ref.read(bluetoothProvider.notifier).updateSettings(threshold: n.clamp(1, 999));
                      }
                    },
                  ),
                ),
                const SizedBox(width: 6),
                _buildStepperButton(
                  icon: Icons.add,
                  onTap: () => _setThreshold(bluetoothState.kingdomAttackThreshold + 5),
                  primary: primary,
                ),
              ] else
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: primary.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: primary.withValues(alpha: 0.35)),
                  ),
                  child: Text(
                    '${bluetoothState.kingdomAttackThreshold} PTS',
                    style: GoogleFonts.sairaStencilOne(
                      color: primary,
                      fontSize: 13,
                      letterSpacing: 1.2,
                    ),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStepperButton({
    required IconData icon,
    required VoidCallback onTap,
    required Color primary,
  }) {
    return _AnimatedPressButton(
      onTap: onTap,
      accentColor: primary,
      child: Container(
        width: 28,
        height: 28,
        decoration: BoxDecoration(
          color: primary.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(7),
          border: Border.all(color: primary.withValues(alpha: 0.35), width: 1),
        ),
        child: Icon(icon, color: primary, size: 14),
      ),
    );
  }

  // ───────────────────────────────────────────────────────────────────────────
  //  Map Selection Tile
  // ───────────────────────────────────────────────────────────────────────────
  Widget _buildMapSelectionTile(BluetoothState bluetoothState, Color primary) {
    final isHost = bluetoothState.isHost;
    final hasMapSelected = bluetoothState.selectedMapPath != null;
    final mapImage = _getMapImage(bluetoothState.selectedMapPath);

    return _StonePanel(
      accentColor: hasMapSelected ? primary : Colors.white24,
      padding: EdgeInsets.zero,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: isHost
            ? _AnimatedPressButton(
                onTap: () async {
                  _playClickSound();
                  final result = await Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (context) => const MapSelectionScreen(isBluetoothMode: true),
                    ),
                  );
                  if (result != null && result is Map<String, String>) {
                    ref.read(bluetoothProvider.notifier).sendMapSelection(result['path']!, result['name']!);
                  }
                },
                accentColor: primary,
                child: _buildMapTileContent(
                  hasMapSelected: hasMapSelected,
                  mapImage: mapImage,
                  mapName: bluetoothState.selectedMapName,
                  isHost: true,
                  primary: primary,
                ),
              )
            : _buildMapTileContent(
                hasMapSelected: hasMapSelected,
                mapImage: mapImage,
                mapName: bluetoothState.selectedMapName,
                isHost: false,
                primary: primary,
              ),
      ),
    );
  }

  Widget _buildMapTileContent({
    required bool hasMapSelected,
    required String mapImage,
    required String? mapName,
    required bool isHost,
    required Color primary,
  }) {
    if (!hasMapSelected) {
      return Container(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            _SectionLabel(
              'THEATRE OF WAR',
              color: primary,
              trailing: Icon(Icons.map_outlined, color: primary.withValues(alpha: 0.7), size: 14),
            ),
            const SizedBox(height: 8),
            Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    isHost ? Icons.add_photo_alternate_outlined : Icons.hourglass_empty,
                    color: primary.withValues(alpha: 0.6),
                    size: 24,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    isHost ? 'SELECT THEATRE MAP' : 'AWAITING MAP SELECTION...',
                    style: GoogleFonts.sairaStencilOne(
                      color: primary,
                      fontSize: 12,
                      letterSpacing: 1.2,
                    ),
                  ),
                  Text(
                    isHost ? 'Tap to choose battleground' : 'Host will select battleground',
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.4),
                      fontSize: 9.5,
                      fontStyle: FontStyle.italic,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 4),
          ],
        ),
      );
    }

    // When Map is selected: Show preview image with gradient and title
    return Stack(
      children: [
        // Map Image Background
        Positioned.fill(
          child: AppAssetImage(
            mapImage,
            fit: BoxFit.cover,
          ),
        ),
        // Dark Vignette Overlay
        Positioned.fill(
          child: Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Colors.black.withValues(alpha: 0.35),
                  const Color(0xFF0F0D0A).withValues(alpha: 0.92),
                ],
              ),
            ),
          ),
        ),
        // Hatch overlay
        Positioned.fill(
          child: CustomPaint(
            painter: _HatchPainter(color: Colors.white.withValues(alpha: 0.03)),
          ),
        ),
        // Text and badges
        Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.6),
                      borderRadius: BorderRadius.circular(5),
                      border: Border.all(color: primary.withValues(alpha: 0.5), width: 1),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.map, color: primary, size: 10),
                        const SizedBox(width: 4),
                        Text(
                          'BATTLEGROUND',
                          style: TextStyle(
                            color: primary,
                            fontSize: 8.5,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 1.2,
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (isHost)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                      decoration: BoxDecoration(
                        color: primary.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(5),
                        border: Border.all(color: primary.withValues(alpha: 0.5), width: 1),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.edit, color: primary, size: 9),
                          const SizedBox(width: 3),
                          Text(
                            'CHANGE',
                            style: TextStyle(
                              color: primary,
                              fontSize: 8,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 1,
                            ),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 12),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    (mapName ?? 'SELECTED MAP').toUpperCase(),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.sairaStencilOne(
                      color: Colors.white,
                      fontSize: 13,
                      letterSpacing: 1.2,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    isHost ? 'Tap to change battlefield' : 'Battlefield designated by Host',
                    style: TextStyle(
                      color: primary.withValues(alpha: 0.7),
                      fontSize: 9,
                      fontStyle: FontStyle.italic,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }

  // ───────────────────────────────────────────────────────────────────────────
  //  Battle Start / Waiting Action Section
  // ───────────────────────────────────────────────────────────────────────────
  Widget _buildStartBattleSection(BluetoothState bluetoothState, Color primary) {
    final isHost = bluetoothState.isHost;
    final isPeerConnected = bluetoothState.status == BluetoothStatus.connected;
    final hasMapSelected = bluetoothState.selectedMapPath != null;

    if (isHost) {
      return _buildPrimaryActionButton(
        onTap: (isPeerConnected && hasMapSelected) ? _startGame : null,
        label: 'MARCH TO BATTLE',
        icon: Icons.sports_kabaddi,
        accentColor: primary,
        isEnabled: isPeerConnected && hasMapSelected,
      );
    }

    return _StonePanel(
      accentColor: primary,
      padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 20),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          SizedBox(
            width: 18,
            height: 18,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              valueColor: AlwaysStoppedAnimation<Color>(primary.withValues(alpha: 0.8)),
            ),
          ),
          const SizedBox(width: 14),
          Text(
            hasMapSelected
                ? 'WAITING FOR HOST TO SOUND BATTLE MARCH...'
                : 'WAITING FOR HOST TO SELECT MAP...',
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.6),
              fontSize: 11,
              letterSpacing: 1.2,
              fontStyle: FontStyle.italic,
            ),
          ),
        ],
      ),
    );
  }

  // ───────────────────────────────────────────────────────────────────────────
  //  Primary Action Button
  // ───────────────────────────────────────────────────────────────────────────
  Widget _buildPrimaryActionButton({
    required VoidCallback? onTap,
    required String label,
    required IconData icon,
    required Color accentColor,
    bool isEnabled = true,
  }) {
    return Center(
      child: Opacity(
        opacity: isEnabled ? 1.0 : 0.45,
        child: _AnimatedPressButton(
          onTap: isEnabled ? (onTap ?? () {}) : () {},
          accentColor: accentColor,
          isEnabled: isEnabled,
          child: Container(
            width: 300,
            height: 56,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  accentColor.withValues(alpha: 0.95),
                  accentColor.withValues(alpha: 0.7),
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: accentColor.withValues(alpha: 0.8),
                width: 1.4,
              ),
              boxShadow: isEnabled
                  ? [
                      BoxShadow(
                        color: accentColor.withValues(alpha: 0.4),
                        blurRadius: 24,
                        spreadRadius: 1,
                        offset: const Offset(0, 5),
                      ),
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.5),
                        blurRadius: 12,
                        offset: const Offset(0, 4),
                      ),
                    ]
                  : [],
            ),
            child: Stack(
              alignment: Alignment.center,
              children: [
                Positioned.fill(
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(14),
                    child: CustomPaint(
                      painter: _HatchPainter(
                        color: Colors.white.withValues(alpha: 0.08),
                      ),
                    ),
                  ),
                ),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(icon, color: Colors.black87, size: 20),
                    const SizedBox(width: 10),
                    Text(
                      label,
                      style: GoogleFonts.sairaStencilOne(
                        color: Colors.black,
                        fontSize: 15,
                        letterSpacing: 2.5,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ───────────────────────────────────────────────────────────────────────────
  //  Modal Sigil Picker Sheet
  // ───────────────────────────────────────────────────────────────────────────
  void _showSigilPickerSheet({
    required String currentSigil,
    required String unavailableSigil,
    required Function(String) onSigilSelected,
    required Color accentColor,
  }) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (ctx) {
        return Container(
          padding: const EdgeInsets.fromLTRB(20, 18, 20, 28),
          decoration: BoxDecoration(
            color: const Color(0xFF14100C),
            borderRadius: const BorderRadius.vertical(top: Radius.circular(22)),
            border: Border.all(color: accentColor.withValues(alpha: 0.4), width: 1.4),
            boxShadow: [
              BoxShadow(
                color: accentColor.withValues(alpha: 0.15),
                blurRadius: 28,
                spreadRadius: 2,
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 16),
              Text(
                'SELECT HOUSE SIGIL',
                style: GoogleFonts.sairaStencilOne(
                  color: accentColor,
                  fontSize: 16,
                  letterSpacing: 2,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'Each sigil represents an ancient warlord lineage',
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.4),
                  fontSize: 10.5,
                  fontStyle: FontStyle.italic,
                ),
              ),
              const SizedBox(height: 18),
              GridView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 4,
                  mainAxisSpacing: 12,
                  crossAxisSpacing: 12,
                ),
                itemCount: _availableSigils.length,
                itemBuilder: (context, index) {
                  final sigil = _availableSigils[index];
                  final isSelected = sigil == currentSigil;
                  final isUnavailable = sigil == unavailableSigil;

                  return GestureDetector(
                    onTap: isUnavailable
                        ? null
                        : () {
                            onSigilSelected(sigil);
                            Navigator.pop(ctx);
                          },
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        gradient: isSelected
                            ? LinearGradient(
                                colors: [
                                  accentColor.withValues(alpha: 0.35),
                                  accentColor.withValues(alpha: 0.12),
                                ],
                              )
                            : null,
                        color: isSelected ? null : Colors.white.withValues(alpha: 0.04),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: isSelected
                              ? accentColor
                              : isUnavailable
                                  ? Colors.transparent
                                  : Colors.white.withValues(alpha: 0.12),
                          width: isSelected ? 1.8 : 1,
                        ),
                        boxShadow: isSelected
                            ? [
                                BoxShadow(
                                  color: accentColor.withValues(alpha: 0.35),
                                  blurRadius: 10,
                                  spreadRadius: 1,
                                ),
                              ]
                            : [],
                      ),
                      child: AnimatedOpacity(
                        duration: const Duration(milliseconds: 180),
                        opacity: isUnavailable ? 0.18 : 1.0,
                        child: AppAssetImage(
                          sigil,
                          color: isSelected ? accentColor : Colors.white.withValues(alpha: 0.65),
                        ),
                      ),
                    ),
                  );
                },
              ),
            ],
          ),
        );
      },
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
//  Press-scale button wrapper (tactile feedback)
// ─────────────────────────────────────────────────────────────────────────────
class _AnimatedPressButton extends StatefulWidget {
  final Widget child;
  final VoidCallback onTap;
  final Color accentColor;
  final bool isEnabled;

  const _AnimatedPressButton({
    required this.child,
    required this.onTap,
    required this.accentColor,
    this.isEnabled = true,
  });

  @override
  State<_AnimatedPressButton> createState() => _AnimatedPressButtonState();
}

class _AnimatedPressButtonState extends State<_AnimatedPressButton>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _scaleAnim;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 100),
      reverseDuration: const Duration(milliseconds: 160),
      lowerBound: 0,
      upperBound: 1,
    );
    _scaleAnim = Tween<double>(begin: 1.0, end: 0.95).animate(
      CurvedAnimation(parent: _ctrl, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.isEnabled) {
      return widget.child;
    }
    return GestureDetector(
      onTapDown: (_) => _ctrl.forward(),
      onTapUp: (_) {
        _ctrl.reverse();
        widget.onTap();
      },
      onTapCancel: () => _ctrl.reverse(),
      child: ScaleTransition(scale: _scaleAnim, child: widget.child),
    );
  }
}
