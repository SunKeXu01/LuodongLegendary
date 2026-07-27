extends Node2D

const Actor = preload("res://scripts/wuxia_actor_3d.gd")
const Minimap = preload("res://scripts/minimap_widget.gd")
const CloudFordWorld = preload("res://scripts/cloud_ford_world_3d.gd")
const LootPickup = preload("res://scripts/loot_pickup_3d.gd")

var player: WuxiaActor3D
var enemies: Array[WuxiaActor3D] = []
var selected_enemy: WuxiaActor3D
var world: CloudFordWorld3D
var quest_npc: WuxiaActor3D
var loot_drops: Array[LootPickup3D] = []
var pending_loot: LootPickup3D
var pending_npc: WuxiaActor3D
var retarget_time := 0.0
var enemy_attack_time := 0.0
var health_bar: ProgressBar
var health_label: Label
var level_label: Label
var inner_power_bar: ProgressBar
var experience_bar: ProgressBar
var silver_label: Label
var quest_count: Label
var quest_title_label: Label
var quest_description_label: Label
var message_label: Label
var target_label: Label
var target_health_bar: ProgressBar
var skill_buttons: Array[Button] = []
var qinggong_time := 0.0
var heal_cooldown := 0.0
var hud_layer: CanvasLayer
var active_window: Panel
var restored_world: Dictionary = {}
var environment_label: Label


func _ready() -> void:
	if GameState.consume_load_request():
		restored_world = GameState.load_game()
		if restored_world.is_empty():
			GameState.reset()
	else:
		GameState.reset()
	GameState.apply_settings()
	_create_background()
	_create_player()
	_create_enemies()
	_create_quest_npc()
	_apply_world_snapshot()
	_create_hud()
	GameState.state_changed.connect(_refresh_hud)
	GameState.inventory_changed.connect(_refresh_active_window)
	_refresh_hud()


func _create_background() -> void:
	world = CloudFordWorld.new()
	add_child(world)

	var shade := ColorRect.new()
	shade.color = Color(0.025, 0.035, 0.03, 0.08)
	shade.size = Vector2(1280, 720)
	shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	shade.z_index = -90
	add_child(shade)


func _create_player() -> void:
	player = Actor.new()
	player.display_name = "青冥门少侠"
	player.max_health = GameState.player_max_health
	player.position = Vector3(-1.5, 0.0, 4.8)
	world.add_actor(player)
	world.set_follow_target(player)


func _create_enemies() -> void:
	if GameState.quest_state in ["followup_available", "second_ready", "completed"]:
		return
	if GameState.quest_state == "second_accepted":
		_spawn_enemy_wave(_followup_enemy_specs())
		return
	_spawn_enemy_wave(_initial_enemy_specs())


func _initial_enemy_specs() -> Array:
	return [
		["寒岭门客", Vector3(2.8, 0.0, 1.5), 54],
		["黑衣暗桩", Vector3(5.2, 0.0, 4.5), 72],
		["寂音武僧", Vector3(6.2, 0.0, -2.8), 96],
	]


func _followup_enemy_specs() -> Array:
	return [
		["寒岭追骑", Vector3(-8.0, 0.0, -1.4), 112],
		["武氏刀客", Vector3(-5.8, 0.0, -3.0), 128],
	]


func _spawn_enemy_wave(specs: Array) -> void:
	for spec in specs:
		var enemy: WuxiaActor3D = Actor.new()
		enemy.display_name = spec[0]
		enemy.position = spec[1]
		enemy.max_health = spec[2]
		enemy.hostile = true
		enemy.move_speed = 3.2
		enemy.defeated.connect(_on_enemy_defeated)
		world.add_actor(enemy)
		enemy.enable_patrol(enemy.position, 1.25, float(enemies.size() + 1))
		enemies.append(enemy)


func _create_quest_npc() -> void:
	quest_npc = Actor.new()
	quest_npc.display_name = "渡口巡检·沈砚"
	quest_npc.position = Vector3(-4.5, 0.0, 1.2)
	quest_npc.move_speed = 4.0
	world.add_actor(quest_npc)


func _apply_world_snapshot() -> void:
	if restored_world.is_empty():
		return
	world.set_world_time(float(restored_world.get("world_time", world.get_world_time())))
	var player_position = restored_world.get("player_position", [])
	if player_position is Array and player_position.size() == 3:
		player.global_position = _array_to_vector(player_position)

	if restored_world.has("enemies"):
		var saved_by_name := {}
		for saved_enemy in restored_world.get("enemies", []):
			saved_by_name[str(saved_enemy.get("name", ""))] = saved_enemy
		for enemy in enemies.duplicate():
			if not saved_by_name.has(enemy.display_name):
				enemies.erase(enemy)
				enemy.queue_free()
				continue
			var saved: Dictionary = saved_by_name[enemy.display_name]
			enemy.global_position = _array_to_vector(saved.get("position", []))
			enemy.restore_health(int(saved.get("health", enemy.max_health)))
			enemy.patrol_origin = enemy.global_position

	for saved_loot in restored_world.get("loot", []):
		var item_id := str(saved_loot.get("item_id", ""))
		if not GameState.ITEM_DEFINITIONS.has(item_id):
			continue
		var definition: Dictionary = GameState.ITEM_DEFINITIONS[item_id]
		var loot: LootPickup3D = LootPickup.new()
		loot.configure(
			item_id,
			str(definition["name"]),
			int(saved_loot.get("amount", 1))
		)
		loot.position = _array_to_vector(saved_loot.get("position", []))
		world.add_actor(loot)
		loot_drops.append(loot)


