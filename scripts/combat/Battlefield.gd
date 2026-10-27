extends Node2D
## 《重装废土：赏金狂飙》 - 废土战场主控脚本
## 负责：沙地地形与履带印绘制、波次倒计时、动态刷怪、赏金首乱入警报、红狼救援彩蛋与战场HUD。

signal wave_completed
signal player_defeated
signal game_victory

const EnemyScript = preload("res://scripts/combat/Enemy.gd")
const ProjectileScript = preload("res://scripts/combat/Projectile.gd")
const DropItemScript = preload("res://scripts/combat/DropItem.gd")
const FloatingTextScript = preload("res://scripts/combat/FloatingText.gd")
const PlayerTankScript = preload("res://scripts/combat/PlayerTank.gd")

var arena_rect: Rect2 = Rect2(80, 90, 1280, 740)
var wave_active: bool = false
var wave_time_left: float = 35.0
var wave_elapsed: float = 0.0
var spawn_timer: float = 0.0
var elite_spawn_timer: float = 11.0
var boss_spawned_this_wave: bool = false
var red_wolf_rescued_this_run: bool = false

# --- 场景容器节点 ---
var enemies_container: Node2D
var projectiles_container: Node2D
var drops_container: Node2D
var fx_layer: Node2D
var player_tank: Node2D

# --- 视觉装饰与震屏 ---
var tread_marks: Array = []
var craters: Array = []
var spawn_telegraphs: Array = []
var shake_timer: float = 0.0
var shake_intensity: float = 0.0

# --- 战场 HUD 控件 ---
var hud_layer: CanvasLayer
var lbl_wave_timer: Label
var lbl_sp_info: Label
var bar_sp: ProgressBar
var lbl_weight_info: Label
var lbl_gold_xp: Label
var lbl_ammo_status: Label
var banner_wanted: PanelContainer
var lbl_wanted_banner: Label
var banner_timer: float = 0.0

# --- 战场即时升级弹窗 (边打边升 & 空投武器合成超武) ---
var level_up_modal: Control
var level_up_cards_hbox: HBoxContainer
var lbl_level_up_sub: Label

# --- 战场战术暂停面板 ([ESC / P / 手柄Start]) ---
var pause_modal: Control
var lbl_pause_summary: Label
var btn_pause_resume: Button
var btn_pause_mute: Button

func _ready() -> void:
	GameState.level_up_triggered.connect(_on_battlefield_level_up)
	GameState.super_weapon_evolved.connect(_on_super_weapon_evolved)

	drops_container = Node2D.new()
	drops_container.name = "DropsContainer"
	add_child(drops_container)

	enemies_container = Node2D.new()
	enemies_container.name = "EnemiesContainer"
	add_child(enemies_container)

	player_tank = Node2D.new()
	player_tank.name = "PlayerTank"
	player_tank.set_script(PlayerTankScript)
	add_child(player_tank)

	projectiles_container = Node2D.new()
	projectiles_container.name = "ProjectilesContainer"
	add_child(projectiles_container)

	fx_layer = Node2D.new()
	fx_layer.name = "FXLayer"
	fx_layer.set_script(FloatingTextScript)
	add_child(fx_layer)

	_build_hud()
	_generate_wasteland_craters()

func _generate_wasteland_craters() -> void:
	craters.clear()
	for i in range(22):
		craters.append({
			"pos": Vector2(randf_range(arena_rect.position.x + 40, arena_rect.end.x - 40), randf_range(arena_rect.position.y + 40, arena_rect.end.y - 40)),
			"radius": randf_range(16.0, 48.0),
			"shade": randf_range(0.08, 0.16)
		})

