extends Node

# --- 1. 常數與資源路徑 ---
const PATH_SKILLS = "res://resources/skills/"
const FALLBACK_ID = "default_failure_cutscene"

# --- 2. 玩家數據與狀態 ---
var mode: String = "test"
var crystal_count: int = 1000
var _current_exp: int = 0
var _allow_cutscene_triggers: bool = false  # Only trigger cutscenes after game mode is selected

var current_exp: int = 0:
	set(value):
		if value != _current_exp:
			_current_exp = value
			data_updated.emit()
			# Defer progression check to prevent multiple calls in one frame
			call_deferred("_check_stage_progression")
	get:
		return _current_exp
var current_stage_index: int = -1
var unlocked_memory_ids: Array[String] = []
var player_skill_levels: Dictionary = {}

# --- 3. 資源快取 ---
var active_stages: Array[StageData] = []
var active_memories: Array[MemoryData] = []
var active_skills: Dictionary = {}
var active_cutscenes: Dictionary = {}

# --- 4. 信號 ---
signal data_updated
signal memory_collected(memory_id: String)
signal gamemode_changed()

# --- 5. 初始化流程 ---

func _ready() -> void:
	# Validate game mode
	_validate_mode()
	
	# Clear existing data before reloading
	active_stages.clear()
	active_memories.clear()
	
	var mode_dir = "res://resources/mode_data/" + mode + "/"
	var global_dir = "res://resources/mode_data/global/"
	
	# 初始化基礎資源 - 從單一合併檔案載入關卡
	var stages_path = mode_dir + "stages.tres"
	var stages_res = load(stages_path) as StageOrder
	if stages_res:
		active_stages.assign(stages_res.stages)
		active_stages.sort_custom(func(a, b): return a.req_exp < b.req_exp)
	else:
		push_error("[ProgressManager] Failed to load stages for mode: " + mode)
	
	active_skills = _load_resources(PATH_SKILLS, SkillData)
	# Initialize player skill levels for all active skills
	for skill_id in active_skills:
		if not player_skill_levels.has(skill_id):
			player_skill_levels[skill_id] = 1
	
	active_cutscenes = _load_resources(global_dir + "cutscenes/", CutsceneScript)
	active_cutscenes.merge(_load_resources(mode_dir + "cutscenes/", CutsceneScript))
	
	# 初始化記憶系統 (全域與模式專屬)
	var all_mems = _load_resources(global_dir + "memories/", MemoryData)
	all_mems.merge(_load_resources(mode_dir + "memories/", MemoryData))
	
	var order_path = mode_dir + "memory_order.tres"
	var order_res = load(order_path) as MemoryOrder
	if order_res:
		for mem_id in order_res.ordered_memory_ids:
			if mem_id in all_mems: active_memories.append(all_mems[mem_id])
	
	# Validate all resources are consistent
	_validate_resources()
	
	# Wire up all signal connections (see _connect_signals below).
	_connect_signals()
	
	# Only check progression if cutscene triggers are enabled (i.e., after game mode selection)
	if _allow_cutscene_triggers:
		_check_stage_progression()
	
	# Emit signal to notify UI that gamemode has changed
	gamemode_changed.emit()

# Centralised signal wiring — all connects live here so _ready() stays clean.
func _connect_signals() -> void:
	# Listen to BattleManager so we can respond to game events without
	# BattleManager knowing anything about cutscenes.
	BattleManager.battle_won.connect(_on_battle_won)

# --- 6. 核心進度邏輯 ---

func _check_stage_progression() -> void:
	# Loop through all stages that the current exp qualifies for
	while true:
		var next_idx = current_stage_index + 1
		if active_stages.is_empty() or next_idx >= active_stages.size(): break

		var stage = active_stages[next_idx]
		if current_exp < stage.req_exp: break

		# 符合條件：更新進度
		current_stage_index = next_idx
		
		# Unlock the memory shard associated with this stage (if any)
		if stage.unlocks_memory_id:
			var play_mem_cutscene = true
			if not stage.cutscene_id.is_empty():
				for mem in active_memories:
					if mem.id == stage.unlocks_memory_id:
						if mem.cutscene_id == stage.cutscene_id:
							play_mem_cutscene = false
						break
			collect_memory(stage.unlocks_memory_id, play_mem_cutscene)
		
		# Stage reached — let ProgressManager decide what cutscene to play (if any).
		if not stage.cutscene_id.is_empty():
			_play_cutscene(stage.cutscene_id)
		
		# Always emit data updated when a stage milestone is reached
		data_updated.emit()

# --- 7. 通用工具與對外接口 ---

## Private — the ONLY place in the entire codebase that calls CutsceneManager.
## All cutscene logic flows through here so the guard is enforced once.
func _play_cutscene(cutscene_id: String) -> void:
	if cutscene_id.is_empty() or not _allow_cutscene_triggers:
		return
	if cutscene_id not in active_cutscenes:
		push_warning("[ProgressManager] Cutscene ID not found: " + cutscene_id)
		return
	CutsceneManager.play(cutscene_id)

# -----------------------------------------------------------------------
# Semantic event handlers — called by other systems describing what happened.
# ProgressManager decides the appropriate response (e.g. which cutscene).
# -----------------------------------------------------------------------

