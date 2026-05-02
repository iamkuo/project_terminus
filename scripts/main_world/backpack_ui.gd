# BackpackUI.gd
extends Control

# 預載入 UI 小節點
const skill_node_tscn = preload("res://scenes/main_world/skill.tscn")
const torch_tscn = preload("res://scenes/main_world/torch.tscn")

# Player skill levels and current skill ID are managed locally for UI interaction
# var player_skill_levels: Dictionary = {} # REMOVED: Centralized in ProgressManager
var current_skill_id: String = ""

@onready var detail_popup = $SkillDetailPopup
@onready var popup_title = detail_popup.get_node("Title")
@onready var popup_description = detail_popup.get_node("Description")
@onready var popup_upgradebtn = detail_popup.get_node("UpgradeBtn")
@onready var popup_closebtn = detail_popup.get_node("CloseButton")
@onready var tab_container = $TabContainer
@onready var bonus_summary = $TabContainer/SkillsTab/SidePanel/BonusSummary
@onready var portrait = $TabContainer/SkillsTab/SidePanel/Portrait
@onready var skill_grid = $TabContainer/SkillsTab/SkillGrid
@onready var memories_container = $TabContainer/MemoriesTab/ScrollContainer/HBoxContainer
@onready var backpack_root = $"."

var _skill_nodes: Dictionary = {} # skill_id -> skill_node
var _memory_torches: Dictionary = {} # memory_id -> torch_node

func _ready():
	# Set tab titles to Chinese
	tab_container.set_tab_title(0, "技能")
	tab_container.set_tab_title(1, "回憶")
	
	# Initialize skill levels (default to 1)
	# We get the skill data from ProgressManager to know which skills exist
	# for skill_id in ProgressManager.active_skills:
	# 	player_skill_levels[skill_id] = 1 # REMOVED: Logic moved to ProgressManager
	backpack_root.visible = false
	detail_popup.hide()
	setup_backpack()
	
	popup_upgradebtn.pressed.connect(func(): perform_upgrade())
	popup_closebtn.pressed.connect(func(): detail_popup.hide())

	# ProgressManager signals
	ProgressManager.data_updated.connect(_refresh_ui)
	ProgressManager.memory_collected.connect(_on_memory_collected)
	ProgressManager.gamemode_changed.connect(_on_gamemode_changed)
	
	_refresh_ui()

func _input(event):
	# Handle Tab (ui_focus_next) to toggle backpack
	if event.is_action_pressed("ui_focus_next"):
		backpack_root.visible = !backpack_root.visible
		if backpack_root.visible:
			_refresh_ui()
		else:
			detail_popup.hide()
		get_viewport().set_input_as_handled()
	
	# Handle ESC (ui_cancel) for staged closing
	elif event.is_action_pressed("ui_cancel"):
		if detail_popup.visible:
			detail_popup.hide()
			get_viewport().set_input_as_handled()
		elif backpack_root.visible:
			backpack_root.visible = false
			get_viewport().set_input_as_handled()

func _process(_delta):
	pass # Logic moved to _input for better control

func _refresh_ui():
	# Refresh skill levels display using Dictionary
	for skill_id in _skill_nodes:
		var skill_node = _skill_nodes[skill_id]
		if skill_node.has_node("VBoxContainer/Level"):
			skill_node.get_node("VBoxContainer/Level").text = "等級 " + str(ProgressManager.get_player_skill_level(skill_id))

	# Refresh memory torch states using Dictionary
	for mem_id in _memory_torches:
		var torch = _memory_torches[mem_id]
		# Check if memory shard is collected
		var is_collected = ProgressManager.unlocked_memory_ids.has(mem_id)
		torch.refresh_visuals(is_collected)
	
	# Refresh Bonus Summary
	if not bonus_summary: return
	
	# Clear existing labels
	for n in bonus_summary.get_children():
		n.queue_free()
	
	# Add current bonuses from all active skills
	for skill_id in ProgressManager.player_skill_levels:
		var level = ProgressManager.get_player_skill_level(skill_id)
		if level <= 1: continue # Only show if boosted
		
		var bonus_text = SkillManager.get_bonus_text(skill_id, level)
		if not bonus_text.is_empty():
			var label = Label.new()
			label.text = "• " + bonus_text
			label.add_theme_font_size_override("font_size", 14)
			bonus_summary.add_child(label)
	
	if bonus_summary.get_child_count() == 0:
		var label = Label.new()
		label.text = "尚無加成效果"
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		label.modulate = Color(0.7, 0.7, 0.7)
		bonus_summary.add_child(label)

