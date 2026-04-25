# BackpackUI.gd
extends Control

# 預載入 UI 小節點
const skill_node_tscn = preload("res://scenes/skill.tscn")
const torch_tscn = preload("res://scenes/torch.tscn")

# Player skill levels and current skill ID are managed locally for UI interaction
# var player_skill_levels: Dictionary = {} # REMOVED: Centralized in ProgressManager
var current_skill_id: String = ""

@onready var detail_popup = $SkillDetailPopup
@onready var popup_title = detail_popup.get_node("Title")
@onready var popup_description = detail_popup.get_node("Description")
@onready var popup_upgradebtn = detail_popup.get_node("UpgradeBtn")
@onready var popup_closebtn = detail_popup.get_node("CloseButton")
@onready var skill_grid = $MarginContainer/TabContainer/SkillsTab/SkillGrid
@onready var memories_container = $"MarginContainer/TabContainer/MemoriesTab/ScrollContainer/HBoxContainer"
@onready var backpack_root = $"."
@onready var tab_container = $MarginContainer/TabContainer

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
	await get_tree().process_frame
	backpack_root.visible = false
	detail_popup.hide()
	setup_backpack()
	
	popup_upgradebtn.pressed.connect(func(): perform_upgrade())
	popup_closebtn.pressed.connect(func(): detail_popup.hide())

	# ProgressManager signals
	ProgressManager.data_updated.connect(_refresh_ui)
	ProgressManager.memory_collected.connect(_on_memory_collected)
	
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

func open_skill_detail(skill_id: String):
	var skill_data = ProgressManager.get_skill_data(skill_id) # Get skill data from ProgressManager
	if not skill_data: return
	
	current_skill_id = skill_id
	# var lv = player_skill_levels.get(skill_id, 1) # USE LOCAL
	var lv = ProgressManager.get_player_skill_level(skill_id) # USE PROGRESS MANAGER
	var cost = int(skill_data.base_cost * pow(1.5, lv - 1))
	
	# Update popup UI content
	popup_title.text = skill_data.name + " 等級 " + str(lv)
	popup_description.text = skill_data.description
	popup_upgradebtn.text = "升級 (消耗 " + str(cost) + " 水晶)"
	detail_popup.show()

# --- Initialize backpack functionality ---
func setup_backpack():
	detail_popup.hide()
	_skill_nodes.clear()
	_memory_torches.clear()
	
	# Clear existing dynamic nodes immediately to avoid naming conflicts
	for n in skill_grid.get_children():
		skill_grid.remove_child(n)
		n.queue_free()
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
		
		# Connect button press to play cutscene
		torch.pressed.connect(func():
			var mem_id = mem_data.id
			var is_collected = ProgressManager.unlocked_memory_ids.has(mem_id)
			if is_collected:
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
		print("Torch lit for memory: ", memory_id)

func perform_upgrade():
	if current_skill_id == "": return
	
	var skill_data = ProgressManager.get_skill_data(current_skill_id) # Get skill data from ProgressManager
	if not skill_data: return # Skill data not found
	var lv = ProgressManager.player_skill_levels.get(current_skill_id, 1) # USE LOCAL
	var cost = int(skill_data.base_cost * pow(1.5, lv - 1))

	if ProgressManager.crystal_count >= cost:
		ProgressManager.crystal_count -= cost
		ProgressManager.player_skill_levels[current_skill_id] = lv + 1 # Increment level locally
		ProgressManager.emit_signal("data_updated") # Signal UI refresh
		# Re-open detail window to show updated level
		open_skill_detail(current_skill_id)
	else:
		print("水晶不足") # Not enough crystals

	# Call the centralized upgrade function in ProgressManager
	var success = ProgressManager.upgrade_player_skill(current_skill_id)
	if success:
		# UI will refresh automatically via ProgressManager.data_updated signal
		# Re-open detail window to show updated level and potentially new cost
		open_skill_detail(current_skill_id)
	else:
		print("Skill upgrade failed.") # Error message printed by ProgressManager
