extends Node
## 《重装废土：赏金狂飙》 - 全局状态机、局外永久存档与战车载重=SP 核心公式引擎

signal stats_updated
signal meta_updated
signal level_up_triggered
signal super_weapon_evolved(evo_info: Dictionary)
signal achievement_unlocked(ach_id: String, ach_data: Dictionary)

const SAVE_PATH: String = "user://metal_wasteland_save.json"
const SETTINGS_PATH: String = "user://metal_wasteland_settings.json"

const DEFAULT_SETTINGS: Dictionary = {
	# 声音与音频
	"master_volume": 1.0,         # 0.0 ~ 1.0
	"bgm_volume": 0.75,           # 0.0 ~ 1.0
	"sfx_volume": 0.85,           # 0.0 ~ 1.0
	"muted": false,
	"gamepad_vibration": true,

	# 画面与显示
	"window_mode": "fullscreen",  # "fullscreen", "windowed"
	"resolution": "1440x810",     # "1280x720", "1440x810", "1600x900", "1920x1080", "2560x1440"
	"vsync": true,

	# 游戏性与无障碍
	"screen_shake_mult": 1.0,     # 0.0, 0.5, 1.0, 1.5
	"show_damage_numbers": true,
	"show_minimap": true,
	"auto_main_cannon": true
}

var settings: Dictionary = {}

# ============================================================================
# 一、 局外永久养成与轮回存档数据 (Meta-Progression)
# ============================================================================
var noah_chips: int = 160 # 局外永久货币：原核晶片 💎 (新档默认赠送160晶片供体验)
var unlocked_hunters: Array = ["bounty_hunter", "mechanic"]
var unlocked_chassis: Array = ["buggy", "abrams"]
var unlocked_features: Array = []
var meta_upgrade_levels: Dictionary = {}
var unlocked_map_count: int = 1
var map_cleared_difficulties: Dictionary = {} # {"map_1": ["easy", "normal"]}
var unlocked_achievements: Array = []
var achievement_progress: Dictionary = {}
var unlocked_hunter_skins: Array = []
var unlocked_chassis_skins: Array = []
var selected_hunter_skin: Dictionary = {}
var selected_chassis_skin: Dictionary = {}
var custom_chassis_paints: Dictionary = {}


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
var mod_bonus_stats: Dictionary = {}
var equipped_tank_mods: Dictionary = {} # {"mod_autoloader": 2, "curse_overloaded_core": 1}
var synergy_counts: Dictionary = {}
var weapon_damage_stats: Dictionary = {} # {"cannon_105mm": 15420.0, "mg_77mm": 8900.0, ...}


func _ready() -> void:
	_init_default_meta()
	load_meta_save()
	load_settings()

func get_setting(key: String, default_val: Variant = null) -> Variant:
	if settings.has(key):
		return settings[key]
	if DEFAULT_SETTINGS.has(key):
		return DEFAULT_SETTINGS[key]
	return default_val

func set_setting(key: String, val: Variant) -> void:
	settings[key] = val

func save_settings() -> void:
	var f := FileAccess.open(SETTINGS_PATH, FileAccess.WRITE)
	if f:
		f.store_string(JSON.stringify(settings, "\t"))
		f.close()
	apply_all_settings()

func load_settings() -> void:
	settings = DEFAULT_SETTINGS.duplicate()
	if FileAccess.file_exists(SETTINGS_PATH):
		var f := FileAccess.open(SETTINGS_PATH, FileAccess.READ)
		if f:
			var txt: String = f.get_as_text()
			f.close()
			var parsed: Variant = JSON.parse_string(txt)
			if typeof(parsed) == TYPE_DICTIONARY:
				for k in parsed.keys():
					settings[k] = parsed[k]
	apply_all_settings()

func restore_default_settings() -> void:
	settings = DEFAULT_SETTINGS.duplicate()
	save_settings()

func apply_all_settings() -> void:
	# 1. 音频设置
	if is_instance_valid(SoundManager):
		SoundManager.set_master_volume(float(get_setting("master_volume", 1.0)))
		SoundManager.set_bgm_volume(float(get_setting("bgm_volume", 0.75)))
		SoundManager.set_sfx_volume(float(get_setting("sfx_volume", 0.85)))
		SoundManager.muted = bool(get_setting("muted", false))
		SoundManager.vibration_enabled = bool(get_setting("gamepad_vibration", true))

	# 2. 显示设置
	var w_mode: String = String(get_setting("window_mode", "fullscreen"))
	if w_mode == "fullscreen":
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN)
	else:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
		var res_str: String = String(get_setting("resolution", "1440x810"))
		var parts: PackedStringArray = res_str.split("x")
		if parts.size() == 2:
			var target_sz := Vector2i(int(parts[0]), int(parts[1]))
			DisplayServer.window_set_size(target_sz)
			var scr_sz: Vector2i = DisplayServer.screen_get_size()
			DisplayServer.window_set_position((scr_sz - target_sz) / 2)

	var vsync_on: bool = bool(get_setting("vsync", true))
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_ENABLED if vsync_on else DisplayServer.VSYNC_DISABLED)

	# 3. 游戏性设置
	auto_main_cannon = bool(get_setting("auto_main_cannon", true))

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
		"unlocked_achievements": unlocked_achievements,
		"achievement_progress": achievement_progress,
		"unlocked_hunter_skins": unlocked_hunter_skins,
		"unlocked_chassis_skins": unlocked_chassis_skins,
		"selected_hunter_skin": selected_hunter_skin,
		"selected_chassis_skin": selected_chassis_skin,
		"custom_chassis_paints": custom_chassis_paints,
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
		unlocked_achievements = d.get("unlocked_achievements", [])
		achievement_progress = d.get("achievement_progress", {})
		unlocked_hunter_skins = d.get("unlocked_hunter_skins", [])
		unlocked_chassis_skins = d.get("unlocked_chassis_skins", [])
		selected_hunter_skin = d.get("selected_hunter_skin", {})
		selected_chassis_skin = d.get("selected_chassis_skin", {})
		custom_chassis_paints = d.get("custom_chassis_paints", {})
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
	unlocked_achievements = []
	achievement_progress = {}
	unlocked_hunter_skins = []
	unlocked_chassis_skins = []
	selected_hunter_skin = {}
	selected_chassis_skin = {}
	custom_chassis_paints = {}
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
	if h_id in unlocked_hunters:
		return true
	var h_def: Dictionary = GameData.HUNTERS.get(h_id, {})
	var req_ach: String = h_def.get("unlock_ach_id", "")
	if req_ach == "" or is_achievement_unlocked(req_ach):
		return true
	return false

