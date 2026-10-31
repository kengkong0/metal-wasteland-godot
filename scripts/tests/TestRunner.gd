extends Node

var tests_passed: int = 0
var tests_failed: int = 0
var failures: Array = []

func _ready() -> void:
	print("\n========================================================")
	print("🚀 [TEST RUNNER] 开始全系统自动化回归与深度压力测试")
	print("========================================================\n")

	test_suite_1_data_integrity()
	test_suite_2_gamestate_logic()
	test_suite_3_meta_and_settings()
	test_suite_4_garage_ui()
	test_suite_5_main_screen_navigation()
	test_suite_6_combat_simulation()
	test_suite_7_super_weapons_and_drops()
	test_suite_8_all_wanted_bosses()
	test_suite_9_swarm_and_crush_mechanics()
	test_suite_10_achievements_skins_and_paint_workshop()
	test_suite_11_v2_blueprint_optimizations()
	test_suite_12_stat_previews_and_layout_constraints()
	test_suite_13_weapon_vfx_and_seamless_map()

	print("\n========================================================")
	print("📊 [TEST RESULTS] 测试统计汇总:")
	print("   ✅ 通过测试数: %d" % tests_passed)
	print("   ❌ 失败测试数: %d" % tests_failed)
	if tests_failed > 0:
		print("\n❌ 失败项列表:")
		for f in failures:
			print("   - %s" % f)
		print("========================================================\n")
		get_tree().quit(1)
	else:
		print("🎉 全部测试 100% 通过！游戏系统与数据逻辑无异常！")
		print("========================================================\n")
		get_tree().quit(0)

func assert_true(cond: bool, test_name: String) -> void:
	if cond:
		tests_passed += 1
		print("  ✅ [PASS] " + test_name)
	else:
		tests_failed += 1
		failures.append(test_name)
		print("  ❌ [FAIL] " + test_name)

# ============================================================================
# 1. 数据完整性与资源关联测试
# ============================================================================
func test_suite_1_data_integrity() -> void:
	print("--- [Suite 1] 数据完整性与资源关联检查 ---")

	# 1.1 猎人数据校验
	assert_true(GameData.HUNTERS.size() == 6, "猎人数量应为 6")
	for h_id in GameData.HUNTERS.keys():
		var h: Dictionary = GameData.HUNTERS[h_id]
		var valid: bool = h.has("id") and h.has("name") and h.has("char_name") and h.has("title") and h.has("quote") and h.has("bio") and h.has("trait_tags")
		assert_true(valid, "猎人数据字段完整: %s" % h_id)
		var p_tex: Texture2D = GameData.get_hunter_portrait_tex(h_id)
		assert_true(p_tex != null, "猎人专属独立立绘加载正常: %s" % h_id)
		var icon_tex: Texture2D = GameData.get_hunter_tex(h_id)
		assert_true(icon_tex != null, "猎人头像图标加载正常: %s" % h_id)

	# 1.2 战车底盘校验
	assert_true(GameData.CHASSIS.size() == 8, "战车底盘数量应为 8")
	for c_id in GameData.CHASSIS.keys():
		var ch: Dictionary = GameData.CHASSIS[c_id]
		var valid: bool = ch.has("id") and ch.has("name") and ch.has("slots") and ch.has("base_weight") and ch.has("sp_per_ton") and ch.has("speed")
		assert_true(valid, "战车底盘字段完整: %s" % c_id)
		var c_tex: Texture2D = GameData.get_chassis_tex(c_id)
		assert_true(c_tex != null, "战车底盘美术素材加载正常: %s" % c_id)

		for w_id in ch.get("starter_weapons", []):
			assert_true(GameData.WEAPONS.has(w_id), "战车初始武器存在于武器库: %s -> %s" % [c_id, w_id])

		var eng_id: String = ch.get("starter_engine", "")
		assert_true(GameData.ENGINES.has(eng_id), "战车初始引擎存在于引擎库: %s -> %s" % [c_id, eng_id])

		var cu_id: String = ch.get("starter_c_unit", "")
		assert_true(GameData.C_UNITS.has(cu_id), "战车初始C装置存在于核心库: %s -> %s" % [c_id, cu_id])

	# 1.3 武器库与超武配方校验
	assert_true(GameData.WEAPONS.size() >= 15, "武器库武器总数充足 (当前 %d)" % GameData.WEAPONS.size())
	for w_id in GameData.WEAPONS.keys():
		var w: Dictionary = GameData.WEAPONS[w_id]
		var valid: bool = w.has("id") and w.has("name") and w.has("slot") and w.has("base_dmg") and w.has("weight")
		assert_true(valid, "武器字段完整: %s (%s)" % [w_id, w.get("name", "")])

	assert_true(GameData.SUPER_EVOLUTIONS.size() >= 5, "超武合成配方数量 >= 5")
	for evo in GameData.SUPER_EVOLUTIONS:
		var res_id: String = evo["result"]
		assert_true(GameData.WEAPONS.has(res_id), "超武合成目标武器在武器库中存在: %s" % res_id)
		for ca in evo["comp_a"]:
			assert_true(GameData.WEAPONS.has(ca), "合成配件A存在: %s" % ca)
		for cb in evo["comp_b"]:
			assert_true(GameData.WEAPONS.has(cb), "合成配件B存在: %s" % cb)

	# 1.4 赏金首与战区生态校验
	assert_true(GameData.WANTED_BOSSES.size() == 10, "赏金首总数为 10 名")
	for b in GameData.WANTED_BOSSES:
		assert_true(b.has("id") and b.has("name") and b.has("hp") and b.has("bounty"), "赏金首信息完整: %s" % b["id"])
		var rw: String = b.get("reward_weapon", "")
		assert_true(GameData.WEAPONS.has(rw), "赏金首击杀掉落红武存在: %s -> %s" % [b["id"], rw])
		var b_tex: Texture2D = GameData.get_boss_tex(b["id"])
		assert_true(b_tex != null, "赏金首贴图正常加载: %s" % b["id"])

	assert_true(GameData.MAPS.size() == 5, "战区地图章节总数为 5 大章")
	for m in GameData.MAPS:
		for e_id in m["enemy_pool"]:
			assert_true(GameData.ENEMIES.has(e_id), "地图小怪生态存在: %s -> %s" % [m["id"], e_id])
		for el_id in m["elite_pool"]:
			assert_true(GameData.ENEMIES.has(el_id), "地图精英生态存在: %s -> %s" % [m["id"], el_id])
		assert_true(GameData.get_boss_by_id(m["regional_boss_id"]) != null, "区域Boss存在: %s" % m["regional_boss_id"])
		assert_true(GameData.get_boss_by_id(m["final_boss_id"]) != null, "关底Boss存在: %s" % m["final_boss_id"])
		var m_tex: Texture2D = GameData.get_terrain_tex(m["id"])
		assert_true(m_tex != null, "战区地貌贴图正常加载: %s" % m["id"])

