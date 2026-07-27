class_name WuxiaActor3D
extends CharacterBody3D

signal defeated(actor: WuxiaActor3D)

const KAYKIT_ADVENTURERS := "res://assets/vendor/kaykit_adventurers/"

@export var display_name := "江湖客"
@export var hostile := false
@export var max_health := 100
@export var move_speed := 5.0
@export var attack_power := 12
@export var actor_level := 1
@export_enum("hero", "npc", "enemy", "boss") var visual_variant := "npc"

var health: int
var selected := false:
	set(value):
		selected = value
		_refresh_interaction_style()
var hovered := false:
	set(value):
		hovered = value
		_refresh_interaction_style()
var moving := false
var combat_target: WuxiaActor3D
var attack_cooldown := 0.0
var destination := Vector3.ZERO
var selection_disc: MeshInstance3D
var selection_material: StandardMaterial3D
var nameplate: Label3D
var status_marker: Label3D
var health_bar_background: MeshInstance3D
var health_bar_fill: MeshInstance3D
var weapon_pivot: Node3D
var model_root: Node3D
var left_leg: Node3D
var right_leg: Node3D
var left_arm: Node3D
var right_arm: Node3D
var animation_player: AnimationPlayer
var animation_tree: AnimationTree
var animation_playback: AnimationNodeStateMachinePlayback
var uses_imported_model := false
var navigation_agent: NavigationAgent3D
var patrol_origin := Vector3.ZERO
var patrol_radius := 0.0
var patrol_wait := 0.0
var patrol_phase := 0.0
var animation_state := "idle"
var vision_radius := 0.0
var vision_angle_degrees := 70.0
var vision_cone: MeshInstance3D
var vision_material: StandardMaterial3D
var alerted := false


func _ready() -> void:
	health = max_health
	_create_collision()
	_create_navigation_agent()
	_create_model()
	_create_animation_state_machine()
	_create_nameplate()


func command_move(target: Vector3) -> void:
	destination = Vector3(target.x, 0.0, target.z)
	navigation_agent.target_position = destination
	moving = true
	_set_animation_state("run")


func stop() -> void:
	moving = false
	velocity = Vector3.ZERO
	if animation_state == "run":
		_set_animation_state("idle")


func enable_patrol(origin: Vector3, radius: float, phase: float) -> void:
	patrol_origin = origin
	patrol_radius = radius
	patrol_phase = phase
	patrol_wait = 0.8 + phase * 0.25


func enable_vision_cone(radius := 5.2, angle_degrees := 70.0) -> void:
	vision_radius = radius
	vision_angle_degrees = angle_degrees
	vision_cone = MeshInstance3D.new()
	vision_cone.name = "警戒视野"
	vision_cone.position.y = 0.035
	vision_cone.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var mesh := ImmediateMesh.new()
	vision_material = StandardMaterial3D.new()
	vision_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	vision_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	vision_material.no_depth_test = true
	vision_material.albedo_color = Color(0.85, 0.68, 0.25, 0.2)
	mesh.surface_begin(Mesh.PRIMITIVE_TRIANGLES, vision_material)
	var segments := 18
	var half_angle := deg_to_rad(angle_degrees * 0.5)
	for index in range(segments):
		var first := lerpf(-half_angle, half_angle, float(index) / float(segments))
		var second := lerpf(-half_angle, half_angle, float(index + 1) / float(segments))
		mesh.surface_add_vertex(Vector3.ZERO)
		mesh.surface_add_vertex(Vector3(sin(first) * radius, 0, cos(first) * radius))
		mesh.surface_add_vertex(Vector3(sin(second) * radius, 0, cos(second) * radius))
	mesh.surface_end()
	vision_cone.mesh = mesh
	add_child(vision_cone)


func can_see(target: Node3D) -> bool:
	if vision_radius <= 0.0 or not is_instance_valid(target):
		return false
	var offset := target.global_position - global_position
	offset.y = 0.0
	if offset.length() > vision_radius or offset.length_squared() < 0.0001:
		return false
	var forward := global_transform.basis.z
	forward.y = 0.0
	forward = forward.normalized()
	var minimum_dot := cos(deg_to_rad(vision_angle_degrees * 0.5))
	return forward.dot(offset.normalized()) >= minimum_dot


