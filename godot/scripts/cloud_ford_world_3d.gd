class_name CloudFordWorld3D
extends SubViewportContainer

var world_viewport: SubViewport
var world_root: Node3D
var camera: Camera3D
var follow_target: Node3D
var camera_offset := Vector3(0.0, 15.5, 18.5)
var combat_vfx: CombatVfx3D
var environment: Environment
var sunlight: DirectionalLight3D
var world_time := 0.31
var time_scale := 1.0 / 240.0
var lantern_lights: Array[OmniLight3D] = []
var occluder_groups: Array[Dictionary] = []
var rain: GPUParticles3D
var camera_shake := 0.0
var camera_shake_phase := 0.0
var mechanism_marker: Node3D


func _ready() -> void:
	position = Vector2.ZERO
	size = Vector2(1280, 720)
	stretch = true
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	z_index = -100
	_create_viewport()
	_create_environment()
	_create_landscape()
	_create_settlement()
	_create_nature()
	_create_rain()
	_create_navigation()


func _create_viewport() -> void:
	world_viewport = SubViewport.new()
	world_viewport.size = Vector2i(1280, 720)
	world_viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	world_viewport.msaa_3d = Viewport.MSAA_4X
	add_child(world_viewport)

	world_root = Node3D.new()
	world_viewport.add_child(world_root)
	combat_vfx = CombatVfx3D.new()
	combat_vfx.name = "战斗特效"
	world_root.add_child(combat_vfx)

	camera = Camera3D.new()
	camera.position = Vector3(0.0, 15.5, 18.5)
	camera.fov = 43.0
	camera.look_at_from_position(camera.position, Vector3(0.2, 0.0, -2.0))
	world_root.add_child(camera)


func _process(delta: float) -> void:
	world_time = fposmod(world_time + delta * time_scale, 1.0)
	_update_environment()
	if not is_instance_valid(follow_target) or not is_instance_valid(camera):
		return
	var focus := follow_target.global_position + Vector3(0.0, 0.0, -1.6)
	var desired := focus + camera_offset
	if camera_shake > 0.001:
		camera_shake_phase += delta * 38.0
		desired += Vector3(
			sin(camera_shake_phase * 1.7),
			cos(camera_shake_phase * 2.3),
			sin(camera_shake_phase * 2.9)
		) * camera_shake
		camera_shake = move_toward(camera_shake, 0.0, delta * 1.35)
	camera.global_position = camera.global_position.lerp(desired, minf(1.0, delta * 2.8))
	camera.look_at(focus, Vector3.UP)
	if is_instance_valid(rain):
		rain.global_position = focus + Vector3(0, 8, 0)
	_update_occluders(delta)


func add_actor(actor: Node3D) -> void:
	world_root.add_child(actor)


func set_follow_target(actor: Node3D) -> void:
	follow_target = actor


func shake_camera(intensity: float) -> void:
	camera_shake = maxf(camera_shake, intensity)


func set_world_time(value: float) -> void:
	world_time = fposmod(value, 1.0)
	_update_environment()


func get_world_time() -> float:
	return world_time


func get_time_label() -> String:
	var hour := int(world_time * 24.0) % 24
	if hour < 5:
		return "寅时"
	if hour < 7:
		return "卯时"
	if hour < 9:
		return "辰时"
	if hour < 11:
		return "巳时"
	if hour < 13:
		return "午时"
	if hour < 15:
		return "未时"
	if hour < 17:
		return "申时"
	if hour < 19:
		return "酉时"
	if hour < 21:
		return "戌时"
	return "亥时"


func get_weather_label() -> String:
	return "薄雾细雨"


func get_location_label() -> String:
	return "云津渡"


func set_mechanism_active(_active: bool) -> void:
	pass


func screen_to_ground(screen_position: Vector2) -> Vector3:
	var origin := camera.project_ray_origin(screen_position)
	var direction := camera.project_ray_normal(screen_position)
	if absf(direction.y) < 0.0001:
		return Vector3.ZERO
	var distance := -origin.y / direction.y
	var point := origin + direction * distance
	return Vector3(clampf(point.x, -11.5, 11.5), 0.0, clampf(point.z, -8.2, 7.2))


