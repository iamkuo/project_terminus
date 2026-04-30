extends Control
signal elixir_changed(current: int)

@export var max_elixir: int = 10
@export var regen_per_sec: float = 1.0
var current: float = 5.0
var last_update_time: float = 0.0

@onready var elixir_bar: ProgressBar = $ElixirUI/ElixirBar
@onready var elixir_label: Label = $ElixirUI/ElixirLabel
@onready var cards_container: Control = $CardsUI/CardsContainer

var card_scene: PackedScene = preload("res://scenes/battle/ui/card.tscn")
var active_cards: Array[Button] = []

func _ready():
	# Initialize the progress bar
	if elixir_bar:
		elixir_bar.max_value = max_elixir
		elixir_bar.value = current
	# Connect to our own signal to update UI
	elixir_changed.connect(_update_ui)
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
	# Check if any Properties UI is visible and adjust mouse filter
	var all_properties = get_tree().get_nodes_in_group("properties_ui")
	var any_visible = false
	for p in all_properties:
		if p.visible:
			any_visible = true
			break
	
	# CRITICAL: Change mouse_filter to allow clicks through to Properties UI
	# 0 = PASS, 1 = STOP (blocks everything), 2 = IGNORE
	if any_visible:
		mouse_filter = Control.MOUSE_FILTER_IGNORE  # Let clicks pass through
	else:
		mouse_filter = Control.MOUSE_FILTER_STOP   # Normal blocking behavior
	
	# Always allow toggling visibility with TAB even when properties UI is open
	if event.is_action_pressed("ui_accept") or (event is InputEventKey and event.keycode == KEY_TAB and event.pressed):
		visible = not visible
		get_viewport().set_input_as_handled()
		return
	
	# Block other inputs (number keys) when properties UI is visible
	if any_visible:
		return
		
	if event is InputEventKey and event.pressed:
		if event.keycode >= KEY_1 and event.keycode <= KEY_9:
			var index = event.keycode - KEY_1
			if index < active_cards.size():
				var card = active_cards[index]
				if card.has_method("_on_pressed"):
					card._on_pressed()
				get_viewport().set_input_as_handled()

func _process(delta):
	current = min(max_elixir, current + regen_per_sec * delta)
	var now: float = Time.get_ticks_msec() / 1000.0
	if now - last_update_time >= 1.0:
		last_update_time = now
		emit_signal("elixir_changed", int(floor(current)))

func _update_ui(current_amount: int):
	if elixir_bar:
		elixir_bar.value = current_amount
	if elixir_label:
		elixir_label.text = "%d/%d" % [current_amount, max_elixir]

func try_consume(amount: int) -> bool:
	if int(floor(current)) >= amount:
		current -= amount
		emit_signal("elixir_changed", int(floor(current)))
		if elixir_label:
			elixir_label.text = "%d/%d" % [int(floor(current)), max_elixir]
		return true
	return false


func get_current_int() -> int:
	return int(floor(current))

func filter_cards(allowed_ids: Array) -> void:
	for card in active_cards:
		if card.unit_stats and card.unit_stats.unit_id not in allowed_ids:
			card.queue_free()
	active_cards = active_cards.filter(func(c): return is_instance_valid(c))
