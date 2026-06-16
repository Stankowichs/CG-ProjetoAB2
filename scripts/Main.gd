extends Node3D

const MAIN_SCENE_PATH := "res://scenes/Main.tscn"
const RESET_KEY := KEY_R
const SCOREBOARD_TEXTURE := preload("res://placar.png")
const SCOREBOARD_SOURCE_REGION := Rect2(20.0, 420.0, 960.0, 140.0)
const SCOREBOARD_SIZE := Vector2(300.0, 43.0)
const SCOREBOARD_CENTER_OFFSET_X := -350.0
const KEEPER_ANIM_LIB := "res://anims/hulk_keeper_anims.res"
const KEEPER_THROW_BONE := &"mixamorig_RightHand"   # mão que segura a bola no arremesso

## Clipes de ação (não-looping): enquanto um deles está genuinamente tocando, a
## locomoção (Idle/Running) não interrompe. Usado também pelo watchdog de animação.
const ACTION_ANIMS := {
	&"Kick": true, &"Pass": true, &"Header": true, &"PenaltyKick": true,
	&"ScissorKick": true, &"DiveA": true, &"DiveB": true, &"Throw": true,
}

@export_group("Regras do campo")
@export var left_goal_line_x: float = -51.5
@export var right_goal_line_x: float = 48.0
@export var touchline_z: float = 36.0
@export var goal_half_width: float = 5.8
@export var restart_delay: float = 1.15
@export var throw_in_inset: float = 2.0
@export var corner_inset: float = 1.4
@export var kickoff_ball_position: Vector3 = Vector3(0.0, 0.4, 0.0)
@export var boundary_restart_margin: float = 0.35
@export var yellow_restart_pass_power: float = 5.8
@export var yellow_restart_settle_time: float = 0.18
@export var yellow_restart_grace_time: float = 1.1
@export var restart_fade_time: float = 0.28

@export_group("IA básica")
@export var disable_ai_players_for_dribble_test: bool = false
@export var yellow_defense_speed: float = 5.0
@export var red_midfielder_speed: float = 7.0
@export var red_attacker_speed: float = 8.2
@export var red_centerback_speed: float = 6.6
@export var red_steal_distance: float = 1.75
@export var red_pass_power: float = 13.0
@export var red_shot_power: float = 21.0
@export var red_control_distance: float = 1.25
@export var yellow_pressure_speed: float = 7.4
@export var yellow_tackle_distance: float = 1.65
@export var yellow_tackle_power: float = 8.5
@export var yellow_pass_to_player_min_distance: float = 4.0
@export var yellow_contain_distance: float = 5.2
@export var yellow_contain_back: float = 3.4
@export var yellow_contain_width: float = 6.0
@export var ai_body_radius: float = 0.62
@export var ai_separation_push: float = 0.3        # empurrão suave na zona de "espaço pessoal"
@export var ai_separation_buffer: float = 0.25     # folga além do encostar (zona pessoal)
@export var ai_separation_hardness: float = 0.5    # fração da sobreposição real resolvida por frame
@export var yellow_recovery_pass_power: float = 7.0
@export var red_counter_tackle_distance: float = 1.75
@export var red_counter_tackle_power: float = 8.0
@export var red_shot_distance_from_goal: float = 12.0
@export var yellow_tackle_control_distance: float = 0.78
@export var ai_recovery_stun: float = 0.55       # quanto tempo o jogador que perdeu a bola fica se recompondo
@export var ai_tackle_settle: float = 0.28        # pequena pausa do tackler logo após dar o bote
@export var ai_think_retreat_distance: float = 3.2
@export var ai_think_retreat_time: float = 0.55
@export var ai_think_turn_time: float = 0.28
@export var red_think_kick_power: float = 15.5
@export var yellow_think_kick_power: float = 7.5
@export var block_follow_x: float = 0.18
@export var block_follow_z: float = 0.42
@export var block_max_x_shift: float = 8.0
@export var block_max_z_shift: float = 12.0
@export var block_lane_width: float = 7.5

@export_group("Movimentação do time vermelho")
## 0 = jogadores grudam na posição da bola; 1 = ficam fixos na "casa". Valores
## baixos fazem o time subir e descer acompanhando a bola de forma natural.
@export var red_shape_bias: float = 0.28
@export var red_support_back: float = 3.0       # quão atrás da bola os meias ficam (lado vermelho)
@export var red_support_front: float = 2.0      # quanto os meias avançam à frente da bola ao apoiar o ataque
@export var red_centerback_back: float = 11.0   # quão atrás da bola o zagueiro fica
@export var red_centerback_min_x: float = 9.0   # linha mais avançada que o zagueiro alcança (último homem)
@export var red_centerback_max_x: float = 33.0  # quão fundo o zagueiro recua (sem atrapalhar o goleiro)
@export var red_carrier_pass_distance: float = 12.0
@export var red_carrier_lane_offset: float = 4.5
@export var red_carrier_holdoff_distance: float = 2.2
@export var ai_ball_carry_correction_speed: float = 7.0
@export var ai_ball_carry_max_force: float = 45.0
@export var ai_ball_carry_extra_speed: float = 1.8
@export var ai_anim_blend: float = 0.28
@export var ai_action_anim_blend: float = 0.20
@export var ai_face_ball_weight: float = 0.82
@export var ai_face_rotate_speed: float = 7.0
@export var ai_run_anim_min_movement: float = 0.06
@export var ai_run_anim_min_target_distance: float = 0.18
## Sincronização da passada com a velocidade real (evita "deslizar"/patinar):
## a 1.0x a animação Running corresponde a esta velocidade de chão; acima/abaixo
## o speed_scale acompanha proporcionalmente (clampado pra não exagerar).
@export var ai_run_anim_reference_speed: float = 6.5
@export var ai_run_anim_min_speed_scale: float = 0.65
@export var ai_run_anim_max_speed_scale: float = 1.6
## Olhar pra bola suavizado: longe (>= far) o peso é ai_face_ball_weight; perto
## (<= near) encara totalmente a bola; entre os dois interpola sem salto brusco.
@export var ai_face_ball_near: float = 1.8
@export var ai_face_ball_far: float = 4.5
## Histerese de quem pressiona a bola (Fase 2): elege UM jogador por time e o
## mantém por um tempo mínimo. Outro candidato só "rouba" o papel se estiver bem
## mais perto (switch_margin) ou se o atual abandonou a jogada (abandon_margin).
@export var ai_presser_min_hold: float = 0.7      # tempo mínimo segurando o papel (s)
@export var ai_presser_switch_margin: float = 1.6 # quão mais perto o rival precisa estar pra roubar (m)
@export var ai_presser_abandon_margin: float = 4.0 # se o atual ficar tão mais longe que isso, troca já (m)
## Movimento com inércia (Fase 3): a IA acelera/desacelera em vez de teleportar,
## eliminando viradas instantâneas. arrive_radius = distância em que começa a
## frear pra não passar do alvo. face_min_speed = velocidade a partir da qual o
## corpo encara a direção real do movimento (abaixo disso, mantém o foco/alvo).
@export var ai_accel: float = 30.0
@export var ai_decel: float = 40.0
@export var ai_arrive_radius: float = 2.2
@export var ai_face_min_speed: float = 0.6

@export_group("Visualização de colisão")
@export var show_collision_radii: bool = false
@export var player_body_radius: float = 0.52
@export var collision_radius_visual_alpha: float = 0.22
@export var collision_radius_visual_y: float = 0.035

@export_group("Goleiros")
@export var keeper_line_offset: float = 2.5   # quão à frente da linha do gol o goleiro fica
@export var keeper_speed: float = 6.5         # velocidade do goleiro deslizando no eixo Z
@export var keeper_post_margin: float = 0.6   # margem pra dentro das traves (fica sempre entre elas)
@export var keeper_dive_distance: float = 5.2 # distância da bola que dispara o mergulho num chute
@export var keeper_catch_distance: float = 1.5 # distância pra agarrar/repor a bola
@export var keeper_shot_speed: float = 4.5    # velocidade mínima da bola pra ser tratada como chute
@export var keeper_action_cooldown: float = 1.1 # intervalo entre mergulhos/reposições
@export var keeper_ground_y: float = 0.26     # compensa a origem do GLB do Hulk, evitando ficar enterrado
@export var keeper_body_radius: float = 0.82  # colisor do goleiro (maior = pega/desvia melhor)
@export var keeper_throw_windup: float = 0.85 # tempo com a bola na mão antes de soltar (anim Throw)
@export var keeper_throw_min_power: float = 5.8
@export var keeper_throw_max_power: float = 9.5
@export var keeper_hand_lift: float = 0.08    # leve ajuste da bola na mão
@export var keeper_area_depth: float = 16.0
@export var keeper_area_half_width: float = 18.0
@export var keeper_area_clear_margin: float = 1.5
@export var keeper_clear_area_speed: float = 7.0

var _snd_kick: AudioStreamPlayer = null
var _snd_goal: AudioStreamPlayer = null
var _snd_whistle: AudioStreamPlayer = null
var _snd_crowd: AudioStreamPlayer = null
var _snd_throw: AudioStreamPlayer = null

var _bra_score: int = 0
var _mar_score: int = 0
var _rules_locked: bool = false
var _scoreboard: Control = null
var _bra_score_label: Label = null
var _mar_score_label: Label = null
var _status_label: Label = null
var _transition_rect: ColorRect = null
var _score_pulse_timer: float = 0.0
var _ai_animation_players: Dictionary = {}
var _yellow_defense: Array[Dictionary] = []
var _red_pass_cooldown: float = 0.0
var _red_shot_cooldown: float = 0.0
var _yellow_tackle_cooldowns: Dictionary = {}
var _red_tackle_cooldowns: Dictionary = {}
var _stun_timers: Dictionary = {}
var _red_dribble_phase: float = 0.0
var _yellow_restart_grace_timer: float = 0.0
var _ai_collision_radii: Dictionary = {}
var _ai_kick_plans: Dictionary = {}
var _ai_think_cooldowns: Dictionary = {}
var _presser_claims: Dictionary = {}     # "yellow"/"red" -> {"node": Node3D, "timer": float} (histerese de quem pressiona)
var _ai_velocities: Dictionary = {}      # instance_id -> Vector3 (velocidade no plano XZ; movimento com inércia)
var _keeper_action_cd: Dictionary = {}   # instance_id -> tempo até poder mergulhar/repor de novo
var _keeper_dive_axis: Dictionary = {}   # instance_id -> sinal de Z (mundo) que o clipe DiveA cobre
var _keeper_hand: Dictionary = {}        # instance_id -> BoneAttachment3D na mão do goleiro
var _ball_holder: Node3D = null          # goleiro que está com a bola na mão (ou null)
var _hold_timer: float = 0.0             # tempo restante segurando a bola antes de soltar
var _hold_target: Node3D = null          # pra quem o goleiro vai arremessar
var _hold_line_x: float = 0.0            # linha do gol do goleiro que está segurando
var _hold_throw_started: bool = false

