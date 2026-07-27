class_name Trail3D
extends MeshInstance3D

# Adapted for Luodong Legendary from the MIT Trail3D implementation by
# Oussama BOUKHELF, updated by JohanAR:
# https://gist.github.com/JohanAR/d4ad3ee23a14296b73ccfc97b6cfc0dd
# Pinned raw revision:
# dd9c8b3a397c2ea8f43056a3b8a6447dc577fa3a

@export var emitting := true
@export var minimum_distance := 0.035
@export var lifetime := 0.24
@export var base_width := 0.58
@export var maximum_points := 24

var trail_color := Color("#f6d77a")
var _target: Node3D
var _points: Array[Dictionary] = []


func _ready() -> void:
	_target = get_parent() as Node3D
	top_level = true
	global_transform = Transform3D.IDENTITY
	mesh = ImmediateMesh.new()
	cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF


func _process(delta: float) -> void:
	for index in range(_points.size() - 1, -1, -1):
		_points[index]["age"] = float(_points[index]["age"]) - delta
		if float(_points[index]["age"]) <= 0.0:
			_points.remove_at(index)
	if emitting and is_instance_valid(_target):
		_sample_target()
	_rebuild_mesh()


func stop_emitting() -> void:
	emitting = false


func _sample_target() -> void:
	var next_position := _target.global_position
	if not _points.is_empty():
		var latest_position: Vector3 = _points[-1]["position"]
		if (
			(next_position - latest_position).length_squared()
			< minimum_distance * minimum_distance
		):
			return
	_points.append({"position": next_position, "age": lifetime})
	if _points.size() > maximum_points:
		_points.pop_front()


func _rebuild_mesh() -> void:
	var immediate_mesh := mesh as ImmediateMesh
	immediate_mesh.clear_surfaces()
	if _points.size() < 2:
		return
	var camera := get_viewport().get_camera_3d()
	if not is_instance_valid(camera):
		return

	immediate_mesh.surface_begin(Mesh.PRIMITIVE_TRIANGLE_STRIP, material_override)
	for index in _points.size():
		var point: Vector3 = _points[index]["position"]
		var previous: Vector3 = _points[maxi(0, index - 1)]["position"]
		var following: Vector3 = _points[mini(_points.size() - 1, index + 1)]["position"]
		var tangent := following - previous
		if tangent.length_squared() < 0.000001:
			tangent = Vector3.FORWARD
		else:
			tangent = tangent.normalized()
		var view_direction := camera.global_position - point
		var normal := view_direction.cross(tangent).normalized()
		if normal.length_squared() < 0.000001:
			normal = Vector3.UP

		var path_factor := float(index) / float(_points.size() - 1)
		var age_factor: float = clampf(float(_points[index]["age"]) / lifetime, 0.0, 1.0)
		var width_profile := sin(path_factor * PI)
		var half_width := base_width * maxf(0.08, width_profile) * 0.5
		var alpha := age_factor * smoothstep(0.0, 0.14, path_factor)
		var vertex_color := Color(
			trail_color.r,
			trail_color.g,
			trail_color.b,
			trail_color.a * alpha
		)
		immediate_mesh.surface_set_color(vertex_color)
		immediate_mesh.surface_set_uv(Vector2(path_factor, 0.0))
		immediate_mesh.surface_add_vertex(point - normal * half_width)
		immediate_mesh.surface_set_color(vertex_color)
		immediate_mesh.surface_set_uv(Vector2(path_factor, 1.0))
		immediate_mesh.surface_add_vertex(point + normal * half_width)
	immediate_mesh.surface_end()