func unlock_hunter(h_id: String) -> bool:
	if not (h_id in unlocked_hunters):
		unlocked_hunters.append(h_id)
		save_meta_data()
	return true

func is_chassis_unlocked(c_id: String) -> bool:
	if c_id in unlocked_chassis:
		return true
	var c_def: Dictionary = GameData.CHASSIS.get(c_id, {})
	var req_ach: String = c_def.get("unlock_ach_id", "")
	if req_ach == "" or is_achievement_unlocked(req_ach):
		return true
	return false

func unlock_chassis(c_id: String) -> bool:
	if not (c_id in unlocked_chassis):
		unlocked_chassis.append(c_id)
		save_meta_data()
	return true

func is_map_unlocked(map_idx: int) -> bool:
	if map_idx <= 0:
		return true
	if map_idx >= GameData.MAPS.size():
		return false
	var m_def: Dictionary = GameData.MAPS[map_idx]
	var req_ach: String = m_def.get("unlock_ach_id", "")
	if req_ach != "" and is_achievement_unlocked(req_ach):
		return true
	return map_idx < unlocked_map_count

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

# --- 轮回结束结算：将本局波次、击杀、赏金首与金币折算为【原核晶片 💎】并判定解锁下一张地图 ---
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
	gold = 35 + get_meta_level("meta_start_gold") * 20 + int(d_def.get("bonus_start_gold", 0))
	xp = 0
	level = 1
	xp_to_next = 18
	pending_level_ups = 0
	total_kills = 0
	bounties_hunted = 0
	mince_free_revive_available = true
	field_defib_available = is_feature_unlocked("mince_defib_lv2")
	active_wanted_boss_id = ""
	defeated_wanted_ids.clear()
	wanted_poster_offset = 0
	run_already_settled = false
	weapon_damage_stats.clear()
	equipped_tank_mods.clear()
	mod_bonus_stats.clear()

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
		"flat_sp_regen": lv_rep * 3.0,
		"reload_speed_pct": lv_reload * 0.04,
		"move_speed_pct": 0.0,
		"crit_chance": 0.08 + lv_crit * 0.025,
		"dodge": lv_crit * 0.02,
		"gold_gain_pct": lv_mag * 0.08,
		"flat_sp_bonus": lv_sp * 25.0
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
		mult += 0.25
	xp += int(ceil(float(amount) * mult))
	var leveled: bool = false
	while xp >= xp_to_next:
		xp -= xp_to_next
		level += 1
		pending_level_ups += 1
		xp_to_next = int(18 + level * 14 + pow(level, 1.85))
		leveled = true
	if leveled:
		emit_signal("level_up_triggered")

func add_gold(amount: int) -> void:
	var mult: float = 1.0 + bonus_stats.get("gold_gain_pct", 0.0)
	if synergy_counts.get("tycoon", 0) >= 4:
		mult += 0.25
	gold += int(ceil(float(amount) * mult))

# --- 核心计算：引擎载重 -> 剩余载重 -> 战车SP装甲片 ---
func recalculate_stats() -> void:
	var ch: Dictionary = GameData.CHASSIS.get(selected_chassis_id, GameData.CHASSIS["buggy"])
	var eng: Dictionary = GameData.ENGINES.get(equipped_engine_id, GameData.ENGINES["eng_bulldog_v8"])
	var cu: Dictionary = GameData.C_UNITS.get(equipped_c_unit_id, GameData.C_UNITS["cu_type66"])

	# 1. 统计流派羁绊数量 (含已安装武器 + 战车战术改装挂件标签)
	synergy_counts.clear()
	for w_entry in equipped_weapons:
		var w_def: Dictionary = GameData.WEAPONS.get(w_entry["id"], {})
		for tag in w_def.get("tags", []):
			synergy_counts[tag] = synergy_counts.get(tag, 0) + 1
	for m_id in equipped_tank_mods.keys():
		var m_def: Dictionary = GameData.TANK_MODS.get(m_id, {})
		for tag in m_def.get("tags", []):
			synergy_counts[tag] = synergy_counts.get(tag, 0) + 1

	# 2. 计算最大载重 W_max
	var eng_weight: float = float(eng.get("max_weight", 18.0))
	if ch.get("dual_engine", false):
		eng_weight *= 1.60 # 猛犸象双核驱动
	max_weight = (eng_weight + bonus_stats.get("flat_max_weight", 0.0)) * (1.0 + bonus_stats.get("max_weight_pct", 0.0))

	# 3. 计算已用载重 W_equip
	used_weight = float(ch.get("base_weight", 5.0)) + float(cu.get("weight", 1.0))
	for w_entry in equipped_weapons:
		used_weight += get_weapon_effective_weight(w_entry["id"], w_entry.get("rarity", 0))

	free_weight = maxf(0.0, max_weight - used_weight)
	overweight_tons = maxf(0.0, used_weight - max_weight)

	# 4. 计算最大 SP (基础SP + 剩余吨位 * 底盘装甲转化率)
	var sp_per_ton: float = float(ch.get("sp_per_ton", 20.0))
	if synergy_counts.get("juggernaut", 0) >= 2:
		sp_per_ton += 6.0
	sp_per_ton *= (1.0 + bonus_stats.get("sp_per_ton_pct", 0.0))

	var raw_sp: float = float(ch.get("base_sp", 140.0)) + bonus_stats.get("flat_sp_bonus", 0.0) + free_weight * sp_per_ton
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
		sp_regen_per_sec += max_sp * 0.008
	if synergy_counts.get("lone_cub", 0) >= 4:
		sp_regen_per_sec += 8.0
	for w_entry in equipped_weapons:
		if w_entry["id"] == "se_drone":
			sp_regen_per_sec += 6.0 * (1.0 + 0.30 * w_entry.get("rarity", 0))
	if selected_chassis_id == "ambulance":
		sp_regen_per_sec *= 1.65

	crit_chance = clampf(bonus_stats.get("crit_chance", 0.08) + float(cu.get("crit_bonus", 0.0)), 0.0, 0.90)
	dodge_chance = clampf(bonus_stats.get("dodge", 0.05) + float(cu.get("dodge_bonus", 0.0)), 0.0, 0.75)
	pickup_range = 185.0 * (1.0 + get_meta_level("meta_magnet_gold") * 0.20)

	var h_mult: float = float(bonus_stats.get("human_hp_mult", 1.0))
	if synergy_counts.get("lone_cub", 0) >= 2:
		h_mult += 0.5
	var base_h_hp: float = 240.0 + (max_sp * 0.16) + get_meta_level("meta_sp") * 25.0 + level * 20.0
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
		base *= pow(1.32, float(rarity))

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
# 触发条件：车上同时装有配方要求的 A 与 B，且 (两件均达到 ★4史诗以上，或第6波以后拾取精英宝箱且一件★4+一件★3)
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
				var ra: int = int(wa.get("rarity", 0))
				var rb: int = int(wb.get("rarity", 0))
				var can_evo: bool = (ra >= 3 and rb >= 3) or (from_chest and current_wave >= 6 and ((ra >= 3 and rb >= 2) or (rb >= 3 and ra >= 2)))
				if can_evo:
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

