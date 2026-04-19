# War — Project Plan

## Overview

War is a turn-based tactical strategy game built with **Flutter + Flame**, targeting mobile platforms. The game features a positional capture mechanic played on an isometric grid, a Minimax-driven AI opponent, and a story-driven campaign where the player conquers a world map by defeating distinct kingdoms one by one — similar in structure to a continent-wide conquest narrative.

---

## Tech Stack

| Layer | Technology |
|---|---|
| Framework | Flutter |
| Game Engine | Flame |
| State Management | Riverpod |
| AI | Minimax + Heuristic Evaluator (Dart Isolate) |
| Persistence | shared_preferences |
| Maps (Future) | Tiled Tilemaps |

---

## Architecture — Four Strict Layers

```
core/          Constants, enums, utilities (no dependencies)
simulation/    Pure Dart game rules, board logic, AI (no Flutter/Flame)
game/          Flame rendering, audio, input (reads from providers)
ui/            Flutter screens, menus, HUD overlays (reads from providers)
```

These layers only communicate downward. `simulation/` never imports from `game/` or `ui/`. This keeps the core logic fully testable and the Tiled migration contained to `game/` only.

---

## Folder Structure

```
kingdom_siege/
│
├── assets/
│   ├── images/
│   │   ├── units/
│   │   ├── tiles/
│   │   ├── ui/
│   │   ├── kingdoms/
│   │   └── overworld/
│   ├── audio/
│   │   ├── sfx/
│   │   └── music/
│   └── animations/
│
├── lib/
│   ├── main.dart                          # ProviderScope entry point
│   ├── app.dart                           # MaterialApp + routing
│   │
│   ├── core/
│   │   ├── models/
│   │   │   └── level_config.dart          # dynamic battle configurations (board size, thresholds)
│   │   ├── constants/
├── board_constants.dart       # standard grid size, zone boundaries
├── game_constants.dart        # default point thresholds, capture rules
└── ui_constants.dart          # colors, typography, sizing
├── enums/
│   ├── game_phase.dart            # placement, kingdom_attack, game_over
│   ├── cell_state.dart            # empty, player, ai, zone
│   └── turn.dart                  # player, ai

│   │   └── utils/
│   │       ├── board_utils.dart           # adjacency helpers, coordinate utils
│   │       └── capture_utils.dart         # surround detection, capture logic
│   │
│   ├── simulation/
│   │   ├── board.dart                     # core matrix + cell state management
│   │   ├── rules.dart                     # placement rules, win condition checks
│   │   ├── game_simulation.dart           # orchestrates a full game instance
│   │   └── ai/
│   │       ├── minimax.dart               # Minimax algorithm with alpha-beta pruning
│   │       └── evaluator.dart             # board heuristic scoring function
│   │
├── campaign/
│   ├── models/
│   │   ├── kingdom_model.dart         # kingdom name, lore, difficulty, banner
│   │   ├── battle_config.dart         # board layout, AI depth
│   │   └── campaign_state.dart        # conquered territories, unlocked battles

│   │   ├── data/
│   │   │   ├── kingdoms_data.dart         # all kingdom definitions
│   │   │   └── battle_configs.dart        # all battle configurations
│   │   └── campaign_manager.dart          # progression logic, unlock checks
│   │
│   ├── game/
│   │   ├── kingdom_game.dart              # FlameGame root
│   │   ├── board/
│   │   │   ├── board_component.dart       # isometric grid renderer + coord translation
│   │   │   ├── cell_component.dart        # individual tile rendering
│   │   │   └── zone_component.dart        # kingdom zone highlight rendering
│   │   ├── units/
│   │   │   ├── unit_component.dart        # base unit sprite + animation
│   │   │   ├── player_unit.dart
│   │   │   └── ai_unit.dart
│   │   ├── effects/
│   │   │   ├── capture_effect.dart        # burst animation on capture
│   │   │   └── kingdom_attack_effect.dart # barrier-drop visual effect
│   │   └── input/
│   │       └── board_input_handler.dart   # tap → grid coordinate translation
│   │
│   ├── ui/
│   │   ├── screens/
│   │   │   ├── splash_screen.dart
│   │   │   ├── main_menu_screen.dart
│   │   │   ├── overworld_map_screen.dart  # conquest map, territory states
│   │   │   ├── pre_battle_screen.dart     # enemy kingdom intro + lore card
│   │   │   ├── game_screen.dart           # Flame GameWidget + Flutter HUD
│   │   │   ├── post_battle_screen.dart    # victory screen + map conquest anim
│   │   │   └── game_over_screen.dart
│   │   └── widgets/
│   │       ├── hud/
│   │       │   ├── score_panel.dart
│   │       │   ├── turn_indicator.dart
│   │       │   └── kingdom_attack_button.dart
│   │       └── overlays/
│   │           ├── ai_thinking_overlay.dart
│   │           └── capture_toast.dart
│   │
│   ├── providers/
│   │   ├── simulation_provider.dart       # NotifierProvider — GameSimulation instance
│   │   ├── turn_provider.dart             # AsyncNotifierProvider — player/AI turn + isolate
│   │   ├── score_provider.dart            # NotifierProvider — points, Kingdom Attack unlock
│   │   └── campaign_provider.dart         # NotifierProvider — overworld progress + unlocks
│   │
│   └── persistence/
│       ├── save_manager.dart              # read/write serialized campaign state
│       └── local_storage.dart            # shared_preferences wrapper
│
└── test/
    ├── simulation/
    │   ├── rules_test.dart
    │   └── capture_utils_test.dart
    ├── ai/
    │   └── minimax_test.dart
    └── campaign/
        └── campaign_manager_test.dart
```

