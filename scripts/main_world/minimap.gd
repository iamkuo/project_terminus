extends Control

## World Minimap Widget
##
## Shows a thumbnail of the world map with an icon tracking the player's position.
## The map image is cropped to a designer-set view_range centred on the player,
## so the player icon is always in the middle.
##
## === TUNING GUIDE (when you have the real map image) ===
## 1. Measure your world in Godot world-units (check player coords at each corner).
## 2. Set world_rect.position = Vector2(left_edge_x, top_edge_y).
## 3. Set world_rect.size    = Vector2(total_width,  total_height).
## 4. The minimap displays world_rect correctly when the MinimapPanel's pixel
##    aspect ratio equals world_rect.size.x / world_rect.size.y.
##
## === ZOOM / VIEW RANGE ===
## view_range defines how many world-space units are visible in the minimap at once
## (centred on the player).  Smaller values = more zoomed-in.
## Example: view_range = Vector2(500, 400) shows a 500×400 world-unit window.

## Active world-space bounding box. Calculated dynamically based on current map.
var world_rect: Rect2 = Rect2(-3000, 0, 6000, 5000)

## Active map image. Set dynamically.
var map_texture: Texture2D

@export_group("Map Textures")
@export var goblin_map_texture: Texture2D
@export var human_map_texture: Texture2D

@export_group("Map World Bounds")
@export var goblin_world_rect: Rect2 = Rect2(-3000, 0, 6000, 5000)
@export var human_world_rect: Rect2 = Rect2(-3000, 0, 6000, 5000)

## Size of the minimap panel in screen pixels.
@export var minimap_size: Vector2 = Vector2(200, 160)

## World-space area shown around the player (zoom window).
## Both axes are clamped so the view never goes outside world_rect.
@export var view_range: Vector2 = Vector2(2000, 1600)

## Size of the player icon in screen pixels.
@export var dot_size: Vector2 = Vector2(24, 24)

# ---- Internal refs ----
@onready var _panel: Panel = $MinimapPanel
@onready var _texture_rect: TextureRect = $MinimapPanel/TextureRect
@onready var _dot: TextureRect = $MinimapPanel/Dot

# AtlasTexture lets us crop the map image to the view_range window each frame.
var _atlas: AtlasTexture

func _ready() -> void:
	_panel.custom_minimum_size = minimap_size
	_panel.size = minimap_size

	_update_current_map()

	# Wrap the map texture in an AtlasTexture so we can crop it per-frame.
	_atlas = AtlasTexture.new()
	if map_texture:
		_atlas.atlas = map_texture
	_texture_rect.texture = _atlas
	_texture_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_texture_rect.stretch_mode = TextureRect.STRETCH_SCALE

	# Size the dot
	_dot.custom_minimum_size = dot_size
	_dot.size = dot_size

func _process(_delta: float) -> void:
	# Toggle visibility
	if Input.is_action_just_pressed("ui_minimap"):
		visible = !visible

	if not visible:
		return

	_update_current_map()

	var player := _get_player()
	if not player:
		return

	_update_map_crop(player.global_position)
	_center_dot()

# Crop the map image so that view_range world-units are visible, centred on player.
func _update_map_crop(player_world_pos: Vector2) -> void:
	if not map_texture or not _atlas:
		return

	# Dynamically update the underlying texture if it changed
	if _atlas.atlas != map_texture:
		_atlas.atlas = map_texture

	var img_size := map_texture.get_size()

	# Half the view range in world units
	var half_view := view_range * 0.5

	# The view window in world space (clamped to world_rect)
	var view_world := Rect2(
		player_world_pos - half_view,
		view_range
	)
	# Clamp so we never pan outside the world_rect
	view_world.position.x = clampf(view_world.position.x,
		world_rect.position.x,
		world_rect.end.x - view_range.x)
	view_world.position.y = clampf(view_world.position.y,
		world_rect.position.y,
		world_rect.end.y - view_range.y)

	# Convert view window from world-space to image-pixel-space
	var world_to_img := img_size / world_rect.size
	var region := Rect2(
		(view_world.position - world_rect.position) * world_to_img,
		view_range * world_to_img
	)
	# Clamp region to image bounds
	region = region.intersection(Rect2(Vector2.ZERO, img_size))
	_atlas.region = region

# Keep the player dot perfectly centred in the panel.
func _center_dot() -> void:
	var panel_size := _panel.size
	_dot.position = (panel_size - _dot.size) * 0.5

func _update_current_map() -> void:
	var path := _get_current_map_path()
	if path.contains("human"):
		map_texture = human_map_texture
		world_rect = human_world_rect
	else:
		# Default to goblin map
		map_texture = goblin_map_texture
		world_rect = goblin_world_rect

func _get_current_map_path() -> String:
	var root := SceneSwitcher.current_scene
	if root:
		var container = root.get_node_or_null("MapContainer")
		if container and container.get_child_count() > 0:
			var current_map = container.get_child(0)
			if current_map:
				return current_map.scene_file_path
	return ""

func _get_player() -> Node2D:
	var root := SceneSwitcher.current_scene
	if root:
		var p := root.get_node_or_null("%Player")
		if is_instance_valid(p):
			return p as Node2D
		p = root.find_child("Player", true, false)
		if is_instance_valid(p):
			return p as Node2D
	return null

