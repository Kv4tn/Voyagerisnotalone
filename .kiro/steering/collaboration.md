# Collaboration Guide: Voyager Is Not Alone

## Two-Developer Workflow

This document defines how **Developer 1 (Kiro-assisted)** and **Developer 2 (Dias)** collaborate effectively on Voyager Is Not Alone.

## Developer Responsibilities

### Developer 1 (Kiro-Assisted) - Systems Programming

**Primary Focus**: Core architecture, game systems, technical infrastructure

**Ownership**:
- `/scripts/core/` - All singleton managers
- `/scripts/systems/` - Major subsystems
- `/scripts/components/` - Reusable components
- `/scripts/data_loaders/` - JSON parsers
- `/scenes/ui/` - UI screens and HUD
- `/scenes/player/` - Player scenes
- `/scenes/prefabs/` - Reusable prefabs (doors, terminals)
- `/tests/` - Automated tests
- `project.godot` - Project configuration
- `.kiro/` - Specifications and tasks

**Key Responsibilities**:
- Implement all singleton managers (GameState, DialogueManager, QuestManager, etc.)
- Create player controller with movement and interaction
- Build NPC base controller and behavior system
- Develop dialogue engine that loads JSON files
- Develop quest engine that loads JSON files
- Implement relationship tracking system
- Create engineering simulation
- Build puzzle framework
- Implement save/load system
- Create audio manager
- Design and implement all JSON data schemas
- Write automated tests for core systems
- Configure Godot project settings
- Create export presets and builds
- Integrate Dias's content into the game

**Communication Needs**:
- Provide clear JSON schemas for Dias to follow
- Document all public APIs and integration points
- Create example dialogue and quest files
- Review Dias's content files for format correctness
- Coordinate on NPC IDs, story flags, and quest IDs

### Developer 2 (Dias) - Content and Environments

**Primary Focus**: Visual content, environments, dialogue writing, quest design

**Ownership**:
- `/scenes/environments/` - All station, ship, planet scenes
- `/scenes/npcs/` - NPC scene instances (using base controller)
- `/assets/sprites/` - All pixel art assets
- `/assets/audio/` - Music and sound effects
- `/assets/fonts/` - UI fonts
- `/data/dialogues/` - All dialogue JSON files
- `/data/quests/` - All quest JSON files
- `/data/npcs/` - NPC metadata JSON files

**Key Responsibilities**:
- Design and build station floors with TileMapLayer
- Create room layouts with doors, terminals, decorations
- Place NPCs in environments with proper spawn points
- Create pixel art for characters, environments, UI
- Write all dialogue content following JSON schema
- Design all quests following JSON schema
- Define NPC metadata (schedules, starting positions)
- Create or source audio assets (music, SFX)
- Implement environmental storytelling details
- Create character portraits
- Design quest objectives and flow
- Balance NPC relationships through dialogue choices

**Communication Needs**:
- Follow JSON schemas exactly as specified
- Use agreed-upon naming conventions for IDs
- Coordinate on story flag names before using them
- Test dialogue trees for logic errors
- Request new story flags when needed
- Report integration issues with base systems

## Folder Ownership Matrix

| Folder | Dev 1 | Dev 2 | Coordination Required |
|--------|-------|-------|----------------------|
| `/scripts/core/` | ✓ Own | Read-only | No |
| `/scripts/systems/` | ✓ Own | Read-only | No |
| `/scripts/components/` | ✓ Own | Read-only | No |
| `/scripts/data_loaders/` | ✓ Own | Read-only | No |
| `/scenes/ui/` | ✓ Own | Read-only | No |
| `/scenes/player/` | ✓ Own | Read-only | No |
| `/scenes/prefabs/` | ✓ Own | Use in scenes | Yes - prefab usage |
| `/scenes/environments/` | Read-only | ✓ Own | No |
| `/scenes/npcs/` | Read-only | ✓ Own | Yes - extends base controller |
| `/assets/sprites/` | Read-only | ✓ Own | No |
| `/assets/audio/` | Read-only | ✓ Own | No |
| `/assets/fonts/` | Read-only | ✓ Own | No |
| `/data/dialogues/` | Examples | ✓ Own | Yes - follow schema |
| `/data/quests/` | Examples | ✓ Own | Yes - follow schema |
| `/data/npcs/` | Examples | ✓ Own | Yes - follow schema |
| `/data/story_config/` | ✓ Own | Read-only | No |
| `/tests/` | ✓ Own | Read-only | No |
| `.kiro/` | ✓ Own | Read-only | No |

## Integration Points

### 1. NPC Creation (Dias Creates NPCs Using Dev 1's Base)

**Dev 1 Provides**:
- `NPCController` base class at `res://scripts/components/npc_controller.gd`
- API documentation for NPCController
- Example NPC scene at `res://scenes/npcs/example_npc.tscn`

**Dias Creates**:
1. Create new scene: `res://scenes/npcs/maya_chen.tscn`
2. Add NPCController as root node
3. Set exported variables:
   - `npc_id`: "maya_chen"
   - `npc_name`: "Maya Chen"
   - `dialogue_file`: "res://data/dialogues/maya_chen.json"
   - `starting_position`: Vector2 from editor
