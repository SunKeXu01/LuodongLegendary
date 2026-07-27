class_name SilentTempleWorld3D
extends CloudFordWorld3D


func screen_to_ground(screen_position: Vector2) -> Vector3:
	var origin := camera.project_ray_origin(screen_position)
	var direction := camera.project_ray_normal(screen_position)
	if absf(direction.y) < 0.0001:
		return Vector3.ZERO
	var distance := -origin.y / direction.y
	var point := origin + direction * distance
	return Vector3(clampf(point.x, -10.4, 10.4), 0.0, clampf(point.z, -7.4, 7.4))


func get_time_label() -> String:
	return "子夜"


func get_weather_label() -> String:
	return "山岚阴雨"


func get_location_label() -> String:
	return "寂音禅院"


func set_mechanism_active(active: bool) -> void:
	if not is_instance_valid(mechanism_marker):
		return
	var label := mechanism_marker.get_node_or_null("机关名牌") as Label3D
	if is_instance_valid(label):
		label.text = "机关总闸" if active else "总闸已关闭"
		label.modulate = Color.WHITE if active else Color("#7d9b88")
	for child in mechanism_marker.get_children():
		if child is MeshInstance3D:
			child.transparency = 0.0 if active else 0.35


func _create_environment() -> void:
	var world_environment := WorldEnvironment.new()
	environment = Environment.new()
	environment.background_mode = Environment.BG_COLOR
	environment.background_color = Color("#121b20")
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.ambient_light_color = Color("#60706a")
	environment.ambient_light_energy = 0.46
	environment.fog_enabled = true
	environment.fog_light_color = Color("#44534f")
	environment.fog_density = 0.034
	environment.fog_height = 1.2
	environment.fog_height_density = 0.18
	world_environment.environment = environment
	world_root.add_child(world_environment)

	sunlight = DirectionalLight3D.new()
	sunlight.rotation_degrees = Vector3(-62, 28, 0)
	sunlight.light_color = Color("#a9b8bb")
	sunlight.light_energy = 0.48
	sunlight.shadow_enabled = true
	world_root.add_child(sunlight)


func _update_environment() -> void:
	if not is_instance_valid(sunlight) or environment == null:
		return
	sunlight.light_energy = 0.46
	environment.fog_density = 0.034


func _create_landscape() -> void:
	_box("禅院石坪", Vector3(0, -0.35, 0), Vector3(23, 0.7, 17), Color("#3d4541"))
	_box("中轴石道", Vector3(0, 0.02, 0), Vector3(3.4, 0.08, 15), Color("#66645b"))
	_box("北侧高台", Vector3(0, 0.15, -5.4), Vector3(10.0, 0.3, 3.2), Color("#4c4d48"))

	_box("南院墙", Vector3(0, 1.2, 8.0), Vector3(23, 2.5, 0.45), Color("#54564e"))
	_box("北院墙", Vector3(0, 1.2, -8.0), Vector3(23, 2.5, 0.45), Color("#454a45"))
	_box("西院墙", Vector3(-11.2, 1.2, 0), Vector3(0.45, 2.5, 16), Color("#4c514b"))
	_box("东院墙", Vector3(11.2, 1.2, 0), Vector3(0.45, 2.5, 16), Color("#4c514b"))
	_box("山门左", Vector3(-2.7, 1.6, 7.2), Vector3(3.2, 3.2, 0.7), Color("#4d3830"))
	_box("山门右", Vector3(2.7, 1.6, 7.2), Vector3(3.2, 3.2, 0.7), Color("#4d3830"))
	_box("山门横匾", Vector3(0, 3.0, 7.2), Vector3(2.4, 0.55, 0.4), Color("#241d19"))

	for index in range(5):
		_box(
			"机关踏板%d" % index,
			Vector3(-2.0 + index, 0.075, 1.3 - (index % 2) * 1.8),
			Vector3(0.72, 0.06, 0.72),
			Color("#7c5748")
		)


func _create_settlement() -> void:
	_temple_hall(Vector3(0, 0, -5.8), Vector3(8.6, 3.6, 3.1), "大雄旧殿")
	_temple_hall(Vector3(-7.7, 0, -2.8), Vector3(4.2, 2.7, 5.0), "西偏殿")
	_temple_hall(Vector3(7.7, 0, -3.5), Vector3(4.2, 2.7, 4.0), "地牢")

	for index in range(4):
		var x := -4.8 + index * 3.2
		_cylinder("廊柱%d" % index, Vector3(x, 1.25, -3.5), 0.18, 2.5, Color("#5d342d"))

	for index in range(5):
		_box(
			"牢栏%d" % index,
			Vector3(6.15 + index * 0.48, 1.0, -1.55),
			Vector3(0.08, 2.0, 0.08),
			Color("#303531"),
			0.55
		)
	_box("牢门横杆", Vector3(7.1, 1.45, -1.55), Vector3(2.2, 0.1, 0.1), Color("#303531"), 0.55)

	mechanism_marker = Node3D.new()
	mechanism_marker.name = "地牢机关总闸"
	mechanism_marker.position = Vector3(-5.0, 0.0, -1.5)
	world_root.add_child(mechanism_marker)
	_add_box_to(
		mechanism_marker, Vector3(0, 0.55, 0), Vector3(0.55, 1.1, 0.55), Color("#3b3029")
	)
	_add_box_to(
		mechanism_marker, Vector3(0, 1.18, 0), Vector3(0.18, 0.75, 0.18), Color("#b7733e")
	)
	var label := Label3D.new()
	label.name = "机关名牌"
	label.text = "机关总闸"
	label.position = Vector3(0, 1.85, 0)
	label.font_size = 28
	label.outline_size = 6
	label.modulate = Color("#efc56f")
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	mechanism_marker.add_child(label)

	var braziers := [
		Vector3(-4.2, 0.7, 5.0), Vector3(4.2, 0.7, 5.0),
		Vector3(-4.2, 0.7, -3.4), Vector3(4.2, 0.7, -3.4),
	]
	for index in braziers.size():
		_create_brazier("火盆%d" % index, braziers[index])


