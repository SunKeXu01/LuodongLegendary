class_name CloudFordWorld3D
extends SubViewportContainer

const KAYKIT_MEDIEVAL := "res://assets/vendor/kaykit_medieval/"
const POLYGONAL_TEMPLE := "res://assets/vendor/polygonal_mind/tomb_chaser_2/"
const POLYGONAL_LUNAR := "res://assets/vendor/polygonal_mind/lunar_year/"

var world_viewport: SubViewport
var world_root: Node3D
var camera: Camera3D
var camera_rig: IsometricCameraRig3D
var follow_target: Node3D
var combat_vfx: CombatVfx3D
var environment: Environment
var sunlight: DirectionalLight3D
var world_time := 0.31
var time_scale := 1.0 / 240.0
var lantern_lights: Array[OmniLight3D] = []
var occluder_groups: Array[Dictionary] = []
var rain: GPUParticles3D
var mechanism_marker: Node3D
var rest_marker: Node3D
var rest_marker_label: Label3D
var rest_marker_ring: MeshInstance3D
var rest_marker_material: StandardMaterial3D
var river_surface: MeshInstance3D


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

	camera_rig = IsometricCameraRig3D.new()
	camera_rig.name = "IsometricCameraRig"
	world_root.add_child(camera_rig)
	camera = camera_rig.camera


func _process(delta: float) -> void:
	world_time = fposmod(world_time + delta * time_scale, 1.0)
	_update_environment()
	if not is_instance_valid(follow_target):
		return
	var focus := follow_target.global_position + Vector3(0.0, 0.0, -1.6)
	if is_instance_valid(rain):
		rain.global_position = focus + Vector3(0, 8, 0)
	_update_occluders(delta)


func add_actor(actor: Node3D) -> void:
	world_root.add_child(actor)


func set_follow_target(actor: Node3D) -> void:
	follow_target = actor
	camera_rig.set_target(actor)


func shake_camera(intensity: float) -> void:
	camera_rig.apply_shake(intensity)


func zoom_camera(steps: float) -> void:
	camera_rig.zoom_by_steps(steps)


func get_camera_mode_label() -> String:
	return camera_rig.get_zoom_label()


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


func set_rest_station_hovered(value: bool) -> void:
	if not is_instance_valid(rest_marker):
		return
	if is_instance_valid(rest_marker_ring):
		rest_marker_ring.scale = Vector3.ONE * (1.18 if value else 1.0)
	if is_instance_valid(rest_marker_material):
		rest_marker_material.albedo_color = (
			Color(0.42, 0.84, 0.58, 0.58)
			if value
			else Color(0.35, 0.65, 0.46, 0.34)
		)
	if is_instance_valid(rest_marker_label):
		rest_marker_label.modulate = Color("#fff0a6") if value else Color("#d8e6bc")


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
		Rect2(-11.15, -8.1, 5.4, 5.5),
		Rect2(-5.45, -8.1, 4.7, 4.4),
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
	environment.ambient_light_energy = 0.4
	environment.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	environment.tonemap_exposure = 0.74
	environment.adjustment_enabled = true
	environment.adjustment_brightness = 0.94
	environment.adjustment_contrast = 1.1
	environment.adjustment_saturation = 0.88
	environment.fog_enabled = true
	environment.fog_light_color = Color("#aeb8a4")
	environment.fog_density = 0.013
	environment.fog_height = 2.0
	environment.fog_height_density = 0.12
	world_environment.environment = environment
	world_root.add_child(world_environment)

	sunlight = DirectionalLight3D.new()
	sunlight.rotation_degrees = Vector3(-54.0, -32.0, 0.0)
	sunlight.light_color = Color("#f3d8a3")
	sunlight.light_energy = 0.82
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
	sunlight.light_energy = 0.08 + daylight * 0.78
	sunlight.light_color = Color("#f2c27f").lerp(Color("#fff0ca"), daylight)
	environment.background_color = Color("#182735").lerp(Color("#91a899"), daylight)
	environment.ambient_light_color = Color("#344a5c").lerp(
		Color("#d7d1b8"), daylight
	)
	environment.ambient_light_energy = 0.24 + daylight * 0.23
	environment.fog_light_color = Color("#465c66").lerp(
		Color("#aeb8a4"), daylight
	)
	environment.fog_density = 0.021 - daylight * 0.01 + twilight * 0.004
	var lantern_energy := clampf((0.48 - daylight) * 5.0, 0.0, 1.0) * 2.25
	for lantern in lantern_lights:
		if is_instance_valid(lantern):
			lantern.light_energy = lantern_energy


