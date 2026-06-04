extends Node2D

@export_multiline var sign_texts: Array[String]

var activated: bool = false
var is_reading: bool = false

func _process(_delta: float) -> void:
	if activated and not is_reading and Input.is_action_just_pressed("ui_skip"):
		if GuiManager.current_state == GuiManager.gui_state.READY:
			_read_sign()

func _read_sign() -> void:
	is_reading = true
	for text in sign_texts:
		GuiManager.play_dialog(text)
		await GuiManager.dialog_finished
	
	GuiManager.hide_gui()
	
	# Wait one frame before unflagging is_reading to prevent the same "ui_skip" input
	# from immediately re-triggering the sign in _process.
	await get_tree().process_frame
	activated = false
	is_reading = false

func _on_body_entered(body: Node2D) -> void:
	if body.is_in_group("player"):
		activated = true

func _on_body_exited(body: Node2D) -> void:
	if body.is_in_group("player"):
		activated = false
