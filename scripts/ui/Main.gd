extends Node
## 《重装废土：赏金狂飙》 - 顶层场景与【局外永久养成/轮回解锁系统】控制器
## 管理：
## 1. 【废铁镇大本营】：猎人招募解锁、埋藏战车底盘解锁、废铁镇新功能基建、明奇研究所永久数值科技树
## 2. 【废土战场】 ⇄ 【多拉姆车库】
## 3. 【明奇博士轮回结算】：将每局波次/击杀/赏金首转化为永久货币【诺亚晶片 💎】

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

# --- 大本营 UI 引用 ---
var lbl_meta_header: Label
var lbl_camp_toast: Label
var tab_loadout_view: Control
var tab_meta_view: Control
var hunters_vbox: VBoxContainer
var chassis_vbox: VBoxContainer
var maps_vbox: VBoxContainer
var diff_hbox: HBoxContainer
var lbl_diff_desc: Label
var features_vbox: VBoxContainer
var upgrades_vbox: VBoxContainer
var lbl_selection_preview: Label
var preview_hunter_rect: TextureRect
var preview_chassis_rect: TextureRect
var preview_boss_rect: TextureRect
var btn_start_run: Button

# --- 明奇博士结算弹窗引用 ---
var lbl_mince_desc: Label
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
	bg.color = Color(0.09, 0.08, 0.07, 1.0)
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	title_screen.add_child(bg)

	var vbox := VBoxContainer.new()
	vbox.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT, Control.PRESET_MODE_MINSIZE, 20)
	vbox.add_theme_constant_override("separation", 10)
	title_screen.add_child(vbox)

	# 1. 顶部主标题与局外永久货币【诺亚晶片 💎】状态栏
	var top_panel := _make_box(Color(0.15, 0.13, 0.11), Color(0.95, 0.55, 0.20))
	vbox.add_child(top_panel)

	var top_vbox := VBoxContainer.new()
	top_vbox.add_theme_constant_override("separation", 6)
	top_panel.add_child(top_vbox)

	var header_row := HBoxContainer.new()
	top_vbox.add_child(header_row)

	var title_lbl := Label.new()
	title_lbl.text = "🔥 《重装废土：赏金狂飙》 METAL WASTELAND"
	title_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title_lbl.add_theme_font_size_override("font_size", 24)
	title_lbl.add_theme_color_override("font_color", Color(1.0, 0.45, 0.22))
	header_row.add_child(title_lbl)

	lbl_meta_header = Label.new()
	lbl_meta_header.add_theme_font_size_override("font_size", 18)
	lbl_meta_header.add_theme_color_override("font_color", Color(0.40, 0.95, 1.0))
	header_row.add_child(lbl_meta_header)

	# 导航切换栏 (出击整备 vs 局外养成科技树 vs 调试福利)
	var nav_row := HBoxContainer.new()
	nav_row.add_theme_constant_override("separation", 12)
	top_vbox.add_child(nav_row)

	var btn_tab_loadout := Button.new()
	btn_tab_loadout.text = "🚜 【出击整备：解锁/选择猎人与战车底盘】"
	btn_tab_loadout.custom_minimum_size = Vector2(340, 38)
	btn_tab_loadout.pressed.connect(func():
		tab_loadout_view.visible = true
		tab_meta_view.visible = false
		SoundManager.play("coin", 0.1, -3.0)
		_refresh_camp_ui()
	)
	nav_row.add_child(btn_tab_loadout)

	var btn_tab_meta := Button.new()
	btn_tab_meta.text = "🧬 【局外养成：解锁新功能 & 永久数值强化科技树】"
	btn_tab_meta.custom_minimum_size = Vector2(380, 38)
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

	var btn_debug_chips := Button.new()
	btn_debug_chips.text = "🎁 测试福利: +500💎 & 解锁全图"
	btn_debug_chips.pressed.connect(func():
		GameState.noah_chips += 500
		GameState.unlocked_map_count = GameData.MAPS.size()
		GameState.save_meta_data()
		SoundManager.play("upgrade", 0.05, 1.0)
		lbl_camp_toast.text = "🎁 已发放 +500 💎 诺亚晶片并开放全部 5 张战区地图！快去体验不同地图的专属赏金首与地狱难度吧！"
		_refresh_camp_ui()
	)
	nav_row.add_child(btn_debug_chips)

	var btn_reset_save := Button.new()
	btn_reset_save.text = "🗑️ 重置存档"
	btn_reset_save.pressed.connect(func():
		GameState.reset_meta_save()
		chosen_hunter = "bounty_hunter"
		chosen_chassis = "buggy"
		chosen_map_idx = 0
		chosen_diff_id = "normal"
		lbl_camp_toast.text = "已重置局外存档为初始状态（仅开放第1章地图）。"
		_refresh_camp_ui()
	)
	nav_row.add_child(btn_reset_save)

	lbl_camp_toast = Label.new()
	lbl_camp_toast.text = "💡 每次轮回结算都将根据波次、击杀与赏金首获得【💎诺亚晶片】，用于永久解锁新猎人、新底盘、车库新功能与基础数值！"
	lbl_camp_toast.add_theme_font_size_override("font_size", 14)
	lbl_camp_toast.add_theme_color_override("font_color", Color(1.0, 0.88, 0.35))
	vbox.add_child(lbl_camp_toast)

	# ========================================================================
	# 视图 A：出击整备 & 解锁新人物/新战车底盘
	# ========================================================================
	tab_loadout_view = VBoxContainer.new()
	tab_loadout_view.size_flags_vertical = Control.SIZE_EXPAND_FILL
	tab_loadout_view.add_theme_constant_override("separation", 10)
	vbox.add_child(tab_loadout_view)

	var hbox_loadout := HBoxContainer.new()
	hbox_loadout.size_flags_vertical = Control.SIZE_EXPAND_FILL
	hbox_loadout.add_theme_constant_override("separation", 16)
	tab_loadout_view.add_child(hbox_loadout)

	# 左栏：6大猎人选择与招募解锁
	var h_panel := _make_box(Color(0.14, 0.13, 0.11), Color(0.90, 0.55, 0.22))
	h_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hbox_loadout.add_child(h_panel)

	var h_scroll := ScrollContainer.new()
	h_scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	h_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	h_panel.add_child(h_scroll)

	hunters_vbox = VBoxContainer.new()
	hunters_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hunters_vbox.add_theme_constant_override("separation", 6)
	h_scroll.add_child(hunters_vbox)

	# 右栏(第2栏)：8大底盘选择与挖掘解锁
	var c_panel := _make_box(Color(0.14, 0.13, 0.12), Color(0.85, 0.28, 0.22))
	c_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hbox_loadout.add_child(c_panel)

	var c_scroll := ScrollContainer.new()
	c_scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	c_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	c_panel.add_child(c_scroll)

	chassis_vbox = VBoxContainer.new()
	chassis_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	chassis_vbox.add_theme_constant_override("separation", 6)
	c_scroll.add_child(chassis_vbox)

	# 第3栏：5大废土战区地图递进选择 & 3档难度切换
	var m_panel := _make_box(Color(0.13, 0.15, 0.14), Color(0.38, 0.88, 0.55))
	m_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hbox_loadout.add_child(m_panel)

	var m_outer_vbox := VBoxContainer.new()
	m_outer_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	m_outer_vbox.size_flags_vertical = Control.SIZE_EXPAND_FILL
	m_outer_vbox.add_theme_constant_override("separation", 8)
	m_panel.add_child(m_outer_vbox)

	var m_scroll := ScrollContainer.new()
	m_scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	m_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	m_outer_vbox.add_child(m_scroll)

	maps_vbox = VBoxContainer.new()
	maps_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	maps_vbox.add_theme_constant_override("separation", 6)
	m_scroll.add_child(maps_vbox)

	var diff_title := Label.new()
	diff_title.text = "⚔️ 第四步：选择战区难度 (简单 / 困难 / 地狱)"
	diff_title.add_theme_font_size_override("font_size", 15)
	diff_title.add_theme_color_override("font_color", Color(1.0, 0.85, 0.30))
	m_outer_vbox.add_child(diff_title)

	diff_hbox = HBoxContainer.new()
	diff_hbox.add_theme_constant_override("separation", 8)
	m_outer_vbox.add_child(diff_hbox)

	lbl_diff_desc = Label.new()
	lbl_diff_desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	lbl_diff_desc.add_theme_font_size_override("font_size", 12)
	lbl_diff_desc.add_theme_color_override("font_color", Color(0.88, 0.92, 0.85))
	m_outer_vbox.add_child(lbl_diff_desc)

	# 底部预览面版与出击按钮 (含猎人立绘 + 战车俯视图 + 关底赏金首立绘展示)
	var preview_panel := _make_box(Color(0.18, 0.15, 0.12), Color(1.0, 0.82, 0.25))
	tab_loadout_view.add_child(preview_panel)

	var preview_hbox := HBoxContainer.new()
	preview_hbox.add_theme_constant_override("separation", 14)
	preview_panel.add_child(preview_hbox)

	preview_hunter_rect = _make_tex_rect(null, Vector2(64, 64))
	preview_hbox.add_child(preview_hunter_rect)

	preview_chassis_rect = _make_tex_rect(null, Vector2(92, 64))
	preview_hbox.add_child(preview_chassis_rect)

	lbl_selection_preview = Label.new()
	lbl_selection_preview.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	lbl_selection_preview.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	lbl_selection_preview.add_theme_font_size_override("font_size", 14)
	lbl_selection_preview.add_theme_color_override("font_color", Color(0.95, 0.92, 0.82))
	preview_hbox.add_child(lbl_selection_preview)

	preview_boss_rect = _make_tex_rect(null, Vector2(88, 64))
	preview_hbox.add_child(preview_boss_rect)

	btn_start_run = Button.new()
	btn_start_run.custom_minimum_size = Vector2(0, 52)
	btn_start_run.text = "🔥 [Start] 发动战车引擎 —— 驶入废土荒漠 (开始新一轮狩猎) 🔥"
	btn_start_run.add_theme_font_size_override("font_size", 22)
	btn_start_run.pressed.connect(_on_start_run_pressed)
	tab_loadout_view.add_child(btn_start_run)

	# ========================================================================
	# 视图 B：局外永久养成所 (废铁镇新功能解锁 & 明奇永久数值科技树)
	# ========================================================================
	tab_meta_view = HBoxContainer.new()
	tab_meta_view.size_flags_vertical = Control.SIZE_EXPAND_FILL
	tab_meta_view.add_theme_constant_override("separation", 16)
	tab_meta_view.visible = false
	vbox.add_child(tab_meta_view)

	# 左栏：废铁镇基建工程 (解锁新功能与局内设施)
	var feat_panel := _make_box(Color(0.14, 0.14, 0.16), Color(0.35, 0.85, 1.0))
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

	# 右栏：明奇与多拉姆改造所 (永久数值强化科技树)
	var upg_panel := _make_box(Color(0.15, 0.13, 0.16), Color(0.85, 0.50, 1.0))
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
	lbl_meta_header.text = "💎 诺亚晶片: %d   |   轮回: %d次   |   最高波次: 第%d波   |   累计狩猎赏金首: %d名" % [
		GameState.noah_chips, GameState.lifetime_runs, GameState.best_wave, GameState.lifetime_bounties
	]

	# 1. 刷新猎人招募/选择列表
	for c in hunters_vbox.get_children():
		c.queue_free()
	var h_title := Label.new()
	h_title.text = "🎖️ 第一步：选择或解锁猎人职业 (点击未解锁角色可直接消费 💎 招募)"
	h_title.add_theme_font_size_override("font_size", 16)
	h_title.add_theme_color_override("font_color", Color(1.0, 0.85, 0.30))
	hunters_vbox.add_child(h_title)

	for h_id in GameData.HUNTERS.keys():
		var h_def: Dictionary = GameData.HUNTERS[h_id]
		var unlocked: bool = GameState.is_hunter_unlocked(String(h_id))
		var is_sel: bool = (chosen_hunter == String(h_id))

		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 8)
		hunters_vbox.add_child(row)

		var h_icon := _make_tex_rect(GameData.get_hunter_tex(String(h_id)), Vector2(52, 52), not unlocked)
		row.add_child(h_icon)

		var btn := Button.new()
		btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		btn.custom_minimum_size = Vector2(0, 52)
		if unlocked:
			var prefix: String = "👉 【当前出击】 " if is_sel else "✅ "
			btn.text = "%s%s — %s" % [prefix, h_def["name"], h_def["title"]]
		else:
			btn.text = "🔒 【未招募】%s — %s  (点击花费 %d 💎 解锁)" % [h_def["name"], h_def["title"], int(h_def["unlock_cost"])]

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
		row.add_child(btn)

	# 2. 刷新战车底盘选择/挖掘列表
	for c in chassis_vbox.get_children():
		c.queue_free()
	var c_title := Label.new()
	c_title.text = "🚜 第二步：选择或解锁战车底盘 (点击未解锁底盘可直接消费 💎 修复)"
	c_title.add_theme_font_size_override("font_size", 16)
	c_title.add_theme_color_override("font_color", Color(1.0, 0.45, 0.35))
	chassis_vbox.add_child(c_title)

	for c_id in GameData.CHASSIS.keys():
		var c_def: Dictionary = GameData.CHASSIS[c_id]
		var unlocked: bool = GameState.is_chassis_unlocked(String(c_id))
		var is_sel: bool = (chosen_chassis == String(c_id))

		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 8)
		chassis_vbox.add_child(row)

		var c_icon := _make_tex_rect(GameData.get_chassis_tex(String(c_id)), Vector2(72, 46), not unlocked)
		row.add_child(c_icon)

		var btn := Button.new()
		btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		btn.custom_minimum_size = Vector2(0, 46)
		if unlocked:
			var prefix: String = "👉 【当前座驾】 " if is_sel else "✅ "
			btn.text = "%s%s (自重 %.1ft | 转化 %.0f SP/t)" % [prefix, c_def["name"], c_def["base_weight"], c_def["sp_per_ton"]]
		else:
			btn.text = "🔒 【埋藏战车】%s  (点击花费 %d 💎 解锁)" % [c_def["name"], int(c_def["unlock_cost"])]

		btn.pressed.connect(func():
			if unlocked:
				chosen_chassis = String(c_id)
				SoundManager.play("coin", 0.08, 0.0)
			else:
				if GameState.unlock_chassis(String(c_id)):
					chosen_chassis = String(c_id)
					SoundManager.play("upgrade", 0.04, 2.0)
					lbl_camp_toast.text = "🎉 成功修复传奇战车底盘：【%s】！" % c_def["name"]
				else:
					lbl_camp_toast.text = "❌ 诺亚晶片不足！解锁【%s】需要 %d 💎。" % [c_def["name"], int(c_def["unlock_cost"])]
			_refresh_camp_ui()
		)
		row.add_child(btn)

	# 3. 刷新 5 大战区地图列表与 3 档难度按钮
	for c in maps_vbox.get_children():
		c.queue_free()
	var m_title := Label.new()
	m_title.text = "🗺️ 第三步：选择废土战区地图 (通关上一张解锁下一张)"
	m_title.add_theme_font_size_override("font_size", 16)
	m_title.add_theme_color_override("font_color", Color(0.45, 0.95, 0.65))
	maps_vbox.add_child(m_title)

	for i in range(GameData.MAPS.size()):
		var m_def: Dictionary = GameData.MAPS[i]
		var is_unlocked: bool = (i < GameState.unlocked_map_count)
		var is_sel: bool = (chosen_map_idx == i)
		var cleared_list: Array = GameState.map_cleared_difficulties.get(m_def["id"], [])
		var badges: Array = []
		if "easy" in cleared_list:
			badges.append("🟢简单✓")
		if "normal" in cleared_list:
			badges.append("🟡困难✓")
		if "hell" in cleared_list:
			badges.append("🔴地狱✓")
		var badge_str: String = (" [" + " ".join(badges) + "]") if not badges.is_empty() else ""

		var reg_b: Dictionary = GameData.get_boss_by_id(m_def["regional_boss_id"])
		var fin_b: Dictionary = GameData.get_boss_by_id(m_def["final_boss_id"])

		var m_row := HBoxContainer.new()
		m_row.add_theme_constant_override("separation", 6)
		maps_vbox.add_child(m_row)

		var ter_icon := _make_tex_rect(GameData.get_terrain_tex(String(m_def["id"])), Vector2(54, 56), not is_unlocked)
		m_row.add_child(ter_icon)

		var boss_icon := _make_tex_rect(GameData.get_boss_tex(String(m_def["final_boss_id"])), Vector2(62, 56), not is_unlocked)
		m_row.add_child(boss_icon)

		var btn := Button.new()
		btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		btn.custom_minimum_size = Vector2(0, 56)
		if is_unlocked:
			var prefix: String = "👉 【当前战区】" if is_sel else "✅ "
			btn.text = "%s%s%s\n驻守Boss: %s | 关底统帅: %s (怪血%.1fx/晶片%.1fx)" % [
				prefix, m_def["name"], badge_str,
				reg_b["name"].split(" ")[0], fin_b["name"].split(" ")[0],
				float(m_def["hp_mult"]), float(m_def["chip_mult"])
			]
		else:
			btn.text = "🔒 【未解锁】%s (需先击败上一章关底统帅解锁)\n镇守赏金首: %s & %s" % [
				m_def["name"], reg_b["name"].split(" ")[0], fin_b["name"].split(" ")[0]
			]

		btn.pressed.connect(func():
			if is_unlocked:
				chosen_map_idx = i
				SoundManager.play("coin", 0.08, 0.0)
				_refresh_camp_ui()
			else:
				lbl_camp_toast.text = "🔒 该战区尚未开放！请先击败【%s】的第10波关底统帅解锁！" % GameData.MAPS[i - 1]["name"]
		)
		m_row.add_child(btn)

	# 刷新简单 / 一般 / 地狱三档难度按钮
	for c in diff_hbox.get_children():
		c.queue_free()
	for d_id in ["easy", "normal", "hell"]:
		var d_def: Dictionary = GameData.DIFFICULTIES[d_id]
		var is_sel_d: bool = (chosen_diff_id == d_id)
		var d_btn := Button.new()
		d_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		d_btn.custom_minimum_size = Vector2(0, 38)
		d_btn.text = ("👉 " if is_sel_d else "") + d_def["name"]
		d_btn.pressed.connect(func():
			chosen_diff_id = d_id
			SoundManager.play("coin", 0.1, 0.0)
			_refresh_camp_ui()
		)
		diff_hbox.add_child(d_btn)

	var cur_d: Dictionary = GameData.DIFFICULTIES[chosen_diff_id]
	lbl_diff_desc.text = "当前难度：%s — %s" % [cur_d["name"], cur_d["desc"]]

	_update_selection_preview()
	_refresh_meta_lab_columns()
	if title_screen.visible and get_viewport() and get_viewport().gui_get_focus_owner() == null and is_instance_valid(btn_start_run) and tab_loadout_view.visible:
		btn_start_run.call_deferred("grab_focus")