func _build_hud() -> void:
	hud_layer = CanvasLayer.new()
	add_child(hud_layer)

	# 顶部战术面板
	var top_bar := PanelContainer.new()
	top_bar.position = Vector2(20, 10)
	top_bar.custom_minimum_size = Vector2(1400, 68)
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.11, 0.10, 0.09, 0.90)
	style.border_color = Color(0.75, 0.48, 0.20)
	style.set_border_width_all(2)
	style.set_corner_radius_all(6)
	top_bar.add_theme_stylebox_override("panel", style)
	hud_layer.add_child(top_bar)

	var hbox := HBoxContainer.new()
	hbox.add_theme_constant_override("separation", 28)
	top_bar.add_child(hbox)

	# 左侧：SP装甲片与载重状态
	var vbox_left := VBoxContainer.new()
	vbox_left.custom_minimum_size = Vector2(420, 0)
	hbox.add_child(vbox_left)

	lbl_sp_info = Label.new()
	lbl_sp_info.add_theme_font_size_override("font_size", 16)
	lbl_sp_info.add_theme_color_override("font_color", Color(0.35, 0.98, 0.55))
	vbox_left.add_child(lbl_sp_info)

	lbl_weight_info = Label.new()
	lbl_weight_info.add_theme_font_size_override("font_size", 13)
	lbl_weight_info.add_theme_color_override("font_color", Color(0.92, 0.80, 0.45))
	vbox_left.add_child(lbl_weight_info)

	# 中间：波次与倒计时
	lbl_wave_timer = Label.new()
	lbl_wave_timer.custom_minimum_size = Vector2(360, 0)
	lbl_wave_timer.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl_wave_timer.add_theme_font_size_override("font_size", 24)
	lbl_wave_timer.add_theme_color_override("font_color", Color(1.0, 0.88, 0.32))
	hbox.add_child(lbl_wave_timer)

	# 右侧：赏金G、猎人等级与主炮弹药
	var vbox_right := VBoxContainer.new()
	vbox_right.custom_minimum_size = Vector2(520, 0)
	hbox.add_child(vbox_right)

	lbl_gold_xp = Label.new()
	lbl_gold_xp.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	lbl_gold_xp.add_theme_font_size_override("font_size", 16)
	lbl_gold_xp.add_theme_color_override("font_color", Color(1.0, 0.85, 0.25))
	vbox_right.add_child(lbl_gold_xp)

	lbl_ammo_status = Label.new()
	lbl_ammo_status.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	lbl_ammo_status.add_theme_font_size_override("font_size", 13)
	lbl_ammo_status.add_theme_color_override("font_color", Color(0.82, 0.90, 0.98))
	vbox_right.add_child(lbl_ammo_status)

	# 底部键位提示栏
	var bottom_lbl := Label.new()
	bottom_lbl.position = Vector2(36, 842)
	bottom_lbl.text = "【键鼠/手柄双支持】 [WASD/左摇杆]驾驶冲撞  [鼠标/右摇杆+RT/RB]主炮瞄准开火  [Q/LT/LB]C装置全弹发射  [E/手柄X]跳车/核爆  [空格/手柄A/B]步兵翻滚  [R/手柄Y]切换自动主炮"
	bottom_lbl.add_theme_font_size_override("font_size", 13)
	bottom_lbl.add_theme_color_override("font_color", Color(0.85, 0.78, 0.65))
	hud_layer.add_child(bottom_lbl)

	# 赏金首乱入警告横幅
	banner_wanted = PanelContainer.new()
	banner_wanted.position = Vector2(320, 95)
	banner_wanted.custom_minimum_size = Vector2(800, 54)
	var b_style := StyleBoxFlat.new()
	b_style.bg_color = Color(0.65, 0.08, 0.08, 0.92)
	b_style.border_color = Color(1.0, 0.85, 0.20)
	b_style.set_border_width_all(3)
	b_style.set_corner_radius_all(8)
	banner_wanted.add_theme_stylebox_override("panel", b_style)
	banner_wanted.visible = false
	hud_layer.add_child(banner_wanted)

	lbl_wanted_banner = Label.new()
	lbl_wanted_banner.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl_wanted_banner.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	lbl_wanted_banner.add_theme_font_size_override("font_size", 20)
	lbl_wanted_banner.add_theme_color_override("font_color", Color(1.0, 0.95, 0.35))
	banner_wanted.add_child(lbl_wanted_banner)

	# 战场即时升级弹窗 (边打边升：三选一属性或空投武器)
	level_up_modal = Control.new()
	level_up_modal.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	level_up_modal.visible = false
	hud_layer.add_child(level_up_modal)

	var lu_bg := ColorRect.new()
	lu_bg.color = Color(0.04, 0.04, 0.05, 0.78)
	lu_bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	level_up_modal.add_child(lu_bg)

	var lu_panel := PanelContainer.new()
	lu_panel.position = Vector2(220, 210)
	lu_panel.custom_minimum_size = Vector2(1000, 440)
	var lu_style := StyleBoxFlat.new()
	lu_style.bg_color = Color(0.14, 0.13, 0.11, 0.98)
	lu_style.border_color = Color(1.0, 0.85, 0.22)
	lu_style.set_border_width_all(3)
	lu_style.set_corner_radius_all(10)
	lu_style.content_margin_left = 20
	lu_style.content_margin_right = 20
	lu_style.content_margin_top = 18
	lu_style.content_margin_bottom = 18
	lu_panel.add_theme_stylebox_override("panel", lu_style)
	level_up_modal.add_child(lu_panel)

	var lu_vbox := VBoxContainer.new()
	lu_vbox.add_theme_constant_override("separation", 16)
	lu_panel.add_child(lu_vbox)

	var lu_title := Label.new()
	lu_title.text = "🎖️ 猎人战场即时升级！(战术时停：请选择一项强化或空投武器补给)"
	lu_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lu_title.add_theme_font_size_override("font_size", 24)
	lu_title.add_theme_color_override("font_color", Color(1.0, 0.90, 0.28))
	lu_vbox.add_child(lu_title)

	lbl_level_up_sub = Label.new()
	lbl_level_up_sub.text = "💡 提示：集齐特定两把关联武器并升级至 ★2 (或拾取战场宝箱)，将自动融合进化为不占槽位的【★6 神话超武】！"
	lbl_level_up_sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl_level_up_sub.add_theme_font_size_override("font_size", 14)
	lbl_level_up_sub.add_theme_color_override("font_color", Color(0.55, 0.95, 1.0))
	lu_vbox.add_child(lbl_level_up_sub)

	level_up_cards_hbox = HBoxContainer.new()
	level_up_cards_hbox.size_flags_vertical = Control.SIZE_EXPAND_FILL
	level_up_cards_hbox.add_theme_constant_override("separation", 18)
	lu_vbox.add_child(level_up_cards_hbox)

	_build_pause_modal()

