extends Control
## End Screen - Shown after the player completes the final level.
## Displays a victory message and a "Press Space" prompt to return to menu.
## Emits `menu_requested` when the player presses Space.

signal menu_requested

@onready var prompt_label: RichTextLabel = $Content/PromptLabel

var _tween: Tween

func _ready() -> void:
	visible = false

func _unhandled_input(event: InputEvent) -> void:
	if not visible:
		return
	if event.is_action_pressed("confirm_bits"):
		menu_requested.emit()
		get_viewport().set_input_as_handled()

## Called by game.gd when transitioning to GAME_OVER state.
## Starts the pulse animation on the prompt label.
func show_screen() -> void:
	visible = true
	_start_pulse()

func hide_screen() -> void:
	visible = false
	if _tween:
		_tween.kill()
		_tween = null

## Looping tween that pulses the prompt label's opacity,
## same style as the start screen.
func _start_pulse() -> void:
	if _tween:
		_tween.kill()
	prompt_label.modulate.a = 1.0
	_tween = create_tween().set_loops()
	_tween.tween_property(prompt_label, "modulate:a", 0.3, 0.8)
	_tween.tween_property(prompt_label, "modulate:a", 1.0, 0.8)