func _create_landscape() -> void:
	_box("渡口地面", Vector3(0, -0.35, -1), Vector3(26, 0.7, 17), Color("#536253"))
	_box("商道路面", Vector3(-1.0, 0.02, -1.2), Vector3(5.0, 0.08, 17), Color("#756951"))
	_create_river_surface()
	_create_road_stones()
	_create_riverbanks()

	for index in range(9):
		_box(
			"桥板%d" % index,
			Vector3(5.5 + index * 0.82, 0.34, 1.0),
			Vector3(0.74, 0.16, 2.5),
			Color("#745538")
		)
	_box("桥栏左", Vector3(8.7, 0.82, -0.15), Vector3(7.5, 0.12, 0.12), Color("#4d382a"))
	_box("桥栏右", Vector3(8.7, 0.82, 2.15), Vector3(7.5, 0.12, 0.12), Color("#4d382a"))

	for index in range(7):
		_create_mountain(
			"远山%d" % index,
			Vector3(-14.0 + index * 4.8, -0.25, -11.2 - float(index % 2) * 0.8),
			3.8 + float(index % 3) * 0.65,
			5.4 + float((index + 1) % 3) * 1.2,
			Color("#344b42").lerp(Color("#607163"), float(index) / 12.0)
		)


func _create_river_surface() -> void:
	river_surface = MeshInstance3D.new()
	river_surface.name = "动态云津河面"
	river_surface.position = Vector3(8.7, 0.055, -1.0)
	var river_mesh := PlaneMesh.new()
	river_mesh.size = Vector2(7.6, 17.0)
	river_mesh.subdivide_width = 56
	river_mesh.subdivide_depth = 96
	var water_shader := Shader.new()
	water_shader.code = """
shader_type spatial;
render_mode blend_mix, depth_draw_opaque, cull_back, diffuse_burley;

uniform vec4 deep_color : source_color = vec4(0.08, 0.25, 0.29, 1.0);
uniform vec4 shallow_color : source_color = vec4(0.24, 0.49, 0.50, 1.0);

void vertex() {
	float long_wave = sin(VERTEX.x * 1.7 + TIME * 0.8) * 0.008;
	float cross_wave = sin(VERTEX.z * 2.4 - TIME * 1.1) * 0.006;
	VERTEX.y += long_wave + cross_wave;
}

void fragment() {
	float ripple_a = sin((UV.x * 7.0 + UV.y * 3.0 + TIME * 0.16) * 12.0);
	float ripple_b = sin((UV.y * 11.0 - UV.x * 2.0 - TIME * 0.22) * 8.0);
	float ripple = ripple_a * 0.5 + ripple_b * 0.5;
	vec3 water = mix(deep_color.rgb, shallow_color.rgb, 0.42 + ripple * 0.025);
	ALBEDO = water;
	ROUGHNESS = 0.46;
	METALLIC = 0.04;
	SPECULAR = 0.62;
}
"""
	var water_material := ShaderMaterial.new()
	water_material.shader = water_shader
	river_mesh.material = water_material
	river_surface.mesh = river_mesh
	world_root.add_child(river_surface)


func _create_road_stones() -> void:
	var stone_colors := [Color("#756b57"), Color("#9a896c"), Color("#665f50")]
	for row in range(13):
		for column in range(3):
			var offset := float((row + column) % 2) * 0.16
			var stone := MeshInstance3D.new()
			stone.name = "商道青石_%d_%d" % [row, column]
			stone.position = Vector3(
				-2.25 + column * 1.22 + offset,
				0.085,
				-7.65 + row * 1.08
			)
			stone.rotation_degrees.y = float((row * 17 + column * 31) % 24) - 12.0
			var stone_mesh := BoxMesh.new()
			stone_mesh.size = Vector3(
				0.76 + float((row + column) % 3) * 0.07,
				0.075,
				0.58 + float((row * 2 + column) % 3) * 0.06
			)
			stone_mesh.material = _material(
				stone_colors[(row + column) % stone_colors.size()],
				0.0,
				0.96
			)
			stone.mesh = stone_mesh
			world_root.add_child(stone)


func _create_riverbanks() -> void:
	for index in range(18):
		var bank_z := -8.0 + index * 0.92
		var bank_x := 5.2 + sin(float(index) * 1.7) * 0.16
		var rock := MeshInstance3D.new()
		rock.name = "河岸石_%d" % index
		rock.position = Vector3(bank_x, 0.04, bank_z)
		rock.rotation_degrees.y = float(index * 29 % 180)
		rock.scale = Vector3(
			0.58 + float(index % 4) * 0.08,
			0.36 + float((index + 1) % 3) * 0.06,
			0.48 + float((index + 2) % 4) * 0.08
		)
		var rock_mesh := SphereMesh.new()
		rock_mesh.radius = 0.25
		rock_mesh.height = 0.5
		rock_mesh.radial_segments = 10
		rock_mesh.rings = 5
		rock_mesh.material = _material(
			Color("#3f4b45").lerp(Color("#665f4e"), float(index % 5) / 9.0),
			0.0,
			0.96
		)
		rock.mesh = rock_mesh
		world_root.add_child(rock)


