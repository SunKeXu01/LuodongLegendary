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
	_create_tracer(source + Vector3(0, 1.05, 0), target + Vector3(0, 0.95, 0), color)
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
	tracer.look_at(to, Vector3.UP)
	var mesh := BoxMesh.new()
	mesh.size = Vector3(0.075, 0.075, length)
	var material := _effect_material(_with_alpha(color, 0.88))
	mesh.material = material
	tracer.mesh = mesh
	add_child(tracer)
	var tween := create_tween()
	tween.tween_property(material, "albedo_color", _with_alpha(color, 0.0), 0.24)
	tween.tween_callback(tracer.queue_free)


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
