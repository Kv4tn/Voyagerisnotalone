# Interactable
# Area2D marker for anything the player can use with the interact action (E).
# The player's InteractionArea detects these on the "interactable" physics layer.
# Owners (terminals, doors, NPCs) connect to `interacted` and react.
class_name Interactable
extends Area2D

# ============================================================================
# SIGNALS
# ============================================================================

signal interacted(interactor: Node)

# ============================================================================
# EXPORTED VARIABLES
# ============================================================================

## Text shown after "[E]" in the interaction prompt, e.g. "Use terminal".
@export var prompt_text: String = "Interact"
## Disabled interactables are ignored by the player's detection.
@export var enabled: bool = true

# ============================================================================
# PUBLIC METHODS
# ============================================================================

func interact(interactor: Node) -> void:
	if not enabled:
		return
	interacted.emit(interactor)
