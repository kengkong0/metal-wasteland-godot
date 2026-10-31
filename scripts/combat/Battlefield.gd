extends Node2D
## 《重装废土：赏金狂飙》 - 废土战场主控脚本 (土豆兄弟风格 HUD & 全分辨率自适应版)
## 负责：沙地地形与履带印绘制、波次倒计时、动态刷怪、赏金首巨型血条、升级选卡与战场HUD。

signal wave_completed
signal player_defeated
signal game_victory
signal request_town_hub

const EnemyScript = preload("res://scripts/combat/Enemy.gd")
const ProjectileScript = preload("res://scripts/combat/Projectile.gd")
const DropItemScript = preload("res://scripts/combat/DropItem.gd")
const FloatingTextScript = preload("res://scripts/combat/FloatingText.gd")
const PlayerTankScript = preload("res://scripts/combat/PlayerTank.gd")

var arena_rect: Rect2 = Rect2(0, 0, 2800, 1900)
var wave_active: bool = false
var wave_time_left: float = 35.0
var wave_elapsed: float = 0.0
var spawn_timer: float = 0.0
var elite_spawn_timer: float = 11.0
var boss_spawned_this_wave: bool = false
var red_wolf_rescued_this_run: bool = false

# --- 敌人狂潮、合围机制与连击系统 ---
var current_max_enemies: int = 240
var is_horde_active: bool = false
var horde_announced: bool = false
var ring_spawn_timer: float = 8.0
var combo_count: int = 0
var combo_timer: float = 0.0
var max_combo: int = 0
var lbl_combo: Label

# --- 场景容器节点与跟随镜头 ---
var enemies_container: Node2D
var projectiles_container: Node2D
var drops_container: Node2D
var fx_layer: Node2D
var player_tank: Node2D
var battle_cam: Camera2D
var minimap_ctrl: Control

# --- 视觉装饰与震屏 ---
var tread_marks: Array = []
var craters: Array = []
var landmarks: Array = []
var wasteland_roads: Array = []
var wasteland_fissures: Array = []
var dust_particles: Array = []

# --- 荒原休整小镇与安全区 (Wasteland Rest Town & Safe Zone) ---
var town_pos: Vector2 = Vector2(850.0, 800.0)
var town_radius: float = 190.0
var town_interact_radius: float = 125.0
var town_available: bool = true
var town_visited_this_wave: bool = false
var is_player_in_safe_zone: bool = false
var town_pulse_time: float = 0.0
var btn_enter_town: Button
var spawn_telegraphs: Array = []
var shake_timer: float = 0.0
var shake_intensity: float = 0.0
var shake_dir_impulse: Vector2 = Vector2.ZERO
var _hitstop_active: bool = false

# --- 动态战场随机事件 (Dynamic Arena Events) ---
var active_arena_event: Dictionary = {}
var arena_event_triggered_this_wave: bool = false

# --- 2D 空间哈希网格与节点对象池 (Spatial Hash Grid & Object Pools) ---
const SPATIAL_CELL_SIZE: float = 160.0
var spatial_grid: Dictionary = {}
var _proj_pool: Array = []
var _drop_pool: Array = []

# --- 土豆兄弟风格 HUD 控件 ---
var hud_layer: CanvasLayer
var hud_root: Control
var bar_sp: ProgressBar
var style_sp_fill: StyleBoxFlat
var lbl_sp_val: Label
var bar_xp: ProgressBar
var lbl_xp_val: Label
var bar_weight: ProgressBar
var lbl_weight_val: Label
var bar_all_out: ProgressBar
var style_all_out_fill: StyleBoxFlat
var lbl_all_out_val: Label

var lbl_gold_num: Label
var lbl_chips_num: Label
var lbl_ammo_badge: Label

var lbl_wave_title: Label
var lbl_wave_countdown: Label

# --- 顶部中央赏金首 BOSS 巨型血条 ---
var boss_hp_panel: PanelContainer
var boss_portrait_rect: TextureRect
var bar_boss_hp: ProgressBar
var lbl_boss_hp: Label

var banner_wanted: PanelContainer
var lbl_wanted_banner: Label
var banner_timer: float = 0.0

# --- 战场即时升级弹窗 (土豆兄弟式立式三选一卡片) ---
var level_up_modal: Control
var level_up_cards_hbox: HBoxContainer
var lbl_level_up_sub: Label

# --- 战场战术暂停面板 ([ESC / P / 手柄Start]) ---
var pause_modal: Control
var pause_stats_vbox: VBoxContainer
var pause_weapons_vbox: VBoxContainer
var pause_dps_vbox: VBoxContainer
var btn_pause_resume: Button
var btn_pause_mute: Button

# --- 边缘重要目标指示器、低血量暗角警报与升级刷新 ---
var offscreen_indicators_ctrl: Control
var vignette_ctrl: Control
var btn_reroll_level_cards: Button

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

	battle_cam = Camera2D.new()
	battle_cam.name = "BattleCamera"
	battle_cam.zoom = Vector2(1.38, 1.38)
	battle_cam.position_smoothing_enabled = true
	battle_cam.position_smoothing_speed = 9.5
	battle_cam.limit_left = -220
	battle_cam.limit_top = -180
	battle_cam.limit_right = 3020
	battle_cam.limit_bottom = 2080
	add_child(battle_cam)

	_build_hud()
	_update_arena_bounds()
	_generate_wasteland_craters()

func _update_arena_bounds() -> void:
	# 巨型卷轴废土竞技场 (2800 x 1900，约 4 倍单屏面积，需驾驶战车驰骋探索)
	arena_rect = Rect2(0.0, 0.0, 2800.0, 1900.0)
	if is_instance_valid(battle_cam):
		battle_cam.limit_left = int(arena_rect.position.x - 220.0)
		battle_cam.limit_top = int(arena_rect.position.y - 180.0)
		battle_cam.limit_right = int(arena_rect.end.x + 220.0)
		battle_cam.limit_bottom = int(arena_rect.end.y + 180.0)

func _generate_wasteland_craters() -> void:
	craters.clear()
	landmarks.clear()
	wasteland_roads.clear()
	wasteland_fissures.clear()

	# 1. 废土公路 (横跨战场的破裂柏油公路与废墟路基)
	var road_start := Vector2(arena_rect.position.x, arena_rect.size.y * 0.42)
	var road_mid := Vector2(arena_rect.size.x * 0.5, arena_rect.size.y * 0.48)
	var road_end := Vector2(arena_rect.end.x, arena_rect.size.y * 0.54)
	wasteland_roads.append({"p1": road_start, "p2": road_mid, "width": 110.0, "cracks": []})
	wasteland_roads.append({"p1": road_mid, "p2": road_end, "width": 110.0, "cracks": []})
	for r in wasteland_roads:
		for s in range(14):
			var t: float = float(s) / 14.0
			var pt: Vector2 = r["p1"].lerp(r["p2"], t) + Vector2(randf_range(-36.0, 36.0), randf_range(-36.0, 36.0))
			r["cracks"].append({
				"pos": pt,
				"size": Vector2(randf_range(16.0, 38.0), randf_range(10.0, 24.0)),
				"rot": randf_range(0.0, TAU)
			})

	# 2. 地质断裂与深渊地缝 (Tectonic Fissures)
	for i in range(7):
		var fx: float = randf_range(arena_rect.position.x + 140, arena_rect.end.x - 140)
		var fy: float = randf_range(arena_rect.position.y + 140, arena_rect.end.y - 140)
		var f_cur := Vector2(fx, fy)
		var f_pts: Array = [f_cur]
		var f_dir: float = randf_range(0.0, TAU)
		var num_segs: int = randi_range(5, 8)
		for j in range(num_segs):
			f_dir += randf_range(-0.55, 0.55)
			f_cur += Vector2.from_angle(f_dir) * randf_range(30.0, 58.0)
			f_pts.append(f_cur)
		wasteland_fissures.append({
			"points": f_pts,
			"width": randf_range(3.5, 6.0)
		})

	# 3. 弹坑与沙地凹坑
	for i in range(52):
		craters.append({
			"pos": Vector2(randf_range(arena_rect.position.x + 80, arena_rect.end.x - 80), randf_range(arena_rect.position.y + 80, arena_rect.end.y - 80)),
			"radius": randf_range(22.0, 64.0),
			"shade": randf_range(0.08, 0.16)
		})
	for i in range(36):
		landmarks.append({
			"pos": Vector2(randf_range(arena_rect.position.x + 110, arena_rect.end.x - 110), randf_range(arena_rect.position.y + 110, arena_rect.end.y - 110)),
			"size": Vector2(randf_range(28.0, 56.0), randf_range(18.0, 38.0)),
			"angle": randf_range(0.0, TAU),
			"kind": i % 3
		})

	# 4. 初始化风沙粒子
	if dust_particles.is_empty():
		for i in range(48):
			dust_particles.append({
				"pos": Vector2(randf_range(arena_rect.position.x, arena_rect.end.x), randf_range(arena_rect.position.y, arena_rect.end.y)),
				"spd": randf_range(65.0, 140.0),
				"size": randf_range(1.8, 3.8),
				"alpha": randf_range(0.20, 0.45)
			})