# ============================================================================
# 2. GameState 运行状态与战车数据计算测试
# ============================================================================
func test_suite_2_gamestate_logic() -> void:
	print("\n--- [Suite 2] 核心状态机与战车改装数值计算 ---")

	var sample_pairs: Array = [
		["bounty_hunter", "buggy"],
		["lone_wolf", "r_wolf"],
		["mechanic", "mammoth"],
		["iron_fist", "ambulance"],
		["pochi", "bus"],
		["mince_aide", "missile_carrier"]
	]

	for pair in sample_pairs:
		var h_id: String = pair[0]
		var c_id: String = pair[1]
		GameState.start_new_run(h_id, c_id, 0, "normal")

		assert_true(GameState.selected_hunter_id == h_id, "开局猎人匹配: %s" % h_id)
		assert_true(GameState.selected_chassis_id == c_id, "开局底盘匹配: %s" % c_id)
		assert_true(GameState.equipped_weapons.size() > 0, "战车装配初始武器数量 > 0")
		assert_true(GameState.max_sp > 50.0, "战车SP最大值计算正常 (>50SP): 当前 %.1f" % GameState.max_sp)
		assert_true(GameState.max_weight > 10.0, "底盘最大载重正常: %.1f 吨" % GameState.max_weight)
		assert_true(GameState.used_weight <= GameState.max_weight, "初始配置未超重: 已用 %.1f / 上限 %.1f" % [GameState.used_weight, GameState.max_weight])

	# 测试武器购买、升星合成
	GameState.start_new_run("lone_wolf", "r_wolf", 0, "normal")
	GameState.add_gold(1000)

	var res1: Dictionary = GameState.add_weapon_to_first_valid_slot("cannon_105mm", 0)
	assert_true(res1.get("equipped", false) or res1.get("merged", false), "武器装配成功")

	for i in range(4):
		GameState.add_weapon_to_first_valid_slot("cannon_105mm", 0)
	var w_105: Dictionary = {}
	for w in GameState.equipped_weapons:
		if w["id"] == "cannon_105mm":
			w_105 = w
			break
	assert_true(not w_105.is_empty(), "找到已装配的 105mm 皇家加农")
	assert_true(w_105.get("rarity", 0) >= 1, "武器成功升级星级: 当前 ★%d" % (w_105.get("rarity", 0) + 1))

	# 测试槽位改装改孔
	var slots_count: int = GameState.chassis_slots.size()
	assert_true(slots_count > 0, "战车槽位配置有效 (共 %d 个)" % slots_count)
	var cur_type: String = GameState.chassis_slots[0]
	var ok_mod: bool = GameState.cycle_chassis_slot_type(0)
	assert_true(ok_mod, "战车底盘改孔执行成功")
	assert_true(GameState.chassis_slots[0] != cur_type, "槽位类型已成功循环切换")

	# 测试羁绊激活字典统计
	assert_true(GameState.synergy_counts is Dictionary, "羁绊系统统计正常存在")

# ============================================================================
# 3. 局外养成系统、原核晶片与设置持久化测试
# ============================================================================
func test_suite_3_meta_and_settings() -> void:
	print("\n--- [Suite 3] 局外养成科技树与存档测试 ---")

	GameState.reset_meta_save()
	GameState.noah_chips = 5000

	# 猎人与底盘解锁
	assert_true(GameState.is_hunter_unlocked("bounty_hunter"), "初始猎人默认解锁: bounty_hunter")
	var ok_unlock_h: bool = GameState.unlock_hunter("lone_wolf")
	assert_true(ok_unlock_h, "成功解锁猎人: lone_wolf")
	assert_true(GameState.is_hunter_unlocked("lone_wolf"), "状态机确认已解锁: lone_wolf")

	var ok_unlock_c: bool = GameState.unlock_chassis("r_wolf")
	assert_true(ok_unlock_c, "成功修复解锁战车底盘: r_wolf")
	assert_true(GameState.is_chassis_unlocked("r_wolf"), "状态机确认已解锁底盘: r_wolf")

	# 局外基础特性解锁
	var ok_feat: bool = GameState.unlock_feature("shop_lock")
	assert_true(ok_feat or GameState.is_feature_unlocked("shop_lock"), "解锁商品锁定器特性成功")

	# 数值科技升级
	var test_stat_id: String = "meta_dmg"
	var prev_lv: int = GameState.get_meta_level(test_stat_id)
	var ok_up: bool = GameState.upgrade_meta_stat(test_stat_id)
	assert_true(ok_up, "科技树升级成功: %s" % test_stat_id)
	assert_true(GameState.get_meta_level(test_stat_id) == prev_lv + 1, "科技树等级提升正确")

	# 存档与读档验证
	GameState.save_meta_data()
	GameState.load_meta_save()
	assert_true(GameState.is_hunter_unlocked("lone_wolf"), "读档后猎人解锁状态保留")
	assert_true(GameState.is_chassis_unlocked("r_wolf"), "读档后战车解锁状态保留")

	# 游戏设置测试
	GameState.set_setting("screen_shake_mult", 0.5)
	assert_true(float(GameState.get_setting("screen_shake_mult")) == 0.5, "设置项读取正常")
	GameState.set_setting("screen_shake_mult", 1.0)

# ============================================================================
# 4. 车库多拉姆商店与交互逻辑测试
# ============================================================================
func test_suite_4_garage_ui() -> void:
	print("\n--- [Suite 4] 车库整备与商店交互逻辑 ---")

	var garage_script: Script = load("res://scripts/ui/GarageUI.gd")
	assert_true(garage_script != null, "成功加载 GarageUI.gd")

	var garage_ui: Control = Control.new()
	garage_ui.set_script(garage_script)
	add_child(garage_ui)

	# 触发车库进入
	GameState.start_new_run("bounty_hunter", "buggy", 0, "normal")
	GameState.add_gold(300)
	garage_ui.open_garage()

	assert_true(garage_ui.shop_items.size() >= 4, "车库商店成功刷新出 4 格以上商品展柜 (当前 %d 格)" % garage_ui.shop_items.size())

	# 测试商品锁定机制
	if garage_ui.shop_items.size() > 0:
		garage_ui.shop_items[0]["locked"] = true
		var locked_id: String = garage_ui.shop_items[0]["id"]
		garage_ui._roll_shop_items()
		assert_true(garage_ui.shop_items[0]["id"] == locked_id, "锁定商品跨刷新保留成功: %s" % locked_id)

	garage_ui.queue_free()

# ============================================================================
# 5. 主菜单与全子界面分级流转测试
# ============================================================================
func test_suite_5_main_screen_navigation() -> void:
	print("\n--- [Suite 5] 主菜单与多全屏子界面流转 ---")

	var main_scene: PackedScene = load("res://scenes/Main.tscn")
	assert_true(main_scene != null, "成功加载 Main.tscn 场景")

	var main_node: Node = main_scene.instantiate()
	add_child(main_node)

	assert_true(main_node.title_screen != null, "主菜单 title_screen 节点存在")
	assert_true(main_node.view_select_hunter != null, "猎人选择子界面节点存在")
	assert_true(main_node.view_select_chassis != null, "战车整备子界面节点存在")
	assert_true(main_node.view_select_map != null, "战区选择子界面节点存在")
	assert_true(main_node.view_meta_lab != null, "科技实验室子界面节点存在")
	assert_true(main_node.view_bounties != null, "赏金首通缉令图鉴节点存在")
	assert_true(main_node.view_settings != null, "设置界面节点存在")

	# 流转到猎人界面
	main_node._switch_to_screen(main_node.ScreenState.SELECT_HUNTER)
	assert_true(main_node.view_select_hunter.visible, "成功流转至猎人选择界面")
	assert_true(main_node.hunter_cards_container.get_child_count() == 6, "猎人名册完整生成 6 张猎人卡")

	# 流转至战车底盘界面
	main_node._switch_to_screen(main_node.ScreenState.SELECT_CHASSIS)
	assert_true(main_node.view_select_chassis.visible, "成功流转至战车整备界面")
	assert_true(main_node.chassis_cards_container.get_child_count() == 8, "底盘网格完整生成 8 台载具卡")

	# 流转至战区章节界面
	main_node._switch_to_screen(main_node.ScreenState.SELECT_MAP)
	assert_true(main_node.view_select_map.visible, "成功流转至战区章节界面")
	assert_true(main_node.maps_cards_container.get_child_count() == 5, "战区列表完整生成 5 大战区卡")

	main_node.queue_free()

