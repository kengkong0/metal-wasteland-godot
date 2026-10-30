extends Node
## 《重装废土：赏金狂飙》 - 顶层场景与【土豆兄弟风格多界面选拔与大本营】控制器
## 架构升级：
## 1. 彻底解决“所有选项挤在一个界面”的杂乱感：
##    - 主界面 (Title): 纯粹利落的主菜单（开始出击、局外改造所、赏金通缉图鉴、全屏、退出）
##    - 步骤 1 (猎人选择): 专属全屏界面，大号猎人卡片网格 + 详细特权展示
##    - 步骤 2 (战车整备): 专属全屏界面，战车底盘蓝图网格 + 槽位/装甲/自重可视化进度条
##    - 步骤 3 (战区与危险度): 专属全屏界面，战区章节 + 危险等级(Hazard 0~2) + 一键出击
##    - 局外科技改造所 (Meta Lab): 专属全屏界面，基建工程 + 属性科技树
##    - 赏金首绝密通缉图鉴 (Bounties): 专属全屏界面，10大赏金首绝密档案海报
## 2. 完善的流转与回退 (ESC/手柄返回键逐级回退)，直观的面包屑导航进度指示器
## 3. 全局 100% 锚点与响应式布局，彻底适配任意分辨率与全屏

const BattlefieldScript = preload("res://scripts/combat/Battlefield.gd")
const GarageUIScript = preload("res://scripts/ui/GarageUI.gd")

enum ScreenState {
	TITLE,           # 主界面 / 首页
	SELECT_HUNTER,   # 步骤 1：猎人选择
	SELECT_CHASSIS,  # 步骤 2：战车改装
	SELECT_MAP,      # 步骤 3：战区与危险度
	META_LAB,        # 局外科技所
	BOUNTIES_CODEX,  # 赏金首通缉令图鉴
	SETTINGS         # ⚙️ 系统设置 (画面/声音/键位)
}

var current_screen: ScreenState = ScreenState.TITLE

var battlefield: Node2D
var ui_layer: CanvasLayer
var title_screen: Control
var garage_ui: Control
var mince_modal: Control

# --- 各分步视图容器引用 ---
var view_title: Control
var view_select_hunter: Control
var view_select_chassis: Control
var view_select_map: Control
var view_meta_lab: Control
var view_bounties: Control
var view_settings: Control

# --- 系统设置界面引用 ---
var settings_tab_idx: int = 0
var settings_content_vbox: VBoxContainer
var lbl_settings_toast: Label
var settings_tab_buttons: Array = []

# --- 当前出击选型暂存 ---
var chosen_hunter: String = "bounty_hunter"
var chosen_chassis: String = "buggy"
var chosen_map_idx: int = 0
var chosen_diff_id: String = "normal"

# --- 步骤 1：猎人选择界面引用 ---
var hunter_cards_container: GridContainer
var hunter_preview_box: VBoxContainer
var btn_hunter_next: Button
var lbl_hunter_toast: Label

# --- 步骤 2：战车整备界面引用 ---
var chassis_cards_container: GridContainer
var chassis_preview_box: VBoxContainer
var btn_chassis_next: Button
var lbl_chassis_toast: Label

# --- 步骤 3：战区与危险度界面引用 ---
var maps_cards_container: VBoxContainer
var map_preview_box: VBoxContainer
var btn_launch_run: Button
var lbl_map_toast: Label

# --- 局外科技改造所界面引用 ---
var meta_features_vbox: VBoxContainer
var meta_upgrades_vbox: VBoxContainer
var lbl_meta_chips: Label
var lbl_meta_toast: Label

# --- 赏金通缉图鉴界面引用 ---
var bounties_grid: GridContainer

# --- 明奇结算弹窗引用 ---
var mince_stats_vbox: VBoxContainer
var btn_mince_continue: Button
var btn_mince_settle_to_meta: Button

# --- 主界面引用 ---
var lbl_title_chips: Label
var lbl_title_stats: Label
var lbl_title_resume: Label
var btn_title_start: Button
var btn_title_quick_start: Button

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

	_build_all_screens()
	_build_mince_modal()
	_switch_to_screen(ScreenState.TITLE)

# ============================================================================
# 构建全部 6 个独立分步/全屏子界面
# ============================================================================
func _build_all_screens() -> void:
	title_screen = Control.new()
	title_screen.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	ui_layer.add_child(title_screen)

	var bg := ColorRect.new()
	bg.color = Color(0.08, 0.08, 0.10, 1.0)
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	title_screen.add_child(bg)

	_build_view_title()
	_build_view_select_hunter()
	_build_view_select_chassis()
	_build_view_select_map()
	_build_view_meta_lab()
	_build_view_bounties()
	_build_view_settings()

# ----------------------------------------------------------------------------
# 1. 主界面 / 首页 (Title Screen) - 参考土豆兄弟，纯粹开门见山的主菜单
# ----------------------------------------------------------------------------
func _build_view_title() -> void:
	view_title = Control.new()
	view_title.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	title_screen.add_child(view_title)

	var margin := MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	margin.add_theme_constant_override("margin_left", 36)
	margin.add_theme_constant_override("margin_right", 36)
	margin.add_theme_constant_override("margin_top", 24)
	margin.add_theme_constant_override("margin_bottom", 24)
	view_title.add_child(margin)

	var root_vbox := VBoxContainer.new()
	root_vbox.add_theme_constant_override("separation", 20)
	margin.add_child(root_vbox)

	# 顶部状态与快捷操作栏
	var top_row := HBoxContainer.new()
	top_row.add_theme_constant_override("separation", 14)
	root_vbox.add_child(top_row)

	lbl_title_chips = _make_outlined_label("💎 0 诺亚晶片", 20, Color(0.40, 0.95, 1.0))
	top_row.add_child(lbl_title_chips)

	lbl_title_stats = _make_outlined_label("", 14, Color(0.85, 0.88, 0.92))
	top_row.add_child(lbl_title_stats)

	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top_row.add_child(spacer)

	var btn_debug := Button.new()
	btn_debug.text = "🎁 +500💎&全图"
	btn_debug.custom_minimum_size = Vector2(130, 36)
	btn_debug.pressed.connect(func():
		GameState.noah_chips += 500
		GameState.unlocked_map_count = GameData.MAPS.size()
		GameState.save_meta_data()
		SoundManager.play("upgrade", 0.05, 1.0)
		_refresh_title_view()
	)
	top_row.add_child(btn_debug)

	var btn_fs := Button.new()
	btn_fs.text = "🖥️ 全屏[F11]"
	btn_fs.custom_minimum_size = Vector2(100, 36)
	btn_fs.pressed.connect(_toggle_fullscreen)
	top_row.add_child(btn_fs)

	var btn_reset := Button.new()
	btn_reset.text = "🗑️ 重置存档"
	btn_reset.custom_minimum_size = Vector2(90, 36)
	btn_reset.pressed.connect(func():
		GameState.reset_meta_save()
		chosen_hunter = "bounty_hunter"
		chosen_chassis = "buggy"
		chosen_map_idx = 0
		chosen_diff_id = "normal"
		_refresh_title_view()
	)
	top_row.add_child(btn_reset)

	# 中部内容区 (左侧主菜单 + 右侧当前出击配置与快速出击卡)
	var body_hbox := HBoxContainer.new()
	body_hbox.size_flags_vertical = Control.SIZE_EXPAND_FILL
	body_hbox.add_theme_constant_override("separation", 36)
	root_vbox.add_child(body_hbox)

	# 左侧：大标题 + 垂直功能菜单
	var left_vbox := VBoxContainer.new()
	left_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	left_vbox.size_flags_stretch_ratio = 1.1
	left_vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	left_vbox.add_theme_constant_override("separation", 18)
	body_hbox.add_child(left_vbox)

	var title_box := VBoxContainer.new()
	title_box.add_theme_constant_override("separation", 6)
	left_vbox.add_child(title_box)

	var title_lbl := _make_outlined_label("🔥 重装废土：赏金狂飙", 36, Color(1.0, 0.58, 0.22))
	title_box.add_child(title_lbl)

	var sub_lbl := _make_outlined_label("METAL WASTELAND: BOUNTY OVERDRIVE", 16, Color(0.40, 0.90, 1.0))
	title_box.add_child(sub_lbl)

	var tip_lbl := _make_outlined_label("《重装机兵》战车武装改装 × 《土豆兄弟》俯视角割草肉鸽", 13, Color(0.75, 0.78, 0.82))
	title_box.add_child(tip_lbl)

	# 按钮组
	var menu_btn_vbox := VBoxContainer.new()
	menu_btn_vbox.custom_minimum_size = Vector2(320, 0)
	menu_btn_vbox.add_theme_constant_override("separation", 12)
	left_vbox.add_child(menu_btn_vbox)

	btn_title_start = _make_styled_button("🚀 开始出击 (分步整备)", 20, Color(0.85, 0.35, 0.18), Color(1.0, 0.85, 0.35), Vector2(0, 52))
	btn_title_start.pressed.connect(func():
		SoundManager.play("coin", 0.08, 0.5)
		_switch_to_screen(ScreenState.SELECT_HUNTER)
	)
	menu_btn_vbox.add_child(btn_title_start)

	var btn_meta := _make_styled_button("🧬 废铁镇改造所 (局外科技树)", 16, Color(0.18, 0.18, 0.24), Color(0.45, 0.90, 1.0), Vector2(0, 46))
	btn_meta.pressed.connect(func():
		SoundManager.play("coin", 0.08, 0.0)
		_switch_to_screen(ScreenState.META_LAB)
	)
	menu_btn_vbox.add_child(btn_meta)

	var btn_bounties := _make_styled_button("📜 赏金首绝密通缉档案", 16, Color(0.18, 0.18, 0.24), Color(1.0, 0.85, 0.35), Vector2(0, 46))
	btn_bounties.pressed.connect(func():
		SoundManager.play("coin", 0.08, 0.0)
		_switch_to_screen(ScreenState.BOUNTIES_CODEX)
	)
	menu_btn_vbox.add_child(btn_bounties)

	var btn_settings := _make_styled_button("⚙️ 系统设置 (画面/声音/键位)", 16, Color(0.18, 0.18, 0.24), Color(0.85, 0.75, 0.40), Vector2(0, 46))
	btn_settings.pressed.connect(func():
		SoundManager.play("coin", 0.08, 0.0)
		_switch_to_screen(ScreenState.SETTINGS)
	)
	menu_btn_vbox.add_child(btn_settings)

	var btn_quit := _make_styled_button("🚪 退出游戏", 15, Color(0.16, 0.16, 0.18), Color(0.55, 0.55, 0.60), Vector2(0, 42))
	btn_quit.pressed.connect(func(): get_tree().quit())
	menu_btn_vbox.add_child(btn_quit)

	# 右侧：上次出击装配卡 + 一键快速出击按钮
	var right_panel := _make_box(Color(0.13, 0.14, 0.17), Color(0.35, 0.55, 0.75))
	right_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	right_panel.size_flags_stretch_ratio = 1.0
	body_hbox.add_child(right_panel)

	var right_vbox := VBoxContainer.new()
	right_vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	right_vbox.add_theme_constant_override("separation", 16)
	right_panel.add_child(right_vbox)

	right_vbox.add_child(_make_outlined_label("⚡ 战术待命配置 (快速出击)", 18, Color(1.0, 0.88, 0.35)))

	lbl_title_resume = _make_outlined_label("", 14, Color(0.85, 0.90, 0.95))
	lbl_title_resume.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	right_vbox.add_child(lbl_title_resume)

	btn_title_quick_start = _make_styled_button("🔥 直接以此配置出击！", 17, Color(0.68, 0.25, 0.16), Color(1.0, 0.80, 0.30), Vector2(0, 48))
	btn_title_quick_start.pressed.connect(_on_start_run_pressed)
	right_vbox.add_child(btn_title_quick_start)