func _build_pause_modal() -> void:
	pause_modal = Control.new()
	pause_modal.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	pause_modal.visible = false
	hud_layer.add_child(pause_modal)

	var p_bg := ColorRect.new()
	p_bg.color = Color(0.04, 0.04, 0.05, 0.86)
	p_bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	pause_modal.add_child(p_bg)

	var p_panel := PanelContainer.new()
	p_panel.position = Vector2(360, 175)
	p_panel.custom_minimum_size = Vector2(720, 490)
	var p_style := StyleBoxFlat.new()
	p_style.bg_color = Color(0.14, 0.13, 0.11, 0.98)
	p_style.border_color = Color(0.95, 0.72, 0.25)
	p_style.set_border_width_all(3)
	p_style.set_corner_radius_all(10)
	p_style.content_margin_left = 24
	p_style.content_margin_right = 24
	p_style.content_margin_top = 20
	p_style.content_margin_bottom = 20
	p_panel.add_theme_stylebox_override("panel", p_style)
	pause_modal.add_child(p_panel)

	var p_vbox := VBoxContainer.new()
	p_vbox.add_theme_constant_override("separation", 14)
	p_panel.add_child(p_vbox)

	var p_title := Label.new()
	p_title.text = "⏸️ 【战术时停：战车状态与系统菜单】"
	p_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	p_title.add_theme_font_size_override("font_size", 24)
	p_title.add_theme_color_override("font_color", Color(1.0, 0.88, 0.30))
	p_vbox.add_child(p_title)

	lbl_pause_summary = Label.new()
	lbl_pause_summary.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	lbl_pause_summary.size_flags_vertical = Control.SIZE_EXPAND_FILL
	lbl_pause_summary.add_theme_font_size_override("font_size", 14)
	lbl_pause_summary.add_theme_color_override("font_color", Color(0.92, 0.90, 0.85))
	p_vbox.add_child(lbl_pause_summary)

	btn_pause_resume = Button.new()
	btn_pause_resume.custom_minimum_size = Vector2(0, 46)
	btn_pause_resume.text = "▶️ 继续战斗 ([ESC / P / 手柄Start])"
	btn_pause_resume.add_theme_font_size_override("font_size", 18)
	btn_pause_resume.pressed.connect(_toggle_pause_modal)
	p_vbox.add_child(btn_pause_resume)

	btn_pause_mute = Button.new()
	btn_pause_mute.custom_minimum_size = Vector2(0, 44)
	btn_pause_mute.text = "🔊 切换音乐与音效静音 ([M]键)"
	btn_pause_mute.add_theme_font_size_override("font_size", 16)
	btn_pause_mute.pressed.connect(func():
		var is_m: bool = SoundManager.toggle_mute()
		btn_pause_mute.text = ("🔇 当前已静音 (点击恢复声音 [M])" if is_m else "🔊 切换音乐与音效静音 ([M]键)")
	)
	p_vbox.add_child(btn_pause_mute)

	var btn_pause_retire := Button.new()
	btn_pause_retire.custom_minimum_size = Vector2(0, 44)
	btn_pause_retire.text = "🏳️ 提前结束本局狩猎 ➔ 前往明奇研究所结算【💎诺亚晶片】"
	btn_pause_retire.add_theme_font_size_override("font_size", 16)
	btn_pause_retire.pressed.connect(func():
		pause_modal.visible = false
		on_player_total_defeat()
	)
	p_vbox.add_child(btn_pause_retire)

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("toggle_mute"):
		var is_m: bool = SoundManager.toggle_mute()
		if visible and is_instance_valid(fx_layer) and is_instance_valid(player_tank):
			fx_layer.spawn_text(player_tank.get_active_position() + Vector2(0, -24), "🔇 音频已静音" if is_m else "🔊 音频已恢复", Color(0.6, 0.95, 1.0), 1.1)
		return
	if not visible or level_up_modal.visible:
		return
	if event.is_action_pressed("pause_game"):
		get_viewport().set_input_as_handled()
		_toggle_pause_modal()

func _toggle_pause_modal() -> void:
	if level_up_modal.visible:
		return
	if pause_modal.visible:
		pause_modal.visible = false
		wave_active = true
	else:
		wave_active = false
		pause_modal.visible = true
		var w_names: Array = []
		for ew in GameState.equipped_weapons:
			var wd: Dictionary = GameData.WEAPONS[ew["id"]]
			w_names.append("%s %s" % [wd["name"], GameData.RARITY_NAMES[int(ew.get("rarity", 0))]])
		var w_str: String = " | ".join(w_names) if not w_names.is_empty() else "无"
		lbl_pause_summary.text = "• 当前战区：%s [%s] (第 %d / %d 波)\n• 猎人：%s  |  底盘：%s\n• 引擎载重：%.1ft / %.1ft (剩余 %.1ft ➔ 装甲 %d SP)\n• 暴击率：%d%%  |  闪避率：%d%%  |  每秒自动修车：+%.0f SP\n• 已装备武器 (%d/%d)：\n  %s" % [
			GameState.get_current_map_def()["name"], GameState.get_current_difficulty_def()["name"],
			GameState.current_wave, GameState.max_waves,
			GameData.HUNTERS[GameState.selected_hunter_id]["name"],
			GameData.CHASSIS[GameState.selected_chassis_id]["name"],
			GameState.used_weight, GameState.max_weight, GameState.free_weight, int(GameState.max_sp),
			int(GameState.crit_chance * 100.0), int(GameState.dodge_chance * 100.0), GameState.sp_regen_per_sec,
			GameState.equipped_weapons.size(), GameState.chassis_slots.size(), w_str
		]
		btn_pause_mute.text = ("🔇 当前已静音 (点击恢复声音 [M])" if SoundManager.muted else "🔊 切换音乐与音效静音 ([M]键)")
		btn_pause_resume.call_deferred("grab_focus")