## Called automatically when BattleManager emits battle_won.
## Plays the win cutscene configured on the tp_point, if any.
func _on_battle_won() -> void:
	_play_cutscene(ConfigManager.unlock_memory_on_win)

## Called by world story-event trigger areas when a player walks into one.
## The event_id maps to a cutscene configured on that trigger node.
func trigger_story_event(event_id: String) -> void:
	_play_cutscene(event_id)

## Called by MapTransitionManager when the player is blocked from entering an area.
## ProgressManager decides how to respond (plays the configured lock cutscene).
func on_area_entry_blocked(lock_id: String) -> void:
	_play_cutscene(lock_id)

## Called by BackpackUI when the player wants to replay a collected memory's story.
## Accepts a memory_id — ProgressManager looks up the associated cutscene internally.
func replay_memory(memory_id: String) -> void:
	for mem in active_memories:
		if mem.id == memory_id:
			_play_cutscene(mem.cutscene_id)
			break

func _load_resources(path: String, type: GDScript) -> Dictionary:
	var collection = {}
	var dir = DirAccess.open(path)
	if not dir: return collection
	
	dir.list_dir_begin()
	var file_name = dir.get_next()
	while file_name != "":
		# Strip .remap if it exists (necessary for exported Godot builds)
		var actual_file_name = file_name.trim_suffix(".remap")
		var full_path = path.path_join(actual_file_name)
		
		if dir.current_is_dir():
			if not file_name.begins_with("."): # Skip hidden directories
				var sub_collection = _load_resources(full_path + "/", type)
				collection.merge(sub_collection)
		elif actual_file_name.ends_with(".tres") or actual_file_name.ends_with(".res"):
			var res = load(full_path)
			if is_instance_of(res, type) and "id" in res:
				collection[res.id] = res
		file_name = dir.get_next()
	return collection

func collect_memory(id: String, play_cutscene: bool = true) -> void:
	if id not in unlocked_memory_ids:
		unlocked_memory_ids.append(id)
		memory_collected.emit(id)
		data_updated.emit()
		if play_cutscene:
			# Play the associated cutscene if this memory has one — handled entirely here
			# so no caller ever needs to know about cutscenes.
			for mem in active_memories:
				if mem.id == id:
					_play_cutscene(mem.cutscene_id)
					break

func upgrade_player_skill(id: String) -> bool:
	var skill = active_skills.get(id)
	var lv = player_skill_levels.get(id, 1)
	if not skill: 
		print("[ProgressManager] Upgrade failed: Skill ID not found: ", id)
		return false
	
	var cost = int(skill.base_cost * pow(1.2, lv - 1))
	if crystal_count >= cost:
		crystal_count -= cost
		player_skill_levels[id] = lv + 1
		print("[ProgressManager] Upgraded %s to level %d. Remaining crystals: %d" % [id, lv + 1, crystal_count])
		data_updated.emit()
		return true
	
	print("[ProgressManager] Upgrade failed: Not enough crystals. Need %d, have %d" % [cost, crystal_count])
	return false

func get_skill_data(skill_id: String) -> SkillData:
	return active_skills.get(skill_id)

func get_player_skill_level(skill_id: String) -> int:
	return player_skill_levels.get(skill_id, 1)

func get_current_level() -> int:
	# Assuming level starts at 1, and stage 0 is the first milestone
	return current_stage_index + 1

func get_next_level_exp() -> int:
	var next_idx = current_stage_index + 1
	if next_idx >= 0 and next_idx < active_stages.size():
		return active_stages[next_idx].req_exp
	return 0

# --- 8. Validation Functions ---

func _validate_mode() -> void:
	var valid_modes = ["test", "trial", "full"]
	if mode not in valid_modes:
		push_error("[ProgressManager] Invalid game mode: '%s'. Valid modes: %s" % [mode, valid_modes])
		push_error("[ProgressManager] Falling back to 'test' mode")
		mode = "test"

func _validate_resources() -> void:
	var errors = []
	var warnings = []
	
	# Build memory ID lookup for validation
	var memory_ids = []
	for mem in active_memories:
		memory_ids.append(mem.id)
	
	# Validate stages
	for stage in active_stages:
		# Check req_exp is valid
		if stage.req_exp < 0:
			errors.append("Stage '%s' has negative req_exp: %d" % [stage.id, stage.req_exp])
		
		# Check memory reference exists
		if stage.unlocks_memory_id and stage.unlocks_memory_id not in memory_ids:
			errors.append("Stage '%s' references missing memory: '%s' (available: %s)" % [stage.id, stage.unlocks_memory_id, memory_ids])
		
		# Check cutscene reference exists
		if not stage.cutscene_id.is_empty() and stage.cutscene_id not in active_cutscenes:
			warnings.append("Stage '%s' references missing cutscene: '%s'" % [stage.id, stage.cutscene_id])
	
	# Report all warnings
	for warning in warnings:
		push_warning("[ProgressManager] " + warning)
	
	# Report all errors and fail if any exist
	for error in errors:
		push_error("[ProgressManager] " + error)
	
	if not errors.is_empty():
		push_error("[ProgressManager] Resource validation FAILED - %d critical error(s) found" % errors.size())
