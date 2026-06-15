@tool
extends Node3D

## Torcida nas arquibancadas, assentada na geometria REAL do stadium.glb.
##
## O bowl do estádio foi mapeado (parse dos vértices do GLB): é uma elipse
## inclinada (rake) centrada em ~(-1.5, 0). A borda interna dos assentos é mais
## perto nas laterais (eixo Z) do que atrás dos gols (eixo X), e sobe/recua com a
## altura. Os painéis (billboards de torcida) são distribuídos sobre essa
## superfície elíptica, em anéis que sobem do fundo ao topo de cada tier, sempre
## voltados para o centro do campo.

const PANEL_PREFIX := "CrowdPanel_"
const TEXTURE_SIZE := Vector2i(1024, 256)

@export_group("Geometria do bowl (medida do GLB)")
## Centro do bowl no mundo (o gramado fica centrado aqui).
@export var bowl_center: Vector3 = Vector3(-1.5, 0.0, 0.0)
## Desloca todos os assentos radialmente pra fora da borda interna, pra ficarem
## sobre os degraus e não no muro/lip da frente.
@export var seat_radial_offset: float = 1.5

@export_group("Tier inferior")
@export var lower_enabled: bool = true
@export var lower_rows: int = 7
@export var lower_y_bottom: float = 4.5
@export var lower_y_top: float = 29.0
@export var lower_ax_bottom: float = 51.0   # semi-eixo X (fundo do gol) na base
@export var lower_ax_top: float = 92.0      # semi-eixo X no topo
@export var lower_az_bottom: float = 42.0   # semi-eixo Z (lateral) na base
@export var lower_az_top: float = 80.0      # semi-eixo Z no topo

@export_group("Tier superior")
@export var upper_enabled: bool = true
@export var upper_rows: int = 4
@export var upper_y_bottom: float = 33.0
@export var upper_y_top: float = 44.0
@export var upper_ax_bottom: float = 66.0
@export var upper_ax_top: float = 58.0
@export var upper_az_bottom: float = 45.0
@export var upper_az_top: float = 44.0

@export_group("Paineis")
## Espaçamento aproximado entre painéis ao longo de cada anel (mundo). A contagem
## por anel é derivada da circunferência da elipse / este valor.
@export var panel_spacing: float = 5.2
@export var panel_height: float = 2.4
@export var panel_width: float = 5.2
@export var panel_scale_jitter: float = 0.12
@export var crowd_alpha: float = 0.95
@export var texture_seed: int = 20240615

@export_group("Animacao")
@export var animate: bool = true
@export var animate_in_editor: bool = false
@export var wave_height: float = 0.08
@export var wave_speed: float = 1.6

@export_group("Rebuild")
## Marque/desmarque no editor pra regerar a torcida após mudar parâmetros.
@export var rebuild_now: bool = false:
	set(value):
		rebuild_now = false
		if is_inside_tree():
			_rebuild()

var _elapsed: float = 0.0
var _material_variants: Array[StandardMaterial3D] = []


func _ready() -> void:
	_rebuild()


func _process(delta: float) -> void:
	if not animate:
		return
	if Engine.is_editor_hint() and not animate_in_editor:
		return

	_elapsed += delta
	for child in get_children():
		var panel := child as MeshInstance3D
		if panel == null or not panel.name.begins_with(PANEL_PREFIX):
			continue

		var base_position: Vector3 = panel.get_meta("base_position", panel.position)
		var phase: float = panel.get_meta("phase", 0.0)
		var amount: float = panel.get_meta("wave_amount", 1.0)
		panel.position = base_position + Vector3(0.0, sin(_elapsed * wave_speed + phase) * wave_height * amount, 0.0)


func _rebuild() -> void:
	_clear_generated_panels()
	_material_variants = _create_material_variants()

	var rng := RandomNumberGenerator.new()
	rng.seed = texture_seed + 421

	if lower_enabled:
		_build_tier("L", lower_rows, lower_y_bottom, lower_y_top,
			lower_ax_bottom, lower_ax_top, lower_az_bottom, lower_az_top, rng)
	if upper_enabled:
		_build_tier("U", upper_rows, upper_y_bottom, upper_y_top,
			upper_ax_bottom, upper_ax_top, upper_az_bottom, upper_az_top, rng)


func _clear_generated_panels() -> void:
	var generated_panels: Array[Node] = []
	for child in get_children():
		if child.name.begins_with(PANEL_PREFIX):
			generated_panels.append(child)

	for panel in generated_panels:
		remove_child(panel)
		panel.free()


## Gera um tier: anéis elípticos que sobem do fundo (s=0) ao topo (s=1). Em cada
## anel, a contagem de painéis acompanha a circunferência pra densidade uniforme.
func _build_tier(tag: String, ring_count: int, y_bottom: float, y_top: float,
		ax_bottom: float, ax_top: float, az_bottom: float, az_top: float,
		rng: RandomNumberGenerator) -> void:
	var rows := maxi(ring_count, 1)
	for row in range(rows):
		var s := float(row) / maxf(float(rows - 1), 1.0)
		var y := lerpf(y_bottom, y_top, s)
		var ax := lerpf(ax_bottom, ax_top, s) + seat_radial_offset
		var az := lerpf(az_bottom, az_top, s) + seat_radial_offset

		# Circunferência aproximada da elipse (Ramanujan) -> nº de painéis no anel.
		var circumference := PI * (3.0 * (ax + az) - sqrt((3.0 * ax + az) * (ax + 3.0 * az)))
		var count := maxi(int(round(circumference / maxf(panel_spacing, 0.5))), 8)

		var height := panel_height * lerpf(0.96, 1.06, s)
		for i in range(count):
			var theta := (float(i) + 0.5) / float(count) * TAU
			var cos_t := cos(theta)
			var sin_t := sin(theta)
			var pos := bowl_center + Vector3(ax * cos_t, y + rng.randf_range(-0.05, 0.05), az * sin_t)

			# Tangente da elipse e normal apontando pra DENTRO (encara o gramado).
			var tangent := Vector3(-ax * sin_t, 0.0, az * cos_t).normalized()
			var normal := Vector3(-tangent.z, 0.0, tangent.x).normalized()
			var to_center := bowl_center - pos
			to_center.y = 0.0
			if normal.dot(to_center) < 0.0:
				normal = -normal

			_add_panel("%s_%d_%d" % [tag, row, i], pos, tangent, normal, height, rng)