func _build_hud() -> void:
	hud_layer = CanvasLayer.new()
	add_child(hud_layer)

	hud_root = Control.new()
	hud_root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	hud_root.mouse_filter = Control.MOUSE_FILTER_PASS
	hud_layer.add_child(hud_root)

	# 全屏呼吸暗角警报层 (低SP / 步兵模式)
	vignette_ctrl = Control.new()
	vignette_ctrl.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	vignette_ctrl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vignette_ctrl.draw.connect(_draw_danger_vignette)
	hud_root.add_child(vignette_ctrl)

	# 屏幕边缘重要目标追踪指示器 (Boss / 精英 / 宝箱)
	offscreen_indicators_ctrl = Control.new()
	offscreen_indicators_ctrl.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	offscreen_indicators_ctrl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	offscreen_indicators_ctrl.draw.connect(_draw_offscreen_indicators)
	hud_root.add_child(offscreen_indicators_ctrl)

	# =========================================================================
	# 1. 左上角：土豆兄弟风格状态条组 (血条 + 经验条 + 载重/全弹CD条 + 金币弹药图标)
	# =========================================================================
	var tl_margin := MarginContainer.new()
	tl_margin.set_anchors_and_offsets_preset(Control.PRESET_TOP_LEFT)
	tl_margin.add_theme_constant_override("margin_left", 18)
	tl_margin.add_theme_constant_override("margin_top", 12)
	tl_margin.mouse_filter = Control.MOUSE_FILTER_PASS
	hud_root.add_child(tl_margin)

	var tl_vbox := VBoxContainer.new()
	tl_vbox.add_theme_constant_override("separation", 5)
	tl_vbox.mouse_filter = Control.MOUSE_FILTER_PASS
	tl_margin.add_child(tl_vbox)

	# 1.1 战车装甲 (SP) / 步兵生命 (HP) 主血条
	var sp_bar_res: Dictionary = _create_brotato_bar(Vector2(290, 26), Color(0.18, 0.78, 0.36), 15)
	bar_sp = sp_bar_res["bar"]
	style_sp_fill = sp_bar_res["fill_style"]
	lbl_sp_val = sp_bar_res["label"]
	tl_vbox.add_child(sp_bar_res["container"])

	# 1.2 猎人等级与经验条 (XP Bar)
	var xp_bar_res: Dictionary = _create_brotato_bar(Vector2(290, 20), Color(0.20, 0.68, 0.92), 13)
	bar_xp = xp_bar_res["bar"]
	lbl_xp_val = xp_bar_res["label"]
	tl_vbox.add_child(xp_bar_res["container"])

	# 1.3 并排双战术条：引擎载重条 + C装置[Q]全弹发射充能条
	var sub_bars_hbox := HBoxContainer.new()
	sub_bars_hbox.add_theme_constant_override("separation", 6)
	tl_vbox.add_child(sub_bars_hbox)

	var w_bar_res: Dictionary = _create_brotato_bar(Vector2(142, 18), Color(0.88, 0.58, 0.18), 11)
	bar_weight = w_bar_res["bar"]
	lbl_weight_val = w_bar_res["label"]
	sub_bars_hbox.add_child(w_bar_res["container"])

	var ao_bar_res: Dictionary = _create_brotato_bar(Vector2(142, 18), Color(0.65, 0.35, 0.95), 11)
	bar_all_out = ao_bar_res["bar"]
	style_all_out_fill = ao_bar_res["fill_style"]
	lbl_all_out_val = ao_bar_res["label"]
	sub_bars_hbox.add_child(ao_bar_res["container"])

	# 1.4 货币图标与主炮弹药胶囊行 (只用大图标+精简数字，告别冗长文字)
	var currency_hbox := HBoxContainer.new()
	currency_hbox.add_theme_constant_override("separation", 14)
	tl_vbox.add_child(currency_hbox)

	lbl_gold_num = _make_outlined_label("💰 0", 18, Color(1.0, 0.88, 0.25))
	currency_hbox.add_child(lbl_gold_num)

	lbl_chips_num = _make_outlined_label("💎 0", 16, Color(0.42, 0.95, 1.0))
	currency_hbox.add_child(lbl_chips_num)

	lbl_ammo_badge = _make_outlined_label("🎯 ∞", 14, Color(0.90, 0.95, 1.0))
	currency_hbox.add_child(lbl_ammo_badge)

	# =========================================================================
	# 2. 正上方：土豆兄弟风格波次标题 + 超大号倒计时秒表 + 赏金首巨型血条
	# =========================================================================
	var tc_margin := MarginContainer.new()
	tc_margin.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	tc_margin.add_theme_constant_override("margin_top", 8)
	tc_margin.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hud_root.add_child(tc_margin)

	var tc_vbox := VBoxContainer.new()
	tc_vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	tc_vbox.add_theme_constant_override("separation", 2)
	tc_vbox.mouse_filter = Control.MOUSE_FILTER_IGNORE
	tc_margin.add_child(tc_vbox)

	lbl_wave_title = _make_outlined_label("第 1 波", 18, Color(0.96, 0.94, 0.88))
	lbl_wave_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	tc_vbox.add_child(lbl_wave_title)

	lbl_wave_countdown = _make_outlined_label("30", 34, Color(1.0, 0.92, 0.30))
	lbl_wave_countdown.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	tc_vbox.add_child(lbl_wave_countdown)

	lbl_combo = _make_outlined_label("", 16, Color(1.0, 0.45, 0.20))
	lbl_combo.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl_combo.visible = false
	tc_vbox.add_child(lbl_combo)

	# 赏金首 BOSS 巨型血条容器 (平时隐藏，Boss 登场时显示)
	var boss_center := CenterContainer.new()
	boss_center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	tc_vbox.add_child(boss_center)

	boss_hp_panel = PanelContainer.new()
	var bp_style := StyleBoxFlat.new()
	bp_style.bg_color = Color(0.14, 0.06, 0.06, 0.92)
	bp_style.border_color = Color(1.0, 0.80, 0.20)
	bp_style.set_border_width_all(2)
	bp_style.set_corner_radius_all(6)
	bp_style.content_margin_left = 8
	bp_style.content_margin_right = 8
	bp_style.content_margin_top = 4
	bp_style.content_margin_bottom = 4
	boss_hp_panel.add_theme_stylebox_override("panel", bp_style)
	boss_hp_panel.visible = false
	boss_center.add_child(boss_hp_panel)

	var boss_hbox := HBoxContainer.new()
	boss_hbox.add_theme_constant_override("separation", 8)
	boss_hp_panel.add_child(boss_hbox)

	boss_portrait_rect = TextureRect.new()
	boss_portrait_rect.custom_minimum_size = Vector2(36, 26)
	boss_portrait_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	boss_portrait_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	boss_hbox.add_child(boss_portrait_rect)

	var boss_bar_res: Dictionary = _create_brotato_bar(Vector2(440, 22), Color(0.92, 0.18, 0.18), 13)
	bar_boss_hp = boss_bar_res["bar"]
	lbl_boss_hp = boss_bar_res["label"]
	boss_hbox.add_child(boss_bar_res["container"])

	# 赏金首乱入横幅提示
	var banner_center := CenterContainer.new()
	banner_center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	tc_vbox.add_child(banner_center)

	banner_wanted = PanelContainer.new()
	banner_wanted.custom_minimum_size = Vector2(560, 38)
	var b_style := StyleBoxFlat.new()
	b_style.bg_color = Color(0.65, 0.08, 0.08, 0.92)
	b_style.border_color = Color(1.0, 0.85, 0.20)
	b_style.set_border_width_all(2)
	b_style.set_corner_radius_all(6)
	b_style.content_margin_left = 14
	b_style.content_margin_right = 14
	banner_wanted.add_theme_stylebox_override("panel", b_style)
	banner_wanted.visible = false
	banner_center.add_child(banner_wanted)

	lbl_wanted_banner = _make_outlined_label("", 16, Color(1.0, 0.95, 0.35))
	lbl_wanted_banner.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl_wanted_banner.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	banner_wanted.add_child(lbl_wanted_banner)

	# =========================================================================
	# 3. 右上角：快捷功能小按钮 (暂停 / 全屏切换)
	# =========================================================================
	var tr_margin := MarginContainer.new()
	tr_margin.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT)
	tr_margin.add_theme_constant_override("margin_right", 18)
	tr_margin.add_theme_constant_override("margin_top", 12)
	hud_root.add_child(tr_margin)

	var tr_hbox := HBoxContainer.new()
	tr_hbox.add_theme_constant_override("separation", 8)
	tr_margin.add_child(tr_hbox)

	var btn_fs := Button.new()
	btn_fs.text = "🖥️ 全屏[F11]"
	btn_fs.custom_minimum_size = Vector2(96, 32)
	btn_fs.focus_mode = Control.FOCUS_NONE
	btn_fs.pressed.connect(_toggle_fullscreen)
	tr_hbox.add_child(btn_fs)

	var btn_top_pause := Button.new()
	btn_top_pause.text = "⏸️ 暂停[ESC]"
	btn_top_pause.custom_minimum_size = Vector2(98, 32)
	btn_top_pause.focus_mode = Control.FOCUS_NONE
	btn_top_pause.pressed.connect(_toggle_pause_modal)
	tr_hbox.add_child(btn_top_pause)

	# 底部进入休整小镇交互大按钮
	var enter_town_center := CenterContainer.new()
	enter_town_center.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	enter_town_center.offset_bottom = -38
	enter_town_center.offset_top = -98
	enter_town_center.mouse_filter = Control.MOUSE_FILTER_PASS
	hud_root.add_child(enter_town_center)

	btn_enter_town = Button.new()
	btn_enter_town.text = "🏰 进入麦卡休整小镇 [按 E / 空格] (本波限 1 次)"
	btn_enter_town.custom_minimum_size = Vector2(440, 48)
	btn_enter_town.add_theme_font_size_override("font_size", 16)
	var et_style := StyleBoxFlat.new()
	et_style.bg_color = Color(0.12, 0.48, 0.26, 0.94)
	et_style.border_color = Color(0.35, 1.0, 0.65)
	et_style.set_border_width_all(2)
	et_style.set_corner_radius_all(8)
	btn_enter_town.add_theme_stylebox_override("normal", et_style)
	var et_hover := et_style.duplicate()
	et_hover.bg_color = Color(0.18, 0.62, 0.34)
	btn_enter_town.add_theme_stylebox_override("hover", et_hover)
	btn_enter_town.visible = false
	btn_enter_town.pressed.connect(enter_town_hub)
	enter_town_center.add_child(btn_enter_town)

	# =========================================================================
	# 4. 底部居中精简按键图标栏 (自适应任意分辨率底部，永不裁切)
	# =========================================================================
	var bot_margin := MarginContainer.new()
	bot_margin.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	bot_margin.add_theme_constant_override("margin_bottom", 6)
	bot_margin.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hud_root.add_child(bot_margin)

	var bottom_lbl := _make_outlined_label(
		"🕹️ [WASD/左摇杆]移动   🎯 [鼠标/右摇杆+RT]主炮   🚀 [Q/LT]全弹发射   🔧 [E/X]跳车   💨 [空格/A]翻滚   🔄 [R/Y]自动/手动主炮",
		13, Color(0.88, 0.84, 0.74)
	)
	bottom_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	bot_margin.add_child(bottom_lbl)

	# =========================================================================
	# 4.5 右下角：废土战术雷达小地图 (Minimap Radar)
	# =========================================================================
	var br_margin := MarginContainer.new()
	br_margin.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_RIGHT)
	br_margin.add_theme_constant_override("margin_right", 18)
	br_margin.add_theme_constant_override("margin_bottom", 34)
	br_margin.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hud_root.add_child(br_margin)

	var radar_panel := PanelContainer.new()
	radar_panel.custom_minimum_size = Vector2(174, 122)
	var rp_style := StyleBoxFlat.new()
	rp_style.bg_color = Color(0.08, 0.09, 0.12, 0.88)
	rp_style.border_color = Color(0.35, 0.75, 0.55, 0.90)
	rp_style.set_border_width_all(2)
	rp_style.set_corner_radius_all(6)
	rp_style.content_margin_left = 4
	rp_style.content_margin_right = 4
	rp_style.content_margin_top = 4
	rp_style.content_margin_bottom = 4
	radar_panel.add_theme_stylebox_override("panel", rp_style)
	radar_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	br_margin.add_child(radar_panel)

	minimap_ctrl = Control.new()
	minimap_ctrl.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	minimap_ctrl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	radar_panel.add_child(minimap_ctrl)
	minimap_ctrl.draw.connect(_draw_minimap)

	# =========================================================================
	# 5. 战场即时升级弹窗 (土豆兄弟风格：居中立式卡片三选一)
	# =========================================================================
	level_up_modal = Control.new()
	level_up_modal.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	level_up_modal.visible = false
	hud_root.add_child(level_up_modal)

	var lu_bg := ColorRect.new()
	lu_bg.color = Color(0.04, 0.04, 0.06, 0.84)
	lu_bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	level_up_modal.add_child(lu_bg)

	var lu_center := CenterContainer.new()
	lu_center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	level_up_modal.add_child(lu_center)

	var lu_panel := PanelContainer.new()
	lu_panel.custom_minimum_size = Vector2(920, 420)
	var lu_style := StyleBoxFlat.new()
	lu_style.bg_color = Color(0.12, 0.12, 0.14, 0.98)
	lu_style.border_color = Color(1.0, 0.85, 0.25)
	lu_style.set_border_width_all(3)
	lu_style.set_corner_radius_all(12)
	lu_style.content_margin_left = 22
	lu_style.content_margin_right = 22
	lu_style.content_margin_top = 18
	lu_style.content_margin_bottom = 18
	lu_panel.add_theme_stylebox_override("panel", lu_style)
	lu_center.add_child(lu_panel)

	var lu_vbox := VBoxContainer.new()
	lu_vbox.add_theme_constant_override("separation", 12)
	lu_panel.add_child(lu_vbox)

	var lu_title := _make_outlined_label("🎖️ 猎人升级！选择一项强化或空投武器", 24, Color(1.0, 0.90, 0.28))
	lu_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lu_vbox.add_child(lu_title)

	lbl_level_up_sub = _make_outlined_label("", 13, Color(0.55, 0.95, 1.0))
	lbl_level_up_sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lu_vbox.add_child(lbl_level_up_sub)

	level_up_cards_hbox = HBoxContainer.new()
	level_up_cards_hbox.size_flags_vertical = Control.SIZE_EXPAND_FILL
	level_up_cards_hbox.add_theme_constant_override("separation", 16)
	lu_vbox.add_child(level_up_cards_hbox)

	var lu_bot_hbox := HBoxContainer.new()
	lu_bot_hbox.alignment = BoxContainer.ALIGNMENT_CENTER
	lu_vbox.add_child(lu_bot_hbox)

	btn_reroll_level_cards = Button.new()
	btn_reroll_level_cards.custom_minimum_size = Vector2(360, 42)
	btn_reroll_level_cards.text = "🎲 刷新升级选项 (消耗 15G)"
	btn_reroll_level_cards.add_theme_font_size_override("font_size", 15)
	btn_reroll_level_cards.pressed.connect(_on_reroll_level_cards_pressed)
	lu_bot_hbox.add_child(btn_reroll_level_cards)

	_build_pause_modal()

func _build_pause_modal() -> void:
	pause_modal = Control.new()
	pause_modal.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	pause_modal.visible = false
	hud_root.add_child(pause_modal)

	var p_bg := ColorRect.new()
	p_bg.color = Color(0.04, 0.04, 0.06, 0.86)
	p_bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	pause_modal.add_child(p_bg)

	var p_center := CenterContainer.new()
	p_center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	pause_modal.add_child(p_center)

	var p_panel := PanelContainer.new()
	p_panel.custom_minimum_size = Vector2(980, 480)
	var p_style := StyleBoxFlat.new()
	p_style.bg_color = Color(0.13, 0.13, 0.15, 0.98)
	p_style.border_color = Color(0.95, 0.72, 0.25)
	p_style.set_border_width_all(3)
	p_style.set_corner_radius_all(12)
	p_style.content_margin_left = 20
	p_style.content_margin_right = 20
	p_style.content_margin_top = 16
	p_style.content_margin_bottom = 16
	p_panel.add_theme_stylebox_override("panel", p_style)
	p_center.add_child(p_panel)

	var p_vbox := VBoxContainer.new()
	p_vbox.add_theme_constant_override("separation", 12)
	p_panel.add_child(p_vbox)

	var p_title := _make_outlined_label("⏸️ 战术暂停 — 属性、武装与伤害统计", 22, Color(1.0, 0.88, 0.30))
	p_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	p_vbox.add_child(p_title)

	var mid_hbox := HBoxContainer.new()
	mid_hbox.size_flags_vertical = Control.SIZE_EXPAND_FILL
	mid_hbox.add_theme_constant_override("separation", 14)
	p_vbox.add_child(mid_hbox)

	# 左栏：土豆兄弟式属性列表
	var left_box := _make_card_box(Color(0.17, 0.17, 0.20), Color(0.45, 0.65, 0.85))
	left_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	mid_hbox.add_child(left_box)
	pause_stats_vbox = VBoxContainer.new()
	pause_stats_vbox.add_theme_constant_override("separation", 6)
	left_box.add_child(pause_stats_vbox)

	# 中栏：已装武器与流派羁绊
	var mid_box := _make_card_box(Color(0.17, 0.17, 0.20), Color(0.85, 0.65, 0.25))
	mid_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	mid_hbox.add_child(mid_box)
	pause_weapons_vbox = VBoxContainer.new()
	pause_weapons_vbox.add_theme_constant_override("separation", 6)
	mid_box.add_child(pause_weapons_vbox)

	# 右栏：吸血鬼幸存者/土豆兄弟式武器伤害输出排行榜 (DPS Meter)
	var right_box := _make_card_box(Color(0.17, 0.17, 0.20), Color(1.0, 0.45, 0.25))
	right_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	mid_hbox.add_child(right_box)
	pause_dps_vbox = VBoxContainer.new()
	pause_dps_vbox.add_theme_constant_override("separation", 6)
	right_box.add_child(pause_dps_vbox)

	var btns_hbox := HBoxContainer.new()
	btns_hbox.add_theme_constant_override("separation", 12)
	p_vbox.add_child(btns_hbox)

	btn_pause_resume = Button.new()
	btn_pause_resume.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	btn_pause_resume.custom_minimum_size = Vector2(0, 44)
	btn_pause_resume.text = "▶️ 继续战斗 [ESC/Start]"
	btn_pause_resume.add_theme_font_size_override("font_size", 16)
	btn_pause_resume.pressed.connect(_toggle_pause_modal)
	btns_hbox.add_child(btn_pause_resume)

	btn_pause_mute = Button.new()
	btn_pause_mute.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	btn_pause_mute.custom_minimum_size = Vector2(0, 44)
	btn_pause_mute.text = "🔊 静音切换 [M]"
	btn_pause_mute.add_theme_font_size_override("font_size", 15)
	btn_pause_mute.pressed.connect(func():
		var is_m: bool = SoundManager.toggle_mute()
		btn_pause_mute.text = ("🔇 已静音 (点击恢复)" if is_m else "🔊 静音切换 [M]")
	)
	btns_hbox.add_child(btn_pause_mute)

	var btn_pause_retire := Button.new()
	btn_pause_retire.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	btn_pause_retire.custom_minimum_size = Vector2(0, 44)
	btn_pause_retire.text = "🏳️ 提前结算晶片"
	btn_pause_retire.add_theme_font_size_override("font_size", 15)
	btn_pause_retire.pressed.connect(func():
		pause_modal.visible = false
		on_player_total_defeat()
	)
	btns_hbox.add_child(btn_pause_retire)

func _toggle_fullscreen() -> void:
	var mode: int = DisplayServer.window_get_mode()
	if mode == DisplayServer.WINDOW_MODE_FULLSCREEN or mode == DisplayServer.WINDOW_MODE_EXCLUSIVE_FULLSCREEN:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
	else:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN)


func _place_town_for_wave() -> void:
	var p_center: Vector2 = arena_rect.get_center()
	var offset_x: float = randf_range(-60.0, 60.0) if GameState.current_wave > 1 else 0.0
	var offset_y: float = randf_range(-30.0, 30.0) if GameState.current_wave > 1 else 0.0
	town_pos = Vector2(p_center.x - 550.0 + offset_x, 880.0 + offset_y)

func _queue_single_spawn(e_id: String = "") -> void:
	if enemies_container.get_child_count() >= current_max_enemies:
		return
	var p_pos: Vector2 = player_tank.get_active_position()
	var ang: float = randf() * TAU
	var dist: float = randf_range(580.0, 760.0)
	var pos: Vector2 = p_pos + Vector2.from_angle(ang) * dist
	pos.x = clampf(pos.x, arena_rect.position.x + 45.0, arena_rect.end.x - 45.0)
	pos.y = clampf(pos.y, arena_rect.position.y + 45.0, arena_rect.end.y - 45.0)
	var chosen: String = e_id
	if chosen == "" or not GameData.ENEMIES.has(chosen):
		var m_pool: Array = GameState.get_current_map_def().get("enemy_pool", ["bio_ant", "scout_bike"])
		chosen = String(m_pool[randi() % m_pool.size()])
	spawn_telegraphs.append({"id": chosen, "pos": pos, "timer": 0.65})

func enter_town_hub() -> void:
	if not town_available:
		return
	emit_signal("request_town_hub")

func on_town_exited() -> void:
	town_available = false
	town_visited_this_wave = true
	is_player_in_safe_zone = false
	if is_instance_valid(btn_enter_town):
		btn_enter_town.visible = false
	if is_instance_valid(fx_layer):
		fx_layer.spawn_smoke_puff(town_pos, 45.0, Color(0.75, 0.70, 0.60, 0.70), 1.2)
		fx_layer.spawn_shockwave(town_pos, 180.0, Color(0.35, 0.95, 0.65))
	banner_timer = 4.0
	lbl_wanted_banner.text = "🏰 小镇商队已进入防空静默并移防隐蔽！下个波次将重新开放！"
	if is_instance_valid(fx_layer) and is_instance_valid(player_tank):
		fx_layer.spawn_text(player_tank.get_active_position() + Vector2(0, -50), "🏰 小镇商队已移防隐蔽！", Color(0.9, 0.8, 0.4), 1.35)

	# 若在小镇接取了赏金通缉令，召唤赏金首 Boss
	if GameState.active_wanted_boss_id != "" and not boss_spawned_this_wave:
		_spawn_wanted_boss(GameState.active_wanted_boss_id)