func set_alerted(value: bool) -> void:
	alerted = value
	if is_instance_valid(vision_material):
		vision_material.albedo_color = (
			Color(0.92, 0.18, 0.12, 0.34)
			if value
			else Color(0.85, 0.68, 0.25, 0.2)
		)
	_refresh_nameplate_style()


func set_interaction_marker(marker_text: String, color := Color("#f0c95c")) -> void:
	if not is_instance_valid(status_marker):
		return
	status_marker.text = marker_text
	status_marker.modulate = color
	status_marker.visible = not marker_text.is_empty()


func take_damage(amount: int) -> void:
	health = maxi(0, health - amount)
	if health > 0:
		play_hit()
	else:
		_set_animation_state("defeated")
	_refresh_nameplate()
	_hit_flash()
	if health == 0:
		defeated.emit(self)


func restore_health(value: int) -> void:
	health = clampi(value, 1, max_health)
	_refresh_nameplate()


func play_attack() -> void:
	_set_animation_state("attack")
	get_tree().create_timer(0.4).timeout.connect(_finish_action_animation)


func play_hit() -> void:
	_set_animation_state("hit")
	get_tree().create_timer(0.22).timeout.connect(_finish_action_animation)


func play_defeat() -> void:
	stop()
	_set_animation_state("defeated")
	if is_instance_valid(nameplate):
		nameplate.visible = false
	if is_instance_valid(selection_disc):
		selection_disc.visible = false
	if is_instance_valid(vision_cone):
		vision_cone.visible = false
	if is_instance_valid(health_bar_background):
		health_bar_background.visible = false
	if is_instance_valid(health_bar_fill):
		health_bar_fill.visible = false
	if is_instance_valid(status_marker):
		status_marker.visible = false


func _physics_process(delta: float) -> void:
	attack_cooldown = maxf(0.0, attack_cooldown - delta)
	_update_patrol(delta)
	if not moving:
		velocity = Vector3.ZERO
		return
	if navigation_agent.is_navigation_finished():
		stop()
		return
	var next_path_position := navigation_agent.get_next_path_position()
	var offset := next_path_position - global_position
	offset.y = 0.0
	if global_position.distance_to(destination) <= 0.22:
		stop()
		return
	var direction := offset.normalized()
	velocity = direction * move_speed
	rotation.y = lerp_angle(rotation.y, atan2(direction.x, direction.z), delta * 12.0)
	move_and_slide()


func _update_patrol(delta: float) -> void:
	if not hostile or patrol_radius <= 0.0 or is_instance_valid(combat_target):
		return
	if moving or animation_state == "defeated":
		return
	patrol_wait -= delta
	if patrol_wait > 0.0:
		return
	patrol_phase += 1.37
	var offset := Vector3(cos(patrol_phase), 0.0, sin(patrol_phase)) * patrol_radius
	command_move(patrol_origin + offset)
	patrol_wait = 1.5


func _create_collision() -> void:
	var collision := CollisionShape3D.new()
	var shape := CapsuleShape3D.new()
	shape.radius = 0.32
	shape.height = 1.5
	collision.shape = shape
	collision.position.y = 0.78
	add_child(collision)


func _create_navigation_agent() -> void:
	navigation_agent = NavigationAgent3D.new()
	navigation_agent.path_desired_distance = 0.18
	navigation_agent.target_desired_distance = 0.22
	navigation_agent.radius = 0.34
	navigation_agent.height = 1.6
	navigation_agent.max_speed = move_speed
	add_child(navigation_agent)


