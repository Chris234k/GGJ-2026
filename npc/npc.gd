class_name npc
extends RigidBody2D

@export var move_speed := Vector2(2.0, 0.0)

# example 2d physics project: https://github.com/godotengine/godot-demo-projects/blob/4.2-31d1c0c/2d/physics_platformer/player/player.gd

func _integrate_forces(state: PhysicsDirectBodyState2D) -> void:
	var velocity := Vector2.ZERO
	velocity = move_speed

	state.set_linear_velocity(velocity)

	if velocity.length() > 0:
		$AnimatedSprite2D.animation = "move"
	else:
		$AnimatedSprite2D.animation = "idle"

	$AnimatedSprite2D.play()
