# Voyager Is Not Alone

A narrative-driven 2D pixel-art space exploration RPG built in Godot 4.7 for **Kiroween 2026 Frankenstein Category**.

## Project Overview

**Voyager Is Not Alone** combines character-driven storytelling, space station exploration, crew relationship management, logical puzzle solving, and aerospace engineering simulation. Players control a named astronaut protagonist exploring Asterion space station, building relationships with four crew members, commanding spacecraft Voyager, and making consequential decisions that lead to multiple endings.

## Game Features

- **Explorable Space Station**: Navigate interconnected 2D environments with multiple floors
- **Crew Relationships**: Build trust and bonds with Maya Chen (Navigator), Elias Voss (Engineer), Nora Reyes (Astrobiologist), and Daniel Kim (Doctor)
- **Branching Narrative**: Make choices that influence story progression and endings
- **Logical Puzzles**: Solve power grid restoration, signal decoding, star navigation challenges
- **Engineering Simulation**: Manage spacecraft systems with realistic physics (Tsiolkovsky equation)
- **Quest System**: Complete main story and side quests with meaningful objectives
- **Save/Load**: Three save slots preserving complete game state

## Development Info

- **Engine**: Godot 4.7
- **Language**: Typed GDScript
- **Platforms**: Windows, macOS
- **Art Style**: Modern pixel art (640×360 internal resolution)
- **Team**: ZEROMUSCLES (2 developers)
- **Repository**: https://github.com/Kv4tn/Voyagerisnotalone

## Project Structure

```
/voyagerisnotalone/
├── .kiro/                  # Kiro specifications and steering
│   ├── specs/
│   │   └── voyager-is-not-alone/
│   │       ├── requirements.md    # 83 detailed requirements
│   │       ├── design.md          # Technical design (~2100 lines)
│   │       └── tasks.md           # 85 implementation tasks
│   └── steering/
│       ├── product.md             # Product vision and success criteria
│       ├── architecture.md        # System architecture and decisions
│       ├── coding-standards.md    # GDScript style guide
│       └── collaboration.md       # Two-developer workflow
├── scenes/
│   ├── ui/                # UI screens (Dev 1)
│   ├── player/            # Player scenes (Dev 1)
│   ├── npcs/              # NPC instances (Dev 2)
│   ├── environments/      # Station, ship, planet (Dev 2)
│   └── prefabs/           # Reusable objects (Dev 1)
├── scripts/
│   ├── core/              # Singleton managers (Dev 1)
│   ├── systems/           # Major subsystems (Dev 1)
│   ├── components/        # Reusable components (Dev 1)
│   └── data_loaders/      # JSON parsers (Dev 1)
├── assets/
│   ├── sprites/           # Pixel art (Dev 2)
│   ├── audio/             # Music and SFX (Dev 2)
│   └── fonts/             # UI fonts (Dev 2)
├── data/
│   ├── dialogues/         # Dialogue JSON (Dev 2)
│   ├── quests/            # Quest JSON (Dev 2)
│   ├── npcs/              # NPC metadata (Dev 2)
│   └── puzzles/           # Puzzle configs (Dev 2)
└── tests/                 # Automated tests (Dev 1)
```

## Getting Started

### Prerequisites

- Godot 4.7 or later
- Git for version control

### Setup

1. Clone the repository:
   ```bash
   git clone https://github.com/Kv4tn/Voyagerisnotalone.git
   cd Voyagerisnotalone
   ```

2. Open project in Godot 4.7:
   - Open Godot
   - Import Project → Select `project.godot`

3. Review specifications:
   - Read `.kiro/specs/voyager-is-not-alone/requirements.md`
   - Read `.kiro/specs/voyager-is-not-alone/design.md`
   - Check `.kiro/specs/voyager-is-not-alone/tasks.md` for implementation tasks

### Development Workflow

**Developer 1 (Systems Programming)**:
1. Implement core systems following `tasks.md`
2. Create singleton managers (GameState, DialogueManager, QuestManager, etc.)
3. Build player controller and NPC base
4. Implement JSON-driven dialogue and quest engines
5. Write automated tests