func _refresh_meta_lab_columns() -> void:
	# 左栏：废铁镇新功能解锁
	for c in features_vbox.get_children():
		c.queue_free()
	var f_title := Label.new()
	f_title.text = "🏗️ 【废铁镇基建工程：解锁局内新功能与特权】"
	f_title.add_theme_font_size_override("font_size", 18)
	f_title.add_theme_color_override("font_color", Color(0.45, 0.92, 1.0))
	features_vbox.add_child(f_title)

	for f_def in GameData.META_FEATURES:
		var f_id: String = f_def["id"]
		var unlocked: bool = GameState.is_feature_unlocked(f_id)
		var card := _make_box(Color(0.18, 0.19, 0.22), Color(0.35, 0.90, 0.55) if unlocked else Color(0.55, 0.55, 0.60))
		features_vbox.add_child(card)

		var row := HBoxContainer.new()
		card.add_child(row)

		var lbl := Label.new()
		lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		lbl.text = "%s\n%s" % [f_def["name"], f_def["desc"]]
		lbl.add_theme_font_size_override("font_size", 13)
		lbl.add_theme_color_override("font_color", Color(0.65, 1.0, 0.75) if unlocked else Color(0.92, 0.92, 0.92))
		row.add_child(lbl)

		var btn := Button.new()
		btn.custom_minimum_size = Vector2(130, 46)
		btn.disabled = unlocked
		btn.text = "✅ 已永久激活" if unlocked else "解锁功能\n💎 %d" % int(f_def["cost"])
		btn.pressed.connect(func():
			if GameState.unlock_feature(f_id):
				SoundManager.play("upgrade", 0.04, 2.0)
				lbl_camp_toast.text = "🎉 新功能【%s】已永久解锁并在所有轮回中生效！" % f_def["name"]
				_refresh_camp_ui()
			else:
				lbl_camp_toast.text = "❌ 诺亚晶片不足，需要 %d 💎！" % int(f_def["cost"])
		)
		row.add_child(btn)

	# 右栏：永久数值科技树升级
	for c in upgrades_vbox.get_children():
		c.queue_free()
	var u_title := Label.new()
	u_title.text = "🧬 【明奇与多拉姆改造所：永久数值强化科技树】"
	u_title.add_theme_font_size_override("font_size", 18)
	u_title.add_theme_color_override("font_color", Color(0.90, 0.60, 1.0))
	upgrades_vbox.add_child(u_title)

	for u_def in GameData.META_UPGRADES:
		var u_id: String = u_def["id"]
		var lv: int = GameState.get_meta_level(u_id)
		var max_lv: int = int(u_def["max_lv"])
		var is_max: bool = (lv >= max_lv)
		var cost: int = GameState.get_meta_upgrade_cost(u_def)

		var card := _make_box(Color(0.20, 0.17, 0.22), Color(0.85, 0.65, 1.0) if lv > 0 else Color(0.50, 0.45, 0.55))
		upgrades_vbox.add_child(card)

		var row := HBoxContainer.new()
		card.add_child(row)

		var lbl := Label.new()
		lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		lbl.text = "%s  [等级: Lv.%d / %d]\n%s" % [u_def["name"], lv, max_lv, u_def["desc_per_lv"]]
		lbl.add_theme_font_size_override("font_size", 13)
		lbl.add_theme_color_override("font_color", Color(0.95, 0.88, 1.0))
		row.add_child(lbl)

		var btn := Button.new()
		btn.custom_minimum_size = Vector2(130, 46)
		btn.disabled = is_max
		btn.text = "🌟 已满级 MAX" if is_max else "强化 +1级\n💎 %d" % cost
		btn.pressed.connect(func():
			if GameState.upgrade_meta_stat(u_id):
				SoundManager.play("upgrade", 0.06, 1.5)
				lbl_camp_toast.text = "⚡ 【%s】已强化至 Lv.%d！战车与猎人基础实力永久提升！" % [u_def["name"], lv + 1]
				_refresh_camp_ui()
			else:
				lbl_camp_toast.text = "❌ 诺亚晶片不足，强化需要 %d 💎！" % cost
		)
		row.add_child(btn)