@onready var _ball: RigidBody3D = $Ball
@onready var _player: Node3D = $Player
@onready var _yellow_defender: Node3D = get_node_or_null("TeamYellow_02") as Node3D
@onready var _yellow_mid_left: Node3D = get_node_or_null("TeamYellow_03") as Node3D
@onready var _yellow_mid_right: Node3D = get_node_or_null("TeamYellow_04") as Node3D
@onready var _red_defender: Node3D = get_node_or_null("TeamRed_Keeper") as Node3D  # goleiro hulk vermelho (gol direito)
@onready var _yellow_keeper: Node3D = get_node_or_null("TeamYellow_Keeper") as Node3D  # goleiro hulk amarelo (gol esquerdo)
@onready var _red_mid_left: Node3D = get_node_or_null("TeamRed_02") as Node3D
@onready var _red_mid_right: Node3D = get_node_or_null("TeamRed_03") as Node3D
@onready var _red_attacker: Node3D = get_node_or_null("TeamRed_04") as Node3D
@onready var _red_centerback: Node3D = get_node_or_null("TeamRed_05") as Node3D  # zagueiro vermelho


func _ready() -> void:
	_setup_audio()
	_setup_match_ai()
	if disable_ai_players_for_dribble_test:
		_disable_ai_players_for_dribble_test()
	_create_scoreboard()
	_update_scoreboard()
	_create_field_walls()
	call_deferred("_hide_collision_debug_shapes")


func _setup_audio() -> void:
	_snd_kick    = _create_audio_player("res://audio/mixkit-soccer-ball-kick-2099.ogg")
	_snd_goal    = _create_audio_player("res://audio/gol1.ogg")
	_snd_whistle = _create_audio_player("res://audio/apito.ogg")
	_snd_throw   = _create_audio_player("res://audio/throw-ball.ogg")

	var crowd_stream := load("res://audio/mixkit-stadium-joy-shouting-crowd-3022.ogg") as AudioStreamOggVorbis
	if crowd_stream:
		crowd_stream.loop = true
	_snd_crowd = AudioStreamPlayer.new()
	_snd_crowd.stream = crowd_stream
	_snd_crowd.volume_db = -18.0
	add_child(_snd_crowd)
	_snd_crowd.play()


func _create_audio_player(path: String) -> AudioStreamPlayer:
	var player := AudioStreamPlayer.new()
	var stream = load(path)
	if stream:
		player.stream = stream
	else:
		push_warning("Audio: arquivo não encontrado: %s" % path)
	add_child(player)
	return player

func _process(delta: float) -> void:
	_update_score_pulse(delta)
	_check_ball_rules()


func _physics_process(delta: float) -> void:
	if _rules_locked:
		return
	if disable_ai_players_for_dribble_test:
		return
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

	if absf(pos.z) >= touchline_z - boundary_restart_margin:
		_register_yellow_restart(pos, "LATERAL YELLOW")
		return

	if absf(pos.z) > goal_half_width and (pos.x <= left_goal_line_x + boundary_restart_margin or pos.x >= right_goal_line_x - boundary_restart_margin):
		_register_keeper_restart(pos)
		return


func _register_goal(bra_scored: bool) -> void:
	_rules_locked = true
	if bra_scored:
		_bra_score += 1
	else:
		_mar_score += 1
	_update_scoreboard()
	_score_pulse_timer = 1.6
	if _snd_goal:
		_snd_goal.play()
	if _snd_crowd:
		_snd_crowd.play()
	await get_tree().create_timer(restart_delay).timeout
	_reset_ball(kickoff_ball_position)
	_reset_player_for_restart()
	_reset_ai_for_restart()
	await get_tree().create_timer(0.55).timeout
	_rules_locked = false


func _register_yellow_restart(ball_pos: Vector3, status_text: String) -> void:
	_rules_locked = true
	_show_status(status_text)
	_stop_ball_motion(true)
	if _snd_whistle:
		_snd_whistle.play()

	await _fade_match(true)

	var restart_pos := _get_yellow_restart_position(ball_pos)
	var kicker := _select_yellow_restart_kicker(restart_pos)
	_reset_match_state_for_restart()
	_position_players_for_yellow_restart(restart_pos, kicker)
	_reset_ball(restart_pos)
	_stop_ball_motion(true)
	_hide_collision_debug_shapes()

	await get_tree().create_timer(yellow_restart_settle_time).timeout
	await _fade_match(false)
	await get_tree().create_timer(0.08).timeout

	_stop_ball_motion(false)
	_yellow_restart_pass_to_player(kicker)
	_yellow_restart_grace_timer = yellow_restart_grace_time
	_show_status("")
	_rules_locked = false


func _register_keeper_restart(ball_pos: Vector3) -> void:
	_rules_locked = true
	var left_side := ball_pos.x < 0.0
	var keeper := _yellow_keeper if left_side else _red_defender
	var line_x := left_goal_line_x + keeper_line_offset if left_side else right_goal_line_x - keeper_line_offset
	_show_status("TIRO DE META YELLOW" if left_side else "TIRO DE META RED")
	_stop_ball_motion(true)
	if _snd_whistle:
		_snd_whistle.play()

	await _fade_match(true)

	_reset_match_state_for_restart()
	_position_players_for_keeper_restart(left_side)
	_place_ball_in_keeper_hands(keeper, line_x)
	_hide_collision_debug_shapes()

	await get_tree().create_timer(yellow_restart_settle_time).timeout
	await _fade_match(false)
	_show_status("")
	_rules_locked = false


func _get_yellow_restart_position(ball_pos: Vector3) -> Vector3:
	var restart := Vector3(
		clampf(ball_pos.x, left_goal_line_x + corner_inset, right_goal_line_x - corner_inset),
		kickoff_ball_position.y,
		clampf(ball_pos.z, -touchline_z + throw_in_inset, touchline_z - throw_in_inset)
	)

	if absf(ball_pos.z) >= touchline_z - boundary_restart_margin:
		var side_z := signf(ball_pos.z)
		if side_z == 0.0:
			side_z = 1.0
		restart.z = side_z * (touchline_z - throw_in_inset)
		return restart

	var side_x := signf(ball_pos.x)
	if side_x == 0.0:
		side_x = -1.0
	restart.x = left_goal_line_x + corner_inset if side_x < 0.0 else right_goal_line_x - corner_inset
	var end_side_z := signf(ball_pos.z)
	if end_side_z == 0.0:
		end_side_z = 1.0
	restart.z = end_side_z * minf(absf(restart.z), touchline_z - corner_inset)
	return restart


func _select_yellow_restart_kicker(restart_pos: Vector3) -> Node3D:
	var options := [_yellow_defender, _yellow_mid_left, _yellow_mid_right]
	var best: Node3D = null
	var best_distance := INF
	for option in options:
		var player_node := option as Node3D
		if player_node == null:
			continue
		var distance := _ground_distance(player_node.global_position, restart_pos)
		if distance < best_distance:
			best = player_node
			best_distance = distance
	return best if best != null else _yellow_defender


func _reset_match_state_for_restart() -> void:
	_stun_timers.clear()
	_ai_kick_plans.clear()
	_ai_think_cooldowns.clear()
	_presser_claims.clear()
	_ai_velocities.clear()
	_yellow_tackle_cooldowns.clear()
	_red_tackle_cooldowns.clear()
	_red_pass_cooldown = 0.0
	_red_shot_cooldown = 0.0
	_keeper_action_cd.clear()
	_ball_holder = null
	_hold_target = null
	_hold_timer = 0.0
	_hold_throw_started = false


func _position_players_for_yellow_restart(restart_pos: Vector3, kicker: Node3D) -> void:
	var side_z := signf(restart_pos.z)
	if side_z == 0.0:
		side_z = 1.0

	var player_receive := Vector3(
		clampf(restart_pos.x - 11.0, left_goal_line_x + 8.0, 6.0),
		0.0,
		clampf(restart_pos.z * 0.35, -12.0, 12.0)
	)
	_set_player_transform(_player, player_receive, restart_pos)

	var yellow_positions := {
		_yellow_defender: Vector3(clampf(player_receive.x - 9.0, left_goal_line_x + 8.0, right_goal_line_x - 12.0), 0.0, clampf(player_receive.z, -16.0, 16.0)),
		_yellow_mid_left: Vector3(clampf(player_receive.x - 4.0, left_goal_line_x + 8.0, right_goal_line_x - 12.0), 0.0, clampf(player_receive.z - 8.0, -22.0, 22.0)),
		_yellow_mid_right: Vector3(clampf(player_receive.x - 4.0, left_goal_line_x + 8.0, right_goal_line_x - 12.0), 0.0, clampf(player_receive.z + 8.0, -22.0, 22.0)),
	}
	for player_node in yellow_positions:
		if player_node == null:
			continue
		var target := yellow_positions[player_node] as Vector3
		if player_node == kicker:
			target = restart_pos + Vector3(-1.2, 0.0, -side_z * 0.7)
		player_node.global_position = target
		_face_node_at(player_node, player_receive)
		_play_ai_anim(player_node, &"Idle", true)

	if _yellow_keeper:
		_yellow_keeper.global_position = Vector3(left_goal_line_x + keeper_line_offset, keeper_ground_y, 0.0)
		_face_node_at(_yellow_keeper, restart_pos)
		_play_ai_anim(_yellow_keeper, &"Idle", true)

	var red_positions := {
		_red_defender: Vector3(right_goal_line_x - keeper_line_offset, keeper_ground_y, 0.0),
		_red_mid_left: Vector3(clampf(player_receive.x + 8.0, left_goal_line_x + 8.0, right_goal_line_x - 8.0), 0.0, clampf(player_receive.z - 8.0, -24.0, 24.0)),
		_red_mid_right: Vector3(clampf(player_receive.x + 10.0, left_goal_line_x + 8.0, right_goal_line_x - 8.0), 0.0, clampf(player_receive.z + 8.0, -24.0, 24.0)),
		_red_attacker: Vector3(clampf(player_receive.x + 6.0, left_goal_line_x + 8.0, right_goal_line_x - 10.0), 0.0, clampf(player_receive.z, -18.0, 18.0)),
		_red_centerback: Vector3(clampf(player_receive.x + 17.0, left_goal_line_x + 12.0, right_goal_line_x - 8.0), 0.0, clampf(player_receive.z * 0.45, -12.0, 12.0)),
	}
	for player_node in red_positions:
		if player_node == null:
			continue
		player_node.global_position = red_positions[player_node]
		_face_node_at(player_node, restart_pos)
		_play_ai_anim(player_node, &"Idle", true)