func _world_snapshot() -> Dictionary:
	var enemy_data: Array[Dictionary] = []
	for enemy in enemies:
		if not is_instance_valid(enemy) or enemy.health <= 0:
			continue
		enemy_data.append({
			"name": enemy.display_name,
			"health": enemy.health,
			"position": _vector_to_array(enemy.global_position),
		})
	var loot_data: Array[Dictionary] = []
	for loot in loot_drops:
		if not is_instance_valid(loot):
			continue
		loot_data.append({
			"item_id": loot.item_id,
			"amount": loot.amount,
			"position": _vector_to_array(loot.global_position),
		})
	return {
		"player_position": _vector_to_array(player.global_position),
		"enemies": enemy_data,
		"loot": loot_data,
		"world_time": world.get_world_time(),
	}


func _vector_to_array(value: Vector3) -> Array[float]:
	return [value.x, value.y, value.z]


func _array_to_vector(value: Array) -> Vector3:
	if value.size() != 3:
		return Vector3.ZERO
	return Vector3(float(value[0]), float(value[1]), float(value[2]))


func _save_current_game(notify := false) -> void:
	if GameState.save_game(_world_snapshot()):
		if notify:
			GameState.set_message("游戏进度已经保存。")
	else:
		GameState.set_message("保存失败，请检查游戏数据目录的写入权限。")


func _unhandled_input(event: InputEvent) -> void:
	if not (event is InputEventMouseButton):
		return
	var mouse_event := event as InputEventMouseButton
	if mouse_event.button_index != MOUSE_BUTTON_LEFT or not mouse_event.pressed:
		return
	var click: Vector2 = mouse_event.position
	for loot in loot_drops:
		if not is_instance_valid(loot):
			continue
		var loot_screen := world.world_to_screen(loot.global_position + Vector3(0, 0.45, 0))
		if loot_screen.distance_to(click) <= 34.0:
			_command_collect_loot(loot)
			return
	if is_instance_valid(quest_npc):
		var npc_screen := world.world_to_screen(quest_npc.global_position + Vector3(0, 1.0, 0))
		if npc_screen.distance_to(click) <= 46.0:
			_command_talk_to_npc(quest_npc)
			return
	for enemy in enemies:
		if not is_instance_valid(enemy):
			continue
		var enemy_screen := world.world_to_screen(enemy.global_position + Vector3(0, 0.9, 0))
		if enemy_screen.distance_to(click) <= 42.0:
			_select_enemy(enemy)
			return
	_clear_target()
	_command_player(click)


func _command_player(click: Vector2) -> void:
	pending_loot = null
	pending_npc = null
	var destination := world.screen_to_ground(click)
	player.command_move(destination)
	world.show_move_marker(destination)
	GameState.set_message("正在前往指定位置。点击敌人可自动追击。")


func _select_enemy(enemy: WuxiaActor3D) -> void:
	pending_loot = null
	pending_npc = null
	if is_instance_valid(selected_enemy):
		selected_enemy.selected = false
		selected_enemy.combat_target = null
	selected_enemy = enemy
	selected_enemy.selected = true
	selected_enemy.combat_target = player
	player.combat_target = enemy
	retarget_time = 0.0
	target_label.text = "目标｜%s  %d/%d" % [enemy.display_name, enemy.health, enemy.max_health]
	target_health_bar.max_value = enemy.max_health
	target_health_bar.value = enemy.health
	GameState.set_message("已锁定%s，少侠将自动接近并施展%s。" % [
		enemy.display_name, GameState.selected_skill
	])


func _clear_target() -> void:
	if is_instance_valid(selected_enemy):
		selected_enemy.selected = false
		selected_enemy.combat_target = null
	selected_enemy = null
	player.combat_target = null
	target_label.text = "目标｜尚未选中"
	target_health_bar.value = 0


func _physics_process(delta: float) -> void:
	retarget_time = maxf(0.0, retarget_time - delta)
	enemy_attack_time = maxf(0.0, enemy_attack_time - delta)
	heal_cooldown = maxf(0.0, heal_cooldown - delta)
	if qinggong_time > 0.0:
		qinggong_time = maxf(0.0, qinggong_time - delta)
		if qinggong_time <= 0.0:
			player.move_speed = 5.0
	_update_pending_interactions()
	_update_player_combat()
	_update_enemy_combat()
	if is_instance_valid(environment_label):
		environment_label.text = "%s · %s" % [
			world.get_time_label(), world.get_weather_label()
		]


func _command_collect_loot(loot: LootPickup3D) -> void:
	_clear_target()
	pending_npc = null
	pending_loot = loot
	player.command_move(loot.global_position)
	world.show_move_marker(loot.global_position)
	GameState.set_message("正在前往拾取%s。" % loot.item_name)


func _command_talk_to_npc(npc: WuxiaActor3D) -> void:
	_clear_target()
	pending_loot = null
	pending_npc = npc
	var approach := npc.global_position + npc.global_position.direction_to(player.global_position) * 1.15
	player.command_move(approach)
	world.show_move_marker(approach)
	GameState.set_message("正在前往与%s交谈。" % npc.display_name)


func _update_pending_interactions() -> void:
	if is_instance_valid(pending_loot):
		if player.global_position.distance_to(pending_loot.global_position) <= 0.9:
			_collect_loot(pending_loot)
		return
	if is_instance_valid(pending_npc):
		if player.global_position.distance_to(pending_npc.global_position) <= 1.55:
			player.stop()
			var npc := pending_npc
			pending_npc = null
			_open_npc_dialogue(npc)


