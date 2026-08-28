import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:nearby_connections/nearby_connections.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:permission_handler/permission_handler.dart';
import '../core/constants/app_assets.dart';
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
    this.player1Symbol = AppAssets.fire,
    this.player2Symbol = AppAssets.eagle,
    this.player1Color = 0xFF2196F3, // Colors.blue
    this.player2Color = 0xFFF44336, // Colors.red
    this.kingdomAttackThreshold = 100,
  });

  BluetoothState copyWith({
    BluetoothStatus? status,
    List<DiscoveredDevice>? discoveredDevices,
    DiscoveredDevice? connectedDevice,
    bool clearConnectedDevice = false,
    bool? isHost,
    bool? gameStarted,
    bool? isPeerPaused,
    String? peerKingdomName,
    bool clearPeerKingdomName = false,
    String? selectedMapPath,
    bool clearSelectedMapPath = false,
    String? selectedMapName,
    bool clearSelectedMapName = false,
    String? player1Symbol,
    String? player2Symbol,
    int? player1Color,
    int? player2Color,
    int? kingdomAttackThreshold,
  }) {
    return BluetoothState(
      status: status ?? this.status,
      discoveredDevices: discoveredDevices ?? this.discoveredDevices,
      connectedDevice: clearConnectedDevice ? null : (connectedDevice ?? this.connectedDevice),
      isHost: isHost ?? this.isHost,
      gameStarted: gameStarted ?? this.gameStarted,
      isPeerPaused: isPeerPaused ?? this.isPeerPaused,
      peerKingdomName: clearPeerKingdomName ? null : (peerKingdomName ?? this.peerKingdomName),
      selectedMapPath: clearSelectedMapPath ? null : (selectedMapPath ?? this.selectedMapPath),
      selectedMapName: clearSelectedMapName ? null : (selectedMapName ?? this.selectedMapName),
      player1Symbol: player1Symbol ?? this.player1Symbol,
      player2Symbol: player2Symbol ?? this.player2Symbol,
      player1Color: player1Color ?? this.player1Color,
      player2Color: player2Color ?? this.player2Color,
      kingdomAttackThreshold: kingdomAttackThreshold ?? this.kingdomAttackThreshold,
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
//  Local Socket P2P Transport (for Windows, Desktop & Local LAN / Hotspot)
// ─────────────────────────────────────────────────────────────────────────────
class LocalP2PTransport {
  static const int discoveryPort = 45455;
  static const String beaconPrefix = "WAR_BEACON";

  RawDatagramSocket? _discoverySocket;
  Timer? _beaconTimer;
  ServerSocket? _serverSocket;
  Socket? _activeSocket;
  StreamSubscription? _socketSub;

  final void Function(String id, String name) onDeviceFound;
  final void Function(String id) onDeviceLost;
  final void Function(dynamic message) onMessageReceived;
  final void Function(String id) onConnected;
  final void Function(String id) onDisconnected;
  final void Function(String error) onError;

  LocalP2PTransport({
    required this.onDeviceFound,
    required this.onDeviceLost,
    required this.onMessageReceived,
    required this.onConnected,
    required this.onDisconnected,
    required this.onError,
  });

  Future<void> startHosting(String hostName) async {
    await stopAll();
    try {
      // 1. Start TCP Server on an available port
      _serverSocket = await ServerSocket.bind(InternetAddress.anyIPv4, 0);
      final tcpPort = _serverSocket!.port;

      _serverSocket!.listen(
        (clientSocket) {
          if (_activeSocket != null) {
            clientSocket.destroy();
            return;
          }
          _setupSocket(clientSocket, isHost: true);
        },
        onError: (err) {
          onError(err.toString());
        },
      );

      // 2. Start UDP Beacon broadcasting
      _discoverySocket = await RawDatagramSocket.bind(InternetAddress.anyIPv4, 0);
      _discoverySocket!.broadcastEnabled = true;

      final beaconMsg = "$beaconPrefix|${hostName.replaceAll('|', '_')}|$tcpPort";
      final data = utf8.encode(beaconMsg);

      _beaconTimer = Timer.periodic(const Duration(milliseconds: 900), (_) {
        try {
          _discoverySocket?.send(data, InternetAddress("255.255.255.255"), discoveryPort);
          _discoverySocket?.send(data, InternetAddress.loopbackIPv4, discoveryPort);
        } catch (_) {}
      });
    } catch (e) {
      onError("Failed to start local host: $e");
    }
  }

  Future<void> startScanning() async {
    await stopAll();
    try {
      _discoverySocket = await RawDatagramSocket.bind(
        InternetAddress.anyIPv4,
        discoveryPort,
        reuseAddress: true,
        reusePort: true,
      );

      _discoverySocket!.listen((RawSocketEvent event) {
        if (event == RawSocketEvent.read) {
          final datagram = _discoverySocket?.receive();
          if (datagram != null) {
            try {
              final text = utf8.decode(datagram.data);
              if (text.startsWith("$beaconPrefix|")) {
                final parts = text.split('|');
                if (parts.length >= 3) {
                  final name = parts[1];
                  final port = int.tryParse(parts[2]);
                  if (port != null) {
                    final hostIp = datagram.address.address;
                    final endpointId = "$hostIp:$port";
                    onDeviceFound(endpointId, name);
                  }
                }
              }
            } catch (_) {}
          }
        }
      });
    } catch (e) {
      onError("Failed to start local scan: $e");
    }
  }

  Future<void> connectToDevice(String endpointId) async {
    await stopDiscovery();
    try {
      final parts = endpointId.split(':');
      final ip = parts[0];
      final port = int.parse(parts[1]);

      final socket = await Socket.connect(ip, port, timeout: const Duration(seconds: 6));
      _setupSocket(socket, isHost: false);
    } catch (e) {
      onError("Failed to connect to $endpointId: $e");
    }
  }

  void _setupSocket(Socket socket, {required bool isHost}) {
    _activeSocket = socket;
    final endpointId = "${socket.remoteAddress.address}:${socket.remotePort}";
    onConnected(endpointId);

    _socketSub = socket
        .cast<List<int>>()
        .transform(utf8.decoder)
        .transform(const LineSplitter())
        .listen(
      (line) {
        if (line.trim().isEmpty) return;
        try {
          final json = jsonDecode(line);
          onMessageReceived(json);
        } catch (e) {
          debugPrint("Failed to decode local socket message: $e");
        }
      },
      onError: (err) {
        onDisconnected(endpointId);
      },
      onDone: () {
        onDisconnected(endpointId);
      },
      cancelOnError: true,
    );
  }

  void sendMessage(Map<String, dynamic> message) {
    if (_activeSocket != null) {
      try {
        final line = "${jsonEncode(message)}\n";
        _activeSocket!.write(line);
      } catch (e) {
        debugPrint("Error sending message over local socket: $e");
      }
    }
  }

  Future<void> stopDiscovery() async {
    _beaconTimer?.cancel();
    _beaconTimer = null;
    try {
      _discoverySocket?.close();
    } catch (_) {}
    _discoverySocket = null;
  }

  Future<void> stopAll() async {
    await stopDiscovery();
    await _socketSub?.cancel();
    _socketSub = null;
    try {
      _activeSocket?.destroy();
    } catch (_) {}
    _activeSocket = null;
    try {
      await _serverSocket?.close();
    } catch (_) {}
    _serverSocket = null;
  }
}

// ─────────────────────────────────────────────────────────────────────────────
//  Bluetooth Provider / Notifier
// ─────────────────────────────────────────────────────────────────────────────
final bluetoothProvider = NotifierProvider<BluetoothNotifier, BluetoothState>(() {
  return BluetoothNotifier();
});

class BluetoothNotifier extends Notifier<BluetoothState> {
  final Strategy strategy = Strategy.P2P_STAR;
  final String serviceId = "com.example.war.p2p";

  late final LocalP2PTransport _localP2P;

  bool get _isAndroid => !kIsWeb && Platform.isAndroid;

  @override
  BluetoothState build() {
    _localP2P = LocalP2PTransport(
      onDeviceFound: (id, name) {
        final devices = List<DiscoveredDevice>.from(state.discoveredDevices);
        if (!devices.any((d) => d.id == id)) {
          devices.add(DiscoveredDevice(id: id, name: name));
          state = state.copyWith(discoveredDevices: devices);
        }
      },
      onDeviceLost: (id) {
        final devices = List<DiscoveredDevice>.from(state.discoveredDevices);
        devices.removeWhere((d) => d.id == id);
        state = state.copyWith(discoveredDevices: devices);
      },
      onMessageReceived: (message) {
        _handleMessage(message);
      },
      onConnected: (id) {
        state = state.copyWith(
          status: BluetoothStatus.connected,
          connectedDevice: DiscoveredDevice(id: id, name: "Peer"),
        );
        sendKingdomName(ref.read(gameSettingsProvider).player1Name);
      },
      onDisconnected: (id) {
        if (state.connectedDevice?.id == id) {
          state = state.copyWith(
            status: BluetoothStatus.idle,
            clearConnectedDevice: true,
            clearPeerKingdomName: true,
          );
        }
      },
      onError: (error) {
        debugPrint("Local P2P Error: $error");
        state = state.copyWith(status: BluetoothStatus.failed);
      },
    );
    return BluetoothState();
  }

  Future<bool> requestPermissions() async {
    if (!_isAndroid) {
      return true; // No special mobile permissions needed on Windows/Desktop
    }

    try {
      Map<Permission, PermissionStatus> statuses = await [
        Permission.bluetooth,
        Permission.bluetoothScan,
        Permission.bluetoothConnect,
        Permission.bluetoothAdvertise,
        Permission.location,
        Permission.nearbyWifiDevices,
      ].request();

      return statuses.values.every((status) => status.isGranted);
    } catch (_) {
      return false;
    }
  }

  Future<void> startScanning() async {
    if (await requestPermissions()) {
      state = state.copyWith(
        status: BluetoothStatus.scanning,
        isHost: false,
        discoveredDevices: [],
      );

      if (_isAndroid) {
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
        await _localP2P.startScanning();
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

      final hostName = ref.read(gameSettingsProvider).player1Name;

      if (_isAndroid) {
        try {
          await Nearby().stopAdvertising();
          await Nearby().startAdvertising(
            hostName,
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
        await _localP2P.startHosting(hostName);
      }
    } else {
      state = state.copyWith(status: BluetoothStatus.failed);
    }
  }

  void _onConnectionInitiated(String id, ConnectionInfo info) {
    if (!_isAndroid) return;
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
        clearConnectedDevice: true,
        clearPeerKingdomName: true,
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

  Future<void> _sendPayload(Map<String, dynamic> message) async {
    if (state.status == BluetoothStatus.connected && state.connectedDevice != null) {
      if (_isAndroid) {
        try {
          final encoded = jsonEncode(message);
          await Nearby().sendBytesPayload(
            state.connectedDevice!.id,
            Uint8List.fromList(encoded.codeUnits),
          );
        } catch (e) {
          debugPrint("Nearby send payload error: $e");
        }
      } else {
        _localP2P.sendMessage(message);
      }
    }
  }

  Future<void> sendSettingsUpdate() async {
    if (state.isHost) {
      await _sendPayload({
        'type': 'sync_settings',
        'p1Symbol': state.player1Symbol,
        'p2Symbol': state.player2Symbol,
        'p1Color': state.player1Color,
        'p2Color': state.player2Color,
        'threshold': state.kingdomAttackThreshold,
      });
    }
  }

  void setGameStarted(bool value) {
    state = state.copyWith(gameStarted: value, isPeerPaused: false);
  }

  Future<void> sendPause(bool paused) async {
    await _sendPayload({
      'type': 'pause',
      'paused': paused,
    });
  }

  Future<void> sendAbandon() async {
    await _sendPayload({
      'type': 'abandon',
    });
    state = state.copyWith(gameStarted: false, isPeerPaused: false);
  }

  Future<void> connectToDevice(DiscoveredDevice device) async {
    state = state.copyWith(status: BluetoothStatus.connecting);
    if (_isAndroid) {
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
    } else {
      await _localP2P.connectToDevice(device.id);
    }
  }

  Future<void> sendKingdomName(String name) async {
    await _sendPayload({
      'type': 'kingdom_name',
      'name': name,
    });
  }

  Future<void> sendMapSelection(String path, String name) async {
    state = state.copyWith(
      selectedMapPath: path,
      selectedMapName: name,
    );
    ref.read(gameSettingsProvider.notifier).setSelectedMap(path);

    await _sendPayload({
      'type': 'map_selection',
      'path': path,
      'name': name,
    });
  }

  Future<void> sendMove(int x, int y) async {
    await _sendPayload({
      'type': 'move',
      'x': x,
      'y': y,
    });
  }

  Future<void> sendStartGame() async {
    await _sendPayload({
      'type': 'start_game',
    });
  }

  Future<void> disconnect() async {
    if (_isAndroid) {
      try {
        if (state.connectedDevice != null) {
          await Nearby().disconnectFromEndpoint(state.connectedDevice!.id);
        }
        await Nearby().stopAdvertising();
        await Nearby().stopDiscovery();
      } catch (_) {}
    } else {
      await _localP2P.stopAll();
    }
    state = BluetoothState();
  }

  void stopAll() {
    if (_isAndroid) {
      try {
        Nearby().stopAdvertising();
        Nearby().stopDiscovery();
        Nearby().stopAllEndpoints();
      } catch (_) {}
    } else {
      _localP2P.stopAll();
    }
  }
}
