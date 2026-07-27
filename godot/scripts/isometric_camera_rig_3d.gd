class_name IsometricCameraRig3D
extends Node3D

# Adapted from marinho/isometric-3d-toolkit:
# src/camera/IsometricCamera3D.cs and src/camera/CameraShaker.cs
# Upstream commit: 95d3507560f80e44a8eb67f40807185c8d0b10fb
# License: CC BY 4.0. The implementation is translated to GDScript and expanded
# with orthographic projection, target damping, mouse zoom and bounded shake.

@export var orthographic := true
@export var orthographic_size := 15.5
@export var minimum_orthographic_size := 11.5
@export var maximum_orthographic_size := 20.0
@export var perspective_fov := 43.0
@export var follow_offset := Vector3(0.0, 15.5, 18.5)
@export var focus_offset := Vector3(0.0, 0.0, -1.6)
@export var follow_damping := 3.4
@export var shake_fade := 1.35

var camera: Camera3D
var target: Node3D
var shake_strength := 0.0
var random := RandomNumberGenerator.new()


func _ready() -> void:
	random.seed = 0x4C554F44
	camera = Camera3D.new()
	camera.name = "IsometricCamera"
	camera.projection = (
		Camera3D.PROJECTION_ORTHOGONAL
		if orthographic
		else Camera3D.PROJECTION_PERSPECTIVE
	)
	camera.size = orthographic_size
	camera.fov = perspective_fov
	camera.position = follow_offset
	add_child(camera)
	_update_camera_transform(1.0)


func _process(delta: float) -> void:
	_update_camera_transform(delta)


func set_target(value: Node3D, snap := true) -> void:
	target = value
	if snap:
		force_snap()


func force_snap() -> void:
	if not is_instance_valid(target) or not is_instance_valid(camera):
		return
	var focus := target.global_position + focus_offset
	camera.global_position = focus + follow_offset
	camera.look_at(focus, Vector3.UP)


func apply_shake(strength: float) -> void:
	shake_strength = maxf(shake_strength, strength)


func zoom_by_steps(steps: float) -> void:
	if orthographic:
		orthographic_size = clampf(
			orthographic_size + steps * 0.9,
			minimum_orthographic_size,
			maximum_orthographic_size
		)
		camera.size = orthographic_size
	else:
		perspective_fov = clampf(perspective_fov + steps * 2.0, 34.0, 58.0)
		camera.fov = perspective_fov


func get_zoom_label() -> String:
	return "正交 %.1f" % orthographic_size if orthographic else "透视 %.0f°" % perspective_fov


func _update_camera_transform(delta: float) -> void:
	if not is_instance_valid(camera):
		return
	var focus := focus_offset
	if is_instance_valid(target):
		focus += target.global_position
	var desired := focus + follow_offset
	if shake_strength > 0.001:
		desired += Vector3(
			random.randf_range(-shake_strength, shake_strength),
			random.randf_range(-shake_strength * 0.45, shake_strength * 0.45),
			random.randf_range(-shake_strength, shake_strength)
		)
		shake_strength = move_toward(shake_strength, 0.0, delta * shake_fade)
	var weight := 1.0 if delta >= 1.0 else minf(1.0, delta * follow_damping)
	camera.global_position = camera.global_position.lerp(desired, weight)
	camera.look_at(focus, Vector3.UP)
