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

	# Account for parent scale to draw correct ranges
	var scale_factor = get_parent().scale.x if get_parent() else 1.0
	
	# Draw detection range circle (view distance)
	var detect_radius = target_unit.stats.view_distance / scale_factor
	draw_arc(Vector2.ZERO, detect_radius, 0, TAU, 128, Color(0.3, 0.7, 1.0, 0.4), 1.5, true)

	# Draw attack range circle
	var attack_radius = target_unit.stats.attack_distance / scale_factor
	draw_arc(Vector2.ZERO, attack_radius, 0, TAU, 128, Color(0.0, 1.0, 0.0, 0.6), 2.0, true)

func _process(_delta):
	if visible:
		queue_redraw()
