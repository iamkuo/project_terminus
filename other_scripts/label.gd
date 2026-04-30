extends Control

@onready var health_bar : ProgressBar = $ProgressBar
@onready var health_label : Label = $Label
var health_value :int
# Called when the node enters the scene tree for the first time.
func _ready():
	pass
	$"..".health_changed.connect(_on_health_bar_changed)

	# call_deferred("_on_health_bar_changed", health_label.text, health_bar.health)

func _on_health_bar_changed(value,a):
	print("New health received: ", value) # 'value' is the data from the signal
# Called every frame. 'delta' is the elapsed time since the previous frame.
	pass
	if health_bar != null:
		health_label.text = str(value)
	else:
		health_label.text = str(value)
		return
		
		
	
	if not is_instance_valid(health_bar):
		return
	