func _create_model() -> void:
	model_root = Node3D.new()
	model_root.name = "CharacterModel"
	add_child(model_root)

	if _create_imported_model():
		_create_selection_disc()
		return

	var robe_color := Color("#31584b") if not hostile else Color("#643238")
	var robe_dark := Color("#203d35") if not hostile else Color("#452329")
	var robe_trim := Color("#d5bd75") if not hostile else Color("#c78d58")
	_add_cylinder(model_root, Vector3(0, 0.9, 0), 0.3, 0.44, 0.92, robe_color)
	_add_box(model_root, Vector3(0, 1.1, 0.02), Vector3(0.58, 0.4, 0.34), robe_color)
	_add_box(model_root, Vector3(0, 0.91, 0.2), Vector3(0.62, 0.07, 0.05), robe_trim)
	_add_sphere(model_root, Vector3(0, 1.57, 0), 0.23, Color("#d2a378"))
	_add_box(model_root, Vector3(0, 1.76, 0), Vector3(0.48, 0.12, 0.42), Color("#202321"))
	_add_box(model_root, Vector3(0, 1.82, -0.08), Vector3(0.12, 0.28, 0.12), Color("#202321"))

	left_leg = _limb_pivot("LeftLeg", Vector3(-0.19, 0.48, 0), model_root)
	right_leg = _limb_pivot("RightLeg", Vector3(0.19, 0.48, 0), model_root)
	_add_box(left_leg, Vector3(0, -0.25, 0), Vector3(0.19, 0.55, 0.22), robe_dark)
	_add_box(right_leg, Vector3(0, -0.25, 0), Vector3(0.19, 0.55, 0.22), robe_dark)
	_add_box(left_leg, Vector3(0, -0.54, 0.07), Vector3(0.2, 0.12, 0.35), Color("#242722"))
	_add_box(right_leg, Vector3(0, -0.54, 0.07), Vector3(0.2, 0.12, 0.35), Color("#242722"))

	left_arm = _limb_pivot("LeftArm", Vector3(-0.39, 1.27, 0), model_root)
	right_arm = _limb_pivot("RightArm", Vector3(0.39, 1.27, 0), model_root)
	left_arm.rotation_degrees.z = -8.0
	right_arm.rotation_degrees.z = 8.0
	_add_box(left_arm, Vector3(0, -0.29, 0), Vector3(0.17, 0.62, 0.19), robe_color)
	_add_box(right_arm, Vector3(0, -0.29, 0), Vector3(0.17, 0.62, 0.19), robe_color)
	_add_sphere(left_arm, Vector3(0, -0.62, 0), 0.09, Color("#d2a378"))
	_add_sphere(right_arm, Vector3(0, -0.62, 0), 0.09, Color("#d2a378"))

	weapon_pivot = Node3D.new()
	weapon_pivot.name = "WeaponPivot"
	weapon_pivot.position = Vector3(0, -0.58, 0)
	weapon_pivot.rotation_degrees.z = 16.0
	right_arm.add_child(weapon_pivot)
	_add_box(weapon_pivot, Vector3(0, -0.38, 0), Vector3(0.065, 0.85, 0.065), Color("#d9d4b9"))
	_add_box(weapon_pivot, Vector3(0, 0.08, 0), Vector3(0.2, 0.07, 0.1), Color("#745235"))

	_create_selection_disc()


func _create_imported_model() -> bool:
	var model_files := {
		"hero": "Rogue_Hooded.glb",
		"npc": "Knight.glb",
		"enemy": "Barbarian.glb",
		"boss": "Mage.glb",
	}
	var resource_path := "%s%s" % [
		KAYKIT_ADVENTURERS,
		model_files.get(visual_variant, "Knight.glb"),
	]
	var scene := load(resource_path) as PackedScene
	if scene == null:
		return false
	var imported := scene.instantiate() as Node3D
	if imported == null:
		return false
	imported.name = "KayKitAnimatedModel"
	imported.rotation_degrees.y = 180.0
	model_root.add_child(imported)
	for candidate in imported.find_children("*", "AnimationPlayer", true, false):
		animation_player = candidate as AnimationPlayer
		if is_instance_valid(animation_player):
			break
	uses_imported_model = is_instance_valid(animation_player)
	return uses_imported_model


