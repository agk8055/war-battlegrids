# Supabase Online Multiplayer Implementation

This document details the architecture and logic used to implement the Online Multiplayer rooms in the WAR project using Supabase.

## 🏗️ Architecture Overview

The system uses a **Pure Realtime Broadcast** approach. This means the game does not store room data in a database table. Instead, it relies on Supabase Realtime Channels to facilitate low-latency, peer-to-peer communication.

### Key Components:
- **`OnlineProvider` (`lib/providers/online_provider.dart`)**: The core engine. It manages the Supabase channel lifecycle, Presence tracking, and message routing.
- **`OnlineLobbyScreen` (`lib/ui/screens/online_lobby_screen.dart`)**: The UI for room creation, code entry, and pre-game settings sync.
- **Supabase Realtime Broadcast**: Used for sending game moves, starting the game, and syncing settings.
- **Supabase Realtime Presence**: Used to monitor who is in the room and detect disconnections.

---

## 📡 Communication Protocol

To ensure reliability and avoid field name collisions with Supabase internal properties, we use a **Double-Wrapped Payload** system.

### Sending a Message:
All game data is nested inside a `payload` map. This prevents Supabase from merging our custom `type` field with its internal `type: broadcast` metadata.
```dart
await channel.sendBroadcastMessage(
  event: 'game_event',
  payload: { 
    'payload': {
      'type': 'start_game',
      'map_path': 'northern_forest.tmx',
    }
  },
);
```

### Receiving a Message:
The client extracts the inner `payload` map before parsing the game event.
```dart
void _handleMessage(Map<String, dynamic> rawPayload) {
  final data = rawPayload['payload'] as Map<String, dynamic>?;
  final type = data['type']; // 'move', 'start_game', 'sync_settings', etc.
}
```

---

## 👥 Presence & Connection Logic

The system uses `onPresenceSync` to track the number of active players in a channel.

1.  **Global Lobby Tracking**:
    - The `rooms_lobby` channel maintains a real-time presence count of all active hosted rooms.
    - When a Host creates a room, they track their presence in `rooms_lobby`.
    - When the Host leaves or disconnects, presence is untracked.
    - If the number of active rooms reaches **70**, the server room creation limit is triggered:
      - Room creation is blocked (`OnlineNotifier.maxOnlineRooms = 70`).
      - In the UI, the "HOST ROOM" button is dimmed and disabled with a clear "ROOM CREATION LIMIT REACHED" indicator.
2.  **Handshake**: When a user joins a game room, they call `channel.track()`.
3.  **Room Persistence**:
    - **Host**: If a client leaves, the Host remains in the room with the same code. `wasPeerConnected` is reset, allowing a new client to join the existing session.
    - **Client**: If the Host leaves, the room is considered "abandoned," and the client is notified via a dialog.
4.  **Disconnection Detection**: If the presence count drops below 2 while a game is in progress, the remaining player is notified that the battle has been disrupted.

---

## 🔄 Synchronization Flow

1.  **Room Creation**: Host generates a 5-char code and joins `room_[CODE]`.
2.  **Joining**: Client enters the code and joins the same channel.
3.  **Identity Exchange**:
    - Client sends their Kingdom Name immediately upon subscribing.
    - Host receives Client name, then re-broadcasts their own name + current room settings (sigils, colors, maps).
4.  **Game Start**: Host sends `start_game`. Client receives it, updates local `GameSettings`, and navigates to the game screen.
5.  **Gameplay**: Moves are broadcasted as coordinates `(x, y)`. The `SimulationProvider` processes these locally to keep the UI in sync.

---

## 🛠️ Dashboard Requirements

For this system to function, the following must be enabled in the Supabase Dashboard:
1.  **Authentication**: Enable **Anonymous Sign-ins** (Providers -> Email/Anonymous).
2.  **Realtime**: Enable **Realtime** for the project (Project Settings -> Realtime).
3.  **Broadcast**: Ensure Broadcast is enabled (standard default).
4.  **Presence**: Ensure Presence is enabled (standard default).

---

## 🛡️ Security Notes
- **No Database RLS needed**: Since no tables are used, RLS is not applicable.
- **Anonymous Auth**: Used to provide each player with a unique `user_id` for Presence tracking without requiring a login/password.