func get_drill_slot_cost() -> int:
	var extra: int = maxi(0, chassis_slots.size() - 4)
	return 80 + extra * 45

func can_drill_slot() -> bool:
	return chassis_slots.size() < 6 and gold >= get_drill_slot_cost()

func drill_new_chassis_slot(slot_type: String = "SUB") -> bool:
	if chassis_slots.size() >= 6:
		return false
	var cost: int = get_drill_slot_cost()
	if gold < cost:
		return false
	gold -= cost
	chassis_slots.append(slot_type)
	recalculate_stats()
	return true

func switch_chassis(new_chassis_id: String) -> bool:
	if not GameData.CHASSIS.has(new_chassis_id):
		return false
	if not is_chassis_unlocked(new_chassis_id):
		return false
	selected_chassis_id = new_chassis_id
	var ch: Dictionary = GameData.CHASSIS[new_chassis_id]
	var base_slots: Array = []
	for s in ch["slots"]:
		base_slots.append(String(s))
	while base_slots.size() < chassis_slots.size() and base_slots.size() < 6:
		base_slots.append("SE")
	chassis_slots = base_slots
	recalculate_stats()
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

# --- 土豆兄弟 / 吸血鬼幸存者风格：武器输出统计与 DPS 排行榜 ---
func record_weapon_damage(w_id: String, dmg: float) -> void:
	if w_id.is_empty() or dmg <= 0.0:
		return
	weapon_damage_stats[w_id] = weapon_damage_stats.get(w_id, 0.0) + dmg

func get_total_weapon_damage() -> float:
	var total: float = 0.0
	for d in weapon_damage_stats.values():
		total += float(d)
	return total

func get_sorted_weapon_damage() -> Array:
	var list: Array = []
	var total: float = get_total_weapon_damage()
	for wid in weapon_damage_stats.keys():
		var d: float = float(weapon_damage_stats[wid])
		var w_name: String = wid
		var slot_badge: String = "🔫"
		var w_color: Color = Color(0.85, 0.85, 0.85)

		if GameData.WEAPONS.has(wid):
			var wdef: Dictionary = GameData.WEAPONS[wid]
			w_name = wdef.get("name", wid)
			var slot: String = wdef.get("slot", "SUB")
			slot_badge = "🔴主炮" if slot == "MAIN" else ("🟡副炮" if slot == "SUB" else "🔵S-E")
			w_color = Color(1.0, 0.55, 0.25) if slot == "MAIN" else (Color(1.0, 0.88, 0.35) if slot == "SUB" else Color(0.35, 0.85, 1.0))
		elif wid == "se_spike_ball":
			w_name = "旋转链锯刺球"
			slot_badge = "⚙️撞角"
			w_color = Color(0.85, 0.75, 0.35)
		elif wid == "chassis_ram":
			w_name = "战车冲撞碾压"
			slot_badge = "🚜车体"
			w_color = Color(0.95, 0.65, 0.30)
		elif wid == "cu_all_out":
			w_name = "全弹发射/轨道卫星"
			slot_badge = "🚀C装置"
			w_color = Color(1.0, 0.85, 0.20)
		elif wid == "human_handgun":
			w_name = "猎人自卫枪械"
			slot_badge = "👤步兵"
			w_color = Color(0.45, 0.95, 0.55)

		var pct: float = (d / total * 100.0) if total > 0.0 else 0.0
		list.append({
			"id": wid,
			"name": w_name,
			"slot_badge": slot_badge,
			"damage": d,
			"pct": pct,
			"color": w_color
		})
	list.sort_custom(func(a, b): return a["damage"] > b["damage"])
	return list



# ============================================================================
# 成就系统判定与奖励分发机制 (ACHIEVEMENTS PROGRESS & REWARDS)
# ============================================================================
func is_achievement_unlocked(ach_id: String) -> bool:
	return ach_id in unlocked_achievements

