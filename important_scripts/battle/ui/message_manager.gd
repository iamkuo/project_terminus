extends Node

var message_label: Label
var hide_timer: Timer

func _ready() -> void:
	# Wait for the scene tree to be ready
	await get_tree().process_frame
	
	# Find the MessageUI node in the Main scene
	var main_scene = get_tree().current_scene
	var ui: CanvasLayer = main_scene.get_node_or_null("UI")
	var message_ui: Control = ui.get_node_or_null("MessageUI")
	if message_ui:
		message_label = message_ui.get_node_or_null("MessageLabel")
		hide_timer = message_ui.get_node_or_null("HideTimer")
		
	if message_label and hide_timer:
		message_label.text = ""
		message_label.hide()
		hide_timer.timeout.connect(_on_timer_timeout)

func show_message(msg: String, duration: float = 2.0) -> void:
	message_label.text = msg
	message_label.show()
	hide_timer.start(duration)

func _on_timer_timeout() -> void:
	message_label.hide()