---

## Core Game Rules (Reference)

- The board dimension is dynamic, based on the loaded **Tiled TMX map**.
- **Playable Battlefield:** The last 3 rows and 3 columns from **each side** (top, bottom, left, right) are non-playable boundaries. For a 25x25 map, this results in a 19x19 active grid.
- Players alternate turns deploying one unit per turn onto any valid empty cell within the playable area.
- **Go-Style Captures:** A group of units is captured when completely sealed off by enemy pieces or the **playable battlefield boundaries**. 
- **Scorched Earth:** Captured units are removed and turn the grid into a permanently unplayable burned zone (`CellState.capturedGrid`).
- Each unit captured grants the capturing player 10 points. 
- **Palace Anchor:** Your own Palace acts as a massive wall of your own units. Touching your own Palace makes your units immune to capture.
- Once a player reaches the point threshold, they unlock the **Kingdom Attack**.
- **Win Condition:** The game is won when a player completely blockades the opponent's Palace with a continuous chain that anchors to both the left and right (or top/bottom) **playable battlefield boundaries** after unlocking Kingdom Attack.

---

## Development Phases

---

### Phase 1 — Project Foundation
**Goal:** Skeleton is running. Nothing breaks. Structure is locked.

- [x] Initialize Flutter project with Flame and Riverpod dependencies
- [x] Set up folder structure exactly as defined above
- [x] Configure `main.dart` with `ProviderScope`
- [x] Define all enums (`GamePhase`, `CellState`, `Turn`)
- [x] Define all constants in `core/constants/`
- [x] Set up basic routing between placeholder screens
- [x] Confirm app builds and runs on target device/emulator

**Milestone:** App launches, navigates between empty placeholder screens.

---

### Phase 2 — Simulation Layer (Pure Dart)
**Goal:** The entire game brain works correctly in isolation, with no UI.

- [x] Implement `board.dart` — matrix initialization with dynamic sizing and playable area support
- [x] Implement `capture_utils.dart` — surround detection on all four cardinal sides
- [x] Implement `rules.dart` — valid placement checks, capture triggering, score update, Kingdom Attack unlock, topological win condition evaluation
- [x] Implement `game_simulation.dart` — orchestrates a full game flow, exposes clean API for providers
- [x] Write unit tests for all capture edge cases
- [x] Write unit tests for Kingdom Attack unlock condition
- [x] Write unit tests for win condition (Palace surrounded)

**Milestone:** Full game logic runs and is verified through tests alone, no visuals needed.

---

### Phase 3 — Basic Flame Board (Visuals)
**Goal:** The game is visually playable. No art assets required yet.