# ----------------------------------------------------------------------------
# 2. 步骤 1：猎人选择 (Select Hunter) - 专属全屏界面
# ----------------------------------------------------------------------------
func _build_view_select_hunter() -> void:
	view_select_hunter = Control.new()
	view_select_hunter.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	title_screen.add_child(view_select_hunter)

	var margin := MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	margin.add_theme_constant_override("margin_left", 24)
	margin.add_theme_constant_override("margin_right", 24)
	margin.add_theme_constant_override("margin_top", 16)
	margin.add_theme_constant_override("margin_bottom", 16)
	view_select_hunter.add_child(margin)

	var root_vbox := VBoxContainer.new()
	root_vbox.add_theme_constant_override("separation", 12)
	margin.add_child(root_vbox)

	# 顶部导航行：返回 + 面包屑进度条 + 晶片
	var top_nav := HBoxContainer.new()
	top_nav.add_theme_constant_override("separation", 12)
	root_vbox.add_child(top_nav)

	var btn_back := _make_styled_button("⬅️ 返回主菜单 [ESC]", 14, Color(0.18, 0.18, 0.22), Color(0.60, 0.60, 0.68), Vector2(160, 36))
	btn_back.pressed.connect(func():
		SoundManager.play("coin", 0.08, -1.0)
		_switch_to_screen(ScreenState.TITLE)
	)
	top_nav.add_child(btn_back)

	var stepper := _make_breadcrumbs(1, chosen_hunter, chosen_chassis)
	stepper.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top_nav.add_child(stepper)

	# 主体区：左侧 6 大猎人卡片网格，右侧猎人详情大卡
	var body_hbox := HBoxContainer.new()
	body_hbox.size_flags_vertical = Control.SIZE_EXPAND_FILL
	body_hbox.add_theme_constant_override("separation", 16)
	root_vbox.add_child(body_hbox)

	# 左侧网格区
	var grid_panel := _make_box(Color(0.12, 0.12, 0.15), Color(0.65, 0.50, 0.25))
	grid_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	grid_panel.size_flags_stretch_ratio = 1.25
	body_hbox.add_child(grid_panel)

	var g_vbox := VBoxContainer.new()
	g_vbox.add_theme_constant_override("separation", 10)
	grid_panel.add_child(g_vbox)

	g_vbox.add_child(_make_outlined_label("🎖️ 选择出击猎人 (共 6 名)", 17, Color(1.0, 0.88, 0.35)))
	g_vbox.add_child(_make_outlined_label("每位猎人具备截然不同的被动天赋、战车改造倾向与初始能力", 12, Color(0.78, 0.82, 0.88)))

	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	g_vbox.add_child(scroll)

	hunter_cards_container = GridContainer.new()
	hunter_cards_container.columns = 3
	hunter_cards_container.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hunter_cards_container.size_flags_vertical = Control.SIZE_EXPAND_FILL
	hunter_cards_container.add_theme_constant_override("h_separation", 12)
	hunter_cards_container.add_theme_constant_override("v_separation", 12)
	scroll.add_child(hunter_cards_container)

	# 右侧详情区
	var preview_panel := _make_box(Color(0.14, 0.14, 0.18), Color(0.95, 0.65, 0.25))
	preview_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	preview_panel.size_flags_stretch_ratio = 0.95
	body_hbox.add_child(preview_panel)

	hunter_preview_box = VBoxContainer.new()
	hunter_preview_box.add_theme_constant_override("separation", 10)
	preview_panel.add_child(hunter_preview_box)

	# 底部操作栏
	var bot_bar := HBoxContainer.new()
	bot_bar.add_theme_constant_override("separation", 16)
	root_vbox.add_child(bot_bar)

	lbl_hunter_toast = _make_outlined_label("💡 点击卡片选定猎人，未解锁猎人可使用 💎 晶片立即招募！", 13, Color(1.0, 0.88, 0.35))
	lbl_hunter_toast.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	bot_bar.add_child(lbl_hunter_toast)

	btn_hunter_next = _make_styled_button("下一步：战车整备 ➡️ [Enter]", 16, Color(0.75, 0.32, 0.18), Color(1.0, 0.85, 0.30), Vector2(230, 44))
	btn_hunter_next.pressed.connect(func():
		if GameState.is_hunter_unlocked(chosen_hunter):
			SoundManager.play("coin", 0.08, 0.5)
			_switch_to_screen(ScreenState.SELECT_CHASSIS)
		else:
			lbl_hunter_toast.text = "🔒 请先招募该猎人或选择其他已就绪的猎人！"
			SoundManager.play("cannon_empty", 0.1, 0.0)
	)
	bot_bar.add_child(btn_hunter_next)

# ----------------------------------------------------------------------------
# 3. 步骤 2：战车整备 (Select Chassis) - 专属全屏界面
# ----------------------------------------------------------------------------
func _build_view_select_chassis() -> void:
	view_select_chassis = Control.new()
	view_select_chassis.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	title_screen.add_child(view_select_chassis)

	var margin := MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	margin.add_theme_constant_override("margin_left", 24)
	margin.add_theme_constant_override("margin_right", 24)
	margin.add_theme_constant_override("margin_top", 16)
	margin.add_theme_constant_override("margin_bottom", 16)
	view_select_chassis.add_child(margin)

	var root_vbox := VBoxContainer.new()
	root_vbox.add_theme_constant_override("separation", 12)
	margin.add_child(root_vbox)

	# 顶部导航行
	var top_nav := HBoxContainer.new()
	top_nav.add_theme_constant_override("separation", 12)
	root_vbox.add_child(top_nav)

	var btn_back := _make_styled_button("⬅️ 上一步: 猎人 [ESC]", 14, Color(0.18, 0.18, 0.22), Color(0.60, 0.60, 0.68), Vector2(170, 36))
	btn_back.pressed.connect(func():
		SoundManager.play("coin", 0.08, -1.0)
		_switch_to_screen(ScreenState.SELECT_HUNTER)
	)
	top_nav.add_child(btn_back)

	var stepper := _make_breadcrumbs(2, chosen_hunter, chosen_chassis)
	stepper.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top_nav.add_child(stepper)

	# 主体区：左侧 8 大战车卡片网格，右侧战车蓝图与属性详情
	var body_hbox := HBoxContainer.new()
	body_hbox.size_flags_vertical = Control.SIZE_EXPAND_FILL
	body_hbox.add_theme_constant_override("separation", 16)
	root_vbox.add_child(body_hbox)

	# 左侧网格区
	var grid_panel := _make_box(Color(0.12, 0.12, 0.15), Color(0.70, 0.32, 0.25))
	grid_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	grid_panel.size_flags_stretch_ratio = 1.25
	body_hbox.add_child(grid_panel)

	var g_vbox := VBoxContainer.new()
	g_vbox.add_theme_constant_override("separation", 10)
	grid_panel.add_child(g_vbox)

	g_vbox.add_child(_make_outlined_label("🚜 选择战车底盘 (共 8 台传奇载具)", 17, Color(1.0, 0.58, 0.35)))
	g_vbox.add_child(_make_outlined_label("底盘决定了主副炮与S-E孔位配置、自重负载比及专属战车特技", 12, Color(0.78, 0.82, 0.88)))

	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	g_vbox.add_child(scroll)

	chassis_cards_container = GridContainer.new()
	chassis_cards_container.columns = 4
	chassis_cards_container.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	chassis_cards_container.size_flags_vertical = Control.SIZE_EXPAND_FILL
	chassis_cards_container.add_theme_constant_override("h_separation", 10)
	chassis_cards_container.add_theme_constant_override("v_separation", 10)
	scroll.add_child(chassis_cards_container)

	# 右侧详情区
	var preview_panel := _make_box(Color(0.14, 0.14, 0.18), Color(0.92, 0.40, 0.30))
	preview_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	preview_panel.size_flags_stretch_ratio = 0.95
	body_hbox.add_child(preview_panel)

	chassis_preview_box = VBoxContainer.new()
	chassis_preview_box.add_theme_constant_override("separation", 10)
	preview_panel.add_child(chassis_preview_box)

	# 底部操作栏
	var bot_bar := HBoxContainer.new()
	bot_bar.add_theme_constant_override("separation", 16)
	root_vbox.add_child(bot_bar)

	lbl_chassis_toast = _make_outlined_label("💡 点击卡片选定战车，未解锁战车底盘可使用 💎 晶片立即修复入库！", 13, Color(1.0, 0.88, 0.35))
	lbl_chassis_toast.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	bot_bar.add_child(lbl_chassis_toast)

	btn_chassis_next = _make_styled_button("下一步：战区与危险度 ➡️ [Enter]", 16, Color(0.75, 0.32, 0.18), Color(1.0, 0.85, 0.30), Vector2(250, 44))
	btn_chassis_next.pressed.connect(func():
		if GameState.is_chassis_unlocked(chosen_chassis):
			SoundManager.play("coin", 0.08, 0.5)
			_switch_to_screen(ScreenState.SELECT_MAP)
		else:
			lbl_chassis_toast.text = "🔒 请先修复该战车底盘或选择已就绪的载具！"
			SoundManager.play("cannon_empty", 0.1, 0.0)
	)
	bot_bar.add_child(btn_chassis_next)

