extends CharacterBody2D
@onready var animated_sprite_2d: AnimatedSprite2D = $AnimatedSprite2D


const SPEED = 100.0
const JUMP_VELOCITY = -850.0

var jump_force := 0.0
var _is_dead := false

@export var auto_move := true
@export var auto_move_left := false
@export var is_player := true

var parent: Node
var enemy_spawn_pos := Vector2(0.0, 0.0)

func _ready() -> void:
	parent = get_parent()

	if is_player:
		GameManager.register_player(self)
	else:
		enemy_spawn_pos = global_position
		GameManager.chip_died.connect(on_player_die)

func _process(_delta: float) -> void:
	if _is_dead:
		return

	var pos: Vector2 = $GroundPos.global_position

	# HACK: if we go too far down reload the level
	if pos.y > 1000:
		die(true) # falling off skips the death animation
		return

	for tilemap in GameManager.level_tilemaps:
		# Skip disabled tilemaps (toggled off via bitmask)
		if not tilemap.enabled:
			continue

		var local_pos := tilemap.to_local(pos)
		var coords    := tilemap.local_to_map(local_pos)
		var data      := tilemap.get_cell_tile_data(coords)

		if data:
			var jf = data.get_custom_data("jump_force")
			if jf != null and jf > 0:
				jump_force = jf
				return

			var is_deadly = data.get_custom_data("is_deadly")
			if is_deadly:
				die()
				return

			var is_goal = data.get_custom_data("is_goal")
			if is_goal:
				GameManager.complete_level()
				return

func _physics_process(delta: float) -> void:
	if _is_dead:
		return

	# Animations
	if velocity.x > 1 or velocity.x < -1:
		animated_sprite_2d.animation = "Run"
	else:
		animated_sprite_2d.animation = "Idle"

	# Add the gravity.
	if not is_on_floor():
		velocity += get_gravity() * delta
		animated_sprite_2d.animation = "Jump"

	# Handle jump.
	if jump_force > 0 and is_on_floor:
		velocity.y = JUMP_VELOCITY
		jump_force = 0

	var direction := 0.0

	if auto_move:
		if auto_move_left:
			direction = -1
		else:
			direction = 1

		velocity.x = direction * SPEED
	else:
		velocity.x = move_toward(velocity.x, 0, SPEED)

	move_and_slide()

	if direction == 1:
		animated_sprite_2d.flip_h = false
	elif direction == -1:
		animated_sprite_2d.flip_h = true


func die(skip_death_animation: bool = false) -> void:
	if _is_dead:
		return
	
	_is_dead = true

	if !skip_death_animation:
		# wait out the death animation
		animated_sprite_2d.animation = "Die"
		await get_tree().create_timer(0.5).timeout

	if is_player:
		respawn(GameManager.get_respawn_position())
		GameManager.notify_chip_died()
	else:
		parent.remove_child(self)

func respawn(spawn_position: Vector2) -> void:
	velocity = Vector2.ZERO

	# Death flash effect
	var tween = create_tween()
	tween.tween_property(animated_sprite_2d, "modulate", Color.RED, 0.1)
	tween.tween_property(animated_sprite_2d, "modulate", Color.TRANSPARENT, 0.1)
	tween.tween_callback(_do_respawn.bind(spawn_position))

func _do_respawn(spawn_position: Vector2) -> void:
	global_position = spawn_position
	velocity = Vector2.ZERO
	jump_force = 0
	_is_dead = false

	animated_sprite_2d.animation = "Idle"
	animated_sprite_2d.play()

	if is_player:
		# Fade back in
		var tween = create_tween()
		tween.tween_property(animated_sprite_2d, "modulate", Color.WHITE, 0.15)
	else:
		parent.add_child(self)

# enemy responds to player death
func on_player_die() -> void:
	_do_respawn(enemy_spawn_pos)

# DEBUG ONLY - Remove before release
# Toggle bits 0-3 with number keys 1-4
func _input(event: InputEvent) -> void:
	if !is_player:
		return

	if event is InputEventKey and event.pressed:
		match event.keycode:
			KEY_1:
				print("DEBUG: Toggling bit 0, current mask: ", GameManager.get_binary_string())
				GameManager.toggle_bit(0)
				print("DEBUG: After toggle, mask: ", GameManager.get_binary_string())
			KEY_2:
				print("DEBUG: Toggling bit 1")
				GameManager.toggle_bit(1)
			KEY_3:
				print("DEBUG: Toggling bit 2")
				GameManager.toggle_bit(2)
			KEY_4:
				print("DEBUG: Toggling bit 3")
				GameManager.toggle_bit(3)
