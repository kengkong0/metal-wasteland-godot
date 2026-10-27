extends Node
## 《重装废土：赏金狂飙》 - 全局状态机、局外永久存档与《重装机兵》载重=SP 核心公式引擎

signal stats_updated
signal meta_updated
signal level_up_triggered
signal super_weapon_evolved(evo_info: Dictionary)

const SAVE_PATH: String = "user://metal_wasteland_save.json"

# ============================================================================
# 一、 局外永久养成与轮回存档数据 (Meta-Progression)
# ============================================================================
var noah_chips: int = 160 # 局外永久货币：诺亚晶片 💎 (新档默认赠送160晶片供体验)
var unlocked_hunters: Array = ["bounty_hunter", "mechanic"]
var unlocked_chassis: Array = ["buggy", "abrams"]
var unlocked_features: Array = []
var meta_upgrade_levels: Dictionary = {}
var unlocked_map_count: int = 1
var map_cleared_difficulties: Dictionary = {} # {"map_1": ["easy", "normal"]}

var lifetime_runs: int = 0
var lifetime_kills: int = 0
var lifetime_bounties: int = 0
var best_wave: int = 1

# ============================================================================
# 二、 局内单次轮回状态数据 (In-Run State)
# ============================================================================
var selected_hunter_id: String = "bounty_hunter"
var selected_chassis_id: String = "buggy"
var selected_map_idx: int = 0
var selected_difficulty_id: String = "normal"
var current_wave: int = 1
var max_waves: int = 10

var gold: int = 120
var xp: int = 0
var level: int = 1
var xp_to_next: int = 12
var pending_level_ups: int = 0

var total_kills: int = 0
var bounties_hunted: int = 0
var mince_free_revive_available: bool = true
var field_defib_available: bool = false
var auto_main_cannon: bool = true
var run_already_settled: bool = false

# --- 战车改装与槽位状态 ---
var chassis_slots: Array = []
var equipped_weapons: Array = [] # [{"id": "cannon_105mm", "rarity": 0}]
var equipped_engine_id: String = "eng_bulldog_v8"
var equipped_c_unit_id: String = "cu_type66"

# --- 赏金首通缉令状态 ---
var active_wanted_boss_id: String = "" # 下一波即将乱入的赏金首
var defeated_wanted_ids: Array = []
var wanted_poster_offset: int = 0

# --- 实时计算的战车与猎人面板属性 ---
var max_weight: float = 20.0
var used_weight: float = 5.0
var free_weight: float = 15.0
var overweight_tons: float = 0.0

var max_sp: float = 800.0
var max_human_hp: float = 180.0
var sp_regen_per_sec: float = 5.0
var move_speed: float = 220.0
var crit_chance: float = 0.10
var dodge_chance: float = 0.05
var pickup_range: float = 140.0

var bonus_stats: Dictionary = {}
var synergy_counts: Dictionary = {}

func _ready() -> void:
	_init_default_meta()
	load_meta_save()

func _init_default_meta() -> void:
	for u in GameData.META_UPGRADES:
		meta_upgrade_levels[u["id"]] = 0

# --- 存档读写与局外解锁接口 ---
func save_meta_data() -> void:
	var data: Dictionary = {
		"noah_chips": noah_chips,
		"unlocked_hunters": unlocked_hunters,
		"unlocked_chassis": unlocked_chassis,
		"unlocked_features": unlocked_features,
		"meta_upgrade_levels": meta_upgrade_levels,
		"unlocked_map_count": unlocked_map_count,
		"map_cleared_difficulties": map_cleared_difficulties,
		"lifetime_runs": lifetime_runs,
		"lifetime_kills": lifetime_kills,
		"lifetime_bounties": lifetime_bounties,
		"best_wave": best_wave
	}
	var f := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if f:
		f.store_string(JSON.stringify(data, "\t"))
		f.close()
	emit_signal("meta_updated")

