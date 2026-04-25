extends UnitBase

func _ready():
	super._ready()

func _get_march_destination() -> Vector2:
	return _get_lane_goal_pos()
