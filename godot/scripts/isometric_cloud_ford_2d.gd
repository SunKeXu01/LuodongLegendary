class_name IsometricCloudFord2D
extends Node2D

const MAP_SIZE := Vector2i(48, 48)
const TILE_SIZE := Vector2i(128, 64)
const ATLAS_PATH := "res://assets/isometric/tiles/cloud_ford_ground_atlas.png"
const PAINTED_INN_PATH := (
	"res://assets/isometric/buildings/riverside_inn-painted-v1.png"
)
const SPAWN_CELL := Vector2i(23, 35)
const MOVE_SPEED := 270.0
const BUILDING_FOOTPRINTS := [
	Rect2i(15, 32, 5, 5),
	Rect2i(27, 32, 6, 5),
	Rect2i(12, 25, 5, 5),
	Rect2i(28, 22, 5, 5),
	Rect2i(14, 14, 5, 5),
	Rect2i(26, 10, 5, 5),
]

var ground_layer: TileMapLayer
var detail_layer: TileMapLayer
var sorted_world: Node2D
var foreground_world: Node2D
var player: Node2D
var camera: Camera2D
var navigation := AStarGrid2D.new()
var navigation_path: Array[Vector2i] = []
var roof_entries: Array[Dictionary] = []
var location_label: Label
var path_label: Label
var target_marker: Polygon2D


func _ready() -> void:
	RenderingServer.set_default_clear_color(Color("#111b1a"))
	_create_tile_layers()
	_create_navigation()
	_create_environment()
	_create_player()
	_create_camera()
	_create_hud()
	_update_location_label(SPAWN_CELL)


func _process(delta: float) -> void:
	_move_player(delta)
	camera.position = camera.position.lerp(player.position, minf(1.0, delta * 6.0))
	_update_roof_fade(delta)


func _unhandled_input(event: InputEvent) -> void:
	if not (
		event is InputEventMouseButton
		and event.button_index == MOUSE_BUTTON_LEFT
		and event.pressed
	):
		return
	var local_mouse := ground_layer.to_local(get_global_mouse_position())
	_set_destination(ground_layer.local_to_map(local_mouse))


func _create_tile_layers() -> void:
	var tile_set := TileSet.new()
	tile_set.tile_size = TILE_SIZE
	tile_set.tile_shape = TileSet.TILE_SHAPE_ISOMETRIC
	tile_set.tile_layout = TileSet.TILE_LAYOUT_DIAMOND_DOWN
	var atlas := TileSetAtlasSource.new()
	atlas.texture = load(ATLAS_PATH) as Texture2D
	atlas.texture_region_size = TILE_SIZE
	for row in 3:
		for column in 4:
			atlas.create_tile(Vector2i(column, row))
	tile_set.add_source(atlas, 0)

	ground_layer = TileMapLayer.new()
	ground_layer.name = "手绘地表"
	ground_layer.tile_set = tile_set
	ground_layer.z_index = -10
	add_child(ground_layer)

	detail_layer = TileMapLayer.new()
	detail_layer.name = "手绘道路"
	detail_layer.tile_set = tile_set
	detail_layer.z_index = -9
	add_child(detail_layer)

	for y in MAP_SIZE.y:
		for x in MAP_SIZE.x:
			var cell := Vector2i(x, y)
			var variant := absi(x * 17 + y * 31 + x * y * 3) % 4
			var atlas_row := 2 if x >= 34 else 0
			ground_layer.set_cell(cell, 0, Vector2i(variant, atlas_row))
			if _is_road(cell):
				detail_layer.set_cell(cell, 0, Vector2i(variant, 1))


func _is_road(cell: Vector2i) -> bool:
	var north_south := cell.x >= 21 and cell.x <= 25
	var river_approach := (
		cell.y >= 20 and cell.y <= 23 and cell.x >= 8 and cell.x <= 39
	)
	var market_square := (
		cell.x >= 16 and cell.x <= 30 and cell.y >= 27 and cell.y <= 34
	)
	return north_south or river_approach or market_square


