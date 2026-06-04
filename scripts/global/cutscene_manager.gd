extends Node

@export var scripts: Array[CutsceneScript]

var _script_map = {}
var is_playing = false # Track if a cutscene is currently playing
var _queue: Array[String] = [] # Queue of cutscene IDs waiting to play

signal cutscene_finished(cutscene_id: String)

func _ready() -> void:
	ProgressManager.gamemode_changed.connect(_reload_cutscenes)
	_reload_cutscenes()

func _reload_cutscenes() -> void:
	scripts.clear()
	_script_map.clear()
	
	var paths_to_search: Array[String] = ["res://resources/mode_data/global/cutscenes/"]
	
	var mode = ProgressManager.mode
	if mode != "":
		var mode_path = "res://resources/mode_data/" + mode + "/cutscenes/"
		if DirAccess.dir_exists_absolute(mode_path):
			paths_to_search.append(mode_path)
	
	while paths_to_search.size() > 0:
		var current_path = paths_to_search.pop_back()
		var dir = DirAccess.open(current_path)
		if not dir:
			push_error("Failed to open directory: " + current_path)
			continue
		
		dir.list_dir_begin()
		var file_name = dir.get_next()
		
		while file_name != "":
			var full_path = current_path.path_join(file_name)
			if dir.current_is_dir():
				if not file_name.begins_with("."):
					paths_to_search.append(full_path + "/")
			else:
				var res_path = full_path.trim_suffix(".remap") if full_path.ends_with(".remap") else full_path
				if res_path.ends_with(".tres"):
					var cutscene_script = load(res_path) as CutsceneScript
					if cutscene_script:
						scripts.append(cutscene_script)
						# print("Loaded cutscene: ", file_name)
					else:
						push_warning("Failed to load cutscene script: " + file_name)
			file_name = dir.get_next()
		
		dir.list_dir_end()
	
	# 建立 ID → Script 對照表
	for script in scripts:
		_script_map[script.id] = script

# =============================
# 對外 API
# =============================
func play(id: String) -> void:
	print("playing cutscene " + id)
	# Validate cutscene exists
	if not _script_map.has(id):
		push_error("Cutscene ID not found: " + id)
		return
	
	# If already playing or transitioning, queue this cutscene for later
	if is_playing or GuiManager.is_transitioning:
		_queue.append(id)
		
		# If we are transitioning, ensure we listen for the end of it
		if GuiManager.is_transitioning and not SceneSwitcher.scene_transition_finished.is_connected(_on_scene_transition_finished):
			SceneSwitcher.scene_transition_finished.connect(_on_scene_transition_finished, CONNECT_ONE_SHOT)
		return
	
	is_playing = true
	await _play_impl(id)
	is_playing = false
	cutscene_finished.emit(id)
	
	# Play next queued cutscene if any
	_play_next_queued()

func _on_scene_transition_finished(_scene_name: String) -> void:
	# Wait a frame to ensure GUI is fully settled
	await get_tree().process_frame
	_play_next_queued()

func _play_next_queued() -> void:
	if _queue.size() > 0:
		var next_id = _queue.pop_front()
		play(next_id)

func _play_impl(id: String) -> void:
	# Run the cutscene script
	var script = _script_map[id]
	for step in script.steps:
		# Run each step based on type
		match step.type:
			CutsceneStep.StepType.DIALOG:
				GuiManager.play_dialog("%s: %s" % [step.speaker, step.text], step.texture)
				await GuiManager.dialog_finished # 等待 GUI 宣告播放完畢

			CutsceneStep.StepType.FULLSCREEN_TEXT:
				GuiManager.play_fullscreen({"type": "text", "text": step.text})
				await GuiManager.fullscreen_finished

			CutsceneStep.StepType.FULLSCREEN_IMAGE:
				GuiManager.play_fullscreen({"type": "image", "texture": step.texture})
				await GuiManager.fullscreen_finished

	# All steps done — Controller is responsible for closing the View
	GuiManager.hide_gui()
