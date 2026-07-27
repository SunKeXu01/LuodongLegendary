class_name MinimapWidget
extends Control

var player: Node3D
var enemies: Array[WuxiaActor3D] = []
var world_rect := Rect2(-11.5, -8.2, 23.0, 15.4)


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	tooltip_text = "云津渡小地图"


func _process(_delta: float) -> void:
	queue_redraw()


func configure(player_actor: Node3D, hostile_actors: Array[WuxiaActor3D]) -> void:
	player = player_actor
	enemies = hostile_actors


func _actor_map_position(actor: Node3D) -> Vector2:
	var world_position: Vector3 = actor.global_position
	var normalized := Vector2(
		(world_position.x - world_rect.position.x) / world_rect.size.x,
		(world_position.z - world_rect.position.y) / world_rect.size.y
	)
	return Vector2(18, 18) + normalized * (size - Vector2(36, 36))


func _draw() -> void:
	var center := size * 0.5
	var radius := minf(size.x, size.y) * 0.5 - 4.0
	draw_circle(center, radius, Color(0.025, 0.04, 0.035, 0.94))
	draw_arc(center, radius, 0.0, TAU, 80, Color("#b89452"), 2.0)
	draw_arc(center, radius - 7.0, 0.0, TAU, 80, Color(0.26, 0.39, 0.31, 0.8), 1.0)

	var river := PackedVector2Array([
		Vector2(17, 98), Vector2(48, 82), Vector2(80, 88),
		Vector2(113, 66), Vector2(153, 72), Vector2(171, 56)
	])
	draw_polyline(river, Color(0.24, 0.48, 0.54, 0.75), 8.0, true)
	draw_polyline(river, Color(0.5, 0.72, 0.72, 0.55), 2.0, true)
	draw_line(Vector2(34, 132), Vector2(146, 33), Color(0.47, 0.42, 0.27, 0.6), 3.0)

	for enemy in enemies:
		if is_instance_valid(enemy):
			draw_circle(_actor_map_position(enemy), 4.0, Color("#d45249"))
	if is_instance_valid(player):
		var point := _actor_map_position(player)
		draw_circle(point, 6.0, Color("#e9cf72"))
		draw_arc(point, 8.0, 0.0, TAU, 20, Color("#fff0a6"), 1.5)