func start_wave() -> void:
	_clear_entities()
	tread_marks.clear()
	_generate_wasteland_craters()
	SoundManager.play_bgm("bgm_battle_wasteland")
	pause_modal.visible = false
	level_up_modal.visible = false

	wave_active = true
	wave_elapsed = 0.0
	wave_time_left = minf(50.0, 28.0 + GameState.current_wave * 2.0)
	if GameState.current_wave == GameState.max_waves:
		wave_time_left = 75.0 # 第10波关底统帅赏金首死斗
		GameState.active_wanted_boss_id = GameState.get_current_map_def()["final_boss_id"]

	boss_spawned_this_wave = false
	spawn_timer = 0.5
	elite_spawn_timer = 10.5
	fx_layer.mortar_strikes.clear()

	player_tank.init_for_wave(arena_rect.get_center())

	# 王牌猎人每波必刷埋藏金属宝箱 + 高敏金属探测器执照翻倍
	var chest_cnt: int = int(GameState.bonus_stats.get("guaranteed_chest", 0))
	if GameState.is_feature_unlocked("detector_unlock"):
		chest_cnt += 1
	if randf() < 0.45:
		chest_cnt += 1
	for i in range(chest_cnt):
		var cpos := Vector2(randf_range(arena_rect.position.x + 120, arena_rect.end.x - 120), randf_range(arena_rect.position.y + 120, arena_rect.end.y - 120))
		spawn_drop("buried_chest", 1, cpos)

func _clear_entities() -> void:
	for c in enemies_container.get_children():
		c.queue_free()
	for c in projectiles_container.get_children():
		c.queue_free()
	for c in drops_container.get_children():
		c.queue_free()
	spawn_telegraphs.clear()

func _process(delta: float) -> void:
	if not wave_active:
		return

	wave_elapsed += delta
	wave_time_left -= delta

	if banner_timer > 0.0:
		banner_timer -= delta
		if banner_timer <= 0.0:
			banner_wanted.visible = false

	# 屏幕震动
	if shake_timer > 0.0:
		shake_timer -= delta
		position = Vector2(randf_range(-shake_intensity, shake_intensity), randf_range(-shake_intensity, shake_intensity))
	else:
		position = Vector2.ZERO

	# 1. 检查是否到达赏金首乱入时间 (常规波次 5.5 秒后乱入，第10波关底决战 2.5 秒直接降临!)
	var boss_enter_delay: float = 2.5 if GameState.current_wave >= GameState.max_waves else 5.5
	if not boss_spawned_this_wave and GameState.active_wanted_boss_id != "" and wave_elapsed >= boss_enter_delay:
		boss_spawned_this_wave = true
		wave_time_left = maxf(wave_time_left + 15.0, 45.0)
		_spawn_wanted_boss(GameState.active_wanted_boss_id)

	# 2. 红狼乱入救援事件 (当挑战赏金首且战车SP低于25%时触发)
	if boss_spawned_this_wave and not red_wolf_rescued_this_run and not player_tank.is_human_mode:
		if player_tank.current_sp > 0.0 and player_tank.current_sp <= GameState.max_sp * 0.25:
			_trigger_red_wolf_rescue()

	# 3. 常规刷怪与定时重装精英怪降临
	elite_spawn_timer -= delta
	if elite_spawn_timer <= 0.0:
		elite_spawn_timer = 11.5
		_spawn_map_elite()

	spawn_timer -= delta
	if spawn_timer <= 0.0:
		var spawn_mult: float = float(GameState.get_current_difficulty_def().get("spawn_mult", 1.0))
		var interval: float = maxf(0.35, (1.40 - GameState.current_wave * 0.05) / spawn_mult)
		spawn_timer = interval
		var batch: int = 1 + int(GameState.current_wave / 3)
		for i in range(batch):
			_queue_enemy_spawn()

	for i in range(spawn_telegraphs.size() - 1, -1, -1):
		spawn_telegraphs[i]["timer"] -= delta
		if spawn_telegraphs[i]["timer"] <= 0.0:
			_do_spawn_enemy(spawn_telegraphs[i]["id"], spawn_telegraphs[i]["pos"])
			spawn_telegraphs.remove_at(i)

	# 4. 波次倒计时结束判定 (第10波关底决战若统帅存活则进入无限决战直到击杀统帅!)
	if wave_time_left <= 0.0:
		if GameState.current_wave >= GameState.max_waves and _has_alive_boss():
			wave_time_left = 0.0
		else:
			_finish_wave_success()
			return

	_update_hud()
	queue_redraw()

func _has_alive_boss() -> bool:
	for e in enemies_container.get_children():
		if is_instance_valid(e) and e.get("is_boss") == true:
			return true
	return false

func _queue_enemy_spawn() -> void:
	if enemies_container.get_child_count() >= 55:
		return
	var pos := Vector2(
		randf_range(arena_rect.position.x + 45, arena_rect.end.x - 45),
		randf_range(arena_rect.position.y + 45, arena_rect.end.y - 45)
	)
	if pos.distance_to(player_tank.get_active_position()) < 220.0:
		pos = arena_rect.get_center() + (pos - arena_rect.get_center()).normalized() * 340.0
		pos.x = clampf(pos.x, arena_rect.position.x + 45, arena_rect.end.x - 45)
		pos.y = clampf(pos.y, arena_rect.position.y + 45, arena_rect.end.y - 45)

	var m_pool: Array = GameState.get_current_map_def().get("enemy_pool", ["bio_ant", "kamikaze_wheel"])
	var chosen: String = String(m_pool[randi() % m_pool.size()])
	spawn_telegraphs.append({"id": chosen, "pos": pos, "timer": 0.85})

