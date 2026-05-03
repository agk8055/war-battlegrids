import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../providers/online_provider.dart';
import '../../providers/turn_provider.dart';
import '../../providers/game_settings_provider.dart';
import '../../providers/simulation_provider.dart';
import '../../core/enums/game_mode.dart';
import '../../core/enums/connection_type.dart';
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
//  Reusable Widgets
// ─────────────────────────────────────────────────────────────────────────────

/// A stone-panel card with corner ornaments and optional title banner.
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
    final ornamentColor = accentColor.withValues(alpha: 0.55);
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            const Color(0xFF1A1510),
            const Color(0xFF0F0D0A),
          ],
        ),
        border: Border.all(color: accentColor.withValues(alpha: 0.28), width: 1.2),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.55),
            blurRadius: 18,
            offset: const Offset(0, 6),
          ),
          BoxShadow(
            color: accentColor.withValues(alpha: 0.06),
            blurRadius: 24,
            spreadRadius: 2,
          ),
        ],
      ),
      child: Stack(
        children: [
          // Parchment hatch texture
          Positioned.fill(
            child: CustomPaint(
              painter: _HatchPainter(
                color: Colors.white.withValues(alpha: 0.018),
              ),
            ),
          ),
          // Corner ornaments
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

/// Section label styled like a carved stone inscription.
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
        Text(
          text,
          style: TextStyle(
            color: color,
            fontSize: 11,
            fontWeight: FontWeight.bold,
            letterSpacing: 2.8,
          ),
        ),
        const SizedBox(width: 8),
        Expanded(child: Container(height: 1.5, color: color.withValues(alpha: 0.5))),
      ],
    );
  }
}

/// Divider styled as a decorative horizontal rule.
class _RoyalDivider extends StatelessWidget {
  final Color color;
  const _RoyalDivider({required this.color});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(child: Container(height: 1, color: color.withValues(alpha: 0.15))),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10),
          child: Icon(Icons.brightness_1, color: color.withValues(alpha: 0.3), size: 5),
        ),
        Expanded(child: Container(height: 1, color: color.withValues(alpha: 0.15))),
      ],
    );
  }
}

class OnlineLobbyScreen extends ConsumerStatefulWidget {
  const OnlineLobbyScreen({super.key});

  @override
  ConsumerState<OnlineLobbyScreen> createState() => _OnlineLobbyScreenState();
}

