extends Node3D

const MAIN_SCENE_PATH := "res://scenes/Main.tscn"
const RESET_KEY := KEY_R
const SCOREBOARD_TEXTURE := preload("res://placar.png")
const SCOREBOARD_SOURCE_REGION := Rect2(20.0, 420.0, 960.0, 140.0)
const SCOREBOARD_SIZE := Vector2(300.0, 43.0)
const SCOREBOARD_CENTER_OFFSET_X := -350.0

@export_group("Regras do campo")
@export var left_goal_line_x: float = -51.5
@export var right_goal_line_x: float = 48.0
@export var touchline_z: float = 36.0
@export var goal_half_width: float = 5.8
@export var restart_delay: float = 1.15
@export var throw_in_inset: float = 2.0
@export var corner_inset: float = 1.4
@export var kickoff_ball_position: Vector3 = Vector3(0.0, 0.4, 0.0)

@export_group("IA básica")
@export var yellow_defense_speed: float = 5.0
@export var red_defender_speed: float = 5.4
@export var red_midfielder_speed: float = 7.0
@export var red_attacker_speed: float = 8.2
@export var red_steal_distance: float = 1.75
@export var red_pass_power: float = 13.0
@export var red_shot_power: float = 21.0
@export var red_control_distance: float = 1.25
@export var yellow_pressure_speed: float = 7.4
@export var yellow_tackle_distance: float = 1.65
@export var yellow_tackle_power: float = 8.5
@export var ai_body_radius: float = 0.62
@export var ai_separation_distance: float = 1.55
@export var yellow_recovery_pass_power: float = 9.0
@export var red_counter_tackle_distance: float = 1.75
@export var red_counter_tackle_power: float = 8.0
@export var red_shot_distance_from_goal: float = 12.0
@export var yellow_tackle_control_distance: float = 0.78
@export var ai_recovery_stun: float = 0.55       # quanto tempo o jogador que perdeu a bola fica se recompondo
@export var ai_tackle_settle: float = 0.28        # pequena pausa do tackler logo após dar o bote

var _bra_score: int = 0
var _mar_score: int = 0
var _rules_locked: bool = false
var _scoreboard: Control = null
var _bra_score_label: Label = null
var _mar_score_label: Label = null
var _status_label: Label = null
var _score_pulse_timer: float = 0.0
var _ai_animation_players: Dictionary = {}
var _yellow_defense: Array[Dictionary] = []
var _red_pass_cooldown: float = 0.0
var _red_shot_cooldown: float = 0.0
var _yellow_tackle_cooldowns: Dictionary = {}
var _red_tackle_cooldowns: Dictionary = {}
var _stun_timers: Dictionary = {}
var _red_dribble_phase: float = 0.0

@onready var _ball: RigidBody3D = $Ball
@onready var _player: Node3D = $Player
@onready var _yellow_defender: Node3D = get_node_or_null("TeamYellow_02") as Node3D
@onready var _yellow_mid_left: Node3D = get_node_or_null("TeamYellow_03") as Node3D
@onready var _yellow_mid_right: Node3D = get_node_or_null("TeamYellow_04") as Node3D
@onready var _red_defender: Node3D = get_node_or_null("TeamRed_Keeper") as Node3D
@onready var _red_mid_left: Node3D = get_node_or_null("TeamRed_02") as Node3D
@onready var _red_mid_right: Node3D = get_node_or_null("TeamRed_03") as Node3D
@onready var _red_attacker: Node3D = get_node_or_null("TeamRed_04") as Node3D


func _ready() -> void:
	_setup_match_ai()
	_create_scoreboard()
	_update_scoreboard()
	_create_field_walls()

func _process(delta: float) -> void:
	_update_score_pulse(delta)
	_check_ball_rules()


func _physics_process(delta: float) -> void:
	_update_match_ai(delta)


func _unhandled_key_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		if event.physical_keycode == RESET_KEY:
			_reload_match()


func _reload_match() -> void:
	var tree := get_tree()
	if tree.current_scene:
		tree.reload_current_scene()
	else:
		tree.change_scene_to_file(MAIN_SCENE_PATH)


func _check_ball_rules() -> void:
	if _rules_locked or _ball == null:
		return

	var pos := _ball.global_position
	if absf(pos.z) <= goal_half_width:
		if pos.x <= left_goal_line_x:
			_register_goal(false)
			return
		if pos.x >= right_goal_line_x:
			_register_goal(true)
			return

	if pos.x <= left_goal_line_x or pos.x >= right_goal_line_x:
		_register_corner(pos)
		return

	if absf(pos.z) >= touchline_z:
		_register_throw_in(pos)