func get_achievement_progress(ach_id: String) -> float:
	var ach: Dictionary = GameData.get_achievement(ach_id)
	if ach.is_empty():
		return 0.0
	var metric: String = ach.get("metric", "")
	return float(achievement_progress.get(metric, 0))

func report_metric(metric_name: String, value: Variant, is_incremental: bool = false) -> void:
	if is_incremental:
		var curr: float = float(achievement_progress.get(metric_name, 0.0))
		achievement_progress[metric_name] = curr + float(value)
	else:
		var prev: float = float(achievement_progress.get(metric_name, 0.0))
		achievement_progress[metric_name] = maxf(prev, float(value))

	var cur_val: float = float(achievement_progress.get(metric_name, 0.0))
	for ach in GameData.ACHIEVEMENTS:
		if ach["metric"] == metric_name:
			var aid: String = ach["id"]
			if not is_achievement_unlocked(aid):
				if cur_val >= float(ach["target"]):
					unlock_achievement(aid)

func unlock_achievement(ach_id: String) -> bool:
	if ach_id in unlocked_achievements:
		return false
	unlocked_achievements.append(ach_id)
	var ach: Dictionary = GameData.get_achievement(ach_id)
	if not ach.is_empty():
		var r_type: String = ach.get("rtype", "")
		var r_id: String = ach.get("rid", "")
		match r_type:
			"hunter":
				if r_id != "" and not (r_id in unlocked_hunters):
					unlocked_hunters.append(r_id)
			"chassis":
				if r_id != "" and not (r_id in unlocked_chassis):
					unlocked_chassis.append(r_id)
			"map":
				for m in GameData.MAPS:
					if m["id"] == r_id:
						unlocked_map_count = maxi(unlocked_map_count, int(m["index"]) + 1)
						break
			"hunter_skin":
				if r_id != "" and not (r_id in unlocked_hunter_skins):
					unlocked_hunter_skins.append(r_id)
			"chassis_skin":
				if r_id != "" and not (r_id in unlocked_chassis_skins):
					unlocked_chassis_skins.append(r_id)
			"chips":
				var reg := RegEx.new()
				reg.compile(r"\d+")
				var m := reg.search(ach.get("rname", ""))
				var grant: int = m.get_string().to_int() if m != null else 50
				noah_chips += grant
		emit_signal("achievement_unlocked", ach_id, ach)
	save_meta_data()
	return true

# --- 角色与战车皮肤装备与持久化 ---
func is_hunter_skin_unlocked(hunter_id: String, skin_id: String) -> bool:
	if skin_id == "default" or skin_id == "":
		return true
	if skin_id in unlocked_hunter_skins:
		return true
	var s_def: Dictionary = GameData.get_hunter_skin_def(hunter_id, skin_id)
	var req_ach: String = s_def.get("unlock_ach_id", "")
	return req_ach != "" and is_achievement_unlocked(req_ach)

func is_chassis_skin_unlocked(chassis_id: String, skin_id: String) -> bool:
	if skin_id == "default" or skin_id == "":
		return true
	if skin_id in unlocked_chassis_skins:
		return true
	var s_def: Dictionary = GameData.get_chassis_skin_def(chassis_id, skin_id)
	var req_ach: String = s_def.get("unlock_ach_id", "")
	return req_ach != "" and is_achievement_unlocked(req_ach)

func set_hunter_skin(hunter_id: String, skin_id: String) -> void:
	selected_hunter_skin[hunter_id] = skin_id
	save_meta_data()

func get_hunter_skin(hunter_id: String) -> String:
	return selected_hunter_skin.get(hunter_id, "default")

func set_chassis_skin(chassis_id: String, skin_id: String) -> void:
	selected_chassis_skin[chassis_id] = skin_id
	save_meta_data()

func get_chassis_skin(chassis_id: String) -> String:
	return selected_chassis_skin.get(chassis_id, "default")

func set_custom_chassis_paint(chassis_id: String, paint_data: Dictionary) -> void:
	var hex_dict: Dictionary = {}
	for k in paint_data.keys():
		var val = paint_data[k]
		if val is Color:
			hex_dict[k] = val.to_html(false)
		else:
			hex_dict[k] = String(val)
	custom_chassis_paints[chassis_id] = hex_dict
	report_metric("custom_paint_saved", 1.0, true)
	save_meta_data()

func get_custom_chassis_paint(chassis_id: String) -> Dictionary:
	var raw: Dictionary = custom_chassis_paints.get(chassis_id, {})
	var col_dict: Dictionary = {}
	for k in raw.keys():
		col_dict[k] = Color.from_string(raw[k], Color.WHITE)
	return col_dict


# ============================================================================
# 车库深度构筑：战术改装挂件、以旧换新折抵、三层智能加权与穿透式属性明细
# ============================================================================
func buy_tank_mod(mod_id: String, price: int = -1) -> bool:
	if not GameData.TANK_MODS.has(mod_id):
		return false
	var m_def: Dictionary = GameData.TANK_MODS[mod_id]
	var actual_cost: int = price if price >= 0 else int(m_def.get("cost", 50))
	if gold < actual_cost:
		return false
	gold -= actual_cost
	equipped_tank_mods[mod_id] = int(equipped_tank_mods.get(mod_id, 0)) + 1
	var mods: Dictionary = m_def.get("mods", {})
	for k in mods.keys():
		var delta_v: float = float(mods[k])
		bonus_stats[k] = float(bonus_stats.get(k, 0.0)) + delta_v
		mod_bonus_stats[k] = float(mod_bonus_stats.get(k, 0.0)) + delta_v
	recalculate_stats()
	return true

func get_engine_trade_in_value() -> int:
	var cur_eng: Dictionary = GameData.ENGINES.get(equipped_engine_id, {})
	return int(float(cur_eng.get("cost", 40)) * 0.50)

func get_c_unit_trade_in_value() -> int:
	var cur_cu: Dictionary = GameData.C_UNITS.get(equipped_c_unit_id, {})
	return int(float(cur_cu.get("cost", 45)) * 0.50)

