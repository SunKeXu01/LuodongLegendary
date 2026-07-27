extends Node2D

const Actor = preload("res://scripts/wuxia_actor_3d.gd")
const Minimap = preload("res://scripts/minimap_widget.gd")
const CloudFordWorld = preload("res://scripts/cloud_ford_world_3d.gd")
const SilentTempleWorld = preload("res://scripts/silent_temple_world_3d.gd")
const LootPickup = preload("res://scripts/loot_pickup_3d.gd")
const SKILL_DATA := {
	"青冥剑式": {"cost": 0, "cooldown": 0.78, "range": 1.4, "damage": 1.0},
	"伏虎掌": {"cost": 14, "cooldown": 2.8, "range": 1.55, "damage": 1.5},
	"机弩术": {"cost": 18, "cooldown": 3.6, "range": 5.6, "damage": 1.05},
	"踏燕行": {"cost": 20, "cooldown": 10.0, "duration": 5.0},
	"调息": {"cost": 26, "cooldown": 12.0, "heal": 32},
}

var player: WuxiaActor3D
var enemies: Array[WuxiaActor3D] = []
var selected_enemy: WuxiaActor3D
var world: CloudFordWorld3D
var quest_npc: WuxiaActor3D
var smith_npc: WuxiaActor3D
var loot_drops: Array[LootPickup3D] = []
var pending_loot: LootPickup3D
var pending_npc: WuxiaActor3D
var pending_mechanism: Node3D
var pending_map_interaction: Node3D
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
var hover_hint_panel: Panel
var hover_hint_label: Label
var skill_buttons: Array[Button] = []
var skill_cooldown_overlays: Dictionary = {}
var skill_cooldown_labels: Dictionary = {}
var skill_cost_labels: Dictionary = {}
var combat_cast_panel: Panel
var combat_cast_bar: ProgressBar
var combat_cast_label: Label
var qinggong_time := 0.0
var queued_skill := ""
var skill_cooldowns := {
	"伏虎掌": 0.0,
	"机弩术": 0.0,
	"踏燕行": 0.0,
	"调息": 0.0,
}
var inner_power_regen_buffer := 0.0
var hud_layer: CanvasLayer
var active_window: Panel
var restored_world: Dictionary = {}
var environment_label: Label
var minimap: MinimapWidget
var location_label: Label
var chapter_label: Label
var current_zone := "cloud_ford"
var dungeon_hazard_cooldown := 0.0
var boss_phase := 0
var boss_skill_cooldown := 3.0
var boss_telegraph_time := 0.0
var boss_telegraph_total := 0.0
var boss_telegraph_radius := 0.0
var boss_telegraph_origin := Vector3.ZERO
var boss_telegraph: MeshInstance3D
var hovered_actor: WuxiaActor3D


func _ready() -> void:
	if GameState.consume_load_request():
		restored_world = GameState.load_game()
		if restored_world.is_empty():
			GameState.reset()
	else:
		GameState.reset()
	current_zone = str(restored_world.get("current_zone", "cloud_ford"))
	if current_zone == "silent_temple" and GameState.dungeon_state == "locked":
		current_zone = "cloud_ford"
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
	world = (
		SilentTempleWorld.new()
		if current_zone == "silent_temple"
		else CloudFordWorld.new()
	)
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
	player.visual_variant = "hero"
	player.max_health = GameState.player_max_health
	player.position = (
		Vector3(0.0, 0.0, 6.0)
		if current_zone == "silent_temple"
		else Vector3(-1.5, 0.0, 4.8)
	)
	world.add_actor(player)
	world.set_follow_target(player)


func _create_enemies() -> void:
	if current_zone == "silent_temple":
		if GameState.dungeon_state == "infiltrate":
			_spawn_enemy_wave(_temple_guard_specs())
		elif GameState.dungeon_state == "boss":
			_spawn_enemy_wave(_temple_boss_specs())
		return
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
		["寒岭追骑", Vector3(-8.0, 0.0, -1.4), 112, 16],
		["武氏刀客", Vector3(-5.8, 0.0, -3.0), 128, 17],
	]


func _temple_guard_specs() -> Array:
	return [
		["巡夜武僧", Vector3(-3.8, 0.0, 2.2), 118, 17, true],
		["持棍戒僧", Vector3(3.6, 0.0, 0.2), 136, 18, true],
	]


func _temple_boss_specs() -> Array:
	return [
		["寂音院主·法砚", Vector3(0.0, 0.0, -3.8), 260, 25],
		["护院武僧·左", Vector3(-3.2, 0.0, -2.5), 120, 18],
		["护院武僧·右", Vector3(3.2, 0.0, -2.5), 120, 18],
	]


func _spawn_enemy_wave(specs: Array) -> void:
	for spec in specs:
		var enemy: WuxiaActor3D = Actor.new()
		enemy.display_name = spec[0]
		enemy.position = spec[1]
		enemy.max_health = spec[2]
		enemy.attack_power = int(spec[3]) if spec.size() > 3 else 12
		enemy.actor_level = GameState.player_level
		if enemy.display_name == "寂音院主·法砚":
			enemy.actor_level += 2
			enemy.visual_variant = "boss"
		elif enemy.max_health >= 112:
			enemy.actor_level += 1
			enemy.visual_variant = "enemy"
		else:
			enemy.visual_variant = "enemy"
		enemy.hostile = true
		enemy.move_speed = 3.2
		enemy.defeated.connect(_on_enemy_defeated)
		world.add_actor(enemy)
		if spec.size() > 4 and bool(spec[4]):
			enemy.enable_vision_cone()
		enemy.enable_patrol(enemy.position, 1.25, float(enemies.size() + 1))
		enemies.append(enemy)


