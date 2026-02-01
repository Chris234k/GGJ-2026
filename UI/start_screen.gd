extends Control
## Start Screen - Shown on game launch before any level loads.
## Emits `start_requested` when Space is pressed, or `level_select_requested`
## when L is pressed. Q shows a quit confirmation (Y/N).

signal start_requested
signal level_select_requested

@onready var prompt_panel: PanelContainer = $Content/PromptPanel
@onready var prompt_label: RichTextLabel = $Content/PromptPanel/PromptLabel
@onready var confirm_panel: PanelContainer = $Content/ConfirmPanel

var _tween: Tween
var _confirming_quit: bool = false

func _unhandled_input(event: InputEvent) -> void:
	if not visible:
		return

	if not event is InputEventKey or not event.pressed:
		return

	if _confirming_quit:
		if event.keycode == KEY_Y:
			get_tree().quit()
		elif event.keycode == KEY_N or event.is_action_pressed("pause"):
			_set_confirming(false)
		get_viewport().set_input_as_handled()
		return

	# "confirm_bits" is already mapped to Space in the project input map.
	if event.is_action_pressed("confirm_bits"):
		start_requested.emit()
		get_viewport().set_input_as_handled()
		return

	# L key opens the level select screen.
	if event.keycode == KEY_L:
		level_select_requested.emit()
		get_viewport().set_input_as_handled()
		return

	# Q key shows quit confirmation.
	if event.keycode == KEY_Q:
		_set_confirming(true)
		get_viewport().set_input_as_handled()

## Called by game.gd (via visibility) to start the pulse animation.
## The tween only runs while the screen is actually visible.
func show_screen() -> void:
	visible = true
	_set_confirming(false)
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

## Toggle between the normal prompt and the quit confirmation.
func _set_confirming(confirming: bool) -> void:
	_confirming_quit = confirming
	prompt_panel.visible = not confirming
	confirm_panel.visible = confirming