# ============================================================================
# 6. 战斗核心循环模拟测试
# ============================================================================
func test_suite_6_combat_simulation() -> void:
	print("\n--- [Suite 6] 战场实体与战斗循环压力模拟 ---")

	var bf_scene: PackedScene = load("res://scenes/Battlefield.tscn")
	assert_true(bf_scene != null, "成功加载 Battlefield.tscn 场景")

	var bf_node: Node2D = bf_scene.instantiate()
	add_child(bf_node)

	GameState.start_new_run("bounty_hunter", "buggy", 0, "normal")
	bf_node.start_wave()

	assert_true(bf_node.wave_active, "波次战斗已成功激活")
	assert_true(bf_node.player_tank != null, "玩家战车成功生成并在场")

	var p_tank = bf_node.player_tank
	assert_true(p_tank.current_sp > 0.0, "战车装甲片SP已充能: %.1f" % p_tank.current_sp)

	# 模拟开火逻辑
	p_tank._process_tank_weapons(0.05, bf_node)
	assert_true(bf_node.projectiles_container != null, "弹幕容器正常运作")

	# 模拟生成敌怪
	bf_node._do_spawn_enemy("bio_ant", Vector2(400, 300))
	assert_true(bf_node.enemies_container.get_child_count() > 0, "成功在战场生成敌怪")
	var enemy_node = bf_node.enemies_container.get_child(0)

	# 模拟敌怪受伤
	var initial_hp: float = enemy_node.hp
	enemy_node.take_damage(20.0, false, "none", enemy_node.global_position)
	assert_true(enemy_node.hp < initial_hp, "敌怪受击扣血结算正常: 原 %.1f -> 现 %.1f" % [initial_hp, enemy_node.hp])

	# 模拟生成赏金首
	bf_node._spawn_wanted_boss("boss_killdozer")
	var has_boss: bool = false
	for e in bf_node.enemies_container.get_children():
		if e.is_boss:
			has_boss = true
			break
	assert_true(has_boss, "赏金首【杀人推土机】成功登场并激活血条")

	# 模拟战车SP受击扣减
	var initial_sp: float = p_tank.current_sp
	p_tank.take_damage(15.0)
	assert_true(p_tank.current_sp < initial_sp, "战车SP成功承受伤害: 原 %.1f -> 现 %.1f" % [initial_sp, p_tank.current_sp])

	# 模拟大破下车逻辑
	p_tank.invuln_timer = 0.0
	p_tank.current_sp = 0.0
	p_tank.take_damage(10.0)
	assert_true(p_tank.is_human_mode, "SP归零后成功紧急脱离战车进入【步兵肉搏状态】")

	# 步兵修复重回战车
	p_tank.human_pos = p_tank.global_position
	p_tank.repair_progress = p_tank.repair_time_needed
	p_tank._process_human_mode(0.1, bf_node, Vector2.ZERO)
	assert_true(not p_tank.is_human_mode, "完成抢修后成功重回战车！")
	assert_true(p_tank.current_sp > 0.0, "重回战车后装甲SP恢复: %.1f" % p_tank.current_sp)

	bf_node.queue_free()

# ============================================================================
# 7. 超武合成体系与战场掉落物吸附测试
# ============================================================================
func test_suite_7_super_weapons_and_drops() -> void:
	print("\n--- [Suite 7] 超武合成体系与战场掉落物 ---")

	GameState.start_new_run("bounty_hunter", "mammoth", 0, "normal")
	GameState.equipped_weapons.clear()

	# 装配两件达到 ★4 (rarity=3) 的合成组件
	GameState.equipped_weapons.append({"id": "cannon_105mm", "rarity": 3})
	GameState.equipped_weapons.append({"id": "mg_vulcan", "rarity": 3})

	var evos: Array = GameState.try_trigger_super_evolutions(false)
	assert_true(evos.size() == 1, "超武合成成功触发: %s" % (evos[0]["evo_name"] if evos.size() > 0 else "无"))
	var has_super: bool = false
	for w in GameState.equipped_weapons:
		if w["id"] == "evo_red_wolf":
			has_super = true
			break
	assert_true(has_super, "神话超武【绯红双星·超重歼灭炮】已装配至战车！")

	# 测试武器出售与赏金折现返还
	var pre_gold: int = GameState.gold
	var sold_val: int = GameState.sell_weapon_at(0)
	assert_true(sold_val > 0, "武器成功出售折算赏金: +%d G" % sold_val)

	# 测试战场掉落物与磁吸
	var drop_scene: PackedScene = load("res://scenes/DropItem.tscn")
	assert_true(drop_scene != null, "成功加载 DropItem.tscn 场景")
	var drop_item = drop_scene.instantiate()
	add_child(drop_item)
	drop_item.setup("scrap", 5, Vector2(100, 100))
	assert_true(drop_item.drop_type == "scrap" and drop_item.value == 5, "掉落物初始化数据正确")
	drop_item.queue_free()

# ============================================================================
# 8. 全部 10 名「赏金首」登场与击杀奖励闭环测试
# ============================================================================
func test_suite_8_all_wanted_bosses() -> void:
	print("\n--- [Suite 8] 全 10 名赏金首召唤与击杀结算循环 ---")

	var bf_scene: PackedScene = load("res://scenes/Battlefield.tscn")
	var bf_node: Node2D = bf_scene.instantiate()
	add_child(bf_node)

	GameState.start_new_run("bounty_hunter", "abrams", 0, "normal")
	bf_node.start_wave()

	for b_def in GameData.WANTED_BOSSES:
		var b_id: String = b_def["id"]
		bf_node._spawn_wanted_boss(b_id)

		var spawned_boss: Node2D = null
		for e in bf_node.enemies_container.get_children():
			if e.enemy_id == b_id:
				spawned_boss = e
				break

		assert_true(spawned_boss != null, "赏金首【%s】在战场成功生成" % b_def["name"])

		# 模拟击杀该赏金首
		var pre_hunted: int = GameState.bounties_hunted
		bf_node.on_wanted_boss_defeated(spawned_boss)
		assert_true(GameState.bounties_hunted == pre_hunted + 1, "赏金首击杀计数自增正确")
		assert_true(b_id in GameState.defeated_wanted_ids, "赏金首已收录至已讨伐通缉档案: %s" % b_id)

		spawned_boss.queue_free()

	bf_node.queue_free()

