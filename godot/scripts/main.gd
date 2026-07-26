extends Node2D

const Actor = preload("res://scripts/wuxia_actor.gd")
const BACKGROUND = preload("res://assets/cloud_ford_2_5d.png")

var player: WuxiaActor
var enemies: Array[WuxiaActor] = []
var selected_enemy: WuxiaActor
var move_marker := Vector2.ZERO
var marker_time := 0.0
var retarget_time := 0.0
var enemy_attack_time := 0.0
var health_bar: ProgressBar
var health_label: Label
var silver_label: Label
var quest_count: Label
var message_label: Label
var target_label: Label
var skill_buttons: Array[Button] = []


func _ready() -> void:
	GameState.reset()
	_create_background()
	_create_navigation()
	_create_player()
	_create_enemies()
	_create_hud()
	GameState.state_changed.connect(_refresh_hud)
	_refresh_hud()


func _create_background() -> void:
	var background := TextureRect.new()
	background.texture = BACKGROUND
	background.position = Vector2.ZERO
	background.size = Vector2(1280, 720)
	background.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	background.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	background.mouse_filter = Control.MOUSE_FILTER_IGNORE
	background.z_index = -100
	add_child(background)

	var shade := ColorRect.new()
	shade.color = Color(0.04, 0.045, 0.035, 0.12)
	shade.size = Vector2(1280, 720)
	shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	shade.z_index = -90
	add_child(shade)


func _create_navigation() -> void:
	var region := NavigationRegion2D.new()
	var polygon := NavigationPolygon.new()
	polygon.vertices = PackedVector2Array([
		Vector2(105, 350), Vector2(280, 215), Vector2(1040, 190),
		Vector2(1215, 285), Vector2(1215, 625), Vector2(105, 625)
	])
	polygon.add_polygon(PackedInt32Array([0, 1, 2, 3, 4, 5]))
	region.navigation_polygon = polygon
	add_child(region)


func _create_player() -> void:
	player = Actor.new()
	player.display_name = "青冥门少侠"
	player.max_health = GameState.player_max_health
	player.position = Vector2(520, 530)
	player.z_index = 20
	add_child(player)


func _create_enemies() -> void:
	var specs := [
		["寒岭门客", Vector2(725, 405), 54],
		["黑衣暗桩", Vector2(910, 520), 72],
		["寂音武僧", Vector2(1080, 345), 96],
	]
	for spec in specs:
		var enemy: WuxiaActor = Actor.new()
		enemy.display_name = spec[0]
		enemy.position = spec[1]
		enemy.max_health = spec[2]
		enemy.hostile = true
		enemy.move_speed = 95.0
		enemy.z_index = 19
		enemy.defeated.connect(_on_enemy_defeated)
		add_child(enemy)
		enemies.append(enemy)


func _unhandled_input(event: InputEvent) -> void:
	if not (event is InputEventMouseButton):
		return
	if event.button_index != MOUSE_BUTTON_LEFT or not event.pressed:
		return
	var click := event.position
	for enemy in enemies:
		if is_instance_valid(enemy) and enemy.global_position.distance_to(click) <= 38.0:
			_select_enemy(enemy)
			return
	_clear_target()
	_command_player(click)


func _command_player(click: Vector2) -> void:
	var destination := Vector2(
		clampf(click.x, 105.0, 1215.0),
		clampf(click.y, 215.0, 625.0)
	)
	player.command_move(destination)
	move_marker = destination
	marker_time = 0.65
	GameState.set_message("正在前往指定位置。点击敌人可自动追击。")
	queue_redraw()


func _select_enemy(enemy: WuxiaActor) -> void:
	if is_instance_valid(selected_enemy):
		selected_enemy.selected = false
		selected_enemy.queue_redraw()
	selected_enemy = enemy
	selected_enemy.selected = true
	selected_enemy.queue_redraw()
	player.combat_target = enemy
	retarget_time = 0.0
	target_label.text = "目标｜%s  %d/%d" % [enemy.display_name, enemy.health, enemy.max_health]
	GameState.set_message("已锁定%s，少侠将自动接近并施展%s。" % [
		enemy.display_name, GameState.selected_skill
	])


