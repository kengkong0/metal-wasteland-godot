extends Node
## 《重装废土：赏金狂飙》 - 核心配置与图鉴数据库 (对应 GDD v1.0)
## 包含：6大猎人、8大底盘、武器库(主炮/副炮/S-E/Boss专属红武)、引擎库、C装置库、6大羁绊、10大赏金首。

const RARITY_NAMES: Array = ["普通(★1)", "精良(★2)", "稀有(★3)", "史诗(★4)", "绯红传奇(★5)", "【神话超武(★6)】"]
const RARITY_COLORS: Array = [
	Color(0.82, 0.82, 0.82), # ★1 白
	Color(0.35, 0.88, 0.45), # ★2 绿
	Color(0.30, 0.68, 1.00), # ★3 蓝
	Color(0.78, 0.42, 1.00), # ★4 紫
	Color(1.00, 0.28, 0.22), # ★5 红(传奇)
	Color(1.00, 0.86, 0.15)  # ★6 金(神话超武)
]

func _ready() -> void:
	_setup_input_map()

func _setup_input_map() -> void:
	# 1. 键盘与手柄左摇杆/十字键：战车驾驶与步兵移动
	_bind_key("move_left", [KEY_A, KEY_LEFT])
	_bind_key("move_right", [KEY_D, KEY_RIGHT])
	_bind_key("move_up", [KEY_W, KEY_UP])
	_bind_key("move_down", [KEY_S, KEY_DOWN])
	_bind_joy_axis("move_left", JOY_AXIS_LEFT_X, -1.0)
	_bind_joy_axis("move_right", JOY_AXIS_LEFT_X, 1.0)
	_bind_joy_axis("move_up", JOY_AXIS_LEFT_Y, -1.0)
	_bind_joy_axis("move_down", JOY_AXIS_LEFT_Y, 1.0)
	_bind_joy_button("move_left", [JOY_BUTTON_DPAD_LEFT])
	_bind_joy_button("move_right", [JOY_BUTTON_DPAD_RIGHT])
	_bind_joy_button("move_up", [JOY_BUTTON_DPAD_UP])
	_bind_joy_button("move_down", [JOY_BUTTON_DPAD_DOWN])

	# 2. 手柄右摇杆：360° 独立旋转主炮塔双摇杆瞄准
	_bind_joy_axis("aim_left", JOY_AXIS_RIGHT_X, -1.0)
	_bind_joy_axis("aim_right", JOY_AXIS_RIGHT_X, 1.0)
	_bind_joy_axis("aim_up", JOY_AXIS_RIGHT_Y, -1.0)
	_bind_joy_axis("aim_down", JOY_AXIS_RIGHT_Y, 1.0)

	# 3. 战斗核心动作：键鼠 + 手柄肩键/扳机/ABXY 全面映射
	_bind_key("all_out_attack", [KEY_Q])
	_bind_joy_button("all_out_attack", [JOY_BUTTON_LEFT_SHOULDER])
	_bind_joy_axis("all_out_attack", JOY_AXIS_TRIGGER_LEFT, 1.0)

	_bind_key("eject_tank", [KEY_E])
	_bind_joy_button("eject_tank", [JOY_BUTTON_X])

	_bind_key("dodge_roll", [KEY_SPACE])
	_bind_joy_button("dodge_roll", [JOY_BUTTON_A, JOY_BUTTON_B])

	_bind_key("toggle_auto_main", [KEY_R])
	_bind_joy_button("toggle_auto_main", [JOY_BUTTON_Y])

	_bind_mouse("fire_main", MOUSE_BUTTON_LEFT)
	_bind_joy_button("fire_main", [JOY_BUTTON_RIGHT_SHOULDER])
	_bind_joy_axis("fire_main", JOY_AXIS_TRIGGER_RIGHT, 1.0)

	_bind_mouse("manual_aim_hold", MOUSE_BUTTON_RIGHT)

	# 4. 手柄快捷菜单动作与战术暂停/静音按键
	_bind_joy_button("gamepad_start", [JOY_BUTTON_START])
	_bind_joy_button("gamepad_select", [JOY_BUTTON_BACK])
	_bind_key("pause_game", [KEY_ESCAPE, KEY_P])
	_bind_joy_button("pause_game", [JOY_BUTTON_START])
	_bind_key("toggle_mute", [KEY_M])
	_bind_key("toggle_fullscreen", [KEY_F11])

	# 5. 确保内置 UI 焦点导航支持手柄十字键、左摇杆与 A 键确认
	_bind_joy_button("ui_accept", [JOY_BUTTON_A])
	_bind_joy_button("ui_left", [JOY_BUTTON_DPAD_LEFT])
	_bind_joy_button("ui_right", [JOY_BUTTON_DPAD_RIGHT])
	_bind_joy_button("ui_up", [JOY_BUTTON_DPAD_UP])
	_bind_joy_button("ui_down", [JOY_BUTTON_DPAD_DOWN])
	_bind_joy_axis("ui_left", JOY_AXIS_LEFT_X, -1.0)
	_bind_joy_axis("ui_right", JOY_AXIS_LEFT_X, 1.0)
	_bind_joy_axis("ui_up", JOY_AXIS_LEFT_Y, -1.0)
	_bind_joy_axis("ui_down", JOY_AXIS_LEFT_Y, 1.0)

func _bind_key(action: String, keys: Array) -> void:
	if not InputMap.has_action(action):
		InputMap.add_action(action)
	for k in keys:
		var ev := InputEventKey.new()
		ev.physical_keycode = k
		InputMap.action_add_event(action, ev)

func _bind_mouse(action: String, button_idx: int) -> void:
	if not InputMap.has_action(action):
		InputMap.add_action(action)
	var ev := InputEventMouseButton.new()
	ev.button_index = button_idx
	InputMap.action_add_event(action, ev)

func _bind_joy_button(action: String, buttons: Array) -> void:
	if not InputMap.has_action(action):
		InputMap.add_action(action)
	for b in buttons:
		var ev := InputEventJoypadButton.new()
		ev.button_index = b
		InputMap.action_add_event(action, ev)

func _bind_joy_axis(action: String, axis: int, axis_val: float) -> void:
	if not InputMap.has_action(action):
		InputMap.add_action(action, 0.22)
	var ev := InputEventJoypadMotion.new()
	ev.axis = axis
	ev.axis_value = axis_val
	InputMap.action_add_event(action, ev)

# ============================================================================
# 1. 六大首发猎人角色 (HUNTERS - 东方日系二次元动漫人设与废土传记)
# ============================================================================
const HUNTERS: Dictionary = {
	"bounty_hunter": {
		"id": "bounty_hunter",
		"name": "雷恩 · 王牌猎人 (Rayne)",
		"char_name": "雷恩 (Rayne)",
		"title": "废土红鹰 · 主炮寻宝专家",
		"quote": "“只要战车的引擎还在跳动，荒原上就没有我追不上的赏金首！”",
		"bio": "在钢铁与风沙中长大的热血赤发少年。为了寻找失踪的父亲以及传说中击溃终末智脑的‘绯红孤狼’战车，他驾驶着由废铁手工打磨拼装的巴吉越野车踏上荒漠。凭借天生敏锐的直觉，他能在极限绝境中捕捉到赏金首的装甲弱点与地下埋藏的金属宝箱。",
		"recommended_chassis": "荒野巴吉 (Buggy) / 复合重坦 (Abrams)",
		"trait_tags": ["主炮高爆", "赏金宝箱", "热血少年"],
		"unlock_ach_id": "",
		"unlock_ach_desc": "初始已解锁",
		"color": Color(0.95, 0.65, 0.20),
		"desc": "【正面】主炮伤害+20%，装填速度+15%，对赏金首伤害+25%；每波必刷1个埋藏金属箱。\n【代价】副炮与S-E改孔费用+25%。",
		"mods": {
			"main_dmg_pct": 0.20,
			"reload_speed_pct": 0.15,
			"boss_dmg_pct": 0.25,
			"guaranteed_chest": 1
		}
	},
	"lone_wolf": {
		"id": "lone_wolf",
		"name": "克莱因 · 绯红孤狼 (Klein)",
		"char_name": "克莱因 (Klein)",
		"title": "绯红死神 · 极限单主炮狙击手",
		"quote": "“闪开。绯红孤狼的炮火从不落空，这一击会把整座要塞撕成碎片。”",
		"bio": "身裹染血深红防风斗篷的冷冽赏金猎人。黑发赤瞳，沉默少言，贯彻‘一发入魂’的绝对炮术美学。传闻他曾在雷鸣要塞一人一车击落三架近地巡航战舰。当他如狼般的血色眼眸锁定目标时，死亡倒计时便已开始。",
		"recommended_chassis": "绯红之狼 (Crimson-Wolf) / 暴龙双炮车 (Tyrannos)",
		"trait_tags": ["单炮极致", "超高暴击", "冷酷孤狼"],
		"unlock_ach_id": "ach_kill_500",
		"unlock_ach_desc": "达成成就【荒原猎王·五百人斩】解锁",
		"color": Color(0.92, 0.22, 0.18),
		"desc": "【正面】当战车仅安装 1 门主炮时，主炮伤害+60%、暴击率+25%，暴击击杀返还1发弹药。\n【代价】无法安装浮游无人机；商店武器价格+15%。",
		"mods": {
			"lone_main_dmg_pct": 0.60,
			"lone_main_crit": 0.25,
			"shop_price_pct": 0.15
		}
	},
	"mechanic": {
		"id": "mechanic",
		"name": "爱丽丝 · 天才机械师 (Alice)",
		"char_name": "爱丽丝 (Alice)",
		"title": "扳手萌妹 · 动力改装与光速抢修",
		"quote": "“嘿嘿，给我两把扳手和半桶柴油，哪怕废铁我也能改造成无敌战神！”",
		"bio": "废铁镇公认的首席天才少女机械技师。留着充满元气的金褐色双马尾，鼻尖常常挂着一抹可爱的机油痕迹。对重工业机甲和大马力柴油引擎有着近乎痴迷的热爱，拥有无与伦比的心灵手巧——哪怕战车被打得只剩底盘装甲，她也能在十秒内让其满血复活！",
		"recommended_chassis": "猛犸要塞 (Mammoth) / 野战救护车 (Ambulance)",
		"trait_tags": ["超载极限", "极速抢修", "元气少女"],
		"unlock_ach_id": "",
		"unlock_ach_desc": "初始已解锁",
		"color": Color(0.28, 0.78, 0.95),
		"desc": "【正面】引擎最大载重+25%，每秒自动恢复1.5%最大SP，刷新费用-40%，底盘改孔免费，修车仅需2秒。\n【代价】主炮基础伤害-15%，步兵肉搏伤害-30%。",
		"mods": {
			"max_weight_pct": 0.25,
			"sp_regen_pct": 0.015,
			"reroll_discount": 0.40,
			"free_slot_mod": true,
			"fast_repair": true,
			"main_dmg_pct": -0.15
		}
	},
	"iron_fist": {
		"id": "iron_fist",
		"name": "凛 · 废土武道家 (Rin)",
		"char_name": "凛 (Rin)",
		"title": "东洋修罗 · 机械外骨骼肉搏大师",
		"quote": "“东方武道的终极奥义——这一拳，连百吨主战坦克也能彻底击穿！”",
		"bio": "来自隐秘东方避难所的古武道传人。身着融合了高弹纳米纤维的无袖战术旗袍，双臂配备重工业碳纤维格斗外骨骼。性格英气豪爽，坚信人类血肉之躯在极限锤炼与东方内劲加持下，不仅能凌驾于冰冷的钢铁之上，甚至能将战车视作发射飞踢的弹药！",
		"recommended_chassis": "荒野巴吉 (Buggy) / 暴风导弹车 (Missile Carrier)",
		"trait_tags": ["肉搏飞踢", "自爆核击", "飒爽英气"],
		"unlock_ach_id": "ach_tank_dmg_2500",
		"unlock_ach_desc": "达成成就【钢筋铁骨】单局吸收2500伤害解锁",
		"color": Color(0.95, 0.40, 0.65),
		"desc": "【正面】步兵HP+200%，肉搏攻速与移速+40%；按[E]可主动引爆战车造成 8倍最大SP 全屏核爆伤害！\n【代价】战车引擎载重上限-25%。",
		"mods": {
			"human_hp_mult": 3.0,
			"human_speed_pct": 0.40,
			"self_destruct_nuke": true,
			"max_weight_pct": -0.25
		}
	},
	"pochi": {
		"id": "pochi",
		"name": "麦克斯 · 战术柴犬 (Max)",
		"char_name": "麦克斯 (Max)",
		"title": "荒原神犬 · 敏捷突袭与基因吞噬",
		"quote": "“汪呜！(麦克斯警惕地立起耳朵，背上的微型加特林发出清脆的上膛声)”",
		"bio": "特斯拉博士最引以为傲的生化奇迹改造萌宠。一只眼神聪明机警、毛发蓬松金黄的秋田柴犬，脖子上戴着红色冒险围巾与风镜。背部搭载高科技轻量化旋转加特林机枪，拥有远超普通猎犬的极速飞奔能力与惊人的基因吞噬本能，是废土每位老猎人梦寐以求的灵魂战友。",
		"recommended_chassis": "武装大巴 (Battle Bus) / 荒野巴吉 (Buggy)",
		"trait_tags": ["极速游击", "基因成长", "萌系战犬"],
		"unlock_ach_id": "ach_human_kill_20",
		"unlock_ach_desc": "达成成就【步兵奇迹】步兵肉搏击杀20敌怪解锁",
		"color": Color(0.90, 0.82, 0.35),
		"desc": "【正面】基础移速+35%，闪避率+20%；击杀敌人有概率掉落【基因肉块】永久增加SP与攻速。\n【代价】无法使用重型主炮，所有主炮孔自动转为副炮/SE。",
		"mods": {
			"move_speed_pct": 0.35,
			"dodge": 0.20,
			"bio_devour": true,
			"no_main_cannon": true
		}
	},
	"mince_aide": {
		"id": "mince_aide",
		"name": "伊戈尔 · 赛博方士 (Igor)",
		"char_name": "伊戈尔 (Igor)",
		"title": "雷法秘术 · 元素异常与电击傀儡",
		"quote": "“电极已就绪……呵呵，愿九天雷霆与高压电弧超度尔等机械残骸。”",
		"bio": "随身悬挂神秘符文电极管的银发紫瞳少年，特斯拉博士唯一的亲传炼金术士兼东方雷法修习者。性格优雅慵懒却心怀玄机，擅长将古老东方五行雷火与现代赛博生化科技交织。谈笑间即可召唤布满特斯拉电弧的高压机甲傀儡，将整座机械兽潮化为灰烬。",
		"recommended_chassis": "暴风导弹车 (Missile Carrier) / 复合重坦 (Abrams)",
		"trait_tags": ["雷火元素", "电击傀儡", "神秘方士"],
		"unlock_ach_id": "ach_boss_noah",
		"unlock_ach_desc": "达成成就【人类黎明】击败终焉主脑解锁",
		"color": Color(0.65, 0.42, 0.95),
		"desc": "【正面】电击、火焰、酸液伤害+35%；元素击杀有20%概率召唤【带电僵尸炮塔】协助作战10秒。\n【代价】实弹物理伤害-20%，每吨SP转化率-15%。",
		"mods": {
			"elemental_dmg_pct": 0.35,
			"zombie_summon": true,
			"main_dmg_pct": -0.20,
			"sp_per_ton_pct": -0.15
		}
	}
}

