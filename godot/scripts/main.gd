extends Node2D

const Actor = preload("res://scripts/wuxia_actor_3d.gd")
const Minimap = preload("res://scripts/minimap_widget.gd")
const CloudFordWorld = preload("res://scripts/cloud_ford_world_3d.gd")

var player: WuxiaActor3D
var enemies: Array[WuxiaActor3D] = []
var selected_enemy: WuxiaActor3D
var world: CloudFordWorld3D
var move_marker := Vector3.ZERO
var marker_time := 0.0
var retarget_time := 0.0
var enemy_attack_time := 0.0
var health_bar: ProgressBar
var health_label: Label
var inner_power_bar: ProgressBar
var experience_bar: ProgressBar
var silver_label: Label
var quest_count: Label
var message_label: Label
var target_label: Label
var target_health_bar: ProgressBar
var skill_buttons: Array[Button] = []
var qinggong_time := 0.0
var heal_cooldown := 0.0


func _ready() -> void:
	GameState.reset()
	_create_background()
	_create_player()
	_create_enemies()
	_create_hud()
	GameState.state_changed.connect(_refresh_hud)
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
	var specs := [
		["寒岭门客", Vector3(2.8, 0.0, 1.5), 54],
		["黑衣暗桩", Vector3(5.2, 0.0, 4.5), 72],
		["寂音武僧", Vector3(6.2, 0.0, -2.8), 96],
	]
	for spec in specs:
		var enemy: WuxiaActor3D = Actor.new()
		enemy.display_name = spec[0]
		enemy.position = spec[1]
		enemy.max_health = spec[2]
		enemy.hostile = true
		enemy.move_speed = 3.2
		enemy.defeated.connect(_on_enemy_defeated)
		world.add_actor(enemy)
		enemies.append(enemy)


func _unhandled_input(event: InputEvent) -> void:
	if not (event is InputEventMouseButton):
		return
	var mouse_event := event as InputEventMouseButton
	if mouse_event.button_index != MOUSE_BUTTON_LEFT or not mouse_event.pressed:
		return
	var click: Vector2 = mouse_event.position
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
	var destination := world.screen_to_ground(click)
	player.command_move(destination)
	move_marker = destination
	marker_time = 0.65
	GameState.set_message("正在前往指定位置。点击敌人可自动追击。")
	queue_redraw()


func _select_enemy(enemy: WuxiaActor3D) -> void:
	if is_instance_valid(selected_enemy):
		selected_enemy.selected = false
	selected_enemy = enemy
	selected_enemy.selected = true
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
	selected_enemy = null
	player.combat_target = null
	target_label.text = "目标｜尚未选中"
	target_health_bar.value = 0


func _physics_process(delta: float) -> void:
	marker_time = maxf(0.0, marker_time - delta)
	retarget_time = maxf(0.0, retarget_time - delta)
	enemy_attack_time = maxf(0.0, enemy_attack_time - delta)
	heal_cooldown = maxf(0.0, heal_cooldown - delta)
	if qinggong_time > 0.0:
		qinggong_time = maxf(0.0, qinggong_time - delta)
		if qinggong_time <= 0.0:
			player.move_speed = 5.0
	if marker_time > 0.0:
		queue_redraw()
	_update_player_combat()
	_update_enemy_combat()


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
	var damage := 22
	if GameState.selected_skill == "伏虎掌":
		damage = 28
	elif GameState.selected_skill == "机弩术":
		damage = 18
	selected_enemy.take_damage(damage)
	_show_damage(
		selected_enemy.global_position + Vector3(0, 1.8, 0), damage, Color("#ffe49a")
	)
	target_label.text = "目标｜%s  %d/%d" % [
		selected_enemy.display_name, selected_enemy.health, selected_enemy.max_health
	]
	target_health_bar.value = selected_enemy.health
	GameState.set_message("%s命中%s，造成 %d 点伤害。" % [
		GameState.selected_skill, selected_enemy.display_name, damage
	])


func _update_enemy_combat() -> void:
	if enemy_attack_time > 0.0 or GameState.player_health <= 0:
		return
	for enemy in enemies:
		if not is_instance_valid(enemy):
			continue
		var distance := enemy.global_position.distance_to(player.global_position)
		if distance < 1.15:
			enemy_attack_time = 1.05
			enemy.play_attack()
			GameState.damage_player(8)
			_show_damage(player.global_position + Vector3(0, 1.8, 0), 8, Color("#ff776d"))
			if GameState.player_health == 0:
				player.stop()
				GameState.set_message("少侠气血耗尽。点击右上角“重新闯荡”再次挑战。")
			else:
				GameState.set_message("%s发动反击，少侠损失 8 点气血。" % enemy.display_name)
			return
		if distance < 5.5 and selected_enemy == enemy:
			var pursuit := (
				player.global_position
				+ player.global_position.direction_to(enemy.global_position) * 0.9
			)
			enemy.command_move(pursuit)


func _on_enemy_defeated(enemy: WuxiaActor3D) -> void:
	var name := enemy.display_name
	if selected_enemy == enemy:
		selected_enemy = null
		player.combat_target = null
	enemies.erase(enemy)
	enemy.queue_free()
	GameState.add_silver(12)
	GameState.set_message("击败%s，获得碎银 12 两。" % name)
	target_label.text = "目标｜尚未选中"
	target_health_bar.value = 0
	if enemies.is_empty():
		GameState.quest_text = "云津渡伏兵已清剿"
		GameState.set_message("云津渡重归安宁。新的江湖线索已解锁。")


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


func _draw() -> void:
	if marker_time <= 0.0:
		return
	var alpha := marker_time / 0.65
	var marker_screen := world.world_to_screen(move_marker)
	draw_arc(marker_screen, 13.0, 0.0, TAU, 32, Color(0.92, 0.76, 0.34, alpha), 2.0)
	draw_circle(marker_screen, 3.0, Color(1.0, 0.9, 0.55, alpha))


func _create_hud() -> void:
	var hud := CanvasLayer.new()
	hud.layer = 50
	add_child(hud)

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
	_add_label(status, "八品 · 青冥门", Vector2(245, 13), Vector2(82, 22), 12, Color("#9fc7ad"), true)
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

	var quest := _panel(Vector2(958, 218), Vector2(302, 148), Color(0.025, 0.04, 0.035, 0.91))
	hud.add_child(quest)
	_add_label(quest, "任务追踪", Vector2(15, 11), Vector2(90, 21), 13, Color("#8fa99a"))
	_add_label(quest, "◆ 云津渡伏兵", Vector2(15, 37), Vector2(190, 25), 18, Color("#ead179"))
	_add_label(quest, "寒岭武氏暗桩潜伏渡口，清剿伏兵。", Vector2(15, 66), Vector2(270, 22), 13, Color("#d5cbb2"))
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

	var restart := _button(currency, "重整江湖", Vector2(71, 51), Vector2(97, 34))
	restart.add_theme_font_size_override("font_size", 12)
	restart.pressed.connect(_restart_game)


func _refresh_hud() -> void:
	health_bar.value = GameState.player_health
	health_label.text = "%d / %d" % [GameState.player_health, GameState.player_max_health]
	inner_power_bar.value = GameState.player_inner_power
	experience_bar.value = GameState.player_experience
	silver_label.text = "◆ 碎银  %d" % GameState.silver
	quest_count.text = "%d / 3 名敌人已清剿" % (3 - enemies.size())
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
	if enemies.is_empty():
		GameState.set_message("当前任务目标已全部完成。")
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
	GameState.set_message("%s系统入口已就位，将在后续版本开放完整内容。" % panel_name)


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
	parent.add_child(button)
	return button