func _create_selection_disc() -> void:
	selection_disc = MeshInstance3D.new()
	selection_disc.name = "目标选择环"
	selection_disc.position.y = 0.025
	var disc := CylinderMesh.new()
	disc.top_radius = 0.56
	disc.bottom_radius = 0.56
	disc.height = 0.025
	selection_material = StandardMaterial3D.new()
	selection_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	selection_material.albedo_color = Color(0.94, 0.72, 0.24, 0.52)
	selection_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	disc.material = selection_material
	selection_disc.mesh = disc
	selection_disc.visible = selected or hovered
	add_child(selection_disc)


func _create_animation_state_machine() -> void:
	if uses_imported_model:
		_set_animation_state("idle")
		return
	animation_player = AnimationPlayer.new()
	animation_player.name = "AnimationPlayer"
	animation_player.root_node = NodePath("..")
	add_child(animation_player)
	var library := AnimationLibrary.new()
	library.add_animation("idle", _idle_animation())
	library.add_animation("run", _run_animation())
	library.add_animation("attack", _attack_animation())
	library.add_animation("hit", _hit_animation())
	library.add_animation("defeated", _defeat_animation())
	animation_player.add_animation_library("", library)

	var state_machine := AnimationNodeStateMachine.new()
	var names := {
		"Idle": "idle",
		"Run": "run",
		"Attack": "attack",
		"Hit": "hit",
		"Defeated": "defeated",
	}
	var index := 0
	for state_name in names:
		var animation_node := AnimationNodeAnimation.new()
		animation_node.animation = names[state_name]
		state_machine.add_node(state_name, animation_node, Vector2(index * 160, 0))
		index += 1
	for from_state in names:
		for to_state in names:
			if from_state == to_state:
				continue
			var transition := AnimationNodeStateMachineTransition.new()
			transition.xfade_time = 0.08
			state_machine.add_transition(from_state, to_state, transition)

	animation_tree = AnimationTree.new()
	animation_tree.name = "AnimationTree"
	animation_tree.anim_player = NodePath("../AnimationPlayer")
	animation_tree.tree_root = state_machine
	add_child(animation_tree)
	animation_tree.active = true
	animation_playback = animation_tree.get("parameters/playback")
	_set_animation_state("idle")


func _idle_animation() -> Animation:
	var animation := Animation.new()
	animation.length = 1.6
	animation.loop_mode = Animation.LOOP_LINEAR
	_add_value_track(
		animation, "CharacterModel:position",
		[0.0, 0.8, 1.6],
		[Vector3.ZERO, Vector3(0, 0.025, 0), Vector3.ZERO]
	)
	_add_value_track(
		animation, "CharacterModel/LeftArm:rotation_degrees",
		[0.0, 0.8, 1.6],
		[Vector3(0, 0, -8), Vector3(2, 0, -10), Vector3(0, 0, -8)]
	)
	_add_value_track(
		animation, "CharacterModel/RightArm:rotation_degrees",
		[0.0, 0.8, 1.6],
		[Vector3(0, 0, 8), Vector3(-2, 0, 10), Vector3(0, 0, 8)]
	)
	return animation


func _run_animation() -> Animation:
	var animation := Animation.new()
	animation.length = 0.62
	animation.loop_mode = Animation.LOOP_LINEAR
	_add_value_track(
		animation, "CharacterModel:position",
		[0.0, 0.155, 0.31, 0.465, 0.62],
		[
			Vector3.ZERO, Vector3(0, 0.065, 0), Vector3.ZERO,
			Vector3(0, 0.065, 0), Vector3.ZERO
		]
	)
	_add_value_track(
		animation, "CharacterModel/LeftLeg:rotation_degrees",
		[0.0, 0.31, 0.62],
		[Vector3(30, 0, 0), Vector3(-30, 0, 0), Vector3(30, 0, 0)]
	)
	_add_value_track(
		animation, "CharacterModel/RightLeg:rotation_degrees",
		[0.0, 0.31, 0.62],
		[Vector3(-30, 0, 0), Vector3(30, 0, 0), Vector3(-30, 0, 0)]
	)
	_add_value_track(
		animation, "CharacterModel/LeftArm:rotation_degrees",
		[0.0, 0.31, 0.62],
		[Vector3(-24, 0, -8), Vector3(24, 0, -8), Vector3(-24, 0, -8)]
	)
	_add_value_track(
		animation, "CharacterModel/RightArm:rotation_degrees",
		[0.0, 0.31, 0.62],
		[Vector3(24, 0, 8), Vector3(-24, 0, 8), Vector3(24, 0, 8)]
	)
	return animation