func _collect_loot(loot: LootPickup3D) -> void:
	var item_name := loot.item_name
	var amount := loot.amount
	GameState.add_item(loot.item_id, loot.amount)
	loot_drops.erase(loot)
	pending_loot = null
	loot.queue_free()
	AudioManager.play_pickup()
	GameState.set_message("拾取%s ×%d，已放入背包。" % [item_name, amount])
	_save_current_game()


func _update_player_combat() -> void:
	if GameState.player_health <= 0:
		return
	if not is_instance_valid(selected_enemy):
		return
	var distance := player.global_position.distance_to(selected_enemy.global_position)
	if distance > 1.35:
		if retarget_time <= 0.0:
			var approach := (
				selected_enemy.global_position
				+ selected_enemy.global_position.direction_to(player.global_position) * 1.1
			)
			player.command_move(approach)
			retarget_time = 0.35
		return
	player.stop()
	if player.attack_cooldown > 0.0:
		return
	player.attack_cooldown = 0.72
	player.play_attack()
	world.play_skill_effect(
		GameState.selected_skill, player.global_position, selected_enemy.global_position
	)
	var damage := GameState.get_attack()
	if GameState.selected_skill == "伏虎掌":
		damage = roundi(float(GameState.get_attack()) * 1.25)
	elif GameState.selected_skill == "机弩术":
		damage = roundi(float(GameState.get_attack()) * 0.85)
	var target := selected_enemy
	target.take_damage(damage)
	AudioManager.play_hit()
	world.shake_camera(0.11)
	_show_damage(
		target.global_position + Vector3(0, 1.8, 0), damage, Color("#ffe49a")
	)
	if target.health > 0:
		target_label.text = "目标｜%s  %d/%d" % [
			target.display_name, target.health, target.max_health
		]
		target_health_bar.value = target.health
		GameState.set_message("%s命中%s，造成 %d 点伤害。" % [
			GameState.selected_skill, target.display_name, damage
		])


func _update_enemy_combat() -> void:
	if enemy_attack_time > 0.0 or GameState.player_health <= 0:
		return
	for enemy in enemies:
		if not is_instance_valid(enemy):
			continue
		var distance := enemy.global_position.distance_to(player.global_position)
		var distance_from_home := enemy.global_position.distance_to(enemy.patrol_origin)
		if enemy != selected_enemy and distance_from_home > 6.5:
			enemy.combat_target = null
			if not enemy.moving:
				enemy.command_move(enemy.patrol_origin)
			continue
		if enemy == selected_enemy or distance < 4.2:
			enemy.combat_target = player
		elif enemy.combat_target == player and distance > 6.0:
			enemy.combat_target = null
		if enemy.combat_target != player:
			continue
		if distance < 1.15:
			enemy_attack_time = 1.05
			enemy.stop()
			enemy.play_attack()
			world.play_skill_effect("敌人反击", enemy.global_position, player.global_position)
			var enemy_damage := maxi(1, 12 - GameState.get_defense())
			GameState.damage_player(enemy_damage)
			player.play_hit()
			AudioManager.play_hit()
			world.shake_camera(0.23)
			_show_damage(
				player.global_position + Vector3(0, 1.8, 0),
				enemy_damage,
				Color("#ff776d")
			)
			if GameState.player_health == 0:
				player.stop()
				GameState.set_message("少侠气血耗尽。点击右上角“重新闯荡”再次挑战。")
			else:
				GameState.set_message("%s发动反击，少侠损失 %d 点气血。" % [
					enemy.display_name, enemy_damage
				])
			return
		if not enemy.moving or enemy.destination.distance_to(player.global_position) > 0.8:
			var pursuit := (
				player.global_position
				+ player.global_position.direction_to(enemy.global_position) * 0.9
			)
			enemy.command_move(pursuit)


func _on_enemy_defeated(enemy: WuxiaActor3D) -> void:
	var name := enemy.display_name
	var defeated_at := enemy.global_position
	if selected_enemy == enemy:
		selected_enemy = null
		player.combat_target = null
	enemies.erase(enemy)
	enemy.play_defeat()
	get_tree().create_timer(0.55).timeout.connect(enemy.queue_free)
	_spawn_loot(name, defeated_at)
	GameState.add_silver(12)
	GameState.set_message("击败%s，获得碎银 12 两。" % name)
	target_label.text = "目标｜尚未选中"
	target_health_bar.value = 0
	if enemies.is_empty():
		GameState.mark_quest_ready()
	_save_current_game()


func _spawn_loot(enemy_name: String, at: Vector3) -> void:
	var item_id := "healing_salve"
	if enemy_name == "黑衣暗桩":
		item_id = "cold_iron"
	elif enemy_name == "寂音武僧":
		item_id = "monk_bracer"
	elif enemy_name in ["寒岭追骑", "武氏刀客"]:
		item_id = "cold_iron"
	var definition: Dictionary = GameState.ITEM_DEFINITIONS[item_id]
	var loot: LootPickup3D = LootPickup.new()
	loot.configure(item_id, str(definition["name"]), 1)
	loot.position = Vector3(at.x, 0.0, at.z)
	world.add_actor(loot)
	loot_drops.append(loot)


