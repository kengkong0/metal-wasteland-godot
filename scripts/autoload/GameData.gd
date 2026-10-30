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
		"unlock_cost": 0,
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
		"unlock_cost": 120,
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
		"unlock_cost": 0,
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
		"unlock_cost": 160,
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
		"unlock_cost": 220,
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
		"unlock_cost": 280,
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
		"unlock_cost": 0,
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
		"unlock_cost": 150,
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
		"unlock_cost": 0,
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
		"unlock_cost": 150,
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
		"unlock_cost": 320,
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
		"unlock_cost": 200,
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
		"unlock_cost": 240,
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
		"unlock_cost": 400,
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
		"weight": 1.8, "base_dmg": 38.0, "cooldown": 1.1, "ammo": 30, "cost": 45,
		"proj_speed": 720.0, "splash": 32.0, "burst": 3, "tags": ["artillery"],
		"desc": "三连发高速穿甲机炮，轻便省重，几乎不挤占SP装甲。"
	},
	"cannon_105mm": {
		"id": "cannon_105mm", "name": "105mm 皇家加农", "slot": "MAIN", "min_rarity": 0,
		"weight": 4.5, "base_dmg": 115.0, "cooldown": 2.0, "ammo": 18, "cost": 70,
		"proj_speed": 650.0, "splash": 85.0, "burst": 1, "tags": ["artillery"],
		"desc": "标准主力加农炮，命中后引发半径85m高爆冲击波。"
	},
	"cannon_cement": {
		"id": "cannon_cement", "name": "水泥弹发射器", "slot": "MAIN", "min_rarity": 1,
		"weight": 3.5, "base_dmg": 70.0, "cooldown": 2.3, "ammo": 16, "cost": 80,
		"proj_speed": 560.0, "splash": 110.0, "burst": 1, "effect": "cement", "tags": ["artillery", "bio"],
		"desc": "废土经典控场神器！命中使范围敌人减速60%并削减25点护甲。"
	},
	"cannon_195mm": {
		"id": "cannon_195mm", "name": "195mm 爆裂巨炮", "slot": "MAIN", "min_rarity": 2,
		"weight": 8.0, "base_dmg": 245.0, "cooldown": 3.0, "ammo": 12, "cost": 125,
		"proj_speed": 600.0, "splash": 125.0, "burst": 1, "effect": "cluster", "tags": ["artillery"],
		"desc": "重型火炮，爆炸时向四周分裂出 5 颗子母高爆弹二次轰炸。"
	},
	"cannon_205_peony": {
		"id": "cannon_205_peony", "name": "205mm 绯红牡丹", "slot": "MAIN", "min_rarity": 3,
		"weight": 10.5, "base_dmg": 390.0, "cooldown": 3.5, "ammo": 10, "cost": 175,
		"proj_speed": 680.0, "splash": 135.0, "burst": 1, "crit_bonus": 0.35, "tags": ["artillery"],
		"desc": "名炮【绯红牡丹】！极高暴击倍率(2.5x)，对半血以下目标必定暴击。"
	},
	"cannon_cosmic_laser": {
		"id": "cannon_cosmic_laser", "name": "SE-宇宙激光主炮", "slot": "MAIN", "min_rarity": 3,
		"weight": 7.0, "base_dmg": 210.0, "cooldown": 2.5, "ammo": 999, "cost": 165,
		"proj_speed": 1400.0, "splash": 45.0, "burst": 1, "pierce": 8, "effect": "laser", "tags": ["artillery", "bio"],
		"desc": "发射贯穿全屏的炽热激光束，无限弹药且无视敌方实弹护甲。"
	},
	"cannon_220_gaia": {
		"id": "cannon_220_gaia", "name": "220mm 盖亚之怒", "slot": "MAIN", "min_rarity": 4,
		"weight": 16.0, "base_dmg": 780.0, "cooldown": 4.4, "ammo": 8, "cost": 260,
		"proj_speed": 620.0, "splash": 210.0, "burst": 1, "effect": "cluster", "tags": ["artillery", "juggernaut"],
		"desc": "【传奇红武】重达16吨的毁灭巨炮，一发轰平半个屏幕！"
	},

	# --- 副炮系列 (SUB) ---
	"mg_77mm": {
		"id": "mg_77mm", "name": "7.7mm 轻机枪", "slot": "SUB", "min_rarity": 0,
		"weight": 0.5, "base_dmg": 10.0, "cooldown": 0.20, "cost": 30,
		"proj_speed": 780.0, "range": 420.0, "tags": ["tycoon"],
		"desc": "仅重0.5吨的超轻机枪，自动点射最近敌人。"
	},
	"mg_vulcan": {
		"id": "mg_vulcan", "name": "火神六管加特林", "slot": "SUB", "min_rarity": 1,
		"weight": 2.2, "base_dmg": 15.0, "cooldown": 0.10, "cost": 65,
		"proj_speed": 820.0, "range": 440.0, "tags": ["artillery"],
		"desc": "每秒10发高密度金属风暴，压制贴脸机械虫群。"
	},
	"sub_flame": {
		"id": "sub_flame", "name": "地狱火焰喷射器", "slot": "SUB", "min_rarity": 1,
		"weight": 1.8, "base_dmg": 14.0, "cooldown": 0.16, "cost": 60,
		"proj_speed": 420.0, "range": 280.0, "pierce": 4, "effect": "burn", "tags": ["bio"],
		"desc": "扇形贯穿火海，为敌人叠加【灼烧】持续百分比掉血。"
	},
	"sub_acid": {
		"id": "sub_acid", "name": "强酸腐蚀喷雾器", "slot": "SUB", "min_rarity": 1,
		"weight": 1.6, "base_dmg": 16.0, "cooldown": 0.28, "cost": 70,
		"proj_speed": 520.0, "range": 380.0, "effect": "acid", "tags": ["bio"],
		"desc": "每次命中永久腐蚀目标 6 点护甲(可减为负数使全队对其增伤)！"
	},
	"sub_tesla": {
		"id": "sub_tesla", "name": "特斯拉连锁电弧", "slot": "SUB", "min_rarity": 2,
		"weight": 2.0, "base_dmg": 28.0, "cooldown": 0.38, "cost": 90,
		"proj_speed": 900.0, "range": 420.0, "chain": 4, "effect": "electric", "tags": ["bio", "missile"],
		"desc": "发射高压闪电在4个目标间弹跳，并克制护盾与水母类赏金首。"
	},
	"sub_shotgun": {
		"id": "sub_shotgun", "name": "废铁霰弹轰击炮", "slot": "SUB", "min_rarity": 1,
		"weight": 2.5, "base_dmg": 19.0, "cooldown": 0.65, "cost": 65,
		"proj_speed": 640.0, "range": 320.0, "pellets": 6, "tags": ["tycoon", "juggernaut"],
		"desc": "近距离一次轰出6颗废铁弹丸并击退敌人。"
	},

	# --- S-E 特殊装备系列 (SE) ---
	"se_atm": {
		"id": "se_atm", "name": "ATM 追踪导弹箱", "slot": "SE", "min_rarity": 0,
		"weight": 2.0, "base_dmg": 48.0, "cooldown": 3.4, "cost": 55,
		"salvo": 4, "effect": "homing", "tags": ["missile"],
		"desc": "每轮齐射 4 枚自动追踪全场高威胁目标的穿甲导弹。"
	},
	"se_tornado": {
		"id": "se_tornado", "name": "龙卷风12联装火箭", "slot": "SE", "min_rarity": 2,
		"weight": 5.2, "base_dmg": 42.0, "cooldown": 5.2, "cost": 120,
		"salvo": 12, "effect": "homing", "tags": ["missile"],
		"desc": "一次性倾泻 12 枚追踪导弹洗地！配合【全弹发射】瞬间清屏。"
	},
	"se_aegis": {
		"id": "se_aegis", "name": "宙斯盾迎击激光网", "slot": "SE", "min_rarity": 1,
		"weight": 1.5, "base_dmg": 35.0, "cooldown": 0.75, "cost": 75,
		"effect": "intercept", "tags": ["missile", "juggernaut"],
		"desc": "自动用激光击落飞向战车的敌方子弹/鱼雷，每次拦截回复 6 SP！"
	},
	"se_spike_ball": {
		"id": "se_spike_ball", "name": "旋转刺球撞角", "slot": "SE", "min_rarity": 1,
		"weight": 4.0, "base_dmg": 65.0, "cooldown": 0.5, "cost": 70,
		"effect": "orbit_ball", "tags": ["juggernaut", "lone_cub"],
		"desc": "两颗重型尖刺铁球环绕战车高速旋转，伤害享受战车总吨位加成！"
	},
	"se_drone": {
		"id": "se_drone", "name": "浮游维修无人机", "slot": "SE", "min_rarity": 2,
		"weight": 1.2, "base_dmg": 24.0, "cooldown": 0.45, "cost": 85,
		"effect": "repair_drone", "tags": ["lone_cub", "tycoon"],
		"desc": "环绕战车自动发射脉冲激光，并每秒为战车修复 18 SP。"
	},
	"se_sonic": {
		"id": "se_sonic", "name": "立体声震荡音波炮", "slot": "SE", "min_rarity": 2,
		"weight": 2.8, "base_dmg": 95.0, "cooldown": 4.0, "cost": 95,
		"effect": "sonic_wave", "tags": ["bio", "juggernaut"],
		"desc": "释放穿透一切护甲与潜沙状态的环形音波，震退并眩晕周围敌人。"
	},

	# --- 赏金首专属掉落红武 (BOSS DROPS) ---
	"boss_shark_torpedo": {
		"id": "boss_shark_torpedo", "name": "【赏金红武】沙鲨钻地鱼雷", "slot": "MAIN", "min_rarity": 4,
		"weight": 6.5, "base_dmg": 340.0, "cooldown": 2.4, "ammo": 20, "cost": 220,
		"proj_speed": 640.0, "splash": 140.0, "burst": 2, "effect": "acid", "tags": ["artillery", "missile"],
		"desc": "击败【沙漠之鲛】战利品！一次连射2枚钻地追踪重型鱼雷。"
	},
	"boss_yamato_cannon": {
		"id": "boss_yamato_cannon", "name": "【赏金红武】沙漠之舟·大和炮", "slot": "MAIN", "min_rarity": 4,
		"weight": 13.0, "base_dmg": 460.0, "cooldown": 3.4, "ammo": 15, "cost": 300,
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
		"crit_bonus": 0.08, "all_out_cd": 12.0,
		"desc": "暴击率 +8%。可按 [Q] 触发【全弹发射】(冷却12秒)。"
	},
	"cu_solomon2": {
		"id": "cu_solomon2", "name": "所罗门 2 型 (全弹核心)", "rarity": 2, "weight": 1.5, "cost": 130,
		"crit_bonus": 0.12, "all_out_cd": 7.5, "se_dmg_bonus": 0.30,
		"desc": "【全弹发射】冷却缩短至 7.5秒 且自动触发！S-E 伤害 +30%。"
	},
	"cu_type99": {
		"id": "cu_type99", "name": "99式神话火控", "rarity": 3, "weight": 1.6, "cost": 165,
		"crit_bonus": 0.25, "all_out_cd": 10.0, "double_shot_chance": 0.30,
		"desc": "暴击率 +25%，主炮每次开火有 30% 概率触发【免费二连射】！"
	},
	"cu_mirage": {
		"id": "cu_mirage", "name": "幻影全息系统", "rarity": 2, "weight": 1.0, "cost": 120,
		"dodge_bonus": 0.25, "all_out_cd": 10.0, "decoy_blast": true,
		"desc": "战车闪避率 +25%，每次成功闪避对周围敌人释放一次全息脉冲。"
	},
	"cu_valkyrie": {
		"id": "cu_valkyrie", "name": "瓦尔基里自律战斗AI", "rarity": 3, "weight": 1.8, "cost": 160,
		"crit_bonus": 0.15, "all_out_cd": 9.0, "auto_turret_wreck": true,
		"desc": "按[E]下车或战车大破时，战车仍会继续自动开火支援，实现【人车同屏双打】！"
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
		"enemy_pool": ["bio_ant", "bionic_hound", "kamikaze_wheel", "sand_turret"],
		"elite_pool": ["auto_tank"],
		"regional_boss_id": "boss_killdozer",
		"final_boss_id": "boss_jelly",
		"bg_color": Color(0.22, 0.18, 0.13),
		"grid_color": Color(0.27, 0.22, 0.16),
		"border_color": Color(0.85, 0.52, 0.18),
		"desc": "【荒野起点】小怪：机械蚁/猎犬/滚雷车/机枪塔 | 精英：杀戮重坦 | 赏金首：【杀人推土机】&【加农水母】"
	},
	{
		"id": "map_2",
		"index": 1,
		"name": "第2章：死亡大沙漠·流沙遗迹",
		"waves": 10,
		"hp_mult": 1.65,
		"dmg_mult": 1.35,
		"chip_mult": 1.40,
		"enemy_pool": ["bionic_hound", "gas_walker", "acid_snail", "mortar_crab"],
		"elite_pool": ["elite_flame_juggernaut", "auto_tank"],
		"regional_boss_id": "boss_sand_shark",
		"final_boss_id": "boss_skunks",
		"bg_color": Color(0.28, 0.19, 0.11),
		"grid_color": Color(0.35, 0.24, 0.14),
		"border_color": Color(0.95, 0.65, 0.20),
		"desc": "【炽热沙海】小怪：猎犬/毒气桶/酸蜗牛/迫击炮蟹 | 精英：喷火装甲车 | 赏金首：【深沙巨鲛】&【狂飙斯卡普】"
	},
	{
		"id": "map_3",
		"index": 2,
		"name": "第3章：铁道废墟·百足峡谷",
		"waves": 10,
		"hp_mult": 2.50,
		"dmg_mult": 1.75,
		"chip_mult": 1.85,
		"enemy_pool": ["sand_turret", "sniper_cannon", "shield_mecha", "repair_bot"],
		"elite_pool": ["elite_missile_mammoth", "auto_tank"],
		"regional_boss_id": "boss_centipede",
		"final_boss_id": "boss_gomez",
		"bg_color": Color(0.15, 0.16, 0.18),
		"grid_color": Color(0.21, 0.22, 0.25),
		"border_color": Color(0.50, 0.75, 0.92),
		"desc": "【工业废墟】小怪：远程狙击炮/护盾卫士/战地维修蜂 | 精英：导弹巨兽 | 赏金首：【百足列车】&【劫掠王巴洛克】"
	},
	{
		"id": "map_4",
		"index": 3,
		"name": "第4章：恶魔跨海大桥·枯竭海床",
		"waves": 10,
		"hp_mult": 3.80,
		"dmg_mult": 2.25,
		"chip_mult": 2.40,
		"enemy_pool": ["gas_walker", "acid_snail", "mortar_crab", "emp_spider", "repair_bot"],
		"elite_pool": ["elite_missile_mammoth", "elite_flame_juggernaut"],
		"regional_boss_id": "boss_chimera",
		"final_boss_id": "boss_desert_boat",
		"bg_color": Color(0.10, 0.18, 0.15),
		"grid_color": Color(0.15, 0.25, 0.21),
		"border_color": Color(0.35, 0.92, 0.55),
		"desc": "【生化海床】小怪：迫击炮蟹/磁暴蛛/毒气桶/维修蜂 | 精英：导弹巨兽 | 赏金首：【奇美拉】&【沙漠之舟】"
	},
	{
		"id": "map_5",
		"index": 4,
		"name": "第5章：人类终焉中枢·深层地核",
		"waves": 10,
		"hp_mult": 5.50,
		"dmg_mult": 3.00,
		"chip_mult": 3.50,
		"enemy_pool": ["sniper_cannon", "mortar_crab", "shield_mecha", "repair_bot", "emp_spider"],
		"elite_pool": ["elite_cyber_executioner", "elite_missile_mammoth", "elite_flame_juggernaut"],
		"regional_boss_id": "boss_bighemoth",
		"final_boss_id": "boss_noah",
		"bg_color": Color(0.13, 0.09, 0.18),
		"grid_color": Color(0.20, 0.13, 0.28),
		"border_color": Color(0.95, 0.25, 0.60),
		"desc": "【终局要塞】全特种军团混编 | 精英：天穹量子处决者 | 赏金首：【重装帕鲁】&【终焉主脑·原核矩阵】"
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
		"desc": "标准废土兽潮强度，开局额外+20G；【显示流派与超武配件提示】，通关解锁下一张地图！"
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
		"desc": "敌军生命×1.45、伤害×1.35、密度+22%！【显示流派与超武配件提示】，结算原核晶片 ×1.40！"
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
		"desc": "敌军生命×2.35、伤害×1.90、密度+50%！【硬核盲配：隐藏所有流派与超武合成提示】，结算原核晶片 ×2.30！"
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

