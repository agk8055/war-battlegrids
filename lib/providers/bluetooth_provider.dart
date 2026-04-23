import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';
import 'package:nearby_connections/nearby_connections.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:permission_handler/permission_handler.dart';
import 'simulation_provider.dart';
import 'game_settings_provider.dart';

enum BluetoothStatus { idle, scanning, connecting, connected, failed }

class DiscoveredDevice {
  final String id;
  final String name;

  DiscoveredDevice({required this.id, required this.name});
}

class BluetoothState {
  final BluetoothStatus status;
  final List<DiscoveredDevice> discoveredDevices;
  final DiscoveredDevice? connectedDevice;
  final bool isHost;
  final bool gameStarted;
  final bool isPeerPaused;
  final String? peerKingdomName;
  final String? selectedMapPath;
  final String? selectedMapName;
  final String player1Symbol;
  final String player2Symbol;
  final int player1Color;
  final int player2Color;
  final int kingdomAttackThreshold;

  BluetoothState({
    this.status = BluetoothStatus.idle,
    this.discoveredDevices = const [],
    this.connectedDevice,
    this.isHost = false,
    this.gameStarted = false,
    this.isPeerPaused = false,
    this.peerKingdomName,
    this.selectedMapPath,
    this.selectedMapName,
    this.player1Symbol = 'assets/symbols/fire.png',
    this.player2Symbol = 'assets/icons/eagle.png',
    this.player1Color = 0xFF2196F3, // Colors.blue
    this.player2Color = 0xFFF44336, // Colors.red
    this.kingdomAttackThreshold = 100,
  });

  BluetoothState copyWith({
    BluetoothStatus? status,
    List<DiscoveredDevice>? discoveredDevices,
    DiscoveredDevice? connectedDevice,
    bool? isHost,
    bool? gameStarted,
    bool? isPeerPaused,
    String? peerKingdomName,
    String? selectedMapPath,
    String? selectedMapName,
    String? player1Symbol,
    String? player2Symbol,
    int? player1Color,
    int? player2Color,
    int? kingdomAttackThreshold,
  }) {
    return BluetoothState(
      status: status ?? this.status,
      discoveredDevices: discoveredDevices ?? this.discoveredDevices,
      connectedDevice: connectedDevice ?? this.connectedDevice,
      isHost: isHost ?? this.isHost,
      gameStarted: gameStarted ?? this.gameStarted,
      isPeerPaused: isPeerPaused ?? this.isPeerPaused,
      peerKingdomName: peerKingdomName ?? this.peerKingdomName,
      selectedMapPath: selectedMapPath ?? this.selectedMapPath,
      selectedMapName: selectedMapName ?? this.selectedMapName,
      player1Symbol: player1Symbol ?? this.player1Symbol,
      player2Symbol: player2Symbol ?? this.player2Symbol,
      player1Color: player1Color ?? this.player1Color,
      player2Color: player2Color ?? this.player2Color,
      kingdomAttackThreshold: kingdomAttackThreshold ?? this.kingdomAttackThreshold,
    );
  }
}

final bluetoothProvider = NotifierProvider<BluetoothNotifier, BluetoothState>(() {
  return BluetoothNotifier();
});

class BluetoothNotifier extends Notifier<BluetoothState> {
  final Strategy strategy = Strategy.P2P_STAR;
  final String serviceId = "com.example.war.p2p";

  @override
  BluetoothState build() {
    return BluetoothState();
  }

  Future<bool> requestPermissions() async {
    Map<Permission, PermissionStatus> statuses = await [
      Permission.bluetooth,
      Permission.bluetoothScan,
      Permission.bluetoothConnect,
      Permission.bluetoothAdvertise,
      Permission.location,
      Permission.nearbyWifiDevices,
    ].request();

    return statuses.values.every((status) => status.isGranted);
  }

  Future<void> startScanning() async {
    if (await requestPermissions()) {
      state = state.copyWith(
        status: BluetoothStatus.scanning, 
        isHost: false,
        discoveredDevices: [],
      );
      
      try {
        await Nearby().stopDiscovery();
        await Nearby().startDiscovery(
          ref.read(gameSettingsProvider).player1Name,
          strategy,
          onEndpointFound: (id, name, serviceId) {
            final devices = List<DiscoveredDevice>.from(state.discoveredDevices);
            if (!devices.any((d) => d.id == id)) {
              devices.add(DiscoveredDevice(id: id, name: name));
              state = state.copyWith(discoveredDevices: devices);
            }
          },
          onEndpointLost: (id) {
            final devices = List<DiscoveredDevice>.from(state.discoveredDevices);
            devices.removeWhere((d) => d.id == id);
            state = state.copyWith(discoveredDevices: devices);
          },
          serviceId: serviceId,
        );
      } catch (e) {
        state = state.copyWith(status: BluetoothStatus.failed);
      }
    } else {
      state = state.copyWith(status: BluetoothStatus.failed);
    }
  }