class _OnlineLobbyScreenState extends ConsumerState<OnlineLobbyScreen>
    with TickerProviderStateMixin {
  bool _isHosting = false;
  bool _isJoining = false;
  final TextEditingController _codeController = TextEditingController();
  final TextEditingController _thresholdController = TextEditingController();

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
    final onlineState = ref.read(onlineProvider);
    _isHosting = onlineState.isHost && onlineState.status != OnlineStatus.idle;
    // Joiner should only be \"joining\" if they have a code and are connected
    _isJoining = !onlineState.isHost && onlineState.status != OnlineStatus.idle;
    _thresholdController.text = '${onlineState.kingdomAttackThreshold}';

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
    _codeController.dispose();
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
    ref.read(onlineProvider.notifier).createRoom();
  }

  void _handleJoin() {
    setState(() {
      _isJoining = true;
      _isHosting = false;
      _codeController.clear();
    });
    // Disconnect any existing session when choosing to join fresh
    ref.read(onlineProvider.notifier).disconnect();
  }

  void _submitJoinCode() {
    if (_codeController.text.length == 5) {
      ref.read(onlineProvider.notifier).joinRoom(_codeController.text);
    }
  }

  void _startGame() {
    if (!mounted) return;

    ref.read(connectionTypeProvider.notifier).setConnectionType(ConnectionType.online);
    ref.read(gameSettingsProvider.notifier).setMode(GameMode.multiplayer);
    ref.read(simulationProvider.notifier).reset();

    // Ensure state is ready for a potential return to lobby later
    ref.read(onlineProvider.notifier).setGameStarted(true);

    if (ref.read(onlineProvider).isHost) {
      ref.read(onlineProvider.notifier).sendStartGame();
    }

    Navigator.of(context).pushReplacement(
      MaterialPageRoute(
        settings: const RouteSettings(name: '/game'),
        builder: (context) => const GameScreen(),
      ),
    );
  }

  Future<bool> _onWillPop() async {
    final onlineState = ref.read(onlineProvider);
    if (onlineState.status == OnlineStatus.connected || onlineState.status == OnlineStatus.connecting) {
      final confirm = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          backgroundColor: const Color(0xFF161410),
          title: const Text('ABANDON ROOM?', style: TextStyle(color: Colors.redAccent, letterSpacing: 2)),
          content: const Text('Leaving now will close the room and disconnect you from your opponent.', style: TextStyle(color: Colors.white70)),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('STAY', style: TextStyle(color: Colors.white38)),
            ),
            TextButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text('LEAVE', style: TextStyle(color: Colors.redAccent)),
            ),
          ],
        ),
      );
      if (confirm == true) {
        ref.read(onlineProvider.notifier).disconnect();
        return true;
      }
      return false;
    }
    
    // If failed, disconnected or idle, just clean up and allow pop
    if (onlineState.status != OnlineStatus.idle) {
      ref.read(onlineProvider.notifier).disconnect();
    }
    return true;
  }

  @override
  Widget build(BuildContext context) {
    final onlineState = ref.watch(onlineProvider);
    final settings = ref.watch(gameSettingsProvider);
    final theme = Theme.of(context);
    final primary = theme.colorScheme.primary;

    ref.listen(onlineProvider, (previous, next) {
      if (!mounted) return;

      if (next.status == OnlineStatus.roomNotFound) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Room not found or no host present'),
            backgroundColor: Colors.orange,
          ),
        );
        setState(() { _isJoining = false; _isHosting = false; });
      }

      if (next.status == OnlineStatus.disconnected && previous?.status == OnlineStatus.connected) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Your opponent has left the room'),
            backgroundColor: Colors.redAccent,
          ),
        );
        setState(() { _isHosting = false; _isJoining = false; });
      }

      // Notify host when client leaves (status stays connected)
      if (next.peerKingdomName == null && previous?.peerKingdomName != null && next.status == OnlineStatus.connected) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Your opponent has left the room'),
            backgroundColor: Colors.redAccent,
          ),
        );
      }

      if (next.status == OnlineStatus.idle && previous?.status == OnlineStatus.connected) {
        setState(() { _isHosting = false; _isJoining = false; });
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

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) async {
        if (didPop) return;
        final shouldPop = await _onWillPop();
        if (shouldPop && mounted) {
          Navigator.of(context).pop();
        }
      },
      child: Scaffold(
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
                                subtitle: 'Get a code and invite a friend',
                                icon: Icons.add_to_home_screen_rounded,
                                onTap: _handleHost,
                                primaryColor: primary,
                              ),
                              const SizedBox(height: 24),
                              _buildModeButton(
                                title: 'JOIN ROOM',
                                subtitle: 'Enter a code to join a battle',
                                icon: Icons.login_rounded,
                                onTap: _handleJoin,
                                primaryColor: primary,
                              ),
                            ] else if (_isJoining && onlineState.status == OnlineStatus.idle) ...[
                              const SizedBox(height: 60),
                              _buildJoinInput(primary),
                            ] else ...[
                              _buildStatusHeader(onlineState, primary),
                              const SizedBox(height: 24),
                              
                              if (onlineState.status == OnlineStatus.connected) ...[
                                _buildBattleSettings(onlineState, primary),
                              ],

                              const SizedBox(height: 32),
                              if (onlineState.status == OnlineStatus.connected && onlineState.isHost) ...[
                                if (onlineState.selectedMapName != null)
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
                                            'SELECTED MAP: ${onlineState.selectedMapName!.toUpperCase()}',
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
                                      ref.read(onlineProvider.notifier).sendMapSelection(result['path']!, result['name']!);
                                    }
                                  },
                                  label: 'SELECT MAP',
                                  icon: Icons.map,
                                  accentColor: Colors.white38,
                                ),
                                const SizedBox(height: 20),
                                _buildThemedButton(
                                  onTap: onlineState.selectedMapPath != null ? _startGame : null,
                                  label: 'START BATTLE',
                                  icon: Icons.sports_kabaddi,
                                  accentColor: primary,
                                  isPrimary: true,
                                ),
                              ],
                              if (onlineState.status == OnlineStatus.connected && !onlineState.isHost)
                                Padding(
                                  padding: const EdgeInsets.symmetric(vertical: 16.0),
                                  child: _StonePanel(
                                    accentColor: primary,
                                    child: Column(
                                      children: [
                                        if (onlineState.selectedMapName != null) ...[
                                          Text(
                                            'MAP: ${onlineState.selectedMapName!.toUpperCase()}',
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
                                  onPressed: () async {
                                    if (await _onWillPop()) {
                                      setState(() {
                                        _isHosting = false;
                                        _isJoining = false;
                                        _codeController.clear();
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
              onTap: () async {
                if (await _onWillPop()) {
                  if (mounted) Navigator.of(context).pop();
                }
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
                    'Online Multiplayer · Global Conquest',
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
              child: Icon(Icons.public, color: primary.withValues(alpha: 0.7), size: 20),
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

  Widget _buildJoinInput(Color primary) {
    return Center(
      child: _StonePanel(
        accentColor: primary,
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'ENTER ROOM CODE',
              style: TextStyle(
                color: primary,
                fontSize: 16,
                fontWeight: FontWeight.bold,
                letterSpacing: 3,
              ),
            ),
            const SizedBox(height: 24),
            TextField(
              controller: _codeController,
              textAlign: TextAlign.center,
              maxLength: 5,
              style: GoogleFonts.sairaStencilOne(
                color: Colors.white,
                fontSize: 32,
                letterSpacing: 8,
              ),
              decoration: InputDecoration(
                counterText: '',
                enabledBorder: UnderlineInputBorder(
                  borderSide: BorderSide(color: primary.withValues(alpha: 0.3)),
                ),
                focusedBorder: UnderlineInputBorder(
                  borderSide: BorderSide(color: primary),
                ),
              ),
              onChanged: (val) {
                if (val.length == 5) _submitJoinCode();
              },
            ),
            const SizedBox(height: 32),
            _buildThemedButton(
              onTap: _submitJoinCode,
              label: 'JOIN BATTLE',
              icon: Icons.login_rounded,
              accentColor: primary,
              isPrimary: true,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatusHeader(OnlineState state, Color primary) {
    String statusText = '';
    Color statusColor = Colors.white54;
    
    switch (state.status) {
      case OnlineStatus.idle:
        statusText = 'IDLE';
        break;
      case OnlineStatus.connecting:
        statusText = 'CONNECTING...';
        statusColor = Colors.orange;
        break;
      case OnlineStatus.connected:
        if (state.peerKingdomName != null) {
          statusText = 'CONNECTED TO ${state.peerKingdomName!.toUpperCase()}';
          statusColor = Colors.green;
        } else {
          statusText = 'WAITING FOR PEER...';
          statusColor = primary;
        }
        break;
      case OnlineStatus.failed:
        statusText = 'CONNECTION FAILED';
        statusColor = Colors.red;
        break;
      case OnlineStatus.roomNotFound:
        statusText = 'ROOM NOT FOUND';
        statusColor = Colors.orange;
        break;
      case OnlineStatus.disconnected:
        statusText = 'DISCONNECTED';
        statusColor = Colors.red;
        break;
    }

    return Column(
      children: [
        if (state.roomCode != null) ...[
          _StonePanel(
            accentColor: primary,
            padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 40),
            child: Column(
              children: [
                Text(
                  'ROOM CODE',
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.3),
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 3,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  state.roomCode!,
                  style: GoogleFonts.sairaStencilOne(
                    color: primary,
                    fontSize: 42,
                    letterSpacing: 6,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
        ],
        Container(
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
      ],
    );
  }

  Widget _buildBattleSettings(OnlineState state, Color primary) {
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
            onSigilSelected: (sigil) => ref.read(onlineProvider.notifier).updateSettings(p1Symbol: sigil),
            accentColor: isHost ? primary : Colors.white38,
          ),
          const SizedBox(height: 18),
          _buildColorSelector(
            currentColor: Color(state.player1Color),
            unavailableColor: Color(state.player2Color),
            isEditable: isHost,
            onColorSelected: (color) => ref.read(onlineProvider.notifier).updateSettings(p1Color: color.toARGB32()),
          ),
          const SizedBox(height: 24),
          _RoyalDivider(color: primary),
          const SizedBox(height: 24),
          
          _buildSigilSelector(
            label: isHost ? '${state.peerKingdomName ?? 'PEER'}\'S SIGIL' : 'YOUR SIGIL',
            currentSigil: state.player2Symbol,
            unavailableSigil: state.player1Symbol,
            isEditable: isHost,
            onSigilSelected: (sigil) => ref.read(onlineProvider.notifier).updateSettings(p2Symbol: sigil),
            accentColor: isHost ? primary : Colors.white38,
          ),
          const SizedBox(height: 18),
          _buildColorSelector(
            currentColor: Color(state.player2Color),
            unavailableColor: Color(state.player1Color),
            isEditable: isHost,
            onColorSelected: (color) => ref.read(onlineProvider.notifier).updateSettings(p2Color: color.toARGB32()),
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
                      ref.read(onlineProvider.notifier).updateSettings(threshold: val);
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
                      child: Image.asset(
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
            child: Image.asset(currentSigil),
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
                        style: TextStyle(
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