# ============================================================================
# 2. 八大经典战车底盘 (CHASSIS)
# ============================================================================
const CHASSIS: Dictionary = {
	"buggy": {
		"id": "buggy",
		"name": "荒野巴吉 (Buggy)",
		"unlock_ach_id": "",
		"unlock_ach_desc": "初始已解锁",
		"slots": ["MAIN", "SUB", "SUB", "SE"],
		"base_weight": 3.5,
		"sp_per_ton": 16.0,
		"base_sp": 90.0,
		"speed": 255.0,
		"color": Color(0.32, 0.58, 0.85),
		"desc": "【沙地漂移】1主/2副/1SE。高机动轻型战车，移动时所有副炮射速 +25%。",
		"starter_weapons": ["cannon_45mm", "mg_77mm"],
		"starter_engine": "eng_bulldog_v8",
		"starter_c_unit": "cu_type66"
	},
	"r_wolf": {
		"id": "r_wolf",
		"name": "绯红之狼 (Crimson Wolf)",
		"unlock_ach_id": "ach_boss_gomez",
		"unlock_ach_desc": "达成成就【劫掠王陨落】击败荒原劫掠王·巴洛克解锁",
		"slots": ["MAIN", "MAIN", "SUB", "SE", "SE"],
		"base_weight": 8.0,
		"sp_per_ton": 20.0,
		"base_sp": 130.0,
		"speed": 220.0,
		"color": Color(0.85, 0.18, 0.15),
		"desc": "【深红连星】2主/1副/2SE。传说游侠座驾，主炮暴击时 30% 概率立即免费追加发射一发！",
		"starter_weapons": ["cannon_105mm", "mg_77mm"],
		"starter_engine": "eng_bulldog_v8",
		"starter_c_unit": "cu_type66"
	},
	"abrams": {
		"id": "abrams",
		"name": "复合重坦 M1 (Abrams)",
		"unlock_ach_id": "",
		"unlock_ach_desc": "初始已解锁",
		"slots": ["MAIN", "MAIN", "SUB", "SUB", "SE"],
		"base_weight": 9.5,
		"sp_per_ton": 26.0,
		"base_sp": 160.0,
		"speed": 190.0,
		"color": Color(0.45, 0.58, 0.35),
		"desc": "【反应装甲】2主/2副/1SE。每吨剩余载重转化 26 SP，受到碰撞与近战伤害 -25%。",
		"starter_weapons": ["cannon_105mm", "mg_77mm"],
		"starter_engine": "eng_bulldog_v8",
		"starter_c_unit": "cu_type66"
	},
	"missile_carrier": {
		"id": "missile_carrier",
		"name": "暴风导弹车 (Missile Carrier)",
		"unlock_ach_id": "ach_all_out_10",
		"unlock_ach_desc": "达成成就【全弹风暴】累计触发10次全弹发射解锁",
		"slots": ["SUB", "SE", "SE", "SE", "SE", "SE"],
		"base_weight": 6.5,
		"sp_per_ton": 18.0,
		"base_sp": 115.0,
		"speed": 210.0,
		"color": Color(0.38, 0.52, 0.48),
		"desc": "【模块化发射架】0主/1副/5SE。所有 S-E 装备重量减轻 30%，S-E 齐射冷却缩短 20%。",
		"starter_weapons": ["mg_77mm", "se_atm"],
		"starter_engine": "eng_bulldog_v8",
		"starter_c_unit": "cu_type66"
	},
	"mammoth": {
		"id": "mammoth",
		"name": "猛犸象要塞 (Mammoth)",
		"unlock_ach_id": "ach_crush_30",
		"unlock_ach_desc": "达成成就【压路狂飙】单局碾碎30只小怪解锁",
		"slots": ["MAIN", "MAIN", "MAIN", "SUB", "SUB", "SE", "SE"],
		"base_weight": 15.0,
		"sp_per_ton": 30.0,
		"base_sp": 210.0,
		"speed": 155.0,
		"dual_engine": true,
		"color": Color(0.55, 0.44, 0.30),
		"desc": "【双核驱动】3主/2副/2SE。双引擎插槽(载重+45%)！碾压伤害 +150% 且免疫击退。",
		"starter_weapons": ["cannon_105mm", "se_spike_ball"],
		"starter_engine": "eng_dozer",
		"starter_c_unit": "cu_type66"
	},
	"ambulance": {
		"id": "ambulance",
		"name": "白色恶魔救护车 (Ambulance)",
		"unlock_ach_id": "ach_repair_sp_3000",
		"unlock_ach_desc": "达成成就【战场天使】累计抢修战车3000 SP解锁",
		"slots": ["SUB", "SUB", "SUB", "SUB", "SE", "SE"],
		"base_weight": 5.0,
		"sp_per_ton": 19.0,
		"base_sp": 125.0,
		"speed": 235.0,
		"color": Color(0.92, 0.92, 0.95),
		"desc": "【过量医疗】0主/4副/2SE。每秒自动维修量 +60%，且周围持续散发生化毒雾。",
		"starter_weapons": ["sub_acid", "mg_77mm"],
		"starter_engine": "eng_bulldog_v8",
		"starter_c_unit": "cu_type66"
	},
	"bus": {
		"id": "bus",
		"name": "武装大巴 (Wasteland Bus)",
		"unlock_ach_id": "ach_survive_waves_15",
		"unlock_ach_desc": "达成成就【废土观光客】存活超过15个战斗波次解锁",
		"slots": ["MAIN", "SUB", "SUB", "SE", "SE"],
		"base_weight": 8.5,
		"sp_per_ton": 22.0,
		"base_sp": 145.0,
		"speed": 200.0,
		"color": Color(0.88, 0.68, 0.18),
		"desc": "【车窗齐射】1主/2副/2SE。车内搭载雇佣兵随从，自动探出车窗向四周射击！",
		"starter_weapons": ["cannon_45mm", "sub_shotgun"],
		"starter_engine": "eng_bulldog_v8",
		"starter_c_unit": "cu_type66"
	},
	"tyrannos": {
		"id": "tyrannos",
		"name": "暴龙生物战车 (Bio-Tyrannos)",
		"unlock_ach_id": "ach_clear_hell",
		"unlock_ach_desc": "达成成就【梦魇主宰】地狱模式通关第1章解锁",
		"slots": ["MAIN", "SUB", "SE", "MAIN"],
		"base_weight": 5.5,
		"sp_per_ton": 24.0,
		"base_sp": 150.0,
		"speed": 225.0,
		"color": Color(0.48, 0.25, 0.58),
		"desc": "【血肉再生】每过 3 波进化长出 1 个新槽位(上限7孔)，每秒自动再生 0.8% 最大SP。",
		"starter_weapons": ["cannon_cement", "mg_77mm"],
		"starter_engine": "eng_bulldog_v8",
		"starter_c_unit": "cu_type66"
	}
}

# ============================================================================
# 3. 战车武器数据库 (WEAPONS: MAIN / SUB / SE / BOSS专属)
# ============================================================================
const WEAPONS: Dictionary = {
	# --- 主炮系列 (MAIN) ---
	"cannon_45mm": {
		"id": "cannon_45mm", "name": "45mm 速射机关炮", "slot": "MAIN", "min_rarity": 0,
		"weight": 1.8, "base_dmg": 58.0, "cooldown": 1.1, "ammo": 30, "cost": 45,
		"proj_speed": 720.0, "splash": 32.0, "burst": 3, "tags": ["artillery"],
		"desc": "三连发高速穿甲机炮，轻便省重，几乎不挤占SP装甲。"
	},
	"cannon_105mm": {
		"id": "cannon_105mm", "name": "105mm 皇家加农", "slot": "MAIN", "min_rarity": 0,
		"weight": 4.5, "base_dmg": 175.0, "cooldown": 2.0, "ammo": 18, "cost": 70,
		"proj_speed": 650.0, "splash": 85.0, "burst": 1, "tags": ["artillery"],
		"desc": "标准主力加农炮，命中后引发半径85m高爆冲击波。"
	},
	"cannon_cement": {
		"id": "cannon_cement", "name": "水泥弹发射器", "slot": "MAIN", "min_rarity": 1,
		"weight": 3.5, "base_dmg": 105.0, "cooldown": 2.3, "ammo": 16, "cost": 80,
		"proj_speed": 560.0, "splash": 110.0, "burst": 1, "effect": "cement", "tags": ["artillery", "bio"],
		"desc": "废土经典控场神器！命中使范围敌人减速60%并削减25点护甲。"
	},
	"cannon_195mm": {
		"id": "cannon_195mm", "name": "195mm 爆裂巨炮", "slot": "MAIN", "min_rarity": 2,
		"weight": 8.0, "base_dmg": 340.0, "cooldown": 3.0, "ammo": 12, "cost": 125,
		"proj_speed": 600.0, "splash": 125.0, "burst": 1, "effect": "cluster", "tags": ["artillery"],
		"desc": "重型火炮，爆炸时向四周分裂出 5 颗子母高爆弹二次轰炸。"
	},
	"cannon_205_peony": {
		"id": "cannon_205_peony", "name": "205mm 绯红牡丹", "slot": "MAIN", "min_rarity": 3,
		"weight": 10.5, "base_dmg": 520.0, "cooldown": 3.5, "ammo": 10, "cost": 175,
		"proj_speed": 680.0, "splash": 135.0, "burst": 1, "crit_bonus": 0.35, "tags": ["artillery"],
		"desc": "名炮【绯红牡丹】！极高暴击倍率(2.5x)，对半血以下目标必定暴击。"
	},
	"cannon_cosmic_laser": {
		"id": "cannon_cosmic_laser", "name": "SE-宇宙激光主炮", "slot": "MAIN", "min_rarity": 3,
		"weight": 7.0, "base_dmg": 300.0, "cooldown": 2.5, "ammo": 999, "cost": 165,
		"proj_speed": 1400.0, "splash": 45.0, "burst": 1, "pierce": 8, "effect": "laser", "tags": ["artillery", "bio"],
		"desc": "发射贯穿全屏的炽热激光束，无限弹药且无视敌方实弹护甲。"
	},
	"cannon_220_gaia": {
		"id": "cannon_220_gaia", "name": "220mm 盖亚之怒", "slot": "MAIN", "min_rarity": 4,
		"weight": 16.0, "base_dmg": 1050.0, "cooldown": 4.4, "ammo": 8, "cost": 260,
		"proj_speed": 620.0, "splash": 210.0, "burst": 1, "effect": "cluster", "tags": ["artillery", "juggernaut"],
		"desc": "【传奇红武】重达16吨的毁灭巨炮，一发轰平半个屏幕！"
	},

	# --- 副炮系列 (SUB) ---
	"mg_77mm": {
		"id": "mg_77mm", "name": "7.7mm 轻机枪", "slot": "SUB", "min_rarity": 0,
		"weight": 0.5, "base_dmg": 18.0, "cooldown": 0.20, "cost": 30,
		"proj_speed": 780.0, "range": 420.0, "tags": ["tycoon"],
		"desc": "仅重0.5吨的超轻机枪，自动点射最近敌人。"
	},
	"mg_vulcan": {
		"id": "mg_vulcan", "name": "火神六管加特林", "slot": "SUB", "min_rarity": 1,
		"weight": 2.2, "base_dmg": 26.0, "cooldown": 0.10, "cost": 65,
		"proj_speed": 820.0, "range": 440.0, "tags": ["artillery"],
		"desc": "每秒10发高密度金属风暴，压制贴脸机械虫群。"
	},
	"sub_flame": {
		"id": "sub_flame", "name": "地狱火焰喷射器", "slot": "SUB", "min_rarity": 1,
		"weight": 1.8, "base_dmg": 22.0, "cooldown": 0.16, "cost": 60,
		"proj_speed": 420.0, "range": 280.0, "pierce": 4, "effect": "burn", "tags": ["bio"],
		"desc": "扇形贯穿火海，为敌人叠加【灼烧】持续百分比掉血。"
	},
	"sub_acid": {
		"id": "sub_acid", "name": "强酸腐蚀喷雾器", "slot": "SUB", "min_rarity": 1,
		"weight": 1.6, "base_dmg": 26.0, "cooldown": 0.28, "cost": 70,
		"proj_speed": 520.0, "range": 380.0, "effect": "acid", "tags": ["bio"],
		"desc": "每次命中永久腐蚀目标 6 点护甲(可减为负数使全队对其增伤)！"
	},
	"sub_tesla": {
		"id": "sub_tesla", "name": "特斯拉连锁电弧", "slot": "SUB", "min_rarity": 2,
		"weight": 2.0, "base_dmg": 42.0, "cooldown": 0.38, "cost": 90,
		"proj_speed": 900.0, "range": 420.0, "chain": 4, "effect": "electric", "tags": ["bio", "missile"],
		"desc": "发射高压闪电在4个目标间弹跳，并克制护盾与水母类赏金首。"
	},
	"sub_shotgun": {
		"id": "sub_shotgun", "name": "废铁霰弹轰击炮", "slot": "SUB", "min_rarity": 1,
		"weight": 2.5, "base_dmg": 28.0, "cooldown": 0.65, "cost": 65,
		"proj_speed": 640.0, "range": 320.0, "pellets": 6, "tags": ["tycoon", "juggernaut"],
		"desc": "近距离一次轰出6颗废铁弹丸并击退敌人。"
	},

	"sub_ciws_phalanx": {
		"id": "sub_ciws_phalanx", "name": "密集阵CIWS近防炮", "slot": "SUB", "min_rarity": 1,
		"weight": 1.8, "base_dmg": 34.0, "cooldown": 0.16, "cost": 72,
		"range": 420.0, "pellets": 1, "pierce": 1, "proj_speed": 840.0,
		"effect": "ciws_intercept", "intercept_range": 195.0, "intercept_cd": 0.28,
		"tags": ["bullet_storm", "juggernaut"],
		"desc": "【迎击副炮】在射击敌怪同时，每0.28秒自动发射钨芯破片弹拦截195px内的敌方导弹并引发破片溅射！"
	},

	# --- S-E 特殊装备系列 (SE) ---
	"se_atm": {
		"id": "se_atm", "name": "ATM 追踪导弹箱", "slot": "SE", "min_rarity": 0,
		"weight": 2.0, "base_dmg": 72.0, "cooldown": 3.4, "cost": 55,
		"salvo": 4, "effect": "homing", "tags": ["missile"],
		"desc": "每轮齐射 4 枚自动追踪全场高威胁目标的穿甲导弹。"
	},
	"se_tornado": {
		"id": "se_tornado", "name": "龙卷风12联装火箭", "slot": "SE", "min_rarity": 2,
		"weight": 5.2, "base_dmg": 58.0, "cooldown": 5.2, "cost": 120,
		"salvo": 12, "effect": "homing", "tags": ["missile"],
		"desc": "一次性倾泻 12 枚追踪导弹洗地！配合【全弹发射】瞬间清屏。"
	},
	"se_aegis": {
		"id": "se_aegis", "name": "宙斯盾迎击激光网", "slot": "SE", "min_rarity": 1,
		"weight": 1.5, "base_dmg": 35.0, "cooldown": 0.42, "cost": 75,
		"effect": "intercept", "intercept_range": 240.0, "intercept_cd": 0.38, "tags": ["missile", "juggernaut"],
		"desc": "【独立迎击雷达】240px警戒圈内全自动高能激光点爆来袭敌弹，每次成功迎击回复 8 SP！"
	},
	"se_spike_ball": {
		"id": "se_spike_ball", "name": "旋转刺球撞角", "slot": "SE", "min_rarity": 1,
		"weight": 4.0, "base_dmg": 85.0, "cooldown": 0.5, "cost": 70,
		"effect": "orbit_ball", "tags": ["juggernaut", "lone_cub"],
		"desc": "两颗重型尖刺铁球环绕战车高速旋转，伤害享受战车总吨位加成！"
	},
	"se_drone": {
		"id": "se_drone", "name": "浮游维修无人机", "slot": "SE", "min_rarity": 2,
		"weight": 1.2, "base_dmg": 36.0, "cooldown": 0.45, "cost": 85,
		"effect": "repair_drone", "tags": ["lone_cub", "tycoon"],
		"desc": "环绕战车自动发射脉冲激光，并每秒为战车修复 18 SP。"
	},
	"se_sonic": {
		"id": "se_sonic", "name": "立体声震荡音波炮", "slot": "SE", "min_rarity": 2,
		"weight": 2.8, "base_dmg": 140.0, "cooldown": 4.0, "cost": 95,
		"effect": "sonic_wave", "tags": ["bio", "juggernaut"],
		"desc": "释放穿透一切护甲与潜沙状态的环形音波，震退并眩晕周围敌人。"
	},

	# --- 赏金首专属掉落红武 (BOSS DROPS) ---
	"boss_shark_torpedo": {
		"id": "boss_shark_torpedo", "name": "【赏金红武】沙鲨钻地鱼雷", "slot": "MAIN", "min_rarity": 4,
		"weight": 6.5, "base_dmg": 440.0, "cooldown": 2.4, "ammo": 20, "cost": 220,
		"proj_speed": 640.0, "splash": 140.0, "burst": 2, "effect": "acid", "tags": ["artillery", "missile"],
		"desc": "击败【沙漠之鲛】战利品！一次连射2枚钻地追踪重型鱼雷。"
	},
	"boss_yamato_cannon": {
		"id": "boss_yamato_cannon", "name": "【赏金红武】沙漠之舟·大和炮", "slot": "MAIN", "min_rarity": 4,
		"weight": 13.0, "base_dmg": 600.0, "cooldown": 3.4, "ammo": 15, "cost": 300,
		"proj_speed": 720.0, "splash": 160.0, "burst": 3, "effect": "cluster", "tags": ["artillery", "juggernaut"],
		"desc": "击败【沙漠之舟】战利品！恐怖的三联装300mm主炮齐射。"
	},

	# --- 六大隐藏合成【神话超武 (MYTHIC SUPER WEAPONS)】 ---
	"evo_red_wolf": {
		"id": "evo_red_wolf", "name": "★【超武】绯红双星·超重歼灭炮", "slot": "MAIN", "min_rarity": 5, "is_evo": true,
		"weight": 4.0, "base_dmg": 520.0, "cooldown": 0.75, "ammo": 999, "cost": 500,
		"proj_speed": 960.0, "splash": 150.0, "burst": 2, "crit_bonus": 1.0, "effect": "cluster", "tags": ["artillery", "lone_cub"],
		"desc": "【皇家加农/绯红牡丹 + 火神加特林 融合超武】无限弹药深红等离子速射双星炮，100%必定暴击并引发十字爆破！"
	},
	"evo_omega_railgun": {
		"id": "evo_omega_railgun", "name": "★【超武】Ω 泰坦天谴轨道炮", "slot": "MAIN", "min_rarity": 5, "is_evo": true,
		"weight": 4.2, "base_dmg": 480.0, "cooldown": 1.35, "ammo": 999, "cost": 500,
		"proj_speed": 1600.0, "splash": 80.0, "burst": 1, "pierce": 15, "effect": "omega_laser", "tags": ["artillery", "bio", "missile"],
		"desc": "【SE-宇宙激光炮 + 特斯拉电弧 融合超武】贯穿全屏的紫金雷霆轨道炮，命中后在全场10个敌人间弹跳高压天谴闪电！"
	},
	"evo_iron_curtain": {
		"id": "evo_iron_curtain", "name": "★【超武】末日铁幕·核子蜂群", "slot": "SE", "min_rarity": 5, "is_evo": true,
		"weight": 3.5, "base_dmg": 145.0, "cooldown": 2.2, "cost": 500,
		"salvo": 20, "effect": "homing", "tags": ["missile", "artillery"],
		"desc": "【ATM追踪导弹 + 龙卷风多管火箭 融合超武】全自动核子导弹母巢，每2.2秒倾泻20枚高爆钻地追踪飞弹洗地！"
	},
	"evo_plague_inferno": {
		"id": "evo_plague_inferno", "name": "★【超武】特斯拉的炼狱黑死病", "slot": "SUB", "min_rarity": 5, "is_evo": true,
		"weight": 1.8, "base_dmg": 95.0, "cooldown": 0.14, "cost": 500,
		"proj_speed": 620.0, "range": 440.0, "pierce": 6, "effect": "plague_fire", "tags": ["bio", "tycoon"],
		"desc": "【强酸喷雾器 + 地狱火焰喷射器 融合超武】喷射翠绿炼狱酸火，瞬间融化18点护甲并叠满灼烧，死后触发连环尸爆！"
	},
	"evo_aegis_star": {
		"id": "evo_aegis_star", "name": "★【超武】绝对领域·神盾粉碎星", "slot": "SE", "min_rarity": 5, "is_evo": true,
		"weight": 2.5, "base_dmg": 260.0, "cooldown": 0.25, "cost": 500,
		"effect": "evo_orbit_star", "tags": ["juggernaut", "lone_cub"],
		"desc": "【旋转刺球撞角 + 宙斯盾迎击网 融合超武】4颗电磁粉碎星环绕车身极速旋转，100%湮灭敌弹并附带20%最大SP碾压伤害与吸血！"
	},
	"evo_gaia_nuke": {
		"id": "evo_gaia_nuke", "name": "★【超武】盖亚毁灭者·石化核弹", "slot": "MAIN", "min_rarity": 5, "is_evo": true,
		"weight": 5.0, "base_dmg": 650.0, "cooldown": 2.1, "ammo": 999, "cost": 500,
		"proj_speed": 640.0, "splash": 220.0, "burst": 1, "effect": "gaia_nuke", "tags": ["artillery", "juggernaut", "bio"],
		"desc": "【水泥弹发射器 + 195mm爆裂炮/废铁霰弹炮 融合超武】发射无限弹药石化子母核弹，全场减速破甲并分裂8颗重磅子母弹！"
	}
}

