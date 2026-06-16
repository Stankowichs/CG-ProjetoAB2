extends Control

## Tela de início do jogo: título, e quatro opções
## (Jogar, Comandos, Créditos, Sair). Os painéis de Comandos e
## Créditos são construídos por código e alternados via visibilidade.

const MAIN_SCENE_PATH := "res://scenes/Main.tscn"
const MAIN_SCENE := preload("res://scenes/Main.tscn")
const BLUR_SHADER := preload("res://shaders/menu_blur.gdshader")
const GAME_TITLE := "Hulk World Cup"

## Lista de comandos exibida na tela "Comandos": [tecla, descrição].
const CONTROLS := [
	["W  A  S  D", "Mover o jogador"],
	["Shift", "Correr"],
	["L", "Controlar / conduzir a bola"],
	["K  ou  Botão esquerdo do mouse", "Carregar e chutar"],
	["J", "Desarme (carrinho)"],
	["R", "Reiniciar a partida"],
]

const CREDITS := [
	"Hugo Stankowich",
	"Lucca Paes",
	"Renato Coca",
]

var _menu_panel: Control
var _controls_panel: Control
var _credits_panel: Control


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE

	_add_background()
	_build_main_menu()
	_build_controls_panel()
	_build_credits_panel()
	_show_main_menu()


# --------------------------------------------------------------------------
# Construção da UI
# --------------------------------------------------------------------------

func _add_background() -> void:
	# Renderiza a cena do jogo (viva) num SubViewport e a exibe atrás do
	# menu com um shader de blur, criando um fundo "do jogo, desfocado".
	var viewport := SubViewport.new()
	viewport.own_world_3d = true
	viewport.transparent_bg = false
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	viewport.size = Vector2i(1280, 720)
	add_child(viewport)

	var game := MAIN_SCENE.instantiate()
	viewport.add_child(game)
	# Silencia a partida que roda ao fundo (torcida, apito, gol, etc.).
	_mute_audio(game)

	var tex := TextureRect.new()
	tex.set_anchors_preset(Control.PRESET_FULL_RECT)
	tex.texture = viewport.get_texture()
	tex.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	tex.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	tex.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var mat := ShaderMaterial.new()
	mat.shader = BLUR_SHADER
	mat.set_shader_parameter("blur_radius", 3.0)
	tex.material = mat
	add_child(tex)

	# Escurece levemente o fundo para o texto do menu ficar legível.
	var overlay := ColorRect.new()
	overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	overlay.color = Color(0.0, 0.0, 0.0, 0.45)
	overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(overlay)


## Zera o volume de todos os AudioStreamPlayer da cena de fundo, de modo
## que tocadas futuras (gols, apitos) também permaneçam mudas.
func _mute_audio(node: Node) -> void:
	if node is AudioStreamPlayer or node is AudioStreamPlayer2D or node is AudioStreamPlayer3D:
		node.volume_db = -80.0
		node.stop()
	for child in node.get_children():
		_mute_audio(child)


func _build_main_menu() -> void:
	_menu_panel = _make_centered_container()
	add_child(_menu_panel)

	var vbox := VBoxContainer.new()
	vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	vbox.add_theme_constant_override("separation", 18)
	_menu_panel.add_child(vbox)

	var title := Label.new()
	title.text = GAME_TITLE
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 80)
	title.add_theme_color_override("font_color", Color(1.0, 0.95, 0.55))
	vbox.add_child(title)

	var spacer := Control.new()
	spacer.custom_minimum_size = Vector2(0, 40)
	vbox.add_child(spacer)

	vbox.add_child(_make_button("Jogar", _on_play_pressed))
	vbox.add_child(_make_button("Comandos", _on_controls_pressed))
	vbox.add_child(_make_button("Créditos", _on_credits_pressed))
	vbox.add_child(_make_button("Sair", _on_quit_pressed))


func _build_controls_panel() -> void:
	_controls_panel = _make_centered_container()
	add_child(_controls_panel)

	var vbox := VBoxContainer.new()
	vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	vbox.add_theme_constant_override("separation", 14)
	_controls_panel.add_child(vbox)

	vbox.add_child(_make_heading("Comandos"))

	var grid := GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", 40)
	grid.add_theme_constant_override("v_separation", 12)
	vbox.add_child(grid)

	for entry in CONTROLS:
		var key_label := Label.new()
		key_label.text = entry[0]
		key_label.add_theme_font_size_override("font_size", 26)
		key_label.add_theme_color_override("font_color", Color(1.0, 0.85, 0.3))
		grid.add_child(key_label)

		var desc_label := Label.new()
		desc_label.text = entry[1]
		desc_label.add_theme_font_size_override("font_size", 26)
		grid.add_child(desc_label)

	var spacer := Control.new()
	spacer.custom_minimum_size = Vector2(0, 30)
	vbox.add_child(spacer)

	vbox.add_child(_make_button("Voltar", _show_main_menu))


func _build_credits_panel() -> void:
	_credits_panel = _make_centered_container()
	add_child(_credits_panel)

	var vbox := VBoxContainer.new()
	vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	vbox.add_theme_constant_override("separation", 16)
	_credits_panel.add_child(vbox)

	vbox.add_child(_make_heading("Créditos"))

	for credit_name in CREDITS:
		var label := Label.new()
		label.text = credit_name
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		label.add_theme_font_size_override("font_size", 34)
		vbox.add_child(label)

	var spacer := Control.new()
	spacer.custom_minimum_size = Vector2(0, 30)
	vbox.add_child(spacer)

	vbox.add_child(_make_button("Voltar", _show_main_menu))


# --------------------------------------------------------------------------
# Helpers
# --------------------------------------------------------------------------

func _make_centered_container() -> CenterContainer:
	var c := CenterContainer.new()
	c.set_anchors_preset(Control.PRESET_FULL_RECT)
	return c


func _make_heading(text: String) -> Label:
	var label := Label.new()
	label.text = text
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", 56)
	label.add_theme_color_override("font_color", Color(1.0, 0.95, 0.55))
	return label


func _make_button(text: String, callback: Callable) -> Button:
	var button := Button.new()
	button.text = text
	button.custom_minimum_size = Vector2(320, 56)
	button.add_theme_font_size_override("font_size", 30)
	button.pressed.connect(callback)
	return button


func _show_main_menu() -> void:
	_menu_panel.visible = true
	_controls_panel.visible = false
	_credits_panel.visible = false


# --------------------------------------------------------------------------
# Ações dos botões
# --------------------------------------------------------------------------

func _on_play_pressed() -> void:
	get_tree().change_scene_to_file(MAIN_SCENE_PATH)


func _on_controls_pressed() -> void:
	_menu_panel.visible = false
	_controls_panel.visible = true
	_credits_panel.visible = false


func _on_credits_pressed() -> void:
	_menu_panel.visible = false
	_controls_panel.visible = false
	_credits_panel.visible = true


func _on_quit_pressed() -> void:
	get_tree().quit()