func _position_players_for_keeper_restart(left_side: bool) -> void:
	var keeper_x := left_goal_line_x + keeper_line_offset if left_side else right_goal_line_x - keeper_line_offset
	var keeper := _yellow_keeper if left_side else _red_defender
	var out_dir := 1.0 if left_side else -1.0

	if keeper:
		keeper.global_position = Vector3(keeper_x, keeper_ground_y, 0.0)
		_face_node_at(keeper, Vector3(keeper_x + out_dir * 12.0, 0.0, 0.0))
		_play_ai_anim(keeper, &"Idle", true)

	var player_target := Vector3(keeper_x + out_dir * 21.0, 0.0, -6.0)
	if not left_side:
		player_target = Vector3(clampf(keeper_x + out_dir * 18.0, left_goal_line_x + 8.0, right_goal_line_x - 8.0), 0.0, -8.0)
	_set_player_transform(_player, player_target, Vector3(keeper_x, 0.0, 0.0))

	var yellow_positions := {
		_yellow_defender: Vector3(left_goal_line_x + 15.0, 0.0, 0.0),
		_yellow_mid_left: Vector3(-20.0, 0.0, -14.0),
		_yellow_mid_right: Vector3(-20.0, 0.0, 14.0),
	}
	for player_node in yellow_positions:
		if player_node == null:
			continue
		player_node.global_position = yellow_positions[player_node]
		_face_node_at(player_node, Vector3(keeper_x, 0.0, 0.0))
		_play_ai_anim(player_node, &"Idle", true)

	if _yellow_keeper and _yellow_keeper != keeper:
		_yellow_keeper.global_position = Vector3(left_goal_line_x + keeper_line_offset, keeper_ground_y, 0.0)
		_play_ai_anim(_yellow_keeper, &"Idle", true)

	var red_positions := {
		_red_defender: Vector3(right_goal_line_x - keeper_line_offset, keeper_ground_y, 0.0),
		_red_mid_left: Vector3(18.0, 0.0, -14.0),
		_red_mid_right: Vector3(18.0, 0.0, 14.0),
		_red_attacker: Vector3(8.0, 0.0, 0.0),
		_red_centerback: Vector3(26.0, 0.0, 0.0),
	}
	for player_node in red_positions:
		if player_node == null or player_node == keeper:
			continue
		player_node.global_position = red_positions[player_node]
		_face_node_at(player_node, Vector3(keeper_x, 0.0, 0.0))
		_play_ai_anim(player_node, &"Idle", true)


func _place_ball_in_keeper_hands(keeper: Node3D, line_x: float) -> void:
	if keeper == null or _ball == null:
		_reset_ball(Vector3(line_x, kickoff_ball_position.y, 0.0))
		return

	_ball_holder = keeper
	_hold_timer = keeper_throw_windup
	_hold_line_x = line_x
	_hold_target = _player if keeper == _yellow_keeper else _red_attacker
	_hold_throw_started = false
	_ball.freeze = true
	_ball.linear_velocity = Vector3.ZERO
	_ball.angular_velocity = Vector3.ZERO
	var hand := _keeper_hand.get(keeper.get_instance_id()) as BoneAttachment3D
	if hand != null:
		_ball.global_position = hand.global_position + Vector3.UP * keeper_hand_lift
	else:
		_ball.global_position = keeper.global_position + Vector3(0.0, 1.2, 0.0)
	_play_ai_anim(keeper, &"Idle", true)
	_keeper_action_cd[keeper.get_instance_id()] = keeper_action_cooldown


func _set_player_transform(player_node: Node3D, position: Vector3, face_target: Vector3) -> void:
	if player_node == null:
		return
	player_node.global_position = position
	if "velocity" in player_node:
		player_node.velocity = Vector3.ZERO
	_face_node_at(player_node, face_target)


func _yellow_restart_pass_to_player(kicker: Node3D) -> void:
	if _ball == null or _player == null:
		return
	var receive_target := _player.global_position + Vector3(0.0, 0.55, 0.0)
	var passer_pos := kicker.global_position if kicker != null else _ball.global_position
	var distance := _ground_distance(passer_pos, receive_target)
	var power := clampf(yellow_restart_pass_power + distance * 0.035, 4.8, yellow_restart_pass_power + 1.6)
	if kicker != null:
		_face_node_at(kicker, receive_target)
		_play_ai_anim(kicker, &"Pass", true)
	_soft_touch_ball_toward(receive_target, power, 0.02)


func _stop_ball_motion(keep_frozen: bool) -> void:
	if _ball == null:
		return
	_ball.freeze = keep_frozen
	_ball.sleeping = false
	_ball.linear_velocity = Vector3.ZERO
	_ball.angular_velocity = Vector3.ZERO


func _reset_ball(position: Vector3) -> void:
	# se algum goleiro estava segurando a bola, libera a posse
	_ball_holder = null
	_hold_target = null
	_hold_timer = 0.0
	_hold_throw_started = false
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
	_setup_keeper_visual(_yellow_keeper)
	_setup_keeper_visual(_red_defender)
	_setup_ai_animation(_red_mid_left)
	_setup_ai_animation(_red_mid_right)
	_setup_ai_animation(_red_attacker)
	_setup_ai_animation(_red_centerback)
	for red_player in [_red_mid_left, _red_mid_right, _red_attacker, _red_centerback]:
		_setup_ai_collision(red_player)
	_place_goalkeepers()
	_setup_collision_radius_visuals()


func _setup_ai_animation(player_node: Node3D) -> void:
	if player_node == null:
		return

	var anim := player_node.find_child("AnimationPlayer", true, false) as AnimationPlayer
	if anim == null:
		return

	_ai_animation_players[player_node.get_instance_id()] = anim
	anim.playback_process_mode = AnimationPlayer.ANIMATION_PROCESS_PHYSICS
	for anim_name in [&"Idle", &"Running"]:
		if anim.has_animation(anim_name):
			anim.get_animation(anim_name).loop_mode = Animation.LOOP_LINEAR
	_play_ai_anim(player_node, &"Idle", true)


func _setup_keeper_visual(keeper: Node3D) -> void:
	if keeper == null:
		return

	_install_keeper_anims(keeper)
	_setup_ai_animation(keeper)        # registra o AnimationPlayer, faz loop do Idle e toca Idle
	_compute_keeper_dive_axis(keeper)
	_setup_keeper_hand(keeper)
	_setup_ai_collision(keeper, keeper_body_radius)


## Cria um BoneAttachment3D na mão de arremesso do goleiro. Enquanto ele segura a
## bola, a bola é grudada nessa posição — daí a percepção de "bola na mão".
func _setup_keeper_hand(keeper: Node3D) -> void:
	var skel := keeper.find_child("Skeleton3D", true, false) as Skeleton3D
	if skel == null or skel.find_bone(KEEPER_THROW_BONE) < 0:
		return
	if skel.has_node("BallHand"):
		_keeper_hand[keeper.get_instance_id()] = skel.get_node("BallHand")
		return
	var att := BoneAttachment3D.new()
	att.name = "BallHand"
	att.bone_name = KEEPER_THROW_BONE
	skel.add_child(att)
	_keeper_hand[keeper.get_instance_id()] = att


## Troca a biblioteca quebrada do hulk pela versão baked de goleiro (Idle, mergulhos
## DiveA/DiveB e Throw). Mesmo esquema do Player.gd.
func _install_keeper_anims(keeper: Node3D) -> void:
	var anim := keeper.find_child("AnimationPlayer", true, false) as AnimationPlayer
	if anim == null:
		return
	var lib: AnimationLibrary = load(KEEPER_ANIM_LIB)
	if lib == null:
		push_warning("Goleiro: biblioteca %s não encontrada." % KEEPER_ANIM_LIB)
		return
	if anim.has_animation_library(&""):
		anim.remove_animation_library(&"")
	anim.add_animation_library(&"", lib)


## Descobre, pro esqueleto deste goleiro, qual sinal de Z (mundo) o clipe DiveA
## cobre. Como os dois gols têm orientações espelhadas, isso garante que cada um
## mergulhe pro lado certo da bola.
func _compute_keeper_dive_axis(keeper: Node3D) -> void:
	if keeper == null:
		return
	var skel := keeper.find_child("Skeleton3D", true, false) as Skeleton3D
	if skel == null:
		return
	var right_world := skel.global_transform.basis * Vector3.RIGHT
	_keeper_dive_axis[keeper.get_instance_id()] = signf(right_world.z)


func _setup_ai_collision(player_node: Node3D, radius: float = ai_body_radius) -> void:
	if player_node == null:
		return
	_ai_collision_radii[player_node.get_instance_id()] = radius
	if player_node.has_node("NpcBodyCollider"):
		return

	var body := AnimatableBody3D.new()
	body.name = "NpcBodyCollider"
	body.top_level = true
	body.sync_to_physics = false  # controlamos a posição manualmente
	body.collision_layer = 1
	body.collision_mask = 4
	player_node.add_child(body)

	var shape := CollisionShape3D.new()
	shape.name = "Shape"
	shape.position = Vector3(0.0, 0.9, 0.0)
	var capsule := CapsuleShape3D.new()
	capsule.radius = radius
	capsule.height = 1.8
	shape.shape = capsule
	shape.visible = false
	body.add_child(shape)


func _setup_collision_radius_visuals() -> void:
	if not show_collision_radii:
		return

	_add_collision_radius_visual(_player, player_body_radius, Color(0.2, 0.65, 1.0, collision_radius_visual_alpha))
	for player_node in [_yellow_defender, _yellow_mid_left, _yellow_mid_right]:
		_add_collision_radius_visual(player_node, ai_body_radius, Color(1.0, 0.9, 0.15, collision_radius_visual_alpha))
	for player_node in [_red_mid_left, _red_mid_right, _red_attacker]:
		_add_collision_radius_visual(player_node, ai_body_radius, Color(1.0, 0.16, 0.12, collision_radius_visual_alpha))
	_add_collision_radius_visual(_yellow_keeper, keeper_body_radius, Color(1.0, 0.9, 0.15, collision_radius_visual_alpha))
	_add_collision_radius_visual(_red_defender, keeper_body_radius, Color(1.0, 0.16, 0.12, collision_radius_visual_alpha))


