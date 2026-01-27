class_name npc
extends RigidBody2D

@export var ground_accel := 1000.0
@export var air_accel := 500.0
@export var max_horizontal_speed := 200.0
@export var max_vertical_speed := 1000.0

# example 2d physics project: https://github.com/godotengine/godot-demo-projects/blob/4.2-31d1c0c/2d/physics_platformer/player/player.gd

func _init():
	self.custom_integrator = true

	# contact monitor required to poll for grounded state
	# should be set in the scene, but just in case
	self.contact_monitor = true
	self.max_contacts_reported = 5



func _integrate_forces(state: PhysicsDirectBodyState2D) -> void:
	var velocity := state.get_linear_velocity()
	var delta := state.get_step()

	var grounded := false
	var floor_index := -1

	# ground check
	for contact_index in state.get_contact_count():
		var collision_normal = state.get_contact_local_normal(contact_index)

		if collision_normal.dot(Vector2(0, -1)) > 0.6:
			grounded = true
			floor_index = contact_index
			break


	if grounded:
		velocity.x += (ground_accel * delta)
	else:
		velocity.x += (air_accel * delta)
		velocity += state.get_total_gravity() * delta


	# max horizontal speed
	var dir: float = sign(velocity.x)
	var speed: float = abs(velocity.x)
	velocity.x = min(speed, max_horizontal_speed) * dir

	# only gravity for now, don't need dir yet
	velocity.y = min(velocity.y, max_vertical_speed)

	# print(velocity)

	# apply to rb
	state.set_linear_velocity(velocity)


	# animation
	if grounded:
		if velocity.length() > 0:
			$AnimatedSprite2D.animation = "move"
		else:
			$AnimatedSprite2D.animation = "idle"
	else:
		$AnimatedSprite2D.animation = "fall"

	$AnimatedSprite2D.play()