func _create_mountain(
	node_name: String,
	at: Vector3,
	radius: float,
	height: float,
	color: Color
) -> void:
	var mountain := MeshInstance3D.new()
	mountain.name = node_name
	mountain.position = at + Vector3(0, height * 0.5, 0)
	mountain.rotation_degrees.y = float(node_name.hash() % 360)
	mountain.scale.z = 0.7
	var mountain_mesh := CylinderMesh.new()
	mountain_mesh.top_radius = radius * 0.08
	mountain_mesh.bottom_radius = radius
	mountain_mesh.height = height
	mountain_mesh.radial_segments = 9
	mountain_mesh.rings = 5
	mountain_mesh.material = _material(color, 0.0, 1.0)
	mountain.mesh = mountain_mesh
	world_root.add_child(mountain)

	var mist_band := MeshInstance3D.new()
	mist_band.name = "%s山岚" % node_name
	mist_band.position = at + Vector3(0, height * 0.32, 0.3)
	mist_band.scale.z = 0.72
	var mist_mesh := CylinderMesh.new()
	mist_mesh.top_radius = radius * 0.67
	mist_mesh.bottom_radius = radius * 0.76
	mist_mesh.height = 0.42
	mist_mesh.radial_segments = 9
	var mist_material := StandardMaterial3D.new()
	mist_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mist_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mist_material.albedo_color = Color(0.72, 0.78, 0.72, 0.18)
	mist_mesh.material = mist_material
	mist_band.mesh = mist_mesh
	world_root.add_child(mist_band)


func _create_settlement() -> void:
	_create_ming_guildhall(Vector3(-8.5, 0.0, -5.45))
	_create_ming_residence(Vector3(-3.1, 0.0, -6.0))
	_create_ming_trade_building(
		"鲁氏铁铺",
		"鲁氏铁铺",
		Vector3(3.2, 0.0, -5.8),
		0.46,
		Color("#d68a58"),
		true
	)
	_create_ming_trade_building(
		"云津货栈",
		"云津货栈",
		Vector3(-9.5, 0.0, 4.9),
		0.5,
		Color("#d2b276"),
		false
	)

	_vendor_asset(
		"云津渡木牌坊",
		"%sArchBanner.glb" % POLYGONAL_LUNAR,
		Vector3(-0.6, 0.0, -3.8),
		0.72,
		0.0
	)
	_vendor_asset(
		"云津巡夜灯阁",
		"%sShrine_Art.glb" % POLYGONAL_TEMPLE,
		Vector3(-5.55, 0.0, 1.15),
		0.78,
		8.0
	)

	var market_props := [
		["crate_long_A", Vector3(-6.8, 0.0, 1.8), 1.45, 10.0],
		["tent", Vector3(-4.3, 0.0, 3.0), 1.8, -8.0],
		["crate_open", Vector3(-2.0, 0.0, 1.9), 1.35, 20.0],
		["barrel", Vector3(2.9, 0.0, 3.1), 1.35, 0.0],
		["weaponrack", Vector3(4.3, 0.0, 2.3), 1.55, -15.0],
	]
	for prop in market_props:
		_vendor_asset(
			"集市道具%s" % prop[0],
			"%sdecoration/props/%s.gltf" % [KAYKIT_MEDIEVAL, prop[0]],
			prop[1], float(prop[2]), float(prop[3])
		)
	var lantern_positions := [
		Vector3(-2.2, 2.15, -3.4),
		Vector3(1.0, 2.15, -3.4),
		Vector3(-6.1, 1.9, 1.7),
		Vector3(3.5, 1.9, 3.0),
	]
	for index in lantern_positions.size():
		_create_lantern("灯笼%d" % index, lantern_positions[index])
	_create_rest_station(Vector3(0.7, 0.0, 4.2))
	_create_riverside_pavilion(Vector3(0.7, 0.0, 4.2))


