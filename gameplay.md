# ⚔️ WAR: BATTLEGRIDS — Gameplay Guide & Rulebook

Welcome to **WAR: BATTLEGRIDS**, a grid-based turn-based tactical strategy game. Command your kingdom, deploy your forces on the grid, capture enemy formations, and execute strategic blockades to conquer enemy territories.

---

## 📋 Table of Contents
1. [Game Overview](#-game-overview)
2. [Board & Grid Elements](#-board--grid-elements)
3. [Turn Flow & Placement Rules](#-turn-flow--placement-rules)
4. [Surround & Capture Mechanics](#-surround--capture-mechanics)
5. [Kingdom Attack Phase](#-kingdom-attack-phase)
6. [Win Conditions & Blockades](#-win-conditions--blockades)
7. [Game Modes](#-game-modes)
8. [Campaign Realms](#-campaign-realms)
9. [Tactical Tips & Strategies](#-tactical-tips--strategies)

---

## 🎮 Game Overview

In **WAR: BATTLEGRIDS**, two factions face off on a grid-based battlefield. Each player's kingdom sits on opposing sides of the grid (Player at the bottom, AI / Opponent at the top).

- **Genre**: Turn-Based Tactical Grid Strategy
- **Grid Sizes**: 15×15 (Standard Skirmishes) up to 25×25 (Grand Battles)
- **Primary Objective**: Encircle and blockade the opponent's Kingdom Zone with an unbroken connected chain of forces.
- **Secondary Objective**: Surround enemy units to capture them, score points, and unlock the **Kingdom Attack** phase.

---

## 🗺️ Board & Grid Elements

The battlefield consists of an interactive grid with distinct terrain states:

| Tile / Element | Description |
| :--- | :--- |
| **Empty Tile** | Open battlefield tile where units can be placed. |
| **Player Unit** | Deployed unit belonging to Player 1 (Blue/Gold faction). |
| **Enemy / AI Unit** | Deployed unit belonging to Player 2 / AI (Red/Dark faction). |
| **Kingdom Zone (Palace)** | Sacred base territory of a faction. Acts as a wall and sanctuary for that faction's forces. |
| **Captured Grid** | Permanently burnt/locked tile created when enemy units or regions are surrounded and captured. Cannot be built on by either player. |
| **Obstacle** | Natural terrain barriers (trees, mountains, rivers) that block unit placement. |

```
┌─────────────────────────────────────────┐
│     AI KINGDOM ZONE (Palace Base)       │  <-- Opponent Base (Top)
├─────────────────────────────────────────┤
│                                         │
│          PLAYABLE BATTLEFIELD           │  <-- Interactive 15x15 or 25x25 Grid
│         [Empty / Units / Captures]      │
│                                         │
├─────────────────────────────────────────┤
│   PLAYER KINGDOM ZONE (Palace Base)     │  <-- Player Base (Bottom)
└─────────────────────────────────────────┘
```

---

## 🔄 Turn Flow & Placement Rules

### 1. Alternating Turns
Players take turns placing **1 unit per turn** on any valid empty grid cell.

### 2. Valid Placement Rules
- **Empty Cells Only**: Units can only be placed on unoccupied, non-obstacle tiles (`Empty`).
- **Kingdom Protection**: You **cannot** place units directly inside the opponent's Kingdom Zone until you unlock the **Kingdom Attack** phase.
- **Own Zone Restriction**: You cannot deploy units into your own Kingdom Zone (it already counts intrinsically as your territory).
- **Early Win Prevention**: Prior to unlocking Kingdom Attack, players are prohibited from placing a piece that would prematurely complete a winning blockade around the opponent.

### 3. Skipping Turns
If a player wishes to pass or has no tactical placements, they can elect to **Skip Turn**. If both players skip consecutively or no valid moves exist for either side, the match ends in a **Draw**.

---

## 🎯 Surround & Capture Mechanics

Battles in **WAR: BATTLEGRIDS** are won through tactical positioning and encirclement.

### How Captures Work
1. **Surrounding a Group**: When a placed unit cuts off all open exit paths ("liberties") of an adjacent enemy unit or contiguous group of enemy units, those units become **Captured**.
2. **Path to Kingdom**: An enemy unit or group is safe as long as it maintains a connected path to its own **Kingdom Zone** or an open board boundary. Once that connection is completely severed by surrounding friendly pieces and obstacles, capture occurs.
3. **Capture Points**: Each captured enemy unit awards **+10 Points** to the capturing player.
4. **Captured Grid Tiles**: Captured units are removed from play and their grid tiles transform into **Captured Grid** tiles, forming permanent blockage linkages across the map.

```
Example: Surround Capture

  [P] = Player Unit  |  [E] = Enemy Unit  |  [C] = Captured Grid

   Before Move:               After Player places at (2,2):
   .  [P]  .                   .  [P]  .
  [P] [E]  .    ──────►       [P] [C] [P]   <-- Enemy [E] captured!
   .   .   .                   .  [P]  .        Gains +10 Points
```

---

## 🔓 Kingdom Attack Phase

Every map features a **Kingdom Attack Threshold** (e.g., 10, 20, 30, 80, or 100 points depending on the level config).

1. **Earning Progress**: Every successful unit capture fills your Kingdom Attack progress bar by **10 points per captured unit**.
2. **Unlocking Attack**: Once your score reaches the required threshold, **Kingdom Attack is Unlocked** for your faction.
3. **Barrier Drop**: Unlocking Kingdom Attack drops the magical barrier guarding the enemy's Kingdom Zone. You are now permitted to:
   - Deploy units directly inside the opponent's Kingdom Zone.
   - Complete final victory blockade lines around or connecting through the enemy palace.

---

## 🏆 Win Conditions & Blockades

Victory is achieved by establishing an unbroken connected chain of units and captured grids surrounding the opponent's kingdom base.

The game evaluates victory through a **Dynamic Win Condition Hierarchy**:

```
               ┌────────────────────────┐
               │    1. U-SHAPE WIN      │  (Primary Target)
               └───────────┬────────────┘
                           │ If blocked/impossible
               ┌───────────▼────────────┐
               │   2. PARALLEL WIN      │  (Secondary Target)
               └───────────┬────────────┘
                           │ If blocked/impossible
               ┌───────────▼────────────┘
               │ 3. KINGDOM-ASSISTED    │  (Final Target)
               └────────────────────────┘
```

### 1. U-Shape Blockade (Primary)
- **Goal**: Connect the **Top-Left Anchor** of the palace to the **Top-Right Anchor** around the enemy kingdom.
- **Rule**: Forms an unbroken U-shaped wall enclosing the opponent's palace.

### 2. Parallel Blockade (Secondary)
- **Goal**: Connect the **Left Edge** of the playable board to the **Right Edge** of the playable board.
- **Rule**: Activated if a U-shape is structurally blocked by opponent pieces or obstacles.

### 3. Kingdom-Assisted Blockade (Final)
- **Goal**: Connect any **2 distinct edge/palace anchors** using your own Kingdom Zone as a structural wall in the chain.
- **Rule**: Activated when both U-Shape and Parallel blockades are no longer possible.

### 4. Draw Condition
If the grid becomes completely filled with no valid moves available for either player and no blockade is formed, the match concludes in a **Draw**.

---

## ⚔️ Game Modes

WAR: BATTLEGRIDS supports both single-player campaign and multi-faceted multiplayer combat:

### 📖 Story Campaign Mode
Journey across an interactive overworld map, conquering 8 unique realms guarded by strategic AI commanders with varying playstyles (Defensive, Aggressive, Double-Threat, Fork Expert, and Master).

### 👥 Multiplayer Modes
- **Online Realtime Rooms**: Host or join online games instantly using 5-character room codes powered by Supabase Realtime.
- **Local Bluetooth / Wi-Fi Direct**: Battle nearby friends offline using Google Nearby Connections.
- **Same-Device Pass & Play**: Local duel mode on a single phone, tablet, or PC screen.

---

## 🏰 Campaign Realms

| Realm | Lore & Environment | Board Size | Threshold | AI Strategy |
| :--- | :--- | :---: | :---: | :--- |
| **Snowy Village** | Frozen northern settlement | 15×15 | 10 pts | Basic |
| **Cerulean Spires** | Scholar city with blue-domed towers | 15×15 | 20 pts | Double Threat |
| **Sea Watch** | Rugged coastal cliff fortress | 15×15 | 20 pts | Defensive |
| **Great Sphinx** | Ancient desert ruins & pyramids | 15×15 | 30 pts | Aggressive |
| **Sand Oasis** | Golden sand marketplace | 15×15 | 30 pts | Fork Expert |
| **Iron Bastion** | Impregnable southern fortress | 15×15 | 30 pts | Master |
| **Jade Temple** | Serene oriental pagoda hills | 25×25 | 80 pts | Master |
| **Royal Capital** | Sprawling imperial heartland | 25×25 | 100 pts | Master |

---

## 💡 Tactical Tips & Strategies

1. **Control the Center**: Early placement in central columns gives you flexibility to swing toward either the left or right anchor edges.
2. **Set Up Double Threats (Forks)**: Create multi-branch unit chains that threaten encirclement in two directions at once. Your opponent can only block one per turn!
3. **Guard Your Anchors**: Keep a close eye on your top-left and top-right palace corners. Prevent the enemy from anchoring their blockade lines early.
4. **Prioritize Captures Early**: Focus on trapping opponent units early in the match to reach the **Kingdom Attack Threshold** first. Unlocking Kingdom Attack before your rival gives you a massive offensive advantage.
5. **Adapt Your Win Path**: Pay attention to the **Active Win Condition** indicator on the HUD. If your U-Shape is blocked, shift your formation immediately toward a Parallel or Kingdom-Assisted blockade!
