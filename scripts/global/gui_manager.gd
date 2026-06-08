extends Node

# =============================
# Constants and Exports
# =============================
@export var show_speed: float = 0.08 # 每個字元顯示的秒數

# =============================
# UI References
# =============================
var dialog: Control
var text_label: Label
var text_end: Label
@onready var fullscreen_ui: Control
@onready var fullscreen_label: Label
@onready var texture_rect: TextureRect
var animation_player: AnimationPlayer
var transition_rect: ColorRect

# =============================
# State Variables
# =============================
var dialog_tween: Tween = null
var fullscreen_tween: Tween = null
var is_transitioning: bool = false
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
	dialog = get_node("/root/Game/GUI/Dialog") as Control
	text_label = dialog.get_node("HBoxContainer/Label") as Label
	text_end = dialog.get_node("HBoxContainer/End") as Label
	fullscreen_ui = get_node("/root/Game/GUI/FullscreenUI") as Control
	fullscreen_label = fullscreen_ui.get_node("Label") as Label
	texture_rect = fullscreen_ui.get_node("TextureRect") as TextureRect
	animation_player = fullscreen_ui.get_node("AnimationPlayer") as AnimationPlayer
	transition_rect = fullscreen_ui.get_node("TransitionColorRect") as ColorRect
	
	dialog.hide()
	fullscreen_ui.hide()
	_change_state(gui_state.READY)
	
func _process(_delta: float) -> void:
	# Pure input handling — no queue polling
	match current_state:
		gui_state.DIALOG_READING:
			if Input.is_action_just_pressed("ui_skip"):
				_skip_typing(dialog_tween, text_label)
		
		gui_state.DIALOG_FINISHED:
			if Input.is_action_just_pressed("ui_skip"):
				_change_state(gui_state.READY)
				emit_signal("dialog_finished")

		gui_state.FULLSCREEN_READING:
			if Input.is_action_just_pressed("ui_skip"):
				_skip_typing(fullscreen_tween, fullscreen_label)
		
		gui_state.FULLSCREEN_FINISHED:
			if Input.is_action_just_pressed("ui_skip"):
				_change_state(gui_state.READY)
				emit_signal("fullscreen_finished")

# =============================
# Public API (View layer)
# =============================

## Show a dialog line with an optional fullscreen background image.
## The background image is fully opaque; the dialog panel becomes semi-transparent over it.
func play_dialog(text: String, background_image: Texture2D = null) -> void:
	_show_dialog_logic(text, background_image)

## Show fullscreen content (text or image).
func play_fullscreen(item_data: Dictionary) -> void:
	_show_fullscreen_logic(item_data)

## Hide all GUI elements and reset state. Call this when the cutscene ends.
func hide_gui() -> void:
	_reset_all_ui()
	_change_state(gui_state.READY)

# Legacy wrappers kept for non-cutscene callers (battle messages, etc.)
func queue_text(text: String) -> void:
	play_dialog(text)

func queue_dialog(text: String, background_image: Texture2D = null) -> void:
	play_dialog(text, background_image)

func queue_texts(texts: Array[String]) -> void:
	# Non-cutscene callers: play first immediately; remaining must be chained by caller
	for t in texts:
		play_dialog(t)

func queue_fullscreen(item_data: Dictionary) -> void:
	play_fullscreen(item_data)

# =============================
# Helper Functions
# =============================

func _change_state(next_state: int) -> void:
	current_state = next_state as gui_state
	if text_end:
		text_end.visible = (current_state == gui_state.DIALOG_FINISHED)

func _reset_all_ui() -> void:
	if dialog_tween and dialog_tween.is_running():
		dialog_tween.kill()
		dialog_tween = null
	if fullscreen_tween and fullscreen_tween.is_running():
		fullscreen_tween.kill()
		fullscreen_tween = null
	
	dialog.hide()
	dialog.modulate.a = 1.0
	text_end.hide()
	
	fullscreen_label.hide()
	texture_rect.hide()
	texture_rect.texture = null

	# Only touch transition and fullscreen_ui root if not transitioning
	if not is_transitioning:
		transition_rect.hide()
		transition_rect.color = Color(0, 0, 0, 0)
		fullscreen_ui.hide()

func _skip_typing(tween: Tween, label: Label) -> void:
	if tween and tween.is_running():
		tween.kill()
		label.visible_ratio = 1.0
		# Manually advance state on skip
		if current_state == gui_state.DIALOG_READING:
			_change_state(gui_state.DIALOG_FINISHED)
		elif current_state == gui_state.FULLSCREEN_READING:
			_change_state(gui_state.FULLSCREEN_FINISHED)

func _show_dialog_logic(text: String, background_image: Texture2D = null) -> void:
	_reset_all_ui()
	
	# 1. Show Dialog Panel
	dialog.show()
	
	# 2. Handle Portrait / Background Image
	if background_image:
		fullscreen_ui.show()
		texture_rect.show()
		texture_rect.texture = background_image
		texture_rect.modulate.a = 1.0  # Image fully opaque
		dialog.modulate.a = 0.5        # Dialog box semi-transparent over the image
		
	# 3. Setup State & Tween
	_change_state(gui_state.DIALOG_READING)
	text_label.visible_ratio = 0
	text_label.text = text
	dialog_tween = create_tween()
	dialog_tween.tween_property(text_label, "visible_ratio", 1.0, len(text) * show_speed)
	dialog_tween.finished.connect(func(): _change_state(gui_state.DIALOG_FINISHED))

func _show_fullscreen_logic(data: Dictionary) -> void:
	_reset_all_ui()
	
	_change_state(gui_state.FULLSCREEN_READING)
	fullscreen_ui.show()
	
	match data.type:
		"text":
			# Show semi-transparent black overlay only for text (no background image)
			transition_rect.show()
			if not is_transitioning:
				transition_rect.color = Color(0, 0, 0, 1)
			fullscreen_label.visible_ratio = 0
			fullscreen_label.text = data.text
			fullscreen_label.show()
			fullscreen_tween = create_tween()
			fullscreen_tween.tween_property(fullscreen_label, "visible_ratio", 1.0, len(data.text) * show_speed)
			fullscreen_tween.finished.connect(func(): _change_state(gui_state.FULLSCREEN_FINISHED))
		"image":
			# No dim overlay when displaying a fullscreen image
			texture_rect.show()
			texture_rect.texture = data.texture
			_change_state(gui_state.FULLSCREEN_FINISHED)

# =============================
# Transition Functions
# =============================

# 統一處理「退場動畫」（畫面被遮住）
func transition_out(type: String = "none") -> void:
	is_transitioning = true
	transition_rect.mouse_filter = Control.MOUSE_FILTER_STOP
	if fullscreen_ui:
		fullscreen_ui.show()
	transition_rect.show()
	
	var animation_name = "%s_in" % type
	if not animation_player.has_animation(animation_name):
		animation_name = "none_in"
	
	animation_player.play(animation_name)
	await animation_player.animation_finished

# 統一處理「進場動畫」（畫面重新亮起）
func transition_in(type: String = "none") -> void:
	var animation_name = "%s_out" % type
	if not animation_player.has_animation(animation_name):
		animation_name = "none_out"
	
	animation_player.play(animation_name)
	await animation_player.animation_finished
	
	transition_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	transition_rect.hide()
	is_transitioning = false
