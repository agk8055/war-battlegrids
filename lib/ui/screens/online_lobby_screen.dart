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

class OnlineLobbyScreen extends ConsumerStatefulWidget {
  const OnlineLobbyScreen({super.key});

  @override
  ConsumerState<OnlineLobbyScreen> createState() => _OnlineLobbyScreenState();
}

class _OnlineLobbyScreenState extends ConsumerState<OnlineLobbyScreen> {
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

  @override
  void initState() {
    super.initState();
    final onlineState = ref.read(onlineProvider);
    _isHosting = onlineState.isHost && onlineState.status != OnlineStatus.idle;
    // Joiner should only be "joining" if they have a code and are connected
    _isJoining = !onlineState.isHost && onlineState.status != OnlineStatus.idle;
    _thresholdController.text = '${onlineState.kingdomAttackThreshold}';
  }

  @override
  void dispose() {
    _codeController.dispose();
    _thresholdController.dispose();
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
        backgroundColor: Colors.black,
        appBar: AppBar(
          title: const Text('ONLINE MULTIPLAYER', style: TextStyle(letterSpacing: 2)),
          backgroundColor: Colors.transparent,
          foregroundColor: primary,
          elevation: 0,
          leading: IconButton(
            icon: const Icon(Icons.chevron_left),
            onPressed: () async {
              if (await _onWillPop()) {
                if (mounted) Navigator.of(context).pop();
              }
            },
          ),
        ),
        body: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 8.0),
          child: SingleChildScrollView(
            child: Column(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
                  decoration: BoxDecoration(
                    border: Border.all(color: primary.withValues(alpha: 0.3)),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    'YOUR KINGDOM: ${settings.player1Name.toUpperCase()}',
                    style: TextStyle(color: primary, fontSize: 10, fontWeight: FontWeight.bold, letterSpacing: 1.5),
                  ),
                ),
                const SizedBox(height: 16),

                if (!_isHosting && !_isJoining) ...[
                  const SizedBox(height: 100),
                  _buildModeButton(
                    title: 'HOST ROOM',
                    subtitle: 'Get a code and invite a friend',
                    icon: Icons.add_to_home_screen_rounded,
                    onTap: _handleHost,
                  ),
                  const SizedBox(height: 24),
                  _buildModeButton(
                    title: 'JOIN ROOM',
                    subtitle: 'Enter a code to join a battle',
                    icon: Icons.login_rounded,
                    onTap: _handleJoin,
                  ),
                ] else if (_isJoining && onlineState.status == OnlineStatus.idle) ...[
                  const SizedBox(height: 100),
                  _buildJoinInput(theme),
                ] else ...[
                  _buildStatusHeader(onlineState),
                  const SizedBox(height: 12),
                  
                  if (onlineState.status == OnlineStatus.connected) ...[
                    const SizedBox(height: 24),
                    _buildBattleSettings(onlineState, theme),
                  ],

                  const SizedBox(height: 32),
                  if (onlineState.status == OnlineStatus.connected && onlineState.isHost) ...[
                    if (onlineState.selectedMapName != null)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 16.0),
                        child: Text(
                          'SELECTED MAP: ${onlineState.selectedMapName}',
                          style: TextStyle(color: theme.colorScheme.primary, fontWeight: FontWeight.bold),
                        ),
                      ),
                    ElevatedButton(
                      onPressed: () async {
                        final result = await Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (context) => const MapSelectionScreen(isBluetoothMode: true),
                          ),
                        );
                        if (result != null && result is Map<String, String>) {
                          ref.read(onlineProvider.notifier).sendMapSelection(result['path']!, result['name']!);
                        }
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.grey[900],
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(horizontal: 48, vertical: 16),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      child: const Text('SELECT MAP', style: TextStyle(fontWeight: FontWeight.bold, letterSpacing: 1.5)),
                    ),
                    const SizedBox(height: 16),
                    ElevatedButton(
                      onPressed: onlineState.selectedMapPath != null ? _startGame : null,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: theme.colorScheme.primary,
                        foregroundColor: Colors.black,
                        padding: const EdgeInsets.symmetric(horizontal: 48, vertical: 16),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      child: const Text('START GAME', style: TextStyle(fontWeight: FontWeight.bold, letterSpacing: 1.5)),
                    ),
                  ],
                  if (onlineState.status == OnlineStatus.connected && !onlineState.isHost)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 16.0),
                      child: Column(
                        children: [
                          if (onlineState.selectedMapName != null)
                            Text(
                              'MAP: ${onlineState.selectedMapName}',
                              style: TextStyle(color: theme.colorScheme.primary, fontWeight: FontWeight.bold),
                            ),
                          const SizedBox(height: 8),
                          const Text(
                            'WAITING FOR HOST TO START...',
                            style: TextStyle(color: Colors.white54, fontStyle: FontStyle.italic),
                          ),
                        ],
                      ),
                    ),
                  const SizedBox(height: 8),
                  TextButton(
                    onPressed: () async {
                      if (await _onWillPop()) {
                        setState(() {
                          _isHosting = false;
                          _isJoining = false;
                          _codeController.clear();
                        });
                      }
                    },
                    child: const Text('CANCEL / LEAVE', style: TextStyle(color: Colors.white38)),
                  ),
                  const SizedBox(height: 16),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildJoinInput(ThemeData theme) {
    return Center(
      child: Container(
        width: 320,
        padding: const EdgeInsets.all(32),
        decoration: BoxDecoration(
          color: Colors.grey[900],
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: Colors.white10),
        ),
        child: Column(
          children: [
            Text('ENTER ROOM CODE', style: GoogleFonts.sairaStencilOne(color: Colors.white, fontSize: 20, letterSpacing: 2)),
            const SizedBox(height: 24),
            TextField(
              controller: _codeController,
              textAlign: TextAlign.center,
              maxLength: 5,
              style: GoogleFonts.sairaStencilOne(color: theme.colorScheme.primary, fontSize: 32, letterSpacing: 8),
              decoration: InputDecoration(
                counterText: '',
                enabledBorder: UnderlineInputBorder(borderSide: BorderSide(color: Colors.white24)),
                focusedBorder: UnderlineInputBorder(borderSide: BorderSide(color: theme.colorScheme.primary)),
              ),
              onChanged: (val) {
                if (val.length == 5) _submitJoinCode();
              },
            ),
            const SizedBox(height: 32),
            ElevatedButton(
              onPressed: _submitJoinCode,
              child: const Text('JOIN BATTLE'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatusHeader(OnlineState state) {
    String statusText = '';
    Color statusColor = Colors.white54;
    final theme = Theme.of(context);
    
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
          statusText = 'CONNECTED TO ${state.peerKingdomName}';
          statusColor = Colors.green;
        } else {
          statusText = 'WAITING FOR PEER...';
          statusColor = theme.colorScheme.primary;
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
          Text('ROOM CODE', style: TextStyle(color: Colors.white38, fontSize: 10, letterSpacing: 2)),
          const SizedBox(height: 4),
          Text(state.roomCode!, style: GoogleFonts.sairaStencilOne(color: theme.colorScheme.primary, fontSize: 36, letterSpacing: 4)),
          const SizedBox(height: 24),
        ],
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          decoration: BoxDecoration(
            color: statusColor.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: statusColor.withValues(alpha: 0.3)),
          ),
          child: Text(
            statusText,
            style: TextStyle(color: statusColor, fontWeight: FontWeight.bold, fontSize: 12),
          ),
        ),
      ],
    );
  }

  Widget _buildBattleSettings(OnlineState state, ThemeData theme) {
    final isHost = state.isHost;
    
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'BATTLE SETTINGS',
            style: TextStyle(
              color: theme.colorScheme.primary,
              fontSize: 14,
              fontWeight: FontWeight.bold,
              letterSpacing: 2,
            ),
          ),
          const SizedBox(height: 24),
          _buildSigilSelector(
            label: isHost ? 'YOUR SIGIL' : '${state.peerKingdomName ?? 'HOST'}\'S SIGIL',
            currentSigil: state.player1Symbol,
            unavailableSigil: state.player2Symbol,
            isEditable: isHost,
            onSigilSelected: (sigil) => ref.read(onlineProvider.notifier).updateSettings(p1Symbol: sigil),
          ),
          const SizedBox(height: 12),
          _buildColorSelector(
            currentColor: Color(state.player1Color),
            unavailableColor: Color(state.player2Color),
            isEditable: isHost,
            onColorSelected: (color) => ref.read(onlineProvider.notifier).updateSettings(p1Color: color.toARGB32()),
          ),
          const SizedBox(height: 24),
          _buildSigilSelector(
            label: isHost ? '${state.peerKingdomName ?? 'PEER'}\'S SIGIL' : 'YOUR SIGIL',
            currentSigil: state.player2Symbol,
            unavailableSigil: state.player1Symbol,
            isEditable: isHost,
            onSigilSelected: (sigil) => ref.read(onlineProvider.notifier).updateSettings(p2Symbol: sigil),
          ),
          const SizedBox(height: 12),
          _buildColorSelector(
            currentColor: Color(state.player2Color),
            unavailableColor: Color(state.player1Color),
            isEditable: isHost,
            onColorSelected: (color) => ref.read(onlineProvider.notifier).updateSettings(p2Color: color.toARGB32()),
          ),
          const SizedBox(height: 32),
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('ATTACK THRESHOLD', style: TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 4),
                    const Text('Points to unlock kingdom assault', style: TextStyle(color: Colors.white38, fontSize: 11)),
                  ],
                ),
              ),
              if (isHost)
                SizedBox(
                  width: 80,
                  child: TextField(
                    controller: _thresholdController,
                    textAlign: TextAlign.center,
                    keyboardType: TextInputType.number,
                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                    decoration: InputDecoration(
                      isDense: true,
                      contentPadding: const EdgeInsets.symmetric(vertical: 8),
                      enabledBorder: UnderlineInputBorder(borderSide: BorderSide(color: theme.colorScheme.primary)),
                    ),
                    onChanged: (value) {
                      final val = int.tryParse(value) ?? 100;
                      ref.read(onlineProvider.notifier).updateSettings(threshold: val);
                    },
                  ),
                )
              else
                Text(
                  '${state.kingdomAttackThreshold}',
                  style: TextStyle(color: theme.colorScheme.primary, fontSize: 18, fontWeight: FontWeight.bold),
                ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSigilSelector({
    required String label,
    required String currentSigil,
    required String unavailableSigil,
    required bool isEditable,
    required Function(String) onSigilSelected,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(color: Colors.white54, fontSize: 11, fontWeight: FontWeight.bold)),
        const SizedBox(height: 12),
        if (isEditable)
          SizedBox(
            height: 50,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              itemCount: _availableSigils.length,
              itemBuilder: (context, index) {
                final sigil = _availableSigils[index];
                final isSelected = sigil == currentSigil;
                final isUnavailable = sigil == unavailableSigil;
                return GestureDetector(
                  onTap: isUnavailable ? null : () => onSigilSelected(sigil),
                  child: Opacity(
                    opacity: isUnavailable ? 0.2 : 1.0,
                    child: Container(
                      width: 50,
                      margin: const EdgeInsets.only(right: 12),
                      decoration: BoxDecoration(
                        color: isSelected ? Theme.of(context).colorScheme.primary.withValues(alpha: 0.2) : Colors.black26,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: isSelected ? Theme.of(context).colorScheme.primary : (isUnavailable ? Colors.transparent : Colors.white12)),
                      ),
                      padding: const EdgeInsets.all(8),
                      child: Image.asset(sigil, color: isSelected ? null : Colors.white54),
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
              color: Colors.white10,
              borderRadius: BorderRadius.circular(10),
            ),
            padding: const EdgeInsets.all(8),
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
            height: 30,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              itemCount: _availableColors.length,
              itemBuilder: (context, index) {
                final color = _availableColors[index];
                final isSelected = color.toARGB32() == currentColor.toARGB32();
                final isUnavailable = color.toARGB32() == unavailableColor.toARGB32();
                return GestureDetector(
                  onTap: isUnavailable ? null : () => onColorSelected(color),
                  child: Opacity(
                    opacity: isUnavailable ? 0.2 : 1.0,
                    child: Container(
                      width: 30,
                      margin: const EdgeInsets.only(right: 12),
                      decoration: BoxDecoration(
                        color: color,
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: isSelected ? Colors.white : Colors.transparent,
                          width: 2,
                        ),
                        boxShadow: isSelected ? [
                          BoxShadow(color: color.withValues(alpha: 0.5), blurRadius: 8, spreadRadius: 1)
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
            width: 30,
            height: 30,
            decoration: BoxDecoration(
              color: currentColor,
              shape: BoxShape.circle,
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
  }) {
    return Center(
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          width: 320,
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: Colors.grey[900],
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: Colors.white10),
          ),
          child: Row(
            children: [
              Icon(icon, size: 40, color: Theme.of(context).colorScheme.primary),
              const SizedBox(width: 24),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 4),
                    Text(subtitle, style: const TextStyle(color: Colors.white54, fontSize: 12)),
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
