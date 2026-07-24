import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../core/constants/app_assets.dart';
import '../../providers/bluetooth_provider.dart';
import '../../providers/turn_provider.dart';
import '../../providers/game_settings_provider.dart';
import '../../providers/simulation_provider.dart';
import '../../core/enums/game_mode.dart';
import '../../core/enums/connection_type.dart';
import 'game_screen.dart';
import 'map_selection_screen.dart';

// ─────────────────────────────────────────────────────────────────────────────
//  Painters & Panel (matching setup aesthetic)
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

class _RoyalDivider extends StatelessWidget {
  final Color color;
  const _RoyalDivider({required this.color});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(child: Container(height: 1, color: color.withValues(alpha: 0.2))),
        Container(
          width: 6,
          height: 6,
          margin: const EdgeInsets.symmetric(horizontal: 10),
          transform: Matrix4.rotationZ(math.pi / 4),
          decoration: BoxDecoration(color: color.withValues(alpha: 0.5)),
        ),
        Expanded(child: Container(height: 1, color: color.withValues(alpha: 0.2))),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
//  Main Screen
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
  late TextEditingController _thresholdController;

  final List<String> _availableSigils = [
    'assets/symbols/fire.png',
    'assets/symbols/tiger.png',
    'assets/symbols/flash.png',
    'assets/icons/hacker.png',
    'assets/icons/lion.png',
    'assets/icons/wolf.png',
    'assets/icons/bull.png',
    'assets/icons/shuriken.png',
  ];

  final List<Color> _availableColors = [
    Colors.blue,
    Colors.red,
    Colors.green,
    Colors.orange,
    Colors.purple,
    Colors.yellow,
    Colors.cyan,
    Colors.pink,
  ];

  // Animation controllers
  late AnimationController _fadeController;
  late AnimationController _slideController;
  late Animation<double> _fadeAnim;
  late Animation<Offset> _slideAnim;