func _attack_animation() -> Animation:
	var animation := Animation.new()
	animation.length = 0.4
	_add_value_track(
		animation, "CharacterModel/RightArm:rotation_degrees",
		[0.0, 0.14, 0.28, 0.4],
		[
			Vector3(0, 0, 8), Vector3(-30, 0, 48),
			Vector3(24, 0, -105), Vector3(0, 0, 8)
		]
	)
	_add_value_track(
		animation, "CharacterModel:rotation_degrees",
		[0.0, 0.18, 0.4],
		[Vector3.ZERO, Vector3(0, -16, 0), Vector3.ZERO]
	)
	return animation


func _hit_animation() -> Animation:
	var animation := Animation.new()
	animation.length = 0.22
	_add_value_track(
		animation, "CharacterModel:rotation_degrees",
		[0.0, 0.08, 0.22],
		[Vector3.ZERO, Vector3(-12, 0, 7), Vector3.ZERO]
	)
	return animation


func _defeat_animation() -> Animation:
	var animation := Animation.new()
	animation.length = 0.5
	_add_value_track(
		animation, "CharacterModel:rotation_degrees",
		[0.0, 0.5],
		[Vector3.ZERO, Vector3(0, 0, 82)]
	)
	_add_value_track(
		animation, "CharacterModel:position",
		[0.0, 0.5],
		[Vector3.ZERO, Vector3(0, -0.3, 0)]
	)
	return animation


func _add_value_track(
	animation: Animation,
	path: String,
	times: Array,
	values: Array
) -> void:
	var track := animation.add_track(Animation.TYPE_VALUE)
	animation.track_set_path(track, NodePath(path))
	animation.value_track_set_update_mode(track, Animation.UPDATE_CONTINUOUS)
	for index in range(times.size()):
		animation.track_insert_key(track, float(times[index]), values[index])


func _create_nameplate() -> void:
	nameplate = Label3D.new()
	nameplate.position = Vector3(0, 2.08, 0)
	nameplate.font_size = 38
	nameplate.outline_size = 7
	nameplate.pixel_size = 0.008
	nameplate.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	nameplate.no_depth_test = true
	nameplate.fixed_size = false
	add_child(nameplate)

	status_marker = Label3D.new()
	status_marker.position = Vector3(0, 2.58, 0)
	status_marker.font_size = 54
	status_marker.outline_size = 9
	status_marker.pixel_size = 0.008
	status_marker.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	status_marker.no_depth_test = true
	status_marker.fixed_size = false
	status_marker.visible = false
	add_child(status_marker)

	if hostile:
		health_bar_background = _create_health_bar_part(
			"气血底条", Vector3(0, 2.3, 0), Vector2(1.12, 0.12), Color("#221819")
		)
		health_bar_fill = _create_health_bar_part(
			"气血填充", Vector3(0, 2.295, 0.001), Vector2(1.04, 0.07), Color("#b3413c")
		)
	_refresh_nameplate()


func _refresh_nameplate() -> void:
	if not is_instance_valid(nameplate):
		return
	nameplate.text = (
		"第%d境 · %s" % [actor_level, display_name]
		if hostile
		else display_name
	)
	if is_instance_valid(health_bar_fill):
		var ratio := clampf(float(health) / float(maxi(1, max_health)), 0.0, 1.0)
		health_bar_fill.scale.x = ratio
		health_bar_fill.position.x = -0.52 * (1.0 - ratio)
	_refresh_nameplate_style()


func _refresh_nameplate_style() -> void:
	if not is_instance_valid(nameplate):
		return
	if hostile:
		nameplate.modulate = (
			Color("#ff8a78")
			if alerted or selected
			else (Color("#ffd4aa") if hovered else Color("#e4b7a0"))
		)
	else:
		nameplate.modulate = Color("#f3e49f") if hovered else Color("#d9edcf")