func _is_walkable(cell: Vector2i) -> bool:
	if not Rect2i(Vector2i.ZERO, MAP_SIZE).has_point(cell):
		return false
	for footprint in BUILDING_FOOTPRINTS:
		if footprint.has_point(cell):
			return false
	if cell.x < 34:
		return true
	return cell.y >= 20 and cell.y <= 23 and cell.x <= 39


func _create_navigation() -> void:
	navigation.region = Rect2i(Vector2i.ZERO, MAP_SIZE)
	navigation.diagonal_mode = AStarGrid2D.DIAGONAL_MODE_ONLY_IF_NO_OBSTACLES
	navigation.default_compute_heuristic = AStarGrid2D.HEURISTIC_OCTILE
	navigation.default_estimate_heuristic = AStarGrid2D.HEURISTIC_OCTILE
	navigation.update()
	for y in MAP_SIZE.y:
		for x in MAP_SIZE.x:
			var cell := Vector2i(x, y)
			navigation.set_point_solid(cell, not _is_walkable(cell))


func _create_environment() -> void:
	sorted_world = Node2D.new()
	sorted_world.name = "足底Y排序层"
	sorted_world.y_sort_enabled = true
	add_child(sorted_world)

	foreground_world = Node2D.new()
	foreground_world.name = "屋顶前景层"
	foreground_world.z_index = 20
	add_child(foreground_world)

	_create_building(Vector2i(17, 34), "鲁氏铁铺", Color("#7e4738"))
	_create_painted_inn(Vector2i(29, 34))
	_create_building(Vector2i(14, 27), "云津货栈", Color("#74503b"))
	_create_building(Vector2i(30, 24), "听雨茶亭", Color("#765b48"))
	_create_building(Vector2i(16, 16), "渡口民居", Color("#765b48"))
	_create_building(Vector2i(28, 12), "北门行栈", Color("#6e4938"))
	_create_pier()
	_create_trees()

	target_marker = Polygon2D.new()
	target_marker.name = "鼠标目的地"
	target_marker.polygon = PackedVector2Array([
		Vector2(0, -9), Vector2(18, 0), Vector2(0, 9), Vector2(-18, 0)
	])
	target_marker.color = Color(0.88, 0.71, 0.3, 0.0)
	target_marker.z_index = 18
	add_child(target_marker)


func _create_painted_inn(cell: Vector2i) -> void:
	var world_position := ground_layer.map_to_local(cell)
	var inn := Node2D.new()
	inn.name = "临河客栈_手绘精修"
	inn.position = world_position
	foreground_world.add_child(inn)

	var shadow := _add_polygon(
		inn,
		_circle_points(Vector2(0, -4), 132.0, 20, 0.34),
		Color(0.015, 0.025, 0.02, 0.34)
	)
	shadow.z_index = -1
	var painted_sprite := Sprite2D.new()
	painted_sprite.name = "临河客栈手绘建筑"
	painted_sprite.texture = load(PAINTED_INN_PATH) as Texture2D
	painted_sprite.position = Vector2(0, -126)
	painted_sprite.scale = Vector2(0.34, 0.34)
	inn.add_child(painted_sprite)

	var title := Label.new()
	title.text = "临河客栈"
	title.position = Vector2(-52, -300)
	title.size = Vector2(104, 24)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 15)
	title.add_theme_color_override("font_color", Color("#ead7a8"))
	inn.add_child(title)
	roof_entries.append({
		"node": inn,
		"position": world_position,
		"radius": 212.0,
	})


