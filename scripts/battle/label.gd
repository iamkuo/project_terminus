extends Control

@onready var health_bar : ProgressBar = $ProgressBar
@onready var health_label : Label = $Label
var health_value :int
# Called when the node enters the scene tree for the first time.
func _ready():
	# Connect to health changed signal
	$"..".health_changed.connect(_on_health_bar_changed)
	
	# Wait for next frame to ensure unit is fully initialized
	call_deferred("_initialize_health_display")

func _initialize_health_display():
	var parent = get_parent()
	if parent and "current_health" in parent:
		var max_hp = 0
		if parent.has_method("get_max_health"):
			max_hp = parent.get_max_health()
		elif "stats" in parent and parent.stats and parent.stats.health > 0:
			max_hp = parent.stats.health
		else:
			max_hp = parent.current_health if parent.current_health > 0 else 100  # Fallback
		
		# Only initialize if we have valid health values
		if parent.current_health > 0 and max_hp > 0:
			_on_health_bar_changed(parent.current_health, max_hp)
	else:
		# Parent does not have current_health property
		pass

func _on_health_bar_changed(value, _max_health):
	# Update health label
	if health_label:
		health_label.text = str(value)
	
	# Update health bar if it exists and is valid
	if health_bar and is_instance_valid(health_bar):
		if _max_health > 0:
			health_bar.value = 100.0 * float(value) / float(_max_health)
		else:
			health_bar.value = 0.0
	