# ============================================================================
# 3.5 隐藏超武合成配方表 (SUPER_EVOLUTIONS —— 类似《吸血鬼幸存者》超武合成)
# ============================================================================
const SUPER_EVOLUTIONS: Array = [
	{
		"result": "evo_red_wolf",
		"name": "★【超武】绯红双星·超重歼灭炮",
		"comp_a": ["cannon_105mm", "cannon_205_peony"],
		"comp_b": ["mg_vulcan"],
		"formula_text": "【105mm皇家加农 / 205mm绯红牡丹 (★4)】 + 【火神六管加特林 (★4)】"
	},
	{
		"result": "evo_omega_railgun",
		"name": "★【超武】Ω 泰坦天谴轨道炮",
		"comp_a": ["cannon_cosmic_laser"],
		"comp_b": ["sub_tesla"],
		"formula_text": "【SE-宇宙激光主炮 (★4)】 + 【特斯拉连锁电弧 (★4)】"
	},
	{
		"result": "evo_iron_curtain",
		"name": "★【超武】末日铁幕·核子蜂群",
		"comp_a": ["se_atm"],
		"comp_b": ["se_tornado"],
		"formula_text": "【ATM 追踪导弹箱 (★4)】 + 【龙卷风12联装火箭 (★4)】"
	},
	{
		"result": "evo_plague_inferno",
		"name": "★【超武】特斯拉的炼狱黑死病",
		"comp_a": ["sub_acid"],
		"comp_b": ["sub_flame"],
		"formula_text": "【强酸腐蚀喷雾器 (★4)】 + 【地狱火焰喷射器 (★4)】"
	},
	{
		"result": "evo_aegis_star",
		"name": "★【超武】绝对领域·神盾粉碎星",
		"comp_a": ["se_spike_ball"],
		"comp_b": ["se_aegis"],
		"formula_text": "【旋转刺球撞角 (★4)】 + 【宙斯盾迎击激光网 (★4)】"
	},
	{
		"result": "evo_gaia_nuke",
		"name": "★【超武】盖亚毁灭者·石化核弹",
		"comp_a": ["cannon_cement"],
		"comp_b": ["cannon_195mm"],
		"formula_text": "【水泥弹发射器 (★4)】 + 【195mm爆裂巨炮 (★4)】"
	}
]

# ============================================================================
# 4. 引擎库 (ENGINES —— 决定最大载重与SP池)
# ============================================================================
const ENGINES: Dictionary = {
	"eng_bulldog_v8": {
		"id": "eng_bulldog_v8", "name": "斗牛犬 V8 引擎", "rarity": 0,
		"max_weight": 18.0, "speed_Bonus": 0.05, "cost": 50,
		"desc": "最大载重 18.0 吨，战车移速 +5%。"
	},
	"eng_dozer": {
		"id": "eng_dozer", "name": "推土机重型柴油机", "rarity": 1,
		"max_weight": 28.0, "speed_Bonus": -0.05, "ram_bonus": 0.50, "cost": 90,
		"desc": "最大载重 28.0 吨，冲撞碾压伤害 +50%，移速 -5%。"
	},
	"eng_rwolf_turbo": {
		"id": "eng_rwolf_turbo", "name": "绯红特制涡轮引擎", "rarity": 2,
		"max_weight": 32.0, "speed_Bonus": 0.22, "main_dmg_bonus": 0.15, "cost": 140,
		"desc": "最大载重 32.0 吨，移速 +22%，主炮伤害 +15%。"
	},
	"eng_solomon_twin": {
		"id": "eng_solomon_twin", "name": "所罗门双子超重引擎", "rarity": 3,
		"max_weight": 46.0, "speed_Bonus": 0.08, "ram_bonus": 0.80, "cost": 210,
		"desc": "最大载重 46.0 吨！为巨炮与超厚SP装甲片提供澎湃动力。"
	},
	"eng_noah_fusion": {
		"id": "eng_noah_fusion", "name": "泰坦核融超载引擎", "rarity": 4,
		"max_weight": 62.0, "speed_Bonus": 0.25, "all_dmg_bonus": 0.35, "cost": 290,
		"desc": "【传奇】最大载重 62.0 吨，全伤害 +35%，移速 +25%！"
	}
}

# ============================================================================
# 5. C装置库 (C-UNITS —— 战车AI核心与主动战技)
# ============================================================================
const C_UNITS: Dictionary = {
	"cu_type66": {
		"id": "cu_type66", "name": "66式标准火控核心", "rarity": 0, "weight": 0.8, "cost": 45,
		"crit_bonus": 0.08, "all_out_cd": 11.0,
		"skill_id": "all_out", "skill_name": "全弹齐射", "skill_icon": "🚀",
		"desc": "暴击率 +8%。按 [Q/空格] 触发【全弹齐射】(全主炮与S-E无消耗齐射，冷却11秒)。"
	},
	"cu_solomon2": {
		"id": "cu_solomon2", "name": "所罗门 2 型 (突击核心)", "rarity": 2, "weight": 1.5, "cost": 130,
		"crit_bonus": 0.12, "all_out_cd": 7.5, "se_dmg_bonus": 0.30,
		"skill_id": "god_barrage", "skill_name": "神之突击齐射", "skill_icon": "🔥",
		"desc": "S-E伤害+30%。【神之突击齐射】冷却7.5秒且自动触发，齐射同时赋予3秒【氮气极速突进】！"
	},
	"cu_type99": {
		"id": "cu_type99", "name": "99式神话火控", "rarity": 3, "weight": 1.6, "cost": 165,
		"crit_bonus": 0.25, "all_out_cd": 10.0, "double_shot_chance": 0.30,
		"skill_id": "overclock", "skill_name": "超频双发过载", "skill_icon": "⚡",
		"desc": "暴击+25%，主炮30%免费二连射！按[Q/空格]开启4.5秒【超频双发过载】(全武器100%双发+攻速35%)！"
	},
	"cu_mirage": {
		"id": "cu_mirage", "name": "幻影全息系统", "rarity": 2, "weight": 1.0, "cost": 120,
		"dodge_bonus": 0.25, "all_out_cd": 9.5, "decoy_blast": true,
		"skill_id": "smoke_decoy", "skill_name": "热烟幕与诱饵", "skill_icon": "💨",
		"desc": "闪避+25%。按[Q/空格]释放【热烟幕与全息诱饵】，获得2.8秒100%绝对闪避并在原地引爆电磁残影！"
	},
	"cu_valkyrie": {
		"id": "cu_valkyrie", "name": "瓦尔基里自律战斗AI", "rarity": 3, "weight": 1.8, "cost": 160,
		"crit_bonus": 0.15, "all_out_cd": 9.0, "auto_turret_wreck": true,
		"skill_id": "valkyrie_sweep", "skill_name": "女武神天基犁地", "skill_icon": "🛰️",
		"desc": "下车可【人车双打】！按[Q/空格]呼叫【女武神天基犁地】，3道轨道死光沿炮塔方向交叉汽化敌群！"
	},
	"cu_interceptor_ai": {
		"id": "cu_interceptor_ai", "name": "神之右手迎击火控", "rarity": 3, "weight": 1.4, "cost": 168,
		"crit_bonus": 0.16, "dodge_bonus": 0.10, "all_out_cd": 8.5,
		"interception_range": 220.0, "interception_cd": 0.35,
		"skill_id": "iron_dome", "skill_name": "铁穹电磁力场", "skill_icon": "🛡️",
		"desc": "自带220px全自动激光迎击雷达！按[Q/空格]展开3.5秒【铁穹电磁力场】，蒸发320px内一切敌弹并电击震退近身怪！"
	}
}

# ============================================================================
# 5.5 战车战术改装挂件与诺亚禁忌诅咒件池 (TANK_MODS —— 不占武器孔，可无限叠加)
# ============================================================================
const TANK_MODS: Dictionary = {
	"mod_autoloader": {
		"id": "mod_autoloader", "name": "液压自动装填机", "rarity": 1, "cost": 45, "is_cursed": false,
		"icon": "⚙️", "tags": ["artillery", "bullet_storm"],
		"mods": {"reload_speed_pct": 0.08, "flat_max_weight": 0.8},
		"desc": "全武器装填速度 +8%，引擎最大载重 +0.8t。"
	},
	"mod_reactive_armor": {
		"id": "mod_reactive_armor", "name": "爆破反应装甲片", "rarity": 1, "cost": 48, "is_cursed": false,
		"icon": "🛡️", "tags": ["juggernaut"],
		"mods": {"flat_sp_bonus": 55.0, "sp_per_ton_pct": 0.08},
		"desc": "战车最大装甲 +55 SP，每吨剩余载重转化 SP 效率 +8%。"
	},
	"mod_ap_core": {
		"id": "mod_ap_core", "name": "钨合金穿甲弹芯", "rarity": 2, "cost": 62, "is_cursed": false,
		"icon": "💥", "tags": ["artillery"],
		"mods": {"main_dmg_pct": 0.14, "boss_dmg_pct": 0.10},
		"desc": "主炮伤害 +14%，对赏金首与精英怪伤害 +10%。"
	},
	"mod_bullet_chain": {
		"id": "mod_bullet_chain", "name": "双联供弹链箱", "rarity": 1, "cost": 50, "is_cursed": false,
		"icon": "🔫", "tags": ["bullet_storm", "missile"],
		"mods": {"sub_dmg_pct": 0.14, "reload_speed_pct": 0.05},
		"desc": "副炮与S-E伤害 +14%，全武器装填速度 +5%。"
	},
	"mod_bio_catalyst": {
		"id": "mod_bio_catalyst", "name": "高浓强酸催化罐", "rarity": 2, "cost": 60, "is_cursed": false,
		"icon": "🧪", "tags": ["bio"],
		"mods": {"elemental_dmg_pct": 0.18, "flat_sp_regen": 4.0},
		"desc": "酸火雷元素伤害 +18%，战车每秒自动修复 +4 SP。"
	},
	"mod_bounty_scanner": {
		"id": "mod_bounty_scanner", "name": "猎人加密悬赏仪", "rarity": 1, "cost": 42, "is_cursed": false,
		"icon": "📡", "tags": ["tycoon"],
		"mods": {"gold_gain_pct": 0.15, "crit_chance": 0.05},
		"desc": "赏金获取 +15%，暴击率 +5%。"
	},
	"mod_nano_welder": {
		"id": "mod_nano_welder", "name": "纳米自修复涂层", "rarity": 2, "cost": 58, "is_cursed": false,
		"icon": "🔧", "tags": ["lone_cub", "juggernaut"],
		"mods": {"flat_sp_regen": 8.0, "sp_regen_pct": 0.01},
		"desc": "战车每秒自动回复 +8 SP 及 1% 最大 SP。"
	},
	"mod_gyro_stabilizer": {
		"id": "mod_gyro_stabilizer", "name": "陀螺仪火控稳定器", "rarity": 2, "cost": 65, "is_cursed": false,
		"icon": "🎯", "tags": ["lone_cub", "bullet_storm"],
		"mods": {"crit_chance": 0.09, "dodge": 0.06},
		"desc": "暴击率 +9%，战车闪避率 +6%。"
	},
	"mod_titanium_chassis": {
		"id": "mod_titanium_chassis", "name": "钛合金轻量化车架", "rarity": 2, "cost": 60, "is_cursed": false,
		"icon": "🚜", "tags": ["juggernaut", "missile"],
		"mods": {"flat_max_weight": 3.2, "move_speed_pct": 0.08},
		"desc": "引擎最大载重 +3.2t，战车移速 +8%。"
	},
	"mod_ciws_booster": {
		"id": "mod_ciws_booster", "name": "相控阵迎击增幅器", "rarity": 2, "cost": 55, "is_cursed": false,
		"icon": "🛡️", "tags": ["missile", "juggernaut"],
		"mods": {"intercept_cd_mult": 0.25, "dodge": 0.08},
		"desc": "迎击雷达与近防炮冷却加快 25%，战车闪避率 +8%。"
	},
	"curse_overloaded_core": {
		"id": "curse_overloaded_core", "name": "☣️【诅咒】过载核融炉", "rarity": 3, "cost": 75, "is_cursed": true,
		"icon": "☢️", "tags": ["artillery", "missile"],
		"mods": {"main_dmg_pct": 0.42, "sub_dmg_pct": 0.35, "flat_sp_bonus": -90.0},
		"desc": "【诺亚禁忌改装】主炮伤害 +42%，副炮/SE伤害 +35%；代价：战车最大装甲 -90 SP！"
	},
	"curse_depleted_uranium": {
		"id": "curse_depleted_uranium", "name": "☣️【诅咒】贫铀超重装甲", "rarity": 3, "cost": 72, "is_cursed": true,
		"icon": "🧱", "tags": ["juggernaut"],
		"mods": {"flat_sp_bonus": 180.0, "sp_per_ton_pct": 0.30, "move_speed_pct": -0.15},
		"desc": "【诺亚禁忌改装】最大装甲 +180 SP，每吨转化SP +30%；代价：战车移速 -15%！"
	},
	"curse_berserk_fcs": {
		"id": "curse_berserk_fcs", "name": "☣️【诅咒】狂战士神经火控", "rarity": 3, "cost": 78, "is_cursed": true,
		"icon": "👁️", "tags": ["bullet_storm", "artillery"],
		"mods": {"crit_chance": 0.22, "reload_speed_pct": 0.25, "dodge": -0.15},
		"desc": "【诺亚禁忌改装】暴击率 +22%，装填速度 +25%；代价：战车闪避率 -15%！"
	},
	"curse_blood_engine": {
		"id": "curse_blood_engine", "name": "☣️【诅咒】嗜血内燃机", "rarity": 3, "cost": 70, "is_cursed": true,
		"icon": "🩸", "tags": ["lone_cub"],
		"mods": {"move_speed_pct": 0.28, "boss_dmg_pct": 0.35, "flat_sp_regen": -6.0},
		"desc": "【诺亚禁忌改装】战车极速 +28%，对首领伤害 +35%；代价：每秒流失 6 SP！"
	},
	"curse_greed_protocol": {
		"id": "curse_greed_protocol", "name": "☣️【诅咒】黑市贪婪协议", "rarity": 3, "cost": 65, "is_cursed": true,
		"icon": "💰", "tags": ["tycoon"],
		"mods": {"gold_gain_pct": 0.50, "shop_price_pct": 0.15},
		"desc": "【诺亚禁忌改装】战斗赏金获取 +50%；代价：商店军火价格上涨 15%！"
	},
	"curse_plague_reactor": {
		"id": "curse_plague_reactor", "name": "☣️【诅咒】瘟疫同位素核心", "rarity": 3, "cost": 76, "is_cursed": true,
		"icon": "☣️", "tags": ["bio"],
		"mods": {"elemental_dmg_pct": 0.50, "flat_max_weight": -2.0},
		"desc": "【诺亚禁忌改装】酸火雷元素伤害 +50%；代价：引擎最大载重 -2.0t！"
	}
}

