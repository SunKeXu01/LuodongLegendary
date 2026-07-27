extends Node

var failures: Array[String] = []


func _ready() -> void:
	GameState.reset()
	_expect(GameState.get_item_count("healing_salve") == 2, "初始金疮药数量应为 2")
	_expect(GameState.get_attack() == 22, "装备旧制长剑后攻击应为 22")
	_expect(GameState.spend_inner_power(20), "内力充足时应能消耗内力")
	_expect(GameState.player_inner_power == 62, "消耗后内力应正确减少")
	_expect(not GameState.spend_inner_power(100), "内力不足时不应允许施放")
	GameState.restore_inner_power(20)
	_expect(GameState.player_inner_power == 82, "内力恢复不应超过当前上限")

	GameState.damage_player(60)
	_expect(GameState.use_item("healing_salve"), "受伤时应能使用金疮药")
	_expect(GameState.player_health == 72, "金疮药应恢复 32 点气血")
	_expect(GameState.get_item_count("healing_salve") == 1, "使用后金疮药应减少 1")
	_expect(GameState.rest_at_tea_stall(), "受伤或内力未满时应能在茶棚休整")
	_expect(GameState.player_health == 100, "茶棚休整应恢复全部气血")
	_expect(GameState.player_inner_power == 100, "茶棚休整应恢复全部内力")
	_expect(not GameState.rest_at_tea_stall(), "状态全满时不应重复执行休整")

	var visual_loot := LootPickup3D.new()
	visual_loot.configure("cold_iron", "寒铁碎片", 1)
	add_child(visual_loot)
	_expect(
		is_instance_valid(visual_loot.get_node_or_null("掉落表现/掉落光柱")),
		"3D 掉落物应显示按类型着色的世界光柱"
	)
	var loot_nameplate := visual_loot.get_node_or_null("掉落表现/掉落名牌") as Label3D
	_expect(
		is_instance_valid(loot_nameplate) and not loot_nameplate.fixed_size,
		"掉落名牌应随 3D 世界透视缩放而不是固定遮挡屏幕"
	)
	visual_loot.queue_free()

	GameState.add_item("monk_bracer")
	_expect(GameState.equip_item("monk_bracer"), "武僧护腕应能装备")
	_expect(GameState.get_defense() == 8, "装备护腕后防御应为 8")

	GameState.choose_quest_route("investigate")
	_expect(GameState.quest_state == "accepted", "任务应进入已接受状态")
	_expect(GameState.quest_route == "investigate", "应记录追查证据路线")
	GameState.mark_quest_ready()
	_expect(GameState.quest_state == "ready", "清剿后任务应进入可交付状态")
	_expect(GameState.evidence_count == 3, "追查路线应获得三枚涉案铜签")
	GameState.finish_first_quest()
	_expect(GameState.quest_state == "followup_available", "首次交付后应解锁追兵任务")
	_expect(GameState.silver == 25, "首次交付应奖励碎银 25 两")
	_expect(GameState.get_item_count("cold_iron") == 2, "追查路线应奖励两份寒铁")
	_expect(GameState.get_item_count("qingming_charm") == 1, "首次交付应奖励青冥玉符")

	GameState.equip_item("qingming_charm")
	_expect(GameState.get_attack() == 24, "装备玉符后攻击应为 24")
	_expect(GameState.get_defense() == 10, "装备玉符后防御应为 10")
	GameState.accept_followup()
	_expect(GameState.quest_state == "second_accepted", "应能接受寒岭追兵任务")
	GameState.mark_quest_ready()
	_expect(GameState.quest_state == "second_ready", "击退追兵后应进入最终交付状态")
	GameState.finish_quest()
	_expect(GameState.quest_state == "completed", "交付后任务应完成")
	_expect(GameState.silver == 75, "两段任务应累计奖励碎银 75 两")
	_expect(GameState.player_level == 9, "完成序章后应提升至第 9 境")
	_expect(GameState.player_experience == 11, "升级后应保留 11 点经验")
	_expect(GameState.player_max_health == 112, "升级后气血上限应提升")
	_expect(GameState.equipment["weapon"] == "hanling_blade", "新兵器应自动装备")
	_expect(GameState.get_attack() == 31, "升级并装备雁翎刀后攻击应为 31")
	_expect(GameState.cloud_ford_reputation == 3, "追查路线完成序章应获得 3 点声望")
	var first_upgrade_cost := GameState.get_upgrade_cost("weapon")
	_expect(int(first_upgrade_cost["material"]) == 1, "兵刃首次淬炼应消耗一份寒铁")
	_expect(int(first_upgrade_cost["silver"]) == 25, "兵刃首次淬炼应消耗碎银 25 两")
	_expect(GameState.upgrade_equipment("weapon"), "材料充足时兵刃应能淬炼至 +1")
	_expect(GameState.get_enhancement("hanling_blade") == 1, "应记录雁翎刀 +1 强化等级")
	_expect(GameState.get_item_count("cold_iron") == 1, "淬炼后应扣除一份寒铁")
	_expect(GameState.silver == 50, "淬炼后应扣除碎银 25 两")
	_expect(GameState.get_attack() == 33, "兵刃 +1 应增加两点外功攻击")
	_expect(not GameState.upgrade_equipment("weapon"), "寒铁不足时不应允许继续淬炼")
	_expect(GameState.get_item_count("cold_iron") == 1, "淬炼失败不应扣除寒铁")
	_expect(GameState.silver == 50, "淬炼失败不应扣除碎银")

	GameState.begin_silent_temple()
	_expect(GameState.dungeon_state == "infiltrate", "完成序章后应能进入寂音禅院")
	GameState.mark_temple_guards_cleared()
	_expect(GameState.dungeon_state == "mechanism_available", "清除守卫后应开放机关目标")
	_expect(GameState.dungeon_approach == "force", "击败守卫应记录正面强攻路线")
	GameState.disable_temple_traps()
	_expect(GameState.dungeon_state == "rescue", "关闭总闸后应进入营救阶段")
	GameState.rescue_temple_prisoner()
	_expect(GameState.dungeon_state == "boss", "营救商客后应触发首领战")
	GameState.mark_temple_boss_defeated()
	_expect(GameState.dungeon_state == "ending", "击败院主后应进入结局选择")
	GameState.finish_silent_temple("justice")
	_expect(GameState.dungeon_state == "completed", "选择处置方案后副本应完成")
	_expect(GameState.dungeon_ending == "justice", "副本应记录罪证交官结局")
	_expect(GameState.silver == 150, "扣除淬炼成本后应剩余碎银 150 两")
	_expect(GameState.cloud_ford_reputation == 6, "公断结局应额外增加 3 点声望")
	_expect(GameState.equipment["accessory"] == "silent_temple_manual", "机关谱应自动装备")
	_expect(GameState.get_attack() == 34, "副本装备与 +1 兵刃完成后攻击应为 34")
	_expect(GameState.get_defense() == 13, "副本装备完成后防御应为 13")

	var test_save_path := "user://automated_state_test.json"
	var snapshot := {
		"current_zone": "silent_temple",
		"player_position": [1.0, 0.0, 2.0],
		"enemies": [],
		"loot": [{"item_id": "cold_iron", "amount": 1, "position": [2.0, 0.0, 3.0]}],
		"world_time": 0.72,
	}
	_expect(GameState.save_game(snapshot, test_save_path), "游戏状态应能写入存档")
	GameState.reset()
	var restored := GameState.load_game(test_save_path)
	_expect(GameState.quest_state == "completed", "读取存档后任务状态应恢复")
	_expect(GameState.quest_route == "investigate", "读取存档后路线选择应恢复")
	_expect(GameState.cloud_ford_reputation == 6, "读取存档后声望应恢复")
	_expect(GameState.dungeon_state == "completed", "读取存档后副本状态应恢复")
	_expect(GameState.dungeon_ending == "justice", "读取存档后副本结局应恢复")
	_expect(GameState.dungeon_approach == "force", "读取存档后潜入方式应恢复")
	_expect(GameState.player_level == 9, "读取存档后境界应恢复")
	_expect(GameState.player_max_health == 112, "读取存档后气血上限应恢复")
	_expect(GameState.silver == 150, "读取存档后碎银应恢复")
	_expect(GameState.get_enhancement("hanling_blade") == 1, "读取存档后兵刃淬炼等级应恢复")
	_expect(GameState.get_attack() == 34, "读取存档后淬炼属性应恢复")
	_expect(restored.get("loot", []).size() == 1, "读取存档后地面掉落应恢复")
	_expect(restored.get("current_zone", "") == "silent_temple", "读取后所在区域应恢复")
	_expect(is_equal_approx(float(restored.get("world_time", 0.0)), 0.72), "读取存档后时辰应恢复")
	DirAccess.remove_absolute(ProjectSettings.globalize_path(test_save_path))

	GameState.reset()
	GameState.choose_quest_route("protect")
	GameState.mark_quest_ready()
	GameState.finish_first_quest()
	_expect(GameState.cloud_ford_reputation == 2, "护民路线首次交付应获得 2 点声望")
	_expect(GameState.get_item_count("healing_salve") == 4, "护民路线应额外奖励两份金疮药")

	var main_scene = load("res://scenes/main.tscn").instantiate()
	add_child(main_scene)
	_expect(is_instance_valid(main_scene.get("smith_npc")), "云津渡应生成可交互铁匠鲁三火")
	var quest_actor = main_scene.get("quest_npc")
	var smith_actor = main_scene.get("smith_npc")
	_expect(quest_actor.status_marker.text == "!", "可接任务 NPC 头顶应显示感叹号")
	_expect(smith_actor.status_marker.text == "锻", "铁匠头顶应显示常驻功能标识")
	var cloud_world = main_scene.get("world")
	_expect(is_instance_valid(cloud_world.rest_marker), "云津渡应包含可点击的茶棚休整设施")
	var imported_inn: Node = cloud_world.world_root.get_node_or_null("临河客栈")
	_expect(is_instance_valid(imported_inn), "云津渡应生成临河客栈")
	_expect(
		is_instance_valid(imported_inn)
		and is_instance_valid(imported_inn.get_node_or_null("青瓦歇山角顶")),
		"临河客栈应由 Polygonal Mind CC0 东亚建筑模型构成"
	)
	_expect(
		is_instance_valid(cloud_world.world_root.get_node_or_null("云津渡木牌坊")),
		"云津渡入口应载入真实 CC0 木牌坊模型"
	)
	var imported_residence: Node = cloud_world.world_root.get_node_or_null("渡口民居")
	_expect(
		is_instance_valid(imported_residence)
		and is_instance_valid(imported_residence.get_node_or_null("青瓦直坡顶")),
		"渡口民居应由真实 CC0 东亚建筑模型构成"
	)
	_expect(
		is_instance_valid(cloud_world.world_root.get_node_or_null("云津巡夜灯阁")),
		"云津渡街市应载入真实 CC0 东亚灯阁模型"
	)
	var imported_smithy: Node = cloud_world.world_root.get_node_or_null("鲁氏铁铺")
	_expect(
		is_instance_valid(imported_smithy)
		and is_instance_valid(imported_smithy.get_node_or_null("鲁氏铁铺青瓦屋顶"))
		and is_instance_valid(imported_smithy.get_node_or_null("鲁氏铁铺匾额")),
		"鲁氏铁铺应由真实 CC0 东亚模块构成并显示中文匾额"
	)
	_expect(
		is_instance_valid(imported_smithy)
		and is_instance_valid(imported_smithy.get_node_or_null("铁铺锻炉"))
		and is_instance_valid(imported_smithy.get_node_or_null("锻炉炭火")),
		"鲁氏铁铺应包含发光锻炉而不是欧洲铁匠铺剪影"
	)
	var imported_warehouse: Node = cloud_world.world_root.get_node_or_null("云津货栈")
	_expect(
		is_instance_valid(imported_warehouse)
		and is_instance_valid(imported_warehouse.get_node_or_null("云津货栈青瓦屋顶"))
		and is_instance_valid(imported_warehouse.get_node_or_null("云津货栈匾额")),
		"云津货栈应由真实 CC0 东亚模块构成并显示中文匾额"
	)
	_expect(
		is_instance_valid(imported_inn)
		and is_instance_valid(imported_inn.get_node_or_null("临河客栈匾额")),
		"客栈应有可辨识的明式中文匾额"
	)
	_expect(
		is_instance_valid(cloud_world.world_root.get_node_or_null("临水茶亭")),
		"云津渡应生成临水茶亭地标"
	)
	_expect(
		is_instance_valid(cloud_world.world_root.get_node_or_null("明式歇山顶")),
		"临水茶亭应包含可辨识的明式歇山屋顶"
	)
	_expect(main_scene.get("skill_cooldown_overlays").size() == 5, "五个武学槽位都应具备冷却遮罩")
	main_scene.get("skill_cooldowns")["踏燕行"] = 3.0
	main_scene.call("_refresh_skill_buttons")
	_expect(
		main_scene.get("skill_cooldown_overlays")["踏燕行"].visible,
		"冷却中的踏燕行应显示纵向冷却遮罩"
	)
	_expect(
		main_scene.get("skill_cooldown_labels")["踏燕行"].visible,
		"冷却中的踏燕行应显示剩余秒数"
	)
	main_scene.get("skill_cooldowns")["踏燕行"] = 0.0
	main_scene.call("_refresh_skill_buttons")
	var world_player = main_scene.get("player")
	_expect(world_player.uses_imported_model, "玩家应使用带骨骼动画的外部 GLB 模型")
	_expect(
		is_instance_valid(world_player.animation_player)
		and not world_player.animation_player.get_animation_list().is_empty(),
		"玩家外部模型应包含可播放的动作"
	)
	_expect(
		cloud_world.camera.projection == Camera3D.PROJECTION_ORTHOGONAL,
		"正式地图应使用正交斜俯视镜头形成 2.5D 观感"
	)
	_expect(cloud_world.camera_rig.target == main_scene.get("player"), "等距镜头应跟随玩家")
	var camera_size_before_zoom: float = float(cloud_world.camera.size)
	cloud_world.zoom_camera(1.0)
	_expect(cloud_world.camera.size > camera_size_before_zoom, "鼠标向下滚动应拉远等距镜头")
	cloud_world.zoom_camera(-1.0)
	_expect(
		cloud_world.call(
			"_segment_intersects_rect",
			Vector2(-2, 0), Vector2(2, 0), Rect2(-0.5, -0.5, 1, 1)
		),
		"镜头到玩家的射线穿过建筑时应命中遮挡区域"
	)
	main_scene.call("_open_smith_window")
	var smith_window = main_scene.get("active_window")
	_expect(
		is_instance_valid(smith_window) and smith_window.get_meta("window_type", "") == "铁匠",
		"点击铁匠后应打开兵刃淬炼界面"
	)
	main_scene.call("_close_active_window")
	var initial_enemies: Array = main_scene.get("enemies")
	if not initial_enemies.is_empty():
		var first_world_enemy = initial_enemies[0]
		_expect(first_world_enemy.actor_level == 8, "普通敌人头顶境界应与当前章节匹配")
		_expect(
			is_instance_valid(first_world_enemy.health_bar_fill),
			"敌人应生成跟随角色的 3D 世界气血条"
		)
		first_world_enemy.take_damage(10)
		_expect(first_world_enemy.health_bar_fill.scale.x < 1.0, "受伤后世界气血条应即时缩短")
		first_world_enemy.restore_health(first_world_enemy.max_health)
		first_world_enemy.hovered = true
		_expect(first_world_enemy.selection_disc.visible, "鼠标悬停敌人时应显示 3D 交互环")
		first_world_enemy.hovered = false
		main_scene.call("_select_enemy", first_world_enemy)
		main_scene.set("queued_skill", "伏虎掌")
		main_scene.call("_refresh_combat_cast_bar")
		_expect(main_scene.get("combat_cast_panel").visible, "排队武学时应显示候招条")
		_expect(
			"候招" in main_scene.get("combat_cast_label").text,
			"候招条应说明正在自动接近有效射程"
		)
		main_scene.set("queued_skill", "")
		main_scene.call("_clear_target")
	cloud_world.play_skill_effect(
		"青冥剑式",
		world_player.global_position,
		world_player.global_position + Vector3(1.2, 0, 0.8)
	)
	await get_tree().process_frame
	_expect(
		is_instance_valid(cloud_world.combat_vfx.get_node_or_null("武学刀光轨迹/MIT三维拖尾")),
		"近战武学应使用移植的 MIT 三维拖尾生成弧形刀光"
	)
	GameState.damage_player(35)
	GameState.spend_inner_power(30)
	main_scene.call("_command_use_rest_station")
	world_player.global_position = cloud_world.rest_marker.global_position + Vector3(0.5, 0, 0.3)
	main_scene.call("_update_pending_interactions")
	_expect(GameState.player_health == GameState.player_max_health, "玩家靠近茶棚后应恢复全部气血")
	_expect(
		GameState.player_inner_power == GameState.player_max_inner_power,
		"玩家靠近茶棚后应恢复全部内力"
	)
	for enemy in initial_enemies:
		enemy.queue_free()
	initial_enemies.clear()
	GameState.choose_quest_route("protect")
	GameState.mark_quest_ready()
	GameState.finish_first_quest()
	GameState.accept_followup()
	main_scene.call("_spawn_enemy_wave", main_scene.call("_followup_enemy_specs"))
	var followup_enemies: Array = main_scene.get("enemies")
	_expect(followup_enemies.size() == 2, "后续任务应动态生成两名寒岭追兵")
	if followup_enemies.size() == 2:
		_expect(followup_enemies[0].display_name == "寒岭追骑", "第一名追兵配置应正确")
		_expect(followup_enemies[1].display_name == "武氏刀客", "第二名追兵配置应正确")
	for enemy in followup_enemies:
		enemy.queue_free()
	followup_enemies.clear()
	GameState.mark_quest_ready()
	GameState.finish_quest()
	main_scene.call("_enter_silent_temple")
	_expect(main_scene.get("current_zone") == "silent_temple", "完成序章后应切换到禅院地图")
	var temple_world = main_scene.get("world")
	_expect(temple_world is SilentTempleWorld3D, "副本应使用独立的寂音禅院世界")
	var temple_enemies: Array = main_scene.get("enemies")
	_expect(temple_enemies.size() == 2, "初次进入禅院应生成两名巡夜守卫")
	_expect(is_instance_valid(temple_world.mechanism_marker), "禅院地图应包含可交互机关总闸")
	var dungeon_player = main_scene.get("player")
	if not temple_enemies.is_empty():
		var sentry = temple_enemies[0]
		dungeon_player.global_position = (
			sentry.global_position + sentry.global_transform.basis.z.normalized() * 2.0
		)
		_expect(sentry.can_see(dungeon_player), "玩家进入黄色视野锥时守卫应能发现目标")
		_expect(is_instance_valid(sentry.vision_cone), "巡夜守卫应显示视野锥")
	var health_before_trap := GameState.player_health
	dungeon_player.global_position = Vector3(-2.0, 0.0, 1.3)
	main_scene.call("_update_dungeon_hazards")
	_expect(GameState.player_health == health_before_trap - 10, "踩中禅院踏板应损失 10 点气血")
	dungeon_player.global_position = (
		temple_world.mechanism_marker.global_position + Vector3(0.9, 0, 0.4)
	)
	main_scene.set("pending_mechanism", temple_world.mechanism_marker)
	main_scene.call("_update_pending_interactions")
	_expect(GameState.dungeon_state == "rescue", "未触发警戒时操作总闸应直接进入营救阶段")
	_expect(GameState.dungeon_approach == "stealth", "绕过守卫应记录无声潜入路线")
	_expect(main_scene.get("enemies").is_empty(), "潜行成功后巡夜守卫应退出当前战斗")
	main_scene.call("_rescue_temple_prisoner")
	var boss_wave: Array = main_scene.get("enemies")
	_expect(boss_wave.size() == 3, "营救商客后应生成院主与两名护院武僧")
	if not boss_wave.is_empty():
		_expect(boss_wave[0].display_name == "寂音院主·法砚", "首领波次应包含寂音院主")
		main_scene.call("_select_enemy", boss_wave[0])
		dungeon_player.global_position = boss_wave[0].global_position + Vector3(0, 0, 5.0)
		var inner_power_before_crossbow := GameState.player_inner_power
		main_scene.call("_activate_skill", "机弩术")
		main_scene.call("_update_player_combat")
		_expect(boss_wave[0].health == 230, "机弩术应在远程造成 105% 外功伤害")
		_expect(
			GameState.player_inner_power == inner_power_before_crossbow - 18,
			"机弩术应消耗 18 点内力"
		)
		_expect(
			float(main_scene.get("skill_cooldowns")["机弩术"]) > 3.5,
			"机弩术施放后应进入独立冷却"
		)
		var inner_power_during_cooldown := GameState.player_inner_power
		main_scene.call("_activate_skill", "机弩术")
		_expect(main_scene.get("queued_skill") == "", "冷却中的技能不应再次进入施放队列")
		_expect(
			GameState.player_inner_power == inner_power_during_cooldown,
			"冷却中的技能不应重复消耗内力"
		)
		main_scene.set("boss_skill_cooldown", 0.0)
		main_scene.call("_update_boss_mechanics", 0.1)
		_expect(
			is_instance_valid(main_scene.get("boss_telegraph")),
			"院主应生成可见的范围招式预警"
		)
		main_scene.call("_refresh_combat_cast_bar")
		_expect(main_scene.get("combat_cast_panel").visible, "首领蓄力时应显示危险施法条")
		_expect(
			"震钟劲" in main_scene.get("combat_cast_label").text,
			"首领施法条应显示正在蓄力的招式"
		)
		dungeon_player.attack_cooldown = 0.0
		dungeon_player.global_position = boss_wave[0].global_position + Vector3(0, 0, 1.0)
		var telegraph_before_interrupt := float(main_scene.get("boss_telegraph_time"))
		main_scene.call("_activate_skill", "伏虎掌")
		main_scene.call("_update_player_combat")
		_expect(
			float(main_scene.get("boss_telegraph_time")) > telegraph_before_interrupt,
			"伏虎掌命中院主时应延缓范围招式蓄力"
		)
		var health_before_aoe := GameState.player_health
		dungeon_player.global_position = main_scene.get("boss_telegraph_origin")
		main_scene.call("_update_boss_mechanics", 2.0)
		_expect(GameState.player_health == health_before_aoe - 21, "第一阶段震钟劲应造成 21 点伤害")
		boss_wave[0].health = 80
		main_scene.call("_update_boss_mechanics", 0.1)
		_expect(main_scene.get("boss_phase") == 3, "院主低于三分之一气血时应进入第三阶段")
	boss_wave.clear()
	main_scene.queue_free()
	AudioManager.stop_all()
	await get_tree().process_frame
	await get_tree().process_frame
	DirAccess.remove_absolute(ProjectSettings.globalize_path(GameState.SAVE_PATH))

	var test_settings_path := "user://automated_settings_test.json"
	GameState.master_volume = 0.4
	GameState.fullscreen = true
	_expect(GameState.save_settings(test_settings_path), "设置应能写入文件")
	GameState.master_volume = 1.0
	GameState.fullscreen = false
	GameState.load_settings(test_settings_path)
	_expect(is_equal_approx(GameState.master_volume, 0.4), "读取后音量应恢复")
	_expect(GameState.fullscreen, "读取后全屏设置应恢复")
	DirAccess.remove_absolute(ProjectSettings.globalize_path(test_settings_path))

	if failures.is_empty():
		print("GAMEPLAY STATE SMOKE TEST PASSED")
		get_tree().quit(0)
		return
	for failure in failures:
		push_error("GAMEPLAY TEST: %s" % failure)
	get_tree().quit(1)


func _expect(condition: bool, failure: String) -> void:
	if not condition:
		failures.append(failure)
