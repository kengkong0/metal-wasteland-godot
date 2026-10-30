extends Node2D
## 《重装废土：赏金狂飙》 - 废土战场主控脚本 (土豆兄弟风格 HUD & 全分辨率自适应版)
## 负责：沙地地形与履带印绘制、波次倒计时、动态刷怪、赏金首巨型血条、升级选卡与战场HUD。

signal wave_completed
signal player_defeated
signal game_victory

const EnemyScript = preload("res://scripts/combat/Enemy.gd")
const ProjectileScript = preload("res://scripts/combat/Projectile.gd")
const DropItemScript = preload("res://scripts/combat/DropItem.gd")
const FloatingTextScript = preload("res://scripts/combat/FloatingText.gd")
const PlayerTankScript = preload("res://scripts/combat/PlayerTank.gd")

var arena_rect: Rect2 = Rect2(80, 76, 1280, 694)
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
	_update_arena_bounds()
	_generate_wasteland_craters()

func _update_arena_bounds() -> void:
	var vp_size: Vector2 = get_viewport_rect().size
	if vp_size.x > 400.0 and vp_size.y > 300.0:
		var aw: float = clampf(vp_size.x - 120.0, 1100.0, 1560.0)
		var ah: float = clampf(vp_size.y - 110.0, 620.0, 880.0)
		arena_rect = Rect2((vp_size.x - aw) * 0.5, (vp_size.y - ah) * 0.5 + 18.0, aw, ah)

func _generate_wasteland_craters() -> void:
	craters.clear()
	for i in range(20):
		craters.append({
			"pos": Vector2(randf_range(arena_rect.position.x + 40, arena_rect.end.x - 40), randf_range(arena_rect.position.y + 40, arena_rect.end.y - 40)),
			"radius": randf_range(16.0, 44.0),
			"shade": randf_range(0.08, 0.16)
		})