# ----------------------------------------------------------------------------
# 4. 步骤 3：目标战区与危险度 (Select Map & Hazard) - 专属全屏界面
# ----------------------------------------------------------------------------
func _build_view_select_map() -> void:
	view_select_map = Control.new()
	view_select_map.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	title_screen.add_child(view_select_map)

	var margin := MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	margin.add_theme_constant_override("margin_left", 24)
	margin.add_theme_constant_override("margin_right", 24)
	margin.add_theme_constant_override("margin_top", 16)
	margin.add_theme_constant_override("margin_bottom", 16)
	view_select_map.add_child(margin)

	var root_vbox := VBoxContainer.new()
	root_vbox.add_theme_constant_override("separation", 12)
	margin.add_child(root_vbox)

	# 顶部导航行
	var top_nav := HBoxContainer.new()
	top_nav.add_theme_constant_override("separation", 12)
	root_vbox.add_child(top_nav)

	var btn_back := _make_styled_button("⬅️ 上一步: 战车 [ESC]", 14, Color(0.18, 0.18, 0.22), Color(0.60, 0.60, 0.68), Vector2(170, 36))
	btn_back.pressed.connect(func():
		SoundManager.play("coin", 0.08, -1.0)
		_switch_to_screen(ScreenState.SELECT_CHASSIS)
	)
	top_nav.add_child(btn_back)

	var stepper := _make_breadcrumbs(3, chosen_hunter, chosen_chassis)
	stepper.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top_nav.add_child(stepper)

	# 主体区：左侧 5 大战区章节卡，右侧危险度设置与【发动引擎出击】卡
	var body_hbox := HBoxContainer.new()
	body_hbox.size_flags_vertical = Control.SIZE_EXPAND_FILL
	body_hbox.add_theme_constant_override("separation", 16)
	root_vbox.add_child(body_hbox)

	# 左侧战区章节卡
	var map_list_panel := _make_box(Color(0.12, 0.13, 0.15), Color(0.35, 0.75, 0.50))
	map_list_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	map_list_panel.size_flags_stretch_ratio = 1.05
	body_hbox.add_child(map_list_panel)

	var m_vbox := VBoxContainer.new()
	m_vbox.add_theme_constant_override("separation", 10)
	map_list_panel.add_child(m_vbox)

	m_vbox.add_child(_make_outlined_label("🗺️ 选择废土战区章节 (共 5 大战区)", 17, Color(0.45, 0.95, 0.65)))
	m_vbox.add_child(_make_outlined_label("逐章推进通关可解锁后续更凶险的深层战区，关底驻守专属统帅", 12, Color(0.78, 0.85, 0.80)))

	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	m_vbox.add_child(scroll)

	maps_cards_container = VBoxContainer.new()
	maps_cards_container.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	maps_cards_container.add_theme_constant_override("separation", 8)
	scroll.add_child(maps_cards_container)

	# 右侧危险度与立即出击面板
	var preview_panel := _make_box(Color(0.14, 0.14, 0.18), Color(0.95, 0.55, 0.20))
	preview_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	preview_panel.size_flags_stretch_ratio = 1.15
	body_hbox.add_child(preview_panel)

	map_preview_box = VBoxContainer.new()
	map_preview_box.add_theme_constant_override("separation", 10)
	preview_panel.add_child(map_preview_box)

	# 底部操作栏
	var bot_bar := HBoxContainer.new()
	bot_bar.add_theme_constant_override("separation", 16)
	root_vbox.add_child(bot_bar)

	lbl_map_toast = _make_outlined_label("💡 检查猎人、战车与目标战区，确认后立即启动战车引擎出击！", 13, Color(1.0, 0.88, 0.35))
	lbl_map_toast.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	bot_bar.add_child(lbl_map_toast)

# ----------------------------------------------------------------------------
# 5. 局外科技改造所 (Meta Lab) - 专属全屏界面
# ----------------------------------------------------------------------------
func _build_view_meta_lab() -> void:
	view_meta_lab = Control.new()
	view_meta_lab.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	title_screen.add_child(view_meta_lab)

	var margin := MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	margin.add_theme_constant_override("margin_left", 24)
	margin.add_theme_constant_override("margin_right", 24)
	margin.add_theme_constant_override("margin_top", 16)
	margin.add_theme_constant_override("margin_bottom", 16)
	view_meta_lab.add_child(margin)

	var root_vbox := VBoxContainer.new()
	root_vbox.add_theme_constant_override("separation", 12)
	margin.add_child(root_vbox)

	# 顶部导航行
	var top_nav := HBoxContainer.new()
	top_nav.add_theme_constant_override("separation", 14)
	root_vbox.add_child(top_nav)

	var btn_back := _make_styled_button("⬅️ 返回主菜单 [ESC]", 14, Color(0.18, 0.18, 0.22), Color(0.60, 0.60, 0.68), Vector2(160, 36))
	btn_back.pressed.connect(func():
		SoundManager.play("coin", 0.08, -1.0)
		_switch_to_screen(ScreenState.TITLE)
	)
	top_nav.add_child(btn_back)

	var title_lbl := _make_outlined_label("🧬 废铁镇改造所 — 永久科技树与基建工程", 20, Color(0.45, 0.95, 1.0))
	title_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top_nav.add_child(title_lbl)

	lbl_meta_chips = _make_outlined_label("💎 0 晶片", 18, Color(0.40, 0.95, 1.0))
	top_nav.add_child(lbl_meta_chips)

	# 主体区：左侧基建工程，右侧属性强化科技树
	var body_hbox := HBoxContainer.new()
	body_hbox.size_flags_vertical = Control.SIZE_EXPAND_FILL
	body_hbox.add_theme_constant_override("separation", 16)
	root_vbox.add_child(body_hbox)

	# 左侧基建工程
	var feat_panel := _make_box(Color(0.12, 0.13, 0.16), Color(0.35, 0.85, 1.0))
	feat_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	body_hbox.add_child(feat_panel)

	var feat_scroll := ScrollContainer.new()
	feat_scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	feat_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	feat_panel.add_child(feat_scroll)

	meta_features_vbox = VBoxContainer.new()
	meta_features_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	meta_features_vbox.add_theme_constant_override("separation", 8)
	feat_scroll.add_child(meta_features_vbox)

	# 右侧属性科技树
	var upg_panel := _make_box(Color(0.13, 0.12, 0.17), Color(0.85, 0.50, 1.0))
	upg_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	body_hbox.add_child(upg_panel)

	var upg_scroll := ScrollContainer.new()
	upg_scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	upg_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	upg_panel.add_child(upg_scroll)

	meta_upgrades_vbox = VBoxContainer.new()
	meta_upgrades_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	meta_upgrades_vbox.add_theme_constant_override("separation", 8)
	upg_scroll.add_child(meta_upgrades_vbox)

	# 底部操作栏
	var bot_bar := HBoxContainer.new()
	bot_bar.add_theme_constant_override("separation", 16)
	root_vbox.add_child(bot_bar)

	lbl_meta_toast = _make_outlined_label("💡 局外科技属性对所有猎人与战车永久生效；可随时无损重置返还全部 💎 晶片！", 13, Color(1.0, 0.88, 0.35))
	lbl_meta_toast.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	bot_bar.add_child(lbl_meta_toast)

	var btn_refund := _make_styled_button("🗑️ 重置所有科技点 (100%返还晶片)", 14, Color(0.24, 0.16, 0.18), Color(0.92, 0.40, 0.35), Vector2(250, 40))
	btn_refund.pressed.connect(_refund_all_meta_tech)
	bot_bar.add_child(btn_refund)

# ----------------------------------------------------------------------------
# 7. 系统设置界面 (System Settings) - 声音 / 分辨率 / 画面 / 键位
# ----------------------------------------------------------------------------
func _build_view_settings() -> void:
	view_settings = Control.new()
	view_settings.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	title_screen.add_child(view_settings)

	var margin := MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	margin.add_theme_constant_override("margin_left", 32)
	margin.add_theme_constant_override("margin_right", 32)
	margin.add_theme_constant_override("margin_top", 18)
	margin.add_theme_constant_override("margin_bottom", 18)
	view_settings.add_child(margin)

	var root_vbox := VBoxContainer.new()
	root_vbox.add_theme_constant_override("separation", 14)
	margin.add_child(root_vbox)

	# 顶部导航行
	var top_nav := HBoxContainer.new()
	top_nav.add_theme_constant_override("separation", 14)
	root_vbox.add_child(top_nav)

	var btn_back := _make_styled_button("⬅️ 返回主菜单 [ESC]", 14, Color(0.18, 0.18, 0.22), Color(0.60, 0.60, 0.68), Vector2(160, 38))
	btn_back.pressed.connect(func():
		SoundManager.play("coin", 0.08, -1.0)
		_switch_to_screen(ScreenState.TITLE)
	)
	top_nav.add_child(btn_back)

	var title_lbl := _make_outlined_label("⚙️ 系统设置 (System Settings)", 20, Color(1.0, 0.85, 0.35))
	title_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top_nav.add_child(title_lbl)

	# 4 个分类标签栏
	var tabs_hbox := HBoxContainer.new()
	tabs_hbox.add_theme_constant_override("separation", 8)
	top_nav.add_child(tabs_hbox)

	var tab_names: Array = ["🔊 音频设置", "🖥️ 画面显示", "🎮 游戏性", "⌨️ 键位表"]
	settings_tab_buttons.clear()
	for i in range(tab_names.size()):
		var t_idx: int = i
		var t_btn := Button.new()
		t_btn.custom_minimum_size = Vector2(120, 36)
		t_btn.text = tab_names[i]
		t_btn.add_theme_font_size_override("font_size", 13)
		t_btn.pressed.connect(func():
			settings_tab_idx = t_idx
			SoundManager.play("coin", 0.08, 0.0)
			_refresh_settings_view()
		)
		tabs_hbox.add_child(t_btn)
		settings_tab_buttons.append(t_btn)

	# 中部内容滑动面板
	var content_panel := _make_box(Color(0.13, 0.13, 0.17), Color(0.35, 0.40, 0.48), 10, 16)
	content_panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	root_vbox.add_child(content_panel)

	var scroll := ScrollContainer.new()
	scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	content_panel.add_child(scroll)

	settings_content_vbox = VBoxContainer.new()
	settings_content_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	settings_content_vbox.add_theme_constant_override("separation", 16)
	scroll.add_child(settings_content_vbox)

	# 底部操作栏
	var bot_bar := HBoxContainer.new()
	bot_bar.add_theme_constant_override("separation", 16)
	root_vbox.add_child(bot_bar)

	var btn_restore := _make_styled_button("🔄 恢复默认设置", 14, Color(0.22, 0.18, 0.18), Color(0.85, 0.45, 0.35), Vector2(160, 40))
	btn_restore.pressed.connect(func():
		GameState.restore_default_settings()
		SoundManager.play("upgrade", 0.05, 1.0)
		lbl_settings_toast.text = "🔄 已成功恢复所有系统默认设置！"
		_refresh_settings_view()
	)
	bot_bar.add_child(btn_restore)

	lbl_settings_toast = _make_outlined_label("💡 所有设置项修改即时生效，并自动保存到本地配置！", 13, Color(1.0, 0.88, 0.35))
	lbl_settings_toast.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	bot_bar.add_child(lbl_settings_toast)

	var btn_save := _make_styled_button("💾 保存并应用设置", 15, Color(0.20, 0.45, 0.25), Color(0.40, 0.95, 0.55), Vector2(170, 40))
	btn_save.pressed.connect(func():
		GameState.save_settings()
		SoundManager.play("coin", 0.08, 1.0)
		lbl_settings_toast.text = "✅ 设置已成功保存并即时生效！"
	)
	bot_bar.add_child(btn_save)

func _refresh_settings_view() -> void:
	for i in range(settings_tab_buttons.size()):
		var tb: Button = settings_tab_buttons[i]
		if i == settings_tab_idx:
			var st := StyleBoxFlat.new()
			st.bg_color = Color(0.24, 0.32, 0.42)
			st.border_color = Color(0.40, 0.95, 1.0)
			st.set_border_width_all(2)
			st.set_corner_radius_all(6)
			tb.add_theme_stylebox_override("normal", st)
		else:
			tb.remove_theme_stylebox_override("normal")

	for c in settings_content_vbox.get_children():
		c.queue_free()

	match settings_tab_idx:
		0:
			_build_settings_audio_tab()
		1:
			_build_settings_display_tab()
		2:
			_build_settings_gameplay_tab()
		3:
			_build_settings_controls_tab()