func _create_ming_trade_building(
	node_name: String,
	sign_text: String,
	at: Vector3,
	module_scale: float,
	sign_color: Color,
	has_forge: bool
) -> void:
	var root := Node3D.new()
	root.name = node_name
	root.position = at
	root.rotation_degrees.y = 8.0 if has_forge else -15.0
	world_root.add_child(root)

	var half_width := 1.8 if has_forge else 2.05
	var half_depth := 1.62 if has_forge else 1.82
	var parts := [
		[
			"%s前墙" % node_name, "%sTempleWall01_Art.glb" % POLYGONAL_TEMPLE,
			Vector3(0, 0, half_depth), module_scale, 0.0
		],
		[
			"%s后墙" % node_name, "%sTempleWall01_Art.glb" % POLYGONAL_TEMPLE,
			Vector3(0, 0, -half_depth), module_scale, 180.0
		],
		[
			"%s左墙" % node_name, "%sTempleWall01_Art.glb" % POLYGONAL_TEMPLE,
			Vector3(-half_width, 0, 0), module_scale, 90.0
		],
		[
			"%s右墙" % node_name, "%sTempleWall01_Art.glb" % POLYGONAL_TEMPLE,
			Vector3(half_width, 0, 0), module_scale, -90.0
		],
		[
			"%s青瓦屋顶" % node_name,
			(
				"%sTempleRoof01Corner_Art.glb" % POLYGONAL_TEMPLE
				if has_forge
				else "%sTempleRoof01_Art.glb" % POLYGONAL_TEMPLE
			),
			Vector3(0, 3.7 if has_forge else 3.86, 0),
			module_scale,
			0.0
		],
		[
			"%s前檐木梁" % node_name, "%sTempleBeam01_Art.glb" % POLYGONAL_TEMPLE,
			Vector3(0, 3.04, half_depth + 0.1), module_scale, 0.0
		],
		[
			"%s石阶" % node_name, "%sEntranceStairs.glb" % POLYGONAL_LUNAR,
			Vector3(0, 0.02, half_depth + 1.02), module_scale + 0.04, 0.0
		],
	]
	for x_offset in [-half_width + 0.22, half_width - 0.22]:
		for z_offset in [-half_depth + 0.18, half_depth - 0.18]:
			parts.append([
				"%s朱柱" % node_name,
				"%sTempleColumn_Art.glb" % POLYGONAL_TEMPLE,
				Vector3(x_offset, 0, z_offset),
				module_scale,
				0.0,
			])
	for part in parts:
		_vendor_asset(
			str(part[0]),
			str(part[1]),
			part[2] as Vector3,
			float(part[3]),
			float(part[4]),
			root
		)

	var sign_back := MeshInstance3D.new()
	sign_back.name = "%s木匾" % node_name
	sign_back.position = Vector3(0, 2.55, half_depth + 0.14)
	var sign_mesh := BoxMesh.new()
	sign_mesh.size = Vector3(1.45 if has_forge else 1.7, 0.5, 0.1)
	sign_mesh.material = _material(Color("#38241c"), 0.0, 0.82)
	sign_back.mesh = sign_mesh
	root.add_child(sign_back)

	var sign := Label3D.new()
	sign.name = "%s匾额" % node_name
	sign.position = Vector3(0, 2.55, half_depth + 0.21)
	sign.text = sign_text
	sign.font_size = 46
	sign.outline_size = 6
	sign.pixel_size = 0.0067
	sign.modulate = sign_color
	root.add_child(sign)

	if has_forge:
		_create_forge_props(root, Vector3(0.95, 0, half_depth + 0.86))
	else:
		for index in range(3):
			_vendor_asset(
				"货栈灯笼%d" % index,
				"%sLamp01.glb" % POLYGONAL_LUNAR,
				Vector3(-1.05 + index * 1.05, 0.08, half_depth + 0.54),
				0.62,
				0.0,
				root
			)

	var meshes: Array[MeshInstance3D] = []
	_collect_meshes(root, meshes)
	occluder_groups.append({
		"center": at,
		"size": Vector2(5.0 if has_forge else 5.4, 4.8 if has_forge else 5.2),
		"meshes": meshes,
	})


func _create_forge_props(parent: Node3D, at: Vector3) -> void:
	var brazier := MeshInstance3D.new()
	brazier.name = "铁铺锻炉"
	brazier.position = at + Vector3(0, 0.36, 0)
	var brazier_mesh := CylinderMesh.new()
	brazier_mesh.top_radius = 0.48
	brazier_mesh.bottom_radius = 0.58
	brazier_mesh.height = 0.7
	brazier_mesh.material = _material(Color("#34302c"), 0.24, 0.68)
	brazier.mesh = brazier_mesh
	parent.add_child(brazier)

	var coals := MeshInstance3D.new()
	coals.name = "锻炉炭火"
	coals.position = at + Vector3(0, 0.73, 0)
	var coal_mesh := CylinderMesh.new()
	coal_mesh.top_radius = 0.39
	coal_mesh.bottom_radius = 0.39
	coal_mesh.height = 0.05
	var coal_material := _material(Color("#e24d28"), 0.0, 0.78)
	coal_material.emission_enabled = true
	coal_material.emission = Color("#ff652f")
	coal_material.emission_energy_multiplier = 2.8
	coal_mesh.material = coal_material
	coals.mesh = coal_mesh
	parent.add_child(coals)

	var forge_light := OmniLight3D.new()
	forge_light.name = "锻炉火光"
	forge_light.position = at + Vector3(0, 0.92, 0)
	forge_light.light_color = Color("#ff7840")
	forge_light.omni_range = 3.5
	forge_light.light_energy = 1.1
	forge_light.shadow_enabled = false
	parent.add_child(forge_light)


