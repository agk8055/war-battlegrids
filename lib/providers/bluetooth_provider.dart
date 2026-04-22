import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';
import 'package:nearby_connections/nearby_connections.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:permission_handler/permission_handler.dart';
import 'simulation_provider.dart';

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

  BluetoothState({
    this.status = BluetoothStatus.idle,
    this.discoveredDevices = const [],
    this.connectedDevice,
    this.isHost = false,
    this.gameStarted = false,
  });

  BluetoothState copyWith({
    BluetoothStatus? status,
    List<DiscoveredDevice>? discoveredDevices,
    DiscoveredDevice? connectedDevice,
    bool? isHost,
    bool? gameStarted,
  }) {
    return BluetoothState(
      status: status ?? this.status,
      discoveredDevices: discoveredDevices ?? this.discoveredDevices,
      connectedDevice: connectedDevice ?? this.connectedDevice,
      isHost: isHost ?? this.isHost,
      gameStarted: gameStarted ?? this.gameStarted,
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
          "Player",
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
          "Host",
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
    // Automatically accept connection for now to simplify
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
      ref.read(simulationProvider.notifier).placeUnit(x, y);
    } else if (message['type'] == 'start_game') {
      state = state.copyWith(gameStarted: true);
    }
  }

  Future<void> connectToDevice(DiscoveredDevice device) async {
    state = state.copyWith(status: BluetoothStatus.connecting);
    try {
      await Nearby().requestConnection(
        "Player",
        device.id,
        onConnectionInitiated: _onConnectionInitiated,
        onConnectionResult: _onConnectionResult,
        onDisconnected: _onDisconnected,
      );
    } catch (e) {
      state = state.copyWith(status: BluetoothStatus.failed);
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