func _disable_ai_players_for_dribble_test() -> void:
	for player_node in _get_ai_players():
		if player_node == null:
			continue
		player_node.visible = false
		player_node.process_mode = Node.PROCESS_MODE_DISABLED
		for child in player_node.find_children("*", "", true, false):
			var collision_object := child as CollisionObject3D
			if collision_object != null:
				collision_object.collision_layer = 0
				collision_object.collision_mask = 0
			var collision_shape := child as CollisionShape3D
			if collision_shape != null:
				collision_shape.disabled = true


func _add_collision_radius_visual(player_node: Node3D, radius: float, color: Color) -> void:
	if player_node == null or player_node.has_node("CollisionRadiusVisual"):
		return

	var mesh := CylinderMesh.new()
	mesh.top_radius = radius
	mesh.bottom_radius = radius
	mesh.height = 0.025
	mesh.radial_segments = 48

	var material := StandardMaterial3D.new()
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.albedo_color = color
	material.no_depth_test = true

	var visual := MeshInstance3D.new()
	visual.name = "CollisionRadiusVisual"
	visual.mesh = mesh
	visual.material_override = material
	visual.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	visual.position = Vector3(0.0, collision_radius_visual_y - player_node.global_position.y, 0.0)
	player_node.add_child(visual)


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
	for key in _ai_think_cooldowns.keys():
		_ai_think_cooldowns[key] = maxf(float(_ai_think_cooldowns[key]) - delta, 0.0)
	_red_dribble_phase += delta
	_yellow_restart_grace_timer = maxf(_yellow_restart_grace_timer - delta, 0.0)

	if _ball_holder != null:
		_update_players_for_keeper_throw(delta)
		_update_goalkeeper(_yellow_keeper, left_goal_line_x + keeper_line_offset, delta)
		_update_goalkeeper(_red_defender, right_goal_line_x - keeper_line_offset, delta)
		return

	_update_yellow_defense(delta)
	_update_red_team(delta)
	_update_goalkeeper(_yellow_keeper, left_goal_line_x + keeper_line_offset, delta)
	_update_goalkeeper(_red_defender, right_goal_line_x - keeper_line_offset, delta)
	_apply_ball_body_rebounds()
	_update_ai_anim_watchdog()


## Watchdog simples: se um jogador ficou "preso" num clipe de ação que já terminou
## (a lógica de movimento daquele frame não chegou a reativar a locomoção), volta
## pra Idle. No frame seguinte, se ele estiver andando, _move_ai_player troca pra
## Running normalmente. Evita o jogador congelar na pose de chute/passe.
func _update_ai_anim_watchdog() -> void:
	for player_node in _get_ai_players():
		if player_node == null:
			continue
		var anim := _get_ai_animation_player(player_node)
		if anim == null:
			continue
		var current := StringName(anim.current_animation)
		if ACTION_ANIMS.has(current) and _action_anim_finished(anim):
			anim.speed_scale = 1.0
			_play_ai_anim(player_node, &"Idle", true)


func _update_yellow_defense(delta: float) -> void:
	var ball_pos := _ball_ground_position()
	var red_carrier := _get_red_ball_carrier()
	var red_has_ball := red_carrier != null
	var brazil_carrier := _get_brazil_ball_carrier()
	var player_controls := _player_controls_ball()
	var closest_yellow := _elect_presser("yellow", [_yellow_defender, _yellow_mid_left, _yellow_mid_right], delta)

	for index in _yellow_defense.size():
		var slot := _yellow_defense[index]
		var player_node := slot["node"] as Node3D
		if player_node == null:
			continue

		if _update_ai_think_kick(player_node, delta, yellow_pressure_speed):
			continue
		if not _player_is_close_to_ball_for_yellow_pass() and not player_controls and not red_has_ball and brazil_carrier == player_node and _start_ai_think_kick(player_node, _player, "yellow", yellow_think_kick_power):
			_update_ai_think_kick(player_node, delta, yellow_pressure_speed)
			continue

		var home := slot["home"] as Vector3
		var lane_side := float(index - 1)

		if _yellow_restart_grace_timer > 0.0:
			var support_target := _midfielder_block_target(home, _player.global_position if _player else ball_pos, lane_side)
			_move_ai_player(player_node, support_target, yellow_defense_speed * 0.72, delta)
			continue

		if player_controls:
			var player_pos := _player.global_position
			player_pos.y = 0.0
			var contain_target := _yellow_contain_target(player_pos, index, lane_side)
			_move_ai_player(player_node, contain_target, yellow_defense_speed * 0.88, delta)
			continue

		if red_has_ball:
			var carrier_pos := red_carrier.global_position
			carrier_pos.y = 0.0
			var target := carrier_pos
			if player_node != closest_yellow:
				var cover_z := clampf(carrier_pos.z + (index - 1) * 3.0, -18.0, 18.0)
				target = _midfielder_block_target(home, Vector3(carrier_pos.x + 2.5 + index * 0.8, 0.0, cover_z), lane_side)
			target.x = minf(target.x, home.x + 11.0)
			target.z = clampf(target.z, home.z - 11.0, home.z + 11.0)
			_move_ai_player(player_node, target, yellow_pressure_speed, delta)
			_try_yellow_tackle(player_node, red_carrier, delta)
		else:
			if player_node == closest_yellow:
				_move_ai_player(player_node, ball_pos, yellow_pressure_speed, delta)
			else:
				var support := _midfielder_block_target(home, ball_pos, lane_side)
				support.z += float(index - 1) * 4.0
				support.x = clampf(support.x, home.x - 3.0, home.x + 10.0)
				support.z = clampf(support.z, -22.0, 22.0)
				_move_ai_player(player_node, support, yellow_defense_speed, delta)


func _update_red_team(delta: float) -> void:
	var ball_pos := _ball_ground_position()
	var red_carrier := _get_red_ball_carrier()
	var red_has_ball := red_carrier != null
	var brazil_carrier := _get_brazil_ball_carrier()
	var closest_red := _elect_presser("red", [_red_mid_left, _red_mid_right, _red_attacker, _red_centerback], delta)

	_update_red_midfielder(_red_mid_left, Vector3(18.0, 0.0, -14.0), ball_pos, red_has_ball, red_carrier, brazil_carrier, closest_red, delta)
	_update_red_midfielder(_red_mid_right, Vector3(18.0, 0.0, 14.0), ball_pos, red_has_ball, red_carrier, brazil_carrier, closest_red, delta)
	_update_red_attacker(ball_pos, red_has_ball, red_carrier, brazil_carrier, closest_red, delta)
	_update_red_centerback(ball_pos, red_has_ball, red_carrier, brazil_carrier, closest_red, delta)


## Alvo que ACOMPANHA a bola: o time vermelho sobe quando ataca (bola indo pra -x)
## e recua na defesa, ficando deslocado em X por back_offset (positivo = atrás da
## bola, lado vermelho) e numa faixa lateral (lane_side). A mistura leve com a
## "casa" (red_shape_bias) mantém a forma — esquerda/centro/direita — sem todo
## mundo grudar na bola.
func _red_field_target(home: Vector3, ball_pos: Vector3, lane_side: float, back_offset: float) -> Vector3:
	var tx := lerpf(ball_pos.x + back_offset, home.x, red_shape_bias)
	var tz := lerpf(ball_pos.z + lane_side * block_lane_width, home.z, red_shape_bias)
	return Vector3(tx, 0.0, tz)


## Zagueiro vermelho: jogador mais recuado, acompanha a jogada como último homem,
## fica entre a bola e o próprio gol e marca o portador se for o mais próximo.
func _update_red_centerback(ball_pos: Vector3, red_has_ball: bool, red_carrier: Node3D, brazil_carrier: Node3D, closest_red: Node3D, delta: float) -> void:
	if _red_centerback == null:
		return

	if _update_ai_think_kick(_red_centerback, delta, red_centerback_speed):
		return
	if red_carrier == _red_centerback:
		_update_red_carrier_to_attacker(_red_centerback, red_centerback_speed, delta)
		return

	var home := Vector3(red_centerback_back + 14.0, 0.0, 0.0)

	# É o mais perto da bola: sai pra marcar/dar o bote.
	if brazil_carrier != null and closest_red == _red_centerback:
		var carrier_pos := brazil_carrier.global_position
		carrier_pos.y = 0.0
		_move_ai_player(_red_centerback, carrier_pos, red_centerback_speed * 1.05, delta)
		_try_red_tackle(_red_centerback, brazil_carrier, delta)
		return

	var target := _red_field_target(home, ball_pos, 0.0, red_centerback_back)
	target.x = clampf(target.x, red_centerback_min_x, red_centerback_max_x)
	_move_ai_player(_red_centerback, target, red_centerback_speed, delta)


func _update_red_carrier_to_attacker(player_node: Node3D, speed: float, delta: float) -> void:
	if player_node == null or _red_attacker == null or _ball == null:
		return
	if _update_ai_think_kick(player_node, delta, speed):
		return

	var carrier_pos := player_node.global_position
	carrier_pos.y = 0.0
	var attacker_pos := _red_attacker.global_position
	attacker_pos.y = 0.0
	var to_attacker := attacker_pos - carrier_pos
	to_attacker.y = 0.0

	if to_attacker.length() <= red_carrier_pass_distance and _has_clear_red_attacker_lane(player_node):
		if _start_ai_think_kick(player_node, _red_attacker, "red", red_think_kick_power):
			_update_ai_think_kick(player_node, delta, speed)
		return

	var lane_side := signf(carrier_pos.z)
	if lane_side == 0.0:
		lane_side = -1.0 if player_node == _red_mid_left else 1.0
	var carry_x := maxf(left_goal_line_x + 8.0, carrier_pos.x - red_carrier_holdoff_distance)
	var carry_z := clampf(attacker_pos.z + lane_side * red_carrier_lane_offset, -touchline_z + 6.0, touchline_z - 6.0)
	var carry_target := Vector3(carry_x, 0.0, carry_z)

	_move_ai_player(player_node, carry_target, speed * 0.82, delta)
	_control_ball_with_ai(player_node, carry_target, delta, speed * 0.82)


