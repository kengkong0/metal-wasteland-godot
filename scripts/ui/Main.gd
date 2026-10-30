extends Node
## 《重装废土：赏金狂飙》 - 顶层场景与【土豆兄弟风格选角/选车/选图/局外科技树】控制器
## 核心改进：
## 1. 全屏与任意分辨率 100% 锚点自适应 (CenterContainer / MarginContainer / GridContainer)，彻底消除文字裁切与溢出
## 2. 参考《土豆兄弟 (Brotato)》选角界面：上方【三联大号视觉详情卡 (立绘+属性进度条+词条)】+ 下方【紧凑图标网格】
## 3. 局外科技树加入可视化等级进度条 (ProgressBar)，明奇结算界面采用居中卡片式战绩表

const BattlefieldScript = preload("res://scripts/combat/Battlefield.gd")
const GarageUIScript = preload("res://scripts/ui/GarageUI.gd")

var battlefield: Node2D
var ui_layer: CanvasLayer
var title_screen: Control
var garage_ui: Control
var mince_modal: Control

var chosen_hunter: String = "bounty_hunter"
var chosen_chassis: String = "buggy"
var chosen_map_idx: int = 0
var chosen_diff_id: String = "normal"

# --- 大本营顶部栏引用 ---
var lbl_chips_header: Label
var lbl_stats_header: Label
var lbl_camp_toast: Label
var tab_loadout_view: Control
var tab_meta_view: Control

# --- 上方三联详情展示卡引用 (土豆兄弟风格) ---
var showcase_hunter_box: VBoxContainer
var showcase_chassis_box: VBoxContainer
var showcase_map_box: VBoxContainer
var btn_start_run: Button

# --- 下方三组图标选择网格引用 ---
var hunters_grid: GridContainer
var chassis_grid: GridContainer
var maps_vbox: VBoxContainer

# --- 局外科技树引用 ---
var features_vbox: VBoxContainer
var upgrades_vbox: VBoxContainer

# --- 明奇博士结算弹窗引用 ---
var mince_stats_vbox: VBoxContainer
var btn_mince_continue: Button
var btn_mince_settle_to_meta: Button

func _ready() -> void:
	battlefield = Node2D.new()
	battlefield.name = "Battlefield"
	battlefield.set_script(BattlefieldScript)
	battlefield.visible = false
	add_child(battlefield)

	battlefield.wave_completed.connect(_on_wave_completed)
	battlefield.player_defeated.connect(_on_player_defeated)
	battlefield.game_victory.connect(_on_game_victory)

	ui_layer = CanvasLayer.new()
	ui_layer.layer = 10
	add_child(ui_layer)

	garage_ui = Control.new()
	garage_ui.name = "GarageUI"
	garage_ui.set_script(GarageUIScript)
	garage_ui.visible = false
	ui_layer.add_child(garage_ui)
	garage_ui.start_next_wave.connect(_on_start_next_wave)

	_build_title_screen()
	_build_mince_modal()
	_show_title_screen(false)

