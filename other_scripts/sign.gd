extends Node2D

@export_multiline var sign_texts : Array[String]

var player_in_range : bool = false

func _process(_delta: float) -> void:
	if player_in_range and Input.is_action_just_pressed("ui_skip"):
		print("sign triggered")
		if GuiManager.current_state == GuiManager.gui_state.READY:
			GuiManager.queue_texts(sign_texts)
			player_in_range = false

func _on_body_entered(_body: Node2D) -> void:
	player_in_range = true

func _on_body_exited(_body: Node2D) -> void:
	player_in_range = false