  @override
  void initState() {
    super.initState();
    final bluetoothState = ref.read(bluetoothProvider);
    _isHosting = bluetoothState.isHost && bluetoothState.status != BluetoothStatus.idle;
    _isJoining = !bluetoothState.isHost && bluetoothState.status != BluetoothStatus.idle;
    _thresholdController = TextEditingController(text: '${bluetoothState.kingdomAttackThreshold}');

    _fadeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 700),
    );
    _slideController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );

    _fadeAnim = CurvedAnimation(parent: _fadeController, curve: Curves.easeIn);
    _slideAnim = Tween<Offset>(
      begin: const Offset(0, 0.08),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _slideController, curve: Curves.easeOutCubic));

    // Stagger intro animations
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
    super.dispose();
  }

  void _handleHost() {
    setState(() {
      _isHosting = true;
      _isJoining = false;
    });
    ref.read(bluetoothProvider.notifier).startHosting();
  }

  void _handleJoin() {
    setState(() {
      _isJoining = true;
      _isHosting = false;
    });
    ref.read(bluetoothProvider.notifier).startScanning();
  }

  void _startGame() {
    if (!mounted) return;

    ref.read(connectionTypeProvider.notifier).setConnectionType(ConnectionType.bluetooth);
    ref.read(gameSettingsProvider.notifier).setMode(GameMode.multiplayer);
    ref.read(simulationProvider.notifier).reset();

    if (ref.read(bluetoothProvider).isHost) {
      ref.read(bluetoothProvider.notifier).sendStartGame();
    }

    Navigator.of(context).pushReplacement(
      MaterialPageRoute(
        settings: const RouteSettings(name: '/game'),
        builder: (context) => const GameScreen(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final bluetoothState = ref.watch(bluetoothProvider);
    final settings = ref.watch(gameSettingsProvider);
    final theme = Theme.of(context);
    final primary = theme.colorScheme.primary;

    // Listen for peer starting game or connection drops
    ref.listen(bluetoothProvider, (previous, next) {
      if (!mounted) return;

      if (next.status == BluetoothStatus.idle && previous?.status == BluetoothStatus.connected) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Peer disconnected'),
            backgroundColor: Colors.redAccent,
          ),
        );
        setState(() {
          _isHosting = false;
          _isJoining = false;
        });
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

    return Scaffold(
      backgroundColor: const Color(0xFF0A0804),
      body: Stack(
        children: [
          // Ambient background gradient
          Positioned.fill(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: RadialGradient(
                  center: const Alignment(0, -0.6),
                  radius: 1.1,
                  colors: [
                    primary.withValues(alpha: 0.08),
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
                child: CustomScrollView(
                  slivers: [
                    _buildAppBar(primary),
                    SliverPadding(
                      padding: const EdgeInsets.fromLTRB(20, 8, 20, 100),
                      sliver: SliverList(
                        delegate: SliverChildListDelegate([
                          _StonePanel(
                            accentColor: primary,
                            padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.castle, color: primary.withValues(alpha: 0.6), size: 14),
                                const SizedBox(width: 8),
                                Text(
                                  'YOUR KINGDOM: ${settings.player1Name.toUpperCase()}',
                                  style: TextStyle(
                                    color: primary,
                                    fontSize: 10,
                                    fontWeight: FontWeight.bold,
                                    letterSpacing: 2,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 16),

                          if (!_isHosting && !_isJoining) ...[
                            const SizedBox(height: 60),
                            _buildModeButton(
                              title: 'HOST ROOM',
                              subtitle: 'Create a room for others to join',
                              icon: Icons.wifi_tethering_rounded,
                              onTap: _handleHost,
                              primaryColor: primary,
                            ),
                            const SizedBox(height: 24),
                            _buildModeButton(
                              title: 'JOIN ROOM',
                              subtitle: 'Search for nearby rooms',
                              icon: Icons.search_rounded,
                              onTap: _handleJoin,
                              primaryColor: primary,
                            ),
                          ] else ...[
                            _buildStatusHeader(bluetoothState, primary),
                            const SizedBox(height: 24),

                            if (_isJoining && bluetoothState.status != BluetoothStatus.connected) 
                               _buildDeviceList(bluetoothState, primary),
                            if (_isHosting && bluetoothState.status != BluetoothStatus.connected) 
                               _buildHostWaiting(bluetoothState, primary),
                            
                            if (bluetoothState.status == BluetoothStatus.connected) ...[
                              _buildBattleSettings(bluetoothState, primary),
                            ],

                            const SizedBox(height: 32),
                            if (bluetoothState.status == BluetoothStatus.connected && bluetoothState.isHost) ...[
                              if (bluetoothState.selectedMapName != null)
                                Padding(
                                  padding: const EdgeInsets.only(bottom: 20.0),
                                  child: _StonePanel(
                                    accentColor: primary,
                                    padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
                                    child: Row(
                                      mainAxisAlignment: MainAxisAlignment.center,
                                      children: [
                                        Icon(Icons.map_outlined, color: primary.withValues(alpha: 0.6), size: 16),
                                        const SizedBox(width: 10),
                                        Text(
                                          'SELECTED MAP: ${bluetoothState.selectedMapName!.toUpperCase()}',
                                          style: TextStyle(
                                            color: primary,
                                            fontSize: 11,
                                            fontWeight: FontWeight.bold,
                                            letterSpacing: 1.5,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              _buildThemedButton(
                                onTap: () async {
                                  final result = await Navigator.of(context).push(
                                    MaterialPageRoute(
                                      builder: (context) => const MapSelectionScreen(isBluetoothMode: true),
                                    ),
                                  );
                                  if (result != null && result is Map<String, String>) {
                                    ref.read(bluetoothProvider.notifier).sendMapSelection(result['path']!, result['name']!);
                                  }
                                },
                                label: 'SELECT MAP',
                                icon: Icons.map,
                                accentColor: Colors.white38,
                              ),
                              const SizedBox(height: 20),
                              _buildThemedButton(
                                onTap: bluetoothState.selectedMapPath != null ? _startGame : null,
                                label: 'START BATTLE',
                                icon: Icons.sports_kabaddi,
                                accentColor: primary,
                                isPrimary: true,
                              ),
                            ],
                            if (bluetoothState.status == BluetoothStatus.connected && !bluetoothState.isHost)
                              Padding(
                                padding: const EdgeInsets.symmetric(vertical: 16.0),
                                child: _StonePanel(
                                  accentColor: primary,
                                  child: Column(
                                    children: [
                                      if (bluetoothState.selectedMapName != null) ...[
                                        Text(
                                          'MAP: ${bluetoothState.selectedMapName!.toUpperCase()}',
                                          style: TextStyle(
                                            color: primary,
                                            fontSize: 12,
                                            fontWeight: FontWeight.bold,
                                            letterSpacing: 2,
                                          ),
                                        ),
                                        const SizedBox(height: 12),
                                        _RoyalDivider(color: primary),
                                        const SizedBox(height: 12),
                                      ],
                                      Row(
                                        mainAxisAlignment: MainAxisAlignment.center,
                                        children: [
                                          SizedBox(
                                            width: 16,
                                            height: 16,
                                            child: CircularProgressIndicator(
                                              strokeWidth: 2,
                                              valueColor: AlwaysStoppedAnimation<Color>(primary.withValues(alpha: 0.6)),
                                            ),
                                          ),
                                          const SizedBox(width: 12),
                                          Text(
                                            'WAITING FOR HOST TO START...',
                                            style: TextStyle(
                                              color: Colors.white.withValues(alpha: 0.45),
                                              fontSize: 11,
                                              letterSpacing: 1.2,
                                              fontStyle: FontStyle.italic,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            const SizedBox(height: 24),
                            Center(
                              child: TextButton(
                                onPressed: () {
                                  ref.read(bluetoothProvider.notifier).disconnect();
                                  if (mounted) {
                                    setState(() {
                                      _isHosting = false;
                                      _isJoining = false;
                                    });
                                  }
                                },
                                child: Text(
                                  'CANCEL / LEAVE COUNCIL',
                                  style: TextStyle(
                                    color: Colors.white.withValues(alpha: 0.25),
                                    fontSize: 10,
                                    fontWeight: FontWeight.bold,
                                    letterSpacing: 2,
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(height: 16),
                          ],
                        ]),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAppBar(Color primary) {
    return SliverToBoxAdapter(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
        child: Row(
          children: [
            GestureDetector(
              onTap: () {
                ref.read(bluetoothProvider.notifier).disconnect();
                if (mounted) Navigator.of(context).pop();
              },
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
                    'WAR COUNCIL',
                    style: TextStyle(
                      color: primary,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 3.5,
                    ),
                  ),
                  Text(
                    'Bluetooth Multiplayer · Local Combat',
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.38),
                      fontSize: 11,
                      letterSpacing: 1.2,
                      fontStyle: FontStyle.italic,
                    ),
                  ),
                ],
              ),
            ),
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: primary.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: primary.withValues(alpha: 0.25),
                  width: 1,
                ),
              ),
              child: Icon(Icons.bluetooth, color: primary.withValues(alpha: 0.7), size: 20),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildThemedButton({
    required VoidCallback? onTap,
    required String label,
    required IconData icon,
    required Color accentColor,
    bool isPrimary = false,
  }) {
    return Center(
      child: _AnimatedPressButton(
        onTap: onTap ?? () {},
        accentColor: accentColor,
        child: Opacity(
          opacity: onTap == null ? 0.5 : 1.0,
          child: Container(
            width: 280,
            height: 56,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: isPrimary 
                  ? [accentColor.withValues(alpha: 0.85), accentColor.withValues(alpha: 0.6)]
                  : [const Color(0xFF1A1510), const Color(0xFF0F0D0A)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: isPrimary ? accentColor.withValues(alpha: 0.6) : Colors.white.withValues(alpha: 0.1),
                width: 1.2,
              ),
              boxShadow: [
                if (isPrimary) BoxShadow(
                  color: accentColor.withValues(alpha: 0.35),
                  blurRadius: 24,
                  spreadRadius: 1,
                  offset: const Offset(0, 6),
                ),
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.5),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Stack(
              alignment: Alignment.center,
              children: [
                Positioned.fill(
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: CustomPaint(
                      painter: _HatchPainter(
                        color: Colors.white.withValues(alpha: isPrimary ? 0.06 : 0.02),
                      ),
                    ),
                  ),
                ),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(icon, color: Colors.white.withValues(alpha: 0.9), size: 18),
                    const SizedBox(width: 12),
                    Text(
                      label,
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.95),
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 2.5,
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

  Widget _buildStatusHeader(BluetoothState state, Color primary) {
    String statusText = '';
    Color statusColor = Colors.white54;
    
    switch (state.status) {
      case BluetoothStatus.idle:
        statusText = 'IDLE';
        break;
      case BluetoothStatus.scanning:
        statusText = state.isHost ? 'ADVERTISING...' : 'SCANNING...';
        statusColor = primary;
        break;
      case BluetoothStatus.connecting:
        statusText = 'CONNECTING...';
        statusColor = Colors.orange;
        break;
      case BluetoothStatus.connected:
        final peerName = state.peerKingdomName ?? state.connectedDevice?.name ?? 'PEER';
        statusText = 'CONNECTED TO ${peerName.toUpperCase()}';
        statusColor = Colors.green;
        break;
      case BluetoothStatus.failed:
        statusText = 'CONNECTION FAILED';
        statusColor = Colors.red;
        break;
    }

    return Center(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
        decoration: BoxDecoration(
          color: statusColor.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: statusColor.withValues(alpha: 0.3), width: 1.2),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 8,
              height: 8,
              decoration: BoxDecoration(
                color: statusColor,
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(color: statusColor.withValues(alpha: 0.4), blurRadius: 6, spreadRadius: 1),
                ],
              ),
            ),
            const SizedBox(width: 12),
            Text(
              statusText,
              style: TextStyle(
                color: statusColor,
                fontWeight: FontWeight.bold,
                fontSize: 11,
                letterSpacing: 1.5,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBattleSettings(BluetoothState state, Color primary) {
    final isHost = state.isHost;
    
    return _StonePanel(
      accentColor: primary,
      padding: const EdgeInsets.fromLTRB(20, 22, 20, 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _SectionLabel('BATTLE SETTINGS', color: primary),
          const SizedBox(height: 24),
          
          _buildSigilSelector(
            label: isHost ? 'YOUR SIGIL' : '${state.peerKingdomName ?? 'HOST'}\'S SIGIL',
            currentSigil: state.player1Symbol,
            unavailableSigil: state.player2Symbol,
            isEditable: isHost,
            onSigilSelected: (sigil) => ref.read(bluetoothProvider.notifier).updateSettings(p1Symbol: sigil),
            accentColor: isHost ? primary : Colors.white38,
          ),
          const SizedBox(height: 18),
          _buildColorSelector(
            currentColor: Color(state.player1Color),
            unavailableColor: Color(state.player2Color),
            isEditable: isHost,
            onColorSelected: (color) => ref.read(bluetoothProvider.notifier).updateSettings(p1Color: color.toARGB32()),
          ),
          const SizedBox(height: 24),
          _RoyalDivider(color: primary),
          const SizedBox(height: 24),
          
          _buildSigilSelector(
            label: isHost ? '${state.peerKingdomName ?? 'PEER'}\'S SIGIL' : 'YOUR SIGIL',
            currentSigil: state.player2Symbol,
            unavailableSigil: state.player1Symbol,
            isEditable: isHost,
            onSigilSelected: (sigil) => ref.read(bluetoothProvider.notifier).updateSettings(p2Symbol: sigil),
            accentColor: isHost ? primary : Colors.white38,
          ),
          const SizedBox(height: 18),
          _buildColorSelector(
            currentColor: Color(state.player2Color),
            unavailableColor: Color(state.player1Color),
            isEditable: isHost,
            onColorSelected: (color) => ref.read(bluetoothProvider.notifier).updateSettings(p2Color: color.toARGB32()),
          ),
          
          const SizedBox(height: 32),
          _RoyalDivider(color: primary),
          const SizedBox(height: 24),
          
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'ATTACK THRESHOLD',
                      style: TextStyle(
                        color: primary.withValues(alpha: 0.9),
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 1.5,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Points to unlock kingdom assault',
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.3),
                        fontSize: 10,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ],
                ),
              ),
              if (isHost)
                SizedBox(
                  width: 90,
                  child: _buildThemedTextField(
                    _thresholdController,
                    'POINTS',
                    primary,
                    onChanged: (value) {
                      final val = int.tryParse(value) ?? 100;
                      ref.read(bluetoothProvider.notifier).updateSettings(threshold: val);
                    },
                  ),
                )
              else
                _StonePanel(
                  accentColor: primary,
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  child: Text(
                    '${state.kingdomAttackThreshold}',
                    style: TextStyle(
                      color: primary,
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 1.5,
                    ),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildThemedTextField(
    TextEditingController controller,
    String label,
    Color accentColor, {
    Function(String)? onChanged,
  }) {
    return TextField(
      controller: controller,
      textAlign: TextAlign.center,
      keyboardType: TextInputType.number,
      style: const TextStyle(
        color: Colors.white,
        fontSize: 14,
        fontWeight: FontWeight.bold,
      ),
      onChanged: onChanged,
      decoration: InputDecoration(
        labelText: label,
        labelStyle: TextStyle(
          color: accentColor.withValues(alpha: 0.5),
          fontSize: 9,
          fontWeight: FontWeight.bold,
          letterSpacing: 1.5,
        ),
        enabledBorder: OutlineInputBorder(
          borderSide: BorderSide(color: accentColor.withValues(alpha: 0.3), width: 1.2),
          borderRadius: BorderRadius.circular(8),
        ),
        focusedBorder: OutlineInputBorder(
          borderSide: BorderSide(color: accentColor, width: 1.5),
          borderRadius: BorderRadius.circular(8),
        ),
        filled: true,
        fillColor: accentColor.withValues(alpha: 0.04),
        contentPadding: const EdgeInsets.symmetric(vertical: 12),
      ),
    );
  }

  Widget _buildSigilSelector({
    required String label,
    required String currentSigil,
    required String unavailableSigil,
    required bool isEditable,
    required Function(String) onSigilSelected,
    required Color accentColor,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            color: Colors.white.withValues(alpha: 0.45),
            fontSize: 10,
            fontWeight: FontWeight.bold,
            letterSpacing: 2,
          ),
        ),
        const SizedBox(height: 12),
        if (isEditable)
          SizedBox(
            height: 52,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              itemCount: _availableSigils.length,
              itemBuilder: (context, index) {
                final sigil = _availableSigils[index];
                final isSelected = sigil == currentSigil;
                final isUnavailable = sigil == unavailableSigil;
                return GestureDetector(
                  onTap: isUnavailable ? null : () => onSigilSelected(sigil),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 250),
                    width: 50,
                    margin: const EdgeInsets.only(right: 12),
                    decoration: BoxDecoration(
                      gradient: isSelected
                          ? LinearGradient(
                              colors: [
                                accentColor.withValues(alpha: 0.25),
                                accentColor.withValues(alpha: 0.1),
                              ],
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            )
                          : null,
                      color: isSelected ? null : Colors.white.withValues(alpha: 0.04),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: isSelected
                            ? accentColor.withValues(alpha: 0.75)
                            : isUnavailable
                                ? Colors.transparent
                                : Colors.white.withValues(alpha: 0.1),
                        width: isSelected ? 1.5 : 1,
                      ),
                      boxShadow: isSelected
                          ? [
                              BoxShadow(
                                color: accentColor.withValues(alpha: 0.3),
                                blurRadius: 12,
                                spreadRadius: 1,
                              )
                            ]
                          : [],
                    ),
                    padding: const EdgeInsets.all(9),
                    child: AnimatedOpacity(
                      duration: const Duration(milliseconds: 200),
                      opacity: isUnavailable ? 0.18 : 1.0,
                      child: AppAssetImage(
                        sigil,
                        color: isSelected ? null : Colors.white.withValues(alpha: 0.55),
                      ),
                    ),
                  ),
                );
              },
            ),
          )
        else
          Container(
            width: 50,
            height: 50,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.06),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: Colors.white.withValues(alpha: 0.15)),
            ),
            padding: const EdgeInsets.all(10),
            child: AppAssetImage(currentSigil),
          ),
      ],
    );
  }

  Widget _buildColorSelector({
    required Color currentColor,
    required Color unavailableColor,
    required bool isEditable,
    required Function(Color) onColorSelected,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (isEditable)
          SizedBox(
            height: 34,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              itemCount: _availableColors.length,
              itemBuilder: (context, index) {
                final color = _availableColors[index];
                final isSelected = color.toARGB32() == currentColor.toARGB32();
                final isUnavailable = color.toARGB32() == unavailableColor.toARGB32();
                return GestureDetector(
                  onTap: isUnavailable ? null : () => onColorSelected(color),
                  child: AnimatedOpacity(
                    duration: const Duration(milliseconds: 200),
                    opacity: isUnavailable ? 0.18 : 1.0,
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 250),
                      width: isSelected ? 34 : 30,
                      height: isSelected ? 34 : 30,
                      margin: EdgeInsets.only(
                        right: 12,
                        top: isSelected ? 0 : 2,
                      ),
                      decoration: BoxDecoration(
                        color: color,
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: isSelected ? Colors.white : Colors.transparent,
                          width: 2,
                        ),
                        boxShadow: isSelected ? [
                          BoxShadow(color: color.withValues(alpha: 0.65), blurRadius: 14, spreadRadius: 2)
                        ] : [],
                      ),
                    ),
                  ),
                );
              },
            ),
          )
        else
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: currentColor,
              shape: BoxShape.circle,
              border: Border.all(color: Colors.white.withValues(alpha: 0.2), width: 1.5),
            ),
          ),
      ],
    );
  }

  Widget _buildModeButton({
    required String title,
    required String subtitle,
    required IconData icon,
    required VoidCallback onTap,
    required Color primaryColor,
  }) {
    return Center(
      child: SizedBox(
        width: 300,
        child: _AnimatedPressButton(
          onTap: onTap,
          accentColor: primaryColor,
          child: _StonePanel(
            accentColor: primaryColor,
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: primaryColor.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: primaryColor.withValues(alpha: 0.2), width: 1),
                  ),
                  child: Icon(icon, size: 24, color: primaryColor),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 2,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        subtitle,
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.4),
                          fontSize: 10,
                          letterSpacing: 0.5,
                        ),
                      ),
                    ],
                  ),
                ),
                Icon(Icons.chevron_right, color: primaryColor.withValues(alpha: 0.4), size: 18),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildDeviceList(BluetoothState state, Color primary) {
    final devices = state.discoveredDevices;

    if (devices.isEmpty && state.status == BluetoothStatus.scanning) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(40.0),
          child: Column(
            children: [
              CircularProgressIndicator(valueColor: AlwaysStoppedAnimation<Color>(primary)),
              const SizedBox(height: 16),
              const Text('Scanning for warriors...', style: TextStyle(color: Colors.white38, fontSize: 12)),
            ],
          ),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _SectionLabel('NEARBY BATTLES', color: primary),
        const SizedBox(height: 16),
        ListView.separated(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: devices.length,
          separatorBuilder: (context, index) => const SizedBox(height: 12),
          itemBuilder: (context, index) {
            final device = devices[index];
            return _AnimatedPressButton(
              onTap: () => ref.read(bluetoothProvider.notifier).connectToDevice(device),
              accentColor: primary,
              child: _StonePanel(
                accentColor: primary,
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                child: Row(
                  children: [
                    Icon(Icons.bluetooth_searching, color: primary.withValues(alpha: 0.6), size: 18),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(device.name, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                          const Text('Tap to join room', style: TextStyle(color: Colors.white38, fontSize: 10)),
                        ],
                      ),
                    ),
                    Icon(Icons.login, color: primary.withValues(alpha: 0.4), size: 18),
                  ],
                ),
              ),
            );
          },
        ),
      ],
    );
  }

  Widget _buildHostWaiting(BluetoothState state, Color primary) {
    return Center(
      child: _StonePanel(
        accentColor: primary,
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.wifi_tethering_rounded, size: 48, color: primary.withValues(alpha: 0.6)),
            const SizedBox(height: 16),
            Text(
              state.status == BluetoothStatus.connected 
                  ? 'PEER CONNECTED!' 
                  : 'WAITING FOR WARRIORS...',
              style: TextStyle(color: primary, fontSize: 16, fontWeight: FontWeight.bold, letterSpacing: 2),
            ),
            const SizedBox(height: 12),
            _RoyalDivider(color: primary),
            const SizedBox(height: 12),
            Text(
              state.status == BluetoothStatus.connected
                  ? 'The council is ready. You may now start the battle.'
                  : 'Signal sent. Make sure your opponent is scanning for the war signal.',
              style: TextStyle(color: Colors.white.withValues(alpha: 0.38), fontSize: 11, height: 1.5),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
//  Press-scale button wrapper (subtle tactile feedback)
// ─────────────────────────────────────────────────────────────────────────────
class _AnimatedPressButton extends StatefulWidget {
  final Widget child;
  final VoidCallback onTap;
  final Color accentColor;

  const _AnimatedPressButton({
    required this.child,
    required this.onTap,
    required this.accentColor,
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
      duration: const Duration(milliseconds: 110),
      reverseDuration: const Duration(milliseconds: 180),
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