func _build_title_screen() -> void:
	title_screen = Control.new()
	title_screen.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	ui_layer.add_child(title_screen)

	var bg := ColorRect.new()
	bg.color = Color(0.08, 0.08, 0.10, 1.0)
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	title_screen.add_child(bg)

	var margin := MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	margin.add_theme_constant_override("margin_left", 16)
	margin.add_theme_constant_override("margin_right", 16)
	margin.add_theme_constant_override("margin_top", 12)
	margin.add_theme_constant_override("margin_bottom", 12)
	title_screen.add_child(margin)

	var root_vbox := VBoxContainer.new()
	root_vbox.add_theme_constant_override("separation", 8)
	margin.add_child(root_vbox)

	# ========================================================================
	# 1. 顶部主导航栏 (游戏标题 + 页签切换 + 诺亚晶片大图标 + 全屏/福利按钮)
	# ========================================================================
	var top_panel := _make_box(Color(0.14, 0.14, 0.17), Color(0.95, 0.55, 0.20))
	root_vbox.add_child(top_panel)

	var top_vbox := VBoxContainer.new()
	top_vbox.add_theme_constant_override("separation", 4)
	top_panel.add_child(top_vbox)

	var nav_row := HBoxContainer.new()
	nav_row.add_theme_constant_override("separation", 10)
	top_vbox.add_child(nav_row)

	var title_lbl := _make_outlined_label("🔥 重装废土：赏金狂飙", 22, Color(1.0, 0.52, 0.22))
	nav_row.add_child(title_lbl)

	var btn_tab_loadout := Button.new()
	btn_tab_loadout.text = "🚜 出击整备"
	btn_tab_loadout.custom_minimum_size = Vector2(125, 36)
	btn_tab_loadout.pressed.connect(func():
		tab_loadout_view.visible = true
		tab_meta_view.visible = false
		SoundManager.play("coin", 0.1, -3.0)
		_refresh_camp_ui()
	)
	nav_row.add_child(btn_tab_loadout)

	var btn_tab_meta := Button.new()
	btn_tab_meta.text = "🧬 局外科技树"
	btn_tab_meta.custom_minimum_size = Vector2(135, 36)
	btn_tab_meta.pressed.connect(func():
		tab_loadout_view.visible = false
		tab_meta_view.visible = true
		SoundManager.play("coin", 0.1, -3.0)
		_refresh_camp_ui()
	)
	nav_row.add_child(btn_tab_meta)

	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	nav_row.add_child(spacer)

	lbl_chips_header = _make_outlined_label("💎 0", 20, Color(0.40, 0.95, 1.0))
	nav_row.add_child(lbl_chips_header)

	lbl_stats_header = _make_outlined_label("", 13, Color(0.82, 0.85, 0.90))
	nav_row.add_child(lbl_stats_header)

	var btn_debug := Button.new()
	btn_debug.text = "🎁 +500💎&全图"
	btn_debug.custom_minimum_size = Vector2(125, 34)
	btn_debug.pressed.connect(func():
		GameState.noah_chips += 500
		GameState.unlocked_map_count = GameData.MAPS.size()
		GameState.save_meta_data()
		SoundManager.play("upgrade", 0.05, 1.0)
		lbl_camp_toast.text = "🎁 已发放 +500 💎 诺亚晶片并解锁全部 5 张战区地图！"
		_refresh_camp_ui()
	)
	nav_row.add_child(btn_debug)

	var btn_fs := Button.new()
	btn_fs.text = "🖥️ 全屏[F11]"
	btn_fs.custom_minimum_size = Vector2(96, 34)
	btn_fs.pressed.connect(_toggle_fullscreen)
	nav_row.add_child(btn_fs)

	var btn_reset := Button.new()
	btn_reset.text = "🗑️重置"
	btn_reset.custom_minimum_size = Vector2(68, 34)
	btn_reset.pressed.connect(func():
		GameState.reset_meta_save()
		chosen_hunter = "bounty_hunter"
		chosen_chassis = "buggy"
		chosen_map_idx = 0
		chosen_diff_id = "normal"
		lbl_camp_toast.text = "已重置存档为初始状态。"
		_refresh_camp_ui()
	)
	nav_row.add_child(btn_reset)

	lbl_camp_toast = _make_outlined_label("💡 点击下方头像网格切换【猎人】【战车】【战区地图】，未解锁项点击可直接用 💎 解锁！", 13, Color(1.0, 0.88, 0.38))
	lbl_camp_toast.clip_text = true
	top_vbox.add_child(lbl_camp_toast)

	# ========================================================================
	# 视图 A：土豆兄弟风格【出击整备】 (上方三联视觉详情卡 + 下方三栏图标网格)
	# ========================================================================
	tab_loadout_view = VBoxContainer.new()
	tab_loadout_view.size_flags_vertical = Control.SIZE_EXPAND_FILL
	tab_loadout_view.add_theme_constant_override("separation", 10)
	root_vbox.add_child(tab_loadout_view)

	# --- 上半部：三联视觉详情展示卡 (猎人卡 | 战车属性进度条卡 | 地图与难度出击卡) ---
	var showcase_hbox := HBoxContainer.new()
	showcase_hbox.size_flags_vertical = Control.SIZE_EXPAND_FILL
	showcase_hbox.size_flags_stretch_ratio = 1.05
	showcase_hbox.add_theme_constant_override("separation", 12)
	tab_loadout_view.add_child(showcase_hbox)

	var sh_panel := _make_box(Color(0.15, 0.14, 0.17), Color(0.95, 0.65, 0.25))
	sh_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	sh_panel.size_flags_stretch_ratio = 1.0
	showcase_hbox.add_child(sh_panel)
	showcase_hunter_box = VBoxContainer.new()
	showcase_hunter_box.add_theme_constant_override("separation", 6)
	sh_panel.add_child(showcase_hunter_box)

	var sc_panel := _make_box(Color(0.15, 0.14, 0.17), Color(0.92, 0.35, 0.28))
	sc_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	sc_panel.size_flags_stretch_ratio = 1.15
	showcase_hbox.add_child(sc_panel)
	showcase_chassis_box = VBoxContainer.new()
	showcase_chassis_box.add_theme_constant_override("separation", 6)
	sc_panel.add_child(showcase_chassis_box)

	var sm_panel := _make_box(Color(0.14, 0.16, 0.16), Color(0.38, 0.90, 0.55))
	sm_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	sm_panel.size_flags_stretch_ratio = 1.25
	showcase_hbox.add_child(sm_panel)
	showcase_map_box = VBoxContainer.new()
	showcase_map_box.add_theme_constant_override("separation", 6)
	sm_panel.add_child(showcase_map_box)

	# --- 下半部：土豆兄弟风格三栏图标网格 (零文字截断！) ---
	var grids_hbox := HBoxContainer.new()
	grids_hbox.size_flags_vertical = Control.SIZE_EXPAND_FILL
	grids_hbox.size_flags_stretch_ratio = 1.25
	grids_hbox.add_theme_constant_override("separation", 12)
	tab_loadout_view.add_child(grids_hbox)

	# 左下：6大猎人头像网格 (3列×2行)
	var h_grid_panel := _make_box(Color(0.13, 0.13, 0.16), Color(0.65, 0.48, 0.25))
	h_grid_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	h_grid_panel.size_flags_stretch_ratio = 1.0
	grids_hbox.add_child(h_grid_panel)

	var hg_vbox := VBoxContainer.new()
	hg_vbox.add_theme_constant_override("separation", 6)
	h_grid_panel.add_child(hg_vbox)
	hg_vbox.add_child(_make_outlined_label("🎖️ 选择猎人 (6名)", 15, Color(1.0, 0.85, 0.32)))

	var hg_scroll := ScrollContainer.new()
	hg_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	hg_vbox.add_child(hg_scroll)

	hunters_grid = GridContainer.new()
	hunters_grid.columns = 3
	hunters_grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hunters_grid.size_flags_vertical = Control.SIZE_EXPAND_FILL
	hunters_grid.add_theme_constant_override("h_separation", 8)
	hunters_grid.add_theme_constant_override("v_separation", 8)
	hg_scroll.add_child(hunters_grid)

	# 中下：8大战车底盘图标网格 (4列×2行)
	var c_grid_panel := _make_box(Color(0.13, 0.13, 0.16), Color(0.68, 0.30, 0.25))
	c_grid_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	c_grid_panel.size_flags_stretch_ratio = 1.15
	grids_hbox.add_child(c_grid_panel)

	var cg_vbox := VBoxContainer.new()
	cg_vbox.add_theme_constant_override("separation", 6)
	c_grid_panel.add_child(cg_vbox)
	cg_vbox.add_child(_make_outlined_label("🚜 选择战车底盘 (8台)", 15, Color(1.0, 0.50, 0.38)))

	var cg_scroll := ScrollContainer.new()
	cg_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	cg_vbox.add_child(cg_scroll)

	chassis_grid = GridContainer.new()
	chassis_grid.columns = 4
	chassis_grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	chassis_grid.size_flags_vertical = Control.SIZE_EXPAND_FILL
	chassis_grid.add_theme_constant_override("h_separation", 8)
	chassis_grid.add_theme_constant_override("v_separation", 8)
	cg_scroll.add_child(chassis_grid)

	# 右下：5大战区地图章节卡列表
	var m_grid_panel := _make_box(Color(0.13, 0.14, 0.15), Color(0.35, 0.72, 0.48))
	m_grid_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	m_grid_panel.size_flags_stretch_ratio = 1.25
	grids_hbox.add_child(m_grid_panel)

	var mg_vbox := VBoxContainer.new()
	mg_vbox.add_theme_constant_override("separation", 6)
	m_grid_panel.add_child(mg_vbox)
	mg_vbox.add_child(_make_outlined_label("🗺️ 选择废土战区章节 (通关解锁下一章)", 15, Color(0.45, 0.95, 0.65)))

	var mg_scroll := ScrollContainer.new()
	mg_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	mg_vbox.add_child(mg_scroll)

	maps_vbox = VBoxContainer.new()
	maps_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	maps_vbox.add_theme_constant_override("separation", 6)
	mg_scroll.add_child(maps_vbox)

	# ========================================================================
	# 视图 B：局外永久养成所 (带可视化等级进度条)
	# ========================================================================
	tab_meta_view = HBoxContainer.new()
	tab_meta_view.size_flags_vertical = Control.SIZE_EXPAND_FILL
	tab_meta_view.add_theme_constant_override("separation", 14)
	tab_meta_view.visible = false
	root_vbox.add_child(tab_meta_view)

	var feat_panel := _make_box(Color(0.14, 0.14, 0.17), Color(0.35, 0.85, 1.0))
	feat_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	tab_meta_view.add_child(feat_panel)

	var feat_scroll := ScrollContainer.new()
	feat_scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	feat_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	feat_panel.add_child(feat_scroll)

	features_vbox = VBoxContainer.new()
	features_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	features_vbox.add_theme_constant_override("separation", 8)
	feat_scroll.add_child(features_vbox)

	var upg_panel := _make_box(Color(0.15, 0.13, 0.17), Color(0.85, 0.50, 1.0))
	upg_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	tab_meta_view.add_child(upg_panel)

	var upg_scroll := ScrollContainer.new()
	upg_scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	upg_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	upg_panel.add_child(upg_scroll)

	upgrades_vbox = VBoxContainer.new()
	upgrades_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	upgrades_vbox.add_theme_constant_override("separation", 8)
	upg_scroll.add_child(upgrades_vbox)