func load_meta_save() -> void:
	if not FileAccess.file_exists(SAVE_PATH):
		save_meta_data()
		return
	var f := FileAccess.open(SAVE_PATH, FileAccess.READ)
	if not f:
		return
	var text: String = f.get_as_text()
	f.close()
	var parsed: Variant = JSON.parse_string(text)
	if typeof(parsed) == TYPE_DICTIONARY:
		var d: Dictionary = parsed
		noah_chips = int(d.get("noah_chips", 160))
		unlocked_hunters = d.get("unlocked_hunters", ["bounty_hunter", "mechanic"])
		unlocked_chassis = d.get("unlocked_chassis", ["buggy", "abrams"])
		unlocked_features = d.get("unlocked_features", [])
		unlocked_map_count = clampi(int(d.get("unlocked_map_count", 1)), 1, GameData.MAPS.size())
		map_cleared_difficulties = d.get("map_cleared_difficulties", {})
		var saved_lv: Dictionary = d.get("meta_upgrade_levels", {})
		for k in saved_lv.keys():
			meta_upgrade_levels[k] = int(saved_lv[k])
		lifetime_runs = int(d.get("lifetime_runs", 0))
		lifetime_kills = int(d.get("lifetime_kills", 0))
		lifetime_bounties = int(d.get("lifetime_bounties", 0))
		best_wave = int(d.get("best_wave", 1))

func reset_meta_save() -> void:
	noah_chips = 160
	unlocked_hunters = ["bounty_hunter", "mechanic"]
	unlocked_chassis = ["buggy", "abrams"]
	unlocked_features = []
	unlocked_map_count = 1
	map_cleared_difficulties = {}
	_init_default_meta()
	lifetime_runs = 0
	lifetime_kills = 0
	lifetime_bounties = 0
	best_wave = 1
	selected_hunter_id = "bounty_hunter"
	selected_chassis_id = "buggy"
	selected_map_idx = 0
	selected_difficulty_id = "normal"
	save_meta_data()

func is_hunter_unlocked(h_id: String) -> bool:
	return h_id in unlocked_hunters or int(GameData.HUNTERS.get(h_id, {}).get("unlock_cost", 0)) <= 0

func unlock_hunter(h_id: String) -> bool:
	if is_hunter_unlocked(h_id):
		return true
	var cost: int = int(GameData.HUNTERS.get(h_id, {}).get("unlock_cost", 999))
	if noah_chips < cost:
		return false
	noah_chips -= cost
	unlocked_hunters.append(h_id)
	save_meta_data()
	return true

func is_chassis_unlocked(c_id: String) -> bool:
	return c_id in unlocked_chassis or int(GameData.CHASSIS.get(c_id, {}).get("unlock_cost", 0)) <= 0

func unlock_chassis(c_id: String) -> bool:
	if is_chassis_unlocked(c_id):
		return true
	var cost: int = int(GameData.CHASSIS.get(c_id, {}).get("unlock_cost", 999))
	if noah_chips < cost:
		return false
	noah_chips -= cost
	unlocked_chassis.append(c_id)
	save_meta_data()
	return true

func is_feature_unlocked(f_id: String) -> bool:
	return f_id in unlocked_features

func unlock_feature(f_id: String) -> bool:
	if is_feature_unlocked(f_id):
		return true
	for f in GameData.META_FEATURES:
		if f["id"] == f_id:
			var cost: int = int(f["cost"])
			if noah_chips < cost:
				return false
			noah_chips -= cost
			unlocked_features.append(f_id)
			save_meta_data()
			return true
	return false

func get_meta_level(u_id: String) -> int:
	return int(meta_upgrade_levels.get(u_id, 0))

func get_meta_upgrade_cost(u_def: Dictionary) -> int:
	var lv: int = get_meta_level(u_def["id"])
	return int(u_def["base_cost"]) + lv * int(u_def["cost_step"])

func upgrade_meta_stat(u_id: String) -> bool:
	for u in GameData.META_UPGRADES:
		if u["id"] == u_id:
			var lv: int = get_meta_level(u_id)
			if lv >= int(u["max_lv"]):
				return false
			var cost: int = get_meta_upgrade_cost(u)
			if noah_chips < cost:
				return false
			noah_chips -= cost
			meta_upgrade_levels[u_id] = lv + 1
			save_meta_data()
			return true
	return false

func get_current_map_def() -> Dictionary:
	var idx: int = clampi(selected_map_idx, 0, GameData.MAPS.size() - 1)
	return GameData.MAPS[idx]

func get_current_difficulty_def() -> Dictionary:
	return GameData.DIFFICULTIES.get(selected_difficulty_id, GameData.DIFFICULTIES["normal"])

