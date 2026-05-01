class_name UnitSelectionCircle
extends Node2D

var target_unit: UnitBase = null
var visible_state: bool = false

func _ready():
	visible = false
	z_index = 100

func show_for_unit(unit: UnitBase):
	target_unit = unit
	visible = true

func hide_circle():
	target_unit = null
	visible = false

func _draw():
	if not visible or not target_unit:
		return

	# Account for parent scale to draw correct attack range
	var scale_factor = get_parent().scale.x if get_parent() else 1.0
	var radius = target_unit.stats.attack_distance / scale_factor

	# Draw attack range circle
	draw_arc(Vector2.ZERO, radius, 0, TAU, 64, Color.GREEN, 2.0)

func _process(_delta):
	if visible:
		queue_redraw()
