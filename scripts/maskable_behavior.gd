class_name MaskableBehavior
extends Node
## Add this as a child to ANY node to make it controllable by the bitmask.
## Parent must implement: on_bit_changed(enabled: bool)
##
## Usage:
##   1. Add MaskableBehavior as a child of any node
##   2. Set bit_index in the Inspector
##   3. Implement on_bit_changed(enabled: bool) in the parent's script
##
## Alternatively, connect to the bit_changed signal instead of implementing the method.

## Emitted when this object's bit state changes (after invert_logic applied)
signal bit_changed(enabled: bool)

## Which bit controls this object (set in Inspector)
@export var bit_index: int = 0

## If true, parent receives OPPOSITE of bit state
## e.g., bit ON = object disabled (for "remove obstacle" mechanics)
@export var invert_logic: bool = false

## Current state (after invert_logic applied)
var is_enabled: bool = false

# --- Activation/Deactivation Cache ---
var _cached_parent: Node = null
var _cached_position_in_parent: int = -1
var _is_parent_deactivated: bool = false
var _cleanup_callable: Callable  # Stored so we can disconnect/reconnect

func _ready() -> void:
	if bit_index < 0 or bit_index >= GameManager.max_bits:
		push_error("MaskableBehavior '%s': bit_index %d out of range (0-%d)" % [get_parent().name, bit_index, GameManager.max_bits - 1])
		return

	# Store callable for disconnect/reconnect during deactivation
	_cleanup_callable = GameManager._on_registered_object_exiting.bind(bit_index)
	GameManager.register_object(bit_index, self)

## Called by GameManager when this bit changes
func on_bit_changed(enabled: bool) -> void:
	is_enabled = enabled if not invert_logic else not enabled

	# Emit signal for nodes that prefer signal connections
	bit_changed.emit(is_enabled)

	# Call parent's method directly if it exists
	var parent = get_parent()
	if parent and parent.has_method("on_bit_changed"):
		parent.on_bit_changed(is_enabled)

## Request GameManager to change this bit's state
## Use for world events: bomb explodes, timer expires, enemy interaction, etc.
func request_bit_flip(new_state: bool) -> void:
	GameManager.object_requests_bit_change(bit_index, new_state)

## Request GameManager to toggle this bit
func request_bit_toggle() -> void:
	GameManager.toggle_bit(bit_index)

# --- Activation/Deactivation ---

## Remove parent from scene tree (preserves all state)
## Call reactivate_parent() to restore it
func deactivate_parent() -> void:
	var parent = get_parent()
	if _is_parent_deactivated or parent == null:
		return

	var grandparent = parent.get_parent()
	if grandparent == null:
		push_warning("MaskableBehavior: Cannot deactivate root node")
		return

	_cached_parent = grandparent
	_cached_position_in_parent = parent.get_index()
	_is_parent_deactivated = true

	# Disconnect cleanup signal before removing (prevents auto-unregister)
	if tree_exiting.is_connected(_cleanup_callable):
		tree_exiting.disconnect(_cleanup_callable)

	grandparent.remove_child(parent)

## Restore parent to scene tree
func reactivate_parent() -> void:
	if not _is_parent_deactivated or _cached_parent == null:
		return

	var parent = get_parent()
	# Clamp position in case siblings were removed while deactivated
	var max_index = _cached_parent.get_child_count()
	var target_index = mini(_cached_position_in_parent, max_index)
	_cached_parent.add_child(parent)
	_cached_parent.move_child(parent, target_index)

	# Reconnect cleanup signal now that we're back in tree
	if not tree_exiting.is_connected(_cleanup_callable):
		tree_exiting.connect(_cleanup_callable)

	_cached_parent = null
	_cached_position_in_parent = -1
	_is_parent_deactivated = false

## Check if parent is currently deactivated
func is_parent_deactivated() -> bool:
	return _is_parent_deactivated