func _clear_target() -> void:
	if is_instance_valid(selected_enemy):
		selected_enemy.selected = false
		selected_enemy.queue_redraw()
	selected_enemy = null
	player.combat_target = null
	target_label.text = "目标｜尚未选中"


func _physics_process(delta: float) -> void:
	marker_time = maxf(0.0, marker_time - delta)
	retarget_time = maxf(0.0, retarget_time - delta)
	enemy_attack_time = maxf(0.0, enemy_attack_time - delta)
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
	if distance > 70.0:
		if retarget_time <= 0.0:
			var approach := (
				selected_enemy.global_position
				+ selected_enemy.global_position.direction_to(player.global_position) * 58.0
			)
			player.command_move(approach)
			retarget_time = 0.35
		return
	player.stop()
	if player.attack_cooldown > 0.0:
		return
	player.attack_cooldown = 0.72
	var damage := 22
	if GameState.selected_skill == "伏虎掌":
		damage = 28
	elif GameState.selected_skill == "机弩术":
		damage = 18
	selected_enemy.take_damage(damage)
	_show_damage(selected_enemy.global_position, damage, Color("#ffe49a"))
	target_label.text = "目标｜%s  %d/%d" % [
		selected_enemy.display_name, selected_enemy.health, selected_enemy.max_health
	]
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
		if distance < 52.0:
			enemy_attack_time = 1.05
			GameState.damage_player(8)
			_show_damage(player.global_position, 8, Color("#ff776d"))
			if GameState.player_health == 0:
				player.stop()
				GameState.set_message("少侠气血耗尽。点击右上角“重新闯荡”再次挑战。")
			else:
				GameState.set_message("%s发动反击，少侠损失 8 点气血。" % enemy.display_name)
			return
		if distance < 245.0 and selected_enemy == enemy:
			var pursuit := (
				player.global_position
				+ player.global_position.direction_to(enemy.global_position) * 46.0
			)
			enemy.command_move(pursuit)


func _on_enemy_defeated(enemy: WuxiaActor) -> void:
	var name := enemy.display_name
	if selected_enemy == enemy:
		selected_enemy = null
		player.combat_target = null
	enemies.erase(enemy)
	enemy.queue_free()
	GameState.add_silver(12)
	GameState.set_message("击败%s，获得碎银 12 两。" % name)
	target_label.text = "目标｜尚未选中"
	if enemies.is_empty():
		GameState.quest_text = "云津渡伏兵已清剿"
		GameState.set_message("云津渡重归安宁。新的江湖线索已解锁。")


func _show_damage(at: Vector2, amount: int, color: Color) -> void:
	var label := Label.new()
	label.text = "-%d" % amount
	label.position = at - Vector2(20, 56)
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
	draw_arc(move_marker, 13.0, 0.0, TAU, 32, Color(0.92, 0.76, 0.34, alpha), 2.0)
	draw_circle(move_marker, 3.0, Color(1.0, 0.9, 0.55, alpha))