func _register_goal(bra_scored: bool) -> void:
	_rules_locked = true
	if bra_scored:
		_bra_score += 1
	else:
		_mar_score += 1
	_update_scoreboard()
	_score_pulse_timer = 1.6
	await get_tree().create_timer(restart_delay).timeout
	_reset_ball(kickoff_ball_position)
	_reset_player_for_restart()
	_reset_ai_for_restart()
	await get_tree().create_timer(0.55).timeout
	_rules_locked = false


func _register_throw_in(ball_pos: Vector3) -> void:
	_rules_locked = true
	var side_z := signf(ball_pos.z)
	if side_z == 0.0:
		side_z = 1.0
	var throw_x := clampf(ball_pos.x, left_goal_line_x + 6.0, right_goal_line_x - 6.0)
	var throw_pos := Vector3(throw_x, kickoff_ball_position.y, side_z * (touchline_z - throw_in_inset))
	_show_status("LATERAL")
	await get_tree().create_timer(0.55).timeout
	_reset_ball(throw_pos)
	await get_tree().create_timer(0.45).timeout
	_show_status("")
	_rules_locked = false


func _register_corner(ball_pos: Vector3) -> void:
	_rules_locked = true
	var side_x := signf(ball_pos.x)
	if side_x == 0.0:
		side_x = 1.0
	var side_z := signf(ball_pos.z)
	if side_z == 0.0:
		side_z = 1.0

	var corner_x := left_goal_line_x + corner_inset
	if side_x > 0.0:
		corner_x = right_goal_line_x - corner_inset
	var corner_pos := Vector3(corner_x, kickoff_ball_position.y, side_z * (touchline_z - corner_inset))

	_show_status("ESCANTEIO")
	await get_tree().create_timer(0.55).timeout
	_reset_ball(corner_pos)
	await get_tree().create_timer(0.45).timeout
	_show_status("")
	_rules_locked = false


func _reset_ball(position: Vector3) -> void:
	_ball.freeze = true
	_ball.global_position = position
	_ball.global_rotation = Vector3.ZERO
	_ball.linear_velocity = Vector3.ZERO
	_ball.angular_velocity = Vector3.ZERO
	_ball.sleeping = false
	_ball.freeze = false


func _reset_player_for_restart() -> void:
	if _player == null:
		return
	_player.global_position = Vector3(-11.0, 0.0, 0.0)
	_player.global_rotation = Vector3(0.0, -PI * 0.5, 0.0)
	if "velocity" in _player:
		_player.velocity = Vector3.ZERO


func _setup_match_ai() -> void:
	_yellow_defense = [
		{"node": _yellow_defender, "home": Vector3(-31.5, 0.0, 0.0), "phase": 0.0},
		{"node": _yellow_mid_left, "home": Vector3(-20.0, 0.0, -14.0), "phase": 2.1},
		{"node": _yellow_mid_right, "home": Vector3(-20.0, 0.0, 14.0), "phase": 4.2},
	]

	for slot in _yellow_defense:
		var yellow_player := slot["node"] as Node3D
		_setup_ai_animation(yellow_player)
		_setup_ai_collision(yellow_player)
	_setup_ai_animation(_red_defender)
	_setup_ai_animation(_red_mid_left)
	_setup_ai_animation(_red_mid_right)
	_setup_ai_animation(_red_attacker)
	for red_player in [_red_defender, _red_mid_left, _red_mid_right, _red_attacker]:
		_setup_ai_collision(red_player)


func _setup_ai_animation(player_node: Node3D) -> void:
	if player_node == null:
		return

	var anim := player_node.find_child("AnimationPlayer", true, false) as AnimationPlayer
	if anim == null:
		return

	_ai_animation_players[player_node.get_instance_id()] = anim
	for anim_name in [&"Idle", &"Running"]:
		if anim.has_animation(anim_name):
			anim.get_animation(anim_name).loop_mode = Animation.LOOP_LINEAR
	_play_ai_anim(player_node, &"Idle", true)


func _setup_ai_collision(player_node: Node3D) -> void:
	if player_node == null or player_node.has_node("NpcBodyCollider"):
		return

	var body := AnimatableBody3D.new()
	body.name = "NpcBodyCollider"
	body.sync_to_physics = false  # controlamos a posição manualmente
	body.collision_layer = 1
	body.collision_mask = 4
	player_node.add_child(body)

	var shape := CollisionShape3D.new()
	shape.name = "Shape"
	shape.position = Vector3(0.0, 0.9, 2.0)  # offset zerado — posição já vem correta do _move_ai_player
	var capsule := CapsuleShape3D.new()
	capsule.radius = ai_body_radius
	capsule.height = 1.8
	shape.shape = capsule
	body.add_child(shape)