func _refresh_interaction_style() -> void:
	if not is_instance_valid(selection_disc):
		return
	selection_disc.visible = selected or hovered
	if not is_instance_valid(selection_material):
		return
	if selected:
		selection_material.albedo_color = Color(0.95, 0.68, 0.16, 0.68)
	elif hostile:
		selection_material.albedo_color = Color(0.88, 0.24, 0.18, 0.48)
	else:
		selection_material.albedo_color = Color(0.32, 0.74, 0.55, 0.44)
	_refresh_nameplate_style()


func _create_health_bar_part(
	node_name: String,
	at: Vector3,
	bar_size: Vector2,
	color: Color
) -> MeshInstance3D:
	var instance := MeshInstance3D.new()
	instance.name = node_name
	instance.position = at
	instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var mesh := QuadMesh.new()
	mesh.size = bar_size
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	material.no_depth_test = true
	material.albedo_color = color
	mesh.material = material
	instance.mesh = mesh
	add_child(instance)
	return instance


func _hit_flash() -> void:
	if not is_instance_valid(model_root):
		return
	var tween := create_tween()
	tween.tween_property(model_root, "scale", Vector3(1.08, 0.94, 1.08), 0.06)
	tween.tween_property(model_root, "scale", Vector3.ONE, 0.11)


func _finish_action_animation() -> void:
	if animation_state == "defeated":
		return
	_set_animation_state("run" if moving else "idle")


func _set_animation_state(value: String) -> void:
	animation_state = value
	if uses_imported_model:
		_play_imported_animation(value)
		return
	if not is_instance_valid(animation_playback):
		return
	var state_names := {
		"idle": "Idle",
		"run": "Run",
		"attack": "Attack",
		"hit": "Hit",
		"defeated": "Defeated",
	}
	animation_playback.travel(state_names.get(value, "Idle"))


func _play_imported_animation(state: String) -> void:
	if not is_instance_valid(animation_player):
		return
	var preferred := {
		"idle": ["Idle"],
		"run": ["Running_A", "Running_B", "Walking_A"],
		"attack": ["Attack_Slice", "Attack_Chop", "Attack_Stab"],
		"hit": ["Hit_A", "Hit_B", "Hit"],
		"defeated": ["Death_A", "Death_B"],
	}
	var available := animation_player.get_animation_list()
	for requested in preferred.get(state, ["Idle"]):
		for animation_name in available:
			if animation_name == requested or animation_name.ends_with("/%s" % requested):
				animation_player.play(animation_name)
				return


func _limb_pivot(node_name: String, at: Vector3, parent: Node3D) -> Node3D:
	var pivot := Node3D.new()
	pivot.name = node_name
	pivot.position = at
	parent.add_child(pivot)
	return pivot


func _add_box(parent: Node3D, at: Vector3, dimensions: Vector3, color: Color) -> void:
	var instance := MeshInstance3D.new()
	instance.position = at
	var mesh := BoxMesh.new()
	mesh.size = dimensions
	mesh.material = _material(color)
	instance.mesh = mesh
	parent.add_child(instance)


func _add_cylinder(
	parent: Node3D,
	at: Vector3,
	top_radius: float,
	bottom_radius: float,
	height: float,
	color: Color
) -> void:
	var instance := MeshInstance3D.new()
	instance.position = at
	var mesh := CylinderMesh.new()
	mesh.top_radius = top_radius
	mesh.bottom_radius = bottom_radius
	mesh.height = height
	mesh.material = _material(color)
	instance.mesh = mesh
	parent.add_child(instance)


func _add_sphere(parent: Node3D, at: Vector3, radius: float, color: Color) -> void:
	var instance := MeshInstance3D.new()
	instance.position = at
	var mesh := SphereMesh.new()
	mesh.radius = radius
	mesh.height = radius * 2.0
	mesh.radial_segments = 16
	mesh.rings = 8
	mesh.material = _material(color)
	instance.mesh = mesh
	parent.add_child(instance)


func _material(color: Color) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.roughness = 0.78
	return material
