extends Node

# --- 1. 常數與資源路徑 ---
const PATH_STAGES = "res://resources/stages/"
const PATH_MEMORIES = "res://resources/memories/"
const PATH_SKILLS = "res://resources/skills/"
const PATH_CUTSCENES = "res://resources/cutscenes/"
const PATH_ORDERS = "res://resources/memories/orders/"
const FALLBACK_ID = "default_failure_cutscene"

# --- 2. 玩家數據與狀態 ---
var mode: String = "test"
var crystal_count: int = 1000
var _current_exp: int = 0

var current_exp: int = 0:
	set(value):
		if value != _current_exp:
			_current_exp = value
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

# --- 5. 初始化流程 ---

func _ready() -> void:
	# 初始化基礎資源
	var stage_map = _load_resources(PATH_STAGES + mode + "/", StageData)
	active_stages.assign(stage_map.values())
	active_stages.sort_custom(func(a, b): return a.req_exp < b.req_exp)
	
	active_skills = _load_resources(PATH_SKILLS, SkillData)
	# Initialize player skill levels for all active skills
	for skill_id in active_skills:
		if not player_skill_levels.has(skill_id):
			player_skill_levels[skill_id] = 1
	active_cutscenes = _load_resources(PATH_CUTSCENES, CutsceneScript)
	
	# 初始化記憶系統 (因涉及排序邏輯，保留獨立提取)
	var all_mems = _load_resources(PATH_MEMORIES, MemoryData)
	var order_path = PATH_ORDERS + mode + "_memory_order.tres"
	var order_res = load(order_path) as MemoryOrder
	if order_res:
		for mem_id in order_res.ordered_memory_ids:
			if mem_id in all_mems: active_memories.append(all_mems[mem_id])
	
	_check_stage_progression()

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
		print("advanced stage to " + str(current_stage_index) + " at exp " + str(current_exp))
		
		# Unlock the memory shard associated with this stage (if any)
		if stage.unlocks_memory_id:
			collect_memory(stage.unlocks_memory_id)
		
		# 處理劇情觸發 (原本的 _handle_stage_unlock 與 _handle_cutscene_fallback 已合併)
		if stage.cutscene_id.is_empty():
			data_updated.emit()
		elif stage.cutscene_id in active_cutscenes:
			CutsceneManager.play(stage.cutscene_id)
		else:
			push_error("[PlayerDataManager] 資源遺失: %s" % stage.cutscene_id)
			if FALLBACK_ID in active_cutscenes:
				CutsceneManager.play(FALLBACK_ID)
			else:
				for mem in active_memories:
					if mem.cutscene_id == FALLBACK_ID:
						collect_memory(mem.id)
						break

# --- 7. 通用工具與對外接口 ---

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

func collect_memory(id: String) -> void:
	if id not in unlocked_memory_ids:
		unlocked_memory_ids.append(id)
		print("Signal emitted: memory_collected for ID ", id)
		memory_collected.emit(id)
		data_updated.emit()
	else:
		print("Memory already collected: ", id)

func upgrade_player_skill(id: String) -> bool:
	var skill = active_skills.get(id)
	var lv = player_skill_levels.get(id, 1)
	if not skill: return false
	
	var cost = int(skill.base_cost * pow(1.5, lv - 1))
	if crystal_count >= cost:
		crystal_count -= cost
		player_skill_levels[id] = lv + 1
		data_updated.emit()
		return true
	return false

func get_skill_data(skill_id: String) -> SkillData:
	return active_skills.get(skill_id)

func get_player_skill_level(skill_id: String) -> int:
	return player_skill_levels.get(skill_id, 1)