func _advance_to_next_wave_seamless() -> void:
	SoundManager.play("upgrade", 0.05, 1.2)
	# 全图战利品全域磁暴回收
	var vacuumed_scrap: int = 0
	var vacuumed_gold: int = 0
	for d in drops_container.get_children():
		if is_instance_valid(d) and not d.is_queued_for_deletion():
			match d.drop_type:
				"scrap": vacuumed_scrap += d.value
				"gold": vacuumed_gold += d.value
			d._collect(self, player_tank)
	if vacuumed_scrap > 0 or vacuumed_gold > 0:
		SoundManager.play("coin", 0.04, 2.0)
		fx_layer.spawn_text(player_tank.get_active_position() + Vector2(0, -42), "⚡ 全域磁暴回收: +%d 零件(XP) | +%d 赏金!" % [vacuumed_scrap, vacuumed_gold], Color(0.45, 0.95, 1.0), 1.6)
	if GameState.synergy_counts.get("tycoon", 0) >= 2:
		var interest: int = int(GameState.gold * 0.15)
		GameState.gold += interest
	if GameState.selected_chassis_id == "tyrannos" and GameState.current_wave % 3 == 0 and GameState.chassis_slots.size() < 7:
		var new_slots: Array = ["MAIN", "SUB", "SE"]
		GameState.chassis_slots.append(new_slots[GameState.current_wave % 3])

	var prev_w: int = GameState.current_wave
	GameState.current_wave += 1
	wave_elapsed = 0.0
	wave_time_left = minf(85.0, 60.0 + GameState.current_wave * 3.0)
	is_horde_active = false
	horde_announced = false
	boss_spawned_this_wave = false
	spawn_timer = 0.6
	elite_spawn_timer = 18.0
	ring_spawn_timer = 22.0

	# 重置休整小镇
	town_available = true
	town_visited_this_wave = false
	_place_town_for_wave()

	banner_timer = 5.0
	lbl_wanted_banner.text = "🏆 第 %d 波 坚守胜利！全域磁暴回收！第 %d 波已逼近！🏰 麦卡休整小镇已开放！" % [prev_w, GameState.current_wave]
	fx_layer.spawn_text(player_tank.get_active_position() + Vector2(0, -68), "🏰 麦卡休整小镇已在荒原开放！可在安全区改装补给！", Color(0.35, 1.0, 0.65), 1.6)
	_update_hud()

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("toggle_fullscreen"):
		get_viewport().set_input_as_handled()
		_toggle_fullscreen()
		return
	if event.is_action_pressed("toggle_mute"):
		var is_m: bool = SoundManager.toggle_mute()
		if visible and is_instance_valid(fx_layer) and is_instance_valid(player_tank):
			fx_layer.spawn_text(player_tank.get_active_position() + Vector2(0, -24), "🔇 音频已静音" if is_m else "🔊 音频已恢复", Color(0.6, 0.95, 1.0), 1.1)
		return
	if town_available and is_player_in_safe_zone and is_instance_valid(player_tank) and player_tank.get_active_position().distance_to(town_pos) <= town_interact_radius:
		if (event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_E) or event.is_action_pressed("ui_accept"):
			get_viewport().set_input_as_handled()
			enter_town_hub()
			return
	if not visible or level_up_modal.visible:
		return
	if event.is_action_pressed("pause_game") or (pause_modal.visible and event.is_action_pressed("ui_cancel")):
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
		for c in pause_stats_vbox.get_children():
			c.queue_free()
		for c in pause_weapons_vbox.get_children():
			c.queue_free()
		for c in pause_dps_vbox.get_children():
			c.queue_free()

		# 1. 战车与猎人属性
		var st_title := _make_outlined_label("📊 战车与猎人属性", 16, Color(0.55, 0.85, 1.0))
		pause_stats_vbox.add_child(st_title)
		_add_stat_row(pause_stats_vbox, "🗺️ 当前战区", "%s [%s]" % [GameState.get_current_map_def()["name"].substr(0, 7), GameState.get_current_difficulty_def()["name"].substr(0, 4)], Color(1.0, 0.88, 0.35))
		_add_stat_row(pause_stats_vbox, "🎖️ 猎人 / 座驾", "%s / %s" % [GameData.HUNTERS[GameState.selected_hunter_id]["name"].split(" ")[0], GameData.CHASSIS[GameState.selected_chassis_id]["name"].split(" ")[0]], Color.WHITE)
		_add_stat_row(pause_stats_vbox, "🛡️ 最大装甲 (SP)", "%d SP (+%.0f/s)" % [int(GameState.max_sp), GameState.sp_regen_per_sec], Color(0.35, 0.98, 0.55))
		_add_stat_row(pause_stats_vbox, "⚖️ 引擎载重", "%.1f / %.1f t" % [GameState.used_weight, GameState.max_weight], Color(0.95, 0.82, 0.35))
		_add_stat_row(pause_stats_vbox, "💥 暴击率", "%d%%" % int(GameState.crit_chance * 100.0), Color(1.0, 0.55, 0.30))
		_add_stat_row(pause_stats_vbox, "💨 闪避率", "%d%%" % int(GameState.dodge_chance * 100.0), Color(0.45, 0.92, 1.0))
		_add_stat_row(pause_stats_vbox, "⚡ 装填加速", "+%d%%" % int(GameState.bonus_stats.get("reload_speed_pct", 0.0) * 100.0), Color(0.85, 0.65, 1.0))

		# 2. 已装武器与流派羁绊
		var wp_title := _make_outlined_label("🔫 已装备武装 (%d/%d)" % [GameState.equipped_weapons.size(), GameState.chassis_slots.size()], 16, Color(1.0, 0.85, 0.30))
		pause_weapons_vbox.add_child(wp_title)
		for ew in GameState.equipped_weapons:
			var wd: Dictionary = GameData.WEAPONS[ew["id"]]
			var rar: int = int(ew.get("rarity", 0))
			var eff_dmg: float = GameState.get_weapon_effective_damage(ew["id"], rar)
			_add_stat_row(pause_weapons_vbox, "[%s] %s" % [wd["slot"], wd["name"]], "%s | 💥%.0f" % [GameData.RARITY_NAMES[rar], eff_dmg], GameData.RARITY_COLORS[rar])

		var syn_active_header := _make_outlined_label("🏷️ 激活羁绊", 14, Color(0.45, 0.95, 0.75))
		pause_weapons_vbox.add_child(syn_active_header)
		var has_syn: bool = false
		for tag in GameData.SYNERGIES.keys():
			var cnt: int = GameState.synergy_counts.get(tag, 0)
			if cnt >= 2:
				has_syn = true
				var s_def: Dictionary = GameData.SYNERGIES[tag]
				_add_stat_row(pause_weapons_vbox, "%s (%d/6)" % [s_def["name"], cnt], s_def["desc"].substr(0, 18) + "...", s_def["color"])
		if not has_syn:
			var no_syn_lbl := _make_outlined_label("尚无满2件激活羁绊", 12, Color(0.6, 0.6, 0.65))
			pause_weapons_vbox.add_child(no_syn_lbl)

		# 3. 武器输出统计与 DPS 排行榜 (土豆兄弟 / 吸血鬼幸存者风格)
		var total_dmg: float = GameState.get_total_weapon_damage()
		var dps_title := _make_outlined_label("🏆 武器输出排行 (累计 %.0f)" % total_dmg, 16, Color(1.0, 0.85, 0.25))
		pause_dps_vbox.add_child(dps_title)

		var sorted_dmg: Array = GameState.get_sorted_weapon_damage()
		if sorted_dmg.is_empty():
			var empty_lbl := _make_outlined_label("暂无武器开火伤害记录", 13, Color(0.65, 0.65, 0.7))
			pause_dps_vbox.add_child(empty_lbl)
		else:
			for item in sorted_dmg:
				var row := VBoxContainer.new()
				row.add_theme_constant_override("separation", 2)
				pause_dps_vbox.add_child(row)

				var top_r := HBoxContainer.new()
				row.add_child(top_r)

				var n_lbl := _make_outlined_label("%s %s" % [item["slot_badge"], item["name"]], 13, item["color"])
				n_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
				top_r.add_child(n_lbl)

				var d_lbl := _make_outlined_label("%.0f (%.1f%%)" % [item["damage"], item["pct"]], 13, Color(0.95, 0.95, 0.95))
				top_r.add_child(d_lbl)

				var bar := ProgressBar.new()
				bar.custom_minimum_size = Vector2(0, 7)
				bar.max_value = 100.0
				bar.value = item["pct"]
				bar.show_percentage = false
				var b_fill := StyleBoxFlat.new()
				b_fill.bg_color = item["color"]
				b_fill.set_corner_radius_all(3)
				var b_bg := StyleBoxFlat.new()
				b_bg.bg_color = Color(0.12, 0.12, 0.15)
				b_bg.set_corner_radius_all(3)
				bar.add_theme_stylebox_override("fill", b_fill)
				bar.add_theme_stylebox_override("background", b_bg)
				row.add_child(bar)

		btn_pause_mute.text = ("🔇 已静音 (点击恢复)" if SoundManager.muted else "🔊 静音切换 [M]")
		btn_pause_resume.call_deferred("grab_focus")

func start_wave() -> void:
	_update_arena_bounds()
	_clear_entities()
	tread_marks.clear()
	_generate_wasteland_craters()
	SoundManager.play_bgm("bgm_battle_wasteland")
	pause_modal.visible = false
	level_up_modal.visible = false
	boss_hp_panel.visible = false

	wave_active = true
	wave_elapsed = 0.0
	wave_time_left = minf(85.0, 60.0 + GameState.current_wave * 3.0)
	if GameState.current_wave == GameState.max_waves:
		wave_time_left = 95.0
		GameState.active_wanted_boss_id = GameState.get_current_map_def()["final_boss_id"]

	boss_spawned_this_wave = false
	is_horde_active = false
	horde_announced = false
	active_arena_event.clear()
	arena_event_triggered_this_wave = false
	combo_count = 0
	combo_timer = 0.0
	ring_spawn_timer = 22.0
	spawn_timer = 0.6
	elite_spawn_timer = 18.0
	fx_layer.mortar_strikes.clear()

	# 重置休整小镇
	town_available = true
	town_visited_this_wave = false
	is_player_in_safe_zone = false
	_place_town_for_wave()

	player_tank.init_for_wave(arena_rect.get_center())
	if is_instance_valid(battle_cam):
		battle_cam.enabled = true
		battle_cam.global_position = player_tank.get_active_position()
		battle_cam.make_current()

	var chest_cnt: int = 0
	if int(GameState.bonus_stats.get("guaranteed_chest", 0)) > 0 and GameState.current_wave >= 3:
		chest_cnt += 1
	if GameState.is_feature_unlocked("detector_unlock") and GameState.current_wave >= 4 and randf() < 0.40:
		chest_cnt += 1
	for i in range(chest_cnt):
		var cpos := Vector2(randf_range(arena_rect.position.x + 180, arena_rect.end.x - 180), randf_range(arena_rect.position.y + 180, arena_rect.end.y - 180))
		spawn_drop("buried_chest", 1, cpos)

func _exit_tree() -> void:
	Engine.time_scale = 1.0
	for p in _proj_pool:
		if is_instance_valid(p):
			p.free()
	_proj_pool.clear()
	for d in _drop_pool:
		if is_instance_valid(d):
			d.free()
	_drop_pool.clear()

func _clear_entities() -> void:
	for c in enemies_container.get_children():
		c.queue_free()
	for c in projectiles_container.get_children():
		recycle_projectile(c)
	for c in drops_container.get_children():
		recycle_drop(c)
	spatial_grid.clear()
	spawn_telegraphs.clear()

func _process(delta: float) -> void:
	if not wave_active:
		return

	_update_arena_bounds()
	rebuild_spatial_grid()
	wave_elapsed += delta
	wave_time_left -= delta

	# 平滑镜头跟随战车 & 弹簧阻尼方向性震屏处理
	if is_instance_valid(player_tank) and is_instance_valid(battle_cam):
		battle_cam.global_position = player_tank.get_active_position()
		shake_dir_impulse = shake_dir_impulse.lerp(Vector2.ZERO, minf(1.0, delta * 14.0))
		if shake_timer > 0.0:
			shake_timer -= delta
			battle_cam.offset = shake_dir_impulse + Vector2(randf_range(-shake_intensity, shake_intensity), randf_range(-shake_intensity, shake_intensity))
		elif shake_dir_impulse.length_squared() > 0.2:
			battle_cam.offset = shake_dir_impulse
		else:
			battle_cam.offset = Vector2.ZERO
	position = Vector2.ZERO

	# 动态战场突发事件处理
	_process_arena_event(delta)

	if banner_timer > 0.0:
		banner_timer -= delta
		if banner_timer <= 0.0:
			banner_wanted.visible = false

	# 1. 赏金首乱入
	var boss_enter_delay: float = 2.5 if GameState.current_wave >= GameState.max_waves else 5.5
	if not boss_spawned_this_wave and GameState.active_wanted_boss_id != "" and wave_elapsed >= boss_enter_delay:
		boss_spawned_this_wave = true
		wave_time_left = maxf(wave_time_left + 15.0, 45.0)
		_spawn_wanted_boss(GameState.active_wanted_boss_id)

	# 2. 绯红孤狼乱入救援
	if boss_spawned_this_wave and not red_wolf_rescued_this_run and not player_tank.is_human_mode:
		if player_tank.current_sp > 0.0 and player_tank.current_sp <= GameState.max_sp * 0.25:
			_trigger_red_wolf_rescue()

	# 3. 动态波次敌人容量计算与狂暴冲锋 (Horde Surge)
	current_max_enemies = mini(320, 85 + GameState.current_wave * 14)
	var is_horde_wave: bool = (GameState.current_wave in [4, 8, 12, 16])
	var is_surge_time: bool = (wave_time_left <= 15.0 and wave_time_left > 1.0 and GameState.current_wave >= 2)
	is_horde_active = is_horde_wave or is_surge_time
	if is_horde_active:
		current_max_enemies = mini(340, current_max_enemies + 60)

	if is_horde_active and not horde_announced:
		horde_announced = true
		SoundManager.play("wanted_siren", 0.05, 1.8)
		trigger_screen_shake(9.0, 0.4)
		banner_wanted.visible = true
		banner_timer = 4.0
		lbl_wanted_banner.text = "⚠️ 警报：机械狂潮集群来袭 (HORDE SURGE)！全速突围！⚠️"

	# 连击倒计时衰减与急速增益
	if combo_timer > 0.0:
		combo_timer -= delta
		if combo_timer <= 0.0:
			combo_count = 0
			GameState.bonus_stats["combo_reload_pct"] = 0.0
			GameState.bonus_stats["combo_speed_pct"] = 0.0
	else:
		combo_count = 0

	if combo_count >= 30:
		GameState.bonus_stats["combo_reload_pct"] = 0.15
		GameState.bonus_stats["combo_speed_pct"] = 0.12
	elif combo_count >= 15:
		GameState.bonus_stats["combo_reload_pct"] = 0.08
		GameState.bonus_stats["combo_speed_pct"] = 0.06
	else:
		GameState.bonus_stats["combo_reload_pct"] = 0.0
		GameState.bonus_stats["combo_speed_pct"] = 0.0

	# 4. 分阶段梯度刷怪节奏 (前10s零星侦察 ➔ 10~25s渐进逼近 ➔ 25s+阵地主力 ➔ 55s+机械狂潮)
	var spawn_mult: float = float(GameState.get_current_difficulty_def().get("spawn_mult", 1.0))
	if wave_elapsed < 10.0:
		# (1) 零星侦察期：间隔极宽 (2.8 ~ 3.5s)，每次仅 1 只零星侦察兵，严禁小队包围与精英突袭
		elite_spawn_timer = maxf(elite_spawn_timer, 18.0)
		ring_spawn_timer = maxf(ring_spawn_timer, 22.0)
		spawn_timer -= delta
		if spawn_timer <= 0.0:
			spawn_timer = randf_range(2.8, 3.5) / spawn_mult
			var scout_pool: Array = ["bio_ant", "scout_bike", "scrap_bug"]
			var s_id: String = scout_pool[randi() % scout_pool.size()]
			_queue_single_spawn(s_id)
	elif wave_elapsed < 25.0:
		# (2) 渐进逼近期：间隔平滑收窄至 1.4 ~ 1.8s，生成 2~3 只小队
		elite_spawn_timer -= delta
		if elite_spawn_timer <= 0.0:
			elite_spawn_timer = 15.0
			_spawn_map_elite()
		spawn_timer -= delta
		if spawn_timer <= 0.0:
			spawn_timer = randf_range(1.4, 1.8) / spawn_mult
			_queue_squad_spawn(randi_range(2, 3))
	else:
		# (3) 阵地交火与高潮狂潮期 (25s+)
		elite_spawn_timer -= delta
		if elite_spawn_timer <= 0.0:
			elite_spawn_timer = maxf(5.5, 9.0 - GameState.current_wave * 0.25)
			_spawn_map_elite()

		ring_spawn_timer -= delta
		if ring_spawn_timer <= 0.0:
			ring_spawn_timer = randf_range(6.5, 9.5) if is_horde_active else randf_range(9.0, 14.0)
			_queue_ring_spawn(14 if is_horde_active else 8)

		spawn_timer -= delta
		if spawn_timer <= 0.0:
			var interval: float = maxf(0.12, (0.75 - GameState.current_wave * 0.035) / spawn_mult)
			if is_horde_active:
				interval = maxf(0.08, interval * 0.45)
			spawn_timer = interval

			var batch: int = 3 + int(GameState.current_wave * 0.8)
			if is_horde_active:
				batch = int(batch * 2.0)
			while batch > 0:
				var s_size: int = mini(batch, randi_range(3, 6))
				_queue_squad_spawn(s_size)
				batch -= s_size

	for i in range(spawn_telegraphs.size() - 1, -1, -1):
		spawn_telegraphs[i]["timer"] -= delta
		if spawn_telegraphs[i]["timer"] <= 0.0:
			_do_spawn_enemy(spawn_telegraphs[i]["id"], spawn_telegraphs[i]["pos"])
			spawn_telegraphs.remove_at(i)

	# 4.5 荒原休整小镇与安全区排斥力场处理
	town_pulse_time += delta
	if town_available and is_instance_valid(player_tank):
		var p_pos: Vector2 = player_tank.get_active_position()
		var dist_to_town: float = p_pos.distance_to(town_pos)
		is_player_in_safe_zone = (dist_to_town <= town_radius)

		if is_instance_valid(btn_enter_town):
			btn_enter_town.visible = (dist_to_town <= town_interact_radius)

		# 怪物排斥力场：严防怪物越界踩入安全区
		for e in enemies_container.get_children():
			if is_instance_valid(e) and not e.is_queued_for_deletion():
				var edist: float = e.global_position.distance_to(town_pos)
				if edist < town_radius + 24.0:
					var pdir: Vector2 = (e.global_position - town_pos).normalized()
					if pdir == Vector2.ZERO: pdir = Vector2.UP
					e.global_position = town_pos + pdir * (town_radius + 25.0)
	else:
		is_player_in_safe_zone = false
		if is_instance_valid(btn_enter_town):
			btn_enter_town.visible = false

	# 4.8 波次计时结束判定：无缝进入下一波，彻底消除强行切屏打断
	if wave_time_left <= 0.0:
		if GameState.current_wave >= GameState.max_waves:
			if _has_alive_boss():
				wave_time_left = 0.0
			else:
				_finish_wave_success()
				return
		else:
			_advance_to_next_wave_seamless()

	# 废土风沙环境微粒飘散
	var wind_vec: Vector2 = Vector2(1.2, 0.35).normalized()
	for dp in dust_particles:
		dp["pos"] += wind_vec * (dp["spd"] * delta)
		if dp["pos"].x > arena_rect.end.x:
			dp["pos"].x = arena_rect.position.x
			dp["pos"].y = randf_range(arena_rect.position.y, arena_rect.end.y)
		elif dp["pos"].y > arena_rect.end.y:
			dp["pos"].y = arena_rect.position.y

	_update_hud()
	queue_redraw()