func roll_weighted_weapon_id(valid_w: Array) -> String:
	if valid_w.is_empty():
		return "mg_77mm"
	var weights: Array = []
	var total_w: float = 0.0
	for wid in valid_w:
		var w_def: Dictionary = GameData.WEAPONS.get(wid, {})
		var w_score: float = 1.0
		# 第一层：已装备流派 Tag 动态倾向 (+25% / 层)
		for t in w_def.get("tags", []):
			w_score += 0.25 * float(synergy_counts.get(t, 0))
		# 第二层：同名可二合一升星倾向 (+45%)
		for ew in equipped_weapons:
			if ew["id"] == wid and int(ew.get("rarity", 0)) < 4:
				w_score += 0.45
				break
		# 第三层：神话超武配方补齐倾向 (+50%)
		if check_super_evolution_partner(wid) != "":
			w_score += 0.50
		weights.append(w_score)
		total_w += w_score

	var pick: float = randf() * total_w
	var accum: float = 0.0
	for i in range(valid_w.size()):
		accum += float(weights[i])
		if pick <= accum:
			return String(valid_w[i])
	return String(valid_w[valid_w.size() - 1])

func get_stat_breakdown(stat_key: String) -> String:
	var ch: Dictionary = GameData.CHASSIS.get(selected_chassis_id, GameData.CHASSIS["buggy"])
	var eng: Dictionary = GameData.ENGINES.get(equipped_engine_id, GameData.ENGINES["eng_bulldog_v8"])
	var cu: Dictionary = GameData.C_UNITS.get(equipped_c_unit_id, GameData.C_UNITS["cu_type66"])
	var h: Dictionary = GameData.HUNTERS.get(selected_hunter_id, GameData.HUNTERS["bounty_hunter"])
	var h_mods: Dictionary = h.get("mods", {})

	match stat_key:
		"max_sp":
			var base_sp_val: float = float(ch.get("base_sp", 140.0))
			var meta_sp_val: float = get_meta_level("meta_sp") * 25.0
			var mod_sp_val: float = float(mod_bonus_stats.get("flat_sp_bonus", 0.0))
			var spt: float = float(ch.get("sp_per_ton", 20.0)) + (6.0 if synergy_counts.get("juggernaut", 0) >= 2 else 0.0)
			spt *= (1.0 + float(bonus_stats.get("sp_per_ton_pct", 0.0)))
			var weight_sp_val: float = free_weight * spt
			return "【最大装甲 SP 构成明细】\n• 底盘基础装甲: %.0f SP\n• 特斯拉实验室: +%.0f SP\n• 战术改装挂件: %+.0f SP\n• 富余载重转化 (%.1ft × %.1f): +%.0f SP\n➔ 最终总计: %.0f SP" % [
				base_sp_val, meta_sp_val, mod_sp_val, free_weight, spt, weight_sp_val, max_sp
			]
		"max_weight":
			var base_w: float = float(eng.get("max_weight", 18.0)) * (1.6 if ch.get("dual_engine", false) else 1.0)
			var flat_w: float = float(bonus_stats.get("flat_max_weight", 0.0))
			var pct_w: float = float(bonus_stats.get("max_weight_pct", 0.0)) * 100.0
			return "【引擎最大载重构成明细】\n• 引擎基础出力: %.1f t\n• 车库扩容与改装件: %+.1f t\n• 百分比载重加成: %+.0f%%\n➔ 最终最大载重: %.1f t (已用 %.1f t)" % [
				base_w, flat_w, pct_w, max_weight, used_weight
			]
		"main_dmg":
			var meta_d: float = get_meta_level("meta_dmg") * 6.0
			var h_d: float = float(h_mods.get("main_dmg_pct", 0.0)) * 100.0
			var mod_d: float = float(mod_bonus_stats.get("main_dmg_pct", 0.0)) * 100.0
			var eng_d: float = (float(eng.get("all_dmg_bonus", 0.0)) + float(eng.get("main_dmg_bonus", 0.0))) * 100.0
			var syn_d: float = 35.0 if synergy_counts.get("artillery", 0) >= 4 else 0.0
			var total_d: float = (float(bonus_stats.get("main_dmg_pct", 0.0)) + float(eng.get("all_dmg_bonus", 0.0)) + float(eng.get("main_dmg_bonus", 0.0))) * 100.0 + syn_d
			return "【主炮伤害加成明细】\n• 特斯拉实验室: +%.0f%%\n• 猎人天赋加成: %+.0f%%\n• 战术改装挂件: %+.0f%%\n• 引擎出力加成: %+.0f%%\n• 重炮轰鸣(4)羁绊: +%.0f%%\n➔ 综合主炮增伤: %+.0f%%" % [
				meta_d, h_d, mod_d, eng_d, syn_d, total_d
			]
		"sub_dmg":
			var meta_d: float = get_meta_level("meta_dmg") * 6.0
			var h_d: float = float(h_mods.get("sub_dmg_pct", 0.0)) * 100.0
			var mod_d: float = float(mod_bonus_stats.get("sub_dmg_pct", 0.0)) * 100.0
			var cu_se: float = float(cu.get("se_dmg_bonus", 0.0)) * 100.0
			var total_d: float = (float(bonus_stats.get("sub_dmg_pct", 0.0)) + float(eng.get("all_dmg_bonus", 0.0))) * 100.0
			return "【副炮与 S-E 伤害加成明细】\n• 特斯拉实验室: +%.0f%%\n• 猎人天赋加成: %+.0f%%\n• 战术改装挂件: %+.0f%%\n• C装置S-E专项加成: +%.0f%%\n➔ 综合副武增伤: %+.0f%%" % [
				meta_d, h_d, mod_d, cu_se, total_d
			]
		"reload_spd":
			var meta_r: float = get_meta_level("meta_reload") * 4.0
			var mod_r: float = float(mod_bonus_stats.get("reload_speed_pct", 0.0)) * 100.0
			var total_r: float = float(bonus_stats.get("reload_speed_pct", 0.0)) * 100.0
			return "【装填攻速加成明细】\n• 特斯拉实验室: +%.0f%%\n• 战术改装挂件: %+.0f%%\n• 战地升级与猎人专精: %+.0f%%\n➔ 综合装填加速: %+.0f%%" % [
				meta_r, mod_r, total_r - meta_r - mod_r, total_r
			]
		"crit_chance":
			var base_c: float = 8.0 + get_meta_level("meta_crit_dodge") * 2.5
			var cu_c: float = float(cu.get("crit_bonus", 0.0)) * 100.0
			var mod_c: float = float(mod_bonus_stats.get("crit_chance", 0.0)) * 100.0
			return "【暴击率构成明细】\n• 基础与实验室: %.1f%%\n• C装置火控加成: +%.0f%%\n• 战术改装挂件: %+.0f%%\n➔ 最终面板暴击率: %.0f%% (上限90%%)" % [
				base_c, cu_c, mod_c, crit_chance * 100.0
			]
		"dodge":
			var base_d: float = 5.0 + get_meta_level("meta_crit_dodge") * 2.0
			var cu_d: float = float(cu.get("dodge_bonus", 0.0)) * 100.0
			var mod_d: float = float(mod_bonus_stats.get("dodge", 0.0)) * 100.0
			return "【战车闪避率构成明细】\n• 基础与实验室: %.1f%%\n• C装置全息加成: +%.0f%%\n• 战术改装挂件: %+.0f%%\n➔ 最终面板闪避率: %.0f%% (上限75%%)" % [
				base_d, cu_d, mod_d, dodge_chance * 100.0
			]
		"move_speed":
			var base_s: float = float(ch.get("speed", 210.0))
			var eng_s: float = float(eng.get("speed_bonus", 0.0)) * 100.0
			var mod_s: float = float(mod_bonus_stats.get("move_speed_pct", 0.0)) * 100.0
			var ow_pen: float = overweight_tons * 12.0
			return "【战车机动移速明细】\n• 底盘基础车速: %.0f\n• 引擎推进加成: %+.0f%%\n• 战术改装挂件: %+.0f%%\n• 超载惩罚: -%.0f%%\n➔ 最终行驶速度: %.0f" % [
				base_s, eng_s, mod_s, ow_pen, move_speed
			]
		_:
			return "战车实时综合战斗指标（悬停可查看详细构成）"


