extends Control

@onready var volume_master_slider: HSlider = $Panel/VBoxContainer/GridContainer/main_volume_slider
@onready var volume_music_slider: HSlider = $Panel/VBoxContainer/GridContainer/music_slider
@onready var volume_sfx_slider: HSlider = $Panel/VBoxContainer/GridContainer/sound_effect_slider
@onready var fullscreen_button: CheckButton = $Panel/VBoxContainer/check_button
@onready var continue_button: Button = $Panel/VBoxContainer/HBoxContainer/continue_button
@onready var exit_button: Button = $Panel/VBoxContainer/HBoxContainer/exit_button


func _ready() -> void:
	# Must always process so ESC can un-pause even while tree is paused
	process_mode = Node.PROCESS_MODE_ALWAYS
	visible = false
	
	# Connect signals
	continue_button.pressed.connect(toggle_pause)
	exit_button.pressed.connect(_on_exit_pressed)
	
	volume_master_slider.value_changed.connect(_on_volume_master_changed)
	volume_music_slider.value_changed.connect(_on_volume_music_changed)
	volume_sfx_slider.value_changed.connect(_on_volume_sfx_changed)
	fullscreen_button.toggled.connect(_on_fullscreen_toggled)
	
	# Initialize values
	_initialize_settings()

func _initialize_settings() -> void:
	# Set initial slider values from AudioServer
	volume_master_slider.value = db_to_linear(AudioServer.get_bus_volume_db(AudioServer.get_bus_index("Master"))) * 100.0
	
	var music_bus = AudioServer.get_bus_index("Music")
	if music_bus != -1:
		volume_music_slider.value = db_to_linear(AudioServer.get_bus_volume_db(music_bus)) * 100.0
	
	var sfx_bus = AudioServer.get_bus_index("SFX")
	if sfx_bus != -1:
		volume_sfx_slider.value = db_to_linear(AudioServer.get_bus_volume_db(sfx_bus)) * 100.0
	
	# Set initial fullscreen state
	fullscreen_button.button_pressed = DisplayServer.window_get_mode() == DisplayServer.WINDOW_MODE_FULLSCREEN

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		toggle_pause()
		# Optionally consume the event to prevent multiple pause toggles
		get_viewport().set_input_as_handled()

func _process(_delta: float) -> void:
	pass

func toggle_pause() -> void:
	var paused := not get_tree().paused
	get_tree().paused = paused
	visible = paused
	if paused:
		_initialize_settings()

func _on_volume_master_changed(value: float) -> void:
	AudioServer.set_bus_volume_db(AudioServer.get_bus_index("Master"), linear_to_db(value / 100.0))

func _on_volume_music_changed(value: float) -> void:
	var bus_idx = AudioServer.get_bus_index("Music")
	if bus_idx != -1:
		AudioServer.set_bus_volume_db(bus_idx, linear_to_db(value / 100.0))

func _on_volume_sfx_changed(value: float) -> void:
	var bus_idx = AudioServer.get_bus_index("SFX")
	if bus_idx != -1:
		AudioServer.set_bus_volume_db(bus_idx, linear_to_db(value / 100.0))

func _on_fullscreen_toggled(toggled_on: bool) -> void:
	if toggled_on:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN)
	else:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)

func _on_exit_pressed() -> void:
	get_tree().paused = false
	get_tree().quit()
