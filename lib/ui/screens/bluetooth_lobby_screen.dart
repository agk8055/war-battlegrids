import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../providers/bluetooth_provider.dart';
import '../../providers/turn_provider.dart';
import '../../providers/game_settings_provider.dart';
import '../../providers/simulation_provider.dart';
import '../../core/enums/game_mode.dart';
import 'game_screen.dart';
import 'map_selection_screen.dart';

class BluetoothLobbyScreen extends ConsumerStatefulWidget {
  const BluetoothLobbyScreen({super.key});

  @override
  ConsumerState<BluetoothLobbyScreen> createState() => _BluetoothLobbyScreenState();
}

class _BluetoothLobbyScreenState extends ConsumerState<BluetoothLobbyScreen> {
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

  @override
  void initState() {
    super.initState();
    final bluetoothState = ref.read(bluetoothProvider);
    _isHosting = bluetoothState.isHost && bluetoothState.status != BluetoothStatus.idle;
    _isJoining = !bluetoothState.isHost && bluetoothState.status != BluetoothStatus.idle;
    _thresholdController = TextEditingController(text: '${bluetoothState.kingdomAttackThreshold}');
  }

  @override
  void dispose() {
    _thresholdController.dispose();
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

    // Set multiplayer mode flag
    ref.read(multiplayerModeProvider.notifier).setMultiplayer(true);
    
    // Update game mode in settings
    ref.read(gameSettingsProvider.notifier).setMode(GameMode.multiplayer);

    // Reset simulation for a fresh game
    ref.read(simulationProvider.notifier).reset();

    // If host, send start game message to peer
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
    final theme = Theme.of(context);

    // Listen for peer starting game or connection drops
    ref.listen(bluetoothProvider, (previous, next) {
      if (!mounted) return;

      if (next.status == BluetoothStatus.idle && previous?.status == BluetoothStatus.connected) {
        // Disconnected mid-lobby
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Peer disconnected')),
        );
        setState(() {
          _isHosting = false;
          _isJoining = false;
        });
      }
      
      if (next.gameStarted && !(previous?.gameStarted ?? false) && !next.isHost) {
        // Host started game, navigate for joiner
        _startGame();
      }

      // Sync controller if threshold changed from outside (sync message)
      if (next.kingdomAttackThreshold != previous?.kingdomAttackThreshold) {
        if (_thresholdController.text != '${next.kingdomAttackThreshold}') {
          _thresholdController.text = '${next.kingdomAttackThreshold}';
        }
      }
    });

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        title: const Text('BLUETOOTH MULTIPLAYER', style: TextStyle(letterSpacing: 2)),
        backgroundColor: Colors.transparent,
        foregroundColor: theme.colorScheme.primary,
        elevation: 0,
      ),
      body: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 8.0),
        child: SingleChildScrollView(
          child: Column(
            children: [
              if (!_isHosting && !_isJoining) ...[
                const SizedBox(height: 100),
                _buildModeButton(
                  title: 'HOST ROOM',
                  subtitle: 'Create a room for others to join',
                  icon: Icons.wifi_tethering_rounded,
                  onTap: _handleHost,
                ),
                const SizedBox(height: 24),
                _buildModeButton(
                  title: 'JOIN ROOM',
                  subtitle: 'Search for nearby rooms',
                  icon: Icons.search_rounded,
                  onTap: _handleJoin,
                ),
              ] else ...[
                _buildStatusHeader(bluetoothState),
                const SizedBox(height: 12),
                if (_isJoining && bluetoothState.status != BluetoothStatus.connected) 
                   _buildDeviceList(bluetoothState),
                if (_isHosting && bluetoothState.status != BluetoothStatus.connected) 
                   _buildHostWaiting(bluetoothState),
                
                if (bluetoothState.status == BluetoothStatus.connected) ...[
                  const SizedBox(height: 24),
                  _buildBattleSettings(bluetoothState, theme),
                ],

                const SizedBox(height: 32),
                if (bluetoothState.status == BluetoothStatus.connected && bluetoothState.isHost) ...[
                  if (bluetoothState.selectedMapName != null)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 16.0),
                      child: Text(
                        'SELECTED MAP: ${bluetoothState.selectedMapName}',
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
                        ref.read(bluetoothProvider.notifier).sendMapSelection(result['path']!, result['name']!);
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
                    onPressed: bluetoothState.selectedMapPath != null ? _startGame : null,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: theme.colorScheme.primary,
                      foregroundColor: Colors.black,
                      padding: const EdgeInsets.symmetric(horizontal: 48, vertical: 16),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    child: const Text('START GAME', style: TextStyle(fontWeight: FontWeight.bold, letterSpacing: 1.5)),
                  ),
                ],
                if (bluetoothState.status == BluetoothStatus.connected && !bluetoothState.isHost)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 16.0),
                    child: Column(
                      children: [
                        if (bluetoothState.selectedMapName != null)
                          Text(
                            'MAP: ${bluetoothState.selectedMapName}',
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
                  onPressed: () {
                    ref.read(bluetoothProvider.notifier).disconnect();
                    if (mounted) {
                      setState(() {
                        _isHosting = false;
                        _isJoining = false;
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
    );
  }

  Widget _buildBattleSettings(BluetoothState state, ThemeData theme) {
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
            onSigilSelected: (sigil) => ref.read(bluetoothProvider.notifier).updateSettings(p1Symbol: sigil),
          ),
          const SizedBox(height: 12),
          _buildColorSelector(
            currentColor: Color(state.player1Color),
            unavailableColor: Color(state.player2Color),
            isEditable: isHost,
            onColorSelected: (color) => ref.read(bluetoothProvider.notifier).updateSettings(p1Color: color.toARGB32()),
          ),
          const SizedBox(height: 24),
          _buildSigilSelector(
            label: isHost ? '${state.peerKingdomName ?? 'PEER'}\'S SIGIL' : 'YOUR SIGIL',
            currentSigil: state.player2Symbol,
            unavailableSigil: state.player1Symbol,
            isEditable: isHost,
            onSigilSelected: (sigil) => ref.read(bluetoothProvider.notifier).updateSettings(p2Symbol: sigil),
          ),
          const SizedBox(height: 12),
          _buildColorSelector(
            currentColor: Color(state.player2Color),
            unavailableColor: Color(state.player1Color),
            isEditable: isHost,
            onColorSelected: (color) => ref.read(bluetoothProvider.notifier).updateSettings(p2Color: color.toARGB32()),
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
                      ref.read(bluetoothProvider.notifier).updateSettings(threshold: val);
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

  Widget _buildStatusHeader(BluetoothState state) {
    String statusText = '';
    Color statusColor = Colors.white54;
    
    switch (state.status) {
      case BluetoothStatus.idle:
        statusText = 'IDLE';
        break;
      case BluetoothStatus.scanning:
        statusText = state.isHost ? 'ADVERTISING...' : 'SCANNING...';
        statusColor = Theme.of(context).colorScheme.primary;
        break;
      case BluetoothStatus.connecting:
        statusText = 'CONNECTING...';
        statusColor = Colors.orange;
        break;
      case BluetoothStatus.connected:
        final peerName = state.peerKingdomName ?? state.connectedDevice?.name ?? 'PEER';
        statusText = 'CONNECTED TO $peerName';
        statusColor = Colors.green;
        break;
      case BluetoothStatus.failed:
        statusText = 'CONNECTION FAILED';
        statusColor = Colors.red;
        break;
    }

    return Container(
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
    );
  }

  Widget _buildDeviceList(BluetoothState state) {
    final devices = state.discoveredDevices;

    if (devices.isEmpty && state.status == BluetoothStatus.scanning) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(40.0),
          child: CircularProgressIndicator(),
        ),
      );
    }

    return ListView.separated(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: devices.length,
      separatorBuilder: (context, index) => const SizedBox(height: 12),
      itemBuilder: (context, index) {
        final device = devices[index];
        return ListTile(
          tileColor: Colors.grey[900],
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          title: Text(device.name, style: const TextStyle(color: Colors.white)),
          subtitle: const Text('Tap to connect', style: TextStyle(color: Colors.white38, fontSize: 11)),
          trailing: const Icon(Icons.chevron_right, color: Colors.white24),
          onTap: () => ref.read(bluetoothProvider.notifier).connectToDevice(device),
        );
      },
    );
  }

  Widget _buildHostWaiting(BluetoothState state) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.wifi_tethering_rounded, size: 64, color: Colors.white10),
          const SizedBox(height: 16),
          Text(
            state.status == BluetoothStatus.connected 
                ? 'PEER CONNECTED!' 
                : 'WAITING FOR PLAYERS...',
            style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          Text(
            state.status == BluetoothStatus.connected
                ? 'You can now start the battle'
                : 'Make sure your opponent is scanning for rooms',
            style: const TextStyle(color: Colors.white38, fontSize: 12),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}