func _has_clear_red_attacker_lane(player_node: Node3D) -> bool:
	if player_node == null or _red_attacker == null:
		return false
	var from := player_node.global_position
	var to := _red_attacker.global_position
	from.y = 0.0
	to.y = 0.0
	for yellow_player in [_yellow_defender, _yellow_mid_left, _yellow_mid_right, _player]:
		var defender := yellow_player as Node3D
		if defender == null:
			continue
		var defender_pos := defender.global_position
		defender_pos.y = 0.0
		if _distance_point_to_segment(defender_pos, from, to) < 2.4:
			return false
	return true


## Goleiro: fica fixo um pouco à frente da linha do gol (line_x) e desliza no eixo
## Z pra acompanhar a bola, cobrindo a boca do gol. O colisor de corpo
## (NpcBodyCollider) desvia a bola fisicamente quando ela chega na linha.
func _update_goalkeeper(keeper: Node3D, line_x: float, delta: float) -> void:
	if keeper == null:
		return

	# Se este goleiro está com a bola na mão, conduz o arremesso e sai.
	if _ball_holder == keeper:
		_update_keeper_hold(keeper, delta)
		return

	var ball_pos := _ball_ground_position()
	# Fica SEMPRE entre as traves: o alvo em Z é limitado pra dentro dos postes
	# (margem keeper_post_margin), então ele nunca passa da trave.
	var z_limit := goal_half_width - keeper_post_margin
	var target := Vector3(line_x, keeper_ground_y, clampf(ball_pos.z, -z_limit, z_limit))

	var pos := keeper.global_position
	var next_pos := pos.move_toward(target, keeper_speed * delta)
	keeper.global_position = next_pos
	var keeper_movement := _ground_distance(pos, next_pos)
	var moved := keeper_movement > 0.01
	var keeper_ground_speed := keeper_movement / delta if delta > 0.0 else 0.0

	var key := keeper.get_instance_id()
	var cd := float(_keeper_action_cd.get(key, 0.0))
	if cd > 0.0:
		_keeper_action_cd[key] = cd - delta

	if _ball_holder == null and _ball != null:
		var dist_ball := _ground_distance(next_pos, ball_pos)
		var hvel := Vector3(_ball.linear_velocity.x, 0.0, _ball.linear_velocity.z)
		var toward_goal := _ball.linear_velocity.x * signf(line_x) > 1.0
		var ball_slow := hvel.length() < keeper_shot_speed

		if dist_ball <= keeper_catch_distance and (toward_goal or ball_slow):
			# Defesa: a bola chegou ao alcance vindo pro gol (ou parada perto) ->
			# agarra e parte pro arremesso. A condição evita re-pegar a bola que
			# o próprio goleiro acabou de arremessar (que sai rápida e pro campo).
			_keeper_catch(keeper, line_x)
		elif cd <= 0.0 and dist_ball <= keeper_dive_distance and toward_goal and hvel.length() >= keeper_shot_speed:
			# Chute indo pro canto: mergulha pro lado da bola (o colisor maior ajuda a pegar).
			var ball_side := signf(ball_pos.z - next_pos.z)
			if ball_side == 0.0:
				ball_side = 1.0
			var dive_axis := float(_keeper_dive_axis.get(key, 1.0))
			var clip: StringName = &"DiveA" if ball_side == dive_axis else &"DiveB"
			_play_ai_anim(keeper, clip, true)
			_keeper_action_cd[key] = keeper_action_cooldown

	_set_ai_motion_anim(keeper, moved, keeper_ground_speed)


## Defesa: o goleiro pega a bola. Ela é congelada e passa a ser segurada na mão;
## dispara a animação de arremesso e define o alvo do passe (player p/ o amarelo,
## atacante p/ o vermelho).
func _keeper_catch(keeper: Node3D, line_x: float) -> void:
	if _ball == null:
		return
	_ball_holder = keeper
	_hold_timer = keeper_throw_windup
	_hold_line_x = line_x
	_hold_target = _player
	_hold_throw_started = false
	_ball.freeze = true
	_ball.linear_velocity = Vector3.ZERO
	_ball.angular_velocity = Vector3.ZERO
	_play_ai_anim(keeper, &"Idle", true)
	_keeper_action_cd[keeper.get_instance_id()] = keeper_action_cooldown


## Mantém a bola grudada na mão durante a animação de arremesso e, no fim do
## windup, solta em direção ao companheiro.
func _update_keeper_hold(keeper: Node3D, delta: float) -> void:
	var hand := _keeper_hand.get(keeper.get_instance_id()) as BoneAttachment3D
	if hand != null and _ball != null:
		_ball.global_position = hand.global_position + Vector3.UP * keeper_hand_lift
		_ball.linear_velocity = Vector3.ZERO
		_ball.angular_velocity = Vector3.ZERO

	if not _keeper_area_clear_for_throw():
		_hold_timer = keeper_throw_windup
		_set_ai_motion_anim(keeper, false)
		return

	if not _hold_throw_started:
		_hold_throw_started = true
		_hold_timer = keeper_throw_windup
		_play_ai_anim(keeper, &"Throw", true)

	_hold_timer -= delta
	if _hold_timer <= 0.0:
		_keeper_release(keeper)


## Solta a bola na direção do companheiro, com força proporcional à distância e um
## leve arco (arremesso por cima).
func _keeper_release(keeper: Node3D) -> void:
	if _ball == null:
		_ball_holder = null
		return

	var from := _ball.global_position
	var to: Vector3
	if _hold_target != null and is_instance_valid(_hold_target):
		to = _hold_target.global_position + Vector3(0.0, 0.55, 0.0)
		var tvel: Variant = _hold_target.get("velocity")
		if tvel is Vector3:
			to += Vector3((tvel as Vector3).x, 0.0, (tvel as Vector3).z) * 0.10
	else:
		to = Vector3(-signf(_hold_line_x) * 16.0, 0.55, 0.0)

	var dir := to - from
	var flat := Vector3(dir.x, 0.0, dir.z)
	if flat.length() < 0.01:
		flat = Vector3(-signf(_hold_line_x), 0.0, 0.0)
	var aim := flat.normalized()
	var power := clampf(flat.length() * 0.45, keeper_throw_min_power, keeper_throw_max_power)

	_ball.freeze = false
	_ball.sleeping = false
	_ball.linear_velocity = Vector3.ZERO
	_ball.angular_velocity = Vector3.ZERO
	_ball.apply_central_impulse(aim * power + Vector3.UP * power * 0.35)
	if _snd_throw:
		_snd_throw.play()

	_ball_holder = null
	_hold_target = null
	_hold_throw_started = false
	_keeper_action_cd[keeper.get_instance_id()] = keeper_action_cooldown


func _update_players_for_keeper_throw(delta: float) -> void:
	var players := [_yellow_defender, _yellow_mid_left, _yellow_mid_right, _red_mid_left, _red_mid_right, _red_attacker]
	for index in players.size():
		var player_node := players[index] as Node3D
		if player_node == null:
			continue

		var target := _keeper_area_exit_target(player_node, index)
		_move_ai_player(player_node, target, keeper_clear_area_speed, delta)


func _keeper_area_clear_for_throw() -> bool:
	for player_node in [_yellow_defender, _yellow_mid_left, _yellow_mid_right, _red_mid_left, _red_mid_right, _red_attacker]:
		if player_node == null:
			continue
		if _is_inside_keeper_area(player_node.global_position, keeper_area_clear_margin):
			return false
	return true


func _keeper_area_exit_target(player_node: Node3D, index: int) -> Vector3:
	var pos := player_node.global_position
	pos.y = 0.0
	var goal_sign := signf(_hold_line_x)
	if goal_sign == 0.0:
		goal_sign = -1.0

	var clear_x := _keeper_area_boundary_x(keeper_area_clear_margin) - goal_sign * (2.0 + float(index % 3) * 1.2)
	var lane_z := clampf(pos.z, -keeper_area_half_width - 3.0, keeper_area_half_width + 3.0)
	if absf(lane_z) < keeper_area_half_width - 2.0:
		var side := -1.0 if index % 2 == 0 else 1.0
		lane_z = side * (keeper_area_half_width + 2.0 + float(index % 3) * 1.4)

	return Vector3(clear_x, 0.0, clampf(lane_z, -touchline_z + 4.0, touchline_z - 4.0))


func _is_inside_keeper_area(position: Vector3, margin: float = 0.0) -> bool:
	var goal_sign := signf(_hold_line_x)
	if goal_sign == 0.0:
		goal_sign = -1.0

	if absf(position.z) > keeper_area_half_width + margin:
		return false

	var boundary_x := _keeper_area_boundary_x(margin)
	if goal_sign < 0.0:
		return position.x <= boundary_x
	return position.x >= boundary_x


func _keeper_area_boundary_x(margin: float = 0.0) -> float:
	var goal_sign := signf(_hold_line_x)
	if goal_sign == 0.0:
		goal_sign = -1.0

	if goal_sign < 0.0:
		return left_goal_line_x + keeper_area_depth + margin
	return right_goal_line_x - keeper_area_depth - margin


func _update_red_midfielder(player_node: Node3D, home: Vector3, ball_pos: Vector3, red_has_ball: bool, red_carrier: Node3D, brazil_carrier: Node3D, closest_red: Node3D, delta: float) -> void:
	if player_node == null:
		return

	if _update_ai_think_kick(player_node, delta, red_midfielder_speed):
		return
	if red_carrier == player_node:
		_update_red_carrier_to_attacker(player_node, red_midfielder_speed, delta)
		return

	var attacker_pos := _red_attacker.global_position if _red_attacker else Vector3(4.0, 0.0, 0.0)
	var distance_to_ball := _ground_distance(player_node.global_position, ball_pos)
	var ball_near_midfield := ball_pos.x > -20.0 and ball_pos.x < 28.0

	if brazil_carrier != null and not red_has_ball:
		var carrier_pos := brazil_carrier.global_position
		carrier_pos.y = 0.0
		var side := -1.0 if home.z < 0.0 else 1.0
		# o mais perto marca o portador; os outros recuam acompanhando a jogada,
		# posicionados do lado do próprio gol em relação à bola.
		var press_target := carrier_pos if player_node == closest_red else _red_field_target(home, carrier_pos, side, red_support_back + 3.0)
		_move_ai_player(player_node, press_target, red_midfielder_speed * 1.05, delta)
		_try_red_tackle(player_node, brazil_carrier, delta)
		return

	if red_has_ball and red_carrier != player_node:
		var side := -1.0 if home.z < 0.0 else 1.0
		# apoia o portador subindo à frente da bola e abrindo na faixa lateral
		var support_target := _red_field_target(home, ball_pos, side, -red_support_front)
		_move_ai_player(player_node, support_target, red_midfielder_speed * 0.9, delta)
		return

	if ball_near_midfield and player_node == closest_red and not _red_attacker_controls_ball():
		_move_ai_player(player_node, ball_pos, red_midfielder_speed, delta)
		if distance_to_ball <= red_steal_distance and _red_pass_cooldown <= 0.0:
			_start_ai_think_kick(player_node, _red_attacker, "red", red_think_kick_power)
			_red_pass_cooldown = 1.1
		return

	var default_side := -1.0 if home.z < 0.0 else 1.0
	_move_ai_player(player_node, _red_field_target(home, ball_pos, default_side, red_support_back), red_midfielder_speed * 0.85, delta)