# ============================================================================
# 无副作用的整备模拟与升级/换装前置对比计算器 (SIMULATION & PREVIEW HELPERS)
# ============================================================================
func simulate_stats(p_engine_id: String = "", p_c_unit_id: String = "", p_weapons: Variant = null, p_tank_mods: Variant = null, p_chassis_id: String = "", p_flat_weight_bonus: Variant = null, p_override_bonus_stats: Variant = null) -> Dictionary:
	var use_eng_id: String = p_engine_id if not p_engine_id.is_empty() else equipped_engine_id
	var use_cu_id: String = p_c_unit_id if not p_c_unit_id.is_empty() else equipped_c_unit_id
	var use_ch_id: String = p_chassis_id if not p_chassis_id.is_empty() else selected_chassis_id
	var use_flat_wt: float = float(p_flat_weight_bonus) if p_flat_weight_bonus != null else float(bonus_stats.get("flat_max_weight", 0.0))
	var use_bonus: Dictionary = p_override_bonus_stats if p_override_bonus_stats != null else bonus_stats

	var ch: Dictionary = GameData.CHASSIS.get(use_ch_id, GameData.CHASSIS["buggy"])
	var eng: Dictionary = GameData.ENGINES.get(use_eng_id, GameData.ENGINES["eng_bulldog_v8"])
	var cu: Dictionary = GameData.C_UNITS.get(use_cu_id, GameData.C_UNITS["cu_type66"])

	var sim_weapons: Array = []
	if p_weapons != null:
		sim_weapons = p_weapons
	else:
		sim_weapons = equipped_weapons.duplicate(true)

	var sim_tank_mods: Dictionary = {}
	if p_tank_mods != null:
		sim_tank_mods = p_tank_mods
	else:
		sim_tank_mods = equipped_tank_mods.duplicate(true)

	# 1. 羁绊统计
	var sim_synergies: Dictionary = {}
	for w_entry in sim_weapons:
		var w_def: Dictionary = GameData.WEAPONS.get(w_entry["id"], {})
		for tag in w_def.get("tags", []):
			sim_synergies[tag] = sim_synergies.get(tag, 0) + 1
	for m_id in sim_tank_mods.keys():
		var m_def: Dictionary = GameData.TANK_MODS.get(m_id, {})
		for tag in m_def.get("tags", []):
			sim_synergies[tag] = sim_synergies.get(tag, 0) + 1

	# 2. 最大载重
	var eng_weight: float = float(eng.get("max_weight", 18.0))
	if ch.get("dual_engine", false):
		eng_weight *= 1.60
	var sim_max_weight: float = (eng_weight + use_flat_wt) * (1.0 + float(use_bonus.get("max_weight_pct", 0.0)))

	# 3. 已用载重
	var sim_used_weight: float = float(ch.get("base_weight", 5.0)) + float(cu.get("weight", 1.0))
	for w_entry in sim_weapons:
		var wid: String = w_entry["id"]
		var rar: int = int(w_entry.get("rarity", 0))
		var w_def: Dictionary = GameData.WEAPONS.get(wid, {})
		var w: float = float(w_def.get("weight", 2.0))
		if not w_def.get("is_evo", false):
			w *= (1.0 + float(rar) * 0.10)
		if w_def.get("slot", "") == "SE" and use_ch_id == "missile_carrier":
			w *= 0.65
		if w_def.get("slot", "") == "MAIN" and sim_synergies.get("artillery", 0) >= 2:
			w *= 0.80
		sim_used_weight += snappedf(w, 0.1)

	var sim_free_weight: float = maxf(0.0, sim_max_weight - sim_used_weight)
	var sim_overweight: float = maxf(0.0, sim_used_weight - sim_max_weight)

	# 4. 最大SP
	var sp_per_ton: float = float(ch.get("sp_per_ton", 20.0))
	if sim_synergies.get("juggernaut", 0) >= 2:
		sp_per_ton += 6.0
	sp_per_ton *= (1.0 + float(use_bonus.get("sp_per_ton_pct", 0.0)))
	var raw_sp: float = float(ch.get("base_sp", 140.0)) + float(use_bonus.get("flat_sp_bonus", 0.0)) + sim_free_weight * sp_per_ton
	var sim_max_sp: float = maxf(100.0, roundf(raw_sp))

	# 5. 移速
	var base_spd: float = float(ch.get("speed", 210.0))
	var spd_mult: float = 1.0 + float(use_bonus.get("move_speed_pct", 0.0)) + float(eng.get("speed_Bonus", eng.get("speed_bonus", 0.0)))
	if sim_overweight > 0.0:
		spd_mult *= maxf(0.35, 1.0 - sim_overweight * 0.12)
	var sim_move_speed: float = base_spd * spd_mult

	# 6. 暴击、闪避、大招CD
	var sim_crit: float = clampf(float(use_bonus.get("crit_chance", 0.08)) + float(cu.get("crit_bonus", 0.0)), 0.0, 0.90)
	var sim_dodge: float = clampf(float(use_bonus.get("dodge", 0.05)) + float(cu.get("dodge_bonus", 0.0)), 0.0, 0.75)
	var sim_c_cd: float = float(cu.get("all_out_cd", 12.0))

	return {
		"max_weight": sim_max_weight,
		"used_weight": sim_used_weight,
		"free_weight": sim_free_weight,
		"overweight": sim_overweight,
		"max_sp": sim_max_sp,
		"move_speed": sim_move_speed,
		"crit_chance": sim_crit,
		"dodge_chance": sim_dodge,
		"c_unit_cd": sim_c_cd,
		"sp_per_ton": sp_per_ton
	}