4. Add sprite as child node
5. Add AnimationPlayer for idle/walk animations
6. Add CollisionShape2D
7. Save scene

**Integration**: Dev 1's NPC systems automatically work with Dias's NPC instances.

### 2. Dialogue Creation (Dias Writes Content for Dev 1's Engine)

**Dev 1 Provides**:
- Complete JSON schema for dialogue trees
- Example dialogue file: `res://data/dialogues/example_dialogue.json`
- Dialogue validator script
- List of available story flags
- List of crew member IDs for relationship effects

**Dias Creates**:
1. Write the dialogue file in `res://data/dialogues/` following **`docs/dialogue-format.md`**,
   the single source of truth for the format (fields, supported conditions and effects, validation).
2. Reference it from the NPC's `data/npcs/<npc_id>.json` under `dialogue_files`.
3. Run `tests/run_tests.sh`: `test_dialogue_content.gd` validates every dialogue and NPC file.
   Working example: `data/dialogues/elias_voss_prologue.json`.

**Integration**: DialogueManager automatically loads and plays Dias's dialogue files.

### 3. Quest Creation (Dias Designs Quests for Dev 1's System)

**Dev 1 Provides**:
- Complete JSON schema for quests
- Example quest file: `res://data/quests/example_quest.json`
- List of available objective types
- List of story flags to use as prerequisites

**Dias Creates**:
1. Write the quest file in `res://data/quests/` following **`docs/quest-format.md`**
   (fields, objective types, how dialogues start and complete quests).
2. Start and finish it from dialogue with `start_quest` / `update_quest`.
3. Run `tests/run_tests.sh`: `test_dialogue_content.gd` validates quests too.
   Working example: `data/quests/ch1_main_borrowed_power.json`.

**Integration**: QuestManager loads quests and tracks progress automatically.

### 4. Environment Scenes (Dias Builds Using Dev 1's Prefabs)

**Dev 1 Provides**:
- Door prefab: `res://scenes/prefabs/door.tscn`
  - Exported variables: `target_scene`, `spawn_point_name`
- Terminal prefab: `res://scenes/prefabs/terminal.tscn`
  - Exported variables: `terminal_id`, `interaction_text`
- Quest object prefab: `res://scenes/prefabs/quest_object.tscn`
  - Exported variables: `object_id`, `quest_id`, `objective_id`

**Dias Creates**:
1. Create scene: `res://scenes/environments/station/residential_deck.tscn`
2. Add TileMapLayer for floor/walls
3. Add collision shapes for boundaries
4. Add lighting (if using)
5. Place Door instances:
   - Configure `target_scene` to next room
   - Set `spawn_point_name`
6. Place Terminal instances
7. Place NPC spawn markers (Marker2D nodes named "NPCSpawn_<npc_id>")
8. Add decorative elements
9. Save scene

**Integration**: SceneManager handles door transitions, NPCs spawn at markers.

## Naming Conventions (Shared Standards)

### Story Flags (Must Coordinate)

Both developers use these flags. Add new flags to this shared list:

**Chapter 1 Flags**:
- `game_started`
- `player_name_set`
- `station_intro_complete`
- `met_maya`
- `met_elias`
- `met_nora`
- `met_daniel`
- `power_grid_puzzle_started`
- `power_grid_puzzle_complete`
- `power_restored`
- `preflight_checklist_started`
- `preflight_checklist_complete`
- `launch_authorized`
- `engineering_log_read` - set by the engineering log terminal (prototype room)
- `signal_disclosed` - Elias shared what he knows about the 1420 MHz transmission
- `power_draw_investigated` - reward of `ch1_main_borrowed_power`

The code list is `initialize_default_flags()` in `scripts/core/story_flag_manager.gd`;
`tests/content/test_dialogue_content.gd` fails on dialogue flags missing from it.

**Chapter 2+ Flags** (TBD during development)

### NPC IDs (Must Coordinate)

- `maya_chen` - Maya Chen
- `elias_voss` - Elias Voss
- `nora_reyes` - Nora Reyes
- `daniel_kim` - Daniel Kim
- `station_commander` - Station commander NPC
- `engineer_tech1` - Engineering technician
- (Add more as needed)

### Quest IDs (Must Coordinate)

Format: `ch<chapter>_<type>_<name>`

- `ch1_main_borrowed_power` - Elias: read the engineering log and report back (implemented)
- `ch1_main_power_restoration`
- `ch1_main_crew_introductions`
- `ch1_side_maya_background`
- `ch1_side_equipment_check`
- (Add more as needed)

### Dialogue IDs (Dias Manages)

Format: `<character>_<context>_<number>`

- `maya_intro_001`
- `maya_navigation_001`
- `elias_engineering_001`
- `elias_power_crisis_001`
- (Dias adds as needed)

### Puzzle IDs (Must Coordinate)

- `power_grid_01` - Power restoration puzzle
- `signal_decode_01` - Signal analysis puzzle
- `star_nav_01` - Star navigation puzzle
- (Add more as needed)

## Git Workflow