func _create_quest_npc() -> void:
	quest_npc = Actor.new()
	if current_zone == "silent_temple":
		quest_npc.display_name = "被困商客·顾行舟"
		quest_npc.position = Vector3(7.2, 0.0, -0.8)
	else:
		quest_npc.display_name = "渡口巡检·沈砚"
		quest_npc.position = Vector3(-4.5, 0.0, 1.2)
	quest_npc.move_speed = 4.0
	quest_npc.visual_variant = "npc"
	world.add_actor(quest_npc)
	if current_zone == "silent_temple":
		smith_npc = null
		world.set_mechanism_active(
			GameState.dungeon_state in ["infiltrate", "mechanism_available"]
		)
	else:
		smith_npc = Actor.new()
		smith_npc.display_name = "渡口铁匠·鲁三火"
		smith_npc.visual_variant = "enemy"
		smith_npc.position = Vector3(-5.8, 0.0, 4.6)
		smith_npc.move_speed = 4.0
		world.add_actor(smith_npc)


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
		"current_zone": current_zone,
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
	if not mouse_event.pressed:
		return
	if mouse_event.button_index in [MOUSE_BUTTON_WHEEL_UP, MOUSE_BUTTON_WHEEL_DOWN]:
		var zoom_step := -1.0 if mouse_event.button_index == MOUSE_BUTTON_WHEEL_UP else 1.0
		world.zoom_camera(zoom_step)
		GameState.set_message("镜头缩放｜%s" % world.get_camera_mode_label())
		return
	if mouse_event.button_index != MOUSE_BUTTON_LEFT:
		return
	var click: Vector2 = mouse_event.position
	if current_zone == "silent_temple" and is_instance_valid(world.mechanism_marker):
		var mechanism_screen := world.world_to_screen(
			world.mechanism_marker.global_position + Vector3(0, 1.0, 0)
		)
		if mechanism_screen.distance_to(click) <= 48.0:
			if GameState.dungeon_state == "mechanism_available":
				_command_use_mechanism()
			elif GameState.dungeon_state == "infiltrate":
				if _temple_guards_alerted():
					GameState.set_message("守卫已经进入警戒，无法悄然操作总闸。")
				else:
					_command_use_mechanism()
			else:
				GameState.set_message("机关总闸已经失去作用。")
			return
	for loot in loot_drops:
		if not is_instance_valid(loot):
			continue
		var loot_screen := world.world_to_screen(loot.global_position + Vector3(0, 0.45, 0))
		if loot_screen.distance_to(click) <= 34.0:
			_command_collect_loot(loot)
			return
	if is_instance_valid(smith_npc):
		var smith_screen := world.world_to_screen(
			smith_npc.global_position + Vector3(0, 1.0, 0)
		)
		if smith_screen.distance_to(click) <= 46.0:
			_command_talk_to_npc(smith_npc)
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
	if current_zone == "cloud_ford" and is_instance_valid(world.rest_marker):
		var rest_screen := world.world_to_screen(
			world.rest_marker.global_position + Vector3(0, 0.75, 0)
		)
		if rest_screen.distance_to(click) <= 52.0:
			_command_use_rest_station()
			return
	_clear_target()
	_command_player(click)


func _command_player(click: Vector2) -> void:
	pending_loot = null
	pending_npc = null
	pending_mechanism = null
	pending_map_interaction = null
	var destination := world.screen_to_ground(click)
	player.command_move(destination)
	world.show_move_marker(destination)
	GameState.set_message("正在前往指定位置。点击敌人可自动追击。")


func _select_enemy(enemy: WuxiaActor3D) -> void:
	pending_loot = null
	pending_npc = null
	pending_mechanism = null
	pending_map_interaction = null
	if is_instance_valid(selected_enemy):
		selected_enemy.selected = false
		selected_enemy.combat_target = null
	selected_enemy = enemy
	selected_enemy.selected = true
	selected_enemy.combat_target = player
	selected_enemy.set_alerted(true)
	player.combat_target = enemy
	retarget_time = 0.0
	target_label.text = "目标｜%s  %d/%d" % [enemy.display_name, enemy.health, enemy.max_health]
	target_health_bar.max_value = enemy.max_health
	target_health_bar.value = enemy.health
	GameState.set_message("已锁定%s，将自动施展青冥剑式；点击技能栏可排队释放绝技。" % enemy.display_name)


func _clear_target() -> void:
	if is_instance_valid(selected_enemy):
		selected_enemy.selected = false
		selected_enemy.combat_target = null
	selected_enemy = null
	player.combat_target = null
	queued_skill = ""
	target_label.text = "目标｜尚未选中"
	target_health_bar.value = 0


func _physics_process(delta: float) -> void:
	retarget_time = maxf(0.0, retarget_time - delta)
	enemy_attack_time = maxf(0.0, enemy_attack_time - delta)
	for skill_name in skill_cooldowns:
		skill_cooldowns[skill_name] = maxf(
			0.0, float(skill_cooldowns[skill_name]) - delta
		)
	inner_power_regen_buffer += delta * (2.0 if is_instance_valid(selected_enemy) else 4.5)
	if inner_power_regen_buffer >= 1.0:
		var recovered := floori(inner_power_regen_buffer)
		inner_power_regen_buffer -= recovered
		GameState.restore_inner_power(recovered)
	dungeon_hazard_cooldown = maxf(0.0, dungeon_hazard_cooldown - delta)
	if qinggong_time > 0.0:
		qinggong_time = maxf(0.0, qinggong_time - delta)
		if qinggong_time <= 0.0:
			player.move_speed = 5.0
	_update_pending_interactions()
	_update_hover_feedback()
	_update_player_combat()
	_update_enemy_combat()
	_update_dungeon_hazards()
	_update_boss_mechanics(delta)
	_refresh_skill_buttons()
	_refresh_combat_cast_bar()
	if is_instance_valid(environment_label):
		environment_label.text = "%s · %s" % [
			world.get_time_label(), world.get_weather_label()
		]


func _command_collect_loot(loot: LootPickup3D) -> void:
	_clear_target()
	pending_npc = null
	pending_mechanism = null
	pending_map_interaction = null
	pending_loot = loot
	player.command_move(loot.global_position)
	world.show_move_marker(loot.global_position)
	GameState.set_message("正在前往拾取%s。" % loot.item_name)


func _command_talk_to_npc(npc: WuxiaActor3D) -> void:
	_clear_target()
	pending_loot = null
	pending_mechanism = null
	pending_map_interaction = null
	pending_npc = npc
	var approach := npc.global_position + npc.global_position.direction_to(player.global_position) * 1.15
	player.command_move(approach)
	world.show_move_marker(approach)
	GameState.set_message("正在前往与%s交谈。" % npc.display_name)


func _command_use_mechanism() -> void:
	_close_active_window()
	_clear_target()
	pending_loot = null
	pending_npc = null
	pending_map_interaction = null
	pending_mechanism = world.mechanism_marker
	var approach := pending_mechanism.global_position + Vector3(0.9, 0, 0.4)
	player.command_move(approach)
	world.show_move_marker(approach)
	GameState.set_message("正在靠近机关总闸。")