**Developer 2 (Dias - Content Creation)**:
1. Design and build station environments
2. Create pixel art assets for characters and environments
3. Write dialogue content following JSON schema
4. Design quests following JSON schema
5. Place NPCs and interactive objects in scenes

### Git Workflow

```bash
# Start new feature
git checkout -b feature/your-feature-name

# Make changes and commit
git add .
git commit -m "feat(scope): description"

# Push and create PR
git push origin feature/your-feature-name
```

## Documentation

### Specifications

- **[Requirements](/.kiro/specs/voyager-is-not-alone/requirements.md)**: 83 detailed requirements covering all game systems
- **[Technical Design](/.kiro/specs/voyager-is-not-alone/design.md)**: Complete architecture, data schemas, code examples
- **[Implementation Tasks](/.kiro/specs/voyager-is-not-alone/tasks.md)**: 85 tasks organized into 12 milestones

### Steering Documents

- **[Product Vision](/.kiro/steering/product.md)**: Game vision, target audience, success criteria
- **[Architecture](/.kiro/steering/architecture.md)**: System design, technical decisions, performance targets
- **[Coding Standards](/.kiro/steering/coding-standards.md)**: GDScript style guide, naming conventions
- **[Collaboration Guide](/.kiro/steering/collaboration.md)**: Two-developer workflow, integration points

## MVP Timeline (6 Weeks)

- **Week 1**: Foundation systems (GameState, SceneManager, player controller)
- **Week 2**: Core gameplay (interaction, NPC base, dialogue engine)
- **Week 3**: Quest and relationship systems
- **Week 4**: Engineering simulation, puzzle framework, environments
- **Week 5**: Save/load, audio, UI polish
- **Week 6**: Testing, integration, builds

## Key Systems

### Data-Driven Architecture

All content is defined in JSON files:
- **Dialogues**: Branching conversation trees with conditions and effects
- **Quests**: Multi-objective tasks with prerequisites and rewards
- **NPCs**: Metadata including schedules and dialogue references

### Core Managers (Autoload Singletons)

- `GameState`: Master coordinator, player state, chapter tracking
- `SceneManager`: Scene transitions with effects
- `DialogueManager`: Conversation engine loading JSON files
- `QuestManager`: Quest tracking and progression
- `RelationshipManager`: Trust/Bond per crew member
- `StoryFlagManager`: Global narrative flags
- `SaveManager`: Versioned save files with complete state
- `AudioManager`: Music and sound effects
- `CrewTaskManager`: Crew assignment system
- `EngineeringSimulation`: Physics and resource tracking
- `PuzzleManager`: Puzzle state and validation

## Testing

### Automated Tests

```bash
# Run unit tests
# TODO: Add test runner command when implemented
```

### Manual Testing

- Player movement and collision
- Dialogue tree navigation
- Quest progression
- Scene transitions
- Save/load functionality
- Relationship changes
- Puzzle solving

## Building for Release

### Windows

```bash
# Export preset: Windows Desktop
# TODO: Add export commands
```

### macOS

```bash
# Export preset: macOS
# TODO: Add export commands
```

## Contributing

This is a two-developer project for Kiroween 2026. External contributions are not currently accepted.

### Developers

- **Developer 1**: Systems programming, core architecture, technical implementation
- **Developer 2 (Dias)**: Content creation, environments, dialogue, quests, art assets

## License

[TODO: Add license information]

## Hackathon Category

**Kiroween 2026 - Frankenstein Category**

Demonstrating meaningful integration of:
- Narrative RPG mechanics
- Aerospace engineering simulation
- Crew relationship management
- Logical puzzle solving
- Persistent decision systems

All systems influence each other to create a cohesive gameplay experience.

## Contact

- **Repository**: https://github.com/Kv4tn/Voyagerisnotalone
- **Team**: ZEROMUSCLES

## Acknowledgments

Built with Godot 4.7 and developed using Kiro IDE for AI-assisted development.

---

**Status**: Specification Complete ✓ | Implementation In Progress
**Target**: December 2026 (Kiroween 2026 Hackathon)
**Version**: MVP Development