func should_show_build_hints() -> bool:
	return bool(get_current_difficulty_def().get("show_hints", true))

func get_enemy_hp_multiplier() -> float:
	return float(get_current_map_def()["hp_mult"]) * float(get_current_difficulty_def()["hp_mult"])

func get_enemy_dmg_multiplier() -> float:
	return float(get_current_map_def()["dmg_mult"]) * float(get_current_difficulty_def()["dmg_mult"])

func get_enemy_speed_multiplier() -> float:
	return float(get_current_difficulty_def()["speed_mult"])

# --- 轮回结束结算：将本局波次、击杀、赏金首与金币折算为【诺亚晶片 💎】并判定解锁下一张地图 ---
func settle_run_rewards(is_victory: bool) -> Dictionary:
	if run_already_settled:
		return {"total": 0, "wave_chips": 0, "kill_chips": 0, "boss_chips": 0, "gold_chips": 0, "win_chips": 0, "chip_mult": 1.0, "unlocked_next_map": ""}
	run_already_settled = true

	var m_def: Dictionary = get_current_map_def()
	var d_def: Dictionary = get_current_difficulty_def()
	var chip_mult: float = float(m_def["chip_mult"]) * float(d_def["chip_mult"])

	var wave_chips: int = current_wave * 18
	var kill_chips: int = total_kills * 1
	var boss_chips: int = bounties_hunted * 80
	var gold_chips: int = int(gold / 10)
	var win_chips: int = 320 if is_victory else 0
	var raw_sum: int = wave_chips + kill_chips + boss_chips + gold_chips + win_chips
	var total_earned: int = int(roundf(float(raw_sum) * chip_mult))

	var newly_unlocked_map_name: String = ""
	if is_victory:
		var m_id: String = m_def["id"]
		var cleared_arr: Array = map_cleared_difficulties.get(m_id, [])
		if not (selected_difficulty_id in cleared_arr):
			cleared_arr.append(selected_difficulty_id)
		map_cleared_difficulties[m_id] = cleared_arr

		if selected_map_idx + 1 >= unlocked_map_count and unlocked_map_count < GameData.MAPS.size():
			unlocked_map_count = selected_map_idx + 2
			newly_unlocked_map_name = GameData.MAPS[unlocked_map_count - 1]["name"]

	noah_chips += total_earned
	lifetime_runs += 1
	lifetime_kills += total_kills
	lifetime_bounties += bounties_hunted
	best_wave = max(best_wave, current_wave)
	save_meta_data()

	return {
		"total": total_earned,
		"wave_chips": wave_chips,
		"kill_chips": kill_chips,
		"boss_chips": boss_chips,
		"gold_chips": gold_chips,
		"win_chips": win_chips,
		"chip_mult": chip_mult,
		"unlocked_next_map": newly_unlocked_map_name
	}

