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
	model_root.position.y = base_height
	add_child(model_root)

	var mesh_instance := MeshInstance3D.new()
	var mesh := BoxMesh.new()
	mesh.size = Vector3(0.3, 0.18, 0.3)
	var material := StandardMaterial3D.new()
	material.albedo_color = Color("#d2b45d")
	material.metallic = 0.25
	material.roughness = 0.42
	material.emission_enabled = true
	material.emission = Color("#6d5424")
	mesh.material = material
	mesh_instance.mesh = mesh
	mesh_instance.rotation_degrees = Vector3(0, 45, 0)
	model_root.add_child(mesh_instance)

	var label := Label3D.new()
	label.position = Vector3(0, 0.55, 0)
	label.text = "%s ×%d" % [item_name, amount]
	label.font_size = 28
	label.outline_size = 7
	label.modulate = Color("#f5d980")
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.no_depth_test = true
	label.fixed_size = true
	model_root.add_child(label)


func _process(delta: float) -> void:
	if not is_instance_valid(model_root):
		return
	bob_phase += delta * 2.8
	model_root.position.y = base_height + sin(bob_phase) * 0.08
	model_root.rotation.y += delta * 0.65
