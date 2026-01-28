# BIT RATE - Global Game Jam 2026

## Theme
**"Mask"** - interpreted as **bitmasking**

## Core Concept
A real-time puzzle game where the player inputs a binary string (bitmask) to toggle level elements on/off while a "dumb" NPC runs forward continuously. Each bit in the mask corresponds to a specific interactable object (obstacles, jump pads, pits, platforms, etc.).

### Gameplay Loop
1. NPC runs forward automatically (no direct control)
2. Player edits a bitmask in real-time
3. Each bit toggles a specific level element on/off
4. Goal: Guide the NPC to the end by toggling the right elements at the right time

### Lore
**Chip** is a loveable, albeit idiot, retro computer who accidentally fell into **Computer Hell**. The player must help Chip escape by manipulating the environment through bitmask operations.

## Tech Stack
- Godot 4.6
- GDScript
- 2D platformer with pixel art

## Project Structure
```
ggj-2026/
├── main.tscn              # Entry point
├── scripts/
│   └── player.gd          # Player controller (may be repurposed or removed)
├── scenes/
│   ├── player.tscn        # Player scene
│   └── Levels/
│       └── level_01.tscn  # Main level
├── npc/
│   ├── npc.gd             # Chip's physics/movement
│   └── npc.tscn           # Chip's scene
└── art/                   # Art assets
```

## Architecture

### Scene Tree Hierarchy
```
Main (Node2D) ← Root entry point
├── GameManager (Autoload singleton - registered in Project Settings)
├── World (Node2D) ← Current level, contains all gameplay
│   ├── TileMapLayer ← Ground, platforms, walls
│   ├── Chip (CharacterBody2D) ← The NPC we're guiding
│   │   ├── Sprite2D / AnimatedSprite2D
│   │   ├── CollisionShape2D
│   │   └── AnimationPlayer (optional)
│   └── MaskableObjects ← Objects controlled by bitmask
│       ├── Obstacle_0 (bit 0)
│       ├── JumpPad_1 (bit 1)
│       ├── Platform_2 (bit 2)
│       └── ...etc
└── UI (CanvasLayer) ← HUD, menus overlay
    └── HUD
        ├── BitmaskInput ← Where player enters/toggles bits
        ├── HealthDisplay
        └── ScoreDisplay
```

### Signal Flow (Pub/Sub Pattern)
```
Chip                    GameManager                 HUD
 ├─ health_changed ───────► listens ─────────────────► updates health display
 ├─ died ─────────────────► listens ─────────────────► shows game over
 └─ reached_goal ─────────► listens ─────────────────► shows level complete

Player Input            GameManager                 MaskableObjects
 └─ bitmask_changed ──────► stores state ───────────► objects check their bit
                            emits bitmask_updated      and enable/disable
```

### GameManager Responsibilities
- **Source of truth** for game state (current bitmask, score, level, chip health)
- **Signal hub** - relays events between gameplay and UI
- **Autoload singleton** - accessible anywhere via `GameManager.property`
- **Object registry** - two-way binding between bits and game objects

### MaskableBehavior System (Composition Pattern)
Any node can become maskable by adding a `MaskableBehavior` child node.
Bit indices range from 0 to `GameManager.max_bits - 1` (default: 4 bits, so 0-3).
`max_bits` can be changed per level as a difficulty modifier.

**Scene structure:**
```
Wall (StaticBody2D)
├── MaskableBehavior (Node)      ← Set bit_index in Inspector
├── ColorRect                     ← Visual
└── CollisionShape2D              ← Physics
```

**Parent script implements behavior:**
```gdscript
extends StaticBody2D

# Called by MaskableBehavior when this object's bit changes
func on_bit_changed(enabled: bool) -> void:
    visible = enabled
    $CollisionShape2D.disabled = not enabled
```

**Two-way communication:**
```gdscript
# GameManager → Object (automatic via MaskableBehavior)
# When player toggles bit 2, MaskableBehavior calls parent's on_bit_changed()

# Object → GameManager (for world events affecting bits)
func _on_bomb_exploded():
    $MaskableBehavior.request_bit_flip(false)  # Turn off this object's bit
```

**Why composition:**
- Works with ANY node type (StaticBody2D, Area2D, CharacterBody2D, etc.)
- No inheritance constraints
- Can add/remove maskable behavior dynamically
- Could support multi-bit objects (multiple MaskableBehavior children)

### Engine Callbacks (automatic, not signals)
- `_process(delta)` → Every frame (UI updates, non-physics logic)
- `_physics_process(delta)` → Fixed 60Hz (physics, movement)
- `_input(event)` → On input events (bitmask toggling)
