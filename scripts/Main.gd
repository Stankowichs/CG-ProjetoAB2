extends Node3D

const MAIN_SCENE_PATH := "res://scenes/Main.tscn"
const RESET_KEY := KEY_R
const SCOREBOARD_TEXTURE := preload("res://placar.png")
const SCOREBOARD_SOURCE_REGION := Rect2(20.0, 420.0, 960.0, 140.0)
const SCOREBOARD_SIZE := Vector2(300.0, 43.0)
const SCOREBOARD_CENTER_OFFSET_X := -350.0
const KEEPER_ANIM_LIB := "res://anims/hulk_keeper_anims.res"
const KEEPER_THROW_BONE := &"mixamorig_RightHand"   # mão que segura a bola no arremesso

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
@export var ai_think_retreat_distance: float = 3.2
@export var ai_think_retreat_time: float = 0.55
@export var ai_think_turn_time: float = 0.28
@export var red_think_kick_power: float = 15.5
@export var yellow_think_kick_power: float = 12.5

@export_group("Visualização de colisão")
@export var show_collision_radii: bool = true
@export var player_body_radius: float = 0.4
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
@export var keeper_throw_min_power: float = 7.0
@export var keeper_throw_max_power: float = 12.0
@export var keeper_hand_lift: float = 0.08    # leve ajuste da bola na mão

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
var _ai_collision_radii: Dictionary = {}
var _ai_kick_plans: Dictionary = {}
var _ai_think_cooldowns: Dictionary = {}
var _keeper_action_cd: Dictionary = {}   # instance_id -> tempo até poder mergulhar/repor de novo
var _keeper_dive_axis: Dictionary = {}   # instance_id -> sinal de Z (mundo) que o clipe DiveA cobre
var _keeper_hand: Dictionary = {}        # instance_id -> BoneAttachment3D na mão do goleiro
var _ball_holder: Node3D = null          # goleiro que está com a bola na mão (ou null)
var _hold_timer: float = 0.0             # tempo restante segurando a bola antes de soltar
var _hold_target: Node3D = null          # pra quem o goleiro vai arremessar
var _hold_line_x: float = 0.0            # linha do gol do goleiro que está segurando

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
	# se algum goleiro estava segurando a bola, libera a posse
	_ball_holder = null
	_hold_target = null
	_hold_timer = 0.0
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
	for red_player in [_red_mid_left, _red_mid_right, _red_attacker]:
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
	body.sync_to_physics = false  # controlamos a posição manualmente
	body.collision_layer = 1
	body.collision_mask = 4
	player_node.add_child(body)

	var shape := CollisionShape3D.new()
	shape.name = "Shape"
	shape.position = Vector3(0.0, 0.9, 2.0)  # offset zerado — posição já vem correta do _move_ai_player
	var capsule := CapsuleShape3D.new()
	capsule.radius = radius
	capsule.height = 1.8
	shape.shape = capsule
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

	_update_yellow_defense(delta)
	_update_red_team(delta)
	_update_goalkeeper(_yellow_keeper, left_goal_line_x + keeper_line_offset, delta)
	_update_goalkeeper(_red_defender, right_goal_line_x - keeper_line_offset, delta)
	_apply_ball_body_rebounds()


func _update_yellow_defense(delta: float) -> void:
	var ball_pos := _ball_ground_position()
	var red_carrier := _get_red_ball_carrier()
	var red_has_ball := red_carrier != null
	var brazil_carrier := _get_brazil_ball_carrier()
	var closest_yellow := _get_closest_player_to_ball([_yellow_defender, _yellow_mid_left, _yellow_mid_right])

	for index in _yellow_defense.size():
		var slot := _yellow_defense[index]
		var player_node := slot["node"] as Node3D
		if player_node == null:
			continue

		if _update_ai_think_kick(player_node, delta, yellow_pressure_speed):
			continue
		if not red_has_ball and brazil_carrier == player_node and _start_ai_think_kick(player_node, _player, "yellow", yellow_think_kick_power):
			_update_ai_think_kick(player_node, delta, yellow_pressure_speed)
			continue

		var home := slot["home"] as Vector3

		if red_has_ball:
			var carrier_pos := red_carrier.global_position
			carrier_pos.y = 0.0
			var target := carrier_pos
			if player_node != closest_yellow:
				var cover_z := clampf(carrier_pos.z + (index - 1) * 3.0, -18.0, 18.0)
				target = Vector3(clampf(carrier_pos.x + 2.5 + index * 0.8, home.x - 3.0, home.x + 10.0), 0.0, cover_z)
			target.x = minf(target.x, home.x + 11.0)
			target.z = clampf(target.z, home.z - 11.0, home.z + 11.0)
			_move_ai_player(player_node, target, yellow_pressure_speed, delta)
			_try_yellow_tackle(player_node, red_carrier)
		else:
			if player_node == closest_yellow:
				_move_ai_player(player_node, ball_pos, yellow_pressure_speed, delta)
			else:
				var support := home.lerp(ball_pos, 0.32)
				support.z += float(index - 1) * 4.0
				support.x = clampf(support.x, home.x - 3.0, home.x + 10.0)
				support.z = clampf(support.z, -22.0, 22.0)
				_move_ai_player(player_node, support, yellow_defense_speed, delta)


