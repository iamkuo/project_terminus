class_name RestrictionArea
extends Area2D

# Reference to the owning tower.
# This will be set by TowerBase during _ready().
@export var tower: Node = null

func set_tower(t: Node) -> void:
    tower = t

func _ready():
    # No special initialization needed for now.
    pass