func open_skill_detail(skill_id: String):
	var skill_data = ProgressManager.get_skill_data(skill_id) # Get skill data from ProgressManager
	if not skill_data: return
	
	current_skill_id = skill_id
	# var lv = player_skill_levels.get(skill_id, 1) # USE LOCAL
	var lv = ProgressManager.get_player_skill_level(skill_id) # USE PROGRESS MANAGER
	var cost = int(skill_data.base_cost * pow(1.5, lv - 1))
	
	# Update popup UI content
	var current_bonus = SkillManager.get_bonus_text(skill_id, lv)
	var next_bonus = SkillManager.get_bonus_text(skill_id, lv + 1)
	
	popup_title.text = skill_data.name + " 等級 " + str(lv)
	
	var desc_text = skill_data.description
	if not current_bonus.is_empty():
		desc_text += "\n\n當前加成: " + current_bonus
	if not next_bonus.is_empty():
		desc_text += "\n下一級加成: " + next_bonus
		
	popup_description.text = desc_text
	popup_upgradebtn.text = "升級 (消耗 " + str(cost) + " 水晶)"
	detail_popup.show()

# --- Initialize backpack functionality ---
func setup_backpack():
	detail_popup.hide()
	_skill_nodes.clear()
	_memory_torches.clear()
	
	# Clear existing dynamic nodes immediately to avoid naming conflicts
	if skill_grid:
		for n in skill_grid.get_children():
			skill_grid.remove_child(n)
			n.queue_free()
	if memories_container:
		for n in memories_container.get_children():
			memories_container.remove_child(n)
			n.queue_free()
	
	# Dynamically generate skill nodes
	for skill_id in ProgressManager.active_skills:
		var skill_data = ProgressManager.active_skills[skill_id]
		
		# Instantiate skill card
		var skill_node = skill_node_tscn.instantiate()
		skill_node.name = skill_id
		skill_grid.add_child(skill_node)
		_skill_nodes[skill_id] = skill_node # Store in dictionary
		
		# Get skill card's child nodes
		var vbox = skill_node.get_node("VBoxContainer")
		var icon_node = vbox.get_node("Icon")
		var name_node = vbox.get_node("Name")
		var level_node = vbox.get_node("Level")
		var upgrade_btn = vbox.get_node("UpgradeBtn")
		
		# Setting up skill card elements
		icon_node.texture = skill_data.icon
		name_node.text = skill_data.name
		level_node.text = "等級 " + str(ProgressManager.player_skill_levels[skill_id])
		
		# Connect button press event
		upgrade_btn.pressed.connect(func(): open_skill_detail(skill_id))

	# Dynamically generate memory torches
	var active_memories = ProgressManager.active_memories
	for mem_data in active_memories:
		var torch = torch_tscn.instantiate()
		torch.name = mem_data.id
		memories_container.add_child(torch)
		_memory_torches[mem_data.id] = torch # Store in dictionary
		
		var is_unlocked = ProgressManager.unlocked_memory_ids.has(mem_data.id)
		torch.refresh_visuals(is_unlocked)
		torch.set_memory_name(mem_data.name)
		
		# Connect button press to play cutscene only for unlocked torches
		if is_unlocked:
			torch.pressed.connect(func():
				backpack_root.visible = false
				CutsceneManager.play(mem_data.cutscene_id)
		)
	
	# Refresh UI to ensure initial state is correct
	_refresh_ui()

func _on_memory_collected(memory_id: String):
	# Find the torch corresponding to the collected memory and light it using dictionary
	var torch = _memory_torches.get(memory_id)
	if torch:
		torch.refresh_visuals(true)
		# Connect the press handler now that the memory is unlocked
		var mem_data = null
		for data in ProgressManager.active_memories:
			if data.id == memory_id:
				mem_data = data
				break
		if mem_data:
			torch.pressed.connect(func():
				backpack_root.visible = false
				CutsceneManager.play(mem_data.cutscene_id)
			)

func _on_gamemode_changed():
	# Refresh the entire backpack when gamemode changes to show correct memories
	setup_backpack()

func perform_upgrade():
	if current_skill_id == "": return
	
	# Call the centralized upgrade function in ProgressManager
	# This handles crystal subtraction, level increment, and signals
	var success = ProgressManager.upgrade_player_skill(current_skill_id)
	
	if success:
		# UI will refresh automatically via ProgressManager.data_updated signal
		# Re-open detail window to show updated level and potentially new cost
		open_skill_detail(current_skill_id)