# ============================================================================
# 6. 六大流派羁绊 (SYNERGIES)
# ============================================================================
const SYNERGIES: Dictionary = {
	"artillery": {
		"name": "重炮轰鸣", "color": Color(1.0, 0.45, 0.25),
		"desc": "(2)主炮重量-20%  (4)主炮伤害+35%且爆炸范围扩大  (6)主炮开火50%概率二连射"
	},
	"missile": {
		"name": "导弹暴雨", "color": Color(0.35, 0.78, 1.0),
		"desc": "(2)S-E齐射数量+1  (4)S-E冷却缩短25%  (6)全弹发射时召唤轨道激光轰炸"
	},
	"juggernaut": {
		"name": "钢铁碾压", "color": Color(0.85, 0.72, 0.32),
		"desc": "(2)每吨剩余载重+30 SP  (4)碰撞反弹100%吨位荆棘伤害  (6)冲撞伤害附带当前SP 15%震荡波"
	},
	"bio": {
		"name": "生化酸火", "color": Color(0.45, 0.95, 0.38),
		"desc": "(2)元素异常伤害+30%  (4)腐蚀与灼烧效果翻倍  (6)对异常状态目标暴击率+30%"
	},
	"lone_cub": {
		"name": "人车双绝", "color": Color(0.95, 0.45, 0.80),
		"desc": "(2)步兵与无人机攻速+35%  (4)每秒额外修复25 SP  (6)人车全伤害+45%"
	},
	"tycoon": {
		"name": "废铁大亨", "color": Color(1.0, 0.85, 0.20),
		"desc": "(2)每波赏金G利息+15%  (4)拾取废铁经验与金币价值+30%  (6)每持有100G全伤害+8%"
	}
}

# ============================================================================
# 7. 废土机械兽生态：常规小怪、远程特种怪、战术支援怪与四大重装精英 (ENEMIES)
# ============================================================================
const ENEMIES: Dictionary = {
	# --- 0. 废土变异生化兽 (LOW-SPEED MELEE MUTATED BEASTS) ---
	"mutant_sludge": {
		"id": "mutant_sludge", "name": "辐射变异软泥怪", "hp": 85.0, "speed": 62.0, "dmg": 18.0,
		"armor": 4.0, "radius": 20.0, "xp": 1, "gold": 1, "color": Color(0.40, 0.88, 0.22),
		"behavior": "melee"
	},
	"rad_beetle": {
		"id": "rad_beetle", "name": "辐射重甲巨甲虫", "hp": 155.0, "speed": 78.0, "dmg": 26.0,
		"armor": 28.0, "radius": 24.0, "xp": 2, "gold": 2, "color": Color(0.55, 0.40, 0.25),
		"behavior": "melee"
	},
	"sand_worm_larva": {
		"id": "sand_worm_larva", "name": "废土沙虫幼体", "hp": 110.0, "speed": 84.0, "dmg": 22.0,
		"armor": 10.0, "radius": 22.0, "xp": 1, "gold": 2, "color": Color(0.85, 0.65, 0.40),
		"behavior": "melee"
	},
	"flesh_juggernaut": {
		"id": "flesh_juggernaut", "name": "生化变异肉山", "hp": 380.0, "speed": 55.0, "dmg": 40.0,
		"armor": 20.0, "radius": 32.0, "xp": 3, "gold": 4, "color": Color(0.68, 0.22, 0.38),
		"behavior": "melee"
	},
	"corpse_crawler": {
		"id": "corpse_crawler", "name": "腐骨爬行尸怪", "hp": 95.0, "speed": 72.0, "dmg": 20.0,
		"armor": 6.0, "radius": 19.0, "xp": 1, "gold": 1, "color": Color(0.50, 0.48, 0.45),
		"behavior": "melee"
	},

	# --- 1. 近战突袭类 ---
	"bio_ant": {
		"id": "bio_ant", "name": "钳甲机械蚁", "hp": 46.0, "speed": 145.0, "dmg": 18.0,
		"armor": 6.0, "radius": 19.0, "xp": 1, "gold": 1, "color": Color(0.75, 0.35, 0.20),
		"behavior": "melee"
	},
	"bionic_hound": {
		"id": "bionic_hound", "name": "狂暴生化猎犬", "hp": 65.0, "speed": 175.0, "dmg": 24.0,
		"armor": 10.0, "radius": 21.0, "xp": 1, "gold": 1, "color": Color(0.88, 0.45, 0.25),
		"behavior": "leap_hound"
	},

	# --- 2. 自爆特攻类 ---
	"kamikaze_wheel": {
		"id": "kamikaze_wheel", "name": "自爆滚雷车", "hp": 38.0, "speed": 225.0, "dmg": 46.0,
		"armor": 0.0, "radius": 19.0, "xp": 1, "gold": 2, "color": Color(0.95, 0.25, 0.15),
		"behavior": "suicide"
	},
	"gas_walker": {
		"id": "gas_walker", "name": "毒气自爆铁桶", "hp": 96.0, "speed": 122.0, "dmg": 38.0,
		"armor": 20.0, "radius": 23.0, "xp": 2, "gold": 2, "color": Color(0.55, 0.88, 0.22),
		"behavior": "toxic_suicide"
	},

	# --- 3. 远程弹幕、狙击与曲射迫击炮类 ---
	"sand_turret": {
		"id": "sand_turret", "name": "沙漠机枪炮台", "hp": 82.0, "speed": 52.0, "dmg": 20.0,
		"armor": 16.0, "radius": 24.0, "xp": 1, "gold": 2, "color": Color(0.65, 0.60, 0.38),
		"behavior": "shooter"
	},
	"acid_snail": {
		"id": "acid_snail", "name": "辐射酸液蜗牛", "hp": 135.0, "speed": 85.0, "dmg": 26.0,
		"armor": 35.0, "radius": 26.0, "xp": 2, "gold": 2, "color": Color(0.42, 0.82, 0.28),
		"behavior": "shooter"
	},
	"sniper_cannon": {
		"id": "sniper_cannon", "name": "远程狙击自行炮", "hp": 105.0, "speed": 70.0, "dmg": 48.0,
		"armor": 14.0, "radius": 25.0, "xp": 2, "gold": 3, "color": Color(0.92, 0.28, 0.42),
		"behavior": "sniper"
	},
	"mortar_crab": {
		"id": "mortar_crab", "name": "迫击炮机械蟹", "hp": 155.0, "speed": 76.0, "dmg": 44.0,
		"armor": 40.0, "radius": 27.0, "xp": 2, "gold": 3, "color": Color(0.85, 0.52, 0.20),
		"behavior": "mortar"
	},

	# --- 4. 护盾防御、战地医疗与EMP控制类 ---
	"shield_mecha": {
		"id": "shield_mecha", "name": "电磁护盾卫士", "hp": 145.0, "shield": 120.0, "speed": 100.0, "dmg": 26.0,
		"armor": 32.0, "radius": 27.0, "xp": 2, "gold": 3, "color": Color(0.28, 0.68, 0.95),
		"behavior": "shield_guard"
	},
	"repair_bot": {
		"id": "repair_bot", "name": "机械战地维修蜂", "hp": 90.0, "speed": 155.0, "dmg": 15.0,
		"armor": 12.0, "radius": 21.0, "xp": 2, "gold": 3, "color": Color(0.30, 0.95, 0.55),
		"behavior": "healer"
	},
	"emp_spider": {
		"id": "emp_spider", "name": "磁暴捕猎蛛", "hp": 112.0, "speed": 132.0, "dmg": 24.0,
		"armor": 18.0, "radius": 23.0, "xp": 2, "gold": 3, "color": Color(0.55, 0.42, 0.95),
		"behavior": "emp_shooter"
	},

	# --- 5. 四大区域重装精英怪 (ELITE MINI-BOSSES) ---
	"auto_tank": {
		"id": "auto_tank", "name": "⚡【精英】自律杀戮重坦", "is_elite": true,
		"hp": 520.0, "speed": 112.0, "dmg": 38.0, "armor": 48.0, "radius": 36.0,
		"xp": 5, "gold": 12, "color": Color(0.50, 0.58, 0.68),
		"behavior": "elite_tank"
	},
	"elite_flame_juggernaut": {
		"id": "elite_flame_juggernaut", "name": "⚡【精英】炼狱喷火装甲车", "is_elite": true,
		"hp": 680.0, "speed": 150.0, "dmg": 44.0, "armor": 44.0, "radius": 38.0,
		"xp": 6, "gold": 14, "color": Color(0.95, 0.38, 0.15),
		"behavior": "elite_flamer"
	},
	"elite_missile_mammoth": {
		"id": "elite_missile_mammoth", "name": "⚡【精英】双联装导弹巨兽", "is_elite": true,
		"hp": 860.0, "speed": 90.0, "dmg": 52.0, "armor": 58.0, "radius": 42.0,
		"xp": 7, "gold": 16, "color": Color(0.68, 0.55, 0.32),
		"behavior": "elite_mortar"
	},
	"elite_cyber_executioner": {
		"id": "elite_cyber_executioner", "name": "⚡【精英】天穹量子处决者", "is_elite": true,
		"hp": 1080.0, "speed": 142.0, "dmg": 58.0, "armor": 54.0, "radius": 40.0,
		"xp": 8, "gold": 20, "color": Color(0.85, 0.25, 0.85),
		"behavior": "elite_blinker"
	}
}

# ============================================================================
# 8. 十大「赏金首 (WANTED BOSSES)」设定
# ============================================================================
const WANTED_BOSSES: Array = [
	{
		"id": "boss_killdozer",
		"name": "杀人推土机 (Killdozer)",
		"stars": 1, "min_wave": 2, "bounty": 180,
		"hp": 1650.0, "armor": 42.0, "speed": 160.0, "dmg": 48.0, "radius": 52.0,
		"color": Color(0.92, 0.72, 0.12),
		"mechanic": "charge_plow",
		"reward_weapon": "cannon_195mm",
		"desc": "★☆☆☆☆ | 正面合金铲刀减免65%实弹伤害，周期发起红线狂暴冲锋！"
	},
	{
		"id": "boss_jelly",
		"name": "加农水母 (Cannon Jelly)",
		"stars": 1, "min_wave": 3, "bounty": 240,
		"hp": 2100.0, "armor": 24.0, "speed": 115.0, "dmg": 38.0, "radius": 54.0,
		"color": Color(0.28, 0.78, 0.95),
		"mechanic": "bullet_ring",
		"reward_weapon": "sub_tesla",
		"desc": "★☆☆☆☆ | 发射360°环形激光弹幕并召唤自爆小水母，弱电击属性。"
	},
	{
		"id": "boss_sand_shark",
		"name": "深沙巨鲛·地龙 (Sand Maw)",
		"stars": 2, "min_wave": 5, "bounty": 380,
		"hp": 3600.0, "armor": 48.0, "speed": 200.0, "dmg": 58.0, "radius": 60.0,
		"color": Color(0.32, 0.48, 0.72),
		"mechanic": "burrow_shark",
		"reward_weapon": "boss_shark_torpedo",
		"desc": "★★☆☆☆ | 潜入沙底高速突袭(潜沙时减伤70%)，跃出地面发射扇形鱼雷！"
	},
	{
		"id": "boss_skunks",
		"name": "狂飙沙盗首领·斯卡普 (Scarp)",
		"stars": 2, "min_wave": 7, "bounty": 480,
		"hp": 4600.0, "armor": 38.0, "speed": 245.0, "dmg": 54.0, "radius": 50.0,
		"color": Color(0.88, 0.35, 0.18),
		"mechanic": "flame_circle",
		"reward_weapon": "se_tornado",
		"desc": "★★☆☆☆ | 驾驶高速喷火战车围绕玩家画圈冲刺，并召唤护卫飞车。"
	},
	{
		"id": "boss_centipede",
		"name": "百足装甲列车 (Centipede Express)",
		"stars": 3, "min_wave": 9, "bounty": 680,
		"hp": 6000.0, "armor": 58.0, "speed": 170.0, "dmg": 65.0, "radius": 58.0,
		"color": Color(0.55, 0.65, 0.35),
		"mechanic": "multi_segment",
		"reward_weapon": "cannon_205_peony",
		"desc": "★★★☆☆ | 搭载多节武装车厢！每打掉25%血量炸毁一节车厢并直接爆出宝箱！"
	},
	{
		"id": "boss_gomez",
		"name": "荒原劫掠王·巴洛克 (Baroque)",
		"stars": 3, "min_wave": 11, "bounty": 850,
		"hp": 7600.0, "armor": 68.0, "speed": 155.0, "dmg": 78.0, "radius": 58.0,
		"color": Color(0.45, 0.32, 0.25),
		"mechanic": "emp_stealth",
		"reward_weapon": "cannon_cosmic_laser",
		"desc": "★★★☆☆ | 宿命死敌！投掷烟雾隐身，发射电磁网减速并蓄力轰击。"
	},
	{
		"id": "boss_chimera",
		"name": "生化融合兽·奇美拉 (Bio-Chimera)",
		"stars": 4, "min_wave": 13, "bounty": 1100,
		"hp": 10200.0, "armor": 54.0, "speed": 135.0, "dmg": 86.0, "radius": 64.0,
		"color": Color(0.62, 0.22, 0.68),
		"mechanic": "regen_acid",
		"reward_weapon": "cannon_220_gaia",
		"desc": "★★★★☆ | 拥有恐怖生命再生，需用火焰/酸液或高爆发主炮压制回血！"
	},
	{
		"id": "boss_desert_boat",
		"name": "陆地战舰·沙漠之舟 (Desert Boat)",
		"stars": 4, "min_wave": 15, "bounty": 1500,
		"hp": 14000.0, "armor": 82.0, "speed": 100.0, "dmg": 96.0, "radius": 86.0,
		"color": Color(0.65, 0.58, 0.45),
		"mechanic": "battleship_parts",
		"reward_weapon": "boss_yamato_cannon",
		"desc": "★★★★☆ | 巨型移动陆地要塞！拥有【左副炮塔】【右导弹舱】【中央主炮】3个独立可破坏部位！"
	},
	{
		"id": "boss_bighemoth",
		"name": "钢铁暴君·重装帕鲁 (Bighemoth)",
		"stars": 5, "min_wave": 17, "bounty": 2200,
		"hp": 18500.0, "armor": 92.0, "speed": 125.0, "dmg": 108.0, "radius": 76.0,
		"color": Color(0.78, 0.25, 0.25),
		"mechanic": "magnet_laser",
		"reward_weapon": "cannon_220_gaia",
		"desc": "★★★★★ | 吞噬无数战车残骸的钢铁巨兽，释放引力场与散射激光。"
	},
	{
		"id": "boss_noah",
		"name": "终焉主脑·原核矩阵 (Master OMEGA CORE)",
		"stars": 5, "min_wave": 20, "bounty": 5000,
		"hp": 26000.0, "armor": 100.0, "speed": 120.0, "dmg": 120.0, "radius": 88.0,
		"color": Color(0.95, 0.20, 0.45),
		"mechanic": "noah_core",
		"reward_weapon": "boss_yamato_cannon",
		"desc": "★★★★★ | 第20波终局主脑！三阶段形态切换：矩阵护盾 → 机械召唤 → 量子十字激光！"
	}
]