func _show_damage(at: Vector3, amount: int, color: Color) -> void:
	var label := Label.new()
	label.text = "-%d" % amount
	label.position = world.world_to_screen(at) - Vector2(20, 32)
	label.add_theme_font_size_override("font_size", 22)
	label.add_theme_color_override("font_color", color)
	label.add_theme_color_override("font_shadow_color", Color(0.05, 0.03, 0.02, 0.9))
	label.add_theme_constant_override("shadow_offset_x", 2)
	label.add_theme_constant_override("shadow_offset_y", 2)
	label.z_index = 100
	add_child(label)
	var tween := create_tween()
	tween.set_parallel(true)
	tween.tween_property(label, "position:y", label.position.y - 42.0, 0.65)
	tween.tween_property(label, "modulate:a", 0.0, 0.65)
	tween.set_parallel(false)
	tween.tween_callback(label.queue_free)


func _create_hud() -> void:
	hud_layer = CanvasLayer.new()
	hud_layer.layer = 50
	add_child(hud_layer)
	var hud := hud_layer

	var chapter := _panel(Vector2(482, 14), Vector2(316, 40), Color(0.025, 0.035, 0.03, 0.82))
	hud.add_child(chapter)
	_add_label(
		chapter, "明中叶 · 云津渡  |  第一回 渡口风波",
		Vector2(13, 8), Vector2(290, 25), 14, Color("#dac48c"), true
	)

	var status := _panel(Vector2(18, 18), Vector2(340, 118), Color(0.025, 0.04, 0.035, 0.91))
	hud.add_child(status)
	var portrait := _panel(Vector2(12, 16), Vector2(74, 74), Color("#17352d"))
	status.add_child(portrait)
	_add_label(portrait, "侠", Vector2(5, 4), Vector2(64, 64), 34, Color("#e5cb82"), true)
	_add_label(status, "青冥门少侠", Vector2(98, 11), Vector2(150, 25), 18, Color("#f0e6c8"))
	level_label = _add_label(
		status, "", Vector2(245, 13), Vector2(82, 22), 12, Color("#9fc7ad"), true
	)
	health_bar = ProgressBar.new()
	health_bar.position = Vector2(98, 41)
	health_bar.size = Vector2(226, 14)
	health_bar.show_percentage = false
	health_bar.max_value = GameState.player_max_health
	health_bar.add_theme_stylebox_override("background", _style(Color("#211b18"), 3))
	health_bar.add_theme_stylebox_override("fill", _style(Color("#a84235"), 3))
	status.add_child(health_bar)
	health_label = _add_label(status, "", Vector2(101, 40), Vector2(218, 15), 11, Color("#fff0dc"), true)
	inner_power_bar = ProgressBar.new()
	inner_power_bar.position = Vector2(98, 60)
	inner_power_bar.size = Vector2(226, 11)
	inner_power_bar.show_percentage = false
	inner_power_bar.max_value = GameState.player_max_inner_power
	inner_power_bar.add_theme_stylebox_override("background", _style(Color("#111d1b"), 3))
	inner_power_bar.add_theme_stylebox_override("fill", _style(Color("#367c70"), 3))
	status.add_child(inner_power_bar)
	_add_label(status, "内力", Vector2(99, 72), Vector2(40, 17), 11, Color("#87bdb1"))
	experience_bar = ProgressBar.new()
	experience_bar.position = Vector2(98, 92)
	experience_bar.size = Vector2(226, 8)
	experience_bar.show_percentage = false
	experience_bar.max_value = 100
	experience_bar.add_theme_stylebox_override("background", _style(Color("#171713"), 2))
	experience_bar.add_theme_stylebox_override("fill", _style(Color("#b6954e"), 2))
	status.add_child(experience_bar)
	_add_label(status, "境界进度", Vector2(12, 94), Vector2(74, 17), 11, Color("#a9a388"), true)

	var target_panel := _panel(Vector2(468, 66), Vector2(344, 65), Color(0.025, 0.035, 0.03, 0.88))
	hud.add_child(target_panel)
	target_label = _add_label(
		target_panel, "目标｜尚未选中", Vector2(14, 8), Vector2(316, 22), 15, Color("#ead9b1"), true
	)
	target_health_bar = ProgressBar.new()
	target_health_bar.position = Vector2(21, 36)
	target_health_bar.size = Vector2(302, 13)
	target_health_bar.show_percentage = false
	target_health_bar.max_value = 100
	target_health_bar.add_theme_stylebox_override("background", _style(Color("#211b18"), 3))
	target_health_bar.add_theme_stylebox_override("fill", _style(Color("#9f3634"), 3))
	target_panel.add_child(target_health_bar)

	var minimap: MinimapWidget = Minimap.new()
	minimap.position = Vector2(1070, 16)
	minimap.size = Vector2(190, 190)
	minimap.configure(player, enemies)
	hud.add_child(minimap)
	_add_label(minimap, "云津渡", Vector2(57, 160), Vector2(78, 23), 14, Color("#f0d993"), true)
	environment_label = _add_label(
		minimap, "", Vector2(35, 137), Vector2(120, 20), 11, Color("#c7d8cf"), true
	)

	var quest := _panel(Vector2(958, 218), Vector2(302, 148), Color(0.025, 0.04, 0.035, 0.91))
	hud.add_child(quest)
	_add_label(quest, "任务追踪", Vector2(15, 11), Vector2(90, 21), 13, Color("#8fa99a"))
	quest_title_label = _add_label(
		quest, "", Vector2(15, 37), Vector2(238, 25), 18, Color("#ead179")
	)
	quest_description_label = _add_label(
		quest, "", Vector2(15, 66), Vector2(270, 22), 13, Color("#d5cbb2")
	)
	quest_count = _add_label(quest, "", Vector2(15, 96), Vector2(178, 24), 14, Color("#d8b45c"))
	var track := _button(quest, "追踪", Vector2(211, 94), Vector2(72, 36))
	track.tooltip_text = "选择最近的任务目标并自动寻路"
	track.pressed.connect(_track_quest)

	var currency := _panel(Vector2(1092, 376), Vector2(168, 40), Color(0.025, 0.04, 0.035, 0.86))
	hud.add_child(currency)
	silver_label = _add_label(currency, "", Vector2(12, 8), Vector2(144, 24), 14, Color("#e1c268"), true)

	var chat_panel := _panel(Vector2(18, 548), Vector2(370, 104), Color(0.02, 0.03, 0.027, 0.88))
	hud.add_child(chat_panel)
	_add_label(chat_panel, "附近   系统   江湖", Vector2(13, 7), Vector2(170, 23), 13, Color("#c7ab68"))
	message_label = _add_label(
		chat_panel, "", Vector2(13, 33), Vector2(344, 59), 13, Color("#e4dfcf")
	)
	message_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART

	var skill_bar := _panel(Vector2(404, 612), Vector2(548, 96), Color(0.02, 0.03, 0.027, 0.94))
	hud.add_child(skill_bar)
	var skill_names := ["青冥剑式", "伏虎掌", "机弩术", "踏燕行", "调息"]
	var skill_marks := ["剑", "掌", "弩", "轻", "息"]
	for index in skill_names.size():
		var button := _button(
			skill_bar, "%s\n%s" % [skill_marks[index], skill_names[index]],
			Vector2(13 + index * 106, 10), Vector2(96, 68)
		)
		button.set_meta("skill_name", skill_names[index])
		button.tooltip_text = "点击施展%s" % skill_names[index]
		button.pressed.connect(_activate_skill.bind(skill_names[index]))
		skill_buttons.append(button)
	_add_label(
		skill_bar, "左键移动 / 选敌 · 点击武学施放", Vector2(131, 77), Vector2(288, 16),
		11, Color("#979b8a"), true
	)

	var system_panel := _panel(Vector2(974, 646), Vector2(286, 62), Color(0.02, 0.03, 0.027, 0.9))
	hud.add_child(system_panel)
	var menu_names := ["角色", "背包", "武学", "任务", "社交"]
	for index in menu_names.size():
		var menu := _button(system_panel, menu_names[index], Vector2(8 + index * 55, 9), Vector2(51, 44))
		menu.add_theme_font_size_override("font_size", 12)
		menu.pressed.connect(_open_system_panel.bind(menu_names[index]))

	var system := _button(currency, "系统", Vector2(71, 51), Vector2(97, 34))
	system.add_theme_font_size_override("font_size", 12)
	system.pressed.connect(_open_system_window)