func _command_use_rest_station() -> void:
	if current_zone != "cloud_ford" or not is_instance_valid(world.rest_marker):
		return
	_close_active_window()
	_clear_target()
	pending_loot = null
	pending_npc = null
	pending_mechanism = null
	pending_map_interaction = world.rest_marker
	var approach := world.rest_marker.global_position + Vector3(0.95, 0, 0.65)
	player.command_move(approach)
	world.show_move_marker(approach)
	GameState.set_message("正在前往渡口茶棚休整。")


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
		return
	if is_instance_valid(pending_mechanism):
		if player.global_position.distance_to(pending_mechanism.global_position) <= 1.45:
			player.stop()
			pending_mechanism = null
			if GameState.dungeon_state == "infiltrate":
				if _temple_guards_alerted():
					GameState.set_message("守卫已经发现少侠，只能先将他们制服。")
					return
				GameState.bypass_temple_guards()
				_despawn_temple_guards()
			else:
				GameState.disable_temple_traps()
			world.set_mechanism_active(false)
			AudioManager.play_quest()
			world.shake_camera(0.16)
			_save_current_game()
		return
	if is_instance_valid(pending_map_interaction):
		if player.global_position.distance_to(pending_map_interaction.global_position) <= 1.45:
			player.stop()
			pending_map_interaction = null
			if GameState.rest_at_tea_stall():
				AudioManager.play_quest()
				world.shake_camera(0.08)
				_save_current_game()


func _temple_guards_alerted() -> bool:
	for enemy in enemies:
		if is_instance_valid(enemy) and (enemy.alerted or enemy.combat_target == player):
			return true
	return false


func _despawn_temple_guards() -> void:
	if is_instance_valid(selected_enemy):
		_clear_target()
	for enemy in enemies.duplicate():
		enemies.erase(enemy)
		enemy.queue_free()


func _update_dungeon_hazards() -> void:
	if (
		current_zone != "silent_temple"
		or GameState.dungeon_state not in ["infiltrate", "mechanism_available"]
		or dungeon_hazard_cooldown > 0.0
		or GameState.player_health <= 0
	):
		return
	var point := Vector2(player.global_position.x, player.global_position.z)
	var trap_areas := [
		Rect2(-2.45, 0.85, 0.9, 0.9),
		Rect2(-1.45, -0.95, 0.9, 0.9),
		Rect2(-0.45, 0.85, 0.9, 0.9),
		Rect2(0.55, -0.95, 0.9, 0.9),
		Rect2(1.55, 0.85, 0.9, 0.9),
	]
	for area in trap_areas:
		if not area.has_point(point):
			continue
		dungeon_hazard_cooldown = 1.25
		GameState.damage_player(10)
		player.play_hit()
		AudioManager.play_hit()
		world.shake_camera(0.28)
		_show_damage(player.global_position + Vector3(0, 1.8, 0), 10, Color("#de8b64"))
		GameState.set_message("踩中翻板暗弩，损失 10 点气血。关闭总闸可解除机关。")
		return


func _update_boss_mechanics(delta: float) -> void:
	if current_zone != "silent_temple" or GameState.dungeon_state != "boss":
		_clear_boss_telegraph()
		boss_phase = 0
		return
	var boss := _get_temple_boss()
	if not is_instance_valid(boss):
		_clear_boss_telegraph()
		return
	var health_ratio := float(boss.health) / float(maxi(1, boss.max_health))
	var next_phase := 1 if health_ratio > 0.66 else (2 if health_ratio > 0.33 else 3)
	if next_phase > boss_phase:
		boss_phase = next_phase
		boss_skill_cooldown = minf(boss_skill_cooldown, 2.2)
		GameState.set_message("寂音院主进入第 %d 阶段，范围招式变得更加凶险。" % boss_phase)
	if is_instance_valid(boss_telegraph):
		boss_telegraph_time -= delta
		var progress := 1.0 - boss_telegraph_time / maxf(0.01, boss_telegraph_total)
		var scale_value := lerpf(0.2, 1.0, clampf(progress, 0.0, 1.0))
		boss_telegraph.scale = Vector3(scale_value, 1.0, scale_value)
		if boss_telegraph_time <= 0.0:
			_resolve_boss_telegraph()
		return
	boss_skill_cooldown -= delta
	if boss_skill_cooldown <= 0.0:
		_start_boss_telegraph(boss)


func _get_temple_boss() -> WuxiaActor3D:
	for enemy in enemies:
		if is_instance_valid(enemy) and enemy.display_name == "寂音院主·法砚":
			return enemy
	return null


func _start_boss_telegraph(boss: WuxiaActor3D) -> void:
	boss_telegraph_radius = 1.9 + boss_phase * 0.48
	boss_telegraph_total = 1.55 - boss_phase * 0.18
	boss_telegraph_time = boss_telegraph_total
	boss_telegraph_origin = (
		boss.global_position
		if boss_phase == 1
		else player.global_position
	)
	boss_telegraph = MeshInstance3D.new()
	boss_telegraph.name = "院主范围招式预警"
	boss_telegraph.position = boss_telegraph_origin + Vector3(0, 0.07, 0)
	var mesh := CylinderMesh.new()
	mesh.top_radius = boss_telegraph_radius
	mesh.bottom_radius = boss_telegraph_radius
	mesh.height = 0.035
	mesh.radial_segments = 48
	var material := StandardMaterial3D.new()
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.albedo_color = Color(0.88, 0.12, 0.08, 0.34)
	mesh.material = material
	boss_telegraph.mesh = mesh
	boss_telegraph.scale = Vector3(0.2, 1.0, 0.2)
	world.world_root.add_child(boss_telegraph)
	GameState.set_message("院主正在蓄力“震钟劲”！立即点击预警圈外的地面躲避。")


func _resolve_boss_telegraph() -> void:
	var damage := 14 + boss_phase * 7
	if player.global_position.distance_to(boss_telegraph_origin) <= boss_telegraph_radius:
		GameState.damage_player(damage)
		player.play_hit()
		AudioManager.play_hit()
		world.shake_camera(0.38)
		_show_damage(
			player.global_position + Vector3(0, 1.8, 0),
			damage,
			Color("#ff5e48")
		)
		if GameState.player_health <= 0:
			player.stop()
			GameState.set_message("少侠被震钟劲击倒。读取存档或重开本章后再战。")
		else:
			GameState.set_message("未能及时躲开震钟劲，损失 %d 点气血。" % damage)
	else:
		GameState.set_message("少侠及时离开预警区域，避开了震钟劲。")
	_clear_boss_telegraph()
	boss_skill_cooldown = 6.2 - boss_phase * 0.75