# ============================================================================
# 9. 猎人升级天赋池 (LEVEL_PERKS —— 土豆兄弟式 1~4 阶属性强化基数)
# ============================================================================
const LEVEL_PERKS: Array = [
	{"id": "main_dmg", "name": "炮术专精", "desc": "主炮伤害 +%d%%", "stat": "main_dmg_pct", "val": 0.08, "is_pct": true},
	{"id": "sub_se_dmg", "name": "弹幕协同", "desc": "副炮与 S-E 伤害 +%d%%", "stat": "sub_dmg_pct", "val": 0.08, "is_pct": true},
	{"id": "max_weight", "name": "底盘加固弹簧", "desc": "引擎最大载重 +%d%% (转化更多SP)", "stat": "max_weight_pct", "val": 0.06, "is_pct": true},
	{"id": "reload_spd", "name": "自动装填液压", "desc": "全武器攻速与装填速度 +%d%%", "stat": "reload_speed_pct", "val": 0.06, "is_pct": true},
	{"id": "crit_chance", "name": "精密鹰眼雷达", "desc": "暴击率 +%d%%", "stat": "crit_chance", "val": 0.04, "is_pct": true},
	{"id": "sp_regen", "name": "纳米板金焊枪", "desc": "每秒额外恢复 +%d 点战车 SP", "stat": "flat_sp_regen", "val": 4.0, "is_pct": false},
	{"id": "move_ram", "name": "氮气冲角改装", "desc": "战车移速 +%d%%，冲撞伤害提升", "stat": "move_speed_pct", "val": 0.05, "is_pct": true},
	{"id": "bounty_magnet", "name": "高倍金属探头", "desc": "拾取范围扩大，赏金获取 +%d%%", "stat": "gold_gain_pct", "val": 0.07, "is_pct": true}
]

# ============================================================================
# 10. 局外永久功能解锁 (META_FEATURES —— 废铁镇基建工程)
# ============================================================================
const META_FEATURES: Array = [
	{
		"id": "shop_lock",
		"name": "🔒 军火库商品锁定器",
		"cost": 100,
		"desc": "在多拉姆商店每个商品旁新增【锁定】按钮，可将心仪的红武或引擎跨波次保留，不怕当前赏金不够！"
	},
	{
		"id": "shop_5th_slot",
		"name": "🛒 多拉姆5号军火展柜",
		"cost": 180,
		"desc": "多拉姆军火商店每次刷新的商品数量从 4 格永久扩充至 5 格，更容易凑齐同名升星与羁绊！"
	},
	{
		"id": "vending_unlock",
		"name": "🥤 自动售货机特权卡",
		"cost": 80,
		"desc": "在车库整备界面解锁【废土自动售货机】，可投币畅饮冷饮永久加SP，并有35%概率触发“再来一瓶”大奖！"
	},
	{
		"id": "detector_unlock",
		"name": "📡 高敏金属探测器执照",
		"cost": 120,
		"desc": "在车库解锁【金属探测器沙漠挖掘】功能，且每波废土战场刷出埋藏金属宝箱的概率翻倍！"
	},
	{
		"id": "black_market_wanted",
		"name": "🎯 猎人黑市悬赏终端",
		"cost": 200,
		"desc": "所有赏金首(Wanted)击杀悬赏金永久 +25%！且在猎人办事处支持主动切换/重刷通缉令！"
	},
	{
		"id": "mince_defib_lv2",
		"name": "⚡ 特斯拉轨道除颤卫星",
		"cost": 320,
		"desc": "除车库复活外，每局额外获得 1 次【战场原地满血电击复苏】：步兵HP归零时降下雷霆满血复活并麻痹全场！"
	}
]

# ============================================================================
# 11. 局外永久数值强化科技树 (META_UPGRADES —— 特斯拉重工改造所)
# ============================================================================
const META_UPGRADES: Array = [
	{
		"id": "meta_weight",
		"name": "⚙️ 超导引擎曲轴",
		"max_lv": 10,
		"base_cost": 45,
		"cost_step": 30,
		"desc_per_lv": "引擎最大载重永久 +5% / 级 (直接转化为更多SP装甲片)"
	},
	{
		"id": "meta_sp",
		"name": "🛡️ 复合钛合金装甲板",
		"max_lv": 10,
		"base_cost": 40,
		"cost_step": 25,
		"desc_per_lv": "战车基础装甲片永久 +25 SP / 级，步兵HP +15 / 级"
	},
	{
		"id": "meta_dmg",
		"name": "💥 大口径膛线研磨",
		"max_lv": 10,
		"base_cost": 50,
		"cost_step": 35,
		"desc_per_lv": "主炮、副炮与 S-E 全武器基础伤害永久 +6% / 级"
	},
	{
		"id": "meta_start_gold",
		"name": "💰 猎人协会预支津贴",
		"max_lv": 8,
		"base_cost": 40,
		"cost_step": 30,
		"desc_per_lv": "每局开局初始携带赏金永久 +20 G / 级"
	},
	{
		"id": "meta_reload",
		"name": "🔄 液压自动装填机",
		"max_lv": 8,
		"base_cost": 55,
		"cost_step": 35,
		"desc_per_lv": "全武器装填与射速永久 +4% / 级，主炮弹药上限 +15% / 级"
	},
	{
		"id": "meta_crit_dodge",
		"name": "💻 天穹量子火控校准",
		"max_lv": 6,
		"base_cost": 65,
		"cost_step": 45,
		"desc_per_lv": "初始暴击率永久 +2.5% / 级，战车闪避率永久 +2% / 级"
	},
	{
		"id": "meta_repair",
		"name": "🔧 机械师纳米焊枪",
		"max_lv": 6,
		"base_cost": 50,
		"cost_step": 40,
		"desc_per_lv": "战场每秒自动修复 +3 SP / 级，大破下车抢修速度 +12% / 级"
	},
	{
		"id": "meta_magnet_gold",
		"name": "🧲 废土传奇声望",
		"max_lv": 5,
		"base_cost": 60,
		"cost_step": 50,
		"desc_per_lv": "拾取磁吸范围 +20% / 级，局内赏金G与经验获取 +8% / 级"
	}
]

# ============================================================================
# 12. 五大废土战区地图设定 (MAPS —— 通关上一张解锁下一张，分配专属Boss与生态)
# ============================================================================
const MAPS: Array = [
	{
		"id": "map_1",
		"index": 0,
		"name": "第1章：红石哨所荒野·巨炮峡谷",
		"waves": 10,
		"hp_mult": 1.0,
		"dmg_mult": 1.0,
		"chip_mult": 1.0,
		"enemy_pool": ["mutant_sludge", "mutant_sludge", "corpse_crawler", "bio_ant", "rad_beetle", "sand_turret"],
		"elite_pool": ["auto_tank"],
		"regional_boss_id": "boss_killdozer",
		"final_boss_id": "boss_jelly",
		"bg_color": Color(0.22, 0.18, 0.13),
		"grid_color": Color(0.27, 0.22, 0.16),
		"border_color": Color(0.85, 0.52, 0.18),
		"desc": "【荒野起点】小怪：辐射软泥怪/腐骨尸怪/辐射甲虫/沙漠机枪塔 | 精英：杀戮重坦 | 赏金首：【杀人推土机】&【加农水母】",
		"unlock_ach_id": "",
		"unlock_ach_desc": "初始已解锁"
	},
	{
		"id": "map_2",
		"index": 1,
		"name": "第2章：死亡大沙漠·流沙遗迹",
		"waves": 10,
		"hp_mult": 1.65,
		"dmg_mult": 1.35,
		"chip_mult": 1.40,
		"enemy_pool": ["sand_worm_larva", "sand_worm_larva", "rad_beetle", "mutant_sludge", "bionic_hound", "acid_snail"],
		"elite_pool": ["elite_flame_juggernaut", "auto_tank"],
		"regional_boss_id": "boss_sand_shark",
		"final_boss_id": "boss_skunks",
		"bg_color": Color(0.28, 0.19, 0.11),
		"grid_color": Color(0.35, 0.24, 0.14),
		"border_color": Color(0.95, 0.65, 0.20),
		"desc": "【炽热沙海】小怪：沙虫幼体/辐射重甲虫/辐射软泥/狂暴猎犬/酸液蜗牛 | 精英：喷火装甲车 | 赏金首：【深沙巨鲛】&【狂飙斯卡普】",
		"unlock_ach_id": "ach_clear_map_1",
		"unlock_ach_desc": "达成成就【荒原先遣队】通关第1章解锁"
	},
	{
		"id": "map_3",
		"index": 2,
		"name": "第3章：铁道废墟·百足峡谷",
		"waves": 10,
		"hp_mult": 2.50,
		"dmg_mult": 1.75,
		"chip_mult": 1.85,
		"enemy_pool": ["flesh_juggernaut", "corpse_crawler", "rad_beetle", "bio_ant", "shield_mecha", "sniper_cannon"],
		"elite_pool": ["elite_missile_mammoth", "auto_tank"],
		"regional_boss_id": "boss_centipede",
		"final_boss_id": "boss_gomez",
		"bg_color": Color(0.15, 0.16, 0.18),
		"grid_color": Color(0.21, 0.22, 0.25),
		"border_color": Color(0.50, 0.75, 0.92),
		"desc": "【工业废墟】小怪：变异肉山/腐骨尸怪/辐射重甲虫/护盾卫士/狙击自行炮 | 精英：导弹巨兽 | 赏金首：【百足列车】&【劫掠王巴洛克】",
		"unlock_ach_id": "ach_clear_map_2",
		"unlock_ach_desc": "达成成就【沙海征服者】通关第2章解锁"
	},
	{
		"id": "map_4",
		"index": 3,
		"name": "第4章：恶魔跨海大桥·枯竭海床",
		"waves": 10,
		"hp_mult": 3.80,
		"dmg_mult": 2.25,
		"chip_mult": 2.40,
		"enemy_pool": ["flesh_juggernaut", "mutant_sludge", "sand_worm_larva", "gas_walker", "mortar_crab", "emp_spider"],
		"elite_pool": ["elite_missile_mammoth", "elite_flame_juggernaut"],
		"regional_boss_id": "boss_chimera",
		"final_boss_id": "boss_desert_boat",
		"bg_color": Color(0.10, 0.18, 0.15),
		"grid_color": Color(0.15, 0.25, 0.21),
		"border_color": Color(0.35, 0.92, 0.55),
		"desc": "【生化海床】小怪：变异肉山/沙虫幼体/辐射软泥/迫击炮蟹/磁暴蛛 | 精英：炼狱喷火/导弹巨兽 | 赏金首：【奇美拉】&【沙漠之舟】",
		"unlock_ach_id": "ach_clear_map_3",
		"unlock_ach_desc": "达成成就【百足终结者】通关第3章解锁"
	},
	{
		"id": "map_5",
		"index": 4,
		"name": "第5章：人类终焉中枢·深层地核",
		"waves": 10,
		"hp_mult": 5.50,
		"dmg_mult": 3.00,
		"chip_mult": 3.50,
		"enemy_pool": ["flesh_juggernaut", "flesh_juggernaut", "rad_beetle", "corpse_crawler", "sniper_cannon", "emp_spider", "repair_bot"],
		"elite_pool": ["elite_cyber_executioner", "elite_missile_mammoth", "elite_flame_juggernaut"],
		"regional_boss_id": "boss_bighemoth",
		"final_boss_id": "boss_noah",
		"bg_color": Color(0.13, 0.09, 0.18),
		"grid_color": Color(0.20, 0.13, 0.28),
		"border_color": Color(0.95, 0.25, 0.60),
		"desc": "【终局要塞】变异肉山/重甲巨甲虫/腐骨尸怪/特种军团 | 精英：天穹量子处决者 | 赏金首：【重装帕鲁】&【终焉主脑·原核矩阵】",
		"unlock_ach_id": "ach_clear_map_4",
		"unlock_ach_desc": "达成成就【海床突围】通关第4章解锁"
	}
]

# ============================================================================
# 13. 单地图三档难度设定 (DIFFICULTIES —— 简单 / 困难 / 地狱)
# ============================================================================
const DIFFICULTIES: Dictionary = {
	"easy": {
		"id": "easy",
		"name": "🟢 简单 (废土巡逻)",
		"hp_mult": 1.00,
		"dmg_mult": 1.00,
		"speed_mult": 1.00,
		"spawn_mult": 1.00,
		"bounty_mult": 1.0,
		"chip_mult": 1.0,
		"bonus_start_gold": 20,
		"show_hints": true,
		"color": Color(0.38, 0.95, 0.50),
		"desc": "标准兽潮强度，开局+20G；【战地应急EMP震荡波与绝境翻盘注能仅此模式生效】；显示流派超武提示，通关解锁下一地图！"
	},
	"normal": {
		"id": "normal",
		"name": "🟡 困难 (赏金猎人)",
		"hp_mult": 1.45,
		"dmg_mult": 1.35,
		"speed_mult": 1.08,
		"spawn_mult": 1.22,
		"bounty_mult": 1.20,
		"chip_mult": 1.40,
		"bonus_start_gold": 0,
		"show_hints": true,
		"color": Color(1.00, 0.85, 0.25),
		"desc": "敌军生命×1.45、伤害×1.35、密度+22%！【无EMP保护与翻倍抢修，纯靠操作走位】，显示合成提示，晶片结算×1.40！"
	},
	"hell": {
		"id": "hell",
		"name": "🔴 地狱 (大破坏梦魇)",
		"hp_mult": 2.35,
		"dmg_mult": 1.90,
		"speed_mult": 1.18,
		"spawn_mult": 1.50,
		"bounty_mult": 1.50,
		"chip_mult": 2.30,
		"bonus_start_gold": 0,
		"show_hints": false,
		"color": Color(1.00, 0.28, 0.25),
		"desc": "敌军生命×2.35、伤害×1.90、密度+50%！【无EMP与翻倍抢修，隐藏全部合成提示】，极度硬核，晶片结算×2.30！"
	}
}

