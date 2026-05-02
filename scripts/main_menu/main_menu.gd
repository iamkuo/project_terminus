extends Control

# Nodes
@onready var main_buttons: VBoxContainer = $MainButtons
@onready var about_panel: Panel = $AboutPanel
@onready var game_mode_selector: Control = $GameModeSelector
var pause


func _ready() -> void:
	pause = get_tree().get_root().get_node_or_null("Game/GUI/Pause")
	about_panel.hide()
	game_mode_selector.hide()
	main_buttons.show()
	
func _input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		if about_panel.visible:
			_on_back_button_pressed()
			get_viewport().set_input_as_handled()
		elif game_mode_selector.visible:
			_on_back_button_pressed()
			get_viewport().set_input_as_handled()

# --- Menu Actions ---

func _on_start_button_pressed() -> void:
	main_buttons.hide()
	game_mode_selector.show()

func _on_settings_button_pressed() -> void:
	if pause:
		pause.toggle_pause()

func _on_about_button_pressed() -> void:
	main_buttons.hide()
	about_panel.show()

func _on_quit_button_pressed() -> void:
	get_tree().quit()

func _on_back_button_pressed() -> void:
	about_panel.hide()
	game_mode_selector.hide()
	main_buttons.show()

func _on_game_mode_back_pressed() -> void:
	main_buttons.show()