func _refresh_hud() -> void:
	health_bar.max_value = GameState.player_max_health
	health_bar.value = GameState.player_health
	health_label.text = "%d / %d" % [GameState.player_health, GameState.player_max_health]
	inner_power_bar.max_value = GameState.player_max_inner_power
	inner_power_bar.value = GameState.player_inner_power
	experience_bar.value = GameState.player_experience
	level_label.text = "%d境 · 青冥门" % GameState.player_level
	silver_label.text = "◆ 碎银  %d" % GameState.silver
	match GameState.quest_state:
		"available":
			quest_title_label.text = "◆ 拜访渡口巡检"
			quest_description_label.text = "沈砚正在渡口商道旁等待少侠。"
			quest_count.text = "点击追踪前往"
		"accepted":
			quest_title_label.text = (
				"◆ 护送商旅" if GameState.quest_route == "protect"
				else "◆ 追查铜签"
			)
			quest_description_label.text = (
				"清除商道伏兵，确保百姓安全撤离。"
				if GameState.quest_route == "protect"
				else "击败暗桩，搜集寒岭武氏的涉案凭证。"
			)
			quest_count.text = "%d / 3 名敌人已清剿" % (3 - enemies.size())
		"ready":
			quest_title_label.text = "◆ 向沈砚复命"
			quest_description_label.text = "伏兵已经清剿，返回巡检处领取酬劳。"
			quest_count.text = "任务可以交付"
		"followup_available":
			quest_title_label.text = "◆ 寒岭追兵"
			quest_description_label.text = "沈砚查明铜签来路，似有追兵正赶往渡口。"
			quest_count.text = "与沈砚继续交谈"
		"second_accepted":
			quest_title_label.text = "◆ 截击寒岭追兵"
			quest_description_label.text = "追兵企图灭口，在渡口北侧截住他们。"
			quest_count.text = "%d / 2 名追兵已击退" % (2 - enemies.size())
		"second_ready":
			quest_title_label.text = "◆ 云津渡复命"
			quest_description_label.text = "追兵已经击退，向沈砚禀明结果。"
			quest_count.text = "序章可以交付"
		"completed":
			quest_title_label.text = "◇ 云津渡风波已平"
			quest_description_label.text = "渡口暂时恢复了往日秩序。"
			quest_count.text = "任务已完成"
	message_label.text = GameState.message
	for button in skill_buttons:
		var skill_name := str(button.get_meta("skill_name"))
		var selected := skill_name == GameState.selected_skill
		button.modulate = Color.WHITE if selected else Color(0.72, 0.72, 0.67)


func _activate_skill(skill_name: String) -> void:
	if skill_name == "踏燕行":
		qinggong_time = 5.0
		player.move_speed = 7.8
		GameState.set_message("踏燕行已施展：五息之内移动速度提升。")
		return
	if skill_name == "调息":
		if heal_cooldown > 0.0:
			GameState.set_message("调息尚未恢复，还需 %.1f 息。" % heal_cooldown)
			return
		if GameState.player_health >= GameState.player_max_health:
			GameState.set_message("当前气血充盈，无需调息。")
			return
		heal_cooldown = 8.0
		GameState.heal_player(25)
		GameState.set_message("运转周天，恢复 25 点气血。")
		return
	GameState.selected_skill = skill_name
	GameState.set_message("已切换为%s，点击敌人即可自动施展。" % skill_name)


