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
	"hanling_blade": {
		"name": "寒岭雁翎刀", "type": "weapon", "attack": 9,
		"description": "从寒岭追兵手中缴获的精钢长刀，锋口沉稳。"
	},
	"silent_temple_manual": {
		"name": "寂音机关谱", "type": "accessory", "attack": 3, "defense": 4,
		"description": "记载禅院暗门与铜钟机关的手抄谱册。"
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
var quest_route: String = ""
var cloud_ford_reputation: int = 0
var evidence_count: int = 0
var dungeon_state: String = "locked"
var dungeon_ending: String = ""
var dungeon_approach: String = ""
var inventory: Array[Dictionary] = []
var equipment := {"weapon": "", "armor": "", "accessory": ""}
var item_enhancement: Dictionary = {}
var message: String = "点击任务追踪，前往拜访渡口巡检沈砚。"
var master_volume := 0.72
var fullscreen := false
var load_requested := false


func _ready() -> void:
	load_settings()
	apply_settings()


func reset() -> void:
	player_max_health = 100
	player_max_inner_power = 100
	player_level = 8
	base_attack = 18
	base_defense = 5
	player_health = player_max_health
	player_inner_power = 82
	player_experience = 36
	silver = 0
	selected_skill = "青冥剑式"
	quest_text = "拜访渡口巡检"
	quest_state = "available"
	quest_route = ""
	cloud_ford_reputation = 0
	evidence_count = 0
	dungeon_state = "locked"
	dungeon_ending = ""
	dungeon_approach = ""
	inventory = [
		{"id": "worn_sword", "count": 1},
		{"id": "healing_salve", "count": 2},
	]
	equipment = {"weapon": "worn_sword", "armor": "", "accessory": ""}
	item_enhancement = {}
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


func spend_inner_power(amount: int) -> bool:
	if amount < 0 or player_inner_power < amount:
		return false
	player_inner_power -= amount
	state_changed.emit()
	return true


func restore_inner_power(amount: int) -> void:
	if amount <= 0 or player_inner_power >= player_max_inner_power:
		return
	player_inner_power = mini(player_max_inner_power, player_inner_power + amount)
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


func get_enhancement(item_id: String) -> int:
	return clampi(int(item_enhancement.get(item_id, 0)), 0, 5)


func get_equipped_name(slot: String) -> String:
	var item_id := str(equipment.get(slot, ""))
	if item_id.is_empty():
		return "未装备"
	var definition: Dictionary = ITEM_DEFINITIONS.get(item_id, {})
	var item_name := str(definition.get("name", item_id))
	var enhancement := get_enhancement(item_id)
	return "%s +%d" % [item_name, enhancement] if enhancement > 0 else item_name


func get_upgrade_cost(slot: String) -> Dictionary:
	var item_id := str(equipment.get(slot, ""))
	if item_id.is_empty():
		return {
			"available": false,
			"reason": "当前没有可淬炼的装备。",
			"current": 0,
			"next": 0,
			"material": 0,
			"silver": 0,
		}
	var current := get_enhancement(item_id)
	if current >= 5:
		return {
			"available": false,
			"reason": "此件装备已淬炼至 +5。",
			"item_id": item_id,
			"name": get_equipped_name(slot),
			"current": current,
			"next": current,
			"material": 0,
			"silver": 0,
		}
	var next_level := current + 1
	return {
		"available": true,
		"reason": "",
		"item_id": item_id,
		"name": get_equipped_name(slot),
		"current": current,
		"next": next_level,
		"material": next_level,
		"silver": 25 * next_level,
	}


func upgrade_equipment(slot: String) -> bool:
	var cost := get_upgrade_cost(slot)
	if not bool(cost.get("available", false)):
		set_message(str(cost.get("reason", "当前装备无法淬炼。")))
		return false
	var material_cost := int(cost["material"])
	var silver_cost := int(cost["silver"])
	if get_item_count("cold_iron") < material_cost:
		set_message("寒铁不足：淬炼至 +%d 需要 %d 份寒铁。" % [
			int(cost["next"]), material_cost
		])
		return false
	if silver < silver_cost:
		set_message("碎银不足：淬炼至 +%d 需要 %d 两碎银。" % [
			int(cost["next"]), silver_cost
		])
		return false
	if not _remove_item_silently("cold_iron", material_cost):
		return false
	silver -= silver_cost
	var item_id := str(cost["item_id"])
	item_enhancement[item_id] = int(cost["next"])
	message = "%s淬炼成功：兵刃提升至 +%d，外功攻击增加 2 点。" % [
		str(ITEM_DEFINITIONS[item_id]["name"]), int(cost["next"])
	]
	inventory_changed.emit()
	state_changed.emit()
	return true


func choose_quest_route(route: String) -> void:
	if route not in ["protect", "investigate"] or quest_state != "available":
		return
	quest_route = route
	quest_state = "accepted"
	if route == "protect":
		quest_text = "护送商旅离开伏击区"
		set_message("选择“护送百姓”：清除商道上的三名伏兵，确保商旅安全撤离。")
	else:
		quest_text = "追查失踪商旅的线索"
		set_message("选择“追查证据”：击败三名暗桩，搜寻寒岭武氏留下的线索。")


func mark_quest_ready() -> void:
	if quest_state == "accepted":
		quest_state = "ready"
		quest_text = "向沈砚复命"
		if quest_route == "investigate":
			evidence_count = 3
			set_message("三枚寒岭铜签已经收齐。返回沈砚处查验线索。")
		else:
			set_message("商旅已经安全撤离。返回渡口巡检沈砚处复命。")
	elif quest_state == "second_accepted":
		quest_state = "second_ready"
		quest_text = "击退追兵，向沈砚复命"
		set_message("寒岭追兵已经击退。返回沈砚处结束云津渡风波。")


func finish_first_quest() -> void:
	if quest_state != "ready":
		return
	quest_state = "followup_available"
	quest_text = "查问寒岭追兵"
	add_silver(25)
	add_experience(30)
	add_item("qingming_charm", 1)
	if quest_route == "protect":
		cloud_ford_reputation += 2
		add_item("healing_salve", 2)
		set_message("商旅感念相救：获得碎银 25 两、金疮药与青冥玉符。")
	else:
		cloud_ford_reputation += 1
		add_item("cold_iron", 2)
		set_message("铜签证实寒岭武氏涉案：获得碎银 25 两、寒铁与青冥玉符。")


func accept_followup() -> void:
	if quest_state != "followup_available":
		return
	quest_state = "second_accepted"
	quest_text = "截击寒岭追兵"
	set_message("寒岭武氏派出追兵灭口。前往渡口北侧截击两名精锐。")


func finish_quest() -> void:
	if quest_state != "second_ready":
		return
	quest_state = "completed"
	quest_text = "云津渡风波已平"
	add_silver(50)
	add_experience(45)
	add_item("hanling_blade", 1)
	equip_item("hanling_blade")
	cloud_ford_reputation += 2
	set_message("序章完成：寒岭雁翎刀已自动装备，云津渡声望与境界均获提升。")


func begin_silent_temple() -> void:
	if quest_state != "completed":
		return
	if dungeon_state == "locked":
		dungeon_state = "infiltrate"
		quest_text = "夜探寂音禅院"
		set_message("已进入寂音禅院：避开机关踏板，先解决两名巡夜武僧。")


func mark_temple_guards_cleared() -> void:
	if dungeon_state != "infiltrate":
		return
	dungeon_approach = "force"
	dungeon_state = "mechanism_available"
	quest_text = "关闭地牢机关"
	set_message("巡夜武僧已被制服。点击西偏殿前的机关总闸关闭陷阱。")


func bypass_temple_guards() -> void:
	if dungeon_state != "infiltrate":
		return
	dungeon_approach = "stealth"
	dungeon_state = "rescue"
	quest_text = "营救被困商客"
	add_experience(15)
	set_message("未惊动巡夜武僧便关闭了总闸：获得 15 点潜行经验。")


func disable_temple_traps() -> void:
	if dungeon_state != "mechanism_available":
		return
	dungeon_state = "rescue"
	quest_text = "营救被困商客"
	set_message("机关总闸已经关闭。前往东侧地牢营救被困商客顾行舟。")


func rescue_temple_prisoner() -> void:
	if dungeon_state != "rescue":
		return
	dungeon_state = "boss"
	quest_text = "击败寂音院主"
	set_message("牢门开启惊动了寂音院主。击败院主与两名护院武僧。")


func mark_temple_boss_defeated() -> void:
	if dungeon_state != "boss":
		return
	dungeon_state = "ending"
	quest_text = "裁定禅院余众"
	set_message("寂音院主已经伏诛。与顾行舟商议如何处置禅院余众和赃物。")


func finish_silent_temple(ending: String) -> void:
	if dungeon_state != "ending" or ending not in ["justice", "mercy", "treasure"]:
		return
	dungeon_state = "completed"
	dungeon_ending = ending
	quest_text = "寂音禅院暗局已破"
	add_experience(65)
	add_item("silent_temple_manual", 1)
	equip_item("silent_temple_manual")
	if dungeon_approach == "stealth":
		cloud_ford_reputation += 1
	if ending == "justice":
		add_silver(100)
		cloud_ford_reputation += 3
		set_message("禅院罪证已交按察司：获得碎银 100 两，声望大幅提升。")
	elif ending == "mercy":
		add_silver(70)
		add_item("healing_salve", 3)
		cloud_ford_reputation += 2
		set_message("悔悟僧人获准离院：获得药品与碎银 70 两，江湖声望提升。")
	else:
		add_silver(180)
		cloud_ford_reputation -= 1
		set_message("少侠带走禅院私藏：获得碎银 180 两，但云津渡声望下降。")


func add_experience(amount: int) -> bool:
	if amount <= 0:
		return false
	var leveled_up := false
	player_experience += amount
	while player_experience >= 100:
		player_experience -= 100
		player_level += 1
		player_max_health += 12
		player_max_inner_power += 5
		base_attack += 2
		base_defense += 1
		player_health = player_max_health
		player_inner_power = player_max_inner_power
		leveled_up = true
	state_changed.emit()
	return leveled_up


func save_game(world_snapshot: Dictionary, path := SAVE_PATH) -> bool:
	var payload := {
		"version": SAVE_VERSION,
		"saved_at": Time.get_datetime_string_from_system(),
		"player": {
			"health": player_health,
			"max_health": player_max_health,
			"inner_power": player_inner_power,
			"max_inner_power": player_max_inner_power,
			"experience": player_experience,
			"level": player_level,
			"base_attack": base_attack,
			"base_defense": base_defense,
			"silver": silver,
			"selected_skill": selected_skill,
		},
		"quest": {
			"text": quest_text,
			"state": quest_state,
			"route": quest_route,
			"cloud_ford_reputation": cloud_ford_reputation,
			"evidence_count": evidence_count,
		},
		"dungeon": {
			"state": dungeon_state,
			"ending": dungeon_ending,
			"approach": dungeon_approach,
		},
		"inventory": inventory.duplicate(true),
		"equipment": equipment.duplicate(true),
		"item_enhancement": item_enhancement.duplicate(true),
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
	player_max_health = maxi(1, int(player_data.get("max_health", 100)))
	player_max_inner_power = maxi(1, int(player_data.get("max_inner_power", 100)))
	player_level = maxi(1, int(player_data.get("level", 8)))
	base_attack = maxi(1, int(player_data.get("base_attack", 18)))
	base_defense = maxi(0, int(player_data.get("base_defense", 5)))
	player_health = clampi(int(player_data.get("health", 100)), 0, player_max_health)
	player_inner_power = clampi(
		int(player_data.get("inner_power", 82)), 0, player_max_inner_power
	)
	player_experience = int(player_data.get("experience", 36))
	silver = int(player_data.get("silver", 0))
	selected_skill = str(player_data.get("selected_skill", "青冥剑式"))
	var quest_data: Dictionary = parsed.get("quest", {})
	quest_text = str(quest_data.get("text", "拜访渡口巡检"))
	quest_state = str(quest_data.get("state", "available"))
	quest_route = str(quest_data.get("route", ""))
	cloud_ford_reputation = int(quest_data.get("cloud_ford_reputation", 0))
	evidence_count = int(quest_data.get("evidence_count", 0))
	var dungeon_data: Dictionary = parsed.get("dungeon", {})
	dungeon_state = str(dungeon_data.get("state", "locked"))
	dungeon_ending = str(dungeon_data.get("ending", ""))
	dungeon_approach = str(dungeon_data.get("approach", ""))
	inventory.assign(parsed.get("inventory", []))
	equipment = parsed.get(
		"equipment", {"weapon": "worn_sword", "armor": "", "accessory": ""}
	).duplicate(true)
	item_enhancement = parsed.get("item_enhancement", {}).duplicate(true)
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
	for slot in equipment:
		var item_id := str(equipment[slot])
		if str(item_id).is_empty():
			continue
		var definition: Dictionary = ITEM_DEFINITIONS.get(item_id, {})
		total += int(definition.get(stat_name, 0))
		var enhancement := get_enhancement(item_id)
		if slot == "weapon" and stat_name == "attack":
			total += enhancement * 2
		elif slot == "armor" and stat_name == "defense":
			total += enhancement * 2
		elif slot == "accessory" and stat_name in ["attack", "defense"]:
			total += enhancement
	return total


func _remove_item_silently(item_id: String, amount: int) -> bool:
	for index in range(inventory.size()):
		var entry := inventory[index]
		if entry["id"] != item_id or int(entry["count"]) < amount:
			continue
		entry["count"] = int(entry["count"]) - amount
		if int(entry["count"]) <= 0:
			inventory.remove_at(index)
		return true
	return false


func add_silver(amount: int) -> void:
	silver += amount
	state_changed.emit()
