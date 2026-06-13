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
@export var anim_blend: float = 0.16

## Biblioteca de animações reaproveitada dos FBX do Mixamo. As animações
## embutidas no ronaldo.glb (exceto Running) perderam a rotação dos ossos na
## exportação, então carregamos esta versão íntegra por cima.
const ANIM_LIB_PATH := "res://anims/ronaldo_anims.res"

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
@export var tackle_radius: float = 1.65
@export var tackle_reach: float = 0.75
@export var tackle_power: float = 8.5
@export var tackle_cooldown: float = 0.65

var _gravity: float = ProjectSettings.get_setting("physics/3d/default_gravity")
var _kick_charge: float = 0.0
var _anim: AnimationPlayer = null
var _kicking: bool = false
var _tackle_timer: float = 0.0

@onready var _kick_area: Area3D = $KickArea
@onready var _model: Node3D = $Model


func _ready() -> void:
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	_anim = find_child("AnimationPlayer", true, false)
	if _anim:
		_install_animation_library()
		_anim.animation_finished.connect(_on_animation_finished)
		_set_looping_animation(&"Idle")
		_set_looping_animation(&"Running")
		_play_anim(&"Idle")
	else:
		push_warning("Player: AnimationPlayer não encontrado dentro de Model.")


## Troca a biblioteca de animações padrão do modelo pela versão baked dos FBX.
## Se o arquivo não existir, mantém as animações do modelo (fallback).
func _install_animation_library() -> void:
	var lib: AnimationLibrary = load(ANIM_LIB_PATH)
	if lib == null:
		push_warning("Player: AnimationLibrary não encontrada em %s; usando animações do modelo." % ANIM_LIB_PATH)
		return
	if _anim.has_animation_library(&""):
		_anim.remove_animation_library(&"")
	_anim.add_animation_library(&"", lib)


func _physics_process(delta: float) -> void:
	_tackle_timer = maxf(_tackle_timer - delta, 0.0)
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
		if _play_anim(&"Kick", true):
			_kicking = true
		_kick_balls(_kick_charge_ratio())
		_kick_charge = 0.0
		kicked_this_frame = true

	if Input.is_action_just_pressed("tackle") and _tackle_timer <= 0.0:
		if _play_anim(&"Kick", true):
			_kicking = true
		_tackle_balls()
		_tackle_timer = tackle_cooldown
		kicked_this_frame = true

	if kicked_this_frame:
		return

	if Input.is_action_pressed("control_ball"):
		_control_balls(delta)
	else:
		_dribble_balls()

	_update_animation()


func _on_animation_finished(anim_name: StringName) -> void:
	if anim_name == &"Kick":
		_kicking = false


func _set_looping_animation(anim_name: StringName) -> void:
	if _anim and _anim.has_animation(anim_name):
		_anim.get_animation(anim_name).loop_mode = Animation.LOOP_LINEAR


func _update_animation() -> void:
	if _anim == null or _kicking:
		return

	var h_speed := Vector2(velocity.x, velocity.z).length()
	if h_speed > 0.5:
		_play_anim(&"Running")
	else:
		_play_anim(&"Idle")


func _play_anim(anim_name: StringName, force: bool = false) -> bool:
	if _anim == null:
		return false

	var target := anim_name
	if not _anim.has_animation(target):
		if target == &"Running" and _anim.has_animation(&"Idle"):
			target = &"Idle"
		else:
			return false

	if not force and StringName(_anim.current_animation) == target:
		return true

	_anim.play(target, anim_blend)
	return true


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


func _tackle_balls() -> void:
	var facing := _facing_dir()
	var center := global_position + facing * tackle_reach
	center.y = 0.45

	var shape := SphereShape3D.new()
	shape.radius = tackle_radius

	var query := PhysicsShapeQueryParameters3D.new()
	query.shape = shape
	query.transform = Transform3D(Basis(), center)
	query.collision_mask = 4
	query.exclude = [get_rid()]

	var results := get_world_3d().direct_space_state.intersect_shape(query, 8)
	for result in results:
		var body := result.get("collider") as Node
		if body is RigidBody3D:
			var ball := body as RigidBody3D
			var to_ball := ball.global_position - global_position
			to_ball.y = 0.0
			var tackle_dir := facing
			if to_ball.length() > 0.05:
				tackle_dir = (facing * 0.65 + to_ball.normalized() * 0.35).normalized()
			var horizontal_velocity := Vector3(ball.linear_velocity.x, 0.0, ball.linear_velocity.z)
			if horizontal_velocity.length() > 4.0:
				horizontal_velocity = horizontal_velocity.normalized() * 4.0
			ball.linear_velocity = Vector3(horizontal_velocity.x, minf(ball.linear_velocity.y, 0.8), horizontal_velocity.z) * 0.45
			ball.angular_velocity *= 0.35
			ball.apply_central_impulse(tackle_dir * tackle_power + Vector3.UP * (tackle_power * 0.04))