func get_boss_by_id(boss_id: String) -> Dictionary:
	for b in WANTED_BOSSES:
		if b["id"] == boss_id:
			return b
	return WANTED_BOSSES[0]

# ============================================================================
# 14. 2D 废土机甲与赏金首美术贴图缓存加载器 (支持未预导入直读与缓存)
# ============================================================================
var _tex_cache: Dictionary = {}

func get_tex(sprite_name: String) -> Texture2D:
	if _tex_cache.has(sprite_name):
		return _tex_cache[sprite_name]
	var res_path: String = "res://assets/sprites/%s.png" % sprite_name
	var tex: Texture2D = null
	if ResourceLoader.exists(res_path):
		tex = load(res_path) as Texture2D
	if tex == null:
		var abs_path: String = ProjectSettings.globalize_path(res_path)
		if FileAccess.file_exists(abs_path):
			var img := Image.load_from_file(abs_path)
			if img != null and not img.is_empty():
				tex = ImageTexture.create_from_image(img)
	_tex_cache[sprite_name] = tex
	return tex

func get_chassis_tex(chassis_id: String) -> Texture2D:
	return get_tex("chassis_" + chassis_id)

func get_hunter_tex(hunter_id: String) -> Texture2D:
	return get_tex("hunter_" + hunter_id)

func get_hunter_portrait_tex(hunter_id: String) -> Texture2D:
	var p_tex: Texture2D = get_tex("portrait_hunter_" + hunter_id)
	if p_tex != null:
		return p_tex
	return get_hunter_tex(hunter_id)

func get_boss_tex(boss_id: String) -> Texture2D:
	return get_tex(boss_id)

func get_enemy_tex(enemy_id: String) -> Texture2D:
	return get_tex("enemy_" + enemy_id)

func get_terrain_tex(map_id: String) -> Texture2D:
	return get_tex("terrain_" + map_id)



# ============================================================================
# 15. 角色专属双皮肤 (HUNTER_SKINS - 6大猎人各2套)
# ============================================================================
const HUNTER_SKINS: Dictionary = {
	"bounty_hunter": [
		{"id": "bh_specops", "name": "荒原特战队 (Spec-Ops)", "desc": "硬派数码迷彩防弹背心与战术战术目镜，适合极端沙暴侦察", "tint": Color(0.95, 0.82, 0.55), "accent": Color(0.35, 0.90, 0.40), "unlock_ach_id": "ach_combo_50"},
		{"id": "bh_cyberpunk", "name": "赛博极夜·霓虹追捕 (Neon Hunt)", "desc": "流光黑曜合金战甲配青蓝霓虹光刃，天穹都市高阶赏金刺客装束", "tint": Color(0.35, 0.45, 0.95), "accent": Color(0.95, 0.25, 0.90), "unlock_ach_id": "ach_super_weapon_1"}
	],
	"lone_wolf": [
		{"id": "lw_blood", "name": "血锈荒魂·复仇战痕 (Blood Rust)", "desc": "暗红重型战痕风衣与血色眼罩，无数次濒死绝境铸就的恶鬼姿态", "tint": Color(0.92, 0.25, 0.20), "accent": Color(1.0, 0.85, 0.25), "unlock_ach_id": "ach_kill_1000"},
		{"id": "lw_phantom", "name": "幽灵白狼·极地巡猎 (Ghost Wolf)", "desc": "冰川雪白迷彩风衣配银白战盔，犹如游弋于永冻荒原的极寒幽灵", "tint": Color(0.85, 0.92, 1.0), "accent": Color(0.30, 0.85, 1.0), "unlock_ach_id": "ach_boss_10"}
	],
	"mechanic": [
		{"id": "mc_industrial", "name": "特斯拉重工·黄黑工业 (Heavy Hazard)", "desc": "工程高亮荧光黄防化背带裤与重型绝缘扳手背架，安全至上的天才少女", "tint": Color(1.0, 0.85, 0.20), "accent": Color(0.15, 0.15, 0.15), "unlock_ach_id": "ach_engine_tune_1"},
		{"id": "mc_cybermaid", "name": "机巧战术·战地女仆 (Combat Maid)", "desc": "黑白古典战术女仆装与纳米医疗注射臂，哪怕在战火中也能优雅救护", "tint": Color(0.95, 0.95, 0.98), "accent": Color(0.95, 0.40, 0.65), "unlock_ach_id": "ach_repair_5"}
	],
	"iron_fist": [
		{"id": "if_riot", "name": "重装防暴·深灰要塞 (Riot Heavy)", "desc": "厚实碳素深灰防暴护甲与全覆式防毒面罩，不动如山的移动钢铁壁垒", "tint": Color(0.40, 0.42, 0.46), "accent": Color(0.35, 0.75, 1.0), "unlock_ach_id": "ach_dodge_20"},
		{"id": "if_molten", "name": "熔岩狂战·炎狱重铠 (Molten Berserk)", "desc": "地热岩浆龟裂动力装甲，伴随高压蒸汽喷射出的炽热战神之拳", "tint": Color(0.95, 0.35, 0.15), "accent": Color(1.0, 0.80, 0.20), "unlock_ach_id": "ach_burn_50"}
	],
	"pochi": [
		{"id": "pc_mecha", "name": "钢铁塞伯·全械波奇 (Cyber Hound)", "desc": "全金属银钛合金义肢与红外电子眼，冷酷背负微型旋转机枪的未来兵器", "tint": Color(0.75, 0.82, 0.90), "accent": Color(1.0, 0.20, 0.20), "unlock_ach_id": "ach_crush_10"},
		{"id": "pc_rescue", "name": "荒原救援·高亮防化 (Rescue Pup)", "desc": "明亮橘红战术防寒背心与战地急救水壶项圈，废土幸存者最温暖的阳光", "tint": Color(1.0, 0.55, 0.15), "accent": Color(0.25, 0.95, 0.55), "unlock_ach_id": "ach_survive_100_sp"}
	],
	"mince_aide": [
		{"id": "ma_mad", "name": "疯狂电极·特斯拉紫袍 (Volt Magus)", "desc": "紫黑高领放电风衣与流窜蓝白高压电弧的特斯拉背囊，掌控天罚雷电", "tint": Color(0.65, 0.35, 0.95), "accent": Color(0.40, 0.90, 1.0), "unlock_ach_id": "ach_emp_50"},
		{"id": "ma_alchemist", "name": "鸟嘴死医·荒原炼金 (Plague Alchemist)", "desc": "复古皮质鸟嘴面罩与暗金滚边学者长袍，腰间挂满咕嘟冒泡的生化药剂瓶", "tint": Color(0.28, 0.35, 0.32), "accent": Color(0.85, 0.75, 0.35), "unlock_ach_id": "ach_toxic_20"}
	]
}

# ============================================================================
# 16. 战车专属双皮肤 (CHASSIS_SKINS - 8大底盘各2套)
# ============================================================================
const CHASSIS_SKINS: Dictionary = {
	"buggy": [
		{"id": "ch_buggy_camo", "name": "荒野沙狐·沙漠迷彩 (Desert Fox)", "desc": "经典沙黄数码迷彩哑光漆面，防沙滤网与车头加固防撞杠", "body": Color(0.82, 0.68, 0.42), "turret": Color(0.55, 0.45, 0.32), "treads": Color(0.25, 0.22, 0.18), "decal": Color(0.95, 0.85, 0.35), "unlock_ach_id": "ach_drill_1"},
		{"id": "ch_buggy_cyber", "name": "极夜疾驰·赛博炫彩 (Neon Velocity)", "desc": "哑光曜黑底漆搭配紫粉渐变荧光线条，废土夜幕下最刺眼的流光", "body": Color(0.18, 0.15, 0.24), "turret": Color(0.35, 0.20, 0.50), "treads": Color(0.12, 0.10, 0.16), "decal": Color(0.95, 0.30, 0.85), "unlock_ach_id": "ach_gold_1000"}
	],
	"r_wolf": [
		{"id": "ch_wolf_crimson", "name": "血色彗星·重装战痕 (Scarlet Comet)", "desc": "耀眼烈焰绯红烤漆，炮塔带有等离子灼烧战痕与孤狼图腾", "body": Color(0.85, 0.18, 0.15), "turret": Color(0.60, 0.12, 0.10), "treads": Color(0.22, 0.20, 0.20), "decal": Color(1.0, 0.88, 0.25), "unlock_ach_id": "ach_boss_killdozer"},
		{"id": "ch_wolf_stealth", "name": "黑夜幽灵·隐形碳纤 (Stealth Carbon)", "desc": "全覆式碳纤维吸波黑装甲，隐藏在雷达盲区的致命荒原幽灵", "body": Color(0.16, 0.16, 0.18), "turret": Color(0.25, 0.25, 0.28), "treads": Color(0.10, 0.10, 0.12), "decal": Color(0.35, 0.85, 1.0), "unlock_ach_id": "ach_crit_50"}
	],
	"abrams": [
		{"id": "ch_abrams_woodland", "name": "重型战线·北约丛林 (Woodland Armor)", "desc": "军绿与泥褐三色交织林地迷彩，挂载重型爆炸反应装甲块", "body": Color(0.32, 0.42, 0.28), "turret": Color(0.25, 0.32, 0.22), "treads": Color(0.18, 0.18, 0.18), "decal": Color(0.85, 0.85, 0.55), "unlock_ach_id": "ach_equip_4"},
		{"id": "ch_abrams_desert", "name": "海湾风暴·重装沙暴 (Gulf Storm)", "desc": "重型防反光耐磨沙土涂层，附带高位进气管与排沙格栅", "body": Color(0.78, 0.65, 0.45), "turret": Color(0.62, 0.52, 0.36), "treads": Color(0.24, 0.20, 0.16), "decal": Color(0.95, 0.45, 0.20), "unlock_ach_id": "ach_tank_dmg_5000"}
	],
	"missile_carrier": [
		{"id": "ch_carrier_arctic", "name": "极地霜冻·冰川几何 (Arctic Frost)", "desc": "永冻冰原雪白与海蓝几何数码迷彩，飞弹发射舱覆有防结冰电热膜", "body": Color(0.80, 0.88, 0.95), "turret": Color(0.45, 0.62, 0.80), "treads": Color(0.22, 0.25, 0.30), "decal": Color(0.35, 0.95, 1.0), "unlock_ach_id": "ach_evo_orbit"},
		{"id": "ch_carrier_hazard", "name": "辐射禁区·核黄警示 (Bio-Hazard)", "desc": "高反差黑黄斑马条纹涂装，醒目的核警示三叶草徽章与强化防化涂层", "body": Color(0.92, 0.78, 0.18), "turret": Color(0.20, 0.20, 0.20), "treads": Color(0.15, 0.15, 0.15), "decal": Color(0.95, 0.25, 0.20), "unlock_ach_id": "ach_synergy_4_cannon"}
	],
	"mammoth": [
		{"id": "ch_mammoth_iron", "name": "荒原重锈·工业钢铁 (Iron Rust)", "desc": "粗犷铆接厚装甲钢板与被油污浸润的重锈车身，推平一切的机械巨兽", "body": Color(0.45, 0.35, 0.30), "turret": Color(0.32, 0.26, 0.22), "treads": Color(0.18, 0.15, 0.14), "decal": Color(0.85, 0.40, 0.20), "unlock_ach_id": "ach_crush_50"},
		{"id": "ch_mammoth_glacier", "name": "极地战象·白金神将 (Glacier Titan)", "desc": "钛银灰与冰晶钢蓝护甲，巨大推土铲镀以金黄耐磨合金，威仪万千", "body": Color(0.70, 0.78, 0.85), "turret": Color(0.40, 0.52, 0.68), "treads": Color(0.22, 0.24, 0.28), "decal": Color(1.0, 0.85, 0.25), "unlock_ach_id": "ach_max_weight_35"}
	],
	"ambulance": [
		{"id": "ch_amb_medic", "name": "战地守护·白鸽红十字 (White Medic)", "desc": "象牙白车身镶嵌醒目急救红十字，蓝红双闪警示爆闪灯，希望的灯塔", "body": Color(0.92, 0.94, 0.95), "turret": Color(0.75, 0.20, 0.22), "treads": Color(0.25, 0.25, 0.26), "decal": Color(0.95, 0.22, 0.25), "unlock_ach_id": "ach_boss_jelly"},
		{"id": "ch_amb_hazmat", "name": "生化消毒·荧光应援 (Hazmat Neon)", "desc": "荧光翠绿防腐酸涂料搭配紫外消毒光环，在毒沼毒海中来去自如", "body": Color(0.25, 0.80, 0.45), "turret": Color(0.18, 0.55, 0.32), "treads": Color(0.16, 0.22, 0.18), "decal": Color(0.40, 0.98, 0.85), "unlock_ach_id": "ach_toxic_gas_kill_30"}
	],
	"bus": [
		{"id": "ch_bus_police", "name": "特警战术·铁壁防暴 (Tactical Riot)", "desc": "黑白经典警务防暴涂漆，车窗加装厚重防爆钢栅栏与高音扩音喇叭", "body": Color(0.22, 0.24, 0.28), "turret": Color(0.85, 0.85, 0.88), "treads": Color(0.15, 0.15, 0.16), "decal": Color(0.35, 0.65, 0.95), "unlock_ach_id": "ach_clear_map_2"},
		{"id": "ch_bus_wasteland", "name": "狂暴摇滚·狂欢朋克 (Punk Festival)", "desc": "车身布满喷漆涂鸦、烈火图腾与带刺防护角，摇滚重金属的废土狂欢", "body": Color(0.75, 0.22, 0.45), "turret": Color(0.85, 0.60, 0.18), "treads": Color(0.20, 0.16, 0.22), "decal": Color(1.0, 0.35, 0.15), "unlock_ach_id": "ach_spend_1500"}
	],
	"tyrannos": [
		{"id": "ch_tyrannos_mech", "name": "原核神兵·黑曜金煞 (Obsidian Core)", "desc": "深黑曜石吸能装甲流淌着黄金原核回路，仿佛从古代智脑中苏醒的歼灭神", "body": Color(0.15, 0.15, 0.17), "turret": Color(0.28, 0.28, 0.32), "treads": Color(0.12, 0.12, 0.14), "decal": Color(1.0, 0.82, 0.20), "unlock_ach_id": "ach_clear_map_5"},
		{"id": "ch_tyrannos_volcano", "name": "熔岩暴龙·深渊炎魔 (Volcano Rex)", "desc": "暗红灼烧玄武岩甲壳，炮口喷薄着灼热硫磺与岩浆烈火", "body": Color(0.65, 0.18, 0.14), "turret": Color(0.42, 0.12, 0.10), "treads": Color(0.20, 0.15, 0.14), "decal": Color(1.0, 0.45, 0.18), "unlock_ach_id": "ach_clear_hard_all"}
	]
}

# ============================================================================
# 17. 局外战车涂装工坊部位与预设方案 (PAINT_PARTS & PRESETS)
# ============================================================================
const PAINT_PARTS: Array = [
	{"id": "body", "name": "车身主装甲 (Hull/Chassis)", "desc": "战车车体外壳与前置冲撞装甲"},
	{"id": "turret", "name": "炮塔与主炮架 (Turret/Mount)", "desc": "主炮回转塔台与副炮基座外框"},
	{"id": "treads", "name": "履带与负重轮 (Treads/Wheels)", "desc": "底盘履带链片、负重轮毂与侧翼挡泥板"},
	{"id": "decal", "name": "战术拉花/能量荧光 (Decal/Glow)", "desc": "军徽拉花条纹、能量管线与车灯涂装"}
]