func _do_spawn_enemy(e_id: String, pos: Vector2) -> void:
	var e := Node2D.new()
	e.set_script(EnemyScript)
	enemies_container.add_child(e)
	e.setup_regular(GameData.ENEMIES[e_id], GameState.current_wave, pos)

func _spawn_map_elite() -> void:
	var e_pool: Array = GameState.get_current_map_def().get("elite_pool", ["auto_tank"])
	if e_pool.is_empty():
		return
	var chosen_id: String = String(e_pool[randi() % e_pool.size()])
	var pos := Vector2(
		randf_range(arena_rect.position.x + 80, arena_rect.end.x - 80),
		randf_range(arena_rect.position.y + 80, arena_rect.end.y - 80)
	)
	if pos.distance_to(player_tank.get_active_position()) < 260.0:
		pos = arena_rect.get_center() + (pos - arena_rect.get_center()).normalized() * 360.0
		pos.x = clampf(pos.x, arena_rect.position.x + 60, arena_rect.end.x - 60)
		pos.y = clampf(pos.y, arena_rect.position.y + 60, arena_rect.end.y - 60)
	_do_spawn_enemy(chosen_id, pos)
	fx_layer.spawn_text(pos + Vector2(0, -24), "⚡ 重装精英乱入：%s !" % GameData.ENEMIES[chosen_id]["name"], Color(1.0, 0.85, 0.20), 1.25)

func _spawn_wanted_boss(boss_id: String) -> void:
	var boss_def: Dictionary = {}
	for b in GameData.WANTED_BOSSES:
		if b["id"] == boss_id:
			boss_def = b
			break
	if boss_def.is_empty():
		return

	var spawn_pos := Vector2(arena_rect.end.x - 120.0, arena_rect.get_center().y)
	var boss := Node2D.new()
	boss.set_script(EnemyScript)
	enemies_container.add_child(boss)
	boss.setup_boss(boss_def, GameState.current_wave, spawn_pos)

	SoundManager.play("wanted_siren", 0.02, 2.5)
	SoundManager.play_bgm("bgm_wanted_boss", -5.5)
	trigger_screen_shake(10.0, 0.45)
	banner_wanted.visible = true
	banner_timer = 5.0
	lbl_wanted_banner.text = "⚠️ 赏金首乱入警告：【%s】 (悬赏金 %d G) ⚠️" % [boss_def["name"], int(boss_def["bounty"])]

func _trigger_red_wolf_rescue() -> void:
	red_wolf_rescued_this_run = true
	SoundManager.play("cannon_heavy", 0.02, 4.0)
	trigger_screen_shake(16.0, 0.5)
	banner_wanted.visible = true
	banner_timer = 4.5
	lbl_wanted_banner.text = "🔥 传奇猎人【红狼 (Red Wolf)】驾驶红狼号乱入支援！！ 🔥"

	var p_pos: Vector2 = player_tank.global_position
	fx_layer.spawn_laser_beam(Vector2(arena_rect.position.x, p_pos.y), Vector2(arena_rect.end.x, p_pos.y), Color(1.0, 0.2, 0.15), 18.0)
	for e in enemies_container.get_children():
		if is_instance_valid(e):
			fx_layer.spawn_explosion(e.global_position, 110.0, Color(1.0, 0.25, 0.15))
			e.take_damage(850.0 + GameState.current_wave * 90.0, true, "cluster", p_pos, true)

	player_tank.heal_sp(GameState.max_sp * 0.45)
	player_tank.refill_all_ammo(8)
	spawn_drop("buried_chest", 1, p_pos + Vector2(60, 0))

func on_wanted_boss_defeated(boss_node: Node2D) -> void:
	var b_id: String = boss_node.enemy_id
	if not (b_id in GameState.defeated_wanted_ids):
		GameState.defeated_wanted_ids.append(b_id)
	GameState.active_wanted_boss_id = ""
	GameState.bounties_hunted += 1
	var final_bounty: int = boss_node.bounty_gold
	if GameState.is_feature_unlocked("black_market_wanted"):
		final_bounty = int(final_bounty * 1.25)
	GameState.add_gold(final_bounty)
	GameState.noah_chips += 25
	GameState.save_meta_data()

	SoundManager.play("upgrade", 0.02, 3.0)
	trigger_screen_shake(14.0, 0.4)
	banner_wanted.visible = true
	banner_timer = 5.0

	# 奖励赏金首专属红装或合成
	var rw_id: String = boss_node.reward_weapon_id
	var rw_name: String = GameData.WEAPONS.get(rw_id, {}).get("name", "传奇红武")
	var res: Dictionary = GameState.add_weapon_to_first_valid_slot(rw_id, 4)
	if res.get("equipped", false) or res.get("merged", false):
		lbl_wanted_banner.text = "🏆 击杀赏金首【%s】! 赏金 +%dG | 诺亚晶片 +25💎 | 战利品【%s】!" % [boss_node.enemy_name, final_bounty, rw_name]
	else:
		GameState.add_gold(200)
		lbl_wanted_banner.text = "🏆 击杀赏金首【%s】! 赏金 +%dG | 诺亚晶片 +25💎 (满槽折算+200G)!" % [boss_node.enemy_name, final_bounty]

	var final_b_id: String = GameState.get_current_map_def()["final_boss_id"]
	if b_id == final_b_id or b_id == "boss_noah":
		wave_active = false
		emit_signal("game_victory")
	else:
		SoundManager.play_bgm("bgm_battle_wasteland")

