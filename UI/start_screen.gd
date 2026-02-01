extends Control
## Start Screen - Shown on game launch before any level loads.
## Emits `start_requested` when Space is pressed, or `level_select_requested`
## when L is pressed.

signal start_requested
signal level_select_requested

@onready var prompt_label: RichTextLabel = $Content/PromptPanel/PromptLabel

var _tween: Tween

func _unhandled_input(event: InputEvent) -> void:
	if not visible:
		return
	# "confirm_bits" is already mapped to Space in the project input map.
	if event.is_action_pressed("confirm_bits"):
		start_requested.emit()
		# Mark the input as handled so it doesn't propagate to other nodes
		# (e.g. the HUD trying to submit bits).
		get_viewport().set_input_as_handled()
		return

	# L key opens the level select screen.
	if event is InputEventKey and event.pressed and event.keycode == KEY_L:
		level_select_requested.emit()
		get_viewport().set_input_as_handled()

## Called by game.gd (via visibility) to start the pulse animation.
## The tween only runs while the screen is actually visible.
func show_screen() -> void:
	visible = true
	_start_pulse()

func hide_screen() -> void:
	visible = false
	if _tween:
		_tween.kill()
		_tween = null

## Create a looping tween that pulses the prompt label's opacity.
func _start_pulse() -> void:
	if _tween:
		_tween.kill()
	prompt_label.modulate.a = 1.0
	_tween = create_tween().set_loops()
	# Fade from full opacity down to 30%, then back up. Each direction
	# takes 0.8 seconds, giving a steady ~1.6 second breathing cycle.
	_tween.tween_property(prompt_label, "modulate:a", 0.3, 0.8)
	_tween.tween_property(prompt_label, "modulate:a", 1.0, 0.8)