func preview_weapon_purchase(weapon_id: String, rarity: int) -> Dictionary:
	var cur_stats: Dictionary = {
		"max_weight": max_weight,
		"used_weight": used_weight,
		"free_weight": free_weight,
		"max_sp": max_sp,
		"move_speed": move_speed
	}
	var is_merge: bool = false
	var merge_idx: int = -1
	var sim_weapons: Array = equipped_weapons.duplicate(true)
	if rarity < 4:
		for i in range(sim_weapons.size()):
			if sim_weapons[i]["id"] == weapon_id and int(sim_weapons[i].get("rarity", 0)) == rarity:
				is_merge = true
				merge_idx = i
				sim_weapons[i]["rarity"] = rarity + 1
				break
	if not is_merge:
		sim_weapons.append({"id": weapon_id, "rarity": rarity})

	var new_stats: Dictionary = simulate_stats("", "", sim_weapons)
	var cur_dmg: float = get_weapon_effective_damage(weapon_id, rarity)
	var next_rar: int = rarity + 1 if is_merge else rarity
	var new_dmg: float = get_weapon_effective_damage(weapon_id, next_rar)
	var cur_w: float = get_weapon_effective_weight(weapon_id, rarity)
	var new_w: float = get_weapon_effective_weight(weapon_id, next_rar)

	return {
		"is_merge": is_merge,
		"merge_idx": merge_idx,
		"cur_rarity": rarity,
		"next_rarity": next_rar,
		"cur_dmg": cur_dmg,
		"new_dmg": new_dmg,
		"dmg_delta": new_dmg - cur_dmg,
		"cur_w": cur_w,
		"new_w": new_w,
		"w_delta": new_w - cur_w,
		"cur_sp": cur_stats["max_sp"],
		"new_sp": new_stats["max_sp"],
		"sp_delta": new_stats["max_sp"] - cur_stats["max_sp"],
		"cur_used_w": cur_stats["used_weight"],
		"new_used_w": new_stats["used_weight"],
		"is_overweight": new_stats["overweight"] > 0.0
	}

func preview_engine_switch(new_engine_id: String) -> Dictionary:
	var cur_stats: Dictionary = {
		"max_weight": max_weight,
		"used_weight": used_weight,
		"free_weight": free_weight,
		"max_sp": max_sp,
		"move_speed": move_speed
	}
	var new_stats: Dictionary = simulate_stats(new_engine_id)
	var cur_eng: Dictionary = GameData.ENGINES.get(equipped_engine_id, {})
	var new_eng: Dictionary = GameData.ENGINES.get(new_engine_id, {})

	return {
		"cur_eng_name": cur_eng.get("name", "标准引擎"),
		"new_eng_name": new_eng.get("name", "新引擎"),
		"cur_max_w": cur_stats["max_weight"],
		"new_max_w": new_stats["max_weight"],
		"max_w_delta": new_stats["max_weight"] - cur_stats["max_weight"],
		"cur_sp": cur_stats["max_sp"],
		"new_sp": new_stats["max_sp"],
		"sp_delta": new_stats["max_sp"] - cur_stats["max_sp"],
		"cur_speed": cur_stats["move_speed"],
		"new_speed": new_stats["move_speed"],
		"speed_delta": new_stats["move_speed"] - cur_stats["move_speed"],
		"cur_all_dmg": float(cur_eng.get("all_dmg_bonus", 0.0)),
		"new_all_dmg": float(new_eng.get("all_dmg_bonus", 0.0)),
		"cur_main_dmg": float(cur_eng.get("main_dmg_bonus", 0.0)),
		"new_main_dmg": float(new_eng.get("main_dmg_bonus", 0.0))
	}