func _track_quest() -> void:
	if GameState.quest_state in ["available", "ready", "followup_available", "second_ready"]:
		_command_talk_to_npc(quest_npc)
		return
	if GameState.quest_state == "completed":
		GameState.set_message("本章主线已经完成，新的江湖线索将在后续章节开放。")
		return
	if enemies.is_empty():
		GameState.mark_quest_ready()
		_command_talk_to_npc(quest_npc)
		return
	var nearest := enemies[0]
	var nearest_distance := player.global_position.distance_to(nearest.global_position)
	for enemy in enemies:
		var distance := player.global_position.distance_to(enemy.global_position)
		if distance < nearest_distance:
			nearest = enemy
			nearest_distance = distance
	_select_enemy(nearest)
	GameState.set_message("已追踪%s，正在自动前往任务目标。" % nearest.display_name)


func _open_system_panel(panel_name: String) -> void:
	if panel_name == "背包":
		_open_inventory_window()
	elif panel_name == "角色":
		_open_character_window()
	elif panel_name == "武学":
		_open_martial_window()
	elif panel_name == "任务":
		_open_quest_window()
	else:
		GameState.set_message("社交系统将在联网阶段开放。")


func _open_inventory_window() -> void:
	_close_active_window()
	active_window = _window("随身行囊", "背包")
	_add_label(
		active_window, "点击药品使用，点击装备穿戴。材料会保存在行囊中。",
		Vector2(22, 49), Vector2(420, 24), 13, Color("#aaa991")
	)
	if GameState.inventory.is_empty():
		_add_label(
			active_window, "行囊空空如也。", Vector2(30, 105), Vector2(380, 30),
			16, Color("#bcb49d"), true
		)
		return
	for index in GameState.inventory.size():
		var entry: Dictionary = GameState.inventory[index]
		var item_id := str(entry["id"])
		var definition: Dictionary = GameState.ITEM_DEFINITIONS[item_id]
		var equipped := item_id in GameState.equipment.values()
		var label := "%s%s  ×%d" % [
			"◆ " if equipped else "",
			definition["name"],
			int(entry["count"])
		]
		var item_button := _button(
			active_window,
			label,
			Vector2(22 + (index % 2) * 211, 82 + (index / 2) * 58),
			Vector2(200, 48)
		)
		item_button.tooltip_text = str(definition["description"])
		item_button.pressed.connect(_handle_inventory_item.bind(item_id))


func _open_character_window() -> void:
	_close_active_window()
	active_window = _window("侠客详情", "角色")
	_add_label(active_window, "青冥门少侠", Vector2(24, 52), Vector2(230, 30), 22, Color("#eddbad"))
	_add_label(
		active_window,
		"境界：第%d境\n经验：%d / 100\n气血：%d / %d\n内力：%d / %d\n外功攻击：%d\n外功防御：%d\n云津渡声望：%d" % [
			GameState.player_level, GameState.player_experience,
			GameState.player_health, GameState.player_max_health,
			GameState.player_inner_power, GameState.player_max_inner_power,
			GameState.get_attack(), GameState.get_defense(),
			GameState.cloud_ford_reputation
		],
		Vector2(24, 96), Vector2(200, 230), 15, Color("#d8d0ba")
	)
	_add_label(active_window, "当前装备", Vector2(247, 54), Vector2(160, 26), 17, Color("#cda95e"))
	var slot_names := {"weapon": "兵刃", "armor": "护具", "accessory": "饰物"}
	var row := 0
	for slot in ["weapon", "armor", "accessory"]:
		var item_id := str(GameState.equipment[slot])
		var item_name := "未装备"
		if not item_id.is_empty():
			item_name = str(GameState.ITEM_DEFINITIONS[item_id]["name"])
		_add_label(
			active_window, "%s｜%s" % [slot_names[slot], item_name],
			Vector2(247, 94 + row * 48), Vector2(190, 34), 15, Color("#ded5bd")
		)
		row += 1


func _open_martial_window() -> void:
	_close_active_window()
	active_window = _window("武学谱录", "武学")
	var descriptions := [
		["青冥剑式", "均衡剑法，造成 100% 外功伤害。"],
		["伏虎掌", "刚猛掌法，造成 125% 外功伤害。"],
		["机弩术", "远射机关，造成 85% 外功伤害。"],
		["踏燕行", "五息之内大幅提升移动速度。"],
		["调息", "恢复气血，使用后需要八息调养。"],
	]
	for index in descriptions.size():
		_add_label(
			active_window,
			"%s\n%s" % [descriptions[index][0], descriptions[index][1]],
			Vector2(24, 55 + index * 65), Vector2(410, 56),
			15, Color("#e1d6bb")
		)


func _open_quest_window() -> void:
	_close_active_window()
	active_window = _window("江湖委托", "任务")
	_add_label(
		active_window, GameState.quest_text,
		Vector2(24, 56), Vector2(410, 32), 21, Color("#e5c972")
	)
	var details := quest_description_label.text
	_add_label(
		active_window, details, Vector2(24, 105), Vector2(410, 80),
		15, Color("#d4ccb6")
	)
	var route_name := "尚未抉择"
	if GameState.quest_route == "protect":
		route_name = "护送百姓"
	elif GameState.quest_route == "investigate":
		route_name = "追查证据"
	var progress_text := "行动路线：%s\n云津渡声望：%d" % [
		route_name, GameState.cloud_ford_reputation
	]
	if GameState.quest_route == "investigate":
		progress_text += "\n已取得铜签：%d / 3" % GameState.evidence_count
	_add_label(
		active_window, progress_text, Vector2(24, 176), Vector2(410, 72),
		14, Color("#a9c5b3")
	)
	var track := _button(active_window, "追踪任务", Vector2(24, 270), Vector2(130, 42))
	track.pressed.connect(_track_quest)


