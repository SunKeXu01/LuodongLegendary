class_name WuxiaActor3D
extends CharacterBody3D

signal defeated(actor: WuxiaActor3D)

@export var display_name := "江湖客"
@export var hostile := false
@export var max_health := 100
@export var move_speed := 5.0

var health: int
var selected := false:
	set(value):
		selected = value
		if is_instance_valid(selection_disc):
			selection_disc.visible = value
var moving := false
var combat_target: WuxiaActor3D
var attack_cooldown := 0.0
var destination := Vector3.ZERO
var selection_disc: MeshInstance3D
var nameplate: Label3D
var weapon_pivot: Node3D
var model_root: Node3D
var walk_phase := 0.0


func _ready() -> void:
	health = max_health
	_create_collision()
	_create_model()
	_create_nameplate()


func command_move(target: Vector3) -> void:
	destination = Vector3(target.x, 0.0, target.z)
	moving = true


func stop() -> void:
	moving = false
	velocity = Vector3.ZERO


func take_damage(amount: int) -> void:
	health = maxi(0, health - amount)
	_refresh_nameplate()
	_hit_flash()
	if health == 0:
		defeated.emit(self)


func play_attack() -> void:
	if not is_instance_valid(weapon_pivot):
		return
	var tween := create_tween()
	tween.tween_property(weapon_pivot, "rotation_degrees:z", -72.0, 0.12)
	tween.tween_property(weapon_pivot, "rotation_degrees:z", 18.0, 0.2)


func _physics_process(delta: float) -> void:
	attack_cooldown = maxf(0.0, attack_cooldown - delta)
	if not moving:
		velocity = Vector3.ZERO
		_set_walk_bob(0.0)
		return
	var offset := destination - global_position
	offset.y = 0.0
	if offset.length() <= 0.18:
		global_position = Vector3(destination.x, global_position.y, destination.z)
		stop()
		_set_walk_bob(0.0)
		return
	var direction := offset.normalized()
	velocity = direction * move_speed
	rotation.y = lerp_angle(rotation.y, atan2(direction.x, direction.z), delta * 12.0)
	move_and_slide()
	walk_phase += delta * 10.0
	_set_walk_bob(sin(walk_phase) * 0.055)


func _create_collision() -> void:
	var collision := CollisionShape3D.new()
	var shape := CapsuleShape3D.new()
	shape.radius = 0.32
	shape.height = 1.5
	collision.shape = shape
	collision.position.y = 0.78
	add_child(collision)


func _create_model() -> void:
	model_root = Node3D.new()
	model_root.name = "武侠角色模型"
	add_child(model_root)

	var robe_color := Color("#31584b") if not hostile else Color("#643238")
	var robe_trim := Color("#d5bd75") if not hostile else Color("#c78d58")
	_add_cylinder(model_root, Vector3(0, 0.72, 0), 0.34, 0.46, 1.1, robe_color)
	_add_sphere(model_root, Vector3(0, 1.48, 0), 0.24, Color("#d2a378"))
	_add_box(model_root, Vector3(0, 1.68, 0), Vector3(0.48, 0.12, 0.42), Color("#202321"))
	_add_box(model_root, Vector3(0, 0.92, 0.29), Vector3(0.52, 0.07, 0.05), robe_trim)

	weapon_pivot = Node3D.new()
	weapon_pivot.position = Vector3(0.35, 1.0, 0.0)
	weapon_pivot.rotation_degrees.z = 18.0
	model_root.add_child(weapon_pivot)
	_add_box(weapon_pivot, Vector3(0, 0.3, 0), Vector3(0.07, 0.85, 0.07), Color("#d9d4b9"))
	_add_box(weapon_pivot, Vector3(0, -0.16, 0), Vector3(0.18, 0.08, 0.1), Color("#745235"))

	selection_disc = MeshInstance3D.new()
	selection_disc.name = "目标选择环"
	selection_disc.position.y = 0.025
	var disc := CylinderMesh.new()
	disc.top_radius = 0.56
	disc.bottom_radius = 0.56
	disc.height = 0.025
	var disc_material := StandardMaterial3D.new()
	disc_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	disc_material.albedo_color = Color(0.94, 0.72, 0.24, 0.52)
	disc_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	disc.material = disc_material
	selection_disc.mesh = disc
	selection_disc.visible = selected
	add_child(selection_disc)


func _create_nameplate() -> void:
	nameplate = Label3D.new()
	nameplate.position = Vector3(0, 2.02, 0)
	nameplate.font_size = 32
	nameplate.outline_size = 8
	nameplate.modulate = Color("#f0d8bc") if hostile else Color("#d9edcf")
	nameplate.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	nameplate.no_depth_test = true
	nameplate.fixed_size = true
	add_child(nameplate)
	_refresh_nameplate()


func _refresh_nameplate() -> void:
	if not is_instance_valid(nameplate):
		return
	nameplate.text = (
		"%s  %d/%d" % [display_name, health, max_health]
		if hostile
		else display_name
	)


func _hit_flash() -> void:
	if not is_instance_valid(model_root):
		return
	var tween := create_tween()
	tween.tween_property(model_root, "scale", Vector3(1.08, 0.94, 1.08), 0.06)
	tween.tween_property(model_root, "scale", Vector3.ONE, 0.11)


func _set_walk_bob(value: float) -> void:
	if is_instance_valid(model_root):
		model_root.position.y = value


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