func _build_settings_audio_tab() -> void:
	settings_content_vbox.add_child(_make_outlined_label("🔊 声音与音频设置 (Audio Settings)", 18, Color(0.40, 0.95, 1.0)))

	# 1. 主音量
	var m_val: float = float(GameState.get_setting("master_volume", 1.0))
	var m_card := _make_box(Color(0.16, 0.16, 0.20), Color(0.35, 0.50, 0.65))
	settings_content_vbox.add_child(m_card)
	var m_row := HBoxContainer.new()
	m_row.add_theme_constant_override("separation", 16)
	m_card.add_child(m_row)
	m_row.add_child(_make_outlined_label("🔊 全局主音量 (Master Volume):", 14, Color.WHITE))
	var m_slider := HSlider.new()
	m_slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	m_slider.min_value = 0.0
	m_slider.max_value = 100.0
	m_slider.step = 1.0
	m_slider.value = m_val * 100.0
	m_row.add_child(m_slider)
	var m_lbl := _make_outlined_label("%d%%" % int(m_val * 100.0), 14, Color(1.0, 0.88, 0.35))
	m_lbl.custom_minimum_size = Vector2(50, 0)
	m_row.add_child(m_lbl)
	m_slider.value_changed.connect(func(v: float):
		m_lbl.text = "%d%%" % int(v)
		GameState.set_setting("master_volume", v / 100.0)
		GameState.apply_all_settings()
	)

	# 2. 音乐音量
	var b_val: float = float(GameState.get_setting("bgm_volume", 0.75))
	var b_card := _make_box(Color(0.16, 0.16, 0.20), Color(0.35, 0.50, 0.65))
	settings_content_vbox.add_child(b_card)
	var b_row := HBoxContainer.new()
	b_row.add_theme_constant_override("separation", 16)
	b_card.add_child(b_row)
	b_row.add_child(_make_outlined_label("🎵 背景音乐音量 (Music BGM):", 14, Color.WHITE))
	var b_slider := HSlider.new()
	b_slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	b_slider.min_value = 0.0
	b_slider.max_value = 100.0
	b_slider.step = 1.0
	b_slider.value = b_val * 100.0
	b_row.add_child(b_slider)
	var b_lbl := _make_outlined_label("%d%%" % int(b_val * 100.0), 14, Color(1.0, 0.88, 0.35))
	b_lbl.custom_minimum_size = Vector2(50, 0)
	b_row.add_child(b_lbl)
	b_slider.value_changed.connect(func(v: float):
		b_lbl.text = "%d%%" % int(v)
		GameState.set_setting("bgm_volume", v / 100.0)
		GameState.apply_all_settings()
	)

	# 3. 战斗音效音量
	var s_val: float = float(GameState.get_setting("sfx_volume", 0.85))
	var s_card := _make_box(Color(0.16, 0.16, 0.20), Color(0.35, 0.50, 0.65))
	settings_content_vbox.add_child(s_card)
	var s_row := HBoxContainer.new()
	s_row.add_theme_constant_override("separation", 16)
	s_card.add_child(s_row)
	s_row.add_child(_make_outlined_label("💥 战斗打击音效 (Sound FX):", 14, Color.WHITE))
	var s_slider := HSlider.new()
	s_slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	s_slider.min_value = 0.0
	s_slider.max_value = 100.0
	s_slider.step = 1.0
	s_slider.value = s_val * 100.0
	s_row.add_child(s_slider)
	var s_lbl := _make_outlined_label("%d%%" % int(s_val * 100.0), 14, Color(1.0, 0.88, 0.35))
	s_lbl.custom_minimum_size = Vector2(50, 0)
	s_row.add_child(s_lbl)
	s_slider.value_changed.connect(func(v: float):
		s_lbl.text = "%d%%" % int(v)
		GameState.set_setting("sfx_volume", v / 100.0)
		GameState.apply_all_settings()
	)
	s_slider.drag_ended.connect(func(_changed: bool):
		SoundManager.play("cannon_light", 0.05, 0.0)
	)

	# 4. 静音与震动开关行
	var toggle_card := _make_box(Color(0.16, 0.16, 0.20), Color(0.35, 0.50, 0.65))
	settings_content_vbox.add_child(toggle_card)
	var t_row := HBoxContainer.new()
	t_row.add_theme_constant_override("separation", 16)
	toggle_card.add_child(t_row)

	var is_muted: bool = bool(GameState.get_setting("muted", false))
	var btn_mute := Button.new()
	btn_mute.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	btn_mute.custom_minimum_size = Vector2(0, 42)
	btn_mute.text = "🔇 已全局静音 (点击恢复音频)" if is_muted else "🔊 声音开启 (正常播放音频)"
	btn_mute.pressed.connect(func():
		var new_m: bool = not bool(GameState.get_setting("muted", false))
		GameState.set_setting("muted", new_m)
		GameState.apply_all_settings()
		_refresh_settings_view()
	)
	t_row.add_child(btn_mute)

	var vib_on: bool = bool(GameState.get_setting("gamepad_vibration", true))
	var btn_vib := Button.new()
	btn_vib.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	btn_vib.custom_minimum_size = Vector2(0, 42)
	btn_vib.text = "📳 手柄马达震动：开启" if vib_on else "📴 手柄马达震动：关闭"
	btn_vib.pressed.connect(func():
		var new_v: bool = not bool(GameState.get_setting("gamepad_vibration", true))
		GameState.set_setting("gamepad_vibration", new_v)
		GameState.apply_all_settings()
		if new_v:
			SoundManager.vibrate(0.4, 0.6, 0.15)
		_refresh_settings_view()
	)
	t_row.add_child(btn_vib)

func _build_settings_display_tab() -> void:
	settings_content_vbox.add_child(_make_outlined_label("🖥️ 画面显示与窗口分辨率 (Display & Resolution)", 18, Color(0.40, 0.95, 1.0)))

	# 1. 窗口模式
	var cur_mode: String = String(GameState.get_setting("window_mode", "fullscreen"))
	var mode_card := _make_box(Color(0.16, 0.16, 0.20), Color(0.35, 0.50, 0.65))
	settings_content_vbox.add_child(mode_card)
	var mv := VBoxContainer.new()
	mv.add_theme_constant_override("separation", 8)
	mode_card.add_child(mv)
	mv.add_child(_make_outlined_label("🖥️ 窗口显示模式 (Display Mode):", 14, Color.WHITE))
	var m_row := HBoxContainer.new()
	m_row.add_theme_constant_override("separation", 12)
	mv.add_child(m_row)

	var btn_fs := Button.new()
	btn_fs.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	btn_fs.custom_minimum_size = Vector2(0, 42)
	btn_fs.text = ("👉 " if cur_mode == "fullscreen" else "") + "🖥️ 全屏模式 (Fullscreen)"
	btn_fs.pressed.connect(func():
		GameState.set_setting("window_mode", "fullscreen")
		GameState.apply_all_settings()
		_refresh_settings_view()
	)
	m_row.add_child(btn_fs)

	var btn_win := Button.new()
	btn_win.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	btn_win.custom_minimum_size = Vector2(0, 42)
	btn_win.text = ("👉 " if cur_mode == "windowed" else "") + "🪟 窗口模式 (Windowed)"
	btn_win.pressed.connect(func():
		GameState.set_setting("window_mode", "windowed")
		GameState.apply_all_settings()
		_refresh_settings_view()
	)
	m_row.add_child(btn_win)

	# 2. 分辨率预设
	var res_card := _make_box(Color(0.16, 0.16, 0.20), Color(0.35, 0.50, 0.65))
	settings_content_vbox.add_child(res_card)
	var rv := VBoxContainer.new()
	rv.add_theme_constant_override("separation", 8)
	res_card.add_child(rv)

	var cur_res: String = String(GameState.get_setting("resolution", "1440x810"))
	rv.add_child(_make_outlined_label("📐 窗口分辨率预设 (在窗口模式生效，全屏时自动匹配屏幕最佳):", 14, Color.WHITE))
	var r_row := HBoxContainer.new()
	r_row.add_theme_constant_override("separation", 8)
	rv.add_child(r_row)

	var res_presets: Array = [
		{"label": "1280×720 (720p)", "val": "1280x720"},
		{"label": "1440×810 (推荐)", "val": "1440x810"},
		{"label": "1600×900 (900p)", "val": "1600x900"},
		{"label": "1920×1080 (1080p)", "val": "1920x1080"},
		{"label": "2560×1440 (2K)", "val": "2560x1440"}
	]

	for rp in res_presets:
		var is_cur_res: bool = (cur_res == rp["val"])
		var r_btn := Button.new()
		r_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		r_btn.custom_minimum_size = Vector2(0, 38)
		r_btn.add_theme_font_size_override("font_size", 12)
		r_btn.text = ("👉 " if is_cur_res else "") + rp["label"]
		if is_cur_res:
			var ds := StyleBoxFlat.new()
			ds.bg_color = Color(0.24, 0.32, 0.42)
			ds.border_color = Color(0.40, 0.95, 1.0)
			ds.set_border_width_all(2)
			ds.set_corner_radius_all(6)
			r_btn.add_theme_stylebox_override("normal", ds)
		r_btn.pressed.connect(func():
			GameState.set_setting("resolution", rp["val"])
			GameState.apply_all_settings()
			_refresh_settings_view()
		)
		r_row.add_child(r_btn)

	# 3. 垂直同步
	var vsync_card := _make_box(Color(0.16, 0.16, 0.20), Color(0.35, 0.50, 0.65))
	settings_content_vbox.add_child(vsync_card)
	var vv := VBoxContainer.new()
	vv.add_theme_constant_override("separation", 8)
	vsync_card.add_child(vv)
	vv.add_child(_make_outlined_label("⚡ 垂直同步 (V-Sync):", 14, Color.WHITE))
	var cur_vsync: bool = bool(GameState.get_setting("vsync", true))
	var v_row := HBoxContainer.new()
	v_row.add_theme_constant_override("separation", 12)
	vv.add_child(v_row)

	var btn_v_on := Button.new()
	btn_v_on.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	btn_v_on.custom_minimum_size = Vector2(0, 40)
	btn_v_on.text = ("👉 " if cur_vsync else "") + "开启垂直同步 (推荐，消除撕裂与显卡负荷)"
	btn_v_on.pressed.connect(func():
		GameState.set_setting("vsync", true)
		GameState.apply_all_settings()
		_refresh_settings_view()
	)
	v_row.add_child(btn_v_on)

	var btn_v_off := Button.new()
	btn_v_off.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	btn_v_off.custom_minimum_size = Vector2(0, 40)
	btn_v_off.text = ("👉 " if not cur_vsync else "") + "关闭垂直同步 (低输入延迟)"
	btn_v_off.pressed.connect(func():
		GameState.set_setting("vsync", false)
		GameState.apply_all_settings()
		_refresh_settings_view()
	)
	v_row.add_child(btn_v_off)

