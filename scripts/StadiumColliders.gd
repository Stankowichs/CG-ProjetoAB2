extends Node3D

## Gera colisão para partes do estádio que precisam ser sólidas (trave e bancos)
## e cria paredes invisíveis nos limites jogáveis do campo.
##
## O estádio é um .glb só visual: a bola e o jogador atravessavam a trave e os
## bancos porque não havia corpo físico. Em vez de colidir o estádio inteiro
## (pesado demais), percorremos apenas os ramos da trave (khungthanh) e dos
## bancos/dugouts (cabin) e geramos uma colisão trimesh estática neles.
## Para o perímetro, usamos BoxShape3D: barato, estável e suficiente para
## impedir jogador e bola de saírem do estádio.

## Pedaços do nome dos nós do modelo que devem virar objetos sólidos.
@export var solid_node_keywords: PackedStringArray = ["khungthanh", "cabin"]

@export_group("Limites do campo")
@export var create_play_bounds: bool = true
@export var field_half_width: float = 58.0
@export var field_half_depth: float = 40.0
@export var wall_thickness: float = 2.0
@export var wall_height: float = 8.0
@export var wall_center_y: float = 4.0

var _colliders_created: int = 0


func _ready() -> void:
	for keyword in solid_node_keywords:
		for node in _find_nodes_containing(self, keyword):
			_make_solid(node)
	if create_play_bounds:
		_create_play_bounds()
	if _colliders_created == 0:
		push_warning("StadiumColliders: nenhum nó sólido encontrado (trave/banco).")


func _find_nodes_containing(root: Node, keyword: String) -> Array:
	var matches: Array = []
	var stack: Array = [root]
	while not stack.is_empty():
		var n: Node = stack.pop_back()
		if n != root and keyword in n.name:
			matches.append(n)
			continue # já cobre os filhos via _make_solid; não aninha buscas
		for child in n.get_children():
			stack.append(child)
	return matches


func _make_solid(branch: Node) -> void:
	# Gera colisão trimesh para cada malha dentro do ramo (trave ou banco).
	var stack: Array = [branch]
	while not stack.is_empty():
		var n: Node = stack.pop_back()
		if n is MeshInstance3D and n.mesh != null:
			n.create_trimesh_collision()
			_colliders_created += 1
		for child in n.get_children():
			stack.append(child)


func _create_play_bounds() -> void:
	var root := StaticBody3D.new()
	root.name = "PlayBounds"
	add_child(root)

	_add_wall(
		root,
		"TouchlineLeft",
		Vector3(-field_half_width - wall_thickness * 0.5, wall_center_y, 0.0),
		Vector3(wall_thickness, wall_height, field_half_depth * 2.0 + wall_thickness * 2.0)
	)
	_add_wall(
		root,
		"TouchlineRight",
		Vector3(field_half_width + wall_thickness * 0.5, wall_center_y, 0.0),
		Vector3(wall_thickness, wall_height, field_half_depth * 2.0 + wall_thickness * 2.0)
	)
	_add_wall(
		root,
		"GoalLineNorth",
		Vector3(0.0, wall_center_y, -field_half_depth - wall_thickness * 0.5),
		Vector3(field_half_width * 2.0 + wall_thickness * 2.0, wall_height, wall_thickness)
	)
	_add_wall(
		root,
		"GoalLineSouth",
		Vector3(0.0, wall_center_y, field_half_depth + wall_thickness * 0.5),
		Vector3(field_half_width * 2.0 + wall_thickness * 2.0, wall_height, wall_thickness)
	)


func _add_wall(parent: Node, wall_name: String, wall_position: Vector3, wall_size: Vector3) -> void:
	var shape := BoxShape3D.new()
	shape.size = wall_size

	var collision := CollisionShape3D.new()
	collision.name = wall_name
	collision.position = wall_position
	collision.shape = shape
	parent.add_child(collision)
	_colliders_created += 1