func _build_hud() -> void:
	hud_layer = CanvasLayer.new()
	add_child(hud_layer)

	hud_root = Control.new()
	hud_root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	hud_root.mouse_filter = Control.MOUSE_FILTER_PASS
	hud_layer.add_child(hud_root)

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
	p_panel.custom_minimum_size = Vector2(760, 450)
	var p_style := StyleBoxFlat.new()
	p_style.bg_color = Color(0.13, 0.13, 0.15, 0.98)
	p_style.border_color = Color(0.95, 0.72, 0.25)
	p_style.set_border_width_all(3)
	p_style.set_corner_radius_all(12)
	p_style.content_margin_left = 22
	p_style.content_margin_right = 22
	p_style.content_margin_top = 18
	p_style.content_margin_bottom = 18
	p_panel.add_theme_stylebox_override("panel", p_style)
	p_center.add_child(p_panel)

	var p_vbox := VBoxContainer.new()
	p_vbox.add_theme_constant_override("separation", 12)
	p_panel.add_child(p_vbox)

	var p_title := _make_outlined_label("⏸️ 战术暂停 — 属性与武装总览", 22, Color(1.0, 0.88, 0.30))
	p_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	p_vbox.add_child(p_title)

	var mid_hbox := HBoxContainer.new()
	mid_hbox.size_flags_vertical = Control.SIZE_EXPAND_FILL
	mid_hbox.add_theme_constant_override("separation", 16)
	p_vbox.add_child(mid_hbox)

	# 左栏：土豆兄弟式属性列表
	var left_box := _make_card_box(Color(0.17, 0.17, 0.20), Color(0.45, 0.65, 0.85))
	left_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	mid_hbox.add_child(left_box)
	pause_stats_vbox = VBoxContainer.new()
	pause_stats_vbox.add_theme_constant_override("separation", 6)
	left_box.add_child(pause_stats_vbox)

	# 右栏：已装武器徽章列表
	var right_box := _make_card_box(Color(0.17, 0.17, 0.20), Color(0.85, 0.65, 0.25))
	right_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	mid_hbox.add_child(right_box)
	pause_weapons_vbox = VBoxContainer.new()
	pause_weapons_vbox.add_theme_constant_override("separation", 6)
	right_box.add_child(pause_weapons_vbox)

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
		for c in pause_stats_vbox.get_children():
			c.queue_free()
		for c in pause_weapons_vbox.get_children():
			c.queue_free()

		var st_title := _make_outlined_label("📊 战车与猎人属性", 16, Color(0.55, 0.85, 1.0))
		pause_stats_vbox.add_child(st_title)
		_add_stat_row(pause_stats_vbox, "🗺️ 当前战区", "%s [%s]" % [GameState.get_current_map_def()["name"].substr(0, 7), GameState.get_current_difficulty_def()["name"].substr(0, 4)], Color(1.0, 0.88, 0.35))
		_add_stat_row(pause_stats_vbox, "🎖️ 猎人 / 座驾", "%s / %s" % [GameData.HUNTERS[GameState.selected_hunter_id]["name"].split(" ")[0], GameData.CHASSIS[GameState.selected_chassis_id]["name"].split(" ")[0]], Color.WHITE)
		_add_stat_row(pause_stats_vbox, "🛡️ 最大装甲 (SP)", "%d SP (+%.0f/s)" % [int(GameState.max_sp), GameState.sp_regen_per_sec], Color(0.35, 0.98, 0.55))
		_add_stat_row(pause_stats_vbox, "⚖️ 引擎载重", "%.1f / %.1f t" % [GameState.used_weight, GameState.max_weight], Color(0.95, 0.82, 0.35))
		_add_stat_row(pause_stats_vbox, "💥 暴击率", "%d%%" % int(GameState.crit_chance * 100.0), Color(1.0, 0.55, 0.30))
		_add_stat_row(pause_stats_vbox, "💨 闪避率", "%d%%" % int(GameState.dodge_chance * 100.0), Color(0.45, 0.92, 1.0))
		_add_stat_row(pause_stats_vbox, "⚡ 装填加速", "+%d%%" % int(GameState.bonus_stats.get("reload_speed_pct", 0.0) * 100.0), Color(0.85, 0.65, 1.0))

		var wp_title := _make_outlined_label("🔫 已装备武装 (%d/%d)" % [GameState.equipped_weapons.size(), GameState.chassis_slots.size()], 16, Color(1.0, 0.85, 0.30))
		pause_weapons_vbox.add_child(wp_title)
		for ew in GameState.equipped_weapons:
			var wd: Dictionary = GameData.WEAPONS[ew["id"]]
			var rar: int = int(ew.get("rarity", 0))
			var eff_dmg: float = GameState.get_weapon_effective_damage(ew["id"], rar)
			_add_stat_row(pause_weapons_vbox, "[%s] %s" % [wd["slot"], wd["name"]], "%s | 💥%.0f" % [GameData.RARITY_NAMES[rar], eff_dmg], GameData.RARITY_COLORS[rar])

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
	wave_time_left = minf(50.0, 28.0 + GameState.current_wave * 2.0)
	if GameState.current_wave == GameState.max_waves:
		wave_time_left = 75.0
		GameState.active_wanted_boss_id = GameState.get_current_map_def()["final_boss_id"]

	boss_spawned_this_wave = false
	spawn_timer = 0.5
	elite_spawn_timer = 10.5
	fx_layer.mortar_strikes.clear()

	player_tank.init_for_wave(arena_rect.get_center())

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

	_update_arena_bounds()
	wave_elapsed += delta
	wave_time_left -= delta

	if banner_timer > 0.0:
		banner_timer -= delta
		if banner_timer <= 0.0:
			banner_wanted.visible = false

	if shake_timer > 0.0:
		shake_timer -= delta
		position = Vector2(randf_range(-shake_intensity, shake_intensity), randf_range(-shake_intensity, shake_intensity))
	else:
		position = Vector2.ZERO

	# 1. 赏金首乱入
	var boss_enter_delay: float = 2.5 if GameState.current_wave >= GameState.max_waves else 5.5
	if not boss_spawned_this_wave and GameState.active_wanted_boss_id != "" and wave_elapsed >= boss_enter_delay:
		boss_spawned_this_wave = true
		wave_time_left = maxf(wave_time_left + 15.0, 45.0)
		_spawn_wanted_boss(GameState.active_wanted_boss_id)

	# 2. 红狼乱入救援
	if boss_spawned_this_wave and not red_wolf_rescued_this_run and not player_tank.is_human_mode:
		if player_tank.current_sp > 0.0 and player_tank.current_sp <= GameState.max_sp * 0.25:
			_trigger_red_wolf_rescue()

	# 3. 定时刷重装精英与小怪
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