func _refresh_camp_ui() -> void:
	lbl_chips_header.text = "💎 %d" % GameState.noah_chips
	lbl_stats_header.text = "轮回:%d  |  最高:%d波  |  狩猎赏金首:%d" % [
		GameState.lifetime_runs, GameState.best_wave, GameState.lifetime_bounties
	]

	_refresh_top_showcase_cards()
	_refresh_bottom_selection_grids()
	_refresh_meta_lab_columns()

	if title_screen.visible and get_viewport() and get_viewport().gui_get_focus_owner() == null and is_instance_valid(btn_start_run) and tab_loadout_view.visible:
		btn_start_run.call_deferred("grab_focus")

# --- 上方三联详情展示卡 (像土豆兄弟一样：大头像 + 进度条 + 简明绿字词条) ---
func _refresh_top_showcase_cards() -> void:
	for c in showcase_hunter_box.get_children():
		c.queue_free()
	for c in showcase_chassis_box.get_children():
		c.queue_free()
	for c in showcase_map_box.get_children():
		c.queue_free()

	# 1. 左卡：当前选中猎人详情
	var h: Dictionary = GameData.HUNTERS[chosen_hunter]
	var h_top := HBoxContainer.new()
	h_top.add_theme_constant_override("separation", 12)
	showcase_hunter_box.add_child(h_top)

	h_top.add_child(_make_tex_rect(GameData.get_hunter_tex(chosen_hunter), Vector2(72, 72)))

	var h_titles := VBoxContainer.new()
	h_titles.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	h_top.add_child(h_titles)
	h_titles.add_child(_make_outlined_label("🎖️ 出击猎人", 12, Color(0.85, 0.80, 0.65)))
	h_titles.add_child(_make_outlined_label(h["name"], 18, Color(1.0, 0.88, 0.30)))
	h_titles.add_child(_make_outlined_label(h["title"], 13, Color(0.45, 0.92, 1.0)))

	var h_desc_box := _make_box(Color(0.11, 0.11, 0.13), Color(0.32, 0.32, 0.38))
	h_desc_box.size_flags_vertical = Control.SIZE_EXPAND_FILL
	showcase_hunter_box.add_child(h_desc_box)

	var h_desc := _make_outlined_label(h["desc"], 13, Color(0.55, 1.0, 0.65))
	h_desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	h_desc_box.add_child(h_desc)

	# 2. 中卡：当前选中战车底盘详情 + 可视化属性进度条
	var ch: Dictionary = GameData.CHASSIS[chosen_chassis]
	var c_top := HBoxContainer.new()
	c_top.add_theme_constant_override("separation", 12)
	showcase_chassis_box.add_child(c_top)

	c_top.add_child(_make_tex_rect(GameData.get_chassis_tex(chosen_chassis), Vector2(98, 66)))

	var c_titles := VBoxContainer.new()
	c_titles.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	c_top.add_child(c_titles)
	c_titles.add_child(_make_outlined_label("🚜 战车底盘", 12, Color(0.85, 0.80, 0.65)))
	c_titles.add_child(_make_outlined_label(ch["name"], 17, Color(1.0, 0.55, 0.38)))

	# 槽位彩色徽章行
	var slot_badges: Array = []
	for s in ch["slots"]:
		slot_badges.append("🔴主炮" if s == "MAIN" else ("🟡副炮" if s == "SUB" else "🔵S-E"))
	var sl_lbl := _make_outlined_label("孔位: " + " ".join(slot_badges), 12, Color(0.95, 0.88, 0.45))
	c_titles.add_child(sl_lbl)

	# 装甲转化率条 & 机动评分条
	var sp_rate: float = float(ch.get("sp_per_ton", 20.0))
	var sp_bar_d: Dictionary = _create_bar(Vector2(0, 18), Color(0.22, 0.82, 0.40), 11, sp_rate, 32.0)
	sp_bar_d["label"].text = "🛡️ 装甲转化率: %.0f SP / 吨" % sp_rate
	showcase_chassis_box.add_child(sp_bar_d["container"])

	var wt_val: float = float(ch.get("base_weight", 6.0))
	var wt_bar_d: Dictionary = _create_bar(Vector2(0, 18), Color(0.88, 0.58, 0.20), 11, wt_val, 16.0)
	wt_bar_d["label"].text = "⚖️ 底盘自重: %.1f 吨  |  🚜 移速 %.0f" % [wt_val, float(ch.get("speed", 220.0))]
	showcase_chassis_box.add_child(wt_bar_d["container"])

	var c_desc := _make_outlined_label(ch["desc"], 12, Color(0.88, 0.90, 0.92))
	c_desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	c_desc.size_flags_vertical = Control.SIZE_EXPAND_FILL
	showcase_chassis_box.add_child(c_desc)

	# 3. 右卡：当前战区地图、关底赏金首、难度选择与【立即出击】主按钮
	var m: Dictionary = GameData.MAPS[chosen_map_idx]
	var d: Dictionary = GameData.DIFFICULTIES[chosen_diff_id]
	var fin_b: Dictionary = GameData.get_boss_by_id(m["final_boss_id"])
	var total_chip_mult: float = float(m["chip_mult"]) * float(d["chip_mult"])

	var m_top := HBoxContainer.new()
	m_top.add_theme_constant_override("separation", 10)
	showcase_map_box.add_child(m_top)

	m_top.add_child(_make_tex_rect(GameData.get_terrain_tex(String(m["id"])), Vector2(56, 52)))
	m_top.add_child(_make_tex_rect(GameData.get_boss_tex(String(m["final_boss_id"])), Vector2(68, 52)))

	var m_titles := VBoxContainer.new()
	m_titles.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	m_top.add_child(m_titles)
	m_titles.add_child(_make_outlined_label(m["name"], 15, Color(0.45, 0.98, 0.65)))
	m_titles.add_child(_make_outlined_label("🎯 关底统帅: %s  |  💎收益 ×%.2f" % [fin_b["name"].split(" ")[0], total_chip_mult], 12, Color(1.0, 0.85, 0.30)))

	# 简单 / 困难 / 地狱 三档难度按钮行
	var diff_row := HBoxContainer.new()
	diff_row.add_theme_constant_override("separation", 6)
	showcase_map_box.add_child(diff_row)

	for d_id in ["easy", "normal", "hell"]:
		var d_def: Dictionary = GameData.DIFFICULTIES[d_id]
		var is_sel_d: bool = (chosen_diff_id == d_id)
		var d_btn := Button.new()
		d_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		d_btn.custom_minimum_size = Vector2(0, 32)
		d_btn.add_theme_font_size_override("font_size", 13)
		d_btn.text = ("👉 " if is_sel_d else "") + d_def["name"].split(" ")[0] + " " + d_def["name"].split(" ")[1]
		if is_sel_d:
			var ds := StyleBoxFlat.new()
			ds.bg_color = Color(0.24, 0.24, 0.30)
			ds.border_color = d_def["color"]
			ds.set_border_width_all(2)
			ds.set_corner_radius_all(6)
			d_btn.add_theme_stylebox_override("normal", ds)
		d_btn.pressed.connect(func():
			chosen_diff_id = d_id
			SoundManager.play("coin", 0.1, 0.0)
			_refresh_camp_ui()
		)
		diff_row.add_child(d_btn)

	var d_desc_lbl := _make_outlined_label(d["desc"], 11, d["color"])
	d_desc_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	d_desc_lbl.size_flags_vertical = Control.SIZE_EXPAND_FILL
	showcase_map_box.add_child(d_desc_lbl)

	btn_start_run = Button.new()
	btn_start_run.custom_minimum_size = Vector2(0, 44)
	btn_start_run.text = "🔥 发动战车引擎 · 立即出击 [Start] 🔥"
	btn_start_run.add_theme_font_size_override("font_size", 17)
	var st_btn := StyleBoxFlat.new()
	st_btn.bg_color = Color(0.75, 0.25, 0.15)
	st_btn.border_color = Color(1.0, 0.85, 0.25)
	st_btn.set_border_width_all(2)
	st_btn.set_corner_radius_all(8)
	btn_start_run.add_theme_stylebox_override("normal", st_btn)
	var st_hover := st_btn.duplicate()
	st_hover.bg_color = Color(0.88, 0.32, 0.18)
	btn_start_run.add_theme_stylebox_override("hover", st_hover)
	btn_start_run.add_theme_stylebox_override("focus", st_hover)
	btn_start_run.pressed.connect(_on_start_run_pressed)
	showcase_map_box.add_child(btn_start_run)

