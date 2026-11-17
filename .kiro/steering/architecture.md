# Architecture Steering: Voyager Is Not Alone

## Architectural Principles

### 1. Data-Driven Design
All content (dialogues, quests, NPCs, puzzles) must be defined in external JSON files, not hardcoded in GDScript. This enables:
- Content expansion without code changes
- Independent content creation by Dev 2
- Easy testing and validation
- Future localization support

### 2. Modular System Design
Core systems must be:
- **Independent**: Each system has clear responsibility boundaries
- **Composable**: Systems interact through well-defined interfaces
- **Testable**: Logic separated from presentation for automated testing
- **Singleton-based**: Global managers accessed via autoload for convenience

### 3. Signal-Based Communication
Use Godot signals for cross-system events to maintain loose coupling:
- Dialogue system emits `dialogue_started`, `dialogue_ended`
- Quest system emits `quest_updated`, `quest_completed`
- Relationship changes emit `relationship_changed`
- Story flags emit `story_flag_set`

### 4. Typed GDScript with Strict Typing
All code must use:
```gdscript
extends Node
class_name SystemName

var typed_variable: int = 0
var typed_object: Resource = null

func typed_function(param: String) -> bool:
    return true
```

### 5. Scene Composition
Prefer composition over deep inheritance:
- Player extends CharacterBody2D, composes InteractionDetector
- NPCs extend base NPCController, compose PathFollower
- UI elements compose reusable components

## System Architecture

### Core Layer (Developer 1 Ownership)
**Singleton Autoloads** (`res://scripts/core/`):
- `GameState` - Master coordinator, player state, chapter tracking
- `SceneManager` - Scene transitions with effects
- `DialogueManager` - Conversation engine
- `QuestManager` - Quest tracking and progression
- `RelationshipManager` - Trust/Bond per crew member
- `StoryFlagManager` - Global narrative flags
- `SaveManager` - Persistence to JSON files
- `AudioManager` - Music and SFX
- `CrewTaskManager` - Crew assignment system
- `EngineeringSimulation` - Physics and resources
- `PuzzleManager` - Puzzle state and validation

### Component Layer (Developer 1 Ownership)
**Reusable Components** (`res://scripts/components/`):
- `PlayerController` - Movement, animation, input
- `InteractionSystem` - Proximity detection, E key trigger
- `NPCController` - Base NPC behavior and state machine
- `Interactable` - Interface for interactive objects
- `Door` - Scene transition component
- `Terminal` - Computer interface component

### Content Layer (Developer 2 Ownership)
**Scenes** (`res://scenes/`):
- Environment scenes (station floors, rooms, ship, planet)
- NPC instances (extending NPCController)
- UI scenes (menus, HUD, dialogue boxes)

**Data Files** (`res://data/`):
- Dialogue JSON files
- Quest JSON files
- NPC metadata JSON files
- Equipment definitions
- Puzzle configurations

**Assets** (`res://assets/`):
- Pixel art sprites and tilesets
- Character portraits
- UI elements
- Audio files (music, SFX)

## Key Architectural Decisions

### Decision 1: JSON for Data Storage
**Rationale**: JSON is human-readable, version-controllable, and natively supported by Godot. Allows Dev 2 to create content without GDScript knowledge.

**Alternative Considered**: Godot Resource files (.tres). Rejected because less portable and harder to edit externally.

### Decision 2: Singleton Autoloads for Managers
**Rationale**: Simplifies access across scenes, ensures single source of truth, matches Godot best practices for game-wide systems.

**Alternative Considered**: Dependency injection. Rejected as over-engineered for game scope.

### Decision 3: CharacterBody2D for Player and NPCs
**Rationale**: Built-in collision, movement, and physics. Simplifies top-down movement implementation.

**Alternative Considered**: RigidBody2D. Rejected as unnecessary physics complexity.

### Decision 4: Separate Dialogue from NPC Scripts
**Rationale**: Enables dialogue reuse, easier editing, supports branching without code changes.

**Alternative Considered**: Hardcoded NPC dialogue. Rejected as unmaintainable.

### Decision 5: Version-Stamped Save Files
**Rationale**: Enables save migration when game structure changes during development.

**Alternative Considered**: Binary saves. Rejected as harder to debug and migrate.

## System Interaction Patterns

### Player Interaction Flow
```
Player presses E key
  → PlayerController detects input
  → InteractionSystem checks proximity
  → Finds Interactable object (NPC, Door, Terminal)
  → Calls interact() method on Interactable
  → NPC triggers DialogueManager with dialogue_id
  → DialogueManager loads JSON, evaluates conditions
  → Dialogue UI displays with response options
  → Player selects response
  → DialogueManager applies effects (relationship change, quest trigger, story flag)
  → RelationshipManager updates Trust/Bond
  → QuestManager updates quest state
  → StoryFlagManager sets flags
  → Dialogue continues or ends
```