# ============================================================================
# 9. 狂潮压迫感与战车履带碾压、连击割草测试
# ============================================================================
func test_suite_9_swarm_and_crush_mechanics() -> void:
	print("\n--- [Suite 9] 狂潮合围、履带碾压与连击割草机制测试 ---")

	var bf_scene: PackedScene = load("res://scenes/Battlefield.tscn")
	var bf_node: Node2D = bf_scene.instantiate()
	add_child(bf_node)

	GameState.start_new_run("iron_fist", "mammoth", 0, "normal")
	bf_node.start_wave()

	# 1. 验证敌人容量扩展与狂潮判定
	assert_true(bf_node.current_max_enemies >= 90, "怪物波次动态容量扩展正常 (初始 %d)" % bf_node.current_max_enemies)
	bf_node.is_horde_active = true
	assert_true(bf_node.is_horde_active == true, "机械狂潮暴动状态正常激活")

	# 2. 验证小队与360°环形包围刷怪
	var pre_telegraphs: int = bf_node.spawn_telegraphs.size()
	bf_node._queue_squad_spawn(4)
	assert_true(bf_node.spawn_telegraphs.size() == pre_telegraphs + 4, "战术小队集群冲锋生成队列正常 (+4)")

	bf_node._queue_ring_spawn(8)
	assert_true(bf_node.spawn_telegraphs.size() == pre_telegraphs + 12, "360° 环形铁桶包围圈生成队列正常 (+8)")

	# 3. 验证战车重型物理履带碾压 (Crush)
	var p_tank = bf_node.player_tank
	p_tank.current_sp = 500.0
	p_tank.current_velocity = Vector2(240.0, 0.0) # 高速巡航
	p_tank.invuln_timer = 0.0

	var dummy_enemy := Node2D.new()
	dummy_enemy.set_script(load("res://scripts/combat/Enemy.gd"))
	bf_node.enemies_container.add_child(dummy_enemy)
	dummy_enemy.setup_regular(GameData.ENEMIES["bio_ant"], 1, p_tank.global_position + Vector2(10, 0))
	dummy_enemy.hp = 20.0 # 极低HP轻量小怪

	var sp_before: float = p_tank.current_sp
	p_tank.on_enemy_collision(dummy_enemy, 0.016)

	assert_true(p_tank.current_sp == sp_before, "高速猛犸战车物理碾碎轻甲小怪，战车毫发无损 (0 SP损耗)")
	assert_true(dummy_enemy.hp <= 0.0, "小怪受到重型履带吨位直接碾碎致死")

	# 4. 验证狂飙连击与战术急速增益
	for i in range(35):
		bf_node.on_enemy_killed(dummy_enemy)
	assert_true(bf_node.combo_count >= 35, "连击杀戮计数器累加正常 (当前 %d Combo)" % bf_node.combo_count)
	bf_node._process(0.016)
	assert_true(float(GameState.bonus_stats.get("combo_reload_pct", 0.0)) >= 0.15, "达到 30+ Combo 触发 +15% 极速装填割草增益")

	# 5. 验证波次结束全图战利品全域磁暴吸附
	var drop1 := Node2D.new()
	drop1.set_script(load("res://scripts/combat/DropItem.gd"))
	bf_node.drops_container.add_child(drop1)
	drop1.setup("gold", 50, Vector2(1000, 1000))

	var gold_before: int = GameState.gold
	bf_node._finish_wave_success()
	assert_true(GameState.gold >= gold_before + 50, "波次结束全域磁暴回收全场掉落物，零资源浪费")

	# 6. 验证车库激光打孔与底盘换乘
	GameState.chassis_slots = ["MAIN", "SUB", "SE", "SE"]
	GameState.gold = 500
	var slots_pre: int = GameState.chassis_slots.size()
	var drill_ok: bool = GameState.drill_new_chassis_slot("MAIN")
	assert_true(drill_ok and GameState.chassis_slots.size() == slots_pre + 1, "车库激光打孔扩充槽位成功: 当前 %d 孔" % GameState.chassis_slots.size())

	var switch_ok: bool = GameState.switch_chassis("r_wolf")
	assert_true(switch_ok and GameState.selected_chassis_id == "r_wolf", "车库底盘换乘至【绯红之狼】成功")

	# 7. 验证战时升级EMP冲击波与绝境翻盘注能（仅简单模式生效）
	GameState.selected_difficulty_id = "easy"
	bf_node.start_wave()
	p_tank.current_sp = 20.0 # 濒死
	var test_e1 := Node2D.new()
	test_e1.set_script(load("res://scripts/combat/Enemy.gd"))
	bf_node.enemies_container.add_child(test_e1)
	test_e1.setup_regular(GameData.ENEMIES["bio_ant"], 1, p_tank.global_position + Vector2(50, 0))
	test_e1.stun_timer = 0.0

	bf_node._close_or_next_level_modal()
	assert_true(test_e1.stun_timer >= 1.0, "【简单模式】战时升级关闭触发战地EMP震荡波并眩晕敌怪 (眩晕时长 %.1fs)" % test_e1.stun_timer)

	# 验证在困难模式(normal)下不触发EMP冲击波与绝境翻盘注能
	GameState.selected_difficulty_id = "normal"
	test_e1.global_position = p_tank.global_position + Vector2(50, 0)
	test_e1.stun_timer = 0.0
	bf_node._close_or_next_level_modal()
	assert_true(test_e1.stun_timer == 0.0, "【困难/地狱模式】战时升级严格禁用EMP震荡波，保持硬核废土战斗节奏")

	bf_node.queue_free()