# ============================================================================
# 三、 开启新轮回与局内外数值融合计算
# ============================================================================
func start_new_run(hunter_id: String, chassis_id: String, map_idx: int = -1, diff_id: String = "") -> void:
	selected_hunter_id = hunter_id
	selected_chassis_id = chassis_id
	if map_idx >= 0:
		selected_map_idx = clampi(map_idx, 0, GameData.MAPS.size() - 1)
	if diff_id != "":
		selected_difficulty_id = diff_id

	var m_def: Dictionary = get_current_map_def()
	var d_def: Dictionary = get_current_difficulty_def()
	current_wave = 1
	max_waves = int(m_def.get("waves", 10))
	gold = 120 + get_meta_level("meta_start_gold") * 35 + int(d_def.get("bonus_start_gold", 0))
	xp = 0
	level = 1
	xp_to_next = 10
	pending_level_ups = 0
	total_kills = 0
	bounties_hunted = 0
	mince_free_revive_available = true
	field_defib_available = is_feature_unlocked("mince_defib_lv2")
	active_wanted_boss_id = ""
	defeated_wanted_ids.clear()
	wanted_poster_offset = 0
	run_already_settled = false

	# 注入局外永久科技树加成 (META_UPGRADES)
	var lv_weight: int = get_meta_level("meta_weight")
	var lv_sp: int = get_meta_level("meta_sp")
	var lv_dmg: int = get_meta_level("meta_dmg")
	var lv_reload: int = get_meta_level("meta_reload")
	var lv_crit: int = get_meta_level("meta_crit_dodge")
	var lv_rep: int = get_meta_level("meta_repair")
	var lv_mag: int = get_meta_level("meta_magnet_gold")

	bonus_stats = {
		"main_dmg_pct": lv_dmg * 0.06,
		"sub_dmg_pct": lv_dmg * 0.06,
		"elemental_dmg_pct": lv_dmg * 0.06,
		"boss_dmg_pct": 0.0,
		"max_weight_pct": lv_weight * 0.05,
		"sp_per_ton_pct": 0.0,
		"sp_regen_pct": 0.0,
		"flat_sp_regen": lv_rep * 12.0,
		"reload_speed_pct": lv_reload * 0.04,
		"move_speed_pct": 0.0,
		"crit_chance": 0.08 + lv_crit * 0.025,
		"dodge": lv_crit * 0.02,
		"gold_gain_pct": lv_mag * 0.08,
		"flat_sp_bonus": lv_sp * 60.0
	}

	var hunter: Dictionary = GameData.HUNTERS.get(hunter_id, GameData.HUNTERS["bounty_hunter"])
	var h_mods: Dictionary = hunter.get("mods", {})
	for k in h_mods.keys():
		if typeof(h_mods[k]) in [TYPE_FLOAT, TYPE_INT] and bonus_stats.has(k):
			bonus_stats[k] += float(h_mods[k])
		else:
			bonus_stats[k] = h_mods[k]

	# 初始化底盘孔位与初始武器
	var ch: Dictionary = GameData.CHASSIS.get(chassis_id, GameData.CHASSIS["buggy"])
	chassis_slots.clear()
	for s in ch["slots"]:
		if bonus_stats.get("no_main_cannon", false) and s == "MAIN":
			chassis_slots.append("SUB")
		else:
			chassis_slots.append(String(s))

	equipped_engine_id = ch.get("starter_engine", "eng_bulldog_v8")
	equipped_c_unit_id = ch.get("starter_c_unit", "cu_type66")

	equipped_weapons.clear()
	var starters: Array = ch.get("starter_weapons", ["cannon_45mm", "mg_77mm"])
	for w_id in starters:
		var actual_id: String = String(w_id)
		if bonus_stats.get("no_main_cannon", false) and GameData.WEAPONS[actual_id]["slot"] == "MAIN":
			actual_id = "sub_shotgun"
		add_weapon_to_first_valid_slot(actual_id, 0)

	recalculate_stats()

func add_xp(amount: int) -> void:
	var mult: float = 1.0 + get_meta_level("meta_magnet_gold") * 0.08
	if synergy_counts.get("tycoon", 0) >= 4:
		mult += 0.30
	xp += int(ceil(float(amount) * mult))
	var leveled: bool = false
	while xp >= xp_to_next:
		xp -= xp_to_next
		level += 1
		pending_level_ups += 1
		xp_to_next = int(10 + level * 6 + pow(level, 1.45))
		leveled = true
	if leveled:
		emit_signal("level_up_triggered")

func add_gold(amount: int) -> void:
	var mult: float = 1.0 + bonus_stats.get("gold_gain_pct", 0.0)
	if synergy_counts.get("tycoon", 0) >= 4:
		mult += 0.30
	gold += int(ceil(float(amount) * mult))