  Future<void> startHosting() async {
    if (await requestPermissions()) {
      state = state.copyWith(
        status: BluetoothStatus.scanning, 
        isHost: true,
        discoveredDevices: [],
      );
      
      try {
        await Nearby().stopAdvertising();
        await Nearby().startAdvertising(
          ref.read(gameSettingsProvider).player1Name,
          strategy,
          onConnectionInitiated: _onConnectionInitiated,
          onConnectionResult: _onConnectionResult,
          onDisconnected: _onDisconnected,
          serviceId: serviceId,
        );
      } catch (e) {
        state = state.copyWith(status: BluetoothStatus.failed);
      }
    } else {
      state = state.copyWith(status: BluetoothStatus.failed);
    }
  }

  void _onConnectionInitiated(String id, ConnectionInfo info) {
    Nearby().acceptConnection(
      id,
      onPayLoadRecieved: (id, payload) {
        if (payload.type == PayloadType.BYTES) {
          final str = String.fromCharCodes(payload.bytes!);
          final message = jsonDecode(str);
          _handleMessage(message);
        }
      },
    );
  }

  void _onConnectionResult(String id, Status status) {
    if (status == Status.CONNECTED) {
      state = state.copyWith(
        status: BluetoothStatus.connected,
        connectedDevice: DiscoveredDevice(id: id, name: "Peer"),
      );
      sendKingdomName(ref.read(gameSettingsProvider).player1Name);
    } else {
      state = state.copyWith(status: BluetoothStatus.failed);
    }
  }

  void _onDisconnected(String id) {
    if (state.connectedDevice?.id == id) {
      state = state.copyWith(
        status: BluetoothStatus.idle,
        connectedDevice: null,
      );
    }
  }

  void _handleMessage(dynamic message) {
    if (message['type'] == 'move') {
      final x = message['x'] as int;
      final y = message['y'] as int;
      ref.read(simulationProvider.notifier).placeUnitFromPeer(x, y);
    } else if (message['type'] == 'start_game') {
      state = state.copyWith(gameStarted: true, isPeerPaused: false);
    } else if (message['type'] == 'kingdom_name') {
      state = state.copyWith(peerKingdomName: message['name']);
      ref.read(gameSettingsProvider.notifier).setPlayerNames(
        ref.read(gameSettingsProvider).player1Name,
        message['name'],
      );
    } else if (message['type'] == 'map_selection') {
      state = state.copyWith(
        selectedMapPath: message['path'],
        selectedMapName: message['name'],
      );
      ref.read(gameSettingsProvider.notifier).setSelectedMap(message['path']);
    } else if (message['type'] == 'sync_settings') {
      state = state.copyWith(
        player1Symbol: message['p1Symbol'],
        player2Symbol: message['p2Symbol'],
        player1Color: message['p1Color'],
        player2Color: message['p2Color'],
        kingdomAttackThreshold: message['threshold'],
      );
      // For joiner, p2 is local, p1 is peer
      ref.read(gameSettingsProvider.notifier).setPlayerSymbols(
        message['p2Symbol'],
        message['p1Symbol'],
      );
      ref.read(gameSettingsProvider.notifier).setPlayerColors(
        message['p2Color'],
        message['p1Color'],
      );
      ref.read(gameSettingsProvider.notifier).setKingdomAttackThreshold(message['threshold']);
    } else if (message['type'] == 'pause') {
      state = state.copyWith(isPeerPaused: message['paused']);
    } else if (message['type'] == 'abandon') {
      state = state.copyWith(gameStarted: false, isPeerPaused: false);
    }
  }

  void updateSettings({String? p1Symbol, String? p2Symbol, int? p1Color, int? p2Color, int? threshold}) {
    // Validation: Host cannot select same sigil or color
    String finalP1Symbol = p1Symbol ?? state.player1Symbol;
    String finalP2Symbol = p2Symbol ?? state.player2Symbol;
    int finalP1Color = p1Color ?? state.player1Color;
    int finalP2Color = p2Color ?? state.player2Color;

    if (finalP1Symbol == finalP2Symbol) return;
    if (finalP1Color == finalP2Color) return;

    state = state.copyWith(
      player1Symbol: finalP1Symbol,
      player2Symbol: finalP2Symbol,
      player1Color: finalP1Color,
      player2Color: finalP2Color,
      kingdomAttackThreshold: threshold,
    );
    
    if (state.isHost) {
      ref.read(gameSettingsProvider.notifier).setPlayerSymbols(
        state.player1Symbol,
        state.player2Symbol,
      );
      ref.read(gameSettingsProvider.notifier).setPlayerColors(
        state.player1Color,
        state.player2Color,
      );
      ref.read(gameSettingsProvider.notifier).setKingdomAttackThreshold(state.kingdomAttackThreshold);
      sendSettingsUpdate();
    }
  }