func preview_c_unit_switch(new_cu_id: String) -> Dictionary:
	var cur_cu: Dictionary = GameData.C_UNITS.get(equipped_c_unit_id, {})
	var new_cu: Dictionary = GameData.C_UNITS.get(new_cu_id, {})
	var new_stats: Dictionary = simulate_stats("", new_cu_id)

	return {
		"cur_cu_name": cur_cu.get("name", "标准火控"),
		"new_cu_name": new_cu.get("name", "新火控"),
		"cur_cd": float(cur_cu.get("all_out_cd", 12.0)),
		"new_cd": float(new_cu.get("all_out_cd", 12.0)),
		"cd_delta": float(new_cu.get("all_out_cd", 12.0)) - float(cur_cu.get("all_out_cd", 12.0)),
		"cur_crit": crit_chance,
		"new_crit": new_stats["crit_chance"],
		"crit_delta": new_stats["crit_chance"] - crit_chance,
		"cur_dodge": dodge_chance,
		"new_dodge": new_stats["dodge_chance"],
		"dodge_delta": new_stats["dodge_chance"] - dodge_chance,
		"cur_sp": max_sp,
		"new_sp": new_stats["max_sp"],
		"sp_delta": new_stats["max_sp"] - max_sp,
		"cur_w": float(cur_cu.get("weight", 1.0)),
		"new_w": float(new_cu.get("weight", 1.0))
	}

func preview_tune_engine(ton_gain: float = 2.5) -> Dictionary:
	var cur_flat: float = float(bonus_stats.get("flat_max_weight", 0.0))
	var new_stats: Dictionary = simulate_stats("", "", null, null, "", cur_flat + ton_gain)
	return {
		"cur_max_w": max_weight,
		"new_max_w": new_stats["max_weight"],
		"max_w_delta": new_stats["max_weight"] - max_weight,
		"cur_sp": max_sp,
		"new_sp": new_stats["max_sp"],
		"sp_delta": new_stats["max_sp"] - max_sp
	}

func preview_tank_mod_purchase(mod_id: String) -> Dictionary:
	var m_def: Dictionary = GameData.TANK_MODS.get(mod_id, {})
	var sim_mods: Dictionary = equipped_tank_mods.duplicate(true)
	sim_mods[mod_id] = int(sim_mods.get(mod_id, 0)) + 1
	var sim_bonus: Dictionary = bonus_stats.duplicate(true)
	var mods: Dictionary = m_def.get("mods", {})
	for k in mods.keys():
		sim_bonus[k] = float(sim_bonus.get(k, 0.0)) + float(mods[k])
	var new_stats: Dictionary = simulate_stats("", "", null, sim_mods, "", null, sim_bonus)
	var stat_deltas: Array = []
	for k in mods.keys():
		var d: float = float(mods[k])
		var name_map: Dictionary = {
			"reload_speed_pct": "装填攻速",
			"main_dmg_pct": "主炮伤害",
			"sub_dmg_pct": "副武伤害",
			"elemental_dmg_pct": "元素伤害",
			"crit_chance": "暴击几率",
			"dodge": "闪避几率",
			"move_speed_pct": "战车移速",
			"gold_gain_pct": "赏金收益",
			"flat_sp_bonus": "基础装甲",
			"flat_sp_regen": "装甲每秒自修"
		}
		var stat_name: String = name_map.get(k, k)
		var is_pct: bool = k.ends_with("_pct") or k in ["crit_chance", "dodge"]
		if is_pct:
			stat_deltas.append("%s %+d%%" % [stat_name, int(roundf(d * 100.0))])
		else:
			stat_deltas.append("%s %+.0f" % [stat_name, d])

	return {
		"cur_sp": max_sp,
		"new_sp": new_stats["max_sp"],
		"sp_delta": new_stats["max_sp"] - max_sp,
		"cur_max_w": max_weight,
		"new_max_w": new_stats["max_weight"],
		"cur_speed": move_speed,
		"new_speed": new_stats["move_speed"],
		"stat_deltas": stat_deltas
	}

func preview_chassis_switch(new_ch_id: String) -> Dictionary:
	var cur_ch: Dictionary = GameData.CHASSIS.get(selected_chassis_id, {})
	var new_ch: Dictionary = GameData.CHASSIS.get(new_ch_id, {})
	var new_stats: Dictionary = simulate_stats("", "", null, null, new_ch_id)
	return {
		"cur_ch_name": cur_ch.get("name", "当前底盘"),
		"new_ch_name": new_ch.get("name", "新底盘"),
		"cur_sp": max_sp,
		"new_sp": new_stats["max_sp"],
		"sp_delta": new_stats["max_sp"] - max_sp,
		"cur_speed": move_speed,
		"new_speed": new_stats["move_speed"],
		"cur_sp_per_ton": float(cur_ch.get("sp_per_ton", 20.0)),
		"new_sp_per_ton": float(new_ch.get("sp_per_ton", 20.0)),
		"cur_slots_count": chassis_slots.size(),
		"new_slots_count": (new_ch.get("slots", []) as Array).size()
	}

func preview_sell_weapon(slot_idx: int) -> Dictionary:
	if slot_idx < 0 or slot_idx >= equipped_weapons.size():
		return {}
	var sim_weapons: Array = equipped_weapons.duplicate(true)
	var removed_w: Dictionary = sim_weapons[slot_idx]
	sim_weapons.remove_at(slot_idx)
	var new_stats: Dictionary = simulate_stats("", "", sim_weapons)
	var w_def: Dictionary = GameData.WEAPONS.get(removed_w["id"], {})
	var rar: int = int(removed_w.get("rarity", 0))
	var refund: int = int(w_def.get("cost", 50) * pow(1.6, rar) * 0.6)
	return {
		"refund": refund,
		"cur_sp": max_sp,
		"new_sp": new_stats["max_sp"],
		"sp_delta": new_stats["max_sp"] - max_sp,
		"cur_used_w": used_weight,
		"new_used_w": new_stats["used_weight"],
		"freed_w": used_weight - new_stats["used_weight"]
	}