# --- 核心计算：引擎载重 -> 剩余载重 -> 战车SP装甲片 ---
func recalculate_stats() -> void:
	var ch: Dictionary = GameData.CHASSIS.get(selected_chassis_id, GameData.CHASSIS["buggy"])
	var eng: Dictionary = GameData.ENGINES.get(equipped_engine_id, GameData.ENGINES["eng_bulldog_v8"])
	var cu: Dictionary = GameData.C_UNITS.get(equipped_c_unit_id, GameData.C_UNITS["cu_type66"])

	# 1. 统计流派羁绊数量
	synergy_counts.clear()
	for w_entry in equipped_weapons:
		var w_def: Dictionary = GameData.WEAPONS.get(w_entry["id"], {})
		for tag in w_def.get("tags", []):
			synergy_counts[tag] = synergy_counts.get(tag, 0) + 1

	# 2. 计算最大载重 W_max
	var eng_weight: float = float(eng.get("max_weight", 18.0))
	if ch.get("dual_engine", false):
		eng_weight *= 1.60 # 猛犸象双核驱动
	max_weight = eng_weight * (1.0 + bonus_stats.get("max_weight_pct", 0.0))

	# 3. 计算已用载重 W_equip
	used_weight = float(ch.get("base_weight", 5.0)) + float(cu.get("weight", 1.0))
	for w_entry in equipped_weapons:
		used_weight += get_weapon_effective_weight(w_entry["id"], w_entry.get("rarity", 0))

	free_weight = maxf(0.0, max_weight - used_weight)
	overweight_tons = maxf(0.0, used_weight - max_weight)

	# 4. 计算最大 SP (基础SP + 剩余吨位 * 底盘装甲转化率)
	var sp_per_ton: float = float(ch.get("sp_per_ton", 100.0))
	if synergy_counts.get("juggernaut", 0) >= 2:
		sp_per_ton += 30.0
	sp_per_ton *= (1.0 + bonus_stats.get("sp_per_ton_pct", 0.0))

	var raw_sp: float = float(ch.get("base_sp", 240.0)) + bonus_stats.get("flat_sp_bonus", 0.0) + free_weight * sp_per_ton
	max_sp = maxf(100.0, roundf(raw_sp))

	# 5. 计算移速 (含超载惩罚)
	var base_spd: float = float(ch.get("speed", 210.0))
	var spd_mult: float = 1.0 + bonus_stats.get("move_speed_pct", 0.0) + float(eng.get("speed_Bonus", 0.0))
	if overweight_tons > 0.0:
		spd_mult *= maxf(0.35, 1.0 - overweight_tons * 0.12)
	move_speed = base_spd * spd_mult

	# 6. 计算 SP 自动修复、暴击率、闪避率、拾取范围与步兵 HP
	sp_regen_per_sec = max_sp * bonus_stats.get("sp_regen_pct", 0.0) + bonus_stats.get("flat_sp_regen", 0.0)
	if selected_chassis_id == "tyrannos":
		sp_regen_per_sec += max_sp * 0.01
	if synergy_counts.get("lone_cub", 0) >= 4:
		sp_regen_per_sec += 25.0
	for w_entry in equipped_weapons:
		if w_entry["id"] == "se_drone":
			sp_regen_per_sec += 18.0 * (1.0 + 0.35 * w_entry.get("rarity", 0))
	if selected_chassis_id == "ambulance":
		sp_regen_per_sec *= 2.0

	crit_chance = clampf(bonus_stats.get("crit_chance", 0.08) + float(cu.get("crit_bonus", 0.0)), 0.0, 0.90)
	dodge_chance = clampf(bonus_stats.get("dodge", 0.05) + float(cu.get("dodge_bonus", 0.0)), 0.0, 0.75)
	pickup_range = 140.0 * (1.0 + get_meta_level("meta_magnet_gold") * 0.20)

	var h_mult: float = float(bonus_stats.get("human_hp_mult", 1.0))
	if synergy_counts.get("lone_cub", 0) >= 2:
		h_mult += 0.5
	var base_h_hp: float = 160.0 + get_meta_level("meta_sp") * 20.0 + level * 18.0
	max_human_hp = roundf(base_h_hp * h_mult)

	emit_signal("stats_updated")

func get_weapon_effective_weight(weapon_id: String, rarity: int) -> float:
	var w_def: Dictionary = GameData.WEAPONS.get(weapon_id, {})
	var w: float = float(w_def.get("weight", 2.0))
	if not w_def.get("is_evo", false):
		w *= (1.0 + float(rarity) * 0.10)
	if w_def.get("slot", "") == "SE" and selected_chassis_id == "missile_carrier":
		w *= 0.65
	if w_def.get("slot", "") == "MAIN" and synergy_counts.get("artillery", 0) >= 2:
		w *= 0.80
	return snappedf(w, 0.1)

