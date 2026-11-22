# FocusUtils
# Explicit keyboard focus links. Godot otherwise moves focus to the nearest
# control on screen in the pressed direction, which can be a button behind a
# modal window. Modal UI links all its buttons so arrows and Tab stay inside.
class_name FocusUtils
extends RefCounted


## Links from to its four neighbours; a null neighbour means "stay on from".
static func link(from: Control, up: Control, down: Control, left: Control, right: Control) -> void:
	from.focus_neighbor_top = from.get_path_to(up if up != null else from)
	from.focus_neighbor_bottom = from.get_path_to(down if down != null else from)
	from.focus_neighbor_left = from.get_path_to(left if left != null else from)
	from.focus_neighbor_right = from.get_path_to(right if right != null else from)


## Tab / Shift+Tab cycle through controls in this order and never leave them.
static func cycle_tab(controls: Array[Control]) -> void:
	for i: int in controls.size():
		var current: Control = controls[i]
		current.focus_next = current.get_path_to(controls[(i + 1) % controls.size()])
		current.focus_previous = current.get_path_to(controls[(i - 1 + controls.size()) % controls.size()])