func _get_alive_boss() -> Node2D:
	for e in enemies_container.get_children():
		if is_instance_valid(e) and e.get("is_boss") == true:
			return e
	return null

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
	fx_layer.spawn_text(pos + Vector2(0, -24), "⚡ 重装精英：%s !" % GameData.ENEMIES[chosen_id]["name"], Color(1.0, 0.85, 0.20), 1.25)

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
	banner_timer = 4.5
	lbl_wanted_banner.text = "⚠️ 赏金首乱入：【%s】 (💰%dG) ⚠️" % [boss_def["name"], int(boss_def["bounty"])]

func _trigger_red_wolf_rescue() -> void:
	red_wolf_rescued_this_run = true
	SoundManager.play("cannon_heavy", 0.02, 4.0)
	trigger_screen_shake(16.0, 0.5)
	banner_wanted.visible = true
	banner_timer = 4.5
	lbl_wanted_banner.text = "🔥 传奇猎人【红狼】驾驶红狼号乱入支援！！ 🔥"

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
	fx_layer.spawn_text(pos, "⚡明奇电击脉冲!", Color(0.65, 0.5, 1.0), 1.05)
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

func _populate_battlefield_level_cards() -> void:
	for c in level_up_cards_hbox.get_children():
		c.queue_free()

	var show_hints: bool = GameState.should_show_build_hints()
	if show_hints:
		lbl_level_up_sub.text = "💡 集齐特定两把关联武器并升至 ★2 (或拾取宝箱)，自动融合成不占槽位的【★6 神话超武】"
	else:
		lbl_level_up_sub.text = "🔴 【地狱模式盲配】已隐藏流派与超武配件提示，全凭老猎人直觉搭配！"

	var perks: Array = GameData.LEVEL_PERKS.duplicate()
	perks.shuffle()
	var perk_icons: Dictionary = {
		"main_dmg": "💥", "sub_se_dmg": "🔫", "max_weight": "⚖️", "reload_spd": "⚡",
		"crit_chance": "🎯", "sp_regen": "🔧", "move_ram": "🚜", "bounty_magnet": "🧲"
	}

	# 前 2 张：土豆兄弟风格属性升级卡
	for i in range(2):
		var p: Dictionary = perks[i]
		var card := _make_card_box(Color(0.16, 0.17, 0.21), Color(0.35, 0.85, 0.50))
		card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		card.size_flags_vertical = Control.SIZE_EXPAND_FILL
		level_up_cards_hbox.add_child(card)

		var cv := VBoxContainer.new()
		cv.add_theme_constant_override("separation", 10)
		card.add_child(cv)

		var badge_lbl := _make_outlined_label("🎖️ 猎人专精强化", 13, Color(0.55, 0.95, 0.65))
		badge_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		cv.add_child(badge_lbl)

		var icon_lbl := _make_outlined_label("%s %s" % [perk_icons.get(p["id"], "★"), p["name"]], 20, Color(1.0, 0.92, 0.35))
		icon_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		cv.add_child(icon_lbl)

		var sep := HSeparator.new()
		cv.add_child(sep)

		var desc_lbl := _make_outlined_label("✅ %s\n💚 立即恢复 15%% 战车装甲(SP)" % p["desc"], 15, Color(0.45, 1.0, 0.55))
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
			GameState.bonus_stats[st] = GameState.bonus_stats.get(st, 0.0) + float(p["val"])
			GameState.pending_level_ups = max(0, GameState.pending_level_ups - 1)
			GameState.recalculate_stats()
			player_tank.heal_sp(GameState.max_sp * 0.15)
			SoundManager.play("coin", 0.08, 0.0)
			_close_or_next_level_modal()
		)
		cv.add_child(btn)
		if i == 0:
			btn.call_deferred("grab_focus")

	# 第 3 张：战场空投武器卡
	var airdrop_w_id: String = _pick_smart_airdrop_weapon()
	var w_def: Dictionary = GameData.WEAPONS[airdrop_w_id]
	var evo_partner_name: String = GameState.check_super_evolution_partner(airdrop_w_id)
	var can_merge: bool = false
	for ew in GameState.equipped_weapons:
		if ew["id"] == airdrop_w_id and int(ew.get("rarity", 0)) < 4:
			can_merge = true
			break

	var w_card := _make_card_box(Color(0.20, 0.16, 0.14), Color(1.0, 0.75, 0.25))
	w_card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	w_card.size_flags_vertical = Control.SIZE_EXPAND_FILL
	level_up_cards_hbox.add_child(w_card)

	var wv := VBoxContainer.new()
	wv.add_theme_constant_override("separation", 8)
	w_card.add_child(wv)

	var air_badge := _make_outlined_label("🪂 战场空投补给 [%s孔]" % w_def["slot"], 13, Color(1.0, 0.82, 0.32))
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
			hint_text += "\n🔥 同名武器！拾取直接二合一升星！"

	var w_desc := _make_outlined_label(hint_text, 13, Color(1.0, 0.88, 0.45) if (evo_partner_name != "" or can_merge) else Color(0.85, 0.85, 0.85))
	w_desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	w_desc.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	w_desc.size_flags_vertical = Control.SIZE_EXPAND_FILL
	wv.add_child(w_desc)

	var air_btn := Button.new()
	air_btn.custom_minimum_size = Vector2(0, 44)
	air_btn.text = "空投装配 (+15% SP)"
	air_btn.add_theme_font_size_override("font_size", 16)
	air_btn.pressed.connect(func():
		GameState.pending_level_ups = max(0, GameState.pending_level_ups - 1)
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
	wv.add_child(air_btn)

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
	lbl_wanted_banner.text = "🌟 【神话超武合成！】 [%s] + [%s] ➔ %s 🌟" % [
		evo_info["comp_a_name"], evo_info["comp_b_name"], evo_info["evo_name"]
	]
	if is_instance_valid(player_tank) and is_instance_valid(fx_layer):
		fx_layer.spawn_explosion(player_tank.get_active_position(), 200.0, Color(1.0, 0.88, 0.20))
		fx_layer.spawn_text(player_tank.get_active_position() + Vector2(0, -36), "★ 神话超武：%s ★" % evo_info["evo_name"], Color(1.0, 0.90, 0.20), 1.55)

func _finish_wave_success() -> void:
	wave_active = false
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
	lbl_all_out_val.text = "🚀 [Q] 全弹就绪!" if ao_ready else "🚀 全弹 %.1fs" % player_tank.all_out_timer

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

func _draw() -> void:
	var m_def: Dictionary = GameState.get_current_map_def()
	var bg_col: Color = m_def.get("bg_color", Color(0.22, 0.18, 0.13))
	var grid_col: Color = m_def.get("grid_color", Color(0.26, 0.21, 0.16))
	var border_col: Color = m_def.get("border_color", Color(0.85, 0.52, 0.18))

	# 1. 填充全屏远景暗底色 + 绘制战场贴图与网格
	var vp_rect: Rect2 = get_viewport_rect()
	draw_rect(vp_rect, bg_col.darkened(0.48))
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

	var grid_line_col: Color = Color(grid_col.r, grid_col.g, grid_col.b, 0.32)
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

	# 4. 刷怪红叉预警 (土豆兄弟式地面红叉)
	for st in spawn_telegraphs:
		var p: Vector2 = st["pos"]
		draw_arc(p, 18.0, 0.0, TAU, 16, Color(1.0, 0.2, 0.2, 0.75), 2.0)
		draw_line(p - Vector2(9, 9), p + Vector2(9, 9), Color(1.0, 0.2, 0.2, 0.85), 3.0)
		draw_line(p - Vector2(9, -9), p + Vector2(9, -9), Color(1.0, 0.2, 0.2, 0.85), 3.0)

	# 5. 警戒边界框
	draw_rect(arena_rect, border_col, false, 4.0)

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