func _update_match_ai(delta: float) -> void:
	if _ball == null:
		return

	_red_pass_cooldown = maxf(_red_pass_cooldown - delta, 0.0)
	_red_shot_cooldown = maxf(_red_shot_cooldown - delta, 0.0)
	for key in _yellow_tackle_cooldowns.keys():
		_yellow_tackle_cooldowns[key] = maxf(float(_yellow_tackle_cooldowns[key]) - delta, 0.0)
	for key in _red_tackle_cooldowns.keys():
		_red_tackle_cooldowns[key] = maxf(float(_red_tackle_cooldowns[key]) - delta, 0.0)
	for key in _stun_timers.keys():
		_stun_timers[key] = maxf(float(_stun_timers[key]) - delta, 0.0)
	_red_dribble_phase += delta

	_update_yellow_defense(delta)
	_update_red_team(delta)
	_apply_ball_body_rebounds()


func _update_yellow_defense(delta: float) -> void:
	var ball_pos := _ball_ground_position()
	var time := Time.get_ticks_msec() * 0.001
	var red_carrier := _get_red_ball_carrier()
	var red_has_ball := red_carrier != null

	for index in _yellow_defense.size():
		var slot := _yellow_defense[index]
		var player_node := slot["node"] as Node3D
		if player_node == null:
			continue

		var home := slot["home"] as Vector3
		var phase := float(slot["phase"])

		if red_has_ball:
			var lane_offset := Vector3(1.8 + index * 1.2, 0.0, (index - 1) * 3.4)
			var carrier_pos := red_carrier.global_position
			carrier_pos.y = 0.0
			var target := carrier_pos + lane_offset
			if index == 0:
				target = ball_pos + Vector3(2.2, 0.0, 0.0)
			target.x = minf(target.x, home.x + 11.0)
			target.z = clampf(target.z, home.z - 11.0, home.z + 11.0)
			_move_ai_player(player_node, target, yellow_pressure_speed, delta)
			_try_yellow_tackle(player_node, red_carrier)
		else:
			var z_shift := clampf(ball_pos.z * 0.28, -7.0, 7.0)
			var x_shift := clampf((ball_pos.x - home.x) * 0.07, -2.5, 4.0)
			var patrol := Vector3(sin(time + phase) * 0.9, 0.0, cos(time * 0.8 + phase) * 1.2)
			var target := home + Vector3(x_shift, 0.0, z_shift) + patrol
			_move_ai_player(player_node, target, yellow_defense_speed, delta)


func _update_red_team(delta: float) -> void:
	var ball_pos := _ball_ground_position()
	var red_carrier := _get_red_ball_carrier()
	var red_has_ball := red_carrier != null
	var brazil_carrier := _get_brazil_ball_carrier()

	_update_red_defender(ball_pos, red_has_ball, brazil_carrier, delta)
	_update_red_midfielder(_red_mid_left, Vector3(18.0, 0.0, -14.0), ball_pos, red_has_ball, red_carrier, brazil_carrier, delta)
	_update_red_midfielder(_red_mid_right, Vector3(18.0, 0.0, 14.0), ball_pos, red_has_ball, red_carrier, brazil_carrier, delta)
	_update_red_attacker(ball_pos, red_has_ball, red_carrier, brazil_carrier, delta)


func _update_red_defender(ball_pos: Vector3, red_has_ball: bool, brazil_carrier: Node3D, delta: float) -> void:
	if _red_defender == null:
		return

	var target := Vector3(26.0, 0.0, clampf(ball_pos.z * 0.52, -13.0, 13.0))
	if red_has_ball:
		target = Vector3(clampf(ball_pos.x + 13.0, 14.0, 28.0), 0.0, clampf(ball_pos.z * 0.45, -13.0, 13.0))
	elif brazil_carrier != null and ball_pos.x > -10.0:
		target = Vector3(clampf(ball_pos.x + 3.0, 12.0, 30.0), 0.0, clampf(ball_pos.z, -17.0, 17.0))
	if ball_pos.x > 12.0:
		target.x = clampf(ball_pos.x + 4.0, 18.0, 31.0)
		target.z = clampf(ball_pos.z, -18.0, 18.0)

	_move_ai_player(_red_defender, target, red_defender_speed, delta)
	if brazil_carrier != null:
		_try_red_tackle(_red_defender, brazil_carrier)