- [x] Set up `kingdom_game.dart` as the root `FlameGame` with `ScaleDetector` for pinch-to-zoom and panning.
- [x] Implement `board_component.dart` — rendering map-driven grid representation with 3-tile boundaries.
- [x] Implement `cell_component.dart` — colored rectangles for empty, player, AI, zone, and captured cells.
- [x] Connect Flame components to Riverpod providers (read-only, no game logic in Flame)
- [x] Embed `GameWidget` inside `game_screen.dart` with HUD

**Milestone:** A full game can be played start to finish on a device using shapes and colors as a hot-seat prototype.

---

### Phase 4 — AI Layer
**Goal:** A competent AI opponent that plays strategically.

- [x] Implement `evaluator.dart` — heuristic board scoring (positional control, threat detection, dynamic palace proximity)
- [x] Implement `minimax.dart` — Minimax with alpha-beta pruning, configurable depth
- [x] Wire AI to run inside a Dart `Isolate` via `turn_provider`
- [x] Expose AI thinking state through `AsyncNotifierProvider` so UI can react
- [x] Tune evaluator weights until AI feels challenging but fair

**Milestone:** AI plays a complete game autonomously against itself with reasonable strategic decisions.

---

### Phase 5 — Flutter HUD & Overlays
**Goal:** All in-game UI is functional and wired to state.

- [x] Build `score_panel.dart` — live score display for both sides with Kingdom Attack indicator
- [x] Build `turn_indicator.dart` — clearly shows whose turn it is
- [x] Build `ai_thinking_overlay.dart` — blocks input and shows indicator while AI isolate runs
- [x] Build `capture_toast.dart` — brief notification on capture event
- [x] Build `game_over_screen.dart` — victory/defeat overlay with return option

**Milestone:** Playing the game feels complete with all information visible and readable.

---

### Phase 6 — Campaign Layer
**Goal:** The story structure exists. Kingdoms have identity. Progression works.

- [ ] Define all kingdoms in `kingdoms_data.dart` — name, lore blurb, difficulty rating, visual identity
- [ ] Define all battle configurations in `battle_configs.dart` — board size, sigil placement, AI depth per kingdom
- [ ] Implement `campaign_manager.dart` — tracks which kingdoms are defeated, which battles are unlocked
- [ ] Build `overworld_map_screen.dart` — visual conquest map with locked/conquered/available territory states
- [ ] Build `pre_battle_screen.dart` — enemy kingdom introduction, lore card, confirm battle
- [ ] Build `post_battle_screen.dart` — victory acknowledgment, conquest animation on map
- [ ] Wire `campaign_provider.dart` to track and expose full campaign state

---

### Phase 9 — Tiled Integration
**Goal:** Use Tiled tilemaps for visual richness.

- [x] Design battle maps in Tiled editor with `IsKingdom` and `isObstacle` properties
- [x] Update `board_component.dart` to load `TiledComponent` and dynamically detect playable area (Map - 3 boundary)
- [x] Parse Kingdom Zone boundaries and palace positions from Tiled properties at runtime
- [x] Add `GridLinesComponent` to visually highlight the dynamic 3-tile boundary region
- [ ] Replace placeholder tile sprites with final art assets

**Milestone:** Game looks visually rich with Tiled maps. All game logic and campaign logic unchanged.

---

## Key Architectural Decisions

| Decision | Rationale |
|---|---|
| Riverpod over BLoC | Less ceremony, cleaner async handling for AI isolate, pairs naturally with Flame's game loop |
| Simulation as pure Dart | Fully testable without Flutter/Flame overhead, portable, and future multiplayer ready |
| Coordinate translation in `board_component.dart` | Tiled migration becomes a single-file change |
| Constants in `core/constants/` | Zone boundaries and sigil positions are defined once, used everywhere, easy to swap |
| AI in Dart Isolate | Minimax tree search is CPU-heavy; isolate keeps the UI thread free and responsive |
| `campaign/` as its own layer | Story progression is independent of core game rules — each can evolve separately |

---

## Future Considerations

- **Local Offline Multiplayer** — matrix-based simulation is already structured for a second human player; replace `turn_provider` AI logic with a second input handler
- **Tiled Maps** — migration is isolated to `game/board/` only
- **Additional Campaign Content** — new kingdoms are data additions to `campaign/data/`, no architectural changes needed
- **Difficulty Settings** — already supported by configurable Minimax depth in `battle_configs.dart`