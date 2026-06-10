extends Camera3D

## Câmera fixa estilo "câmera de transmissão de TV de jogo de futebol".
## Não se move, só rotaciona suavemente pra seguir o alvo (jogador / bola).
##
## Pra escolher entre tracking do jogador, da bola, ou de qualquer outro nó:
##   target_path no Inspector.

@export var target_path: NodePath
@export var target_offset: Vector3 = Vector3(0, 1.0, 0)  # mira pro torso, não pros pés
@export var track_speed: float = 4.0                     # qto maior, mais "rápido" a câmera segue
@export var idle_target: Vector3 = Vector3(0, 0, 0)      # se alvo sumir, mira no centro do campo

# Zoom dinâmico opcional (câmera vai mais perto quando jogador chega no ataque, mais longe na defesa)
@export var dynamic_fov: bool = true
@export var fov_near: float = 35.0
@export var fov_far: float = 60.0

var _target: Node3D = null


func _ready() -> void:
	if not target_path.is_empty():
		var n := get_node_or_null(target_path)
		if n is Node3D:
			_target = n
	current = true


func _process(delta: float) -> void:
	var aim_pos := idle_target
	if _target:
		aim_pos = _target.global_position + target_offset

	# Interpola a direção pra suavizar — sem isso a câmera "trava" instantaneamente,
	# parecendo robô. Com t baixo, parece operador humano.
	var t: float = clamp(track_speed * delta, 0.0, 1.0)
	var current_fwd: Vector3 = -global_transform.basis.z
	var desired_fwd: Vector3 = (aim_pos - global_position).normalized()
	var blended_fwd: Vector3 = current_fwd.lerp(desired_fwd, t).normalized()
	look_at(global_position + blended_fwd, Vector3.UP)

	# Zoom em função da distância ao alvo (TV usa zoom variável também)
	if dynamic_fov and _target:
		var dist := global_position.distance_to(_target.global_position)
		# 25m de distância → fov_near (close-up); 120m → fov_far (wide)
		var k: float = clamp(remap(dist, 25.0, 120.0, 0.0, 1.0), 0.0, 1.0)
		fov = lerp(fov_near, fov_far, k)