func _create_building(cell: Vector2i, title: String, wall_color: Color) -> void:
	var world_position := ground_layer.map_to_local(cell)
	var body := Node2D.new()
	body.name = title + "下层"
	body.position = world_position
	sorted_world.add_child(body)

	_add_polygon(
		body,
		PackedVector2Array([
			Vector2(-72, -88), Vector2(0, -52), Vector2(72, -88),
			Vector2(72, 2), Vector2(0, 40), Vector2(-72, 2)
		]),
		wall_color.darkened(0.08)
	)
	_add_polygon(
		body,
		PackedVector2Array([
			Vector2(0, -52), Vector2(72, -88), Vector2(72, 2), Vector2(0, 40)
		]),
		wall_color.darkened(0.22)
	)
	_add_polygon(
		body,
		PackedVector2Array([
			Vector2(-18, -22), Vector2(10, -8), Vector2(10, 31), Vector2(-18, 17)
		]),
		Color("#392b25")
	)
	var sign := Label.new()
	sign.text = title
	sign.position = Vector2(-45, -70)
	sign.size = Vector2(90, 24)
	sign.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	sign.add_theme_font_size_override("font_size", 14)
	sign.add_theme_color_override("font_color", Color("#ead7a8"))
	body.add_child(sign)

	var roof := Node2D.new()
	roof.name = title + "屋顶"
	roof.position = world_position
	foreground_world.add_child(roof)
	_add_polygon(
		roof,
		PackedVector2Array([
			Vector2(-94, -91), Vector2(0, -139), Vector2(94, -91),
			Vector2(0, -42)
		]),
		Color("#243c3a")
	)
	_add_polygon(
		roof,
		PackedVector2Array([
			Vector2(-94, -91), Vector2(0, -42), Vector2(0, -30),
			Vector2(-104, -82)
		]),
		Color("#182d2c")
	)
	_add_polygon(
		roof,
		PackedVector2Array([
			Vector2(94, -91), Vector2(0, -42), Vector2(0, -30),
			Vector2(104, -82)
		]),
		Color("#142827")
	)
	roof_entries.append({
		"node": roof,
		"position": world_position,
		"radius": 128.0,
	})


func _create_pier() -> void:
	for index in 8:
		var cell := Vector2i(34 + index, 21)
		var plank := Node2D.new()
		plank.name = "渡口木栈_%02d" % index
		plank.position = ground_layer.map_to_local(cell)
		sorted_world.add_child(plank)
		_add_polygon(
			plank,
			PackedVector2Array([
				Vector2(-63, -28), Vector2(0, -4), Vector2(63, -28),
				Vector2(0, 4)
			]),
			Color("#6c5138").lightened(float(index % 3) * 0.04)
		)


func _create_trees() -> void:
	var tree_cells := [
		Vector2i(9, 34), Vector2i(11, 28), Vector2i(31, 37),
		Vector2i(8, 20), Vector2i(31, 19), Vector2i(12, 12),
		Vector2i(30, 8), Vector2i(18, 7)
	]
	for index in tree_cells.size():
		var tree := Node2D.new()
		tree.name = "水墨树_%02d" % index
		tree.position = ground_layer.map_to_local(tree_cells[index])
		sorted_world.add_child(tree)
		_add_polygon(
			tree,
			PackedVector2Array([
				Vector2(-7, -60), Vector2(7, -60), Vector2(11, 12), Vector2(-8, 12)
			]),
			Color("#46382c")
		)
		for crown_index in 3:
			var crown := _add_polygon(
				tree,
				_circle_points(
					Vector2((crown_index - 1) * 22, -78 - abs(crown_index - 1) * 8),
					38.0,
					12
				),
				Color("#26443b").lightened(float(crown_index) * 0.035)
			)
			crown.z_index = 3


