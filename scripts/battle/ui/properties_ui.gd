class_name PropertiesUI
extends Control

static func any_open(tree: SceneTree) -> bool:
	for panel in tree.get_nodes_in_group("properties_ui"):
		if panel.has_method("is_panel_open") and panel.is_panel_open():
			return true
	return false

static func close_all_panels(tree: SceneTree, except: Control = null) -> void:
	for panel in tree.get_nodes_in_group("properties_ui"):
		if panel == except:
			continue
		if panel.has_method("is_panel_open") and not panel.is_panel_open():
			continue
		if panel.has_method("hide_panel"):
			panel.hide_panel()

var parent_unit: UnitBase = null
var _panel_open: bool = false

var title_label: Label
var stay_button: Button
var follow_player_button: Button
var attack_enemy_button: Button
var attack_tower_button: Button
var close_button: Button
var bg_close_button : Button

func _ready():
	visible = false
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	
	# Ensure we're in the properties_ui group for input blocking detection
	add_to_group("properties_ui")
	
	# Get node references
	title_label = get_node("PanelContainer/MarginContainer/VBoxContainer/TitleLabel")
	
	stay_button = get_node("PanelContainer/MarginContainer/VBoxContainer/PatternButtons/StayButton")
	
	follow_player_button = get_node("PanelContainer/MarginContainer/VBoxContainer/PatternButtons/FollowPlayerButton")
	
	attack_enemy_button = get_node("PanelContainer/MarginContainer/VBoxContainer/PatternButtons/AttackEnemyButton")
	
	attack_tower_button = get_node("PanelContainer/MarginContainer/VBoxContainer/PatternButtons/AttackTowerButton")
	
	close_button = get_node("PanelContainer/MarginContainer/VBoxContainer/CloseButton")
	
	bg_close_button = get_node("BgCloseButton")
	
	# Connect button signals
	
	if bg_close_button:
		bg_close_button.pressed.connect(hide_panel)
	if stay_button:
		stay_button.pressed.connect(_on_pattern_selected.bind(BehaviorPattern.PatternType.STAY))
	if follow_player_button:
		follow_player_button.pressed.connect(_on_pattern_selected.bind(BehaviorPattern.PatternType.FOLLOW_PLAYER))
	if attack_enemy_button:
		attack_enemy_button.pressed.connect(_on_pattern_selected.bind(BehaviorPattern.PatternType.ATTACK_NEAREST_ENEMY))
	if attack_tower_button:
		attack_tower_button.pressed.connect(_on_pattern_selected.bind(BehaviorPattern.PatternType.ATTACK_NEAREST_TOWER))
	if close_button:
		close_button.pressed.connect(hide_panel)

func is_panel_open() -> bool:
	return _panel_open and visible and is_instance_valid(parent_unit)

func show_for_unit(unit: UnitBase):
	close_all_panels(get_tree(), self)
	parent_unit = unit
	_panel_open = true
	title_label.text = "[ %s ]" % (unit.stats.display_name if unit.stats.display_name != "" else unit.stats.unit_id)
	z_index = 100
	mouse_filter = Control.MOUSE_FILTER_STOP
	visible = true
	_update_button_highlights()

func _unhandled_input(event: InputEvent) -> void:
	if not is_panel_open():
		return
	if event.is_action_pressed("ui_cancel"):
		hide_panel()
		get_viewport().set_input_as_handled()

func _on_pattern_selected(pattern_type: int):
	if not parent_unit:
		print("Error: parent_unit is null")
		return

	print("Pattern selected: ", pattern_type)
	var new_pattern = BehaviorPattern.new()
	new_pattern.pattern_type = pattern_type
	parent_unit.set_behavior_pattern(new_pattern)
	
	# Clear move_to_position meta when switching to STAY to stop immediately
	if pattern_type == BehaviorPattern.PatternType.STAY and parent_unit.has_meta("move_to_position"):
		parent_unit.remove_meta("move_to_position")
	
	print("Pattern set on unit: ", parent_unit.behavior_pattern.pattern_type)
	_update_button_highlights()

func _update_button_highlights():
	if not parent_unit:
		return
	
	# Reset all buttons
	stay_button.modulate = Color(1, 1, 1)
	follow_player_button.modulate = Color(1, 1, 1)
	attack_enemy_button.modulate = Color(1, 1, 1)
	attack_tower_button.modulate = Color(1, 1, 1)
	
	# Highlight active button (default to ATTACK_NEAREST_ENEMY if no pattern set)
	var current_type = BehaviorPattern.PatternType.ATTACK_NEAREST_ENEMY
	if parent_unit.behavior_pattern:
		current_type = parent_unit.behavior_pattern.pattern_type
	
	match current_type:
		BehaviorPattern.PatternType.STAY:
			stay_button.modulate = Color(1, 1, 0)
		BehaviorPattern.PatternType.FOLLOW_PLAYER:
			follow_player_button.modulate = Color(1, 1, 0)
		BehaviorPattern.PatternType.ATTACK_NEAREST_ENEMY:
			attack_enemy_button.modulate = Color(1, 1, 0)
		BehaviorPattern.PatternType.ATTACK_NEAREST_TOWER:
			attack_tower_button.modulate = Color(1, 1, 0)

func hide_panel():
	_panel_open = false
	visible = false
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	z_index = 0
	if parent_unit:
		parent_unit.deselect_unit()
	parent_unit = null