func trigger_zombie_shock(pos: Vector2) -> void:
	fx_layer.spawn_explosion(pos, 115.0, Color(0.55, 0.35, 1.0))
	fx_layer.spawn_text(pos, "明奇电击僵尸脉冲!", Color(0.65, 0.5, 1.0), 1.05)
	for e in enemies_container.get_children():
		if is_instance_valid(e) and pos.distance_to(e.global_position) <= 130.0:
			e.take_damage(75.0 + GameState.level * 12.0, false, "electric", pos, false)

# --- 战场边打边升：即时三选一弹窗与空投武器合成超武 ---
func _on_battlefield_level_up() -> void:
	if not visible or GameState.pending_level_ups <= 0:
		return
	wave_active = false
	level_up_modal.visible = true
	SoundManager.play("upgrade", 0.04, 1.5)
	_populate_battlefield_level_cards()

func _populate_battlefield_level_cards() -> void:
	for c in level_up_cards_hbox.get_children():
		c.queue_free()

	var show_hints: bool = GameState.should_show_build_hints()
	if show_hints:
		lbl_level_up_sub.text = "💡 提示：集齐特定两把关联武器并升级至 ★2 (或拾取战场宝箱)，将自动融合进化为不占槽位的【★6 神话超武】！"
	else:
		lbl_level_up_sub.text = "🔴 【地狱模式硬核法则】已隐藏流派羁绊与超武配件合成提示，全凭老猎人直觉与记忆盲配！"

	# 前 2 张卡：猎人驾驶/改装属性强化 (+即时回复 15% 战车SP)
	var perks: Array = GameData.LEVEL_PERKS.duplicate()
	perks.shuffle()
	for i in range(2):
		var p: Dictionary = perks[i]
		var btn := Button.new()
		btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		btn.size_flags_vertical = Control.SIZE_EXPAND_FILL
		btn.text = "🎖️ 【战术专精 Lv.%d】\n\n★ %s\n%s\n\n(+立即恢复 15%% 战车SP)" % [GameState.level, p["name"], p["desc"]]
		btn.add_theme_font_size_override("font_size", 16)
		btn.pressed.connect(func():
			var st: String = p["stat"]
			GameState.bonus_stats[st] = GameState.bonus_stats.get(st, 0.0) + float(p["val"])
			GameState.pending_level_ups = max(0, GameState.pending_level_ups - 1)
			GameState.recalculate_stats()
			player_tank.heal_sp(GameState.max_sp * 0.15)
			SoundManager.play("coin", 0.08, 0.0)
			_close_or_next_level_modal()
		)
		level_up_cards_hbox.add_child(btn)

	# 第 3 张卡：战场空投武器补给 (简单/困难难度下提示二合一与超武合成配方，地狱难度不提示!)
	var airdrop_w_id: String = _pick_smart_airdrop_weapon()
	var w_def: Dictionary = GameData.WEAPONS[airdrop_w_id]
	var evo_partner_name: String = GameState.check_super_evolution_partner(airdrop_w_id)
	var can_merge: bool = false
	for ew in GameState.equipped_weapons:
		if ew["id"] == airdrop_w_id and int(ew.get("rarity", 0)) < 4:
			can_merge = true
			break

	var tag_hint: String = ""
	if show_hints:
		var syn_names: Array = []
		for t in w_def.get("tags", []):
			if GameData.SYNERGIES.has(t):
				syn_names.append(GameData.SYNERGIES[t]["name"])
		if not syn_names.is_empty():
			tag_hint += "\n【流派: %s】" % "/".join(syn_names)
		if evo_partner_name != "":
			tag_hint += "\n🌟【超武配方组件！可合成：%s】" % evo_partner_name
		elif can_merge:
			tag_hint += "\n🔥【同名武器！拾取直接二合一升星！】"

	var air_btn := Button.new()
	air_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	air_btn.size_flags_vertical = Control.SIZE_EXPAND_FILL
	air_btn.text = "🪂 【战场空投武器补给】\n\n[%s] %s\n基础伤: %.0f | 重量: %.1ft\n%s%s" % [
		w_def["slot"], w_def["name"], float(w_def["base_dmg"]), float(w_def["weight"]), w_def["desc"], tag_hint
	]
	air_btn.add_theme_font_size_override("font_size", 15)
	air_btn.pressed.connect(func():
		GameState.pending_level_ups = max(0, GameState.pending_level_ups - 1)
		# 如果没有对应空槽且不能直接二合一，则自动扩充/改孔一个槽位装入空投武器！
		if not GameState.can_equip_or_merge(airdrop_w_id, 0):
			if GameState.chassis_slots.size() < 7:
				GameState.chassis_slots.append(w_def["slot"])
			elif GameState.chassis_slots.size() > 0:
				GameState.chassis_slots[GameState.chassis_slots.size() - 1] = w_def["slot"]
		GameState.add_weapon_to_first_valid_slot(airdrop_w_id, 0, true)
		player_tank.sync_weapons_from_state(1.0 + GameState.get_meta_level("meta_reload") * 0.15)
		player_tank.heal_sp(GameState.max_sp * 0.15)
		SoundManager.play("upgrade", 0.05, 1.5)
		_close_or_next_level_modal()
	)
	level_up_cards_hbox.add_child(air_btn)
	if level_up_cards_hbox.get_child_count() > 0:
		(level_up_cards_hbox.get_child(0) as Control).call_deferred("grab_focus")