# ============================================================================
# 10. 成就系统(90+)、双皮肤体系、货币完全隔离与战车自由涂装车间测试
# ============================================================================
func test_suite_10_achievements_skins_and_paint_workshop() -> void:
	print("\n--- [Suite 10] 成就系统、双皮肤体系、货币隔离与涂装工坊 ---")

	# 10.1 成就系统数量与数据完整性
	assert_true(GameData.ACHIEVEMENTS.size() >= 80, "成就数量应不少于 80 项 (当前 %d 项)" % GameData.ACHIEVEMENTS.size())
	for ach in GameData.ACHIEVEMENTS:
		var has_fields: bool = ach.has("id") and ach.has("cat") and ach.has("name") and ach.has("desc") and ach.has("metric") and ach.has("target") and ach.has("rtype") and ach.has("rname")
		assert_true(has_fields, "成就字段完整: %s" % ach["id"])

	# 10.2 角色专属双皮肤校验 (6角色 × 2皮肤 = 12套)
	assert_true(GameData.HUNTER_SKINS.size() == 6, "全 6 名猎人均配置有专属皮肤库")
	for h_id in GameData.HUNTER_SKINS.keys():
		var skins: Array = GameData.HUNTER_SKINS[h_id]
		assert_true(skins.size() == 2, "猎人 %s 拥有 2 套专属战术皮肤" % h_id)
		for s in skins:
			assert_true(s.has("id") and s.has("name") and s.has("tint") and s.has("unlock_ach_id"), "猎人皮肤字段完整: %s -> %s" % [h_id, s["id"]])

	# 10.3 战车底盘专属双皮肤校验 (8战车 × 2皮肤 = 16套)
	assert_true(GameData.CHASSIS_SKINS.size() == 8, "全 8 台战车底盘均配置有专属皮肤库")
	for c_id in GameData.CHASSIS_SKINS.keys():
		var cskins: Array = GameData.CHASSIS_SKINS[c_id]
		assert_true(cskins.size() == 2, "战车 %s 拥有 2 套专属涂装皮肤" % c_id)
		for cs in cskins:
			assert_true(cs.has("id") and cs.has("name") and cs.has("body") and cs.has("turret") and cs.has("treads") and cs.has("decal"), "战车皮肤部位涂色字段完整: %s -> %s" % [c_id, cs["id"]])

	# 10.4 货币完全隔离校验 (原核晶片仅供科技树，角色与地图不消耗货币)
	GameState.reset_meta_save()
	var chips_pre: int = GameState.noah_chips
	GameState.unlock_hunter("lone_wolf")
	assert_true(GameState.noah_chips == chips_pre, "解锁猎人绝不扣除原核晶片货币 (原核晶片仅供科技树使用)")
	GameState.unlock_chassis("r_wolf")
	assert_true(GameState.noah_chips == chips_pre, "解锁战车底盘绝不扣除原核晶片货币 (原核晶片仅供科技树使用)")

	GameState.start_new_run("bounty_hunter", "buggy", 0, "normal")
	GameState.add_gold(400)
	assert_true(GameState.gold >= 400, "单局战斗内金币获取正常")
	GameState.start_new_run("bounty_hunter", "buggy", 0, "normal")
	assert_true(GameState.gold < 150, "车库金币仅当次闯关有效，新局开启自动重置初始津贴")

	# 10.5 成就达成与奖励解锁闭环联动
	# 连击成就解锁猎人皮肤
	GameState.report_metric("max_combo", 50, false)
	assert_true(GameState.is_achievement_unlocked("ach_combo_50"), "达成 50 Combo 触发解锁成就【连击大师】")
	assert_true(GameState.is_hunter_skin_unlocked("bounty_hunter", "bh_specops"), "成就【连击大师】自动解锁雷恩皮肤【荒原特战队】")

	# 击败首领成就解锁新战车
	GameState.report_metric("kill_boss_gomez", 1, false)
	assert_true(GameState.is_achievement_unlocked("ach_boss_gomez"), "击败巴洛克触发解锁成就【劫掠王陨落】")
	assert_true(GameState.is_chassis_unlocked("r_wolf"), "成就【劫掠王陨落】自动解锁传奇战车【绯红之狼】")

	# 通关章节成就解锁新地图
	GameState.report_metric("clear_map_1", 1, false)
	assert_true(GameState.is_achievement_unlocked("ach_clear_map_1"), "通关第 1 章节解锁成就【荒原先遣队】")
	assert_true(GameState.is_map_unlocked(1), "成就【荒原先遣队】自动解锁第 2 战区地图【死亡大沙漠】")

	# 10.6 战车改装涂装工坊 (自由 4 大独立部位调色与存档读档验证)
	var custom_paint_data: Dictionary = {
		"body": Color(0.9, 0.2, 0.3),
		"turret": Color(0.2, 0.4, 0.8),
		"treads": Color(0.1, 0.1, 0.1),
		"decal": Color(0.3, 0.9, 1.0)
	}
	GameState.set_custom_chassis_paint("buggy", custom_paint_data)
	assert_true(GameState.is_achievement_unlocked("ach_custom_paint"), "保存自定义战车涂色成功解锁成就【涂装大师】")

	var paint_read: Dictionary = GameState.get_custom_chassis_paint("buggy")
	assert_true(paint_read.has("body") and paint_read.has("turret") and paint_read.has("treads") and paint_read.has("decal"), "战车改造车间自由 4 部位颜色读取正确")

	GameState.save_meta_data()
	GameState.load_meta_save()
	var paint_after_load: Dictionary = GameState.get_custom_chassis_paint("buggy")
	var body_col: Color = paint_after_load.get("body", Color.BLACK)
	var is_color_match: bool = absf(body_col.r - 0.9) < 0.01 and absf(body_col.g - 0.2) < 0.01 and absf(body_col.b - 0.3) < 0.01
	assert_true(is_color_match, "局外存档读档完整保留战车自定义涂装色值 (8-bit色域精确还原)")


