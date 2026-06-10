extends CharacterBody3D

## Controle do protagonista no estilo "câmera de TV fixa":
##   WASD movem o jogador relativo à direção que a câmera está olhando.
##   O CORPO do jogador rotaciona suavemente pra encarar a direção do movimento.
##   Sem mouse-look — a câmera é controlada pela BroadcastCamera (segue o jogador).
##
## Acoplamento: Player não conhece a câmera diretamente; pega a active camera
## da viewport. Isso permite trocar de câmera (replay, gol cam, etc.) sem mexer
## em Player.gd.

@export var walk_speed:       float = 12.0
@export var sprint_mult:      float = 1.7
@export var accel:            float = 26.0
@export var face_rotate_speed: float = 14.0   # qto maior, mais rápido vira pra direção do movimento
@export var ground_lock_y: float = 0.0

@export_group("Bola")
@export var kick_min_power: float = 5.5
@export var kick_max_power: float = 22.0
@export var kick_charge_time: float = 1.35
@export var kick_lift: float = 0.18
@export var dribble_push: float = 1.2
@export var control_distance: float = 0.82
@export var control_pull_strength: float = 42.0
@export var control_velocity_match: float = 6.0
@export var control_max_force: float = 85.0

var _gravity: float = ProjectSettings.get_setting("physics/3d/default_gravity")
var _kick_charge: float = 0.0

@onready var _kick_area: Area3D = $KickArea


func _ready() -> void:
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE


func _physics_process(delta: float) -> void:
	if not is_on_floor():
		velocity.y -= _gravity * delta

	# Direção desejada relativa à câmera ativa, projetada no plano XZ
	var cam := get_viewport().get_camera_3d()
	var input_dir := Input.get_vector("move_left", "move_right", "move_forward", "move_back")
	var move_dir := Vector3.ZERO
	if cam:
		var fwd := -cam.global_transform.basis.z
		fwd.y = 0.0
		if fwd.length() > 0.01:
			fwd = fwd.normalized()
		var right := cam.global_transform.basis.x
		right.y = 0.0
		if right.length() > 0.01:
			right = right.normalized()
		move_dir = fwd * -input_dir.y + right * input_dir.x
	else:
		move_dir = Vector3(input_dir.x, 0, input_dir.y)

	var speed := walk_speed
	if Input.is_action_pressed("sprint"):
		speed *= sprint_mult

	var target_h := move_dir.normalized() * speed if move_dir.length() > 0.05 else Vector3.ZERO
	var current_h := Vector3(velocity.x, 0, velocity.z)
	current_h = current_h.move_toward(target_h, accel * delta)
	velocity.x = current_h.x
	velocity.z = current_h.z

	move_and_slide()
	_lock_player_to_ground()

	# Vira o corpo pra encarar a direção do movimento
	if move_dir.length() > 0.1:
		var target_yaw := atan2(move_dir.x, move_dir.z)
		rotation.y = lerp_angle(rotation.y, target_yaw, face_rotate_speed * delta)

	var kicked_this_frame := false

	if Input.is_action_pressed("kick"):
		_kick_charge = minf(_kick_charge + delta, kick_charge_time)

	if Input.is_action_just_released("kick"):
		_kick_balls(_kick_charge_ratio())
		_kick_charge = 0.0
		kicked_this_frame = true

	if kicked_this_frame:
		return

	if Input.is_action_pressed("control_ball"):
		_control_balls(delta)
	else:
		_dribble_balls()


## Direção pra onde o jogador está virado, no plano do chão (XZ).
func _facing_dir() -> Vector3:
	var dir := global_transform.basis.z
	dir.y = 0.0
	if dir.length() < 0.01:
		return Vector3.FORWARD
	return dir.normalized()


func _lock_player_to_ground() -> void:
	if global_position.y <= ground_lock_y:
		return

	global_position.y = ground_lock_y
	if velocity.y > 0.0:
		velocity.y = 0.0


func _kick_charge_ratio() -> float:
	if kick_charge_time <= 0.0:
		return 1.0
	return clampf(_kick_charge / kick_charge_time, 0.0, 1.0)


## Aplica um impulso na bola. Quanto mais tempo K fica pressionado, mais forte sai.
func _kick_balls(charge_ratio: float) -> void:
	var power := lerpf(kick_min_power, kick_max_power, charge_ratio)
	for body in _kick_area.get_overlapping_bodies():
		if body is RigidBody3D:
			var ball := body as RigidBody3D
			var impulse := _facing_dir() * power + Vector3.UP * (power * kick_lift)
			ball.apply_central_impulse(impulse)


## Mantém a bola perto do pé enquanto L estiver pressionado.
func _control_balls(delta: float) -> void:
	var facing := _facing_dir()
	var target := global_position + facing * control_distance
	target.y = 0.0

	for body in _kick_area.get_overlapping_bodies():
		if body is RigidBody3D:
			var ball := body as RigidBody3D
			var ball_pos := ball.global_position
			ball_pos.y = 0.0
			var to_target := target - ball_pos
			var follow_velocity := Vector3(velocity.x, 0.0, velocity.z)
			var corrective_velocity := to_target / maxf(delta, 0.001)
			var desired_velocity := follow_velocity + corrective_velocity
			var ball_velocity := ball.linear_velocity
			ball_velocity.y = 0.0
			var velocity_error := desired_velocity - ball_velocity
			var force := velocity_error * ball.mass * control_pull_strength
			force.y = 0.0

			if force.length() > control_max_force:
				force = force.normalized() * control_max_force
				force.y = 0.0

			ball.apply_central_force(force)
			ball.apply_central_force(facing * control_velocity_match)


## Empurra a bola de leve enquanto o jogador anda encostado nela (condução/drible).
func _dribble_balls() -> void:
	var ground_speed := Vector3(velocity.x, 0.0, velocity.z).length()
	if ground_speed < 0.5:
		return
	for body in _kick_area.get_overlapping_bodies():
		if body is RigidBody3D:
			var ball := body as RigidBody3D
			ball.apply_central_force(_facing_dir() * dribble_push * ground_speed)