# --- 下方三组土豆兄弟式图标卡片网格 ---
func _refresh_bottom_selection_grids() -> void:
	for c in hunters_grid.get_children():
		c.queue_free()
	for c in chassis_grid.get_children():
		c.queue_free()
	for c in maps_vbox.get_children():
		c.queue_free()

	# 1. 猎人 3x2 图标卡片网格
	for h_id in GameData.HUNTERS.keys():
		var h_def: Dictionary = GameData.HUNTERS[h_id]
		var unlocked: bool = GameState.is_hunter_unlocked(String(h_id))
		var is_sel: bool = (chosen_hunter == String(h_id))
		var short_name: String = String(h_def["name"]).split(" ")[0]

		var border_col: Color = Color(1.0, 0.88, 0.22) if is_sel else (Color(0.38, 0.42, 0.48) if unlocked else Color(0.25, 0.25, 0.28))
		var bg_col: Color = Color(0.24, 0.20, 0.14) if is_sel else Color(0.16, 0.16, 0.19)
		var cell := _make_box(bg_col, border_col)
		cell.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		cell.size_flags_vertical = Control.SIZE_EXPAND_FILL
		hunters_grid.add_child(cell)

		var cv := VBoxContainer.new()
		cv.alignment = BoxContainer.ALIGNMENT_CENTER
		cv.add_theme_constant_override("separation", 4)
		cell.add_child(cv)

		var icon_center := CenterContainer.new()
		cv.add_child(icon_center)
		icon_center.add_child(_make_tex_rect(GameData.get_hunter_tex(String(h_id)), Vector2(54, 54), not unlocked))

		var btn := Button.new()
		btn.custom_minimum_size = Vector2(0, 30)
		btn.add_theme_font_size_override("font_size", 12)
		btn.text = ("👉" if is_sel else "") + short_name if unlocked else "🔒%s(%d💎)" % [short_name.substr(0, 4), int(h_def["unlock_cost"])]
		btn.pressed.connect(func():
			if unlocked:
				chosen_hunter = String(h_id)
				SoundManager.play("coin", 0.08, 0.0)
			else:
				if GameState.unlock_hunter(String(h_id)):
					chosen_hunter = String(h_id)
					SoundManager.play("upgrade", 0.04, 2.0)
					lbl_camp_toast.text = "🎉 成功招募新猎人：【%s】！" % h_def["name"]
				else:
					lbl_camp_toast.text = "❌ 诺亚晶片不足！解锁【%s】需要 %d 💎。" % [h_def["name"], int(h_def["unlock_cost"])]
			_refresh_camp_ui()
		)
		cv.add_child(btn)

	# 2. 战车底盘 4x2 图标卡片网格
	for c_id in GameData.CHASSIS.keys():
		var c_def: Dictionary = GameData.CHASSIS[c_id]
		var unlocked: bool = GameState.is_chassis_unlocked(String(c_id))
		var is_sel: bool = (chosen_chassis == String(c_id))
		var short_name: String = String(c_def["name"]).split(" ")[0]

		var border_col: Color = Color(1.0, 0.88, 0.22) if is_sel else (Color(0.42, 0.38, 0.45) if unlocked else Color(0.25, 0.25, 0.28))
		var bg_col: Color = Color(0.24, 0.17, 0.15) if is_sel else Color(0.16, 0.16, 0.19)
		var cell := _make_box(bg_col, border_col)
		cell.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		cell.size_flags_vertical = Control.SIZE_EXPAND_FILL
		chassis_grid.add_child(cell)

		var cv := VBoxContainer.new()
		cv.alignment = BoxContainer.ALIGNMENT_CENTER
		cv.add_theme_constant_override("separation", 4)
		cell.add_child(cv)

		var icon_center := CenterContainer.new()
		cv.add_child(icon_center)
		icon_center.add_child(_make_tex_rect(GameData.get_chassis_tex(String(c_id)), Vector2(68, 46), not unlocked))

		var btn := Button.new()
		btn.custom_minimum_size = Vector2(0, 30)
		btn.add_theme_font_size_override("font_size", 11)
		btn.text = ("👉" if is_sel else "") + short_name if unlocked else "🔒%d💎" % int(c_def["unlock_cost"])
		btn.pressed.connect(func():
			if unlocked:
				chosen_chassis = String(c_id)
				SoundManager.play("coin", 0.08, 0.0)
			else:
				if GameState.unlock_chassis(String(c_id)):
					chosen_chassis = String(c_id)
					SoundManager.play("upgrade", 0.04, 2.0)
					lbl_camp_toast.text = "🎉 成功修复战车底盘：【%s】！" % c_def["name"]
				else:
					lbl_camp_toast.text = "❌ 诺亚晶片不足！修复【%s】需要 %d 💎。" % [c_def["name"], int(c_def["unlock_cost"])]
			_refresh_camp_ui()
		)
		cv.add_child(btn)

	# 3. 战区地图章节横卡列表
	for i in range(GameData.MAPS.size()):
		var m_def: Dictionary = GameData.MAPS[i]
		var is_unlocked: bool = (i < GameState.unlocked_map_count)
		var is_sel: bool = (chosen_map_idx == i)
		var cleared_list: Array = GameState.map_cleared_difficulties.get(m_def["id"], [])
		var badges: Array = []
		if "easy" in cleared_list:
			badges.append("🟢")
		if "normal" in cleared_list:
			badges.append("🟡")
		if "hell" in cleared_list:
			badges.append("🔴")
		var badge_str: String = (" " + "".join(badges)) if not badges.is_empty() else ""

		var fin_b: Dictionary = GameData.get_boss_by_id(m_def["final_boss_id"])
		var m_row := HBoxContainer.new()
		m_row.add_theme_constant_override("separation", 6)
		maps_vbox.add_child(m_row)

		m_row.add_child(_make_tex_rect(GameData.get_terrain_tex(String(m_def["id"])), Vector2(44, 42), not is_unlocked))
		m_row.add_child(_make_tex_rect(GameData.get_boss_tex(String(m_def["final_boss_id"])), Vector2(52, 42), not is_unlocked))

		var btn := Button.new()
		btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		btn.custom_minimum_size = Vector2(0, 42)
		btn.add_theme_font_size_override("font_size", 12)
		if is_unlocked:
			btn.text = "%s%s%s  (Boss:%s | 💎×%.1f)" % [
				"👉 " if is_sel else "✅ ",
				m_def["name"], badge_str, fin_b["name"].split(" ")[0], float(m_def["chip_mult"])
			]
		else:
			btn.text = "🔒 %s (通关上一章解锁)" % m_def["name"]

		btn.pressed.connect(func():
			if is_unlocked:
				chosen_map_idx = i
				SoundManager.play("coin", 0.08, 0.0)
				_refresh_camp_ui()
			else:
				lbl_camp_toast.text = "🔒 请先击败【%s】关底统帅解锁该战区！" % GameData.MAPS[i - 1]["name"]
		)
		m_row.add_child(btn)