const PAINT_PRESETS: Array = [
	{"id": "scarlet", "name": "赤色风暴 (Crimson Storm)", "body": Color(0.85, 0.20, 0.18), "turret": Color(0.55, 0.12, 0.12), "treads": Color(0.22, 0.20, 0.20), "decal": Color(1.0, 0.85, 0.25)},
	{"id": "desert", "name": "沙暴迷彩 (Desert Dune)", "body": Color(0.80, 0.68, 0.45), "turret": Color(0.58, 0.48, 0.32), "treads": Color(0.24, 0.20, 0.16), "decal": Color(0.95, 0.50, 0.20)},
	{"id": "arctic", "name": "极地雪原 (Arctic Snow)", "body": Color(0.88, 0.92, 0.98), "turret": Color(0.45, 0.65, 0.85), "treads": Color(0.25, 0.28, 0.32), "decal": Color(0.35, 0.95, 1.0)},
	{"id": "cyber", "name": "赛博霓虹 (Cyber Neon)", "body": Color(0.18, 0.15, 0.24), "turret": Color(0.32, 0.20, 0.48), "treads": Color(0.12, 0.10, 0.15), "decal": Color(0.95, 0.25, 0.85)},
	{"id": "hazard", "name": "工业明黄 (Hazard Yellow)", "body": Color(0.95, 0.82, 0.18), "turret": Color(0.22, 0.22, 0.22), "treads": Color(0.18, 0.18, 0.18), "decal": Color(0.95, 0.25, 0.20)},
	{"id": "military", "name": "军工重装 (Military Olive)", "body": Color(0.35, 0.42, 0.30), "turret": Color(0.26, 0.32, 0.22), "treads": Color(0.18, 0.18, 0.18), "decal": Color(0.90, 0.85, 0.50)},
	{"id": "stealth", "name": "隐形黑曜 (Stealth Dark)", "body": Color(0.16, 0.16, 0.18), "turret": Color(0.25, 0.25, 0.28), "treads": Color(0.10, 0.10, 0.12), "decal": Color(0.40, 0.85, 1.0)},
	{"id": "purple_core", "name": "原核紫晶 (Noah Amethyst)", "body": Color(0.25, 0.18, 0.35), "turret": Color(0.42, 0.25, 0.60), "treads": Color(0.14, 0.12, 0.18), "decal": Color(0.95, 0.40, 0.95)}
]

# ============================================================================
# 18. 废土荣誉殿堂 - 全 92 项成就系统 (ACHIEVEMENTS)
# ============================================================================
const ACHIEVEMENT_CATEGORIES: Dictionary = {
	"all": "全部成就",
	"career": "猎人生涯",
	"boss": "通缉猎杀",
	"chassis": "战车车间",
	"weapon": "神话流派",
	"survival": "铁血生存",
	"tactics": "战术身法",
	"chapter": "章节征程",
	"meta": "科技特权"
}