func _create_ming_residence(at: Vector3) -> void:
	var root := Node3D.new()
	root.name = "渡口民居"
	root.position = at
	world_root.add_child(root)
	var parts := [
		[
			"民居前墙", "%sTempleWall01_Art.glb" % POLYGONAL_TEMPLE,
			Vector3(0, 0, 1.76), 0.45, 0.0
		],
		[
			"民居后墙", "%sTempleWall01_Art.glb" % POLYGONAL_TEMPLE,
			Vector3(0, 0, -1.76), 0.45, 180.0
		],
		[
			"民居左墙", "%sTempleWall01_Art.glb" % POLYGONAL_TEMPLE,
			Vector3(-1.76, 0, 0), 0.45, 90.0
		],
		[
			"民居右墙", "%sTempleWall01_Art.glb" % POLYGONAL_TEMPLE,
			Vector3(1.76, 0, 0), 0.45, -90.0
		],
		[
			"青瓦直坡顶", "%sTempleRoof01_Art.glb" % POLYGONAL_TEMPLE,
			Vector3(0, 3.46, 0), 0.45, 0.0
		],
		[
			"民居石阶", "%sEntranceStairs.glb" % POLYGONAL_LUNAR,
			Vector3(0, 0.01, 2.77), 0.45, 0.0
		],
		[
			"民居门楼", "%sArchBanner.glb" % POLYGONAL_LUNAR,
			Vector3(0, 0.01, 3.67), 0.46, 0.0
		],
	]
	for x_offset in [-1.48, 1.48]:
		for z_offset in [-1.48, 1.48]:
			parts.append([
				"民居朱柱", "%sTempleColumn_Art.glb" % POLYGONAL_TEMPLE,
				Vector3(x_offset, 0, z_offset), 0.45, 0.0
			])
	for part in parts:
		_vendor_asset(
			str(part[0]),
			str(part[1]),
			part[2] as Vector3,
			float(part[3]),
			float(part[4]),
			root
		)
	var meshes: Array[MeshInstance3D] = []
	_collect_meshes(root, meshes)
	occluder_groups.append({
		"center": at,
		"size": Vector2(4.35, 4.35),
		"meshes": meshes,
	})


func _create_ming_guildhall(at: Vector3) -> void:
	var root := Node3D.new()
	root.name = "临河客栈"
	root.position = at
	world_root.add_child(root)
	var parts := [
		[
			"客栈前墙", "%sTempleWall01_Art.glb" % POLYGONAL_TEMPLE,
			Vector3(0, 0, 2.12), 0.55, 0.0
		],
		[
			"客栈后墙", "%sTempleWall01_Art.glb" % POLYGONAL_TEMPLE,
			Vector3(0, 0, -2.12), 0.55, 180.0
		],
		[
			"客栈左墙", "%sTempleWall01_Art.glb" % POLYGONAL_TEMPLE,
			Vector3(-2.12, 0, 0), 0.55, 90.0
		],
		[
			"客栈右墙", "%sTempleWall01_Art.glb" % POLYGONAL_TEMPLE,
			Vector3(2.12, 0, 0), 0.55, -90.0
		],
		[
			"青瓦歇山角顶", "%sTempleRoof01Corner_Art.glb" % POLYGONAL_TEMPLE,
			Vector3(0, 4.48, 0), 0.55, 0.0
		],
		[
			"前檐额枋", "%sTempleBeam01_Art.glb" % POLYGONAL_TEMPLE,
			Vector3(0, 3.58, 2.18), 0.55, 0.0
		],
		[
			"入馆石阶", "%sEntranceStairs.glb" % POLYGONAL_LUNAR,
			Vector3(0, 0.02, 3.62), 0.62, 0.0
		],
		[
			"客栈门楼", "%sArchBanner.glb" % POLYGONAL_LUNAR,
			Vector3(0, 0.02, 5.05), 0.64, 0.0
		],
		[
			"门前灯左", "%sLamp01.glb" % POLYGONAL_LUNAR,
			Vector3(-1.52, 0.15, 2.62), 0.72, 0.0
		],
		[
			"门前灯右", "%sLamp01.glb" % POLYGONAL_LUNAR,
			Vector3(1.52, 0.15, 2.62), 0.72, 0.0
		],
	]
	for x_offset in [-1.82, 1.82]:
		for z_offset in [-1.82, 1.82]:
			parts.append([
				"朱柱", "%sTempleColumn_Art.glb" % POLYGONAL_TEMPLE,
				Vector3(x_offset, 0, z_offset), 0.55, 0.0
			])
	for part in parts:
		_vendor_asset(
			str(part[0]),
			str(part[1]),
			part[2] as Vector3,
			float(part[3]),
			float(part[4]),
			root
		)
	var sign := Label3D.new()
	sign.name = "临河客栈匾额"
	sign.position = Vector3(0, 2.82, 2.18)
	sign.text = "临河客栈"
	sign.font_size = 56
	sign.outline_size = 8
	sign.pixel_size = 0.007
	sign.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	sign.no_depth_test = true
	sign.modulate = Color("#e6c77d")
	root.add_child(sign)
	for lamp_position in [
		Vector3(-1.52, 1.32, 2.62),
		Vector3(1.52, 1.32, 2.62),
	]:
		var light := OmniLight3D.new()
		light.name = "客栈暖灯"
		light.position = lamp_position
		light.light_color = Color("#ff9a47")
		light.omni_range = 4.2
		light.light_energy = 0.0
		light.shadow_enabled = false
		root.add_child(light)
		lantern_lights.append(light)
	var meshes: Array[MeshInstance3D] = []
	_collect_meshes(root, meshes)
	occluder_groups.append({
		"center": at,
		"size": Vector2(5.35, 5.35),
		"meshes": meshes,
	})