func _has_alive_boss() -> bool:
	for e in enemies_container.get_children():
		if is_instance_valid(e) and e.get("is_boss") == true:
			return true
	return false

func _get_alive_boss() -> Node2D:
	for e in enemies_container.get_children():
		if is_instance_valid(e) and e.get("is_boss") == true:
			return e
	return null

func _queue_enemy_spawn(is_ring: bool = false, ring_angle: float = 0.0) -> void:
	if enemies_container.get_child_count() >= current_max_enemies:
		return
	var p_pos: Vector2 = player_tank.get_active_position()
	var ang: float = ring_angle if is_ring else (randf() * TAU)
	var dist: float = randf_range(520.0, 720.0) if not is_ring else randf_range(540.0, 650.0)
	var pos: Vector2 = p_pos + Vector2.from_angle(ang) * dist
	pos.x = clampf(pos.x, arena_rect.position.x + 45.0, arena_rect.end.x - 45.0)
	pos.y = clampf(pos.y, arena_rect.position.y + 45.0, arena_rect.end.y - 45.0)

	var m_pool: Array = GameState.get_current_map_def().get("enemy_pool", ["bio_ant", "kamikaze_wheel"])
	var chosen: String = String(m_pool[randi() % m_pool.size()])
	var tele_timer: float = 0.35 if is_horde_active else 0.55
	spawn_telegraphs.append({"id": chosen, "pos": pos, "timer": tele_timer})

func _queue_squad_spawn(squad_size: int = 5) -> void:
	if enemies_container.get_child_count() + squad_size > current_max_enemies:
		return
	var center_ang: float = randf() * TAU
	for i in range(squad_size):
		var ang: float = center_ang + randf_range(-0.25, 0.25)
		_queue_enemy_spawn(true, ang)

func _queue_ring_spawn(count: int = 12) -> void:
	if enemies_container.get_child_count() + count > current_max_enemies:
		return
	var base_ang: float = randf() * TAU
	for i in range(count):
		var ang: float = base_ang + TAU * float(i) / float(count)
		_queue_enemy_spawn(true, ang)

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
	var p_pos: Vector2 = player_tank.get_active_position()
	var ang: float = randf() * TAU
	var pos: Vector2 = p_pos + Vector2.from_angle(ang) * randf_range(560.0, 750.0)
	pos.x = clampf(pos.x, arena_rect.position.x + 60.0, arena_rect.end.x - 60.0)
	pos.y = clampf(pos.y, arena_rect.position.y + 60.0, arena_rect.end.y - 60.0)
	_do_spawn_enemy(chosen_id, pos)
	fx_layer.spawn_text(pos + Vector2(0, -24), "⚡ 重装精英：%s !" % GameData.ENEMIES[chosen_id]["name"], Color(1.0, 0.85, 0.20), 1.25)

func _spawn_wanted_boss(boss_id: String) -> void:
	var boss_def: Dictionary = {}
	for b in GameData.WANTED_BOSSES:
		if b["id"] == boss_id:
			boss_def = b
			break
	if boss_def.is_empty():
		return

	var p_pos: Vector2 = player_tank.get_active_position()
	var ang: float = randf() * TAU
	var spawn_pos: Vector2 = p_pos + Vector2.from_angle(ang) * 620.0
	spawn_pos.x = clampf(spawn_pos.x, arena_rect.position.x + 120.0, arena_rect.end.x - 120.0)
	spawn_pos.y = clampf(spawn_pos.y, arena_rect.position.y + 120.0, arena_rect.end.y - 120.0)
	var boss := Node2D.new()
	boss.set_script(EnemyScript)
	enemies_container.add_child(boss)
	boss.setup_boss(boss_def, GameState.current_wave, spawn_pos)

	SoundManager.play("wanted_siren", 0.02, 2.5)
	SoundManager.play_bgm("bgm_wanted_boss", -5.5)
	trigger_screen_shake(10.0, 0.45)
	banner_wanted.visible = true
	banner_timer = 4.5
	lbl_wanted_banner.text = "⚠️ 赏金首乱入：【%s】 (💰%dG) ⚠️" % [boss_def["name"], int(boss_def["bounty"])]

func _trigger_red_wolf_rescue() -> void:
	red_wolf_rescued_this_run = true
	SoundManager.play("cannon_heavy", 0.02, 4.0)
	trigger_screen_shake(16.0, 0.5)
	banner_wanted.visible = true
	banner_timer = 4.5
	lbl_wanted_banner.text = "🔥 传奇游侠【绯红孤狼】驾驶绯红之狼乱入支援！！ 🔥"

	var p_pos: Vector2 = player_tank.global_position
	fx_layer.spawn_laser_beam(Vector2(arena_rect.position.x, p_pos.y), Vector2(arena_rect.end.x, p_pos.y), Color(1.0, 0.2, 0.15), 18.0)
	for e in enemies_container.get_children():
		if is_instance_valid(e):
			fx_layer.spawn_explosion(e.global_position, 110.0, Color(1.0, 0.25, 0.15))
			e.take_damage(850.0 + GameState.current_wave * 90.0, true, "cluster", p_pos, true)

	player_tank.heal_sp(GameState.max_sp * 0.45)
	player_tank.refill_all_ammo(8)
	spawn_drop("buried_chest", 1, p_pos + Vector2(60, 0))

func on_enemy_killed(_enemy_node: Node2D) -> void:
	combo_count += 1
	combo_timer = 2.4
	max_combo = maxi(max_combo, combo_count)
	GameState.total_kills += 1
	GameState.report_metric("total_kills", 1, true)
	GameState.report_metric("max_combo", combo_count, false)
	if is_instance_valid(player_tank) and player_tank.is_human_mode:
		GameState.report_metric("human_kills", 1, true)

	if combo_count in [15, 30, 50, 75, 100, 150, 200, 300]:
		var p_pos: Vector2 = player_tank.get_active_position()
		var tag_txt: String = ""
		var col: Color = Color(1.0, 0.85, 0.25)
		var s_shake: float = 3.5

		if combo_count == 15:
			tag_txt = "🔥 15 连斩 COMBO! [急速+6%]"
			col = Color(1.0, 0.75, 0.2)
		elif combo_count == 30:
			tag_txt = "⚡ 30 连破 MULTI-KILL! [装填+15%]"
			col = Color(0.35, 0.9, 1.0)
			s_shake = 5.0
		elif combo_count == 50:
			tag_txt = "💥 50 狂轰 RAMPAGE! [急速+20%]"
			col = Color(1.0, 0.4, 0.15)
			s_shake = 7.0
		elif combo_count == 100:
			tag_txt = "💀 100 狂飙百斩 MASSACRE! [SP恢复+10%]"
			col = Color(1.0, 0.2, 0.3)
			s_shake = 9.0
			player_tank.heal_sp(GameState.max_sp * 0.10)
		elif combo_count >= 150:
			tag_txt = "🌟 %d 荒原主宰 ANNIHILATION! [全场割草]" % combo_count
			col = Color(1.0, 0.9, 0.25)
			s_shake = 11.0
			player_tank.heal_sp(GameState.max_sp * 0.15)

		fx_layer.spawn_text(p_pos + Vector2(0, -32), tag_txt, col, 1.45)
		trigger_screen_shake(s_shake, 0.18)
		SoundManager.play("upgrade", 0.06, 1.2)

func on_wanted_boss_defeated(boss_node: Node2D) -> void:
	var b_id: String = boss_node.enemy_id
	if not (b_id in GameState.defeated_wanted_ids):
		GameState.defeated_wanted_ids.append(b_id)
	GameState.active_wanted_boss_id = ""
	GameState.bounties_hunted += 1
	GameState.report_metric("kill_" + b_id, 1, false)
	GameState.report_metric("total_bounties", 1, true)
	if wave_elapsed <= 30.0:
		GameState.report_metric("fast_boss_kill", 1, false)
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
	boss_hp_panel.visible = false

	var rw_id: String = boss_node.reward_weapon_id
	var rw_name: String = GameData.WEAPONS.get(rw_id, {}).get("name", "传奇红武")
	var res: Dictionary = GameState.add_weapon_to_first_valid_slot(rw_id, 4)
	if res.get("equipped", false) or res.get("merged", false):
		lbl_wanted_banner.text = "🏆 击杀【%s】! +%dG | +25💎 | 获得【%s】!" % [boss_node.enemy_name, final_bounty, rw_name]
	else:
		GameState.add_gold(200)
		lbl_wanted_banner.text = "🏆 击杀【%s】! +%dG | +25💎 (满槽折算+200G)!" % [boss_node.enemy_name, final_bounty]

	var final_b_id: String = GameState.get_current_map_def()["final_boss_id"]
	if b_id == final_b_id or b_id == "boss_noah":
		wave_active = false
		emit_signal("game_victory")
	else:
		SoundManager.play_bgm("bgm_battle_wasteland")

func trigger_zombie_shock(pos: Vector2) -> void:
	fx_layer.spawn_explosion(pos, 115.0, Color(0.55, 0.35, 1.0))
	fx_layer.spawn_text(pos, "⚡特斯拉电弧脉冲!", Color(0.65, 0.5, 1.0), 1.05)
	for e in enemies_container.get_children():
		if is_instance_valid(e) and pos.distance_to(e.global_position) <= 130.0:
			e.take_damage(75.0 + GameState.level * 12.0, false, "electric", pos, false)

# --- 战场即时升级：土豆兄弟风格三选一立式卡片 ---
func _on_battlefield_level_up() -> void:
	if not visible or GameState.pending_level_ups <= 0:
		return
	wave_active = false
	level_up_modal.visible = true
	SoundManager.play("upgrade", 0.04, 1.5)
	_populate_battlefield_level_cards()

func _roll_perk_tier_for_wave(w: int) -> int:
	var roll: float = randf()
	if w <= 2:
		return 1 if roll < 0.15 else 0
	elif w <= 5:
		if roll < 0.08:
			return 2
		elif roll < 0.42:
			return 1
		return 0
	elif w <= 8:
		if roll < 0.06:
			return 3
		elif roll < 0.28:
			return 2
		elif roll < 0.70:
			return 1
		return 0
	else:
		if roll < 0.15:
			return 3
		elif roll < 0.48:
			return 2
		elif roll < 0.85:
			return 1
		return 0