func _build_settings_gameplay_tab() -> void:
	settings_content_vbox.add_child(_make_outlined_label("🎮 游戏体验与无障碍选项 (Gameplay & Accessibility)", 18, Color(0.40, 0.95, 1.0)))

	# 1. 屏幕震动强度
	var cur_shake: float = float(GameState.get_setting("screen_shake_mult", 1.0))
	var s_card := _make_box(Color(0.16, 0.16, 0.20), Color(0.35, 0.50, 0.65))
	settings_content_vbox.add_child(s_card)
	var sv := VBoxContainer.new()
	sv.add_theme_constant_override("separation", 8)
	s_card.add_child(sv)
	sv.add_child(_make_outlined_label("💥 屏幕打击震动强度 (Screen Shake):", 14, Color.WHITE))

	var s_row := HBoxContainer.new()
	s_row.add_theme_constant_override("separation", 10)
	sv.add_child(s_row)

	var shake_options: Array = [
		{"label": "🚫 关闭 (0%)", "val": 0.0},
		{"label": "🌱 轻度 (50%)", "val": 0.5},
		{"label": "💥 标准 (100%)", "val": 1.0},
		{"label": "🔥 狂暴 (150%)", "val": 1.5}
	]
	for opt in shake_options:
		var is_sel: bool = is_equal_approx(cur_shake, opt["val"])
		var btn := Button.new()
		btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		btn.custom_minimum_size = Vector2(0, 38)
		btn.text = ("👉 " if is_sel else "") + opt["label"]
		btn.pressed.connect(func():
			GameState.set_setting("screen_shake_mult", opt["val"])
			_refresh_settings_view()
		)
		s_row.add_child(btn)

	# 2. 伤害飘字与小地图开关
	var g2_card := _make_box(Color(0.16, 0.16, 0.20), Color(0.35, 0.50, 0.65))
	settings_content_vbox.add_child(g2_card)
	var g2_row := HBoxContainer.new()
	g2_row.add_theme_constant_override("separation", 14)
	g2_card.add_child(g2_row)

	var show_dmg: bool = bool(GameState.get_setting("show_damage_numbers", true))
	var btn_dmg := Button.new()
	btn_dmg.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	btn_dmg.custom_minimum_size = Vector2(0, 42)
	btn_dmg.text = "🎯 伤害数值跳字：开启" if show_dmg else "🎯 伤害数值跳字：关闭 (清爽模式)"
	btn_dmg.pressed.connect(func():
		GameState.set_setting("show_damage_numbers", not show_dmg)
		_refresh_settings_view()
	)
	g2_row.add_child(btn_dmg)

	var show_mini: bool = bool(GameState.get_setting("show_minimap", true))
	var btn_mini := Button.new()
	btn_mini.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	btn_mini.custom_minimum_size = Vector2(0, 42)
	btn_mini.text = "📡 右下角战术雷达：开启" if show_mini else "📡 战术雷达：关闭"
	btn_mini.pressed.connect(func():
		GameState.set_setting("show_minimap", not show_mini)
		_refresh_settings_view()
	)
	g2_row.add_child(btn_mini)

	# 3. 主炮开火模式
	var auto_on: bool = bool(GameState.get_setting("auto_main_cannon", true))
	var g3_card := _make_box(Color(0.16, 0.16, 0.20), Color(0.35, 0.50, 0.65))
	settings_content_vbox.add_child(g3_card)
	var g3_row := HBoxContainer.new()
	g3_row.add_theme_constant_override("separation", 14)
	g3_card.add_child(g3_row)

	var btn_auto := Button.new()
	btn_auto.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	btn_auto.custom_minimum_size = Vector2(0, 42)
	btn_auto.text = "🤖 主炮射击模式：全自动索敌开火 [R键切换]" if auto_on else "🎯 主炮射击模式：纯手动瞄准发射 [R键切换]"
	btn_auto.pressed.connect(func():
		GameState.set_setting("auto_main_cannon", not auto_on)
		GameState.apply_all_settings()
		_refresh_settings_view()
	)
	g3_row.add_child(btn_auto)

func _build_settings_controls_tab() -> void:
	settings_content_vbox.add_child(_make_outlined_label("⌨️ 操作指南与完整键位表 (Controls Guide)", 18, Color(0.40, 0.95, 1.0)))

	var grid := HBoxContainer.new()
	grid.add_theme_constant_override("separation", 16)
	settings_content_vbox.add_child(grid)

	# 键盘与鼠标
	var km_box := _make_box(Color(0.15, 0.15, 0.18), Color(0.45, 0.75, 0.95))
	km_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	grid.add_child(km_box)

	var km_v := VBoxContainer.new()
	km_v.add_theme_constant_override("separation", 8)
	km_box.add_child(km_v)
	km_v.add_child(_make_outlined_label("💻 键盘与鼠标布局 (Keyboard & Mouse)", 16, Color(1.0, 0.88, 0.35)))

	var km_keys: Array = [
		{"act": "战车行驶 / 步兵移动", "key": "[W] [A] [S] [D] 或 方向键"},
		{"act": "360° 炮塔旋转瞄准", "key": "移动鼠标光标 (按住右键微调)"},
		{"act": "主炮手动发射", "key": "鼠标左键 [LMB]"},
		{"act": "C装置全弹齐射", "key": "[Q] 键"},
		{"act": "战术机动 (紧急闪避)", "key": "[空格 Space]"},
		{"act": "战车下车 / 步兵肉搏", "key": "[E] 键"},
		{"act": "切换主炮自动/手动", "key": "[R] 键"},
		{"act": "快速音频静音", "key": "[M] 键"},
		{"act": "全屏切换", "key": "[F11] 键"},
		{"act": "战术暂停 / 菜单返回", "key": "[ESC] 键 或 [P] 键"}
	]
	for k in km_keys:
		var r := HBoxContainer.new()
		km_v.add_child(r)
		var al := _make_outlined_label(k["act"], 13, Color(0.85, 0.88, 0.92))
		al.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		r.add_child(al)
		r.add_child(_make_outlined_label(k["key"], 13, Color(0.40, 0.95, 0.65)))

	# 手柄操作
	var pad_box := _make_box(Color(0.15, 0.15, 0.18), Color(0.95, 0.65, 0.35))
	pad_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	grid.add_child(pad_box)

	var pad_v := VBoxContainer.new()
	pad_v.add_theme_constant_override("separation", 8)
	pad_box.add_child(pad_v)
	pad_v.add_child(_make_outlined_label("🎮 游戏手柄布局 (Controller / Steam Deck)", 16, Color(1.0, 0.88, 0.35)))

	var pad_keys: Array = [
		{"act": "战车驾驶 / 步兵走位", "key": "左摇杆 (Left Stick) / 十字键"},
		{"act": "360° 炮塔瞄准", "key": "右摇杆 (Right Stick)"},
		{"act": "主炮手动发射", "key": "右肩键 [RB] 或 右扳机 [RT]"},
		{"act": "C装置全弹齐射", "key": "左肩键 [LB] 或 左扳机 [LT]"},
		{"act": "战术机动 (闪避翻滚)", "key": "[A] 键 或 [B] 键"},
		{"act": "主动战车下车", "key": "[X] 键"},
		{"act": "切换主炮自动/手动", "key": "[Y] 键"},
		{"act": "双马达力反馈震动", "key": "全自动联动打击强弱"},
		{"act": "战术暂停", "key": "[Start] 键"},
		{"act": "菜单确认 / 返回", "key": "[A] 键确认 / [B] 键返回"}
	]
	for k in pad_keys:
		var r := HBoxContainer.new()
		pad_v.add_child(r)
		var al := _make_outlined_label(k["act"], 13, Color(0.85, 0.88, 0.92))
		al.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		r.add_child(al)
		r.add_child(_make_outlined_label(k["key"], 13, Color(1.0, 0.75, 0.35)))
func _build_view_bounties() -> void:
	view_bounties = Control.new()
	view_bounties.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	title_screen.add_child(view_bounties)

	var margin := MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	margin.add_theme_constant_override("margin_left", 24)
	margin.add_theme_constant_override("margin_right", 24)
	margin.add_theme_constant_override("margin_top", 16)
	margin.add_theme_constant_override("margin_bottom", 16)
	view_bounties.add_child(margin)

	var root_vbox := VBoxContainer.new()
	root_vbox.add_theme_constant_override("separation", 12)
	margin.add_child(root_vbox)

	# 顶部导航行
	var top_nav := HBoxContainer.new()
	top_nav.add_theme_constant_override("separation", 14)
	root_vbox.add_child(top_nav)

	var btn_back := _make_styled_button("⬅️ 返回主菜单 [ESC]", 14, Color(0.18, 0.18, 0.22), Color(0.60, 0.60, 0.68), Vector2(160, 36))
	btn_back.pressed.connect(func():
		SoundManager.play("coin", 0.08, -1.0)
		_switch_to_screen(ScreenState.TITLE)
	)
	top_nav.add_child(btn_back)

	var title_lbl := _make_outlined_label("📜 废土猎人办事处 — 绝密赏金首通缉令图鉴", 20, Color(1.0, 0.85, 0.30))
	title_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top_nav.add_child(title_lbl)

	var stats_lbl := _make_outlined_label("已狩猎赏金首: %d 名" % GameState.lifetime_bounties, 15, Color(0.85, 0.90, 0.95))
	top_nav.add_child(stats_lbl)

	# 通缉令卡片网格
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	root_vbox.add_child(scroll)

	bounties_grid = GridContainer.new()
	bounties_grid.columns = 2
	bounties_grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	bounties_grid.size_flags_vertical = Control.SIZE_EXPAND_FILL
	bounties_grid.add_theme_constant_override("h_separation", 14)
	bounties_grid.add_theme_constant_override("v_separation", 14)
	scroll.add_child(bounties_grid)

# ============================================================================
# 界面流转状态切换机
# ============================================================================
func _switch_to_screen(new_state: ScreenState) -> void:
	current_screen = new_state
	view_title.visible = (new_state == ScreenState.TITLE)
	view_select_hunter.visible = (new_state == ScreenState.SELECT_HUNTER)
	view_select_chassis.visible = (new_state == ScreenState.SELECT_CHASSIS)
	view_select_map.visible = (new_state == ScreenState.SELECT_MAP)
	view_meta_lab.visible = (new_state == ScreenState.META_LAB)
	view_bounties.visible = (new_state == ScreenState.BOUNTIES_CODEX)
	view_settings.visible = (new_state == ScreenState.SETTINGS)

	match new_state:
		ScreenState.TITLE:
			_refresh_title_view()
			if is_instance_valid(btn_title_start):
				btn_title_start.call_deferred("grab_focus")
		ScreenState.SELECT_HUNTER:
			_refresh_hunter_view()
			if is_instance_valid(btn_hunter_next):
				btn_hunter_next.call_deferred("grab_focus")
		ScreenState.SELECT_CHASSIS:
			_refresh_chassis_view()
			if is_instance_valid(btn_chassis_next):
				btn_chassis_next.call_deferred("grab_focus")
		ScreenState.SELECT_MAP:
			_refresh_map_view()
			if is_instance_valid(btn_launch_run):
				btn_launch_run.call_deferred("grab_focus")
		ScreenState.META_LAB:
			_refresh_meta_view()
		ScreenState.BOUNTIES_CODEX:
			_refresh_bounties_view()
		ScreenState.SETTINGS:
			_refresh_settings_view()

# ============================================================================
# 各子界面数据填充与刷新
# ============================================================================

# --- 刷新首页 ---
func _refresh_title_view() -> void:
	lbl_title_chips.text = "💎 %d 诺亚晶片" % GameState.noah_chips
	lbl_title_stats.text = "轮回历练:%d次 | 最高波次:%d | 狩猎赏金首:%d名" % [
		GameState.lifetime_runs, GameState.best_wave, GameState.lifetime_bounties
	]

	var h_def: Dictionary = GameData.HUNTERS.get(chosen_hunter, {})
	var c_def: Dictionary = GameData.CHASSIS.get(chosen_chassis, {})
	var m_def: Dictionary = GameData.MAPS[chosen_map_idx]
	var d_def: Dictionary = GameData.DIFFICULTIES[chosen_diff_id]

	lbl_title_resume.text = "🎖️ 领航猎人: %s\n🚜 主战载具: %s\n🗺️ 目标战区: %s\n⚠️ 危险等级: %s" % [
		h_def.get("name", "未选定"),
		c_def.get("name", "未选定"),
		m_def.get("name", "荒原哨所"),
		d_def.get("name", "赏金老兵")
	]