func get_weapon_effective_damage(weapon_id: String, rarity: int) -> float:
	var w_def: Dictionary = GameData.WEAPONS.get(weapon_id, {})
	var base: float = float(w_def.get("base_dmg", 20.0))
	if not w_def.get("is_evo", false):
		base *= pow(1.65, float(rarity))

	var mult: float = 1.0
	var slot: String = w_def.get("slot", "SUB")
	var eng: Dictionary = GameData.ENGINES.get(equipped_engine_id, {})
	var cu: Dictionary = GameData.C_UNITS.get(equipped_c_unit_id, {})

	mult += float(eng.get("all_dmg_bonus", 0.0))
	if slot == "MAIN":
		mult += bonus_stats.get("main_dmg_pct", 0.0) + float(eng.get("main_dmg_bonus", 0.0))
		if synergy_counts.get("artillery", 0) >= 4:
			mult += 0.35
		if count_equipped_slot_type("MAIN") == 1:
			mult += bonus_stats.get("lone_main_dmg_pct", 0.0)
	else:
		mult += bonus_stats.get("sub_dmg_pct", 0.0)
		if slot == "SE":
			mult += float(cu.get("se_dmg_bonus", 0.0))

	if w_def.get("effect", "") in ["burn", "acid", "electric", "plague_fire", "omega_laser"]:
		mult += bonus_stats.get("elemental_dmg_pct", 0.0)
		if synergy_counts.get("bio", 0) >= 2:
			mult += 0.30

	if synergy_counts.get("lone_cub", 0) >= 6:
		mult += 0.45
	if synergy_counts.get("tycoon", 0) >= 6:
		mult += floorf(float(gold) / 100.0) * 0.08

	return roundf(maxf(2.0, base * mult))

func count_equipped_slot_type(slot_type: String) -> int:
	var c: int = 0
	for w in equipped_weapons:
		var def: Dictionary = GameData.WEAPONS.get(w["id"], {})
		if def.get("slot", "") == slot_type:
			c += 1
	return c

func can_equip_or_merge(weapon_id: String, rarity: int) -> bool:
	if rarity < 4:
		for w in equipped_weapons:
			if w["id"] == weapon_id and w.get("rarity", 0) == rarity:
				return true
	var slot_needed: String = GameData.WEAPONS[weapon_id]["slot"]
	return get_free_slot_count(slot_needed) > 0

func get_free_slot_count(slot_type: String) -> int:
	var total_slots: int = 0
	for s in chassis_slots:
		if s == slot_type:
			total_slots += 1
	var used_slots: int = count_equipped_slot_type(slot_type)
	return max(0, total_slots - used_slots)

func add_weapon_to_first_valid_slot(weapon_id: String, rarity: int, check_evo: bool = false) -> Dictionary:
	if rarity < 4:
		for i in range(equipped_weapons.size()):
			var w: Dictionary = equipped_weapons[i]
			if w["id"] == weapon_id and w.get("rarity", 0) == rarity:
				w["rarity"] = rarity + 1
				var evos: Array = []
				if check_evo:
					evos = try_trigger_super_evolutions(false)
				recalculate_stats()
				return {"merged": true, "new_rarity": w["rarity"], "evos": evos}

	var slot_needed: String = GameData.WEAPONS[weapon_id]["slot"]
	if get_free_slot_count(slot_needed) > 0:
		equipped_weapons.append({"id": weapon_id, "rarity": rarity})
		var evos: Array = []
		if check_evo:
			evos = try_trigger_super_evolutions(false)
		recalculate_stats()
		return {"merged": false, "equipped": true, "evos": evos}

	return {"merged": false, "equipped": false, "evos": []}

# --- 检查某把候选武器是否能与当前车上的武器配对合成【神话超武】 ---
func check_super_evolution_partner(candidate_id: String) -> String:
	for recipe in GameData.SUPER_EVOLUTIONS:
		var comp_a: Array = recipe["comp_a"]
		var comp_b: Array = recipe["comp_b"]
		if candidate_id in comp_a:
			for w in equipped_weapons:
				if w["id"] in comp_b:
					return String(recipe["name"])
		elif candidate_id in comp_b:
			for w in equipped_weapons:
				if w["id"] in comp_a:
					return String(recipe["name"])
	return ""

