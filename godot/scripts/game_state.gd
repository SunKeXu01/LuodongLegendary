extends Node

signal state_changed
signal inventory_changed

const ITEM_DEFINITIONS := {
	"worn_sword": {
		"name": "旧制长剑", "type": "weapon", "attack": 4,
		"description": "青冥门外院弟子使用的旧剑。"
	},
	"healing_salve": {
		"name": "金疮药", "type": "consumable", "heal": 32,
		"description": "使用后恢复 32 点气血。"
	},
	"cold_iron": {
		"name": "寒铁碎片", "type": "material",
		"description": "寒岭武氏兵刃上脱落的精铁。"
	},
	"monk_bracer": {
		"name": "武僧护腕", "type": "armor", "defense": 3,
		"description": "结实的皮革护腕，能够减轻外伤。"
	},
	"qingming_charm": {
		"name": "青冥玉符", "type": "accessory", "attack": 2, "defense": 2,
		"description": "沈砚赠予的青玉信物，刻有青冥云纹。"
	},
}
const SAVE_VERSION := 1
const SAVE_PATH := "user://luodong_save.json"
const SETTINGS_PATH := "user://luodong_settings.json"

var player_health: int = 100
var player_max_health: int = 100
var player_inner_power: int = 82
var player_max_inner_power: int = 100
var player_experience: int = 36
var player_level: int = 8
var base_attack: int = 18
var base_defense: int = 5
var silver: int = 0
var selected_skill: String = "青冥剑式"
var quest_text: String = "拜访渡口巡检"
var quest_state: String = "available"
var inventory: Array[Dictionary] = []
var equipment := {"weapon": "", "armor": "", "accessory": ""}
var message: String = "点击任务追踪，前往拜访渡口巡检沈砚。"
var master_volume := 0.72
var fullscreen := false
var load_requested := false


func _ready() -> void:
	load_settings()
	apply_settings()


func reset() -> void:
	player_health = player_max_health
	player_inner_power = 82
	player_experience = 36
	silver = 0
	selected_skill = "青冥剑式"
	quest_text = "拜访渡口巡检"
	quest_state = "available"
	inventory = [
		{"id": "worn_sword", "count": 1},
		{"id": "healing_salve", "count": 2},
	]
	equipment = {"weapon": "worn_sword", "armor": "", "accessory": ""}
	message = "点击任务追踪，前往拜访渡口巡检沈砚。"
	state_changed.emit()
	inventory_changed.emit()


func set_message(value: String) -> void:
	message = value
	state_changed.emit()


func damage_player(amount: int) -> void:
	player_health = maxi(0, player_health - amount)
	state_changed.emit()


func heal_player(amount: int) -> void:
	player_health = mini(player_max_health, player_health + amount)
	state_changed.emit()


func add_item(item_id: String, amount := 1) -> void:
	if not ITEM_DEFINITIONS.has(item_id) or amount <= 0:
		return
	for entry in inventory:
		if entry["id"] == item_id:
			entry["count"] = int(entry["count"]) + amount
			inventory_changed.emit()
			state_changed.emit()
			return
	inventory.append({"id": item_id, "count": amount})
	inventory_changed.emit()
	state_changed.emit()


func remove_item(item_id: String, amount := 1) -> bool:
	for index in range(inventory.size()):
		var entry := inventory[index]
		if entry["id"] != item_id or int(entry["count"]) < amount:
			continue
		entry["count"] = int(entry["count"]) - amount
		if int(entry["count"]) <= 0:
			inventory.remove_at(index)
		inventory_changed.emit()
		state_changed.emit()
		return true
	return false


func use_item(item_id: String) -> bool:
	var definition: Dictionary = ITEM_DEFINITIONS.get(item_id, {})
	if definition.get("type", "") != "consumable":
		return false
	if player_health >= player_max_health:
		set_message("当前气血充盈，无需使用%s。" % definition["name"])
		return false
	if not remove_item(item_id, 1):
		return false
	heal_player(int(definition.get("heal", 0)))
	set_message("使用%s，恢复 %d 点气血。" % [
		definition["name"], int(definition.get("heal", 0))
	])
	return true


func equip_item(item_id: String) -> bool:
	var definition: Dictionary = ITEM_DEFINITIONS.get(item_id, {})
	var item_type := str(definition.get("type", ""))
	if item_type not in ["weapon", "armor", "accessory"]:
		return false
	equipment[item_type] = item_id
	inventory_changed.emit()
	set_message("已装备%s，角色属性获得提升。" % definition["name"])
	return true


func get_attack() -> int:
	return base_attack + _equipment_bonus("attack")


func get_defense() -> int:
	return base_defense + _equipment_bonus("defense")