func _update_selection_preview() -> void:
	var h: Dictionary = GameData.HUNTERS[chosen_hunter]
	var c: Dictionary = GameData.CHASSIS[chosen_chassis]
	var m: Dictionary = GameData.MAPS[chosen_map_idx]
	var d: Dictionary = GameData.DIFFICULTIES[chosen_diff_id]
	var total_chip_mult: float = float(m["chip_mult"]) * float(d["chip_mult"])

	if is_instance_valid(preview_hunter_rect):
		preview_hunter_rect.texture = GameData.get_hunter_tex(chosen_hunter)
	if is_instance_valid(preview_chassis_rect):
		preview_chassis_rect.texture = GameData.get_chassis_tex(chosen_chassis)
	if is_instance_valid(preview_boss_rect):
		preview_boss_rect.texture = GameData.get_boss_tex(String(m["final_boss_id"]))

	lbl_selection_preview.text = "【当前出击简报】 战区：%s [%s] (共%d波 | 诺亚晶片收益 ×%.2f)  |  猎人：%s  ×  战车：%s\n• 战区情报：%s" % [
		m["name"], d["name"], int(m["waves"]), total_chip_mult, h["name"], c["name"], m["desc"]
	]

func _build_mince_modal() -> void:
	mince_modal = Control.new()
	mince_modal.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mince_modal.visible = false
	ui_layer.add_child(mince_modal)

	var overlay := ColorRect.new()
	overlay.color = Color(0.05, 0.04, 0.06, 0.92)
	overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mince_modal.add_child(overlay)

	var box := _make_box(Color(0.14, 0.12, 0.18), Color(0.45, 0.92, 1.0))
	box.custom_minimum_size = Vector2(860, 500)
	box.position = Vector2(290, 180)
	mince_modal.add_child(box)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 14)
	box.add_child(vbox)

	var title := Label.new()
	title.name = "ModalTitle"
	title.text = "⚡ 明奇博士的生命科学研究所 (轮回结算 & 电击复活) ⚡"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 24)
	title.add_theme_color_override("font_color", Color(0.45, 0.95, 1.0))
	vbox.add_child(title)

	var mid_hbox := HBoxContainer.new()
	mid_hbox.size_flags_vertical = Control.SIZE_EXPAND_FILL
	mid_hbox.add_theme_constant_override("separation", 18)
	vbox.add_child(mid_hbox)

	var mince_portrait := _make_tex_rect(GameData.get_tex("npc_dr_mince"), Vector2(210, 170))
	mid_hbox.add_child(mince_portrait)

	lbl_mince_desc = Label.new()
	lbl_mince_desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	lbl_mince_desc.add_theme_font_size_override("font_size", 15)
	lbl_mince_desc.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	lbl_mince_desc.size_flags_vertical = Control.SIZE_EXPAND_FILL
	mid_hbox.add_child(lbl_mince_desc)

	btn_mince_continue = Button.new()
	btn_mince_continue.custom_minimum_size = Vector2(0, 48)
	btn_mince_continue.add_theme_font_size_override("font_size", 17)
	btn_mince_continue.pressed.connect(_on_mince_revive_to_garage)
	vbox.add_child(btn_mince_continue)

	btn_mince_settle_to_meta = Button.new()
	btn_mince_settle_to_meta.custom_minimum_size = Vector2(0, 50)
	btn_mince_settle_to_meta.text = "🧬 领取诺亚晶片并前往【局外养成所】(解锁新人物 / 新底盘 / 新功能 / 永久属性)"
	btn_mince_settle_to_meta.add_theme_font_size_override("font_size", 18)
	btn_mince_settle_to_meta.pressed.connect(func():
		_show_title_screen(true)
	)
	vbox.add_child(btn_mince_settle_to_meta)

	var btn_restart := Button.new()
	btn_restart.custom_minimum_size = Vector2(0, 44)
	btn_restart.text = "🚜 返回出击整备大厅 (立即开启下一轮回)"
	btn_restart.add_theme_font_size_override("font_size", 16)
	btn_restart.pressed.connect(func():
		_show_title_screen(false)
	)
	vbox.add_child(btn_restart)

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

