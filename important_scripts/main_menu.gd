extends Control

# Nodes
@onready var main_buttons: VBoxContainer = $MainButtons
@onready var options_panel: Panel = $OptionsPanel
@onready var about_panel: Panel = $AboutPanel

# Settings Nodes
@onready var master_slider: HSlider = $OptionsPanel/Content/SettingsGrid/MasterSlider
@onready var music_slider: HSlider = $OptionsPanel/Content/SettingsGrid/MusicSlider
@onready var sfx_slider: HSlider = $OptionsPanel/Content/SettingsGrid/SfxSlider
@onready var fullscreen_button: CheckButton = $OptionsPanel/Content/FullscreenButton

func _ready() -> void:
	options_panel.hide()
	about_panel.hide()
	main_buttons.show()
	
	# Initialize settings from AudioServer/DisplayServer
	_initialize_settings()
	
	# Connect settings signals
	master_slider.value_changed.connect(_on_master_slider_changed)
	music_slider.value_changed.connect(_on_music_slider_changed)
	sfx_slider.value_changed.connect(_on_sfx_slider_changed)
	fullscreen_button.toggled.connect(_on_fullscreen_toggled)
	
func _input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		if options_panel.visible or about_panel.visible:
			_on_back_button_pressed()
			get_viewport().set_input_as_handled()

func _initialize_settings() -> void:
	# Set initial slider values from AudioServer
	master_slider.value = db_to_linear(AudioServer.get_bus_volume_db(AudioServer.get_bus_index("Master"))) * 100.0
	
	var music_bus = AudioServer.get_bus_index("Music")
	if music_bus != -1:
		music_slider.value = db_to_linear(AudioServer.get_bus_volume_db(music_bus)) * 100.0
	
	var sfx_bus = AudioServer.get_bus_index("SFX")
	if sfx_bus != -1:
		sfx_slider.value = db_to_linear(AudioServer.get_bus_volume_db(sfx_bus)) * 100.0
	
	# Set initial fullscreen state
	fullscreen_button.button_pressed = DisplayServer.window_get_mode() == DisplayServer.WINDOW_MODE_FULLSCREEN

# --- Menu Actions ---

func _on_start_button_pressed() -> void:
	ProgressManager.current_exp += 10
	SceneSwitcher.switch_scene("main_world", "none")

func _on_settings_button_pressed() -> void:
	# Re-init settings in case they were changed in pause menu
	_initialize_settings()
	main_buttons.hide()
	options_panel.show()

func _on_about_button_pressed() -> void:
	main_buttons.hide()
	about_panel.show()

func _on_quit_button_pressed() -> void:
	get_tree().quit()

func _on_back_button_pressed() -> void:
	options_panel.hide()
	about_panel.hide()
	main_buttons.show()

# --- Settings Handling ---

func _on_master_slider_changed(value: float) -> void:
	AudioServer.set_bus_volume_db(AudioServer.get_bus_index("Master"), linear_to_db(value / 100.0))

func _on_music_slider_changed(value: float) -> void:
	var bus_idx = AudioServer.get_bus_index("Music")
	if bus_idx != -1:
		AudioServer.set_bus_volume_db(bus_idx, linear_to_db(value / 100.0))

func _on_sfx_slider_changed(value: float) -> void:
	var bus_idx = AudioServer.get_bus_index("SFX")
	if bus_idx != -1:
		AudioServer.set_bus_volume_db(bus_idx, linear_to_db(value / 100.0))

func _on_fullscreen_toggled(toggled_on: bool) -> void:
	if toggled_on:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN)
	else:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