func _refresh_meta_lab_columns() -> void:
	for c in features_vbox.get_children():
		c.queue_free()
	features_vbox.add_child(_make_outlined_label("🏗️ 废铁镇基建工程 (永久解锁局内设施与特权)", 17, Color(0.45, 0.92, 1.0)))

	for f_def in GameData.META_FEATURES:
		var f_id: String = f_def["id"]
		var unlocked: bool = GameState.is_feature_unlocked(f_id)
		var card := _make_box(Color(0.18, 0.19, 0.22), Color(0.35, 0.90, 0.55) if unlocked else Color(0.48, 0.48, 0.54))
		features_vbox.add_child(card)

		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 10)
		card.add_child(row)

		var lbl := _make_outlined_label("%s\n%s" % [f_def["name"], f_def["desc"]], 12, Color(0.65, 1.0, 0.75) if unlocked else Color(0.92, 0.92, 0.92))
		lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		row.add_child(lbl)

		var btn := Button.new()
		btn.custom_minimum_size = Vector2(115, 42)
		btn.disabled = unlocked
		btn.text = "✅ 已激活" if unlocked else "解锁 💎%d" % int(f_def["cost"])
		btn.pressed.connect(func():
			if GameState.unlock_feature(f_id):
				SoundManager.play("upgrade", 0.04, 2.0)
				lbl_camp_toast.text = "🎉 已永久解锁【%s】！" % f_def["name"]
				_refresh_camp_ui()
			else:
				lbl_camp_toast.text = "❌ 诺亚晶片不足，需要 %d 💎！" % int(f_def["cost"])
		)
		row.add_child(btn)

	# 右栏：永久数值科技树 (带可视化等级进度条 ProgressBar!)
	for c in upgrades_vbox.get_children():
		c.queue_free()
	upgrades_vbox.add_child(_make_outlined_label("🧬 明奇与多拉姆改造所 (永久属性科技树)", 17, Color(0.90, 0.60, 1.0)))

	for u_def in GameData.META_UPGRADES:
		var u_id: String = u_def["id"]
		var lv: int = GameState.get_meta_level(u_id)
		var max_lv: int = int(u_def["max_lv"])
		var is_max: bool = (lv >= max_lv)
		var cost: int = GameState.get_meta_upgrade_cost(u_def)

		var card := _make_box(Color(0.19, 0.17, 0.22), Color(0.85, 0.65, 1.0) if lv > 0 else Color(0.45, 0.42, 0.50))
		upgrades_vbox.add_child(card)

		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 10)
		card.add_child(row)

		var info_v := VBoxContainer.new()
		info_v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		info_v.add_theme_constant_override("separation", 4)
		row.add_child(info_v)

		var title_row := HBoxContainer.new()
		info_v.add_child(title_row)
		var nl := _make_outlined_label(u_def["name"], 14, Color(0.98, 0.90, 1.0))
		nl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		title_row.add_child(nl)

		var bar_d: Dictionary = _create_bar(Vector2(150, 16), Color(0.75, 0.42, 0.98), 11, float(lv), float(max_lv))
		bar_d["label"].text = "Lv. %d / %d" % [lv, max_lv]
		title_row.add_child(bar_d["container"])

		var dl := _make_outlined_label(u_def["desc_per_lv"], 12, Color(0.82, 0.85, 0.90))
		dl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		info_v.add_child(dl)

		var btn := Button.new()
		btn.custom_minimum_size = Vector2(115, 42)
		btn.disabled = is_max
		btn.text = "🌟 MAX" if is_max else "强化 💎%d" % cost
		btn.pressed.connect(func():
			if GameState.upgrade_meta_stat(u_id):
				SoundManager.play("upgrade", 0.06, 1.5)
				lbl_camp_toast.text = "⚡ 【%s】已强化至 Lv.%d！" % [u_def["name"], lv + 1]
				_refresh_camp_ui()
			else:
				lbl_camp_toast.text = "❌ 诺亚晶片不足，需要 %d 💎！" % cost
		)
		row.add_child(btn)