func world_to_screen(world_position: Vector3) -> Vector2:
	return camera.unproject_position(world_position)


func play_skill_effect(skill_name: String, source: Vector3, target: Vector3) -> void:
	combat_vfx.play_skill(skill_name, source, target)


func show_move_marker(at: Vector3) -> void:
	combat_vfx.play_move_marker(at)


func _create_navigation() -> void:
	var navigation_region := NavigationRegion3D.new()
	navigation_region.name = "云津渡导航区域"
	var navigation_mesh := NavigationMesh.new()
	navigation_mesh.agent_radius = 0.34
	navigation_mesh.agent_height = 1.6

	var minimum := Vector2(-11.5, -8.2)
	var maximum := Vector2(4.8, 7.2)
	var columns := 30
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
	var building_areas := [
		Rect2(-10.95, -7.6, 4.9, 3.8),
		Rect2(-5.45, -7.85, 4.7, 3.5),
		Rect2(0.55, -7.75, 5.3, 3.9),
		Rect2(-11.5, 3.0, 4.45, 3.8),
	]
	for area in building_areas:
		if area.has_point(point):
			return true
	return false


func _create_environment() -> void:
	var world_environment := WorldEnvironment.new()
	environment = Environment.new()
	environment.background_mode = Environment.BG_COLOR
	environment.background_color = Color("#9aab98")
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.ambient_light_color = Color("#d7d1b8")
	environment.ambient_light_energy = 0.62
	environment.fog_enabled = true
	environment.fog_light_color = Color("#aeb8a4")
	environment.fog_density = 0.018
	environment.fog_height = 2.0
	environment.fog_height_density = 0.12
	world_environment.environment = environment
	world_root.add_child(world_environment)

	sunlight = DirectionalLight3D.new()
	sunlight.rotation_degrees = Vector3(-54.0, -32.0, 0.0)
	sunlight.light_color = Color("#f3d8a3")
	sunlight.light_energy = 1.25
	sunlight.shadow_enabled = true
	world_root.add_child(sunlight)
	_update_environment()


func _update_environment() -> void:
	if not is_instance_valid(sunlight) or environment == null:
		return
	var sun_angle := world_time * TAU - PI * 0.5
	var daylight := clampf(sin(sun_angle) * 0.65 + 0.55, 0.08, 1.0)
	var twilight := 1.0 - absf(world_time - 0.73) * 8.0
	twilight = clampf(twilight, 0.0, 1.0)
	sunlight.rotation_degrees = Vector3(
		-12.0 - daylight * 62.0,
		world_time * 360.0 - 90.0,
		0.0
	)
	sunlight.light_energy = 0.12 + daylight * 1.25
	sunlight.light_color = Color("#f2c27f").lerp(Color("#fff0ca"), daylight)
	environment.background_color = Color("#182735").lerp(Color("#91a899"), daylight)
	environment.ambient_light_color = Color("#344a5c").lerp(
		Color("#d7d1b8"), daylight
	)
	environment.ambient_light_energy = 0.34 + daylight * 0.42
	environment.fog_light_color = Color("#465c66").lerp(
		Color("#aeb8a4"), daylight
	)
	environment.fog_density = 0.026 - daylight * 0.009 + twilight * 0.006
	var lantern_energy := clampf((0.48 - daylight) * 5.0, 0.0, 1.0) * 2.25
	for lantern in lantern_lights:
		if is_instance_valid(lantern):
			lantern.light_energy = lantern_energy


