extends Control

# Nodes
@onready var main_buttons: VBoxContainer = $MainButtons
@onready var about_panel: Panel = $AboutPanel

@onready var pause_scene = $Pause

func _ready() -> void:
	about_panel.hide()
	main_buttons.show()
	
func _input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		if about_panel.visible:
			_on_back_button_pressed()
			get_viewport().set_input_as_handled()

# --- Menu Actions ---

func _on_start_button_pressed() -> void:
	ProgressManager.current_exp += 10
	SceneSwitcher.switch_scene("main_world", "none")

func _on_settings_button_pressed() -> void:
	pause_scene.toggle_pause()

func _on_about_button_pressed() -> void:
	main_buttons.hide()
	about_panel.show()

func _on_quit_button_pressed() -> void:
	get_tree().quit()

func _on_back_button_pressed() -> void:
	about_panel.hide()
	main_buttons.show()