func _update_red_midfielder(player_node: Node3D, home: Vector3, ball_pos: Vector3, red_has_ball: bool, red_carrier: Node3D, brazil_carrier: Node3D, delta: float) -> void:
	if player_node == null:
		return

	var attacker_pos := _red_attacker.global_position if _red_attacker else Vector3(4.0, 0.0, 0.0)
	var distance_to_ball := _ground_distance(player_node.global_position, ball_pos)
	var ball_near_midfield := ball_pos.x > -20.0 and ball_pos.x < 28.0

	if brazil_carrier != null and not red_has_ball:
		var carrier_pos := brazil_carrier.global_position
		carrier_pos.y = 0.0
		var side := -1.0 if home.z < 0.0 else 1.0
		var press_target := carrier_pos + Vector3(1.2, 0.0, side * 1.8)
		_move_ai_player(player_node, press_target, red_midfielder_speed * 1.05, delta)
		_try_red_tackle(player_node, brazil_carrier)
		return

	if red_has_ball and red_carrier != player_node:
		var side := -1.0 if home.z < 0.0 else 1.0
		var support_x := clampf(ball_pos.x + 7.0, left_goal_line_x + 17.0, 22.0)
		var support_z := clampf(ball_pos.z + side * 8.0, -20.0, 20.0)
		_move_ai_player(player_node, Vector3(support_x, 0.0, support_z), red_midfielder_speed * 0.78, delta)
		return

	if ball_near_midfield and distance_to_ball < 14.0 and not _red_attacker_controls_ball():
		_move_ai_player(player_node, ball_pos, red_midfielder_speed, delta)
		if distance_to_ball <= red_steal_distance and _red_pass_cooldown <= 0.0:
			var pass_target := attacker_pos + Vector3(-6.0, 0.55, clampf(-attacker_pos.z * 0.25, -4.0, 4.0))
			_finish_red_tackle(player_node, pass_target)
			_play_ai_anim(player_node, &"Pass", true)
			_red_pass_cooldown = 1.1
		return

	var support_shift := Vector3(clampf((ball_pos.x - home.x) * 0.08, -4.0, 3.0), 0.0, clampf(ball_pos.z * 0.22, -5.0, 5.0))
	_move_ai_player(player_node, home + support_shift, red_midfielder_speed * 0.72, delta)


func _update_red_attacker(ball_pos: Vector3, red_has_ball: bool, red_carrier: Node3D, brazil_carrier: Node3D, delta: float) -> void:
	if _red_attacker == null:
		return

	var distance_to_ball := _ground_distance(_red_attacker.global_position, ball_pos)
	var shot_z := clampf(sin(_red_dribble_phase * 1.7) * goal_half_width * 0.32, -goal_half_width * 0.45, goal_half_width * 0.45)
	var goal_target := Vector3(left_goal_line_x - 2.0, 0.65, shot_z)

	if brazil_carrier != null and not red_has_ball:
		var carrier_pos := brazil_carrier.global_position
		carrier_pos.y = 0.0
		_move_ai_player(_red_attacker, carrier_pos + Vector3(1.0, 0.0, 0.0), red_attacker_speed * 0.98, delta)
		_try_red_tackle(_red_attacker, brazil_carrier)
		return

	if red_has_ball and red_carrier != _red_attacker:
		var receive_target := Vector3(clampf(ball_pos.x - 11.0, left_goal_line_x + 9.0, 8.0), 0.0, clampf(ball_pos.z * 0.55, -14.0, 14.0))
		_move_ai_player(_red_attacker, receive_target, red_attacker_speed * 0.82, delta)
		return

	if distance_to_ball <= red_control_distance + 0.85:
		if ball_pos.x <= left_goal_line_x + red_shot_distance_from_goal and _red_shot_cooldown <= 0.0:
			_kick_ball_toward(goal_target, red_shot_power, 0.22)
			_play_ai_anim(_red_attacker, &"Kick", true)
			_red_shot_cooldown = 1.6
			return

		var current_pos := _red_attacker.global_position
		var advance_x := maxf(left_goal_line_x + 6.5, current_pos.x - 9.0)
		var weave := sin(_red_dribble_phase * 2.4) * 4.0 + sin(_red_dribble_phase * 0.9) * 2.2
		var inside_cut := -signf(current_pos.z) * minf(absf(current_pos.z) * 0.28, 3.5)
		var run_target := Vector3(advance_x, 0.0, clampf(ball_pos.z * 0.22 + weave + inside_cut, -goal_half_width * 1.15, goal_half_width * 1.15))
		_move_ai_player(_red_attacker, run_target, red_attacker_speed, delta)
		_control_ball_with_ai(_red_attacker, run_target, delta)
		return

	var chase_target := ball_pos
	if ball_pos.x > 14.0:
		chase_target = Vector3(6.0, 0.0, clampf(ball_pos.z, -12.0, 12.0))

	_move_ai_player(_red_attacker, chase_target, red_attacker_speed, delta)
	if distance_to_ball <= red_counter_tackle_distance:
		_finish_red_tackle(_red_attacker, Vector3(left_goal_line_x + 13.0, 0.55, clampf(ball_pos.z * 0.35, -12.0, 12.0)))


func _red_attacker_controls_ball() -> bool:
	return _red_attacker != null and _ground_distance(_red_attacker.global_position, _ball_ground_position()) <= red_control_distance + 0.85


func _get_red_ball_carrier() -> Node3D:
	var best_player: Node3D = null
	var best_distance := INF
	var ball_pos := _ball_ground_position()

	for player_node in [_red_attacker, _red_mid_left, _red_mid_right]:
		if player_node == null:
			continue

		var distance := _ground_distance(player_node.global_position, ball_pos)
		var possession_radius := red_control_distance + 0.95
		if player_node == _red_attacker:
			possession_radius += 0.35
		if distance <= possession_radius and distance < best_distance:
			best_distance = distance
			best_player = player_node

	return best_player


