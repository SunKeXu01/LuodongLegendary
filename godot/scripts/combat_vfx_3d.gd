class_name CombatVfx3D
extends Node3D


func play_skill(skill_name: String, source: Vector3, target: Vector3) -> void:
	var color := Color("#ebcf72")
	if skill_name == "伏虎掌":
		color = Color("#d48a4f")
	elif skill_name == "机弩术":
		color = Color("#77c8bd")
	elif skill_name == "敌人反击":
		color = Color("#c14e48")
	if skill_name == "机弩术":
		_create_tracer(source + Vector3(0, 1.05, 0), target + Vector3(0, 0.95, 0), color)
	else:
		_create_weapon_arc(
			source + Vector3(0, 0.82, 0),
			target + Vector3(0, 0.92, 0),
			color,
			skill_name == "伏虎掌"
		)
	_create_impact(target + Vector3(0, 0.9, 0), color)


func play_move_marker(at: Vector3) -> void:
	var marker := MeshInstance3D.new()
	marker.position = at + Vector3(0, 0.06, 0)
	var mesh := CylinderMesh.new()
	mesh.top_radius = 0.36
	mesh.bottom_radius = 0.36
	mesh.height = 0.025
	var material := _effect_material(Color(0.94, 0.75, 0.28, 0.58))
	mesh.material = material
	marker.mesh = mesh
	add_child(marker)
	marker.scale = Vector3(0.35, 1.0, 0.35)
	var tween := create_tween()
	tween.set_parallel(true)
	tween.tween_property(marker, "scale", Vector3(1.25, 1.0, 1.25), 0.48)
	tween.tween_property(material, "albedo_color", Color(0.94, 0.75, 0.28, 0.0), 0.48)
	tween.set_parallel(false)
	tween.tween_callback(marker.queue_free)


func _create_tracer(from: Vector3, to: Vector3, color: Color) -> void:
	var direction := to - from
	var length := maxf(0.1, direction.length())
	var tracer := MeshInstance3D.new()
	tracer.position = (from + to) * 0.5
	add_child(tracer)
	tracer.look_at(to, Vector3.UP)
	var mesh := BoxMesh.new()
	mesh.size = Vector3(0.075, 0.075, length)
	var material := _effect_material(_with_alpha(color, 0.88))
	mesh.material = material
	tracer.mesh = mesh
	var tween := create_tween()
	tween.tween_property(material, "albedo_color", _with_alpha(color, 0.0), 0.24)
	tween.tween_callback(tracer.queue_free)


func _create_weapon_arc(
	from: Vector3,
	to: Vector3,
	color: Color,
	heavy := false
) -> void:
	var direction := to - from
	direction.y = 0.0
	if direction.length_squared() < 0.0001:
		direction = Vector3.FORWARD
	else:
		direction = direction.normalized()
	var side := Vector3(-direction.z, 0.0, direction.x)
	var start := from - side * (0.72 if heavy else 0.54) + Vector3(0, 0.16, 0)
	var control := (from + to) * 0.5 + side * (0.82 if heavy else 0.62)
	control.y += 1.05 if heavy else 0.76
	var finish := to + side * (0.42 if heavy else 0.3) - Vector3(0, 0.12, 0)

	var trail_tip := Node3D.new()
	trail_tip.name = "武学刀光轨迹"
	add_child(trail_tip)
	trail_tip.global_position = start
	var trail := Trail3D.new()
	trail.name = "MIT三维拖尾"
	trail.lifetime = 0.3 if heavy else 0.24
	trail.base_width = 0.78 if heavy else 0.56
	trail.maximum_points = 28
	trail.trail_color = _with_alpha(color.lightened(0.18), 0.94)
	var material := _effect_material(Color.WHITE)
	material.vertex_color_use_as_albedo = true
	material.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.no_depth_test = true
	trail.material_override = material
	trail_tip.add_child(trail)

	var update_arc := func(progress: float) -> void:
		var inverse := 1.0 - progress
		trail_tip.global_position = (
			start * inverse * inverse
			+ control * 2.0 * inverse * progress
			+ finish * progress * progress
		)
	var tween := create_tween()
	tween.tween_method(update_arc, 0.0, 1.0, 0.24 if heavy else 0.18)
	tween.tween_callback(trail.stop_emitting)
	tween.tween_interval(trail.lifetime + 0.08)
	tween.tween_callback(trail_tip.queue_free)


func _create_impact(at: Vector3, color: Color) -> void:
	var impact := MeshInstance3D.new()
	impact.position = at
	var mesh := SphereMesh.new()
	mesh.radius = 0.3
	mesh.height = 0.6
	mesh.radial_segments = 12
	mesh.rings = 6
	var material := _effect_material(_with_alpha(color, 0.72))
	mesh.material = material
	impact.mesh = mesh
	impact.scale = Vector3(0.25, 0.25, 0.25)
	add_child(impact)
	var tween := create_tween()
	tween.set_parallel(true)
	tween.tween_property(impact, "scale", Vector3(1.5, 1.5, 1.5), 0.34)
	tween.tween_property(material, "albedo_color", _with_alpha(color, 0.0), 0.34)
	tween.set_parallel(false)
	tween.tween_callback(impact.queue_free)


func _effect_material(color: Color) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.albedo_color = color
	return material


func _with_alpha(color: Color, alpha: float) -> Color:
	return Color(color.r, color.g, color.b, alpha)