### Branch Strategy

**main**: Stable, working code only
**dev-systems**: Dev 1's feature branch
**dev-content**: Dev 2's feature branch

### Daily Workflow

**Both Developers**:
1. Start day: `git pull origin main`
2. Create feature branch: `git checkout -b feature/your-feature-name`
3. Work on tasks
4. Commit frequently: `git commit -m "feat(scope): description"`
5. Push to remote: `git push origin feature/your-feature-name`
6. Create PR to merge into main
7. Other developer reviews and approves
8. Merge to main
9. Delete feature branch

### Merge Conflict Prevention

**Rules**:
- Dev 1 never edits files in Dias's folders (except for examples)
- Dias never edits files in Dev 1's folders
- Both pull from main before starting new work
- Both communicate before editing shared files (project.godot)
- Commit and push at end of each work session

### When Conflicts Happen

1. Communicate immediately in team chat
2. Coordinate who resolves the conflict
3. Use `git merge` or `git rebase` as appropriate
4. Test thoroughly after resolution
5. Document what was changed

## Communication Protocols

### Daily Standup (Async)

Each developer posts:
- What I completed yesterday
- What I'm working on today
- Any blockers or questions

### Integration Checkpoints

**Week 1 End**: Dev 1 provides base systems, Dias creates first test scene
**Week 2 End**: First NPC and dialogue integrated
**Week 3 Mid**: First quest integrated
**Week 4 End**: MVP feature-complete
**Week 5**: Testing and polish
**Week 6**: Final integration and builds

### Requesting New Features or Changes

**Dias Needs New Story Flag**:
1. Post in team chat: "Need new flag: `crew_ready_for_launch` for quest completion"
2. Dev 1 adds to shared list and confirms
3. Dias proceeds with usage

**Dias Finds Bug in Core System**:
1. Document bug with reproduction steps
2. Post in team chat or create GitHub issue
3. Dev 1 prioritizes fix
4. Dev 1 notifies when fixed

**Dev 1 Changes JSON Schema**:
1. Update documentation with migration guide
2. Notify Dias of breaking changes
3. Provide example of new format
4. Help migrate existing files if needed

## Quality Assurance

### Dev 1 Reviews

Before merging Dias's content:
- Validate JSON files against schema
- Check that story flags exist in shared list
- Verify NPC IDs match agreed-upon format
- Test dialogue trees don't have dead ends
- Ensure quest objectives are achievable

### Dias Reviews

Before merging Dev 1's systems:
- Test that NPC controller works with example NPC
- Verify dialogue system displays correctly
- Check that quest tracking updates properly
- Ensure save/load preserves environment state

## Tools and Resources

### Shared Documentation

- **JSON Schemas**: `.kiro/specs/voyager-is-not-alone/design.md` (Section 4)
- **Story Flags List**: This document (updated collaboratively)
- **API Documentation**: Auto-generated from GDScript doc comments
- **Task Tracking**: `.kiro/specs/voyager-is-not-alone/tasks.md`

### Recommended Tools for Dias

- **JSON Editor**: VS Code with JSON validation
- **Dialogue Visualization**: Draw.io or Miro for planning dialogue trees
- **Pixel Art**: Aseprite, Piskel, or GraphicsGale
- **Audio**: Audacity for editing, LMMS or Bosca Ceoil for music

### Recommended Tools for Dev 1

- **Testing**: GUT (Godot Unit Testing) framework
- **Profiling**: Godot's built-in profiler
- **Documentation**: GDScript doc comments
- **Version Control**: GitHub Desktop or command-line git

## Troubleshooting Common Issues

### "DialogueManager can't find dialogue file"

**Cause**: File path mismatch
**Solution**: Dias verifies path is `res://data/dialogues/filename.json` (not absolute path)

### "Quest objective not completing"

**Cause**: Objective type or target ID mismatch
**Solution**: Dias checks objective type matches QuestManager's supported types, verifies NPC/puzzle IDs exist

### "NPC not appearing in scene"

**Cause**: NPC spawn marker missing or misnamed
**Solution**: Dias adds Marker2D named `NPCSpawn_<npc_id>`, Dev 1's system spawns NPC at marker

### "Merge conflict in project.godot"

**Cause**: Both developers changed project settings simultaneously
**Solution**: Coordinate who makes project-wide changes, pull frequently

### "Save file doesn't restore NPC positions"

**Cause**: NPC scenes not using base controller properly
**Solution**: Dias ensures NPC extends NPCController, Dev 1 checks save serialization

## Success Metrics

Our collaboration is successful when:
- ✅ No merge conflicts in the last week
- ✅ All JSON files pass schema validation
- ✅ Integration happens smoothly without blocking either developer
- ✅ Both developers can work independently 80% of the time
- ✅ Issues are resolved within 24 hours
- ✅ MVP ships on time with all features functional
- ✅ Both developers understand each other's work

## Emergency Contacts

**Dev 1**: [Add contact method]
**Dev 2 (Dias)**: [Add contact method]
**Team Chat**: [Add Discord/Slack/Telegram link]
**Repository**: https://github.com/Kv4tn/Voyagerisnotalone