func _get_brazil_ball_carrier() -> Node3D:
	var best_player: Node3D = null
	var best_distance := INF
	var ball_pos := _ball_ground_position()

	for player_node in [_player, _yellow_defender, _yellow_mid_left, _yellow_mid_right]:
		if player_node == null:
			continue

		var distance := _ground_distance(player_node.global_position, ball_pos)
		var possession_radius := red_control_distance + 0.85
		if player_node == _player:
			possession_radius += 0.35
		if distance <= possession_radius and distance < best_distance:
			best_distance = distance
			best_player = player_node

	return best_player


func _try_yellow_tackle(player_node: Node3D, red_carrier: Node3D) -> void:
	if player_node == null or red_carrier == null or _ball == null:
		return

	var key := player_node.get_instance_id()
	if float(_yellow_tackle_cooldowns.get(key, 0.0)) > 0.0:
		return

	var player_to_ball := _ground_distance(player_node.global_position, _ball_ground_position())
	var player_to_carrier := _ground_distance(player_node.global_position, red_carrier.global_position)
	if player_to_ball > yellow_tackle_distance and player_to_carrier > yellow_tackle_distance + 0.35:
		return

	_snap_ai_player_toward(player_node, _player.global_position)
	_play_ai_anim(player_node, &"Kick", true)
	_finish_yellow_tackle(player_node)
	_yellow_tackle_cooldowns[key] = 1.15


func _try_red_tackle(player_node: Node3D, brazil_carrier: Node3D) -> void:
	if player_node == null or brazil_carrier == null or _ball == null:
		return

	var key := player_node.get_instance_id()
	if float(_red_tackle_cooldowns.get(key, 0.0)) > 0.0:
		return

	var player_to_ball := _ground_distance(player_node.global_position, _ball_ground_position())
	var player_to_carrier := _ground_distance(player_node.global_position, brazil_carrier.global_position)
	if player_to_ball > red_counter_tackle_distance and player_to_carrier > red_counter_tackle_distance + 0.3:
		return

	var target := Vector3(left_goal_line_x + 12.0, 0.55, clampf(_ball.global_position.z * 0.4, -12.0, 12.0))
	if _red_attacker != null and player_node != _red_attacker:
		target = _red_attacker.global_position + Vector3(-5.0, 0.55, 0.0)
	_finish_red_tackle(player_node, target)
	_play_ai_anim(player_node, &"Kick", true)
	_red_tackle_cooldowns[key] = 1.05


func _pass_ball_to_player(from_player: Node3D) -> void:
	if _player == null or _ball == null:
		return

	var receive_target := _player.global_position
	var player_forward := Vector3.ZERO
	var player_velocity: Variant = _player.get("velocity")
	if player_velocity is Vector3:
		player_forward = Vector3(player_velocity.x, 0.0, player_velocity.z)
	if player_forward.length() > 0.2:
		receive_target += player_forward.normalized() * 2.5

	var passer_pos := from_player.global_position if from_player else _ball.global_position
	var distance := _ground_distance(passer_pos, receive_target)
	var power := clampf(yellow_recovery_pass_power + distance * 0.10, 8.0, yellow_tackle_power + 2.0)
	_soft_touch_ball_toward(receive_target + Vector3(0.0, 0.55, 0.0), power, 0.04)


func _finish_yellow_tackle(player_node: Node3D) -> void:
	if player_node == null or _player == null or _ball == null:
		return

	# Quem estava com a bola (o vermelho) perde a posse e fica se recompondo antes
	# de voltar a disputar. A bola NÃO é teleportada: é tocada fisicamente na direção
	# do brasileiro a partir de onde ela está.
	var loser := _get_red_ball_carrier()
	if loser != null:
		_stun_ai_player(loser, ai_recovery_stun)
	_stun_ai_player(player_node, ai_tackle_settle)

	_ball.sleeping = false
	_pass_ball_to_player(player_node)


func _finish_red_tackle(player_node: Node3D, target: Vector3) -> void:
	if player_node == null or _ball == null:
		return

	# Quem estava com a bola (brasileiro/IA) perde a posse e fica se recompondo.
	# O humano não é "stunado" (ele segue no controle do jogador).
	var loser := _get_brazil_ball_carrier()
	if loser != null:
		_stun_ai_player(loser, ai_recovery_stun)
	_stun_ai_player(player_node, ai_tackle_settle)

	_snap_ai_player_toward(player_node, target)
	# Sem teleporte da bola: empurra fisicamente a partir da posição atual dela.
	_ball.sleeping = false
	_soft_touch_ball_toward(target, red_counter_tackle_power, 0.04)