func _build_mince_modal() -> void:
	mince_modal = Control.new()
	mince_modal.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mince_modal.visible = false
	ui_layer.add_child(mince_modal)

	var overlay := ColorRect.new()
	overlay.color = Color(0.04, 0.04, 0.06, 0.90)
	overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mince_modal.add_child(overlay)

	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mince_modal.add_child(center)

	var box := _make_box(Color(0.14, 0.13, 0.18), Color(0.45, 0.92, 1.0))
	box.custom_minimum_size = Vector2(780, 440)
	center.add_child(box)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 12)
	box.add_child(vbox)

	var title := _make_outlined_label("⚡ 明奇博士研究所 — 轮回战绩与晶片结算 ⚡", 22, Color(0.45, 0.95, 1.0))
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(title)

	var mid_hbox := HBoxContainer.new()
	mid_hbox.size_flags_vertical = Control.SIZE_EXPAND_FILL
	mid_hbox.add_theme_constant_override("separation", 16)
	vbox.add_child(mid_hbox)

	mid_hbox.add_child(_make_tex_rect(GameData.get_tex("npc_dr_mince"), Vector2(180, 150)))

	var stats_card := _make_box(Color(0.11, 0.11, 0.14), Color(0.35, 0.55, 0.75))
	stats_card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	stats_card.size_flags_vertical = Control.SIZE_EXPAND_FILL
	mid_hbox.add_child(stats_card)

	mince_stats_vbox = VBoxContainer.new()
	mince_stats_vbox.add_theme_constant_override("separation", 6)
	stats_card.add_child(mince_stats_vbox)

	btn_mince_continue = Button.new()
	btn_mince_continue.custom_minimum_size = Vector2(0, 44)
	btn_mince_continue.add_theme_font_size_override("font_size", 15)
	btn_mince_continue.pressed.connect(_on_mince_revive_to_garage)
	vbox.add_child(btn_mince_continue)

	var bot_row := HBoxContainer.new()
	bot_row.add_theme_constant_override("separation", 12)
	vbox.add_child(bot_row)

	btn_mince_settle_to_meta = Button.new()
	btn_mince_settle_to_meta.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	btn_mince_settle_to_meta.custom_minimum_size = Vector2(0, 46)
	btn_mince_settle_to_meta.text = "🧬 前往【局外科技树】强化属性"
	btn_mince_settle_to_meta.add_theme_font_size_override("font_size", 16)
	btn_mince_settle_to_meta.pressed.connect(func(): _show_title_screen(true))
	bot_row.add_child(btn_mince_settle_to_meta)

	var btn_restart := Button.new()
	btn_restart.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	btn_restart.custom_minimum_size = Vector2(0, 46)
	btn_restart.text = "🚜 返回【出击整备大厅】"
	btn_restart.add_theme_font_size_override("font_size", 16)
	btn_restart.pressed.connect(func(): _show_title_screen(false))
	bot_row.add_child(btn_restart)