func _create_rest_station(at: Vector3) -> void:
	rest_marker = Node3D.new()
	rest_marker.name = "渡口茶棚交互点"
	rest_marker.position = at
	world_root.add_child(rest_marker)

	var table := MeshInstance3D.new()
	table.name = "茶桌"
	table.position = Vector3(0, 0.52, 0)
	var table_mesh := CylinderMesh.new()
	table_mesh.top_radius = 0.48
	table_mesh.bottom_radius = 0.43
	table_mesh.height = 0.12
	table_mesh.material = _material(Color("#654a32"), 0.0, 0.88)
	table.mesh = table_mesh
	rest_marker.add_child(table)
	for x_offset in [-0.28, 0.28]:
		var cup := MeshInstance3D.new()
		cup.position = Vector3(x_offset, 0.68, 0)
		var cup_mesh := CylinderMesh.new()
		cup_mesh.top_radius = 0.08
		cup_mesh.bottom_radius = 0.065
		cup_mesh.height = 0.12
		cup_mesh.material = _material(Color("#b9ad8c"), 0.0, 0.6)
		cup.mesh = cup_mesh
		rest_marker.add_child(cup)

	rest_marker_ring = MeshInstance3D.new()
	rest_marker_ring.name = "茶棚交互环"
	rest_marker_ring.position.y = 0.035
	var ring_mesh := CylinderMesh.new()
	ring_mesh.top_radius = 0.72
	ring_mesh.bottom_radius = 0.72
	ring_mesh.height = 0.025
	rest_marker_material = StandardMaterial3D.new()
	rest_marker_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	rest_marker_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	rest_marker_material.albedo_color = Color(0.35, 0.65, 0.46, 0.34)
	ring_mesh.material = rest_marker_material
	rest_marker_ring.mesh = ring_mesh
	rest_marker.add_child(rest_marker_ring)

	rest_marker_label = Label3D.new()
	rest_marker_label.name = "茶棚名牌"
	rest_marker_label.position = Vector3(0, 1.45, 0)
	rest_marker_label.text = "茶棚休整"
	rest_marker_label.font_size = 40
	rest_marker_label.outline_size = 8
	rest_marker_label.pixel_size = 0.009
	rest_marker_label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	rest_marker_label.no_depth_test = true
	rest_marker_label.fixed_size = false
	rest_marker_label.modulate = Color("#d8e6bc")
	rest_marker.add_child(rest_marker_label)