func _update_red_attacker(ball_pos: Vector3, red_has_ball: bool, red_carrier: Node3D, brazil_carrier: Node3D, closest_red: Node3D, delta: float) -> void:
	if _red_attacker == null:
		return

	if _update_ai_think_kick(_red_attacker, delta, red_attacker_speed):
		return

	var distance_to_ball := _ground_distance(_red_attacker.global_position, ball_pos)

	if brazil_carrier != null and not red_has_ball:
		var carrier_pos := brazil_carrier.global_position
		carrier_pos.y = 0.0
		var press_target := carrier_pos + Vector3(1.0, 0.0, 0.0)
		if closest_red != _red_attacker:
			press_target = _block_target(Vector3(8.0, 0.0, 0.0), carrier_pos + Vector3(-7.0, 0.0, 0.0))
		_move_ai_player(_red_attacker, press_target, red_attacker_speed * 0.98, delta)
		_try_red_tackle(_red_attacker, brazil_carrier, delta)
		return

	if red_has_ball and red_carrier != _red_attacker:
		var receive_target := Vector3(clampf(ball_pos.x - 11.0, left_goal_line_x + 9.0, 8.0), 0.0, clampf(ball_pos.z * 0.55, -14.0, 14.0))
		_move_ai_player(_red_attacker, receive_target, red_attacker_speed * 0.82, delta)
		return

	if distance_to_ball <= red_control_distance + 0.85:
		if _can_red_attacker_shoot(ball_pos) and _start_ai_think_kick(_red_attacker, null, "red", red_shot_power):
			_update_ai_think_kick(_red_attacker, delta, red_attacker_speed)
			return
		var current_pos := _red_attacker.global_position
		var advance_x := maxf(left_goal_line_x + 6.5, current_pos.x - 9.0)
		var inside_cut := -signf(current_pos.z) * minf(absf(current_pos.z) * 0.18, 2.2)
		var run_target := Vector3(advance_x, 0.0, clampf(ball_pos.z * 0.45 + inside_cut, -goal_half_width * 1.05, goal_half_width * 1.05))
		_move_ai_player(_red_attacker, run_target, red_attacker_speed, delta)
		_control_ball_with_ai(_red_attacker, run_target, delta)
		return

	var chase_target := ball_pos
	if closest_red != _red_attacker and ball_pos.x > -4.0:
		chase_target = Vector3(clampf(ball_pos.x - 9.0, left_goal_line_x + 8.0, 8.0), 0.0, clampf(ball_pos.z * 0.65, -14.0, 14.0))

	_move_ai_player(_red_attacker, chase_target, red_attacker_speed, delta)
	if distance_to_ball <= red_counter_tackle_distance:
		_finish_red_tackle(_red_attacker, Vector3(left_goal_line_x + 13.0, 0.55, clampf(ball_pos.z * 0.35, -12.0, 12.0)))


func _red_attacker_controls_ball() -> bool:
	return _red_attacker != null and _ground_distance(_red_attacker.global_position, _ball_ground_position()) <= red_control_distance + 0.85


func _can_red_attacker_shoot(ball_pos: Vector3) -> bool:
	return ball_pos.x <= left_goal_line_x + red_shot_distance_from_goal and _red_shot_cooldown <= 0.0


func _get_red_ball_carrier() -> Node3D:
	var best_player: Node3D = null
	var best_distance := INF
	var ball_pos := _ball_ground_position()

	for player_node in [_red_attacker, _red_mid_left, _red_mid_right, _red_centerback]:
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


func _get_closest_player_to_ball(players: Array) -> Node3D:
	var best_player: Node3D = null
	var best_distance := INF
	var ball_pos := _ball_ground_position()

	for player_node in players:
		var candidate := player_node as Node3D
		if candidate == null:
			continue

		var distance := _ground_distance(candidate.global_position, ball_pos)
		if distance < best_distance:
			best_distance = distance
			best_player = candidate

	return best_player


## Elege o pressionador da bola de um time COM HISTERESE (Fase 2).
## Sem isto, "o mais perto" era recalculado todo frame e, com dois jogadores quase
## equidistantes, o papel ficava alternando — causando perseguição dupla e os dois
## convergindo um no outro. Aqui o papel "gruda" num jogador por ai_presser_min_hold
## e só passa pra outro se ele estiver claramente mais perto (switch_margin), se o
## atual abandonou a jogada (abandon_margin), ou se ficou inválido/atordoado.
func _elect_presser(team_key: String, candidates: Array, delta: float) -> Node3D:
	var ball_pos := _ball_ground_position()

	var best: Node3D = null
	var best_dist := INF
	for c in candidates:
		var node := c as Node3D
		if node == null:
			continue
		var d := _ground_distance(node.global_position, ball_pos)
		if d < best_dist:
			best_dist = d
			best = node

	var claim: Dictionary = _presser_claims.get(team_key, {})
	var current := claim.get("node", null) as Node3D
	var timer := maxf(float(claim.get("timer", 0.0)) - delta, 0.0)

	var current_valid := current != null and is_instance_valid(current) \
		and candidates.has(current) and not _is_ai_stunned(current)

	var should_switch := false
	if not current_valid:
		should_switch = true
	elif best != null and best != current:
		var current_dist := _ground_distance(current.global_position, ball_pos)
		var hold_elapsed := timer <= 0.0 and best_dist < current_dist - ai_presser_switch_margin
		var abandoned := current_dist > best_dist + ai_presser_abandon_margin
		should_switch = hold_elapsed or abandoned

	if should_switch and best != null:
		current = best
		timer = ai_presser_min_hold

	_presser_claims[team_key] = {"node": current, "timer": timer}
	return current


func _player_controls_ball() -> bool:
	if _player == null or _ball == null:
		return false
	if not Input.is_action_pressed("control_ball"):
		return false

	var control_radius := 1.65
	var player_control_distance: Variant = _player.get("control_distance")
	if player_control_distance is float:
		control_radius = float(player_control_distance) + 0.85
	return _ground_distance(_player.global_position, _ball_ground_position()) <= control_radius


func _yellow_contain_target(player_pos: Vector3, index: int, lane_side: float) -> Vector3:
	var goal_side := Vector3(1.0, 0.0, 0.0)
	var lateral_side := lane_side
	if lateral_side == 0.0:
		lateral_side = 0.0
	var width := yellow_contain_width
	if index == 1:
		width = 0.0
	var target := player_pos + goal_side * (yellow_contain_back + float(index) * 0.45) + Vector3(0.0, 0.0, lateral_side * width)
	var min_distance := yellow_contain_distance + float(index) * 0.25
	var away := target - player_pos
	away.y = 0.0
	if away.length() < min_distance:
		target = player_pos + away.normalized() * min_distance if away.length() > 0.01 else player_pos + goal_side * min_distance
	target.x = clampf(target.x, left_goal_line_x + 7.0, right_goal_line_x - 7.0)
	target.z = clampf(target.z, -touchline_z + 6.0, touchline_z - 6.0)
	return target


func _player_is_close_to_ball_for_yellow_pass() -> bool:
	if _player == null or _ball == null:
		return false
	return _ground_distance(_player.global_position, _ball_ground_position()) <= yellow_pass_to_player_min_distance


func _distance_point_to_segment(point: Vector3, start: Vector3, end: Vector3) -> float:
	point.y = 0.0
	start.y = 0.0
	end.y = 0.0
	var segment := end - start
	var length_sq := segment.length_squared()
	if length_sq <= 0.0001:
		return _ground_distance(point, start)
	var t := clampf((point - start).dot(segment) / length_sq, 0.0, 1.0)
	var projection := start + segment * t
	return _ground_distance(point, projection)


func _block_target(home: Vector3, anchor: Vector3) -> Vector3:
	home.y = 0.0
	anchor.y = 0.0
	var target := home + Vector3(
		clampf((anchor.x - home.x) * block_follow_x, -block_max_x_shift, block_max_x_shift),
		0.0,
		clampf((anchor.z - home.z) * block_follow_z, -block_max_z_shift, block_max_z_shift)
	)
	target.x = clampf(target.x, left_goal_line_x + 5.0, right_goal_line_x - 5.0)
	target.z = clampf(target.z, -touchline_z + 4.0, touchline_z - 4.0)
	return target


func _midfielder_block_target(home: Vector3, anchor: Vector3, lane_side: float) -> Vector3:
	var target := _block_target(home, anchor)
	if lane_side != 0.0:
		target.z = clampf(target.z + lane_side * block_lane_width * 0.32, -touchline_z + 5.0, touchline_z - 5.0)
	return target


func _try_yellow_tackle(player_node: Node3D, red_carrier: Node3D, delta: float) -> void:
	if player_node == null or red_carrier == null or _ball == null:
		return
	if _yellow_restart_grace_timer > 0.0:
		return

	var key := player_node.get_instance_id()
	if float(_yellow_tackle_cooldowns.get(key, 0.0)) > 0.0:
		return

	var player_to_ball := _ground_distance(player_node.global_position, _ball_ground_position())
	var player_to_carrier := _ground_distance(player_node.global_position, red_carrier.global_position)
	if player_to_ball > yellow_tackle_distance and player_to_carrier > yellow_tackle_distance + 0.35:
		return

	_face_ai_player(player_node, red_carrier.global_position, delta)
	_play_ai_anim(player_node, &"Kick", true)
	_finish_yellow_tackle(player_node)
	_yellow_tackle_cooldowns[key] = 1.15


func _try_red_tackle(player_node: Node3D, brazil_carrier: Node3D, delta: float) -> void:
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
	_face_ai_player(player_node, brazil_carrier.global_position, delta)
	_finish_red_tackle(player_node, target)
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
	var power := clampf(yellow_recovery_pass_power + distance * 0.04, 5.5, yellow_recovery_pass_power + 1.8)
	_soft_touch_ball_toward(receive_target + Vector3(0.0, 0.55, 0.0), power, 0.02)