func _create_hud() -> void:
	var hud := CanvasLayer.new()
	hud.layer = 50
	add_child(hud)

	var top_bar := _panel(Vector2(0, 0), Vector2(1280, 72), Color(0.035, 0.04, 0.035, 0.94))
	hud.add_child(top_bar)
	_add_label(top_bar, "泺栋传奇", Vector2(28, 12), Vector2(230, 42), 28, Color("#e8d49d"))
	_add_label(top_bar, "明中叶 · 湖广云津渡", Vector2(238, 25), Vector2(280, 28), 15, Color("#aaa98f"))
	_add_label(top_bar, "第一回  渡口风波", Vector2(545, 23), Vector2(210, 30), 17, Color("#c7ad78"))

	var restart := _button(top_bar, "重新闯荡", Vector2(1145, 16), Vector2(110, 40))
	restart.pressed.connect(_restart_game)

	var status := _panel(Vector2(20, 90), Vector2(288, 92), Color(0.035, 0.045, 0.04, 0.88))
	hud.add_child(status)
	_add_label(status, "侠", Vector2(16, 17), Vector2(50, 50), 27, Color("#d9c17e"), true)
	_add_label(status, "青冥门少侠", Vector2(76, 12), Vector2(165, 28), 18, Color("#f0e6c8"))
	health_bar = ProgressBar.new()
	health_bar.position = Vector2(76, 45)
	health_bar.size = Vector2(188, 15)
	health_bar.show_percentage = false
	health_bar.max_value = GameState.player_max_health
	health_bar.add_theme_stylebox_override("background", _style(Color("#211b18"), 3))
	health_bar.add_theme_stylebox_override("fill", _style(Color("#a84235"), 3))
	status.add_child(health_bar)
	health_label = _add_label(status, "", Vector2(76, 62), Vector2(190, 21), 12, Color("#c9c0a8"))

	var quest := _panel(Vector2(970, 90), Vector2(290, 132), Color(0.035, 0.04, 0.035, 0.9))
	hud.add_child(quest)
	_add_label(quest, "当前任务", Vector2(18, 13), Vector2(100, 22), 13, Color("#9e9b82"))
	_add_label(quest, "云津渡伏兵", Vector2(18, 37), Vector2(190, 27), 20, Color("#ead69a"))
	_add_label(quest, "点击敌人，自动接近并施展武学。", Vector2(18, 69), Vector2(250, 23), 14, Color("#cec5ac"))
	quest_count = _add_label(quest, "", Vector2(18, 98), Vector2(230, 23), 15, Color("#d8b45c"))

	var target_panel := _panel(Vector2(470, 84), Vector2(340, 44), Color(0.035, 0.04, 0.035, 0.84))
	hud.add_child(target_panel)
	target_label = _add_label(
		target_panel, "目标｜尚未选中", Vector2(16, 10), Vector2(310, 28), 15, Color("#e8d9b0")
	)

	var currency := _panel(Vector2(1090, 234), Vector2(170, 42), Color(0.035, 0.04, 0.035, 0.84))
	hud.add_child(currency)
	silver_label = _add_label(currency, "", Vector2(14, 9), Vector2(145, 25), 15, Color("#e1c268"))

	var message_panel := _panel(Vector2(270, 570), Vector2(740, 54), Color(0.035, 0.04, 0.035, 0.88))
	hud.add_child(message_panel)
	_add_label(message_panel, "江湖见闻", Vector2(14, 15), Vector2(86, 25), 14, Color("#d1ad67"))
	message_label = _add_label(
		message_panel, "", Vector2(108, 14), Vector2(615, 28), 14, Color("#eee8d5")
	)

	var skill_bar := _panel(Vector2(0, 646), Vector2(1280, 74), Color(0.025, 0.03, 0.027, 0.96))
	hud.add_child(skill_bar)
	_add_label(skill_bar, "鼠标左键：移动 / 选敌", Vector2(24, 25), Vector2(205, 25), 14, Color("#aaa991"))
	var skill_names := ["青冥剑式", "伏虎掌", "机弩术"]
	for index in skill_names.size():
		var button := _button(
			skill_bar, skill_names[index], Vector2(445 + index * 132, 13), Vector2(120, 48)
		)
		button.pressed.connect(_select_skill.bind(skill_names[index]))
		skill_buttons.append(button)
	_add_label(skill_bar, "纯鼠标操作 · 自动追击", Vector2(1010, 25), Vector2(230, 25), 14, Color("#aaa991"))


func _refresh_hud() -> void:
	health_bar.value = GameState.player_health
	health_label.text = "%d / %d" % [GameState.player_health, GameState.player_max_health]
	silver_label.text = "◆ 碎银  %d" % GameState.silver
	quest_count.text = "%d 名敌人尚存" % enemies.size()
	message_label.text = GameState.message
	for button in skill_buttons:
		button.modulate = Color.WHITE if button.text == GameState.selected_skill else Color(0.68, 0.68, 0.62)


func _select_skill(skill_name: String) -> void:
	GameState.selected_skill = skill_name
	GameState.set_message("已切换为%s，点击敌人即可自动施展。" % skill_name)


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