func _create_player() -> void:
	player = Node2D.new()
	player.name = "青灰长衫剑客占位精灵"
	player.position = ground_layer.map_to_local(SPAWN_CELL)
	sorted_world.add_child(player)

	var shadow := _add_polygon(
		player,
		_circle_points(Vector2(0, 4), 20.0, 16, 0.42),
		Color(0.02, 0.03, 0.025, 0.42)
	)
	shadow.z_index = -1
	_add_polygon(
		player,
		PackedVector2Array([
			Vector2(-17, -54), Vector2(15, -54), Vector2(26, -9),
			Vector2(9, 4), Vector2(-22, -5)
		]),
		Color("#53665d")
	)
	_add_polygon(
		player,
		PackedVector2Array([
			Vector2(-17, -45), Vector2(-37, -20), Vector2(-24, -14), Vector2(-8, -32)
		]),
		Color("#465950")
	)
	_add_polygon(
		player,
		PackedVector2Array([
			Vector2(13, -44), Vector2(34, -22), Vector2(25, -13), Vector2(6, -31)
		]),
		Color("#3d5049")
	)
	_add_polygon(
		player,
		_circle_points(Vector2(0, -70), 13.5, 16),
		Color("#c89c79")
	)
	_add_polygon(
		player,
		PackedVector2Array([
			Vector2(-13, -75), Vector2(-7, -88), Vector2(8, -88),
			Vector2(14, -74), Vector2(5, -81), Vector2(-7, -80)
		]),
		Color("#1d2422")
	)
	_add_polygon(
		player,
		PackedVector2Array([
			Vector2(16, -49), Vector2(21, -47), Vector2(-16, 8), Vector2(-22, 5)
		]),
		Color("#c1a25c")
	)
	var nameplate := Label.new()
	nameplate.text = "云津少侠"
	nameplate.position = Vector2(-50, -112)
	nameplate.size = Vector2(100, 24)
	nameplate.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	nameplate.add_theme_font_size_override("font_size", 15)
	nameplate.add_theme_color_override("font_color", Color("#f1e3bc"))
	player.add_child(nameplate)


func _create_camera() -> void:
	camera = Camera2D.new()
	camera.name = "等轴测镜头"
	camera.position = player.position
	camera.zoom = Vector2(0.82, 0.82)
	camera.position_smoothing_enabled = false
	add_child(camera)


func _create_hud() -> void:
	var hud := CanvasLayer.new()
	hud.name = "2.5D原型界面"
	hud.layer = 80
	add_child(hud)

	var top_bar := ColorRect.new()
	top_bar.position = Vector2(22, 18)
	top_bar.size = Vector2(1236, 64)
	top_bar.color = Color(0.025, 0.045, 0.04, 0.94)
	top_bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hud.add_child(top_bar)

	var title := Label.new()
	title.text = "泺 栋 传 奇　｜　云津渡 · 手绘等轴测原型"
	title.position = Vector2(24, 10)
	title.size = Vector2(620, 38)
	title.add_theme_font_size_override("font_size", 23)
	title.add_theme_color_override("font_color", Color("#dfc178"))
	top_bar.add_child(title)

	location_label = Label.new()
	location_label.position = Vector2(680, 11)
	location_label.size = Vector2(255, 30)
	location_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	location_label.add_theme_font_size_override("font_size", 14)
	location_label.add_theme_color_override("font_color", Color("#b8c5b8"))
	top_bar.add_child(location_label)

	path_label = Label.new()
	path_label.text = "鼠标左键：寻路移动"
	path_label.position = Vector2(945, 11)
	path_label.size = Vector2(255, 30)
	path_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	path_label.add_theme_font_size_override("font_size", 14)
	path_label.add_theme_color_override("font_color", Color("#c9ad68"))
	top_bar.add_child(path_label)

	var note := Label.new()
	note.text = "原型阶段：地表瓦片已手绘化；人物与建筑正在按八方向精灵规范替换"
	note.position = Vector2(24, 672)
	note.size = Vector2(720, 28)
	note.add_theme_font_size_override("font_size", 14)
	note.add_theme_color_override("font_color", Color("#d8cda9"))
	var note_back := ColorRect.new()
	note_back.position = Vector2(14, 662)
	note_back.size = Vector2(750, 45)
	note_back.color = Color(0.025, 0.045, 0.04, 0.9)
	hud.add_child(note_back)
	hud.add_child(note)

	var return_button := Button.new()
	return_button.name = "返回主界面"
	return_button.text = "返回角色界面"
	return_button.position = Vector2(1088, 664)
	return_button.size = Vector2(170, 42)
	return_button.add_theme_font_size_override("font_size", 15)
	return_button.add_theme_color_override("font_color", Color("#e2d4aa"))
	return_button.add_theme_stylebox_override(
		"normal",
		_panel_style(Color("#15231f"), Color("#8d7445"))
	)
	return_button.add_theme_stylebox_override(
		"hover",
		_panel_style(Color("#24392f"), Color("#c3a45f"))
	)
	return_button.pressed.connect(_return_to_main)
	hud.add_child(return_button)


