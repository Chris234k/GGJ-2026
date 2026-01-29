extends CharacterBody2D
@onready var animated_sprite_2d: AnimatedSprite2D = $AnimatedSprite2D


const SPEED = 300.0
const JUMP_VELOCITY = -850.0

var jump_force := 0.0

func _process(delta: float) -> void:
	var is_jump = false
	var pos: Vector2 = $GroundPos.global_position

	for tilemap in GameManager.level_tilemaps:
		var local_pos := tilemap.to_local(pos)
		var coords    := tilemap.local_to_map(local_pos)
		var data      := tilemap.get_cell_tile_data(coords)

		if data:
			jump_force = data.get_custom_data("jump_force")

			if jump_force > 0:
				return

func _physics_process(delta: float) -> void:
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

	# Get the input direction and handle the movement/deceleration.
	# As good practice, you should replace UI actions with custom gameplay actions.
	var direction := Input.get_axis("Left", "Right")
	if direction:
		velocity.x = direction * SPEED
	else:
		velocity.x = move_toward(velocity.x, 0, SPEED)

	move_and_slide()
	
	if direction == 1:
		animated_sprite_2d.flip_h = false
	elif direction == -1:
		animated_sprite_2d.flip_h = true


# DEBUG ONLY - Remove before release
# Toggle bits 0-3 with number keys 1-4
func _input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed:
		match event.keycode:
			KEY_1:
				print("DEBUG: Toggling bit 0, current mask: ", GameManager.get_binary_string())
				GameManager.toggle_bit(0)
				print("DEBUG: After toggle, mask: ", GameManager.get_binary_string())
			KEY_2: GameManager.toggle_bit(1)
			KEY_3: GameManager.toggle_bit(2)
			KEY_4: GameManager.toggle_bit(3)