func _control_ball_with_ai(player_node: Node3D, target: Vector3, delta: float) -> void:
	if player_node == null or _ball == null:
		return

	var player_pos := player_node.global_position
	player_pos.y = 0.0
	var move_dir := target - player_pos
	move_dir.y = 0.0
	if move_dir.length() < 0.01:
		return
	move_dir = move_dir.normalized()

	var desired_ball_pos := player_pos + move_dir * red_control_distance
	desired_ball_pos.y = _ball.global_position.y
	var desired_velocity := move_dir * (red_attacker_speed * 0.9) + (desired_ball_pos - _ball.global_position) / maxf(delta, 0.001)
	var velocity_error := desired_velocity - _ball.linear_velocity
	var force := velocity_error * _ball.mass * 18.0
	if force.length() > 85.0:
		force = force.normalized() * 85.0
	_ball.apply_central_force(force)


func _kick_ball_toward(target: Vector3, power: float, lift: float) -> void:
	if _ball == null:
		return

	var dir := target - _ball.global_position
	dir.y = 0.0
	if dir.length() < 0.01:
		return

	var impulse := dir.normalized() * power + Vector3.UP * (power * lift)
	_ball.apply_central_impulse(impulse)


func _soft_touch_ball_toward(target: Vector3, power: float, lift: float) -> void:
	if _ball == null:
		return

	var dir := target - _ball.global_position
	dir.y = 0.0
	if dir.length() < 0.01:
		return

	var horizontal_velocity := Vector3(_ball.linear_velocity.x, 0.0, _ball.linear_velocity.z)
	if horizontal_velocity.length() > 4.0:
		horizontal_velocity = horizontal_velocity.normalized() * 4.0
	_ball.linear_velocity = Vector3(horizontal_velocity.x, minf(_ball.linear_velocity.y, 0.8), horizontal_velocity.z) * 0.45
	_ball.angular_velocity *= 0.35

	var impulse := dir.normalized() * power + Vector3.UP * (power * lift)
	_ball.apply_central_impulse(impulse)


func _move_ai_player(player_node: Node3D, target: Vector3, speed: float, delta: float) -> void:
	if player_node == null:
		return

	if _is_ai_stunned(player_node):
		_set_ai_motion_anim(player_node, false)
		_face_ai_player(player_node, target, delta)
		return

	target.x = clampf(target.x, left_goal_line_x + 5.0, right_goal_line_x - 5.0)
	target.y = 0.0
	target.z = clampf(target.z, -touchline_z + 4.0, touchline_z - 4.0)

	var pos := player_node.global_position
	pos.y = 0.0
	var next_pos := pos.move_toward(target, speed * delta)
	next_pos = _separate_ai_position(player_node, next_pos)

	# Move o AnimatableBody diretamente para a colisão seguir sem delay
	var body := player_node.get_node_or_null("NpcBodyCollider") as AnimatableBody3D
	if body:
		body.global_position = next_pos

	player_node.global_position = next_pos

	var moved := _ground_distance(pos, next_pos) > 0.015
	_set_ai_motion_anim(player_node, moved)
	if moved:
		_face_ai_player(player_node, target, delta)


func _separate_ai_position(player_node: Node3D, desired_pos: Vector3) -> Vector3:
	var separation := Vector3.ZERO
	for other in _get_player_bodies_for_separation():
		if other == null or other == player_node:
			continue

		var other_pos := other.global_position
		other_pos.y = 0.0
		var away := desired_pos - other_pos
		away.y = 0.0
		var distance := away.length()
		if distance < 0.01 or distance >= ai_separation_distance:
			continue

		separation += away.normalized() * ((ai_separation_distance - distance) / ai_separation_distance)

	if separation.length() > 0.01:
		desired_pos += separation.normalized() * minf(separation.length(), 0.65)

	desired_pos.x = clampf(desired_pos.x, left_goal_line_x + 5.0, right_goal_line_x - 5.0)
	desired_pos.y = 0.0
	desired_pos.z = clampf(desired_pos.z, -touchline_z + 4.0, touchline_z - 4.0)
	return desired_pos


func _apply_ball_body_rebounds() -> void:
	if _ball == null:
		return

	var ball_pos := _ball_ground_position()
	for player_node in _get_ai_players():
		if player_node == null:
			continue

		var player_pos := player_node.global_position
		player_pos.y = 0.0
		var away := ball_pos - player_pos
		away.y = 0.0
		var distance := away.length()
		var rebound_distance := ai_body_radius + 0.45
		if distance < 0.01 or distance > rebound_distance:
			continue

		# O colisor (AnimatableBody) já trata o ressalto quando o jogador se move.
		# Aqui só damos um empurrãozinho de separação pra bola não ficar presa
		# encostada num jogador parado — bem mais fraco que antes, sem somar tranco.
		var penetration := (rebound_distance - distance) / rebound_distance
		var away_dir := away.normalized()
		_ball.apply_central_impulse(away_dir * 0.6 * penetration)