func _update_red_team(delta: float) -> void:
	var ball_pos := _ball_ground_position()
	var red_carrier := _get_red_ball_carrier()
	var red_has_ball := red_carrier != null
	var brazil_carrier := _get_brazil_ball_carrier()
	var closest_red := _get_closest_player_to_ball([_red_mid_left, _red_mid_right, _red_attacker])

	_update_red_midfielder(_red_mid_left, Vector3(18.0, 0.0, -14.0), ball_pos, red_has_ball, red_carrier, brazil_carrier, closest_red, delta)
	_update_red_midfielder(_red_mid_right, Vector3(18.0, 0.0, 14.0), ball_pos, red_has_ball, red_carrier, brazil_carrier, closest_red, delta)
	_update_red_attacker(ball_pos, red_has_ball, red_carrier, brazil_carrier, closest_red, delta)


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
	var moved := _ground_distance(pos, next_pos) > 0.01

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

	_set_ai_motion_anim(keeper, moved)


## Defesa: o goleiro pega a bola. Ela é congelada e passa a ser segurada na mão;
## dispara a animação de arremesso e define o alvo do passe (player p/ o amarelo,
## atacante p/ o vermelho).
func _keeper_catch(keeper: Node3D, line_x: float) -> void:
	if _ball == null:
		return
	_ball_holder = keeper
	_hold_timer = keeper_throw_windup
	_hold_line_x = line_x
	_hold_target = _player if keeper == _yellow_keeper else _red_attacker
	_ball.freeze = true
	_ball.linear_velocity = Vector3.ZERO
	_ball.angular_velocity = Vector3.ZERO
	_play_ai_anim(keeper, &"Throw", true)
	_keeper_action_cd[keeper.get_instance_id()] = keeper_action_cooldown


## Mantém a bola grudada na mão durante a animação de arremesso e, no fim do
## windup, solta em direção ao companheiro.
func _update_keeper_hold(keeper: Node3D, delta: float) -> void:
	var hand := _keeper_hand.get(keeper.get_instance_id()) as BoneAttachment3D
	if hand != null and _ball != null:
		_ball.global_position = hand.global_position + Vector3.UP * keeper_hand_lift
		_ball.linear_velocity = Vector3.ZERO
		_ball.angular_velocity = Vector3.ZERO

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
		to = _hold_target.global_position + Vector3(0.0, 0.7, 0.0)
		var tvel: Variant = _hold_target.get("velocity")
		if tvel is Vector3:
			to += Vector3((tvel as Vector3).x, 0.0, (tvel as Vector3).z) * 0.25
	else:
		to = Vector3(-signf(_hold_line_x) * 16.0, 0.7, 0.0)

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

	_ball_holder = null
	_hold_target = null
	_keeper_action_cd[keeper.get_instance_id()] = keeper_action_cooldown