func _set_destination(cell: Vector2i) -> bool:
	if not _is_walkable(cell):
		path_label.text = "此处不可通行"
		return false
	var current_cell := ground_layer.local_to_map(
		ground_layer.to_local(player.position)
	)
	navigation_path = navigation.get_id_path(current_cell, cell, true)
	if not navigation_path.is_empty() and navigation_path[0] == current_cell:
		navigation_path.pop_front()
	target_marker.position = ground_layer.map_to_local(cell)
	target_marker.color.a = 0.82
	path_label.text = "寻路：%d 格" % navigation_path.size()
	_update_location_label(cell)
	return true


func _move_player(delta: float) -> void:
	if navigation_path.is_empty():
		target_marker.color.a = move_toward(target_marker.color.a, 0.0, delta * 2.5)
		return
	var target_cell := navigation_path[0]
	var target_position := ground_layer.map_to_local(target_cell)
	var previous_x := player.position.x
	player.position = player.position.move_toward(target_position, MOVE_SPEED * delta)
	if absf(player.position.x - previous_x) > 0.1:
		player.scale.x = 1.0 if player.position.x >= previous_x else -1.0
	if player.position.distance_to(target_position) <= 2.0:
		player.position = target_position
		navigation_path.pop_front()
		if navigation_path.is_empty():
			path_label.text = "已抵达"


func _update_roof_fade(delta: float) -> void:
	for entry in roof_entries:
		var roof := entry["node"] as Node2D
		var roof_position: Vector2 = entry["position"]
		var radius: float = entry["radius"]
		var behind_roof := (
			player.position.distance_to(roof_position) < radius
			and player.position.y < roof_position.y + 52.0
		)
		var target_alpha := 0.22 if behind_roof else 1.0
		roof.modulate.a = move_toward(roof.modulate.a, target_alpha, delta * 3.5)


func _update_location_label(cell: Vector2i) -> void:
	var district := "渡口商埠"
	if cell.x >= 34:
		district = "云津木栈"
	elif cell.y <= 15:
		district = "北门商路"
	elif cell.y >= 34:
		district = "南市入口"
	location_label.text = "%s　(%d, %d)" % [district, cell.x, cell.y]


func _return_to_main() -> void:
	get_tree().change_scene_to_file("res://scenes/main.tscn")


func _panel_style(background: Color, border: Color) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = background
	style.border_color = border
	style.set_border_width_all(1)
	style.corner_radius_top_left = 3
	style.corner_radius_top_right = 3
	style.corner_radius_bottom_left = 3
	style.corner_radius_bottom_right = 3
	return style


func _add_polygon(
	parent: Node,
	points: PackedVector2Array,
	color: Color
) -> Polygon2D:
	var polygon := Polygon2D.new()
	polygon.polygon = points
	polygon.color = color
	parent.add_child(polygon)
	return polygon


func _circle_points(
	center: Vector2,
	radius: float,
	segments: int,
	y_scale := 1.0
) -> PackedVector2Array:
	var points := PackedVector2Array()
	for index in segments:
		var angle := TAU * float(index) / float(segments)
		points.append(
			center + Vector2(cos(angle) * radius, sin(angle) * radius * y_scale)
		)
	return points
