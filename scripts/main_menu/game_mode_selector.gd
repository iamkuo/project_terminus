extends Control

# Dictionary merging display names and keybinds-panel descriptions per mode
@export var mode_data: Dictionary = {
	"full": {
		"name": "完整模式  (~40分鐘)",
		"description": "【完整模式】\n\n體驗完整的遊戲流程，\n包含所有主線劇情、\n戰鬥關卡與結局。\n\n預計遊玩時間：~40分鐘"
	},
	"trial": {
		"name": "試玩模式  (~5分鐘)",
		"description": "【試玩模式】\n\n快速體驗遊戲核心玩法，\n包含開場劇情與\n首個戰鬥關卡。\n\n預計遊玩時間：~5分鐘"
	},
	"test": {
		"name": "測試模式  (~1分鐘)",
		"description": "【測試模式】\n\n開發者測試用途，\n直接進入戰鬥場景，\n跳過所有劇情演出。\n\n預計遊玩時間：~1分鐘"
	}
}

# Default keybinds text shown when no mode is hovered
const KEYBINDS_TEXT: String = "【操作說明】

[W][A][S][D] / 方向鍵
移動

[E]
互動

[Space]
跳過對話

[Ctrl] + [Space]
跳過所有劇情

[Esc]
暫停 / 取消

[Tab]
開關召喚介面

1~9
召喚角色(由左到右)"

# Nodes
@onready var mode_panel: Panel = $ModePanel
@onready var mode_title: Label = $ModePanel/VBoxContent/ModeTitle
@onready var mode_buttons_container: VBoxContainer = $ModePanel/VBoxContent/ModeButtonsContainer
@onready var mode_button_template: Button = $ModePanel/VBoxContent/ModeButtonsContainer/ModeButtonTemplate
@onready var keybinds_text: Label = $ModePanel/KeybindsPanel/KeybindsText

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
	var mode_data_path = "res://resources/mode_data/"
	var dir = DirAccess.open(mode_data_path)
	
	if not dir:
		print("[GameModeSelector] Failed to open mode_data directory: ", mode_data_path)
		return
	
	dir.list_dir_begin()
	var folder_name = dir.get_next()
	
	while folder_name != "":
		var is_valid_folder = dir.current_is_dir() and not folder_name.begins_with(".") and folder_name != "global"
		if is_valid_folder:
			available_modes.append(folder_name)
			print("[GameModeSelector] Found game mode: ", folder_name)
		folder_name = dir.get_next()
	
	dir.list_dir_end()
	
	# Create mode buttons
	# Clear any existing buttons (except template)
	for child in mode_buttons_container.get_children():
		if child != mode_button_template:
			child.queue_free()
	
	# Create a button for each available mode
	for mode in available_modes:
		var mode_button = mode_button_template.duplicate()
		mode_buttons_container.add_child(mode_button)
		
		# Set button text using display name from mode_data, falling back to the mode key
		var entry = mode_data.get(mode, {})
		mode_button.text = entry.get("name", mode)
		mode_button.show()
		
		# Connect the button signal
		mode_button.pressed.connect(_on_mode_button_pressed.bind(mode))
		
		# Connect hover signals to update keybinds panel with mode description
		mode_button.mouse_entered.connect(_on_mode_button_hovered.bind(mode))
		mode_button.mouse_exited.connect(_on_mode_button_unhovered)
		mode_button.focus_entered.connect(_on_mode_button_hovered.bind(mode))
		mode_button.focus_exited.connect(_on_mode_button_unhovered)

func _on_mode_button_hovered(mode: String) -> void:
	# Show the mode-specific description in the keybinds panel
	var entry = mode_data.get(mode, {})
	keybinds_text.text = entry.get("description", KEYBINDS_TEXT)

func _on_mode_button_unhovered() -> void:
	# Restore the default keybinds text
	keybinds_text.text = KEYBINDS_TEXT

func _on_mode_button_pressed(mode: String) -> void:
	selected_mode = mode
	print("[GameModeSelector] Selected mode: ", mode)
	
	# Define the heavy setup task to be run during the transition (while black)
	var setup_task = func():
		# Initialize ProgressManager with the selected mode
		ProgressManager.load_mode(mode)
		
		# Enable cutscene triggers now that game mode has been explicitly selected
		ProgressManager._allow_cutscene_triggers = true
		
		# Add some starting experience as in original code
		ProgressManager.current_exp += 10
	
	# Switch to main world scene, running the setup task during the fade
	SceneSwitcher.switch_scene("main_world", "none", setup_task)
	
	# Hide the mode selection
	hide()

func _on_back_button_pressed() -> void:
	hide()
	back_to_main_menu.emit()