func _create_riverside_pavilion(at: Vector3) -> void:
	var root := Node3D.new()
	root.name = "临水茶亭"
	root.position = at
	world_root.add_child(root)
	var platform := _box(
		"茶亭台基",
		at + Vector3(0, 0.12, 0),
		Vector3(3.15, 0.24, 2.75),
		Color("#727064")
	)
	var timber := Color("#5d2924")
	for x_offset in [-1.12, 1.12]:
		for z_offset in [-0.92, 0.92]:
			_cylinder(
				"茶亭柱",
				at + Vector3(x_offset, 1.22, z_offset),
				0.11,
				2.2,
				timber
			)
	var beams := [
		[Vector3(0, 2.18, -0.92), Vector3(2.55, 0.16, 0.16)],
		[Vector3(0, 2.18, 0.92), Vector3(2.55, 0.16, 0.16)],
		[Vector3(-1.12, 2.18, 0), Vector3(0.16, 0.16, 2.1)],
		[Vector3(1.12, 2.18, 0), Vector3(0.16, 0.16, 2.1)],
	]
	for index in beams.size():
		_box(
			"茶亭梁%d" % index,
			at + beams[index][0],
			beams[index][1],
			timber
		)
	var roof := MeshInstance3D.new()
	roof.name = "明式歇山顶"
	roof.position = at + Vector3(0, 2.2, 0)
	roof.mesh = _hip_roof_mesh(3.65, 3.15, 0.82, 1.22, Color("#263a35"))
	world_root.add_child(roof)
	var eave_color := Color("#b79b61")
	var eave_parts := [
		[Vector3(0, 2.21, -1.58), Vector3(3.72, 0.09, 0.10)],
		[Vector3(0, 2.21, 1.58), Vector3(3.72, 0.09, 0.10)],
		[Vector3(-1.83, 2.21, 0), Vector3(0.10, 0.09, 3.16)],
		[Vector3(1.83, 2.21, 0), Vector3(0.10, 0.09, 3.16)],
	]
	for index in eave_parts.size():
		_box(
			"茶亭檐饰%d" % index,
			at + eave_parts[index][0],
			eave_parts[index][1],
			eave_color
		)
	var ridge := _cylinder_mesh_instance(
		"屋脊",
		at + Vector3(0, 3.04, 0),
		0.07,
		1.42,
		Color("#b69a62")
	)
	ridge.rotation_degrees.z = 90.0
	var plaque := _box(
		"云津茶亭匾",
		at + Vector3(0, 1.93, 1.02),
		Vector3(1.05, 0.36, 0.08),
		Color("#34231d")
	)
	var plaque_label := Label3D.new()
	plaque_label.name = "云津茶亭匾文"
	plaque_label.position = at + Vector3(0, 1.93, 1.075)
	plaque_label.text = "云津茶亭"
	plaque_label.font_size = 34
	plaque_label.outline_size = 5
	plaque_label.pixel_size = 0.0065
	plaque_label.modulate = Color("#d8bd72")
	world_root.add_child(plaque_label)
	occluder_groups.append({
		"center": at,
		"size": Vector2(3.7, 3.2),
		"meshes": [platform, roof, ridge, plaque],
	})


func _hip_roof_mesh(
	width: float,
	depth: float,
	height: float,
	ridge_length: float,
	color: Color
) -> ArrayMesh:
	var surface := SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	var front_left := Vector3(-width * 0.5, 0, depth * 0.5)
	var front_right := Vector3(width * 0.5, 0, depth * 0.5)
	var back_left := Vector3(-width * 0.5, 0, -depth * 0.5)
	var back_right := Vector3(width * 0.5, 0, -depth * 0.5)
	var ridge_left := Vector3(-ridge_length * 0.5, height, 0)
	var ridge_right := Vector3(ridge_length * 0.5, height, 0)
	var triangles := [
		[front_left, front_right, ridge_right],
		[front_left, ridge_right, ridge_left],
		[back_right, back_left, ridge_left],
		[back_right, ridge_left, ridge_right],
		[back_left, front_left, ridge_left],
		[front_right, back_right, ridge_right],
	]
	for triangle in triangles:
		for vertex in triangle:
			surface.set_uv(Vector2(vertex.x / width + 0.5, vertex.z / depth + 0.5))
			surface.add_vertex(vertex)
	surface.generate_normals()
	var roof_material := _material(color, 0.0, 0.82)
	# The procedural roof is intentionally double-sided: the isometric camera
	# can cross the ridge during mouse travel, and a one-sided SurfaceTool mesh
	# otherwise appears as a bare timber frame from half of the map.
	roof_material.cull_mode = BaseMaterial3D.CULL_DISABLED
	surface.set_material(roof_material)
	return surface.commit()