### Quest Progression Flow
```
QuestManager activates quest
  → Quest loaded from JSON with objectives
  → Player interacts with NPC (talk_to objective)
  → DialogueManager notifies QuestManager of completion
  → Player examines object (investigate objective)
  → InteractionSystem notifies QuestManager
  → All objectives complete
  → QuestManager emits quest_completed signal
  → Story flags updated
  → Next quest unlocked based on prerequisites
```

## Performance Targets

- **Frame Rate**: Maintain 60 FPS on modest hardware (Intel i5, 8GB RAM, integrated graphics)
- **Load Times**: Scene transitions < 1 second
- **Memory**: < 512 MB RAM usage
- **Save/Load**: < 500ms for save/load operations
- **Build Size**: < 200 MB for full game

## Technical Constraints

- **Engine Version**: Godot 4.7+ (no downgrades to maintain feature compatibility)
- **Language**: GDScript only (no C#, C++, or GDNative for hackathon scope)
- **Platforms**: Windows 10+, macOS 12+ (Intel and Apple Silicon)
- **Resolution**: 640×360 internal, scaled to display
- **Input**: Keyboard only (WASD/arrows, E, Escape, Space)

## Testing Strategy

### Automated Tests (`res://tests/`)
- Unit tests for engineering simulation (delta-v calculations, power balance)
- Unit tests for relationship system (trust/bond changes, thresholds)
- Unit tests for story flags (set, get, conditional logic)
- Property-based tests for save/load (round-trip serialization)
- Integration tests for dialogue → quest → relationship chains

### Manual Tests
- Player movement and collision on all environment scenes
- Complete dialogue trees with all branches
- Quest progression from start to completion
- Scene transitions preserve state correctly
- Save/load restores exact game state
- Performance profiling during intensive scenes

## Code Organization

```
/voyagerisnotalone/
├── .godot/                 # Godot generated (ignored by Git)
├── .kiro/                  # Kiro specs and config
│   ├── specs/
│   │   └── voyager-is-not-alone/
│   │       ├── requirements.md
│   │       ├── design.md
│   │       └── tasks.md
│   └── steering/
│       ├── product.md
│       ├── architecture.md
│       ├── coding-standards.md
│       └── collaboration.md
├── scenes/
│   ├── ui/                # UI screens (Developer 1)
│   ├── player/            # Player scenes (Developer 1)
│   ├── npcs/              # NPC instances (Developer 2)
│   ├── environments/      # Station, ship, planet (Developer 2)
│   │   ├── station/
│   │   ├── ship/
│   │   └── planet/
│   └── prefabs/           # Reusable objects (Developer 1)
├── scripts/
│   ├── core/              # Singleton managers (Developer 1)
│   ├── systems/           # Major subsystems (Developer 1)
│   ├── components/        # Reusable components (Developer 1)
│   └── data_loaders/      # JSON parsers (Developer 1)
├── assets/
│   ├── sprites/           # Pixel art (Developer 2)
│   │   ├── characters/
│   │   ├── environments/
│   │   └── ui/
│   ├── audio/             # Music and SFX (Developer 2)
│   │   ├── music/
│   │   └── sfx/
│   └── fonts/             # UI fonts (Developer 2)
├── data/
│   ├── dialogues/         # Dialogue JSON (Developer 2)
│   ├── quests/            # Quest JSON (Developer 2)
│   ├── npcs/              # NPC metadata (Developer 2)
│   ├── puzzles/           # Puzzle configs (Developer 2)
│   └── story_config/      # Chapter definitions (Developer 1)
├── tests/                 # Automated tests (Developer 1)
├── project.godot          # Godot project file
├── .gitignore
└── README.md
```

## Architectural Risks and Mitigations

### Risk 1: Save File Corruption
**Mitigation**: Implement save file validation, versioning, and backup to previous save on load failure.

### Risk 2: Complex Dialogue Tree Management
**Mitigation**: Create dialogue editor tool or clear JSON schema documentation. Validate dialogue files on load.

### Risk 3: Performance Degradation in Large Scenes
**Mitigation**: Use TileMapLayer culling, object pooling for particles/SFX, scene instancing for repeated elements.

### Risk 4: Merge Conflicts Between Developers
**Mitigation**: Clear folder ownership, feature branches, regular integration points, prefer separate files over shared ones.

### Risk 5: Inconsistent Asset Styles
**Mitigation**: Establish pixel art style guide early, create base character template, maintain consistent tile size (16×16 or 32×32).
