extends Control

@onready var health_bar : ProgressBar = $ProgressBar
@onready var health_label : Label = $Label

func _ready():
	$"..".health_changed.connect(_on_health_bar_changed)
	call_deferred("_initialize_health_display")

func _initialize_health_display():
	var parent = get_parent()
	if parent and "stats" in parent and parent.stats:
		_on_health_bar_changed(parent.current_health, parent.stats.health)

func _on_health_bar_changed(value: int, max_health: int):
	health_label.text = str(value)
	
	if max_health > 0:
		health_bar.value = 100.0 * float(value) / float(max_health)
	else:
		health_bar.value = 0.0
	