func _pick_smart_airdrop_weapon() -> String:
	var candidates: Array = []
	var priority: Array = []
	for k in GameData.WEAPONS.keys():
		var wid: String = String(k)
		var def: Dictionary = GameData.WEAPONS[wid]
		if def.get("is_evo", false) or wid.begins_with("boss_"):
			continue
		if GameState.bonus_stats.get("no_main_cannon", false) and def["slot"] == "MAIN":
			continue
		candidates.append(wid)
		if GameState.check_super_evolution_partner(wid) != "":
			priority.append(wid)
		else:
			for ew in GameState.equipped_weapons:
				if ew["id"] == wid and int(ew.get("rarity", 0)) < 4:
					priority.append(wid)
					break
	if GameState.should_show_build_hints() and not priority.is_empty() and randf() < 0.72:
		return priority[randi() % priority.size()]
	return candidates[randi() % candidates.size()]

func _close_or_next_level_modal() -> void:
	if GameState.pending_level_ups > 0:
		_populate_battlefield_level_cards()
	else:
		level_up_modal.visible = false
		wave_active = true
		_update_hud()

func _on_super_weapon_evolved(evo_info: Dictionary) -> void:
	SoundManager.play("mince_revive", 0.02, 3.5)
	trigger_screen_shake(15.0, 0.45)
	banner_wanted.visible = true
	banner_timer = 6.0
	lbl_wanted_banner.text = "🌟 【隐藏超武合成触发！】 [%s] + [%s] ➔ 进化为 %s！！ 🌟" % [
		evo_info["comp_a_name"], evo_info["comp_b_name"], evo_info["evo_name"]
	]
	if is_instance_valid(player_tank) and is_instance_valid(fx_layer):
		fx_layer.spawn_explosion(player_tank.get_active_position(), 200.0, Color(1.0, 0.88, 0.20))
		fx_layer.spawn_text(player_tank.get_active_position() + Vector2(0, -36), "★ 神话超武诞生：%s ★" % evo_info["evo_name"], Color(1.0, 0.90, 0.20), 1.55)

func _finish_wave_success() -> void:
	wave_active = false
	# 废铁大亨 (2) 赏金利息结算
	if GameState.synergy_counts.get("tycoon", 0) >= 2:
		var interest: int = int(GameState.gold * 0.15)
		GameState.gold += interest
	# 暴龙生物战车每3波进化增加1个槽位(最多7槽)
	if GameState.selected_chassis_id == "tyrannos" and GameState.current_wave % 3 == 0 and GameState.chassis_slots.size() < 7:
		var new_slots: Array = ["MAIN", "SUB", "SE"]
		GameState.chassis_slots.append(new_slots[GameState.current_wave % 3])

	if GameState.current_wave >= GameState.max_waves:
		emit_signal("game_victory")
	else:
		emit_signal("wave_completed")

func on_player_total_defeat() -> void:
	wave_active = false
	emit_signal("player_defeated")

func spawn_player_projectile(pos: Vector2, dir: Vector2, spd: float, dmg: float, splash: float, effect: String, is_crit: bool, is_main: bool, pierce: int) -> void:
	var p := Node2D.new()
	p.set_script(ProjectileScript)
	projectiles_container.add_child(p)
	p.setup_player_proj(pos, dir, spd, dmg, splash, effect, is_crit, is_main, pierce)

func spawn_enemy_projectile(pos: Vector2, dir: Vector2, spd: float, dmg: float, col: Color = Color(1.0, 0.25, 0.35), rad: float = 6.5, eff: String = "") -> void:
	var p := Node2D.new()
	p.set_script(ProjectileScript)
	projectiles_container.add_child(p)
	p.setup_enemy_proj(pos, dir, spd, dmg, col, rad, eff)

func spawn_drop(d_type: String, val: int, pos: Vector2) -> void:
	var d := Node2D.new()
	d.set_script(DropItemScript)
	drops_container.add_child(d)
	d.setup(d_type, val, pos)

func get_nearest_enemy(from_pos: Vector2, max_range: float) -> Node2D:
	var best: Node2D = null
	var best_d: float = max_range
	for e in enemies_container.get_children():
		if is_instance_valid(e):
			var d: float = from_pos.distance_to(e.global_position)
			if d < best_d:
				best_d = d
				best = e
	return best

func get_highest_threat_enemy(from_pos: Vector2, max_range: float) -> Node2D:
	var best: Node2D = null
	var best_score: float = -1.0
	for e in enemies_container.get_children():
		if is_instance_valid(e):
			var d: float = from_pos.distance_to(e.global_position)
			if d <= max_range:
				var score: float = (10000.0 if e.is_boss else e.max_hp) - d * 0.4
				if score > best_score:
					best_score = score
					best = e
	return best

func add_tread_mark(pos: Vector2, angle: float) -> void:
	tread_marks.append({"pos": pos, "angle": angle})
	if tread_marks.size() > 90:
		tread_marks.pop_front()

func trigger_screen_shake(intensity: float, duration: float) -> void:
	shake_intensity = maxf(shake_intensity, intensity)
	shake_timer = maxf(shake_timer, duration)