func _populate_battlefield_level_cards() -> void:
	for c in level_up_cards_hbox.get_children():
		c.queue_free()

	var show_hints: bool = GameState.should_show_build_hints()
	if show_hints:
		lbl_level_up_sub.text = "💡 选择一项猎人专精强化 (随波次解锁 ★2精良 / ★3稀有 / ★4史诗 高阶属性卡)"
	else:
		lbl_level_up_sub.text = "🔴 【地狱模式盲配】已隐藏流派与超武配件提示，全凭老猎人直觉搭配！"

	var perks: Array = GameData.LEVEL_PERKS.duplicate()
	perks.shuffle()
	var perk_icons: Dictionary = {
		"main_dmg": "💥", "sub_se_dmg": "🔫", "max_weight": "⚖️", "reload_spd": "⚡",
		"crit_chance": "🎯", "sp_regen": "🔧", "move_ram": "🚜", "bounty_magnet": "🧲"
	}
	var tier_mults: Array = [1.0, 1.5, 2.0, 2.75]
	var offer_airdrop_on_3rd: bool = (GameState.current_wave >= 4 and randf() < 0.18)
	var stat_card_count: int = 2 if offer_airdrop_on_3rd else 3

	# 土豆兄弟风格：1~4 阶颜色边框属性强化卡
	for i in range(stat_card_count):
		var p: Dictionary = perks[i]
		var tier: int = _roll_perk_tier_for_wave(GameState.current_wave)
		var t_col: Color = GameData.RARITY_COLORS[tier]
		var t_name: String = GameData.RARITY_NAMES[tier]
		var mult: float = float(tier_mults[tier])
		var final_val: float = float(p["val"]) * mult
		var disp_num: int = int(roundf(final_val * 100.0)) if p.get("is_pct", true) else int(roundf(final_val))
		var desc_txt: String = String(p["desc"]) % disp_num

		var stat_compare: String = ""
		var tangible_compare: String = ""
		if p.get("is_pct", true):
			var cur_val: float = float(GameState.bonus_stats.get(p["stat"], 0.0))
			if p["stat"] == "crit_chance":
				cur_val = GameState.crit_chance
			var cur_disp: int = int(roundf(cur_val * 100.0))
			var next_disp: int = cur_disp + disp_num
			stat_compare = "📊 加成: %+d%% ➔ %+d%%" % [cur_disp, next_disp]

			match p["id"]:
				"main_dmg":
					var rep_dmg: float = 0.0
					for w in GameState.equipped_weapons:
						if GameData.WEAPONS.get(w["id"], {}).get("slot", "") == "MAIN":
							rep_dmg = GameState.get_weapon_effective_damage(w["id"], w.get("rarity", 0))
							break
					if rep_dmg > 0.0:
						var next_dmg: float = rep_dmg * (1.0 + final_val)
						tangible_compare = "💥 主炮伤害: %.0f ➔ %.0f (+%.0f)" % [rep_dmg, next_dmg, next_dmg - rep_dmg]
				"max_weight":
					var cur_w: float = GameState.max_weight
					var next_w: float = cur_w * (1.0 + final_val)
					var ch: Dictionary = GameData.CHASSIS.get(GameState.selected_chassis_id, {})
					var sp_ton: float = float(ch.get("sp_per_ton", 20.0))
					var delta_sp: int = int(roundf((next_w - cur_w) * sp_ton))
					tangible_compare = "⚖️ 最大载重: %.1ft ➔ %.1ft (血量 +%d)" % [cur_w, next_w, delta_sp]
				"move_ram":
					var cur_spd: float = GameState.move_speed
					var next_spd: float = cur_spd * (1.0 + final_val)
					tangible_compare = "🚜 战车移速: %.0f ➔ %.0f (+%.0f)" % [cur_spd, next_spd, next_spd - cur_spd]
				"reload_spd":
					tangible_compare = "⚡ 装填加速: %+d%%" % disp_num
				"crit_chance":
					tangible_compare = "🎯 全车暴击: %d%% ➔ %d%%" % [cur_disp, next_disp]
		else:
			var cur_disp: int = int(roundf(GameState.sp_regen_per_sec))
			var next_disp: int = cur_disp + disp_num
			stat_compare = "📊 修护: %d/s ➔ %d/s" % [cur_disp, next_disp]
			tangible_compare = "🔧 装甲每秒自修: +%d SP/秒" % disp_num

		var full_compare: String = stat_compare
		if not tangible_compare.is_empty():
			full_compare += "\n" + tangible_compare

		var card := _make_card_box(Color(0.16, 0.17, 0.21), t_col)
		card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		card.size_flags_vertical = Control.SIZE_EXPAND_FILL
		level_up_cards_hbox.add_child(card)

		var cv := VBoxContainer.new()
		cv.add_theme_constant_override("separation", 10)
		card.add_child(cv)

		var badge_lbl := _make_outlined_label("🎖️ 猎人专精  ·  %s" % t_name, 13, t_col)
		badge_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		cv.add_child(badge_lbl)

		var icon_lbl := _make_outlined_label("%s %s" % [perk_icons.get(p["id"], "★"), p["name"]], 20, t_col)
		icon_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		cv.add_child(icon_lbl)

		var sep := HSeparator.new()
		cv.add_child(sep)

		var is_emergency: bool = (GameState.selected_difficulty_id == "easy") and (player_tank.is_human_mode or (player_tank.current_sp <= GameState.max_sp * 0.25))
		var heal_label: String = "⚡【简单模式·绝境逆转】紧急注入 +16% SP!" if is_emergency else "💚 战地应急抢修 +6% SP"
		var desc_lbl := _make_outlined_label("✅ %s\n%s\n%s" % [desc_txt, full_compare, heal_label], 14, Color(1.0, 0.88, 0.25) if is_emergency else Color(0.92, 0.96, 0.92))
		desc_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		desc_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		desc_lbl.size_flags_vertical = Control.SIZE_EXPAND_FILL
		cv.add_child(desc_lbl)

		var btn := Button.new()
		btn.custom_minimum_size = Vector2(0, 44)
		btn.text = "选择强化"
		btn.add_theme_font_size_override("font_size", 16)
		btn.pressed.connect(func():
			var st: String = p["stat"]
			GameState.bonus_stats[st] = GameState.bonus_stats.get(st, 0.0) + final_val
			GameState.pending_level_ups = max(0, GameState.pending_level_ups - 1)
			GameState.recalculate_stats()
			if is_emergency:
				if player_tank.is_human_mode:
					player_tank.human_hp = minf(GameState.max_human_hp, player_tank.human_hp + 28.0)
					fx_layer.spawn_text(player_tank.human_pos, "⚡ 绝境翻盘！紧急急救 +28 HP!", Color(0.3, 1.0, 0.5), 1.35)
				else:
					player_tank.heal_sp(GameState.max_sp * 0.16)
					fx_layer.spawn_text(player_tank.global_position, "⚡ 绝境翻盘！装甲紧急注能 +16% SP!", Color(1.0, 0.88, 0.2), 1.35)
			else:
				player_tank.heal_sp(GameState.max_sp * 0.06)
			SoundManager.play("coin", 0.08, 0.0)
			_close_or_next_level_modal()
		)
		cv.add_child(btn)
		if i == 0:
			btn.call_deferred("grab_focus")

	_update_reroll_button_state()

	if not offer_airdrop_on_3rd:
		return

	# 第 4 波以后仅 18% 概率在第 3 张出现 ★1 稀有空投补给卡
	var airdrop_w_id: String = _pick_smart_airdrop_weapon()
	var w_def: Dictionary = GameData.WEAPONS[airdrop_w_id]
	var evo_partner_name: String = GameState.check_super_evolution_partner(airdrop_w_id)
	var can_merge: bool = false
	for ew in GameState.equipped_weapons:
		if ew["id"] == airdrop_w_id and int(ew.get("rarity", 0)) == 0:
			can_merge = true
			break

	var w_card := _make_card_box(Color(0.20, 0.16, 0.14), Color(1.0, 0.75, 0.25))
	w_card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	w_card.size_flags_vertical = Control.SIZE_EXPAND_FILL
	level_up_cards_hbox.add_child(w_card)

	var wv := VBoxContainer.new()
	wv.add_theme_constant_override("separation", 8)
	w_card.add_child(wv)

	var air_badge := _make_outlined_label("🪂 稀有战场空投 [★1·%s孔]" % w_def["slot"], 13, Color(1.0, 0.82, 0.32))
	air_badge.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	wv.add_child(air_badge)

	var w_title := _make_outlined_label(w_def["name"], 19, Color(0.45, 0.92, 1.0))
	w_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	w_title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	wv.add_child(w_title)

	var stats_lbl := _make_outlined_label("💥 伤害: %.0f   |   ⚖️ 重量: %.1ft   |   ⏱️ %.1fs" % [
		float(w_def["base_dmg"]), float(w_def["weight"]), float(w_def["cooldown"])
	], 13, Color(0.95, 0.92, 0.85))
	stats_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	wv.add_child(stats_lbl)

	var can_take_w: bool = GameState.can_equip_or_merge(airdrop_w_id, 0)
	var prev_air: Dictionary = GameState.preview_weapon_purchase(airdrop_w_id, 0)

	var hint_text: String = w_def["desc"]
	if show_hints:
		var syn_names: Array = []
		for t in w_def.get("tags", []):
			if GameData.SYNERGIES.has(t):
				syn_names.append(GameData.SYNERGIES[t]["name"])
		if not syn_names.is_empty():
			hint_text += "\n🏷️ 流派: " + " / ".join(syn_names)
		if evo_partner_name != "":
			hint_text += "\n🌟 超武配件 ➔ " + evo_partner_name
		elif can_merge:
			hint_text += "\n✨ 【战地二合一升星！】★1 ➔ ★2\n💥 伤害: %.0f ➔ %.0f (%+d) | 🛡️ 血量: %d ➔ %d" % [
				prev_air["cur_dmg"], prev_air["new_dmg"], int(prev_air["dmg_delta"]),
				int(prev_air["cur_sp"]), int(prev_air["new_sp"])
			]
		elif can_take_w:
			hint_text += "\n🔧 【装配入空槽】\n💥 实际伤害: %.0f | 🛡️ 上车后血量: %d ➔ %d (%+d)" % [
				prev_air["cur_dmg"], int(prev_air["cur_sp"]), int(prev_air["new_sp"]), int(prev_air["sp_delta"])
			]

	var w_desc := _make_outlined_label(hint_text, 13, Color(1.0, 0.88, 0.45) if (evo_partner_name != "" or can_merge) else Color(0.85, 0.85, 0.85))
	w_desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	w_desc.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	w_desc.size_flags_vertical = Control.SIZE_EXPAND_FILL
	wv.add_child(w_desc)
	var air_btn := Button.new()
	air_btn.custom_minimum_size = Vector2(0, 44)
	air_btn.text = "空投装配 (+6% SP)" if can_take_w else "槽位已满：折算 +35G"
	air_btn.add_theme_font_size_override("font_size", 16)
	air_btn.pressed.connect(func():
		GameState.pending_level_ups = max(0, GameState.pending_level_ups - 1)
		if can_take_w:
			GameState.add_weapon_to_first_valid_slot(airdrop_w_id, 0, true)
			player_tank.sync_weapons_from_state(1.0 + GameState.get_meta_level("meta_reload") * 0.15)
		else:
			GameState.add_gold(35)
		player_tank.heal_sp(GameState.max_sp * 0.06)
		SoundManager.play("upgrade", 0.05, 1.5)
		_close_or_next_level_modal()
	)
	wv.add_child(air_btn)

func _pick_smart_airdrop_weapon() -> String:
	var candidates: Array = []
	for k in GameData.WEAPONS.keys():
		var wid: String = String(k)
		var def: Dictionary = GameData.WEAPONS[wid]
		if def.get("is_evo", false) or wid.begins_with("boss_"):
			continue
		if int(def.get("min_rarity", 0)) > 1:
			continue # 空投补给仅限基础/中阶武器，绝不空投紫装/红装
		if GameState.bonus_stats.get("no_main_cannon", false) and def["slot"] == "MAIN":
			continue
		candidates.append(wid)
	if candidates.is_empty():
		return "mg_77mm"
	return candidates[randi() % candidates.size()]

func _update_reroll_button_state() -> void:
	if not is_instance_valid(btn_reroll_level_cards):
		return
	var reroll_cost: int = 15 + GameState.level * 2
	if GameState.gold >= reroll_cost:
		btn_reroll_level_cards.text = "🎲 消耗 %d G 刷新升级专精 (当前持有 %d G)" % [reroll_cost, GameState.gold]
		btn_reroll_level_cards.disabled = false
	else:
		btn_reroll_level_cards.text = "🎲 刷新需 %d G (持有 %d G - 赏金不足)" % [reroll_cost, GameState.gold]
		btn_reroll_level_cards.disabled = true

func _on_reroll_level_cards_pressed() -> void:
	var reroll_cost: int = 15 + GameState.level * 2
	if GameState.gold < reroll_cost:
		return
	GameState.gold -= reroll_cost
	SoundManager.play("upgrade", 0.04, 1.2)
	_populate_battlefield_level_cards()

func _close_or_next_level_modal() -> void:
	if GameState.pending_level_ups > 0:
		_populate_battlefield_level_cards()
	else:
		level_up_modal.visible = false
		wave_active = true
		_update_hud()

		# 战地应急 EMP 动能冲击波：仅简单模式(easy)生效，震退战车周围敌怪并眩晕1秒，给新手玩家留出绝地反杀身位！
		if GameState.selected_difficulty_id == "easy" and is_instance_valid(player_tank) and is_instance_valid(fx_layer):
			var p_pos: Vector2 = player_tank.get_active_position()
			fx_layer.spawn_explosion(p_pos, 160.0, Color(0.35, 0.90, 1.0))
			trigger_screen_shake(7.0, 0.22)
			SoundManager.play("explosion_small", 0.08, 1.6)
			fx_layer.spawn_text(p_pos + Vector2(0, -32), "⚡ EMP 动能震荡波！震退敌群！", Color(0.4, 0.95, 1.0), 1.3)
			for e in enemies_container.get_children():
				if is_instance_valid(e):
					var d: float = p_pos.distance_to(e.global_position)
					if d <= 175.0:
						var push_dir: Vector2 = (e.global_position - p_pos).normalized() if d > 1.0 else Vector2.RIGHT
						e.global_position += push_dir * maxf(60.0, 160.0 - d)
						e.stun_timer = maxf(e.stun_timer, 1.1)

func _on_super_weapon_evolved(evo_info: Dictionary) -> void:
	SoundManager.play("mince_revive", 0.02, 3.5)
	trigger_screen_shake(15.0, 0.45)
	banner_wanted.visible = true
	banner_timer = 6.0
	lbl_wanted_banner.text = "🌟 【神话超武合成！】 [%s] + [%s] ➔ %s 🌟" % [
		evo_info["comp_a_name"], evo_info["comp_b_name"], evo_info["evo_name"]
	]
	GameState.report_metric("super_weapon_count", 1, true)
	var evo_w_id: String = evo_info.get("evo_id", "")
	match evo_w_id:
		"evo_crimson_stars": GameState.report_metric("evo_crimson_stars", 1, false)
		"evo_aurora_storm": GameState.report_metric("evo_aurora_storm", 1, false)
		"evo_zeus_orbit": GameState.report_metric("evo_zeus_orbit", 1, false)
		"evo_damocles": GameState.report_metric("evo_damocles", 1, false)
	if is_instance_valid(player_tank) and is_instance_valid(fx_layer):
		fx_layer.spawn_explosion(player_tank.get_active_position(), 200.0, Color(1.0, 0.88, 0.20))
		fx_layer.spawn_text(player_tank.get_active_position() + Vector2(0, -36), "★ 神话超武：%s ★" % evo_info["evo_name"], Color(1.0, 0.90, 0.20), 1.55)

func _finish_wave_success() -> void:
	wave_active = false
	if is_instance_valid(player_tank):
		if player_tank.current_sp >= GameState.max_sp * 0.99:
			GameState.report_metric("flawless_wave_count", 1, true)
		if player_tank.current_sp <= GameState.max_sp * 0.15:
			GameState.report_metric("clutch_wave_clear", 1, true)
	# 全图战利品全域磁暴回收：将所有遗留掉落物100%吸附结算给玩家，零资源浪费
	var vacuumed_scrap: int = 0
	var vacuumed_gold: int = 0
	for d in drops_container.get_children():
		if is_instance_valid(d) and not d.is_queued_for_deletion():
			match d.drop_type:
				"scrap":
					vacuumed_scrap += d.value
				"gold":
					vacuumed_gold += d.value
			d._collect(self, player_tank)

	if vacuumed_scrap > 0 or vacuumed_gold > 0:
		SoundManager.play("coin", 0.04, 2.0)
		fx_layer.spawn_text(player_tank.get_active_position() + Vector2(0, -42), "⚡ 全域磁暴回收: +%d 零件(XP) | +%d 赏金!" % [vacuumed_scrap, vacuumed_gold], Color(0.45, 0.95, 1.0), 1.6)

	if GameState.synergy_counts.get("tycoon", 0) >= 2:
		var interest: int = int(GameState.gold * 0.15)
		GameState.gold += interest
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

func _acquire_projectile() -> Node2D:
	while not _proj_pool.is_empty():
		var p: Node2D = _proj_pool.pop_back()
		if is_instance_valid(p):
			projectiles_container.add_child(p)
			return p
	var np := Node2D.new()
	np.set_script(ProjectileScript)
	projectiles_container.add_child(np)
	return np

func recycle_projectile(p: Node2D) -> void:
	if not is_instance_valid(p):
		return
	p.set_process(false)
	p.visible = false
	if p.get_parent() == projectiles_container:
		projectiles_container.remove_child(p)
	if _proj_pool.size() < 320:
		if not (p in _proj_pool):
			_proj_pool.append(p)
	else:
		p.queue_free()

func _acquire_drop() -> Node2D:
	while not _drop_pool.is_empty():
		var d: Node2D = _drop_pool.pop_back()
		if is_instance_valid(d):
			drops_container.add_child(d)
			return d
	var nd := Node2D.new()
	nd.set_script(DropItemScript)
	drops_container.add_child(nd)
	return nd

func recycle_drop(d: Node2D) -> void:
	if not is_instance_valid(d):
		return
	d.set_process(false)
	d.visible = false
	if d.get_parent() == drops_container:
		drops_container.remove_child(d)
	if _drop_pool.size() < 160:
		if not (d in _drop_pool):
			_drop_pool.append(d)
	else:
		d.queue_free()

func spawn_player_projectile(pos: Vector2, dir: Vector2, spd: float, dmg: float, splash: float, effect: String, is_crit: bool, is_main: bool, pierce: int, weapon_id: String = "", p_rarity: int = 0) -> void:
	var p: Node2D = _acquire_projectile()
	p.setup_player_proj(pos, dir, spd, dmg, splash, effect, is_crit, is_main, pierce, weapon_id, p_rarity)

func spawn_enemy_projectile(pos: Vector2, dir: Vector2, spd: float, dmg: float, col: Color = Color(1.0, 0.25, 0.35), rad: float = 6.5, eff: String = "") -> void:
	var p: Node2D = _acquire_projectile()
	p.setup_enemy_proj(pos, dir, spd, dmg, col, rad, eff)

