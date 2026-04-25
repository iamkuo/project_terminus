extends Node

var current_scene = null
@onready var scene_container = get_node("/root/Game/SceneContainer") # Corrected path based on common Godot structure
@onready var animation_player = get_node("/root/Game/GUI/FullscreenUI/AnimationPlayer")
# Updated to reference the renamed ColorRect
@onready var transition_rect = get_node("/root/Game/GUI/FullscreenUI/TransitionColorRect") 
@onready var fullscreen_ui = get_node("/root/Game/GUI/FullscreenUI")

# Signal to be emitted when a scene transition is fully completed
signal scene_transition_finished(scene_name: String)

func _ready() -> void: 
	await get_tree().process_frame
	if scene_container.get_child_count() > 0:
		current_scene = scene_container.get_child(0)

func switch_scene(scene_name: String, transition_type: String):
	call_deferred("_deferred_switch_scene", scene_name, transition_type)

func _deferred_switch_scene(scene_name: String, transition_type: String):
	print("switching scene")
	transition_rect.mouse_filter = Control.MOUSE_FILTER_STOP
	# Show fullscreen_ui so transition_rect (its child) is visible
	fullscreen_ui.show()
	transition_rect.color = Color(0, 0, 0, 0) # Start transparent for fade-in
	transition_rect.show() # Make sure it's visible
	animation_player.play("%s_in" % transition_type)
	await animation_player.animation_finished
	current_scene.queue_free()
	var new_scene = load("res://scenes/%s.tscn" % scene_name)
	current_scene = new_scene.instantiate()
	scene_container.add_child(current_scene)  # Add to the fixed container
	animation_player.play("%s_out" % transition_type)
	await animation_player.animation_finished
	print("scene switched")
	transition_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	transition_rect.hide()

	# Emit signal that transition is complete
	scene_transition_finished.emit(scene_name)