func _update_red_midfielder(player_node: Node3D, home: Vector3, ball_pos: Vector3, red_has_ball: bool, red_carrier: Node3D, brazil_carrier: Node3D, closest_red: Node3D, delta: float) -> void:
	if player_node == null:
		return

	if _update_ai_think_kick(player_node, delta, red_midfielder_speed):
		return
	if red_carrier == player_node and _start_ai_think_kick(player_node, _red_attacker, "red", red_think_kick_power):
		_update_ai_think_kick(player_node, delta, red_midfielder_speed)
		return

	var attacker_pos := _red_attacker.global_position if _red_attacker else Vector3(4.0, 0.0, 0.0)
	var distance_to_ball := _ground_distance(player_node.global_position, ball_pos)
	var ball_near_midfield := ball_pos.x > -20.0 and ball_pos.x < 28.0

	if brazil_carrier != null and not red_has_ball:
		var carrier_pos := brazil_carrier.global_position
		carrier_pos.y = 0.0
		var side := -1.0 if home.z < 0.0 else 1.0
		var press_target := carrier_pos if player_node == closest_red else carrier_pos + Vector3(1.6, 0.0, side * 2.2)
		_move_ai_player(player_node, press_target, red_midfielder_speed * 1.05, delta)
		_try_red_tackle(player_node, brazil_carrier)
		return

	if red_has_ball and red_carrier != player_node:
		var side := -1.0 if home.z < 0.0 else 1.0
		var support_x := clampf(ball_pos.x + 4.5, left_goal_line_x + 14.0, 20.0)
		var support_z := clampf(ball_pos.z + side * 5.0, -18.0, 18.0)
		_move_ai_player(player_node, Vector3(support_x, 0.0, support_z), red_midfielder_speed * 0.78, delta)
		return

	if ball_near_midfield and player_node == closest_red and not _red_attacker_controls_ball():
		_move_ai_player(player_node, ball_pos, red_midfielder_speed, delta)
		if distance_to_ball <= red_steal_distance and _red_pass_cooldown <= 0.0:
			_start_ai_think_kick(player_node, _red_attacker, "red", red_think_kick_power)
			_red_pass_cooldown = 1.1
		return

	var support_shift := Vector3(clampf((ball_pos.x - home.x) * 0.10, -5.0, 4.0), 0.0, clampf((ball_pos.z - home.z) * 0.18, -5.0, 5.0))
	_move_ai_player(player_node, home + support_shift, red_midfielder_speed * 0.72, delta)


func _update_red_attacker(ball_pos: Vector3, red_has_ball: bool, red_carrier: Node3D, brazil_carrier: Node3D, closest_red: Node3D, delta: float) -> void:
	if _red_attacker == null:
		return

	if _update_ai_think_kick(_red_attacker, delta, red_attacker_speed):
		return

	var distance_to_ball := _ground_distance(_red_attacker.global_position, ball_pos)

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
	_ball.sleeping = false
	_start_ai_think_kick(player_node, _player, "yellow", yellow_think_kick_power)


func _finish_red_tackle(player_node: Node3D, target: Vector3) -> void:
	if player_node == null or _ball == null:
		return

	# Quem estava com a bola (brasileiro/IA) perde a posse e fica se recompondo.
	# O humano não é "stunado" (ele segue no controle do jogador).
	var loser := _get_brazil_ball_carrier()
	if loser != null:
		_stun_ai_player(loser, ai_recovery_stun)

	_snap_ai_player_toward(player_node, target)
	_ball.sleeping = false
	_start_ai_think_kick(player_node, _red_attacker if player_node != _red_attacker else null, "red", red_think_kick_power)


func _start_ai_think_kick(player_node: Node3D, target_node: Node3D, team: String, power: float) -> bool:
	if player_node == null or _ball == null or _ball_holder != null:
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
			_snap_ai_player_toward(player_node, target)
			_play_ai_anim(player_node, &"Kick", true)
			_soft_touch_ball_toward(target, float(plan.get("power", red_think_kick_power)), 0.08)
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

	var desired_ball_pos := player_pos + move_dir * red_control_distance
	desired_ball_pos.y = _ball.global_position.y
	var desired_velocity := move_dir * (carry_speed * 0.9) + (desired_ball_pos - _ball.global_position) / maxf(delta, 0.001)
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
	return [_yellow_defender, _yellow_mid_left, _yellow_mid_right, _yellow_keeper, _red_defender, _red_mid_left, _red_mid_right, _red_attacker]


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
	if anim.is_playing() and (current == &"Kick" or current == &"Pass" or current == &"Header" or current == &"PenaltyKick" or current == &"ScissorKick" or current == &"DiveA" or current == &"DiveB" or current == &"Throw"):
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
	_ai_kick_plans.clear()
	_ai_think_cooldowns.clear()
	_keeper_action_cd.clear()
	_ball_holder = null
	_hold_target = null
	_hold_timer = 0.0
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