func _clear_boss_telegraph() -> void:
	if is_instance_valid(boss_telegraph):
		boss_telegraph.queue_free()
	boss_telegraph = null
	boss_telegraph_time = 0.0


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
	var skill_name := queued_skill if not queued_skill.is_empty() else "青冥剑式"
	var skill: Dictionary = SKILL_DATA[skill_name]
	var attack_range := float(skill["range"])
	var distance := player.global_position.distance_to(selected_enemy.global_position)
	if distance > attack_range:
		if retarget_time <= 0.0:
			var approach := (
				selected_enemy.global_position
				+ selected_enemy.global_position.direction_to(player.global_position)
				* maxf(0.9, attack_range - 0.2)
			)
			player.command_move(approach)
			retarget_time = 0.35
		return
	player.stop()
	if player.attack_cooldown > 0.0:
		return
	var inner_power_cost := int(skill["cost"])
	if inner_power_cost > 0 and not GameState.spend_inner_power(inner_power_cost):
		queued_skill = ""
		GameState.set_message("内力不足，无法施展%s；已继续使用青冥剑式。" % skill_name)
		return
	if skill_cooldowns.has(skill_name):
		skill_cooldowns[skill_name] = float(skill["cooldown"])
	queued_skill = ""
	GameState.selected_skill = skill_name
	player.attack_cooldown = 0.48 if skill_name != "青冥剑式" else float(skill["cooldown"])
	player.play_attack()
	world.play_skill_effect(
		skill_name, player.global_position, selected_enemy.global_position
	)
	var damage := roundi(float(GameState.get_attack()) * float(skill["damage"]))
	var target := selected_enemy
	target.take_damage(damage)
	if (
		skill_name == "伏虎掌"
		and target.display_name == "寂音院主·法砚"
		and is_instance_valid(boss_telegraph)
	):
		boss_telegraph_time += 0.35
		boss_telegraph_total += 0.35
	AudioManager.play_hit()
	world.shake_camera(0.16 if skill_name == "伏虎掌" else 0.11)
	_show_damage(
		target.global_position + Vector3(0, 1.8, 0), damage, Color("#ffe49a")
	)
	if target.health > 0:
		target_label.text = "目标｜%s  %d/%d" % [
			target.display_name, target.health, target.max_health
		]
		target_health_bar.value = target.health
		var combat_message := "%s命中%s，造成 %d 点伤害。" % [
			skill_name, target.display_name, damage
		]
		if skill_name == "伏虎掌" and is_instance_valid(boss_telegraph):
			combat_message += " 刚劲扰乱院主气息，蓄力延长 0.35 息。"
		GameState.set_message(combat_message)


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
			enemy.set_alerted(false)
			if not enemy.moving:
				enemy.command_move(enemy.patrol_origin)
			continue
		var sentry_mode := (
			current_zone == "silent_temple"
			and GameState.dungeon_state == "infiltrate"
			and enemy.vision_radius > 0.0
		)
		if sentry_mode:
			var spotted := enemy.can_see(player)
			if enemy == selected_enemy or spotted:
				if not enemy.alerted:
					GameState.set_message("%s发现了少侠，潜行路线暂时失效！" % enemy.display_name)
				enemy.combat_target = player
				enemy.set_alerted(true)
			elif enemy.combat_target == player and distance > 7.0:
				enemy.combat_target = null
				enemy.set_alerted(false)
		else:
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
			var enemy_damage := maxi(1, enemy.attack_power - GameState.get_defense())
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
		queued_skill = ""
	enemies.erase(enemy)
	enemy.play_defeat()
	get_tree().create_timer(0.55).timeout.connect(enemy.queue_free)
	_spawn_loot(name, defeated_at)
	GameState.add_silver(12)
	GameState.set_message("击败%s，获得碎银 12 两。" % name)
	target_label.text = "目标｜尚未选中"
	target_health_bar.value = 0
	if enemies.is_empty():
		if current_zone == "silent_temple":
			if GameState.dungeon_state == "infiltrate":
				GameState.mark_temple_guards_cleared()
				world.set_mechanism_active(true)
			elif GameState.dungeon_state == "boss":
				GameState.mark_temple_boss_defeated()
		else:
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
	elif enemy_name == "寂音院主·法砚":
		item_id = "cold_iron"
	elif enemy_name.begins_with("护院") or enemy_name in ["巡夜武僧", "持棍戒僧"]:
		item_id = "healing_salve"
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
	chapter_label = _add_label(
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

	var target_panel := _panel(Vector2(468, 66), Vector2(344, 65), Color(0.025, 0.035, 0.03, 0.91))
	hud.add_child(target_panel)
	var target_seal := _panel(Vector2(9, 8), Vector2(44, 44), Color("#5b2525"))
	target_panel.add_child(target_seal)
	_add_label(
		target_seal, "敌", Vector2(2, 1), Vector2(40, 40),
		23, Color("#f1d2a0"), true
	)
	target_label = _add_label(
		target_panel, "目标｜尚未选中", Vector2(62, 7), Vector2(268, 22),
		15, Color("#ead9b1"), true
	)
	target_health_bar = ProgressBar.new()
	target_health_bar.position = Vector2(62, 36)
	target_health_bar.size = Vector2(264, 13)
	target_health_bar.show_percentage = false
	target_health_bar.max_value = 100
	target_health_bar.add_theme_stylebox_override("background", _style(Color("#211b18"), 3))
	target_health_bar.add_theme_stylebox_override("fill", _style(Color("#9f3634"), 3))
	target_panel.add_child(target_health_bar)

	combat_cast_panel = _panel(
		Vector2(476, 139), Vector2(328, 38), Color(0.03, 0.035, 0.03, 0.92)
	)
	combat_cast_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	combat_cast_panel.visible = false
	hud.add_child(combat_cast_panel)
	combat_cast_bar = ProgressBar.new()
	combat_cast_bar.position = Vector2(8, 18)
	combat_cast_bar.size = Vector2(312, 11)
	combat_cast_bar.show_percentage = false
	combat_cast_bar.min_value = 0
	combat_cast_bar.max_value = 1
	combat_cast_bar.add_theme_stylebox_override("background", _style(Color("#211b18"), 2))
	combat_cast_bar.add_theme_stylebox_override("fill", _style(Color("#b64b37"), 2))
	combat_cast_panel.add_child(combat_cast_bar)
	combat_cast_label = _add_label(
		combat_cast_panel, "", Vector2(8, 1), Vector2(312, 17),
		12, Color("#f1d09a"), true
	)

	hover_hint_panel = _panel(
		Vector2(476, 184), Vector2(328, 34), Color(0.025, 0.035, 0.03, 0.88)
	)
	hover_hint_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hover_hint_panel.visible = false
	hud.add_child(hover_hint_panel)
	hover_hint_label = _add_label(
		hover_hint_panel, "", Vector2(10, 6), Vector2(308, 22),
		13, Color("#ead79b"), true
	)

	minimap = Minimap.new()
	minimap.position = Vector2(1070, 16)
	minimap.size = Vector2(190, 190)
	minimap.configure(player, enemies)
	hud.add_child(minimap)
	location_label = _add_label(
		minimap, "", Vector2(45, 160), Vector2(100, 23), 14, Color("#f0d993"), true
	)
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

	var skill_bar := _panel(Vector2(390, 604), Vector2(576, 104), Color(0.02, 0.03, 0.027, 0.95))
	hud.add_child(skill_bar)
	var skill_names := ["青冥剑式", "伏虎掌", "机弩术", "踏燕行", "调息"]
	var skill_marks := ["剑", "掌", "弩", "轻", "息"]
	for index in skill_names.size():
		var button := _button(
			skill_bar, skill_marks[index],
			Vector2(15 + index * 112, 8), Vector2(98, 78)
		)
		button.set_meta("skill_name", skill_names[index])
		button.set_meta("skill_mark", skill_marks[index])
		button.tooltip_text = _skill_tooltip(skill_names[index])
		button.add_theme_font_size_override("font_size", 25)
		button.pressed.connect(_activate_skill.bind(skill_names[index]))
		var cooldown_overlay := ColorRect.new()
		cooldown_overlay.name = "冷却遮罩"
		cooldown_overlay.color = Color(0.02, 0.025, 0.022, 0.72)
		cooldown_overlay.position = Vector2.ZERO
		cooldown_overlay.size = button.size
		cooldown_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
		cooldown_overlay.visible = false
		button.add_child(cooldown_overlay)
		var skill_name_label := _add_label(
			button, skill_names[index], Vector2(4, 54), Vector2(90, 20),
			11, Color("#e6d8b4"), true
		)
		skill_name_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var cost_label := _add_label(
			button, "", Vector2(50, 4), Vector2(42, 17),
			10, Color("#8fc6b6"), true
		)
		cost_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var cooldown_label := _add_label(
			button, "", Vector2(5, 25), Vector2(88, 25),
			16, Color("#fff0cf"), true
		)
		cooldown_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		cooldown_label.visible = false
		skill_cooldown_overlays[skill_names[index]] = cooldown_overlay
		skill_cooldown_labels[skill_names[index]] = cooldown_label
		skill_cost_labels[skill_names[index]] = cost_label
		skill_buttons.append(button)
	_add_label(
		skill_bar, "纯鼠标操作 · 左键寻路 / 选敌 / 施展武学",
		Vector2(126, 86), Vector2(324, 16),
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
	location_label.text = world.get_location_label()
	chapter_label.text = (
		"明中叶 · 寂音禅院  |  第二回 古刹暗局"
		if current_zone == "silent_temple"
		else "明中叶 · 云津渡  |  第一回 渡口风波"
	)
	if current_zone == "silent_temple":
		_refresh_dungeon_hud()
	else:
		_refresh_cloud_ford_hud()
	message_label.text = GameState.message
	_refresh_world_markers()
	for button in skill_buttons:
		var skill_name := str(button.get_meta("skill_name"))
		var selected := (
			skill_name == queued_skill
			or (queued_skill.is_empty() and skill_name == "青冥剑式")
		)
		button.modulate = Color.WHITE if selected else Color(0.72, 0.72, 0.67)
	_refresh_skill_buttons()


func _refresh_world_markers() -> void:
	if is_instance_valid(smith_npc):
		smith_npc.set_interaction_marker("锻", Color("#ed9b4b"))
	if not is_instance_valid(quest_npc):
		return
	var marker := ""
	var color := Color("#e5c35b")
	if current_zone == "silent_temple":
		match GameState.dungeon_state:
			"rescue":
				marker = "!"
			"ending":
				marker = "?"
			"completed":
				marker = "归"
				color = Color("#8fc9a4")
	else:
		match GameState.quest_state:
			"available", "followup_available":
				marker = "!"
			"ready", "second_ready":
				marker = "?"
			"completed":
				if GameState.dungeon_state != "completed":
					marker = "!"
	quest_npc.set_interaction_marker(marker, color)


func _update_hover_feedback() -> void:
	if is_instance_valid(active_window):
		if current_zone == "cloud_ford":
			world.set_rest_station_hovered(false)
		_set_hovered_actor(null)
		return
	var pointer := get_viewport().get_mouse_position()
	var nearest: WuxiaActor3D
	var nearest_distance := 9999.0
	var candidates: Array[WuxiaActor3D] = []
	if is_instance_valid(smith_npc):
		candidates.append(smith_npc)
	if is_instance_valid(quest_npc):
		candidates.append(quest_npc)
	for enemy in enemies:
		if is_instance_valid(enemy):
			candidates.append(enemy)
	for actor in candidates:
		var screen_position := world.world_to_screen(
			actor.global_position + Vector3(0, 1.0, 0)
		)
		var distance := screen_position.distance_to(pointer)
		if distance <= 48.0 and distance < nearest_distance:
			nearest = actor
			nearest_distance = distance
	if is_instance_valid(nearest):
		if current_zone == "cloud_ford":
			world.set_rest_station_hovered(false)
		_set_hovered_actor(nearest)
		return
	_set_hovered_actor(null)
	if current_zone == "cloud_ford" and is_instance_valid(world.rest_marker):
		var rest_screen := world.world_to_screen(
			world.rest_marker.global_position + Vector3(0, 0.75, 0)
		)
		if rest_screen.distance_to(pointer) <= 52.0:
			world.set_rest_station_hovered(true)
			hover_hint_panel.visible = true
			hover_hint_label.text = "左键使用｜渡口茶棚休整"
			Input.set_default_cursor_shape(Input.CURSOR_POINTING_HAND)
			return
		world.set_rest_station_hovered(false)


func _set_hovered_actor(actor: WuxiaActor3D) -> void:
	if is_instance_valid(hovered_actor) and hovered_actor != actor:
		hovered_actor.hovered = false
	hovered_actor = actor
	if not is_instance_valid(hovered_actor):
		hovered_actor = null
		if is_instance_valid(hover_hint_panel):
			hover_hint_panel.visible = false
		Input.set_default_cursor_shape(Input.CURSOR_ARROW)
		return
	hovered_actor.hovered = true
	hover_hint_panel.visible = true
	Input.set_default_cursor_shape(Input.CURSOR_POINTING_HAND)
	if hovered_actor.hostile:
		hover_hint_label.text = "左键锁定｜第%d境 · %s" % [
			hovered_actor.actor_level, hovered_actor.display_name
		]
	elif hovered_actor == smith_npc:
		hover_hint_label.text = "左键交谈｜淬炼兵刃"
	else:
		hover_hint_label.text = "左键交谈｜%s" % hovered_actor.display_name


func _refresh_cloud_ford_hud() -> void:
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
			if GameState.dungeon_state == "locked":
				quest_title_label.text = "◆ 寂音禅院线索"
				quest_description_label.text = "沈砚查到失踪商旅被押往深山古刹。"
				quest_count.text = "与沈砚交谈进入副本"
			elif GameState.dungeon_state == "completed":
				quest_title_label.text = "◇ 寂音禅院暗局已破"
				quest_description_label.text = "失踪案已了结，渡口暂时恢复秩序。"
				quest_count.text = "副本已完成"
			else:
				quest_title_label.text = "◆ 重返寂音禅院"
				quest_description_label.text = "寂音禅院的调查仍未结束。"
				quest_count.text = "与沈砚交谈返回副本"


func _refresh_dungeon_hud() -> void:
	match GameState.dungeon_state:
		"infiltrate":
			quest_title_label.text = "◆ 夜探寂音禅院"
			quest_description_label.text = "避开黄色视野锥潜入总闸，或正面制服守卫。"
			quest_count.text = "潜行总闸 / 强攻 %d / 2" % (2 - enemies.size())
		"mechanism_available":
			quest_title_label.text = "◆ 关闭机关总闸"
			quest_description_label.text = "西偏殿前的橙色拉杆控制暗弩与牢门。"
			quest_count.text = "点击场景中的机关总闸"
		"rescue":
			quest_title_label.text = "◆ 营救被困商客"
			quest_description_label.text = "机关已经关闭，前往东侧地牢。"
			quest_count.text = (
				"潜行成功 · 与顾行舟交谈"
				if GameState.dungeon_approach == "stealth"
				else "强攻完成 · 与顾行舟交谈"
			)
		"boss":
			quest_title_label.text = "◆ 击败寂音院主"
			quest_description_label.text = "院主带着护院武僧赶到地牢前。"
			quest_count.text = "%d / 3 名首领卫队已击败" % (3 - enemies.size())
		"ending":
			quest_title_label.text = "◆ 裁定禅院余众"
			quest_description_label.text = "罪证、悔悟僧人与赃物都等待处置。"
			quest_count.text = "与顾行舟选择副本结局"
		"completed":
			quest_title_label.text = "◇ 寂音禅院暗局已破"
			quest_description_label.text = "副本结局已经写入江湖历程。"
			quest_count.text = "可返回云津渡"


func _activate_skill(skill_name: String) -> void:
	if not SKILL_DATA.has(skill_name):
		return
	var skill: Dictionary = SKILL_DATA[skill_name]
	var cooldown_left := float(skill_cooldowns.get(skill_name, 0.0))
	if cooldown_left > 0.0:
		GameState.set_message("%s尚在调息，还需 %.1f 息。" % [skill_name, cooldown_left])
		return
	var cost := int(skill["cost"])
	if GameState.player_inner_power < cost:
		GameState.set_message("内力不足：%s需要 %d 点内力。" % [skill_name, cost])
		return
	if skill_name == "踏燕行":
		GameState.spend_inner_power(cost)
		skill_cooldowns[skill_name] = float(skill["cooldown"])
		qinggong_time = float(skill["duration"])
		player.move_speed = 7.8
		GameState.selected_skill = skill_name
		GameState.set_message("踏燕行已施展：五息之内移动速度提升。")
		return
	if skill_name == "调息":
		if GameState.player_health >= GameState.player_max_health:
			GameState.set_message("当前气血充盈，无需调息。")
			return
		GameState.spend_inner_power(cost)
		skill_cooldowns[skill_name] = float(skill["cooldown"])
		GameState.selected_skill = skill_name
		GameState.heal_player(int(skill["heal"]))
		GameState.set_message("运转周天，消耗 %d 点内力并恢复 %d 点气血。" % [
			cost, int(skill["heal"])
		])
		return
	if skill_name == "青冥剑式":
		queued_skill = ""
		GameState.selected_skill = skill_name
		GameState.set_message("已切回青冥剑式，将对选中目标持续自动攻击。")
		return
	if not is_instance_valid(selected_enemy):
		GameState.set_message("请先点击选择敌人，再施展%s。" % skill_name)
		return
	queued_skill = skill_name
	GameState.selected_skill = skill_name
	retarget_time = 0.0
	GameState.set_message("%s已排入施放队列，少侠会自动接近有效射程。" % skill_name)


func _refresh_skill_buttons() -> void:
	for button in skill_buttons:
		var skill_name := str(button.get_meta("skill_name"))
		var skill: Dictionary = SKILL_DATA[skill_name]
		var cooldown_left := float(skill_cooldowns.get(skill_name, 0.0))
		var cooldown_total := float(skill["cooldown"])
		var overlay := skill_cooldown_overlays.get(skill_name) as ColorRect
		var cooldown_label := skill_cooldown_labels.get(skill_name) as Label
		var cost_label := skill_cost_labels.get(skill_name) as Label
		if is_instance_valid(cost_label):
			cost_label.text = (
				"自动"
				if skill_name == "青冥剑式"
				else "%d 内" % int(skill["cost"])
			)
		if is_instance_valid(overlay):
			var ratio := clampf(cooldown_left / maxf(0.01, cooldown_total), 0.0, 1.0)
			overlay.visible = cooldown_left > 0.05
			overlay.position.y = button.size.y * (1.0 - ratio)
			overlay.size = Vector2(button.size.x, button.size.y * ratio)
		if is_instance_valid(cooldown_label):
			cooldown_label.visible = cooldown_left > 0.05 or queued_skill == skill_name
			cooldown_label.text = (
				"候招"
				if queued_skill == skill_name
				else ("%.1f" % cooldown_left if cooldown_left > 0.05 else "")
			)
		button.modulate = (
			Color("#fff5dc")
			if queued_skill == skill_name
			else (Color("#d6d6ce") if cooldown_left <= 0.05 else Color("#8a8e88"))
		)


func _refresh_combat_cast_bar() -> void:
	if not is_instance_valid(combat_cast_panel):
		return
	if is_instance_valid(boss_telegraph):
		combat_cast_panel.visible = true
		combat_cast_label.text = "危险｜寂音院主正在蓄力 · 震钟劲"
		combat_cast_bar.value = clampf(
			1.0 - boss_telegraph_time / maxf(0.01, boss_telegraph_total),
			0.0,
			1.0
		)
		return
	if not queued_skill.is_empty() and is_instance_valid(selected_enemy):
		var skill: Dictionary = SKILL_DATA[queued_skill]
		var distance := player.global_position.distance_to(selected_enemy.global_position)
		var required_range := float(skill["range"])
		combat_cast_panel.visible = true
		combat_cast_label.text = "候招｜%s · 自动接近有效射程" % queued_skill
		combat_cast_bar.value = clampf(required_range / maxf(required_range, distance), 0.0, 1.0)
		return
	combat_cast_panel.visible = false


func _skill_tooltip(skill_name: String) -> String:
	var descriptions := {
		"青冥剑式": "基础自动攻击｜近战｜不消耗内力",
		"伏虎掌": "150% 外功伤害｜近战｜可延缓院主蓄力",
		"机弩术": "105% 外功伤害｜5.6 丈远程射程",
		"踏燕行": "五息内大幅提高移动速度",
		"调息": "恢复 32 点气血",
	}
	var skill: Dictionary = SKILL_DATA[skill_name]
	return "%s\n消耗：%d 内力　冷却：%.1f 息" % [
		descriptions[skill_name], int(skill["cost"]), float(skill["cooldown"])
	]


func _track_quest() -> void:
	if current_zone == "silent_temple":
		if GameState.dungeon_state == "mechanism_available":
			_command_use_mechanism()
			return
		if GameState.dungeon_state in ["rescue", "ending", "completed"]:
			_command_talk_to_npc(quest_npc)
			return
		if enemies.is_empty():
			GameState.set_message("当前区域没有可以追踪的战斗目标。")
			return
		_select_nearest_enemy()
		return
	if GameState.quest_state in ["available", "ready", "followup_available", "second_ready"]:
		_command_talk_to_npc(quest_npc)
		return
	if GameState.quest_state == "completed":
		_command_talk_to_npc(quest_npc)
		return
	if enemies.is_empty():
		GameState.mark_quest_ready()
		_command_talk_to_npc(quest_npc)
		return
	_select_nearest_enemy()


func _select_nearest_enemy() -> void:
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
		var enhancement := GameState.get_enhancement(item_id)
		var display_name := str(definition["name"])
		if enhancement > 0:
			display_name += " +%d" % enhancement
		var label := "%s%s  ×%d" % [
			"◆ " if equipped else "",
			display_name,
			int(entry["count"])
		]
		var item_button := _button(
			active_window,
			label,
			Vector2(22 + (index % 2) * 211, 82 + (index / 2) * 58),
			Vector2(200, 48)
		)
		item_button.tooltip_text = str(definition["description"])
		if enhancement > 0:
			item_button.tooltip_text += "\n淬炼等级：+%d" % enhancement
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
		_add_label(
			active_window, "%s｜%s" % [slot_names[slot], GameState.get_equipped_name(slot)],
			Vector2(247, 94 + row * 48), Vector2(190, 34), 15, Color("#ded5bd")
		)
		row += 1


func _open_martial_window() -> void:
	_close_active_window()
	active_window = _window("武学谱录", "武学")
	var descriptions := [
		["青冥剑式", "基础自动攻击｜100% 外功｜0 内力"],
		["伏虎掌", "150% 外功｜14 内力｜2.8 息冷却｜延缓首领蓄力"],
		["机弩术", "105% 外功｜18 内力｜3.6 息冷却｜5.6 丈射程"],
		["踏燕行", "20 内力｜10 息冷却｜五息内大幅提升移动速度"],
		["调息", "26 内力｜12 息冷却｜恢复 32 点气血"],
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
	var progress_text := ""
	if current_zone == "silent_temple":
		var stage_names := {
			"infiltrate": "夜探禅院",
			"mechanism_available": "关闭机关",
			"rescue": "营救商客",
			"boss": "院主决战",
			"ending": "裁定余众",
			"completed": "副本完成",
		}
		var ending_names := {
			"": "尚未裁定",
			"justice": "罪证交付按察司",
			"mercy": "宽宥悔悟僧人",
			"treasure": "带走禅院赃银",
		}
		var approach_names := {
			"": "尚未决定",
			"stealth": "无声潜入",
			"force": "正面强攻",
		}
		progress_text = "副本阶段：%s\n潜入方式：%s\n最终裁定：%s" % [
			stage_names.get(GameState.dungeon_state, "尚未进入"),
			approach_names.get(GameState.dungeon_approach, "尚未决定"),
			ending_names.get(GameState.dungeon_ending, "尚未裁定"),
		]
	else:
		var route_name := "尚未抉择"
		if GameState.quest_route == "protect":
			route_name = "护送百姓"
		elif GameState.quest_route == "investigate":
			route_name = "追查证据"
		progress_text = "行动路线：%s\n云津渡声望：%d" % [
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
		GameState.set_message("%s是锻造材料，请前往云津渡寻找铁匠鲁三火。" % definition["name"])
	_save_current_game()


func _open_npc_dialogue(npc: WuxiaActor3D) -> void:
	if npc == smith_npc:
		_open_smith_window()
		return
	if current_zone == "silent_temple":
		_open_temple_dialogue()
		return
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
			if GameState.dungeon_state == "completed":
				dialogue = "寂音禅院的罪证已经送出，云津渡失踪案暂告一段落。少侠可先休整。"
				action_text = "告辞"
				action = _close_active_window
			else:
				dialogue = (
					"失踪商旅最后都在寂音禅院附近出现。此处表面清修，"
					+ "夜里却常有囚车入山。少侠可愿趁夜潜入查探？"
				)
				action_text = "前往禅院"
				action = _enter_silent_temple
	_add_label(
		active_window, dialogue, Vector2(24, 56), Vector2(502, 92),
		16, Color("#e5ddc9")
	).autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	var action_button := _button(active_window, action_text, Vector2(292, 205), Vector2(110, 42))
	action_button.pressed.connect(action)
	var leave := _button(active_window, "离开", Vector2(416, 205), Vector2(110, 42))
	leave.pressed.connect(_close_active_window)


func _open_smith_window() -> void:
	_close_active_window()
	active_window = _window(
		"渡口铁匠·鲁三火", "铁匠", Vector2(720, 160), Vector2(480, 390)
	)
	var cost := GameState.get_upgrade_cost("weapon")
	var current_weapon := GameState.get_equipped_name("weapon")
	_add_label(
		active_window,
		"“寒铁要慢火淬、急水收。手稳，刃才不会脆。”",
		Vector2(24, 53), Vector2(430, 28), 14, Color("#b8ad92")
	)
	_add_label(
		active_window,
		"当前兵刃｜%s\n外功攻击｜%d\n持有材料｜寒铁 %d 份 · 碎银 %d 两" % [
			current_weapon,
			GameState.get_attack(),
			GameState.get_item_count("cold_iron"),
			GameState.silver,
		],
		Vector2(24, 94), Vector2(430, 88), 16, Color("#e3d7ba")
	)
	var cost_text := str(cost.get("reason", ""))
	if bool(cost.get("available", false)):
		cost_text = "下一等级｜+%d\n所需费用｜寒铁 %d 份 · 碎银 %d 两\n淬炼效果｜外功攻击永久增加 2 点" % [
			int(cost["next"]), int(cost["material"]), int(cost["silver"])
		]
	_add_label(
		active_window, cost_text,
		Vector2(24, 194), Vector2(430, 86), 15, Color("#d9bb70")
	)
	var upgrade := _button(
		active_window,
		"淬炼兵刃" if bool(cost.get("available", false)) else "已达淬炼上限",
		Vector2(252, 307), Vector2(128, 44)
	)
	upgrade.disabled = not bool(cost.get("available", false))
	upgrade.tooltip_text = "稳定淬炼，不会随机损坏装备。"
	upgrade.pressed.connect(_upgrade_weapon)
	var leave := _button(active_window, "离开", Vector2(390, 307), Vector2(66, 44))
	leave.pressed.connect(_close_active_window)


func _upgrade_weapon() -> void:
	if GameState.upgrade_equipment("weapon"):
		AudioManager.play_quest()
		_save_current_game()


func _open_temple_dialogue() -> void:
	_close_active_window()
	active_window = _window("被困商客·顾行舟", "对话", Vector2(365, 350), Vector2(550, 285))
	if GameState.dungeon_state == "ending":
		_add_label(
			active_window,
			"院主已死，地牢中留下罪证、愿意悔过的年轻僧人与一批无主赃银。少侠准备如何处置？",
			Vector2(24, 54), Vector2(502, 72), 16, Color("#e5ddc9")
		).autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		var justice := _button(
			active_window, "交付罪证\n声望最高", Vector2(20, 145), Vector2(158, 62)
		)
		justice.pressed.connect(_finish_temple.bind("justice"))
		var mercy := _button(
			active_window, "宽宥悔悟者\n药品奖励", Vector2(196, 145), Vector2(158, 62)
		)
		mercy.pressed.connect(_finish_temple.bind("mercy"))
		var treasure := _button(
			active_window, "带走赃银\n银两最高", Vector2(372, 145), Vector2(158, 62)
		)
		treasure.pressed.connect(_finish_temple.bind("treasure"))
		return

	var dialogue := ""
	var action_text := ""
	var action: Callable
	match GameState.dungeon_state:
		"infiltrate":
			dialogue = (
				"牢外守卫的黄色视野锥代表警戒范围。少侠可绕到西侧总闸无声潜入，"
				+ "也可正面制服他们；中轴暗色踏板会触发弩箭。"
			)
			action_text = "先清守卫"
			action = _close_active_window
		"mechanism_available":
			dialogue = "牢门与暗弩都连着西偏殿前的橙色拉杆。先关闭总闸，才能打开牢门。"
			action_text = "去关总闸"
			action = _command_use_mechanism
		"rescue":
			dialogue = "总闸停了！快替我拉开牢门。院主发现后一定会带护院武僧赶来。"
			action_text = "打开牢门"
			action = _rescue_temple_prisoner
		"boss":
			dialogue = "院主就在大殿前！他手中掌握失踪商旅的账册，不能让他把证据毁掉。"
			action_text = "迎战院主"
			action = _close_active_window
		"completed":
			dialogue = "此间暗局已经了结。我会护送获救商旅下山，少侠也可返回云津渡复命。"
			action_text = "返回云津渡"
			action = _return_cloud_ford
	_add_label(
		active_window, dialogue, Vector2(24, 56), Vector2(502, 100),
		16, Color("#e5ddc9")
	).autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	var action_button := _button(active_window, action_text, Vector2(292, 205), Vector2(110, 42))
	action_button.pressed.connect(action)
	var leave := _button(active_window, "离开", Vector2(416, 205), Vector2(110, 42))
	leave.pressed.connect(_close_active_window)


func _rescue_temple_prisoner() -> void:
	_close_active_window()
	GameState.rescue_temple_prisoner()
	boss_phase = 0
	boss_skill_cooldown = 3.0
	_spawn_enemy_wave(_temple_boss_specs())
	AudioManager.play_quest()
	world.shake_camera(0.22)
	_save_current_game()


func _finish_temple(ending: String) -> void:
	_close_active_window()
	GameState.finish_silent_temple(ending)
	AudioManager.play_quest()
	_save_current_game()


func _enter_silent_temple() -> void:
	_close_active_window()
	GameState.begin_silent_temple()
	_switch_zone("silent_temple")


func _return_cloud_ford() -> void:
	_close_active_window()
	_switch_zone("cloud_ford")


func _switch_zone(zone_id: String) -> void:
	if zone_id == current_zone or zone_id not in ["cloud_ford", "silent_temple"]:
		return
	_clear_target()
	_set_hovered_actor(null)
	_clear_boss_telegraph()
	boss_phase = 0
	boss_skill_cooldown = 3.0
	player.stop()
	pending_loot = null
	pending_npc = null
	pending_mechanism = null
	pending_map_interaction = null
	var old_world := world
	enemies.clear()
	loot_drops.clear()
	quest_npc = null
	smith_npc = null
	current_zone = zone_id
	world = SilentTempleWorld.new() if zone_id == "silent_temple" else CloudFordWorld.new()
	add_child(world)
	player.reparent(world.world_root)
	player.position = (
		Vector3(0, 0, 6.0)
		if zone_id == "silent_temple"
		else Vector3(-1.5, 0, 4.8)
	)
	world.set_follow_target(player)
	old_world.queue_free()
	_create_enemies()
	_create_quest_npc()
	minimap.configure(player, enemies)
	minimap.world_rect = (
		Rect2(-10.5, -7.5, 21.0, 15.0)
		if zone_id == "silent_temple"
		else Rect2(-11.5, -8.2, 23.0, 15.4)
	)
	GameState.set_message(
		"已潜入寂音禅院，注意中轴机关。"
		if zone_id == "silent_temple"
		else "已返回云津渡。"
	)
	_refresh_hud()
	_save_current_game()


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
	elif window_type == "铁匠":
		_close_active_window()
		call_deferred("_open_smith_window")


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