func get_item_count(item_id: String) -> int:
	for entry in inventory:
		if entry["id"] == item_id:
			return int(entry["count"])
	return 0


func accept_quest() -> void:
	quest_state = "accepted"
	quest_text = "清剿云津渡伏兵"
	set_message("已接受任务“云津渡伏兵”，清剿潜伏在渡口的三名暗桩。")


func mark_quest_ready() -> void:
	if quest_state != "accepted":
		return
	quest_state = "ready"
	quest_text = "向沈砚复命"
	set_message("伏兵已经清剿。返回渡口巡检沈砚处复命。")


func finish_quest() -> void:
	quest_state = "completed"
	quest_text = "云津渡风波已平"
	add_silver(50)
	add_item("qingming_charm", 1)
	set_message("任务完成：获得碎银 50 两与青冥玉符。")


func save_game(world_snapshot: Dictionary, path := SAVE_PATH) -> bool:
	var payload := {
		"version": SAVE_VERSION,
		"saved_at": Time.get_datetime_string_from_system(),
		"player": {
			"health": player_health,
			"inner_power": player_inner_power,
			"experience": player_experience,
			"level": player_level,
			"silver": silver,
			"selected_skill": selected_skill,
		},
		"quest": {
			"text": quest_text,
			"state": quest_state,
		},
		"inventory": inventory.duplicate(true),
		"equipment": equipment.duplicate(true),
		"world": world_snapshot.duplicate(true),
	}
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		return false
	file.store_string(JSON.stringify(payload, "\t"))
	return true


func load_game(path := SAVE_PATH) -> Dictionary:
	if not FileAccess.file_exists(path):
		return {}
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		return {}
	var parsed = JSON.parse_string(file.get_as_text())
	if not (parsed is Dictionary) or int(parsed.get("version", 0)) != SAVE_VERSION:
		return {}
	var player_data: Dictionary = parsed.get("player", {})
	player_health = clampi(int(player_data.get("health", 100)), 0, player_max_health)
	player_inner_power = clampi(
		int(player_data.get("inner_power", 82)), 0, player_max_inner_power
	)
	player_experience = int(player_data.get("experience", 36))
	player_level = int(player_data.get("level", 8))
	silver = int(player_data.get("silver", 0))
	selected_skill = str(player_data.get("selected_skill", "青冥剑式"))
	var quest_data: Dictionary = parsed.get("quest", {})
	quest_text = str(quest_data.get("text", "拜访渡口巡检"))
	quest_state = str(quest_data.get("state", "available"))
	inventory.assign(parsed.get("inventory", []))
	equipment = parsed.get(
		"equipment", {"weapon": "worn_sword", "armor": "", "accessory": ""}
	).duplicate(true)
	message = "存档读取成功，江湖历程已经恢复。"
	inventory_changed.emit()
	state_changed.emit()
	return parsed.get("world", {}).duplicate(true)


func has_save(path := SAVE_PATH) -> bool:
	return FileAccess.file_exists(path)


func request_load() -> void:
	load_requested = true


func consume_load_request() -> bool:
	var requested := load_requested
	load_requested = false
	return requested


func save_settings(path := SETTINGS_PATH) -> bool:
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		return false
	file.store_string(JSON.stringify({
		"master_volume": master_volume,
		"fullscreen": fullscreen,
	}, "\t"))
	return true


func load_settings(path := SETTINGS_PATH) -> void:
	if not FileAccess.file_exists(path):
		return
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		return
	var parsed = JSON.parse_string(file.get_as_text())
	if not (parsed is Dictionary):
		return
	master_volume = clampf(float(parsed.get("master_volume", 0.72)), 0.0, 1.0)
	fullscreen = bool(parsed.get("fullscreen", false))


func apply_settings() -> void:
	AudioServer.set_bus_volume_db(
		AudioServer.get_bus_index("Master"),
		linear_to_db(maxf(0.001, master_volume))
	)
	DisplayServer.window_set_mode(
		DisplayServer.WINDOW_MODE_FULLSCREEN
		if fullscreen
		else DisplayServer.WINDOW_MODE_WINDOWED
	)


func set_master_volume(value: float) -> void:
	master_volume = clampf(value, 0.0, 1.0)
	apply_settings()
	save_settings()
	state_changed.emit()


func toggle_fullscreen() -> void:
	fullscreen = not fullscreen
	apply_settings()
	save_settings()
	state_changed.emit()


func _equipment_bonus(stat_name: String) -> int:
	var total := 0
	for item_id in equipment.values():
		if str(item_id).is_empty():
			continue
		var definition: Dictionary = ITEM_DEFINITIONS.get(item_id, {})
		total += int(definition.get(stat_name, 0))
	return total


func add_silver(amount: int) -> void:
	silver += amount
	state_changed.emit()
