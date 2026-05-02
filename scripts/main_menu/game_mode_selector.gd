extends Control

# Export dictionary for mapping mode prefixes to display names
@export var mode_display_names: Dictionary = {
	"full": "完整模式  (~40分鐘)",
	"trial": "試玩模式  (~5分鐘)", 
	"test": "測試模式  (~1分鐘)"
}

# Nodes
@onready var mode_panel: Panel = $ModePanel
@onready var mode_title: Label = $ModePanel/VBoxContent/ModeTitle
@onready var mode_buttons_container: VBoxContainer = $ModePanel/VBoxContent/ModeButtonsContainer
@onready var mode_button_template: Button = $ModePanel/VBoxContent/ModeButtonsContainer/ModeButtonTemplate

# Signals
signal back_to_main_menu()

# Available game modes discovered
var available_modes: Array[String] = []
var selected_mode: String = ""

func _ready() -> void:
	# Hide the control node initially
	hide()
	# Hide the template button since it's just for duplication
	mode_button_template.hide()
	
	# Discover available game modes
	_discover_game_modes()
	
	# Create mode buttons
	_create_mode_buttons()

func _discover_game_modes() -> void:
	var orders_path = "res://resources/memories/orders/"
	var dir = DirAccess.open(orders_path)
	
	if not dir:
		print("[GameModeSelector] Failed to open orders directory: ", orders_path)
		return
	
	dir.list_dir_begin()
	var file_name = dir.get_next()
	
	while file_name != "":
		# Strip .remap if it exists (necessary for exported Godot builds)
		var actual_file_name = file_name.trim_suffix(".remap")
		
		if actual_file_name.ends_with("_memory_order.tres"):
			# Extract mode prefix from filename
			var mode_name = actual_file_name.replace("_memory_order.tres", "")
			available_modes.append(mode_name)
			print("[GameModeSelector] Found game mode: ", mode_name)
		file_name = dir.get_next()
	
	dir.list_dir_end()

func _create_mode_buttons() -> void:
	# Clear any existing buttons (except template)
	for child in mode_buttons_container.get_children():
		if child != mode_button_template:
			child.queue_free()
	
	# Create a button for each available mode
	for mode in available_modes:
		var mode_button = mode_button_template.duplicate()
		mode_buttons_container.add_child(mode_button)
		
		# Set button text using display name mapping or prefix directly
		var display_name = mode_display_names.get(mode, mode)
		mode_button.text = display_name
		mode_button.show()
		
		# Connect the button signal
		mode_button.pressed.connect(_on_mode_button_pressed.bind(mode))

func _on_mode_button_pressed(mode: String) -> void:
	selected_mode = mode
	print("[GameModeSelector] Selected mode: ", mode)
	
	# Initialize ProgressManager with the selected mode
	ProgressManager.mode = mode
	
	# Reload ProgressManager to apply the new mode
	ProgressManager._ready()
	
	# Add some starting experience as in original code
	ProgressManager.current_exp += 10
	
	# Switch to main world scene
	SceneSwitcher.switch_scene("main_world", "none")
	
	# Hide the mode selection
	hide()

func _on_back_button_pressed() -> void:
	hide()
	back_to_main_menu.emit()