func spawn_drop(d_type: String, val: int, pos: Vector2) -> void:
	# 高密度同屏掉落物自动合并 (>75个时自动合并邻近同类型零件/金币)
	if d_type in ["scrap", "gold"] and drops_container.get_child_count() >= 75:
		var merge_target: Node2D = null
		var best_dist: float = 999999.0
		for existing in drops_container.get_children():
			if is_instance_valid(existing) and existing.get("drop_type") == d_type:
				var dist: float = existing.global_position.distance_to(pos)
				if dist < best_dist:
					best_dist = dist
					merge_target = existing
		if is_instance_valid(merge_target):
			merge_target.value += val
			return
	var d: Node2D = _acquire_drop()
	d.setup(d_type, val, pos)

func rebuild_spatial_grid() -> void:
	spatial_grid.clear()
	if not is_instance_valid(enemies_container):
		return
	for e in enemies_container.get_children():
		if is_instance_valid(e) and not e.is_queued_for_deletion():
			var cx: int = int(floor(e.global_position.x / SPATIAL_CELL_SIZE))
			var cy: int = int(floor(e.global_position.y / SPATIAL_CELL_SIZE))
			var key := Vector2i(cx, cy)
			if not spatial_grid.has(key):
				spatial_grid[key] = []
			spatial_grid[key].append(e)

func get_enemies_in_radius(pos: Vector2, radius: float) -> Array:
	if spatial_grid.is_empty() and is_instance_valid(enemies_container) and enemies_container.get_child_count() > 0:
		rebuild_spatial_grid()
	var result: Array = []
	var pad: float = radius + 68.0
	var min_cx: int = int(floor((pos.x - pad) / SPATIAL_CELL_SIZE))
	var max_cx: int = int(floor((pos.x + pad) / SPATIAL_CELL_SIZE))
	var min_cy: int = int(floor((pos.y - pad) / SPATIAL_CELL_SIZE))
	var max_cy: int = int(floor((pos.y + pad) / SPATIAL_CELL_SIZE))
	for cx in range(min_cx, max_cx + 1):
		for cy in range(min_cy, max_cy + 1):
			var key := Vector2i(cx, cy)
			if spatial_grid.has(key):
				for e in spatial_grid[key]:
					if is_instance_valid(e) and not e.is_queued_for_deletion():
						if pos.distance_to(e.global_position) <= radius + float(e.get("radius")):
							result.append(e)
	return result

func get_nearest_enemy(from_pos: Vector2, max_range: float) -> Node2D:
	var best: Node2D = null
	var best_d: float = max_range
	var candidates: Array = get_enemies_in_radius(from_pos, max_range) if not spatial_grid.is_empty() else enemies_container.get_children()
	for e in candidates:
		if is_instance_valid(e):
			var d: float = from_pos.distance_to(e.global_position)
			if d < best_d:
				best_d = d
				best = e
	return best

func get_highest_threat_enemy(from_pos: Vector2, max_range: float) -> Node2D:
	var best: Node2D = null
	var best_score: float = -1.0
	var candidates: Array = get_enemies_in_radius(from_pos, max_range) if not spatial_grid.is_empty() else enemies_container.get_children()
	for e in candidates:
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

func trigger_screen_shake(intensity: float, duration: float, dir: Vector2 = Vector2.ZERO) -> void:
	var mult: float = float(GameState.get_setting("screen_shake_mult", 1.0))
	if mult <= 0.01:
		return
	shake_intensity = maxf(shake_intensity, intensity * mult)
	shake_timer = maxf(shake_timer, duration)
	if dir != Vector2.ZERO:
		shake_dir_impulse = dir.normalized() * intensity * mult * 1.45

func trigger_hitstop(duration: float = 0.032, time_scale: float = 0.05) -> void:
	if _hitstop_active:
		return
	_hitstop_active = true
	Engine.time_scale = clampf(time_scale, 0.02, 1.0)
	if is_inside_tree():
		get_tree().create_timer(duration, true, false, true).timeout.connect(func():
			Engine.time_scale = 1.0
			_hitstop_active = false
		)
	else:
		Engine.time_scale = 1.0
		_hitstop_active = false

# --- 阶段三：动态战场突发事件系统 (Dynamic Arena Events) ---
func trigger_arena_event(force_type: String = "") -> void:
	arena_event_triggered_this_wave = true
	var ev_types: Array = ["airdrop_defense", "acid_sandstorm", "noah_beacon"]
	var chosen: String = force_type if not force_type.is_empty() else String(ev_types[randi() % ev_types.size()])
	var p_pos: Vector2 = player_tank.get_active_position() if is_instance_valid(player_tank) else arena_rect.get_center()
	var ev_pos: Vector2 = p_pos + Vector2.from_angle(randf() * TAU) * 340.0
	ev_pos.x = clampf(ev_pos.x, arena_rect.position.x + 180.0, arena_rect.end.x - 180.0)
	ev_pos.y = clampf(ev_pos.y, arena_rect.position.y + 180.0, arena_rect.end.y - 180.0)

	match chosen:
		"airdrop_defense":
			active_arena_event = {
				"type": "airdrop_defense",
				"name": "🪂 军火空投信标防守",
				"pos": ev_pos,
				"radius": 145.0,
				"progress": 0.0,
				"goal": 4.0,
				"timer": 16.0
			}
			banner_wanted.visible = true
			banner_timer = 4.0
			lbl_wanted_banner.text = "🪂 【战场突发事件】军火空投信标已降落！进入绿圈驻守 4 秒获取战车改装芯片与弹药！"
		"acid_sandstorm":
			active_arena_event = {
				"type": "acid_sandstorm",
				"name": "🌪️ 强酸腐蚀沙尘暴",
				"pos": arena_rect.get_center(),
				"radius": 2800.0,
				"progress": 0.0,
				"goal": 10.0,
				"timer": 10.0,
				"tick_timer": 0.0
			}
			banner_wanted.visible = true
			banner_timer = 4.0
			lbl_wanted_banner.text = "🌪️ 【战场突发气象】强酸沙尘暴席卷战区！全场敌军护甲持续腐蚀剥落！"
		"noah_beacon":
			active_arena_event = {
				"type": "noah_beacon",
				"name": "📡 诺亚超载干扰塔",
				"pos": ev_pos,
				"radius": 125.0,
				"progress": 0.0,
				"goal": 3.0,
				"timer": 15.0
			}
			banner_wanted.visible = true
			banner_timer = 4.0
			lbl_wanted_banner.text = "📡 【战场突发事件】发现诺亚超载信标！靠近骇入 3 秒引发全屏EMP磁暴并夺取诺亚晶片！"
	SoundManager.play("interception_chirp", 0.05, 1.0)

func _process_arena_event(delta: float) -> void:
	if not arena_event_triggered_this_wave and GameState.current_wave >= 2 and wave_elapsed >= 9.5:
		trigger_arena_event()

	if active_arena_event.is_empty():
		return

	active_arena_event["timer"] = float(active_arena_event.get("timer", 0.0)) - delta
	var ev_type: String = String(active_arena_event.get("type", ""))
	var p_pos: Vector2 = player_tank.get_active_position() if is_instance_valid(player_tank) else Vector2.ZERO

	if ev_type == "acid_sandstorm":
		active_arena_event["tick_timer"] = float(active_arena_event.get("tick_timer", 0.0)) + delta
		if float(active_arena_event["tick_timer"]) >= 1.0:
			active_arena_event["tick_timer"] = 0.0
			for e in enemies_container.get_children():
				if is_instance_valid(e):
					e.armor = maxf(-45.0, e.armor - 5.0)
		if float(active_arena_event["timer"]) <= 0.0:
			active_arena_event.clear()
		return

	var ev_pos: Vector2 = active_arena_event.get("pos", Vector2.ZERO)
	var ev_rad: float = float(active_arena_event.get("radius", 140.0))
	if p_pos.distance_to(ev_pos) <= ev_rad:
		active_arena_event["progress"] = float(active_arena_event.get("progress", 0.0)) + delta
		if float(active_arena_event["progress"]) >= float(active_arena_event.get("goal", 3.5)):
			_complete_arena_event()
			return

	if float(active_arena_event["timer"]) <= 0.0:
		active_arena_event.clear()

func _complete_arena_event() -> void:
	if active_arena_event.is_empty():
		return
	var ev_type: String = String(active_arena_event.get("type", ""))
	var ev_pos: Vector2 = active_arena_event.get("pos", player_tank.get_active_position())
	active_arena_event.clear()
	GameState.report_metric("arena_events_completed", 1, true)
	SoundManager.play("upgrade", 0.04, 2.0)

	if ev_type == "airdrop_defense":
		GameState.add_gold(55)
		if is_instance_valid(player_tank):
			player_tank.refill_all_ammo(8)
			player_tank.heal_sp(GameState.max_sp * 0.20)
		var mod_keys: Array = GameData.TANK_MODS.keys()
		if not mod_keys.is_empty():
			var rand_mod: String = String(mod_keys[randi() % mod_keys.size()])
			GameState.buy_tank_mod(rand_mod, 0)
			var m_name: String = GameData.TANK_MODS[rand_mod]["name"]
			if is_instance_valid(fx_layer):
				fx_layer.spawn_shockwave(ev_pos, 220.0, Color(0.35, 1.0, 0.55))
				fx_layer.spawn_text(ev_pos + Vector2(0, -28), "🪂 空投解锁：【%s】 +55G & 满弹药!" % m_name, Color(0.35, 1.0, 0.55), 1.45)
	elif ev_type == "noah_beacon":
		GameState.noah_chips += 8
		GameState.add_gold(40)
		GameState.save_meta_data()
		if is_instance_valid(fx_layer):
			fx_layer.spawn_shockwave(ev_pos, 420.0, Color(0.35, 0.90, 1.0))
			fx_layer.spawn_text(ev_pos + Vector2(0, -28), "📡 诺亚信标骇入成功！全屏EMP过载 +8💎 +40G!", Color(0.40, 0.95, 1.0), 1.5)
		for e in enemies_container.get_children():
			if is_instance_valid(e):
				e.stun_timer = maxf(e.stun_timer, 2.0)
				e.take_damage(260.0 + GameState.current_wave * 35.0, true, "electric", ev_pos, false)

func _update_hud() -> void:
	# 1. 更新左上角 SP/HP 主血条
	if player_tank.is_human_mode:
		bar_sp.max_value = maxf(1.0, GameState.max_human_hp)
		bar_sp.value = clampf(player_tank.human_hp, 0.0, bar_sp.max_value)
		style_sp_fill.bg_color = Color(0.92, 0.22, 0.22)
		lbl_sp_val.text = "❤️ 步兵 HP: %d / %d (靠近战车抢修!)" % [int(player_tank.human_hp), int(GameState.max_human_hp)]
	else:
		bar_sp.max_value = maxf(1.0, GameState.max_sp)
		bar_sp.value = clampf(player_tank.current_sp, 0.0, bar_sp.max_value)
		var sp_ratio: float = bar_sp.value / bar_sp.max_value
		style_sp_fill.bg_color = Color(0.20, 0.82, 0.38) if sp_ratio > 0.30 else Color(0.95, 0.35, 0.18)
		lbl_sp_val.text = "🛡️ %d / %d SP  (+%.0f/s)" % [int(player_tank.current_sp), int(GameState.max_sp), GameState.sp_regen_per_sec]

	# 2. 更新经验条
	bar_xp.max_value = maxf(1.0, float(GameState.xp_to_next))
	bar_xp.value = clampf(float(GameState.xp), 0.0, bar_xp.max_value)
	lbl_xp_val.text = "🎖️ Lv.%d   (%d / %d)" % [GameState.level, GameState.xp, GameState.xp_to_next]

	# 3. 更新载重条 & C装置全弹发射充能条
	bar_weight.max_value = maxf(1.0, GameState.max_weight)
	bar_weight.value = clampf(GameState.used_weight, 0.0, bar_weight.max_value)
	lbl_weight_val.text = "⚖️ %.1f / %.1ft" % [GameState.used_weight, GameState.max_weight]

	var ao_max: float = maxf(0.1, player_tank.all_out_max_cd)
	var ao_ready: bool = (player_tank.all_out_timer <= 0.0)
	bar_all_out.max_value = ao_max
	bar_all_out.value = ao_max if ao_ready else clampf(ao_max - player_tank.all_out_timer, 0.0, ao_max)
	style_all_out_fill.bg_color = Color(0.95, 0.78, 0.15) if ao_ready else Color(0.55, 0.35, 0.92)
	var cu_info: Dictionary = GameData.C_UNITS.get(GameState.equipped_c_unit_id, {})
	var sk_icon: String = cu_info.get("skill_icon", "🚀")
	var sk_name: String = cu_info.get("skill_name", "全弹发射")
	lbl_all_out_val.text = "%s [Q] %s!" % [sk_icon, sk_name] if ao_ready else "%s %s %.1fs" % [sk_icon, sk_name.substr(0, 4), player_tank.all_out_timer]

	# 4. 更新金币、晶片与弹药胶囊
	lbl_gold_num.text = "💰 %d" % GameState.gold
	lbl_chips_num.text = "💎 %d" % GameState.noah_chips

	var ammo_parts: Array = []
	for i in range(GameState.equipped_weapons.size()):
		var w_id: String = GameState.equipped_weapons[i]["id"]
		var w_def: Dictionary = GameData.WEAPONS[w_id]
		if w_def["slot"] == "MAIN" and i < player_tank.weapon_ammo.size():
			var a_str: String = "∞" if int(w_def.get("ammo", 999)) > 500 else str(player_tank.weapon_ammo[i])
			ammo_parts.append(a_str)
	var mode_icon: String = "🤖自动" if GameState.auto_main_cannon else "🎯手动"
	lbl_ammo_badge.text = "%s 主炮弹药: %s" % [mode_icon, "/".join(ammo_parts) if not ammo_parts.is_empty() else "副炮特化"]

	# 5. 更新正上方波次与大号秒表 (参考《土豆兄弟》正上方)
	var m_short: String = GameState.get_current_map_def()["name"].split("·")[0]
	var d_short: String = GameState.get_current_difficulty_def()["name"].substr(0, 4)
	lbl_wave_title.text = "第 %d / %d 波  ·  %s [%s]" % [GameState.current_wave, GameState.max_waves, m_short, d_short]

	if wave_time_left <= 0.0 and GameState.current_wave >= GameState.max_waves:
		lbl_wave_countdown.text = "⚡ 决战统帅 ⚡"
		lbl_wave_countdown.add_theme_color_override("font_color", Color(1.0, 0.28, 0.25))
	else:
		var sec_left: int = int(ceil(maxf(0.0, wave_time_left)))
		lbl_wave_countdown.text = "%d" % sec_left
		lbl_wave_countdown.add_theme_color_override("font_color", Color(1.0, 0.28, 0.25) if sec_left <= 5 else Color(1.0, 0.92, 0.30))

	# 5.1 更新狂飙连杀 Combo 计数器
	if is_instance_valid(lbl_combo):
		if combo_count >= 5 and combo_timer > 0.0:
			lbl_combo.visible = true
			var heat_color: Color = Color(1.0, 0.85, 0.20) if combo_count < 30 else (Color(1.0, 0.50, 0.15) if combo_count < 75 else Color(1.0, 0.22, 0.28))
			var buff_desc: String = " (+15%急速)" if combo_count >= 30 else (" (+8%急速)" if combo_count >= 15 else "")
			lbl_combo.text = "🔥 %d COMBO 狂飙连杀!%s (%.1fs)" % [combo_count, buff_desc, combo_timer]
			lbl_combo.add_theme_color_override("font_color", heat_color)
		else:
			lbl_combo.visible = false

	# 6. 更新顶部赏金首 BOSS 巨型血条
	var boss_node: Node2D = _get_alive_boss()
	if is_instance_valid(boss_node):
		boss_hp_panel.visible = true
		boss_portrait_rect.texture = GameData.get_boss_tex(String(boss_node.enemy_id))
		bar_boss_hp.max_value = maxf(1.0, boss_node.max_hp)
		bar_boss_hp.value = clampf(boss_node.hp, 0.0, bar_boss_hp.max_value)
		lbl_boss_hp.text = "★ %s   %d / %d" % [boss_node.enemy_name.split(" ")[0], int(maxf(0.0, boss_node.hp)), int(boss_node.max_hp)]
	else:
		boss_hp_panel.visible = false

	# 7. 更新战术雷达小地图
	if is_instance_valid(minimap_ctrl):
		var radar_p: Node = minimap_ctrl.get_parent()
		if is_instance_valid(radar_p):
			radar_p.visible = bool(GameState.get_setting("show_minimap", true))
		if radar_p.visible:
			minimap_ctrl.queue_redraw()

	# 8. 更新屏幕边缘目标追踪指示器与全屏濒死暗角 (土豆兄弟 / 吸血鬼幸存者风格)
	if is_instance_valid(offscreen_indicators_ctrl):
		offscreen_indicators_ctrl.queue_redraw()
	if is_instance_valid(vignette_ctrl):
		vignette_ctrl.queue_redraw()