func _handle_inventory_item(item_id: String) -> void:
	var definition: Dictionary = GameState.ITEM_DEFINITIONS[item_id]
	var item_type := str(definition["type"])
	if item_type == "consumable":
		GameState.use_item(item_id)
	elif item_type in ["weapon", "armor", "accessory"]:
		GameState.equip_item(item_id)
	else:
		GameState.set_message("%s是锻造材料，暂时无法直接使用。" % definition["name"])
	_save_current_game()


func _open_npc_dialogue(_npc: WuxiaActor3D) -> void:
	_close_active_window()
	active_window = _window("渡口巡检·沈砚", "对话", Vector2(365, 350), Vector2(550, 285))
	if GameState.quest_state == "available":
		var choice_text := (
			"寒岭武氏的暗桩混入云津渡。眼下有两件急事：商旅被困在商道，"
			+ "而失踪者附近又发现了可疑铜签。少侠只能先顾一头。"
		)
		_add_label(
			active_window, choice_text, Vector2(24, 54), Vector2(502, 78),
			16, Color("#e5ddc9")
		).autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		var protect := _button(
			active_window, "护送百姓\n声望奖励较高",
			Vector2(24, 150), Vector2(190, 62)
		)
		protect.pressed.connect(_choose_quest_route.bind("protect"))
		var investigate := _button(
			active_window, "追查证据\n材料奖励较多",
			Vector2(228, 150), Vector2(190, 62)
		)
		investigate.pressed.connect(_choose_quest_route.bind("investigate"))
		var leave_choice := _button(active_window, "容我想想", Vector2(432, 150), Vector2(94, 62))
		leave_choice.pressed.connect(_close_active_window)
		return
	var dialogue := ""
	var action_text := ""
	var action: Callable
	match GameState.quest_state:
		"accepted":
			dialogue = (
				"商道局势未定。先按少侠选定的办法行事，清除三名暗桩后再来找我。"
			)
			action_text = "我这便去"
			action = _close_active_window
		"ready":
			dialogue = (
				"三名暗桩已经伏诛。无论是护住商旅还是取得铜签，"
				+ "少侠都替云津渡解了燃眉之急。这是第一份酬劳。"
			)
			action_text = "领取酬劳"
			action = _turn_in_quest
		"followup_available":
			if GameState.quest_route == "protect":
				dialogue = (
					"获救商旅认出一名寒岭眼线。方才哨探又见两名精锐自北岸赶来，"
					+ "多半是要灭口。若放他们过桥，先前所做便会前功尽弃。"
				)
			else:
				dialogue = (
					"铜签的刻痕指向寒岭武氏。方才哨探又见两名精锐自北岸赶来，"
					+ "多半是要灭口。若放他们过桥，先前所做便会前功尽弃。"
				)
			action_text = "截击追兵"
			action = _accept_followup
		"second_accepted":
			dialogue = "两名追兵正在渡口北侧游弋。此战比先前凶险，少侠务必备好药物。"
			action_text = "前往迎敌"
			action = _close_active_window
		"second_ready":
			dialogue = (
				"追兵已退，商道和证据都保住了。此刀是从武氏兵器库流出的旧物，"
				+ "便赠给少侠防身。云津渡百姓也会记得今日之事。"
			)
			action_text = "完成序章"
			action = _turn_in_quest
		"completed":
			dialogue = "渡口虽已平静，寒岭武氏绝不会善罢甘休。寂音禅院似乎也与失踪商旅有关。"
			action_text = "告辞"
			action = _close_active_window
	_add_label(
		active_window, dialogue, Vector2(24, 56), Vector2(502, 92),
		16, Color("#e5ddc9")
	).autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	var action_button := _button(active_window, action_text, Vector2(292, 205), Vector2(110, 42))
	action_button.pressed.connect(action)
	var leave := _button(active_window, "离开", Vector2(416, 205), Vector2(110, 42))
	leave.pressed.connect(_close_active_window)


func _choose_quest_route(route: String) -> void:
	GameState.choose_quest_route(route)
	if enemies.is_empty():
		GameState.mark_quest_ready()
	AudioManager.play_quest()
	_save_current_game()
	_close_active_window()


func _accept_followup() -> void:
	GameState.accept_followup()
	_spawn_enemy_wave(_followup_enemy_specs())
	AudioManager.play_quest()
	_save_current_game()
	_close_active_window()


func _turn_in_quest() -> void:
	if GameState.quest_state not in ["ready", "second_ready"]:
		return
	_close_active_window()
	if GameState.quest_state == "ready":
		GameState.finish_first_quest()
	else:
		GameState.finish_quest()
	AudioManager.play_quest()
	_save_current_game()


func _window(
	title: String,
	window_type: String,
	at := Vector2(730, 145),
	window_size := Vector2(470, 430)
) -> Panel:
	var window := _panel(at, window_size, Color(0.025, 0.035, 0.03, 0.98))
	window.set_meta("window_type", window_type)
	hud_layer.add_child(window)
	_add_label(window, title, Vector2(20, 13), Vector2(window_size.x - 75, 30), 22, Color("#e7cf91"))
	var close := _button(window, "×", Vector2(window_size.x - 48, 10), Vector2(36, 34))
	close.pressed.connect(_close_active_window)
	return window