func _update_hud() -> void:
	if player_tank.is_human_mode:
		lbl_sp_info.text = "⚠️ 【步兵肉搏模式】 人类HP: %d / %d  (靠近战车残骸抢修!)" % [int(player_tank.human_hp), int(GameState.max_human_hp)]
		lbl_sp_info.add_theme_color_override("font_color", Color(1.0, 0.42, 0.35))
	else:
		lbl_sp_info.text = "🛡️ 战车装甲片 (SP): %d / %d   (+%.0f SP/秒)" % [int(player_tank.current_sp), int(GameState.max_sp), GameState.sp_regen_per_sec]
		lbl_sp_info.add_theme_color_override("font_color", Color(0.35, 0.98, 0.55))

	lbl_weight_info.text = "⚙️ 引擎载重: %.1ft / %.1ft (剩余 %.1ft ➔ 转化 %.0f SP) | [Q]全弹发射: %s" % [
		GameState.used_weight, GameState.max_weight, GameState.free_weight, GameState.max_sp,
		"就绪 READY!" if player_tank.all_out_timer <= 0.0 else "%.1f秒" % player_tank.all_out_timer
	]

	var m_name: String = GameState.get_current_map_def()["name"].substr(0, 9)
	var d_name: String = GameState.get_current_difficulty_def()["name"].substr(0, 4)
	var t_str: String = "⚡决战统帅!" if (wave_time_left <= 0.0 and GameState.current_wave >= GameState.max_waves) else "%.1fs" % maxf(0.0, wave_time_left)
	lbl_wave_timer.text = "%s[%s] 第%d/%d波 — %s" % [m_name, d_name, GameState.current_wave, GameState.max_waves, t_str]
	lbl_gold_xp.text = "💰 赏金: %d G   |   🎖️ 猎人 Lv.%d (经验 %d/%d)" % [GameState.gold, GameState.level, GameState.xp, GameState.xp_to_next]

	# 汇总主炮弹药显示
	var ammo_parts: Array = []
	for i in range(GameState.equipped_weapons.size()):
		var w_id: String = GameState.equipped_weapons[i]["id"]
		var w_def: Dictionary = GameData.WEAPONS[w_id]
		if w_def["slot"] == "MAIN" and i < player_tank.weapon_ammo.size():
			var a_str: String = "∞" if int(w_def.get("ammo", 999)) > 500 else str(player_tank.weapon_ammo[i])
			ammo_parts.append("%s[%s发]" % [w_def["name"].substr(0, 6), a_str])
	var mode_str: String = "[自动主炮]" if GameState.auto_main_cannon else "[手动主炮]"
	lbl_ammo_status.text = "%s 主炮弹药: %s" % [mode_str, " | ".join(ammo_parts) if ammo_parts.size() > 0 else "无主炮(副炮/SE特化)"]

func _draw() -> void:
	var m_def: Dictionary = GameState.get_current_map_def()
	var bg_col: Color = m_def.get("bg_color", Color(0.22, 0.18, 0.13))
	var grid_col: Color = m_def.get("grid_color", Color(0.26, 0.21, 0.16))
	var border_col: Color = m_def.get("border_color", Color(0.85, 0.52, 0.18))

	# 1. 废土战区专属底色、2D 高清地形贴图平铺与战术网格
	draw_rect(arena_rect, bg_col)
	var ter_tex: Texture2D = GameData.get_terrain_tex(String(m_def.get("id", "map_1")))
	if ter_tex != null:
		var cols: int = 3
		var rows: int = 2
		var cell_w: float = arena_rect.size.x / float(cols)
		var cell_h: float = arena_rect.size.y / float(rows)
		for rx in range(cols):
			for ry in range(rows):
				var tile_rect := Rect2(
					arena_rect.position.x + rx * cell_w,
					arena_rect.position.y + ry * cell_h,
					cell_w,
					cell_h
				)
				draw_texture_rect(ter_tex, tile_rect, false, Color(0.82, 0.82, 0.82, 0.86))

	var grid_line_col: Color = Color(grid_col.r, grid_col.g, grid_col.b, 0.35)
	for x in range(int(arena_rect.position.x), int(arena_rect.end.x), 80):
		draw_line(Vector2(x, arena_rect.position.y), Vector2(x, arena_rect.end.y), grid_line_col, 1.0)
	for y in range(int(arena_rect.position.y), int(arena_rect.end.y), 80):
		draw_line(Vector2(arena_rect.position.x, y), Vector2(arena_rect.end.x, y), grid_line_col, 1.0)

	# 2. 弹坑
	for c in craters:
		draw_circle(c["pos"], c["radius"], bg_col.darkened(0.35))
		draw_arc(c["pos"], c["radius"], 0.0, TAU, 20, grid_col.lightened(0.15), 2.0)

	# 3. 战车履带车辙印
	for tm in tread_marks:
		var dir: Vector2 = Vector2.from_angle(tm["angle"]).orthogonal() * 18.0
		draw_circle(tm["pos"] + dir, 4.0, Color(0.08, 0.07, 0.06, 0.45))
		draw_circle(tm["pos"] - dir, 4.0, Color(0.08, 0.07, 0.06, 0.45))

	# 4. 刷怪红叉预警
	for st in spawn_telegraphs:
		var p: Vector2 = st["pos"]
		draw_arc(p, 20.0, 0.0, TAU, 16, Color(1.0, 0.2, 0.2, 0.8), 2.0)
		draw_line(p - Vector2(10, 10), p + Vector2(10, 10), Color(1.0, 0.2, 0.2, 0.8), 2.5)
		draw_line(p - Vector2(10, -10), p + Vector2(10, -10), Color(1.0, 0.2, 0.2, 0.8), 2.5)

	# 5. 警戒边界框
	draw_rect(arena_rect, border_col, false, 4.0)