func _draw_minimap() -> void:
	if not is_instance_valid(minimap_ctrl):
		return
	var m_sz: Vector2 = minimap_ctrl.size
	if m_sz.x < 10.0 or m_sz.y < 10.0 or arena_rect.size.x < 10.0:
		return
	var sx: float = m_sz.x / arena_rect.size.x
	var sy: float = m_sz.y / arena_rect.size.y

	# 1. 雷达底色与坐标网格
	minimap_ctrl.draw_rect(Rect2(Vector2.ZERO, m_sz), Color(0.08, 0.12, 0.10, 0.85))
	minimap_ctrl.draw_line(Vector2(m_sz.x * 0.5, 0), Vector2(m_sz.x * 0.5, m_sz.y), Color(0.20, 0.45, 0.32, 0.4), 1.0)
	minimap_ctrl.draw_line(Vector2(0, m_sz.y * 0.5), Vector2(m_sz.x, m_sz.y * 0.5), Color(0.20, 0.45, 0.32, 0.4), 1.0)

	# 2. 当前屏幕视野框 (Camera Viewport Frame)
	if is_instance_valid(battle_cam):
		var cam_p: Vector2 = battle_cam.global_position
		var vp_sz: Vector2 = get_viewport_rect().size / battle_cam.zoom
		var cam_min: Vector2 = cam_p - vp_sz * 0.5
		var mini_vp := Rect2(cam_min.x * sx, cam_min.y * sy, vp_sz.x * sx, vp_sz.y * sy)
		minimap_ctrl.draw_rect(mini_vp, Color(0.4, 0.85, 1.0, 0.40), false, 1.0)

	# 3. 埋藏宝箱 (黄金菱形亮点)
	for d in drops_container.get_children():
		if is_instance_valid(d) and d.get("drop_type") == "buried_chest":
			var d_pos: Vector2 = Vector2(d.global_position.x * sx, d.global_position.y * sy)
			minimap_ctrl.draw_circle(d_pos, 3.5, Color(1.0, 0.85, 0.25))

	# 4. 机械兽群、精英与赏金首
	for e in enemies_container.get_children():
		if is_instance_valid(e):
			var e_pos: Vector2 = Vector2(e.global_position.x * sx, e.global_position.y * sy)
			if e.is_boss:
				var pulse: float = 1.0 + 0.3 * sin(wave_elapsed * 8.0)
				minimap_ctrl.draw_circle(e_pos, 5.5 * pulse, Color(1.0, 0.20, 0.20))
				minimap_ctrl.draw_arc(e_pos, 7.5 * pulse, 0.0, TAU, 12, Color(1.0, 0.90, 0.25), 1.5)
			elif e.is_elite:
				minimap_ctrl.draw_circle(e_pos, 3.5, Color(1.0, 0.65, 0.20))
			else:
				minimap_ctrl.draw_circle(e_pos, 1.8, Color(0.92, 0.28, 0.28, 0.85))

	# 4.5 绘制休整小镇雷达地标
	if town_available:
		var tm := Vector2(town_pos.x * sx, town_pos.y * sy)
		var tr_m := town_radius * sx
		minimap_ctrl.draw_circle(tm, tr_m, Color(0.15, 0.95, 0.45, 0.25))
		minimap_ctrl.draw_arc(tm, tr_m, 0.0, TAU, 18, Color(0.35, 1.0, 0.65, 0.85), 1.5)
		minimap_ctrl.draw_rect(Rect2(tm - Vector2(3, 3), Vector2(6, 6)), Color(0.95, 0.85, 0.25))
		minimap_ctrl.draw_string(ThemeDB.fallback_font, tm + Vector2(6, 3), "🏰小镇", HORIZONTAL_ALIGNMENT_LEFT, -1, 9, Color(0.35, 1.0, 0.65))

	# 5. 玩家战车 (醒目绿色光标与行进方向指示)
	if is_instance_valid(player_tank):
		var p_pos: Vector2 = player_tank.get_active_position()
		var pm := Vector2(p_pos.x * sx, p_pos.y * sy)
		minimap_ctrl.draw_circle(pm, 3.5, Color(0.25, 1.0, 0.45))
		var fwd := Vector2.from_angle(player_tank.chassis_angle) * 7.0
		minimap_ctrl.draw_line(pm, pm + fwd, Color(0.25, 1.0, 0.45), 1.5)

	# 6. 雷达标签与外框
	minimap_ctrl.draw_rect(Rect2(Vector2.ZERO, m_sz), Color(0.35, 0.75, 0.55), false, 1.5)
	minimap_ctrl.draw_string(ThemeDB.fallback_font, Vector2(5, 12), "📡 战术雷达", HORIZONTAL_ALIGNMENT_LEFT, -1, 10, Color(0.55, 0.95, 0.75, 0.90))

# --- 土豆兄弟 / 吸血鬼幸存者风格：低血量/大破全屏呼吸暗角警报 ---
func _draw_danger_vignette() -> void:
	if not is_instance_valid(vignette_ctrl) or not wave_active or not is_instance_valid(player_tank):
		return
	var vp_sz: Vector2 = vignette_ctrl.get_viewport_rect().size
	if vp_sz.x <= 10.0 or vp_sz.y <= 10.0:
		return

	var is_human: bool = player_tank.is_human_mode
	var sp_ratio: float = player_tank.current_sp / maxf(1.0, GameState.max_sp)

	if not is_human and sp_ratio >= 0.30 and not is_horde_active:
		return

	var t: float = float(Time.get_ticks_msec()) * 0.005
	var pulse: float = 0.55 + 0.45 * sin(t)

	var base_col: Color
	var border_depth: float = 52.0
	var alert_text: String = ""

	if is_human:
		base_col = Color(0.95, 0.22, 0.08, 0.45 * pulse)
		border_depth = 64.0
		alert_text = "🚨 战车大破！猎人肉身脱出，快靠近残骸抢修！"
	elif sp_ratio < 0.30:
		var danger_mult: float = 1.0 - (sp_ratio / 0.30)
		base_col = Color(0.85, 0.06, 0.06, (0.28 + 0.35 * danger_mult) * pulse)
		border_depth = 44.0 + 26.0 * danger_mult
		alert_text = "⚠️ 警告：战车装甲濒临大破 (SP < 30%)！"
	elif is_horde_active:
		base_col = Color(1.0, 0.38, 0.08, 0.24 * pulse)
		border_depth = 42.0
		alert_text = "⚠️ 机械狂潮暴动中 (HORDE SURGE)！全速突围！"

	# 绘制四周边框暗角阶梯渐变
	vignette_ctrl.draw_rect(Rect2(0, 0, vp_sz.x, border_depth * 0.5), base_col)
	vignette_ctrl.draw_rect(Rect2(0, border_depth * 0.5, vp_sz.x, border_depth * 0.5), Color(base_col.r, base_col.g, base_col.b, base_col.a * 0.45))
	vignette_ctrl.draw_rect(Rect2(0, vp_sz.y - border_depth * 0.5, vp_sz.x, border_depth * 0.5), base_col)
	vignette_ctrl.draw_rect(Rect2(0, vp_sz.y - border_depth, vp_sz.x, border_depth * 0.5), Color(base_col.r, base_col.g, base_col.b, base_col.a * 0.45))
	vignette_ctrl.draw_rect(Rect2(0, 0, border_depth * 0.5, vp_sz.y), base_col)
	vignette_ctrl.draw_rect(Rect2(border_depth * 0.5, 0, border_depth * 0.5, vp_sz.y), Color(base_col.r, base_col.g, base_col.b, base_col.a * 0.45))
	vignette_ctrl.draw_rect(Rect2(vp_sz.x - border_depth * 0.5, 0, border_depth * 0.5, vp_sz.y), base_col)
	vignette_ctrl.draw_rect(Rect2(vp_sz.x - border_depth, 0, border_depth * 0.5, vp_sz.y), Color(base_col.r, base_col.g, base_col.b, base_col.a * 0.45))

	if alert_text != "":
		var font: Font = ThemeDB.fallback_font
		var f_size: int = 14
		var str_sz: Vector2 = font.get_string_size(alert_text, HORIZONTAL_ALIGNMENT_CENTER, -1, f_size)
		var center_x: float = vp_sz.x * 0.5
		var bg_rect := Rect2(center_x - str_sz.x * 0.5 - 16.0, 78.0, str_sz.x + 32.0, 26.0)
		vignette_ctrl.draw_rect(bg_rect, Color(0.12, 0.02, 0.02, 0.90 * pulse))
		vignette_ctrl.draw_rect(bg_rect, Color(1.0, 0.35, 0.25, 0.95 * pulse), false, 1.5)
		vignette_ctrl.draw_string(font, Vector2(center_x - str_sz.x * 0.5, 96.0), alert_text, HORIZONTAL_ALIGNMENT_CENTER, -1, f_size, Color(1.0, 0.95, 0.40))

# --- 土豆兄弟 / 吸血鬼幸存者风格：屏幕边缘重要目标追踪指示器 ---
func _draw_offscreen_indicators() -> void:
	if not is_instance_valid(offscreen_indicators_ctrl) or not wave_active:
		return
	if not is_instance_valid(battle_cam) or not is_instance_valid(player_tank):
		return

	var vp_sz: Vector2 = offscreen_indicators_ctrl.get_viewport_rect().size
	if vp_sz.x <= 100.0 or vp_sz.y <= 100.0:
		return

	var cam_center: Vector2 = battle_cam.get_screen_center_position()
	var zoom: Vector2 = battle_cam.zoom
	var screen_center: Vector2 = vp_sz * 0.5
	var player_pos: Vector2 = player_tank.get_active_position()

	var targets: Array = []

	# 1. 赏金首 BOSS
	for e in enemies_container.get_children():
		if is_instance_valid(e) and e.get("is_boss") == true:
			targets.append({
				"pos": e.global_position,
				"icon": "💀",
				"color": Color(1.0, 0.25, 0.25),
				"border_col": Color(1.0, 0.85, 0.20)
			})

	# 2. 重装精英怪
	for e in enemies_container.get_children():
		if is_instance_valid(e) and e.get("is_elite") == true and e.get("is_boss") != true:
			targets.append({
				"pos": e.global_position,
				"icon": "⚡",
				"color": Color(1.0, 0.75, 0.15),
				"border_col": Color(1.0, 0.95, 0.35)
			})

	# 0. 休整小镇 (安全区)
	if town_available:
		targets.append({
			"pos": town_pos,
			"icon": "🏰",
			"color": Color(0.25, 1.0, 0.65),
			"border_col": Color(0.85, 1.0, 0.55),
			"is_town": true
		})

	# 3. 埋藏宝箱与战场动态事件信标
	for d in drops_container.get_children():
		if is_instance_valid(d) and d.get("drop_type") == "buried_chest":
			targets.append({
				"pos": d.global_position,
				"icon": "💎",
				"color": Color(0.25, 0.85, 1.0),
				"border_col": Color(0.65, 0.95, 1.0)
			})
	if not active_arena_event.is_empty() and String(active_arena_event.get("type", "")) in ["airdrop_defense", "noah_beacon"]:
		var is_air: bool = (String(active_arena_event.get("type", "")) == "airdrop_defense")
		targets.append({
			"pos": active_arena_event["pos"],
			"icon": "🪂" if is_air else "📡",
			"color": Color(0.30, 0.95, 0.55) if is_air else Color(0.35, 0.90, 1.0),
			"border_col": Color(0.85, 1.0, 0.85)
		})

	var margin: float = 46.0
	var min_bound := Vector2(margin, margin + 46.0)
	var max_bound := Vector2(vp_sz.x - margin, vp_sz.y - margin - 24.0)

	var font: Font = ThemeDB.fallback_font
	var f_size: int = 12

	for t in targets:
		var w_pos: Vector2 = t["pos"]
		var scr_pos: Vector2 = (w_pos - cam_center) * zoom + screen_center

		# 屏幕内目标无需边缘指针
		if scr_pos.x >= min_bound.x and scr_pos.x <= max_bound.x and scr_pos.y >= min_bound.y and scr_pos.y <= max_bound.y:
			continue

		var ray: Vector2 = scr_pos - screen_center
		if ray.length_squared() < 0.001:
			continue
		var dir: Vector2 = ray.normalized()

		var t_candidate: float = 1e6
		if dir.x > 0.001:
			t_candidate = minf(t_candidate, (max_bound.x - screen_center.x) / dir.x)
		elif dir.x < -0.001:
			t_candidate = minf(t_candidate, (min_bound.x - screen_center.x) / dir.x)

		if dir.y > 0.001:
			t_candidate = minf(t_candidate, (max_bound.y - screen_center.y) / dir.y)
		elif dir.y < -0.001:
			t_candidate = minf(t_candidate, (min_bound.y - screen_center.y) / dir.y)

		var edge_pos: Vector2 = screen_center + dir * t_candidate
		edge_pos.x = clampf(edge_pos.x, min_bound.x, max_bound.x)
		edge_pos.y = clampf(edge_pos.y, min_bound.y, max_bound.y)

		var dist_m: int = int(roundf(w_pos.distance_to(player_pos) / 25.0))
		var badge_str: String = "%s %dm" % [t["icon"], dist_m]
		var str_sz: Vector2 = font.get_string_size(badge_str, HORIZONTAL_ALIGNMENT_CENTER, -1, f_size)

		# 绘制边缘指向箭头 (三角形)
		var arrow_len: float = 14.0
		var arrow_tip: Vector2 = edge_pos + dir * 6.0
		var arrow_left: Vector2 = edge_pos - dir * arrow_len + dir.orthogonal() * 7.0
		var arrow_right: Vector2 = edge_pos - dir * arrow_len - dir.orthogonal() * 7.0
		var arrow_pts: PackedVector2Array = [arrow_tip, arrow_left, arrow_right]
		offscreen_indicators_ctrl.draw_colored_polygon(arrow_pts, t["color"])
		offscreen_indicators_ctrl.draw_polyline(PackedVector2Array([arrow_tip, arrow_left, arrow_right, arrow_tip]), t["border_col"], 1.5)

		# 绘制距离与图标小卡片
		var box_pos: Vector2 = edge_pos - dir * (arrow_len + 16.0)
		var box_w: float = str_sz.x + 14.0
		var box_h: float = str_sz.y + 6.0
		var badge_rect := Rect2(box_pos.x - box_w * 0.5, box_pos.y - box_h * 0.5, box_w, box_h)
		offscreen_indicators_ctrl.draw_rect(badge_rect, Color(0.08, 0.09, 0.12, 0.90))
		offscreen_indicators_ctrl.draw_rect(badge_rect, t["border_col"], false, 1.2)
		offscreen_indicators_ctrl.draw_string(font, Vector2(badge_rect.position.x + 7.0, badge_rect.position.y + str_sz.y), badge_str, HORIZONTAL_ALIGNMENT_LEFT, -1, f_size, Color.WHITE)