func _finish_yellow_tackle(player_node: Node3D) -> void:
	if player_node == null or _player == null or _ball == null:
		return

	# Quem estava com a bola (o vermelho) perde a posse e fica se recompondo antes
	# de voltar a disputar. A bola NÃO é teleportada: é tocada fisicamente na direção
	# do brasileiro a partir de onde ela está.
	var loser := _get_red_ball_carrier()
	if loser != null:
		_stun_ai_player(loser, ai_recovery_stun)
	_ball.sleeping = false
	if not _player_is_close_to_ball_for_yellow_pass():
		_start_ai_think_kick(player_node, _player, "yellow", yellow_think_kick_power)


func _finish_red_tackle(player_node: Node3D, target: Vector3) -> void:
	if player_node == null or _ball == null:
		return

	# Quem estava com a bola (brasileiro/IA) perde a posse e fica se recompondo.
	# O humano não é "stunado" (ele segue no controle do jogador).
	var loser := _get_brazil_ball_carrier()
	if loser != null:
		_stun_ai_player(loser, ai_recovery_stun)

	_ball.sleeping = false
	_start_ai_think_kick(player_node, _red_attacker if player_node != _red_attacker else null, "red", red_think_kick_power)


func _start_ai_think_kick(player_node: Node3D, target_node: Node3D, team: String, power: float) -> bool:
	if player_node == null or _ball == null or _ball_holder != null:
		return false
	if team == "yellow" and _yellow_restart_grace_timer > 0.0:
		return false
	if team == "yellow" and target_node == _player and _player_is_close_to_ball_for_yellow_pass():
		return false

	var key := player_node.get_instance_id()
	if _ai_kick_plans.has(key) or float(_ai_think_cooldowns.get(key, 0.0)) > 0.0:
		return false
	if _ground_distance(player_node.global_position, _ball_ground_position()) > red_control_distance + 1.25:
		return false

	var player_pos := player_node.global_position
	player_pos.y = 0.0
	var retreat_dir := Vector3(1.0 if team == "red" else -1.0, 0.0, 0.0)

	var retreat_target := player_pos + retreat_dir.normalized() * ai_think_retreat_distance
	retreat_target.x = clampf(retreat_target.x, left_goal_line_x + 6.0, right_goal_line_x - 6.0)
	retreat_target.z = clampf(retreat_target.z, -touchline_z + 5.0, touchline_z - 5.0)

	_ai_kick_plans[key] = {
		"team": team,
		"target_node": target_node,
		"power": power,
		"phase": "retreat",
		"timer": ai_think_retreat_time,
		"retreat_target": retreat_target,
	}
	return true


func _update_ai_think_kick(player_node: Node3D, delta: float, speed: float) -> bool:
	if player_node == null or _ball == null:
		return false

	var key := player_node.get_instance_id()
	if not _ai_kick_plans.has(key):
		return false

	var plan := _ai_kick_plans[key] as Dictionary
	if _ground_distance(player_node.global_position, _ball_ground_position()) > red_control_distance + 2.0:
		_ai_kick_plans.erase(key)
		return false

	var phase := String(plan.get("phase", "retreat"))
	var team := String(plan.get("team", "red"))
	var target_node := plan.get("target_node", null) as Node3D
	if team == "yellow" and target_node == _player and _player_is_close_to_ball_for_yellow_pass():
		_ai_kick_plans.erase(key)
		_ai_think_cooldowns[key] = 0.45
		return false
	var target := _get_ai_think_kick_target(player_node, target_node, team)

	if phase == "retreat":
		var retreat_target := plan["retreat_target"] as Vector3
		_move_ai_player(player_node, retreat_target, speed * 0.72, delta)
		_control_ball_with_ai(player_node, retreat_target, delta, speed * 0.72)
		plan["timer"] = float(plan["timer"]) - delta
		if float(plan["timer"]) <= 0.0 or _ground_distance(player_node.global_position, retreat_target) < 0.25:
			plan["phase"] = "turn"
			plan["timer"] = ai_think_turn_time
		_ai_kick_plans[key] = plan
		return true

	if phase == "turn":
		_face_ai_player(player_node, target, delta)
		var player_pos := player_node.global_position
		player_pos.y = 0.0
		var aim_dir := target - player_pos
		aim_dir.y = 0.0
		if aim_dir.length() > 0.1:
			_control_ball_with_ai(player_node, player_pos + aim_dir.normalized() * red_control_distance, delta, speed * 0.25)
		_set_ai_motion_anim(player_node, false)
		plan["timer"] = float(plan["timer"]) - delta
		if float(plan["timer"]) <= 0.0:
			_play_ai_anim(player_node, &"Kick", true)
			_soft_touch_ball_toward(target, float(plan.get("power", red_think_kick_power)), 0.08)
			if _snd_kick:
				_snd_kick.play()
			if team == "red" and target_node == null:
				_red_shot_cooldown = 1.6
			_ai_kick_plans.erase(key)
			_ai_think_cooldowns[key] = 1.15
		else:
			_ai_kick_plans[key] = plan
		return true

	_ai_kick_plans.erase(key)
	return false


func _get_ai_think_kick_target(player_node: Node3D, target_node: Node3D, team: String) -> Vector3:
	if team == "yellow":
		return _get_player_receive_target()
	if target_node != null and is_instance_valid(target_node):
		return target_node.global_position + Vector3(-4.0, 0.55, clampf(-target_node.global_position.z * 0.18, -3.5, 3.5))

	var shot_z := clampf(sin(_red_dribble_phase * 1.7) * goal_half_width * 0.32, -goal_half_width * 0.45, goal_half_width * 0.45)
	return Vector3(left_goal_line_x - 2.0, 0.65, shot_z)


func _get_player_receive_target() -> Vector3:
	if _player == null:
		return Vector3(-11.0, 0.55, 0.0)

	var receive_target := _player.global_position
	var player_velocity: Variant = _player.get("velocity")
	if player_velocity is Vector3:
		var forward := Vector3((player_velocity as Vector3).x, 0.0, (player_velocity as Vector3).z)
		if forward.length() > 0.2:
			receive_target += forward.normalized() * 2.5
	receive_target.y = 0.55
	return receive_target


func _control_ball_with_ai(player_node: Node3D, target: Vector3, delta: float, carry_speed: float = red_attacker_speed) -> void:
	if player_node == null or _ball == null:
		return

	var player_pos := player_node.global_position
	player_pos.y = 0.0
	var move_dir := target - player_pos
	move_dir.y = 0.0
	if move_dir.length() < 0.01:
		return
	move_dir = move_dir.normalized()

	# Velocidade real do condutor (base da Fase 3): a bola viaja JUNTO com ele.
	# Sem casar o feed-forward com a velocidade real, a bola ficava pra trás —
	# a mesma falha que o jogador humano tinha.
	var carrier_vel := _ai_velocities.get(player_node.get_instance_id(), Vector3.ZERO) as Vector3
	carrier_vel.y = 0.0
	var carrier_speed := carrier_vel.length()

	# Ponto à frente do pé, na direção em que ele REALMENTE anda (cai pro alvo se parado).
	var carry_dir := move_dir
	if carrier_speed > 0.5:
		carry_dir = carrier_vel.normalized()
	var desired_ball_pos := player_pos + carry_dir * red_control_distance

	var flat_ball := Vector3(_ball.global_position.x, 0.0, _ball.global_position.z)
	var correction := Vector3(desired_ball_pos.x, 0.0, desired_ball_pos.z) - flat_ball

	# Feed-forward (velocidade do condutor) + correção que gruda a bola à frente.
	var desired_velocity := carrier_vel + correction * ai_ball_carry_correction_speed

	# Teto sobe junto com a velocidade do condutor pra a bola nunca ser deixada pra trás.
	var speed_cap := maxf(carry_speed + ai_ball_carry_extra_speed, carrier_speed * 1.5)
	if desired_velocity.length() > speed_cap:
		desired_velocity = desired_velocity.normalized() * speed_cap

	var ball_flat_vel := Vector3(_ball.linear_velocity.x, 0.0, _ball.linear_velocity.z)
	var force := (desired_velocity - ball_flat_vel) * _ball.mass * 18.0
	if force.length() > ai_ball_carry_max_force:
		force = force.normalized() * ai_ball_carry_max_force
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

	var key := player_node.get_instance_id()
	var vel := _ai_velocities.get(key, Vector3.ZERO) as Vector3

	# Atordoado: freia até parar (não teleporta a 0) e fica encarando a jogada.
	if _is_ai_stunned(player_node):
		vel = vel.move_toward(Vector3.ZERO, ai_decel * delta)
		_ai_velocities[key] = vel
		_set_ai_motion_anim(player_node, false)
		_face_ai_player_focus(player_node, target, delta)
		return

	target.x = clampf(target.x, left_goal_line_x + 5.0, right_goal_line_x - 5.0)
	target.y = 0.0
	target.z = clampf(target.z, -touchline_z + 4.0, touchline_z - 4.0)

	var pos := player_node.global_position
	pos.y = 0.0
	var distance_to_target := _ground_distance(pos, target)

	# Velocidade desejada: aponta pro alvo na velocidade pedida, mas com "arrive" —
	# reduz ao chegar perto pra não passar do ponto nem ficar oscilando em cima dele.
	var desired := Vector3.ZERO
	if distance_to_target > 0.08:
		var dir := target - pos
		dir.y = 0.0
		dir = dir.normalized()
		var arrive_speed := speed
		if distance_to_target < ai_arrive_radius:
			arrive_speed = speed * (distance_to_target / ai_arrive_radius)
		desired = dir * arrive_speed

	# Acelera/desacelera a velocidade atual rumo à desejada -> inércia, sem virar
	# de 180° num frame. Desacelera mais rápido do que acelera (mais responsivo).
	var rate := ai_accel if desired.length() >= vel.length() else ai_decel
	vel = vel.move_toward(desired, rate * delta)

	var next_pos := pos + vel * delta
	next_pos = _separate_ai_position(player_node, next_pos)

	# Move o AnimatableBody diretamente para a colisão seguir sem delay
	var body := player_node.get_node_or_null("NpcBodyCollider") as AnimatableBody3D
	if body:
		body.global_position = next_pos

	player_node.global_position = next_pos

	# Reconcilia a velocidade com o que REALMENTE andou (separação/clamp podem ter
	# barrado o passo) pra não acumular empurrão contra colega ou parede.
	if delta > 0.0:
		vel = (next_pos - pos) / delta
	_ai_velocities[key] = vel

	var actual_movement := _ground_distance(pos, next_pos)
	var moved := actual_movement > ai_run_anim_min_movement and distance_to_target > ai_run_anim_min_target_distance
	var ground_speed := actual_movement / delta if delta > 0.0 else 0.0
	_set_ai_motion_anim(player_node, moved, ground_speed)

	# Rumo segue a direção REAL do movimento quando há velocidade relevante; parado
	# ou bem devagar, mantém o foco no alvo/bola (comportamento anterior).
	var face_target := target
	if vel.length() > ai_face_min_speed:
		face_target = pos + vel.normalized() * 2.0
	_face_ai_player_focus(player_node, face_target, delta)