# --- 刷新猎人选择界面 ---
func _refresh_hunter_view() -> void:
	for c in hunter_cards_container.get_children():
		c.queue_free()

	for h_id in GameData.HUNTERS.keys():
		var h_def: Dictionary = GameData.HUNTERS[h_id]
		var unlocked: bool = GameState.is_hunter_unlocked(String(h_id))
		var is_sel: bool = (chosen_hunter == String(h_id))
		var short_name: String = String(h_def["name"]).split(" ")[0]

		var border_col: Color = Color(1.0, 0.88, 0.22) if is_sel else (Color(0.45, 0.50, 0.58) if unlocked else Color(0.26, 0.26, 0.30))
		var bg_col: Color = Color(0.24, 0.20, 0.14) if is_sel else Color(0.15, 0.15, 0.18)
		var card := _make_box(bg_col, border_col, 8, 8)
		card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		card.size_flags_vertical = Control.SIZE_EXPAND_FILL
		hunter_cards_container.add_child(card)

		var cv := VBoxContainer.new()
		cv.alignment = BoxContainer.ALIGNMENT_CENTER
		cv.add_theme_constant_override("separation", 6)
		card.add_child(cv)

		var icon_c := CenterContainer.new()
		cv.add_child(icon_c)
		icon_c.add_child(_make_tex_rect(GameData.get_hunter_tex(String(h_id)), Vector2(76, 76), not unlocked))

		var name_lbl := _make_outlined_label(short_name, 14, Color(1.0, 0.88, 0.35) if is_sel else Color.WHITE)
		name_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		cv.add_child(name_lbl)

		var btn := Button.new()
		btn.custom_minimum_size = Vector2(0, 32)
		btn.add_theme_font_size_override("font_size", 12)
		if is_sel:
			btn.text = "👉 已选定"
		elif unlocked:
			btn.text = "选择此猎人"
		else:
			btn.text = "🔒 解锁 (%d💎)" % int(h_def["unlock_cost"])

		btn.pressed.connect(func():
			chosen_hunter = String(h_id)
			if not unlocked:
				if GameState.unlock_hunter(String(h_id)):
					SoundManager.play("upgrade", 0.04, 2.0)
					lbl_hunter_toast.text = "🎉 成功招募新猎人：【%s】！" % h_def["name"]
				else:
					lbl_hunter_toast.text = "❌ 诺亚晶片不足！招募【%s】需要 %d 💎。" % [h_def["name"], int(h_def["unlock_cost"])]
			else:
				SoundManager.play("coin", 0.08, 0.0)
			_refresh_hunter_view()
		)
		cv.add_child(btn)

	# 刷新右侧猎人详情面板
	for c in hunter_preview_box.get_children():
		c.queue_free()

	var h: Dictionary = GameData.HUNTERS[chosen_hunter]
	var unlocked_sel: bool = GameState.is_hunter_unlocked(chosen_hunter)

	var h_top := HBoxContainer.new()
	h_top.add_theme_constant_override("separation", 14)
	hunter_preview_box.add_child(h_top)

	h_top.add_child(_make_tex_rect(GameData.get_hunter_tex(chosen_hunter), Vector2(96, 96), not unlocked_sel))

	var h_titles := VBoxContainer.new()
	h_titles.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	h_titles.add_theme_constant_override("separation", 4)
	h_top.add_child(h_titles)

	h_titles.add_child(_make_outlined_label("🎖️ 领航猎人档案", 13, Color(0.85, 0.80, 0.65)))
	h_titles.add_child(_make_outlined_label(h["name"], 20, Color(1.0, 0.88, 0.35)))
	h_titles.add_child(_make_outlined_label(h["title"], 14, Color(0.40, 0.92, 1.0)))

	# 详细词条解释卡
	var desc_box := _make_box(Color(0.10, 0.10, 0.12), Color(0.35, 0.38, 0.45))
	desc_box.size_flags_vertical = Control.SIZE_EXPAND_FILL
	hunter_preview_box.add_child(desc_box)

	var desc_lbl := _make_outlined_label(h["desc"], 13, Color(0.55, 1.0, 0.68))
	desc_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	desc_box.add_child(desc_lbl)

	# 招募 / 已就绪按钮状态
	if not unlocked_sel:
		var unlock_btn := _make_styled_button("💎 消耗 %d 晶片立即招募此猎人" % int(h["unlock_cost"]), 15, Color(0.20, 0.45, 0.60), Color(0.40, 0.95, 1.0), Vector2(0, 42))
		unlock_btn.pressed.connect(func():
			if GameState.unlock_hunter(chosen_hunter):
				SoundManager.play("upgrade", 0.04, 2.0)
				lbl_hunter_toast.text = "🎉 成功招募新猎人：【%s】！" % h["name"]
				_refresh_hunter_view()
			else:
				lbl_hunter_toast.text = "❌ 晶片不足！需要 %d 💎。" % int(h["unlock_cost"])
				SoundManager.play("cannon_empty", 0.1, 0.0)
		)
		hunter_preview_box.add_child(unlock_btn)
	else:
		var ready_lbl := _make_outlined_label("✅ 猎人已在格纳库待命，可立即出发！", 14, Color(0.40, 1.0, 0.55))
		ready_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		hunter_preview_box.add_child(ready_lbl)

	btn_hunter_next.disabled = not unlocked_sel

# --- 刷新战车整备界面 ---
func _refresh_chassis_view() -> void:
	for c in chassis_cards_container.get_children():
		c.queue_free()

	for c_id in GameData.CHASSIS.keys():
		var c_def: Dictionary = GameData.CHASSIS[c_id]
		var unlocked: bool = GameState.is_chassis_unlocked(String(c_id))
		var is_sel: bool = (chosen_chassis == String(c_id))
		var short_name: String = String(c_def["name"]).split(" ")[0]

		var border_col: Color = Color(1.0, 0.88, 0.22) if is_sel else (Color(0.45, 0.40, 0.48) if unlocked else Color(0.26, 0.26, 0.30))
		var bg_col: Color = Color(0.24, 0.17, 0.15) if is_sel else Color(0.15, 0.15, 0.18)
		var card := _make_box(bg_col, border_col, 8, 8)
		card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		card.size_flags_vertical = Control.SIZE_EXPAND_FILL
		chassis_cards_container.add_child(card)

		var cv := VBoxContainer.new()
		cv.alignment = BoxContainer.ALIGNMENT_CENTER
		cv.add_theme_constant_override("separation", 6)
		card.add_child(cv)

		var icon_c := CenterContainer.new()
		cv.add_child(icon_c)
		icon_c.add_child(_make_tex_rect(GameData.get_chassis_tex(String(c_id)), Vector2(80, 52), not unlocked))

		var name_lbl := _make_outlined_label(short_name, 13, Color(1.0, 0.88, 0.35) if is_sel else Color.WHITE)
		name_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		cv.add_child(name_lbl)

		var btn := Button.new()
		btn.custom_minimum_size = Vector2(0, 30)
		btn.add_theme_font_size_override("font_size", 11)
		if is_sel:
			btn.text = "👉 已选定"
		elif unlocked:
			btn.text = "选择此战车"
		else:
			btn.text = "🔒 修复(%d💎)" % int(c_def["unlock_cost"])

		btn.pressed.connect(func():
			chosen_chassis = String(c_id)
			if not unlocked:
				if GameState.unlock_chassis(String(c_id)):
					SoundManager.play("upgrade", 0.04, 2.0)
					lbl_chassis_toast.text = "🎉 成功修复战车底盘：【%s】！" % c_def["name"]
				else:
					lbl_chassis_toast.text = "❌ 晶片不足！修复【%s】需要 %d 💎。" % [c_def["name"], int(c_def["unlock_cost"])]
			else:
				SoundManager.play("coin", 0.08, 0.0)
			_refresh_chassis_view()
		)
		cv.add_child(btn)

	# 刷新右侧战车详情面板
	for c in chassis_preview_box.get_children():
		c.queue_free()

	var ch: Dictionary = GameData.CHASSIS[chosen_chassis]
	var unlocked_sel: bool = GameState.is_chassis_unlocked(chosen_chassis)

	var c_top := HBoxContainer.new()
	c_top.add_theme_constant_override("separation", 14)
	chassis_preview_box.add_child(c_top)

	c_top.add_child(_make_tex_rect(GameData.get_chassis_tex(chosen_chassis), Vector2(120, 72), not unlocked_sel))

	var c_titles := VBoxContainer.new()
	c_titles.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	c_titles.add_theme_constant_override("separation", 4)
	c_top.add_child(c_titles)

	c_titles.add_child(_make_outlined_label("🚜 战车底盘蓝图", 13, Color(0.85, 0.80, 0.65)))
	c_titles.add_child(_make_outlined_label(ch["name"], 20, Color(1.0, 0.58, 0.35)))

	# 槽位彩色徽章行
	var slot_badges: Array = []
	for s in ch["slots"]:
		slot_badges.append("🔴主炮" if s == "MAIN" else ("🟡副炮" if s == "SUB" else "🔵S-E"))
	c_titles.add_child(_make_outlined_label("孔位配置: " + " ".join(slot_badges), 13, Color(0.95, 0.88, 0.45)))

	# 装甲转化率条 & 极速自重条
	var sp_rate: float = float(ch.get("sp_per_ton", 20.0))
	var sp_bar_d: Dictionary = _create_bar(Vector2(0, 20), Color(0.22, 0.82, 0.40), 12, sp_rate, 32.0)
	sp_bar_d["label"].text = "🛡️ 装甲转化率: %.0f SP / 吨" % sp_rate
	chassis_preview_box.add_child(sp_bar_d["container"])

	var wt_val: float = float(ch.get("base_weight", 6.0))
	var wt_bar_d: Dictionary = _create_bar(Vector2(0, 20), Color(0.88, 0.58, 0.20), 12, wt_val, 16.0)
	wt_bar_d["label"].text = "⚖️ 底盘自重: %.1f 吨  |  🚜 移速: %.0f" % [wt_val, float(ch.get("speed", 220.0))]
	chassis_preview_box.add_child(wt_bar_d["container"])

	# 特技说明
	var desc_box := _make_box(Color(0.10, 0.10, 0.12), Color(0.35, 0.38, 0.45))
	desc_box.size_flags_vertical = Control.SIZE_EXPAND_FILL
	chassis_preview_box.add_child(desc_box)

	var desc_lbl := _make_outlined_label(ch["desc"], 13, Color(0.88, 0.92, 0.95))
	desc_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	desc_box.add_child(desc_lbl)

	# 修复 / 就绪状态
	if not unlocked_sel:
		var unlock_btn := _make_styled_button("💎 消耗 %d 晶片修复此战车底盘" % int(ch["unlock_cost"]), 15, Color(0.40, 0.22, 0.20), Color(1.0, 0.55, 0.38), Vector2(0, 42))
		unlock_btn.pressed.connect(func():
			if GameState.unlock_chassis(chosen_chassis):
				SoundManager.play("upgrade", 0.04, 2.0)
				lbl_chassis_toast.text = "🎉 成功修复战车底盘：【%s】！" % ch["name"]
				_refresh_chassis_view()
			else:
				lbl_chassis_toast.text = "❌ 晶片不足！需要 %d 💎。" % int(ch["unlock_cost"])
				SoundManager.play("cannon_empty", 0.1, 0.0)
		)
		chassis_preview_box.add_child(unlock_btn)
	else:
		var ready_lbl := _make_outlined_label("✅ 战车已在整备车位就绪，油料弹药满载！", 14, Color(0.40, 1.0, 0.55))
		ready_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		chassis_preview_box.add_child(ready_lbl)

	btn_chassis_next.disabled = not unlocked_sel