func _draw() -> void:
	var m_def: Dictionary = GameState.get_current_map_def()
	var bg_col: Color = m_def.get("bg_color", Color(0.22, 0.18, 0.13))
	var grid_col: Color = m_def.get("grid_color", Color(0.26, 0.21, 0.16))
	var border_col: Color = m_def.get("border_color", Color(0.85, 0.52, 0.18))

	# 1. 外部深渊边界底色与竞技场大地
	draw_rect(arena_rect.grow(700.0), bg_col.darkened(0.55))
	draw_rect(arena_rect, bg_col)

	# 2. 地形贴图 1:1 无缝平铺 (彻底消除原 4x3 拉伸形变与接缝黑线)
	var ter_tex: Texture2D = GameData.get_terrain_tex(String(m_def.get("id", "map_1")))
	if ter_tex != null:
		var tile_sz: float = 480.0
		var x_tiles: int = int(ceil(arena_rect.size.x / tile_sz))
		var y_tiles: int = int(ceil(arena_rect.size.y / tile_sz))
		for ix in range(x_tiles):
			for iy in range(y_tiles):
				var px: float = arena_rect.position.x + float(ix) * tile_sz
				var py: float = arena_rect.position.y + float(iy) * tile_sz
				var w: float = minf(tile_sz, arena_rect.end.x - px)
				var h: float = minf(tile_sz, arena_rect.end.y - py)
				draw_texture_rect_region(ter_tex, Rect2(px, py, w, h), Rect2(0, 0, w, h), Color(0.92, 0.92, 0.92, 0.92))

	# 2.5 废土柏油公路 (破损公路基带 + 沥青碎裂凹坑 + 磨损黄色道路中线)
	for road in wasteland_roads:
		var p1: Vector2 = road["p1"]
		var p2: Vector2 = road["p2"]
		var rw: float = road["width"]
		draw_line(p1, p2, Color(0.12, 0.11, 0.10, 0.62), rw)
		draw_line(p1, p2, Color(0.16, 0.14, 0.13, 0.48), rw - 8.0)
		for ck in road.get("cracks", []):
			draw_set_transform(ck["pos"], ck["rot"], Vector2.ONE)
			var csz: Vector2 = ck["size"]
			draw_rect(Rect2(-csz * 0.5, csz), Color(0.08, 0.07, 0.06, 0.55))
			draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
		var seg_len: float = 24.0
		var gap_len: float = 16.0
		var total_len: float = p1.distance_to(p2)
		var r_dir: Vector2 = (p2 - p1).normalized()
		var cur_d: float = 0.0
		var line_col: Color = Color(0.85, 0.72, 0.22, 0.38)
		while cur_d < total_len:
			var sp: Vector2 = p1 + r_dir * cur_d
			var ep: Vector2 = p1 + r_dir * minf(total_len, cur_d + seg_len)
			draw_line(sp, ep, line_col, 2.5)
			cur_d += seg_len + gap_len

	# 2.8 地质断裂与深渊地缝 (Tectonic Fissures)
	var mid_id: String = String(m_def.get("id", "map_1"))
	var glow_col: Color = Color(0.95, 0.35, 0.10, 0.45) if mid_id == "map_4" else (Color(0.35, 0.95, 0.25, 0.40) if mid_id == "map_3" else Color(0.04, 0.03, 0.03, 0.70))
	for f in wasteland_fissures:
		var pts: Array = f["points"]
		var fw: float = f["width"]
		for idx in range(pts.size() - 1):
			draw_line(pts[idx], pts[idx + 1], Color(0.05, 0.04, 0.04, 0.85), fw)
			if mid_id in ["map_4", "map_3"]:
				draw_line(pts[idx], pts[idx + 1], glow_col, fw * 0.45)

	# 3. 废土休整小镇与全向安全区力场 (Wasteland Rest Town & Safe Zone)
	if town_available:
		# (1) 地面小镇基座与工业停机坪
		draw_circle(town_pos, town_radius * 0.78, Color(0.18, 0.17, 0.16, 0.75))
		draw_arc(town_pos, town_radius * 0.78, 0.0, TAU, 36, Color(0.35, 0.32, 0.28, 0.8), 2.5)

		# (2) 绿色安全区力场护盾 (Safe Zone Forcefield)
		var shield_alpha: float = 0.65 + sin(town_pulse_time * 3.5) * 0.20
		var shield_col := Color(0.25, 0.98, 0.65, shield_alpha)
		draw_circle(town_pos, town_radius, Color(0.15, 0.85, 0.45, 0.08 + sin(town_pulse_time * 2.0) * 0.03))
		draw_arc(town_pos, town_radius, 0.0, TAU, 48, shield_col, 3.5)
		draw_arc(town_pos, town_radius - 8.0, 0.0, TAU, 36, Color(0.4, 1.0, 0.75, shield_alpha * 0.5), 1.5)

		# 4 座力场水晶发射基桩 (Pylon Emitters)
		for p_idx in range(4):
			var p_ang: float = float(p_idx) * (TAU / 4.0) + town_pulse_time * 0.2
			var p_pt: Vector2 = town_pos + Vector2.from_angle(p_ang) * town_radius
			draw_circle(p_pt, 7.0, Color(0.12, 0.12, 0.12))
			draw_circle(p_pt, 4.5, Color(0.35, 1.0, 0.70))
			draw_circle(p_pt, 2.0, Color.WHITE)

		# (3) 小镇核心建筑群 (Town Architecture)
		# 麦卡改装工坊 (Main Garage)
		var b_w: float = 88.0
		var b_h: float = 56.0
		var b_pos: Vector2 = town_pos + Vector2(-b_w * 0.5, -b_h * 0.5)
		draw_rect(Rect2(b_pos, Vector2(b_w, b_h)), Color(0.24, 0.22, 0.20))
		draw_rect(Rect2(b_pos, Vector2(b_w, b_h)), Color(0.85, 0.55, 0.20), false, 2.0)
		draw_rect(Rect2(b_pos + Vector2(16, b_h - 18), Vector2(b_w - 32, 18)), Color(0.12, 0.12, 0.14))
		draw_string_outline(ThemeDB.fallback_font, town_pos + Vector2(-36, -6), "🔧 麦卡车库", HORIZONTAL_ALIGNMENT_LEFT, -1, 14, 3, Color.BLACK)
		draw_string(ThemeDB.fallback_font, town_pos + Vector2(-36, -6), "🔧 麦卡车库", HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Color(1.0, 0.88, 0.25))

		# 赏金公会办事处帐篷 (Bounty Guild Tent)
		var g_pos: Vector2 = town_pos + Vector2(58, -32)
		draw_circle(g_pos, 22.0, Color(0.35, 0.18, 0.15))
		draw_circle(g_pos, 22.0, Color(0.95, 0.35, 0.25), false, 2.0)
		draw_string_outline(ThemeDB.fallback_font, g_pos + Vector2(-16, 5), "🎯公会", HORIZONTAL_ALIGNMENT_LEFT, -1, 11, 2, Color.BLACK)
		draw_string(ThemeDB.fallback_font, g_pos + Vector2(-16, 5), "🎯公会", HORIZONTAL_ALIGNMENT_LEFT, -1, 11, Color(1.0, 0.6, 0.5))

		# 补给站油罐与弹药箱 (Fuel Depot)
		var f_pos: Vector2 = town_pos + Vector2(-68, 22)
		draw_circle(f_pos, 15.0, Color(0.32, 0.35, 0.38))
		draw_circle(f_pos + Vector2(16, 6), 12.0, Color(0.28, 0.30, 0.32))
		draw_string_outline(ThemeDB.fallback_font, f_pos + Vector2(-10, 4), "⛽", HORIZONTAL_ALIGNMENT_LEFT, -1, 12, 2, Color.BLACK)
		draw_string(ThemeDB.fallback_font, f_pos + Vector2(-10, 4), "⛽", HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color(0.4, 0.9, 1.0))

		# (4) 悬浮标题与进镇交互提示
		var t_title: String = "🏰 麦卡休整小镇 [安全区]"
		draw_string_outline(ThemeDB.fallback_font, town_pos + Vector2(-75, -town_radius - 14), t_title, HORIZONTAL_ALIGNMENT_LEFT, -1, 16, 4, Color.BLACK)
		draw_string(ThemeDB.fallback_font, town_pos + Vector2(-75, -town_radius - 14), t_title, HORIZONTAL_ALIGNMENT_LEFT, -1, 16, Color(0.35, 1.0, 0.65))

		if is_player_in_safe_zone:
			var prompt_txt: String = "💡 按 [E] / [空格] 进入小镇休整 (本波限进 1 次)"
			var pulse_prompt: float = 0.85 + sin(town_pulse_time * 6.0) * 0.15
			draw_string_outline(ThemeDB.fallback_font, town_pos + Vector2(-130, town_radius + 24), prompt_txt, HORIZONTAL_ALIGNMENT_LEFT, -1, 14, 3, Color.BLACK)
			draw_string(ThemeDB.fallback_font, town_pos + Vector2(-130, town_radius + 24), prompt_txt, HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Color(1.0, 0.95, 0.35, pulse_prompt))

	# 3. 弹坑与沙地凹坑
	for c in craters:
		draw_circle(c["pos"], c["radius"], bg_col.darkened(0.38))
		draw_arc(c["pos"], c["radius"], 0.0, TAU, 24, grid_col.lightened(0.18), 2.5)

	# 5. 废土战地废墟与残骸地貌 (Landmarks)
	for lm in landmarks:
		draw_set_transform(lm["pos"], lm["angle"], Vector2.ONE)
		var sz: Vector2 = lm["size"]
		match lm["kind"]:
			0: # 废弃混凝土防御桩
				draw_rect(Rect2(-sz * 0.5, sz), Color(0.18, 0.17, 0.16))
				draw_rect(Rect2(-sz * 0.5, sz), Color(0.42, 0.40, 0.38), false, 2.0)
				draw_line(Vector2(-sz.x * 0.4, 0), Vector2(sz.x * 0.4, 0), Color(0.65, 0.45, 0.25), 2.0)
			1: # 锈蚀重坦残骸
				draw_rect(Rect2(-sz * 0.5, sz), Color(0.28, 0.20, 0.14))
				draw_rect(Rect2(-sz.x * 0.3, -sz.y * 0.3, sz.x * 0.6, sz.y * 0.6), Color(0.38, 0.26, 0.18))
				draw_line(Vector2(0, 0), Vector2(sz.x * 0.6, 0), Color(0.15, 0.15, 0.15), 3.0)
			2: # 废弃金属油桶堆
				draw_circle(Vector2(-sz.x * 0.25, 0), sz.y * 0.35, Color(0.35, 0.22, 0.15))
				draw_circle(Vector2(sz.x * 0.25, 0), sz.y * 0.35, Color(0.45, 0.28, 0.18))
				draw_circle(Vector2(0, -sz.y * 0.25), sz.y * 0.32, Color(0.25, 0.18, 0.14))
		draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)

	# 6. 战车履带车辙印
	for tm in tread_marks:
		var dir: Vector2 = Vector2.from_angle(tm["angle"]).orthogonal() * 26.0
		draw_circle(tm["pos"] + dir, 5.0, Color(0.08, 0.07, 0.06, 0.45))
		draw_circle(tm["pos"] - dir, 5.0, Color(0.08, 0.07, 0.06, 0.45))

	# 7. 刷怪红叉预警 (土豆兄弟式地面红叉)
	for st in spawn_telegraphs:
		var p: Vector2 = st["pos"]
		draw_arc(p, 24.0, 0.0, TAU, 20, Color(1.0, 0.2, 0.2, 0.75), 2.5)
		draw_line(p - Vector2(12, 12), p + Vector2(12, 12), Color(1.0, 0.2, 0.2, 0.85), 3.5)
		draw_line(p - Vector2(12, -12), p + Vector2(12, -12), Color(1.0, 0.2, 0.2, 0.85), 3.5)

	# 7.5 绘制动态战场随机事件区域 (空投防守圈 / 诺亚干扰信标 / 强酸沙尘暴)
	if not active_arena_event.is_empty():
		var ev_t: String = String(active_arena_event.get("type", ""))
		if ev_t in ["airdrop_defense", "noah_beacon"]:
			var ep: Vector2 = active_arena_event.get("pos", Vector2.ZERO)
			var er: float = float(active_arena_event.get("radius", 140.0))
			var prog: float = float(active_arena_event.get("progress", 0.0))
			var goal: float = maxf(0.1, float(active_arena_event.get("goal", 3.5)))
			var ratio: float = clampf(prog / goal, 0.0, 1.0)
			var ecol: Color = Color(0.25, 0.95, 0.52) if ev_t == "airdrop_defense" else Color(0.35, 0.90, 1.0)
			draw_circle(ep, er, Color(ecol.r, ecol.g, ecol.b, 0.14))
			draw_arc(ep, er, 0.0, TAU, 36, Color(ecol.r, ecol.g, ecol.b, 0.75), 3.0)
			if ratio > 0.0:
				draw_arc(ep, er - 6.0, -PI * 0.5, -PI * 0.5 + TAU * ratio, 32, Color(1.0, 0.92, 0.25, 0.95), 5.0)
			var ev_label: String = "%s (%d%%)" % [active_arena_event.get("name", "事件"), int(ratio * 100.0)]
			draw_string_outline(ThemeDB.fallback_font, ep + Vector2(-75, -er - 12), ev_label, HORIZONTAL_ALIGNMENT_LEFT, -1, 15, 3, Color.BLACK)
			draw_string(ThemeDB.fallback_font, ep + Vector2(-75, -er - 12), ev_label, HORIZONTAL_ALIGNMENT_LEFT, -1, 15, ecol)
		elif ev_t == "acid_sandstorm":
			draw_rect(arena_rect, Color(0.45, 0.85, 0.20, 0.08))

	# 7.8 废土风沙与漂浮粒子 (Ambient Dust & Embers)
	var dust_tint: Color = Color(1.0, 0.55, 0.20) if mid_id == "map_4" else Color(0.88, 0.80, 0.65)
	for dp in dust_particles:
		var c := dust_tint
		c.a = dp["alpha"]
		draw_circle(dp["pos"], dp["size"], c)

	# 8. 废土警戒高压电网边界
	draw_rect(arena_rect, border_col, false, 6.0)
	draw_rect(arena_rect.grow(4.0), Color(1.0, 0.85, 0.25, 0.45), false, 1.5)

# --- 土豆兄弟风格 UI 构建辅助函数 ---
func _create_brotato_bar(min_sz: Vector2, fill_col: Color, font_sz: int) -> Dictionary:
	var container := Control.new()
	container.custom_minimum_size = min_sz

	var bar := ProgressBar.new()
	bar.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	bar.show_percentage = false

	var bg_style := StyleBoxFlat.new()
	bg_style.bg_color = Color(0.08, 0.08, 0.10, 0.92)
	bg_style.border_color = Color(0.02, 0.02, 0.03, 1.0)
	bg_style.set_border_width_all(2)
	bg_style.set_corner_radius_all(5)

	var fill_style := StyleBoxFlat.new()
	fill_style.bg_color = fill_col
	fill_style.border_color = Color(0.02, 0.02, 0.03, 1.0)
	fill_style.set_border_width_all(2)
	fill_style.set_corner_radius_all(5)

	bar.add_theme_stylebox_override("background", bg_style)
	bar.add_theme_stylebox_override("fill", fill_style)
	container.add_child(bar)

	var lbl := _make_outlined_label("", font_sz, Color.WHITE)
	lbl.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	container.add_child(lbl)

	return {"container": container, "bar": bar, "fill_style": fill_style, "label": lbl}

func _make_outlined_label(txt: String, f_size: int, col: Color) -> Label:
	var l := Label.new()
	l.text = txt
	l.add_theme_font_size_override("font_size", f_size)
	l.add_theme_color_override("font_color", col)
	l.add_theme_color_override("font_outline_color", Color(0.0, 0.0, 0.0, 0.95))
	l.add_theme_constant_override("outline_size", 4)
	return l

func _make_card_box(bg_col: Color, border_col: Color) -> PanelContainer:
	var p := PanelContainer.new()
	var s := StyleBoxFlat.new()
	s.bg_color = bg_col
	s.border_color = border_col
	s.set_border_width_all(2)
	s.set_corner_radius_all(8)
	s.content_margin_left = 12
	s.content_margin_right = 12
	s.content_margin_top = 10
	s.content_margin_bottom = 10
	p.add_theme_stylebox_override("panel", s)
	return p

func _add_stat_row(parent: VBoxContainer, k_txt: String, v_txt: String, v_col: Color) -> void:
	var row := HBoxContainer.new()
	parent.add_child(row)
	var kl := _make_outlined_label(k_txt, 13, Color(0.82, 0.82, 0.86))
	kl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(kl)
	var vl := _make_outlined_label(v_txt, 13, v_col)
	vl.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	row.add_child(vl)