func _unhandled_input(event: InputEvent) -> void:
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

func _on_player_defeated() -> void:
	SoundManager.play("mince_revive", 0.02, 2.0)
	SoundManager.play_bgm("bgm_dr_mince")
	battlefield.visible = false
	battlefield.hud_layer.visible = false
	mince_modal.visible = true

	var rewards: Dictionary = GameState.settle_run_rewards(false)
	lbl_mince_desc.text = "“伊戈尔，快把高压电极接上！哔——啪！！”\n\n【本局轮回战绩 & 诺亚晶片 💎 结算单】\n• 抵达波次：第 %d 波  ➔  +%d 💎\n• 击毁机械兽：%d 台  ➔  +%d 💎\n• 狩猎赏金首：%d 名  ➔  +%d 💎\n• 剩余赏金折算：%d G  ➔  +%d 💎\n————————————————————————\n🎉 本次轮回共获得：+%d 💎 诺亚晶片！ (当前总持有：%d 💎)" % [
		GameState.current_wave, rewards["wave_chips"],
		GameState.total_kills, rewards["kill_chips"],
		GameState.bounties_hunted, rewards["boss_chips"],
		GameState.gold, rewards["gold_chips"],
		rewards["total"], GameState.noah_chips
	]

	if GameState.mince_free_revive_available:
		btn_mince_continue.visible = true
		btn_mince_continue.text = "⚡ 不甘心？接受明奇博士当场电击续命！(赠送+120G改装补贴，退回多拉姆车库重整旗鼓)"
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
	var m_def: Dictionary = GameState.get_current_map_def()
	var d_def: Dictionary = GameState.get_current_difficulty_def()
	var unlock_banner: String = ""
	if rewards.get("unlocked_next_map", "") != "":
		unlock_banner = "\n🔓【重大捷报：已成功解锁下一章新地图 —— %s！】🔓\n" % rewards["unlocked_next_map"]
		chosen_map_idx = min(GameData.MAPS.size() - 1, chosen_map_idx + 1)

	lbl_mince_desc.text = "🏆 【战区肃清！已成功击杀关底统帅，征服 %s (%s)！】 🏆%s\n【通关轮回战绩 & 诺亚晶片 💎 结算单 (战区与难度总倍率 ×%.2f)】\n• 征服 %d 波战区：+%d 💎   |   通关统帅大奖：+%d 💎\n• 击毁机械兽 (%d台)：+%d 💎   |   狩猎赏金首 (%d名)：+%d 💎\n• 剩余赏金折算 (%dG)：+%d 💎\n————————————————————————\n🎉 本局最终实得：+%d 💎 诺亚晶片！ (当前总持有：%d 💎)" % [
		m_def["name"], d_def["name"], unlock_banner, float(rewards.get("chip_mult", 1.0)),
		GameState.max_waves, rewards["wave_chips"], rewards["win_chips"],
		GameState.total_kills, rewards["kill_chips"],
		GameState.bounties_hunted, rewards["boss_chips"],
		GameState.gold, rewards["gold_chips"],
		rewards["total"], GameState.noah_chips
	]

func _make_box(bg_col: Color, border_col: Color) -> PanelContainer:
	var p := PanelContainer.new()
	var s := StyleBoxFlat.new()
	s.bg_color = bg_col
	s.border_color = border_col
	s.set_border_width_all(2)
	s.set_corner_radius_all(8)
	s.content_margin_left = 14
	s.content_margin_right = 14
	s.content_margin_top = 10
	s.content_margin_bottom = 10
	p.add_theme_stylebox_override("panel", s)
	return p

func _make_tex_rect(tex: Texture2D, min_sz: Vector2, darkened: bool = false) -> TextureRect:
	var tr := TextureRect.new()
	tr.texture = tex
	tr.custom_minimum_size = min_sz
	tr.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	tr.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	if darkened:
		tr.modulate = Color(0.38, 0.38, 0.38, 0.85)
	return tr