func _create_landscape() -> void:
	_box("渡口地面", Vector3(0, -0.35, -1), Vector3(26, 0.7, 17), Color("#667558"))
	_box("商道路面", Vector3(-1.0, 0.02, -1.2), Vector3(5.0, 0.08, 17), Color("#8f8062"))
	_box("河道", Vector3(8.7, -0.05, -1.0), Vector3(7.6, 0.18, 17.0), Color("#477b82"), 0.18)

	for index in range(9):
		_box(
			"桥板%d" % index,
			Vector3(5.5 + index * 0.82, 0.34, 1.0),
			Vector3(0.74, 0.16, 2.5),
			Color("#745538")
		)
	_box("桥栏左", Vector3(8.7, 0.82, -0.15), Vector3(7.5, 0.12, 0.12), Color("#4d382a"))
	_box("桥栏右", Vector3(8.7, 0.82, 2.15), Vector3(7.5, 0.12, 0.12), Color("#4d382a"))

	for index in range(6):
		_box(
			"远山%d" % index,
			Vector3(-12.0 + index * 5.0, 2.1 + index % 2, -10.5),
			Vector3(6.0, 4.5 + index % 2, 3.0),
			Color("#4c5f4e")
		)


func _create_settlement() -> void:
	_house(Vector3(-8.5, 0.0, -5.7), Vector3(4.1, 2.8, 3.0), Color("#aa9a75"))
	_house(Vector3(-3.1, 0.0, -6.1), Vector3(3.8, 2.5, 2.8), Color("#988667"))
	_house(Vector3(3.2, 0.0, -5.8), Vector3(4.4, 3.1, 3.1), Color("#b4a17a"))
	_house(Vector3(-9.5, 0.0, 4.9), Vector3(3.8, 2.6, 2.9), Color("#9f8c69"))

	_box("牌坊横梁", Vector3(-0.6, 3.0, -3.8), Vector3(4.2, 0.35, 0.4), Color("#4c3025"))
	_box("牌坊左柱", Vector3(-2.25, 1.45, -3.8), Vector3(0.35, 3.1, 0.35), Color("#56362a"))
	_box("牌坊右柱", Vector3(1.05, 1.45, -3.8), Vector3(0.35, 3.1, 0.35), Color("#56362a"))

	for index in range(5):
		_box(
			"摊位%d" % index,
			Vector3(-6.5 + index * 2.4, 0.55, 1.8 + (index % 2) * 1.4),
			Vector3(1.4, 1.1, 0.9),
			Color("#77664b")
		)
	var lantern_positions := [
		Vector3(-2.2, 2.15, -3.4),
		Vector3(1.0, 2.15, -3.4),
		Vector3(-6.1, 1.9, 1.7),
		Vector3(3.5, 1.9, 3.0),
	]
	for index in lantern_positions.size():
		_create_lantern("灯笼%d" % index, lantern_positions[index])


func _create_nature() -> void:
	var tree_positions := [
		Vector3(-11.0, 0.0, -1.5), Vector3(-7.0, 0.0, -3.2),
		Vector3(4.3, 0.0, -3.7), Vector3(-11.2, 0.0, 6.2),
		Vector3(3.8, 0.0, 5.8), Vector3(5.0, 0.0, 3.8)
	]
	for index in tree_positions.size():
		var at: Vector3 = tree_positions[index]
		_cylinder("树干%d" % index, at + Vector3(0, 1.05, 0), 0.22, 2.1, Color("#58422f"))
		_sphere("树冠%d" % index, at + Vector3(0, 2.65, 0), 1.35, Color("#3e6748"))
		_sphere("树冠侧%d" % index, at + Vector3(0.75, 2.35, 0.1), 0.85, Color("#527657"))


func _house(at: Vector3, dimensions: Vector3, wall_color: Color) -> void:
	var body := _box(
		"屋身", at + Vector3(0, dimensions.y * 0.5, 0), dimensions, wall_color
	)
	var roof := _box(
		"屋顶",
		at + Vector3(0, dimensions.y + 0.35, 0),
		Vector3(dimensions.x + 0.7, 0.42, dimensions.z + 0.75),
		Color("#293b36")
	)
	var door := _box(
		"门",
		at + Vector3(0, 0.85, dimensions.z * 0.505),
		Vector3(0.75, 1.7, 0.08),
		Color("#4b3026")
	)
	occluder_groups.append({
		"center": at,
		"size": Vector2(dimensions.x + 1.1, dimensions.z + 1.1),
		"meshes": [body, roof, door],
	})