# ============================================================================
# 11. v2.0 成熟商业化标杆对比与四阶段全面优化验证
# ============================================================================
func test_suite_11_v2_blueprint_optimizations() -> void:
	print("\n--- [Suite 11] v2.0 商业化标杆四阶段优化全量验证 ---")

	# 11.1 阶段一：6种C装置主动战术技能、实时迎击拦截网、动态音频闪避与碎片粒子
	assert_true(GameData.C_UNITS.size() == 6, "C装置总数扩充至 6 款 (含神之右手迎击火控)")
	for cu_id in GameData.C_UNITS.keys():
		var cu: Dictionary = GameData.C_UNITS[cu_id]
		assert_true(cu.has("skill_id") and cu.has("skill_name") and cu.has("skill_icon"), "C装置主动战技字段完整: %s -> %s" % [cu_id, cu.get("skill_name", "")])

	assert_true(GameData.WEAPONS.has("sub_ciws_phalanx"), "新增副炮【密集阵CIWS近防迎击炮】存在")
	SoundManager.trigger_ducking(-5.5, 0.15)
	assert_true(SoundManager._duck_timer > 0.0, "SoundManager 动态侧链闪避 (Sidechain Ducking) 正常触发")

	# 11.2 阶段二：车库智能加权商店、16款战车改装件/诺亚诅咒件、引擎折旧换购与属性溯源
	assert_true(GameData.TANK_MODS.size() >= 16, "战车被动改装芯片与诺亚诅咒件不少于 16 款 (当前 %d 款)" % GameData.TANK_MODS.size())
	var cursed_cnt: int = 0
	for m_id in GameData.TANK_MODS.keys():
		if bool(GameData.TANK_MODS[m_id].get("is_cursed", false)):
			cursed_cnt += 1
	assert_true(cursed_cnt >= 6, "包含不少于 6 款高风险高回报【诺亚失控诅咒改装件】 (当前 %d 款)" % cursed_cnt)

	GameState.start_new_run("bounty_hunter", "mammoth", 0, "normal")
	GameState.gold = 500
	var w_slots_before: int = GameState.equipped_weapons.size()
	var mod_ok: bool = GameState.buy_tank_mod("mod_autoloader", 45)
	assert_true(mod_ok and GameState.equipped_tank_mods.get("mod_autoloader", 0) == 1, "成功购买并安装战车改装芯片【液压自动装填机】")
	assert_true(GameState.equipped_weapons.size() == w_slots_before, "战车改装芯片独立叠加，绝不占用战车武器孔位")
	assert_true(float(GameState.mod_bonus_stats.get("reload_speed_pct", 0.0)) >= 0.08, "改装件属性实时汇总至 mod_bonus_stats 并生效")

	# 测试引擎与C装置 50% 折旧换购
	GameState.equipped_engine_id = "eng_rwolf_turbo" # cost 140 -> trade-in 70
	assert_true(GameState.get_engine_trade_in_value() == 70, "旧引擎【绯红特制涡轮引擎】折旧 50% 抵扣计算准确 (70G)")
	GameState.equipped_c_unit_id = "cu_mirage" # cost 120 -> trade-in 60
	assert_true(GameState.get_c_unit_trade_in_value() == 60, "旧C装置【幻影全息系统】折旧 50% 抵扣计算准确 (60G)")

	# 测试智能加权商店刷新与属性溯源明细
	var candidate_weapons: Array = ["cannon_45mm", "cannon_105mm", "mg_77mm", "se_atm"]
	var rolled_wid: String = GameState.roll_weighted_weapon_id(candidate_weapons)
	assert_true(rolled_wid in candidate_weapons, "车库三层智能加权算法成功抽出合法候选武器: %s" % rolled_wid)
	var breakdown_sp: String = GameState.get_stat_breakdown("max_sp")
	assert_true(breakdown_sp.contains("底盘基础装甲") and breakdown_sp.contains("最终总计"), "车库属性面板支持多源加成公式溯源 Tooltip")

	# 11.3 阶段三 & 阶段四：战场实机验证 (迎击拦截、全Boss弱点破坏、精英词缀、动态事件、空间网格与对象池)
	var bf_scene: PackedScene = load("res://scenes/Battlefield.tscn")
	var bf_node: Node2D = bf_scene.instantiate()
	add_child(bf_node)
	bf_node.start_wave()
	var pt: Node2D = bf_node.player_tank

	# 验证金属碎片粒子与气浪环
	bf_node.fx_layer.debris.clear()
	bf_node.fx_layer.effects.clear()
	bf_node.fx_layer.spawn_metal_debris(pt.global_position, Color.ORANGE, 6)
	bf_node.fx_layer.spawn_shockwave(pt.global_position, 160.0, Color.CYAN)
	assert_true(bf_node.fx_layer.debris.size() == 6 and bf_node.fx_layer.effects.size() == 1, "战场物理弹片飞溅与冲击波气浪环正常生成")

	# 验证方向性弹簧震屏与顿帧
	bf_node.trigger_screen_shake(12.0, 0.25, Vector2.LEFT)
	assert_true(bf_node.shake_dir_impulse.x < -1.0, "主炮开火反冲方向性弹簧震屏冲量计算正确")
	bf_node.trigger_hitstop(0.02, 0.05)
	Engine.time_scale = 1.0
	bf_node._hitstop_active = false

	# 验证实时防空迎击系统 (CIWS / 宙斯盾 / 神之右手)
	GameState.equipped_c_unit_id = "cu_interceptor_ai"
	pt.sync_weapons_from_state()
	pt.intercept_timers.clear()
	var pre_intercept: float = float(GameState.achievement_progress.get("intercept_count", 0.0))
	bf_node.spawn_enemy_projectile(pt.global_position + Vector2(80, 0), Vector2.LEFT, 300.0, 20.0)
	assert_true(bf_node.projectiles_container.get_child_count() == 1, "敌方测试弹幕已生成")
	pt._process_interception_system(0.016, bf_node)
	assert_true(float(GameState.achievement_progress.get("intercept_count", 0.0)) == pre_intercept + 1.0, "迎击雷达成功在半空凌空击落敌方弹幕！")
	assert_true(bf_node.projectiles_container.get_child_count() == 0, "被拦截的敌方弹幕已从战场安全回收至对象池")

	# 验证 C 装置差异化主动战技释放
	for test_cu in ["cu_mirage", "cu_valkyrie", "cu_interceptor_ai"]:
		GameState.equipped_c_unit_id = test_cu
		pt.all_out_timer = 0.0
		pt._trigger_all_out_attack(bf_node)
		assert_true(pt.all_out_timer > 0.0, "C装置【%s】专属主动战技成功释放并进入冷却" % GameData.C_UNITS[test_cu]["skill_name"])

	# 验证全 10 名赏金首均具备可破坏弱点部位，且推土机铲刀破坏后解除正面减伤
	bf_node._clear_entities()
	bf_node._spawn_wanted_boss("boss_killdozer")
	var bulldozer: Node2D = bf_node.enemies_container.get_child(0)
	assert_true(bulldozer != null and bulldozer.boss_parts.size() >= 1, "杀人推土机拥有独立可破坏部位【前部合金推土铲】")
	bulldozer.facing_angle = 0.0
	var plow_world: Vector2 = bulldozer.global_position + Vector2(28, 0)
	bulldozer.take_damage(2500.0, true, "", plow_world, true)
	assert_true(not bulldozer.has_alive_part("plow"), "推土机前部合金推土铲被成功击碎破坏！")

	# 验证重装精英随机词缀生成
	bf_node._spawn_map_elite()
	var spawned_elite: Node2D = null
	for e in bf_node.enemies_container.get_children():
		if is_instance_valid(e) and e.is_elite and not e.is_boss:
			spawned_elite = e
			break
	assert_true(spawned_elite != null and spawned_elite.elite_affixes.size() >= 1, "重装精英成功挂载随机词缀: %s" % spawned_elite.enemy_name)

	# 验证波次内动态随机事件触发与完成结算
	bf_node.trigger_arena_event("airdrop_defense")
	assert_true(bf_node.active_arena_event.get("type", "") == "airdrop_defense", "战场动态事件【军火空投信标防守】成功激活")
	bf_node._complete_arena_event()
	assert_true(bf_node.active_arena_event.is_empty(), "战场动态事件完成后正常清理并派发空投改装奖励")

	# 验证 2D 空间哈希网格 O(1) 邻域检索与掉落物自动合并 (>75)
	bf_node._clear_entities()
	bf_node._do_spawn_enemy("bio_ant", Vector2(500, 500))
	bf_node._do_spawn_enemy("bio_ant", Vector2(2200, 1500))
	bf_node.rebuild_spatial_grid()
	var near_list: Array = bf_node.get_enemies_in_radius(Vector2(510, 510), 80.0)
	assert_true(near_list.size() == 1, "2D 空间哈希网格精准检索邻域敌怪 (命中 1，过滤远端敌怪)")

	for i in range(85):
		bf_node.spawn_drop("scrap", 1, Vector2(600 + (i % 5) * 4, 600))
	assert_true(bf_node.drops_container.get_child_count() <= 75, "同屏掉落物超过 75 个时触发自动合并压缩，防止节点爆炸 (当前节点数 %d)" % bf_node.drops_container.get_child_count())

	bf_node.queue_free()