func _get_ai_players() -> Array[Node3D]:
	return [_yellow_defender, _yellow_mid_left, _yellow_mid_right, _red_defender, _red_mid_left, _red_mid_right, _red_attacker]


func _get_player_bodies_for_separation() -> Array[Node3D]:
	var bodies := _get_ai_players()
	if _player:
		bodies.append(_player)
	return bodies


func _face_ai_player(player_node: Node3D, target: Vector3, delta: float) -> void:
	if player_node == null:
		return

	var dir := target - player_node.global_position
	dir.y = 0.0
	if dir.length() < 0.05:
		return

	var target_yaw := atan2(dir.x, dir.z)
	player_node.rotation.y = lerp_angle(player_node.rotation.y, target_yaw, 10.0 * delta)


func _snap_ai_player_toward(player_node: Node3D, target: Vector3) -> void:
	if player_node == null:
		return

	var dir := target - player_node.global_position
	dir.y = 0.0
	if dir.length() < 0.05:
		return

	player_node.rotation.y = atan2(dir.x, dir.z)


## Marca um jogador de IA como "se recompondo" por alguns instantes (ele para de
## perseguir e fica encarando a jogada). Nunca afeta o jogador humano.
func _stun_ai_player(player_node: Node3D, duration: float) -> void:
	if player_node == null or player_node == _player or duration <= 0.0:
		return
	var key := player_node.get_instance_id()
	_stun_timers[key] = maxf(float(_stun_timers.get(key, 0.0)), duration)


func _is_ai_stunned(player_node: Node3D) -> bool:
	if player_node == null:
		return false
	return float(_stun_timers.get(player_node.get_instance_id(), 0.0)) > 0.0


func _set_ai_motion_anim(player_node: Node3D, moving: bool) -> void:
	var anim := _get_ai_animation_player(player_node)
	if anim == null:
		return

	var current := StringName(anim.current_animation)
	if anim.is_playing() and (current == &"Kick" or current == &"Pass" or current == &"Header" or current == &"PenaltyKick" or current == &"ScissorKick"):
		return

	_play_ai_anim(player_node, &"Running" if moving else &"Idle")


func _play_ai_anim(player_node: Node3D, anim_name: StringName, force: bool = false) -> bool:
	var anim := _get_ai_animation_player(player_node)
	if anim == null:
		return false

	var target := anim_name
	if not anim.has_animation(target):
		if target != &"Idle" and anim.has_animation(&"Idle"):
			target = &"Idle"
		else:
			return false

	if not force and StringName(anim.current_animation) == target:
		return true

	anim.play(target, 0.14)
	return true


func _get_ai_animation_player(player_node: Node3D) -> AnimationPlayer:
	if player_node == null:
		return null
	return _ai_animation_players.get(player_node.get_instance_id(), null) as AnimationPlayer


func _reset_ai_for_restart() -> void:
	_stun_timers.clear()
	for slot in _yellow_defense:
		var player_node := slot["node"] as Node3D
		if player_node == null:
			continue
		player_node.global_position = slot["home"] as Vector3
		_play_ai_anim(player_node, &"Idle", true)

	var red_homes := {
		_red_defender: Vector3(27.5, 0.0, 0.0),
		_red_mid_left: Vector3(18.0, 0.0, -14.0),
		_red_mid_right: Vector3(18.0, 0.0, 14.0),
		_red_attacker: Vector3(8.0, 0.0, 0.0),
	}
	for player_node in red_homes:
		if player_node == null:
			continue
		player_node.global_position = red_homes[player_node]
		_play_ai_anim(player_node, &"Idle", true)


func _ball_ground_position() -> Vector3:
	var pos := _ball.global_position
	pos.y = 0.0
	return pos


func _ground_distance(a: Vector3, b: Vector3) -> float:
	a.y = 0.0
	b.y = 0.0
	return a.distance_to(b)


