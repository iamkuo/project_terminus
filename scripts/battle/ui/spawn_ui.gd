extends Control

@onready var cards_container: Control = $CardsUI/CardsContainer

var card_scene: PackedScene = preload("res://scenes/battle/ui/card.tscn")
var active_cards: Array[Button] = []

func _ready():
	# Auto-generate cards from unit stats resources
	_generate_cards()

func _generate_cards():
	var stats_dir = "res://resources/unit_stats/"
	var dir = DirAccess.open(stats_dir)
	if not dir:
		push_warning("Cannot open unit stats directory: " + stats_dir)
		return
	
	var files = dir.get_files()
	for file in files:
		file = file.trim_suffix(".remap")
		if file.ends_with(".tres") or file.ends_with(".res"):
			var stats_path = stats_dir + file
			var stats = load(stats_path)
			if stats and stats is UnitStats and stats.team == 0:
				_create_card(stats)

func _create_card(stats: UnitStats):
	var card = card_scene.instantiate()
	card.unit_stats = stats
	
	# Priority for node name: display_name > unit_id > None
	var node_name = stats.display_name
	if node_name == "": node_name = stats.unit_id
	if node_name == "": node_name = "None"
	
	card.name = node_name
	cards_container.add_child(card)
	active_cards.append(card)
	
	# Pass the hotkey number to the card for display
	if card.has_method("set_hotkey"):
		card.call("set_hotkey", str(active_cards.size()))

func _input(event: InputEvent) -> void:
	# Check if any Properties UI is visible
	var all_properties = get_tree().get_nodes_in_group("properties_ui")
	var any_visible = false
	for p in all_properties:
		if p.visible:
			any_visible = true
			break
	
	# CRITICAL: Disable SpawnUI entirely when Properties UI is open due to CanvasLayer priority
	if any_visible:
		# Only allow TAB to toggle visibility when Properties UI is open
		if event.is_action_pressed("ui_accept") or (event is InputEventKey and event.keycode == KEY_TAB and event.pressed):
			visible = not visible
			get_viewport().set_input_as_handled()
		return  # Block all other input when Properties UI is open
	
	# Normal input handling when no Properties UI is visible
	if event.is_action_pressed("ui_accept") or (event is InputEventKey and event.keycode == KEY_TAB and event.pressed):
		visible = not visible
		get_viewport().set_input_as_handled()
		return
		
	if event is InputEventKey and event.pressed:
		if event.keycode >= KEY_1 and event.keycode <= KEY_9:
			var index = event.keycode - KEY_1
			if index < active_cards.size():
				var card = active_cards[index]
				if card.has_method("_on_pressed"):
					card._on_pressed()
				get_viewport().set_input_as_handled()


func filter_cards(allowed_ids: Array) -> void:
	for card in active_cards:
		if card.unit_stats and card.unit_stats.unit_id not in allowed_ids:
			card.queue_free()
	active_cards = active_cards.filter(func(c): return is_instance_valid(c))
