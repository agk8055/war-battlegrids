import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../providers/bluetooth_provider.dart';
import '../../providers/turn_provider.dart';
import '../../providers/game_settings_provider.dart';
import '../../providers/simulation_provider.dart';
import '../../core/enums/game_mode.dart';
import 'game_screen.dart';

class BluetoothLobbyScreen extends ConsumerStatefulWidget {
  const BluetoothLobbyScreen({super.key});

  @override
  ConsumerState<BluetoothLobbyScreen> createState() => _BluetoothLobbyScreenState();
}

class _BluetoothLobbyScreenState extends ConsumerState<BluetoothLobbyScreen> {
  bool _isHosting = false;
  bool _isJoining = false;

  @override
  void dispose() {
    // Stop all Bluetooth operations when leaving the lobby
    ref.read(bluetoothProvider.notifier).stopAll();
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
    ref.read(multiplayerModeProvider.notifier).state = true;
    
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
      }
      
      if (next.gameStarted && !(previous?.gameStarted ?? false) && !next.isHost) {
        // Host started game, navigate for joiner
        _startGame();
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
        child: Column(
          children: [
            if (!_isHosting && !_isJoining) ...[
              const Spacer(),
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
              const Spacer(),
            ] else ...[
              _buildStatusHeader(bluetoothState),
              const SizedBox(height: 12),
              if (_isJoining) _buildDeviceList(bluetoothState),
              if (_isHosting) _buildHostWaiting(bluetoothState),
              const Spacer(),
              if (bluetoothState.status == BluetoothStatus.connected && bluetoothState.isHost)
                ElevatedButton(
                  onPressed: _startGame,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: theme.colorScheme.primary,
                    foregroundColor: Colors.black,
                    padding: const EdgeInsets.symmetric(horizontal: 48, vertical: 16),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  child: const Text('START GAME', style: TextStyle(fontWeight: FontWeight.bold, letterSpacing: 1.5)),
                ),
              if (bluetoothState.status == BluetoothStatus.connected && !bluetoothState.isHost)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 16.0),
                  child: Text(
                    'WAITING FOR HOST TO START...',
                    style: TextStyle(color: Colors.white54, fontStyle: FontStyle.italic),
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
                child: const Text('CANCEL', style: TextStyle(color: Colors.white38)),
              ),
              const SizedBox(height: 16),
            ],
          ],
        ),
      ),
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
        statusText = 'CONNECTED TO ${state.connectedDevice?.name ?? 'PEER'}';
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
      return const Expanded(
        child: Center(
          child: CircularProgressIndicator(),
        ),
      );
    }

    return Expanded(
      child: ListView.separated(
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
      ),
    );
  }

  Widget _buildHostWaiting(BluetoothState state) {
    return Expanded(
      child: Center(
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.wifi_tethering_rounded, size: 64, color: Colors.white10),
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
        ),
      ),
    );
  }
}