func _update_occluders(delta: float) -> void:
	if not is_instance_valid(follow_target):
		return
	var player_xz := Vector2(follow_target.global_position.x, follow_target.global_position.z)
	for group in occluder_groups:
		var center: Vector3 = group["center"]
		var dimensions: Vector2 = group["size"]
		var area := Rect2(
			Vector2(center.x, center.z) - dimensions * 0.5,
			dimensions
		)
		var should_fade := area.grow(0.8).has_point(player_xz)
		var target_alpha := 0.58 if should_fade else 0.0
		for mesh in group["meshes"]:
			if is_instance_valid(mesh):
				mesh.transparency = move_toward(
					mesh.transparency, target_alpha, delta * 2.8
				)


func _create_lantern(node_name: String, at: Vector3) -> void:
	var lantern := _box(node_name, at, Vector3(0.22, 0.34, 0.22), Color("#b6412f"))
	var material := lantern.mesh.material as StandardMaterial3D
	material.emission_enabled = true
	material.emission = Color("#ff9b45")
	material.emission_energy_multiplier = 1.8
	var light := OmniLight3D.new()
	light.name = "%s光源" % node_name
	light.position = at
	light.light_color = Color("#ffb45e")
	light.omni_range = 4.2
	light.shadow_enabled = false
	world_root.add_child(light)
	lantern_lights.append(light)


func _create_rain() -> void:
	rain = GPUParticles3D.new()
	rain.name = "薄雾细雨"
	rain.amount = 320
	rain.lifetime = 1.8
	rain.randomness = 0.35
	rain.visibility_aabb = AABB(Vector3(-12, -10, -12), Vector3(24, 20, 24))
	var particles := ParticleProcessMaterial.new()
	particles.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	particles.emission_box_extents = Vector3(11, 0.5, 9)
	particles.direction = Vector3(-0.12, -1.0, 0.05)
	particles.spread = 5.0
	particles.initial_velocity_min = 8.0
	particles.initial_velocity_max = 11.0
	particles.gravity = Vector3(0, -3.0, 0)
	rain.process_material = particles
	var drop := BoxMesh.new()
	drop.size = Vector3(0.018, 0.42, 0.018)
	var drop_material := StandardMaterial3D.new()
	drop_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	drop_material.albedo_color = Color(0.72, 0.84, 0.88, 0.42)
	drop_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	drop.material = drop_material
	rain.draw_pass_1 = drop
	world_root.add_child(rain)


func _box(
	node_name: String,
	at: Vector3,
	dimensions: Vector3,
	color: Color,
	metallic := 0.0
) -> MeshInstance3D:
	var mesh_instance := MeshInstance3D.new()
	mesh_instance.name = node_name
	mesh_instance.position = at
	var mesh := BoxMesh.new()
	mesh.size = dimensions
	mesh.material = _material(color, metallic, 0.78)
	mesh_instance.mesh = mesh
	world_root.add_child(mesh_instance)
	return mesh_instance


func _cylinder(
	node_name: String,
	at: Vector3,
	radius: float,
	height: float,
	color: Color
) -> void:
	var mesh_instance := MeshInstance3D.new()
	mesh_instance.name = node_name
	mesh_instance.position = at
	var mesh := CylinderMesh.new()
	mesh.top_radius = radius * 0.8
	mesh.bottom_radius = radius
	mesh.height = height
	mesh.material = _material(color, 0.0, 0.9)
	mesh_instance.mesh = mesh
	world_root.add_child(mesh_instance)


func _sphere(node_name: String, at: Vector3, radius: float, color: Color) -> void:
	var mesh_instance := MeshInstance3D.new()
	mesh_instance.name = node_name
	mesh_instance.position = at
	var mesh := SphereMesh.new()
	mesh.radius = radius
	mesh.height = radius * 2.0
	mesh.radial_segments = 16
	mesh.rings = 8
	mesh.material = _material(color, 0.0, 0.95)
	mesh_instance.mesh = mesh
	world_root.add_child(mesh_instance)


func _material(color: Color, metallic: float, roughness: float) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.metallic = metallic
	material.roughness = roughness
	return material