func _create_nature() -> void:
	var tree_positions := [
		Vector3(-11.0, 0.0, -1.5), Vector3(-7.0, 0.0, -3.2),
		Vector3(4.3, 0.0, -3.7), Vector3(-11.2, 0.0, 6.2),
		Vector3(3.8, 0.0, 5.8), Vector3(5.0, 0.0, 3.8)
	]
	for index in tree_positions.size():
		var at: Vector3 = tree_positions[index]
		var tree_name := "tree_single_A" if index % 2 == 0 else "tree_single_B"
		_vendor_asset(
			"河岸古树%d" % index,
			"%sdecoration/nature/%s.gltf" % [KAYKIT_MEDIEVAL, tree_name],
			at, 2.45 + float(index % 3) * 0.18, float(index * 37)
		)
	var natural_props := [
		["rock_single_A", Vector3(-10.6, 0.0, 1.8), 1.7, 0.0],
		["rock_single_D", Vector3(4.9, 0.0, -0.9), 1.45, 80.0],
		["waterplant_A", Vector3(6.4, -0.03, 5.6), 1.4, 0.0],
		["waterplant_C", Vector3(7.0, -0.03, -4.7), 1.55, 45.0],
	]
	for prop in natural_props:
		_vendor_asset(
			"自然道具%s" % prop[0],
			"%sdecoration/nature/%s.gltf" % [KAYKIT_MEDIEVAL, prop[0]],
			prop[1], float(prop[2]), float(prop[3])
		)


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


func _vendor_building(
	node_name: String,
	asset_name: String,
	at: Vector3,
	uniform_scale: float,
	yaw_degrees: float,
	occluder_size: Vector2
) -> void:
	var instance := _vendor_asset(
		node_name,
		"%sbuildings/red/%s.gltf" % [KAYKIT_MEDIEVAL, asset_name],
		at,
		uniform_scale,
		yaw_degrees
	)
	if not is_instance_valid(instance):
		_house(at, Vector3(occluder_size.x, 2.8, occluder_size.y), Color("#a59270"))
		return
	var meshes: Array[MeshInstance3D] = []
	_collect_meshes(instance, meshes)
	occluder_groups.append({
		"center": at,
		"size": occluder_size,
		"meshes": meshes,
	})


func _vendor_asset(
	node_name: String,
	resource_path: String,
	at: Vector3,
	uniform_scale: float,
	yaw_degrees: float,
	parent: Node3D = null
) -> Node3D:
	var scene := load(resource_path) as PackedScene
	if scene == null:
		push_warning("未能载入场景资产：%s" % resource_path)
		return null
	var instance := scene.instantiate() as Node3D
	if instance == null:
		return null
	instance.name = node_name
	instance.position = at
	instance.rotation_degrees.y = yaw_degrees
	instance.scale = Vector3.ONE * uniform_scale
	if is_instance_valid(parent):
		parent.add_child(instance)
	else:
		world_root.add_child(instance)
	return instance


func _collect_meshes(node: Node, result: Array[MeshInstance3D]) -> void:
	if node is MeshInstance3D:
		result.append(node as MeshInstance3D)
	for child in node.get_children():
		_collect_meshes(child, result)


func _update_occluders(delta: float) -> void:
	if not is_instance_valid(follow_target) or not is_instance_valid(camera):
		return
	var player_xz := Vector2(follow_target.global_position.x, follow_target.global_position.z)
	var camera_xz := Vector2(camera.global_position.x, camera.global_position.z)
	for group in occluder_groups:
		var center: Vector3 = group["center"]
		var dimensions: Vector2 = group["size"]
		var area := Rect2(
			Vector2(center.x, center.z) - dimensions * 0.5,
			dimensions
		)
		var visibility_area := area.grow(0.5)
		var should_fade: bool = (
			visibility_area.has_point(player_xz)
			or _segment_intersects_rect(camera_xz, player_xz, visibility_area)
		)
		var target_alpha := 0.58 if should_fade else 0.0
		for mesh in group["meshes"]:
			if is_instance_valid(mesh):
				mesh.transparency = move_toward(
					mesh.transparency, target_alpha, delta * 2.8
				)


func _segment_intersects_rect(from: Vector2, to: Vector2, area: Rect2) -> bool:
	if area.has_point(from) or area.has_point(to):
		return true
	var top_left := area.position
	var top_right := area.position + Vector2(area.size.x, 0)
	var bottom_right := area.end
	var bottom_left := area.position + Vector2(0, area.size.y)
	var edges := [
		[top_left, top_right],
		[top_right, bottom_right],
		[bottom_right, bottom_left],
		[bottom_left, top_left],
	]
	for edge in edges:
		if Geometry2D.segment_intersects_segment(from, to, edge[0], edge[1]) != null:
			return true
	return false


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


func _cylinder_mesh_instance(
	node_name: String,
	at: Vector3,
	radius: float,
	height: float,
	color: Color
) -> MeshInstance3D:
	var mesh_instance := MeshInstance3D.new()
	mesh_instance.name = node_name
	mesh_instance.position = at
	var mesh := CylinderMesh.new()
	mesh.top_radius = radius
	mesh.bottom_radius = radius
	mesh.height = height
	mesh.material = _material(color, 0.0, 0.72)
	mesh_instance.mesh = mesh
	world_root.add_child(mesh_instance)
	return mesh_instance


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