func _show_title_screen(open_meta_tab: bool = false) -> void:
	battlefield.visible = false
	battlefield.hud_layer.visible = false
	garage_ui.visible = false
	mince_modal.visible = false
	title_screen.visible = true
	tab_loadout_view.visible = not open_meta_tab
	tab_meta_view.visible = open_meta_tab
	SoundManager.play_bgm("bgm_camp_garage")
	_refresh_camp_ui()
	if is_instance_valid(btn_start_run) and tab_loadout_view.visible:
		btn_start_run.call_deferred("grab_focus")

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
	if not is_instance_valid(title_screen) or not title_screen.visible:
		return
	if event.is_action_pressed("gamepad_start") and tab_loadout_view.visible:
		get_viewport().set_input_as_handled()
		_on_start_run_pressed()
	elif event.is_action_pressed("gamepad_select"):
		get_viewport().set_input_as_handled()
		tab_loadout_view.visible = not tab_loadout_view.visible
		tab_meta_view.visible = not tab_loadout_view.visible
		SoundManager.play("coin", 0.1, -3.0)
		_refresh_camp_ui()

func _on_start_run_pressed() -> void:
	SoundManager.play("cannon_heavy", 0.05, 0.0)
	GameState.start_new_run(chosen_hunter, chosen_chassis, chosen_map_idx, chosen_diff_id)
	title_screen.visible = false
	garage_ui.visible = false
	mince_modal.visible = false
	battlefield.visible = true
	battlefield.hud_layer.visible = true
	battlefield.start_wave()

func _on_wave_completed() -> void:
	SoundManager.play("upgrade", 0.05, 1.0)
	SoundManager.play_bgm("bgm_camp_garage")
	battlefield.visible = false
	battlefield.hud_layer.visible = false
	garage_ui.open_garage()

func _on_start_next_wave() -> void:
	GameState.current_wave += 1
	battlefield.visible = true
	battlefield.hud_layer.visible = true
	battlefield.start_wave()

func _populate_mince_rows(is_victory: bool, rewards: Dictionary) -> void:
	for c in mince_stats_vbox.get_children():
		c.queue_free()

	var m_def: Dictionary = GameState.get_current_map_def()
	var d_def: Dictionary = GameState.get_current_difficulty_def()

	if is_victory:
		var v_lbl := _make_outlined_label("🏆 战区肃清！已征服 %s [%s]" % [m_def["name"], d_def["name"].split(" ")[0]], 16, Color(1.0, 0.88, 0.25))
		mince_stats_vbox.add_child(v_lbl)
		if rewards.get("unlocked_next_map", "") != "":
			var u_lbl := _make_outlined_label("🔓 已解锁下一章新地图：【%s】！" % rewards["unlocked_next_map"], 14, Color(0.40, 1.0, 0.55))
			mince_stats_vbox.add_child(u_lbl)
			chosen_map_idx = min(GameData.MAPS.size() - 1, chosen_map_idx + 1)
	else:
		var d_lbl := _make_outlined_label("⚡ “伊戈尔，快把高压电极接上！哔——啪！！”", 15, Color(0.55, 0.92, 1.0))
		mince_stats_vbox.add_child(d_lbl)

	_add_settle_row("🌊 推进波次 (第 %d 波)" % GameState.current_wave, "+%d 💎" % int(rewards["wave_chips"]), Color(0.45, 0.95, 1.0))
	_add_settle_row("💥 击毁机械兽 (%d 台)" % GameState.total_kills, "+%d 💎" % int(rewards["kill_chips"]), Color(0.45, 0.95, 1.0))
	_add_settle_row("🎯 狩猎赏金首 (%d 名)" % GameState.bounties_hunted, "+%d 💎" % int(rewards["boss_chips"]), Color(1.0, 0.85, 0.30))
	_add_settle_row("💰 剩余赏金折算 (%d G)" % GameState.gold, "+%d 💎" % int(rewards["gold_chips"]), Color(0.95, 0.88, 0.45))
	if is_victory:
		_add_settle_row("🏆 统帅首通大奖", "+%d 💎" % int(rewards.get("win_chips", 0)), Color(1.0, 0.55, 0.25))

	mince_stats_vbox.add_child(HSeparator.new())
	_add_settle_row("🎉 本局合计获得 (总持有 %d 💎)" % GameState.noah_chips, "+%d 💎" % int(rewards["total"]), Color(0.40, 1.0, 0.55))