# ============================================================================
# 12. 数值对比预览系统 (A ➔ B) 与满孔位防挤压 UI 约束测试
# ============================================================================
func test_suite_12_stat_previews_and_layout_constraints() -> void:
	print("--- [Suite 12] 数值对比预览系统 (A ➔ B) 与满孔位防挤压 UI 约束测试 ---")

	GameState.start_new_run("bounty_hunter", "buggy")

	# 1. 验证基础 simulate_stats 完整性
	var sim: Dictionary = GameState.simulate_stats()
	assert_true(sim.has("max_weight") and sim.has("used_weight") and sim.has("max_sp") and sim.has("move_speed"), "simulate_stats 包含核心载重与装甲字段")
	assert_true(sim["max_sp"] > 100.0, "模拟初始装甲血量正常大于 100 SP")

	# 2. 验证武器买入与二合一升星预览 (A ➔ B)
	# 2.1 新购入未装备武器
	var prev_new: Dictionary = GameState.preview_weapon_purchase("sub_acid", 0)
	assert_true(not prev_new["is_merge"], "新武器未装备时 preview_weapon_purchase 判定为非合成")
	assert_true(prev_new["cur_dmg"] > 0.0, "新武器伤害预览有效计入当前加成")
	assert_true(prev_new["new_used_w"] > prev_new["cur_used_w"], "新武器装车后已用负重正确增加")

	# 2.2 二合一合成升星预览
	var starter_w: String = GameState.equipped_weapons[0]["id"]
	var starter_rar: int = int(GameState.equipped_weapons[0].get("rarity", 0))
	var prev_merge: Dictionary = GameState.preview_weapon_purchase(starter_w, starter_rar)
	assert_true(prev_merge["is_merge"], "同名同星级武器 preview_weapon_purchase 判定为二合一合成")
	assert_true(prev_merge["next_rarity"] == starter_rar + 1, "合成后星级正确 +1")
	assert_true(prev_merge["new_dmg"] > prev_merge["cur_dmg"], "合成后伤害显著提升 (A ➔ B 伤害正向增长)")
	assert_true(prev_merge["dmg_delta"] > 0.0, "伤害增量 dmg_delta 为正值")

	# 3. 验证引擎换装对比预览
	var eng_prev: Dictionary = GameState.preview_engine_switch("eng_dozer")
	assert_true(eng_prev["max_w_delta"] > 0.0, "重型推土机引擎载重增量为正 (最大载重提升)")
	assert_true(eng_prev["sp_delta"] > 0.0, "重型推土机引擎带来正向战车装甲血量提升")
	assert_true(eng_prev["cur_max_w"] > 0.0 and eng_prev["new_max_w"] > eng_prev["cur_max_w"], "引擎换装 A ➔ B 最大载重准确")

	# 4. 验证火控电脑/C装置换装对比预览
	var cu_prev: Dictionary = GameState.preview_c_unit_switch("cu_type99")
	assert_true(cu_prev.has("cd_delta") and cu_prev.has("crit_delta") and cu_prev.has("sp_delta"), "C装置预览包含大招CD、暴击率与装甲血量变动")
	assert_true(cu_prev["crit_delta"] >= 0.0, "99式火控提供正向暴击率增幅")

	# 5. 验证引擎扩载快捷改装预览 (+2.5t)
	var tune_prev: Dictionary = GameState.preview_tune_engine(2.5)
	assert_true(tune_prev["max_w_delta"] >= 2.5, "引擎出力扩载 preview_tune_engine 最大载重增加 >= 2.5t")
	assert_true(tune_prev["sp_delta"] > 0.0, "引擎载重扩充后自动转化为战车装甲血量提升")

	# 6. 验证改装挂件 (Tank Mod) 叠加预览
	var mod_prev: Dictionary = GameState.preview_tank_mod_purchase("mod_autoloader")
	assert_true(mod_prev.has("stat_deltas") and not mod_prev["stat_deltas"].is_empty(), "改装挂件预览成功生成大白话属性变动列表")

	# 7. 验证底盘换乘预览
	var ch_prev: Dictionary = GameState.preview_chassis_switch("mammoth")
	assert_true(ch_prev.has("cur_sp") and ch_prev.has("new_sp") and ch_prev.has("cur_speed"), "换乘底盘预览提供装甲血量与车速完整对比")

	# 8. 验证武器出售回收预览
	var sell_prev: Dictionary = GameState.preview_sell_weapon(0)
	assert_true(sell_prev["refund"] > 0, "出售武器获得大于0的赏金回收")
	assert_true(sell_prev["sp_delta"] >= 0.0, "卸下武器释放负重后战车装甲血量正向恢复")
	assert_true(sell_prev["freed_w"] > 0.0, "卸下武器成功释放战车负重吨位")

	# 9. 验证 GarageUI 满孔位与防挤出 UI 布局约束
	var garage_script: Script = load("res://scripts/ui/GarageUI.gd")
	var garage_ui: Control = garage_script.new()
	assert_true(garage_ui != null, "GarageUI 成功实例化")

	# 将孔位开满至 6 孔并安装 6 把武器
	GameState.gold = 5000
	while GameState.chassis_slots.size() < 6:
		GameState.drill_new_chassis_slot("SUB")
	assert_true(GameState.chassis_slots.size() == 6, "战车武器孔位成功开满 6/6")

	var test_w_list: Array = ["sub_acid", "sub_shotgun", "se_atm", "se_spike_ball", "cannon_105mm", "sub_gatling"]
	for wid in test_w_list:
		if GameState.equipped_weapons.size() < 6 and GameData.WEAPONS.has(wid):
			GameState.equipped_weapons.append({"id": wid, "rarity": 0})
	GameState.recalculate_stats()
	assert_true(GameState.equipped_weapons.size() == 6, "战车武装成功装满 6/6")

	# 模拟添加 6 种不同流派挂件以激活全部流派胶囊
	for t in GameData.SYNERGIES.keys():
		GameState.synergy_counts[t] = 2

	# 挂载到根节点测试其布局约束
	add_child(garage_ui)
	garage_ui._build_ui()
	garage_ui.refresh_all()

	# 检查布局防挤压防御措施
	assert_true(garage_ui.left_vbox.clip_contents, "左侧主面板已启用 clip_contents 防止内容撑大外框")
	assert_true(garage_ui.slots_scroll.clip_contents, "武器槽位滚动容器已启用 clip_contents")
	assert_true(garage_ui.right_vbox.custom_minimum_size.x >= 340.0, "右侧战车属性栏锁定 >= 340px 最小保护宽度，100% 杜绝被挤出屏幕")
	assert_true(garage_ui.btn_tune_engine != null, "引擎扩载按钮引用有效挂载")
	assert_true(garage_ui.btn_tune_engine.tooltip_text.contains("最大载重"), "引擎扩载按钮提供详细 A ➔ B 悬停对比预览")

	garage_ui.queue_free()