func _separate_ai_position(player_node: Node3D, desired_pos: Vector3) -> Vector3:
	var my_radius := _get_player_collision_radius(player_node)
	var push := Vector3.ZERO

	for other in _get_player_bodies_for_separation():
		if other == null or other == player_node:
			continue

		var other_pos := other.global_position
		other_pos.y = 0.0
		var away := desired_pos - other_pos
		away.y = 0.0
		var distance := away.length()

		# Distâncias por par usando os raios REAIS (goleiros são maiores). "core" é o
		# encostar de fato; "personal" inclui uma folga de espaço pessoal.
		var core := my_radius + _get_player_collision_radius(other)
		var personal := core + ai_separation_buffer
		if distance >= personal:
			continue

		# Direção pra longe do outro; se estiverem praticamente em cima um do outro,
		# usa uma direção determinística pra não ficar indefinido (nem aleatório).
		var dir := away / distance if distance > 0.001 else _fallback_separation_dir(player_node, other)

		if distance < core:
			# Sobreposição real: empurra forte (núcleo duro). Como o outro também se
			# afasta no frame dele, resolver uma fração por frame converge sem tranco.
			push += dir * (core - distance) * ai_separation_hardness
		else:
			# Zona pessoal: empurrãozinho suave proporcional pra manterem distância.
			push += dir * ((personal - distance) / personal) * ai_separation_push

	desired_pos += push
	desired_pos.x = clampf(desired_pos.x, left_goal_line_x + 5.0, right_goal_line_x - 5.0)
	desired_pos.y = 0.0
	desired_pos.z = clampf(desired_pos.z, -touchline_z + 4.0, touchline_z - 4.0)
	return desired_pos


## Direção de separação estável pra quando dois jogadores estão exatamente na mesma
## posição (away ~ 0). Deriva do id pra ser determinística e oposta entre o par.
func _fallback_separation_dir(player_node: Node3D, other: Node3D) -> Vector3:
	var dir_sign := 1.0 if player_node.get_instance_id() > other.get_instance_id() else -1.0
	var angle := float(player_node.get_instance_id() % 628) * 0.01
	return Vector3(cos(angle), 0.0, sin(angle)) * dir_sign


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
		var rebound_distance := _get_player_collision_radius(player_node) + 0.45
		if distance < 0.01 or distance > rebound_distance:
			continue

		# O colisor (AnimatableBody) já trata o ressalto quando o jogador se move.
		# Aqui só damos um empurrãozinho de separação pra bola não ficar presa
		# encostada num jogador parado — bem mais fraco que antes, sem somar tranco.
		var penetration := (rebound_distance - distance) / rebound_distance
		var away_dir := away.normalized()
		_ball.apply_central_impulse(away_dir * 0.6 * penetration)


func _get_player_collision_radius(player_node: Node3D) -> float:
	if player_node == null:
		return ai_body_radius
	return float(_ai_collision_radii.get(player_node.get_instance_id(), ai_body_radius))


func _get_ai_players() -> Array[Node3D]:
	return [_yellow_defender, _yellow_mid_left, _yellow_mid_right, _yellow_keeper, _red_defender, _red_mid_left, _red_mid_right, _red_attacker, _red_centerback]


func _get_player_bodies_for_separation() -> Array[Node3D]:
	var bodies := _get_ai_players()
	if _player:
		bodies.append(_player)
	return bodies


func _face_node_at(player_node: Node3D, target: Vector3) -> void:
	if player_node == null:
		return
	var dir := target - player_node.global_position
	dir.y = 0.0
	if dir.length() < 0.05:
		return
	player_node.rotation.y = atan2(dir.x, dir.z)


func _face_ai_player(player_node: Node3D, target: Vector3, delta: float) -> void:
	if player_node == null:
		return

	var dir := target - player_node.global_position
	dir.y = 0.0
	if dir.length() < 0.05:
		return

	var target_yaw := atan2(dir.x, dir.z)
	player_node.rotation.y = lerp_angle(player_node.rotation.y, target_yaw, clampf(ai_face_rotate_speed * delta, 0.0, 1.0))


func _face_ai_player_focus(player_node: Node3D, move_target: Vector3, delta: float) -> void:
	if player_node == null:
		return

	var focus := move_target
	if _ball != null:
		var ball_pos := _ball_ground_position()
		var player_pos := player_node.global_position
		player_pos.y = 0.0
		var distance_to_ball := _ground_distance(player_pos, ball_pos)
		# Parte C: rampa suave em vez do salto seco em 1.8m (que causava os giros).
		# Perto (<= near) encara a bola; longe (>= far) usa o peso base; entre os
		# dois interpola com smoothstep pra direção de olhar não pular.
		var weight := ai_face_ball_weight
		if distance_to_ball <= ai_face_ball_near:
			weight = 1.0
		elif distance_to_ball < ai_face_ball_far:
			var t := smoothstep(ai_face_ball_far, ai_face_ball_near, distance_to_ball)
			weight = lerpf(ai_face_ball_weight, 1.0, t)
		focus = move_target.lerp(ball_pos, weight)

	_face_ai_player(player_node, focus, delta)


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


func _set_ai_motion_anim(player_node: Node3D, moving: bool, ground_speed: float = -1.0) -> void:
	var anim := _get_ai_animation_player(player_node)
	if anim == null:
		return

	# Não interrompe um clipe de ação que ainda está genuinamente tocando.
	var current := StringName(anim.current_animation)
	if anim.is_playing() and ACTION_ANIMS.has(current) and not _action_anim_finished(anim):
		return

	if moving:
		_play_ai_anim(player_node, &"Running")
		# Parte A: passada acompanha a velocidade de chão -> sem patinar.
		# ground_speed < 0 = chamador não informou (ex.: posicionamento) -> mantém 1.0x.
		if ground_speed >= 0.0:
			var ref := maxf(ai_run_anim_reference_speed, 0.01)
			anim.speed_scale = clampf(ground_speed / ref, ai_run_anim_min_speed_scale, ai_run_anim_max_speed_scale)
		else:
			anim.speed_scale = 1.0
	else:
		anim.speed_scale = 1.0
		_play_ai_anim(player_node, &"Idle")


## Um clipe de ação (não-looping) chegou ao fim? Serve de base pro watchdog e pra
## liberar a volta à locomoção mesmo que o AnimationPlayer não tenha parado sozinho.
func _action_anim_finished(anim: AnimationPlayer) -> bool:
	if not anim.is_playing():
		return true
	var length := anim.current_animation_length
	return length > 0.0 and anim.current_animation_position >= length - 0.02


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

	if not force and anim.is_playing() and StringName(anim.current_animation) == target:
		return true

	var blend := ai_action_anim_blend if force else ai_anim_blend
	anim.play(target, blend)
	return true


func _get_ai_animation_player(player_node: Node3D) -> AnimationPlayer:
	if player_node == null:
		return null
	return _ai_animation_players.get(player_node.get_instance_id(), null) as AnimationPlayer


func _reset_ai_for_restart() -> void:
	_stun_timers.clear()
	_ai_kick_plans.clear()
	_ai_think_cooldowns.clear()
	_presser_claims.clear()
	_ai_velocities.clear()
	_keeper_action_cd.clear()
	_ball_holder = null
	_hold_target = null
	_hold_timer = 0.0
	_hold_throw_started = false
	for slot in _yellow_defense:
		var player_node := slot["node"] as Node3D
		if player_node == null:
			continue
		player_node.global_position = slot["home"] as Vector3
		_play_ai_anim(player_node, &"Idle", true)

	if _yellow_keeper:
		_yellow_keeper.global_position = Vector3(left_goal_line_x + keeper_line_offset, keeper_ground_y, 0.0)
		_play_ai_anim(_yellow_keeper, &"Idle", true)

	var red_homes := {
		_red_defender: Vector3(right_goal_line_x - keeper_line_offset, keeper_ground_y, 0.0),
		_red_mid_left: Vector3(18.0, 0.0, -14.0),
		_red_mid_right: Vector3(18.0, 0.0, 14.0),
		_red_attacker: Vector3(8.0, 0.0, 0.0),
		_red_centerback: Vector3(26.0, 0.0, 0.0),
	}
	for player_node in red_homes:
		if player_node == null:
			continue
		player_node.global_position = red_homes[player_node]
		_play_ai_anim(player_node, &"Idle", true)


func _place_goalkeepers() -> void:
	if _yellow_keeper:
		_yellow_keeper.global_position = Vector3(left_goal_line_x + keeper_line_offset, keeper_ground_y, 0.0)
	if _red_defender:
		_red_defender.global_position = Vector3(right_goal_line_x - keeper_line_offset, keeper_ground_y, 0.0)


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

	_transition_rect = ColorRect.new()
	_transition_rect.name = "RestartFade"
	_transition_rect.color = Color.BLACK
	_transition_rect.modulate = Color(1.0, 1.0, 1.0, 0.0)
	_transition_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_transition_rect.visible = false
	_transition_rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	layer.add_child(_transition_rect)


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


func _fade_match(to_black: bool) -> void:
	if _transition_rect == null:
		return

	_transition_rect.visible = true
	var target_alpha := 1.0 if to_black else 0.0
	var tween := create_tween()
	tween.tween_property(_transition_rect, "modulate", Color(1.0, 1.0, 1.0, target_alpha), restart_fade_time)
	await tween.finished
	if not to_black:
		_transition_rect.visible = false


func _hide_collision_debug_shapes() -> void:
	for node in find_children("*", "CollisionShape3D", true, false):
		var shape_node := node as CollisionShape3D
		if shape_node != null:
			shape_node.visible = false


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
	body.collision_layer = 32
	body.collision_mask = 4

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

func _add_field_wall(parent: Node, wall_name: String, pos: Vector3, size: Vector3) -> void:
	var shape := BoxShape3D.new()
	shape.size = size
	var col := CollisionShape3D.new()
	col.name = wall_name
	col.position = pos
	col.shape = shape
	col.visible = false
	parent.add_child(col)