func _add_settle_row(k_str: String, v_str: String, v_col: Color) -> void:
	var r := HBoxContainer.new()
	mince_stats_vbox.add_child(r)
	var kl := _make_outlined_label(k_str, 14, Color(0.88, 0.88, 0.92))
	kl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	r.add_child(kl)
	var vl := _make_outlined_label(v_str, 15, v_col)
	r.add_child(vl)

func _on_player_defeated() -> void:
	SoundManager.play("mince_revive", 0.02, 2.0)
	SoundManager.play_bgm("bgm_dr_mince")
	battlefield.visible = false
	battlefield.hud_layer.visible = false
	mince_modal.visible = true

	var rewards: Dictionary = GameState.settle_run_rewards(false)
	_populate_mince_rows(false, rewards)

	if GameState.mince_free_revive_available:
		btn_mince_continue.visible = true
		btn_mince_continue.text = "⚡ 免费电击续命！(获赠 +120G 改装补贴，退回多拉姆车库重整旗鼓)"
		btn_mince_continue.call_deferred("grab_focus")
	else:
		btn_mince_continue.visible = false
		btn_mince_settle_to_meta.call_deferred("grab_focus")

func _on_mince_revive_to_garage() -> void:
	GameState.mince_free_revive_available = false
	GameState.run_already_settled = false
	GameState.gold += 120
	GameState.current_wave = max(1, GameState.current_wave - 1)
	SoundManager.play("mince_revive", 0.05, 1.0)
	SoundManager.play_bgm("bgm_camp_garage")
	mince_modal.visible = false
	garage_ui.open_garage()

func _on_game_victory() -> void:
	SoundManager.play("mince_revive", 0.02, 3.0)
	SoundManager.play_bgm("bgm_dr_mince")
	battlefield.visible = false
	battlefield.hud_layer.visible = false
	mince_modal.visible = true
	btn_mince_continue.visible = false
	btn_mince_settle_to_meta.call_deferred("grab_focus")

	var rewards: Dictionary = GameState.settle_run_rewards(true)
	_populate_mince_rows(true, rewards)

# --- UI 辅助构建函数 ---
func _create_bar(min_sz: Vector2, fill_col: Color, font_sz: int, val: float, max_val: float) -> Dictionary:
	var container := Control.new()
	container.custom_minimum_size = min_sz

	var bar := ProgressBar.new()
	bar.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	bar.show_percentage = false
	bar.max_value = maxf(1.0, max_val)
	bar.value = clampf(val, 0.0, bar.max_value)

	var bg_style := StyleBoxFlat.new()
	bg_style.bg_color = Color(0.08, 0.08, 0.10, 0.95)
	bg_style.border_color = Color(0.02, 0.02, 0.03, 1.0)
	bg_style.set_border_width_all(2)
	bg_style.set_corner_radius_all(4)

	var fill_style := StyleBoxFlat.new()
	fill_style.bg_color = fill_col
	fill_style.border_color = Color(0.02, 0.02, 0.03, 1.0)
	fill_style.set_border_width_all(2)
	fill_style.set_corner_radius_all(4)

	bar.add_theme_stylebox_override("background", bg_style)
	bar.add_theme_stylebox_override("fill", fill_style)
	container.add_child(bar)

	var lbl := _make_outlined_label("", font_sz, Color.WHITE)
	lbl.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	container.add_child(lbl)

	return {"container": container, "bar": bar, "label": lbl}

func _make_outlined_label(txt: String, f_size: int, col: Color) -> Label:
	var l := Label.new()
	l.text = txt
	l.add_theme_font_size_override("font_size", f_size)
	l.add_theme_color_override("font_color", col)
	l.add_theme_color_override("font_outline_color", Color(0.0, 0.0, 0.0, 0.95))
	l.add_theme_constant_override("outline_size", 3)
	return l

func _make_box(bg_col: Color, border_col: Color) -> PanelContainer:
	var p := PanelContainer.new()
	var s := StyleBoxFlat.new()
	s.bg_color = bg_col
	s.border_color = border_col
	s.set_border_width_all(2)
	s.set_corner_radius_all(8)
	s.content_margin_left = 10
	s.content_margin_right = 10
	s.content_margin_top = 8
	s.content_margin_bottom = 8
	p.add_theme_stylebox_override("panel", s)
	return p

func _make_tex_rect(tex: Texture2D, min_sz: Vector2, darkened: bool = false) -> TextureRect:
	var tr := TextureRect.new()
	tr.texture = tex
	tr.custom_minimum_size = min_sz
	tr.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	tr.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	if darkened:
		tr.modulate = Color(0.35, 0.35, 0.38, 0.85)
	return tr