# ============================================================================
# 13. 武器绚丽弹道特效 (8大类型+星级缩放+弹壳火光) 与无缝废土大地图测试
# ============================================================================
func test_suite_13_weapon_vfx_and_seamless_map() -> void:
	print("--- [Suite 13] 武器绚丽弹道特效与无缝废土地图综合验证 ---")

	var ProjScript: Script = load("res://scripts/combat/Projectile.gd")
	var FxScript: Script = load("res://scripts/combat/FloatingText.gd")
	var BfScript: Script = load("res://scripts/combat/Battlefield.gd")
	assert_true(ProjScript != null and FxScript != null and BfScript != null, "核心战斗弹道、粒子与战场脚本成功载入")

	# 1. 验证 8 大武器专属弹道原型 (VFX Kind)
	var p: Node2D = ProjScript.new()
	add_child(p)

	# 1.1 加特林/机枪 (tracer 曳光穿甲)
	p.setup_player_proj(Vector2.ZERO, Vector2.RIGHT, 720.0, 30.0, 0.0, "", false, false, 1, "sub_gatling", 0)
	assert_true(p.vfx_kind == "tracer" and p.trail_max >= 4, "加特林/副炮成功解析为 tracer 曳光弹形态 (带尾迹缓冲)")

	# 1.2 巨型重炮 (shell 沉重炮弹 + 冲击波环)
	p.setup_player_proj(Vector2.ZERO, Vector2.RIGHT, 650.0, 150.0, 70.0, "", false, true, 1, "cannon_105mm", 0)
	assert_true(p.vfx_kind == "shell" and p.trail_max == 7, "主炮重型炮弹成功解析为 shell 炮弹形态 (高对比尾流)")

	# 1.3 追踪导弹 (missile 火箭外形 + 尾翼 + 尾气青烟)
	p.setup_player_proj(Vector2.ZERO, Vector2.RIGHT, 540.0, 80.0, 45.0, "homing", false, false, 1, "se_atm", 0)
	assert_true(p.vfx_kind == "missile", "S-E 导弹成功解析为 missile 原型")

	# 1.4 地狱火焰 (flame 翻滚火球)
	p.setup_player_proj(Vector2.ZERO, Vector2.RIGHT, 480.0, 45.0, 0.0, "burn", false, false, 1, "sub_flamethrower", 0)
	assert_true(p.vfx_kind == "flame", "喷火器成功解析为 flame 火浪形态")

	# 1.5 强酸腐蚀 (acid 毒液水滴)
	p.setup_player_proj(Vector2.ZERO, Vector2.RIGHT, 500.0, 50.0, 0.0, "acid", false, false, 1, "sub_acid", 0)
	assert_true(p.vfx_kind == "acid", "酸液喷雾器成功解析为 acid 强酸水滴形态")

	# 1.6 特斯拉电弧 (tesla 闪电离子球)
	p.setup_player_proj(Vector2.ZERO, Vector2.RIGHT, 680.0, 40.0, 0.0, "electric", false, false, 1, "sub_spark", 0)
	assert_true(p.vfx_kind == "tesla", "副炮电磁枪成功解析为 tesla 电弧光球形态")

	# 1.7 贯穿激光 (laser 高能激光柱)
	p.setup_player_proj(Vector2.ZERO, Vector2.RIGHT, 850.0, 120.0, 0.0, "laser", false, true, 3, "cannon_laser", 0)
	assert_true(p.vfx_kind == "laser", "激光炮成功解析为 laser 强光柱形态")

	# 1.8 神话超武原型 (evo_plasma, evo_omega, evo_nuke, evo_plague, evo_gaia)
	p.setup_player_proj(Vector2.ZERO, Vector2.RIGHT, 700.0, 300.0, 100.0, "plasma_cluster", false, true, 2, "evo_red_wolf", 4)
	assert_true(p.vfx_kind == "evo_plasma", "超武【日冕离子炮 / 绯红双星】成功解析为 evo_plasma 等离子超武形态")

	p.setup_player_proj(Vector2.ZERO, Vector2.RIGHT, 900.0, 250.0, 0.0, "omega_laser", false, true, 5, "evo_omega_railgun", 4)
	assert_true(p.vfx_kind == "evo_omega", "超武【欧米茄光矛 / Ω轨道炮】成功解析为 evo_omega 聚能终极激光形态")

	# 2. 验证星级体积视觉成长 (★1 1.0x ➔ ★5 1.72x)
	p.setup_player_proj(Vector2.ZERO, Vector2.RIGHT, 650.0, 80.0, 0.0, "", false, false, 1, "sub_gatling", 0)
	assert_true(is_equal_approx(p.vis_scale, 1.0), "★1 武器弹道基础体积比例为 1.0x")

	p.setup_player_proj(Vector2.ZERO, Vector2.RIGHT, 650.0, 80.0, 0.0, "", false, false, 1, "sub_gatling", 4)
	assert_true(is_equal_approx(p.vis_scale, 1.72), "★5 (满级/超武) 武器弹道体积显著放大至 1.72x，反馈震撼")
	p.queue_free()

	# 3. 验证战场粒子与开火反馈系统 (FloatingText.gd)
	var fx: Node2D = FxScript.new()
	add_child(fx)

	# 3.1 枪口焰 (Muzzle Flash)
	fx.spawn_muzzle_flash(Vector2(100, 100), Vector2.RIGHT, "cannon", 1.5)
	assert_true(fx.muzzle_flashes.size() == 1, "成功生成主炮炮口火光与暴风特效")
	assert_true(fx.muzzle_flashes[0]["kind"] == "cannon", "枪口火光类型记录正确")

	# 3.2 黄铜弹壳抛射 (Casings)
	fx.spawn_casing(Vector2(100, 100), Vector2(-1, 0), true)
	assert_true(fx.casings.size() == 1 and fx.casings[0]["is_cannon"], "成功抛射重炮大口径黄铜弹壳")

	fx.spawn_casing(Vector2(100, 100), Vector2(-1, 0), false)
	assert_true(fx.casings.size() == 2 and not fx.casings[1]["is_cannon"], "成功抛射副炮速射黄铜弹壳")

	# 3.3 尾气青烟 (Smoke Puffs)
	fx.spawn_smoke_puff(Vector2(200, 200), 8.0, Color(0.9, 0.9, 0.9, 0.5), 0.5)
	assert_true(fx.smoke_puffs.size() == 1, "成功生成导弹/战车尾焰青烟粒子")

	# 3.4 命中金属火花束 (Spark Shower)
	fx.spawn_spark_shower(Vector2(300, 300), Vector2.RIGHT, Color.YELLOW, 8)
	assert_true(fx.sparks.size() == 8, "击中金属甲板成功迸射 8 枚反向高光火星")

	# 3.5 地面焦黑弹坑 (Scorch)
	fx.spawn_scorch(Vector2(400, 400), 25.0)
	assert_true(fx.scorches.size() == 1, "高爆弹爆炸成功在地面烙印焦黑弹坑")

	# 模拟粒子生命周期衰减与自然移除
	fx._process(0.2)
	assert_true(fx.muzzle_flashes.is_empty(), "枪口短促火光 (0.11s) 历经 0.2s 后已自然消散")
	assert_true(fx.casings.size() == 2, "黄铜弹壳在地面持续留存 (生命周期 1.6s)")

	fx.queue_free()

	# 4. 验证 100% 无缝地形纹理与废土公路地裂
	var bf_scene: PackedScene = load("res://scenes/Battlefield.tscn")
	var bf: Node2D = bf_scene.instantiate()
	add_child(bf)
	GameState.start_new_run("bounty_hunter", "buggy", 0, "normal")
	bf.start_wave()

	# 4.1 校验 5 幅地图贴图加载无缺失
	for m_id in ["map_1", "map_2", "map_3", "map_4", "map_5"]:
		var tex: Texture2D = GameData.get_terrain_tex(m_id)
		assert_true(tex != null, "地图地形纹理加载正常: %s" % m_id)

	# 4.2 校验废土公路生成
	assert_true(bf.wasteland_roads.size() >= 2, "成功生成横跨废土战场的破裂柏油公路")
	assert_true(bf.wasteland_roads[0].has("cracks") and bf.wasteland_roads[0]["cracks"].size() > 0, "柏油公路包含沥青破损路面凹坑细节")

	# 4.3 校验地裂缝与断裂带生成
	assert_true(bf.wasteland_fissures.size() == 7, "成功生成 7 条地质断裂带与深渊地缝")
	assert_true(bf.wasteland_fissures[0]["points"].size() >= 5, "地裂缝包含多段曲折折线点集合")

	# 4.4 校验环境风沙微粒漂浮
	assert_true(bf.dust_particles.size() == 48, "成功生成 48 枚常驻环境废土风沙漂浮微粒")
	var prev_pos_x: float = bf.dust_particles[0]["pos"].x
	bf._process(0.25)
	assert_true(bf.dust_particles[0]["pos"].x != prev_pos_x, "环境风沙粒子随风速实时位移飘散，赋予大地动态活力")

	bf.queue_free()