func _create_nature() -> void:
	var cypress_positions := [
		Vector3(-9.5, 0, 5.4), Vector3(9.5, 0, 5.4),
		Vector3(-9.8, 0, -6.5), Vector3(9.8, 0, -6.5),
	]
	for index in cypress_positions.size():
		var at: Vector3 = cypress_positions[index]
		_cylinder("古柏树干%d" % index, at + Vector3(0, 1.25, 0), 0.24, 2.5, Color("#42372e"))
		_sphere("古柏树冠%d" % index, at + Vector3(0, 3.0, 0), 1.0, Color("#283e34"))


func _create_rain() -> void:
	rain = GPUParticles3D.new()
	rain.name = "山岚微雨"
	rain.amount = 160
	rain.lifetime = 2.1
	rain.randomness = 0.45
	rain.visibility_aabb = AABB(Vector3(-12, -10, -12), Vector3(24, 20, 24))
	var particles := ParticleProcessMaterial.new()
	particles.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	particles.emission_box_extents = Vector3(10, 0.5, 8)
	particles.direction = Vector3(-0.08, -1.0, 0.02)
	particles.spread = 4.0
	particles.initial_velocity_min = 6.0
	particles.initial_velocity_max = 8.0
	rain.process_material = particles
	var drop := BoxMesh.new()
	drop.size = Vector3(0.012, 0.32, 0.012)
	var material := StandardMaterial3D.new()
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.albedo_color = Color(0.63, 0.73, 0.76, 0.3)
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	drop.material = material
	rain.draw_pass_1 = drop
	world_root.add_child(rain)


func _create_navigation() -> void:
	var navigation_region := NavigationRegion3D.new()
	navigation_region.name = "寂音禅院导航区域"
	var navigation_mesh := NavigationMesh.new()
	navigation_mesh.agent_radius = 0.34
	navigation_mesh.agent_height = 1.6
	var minimum := Vector2(-10.4, -7.4)
	var maximum := Vector2(10.4, 7.4)
	var columns := 34
	var rows := 28
	var step := Vector2(
		(maximum.x - minimum.x) / float(columns),
		(maximum.y - minimum.y) / float(rows)
	)
	var vertices := PackedVector3Array()
	for row in range(rows + 1):
		for column in range(columns + 1):
			vertices.append(Vector3(
				minimum.x + column * step.x,
				0.08,
				minimum.y + row * step.y
			))
	navigation_mesh.vertices = vertices
	for row in range(rows):
		for column in range(columns):
			var center := Vector2(
				minimum.x + (column + 0.5) * step.x,
				minimum.y + (row + 0.5) * step.y
			)
			if _navigation_cell_blocked(center):
				continue
			var top_left := row * (columns + 1) + column
			var bottom_left := (row + 1) * (columns + 1) + column
			var bottom_right := bottom_left + 1
			var top_right := top_left + 1
			navigation_mesh.add_polygon(PackedInt32Array([
				top_left, bottom_left, bottom_right, top_right
			]))
	navigation_region.navigation_mesh = navigation_mesh
	world_root.add_child(navigation_region)


func _navigation_cell_blocked(point: Vector2) -> bool:
	var obstacle_areas := [
		Rect2(-10.1, -5.5, 4.5, 5.4),
		Rect2(5.6, -5.7, 4.5, 4.4),
		Rect2(-4.6, -7.3, 9.2, 2.5),
	]
	for area in obstacle_areas:
		if area.has_point(point):
			return true
	return false


func _temple_hall(at: Vector3, dimensions: Vector3, hall_name: String) -> void:
	_box(hall_name, at + Vector3(0, dimensions.y * 0.5, 0), dimensions, Color("#615f54"))
	_box(
		"%s屋顶" % hall_name,
		at + Vector3(0, dimensions.y + 0.4, 0),
		Vector3(dimensions.x + 0.8, 0.5, dimensions.z + 0.8),
		Color("#222d2b")
	)


func _create_brazier(node_name: String, at: Vector3) -> void:
	_cylinder(node_name, at, 0.25, 0.65, Color("#342c28"))
	var light := OmniLight3D.new()
	light.name = "%s火光" % node_name
	light.position = at + Vector3(0, 0.55, 0)
	light.light_color = Color("#ff8542")
	light.light_energy = 2.1
	light.omni_range = 4.8
	world_root.add_child(light)


func _add_box_to(
	parent: Node3D,
	at: Vector3,
	dimensions: Vector3,
	color: Color
) -> void:
	var mesh_instance := MeshInstance3D.new()
	mesh_instance.position = at
	var mesh := BoxMesh.new()
	mesh.size = dimensions
	mesh.material = _material(color, 0.0, 0.82)
	mesh_instance.mesh = mesh
	parent.add_child(mesh_instance)