# --- 类似《吸血鬼幸存者》的超武进化合成检查 ---
# 触发条件：车上同时装有配方要求的 A 与 B，且 (任意一件达到 ★2精良以上 或 开启了战场埋藏金属箱!)
func try_trigger_super_evolutions(from_chest: bool = false) -> Array:
	var triggered_list: Array = []
	var changed: bool = true
	while changed:
		changed = false
		for recipe in GameData.SUPER_EVOLUTIONS:
			var idx_a: int = -1
			var idx_b: int = -1
			for i in range(equipped_weapons.size()):
				var wid: String = equipped_weapons[i]["id"]
				if idx_a == -1 and (wid in recipe["comp_a"]):
					idx_a = i
				elif idx_b == -1 and (wid in recipe["comp_b"]) and i != idx_a:
					idx_b = i
			if idx_a != -1 and idx_b != -1:
				var wa: Dictionary = equipped_weapons[idx_a]
				var wb: Dictionary = equipped_weapons[idx_b]
				if from_chest or int(wa.get("rarity", 0)) >= 1 or int(wb.get("rarity", 0)) >= 1:
					var name_a: String = GameData.WEAPONS[wa["id"]]["name"]
					var name_b: String = GameData.WEAPONS[wb["id"]]["name"]
					var res_id: String = recipe["result"]
					var res_def: Dictionary = GameData.WEAPONS[res_id]

					# 移除原有的两把组件武器 (先删下标较大的)
					var hi: int = max(idx_a, idx_b)
					var lo: int = min(idx_a, idx_b)
					equipped_weapons.remove_at(hi)
					equipped_weapons.remove_at(lo)

					# 确保底盘有一个适配超武的孔位
					var needed_slot: String = res_def["slot"]
					if get_free_slot_count(needed_slot) <= 0 and chassis_slots.size() > 0:
						chassis_slots[0] = needed_slot

					equipped_weapons.append({"id": res_id, "rarity": 5})
					var info: Dictionary = {
						"evo_id": res_id,
						"evo_name": res_def["name"],
						"comp_a_name": name_a,
						"comp_b_name": name_b,
						"desc": res_def["desc"]
					}
					triggered_list.append(info)
					emit_signal("super_weapon_evolved", info)
					changed = true
					break
	if not triggered_list.is_empty():
		recalculate_stats()
	return triggered_list

func sell_weapon_at(index: int) -> int:
	if index < 0 or index >= equipped_weapons.size():
		return 0
	var w: Dictionary = equipped_weapons[index]
	var base_cost: int = GameData.WEAPONS[w["id"]].get("cost", 50)
	var refund: int = int(base_cost * pow(1.6, w.get("rarity", 0)) * 0.6)
	equipped_weapons.remove_at(index)
	gold += refund
	recalculate_stats()
	return refund

func cycle_chassis_slot_type(slot_index: int) -> bool:
	if slot_index < 0 or slot_index >= chassis_slots.size():
		return false
	if bonus_stats.get("no_main_cannon", false):
		chassis_slots[slot_index] = "SE" if chassis_slots[slot_index] == "SUB" else "SUB"
		return true
	var order: Array = ["MAIN", "SUB", "SE"]
	var cur: String = chassis_slots[slot_index]
	var next_idx: int = (order.find(cur) + 1) % order.size()
	chassis_slots[slot_index] = order[next_idx]
	return true

func get_available_wanted_posters() -> Array:
	var m_def: Dictionary = get_current_map_def()
	var reg_boss_id: String = m_def["regional_boss_id"]
	var final_boss_id: String = m_def["final_boss_id"]

	var candidates: Array = []
	# 优先放当前地图的驻守悬赏首领
	var reg_boss: Dictionary = GameData.get_boss_by_id(reg_boss_id)
	if not (reg_boss_id in defeated_wanted_ids):
		candidates.append(reg_boss)

	# 如果开启了黑市悬赏网，或当前地图区域Boss已击杀，补充其他可狩猎的通缉犯
	for boss in GameData.WANTED_BOSSES:
		if boss["id"] in [reg_boss_id, final_boss_id, "boss_noah"]:
			continue
		if boss["id"] in defeated_wanted_ids:
			continue
		if is_feature_unlocked("black_market_wanted") or candidates.size() < 2:
			candidates.append(boss)

	if candidates.size() <= 2:
		return candidates
	var list: Array = []
	for i in range(2):
		list.append(candidates[(wanted_poster_offset + i) % candidates.size()])
	return list
