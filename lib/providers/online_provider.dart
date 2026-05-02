import 'package:flutter/foundation.dart';
import 'dart:async';
import 'dart:math' as math;
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'simulation_provider.dart';
import 'game_settings_provider.dart';
import '../core/enums/game_mode.dart';

enum OnlineStatus { idle, connecting, connected, failed, disconnected }

class OnlineState {
  final OnlineStatus status;
  final String? roomCode;
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

  OnlineState({
    this.status = OnlineStatus.idle,
    this.roomCode,
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

  OnlineState copyWith({
    OnlineStatus? status,
    String? roomCode,
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
    return OnlineState(
      status: status ?? this.status,
      roomCode: roomCode ?? this.roomCode,
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

final onlineProvider = NotifierProvider<OnlineNotifier, OnlineState>(() {
  return OnlineNotifier();
});

class OnlineNotifier extends Notifier<OnlineState> {
  RealtimeChannel? _channel;

  @override
  OnlineState build() {
    return OnlineState();
  }

  String _generateRoomCode() {
    const chars = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';
    final rnd = math.Random();
    return String.fromCharCodes(Iterable.generate(
      5, (_) => chars.codeUnitAt(rnd.nextInt(chars.length)),
    ));
  }

  Future<void> createRoom() async {
    final code = _generateRoomCode();
    state = state.copyWith(
      status: OnlineStatus.connecting,
      roomCode: code,
      isHost: true,
    );
    await _joinChannel(code);
  }

  Future<void> joinRoom(String code) async {
    state = state.copyWith(
      status: OnlineStatus.connecting,
      roomCode: code.toUpperCase(),
      isHost: false,
    );
    await _joinChannel(code.toUpperCase());
  }

  Future<void> _joinChannel(String code) async {
    try {
      debugPrint('🌐 Attempting to join channel: room_$code');
      
      // Ensure we are signed in anonymously for Realtime to work best
      if (Supabase.instance.client.auth.currentSession == null) {
        debugPrint('🌐 No session found, signing in anonymously...');
        await Supabase.instance.client.auth.signInAnonymously();
        debugPrint('🌐 Anonymous sign-in successful: ${Supabase.instance.client.auth.currentUser?.id}');
      } else {
        debugPrint('🌐 Using existing session: ${Supabase.instance.client.auth.currentUser?.id}');
      }

      final channelName = 'room_$code';
      _channel = Supabase.instance.client.channel(channelName);

      debugPrint('🌐 Subscribing to channel...');
      _channel!.onBroadcast(
        event: 'game_event',
        callback: (payload) {
          debugPrint('🌐 Received broadcast: $payload');
          _handleMessage(payload);
        },
      ).subscribe((status, [error]) {
        debugPrint('🌐 Subscription status: $status');
        if (error != null) {
          debugPrint('🌐 Subscription error details: $error');
        }

        if (status == RealtimeSubscribeStatus.subscribed) {
          debugPrint('✅ Successfully joined room: $code');
          state = state.copyWith(status: OnlineStatus.connected);
          sendKingdomName(ref.read(gameSettingsProvider).player1Name);
        } else if (status == RealtimeSubscribeStatus.channelError) {
          debugPrint('❌ Channel error joining room: $code');
          state = state.copyWith(status: OnlineStatus.failed);
        } else if (status == RealtimeSubscribeStatus.timedOut) {
          debugPrint('❌ Timeout joining room: $code');
          state = state.copyWith(status: OnlineStatus.failed);
        }
      });
    } catch (e, stack) {
      debugPrint('❌ General exception in _joinChannel: $e');
      debugPrint('Stack: $stack');
      state = state.copyWith(status: OnlineStatus.failed);
    }
  }

  void _handleMessage(Map<String, dynamic> rawPayload) {
    // Supabase Realtime 'broadcast' event structure:
    // The data we sent is usually inside 'payload'
    final data = rawPayload['payload'] as Map<String, dynamic>?;
    
    if (data == null) {
      debugPrint('🌐 Received broadcast but payload was null: $rawPayload');
      return;
    }

    final type = data['type'];
    debugPrint('🌐 Parsing Game Event: $type');
    
    switch (type) {
      case 'move':
        final x = data['x'] as int;
        final y = data['y'] as int;
        ref.read(simulationProvider.notifier).placeUnitFromPeer(x, y);
        break;
      case 'start_game':
        debugPrint('🌐 ACTION: Start Game received');
        ref.read(gameSettingsProvider.notifier).setMode(GameMode.multiplayer);
        ref.read(gameSettingsProvider.notifier).setSelectedMap(state.selectedMapPath ?? '25x25_map.tmx');
        state = state.copyWith(gameStarted: true, isPeerPaused: false);
        break;
      case 'kingdom_name':
        debugPrint('🌐 ACTION: Peer Name received: ${data['name']}');
        state = state.copyWith(peerKingdomName: data['name']);
        ref.read(gameSettingsProvider.notifier).setPlayerNames(
          ref.read(gameSettingsProvider).player1Name,
          data['name'],
        );
        if (state.isHost) {
          sendKingdomName(ref.read(gameSettingsProvider).player1Name);
          sendSettingsUpdate();
        }
        break;
      case 'map_selection':
        debugPrint('🌐 ACTION: Map Selection received: ${data['name']}');
        state = state.copyWith(
          selectedMapPath: data['path'],
          selectedMapName: data['name'],
        );
        ref.read(gameSettingsProvider.notifier).setSelectedMap(data['path']);
        break;
      case 'sync_settings':
        debugPrint('🌐 ACTION: Settings Sync received');
        state = state.copyWith(
          player1Symbol: data['p1Symbol'],
          player2Symbol: data['p2Symbol'],
          player1Color: data['p1Color'],
          player2Color: data['p2Color'],
          kingdomAttackThreshold: data['threshold'],
        );
        ref.read(gameSettingsProvider.notifier).setPlayerSymbols(
          data['p2Symbol'],
          data['p1Symbol'],
        );
        ref.read(gameSettingsProvider.notifier).setPlayerColors(
          data['p2Color'],
          data['p1Color'],
        );
        ref.read(gameSettingsProvider.notifier).setKingdomAttackThreshold(data['threshold']);
        break;
      case 'pause':
        state = state.copyWith(isPeerPaused: data['paused']);
        break;
      case 'abandon':
        state = state.copyWith(gameStarted: false, isPeerPaused: false);
        break;
    }
  }

  Future<void> _sendMessage(Map<String, dynamic> message) async {
    if (_channel != null && state.status == OnlineStatus.connected) {
      debugPrint('🌐 Broadcasting Game Event: ${message['type']}');
      // We MUST explicitly put our data inside a 'payload' map 
      // to avoid Supabase merging our 'type' with its internal 'type: broadcast'
      await _channel!.sendBroadcastMessage(
        event: 'game_event',
        payload: { 'payload': message },
      );
    }
  }

  void updateSettings({String? p1Symbol, String? p2Symbol, int? p1Color, int? p2Color, int? threshold}) {
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
    await _sendMessage({
      'type': 'sync_settings',
      'p1Symbol': state.player1Symbol,
      'p2Symbol': state.player2Symbol,
      'p1Color': state.player1Color,
      'p2Color': state.player2Color,
      'threshold': state.kingdomAttackThreshold,
    });
  }

  void setGameStarted(bool value) {
    state = state.copyWith(gameStarted: value, isPeerPaused: false);
  }

  Future<void> sendPause(bool paused) async {
    await _sendMessage({
      'type': 'pause',
      'paused': paused,
    });
  }

  Future<void> sendAbandon() async {
    await _sendMessage({
      'type': 'abandon',
    });
    state = state.copyWith(gameStarted: false, isPeerPaused: false);
  }

  Future<void> sendKingdomName(String name) async {
    await _sendMessage({
      'type': 'kingdom_name',
      'name': name,
    });
  }

  Future<void> sendMapSelection(String path, String name) async {
    await _sendMessage({
      'type': 'map_selection',
      'path': path,
      'name': name,
    });
    
    state = state.copyWith(
      selectedMapPath: path,
      selectedMapName: name,
    );
    ref.read(gameSettingsProvider.notifier).setSelectedMap(path);
  }

  Future<void> sendMove(int x, int y) async {
    await _sendMessage({
      'type': 'move',
      'x': x,
      'y': y,
    });
  }

  Future<void> sendStartGame() async {
    await _sendMessage({
      'type': 'start_game',
    });
  }

  Future<void> disconnect() async {
    if (_channel != null) {
      await Supabase.instance.client.removeChannel(_channel!);
      _channel = null;
    }
    state = OnlineState();
  }
}