# --- 刷新目标战区与危险度界面 ---
func _refresh_map_view() -> void:
	for c in maps_cards_container.get_children():
		c.queue_free()

	for i in range(GameData.MAPS.size()):
		var m_def: Dictionary = GameData.MAPS[i]
		var is_unlocked: bool = (i < GameState.unlocked_map_count)
		var is_sel: bool = (chosen_map_idx == i)
		var fin_b: Dictionary = GameData.get_boss_by_id(m_def["final_boss_id"])

		var cleared_list: Array = GameState.map_cleared_difficulties.get(m_def["id"], [])
		var badges: Array = []
		if "easy" in cleared_list:
			badges.append("🟢简单")
		if "normal" in cleared_list:
			badges.append("🟡老兵")
		if "hell" in cleared_list:
			badges.append("🔴地狱")
		var badge_str: String = (" [" + " ".join(badges) + "]") if not badges.is_empty() else ""

		var card_bg: Color = Color(0.20, 0.24, 0.20) if is_sel else Color(0.14, 0.15, 0.17)
		var card_border: Color = Color(0.40, 1.0, 0.55) if is_sel else (Color(0.35, 0.45, 0.40) if is_unlocked else Color(0.24, 0.24, 0.28))
		var card := _make_box(card_bg, card_border, 8, 8)
		maps_cards_container.add_child(card)

		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 12)
		card.add_child(row)

		row.add_child(_make_tex_rect(GameData.get_terrain_tex(String(m_def["id"])), Vector2(64, 52), not is_unlocked))
		row.add_child(_make_tex_rect(GameData.get_boss_tex(String(m_def["final_boss_id"])), Vector2(68, 52), not is_unlocked))

		var info_v := VBoxContainer.new()
		info_v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		info_v.add_theme_constant_override("separation", 3)
		row.add_child(info_v)

		var title_txt: String = ("👉 " if is_sel else "") + ("✅ " if is_unlocked else "🔒 ") + m_def["name"] + badge_str
		info_v.add_child(_make_outlined_label(title_txt, 15, Color(1.0, 0.88, 0.35) if is_sel else Color.WHITE))

		if is_unlocked:
			var sub_txt: String = "波次: %d波 | 关底统帅: %s | 晶片收益倍率: ×%.1f" % [
				int(m_def["waves"]), fin_b["name"].split(" ")[0], float(m_def["chip_mult"])
			]
			info_v.add_child(_make_outlined_label(sub_txt, 12, Color(0.75, 0.88, 0.80)))
		else:
			info_v.add_child(_make_outlined_label("需通关上一章节战区解锁！", 12, Color(0.75, 0.45, 0.45)))

		var sel_btn := Button.new()
		sel_btn.custom_minimum_size = Vector2(96, 36)
		sel_btn.text = "选定" if is_sel else ("选择" if is_unlocked else "未解锁")
		sel_btn.disabled = not is_unlocked
		sel_btn.pressed.connect(func():
			chosen_map_idx = i
			SoundManager.play("coin", 0.08, 0.0)
			_refresh_map_view()
		)
		row.add_child(sel_btn)

	# 刷新右侧危险等级与出击总览
	for c in map_preview_box.get_children():
		c.queue_free()

	map_preview_box.add_child(_make_outlined_label("⚠️ 设定战区危险等级 (Hazard Level)", 16, Color(1.0, 0.85, 0.35)))

	# 难度三档切换按钮行
	var diff_row := HBoxContainer.new()
	diff_row.add_theme_constant_override("separation", 8)
	map_preview_box.add_child(diff_row)

	for d_id in ["easy", "normal", "hell"]:
		var d_def: Dictionary = GameData.DIFFICULTIES[d_id]
		var is_sel_d: bool = (chosen_diff_id == d_id)
		var d_btn := Button.new()
		d_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		d_btn.custom_minimum_size = Vector2(0, 38)
		d_btn.add_theme_font_size_override("font_size", 13)
		d_btn.text = ("👉 " if is_sel_d else "") + d_def["name"]
		if is_sel_d:
			var ds := StyleBoxFlat.new()
			ds.bg_color = Color(0.24, 0.24, 0.30)
			ds.border_color = d_def["color"]
			ds.set_border_width_all(2)
			ds.set_corner_radius_all(6)
			d_btn.add_theme_stylebox_override("normal", ds)
		d_btn.pressed.connect(func():
			chosen_diff_id = d_id
			SoundManager.play("coin", 0.08, 0.0)
			_refresh_map_view()
		)
		diff_row.add_child(d_btn)

	var d: Dictionary = GameData.DIFFICULTIES[chosen_diff_id]
	var d_desc := _make_outlined_label(d["desc"], 12, d["color"])
	d_desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	map_preview_box.add_child(d_desc)

	map_preview_box.add_child(HSeparator.new())

	# 出击编队一览总结
	var m: Dictionary = GameData.MAPS[chosen_map_idx]
	var fin_boss: Dictionary = GameData.get_boss_by_id(m["final_boss_id"])
	var total_chip_mult: float = float(m["chip_mult"]) * float(d["chip_mult"])

	var sum_box := _make_box(Color(0.10, 0.10, 0.12), Color(0.35, 0.40, 0.48))
	sum_box.size_flags_vertical = Control.SIZE_EXPAND_FILL
	map_preview_box.add_child(sum_box)

	var sum_v := VBoxContainer.new()
	sum_v.add_theme_constant_override("separation", 6)
	sum_box.add_child(sum_v)

	sum_v.add_child(_make_outlined_label("📋 本次出击编队配置总览：", 14, Color(1.0, 0.88, 0.35)))
	sum_v.add_child(_make_outlined_label("🎖️ 领航猎人: %s" % GameData.HUNTERS[chosen_hunter]["name"], 13, Color(0.85, 0.90, 0.95)))
	sum_v.add_child(_make_outlined_label("🚜 主战载具: %s" % GameData.CHASSIS[chosen_chassis]["name"], 13, Color(0.85, 0.90, 0.95)))
	sum_v.add_child(_make_outlined_label("🗺️ 目标战区: %s (共 %d 波次)" % [m["name"], int(m["waves"])], 13, Color(0.45, 0.95, 0.65)))
	sum_v.add_child(_make_outlined_label("🎯 关底统帅: %s" % fin_boss["name"], 13, Color(1.0, 0.45, 0.40)))
	sum_v.add_child(_make_outlined_label("💎 综合晶片收益: ×%.2f 倍" % total_chip_mult, 13, Color(0.40, 0.95, 1.0)))

	# 大号出击按钮
	btn_launch_run = _make_styled_button("🔥 发动战车引擎 · 立即出击！ [Enter / Space] 🔥", 18, Color(0.80, 0.28, 0.16), Color(1.0, 0.88, 0.35), Vector2(0, 52))
	btn_launch_run.pressed.connect(_on_start_run_pressed)
	map_preview_box.add_child(btn_launch_run)

# --- 刷新局外科技改造所 ---
func _refresh_meta_view() -> void:
	lbl_meta_chips.text = "💎 %d 晶片" % GameState.noah_chips

	# 1. 废铁镇基建工程
	for c in meta_features_vbox.get_children():
		c.queue_free()
	meta_features_vbox.add_child(_make_outlined_label("🏗️ 废铁镇基建工程 (局内设施与功能特权)", 16, Color(0.45, 0.92, 1.0)))

	for f_def in GameData.META_FEATURES:
		var f_id: String = f_def["id"]
		var unlocked: bool = GameState.is_feature_unlocked(f_id)
		var card := _make_box(Color(0.17, 0.18, 0.22), Color(0.35, 0.90, 0.55) if unlocked else Color(0.42, 0.45, 0.50))
		meta_features_vbox.add_child(card)

		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 10)
		card.add_child(row)

		var lbl := _make_outlined_label("%s\n%s" % [f_def["name"], f_def["desc"]], 12, Color(0.65, 1.0, 0.75) if unlocked else Color(0.90, 0.90, 0.90))
		lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		row.add_child(lbl)

		var btn := Button.new()
		btn.custom_minimum_size = Vector2(110, 38)
		btn.disabled = unlocked
		btn.text = "✅ 已激活" if unlocked else "激活 💎%d" % int(f_def["cost"])
		btn.pressed.connect(func():
			if GameState.unlock_feature(f_id):
				SoundManager.play("upgrade", 0.04, 2.0)
				lbl_meta_toast.text = "🎉 已永久解锁【%s】！" % f_def["name"]
				_refresh_meta_view()
			else:
				lbl_meta_toast.text = "❌ 诺亚晶片不足，需要 %d 💎！" % int(f_def["cost"])
				SoundManager.play("cannon_empty", 0.1, 0.0)
		)
		row.add_child(btn)

	# 2. 永久数值科技树 (带进度条)
	for c in meta_upgrades_vbox.get_children():
		c.queue_free()
	meta_upgrades_vbox.add_child(_make_outlined_label("🧬 明奇与多拉姆改造所 (永久属性科技树)", 16, Color(0.90, 0.60, 1.0)))

	for u_def in GameData.META_UPGRADES:
		var u_id: String = u_def["id"]
		var lv: int = GameState.get_meta_level(u_id)
		var max_lv: int = int(u_def["max_lv"])
		var is_max: bool = (lv >= max_lv)
		var cost: int = GameState.get_meta_upgrade_cost(u_def)

		var card := _make_box(Color(0.18, 0.17, 0.22), Color(0.85, 0.65, 1.0) if lv > 0 else Color(0.42, 0.40, 0.48))
		meta_upgrades_vbox.add_child(card)

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

		var bar_d: Dictionary = _create_bar(Vector2(140, 16), Color(0.75, 0.42, 0.98), 11, float(lv), float(max_lv))
		bar_d["label"].text = "Lv. %d / %d" % [lv, max_lv]
		title_row.add_child(bar_d["container"])

		var dl := _make_outlined_label(u_def["desc_per_lv"], 12, Color(0.82, 0.85, 0.90))
		dl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		info_v.add_child(dl)

		var btn := Button.new()
		btn.custom_minimum_size = Vector2(110, 38)
		btn.disabled = is_max
		btn.text = "🌟 MAX" if is_max else "强化 💎%d" % cost
		btn.pressed.connect(func():
			if GameState.upgrade_meta_stat(u_id):
				SoundManager.play("upgrade", 0.06, 1.5)
				lbl_meta_toast.text = "⚡ 【%s】已强化至 Lv.%d！" % [u_def["name"], lv + 1]
				_refresh_meta_view()
			else:
				lbl_meta_toast.text = "❌ 诺亚晶片不足，需要 %d 💎！" % cost
				SoundManager.play("cannon_empty", 0.1, 0.0)
		)
		row.add_child(btn)

