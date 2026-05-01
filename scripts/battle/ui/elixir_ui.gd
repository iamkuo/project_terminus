extends Control
signal elixir_changed(current: int)

@export var max_elixir: int = 10
@export var regen_per_sec: float = 1.0
var current: float = 5.0
var last_update_time: float = 0.0

@onready var elixir_bar: ProgressBar = $ElixirBar
@onready var elixir_label: Label = $ElixirLabel

func _ready():
	# Initialize the progress bar
	if elixir_bar:
		elixir_bar.max_value = max_elixir
		elixir_bar.value = current
	# Connect to our own signal to update UI
	elixir_changed.connect(_update_ui)

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
		elixir_label.text = "魔力: %d/%d" % [current_amount, max_elixir]

func try_consume(amount: int) -> bool:
	if int(floor(current)) >= amount:
		current -= amount
		emit_signal("elixir_changed", int(floor(current)))
		if elixir_label:
			elixir_label.text = "魔力: %d/%d" % [int(floor(current)), max_elixir]
		return true
	return false

func get_current_int() -> int:
	return int(floor(current))
