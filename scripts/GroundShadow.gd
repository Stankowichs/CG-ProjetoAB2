extends Node3D

## Sombra "blob" simples: um círculo escuro suave deitado no gramado que segue
## o alvo (jogador ou bola) apenas no plano do chão. É a sombra de contato
## básica que você pediu — limpa, sempre legível e sem depender do ângulo do sol
## (a sombra direcional do estádio continua fixa na grama).
##
## A malha é "top_level": ignora a rotação/posição do pai, então fica sempre
## plana no chão mesmo que a bola gire ou o jogador incline.

## Quem a sombra segue. Vazio = usa o nó pai.
@export var target_path: NodePath
## Raio do círculo de sombra, em metros.
@export var radius: float = 0.9
## Altura do gramado (um tiquinho acima pra não brigar com o chão / z-fighting).
@export var ground_y: float = 0.05
## Quão escura é a sombra no centro (0 = invisível, 1 = preto).
@export_range(0.0, 1.0) var darkness: float = 0.45
## Altura em que a sombra sela some (ex.: bola chutada pro alto fica sem sombra).
@export var fade_height: float = 5.0
## Desliga a sombra projetada "de verdade" do alvo, pra não ficar dobrada.
@export var disable_target_real_shadow: bool = true

const SHADER_CODE := """
shader_type spatial;
render_mode unshaded, blend_mix, cull_disabled, depth_draw_never, shadows_disabled;

uniform float darkness = 0.45;
uniform float opacity = 1.0;

void fragment() {
	float d = distance(UV, vec2(0.5)) * 2.0;      // 0 no centro -> 1 na borda
	float a = pow(clamp(1.0 - d, 0.0, 1.0), 2.0); // queda suave pras bordas
	ALBEDO = vec3(0.0);
	ALPHA = a * darkness * opacity;
}
"""

var _target: Node3D
var _mesh: MeshInstance3D
var _mat: ShaderMaterial


func _ready() -> void:
	_target = get_node_or_null(target_path) if not target_path.is_empty() else get_parent() as Node3D

	var plane := PlaneMesh.new() # PlaneMesh já fica deitado no plano XZ (normal pra cima)
	plane.size = Vector2(radius * 2.0, radius * 2.0)

	var shader := Shader.new()
	shader.code = SHADER_CODE
	_mat = ShaderMaterial.new()
	_mat.shader = shader
	_mat.set_shader_parameter("darkness", darkness)
	_mat.set_shader_parameter("opacity", 1.0)

	_mesh = MeshInstance3D.new()
	_mesh.mesh = plane
	_mesh.material_override = _mat
	_mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_mesh.top_level = true # não herda transform do pai: controlamos a posição direto
	add_child(_mesh)

	if disable_target_real_shadow and _target != null:
		_turn_off_real_shadow(_target)


## Percorre o alvo e desliga a sombra projetada das malhas dele.
func _turn_off_real_shadow(root: Node) -> void:
	var stack: Array = [root]
	while not stack.is_empty():
		var n: Node = stack.pop_back()
		if n is GeometryInstance3D:
			n.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		for c in n.get_children():
			stack.append(c)


func _process(_delta: float) -> void:
	if _target == null:
		return
	var p := _target.global_position
	# Mantém o blob plano no gramado, seguindo o alvo só em X/Z.
	_mesh.global_position = Vector3(p.x, ground_y, p.z)
	_mesh.global_rotation = Vector3.ZERO
	# Some conforme o alvo sobe (bola no ar), volta ao pousar.
	var h: float = maxf(p.y - ground_y, 0.0)
	var op: float = clampf(1.0 - h / fade_height, 0.0, 1.0)
	_mat.set_shader_parameter("opacity", op)