# --- 刷新赏金首绝密通缉档案 ---
func _refresh_bounties_view() -> void:
	for c in bounties_grid.get_children():
		c.queue_free()

	for b_def in GameData.WANTED_BOSSES:
		var card := _make_box(Color(0.14, 0.13, 0.16), Color(0.75, 0.58, 0.25))
		card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		bounties_grid.add_child(card)

		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 12)
		card.add_child(row)

		row.add_child(_make_tex_rect(GameData.get_boss_tex(String(b_def["id"])), Vector2(80, 70)))

		var info_v := VBoxContainer.new()
		info_v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		info_v.add_theme_constant_override("separation", 3)
		row.add_child(info_v)

		var star_str: String = "★".repeat(int(b_def.get("stars", 1)))
		info_v.add_child(_make_outlined_label("💀 通缉犯：%s (%s)" % [b_def["name"], star_str], 15, Color(1.0, 0.88, 0.35)))

		var bounty_str: String = "💰 赏金: %d G  |  HP: %.0f  |  装甲: %.0f  |  移速: %.0f" % [
			int(b_def["bounty"]), float(b_def["hp"]), float(b_def["armor"]), float(b_def["speed"])
		]
		info_v.add_child(_make_outlined_label(bounty_str, 12, Color(0.45, 0.95, 1.0)))

		var threat_str: String = "特技威胁: %s (出没波次: 第 %d 波起)" % [
			b_def.get("desc", "废土极度危险的生化重装统帅"), int(b_def.get("min_wave", 3))
		]
		var tl := _make_outlined_label(threat_str, 12, Color(0.85, 0.88, 0.90))
		tl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		info_v.add_child(tl)

# ============================================================================
# 无损重置所有科技点与晶片返还
# ============================================================================
func _refund_all_meta_tech() -> void:
	var total_refund: int = 0

	# 1. 返还基建工程消耗
	for f_id in GameState.unlocked_features:
		for f_def in GameData.META_FEATURES:
			if f_def["id"] == f_id:
				total_refund += int(f_def["cost"])
	GameState.unlocked_features.clear()

	# 2. 返还属性强化消耗
	for u_def in GameData.META_UPGRADES:
		var u_id: String = u_def["id"]
		var lv: int = GameState.get_meta_level(u_id)
		var base_cost: int = int(u_def["base_cost"])
		var step: int = int(u_def["cost_step"])
		for i in range(lv):
			total_refund += base_cost + i * step

	GameState.meta_upgrade_levels.clear()
	GameState.noah_chips += total_refund
	GameState.save_meta_data()

	SoundManager.play("upgrade", 0.05, 1.2)
	lbl_meta_toast.text = "🎉 已全额重置所有科技点，成功返还 %d 💎 诺亚晶片！" % total_refund
	_refresh_meta_view()

# ============================================================================
# 明奇博士战绩与晶片结算弹窗
# ============================================================================
func _build_mince_modal() -> void:
	mince_modal = Control.new()
	mince_modal.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mince_modal.visible = false
	ui_layer.add_child(mince_modal)

	var overlay := ColorRect.new()
	overlay.color = Color(0.04, 0.04, 0.06, 0.92)
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
	btn_restart.text = "🚜 返回【主菜单】"
	btn_restart.add_theme_font_size_override("font_size", 16)
	btn_restart.pressed.connect(func(): _show_title_screen(false))
	bot_row.add_child(btn_restart)

# ============================================================================
# 战斗循环触发与返回
# ============================================================================
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

	# 土豆兄弟 / 吸血鬼幸存者风格：战后武装伤害统计与输出排行 (DPS Meter)
	var sorted_dmg: Array = GameState.get_sorted_weapon_damage()
	if not sorted_dmg.is_empty():
		mince_stats_vbox.add_child(HSeparator.new())
		var dps_header := _make_outlined_label("🏆 本局武装伤害排行 (DPS Meter)", 15, Color(1.0, 0.85, 0.25))
		mince_stats_vbox.add_child(dps_header)

		for item in sorted_dmg:
			var r := HBoxContainer.new()
			mince_stats_vbox.add_child(r)
			var nl := _make_outlined_label("%s %s" % [item["slot_badge"], item["name"]], 13, item["color"])
			nl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			r.add_child(nl)
			var dl := _make_outlined_label("%.0f 伤害 (%.1f%%)" % [item["damage"], item["pct"]], 13, Color(0.92, 0.92, 0.95))
			r.add_child(dl)

func _add_settle_row(k_str: String, v_str: String, v_col: Color) -> void:
	var r := HBoxContainer.new()
	mince_stats_vbox.add_child(r)
	var kl := _make_outlined_label(k_str, 14, Color(0.88, 0.88, 0.92))
	kl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	r.add_child(kl)
	var vl := _make_outlined_label(v_str, 15, v_col)
	r.add_child(vl)

func _show_title_screen(open_meta_tab: bool = false) -> void:
	battlefield.visible = false
	battlefield.hud_layer.visible = false
	garage_ui.visible = false
	mince_modal.visible = false
	title_screen.visible = true
	SoundManager.play_bgm("bgm_camp_garage")
	_switch_to_screen(ScreenState.META_LAB if open_meta_tab else ScreenState.TITLE)

func _toggle_fullscreen() -> void:
	var mode: int = DisplayServer.window_get_mode()
	if mode == DisplayServer.WINDOW_MODE_FULLSCREEN or mode == DisplayServer.WINDOW_MODE_EXCLUSIVE_FULLSCREEN:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
	else:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN)

# ============================================================================
# 按键与手柄返回逐级流转导航
# ============================================================================
func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("toggle_fullscreen"):
		get_viewport().set_input_as_handled()
		_toggle_fullscreen()
		return

	if not is_instance_valid(title_screen) or not title_screen.visible:
		return

	# ESC / 返回键逐级流转
	if event.is_action_pressed("ui_cancel") or (event is InputEventKey and event.pressed and event.keycode == KEY_ESCAPE):
		get_viewport().set_input_as_handled()
		match current_screen:
			ScreenState.SELECT_HUNTER:
				SoundManager.play("coin", 0.08, -1.0)
				_switch_to_screen(ScreenState.TITLE)
			ScreenState.SELECT_CHASSIS:
				SoundManager.play("coin", 0.08, -1.0)
				_switch_to_screen(ScreenState.SELECT_HUNTER)
			ScreenState.SELECT_MAP:
				SoundManager.play("coin", 0.08, -1.0)
				_switch_to_screen(ScreenState.SELECT_CHASSIS)
			ScreenState.META_LAB, ScreenState.BOUNTIES_CODEX, ScreenState.SETTINGS:
				SoundManager.play("coin", 0.08, -1.0)
				_switch_to_screen(ScreenState.TITLE)
			ScreenState.TITLE:
				pass
		return

	# 在战区选择界面按 Enter 或手柄 Start 快速出击
	if (event.is_action_pressed("gamepad_start") or event.is_action_pressed("ui_accept")) and current_screen == ScreenState.SELECT_MAP:
		if is_instance_valid(btn_launch_run) and not btn_launch_run.disabled:
			get_viewport().set_input_as_handled()
			_on_start_run_pressed()

# ============================================================================
# UI 样式与结构辅助构造函数
# ============================================================================
func _make_breadcrumbs(step_idx: int, h_id: String, c_id: String) -> Control:
	var hbox := HBoxContainer.new()
	hbox.add_theme_constant_override("separation", 8)

	var h_name: String = GameData.HUNTERS.get(h_id, {}).get("name", "").split(" ")[0]
	var c_name: String = GameData.CHASSIS.get(c_id, {}).get("name", "").split(" ")[0]

	var steps_info: Array = [
		{"num": 1, "title": "① 猎人选择", "tag": "✓ " + h_name},
		{"num": 2, "title": "② 战车改装", "tag": "✓ " + c_name},
		{"num": 3, "title": "③ 战区与危险度", "tag": "目标战区"}
	]

	for i in range(steps_info.size()):
		var s: Dictionary = steps_info[i]
		var s_num: int = s["num"]
		var is_active: bool = (s_num == step_idx)
		var is_past: bool = (s_num < step_idx)

		var pill := PanelContainer.new()
		var p_style := StyleBoxFlat.new()
		p_style.set_corner_radius_all(14)
		p_style.content_margin_left = 12
		p_style.content_margin_right = 12
		p_style.content_margin_top = 4
		p_style.content_margin_bottom = 4

		if is_active:
			p_style.bg_color = Color(0.85, 0.40, 0.15)
			p_style.border_color = Color(1.0, 0.88, 0.35)
			p_style.set_border_width_all(2)
		elif is_past:
			p_style.bg_color = Color(0.18, 0.28, 0.22)
			p_style.border_color = Color(0.35, 0.85, 0.50)
			p_style.set_border_width_all(1)
		else:
			p_style.bg_color = Color(0.15, 0.15, 0.18)
			p_style.border_color = Color(0.30, 0.30, 0.35)
			p_style.set_border_width_all(1)

		pill.add_theme_stylebox_override("panel", p_style)
		hbox.add_child(pill)

		var lbl_txt: String = s["title"] if (is_active or not is_past) else s["tag"]
		var lbl_col: Color = Color.WHITE if is_active else (Color(0.50, 0.95, 0.65) if is_past else Color(0.55, 0.55, 0.60))
		pill.add_child(_make_outlined_label(lbl_txt, 13, lbl_col))

		if i < steps_info.size() - 1:
			var arrow := _make_outlined_label("▶", 11, Color(0.40, 0.42, 0.48))
			hbox.add_child(arrow)

	return hbox

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

func _make_box(bg_col: Color, border_col: Color, corner_r: int = 8, pad: int = 10) -> PanelContainer:
	var p := PanelContainer.new()
	var s := StyleBoxFlat.new()
	s.bg_color = bg_col
	s.border_color = border_col
	s.set_border_width_all(2)
	s.set_corner_radius_all(corner_r)
	s.content_margin_left = pad
	s.content_margin_right = pad
	s.content_margin_top = pad
	s.content_margin_bottom = pad
	p.add_theme_stylebox_override("panel", s)
	return p

func _make_styled_button(txt: String, font_sz: int, bg_col: Color, border_col: Color, min_sz: Vector2) -> Button:
	var btn := Button.new()
	btn.text = txt
	btn.custom_minimum_size = min_sz
	btn.add_theme_font_size_override("font_size", font_sz)

	var normal_s := StyleBoxFlat.new()
	normal_s.bg_color = bg_col
	normal_s.border_color = border_col
	normal_s.set_border_width_all(2)
	normal_s.set_corner_radius_all(8)
	btn.add_theme_stylebox_override("normal", normal_s)

	var hover_s := normal_s.duplicate()
	hover_s.bg_color = bg_col.lightened(0.20)
	hover_s.border_color = border_col.lightened(0.25)
	btn.add_theme_stylebox_override("hover", hover_s)
	btn.add_theme_stylebox_override("focus", hover_s)

	var pressed_s := normal_s.duplicate()
	pressed_s.bg_color = bg_col.darkened(0.15)
	btn.add_theme_stylebox_override("pressed", pressed_s)

	return btn

func _make_tex_rect(tex: Texture2D, min_sz: Vector2, darkened: bool = false) -> TextureRect:
	var tr := TextureRect.new()
	tr.texture = tex
	tr.custom_minimum_size = min_sz
	tr.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	tr.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	if darkened:
		tr.modulate = Color(0.35, 0.35, 0.38, 0.85)
	return tr
