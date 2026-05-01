extends Node

# =============================
# Constants and Exports
# =============================
@export var show_speed: float = 0.05  # 每個字元顯示的秒數

# =============================
# UI References
# =============================
var dialog: Control
var text_label: Label
var text_end: Label
@onready var fullscreen_ui: Control
# Removed: @onready var color_rect: ColorRect  # This was the shared ColorRect
@onready var dialog_color_rect: ColorRect # New reference for dialog overlay
@onready var fullscreen_label: Label
@onready var texture_rect: TextureRect

# =============================
# State Variables
# =============================
var main_queue: Array[Dictionary] = []
var dialog_tween: Tween = null
var fullscreen_tween: Tween = null
var current_state = gui_state.READY
enum gui_state {
	READY,
	DIALOG_READING,
	DIALOG_FINISHED,
	FULLSCREEN_READING,
	FULLSCREEN_FINISHED
}

# =============================
# Signals
# =============================

signal dialog_finished()
signal fullscreen_finished()

# =============================
# Lifecycle
# =============================

func _ready() -> void:
	await get_tree().process_frame
	print("GUI Manager: Initializing...")
	dialog = get_node("/root/Game/GUI/Dialog") as Control
	text_label = dialog.get_node("HBoxContainer/Label") as Label
	text_end = dialog.get_node("HBoxContainer/End") as Label
	
	fullscreen_ui = get_node("/root/Game/GUI/FullscreenUI") as Control
	dialog_color_rect = fullscreen_ui.get_node("DialogOverlay") as ColorRect 
	fullscreen_label = fullscreen_ui.get_node("Label") as Label
	texture_rect = fullscreen_ui.get_node("TextureRect") as TextureRect
	
	print("GUI Manager: Nodes initialized successfully")
	dialog.hide()
	fullscreen_ui.hide()
	_change_state(gui_state.READY)
	
func _process(_delta: float) -> void:
	# Process unified state machine
	match current_state:
		gui_state.READY:
			if not main_queue.is_empty():
				var cmd = main_queue.pop_front()
				match cmd.type:
					"dialog":
						_show_dialog_logic(cmd.content)
					"fullscreen":
						_show_fullscreen_logic(cmd.content)
		
		gui_state.DIALOG_READING:
			if Input.is_action_just_pressed("ui_skip"):
				_skip_typing(dialog_tween, text_label)
		
		gui_state.DIALOG_FINISHED:
			if Input.is_action_just_pressed("ui_skip"):
				_advance_queue("dialog")

		gui_state.FULLSCREEN_READING:
			if Input.is_action_just_pressed("ui_skip"):
				_skip_typing(fullscreen_tween, fullscreen_label)
		
		gui_state.FULLSCREEN_FINISHED:
			if Input.is_action_just_pressed("ui_skip"):
				_advance_queue("fullscreen")

# =============================
# Public API
# =============================

func queue_text(text: String) -> void:
	print("GUI Manager: Queueing text: ", text)
	main_queue.push_back({"type" : "dialog","content" : text})
	
func queue_texts(texts: Array[String]) -> void:
	print("GUI Manager: Queueing ", texts.size(), " texts")
	for t in texts:
		print("GUI Manager: - ", t)
		main_queue.push_back({"type" : "dialog","content" : t})

func queue_fullscreen(item_data: Dictionary) -> void:
		main_queue.push_back({"type": "fullscreen", "content": item_data})

# =============================
# Helper Functions
# =============================

func _change_state(next_state: int) -> void:
	# var previous_state = current_state
	current_state = next_state as gui_state
	# print("GUI state changed from %s to %s" % [gui_state.keys()[previous_state],
	# gui_state.keys()[current_state]])ss
	
func _advance_queue(finished_type: String) -> void:
	# 決定是否要隱藏當前 UI：
	# 如果下一個指令跟現在類型不同，或是隊列空了，才隱藏
	if main_queue.is_empty() or main_queue[0].type != finished_type: _reset_all_ui()

	# 發送訊號讓 CutsceneManager 知道這一步跑完了
	if finished_type == "dialog": emit_signal("dialog_finished")
	else: emit_signal("fullscreen_finished")
	
	_change_state(gui_state.READY)
	
func _reset_all_ui() -> void:
	if dialog_tween and dialog_tween.is_running():
		dialog_tween.kill()
		dialog_tween = null
	if fullscreen_tween and fullscreen_tween.is_running():
		fullscreen_tween.kill()
		fullscreen_tween = null
	
	dialog.hide()
	text_end.hide()
	fullscreen_ui.hide()
	fullscreen_label.hide()
	texture_rect.hide()
	dialog_color_rect.hide()
	
	# Clean up texture to free memory
	texture_rect.texture = null

func _skip_typing(tween: Tween, label: Label) -> void:
	if tween and tween.is_running():
		tween.kill()
		label.visible_ratio = 1.0
		# 根據目前狀態手動觸發轉場
		if current_state == gui_state.DIALOG_READING:
			_change_state(gui_state.DIALOG_FINISHED)
		elif current_state == gui_state.FULLSCREEN_READING:
			_change_state(gui_state.FULLSCREEN_FINISHED)

func _show_dialog_logic(text: String) -> void:
	#_reset_all_ui()
	# Ensure dialog and its overlay are visible and reset properties.
	dialog.show()
	
	_change_state(gui_state.DIALOG_READING)
	
	text_label.visible_ratio = 0
	text_label.text = text
	dialog_tween = create_tween()
	dialog_tween.tween_property(text_label, "visible_ratio", 1.0, len(text) * show_speed)
	
	dialog_tween.finished.connect(func(): _change_state(gui_state.DIALOG_FINISHED))

func _show_fullscreen_logic(data: Dictionary) -> void:
	#_reset_all_ui()
	_change_state(gui_state.FULLSCREEN_READING)
	if not fullscreen_ui.is_visible():
		fullscreen_ui.show()
	if not dialog_color_rect.is_visible():
		dialog_color_rect.show()
		# Reset properties in case they were modified or not set correctly before.
		dialog_color_rect.modulate.a = 1.0
		dialog_color_rect.color = Color(0, 0, 0, 1)
		dialog_color_rect.scale = Vector2(1, 1)
	
	match data.type:
		"text":
			fullscreen_label.visible_ratio = 0
			fullscreen_label.text = data.text
			fullscreen_label.show()
			fullscreen_tween = create_tween()
			fullscreen_tween.tween_property(fullscreen_label, "visible_ratio", 1.0, len(data.text) * show_speed)
			fullscreen_tween.finished.connect(func(): _change_state(gui_state.FULLSCREEN_FINISHED))
		"image":
			texture_rect.show()
			texture_rect.texture = data.texture
			_change_state(gui_state.FULLSCREEN_FINISHED)