  Future<void> sendSettingsUpdate() async {
    if (state.status == BluetoothStatus.connected && state.connectedDevice != null && state.isHost) {
      final message = jsonEncode({
        'type': 'sync_settings',
        'p1Symbol': state.player1Symbol,
        'p2Symbol': state.player2Symbol,
        'p1Color': state.player1Color,
        'p2Color': state.player2Color,
        'threshold': state.kingdomAttackThreshold,
      });
      await Nearby().sendBytesPayload(
        state.connectedDevice!.id,
        Uint8List.fromList(message.codeUnits),
      );
    }
  }

  void setGameStarted(bool value) {
    state = state.copyWith(gameStarted: value, isPeerPaused: false);
  }

  Future<void> sendPause(bool paused) async {
    if (state.status == BluetoothStatus.connected && state.connectedDevice != null) {
      final message = jsonEncode({
        'type': 'pause',
        'paused': paused,
      });
      await Nearby().sendBytesPayload(
        state.connectedDevice!.id,
        Uint8List.fromList(message.codeUnits),
      );
    }
  }

  Future<void> sendAbandon() async {
    if (state.status == BluetoothStatus.connected && state.connectedDevice != null) {
      final message = jsonEncode({
        'type': 'abandon',
      });
      await Nearby().sendBytesPayload(
        state.connectedDevice!.id,
        Uint8List.fromList(message.codeUnits),
      );
      state = state.copyWith(gameStarted: false, isPeerPaused: false);
    }
  }

  Future<void> connectToDevice(DiscoveredDevice device) async {
    state = state.copyWith(status: BluetoothStatus.connecting);
    try {
      await Nearby().requestConnection(
        ref.read(gameSettingsProvider).player1Name,
        device.id,
        onConnectionInitiated: _onConnectionInitiated,
        onConnectionResult: _onConnectionResult,
        onDisconnected: _onDisconnected,
      );
    } catch (e) {
      state = state.copyWith(status: BluetoothStatus.failed);
    }
  }

  Future<void> sendKingdomName(String name) async {
    if (state.status == BluetoothStatus.connected && state.connectedDevice != null) {
      final message = jsonEncode({
        'type': 'kingdom_name',
        'name': name,
      });
      await Nearby().sendBytesPayload(
        state.connectedDevice!.id,
        Uint8List.fromList(message.codeUnits),
      );
    }
  }

  Future<void> sendMapSelection(String path, String name) async {
    if (state.status == BluetoothStatus.connected && state.connectedDevice != null) {
      final message = jsonEncode({
        'type': 'map_selection',
        'path': path,
        'name': name,
      });
      await Nearby().sendBytesPayload(
        state.connectedDevice!.id,
        Uint8List.fromList(message.codeUnits),
      );
      
      state = state.copyWith(
        selectedMapPath: path,
        selectedMapName: name,
      );
      ref.read(gameSettingsProvider.notifier).setSelectedMap(path);
    }
  }

  Future<void> sendMove(int x, int y) async {
    if (state.status == BluetoothStatus.connected && state.connectedDevice != null) {
      final message = jsonEncode({
        'type': 'move',
        'x': x,
        'y': y,
      });
      await Nearby().sendBytesPayload(
        state.connectedDevice!.id,
        Uint8List.fromList(message.codeUnits),
      );
    }
  }

  Future<void> sendStartGame() async {
    if (state.status == BluetoothStatus.connected && state.connectedDevice != null) {
      final message = jsonEncode({
        'type': 'start_game',
      });
      await Nearby().sendBytesPayload(
        state.connectedDevice!.id,
        Uint8List.fromList(message.codeUnits),
      );
    }
  }

  Future<void> disconnect() async {
    if (state.connectedDevice != null) {
      await Nearby().disconnectFromEndpoint(state.connectedDevice!.id);
    }
    await Nearby().stopAdvertising();
    await Nearby().stopDiscovery();
    state = BluetoothState();
  }

  void stopAll() {
    Nearby().stopAdvertising();
    Nearby().stopDiscovery();
    Nearby().stopAllEndpoints();
  }
}