func _add_panel(panel_name: String, pos: Vector3, tangent: Vector3, normal: Vector3,
		height: float, rng: RandomNumberGenerator) -> void:
	var width := panel_width * rng.randf_range(1.0 - panel_scale_jitter, 1.0 + panel_scale_jitter)
	var mesh := QuadMesh.new()
	mesh.size = Vector2(width, height)

	var panel := MeshInstance3D.new()
	panel.name = PANEL_PREFIX + panel_name
	panel.mesh = mesh
	panel.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF

	var up := Vector3.UP
	panel.transform = Transform3D(Basis(tangent, up, normal).orthonormalized(), pos)
	panel.material_override = _material_variants[rng.randi_range(0, _material_variants.size() - 1)]
	panel.set_meta("base_position", pos)
	panel.set_meta("phase", rng.randf_range(0.0, TAU))
	panel.set_meta("wave_amount", rng.randf_range(0.65, 1.15))
	add_child(panel)


func _create_material_variants() -> Array[StandardMaterial3D]:
	var variants: Array[StandardMaterial3D] = []
	var palette_sets := [
		[Color("#f2cf66"), Color("#c93b35"), Color("#2f6bbd"), Color("#eeeeee"), Color("#1b1d22")],
		[Color("#62b85f"), Color("#f0f3f7"), Color("#d33f49"), Color("#273a80"), Color("#202126")],
		[Color("#f1d04f"), Color("#2b9248"), Color("#ffffff"), Color("#ba3030"), Color("#24242a")],
	]

	for i in range(palette_sets.size()):
		var material := StandardMaterial3D.new()
		material.albedo_texture = _create_crowd_texture(texture_seed + i * 97, palette_sets[i])
		material.albedo_color = Color(1.0, 1.0, 1.0, crowd_alpha)
		material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		material.cull_mode = BaseMaterial3D.CULL_DISABLED
		material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		material.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST_WITH_MIPMAPS
		variants.append(material)

	return variants


func _create_crowd_texture(seed_value: int, palette: Array) -> ImageTexture:
	var image := Image.create(TEXTURE_SIZE.x, TEXTURE_SIZE.y, false, Image.FORMAT_RGBA8)
	image.fill(Color(0.0, 0.0, 0.0, 0.0))

	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value

	var lanes := 5
	for lane in range(lanes):
		var y_center := 42 + lane * 40 + rng.randi_range(-4, 4)
		var x := rng.randi_range(-12, 6)
		while x < TEXTURE_SIZE.x + 12:
			var body_color: Color = palette[rng.randi_range(0, palette.size() - 1)]
			body_color.a = rng.randf_range(0.82, 1.0)
			var head_color := Color(rng.randf_range(0.55, 0.95), rng.randf_range(0.38, 0.72), rng.randf_range(0.25, 0.55), body_color.a)
			var body_w := rng.randi_range(8, 15)
			var body_h := rng.randi_range(14, 26)
			var head_r := rng.randi_range(3, 5)

			_draw_rect(image, Rect2i(x - body_w / 2, y_center, body_w, body_h), body_color)
			_draw_circle(image, Vector2i(x, y_center - head_r + 2), head_r, head_color)

			if rng.randf() < 0.18:
				var arm_color := body_color.darkened(0.08)
				_draw_rect(image, Rect2i(x - body_w / 2 - 5, y_center + 2, 5, 4), arm_color)
				_draw_rect(image, Rect2i(x + body_w / 2, y_center + 2, 5, 4), arm_color)

			x += rng.randi_range(10, 20)

	return ImageTexture.create_from_image(image)


func _draw_rect(image: Image, rect: Rect2i, color: Color) -> void:
	var x0 := clampi(rect.position.x, 0, image.get_width() - 1)
	var y0 := clampi(rect.position.y, 0, image.get_height() - 1)
	var x1 := clampi(rect.position.x + rect.size.x, 0, image.get_width())
	var y1 := clampi(rect.position.y + rect.size.y, 0, image.get_height())

	for y in range(y0, y1):
		for x in range(x0, x1):
			image.set_pixel(x, y, color)


func _draw_circle(image: Image, center: Vector2i, radius: int, color: Color) -> void:
	var radius_sq := radius * radius
	for y in range(center.y - radius, center.y + radius + 1):
		if y < 0 or y >= image.get_height():
			continue
		for x in range(center.x - radius, center.x + radius + 1):
			if x < 0 or x >= image.get_width():
				continue
			var dx := x - center.x
			var dy := y - center.y
			if dx * dx + dy * dy <= radius_sq:
				image.set_pixel(x, y, color)
