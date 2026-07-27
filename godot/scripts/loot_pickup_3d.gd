class_name LootPickup3D
extends Node3D

var item_id := ""
var item_name := "江湖遗物"
var amount := 1
var model_root: Node3D
var base_height := 0.28
var bob_phase := 0.0


func configure(new_item_id: String, new_name: String, new_amount: int) -> void:
	item_id = new_item_id
	item_name = new_name
	amount = new_amount


func _ready() -> void:
	model_root = Node3D.new()
	model_root.name = "掉落表现"
	model_root.position.y = base_height
	add_child(model_root)

	var mesh_instance := MeshInstance3D.new()
	var mesh := BoxMesh.new()
	mesh.size = Vector3(0.3, 0.18, 0.3)
	var loot_color := _loot_color()
	var material := StandardMaterial3D.new()
	material.albedo_color = loot_color
	material.metallic = 0.25
	material.roughness = 0.42
	material.emission_enabled = true
	material.emission = loot_color * 0.55
	mesh.material = material
	mesh_instance.mesh = mesh
	mesh_instance.rotation_degrees = Vector3(0, 45, 0)
	model_root.add_child(mesh_instance)

	var beam := MeshInstance3D.new()
	beam.name = "掉落光柱"
	beam.position = Vector3(0, 0.82, 0)
	beam.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var beam_mesh := CylinderMesh.new()
	beam_mesh.top_radius = 0.035
	beam_mesh.bottom_radius = 0.095
	beam_mesh.height = 1.35
	beam_mesh.radial_segments = 12
	var beam_material := StandardMaterial3D.new()
	beam_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	beam_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	beam_material.albedo_color = Color(loot_color, 0.24)
	beam_material.emission_enabled = true
	beam_material.emission = loot_color
	beam_material.emission_energy_multiplier = 1.4
	beam_mesh.material = beam_material
	beam.mesh = beam_mesh
	model_root.add_child(beam)

	var label := Label3D.new()
	label.name = "掉落名牌"
	label.position = Vector3(0, 1.62, 0)
	label.text = "%s ×%d" % [item_name, amount]
	label.font_size = 40
	label.outline_size = 7
	label.pixel_size = 0.008
	label.modulate = loot_color.lightened(0.26)
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.no_depth_test = true
	label.fixed_size = false
	model_root.add_child(label)


func _process(delta: float) -> void:
	if not is_instance_valid(model_root):
		return
	bob_phase += delta * 2.8
	model_root.position.y = base_height + sin(bob_phase) * 0.08
	model_root.rotation.y += delta * 0.65


func _loot_color() -> Color:
	match item_id:
		"healing_salve":
			return Color("#77cf83")
		"cold_iron":
			return Color("#72b8d4")
		"monk_bracer", "qingming_charm", "hanling_blade", "silent_temple_manual":
			return Color("#e4b85c")
	return Color("#d8cfad")