const ACHIEVEMENTS: Array = [
	{"id": "ach_kill_10", "cat": "career", "name": "🌱 荒原初啼", "desc": "在战斗中累计消灭 10 只机械怪物", "metric": "total_kills", "target": 10, "rtype": "chips", "rid": "", "rname": "💎 20 原核晶片"},
	{"id": "ach_kill_100", "cat": "career", "name": "🎯 赏金学徒", "desc": "在战斗中累计消灭 100 只机械怪物", "metric": "total_kills", "target": 100, "rtype": "chips", "rid": "", "rname": "💎 40 原核晶片"},
	{"id": "ach_kill_300", "cat": "career", "name": "⚔️ 荒原百人斩", "desc": "在战斗中累计消灭 300 只机械怪物", "metric": "total_kills", "target": 300, "rtype": "chips", "rid": "", "rname": "💎 60 原核晶片"},
	{"id": "ach_kill_500", "cat": "career", "name": "🐺 荒原猎王", "desc": "在战斗中累计消灭 500 只机械怪物", "metric": "total_kills", "target": 500, "rtype": "hunter", "rid": "lone_wolf", "rname": "解锁新猎人【克莱因·绯红孤狼】"},
	{"id": "ach_kill_1000", "cat": "career", "name": "🩸 千人屠夫", "desc": "在战斗中累计消灭 1000 只机械怪物", "metric": "total_kills", "target": 1000, "rtype": "hunter_skin", "rid": "lw_blood", "rname": "解锁孤狼皮肤【血锈荒魂】"},
	{"id": "ach_kill_3000", "cat": "career", "name": "💀 废土死神", "desc": "在战斗中累计消灭 3000 只机械怪物", "metric": "total_kills", "target": 3000, "rtype": "chips", "rid": "", "rname": "💎 150 原核晶片"},
	{"id": "ach_kill_10000", "cat": "career", "name": "🌌 万械俱灭", "desc": "在战斗中累计消灭 10000 只机械怪物", "metric": "total_kills", "target": 10000, "rtype": "chips", "rid": "", "rname": "💎 300 原核晶片"},
	{"id": "ach_combo_20", "cat": "career", "name": "⚡ 连击新星", "desc": "单局击杀计数器达成 20 Combo 连击", "metric": "max_combo", "target": 20, "rtype": "chips", "rid": "", "rname": "💎 30 原核晶片"},
	{"id": "ach_combo_35", "cat": "career", "name": "🔥 杀戮沸腾", "desc": "单局击杀计数器达成 35 Combo 连击", "metric": "max_combo", "target": 35, "rtype": "chips", "rid": "", "rname": "💎 50 原核晶片"},
	{"id": "ach_combo_50", "cat": "career", "name": "🌪️ 连击大师", "desc": "单局击杀计数器达成 50 Combo 连击", "metric": "max_combo", "target": 50, "rtype": "hunter_skin", "rid": "bh_specops", "rname": "解锁雷恩皮肤【荒原特战队】"},
	{"id": "ach_combo_100", "cat": "career", "name": "🌪️ 狂飙风暴", "desc": "单局击杀计数器达成 100 Combo 极限连击", "metric": "max_combo", "target": 100, "rtype": "chips", "rid": "", "rname": "💎 120 原核晶片"},
	{"id": "ach_combo_200", "cat": "career", "name": "👑 割草至尊", "desc": "单局击杀计数器达成 200 Combo 绝世割草", "metric": "max_combo", "target": 200, "rtype": "chips", "rid": "", "rname": "💎 250 原核晶片"},
	{"id": "ach_boss_killdozer", "cat": "boss", "name": "🚜 推土机终结者", "desc": "成功讨伐赏金首【杀人推土机 (Killdozer)】", "metric": "kill_boss_killdozer", "target": 1, "rtype": "chassis_skin", "rid": "ch_wolf_crimson", "rname": "解锁红狼皮肤【血色彗星】"},
	{"id": "ach_boss_jelly", "cat": "boss", "name": "⚡ 水母电击疗法", "desc": "成功讨伐赏金首【加农水母 (Cannon Jelly)】", "metric": "kill_boss_jelly", "target": 1, "rtype": "chassis_skin", "rid": "ch_amb_medic", "rname": "解锁救护车皮肤【白鸽红十字】"},
	{"id": "ach_boss_sand_shark", "cat": "boss", "name": "🦈 沙海钓龙者", "desc": "成功讨伐赏金首【深沙巨鲛·地龙 (Sand Maw)】", "metric": "kill_boss_sand_shark", "target": 1, "rtype": "chips", "rid": "", "rname": "💎 60 原核晶片"},
	{"id": "ach_boss_skunks", "cat": "boss", "name": "🦨 沙盗死期", "desc": "成功讨伐赏金首【狂飙沙盗首领·斯卡普 (Scarp)】", "metric": "kill_boss_skunks", "target": 1, "rtype": "chips", "rid": "", "rname": "💎 60 原核晶片"},
	{"id": "ach_boss_centipede", "cat": "boss", "name": "🚂 脱轨时刻", "desc": "成功讨伐赏金首【百足装甲列车 (Centipede)】", "metric": "kill_boss_centipede", "target": 1, "rtype": "chips", "rid": "", "rname": "💎 80 原核晶片"},
	{"id": "ach_boss_gomez", "cat": "boss", "name": "👑 劫掠王陨落", "desc": "成功讨伐赏金首【荒原劫掠王·巴洛克 (Baroque)】", "metric": "kill_boss_gomez", "target": 1, "rtype": "chassis", "rid": "r_wolf", "rname": "解锁新战车【绯红之狼】"},
	{"id": "ach_boss_chimera", "cat": "boss", "name": "🧬 终结生化兽", "desc": "成功讨伐赏金首【生化融合兽·奇美拉 (Bio-Chimera)】", "metric": "kill_boss_chimera", "target": 1, "rtype": "chips", "rid": "", "rname": "💎 90 原核晶片"},
	{"id": "ach_boss_desert_boat", "cat": "boss", "name": "⚓ 击沉巨舰", "desc": "成功讨伐赏金首【陆地战舰·沙漠之舟 (Desert Boat)】", "metric": "kill_boss_desert_boat", "target": 1, "rtype": "chips", "rid": "", "rname": "💎 100 原核晶片"},
	{"id": "ach_boss_bighemoth", "cat": "boss", "name": "🦾 暴君伏诛", "desc": "成功讨伐赏金首【钢铁暴君·重装帕鲁 (Bighemoth)】", "metric": "kill_boss_bighemoth", "target": 1, "rtype": "chips", "rid": "", "rname": "💎 120 原核晶片"},
	{"id": "ach_boss_noah", "cat": "boss", "name": "☀️ 人类黎明", "desc": "成功讨伐终极赏金首【终焉主脑·原核矩阵 (Master OMEGA)】", "metric": "kill_boss_noah", "target": 1, "rtype": "hunter", "rid": "mince_aide", "rname": "解锁新猎人【伊戈尔·赛博方士】"},
	{"id": "ach_boss_3", "cat": "boss", "name": "🎖️ 初出茅庐", "desc": "累计击败 3 名通缉赏金首", "metric": "total_bounties", "target": 3, "rtype": "chips", "rid": "", "rname": "💎 50 原核晶片"},
	{"id": "ach_boss_10", "cat": "boss", "name": "🏅 传奇猎手", "desc": "累计击败 10 名通缉赏金首", "metric": "total_bounties", "target": 10, "rtype": "hunter_skin", "rid": "lw_phantom", "rname": "解锁孤狼皮肤【幽灵白狼】"},
	{"id": "ach_boss_30", "cat": "boss", "name": "🏆 荒原清道夫", "desc": "累计击败 30 名通缉赏金首", "metric": "total_bounties", "target": 30, "rtype": "chips", "rid": "", "rname": "💎 180 原核晶片"},
	{"id": "ach_boss_100", "cat": "boss", "name": "🌟 赏金神话", "desc": "累计击败 100 名通缉赏金首", "metric": "total_bounties", "target": 100, "rtype": "chips", "rid": "", "rname": "💎 350 原核晶片"},
	{"id": "ach_boss_fast_kill", "cat": "boss", "name": "⏱️ 极速处决", "desc": "在 30 秒内迅速击杀任意一名赏金首", "metric": "fast_boss_kill", "target": 1, "rtype": "chips", "rid": "", "rname": "💎 80 原核晶片"},
	{"id": "ach_drill_1", "cat": "chassis", "name": "🔧 激光始动", "desc": "在多拉姆车库完成 1 次战车底盘激光打孔扩充槽位", "metric": "drill_slot_count", "target": 1, "rtype": "chassis_skin", "rid": "ch_buggy_camo", "rname": "解锁越野车皮肤【荒野沙狐】"},
	{"id": "ach_drill_2", "cat": "chassis", "name": "🌟 六孔全开", "desc": "单局将战车底盘槽位打孔扩充至 6 孔全满上限", "metric": "max_slots_reached", "target": 6, "rtype": "chips", "rid": "", "rname": "💎 100 原核晶片"},
	{"id": "ach_engine_tune_1", "cat": "chassis", "name": "⚡ 引擎超频", "desc": "在车库完成 1 次引擎出力扩容调校 (+2.5t 载重)", "metric": "engine_tune_count", "target": 1, "rtype": "hunter_skin", "rid": "mc_industrial", "rname": "解锁爱丽丝皮肤【黄黑工业装】"},
	{"id": "ach_engine_tune_3", "cat": "chassis", "name": "🚀 动力澎湃", "desc": "单局在车库累计完成 3 次引擎出力扩容", "metric": "engine_tune_count", "target": 3, "rtype": "chips", "rid": "", "rname": "💎 80 原核晶片"},
	{"id": "ach_max_weight_25", "cat": "chassis", "name": "⚖️ 重装先锋", "desc": "战车最大引擎载重达到 25.0t 以上", "metric": "max_weight", "target": 25.0, "rtype": "chips", "rid": "", "rname": "💎 50 原核晶片"},
	{"id": "ach_max_weight_35", "cat": "chassis", "name": "🏰 移动堡垒", "desc": "战车最大引擎载重达到 35.0t 以上", "metric": "max_weight", "target": 35.0, "rtype": "chassis_skin", "rid": "ch_mammoth_glacier", "rname": "解锁猛犸皮肤【极地战象】"},
	{"id": "ach_switch_chassis_1", "cat": "chassis", "name": "🔄 换乘体验", "desc": "在多拉姆车库成功换乘一次其他战车底盘", "metric": "switch_chassis_count", "target": 1, "rtype": "chips", "rid": "", "rname": "💎 40 原核晶片"},
	{"id": "ach_mod_slot_1", "cat": "chassis", "name": "🔩 武器改孔", "desc": "在车库完成 1 次槽位类型改装切换 (主炮/副炮/SE)", "metric": "mod_slot_count", "target": 1, "rtype": "chips", "rid": "", "rname": "💎 30 原核晶片"},
	{"id": "ach_mod_slot_5", "cat": "chassis", "name": "🛠️ 车间常客", "desc": "累计完成 5 次槽位属性改孔", "metric": "mod_slot_count", "target": 5, "rtype": "chips", "rid": "", "rname": "💎 80 原核晶片"},
	{"id": "ach_gold_500", "cat": "chassis", "name": "💰 赏金丰厚", "desc": "单局内手头持有的废土多拉姆达到 500 G", "metric": "max_gold_held", "target": 500, "rtype": "chips", "rid": "", "rname": "💎 40 原核晶片"},
	{"id": "ach_gold_1000", "cat": "chassis", "name": "💎 废土富豪", "desc": "单局内手头持有的废土多拉姆达到 1000 G", "metric": "max_gold_held", "target": 1000, "rtype": "chassis_skin", "rid": "ch_buggy_cyber", "rname": "解锁越野车皮肤【极夜疾驰】"},
	{"id": "ach_spend_1500", "cat": "chassis", "name": "🛍️ 挥金如土", "desc": "单局在多拉姆车库中累计消费 1500 G 赏金", "metric": "gold_spent_run", "target": 1500, "rtype": "chassis_skin", "rid": "ch_bus_wasteland", "rname": "解锁大巴皮肤【狂暴摇滚】"},
	{"id": "ach_equip_4", "cat": "weapon", "name": "⚔️ 全副武装", "desc": "战车挂架上同时装配满 4 门武器", "metric": "equipped_weapons_count", "target": 4, "rtype": "chassis_skin", "rid": "ch_abrams_woodland", "rname": "解锁重坦皮肤【北约丛林】"},
	{"id": "ach_equip_6", "cat": "weapon", "name": "🚀 移动军火库", "desc": "战车挂架上同时装配满 6 门武器", "metric": "equipped_weapons_count", "target": 6, "rtype": "chips", "rid": "", "rname": "💎 80 原核晶片"},
	{"id": "ach_weapon_rarity_2", "cat": "weapon", "name": "⭐ 质的飞跃", "desc": "在战斗中将任意武器合成升至 ★2 精良稀有度", "metric": "max_weapon_rarity", "target": 1, "rtype": "chips", "rid": "", "rname": "💎 30 原核晶片"},
	{"id": "ach_weapon_rarity_3", "cat": "weapon", "name": "🔷 稀有精炼", "desc": "在战斗中拥有至少 1 门 ★3 稀有蓝色武器", "metric": "max_weapon_rarity", "target": 2, "rtype": "chips", "rid": "", "rname": "💎 40 原核晶片"},
	{"id": "ach_weapon_rarity_4", "cat": "weapon", "name": "🟣 史诗重炮", "desc": "在战斗中拥有至少 1 门 ★4 史诗紫色武器", "metric": "max_weapon_rarity", "target": 3, "rtype": "chips", "rid": "", "rname": "💎 60 原核晶片"},
	{"id": "ach_weapon_rarity_5", "cat": "weapon", "name": "🔴 绯红传奇", "desc": "获得至少 1 门 ★5 绯红传奇武器", "metric": "max_weapon_rarity", "target": 4, "rtype": "chips", "rid": "", "rname": "💎 100 原核晶片"},
	{"id": "ach_super_weapon_1", "cat": "weapon", "name": "🌟 神话降临", "desc": "成功合成出第 1 把 ★6 神话级超武", "metric": "super_weapon_count", "target": 1, "rtype": "hunter_skin", "rid": "bh_cyberpunk", "rname": "解锁雷恩皮肤【赛博极夜】"},
	{"id": "ach_evo_cannon", "cat": "weapon", "name": "💥 双星交辉", "desc": "合成神话超武【★超武：绯红双星·超重歼灭炮】", "metric": "evo_crimson_stars", "target": 1, "rtype": "chips", "rid": "", "rname": "💎 80 原核晶片"},
	{"id": "ach_evo_aurora", "cat": "weapon", "name": "🌌 全域死光", "desc": "合成神话超武【★超武：天穹极光·暴风近防阵列】", "metric": "evo_aurora_storm", "target": 1, "rtype": "chips", "rid": "", "rname": "💎 80 原核晶片"},
	{"id": "ach_evo_orbit", "cat": "weapon", "name": "⚡ 磁暴天罚", "desc": "合成神话超武【★超武：宙斯裁决·泰坦重装震荡球】", "metric": "evo_zeus_orbit", "target": 1, "rtype": "chassis_skin", "rid": "ch_carrier_arctic", "rname": "解锁导弹车皮肤【极地霜冻】"},
	{"id": "ach_evo_damocles", "cat": "weapon", "name": "🛰️ 终焉轨道", "desc": "合成神话超武【★超武：达摩克利斯·原核湮灭激光柱】", "metric": "evo_damocles", "target": 1, "rtype": "chips", "rid": "", "rname": "💎 100 原核晶片"},
	{"id": "ach_synergy_4_cannon", "cat": "weapon", "name": "💣 狂轰滥炸", "desc": "战车装备同时凑齐 4 门【重炮】流派羁绊", "metric": "synergy_cannon_4", "target": 1, "rtype": "chassis_skin", "rid": "ch_carrier_hazard", "rname": "解锁导弹车皮肤【核黄警示】"},
	{"id": "ach_synergy_4_rapid", "cat": "weapon", "name": "🔥 弹幕倾泻", "desc": "战车装备同时凑齐 4 门【速射】流派羁绊", "metric": "synergy_rapid_4", "target": 1, "rtype": "chips", "rid": "", "rname": "💎 60 原核晶片"},
	{"id": "ach_synergy_4_electric", "cat": "weapon", "name": "⚡ 磁暴电网", "desc": "战车装备同时凑齐 4 门【电磁】流派羁绊", "metric": "synergy_electric_4", "target": 1, "rtype": "chips", "rid": "", "rname": "💎 60 原核晶片"},
	{"id": "ach_tank_wreck_1", "cat": "survival", "name": "🩸 大难不死", "desc": "战车 SP 归零大破跳车，成功进入步兵肉搏形态存活", "metric": "tank_wreck_count", "target": 1, "rtype": "chips", "rid": "", "rname": "💎 30 原核晶片"},
	{"id": "ach_repair_1", "cat": "survival", "name": "🔧 绝境焊匠", "desc": "在步兵肉搏状态下靠近残骸读条抢修成功重回战车", "metric": "repair_success_count", "target": 1, "rtype": "chips", "rid": "", "rname": "💎 40 原核晶片"},
	{"id": "ach_repair_5", "cat": "survival", "name": "🔨 抢修老手", "desc": "累计完成 5 次大破紧急抢修重回战车", "metric": "repair_success_count", "target": 5, "rtype": "hunter_skin", "rid": "mc_cybermaid", "rname": "解锁爱丽丝皮肤【战地女仆】"},
	{"id": "ach_repair_sp_3000", "cat": "survival", "name": "👼 战场天使", "desc": "累计抢修战车恢复 3000 点 SP 装甲片", "metric": "total_repaired_sp", "target": 3000, "rtype": "chassis", "rid": "ambulance", "rname": "解锁新战车【野战救护车】"},
	{"id": "ach_survive_100_sp", "cat": "survival", "name": "🛡️ 毫发无损", "desc": "单波次战斗结束时战车 SP 保持 100% 满状态", "metric": "flawless_wave_count", "target": 1, "rtype": "hunter_skin", "rid": "pc_rescue", "rname": "解锁波奇皮肤【荒原救援犬】"},
	{"id": "ach_tank_dmg_2500", "cat": "survival", "name": "🦾 钢筋铁骨", "desc": "单局战车装甲片累计承受吸收 2500 点伤害", "metric": "tank_absorbed_dmg", "target": 2500, "rtype": "hunter", "rid": "iron_fist", "rname": "解锁新猎人【凛·废土武道家】"},
	{"id": "ach_tank_dmg_5000", "cat": "survival", "name": "🧱 叹息之壁", "desc": "单局战车装甲片累计承受吸收 5000 点伤害", "metric": "tank_absorbed_dmg", "target": 5000, "rtype": "chassis_skin", "rid": "ch_abrams_desert", "rname": "解锁重坦皮肤【海湾风暴】"},
	{"id": "ach_human_kill_1", "cat": "survival", "name": "🔫 绝地步兵", "desc": "以步兵肉搏状态手枪击杀 1 名机械怪物", "metric": "human_kills", "target": 1, "rtype": "chips", "rid": "", "rname": "💎 30 原核晶片"},
	{"id": "ach_human_kill_20", "cat": "survival", "name": "🐕 步兵奇迹", "desc": "累计以步兵肉搏状态击杀 20 名机械怪物", "metric": "human_kills", "target": 20, "rtype": "hunter", "rid": "pochi", "rname": "解锁新猎人【麦克斯·战术柴犬】"},
	{"id": "ach_low_sp_wave", "cat": "survival", "name": "⏱️ 绝境求生", "desc": "战车 SP 低于 15% 濒死状态下完成波次读秒胜利", "metric": "clutch_wave_clear", "target": 1, "rtype": "chips", "rid": "", "rname": "💎 60 原核晶片"},
	{"id": "ach_defib_revive", "cat": "survival", "name": "🛰️ 轨道除颤", "desc": "触发特斯拉轨道除颤卫星满血复苏 1 次", "metric": "defib_revive_count", "target": 1, "rtype": "chips", "rid": "", "rname": "💎 50 原核晶片"},
	{"id": "ach_crush_10", "cat": "tactics", "name": "🚜 钢铁履带", "desc": "高速驾驶战车物理碾碎 10 只轻甲小怪", "metric": "crushed_enemies", "target": 10, "rtype": "hunter_skin", "rid": "pc_mecha", "rname": "解锁波奇皮肤【钢铁赛博】"},
	{"id": "ach_crush_30", "cat": "tactics", "name": "💥 压路狂飙", "desc": "单局驾驶战车物理碾碎 30 只轻甲小怪", "metric": "crushed_enemies", "target": 30, "rtype": "chassis", "rid": "mammoth", "rname": "解锁新战车【猛犸重装突进要塞】"},
	{"id": "ach_crush_50", "cat": "tactics", "name": "🦣 猛犸横行", "desc": "单局驾驶战车物理碾碎 50 只轻甲小怪", "metric": "crushed_enemies", "target": 50, "rtype": "chassis_skin", "rid": "ch_mammoth_iron", "rname": "解锁猛犸皮肤【荒原重锈】"},
	{"id": "ach_all_out_1", "cat": "tactics", "name": "🎯 全弹齐发", "desc": "触发 1 次 C装置【全弹发射】终极指令", "metric": "all_out_count", "target": 1, "rtype": "chips", "rid": "", "rname": "💎 30 原核晶片"},
	{"id": "ach_all_out_10", "cat": "tactics", "name": "🌪️ 全弹风暴", "desc": "累计触发 10 次 C装置【全弹发射】终极指令", "metric": "all_out_count", "target": 10, "rtype": "chassis", "rid": "missile_carrier", "rname": "解锁新战车【暴风导弹车】"},
	{"id": "ach_dodge_20", "cat": "tactics", "name": "💨 闪电身法", "desc": "单局战斗中成功触发 20 次战车闪避 (MISS)", "metric": "dodge_count", "target": 20, "rtype": "hunter_skin", "rid": "if_riot", "rname": "解锁凛皮肤【重装防暴】"},
	{"id": "ach_crit_50", "cat": "tactics", "name": "🎯 致命火控", "desc": "单局战车综合暴击率提升至 50% 以上", "metric": "crit_chance", "target": 0.5, "rtype": "chassis_skin", "rid": "ch_wolf_stealth", "rname": "解锁红狼皮肤【黑夜幽灵】"},
	{"id": "ach_toxic_gas_kill_30", "cat": "tactics", "name": "☣️ 生化毒沼", "desc": "利用救护车生化毒雾腐蚀消灭 30 只小怪", "metric": "toxic_aura_kills", "target": 30, "rtype": "chassis_skin", "rid": "ch_amb_hazmat", "rname": "解锁救护车皮肤【生化隔离】"},
	{"id": "ach_burn_50", "cat": "tactics", "name": "🔥 烈火燎原", "desc": "使用火焰武器使累计 50 名敌人燃烧", "metric": "burned_enemies", "target": 50, "rtype": "hunter_skin", "rid": "if_molten", "rname": "解锁凛皮肤【熔岩狂战】"},
	{"id": "ach_emp_50", "cat": "tactics", "name": "⚡ 磁暴震荡", "desc": "使用电击武器使累计 50 名敌人感电瘫痪", "metric": "emp_stunned_enemies", "target": 50, "rtype": "hunter_skin", "rid": "ma_mad", "rname": "解锁伊戈尔皮肤【疯狂电极】"},
	{"id": "ach_clear_map_1", "cat": "chapter", "name": "🚩 荒原先遣队", "desc": "成功通关第 1 章节【废土哨站·荒野起点】", "metric": "clear_map_1", "target": 1, "rtype": "map", "rid": "map_2", "rname": "解锁新地图【第2章·流沙遗迹】"},
	{"id": "ach_clear_map_2", "cat": "chapter", "name": "🏜️ 沙海征服者", "desc": "成功通关第 2 章节【死亡大沙漠·流沙遗迹】", "metric": "clear_map_2", "target": 1, "rtype": "map", "rid": "map_3", "rname": "解锁新地图【第3章·百足峡谷】"},
	{"id": "ach_clear_map_3", "cat": "chapter", "name": "🚂 百足终结者", "desc": "成功通关第 3 章节【铁道废墟·百足峡谷】", "metric": "clear_map_3", "target": 1, "rtype": "map", "rid": "map_4", "rname": "解锁新地图【第4章·枯竭海床】"},
	{"id": "ach_clear_map_4", "cat": "chapter", "name": "🌉 海床突围", "desc": "成功通关第 4 章节【恶魔跨海大桥·枯竭海床】", "metric": "clear_map_4", "target": 1, "rtype": "map", "rid": "map_5", "rname": "解锁新地图【第5章·深层地核】"},
	{"id": "ach_clear_map_5", "cat": "chapter", "name": "🏆 废土救世主", "desc": "成功通关第 5 章节【人类终焉中枢·深层地核】", "metric": "clear_map_5", "target": 1, "rtype": "chassis_skin", "rid": "ch_tyrannos_mech", "rname": "解锁暴龙车皮肤【原核神兵】"},
	{"id": "ach_survive_waves_15", "cat": "chapter", "name": "🚌 废土观光客", "desc": "在任意关卡累计存活超过 15 个战斗波次", "metric": "total_waves_survived", "target": 15, "rtype": "chassis", "rid": "bus", "rname": "解锁新战车【末日防暴武装巴士】"},
	{"id": "ach_survive_waves_50", "cat": "chapter", "name": "🎖️ 废土常胜军", "desc": "累计存活超过 50 个战斗波次", "metric": "total_waves_survived", "target": 50, "rtype": "chips", "rid": "", "rname": "💎 150 原核晶片"},
	{"id": "ach_clear_hard_1", "cat": "chapter", "name": "💪 赏金硬汉", "desc": "在【困难模式】下成功通关任意章节", "metric": "clear_hard_count", "target": 1, "rtype": "chips", "rid": "", "rname": "💎 80 原核晶片"},
	{"id": "ach_clear_hard_all", "cat": "chapter", "name": "🌋 末日行者", "desc": "在【困难模式】下成功通关全部 5 大章节", "metric": "clear_hard_all", "target": 1, "rtype": "chassis_skin", "rid": "ch_tyrannos_volcano", "rname": "解锁暴龙车皮肤【熔岩暴龙】"},
	{"id": "ach_clear_hell", "cat": "chapter", "name": "👹 梦魇主宰", "desc": "在【地狱模式】下成功通关第 1 章节", "metric": "clear_hell_count", "target": 1, "rtype": "chassis", "rid": "tyrannos", "rname": "解锁新战车【暴龙机神】"},
	{"id": "ach_meta_up_1", "cat": "meta", "name": "💡 初窥门径", "desc": "在特斯拉实验室使用原核晶片升级 1 次永久科技", "metric": "meta_upgrades_purchased", "target": 1, "rtype": "chips", "rid": "", "rname": "💎 20 原核晶片"},
	{"id": "ach_meta_up_10", "cat": "meta", "name": "🔬 科技先锋", "desc": "在特斯拉实验室累计升级 10 次永久科技", "metric": "meta_upgrades_purchased", "target": 10, "rtype": "chips", "rid": "", "rname": "💎 60 原核晶片"},
	{"id": "ach_meta_max_1", "cat": "meta", "name": "⚙️ 极限科技", "desc": "将特斯拉实验室中任意一项永久科技提升至满级", "metric": "meta_maxed_count", "target": 1, "rtype": "chips", "rid": "", "rname": "💎 100 原核晶片"},
	{"id": "ach_chips_1000", "cat": "meta", "name": "💎 晶片达人", "desc": "生涯累计获得超过 1000 颗原核晶片", "metric": "total_chips_earned", "target": 1000, "rtype": "chips", "rid": "", "rname": "💎 100 原核晶片"},
	{"id": "ach_chips_5000", "cat": "meta", "name": "🏦 晶片巨贾", "desc": "生涯累计获得超过 5000 颗原核晶片", "metric": "total_chips_earned", "target": 5000, "rtype": "chips", "rid": "", "rname": "💎 250 原核晶片"},
	{"id": "ach_feature_lock", "cat": "meta", "name": "🔒 商业战术", "desc": "在实验室解锁【军火库商品锁定器】局外特性", "metric": "feature_shop_lock", "target": 1, "rtype": "chips", "rid": "", "rname": "💎 50 原核晶片"},
	{"id": "ach_custom_paint", "cat": "meta", "name": "🎨 涂装大师", "desc": "在局外战车涂装工坊中成功保存 1 次自定义车体涂色", "metric": "custom_paint_saved", "target": 1, "rtype": "chips", "rid": "", "rname": "💎 50 原核晶片"},
	{"id": "ach_toxic_20", "cat": "meta", "name": "🧪 毒抗淬炼", "desc": "在毒沼毒雾中承受累计 20 次接触腐蚀未阵亡", "metric": "toxic_survived", "target": 20, "rtype": "hunter_skin", "rid": "ma_alchemist", "rname": "解锁伊戈尔皮肤【鸟嘴炼金】"},
	{"id": "ach_intercept_10", "cat": "tactics", "name": "🛡️ 铁幕守护", "desc": "使用战车迎击系统累计击落 10 枚敌方导弹或飞弹", "metric": "intercept_count", "target": 10, "rtype": "chips", "rid": "", "rname": "💎 40 原核晶片"},
	{"id": "ach_intercept_50", "cat": "tactics", "name": "📡 绝对防御圈", "desc": "使用战车迎击系统累计击落 50 枚敌方导弹或飞弹", "metric": "intercept_count", "target": 50, "rtype": "chips", "rid": "", "rname": "💎 100 原核晶片"},
]

func get_achievement(ach_id: String) -> Dictionary:
	for a in ACHIEVEMENTS:
		if a["id"] == ach_id:
			return a
	return {}

func get_hunter_skins(hunter_id: String) -> Array:
	return HUNTER_SKINS.get(hunter_id, [])

func get_chassis_skins(chassis_id: String) -> Array:
	return CHASSIS_SKINS.get(chassis_id, [])

func get_chassis_skin_def(chassis_id: String, skin_id: String) -> Dictionary:
	for s in get_chassis_skins(chassis_id):
		if s["id"] == skin_id:
			return s
	return {}

func get_hunter_skin_def(hunter_id: String, skin_id: String) -> Dictionary:
	for s in get_hunter_skins(hunter_id):
		if s["id"] == skin_id:
			return s
	return {}