func _create_scoreboard() -> void:
	var layer := CanvasLayer.new()
	layer.name = "MatchHud"
	add_child(layer)

	_scoreboard = Control.new()
	_scoreboard.name = "Scoreboard"
	_scoreboard.anchor_left = 0.5
	_scoreboard.anchor_top = 0.0
	_scoreboard.anchor_right = 0.5
	_scoreboard.anchor_bottom = 0.0
	_scoreboard.offset_left = -SCOREBOARD_SIZE.x * 0.5 + SCOREBOARD_CENTER_OFFSET_X
	_scoreboard.offset_top = 16.0
	_scoreboard.offset_right = SCOREBOARD_SIZE.x * 0.5 + SCOREBOARD_CENTER_OFFSET_X
	_scoreboard.offset_bottom = 16.0 + SCOREBOARD_SIZE.y
	_scoreboard.pivot_offset = SCOREBOARD_SIZE * 0.5
	layer.add_child(_scoreboard)

	var scoreboard_texture := AtlasTexture.new()
	scoreboard_texture.atlas = SCOREBOARD_TEXTURE
	scoreboard_texture.region = SCOREBOARD_SOURCE_REGION

	var background := TextureRect.new()
	background.name = "ScoreboardImage"
	background.texture = scoreboard_texture
	background.stretch_mode = TextureRect.STRETCH_SCALE
	background.set_anchors_preset(Control.PRESET_FULL_RECT)
	_scoreboard.add_child(background)

	_bra_score_label = _create_score_number_label(Vector2(400.0, 35.0))
	_scoreboard.add_child(_bra_score_label)

	_mar_score_label = _create_score_number_label(Vector2(550.0, 35.0))
	_scoreboard.add_child(_mar_score_label)

	_status_label = Label.new()
	_status_label.anchor_left = 0.0
	_status_label.anchor_top = 1.0
	_status_label.anchor_right = 1.0
	_status_label.anchor_bottom = 1.0
	_status_label.offset_left = 0.0
	_status_label.offset_top = 2.0
	_status_label.offset_right = 0.0
	_status_label.offset_bottom = 26.0
	_status_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_status_label.add_theme_font_size_override("font_size", 13)
	_status_label.add_theme_color_override("font_color", Color(1.0, 0.94, 0.38))
	_status_label.add_theme_color_override("font_shadow_color", Color(0.0, 0.0, 0.0, 0.9))
	_status_label.add_theme_constant_override("shadow_offset_x", 2)
	_status_label.add_theme_constant_override("shadow_offset_y", 2)
	_scoreboard.add_child(_status_label)


func _create_score_number_label(position: Vector2) -> Label:
	var label := Label.new()
	label.position = position
	label.size = Vector2(38.0, 34.0)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", 45)
	label.add_theme_color_override("font_color", Color(0.02, 0.02, 0.02))
	label.add_theme_color_override("font_shadow_color", Color(1.0, 1.0, 1.0, 0.65))
	label.add_theme_constant_override("shadow_offset_x", 1)
	label.add_theme_constant_override("shadow_offset_y", 1)
	return label


func _update_scoreboard() -> void:
	if _bra_score_label:
		_bra_score_label.text = str(_bra_score)
	if _mar_score_label:
		_mar_score_label.text = str(_mar_score)


func _show_status(text: String) -> void:
	if _status_label:
		_status_label.text = text


func _update_score_pulse(delta: float) -> void:
	if _scoreboard == null:
		return
	if _score_pulse_timer > 0.0:
		_score_pulse_timer -= delta
		var pulse := 1.0 + sin(_score_pulse_timer * 18.0) * 0.10
		_scoreboard.scale = Vector2.ONE * pulse
	else:
		_scoreboard.scale = Vector2.ONE
		
func _create_field_walls() -> void:
	var body := StaticBody3D.new()
	body.name = "FieldWalls"
	body.collision_layer = 1
	body.collision_mask = 68

	var seg_length := touchline_z - goal_half_width
	var seg_center_z := goal_half_width + seg_length * 0.5
	var field_len := right_goal_line_x - left_goal_line_x

	# Laterais
	_add_field_wall(body, "SideNorth",
		Vector3(left_goal_line_x + field_len * 0.5, 0.5, -(touchline_z + 0.5)),
		Vector3(field_len, 2.0, 1.0))
	_add_field_wall(body, "SideSouth",
		Vector3(left_goal_line_x + field_len * 0.5, 0.5, touchline_z + 0.5),
		Vector3(field_len, 2.0, 1.0))

	# Linhas de fundo com abertura do gol
	_add_field_wall(body, "EndLeftNorth",
		Vector3(left_goal_line_x - 0.5, 0.5, -seg_center_z),
		Vector3(1.0, 2.0, seg_length))
	_add_field_wall(body, "EndLeftSouth",
		Vector3(left_goal_line_x - 0.5, 0.5, seg_center_z),
		Vector3(1.0, 2.0, seg_length))
	_add_field_wall(body, "EndRightNorth",
		Vector3(right_goal_line_x + 0.5, 0.5, -seg_center_z),
		Vector3(1.0, 2.0, seg_length))
	_add_field_wall(body, "EndRightSouth",
		Vector3(right_goal_line_x + 0.5, 0.5, seg_center_z),
		Vector3(1.0, 2.0, seg_length))

	add_child(body)
	print("FieldWalls criado: ", body.get_child_count(), " paredes")

func _add_field_wall(parent: Node, wall_name: String, pos: Vector3, size: Vector3) -> void:
	var shape := BoxShape3D.new()
	shape.size = size
	var col := CollisionShape3D.new()
	col.name = wall_name
	col.position = pos
	col.shape = shape
	parent.add_child(col)