func _close_active_window() -> void:
	if is_instance_valid(active_window):
		active_window.queue_free()
	active_window = null


func _refresh_active_window() -> void:
	if not is_instance_valid(active_window):
		return
	var window_type := str(active_window.get_meta("window_type", ""))
	if window_type in ["背包", "角色"]:
		_close_active_window()
		call_deferred("_open_system_panel", window_type)


func _open_system_window() -> void:
	_close_active_window()
	active_window = _window("系统菜单", "系统", Vector2(805, 178), Vector2(395, 390))
	_add_label(
		active_window,
		"存档保存在当前 Windows 用户的游戏数据目录。",
		Vector2(22, 53), Vector2(350, 24), 13, Color("#a9a58f")
	)
	var save_button := _button(active_window, "保存进度", Vector2(24, 90), Vector2(160, 46))
	save_button.pressed.connect(_save_current_game.bind(true))
	var load_button := _button(active_window, "读取进度", Vector2(207, 90), Vector2(160, 46))
	load_button.disabled = not GameState.has_save()
	load_button.pressed.connect(_load_saved_game)
	var settings_button := _button(active_window, "声音与画面", Vector2(24, 154), Vector2(160, 46))
	settings_button.pressed.connect(_open_settings_window)
	var restart_button := _button(active_window, "重开本章", Vector2(207, 154), Vector2(160, 46))
	restart_button.pressed.connect(_restart_game)
	var return_button := _button(active_window, "返回江湖", Vector2(24, 218), Vector2(160, 46))
	return_button.pressed.connect(_close_active_window)
	var exit_button := _button(active_window, "退出游戏", Vector2(207, 218), Vector2(160, 46))
	exit_button.pressed.connect(get_tree().quit)


func _open_settings_window() -> void:
	_close_active_window()
	active_window = _window("声音与画面", "设置", Vector2(805, 190), Vector2(395, 330))
	_add_label(
		active_window,
		"主音量　%d%%" % roundi(GameState.master_volume * 100.0),
		Vector2(28, 72), Vector2(210, 30), 18, Color("#ded4b9")
	)
	var quieter := _button(active_window, "－", Vector2(245, 65), Vector2(52, 42))
	quieter.pressed.connect(_adjust_volume.bind(-0.1))
	var louder := _button(active_window, "＋", Vector2(309, 65), Vector2(52, 42))
	louder.pressed.connect(_adjust_volume.bind(0.1))
	_add_label(
		active_window,
		"显示模式　%s" % ("全屏" if GameState.fullscreen else "窗口"),
		Vector2(28, 139), Vector2(210, 30), 18, Color("#ded4b9")
	)
	var display_button := _button(active_window, "切换模式", Vector2(245, 132), Vector2(116, 42))
	display_button.pressed.connect(_toggle_fullscreen)
	var back := _button(active_window, "返回系统", Vector2(126, 218), Vector2(142, 44))
	back.pressed.connect(_open_system_window)


func _adjust_volume(delta: float) -> void:
	GameState.set_master_volume(GameState.master_volume + delta)
	call_deferred("_open_settings_window")


func _toggle_fullscreen() -> void:
	GameState.toggle_fullscreen()
	call_deferred("_open_settings_window")


func _load_saved_game() -> void:
	if not GameState.has_save():
		GameState.set_message("尚未找到可以读取的存档。")
		return
	GameState.request_load()
	get_tree().reload_current_scene()


func _restart_game() -> void:
	get_tree().reload_current_scene()


func _panel(at: Vector2, panel_size: Vector2, color: Color) -> Panel:
	var panel := Panel.new()
	panel.position = at
	panel.size = panel_size
	panel.mouse_filter = Control.MOUSE_FILTER_STOP
	panel.add_theme_stylebox_override("panel", _style(color, 7, Color("#746246")))
	return panel


func _style(color: Color, radius: int, border := Color.TRANSPARENT) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = color
	style.corner_radius_top_left = radius
	style.corner_radius_top_right = radius
	style.corner_radius_bottom_left = radius
	style.corner_radius_bottom_right = radius
	if border.a > 0.0:
		style.border_width_left = 1
		style.border_width_top = 1
		style.border_width_right = 1
		style.border_width_bottom = 1
		style.border_color = border
	return style


func _add_label(
	parent: Control,
	text: String,
	at: Vector2,
	label_size: Vector2,
	font_size: int,
	color: Color,
	centered := false
) -> Label:
	var label := Label.new()
	label.text = text
	label.position = at
	label.size = label_size
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	if centered:
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	parent.add_child(label)
	return label


func _button(parent: Control, text: String, at: Vector2, button_size: Vector2) -> Button:
	var button := Button.new()
	button.text = text
	button.position = at
	button.size = button_size
	button.focus_mode = Control.FOCUS_NONE
	button.add_theme_font_size_override("font_size", 15)
	button.add_theme_color_override("font_color", Color("#efe3c4"))
	button.add_theme_stylebox_override("normal", _style(Color("#382f25"), 5, Color("#78613e")))
	button.add_theme_stylebox_override("hover", _style(Color("#5a432b"), 5, Color("#d3ae62")))
	button.add_theme_stylebox_override("pressed", _style(Color("#76502c"), 5, Color("#e9ca78")))
	button.pressed.connect(AudioManager.play_ui)
	parent.add_child(button)
	return button
