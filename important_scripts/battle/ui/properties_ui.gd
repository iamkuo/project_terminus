extends Control

var parent_unit: UnitBase = null

var title_label: Label
var stay_button: Button
var follow_player_button: Button
var attack_enemy_button: Button
var attack_tower_button: Button
var close_button: Button

func _ready():
	visible = false
	
	# Ensure we're in the properties_ui group for input blocking detection
	add_to_group("properties_ui")
	
	print("PropertiesUI _ready() called, in group: ", is_in_group("properties_ui"))
	
	# Get node references
	title_label = get_node("PanelContainer/MarginContainer/VBoxContainer/TitleLabel")
	print("title_label found: ", title_label != null)
	
	stay_button = get_node("PanelContainer/MarginContainer/VBoxContainer/PatternButtons/StayButton")
	print("stay_button found: ", stay_button != null)
	
	follow_player_button = get_node("PanelContainer/MarginContainer/VBoxContainer/PatternButtons/FollowPlayerButton")
	print("follow_player_button found: ", follow_player_button != null)
	
	attack_enemy_button = get_node("PanelContainer/MarginContainer/VBoxContainer/PatternButtons/AttackEnemyButton")
	print("attack_enemy_button found: ", attack_enemy_button != null)
	
	attack_tower_button = get_node("PanelContainer/MarginContainer/VBoxContainer/PatternButtons/AttackTowerButton")
	print("attack_tower_button found: ", attack_tower_button != null)
	
	close_button = get_node("PanelContainer/MarginContainer/VBoxContainer/CloseButton")
	print("close_button found: ", close_button != null)
	
	# Connect button signals
	if stay_button:
		stay_button.pressed.connect(_on_pattern_selected.bind(BehaviorPattern.PatternType.STAY))
		print("stay_button connected")
	if follow_player_button:
		follow_player_button.pressed.connect(_on_pattern_selected.bind(BehaviorPattern.PatternType.FOLLOW_PLAYER))
		print("follow_player_button connected")
	if attack_enemy_button:
		attack_enemy_button.pressed.connect(_on_pattern_selected.bind(BehaviorPattern.PatternType.ATTACK_NEAREST_ENEMY))
		print("attack_enemy_button connected")
	if attack_tower_button:
		attack_tower_button.pressed.connect(_on_pattern_selected.bind(BehaviorPattern.PatternType.ATTACK_NEAREST_TOWER))
		print("attack_tower_button connected")
	if close_button:
		close_button.pressed.connect(hide_panel)
		print("close_button connected")

func show_for_unit(unit: UnitBase):
	parent_unit = unit
	title_label.text = "[ %s ]" % (unit.stats.display_name if unit.stats.display_name != "" else unit.stats.unit_id)
	visible = true
	_update_button_highlights()

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
	visible = false
	if parent_unit:
		parent_unit.deselect_unit()
	parent_unit = null
