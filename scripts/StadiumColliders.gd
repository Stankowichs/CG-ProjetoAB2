@tool
extends Node3D

@export var solid_node_keywords: PackedStringArray = ["khungthanh", "cabin"]

@export var bounds_offset: Vector3 = Vector3(0.0, 0.0, 0.0)

@export_group("Formato do estádio")
@export var create_play_bounds: bool = true
@export var straight_half_length: float = 52.0
## Largura do arco — deve coincidir com a metade da largura das laterais
@export var arc_radius_x: float = 5.0
## Profundidade do arco — controla só o quanto avança atrás do gol
@export var arc_radius_z: float = 35.0
@export var arc_segments: int = 6
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
		push_warning("StadiumColliders: nenhum nó sólido encontrado.")

func _find_nodes_containing(root: Node, keyword: String) -> Array:
	var matches: Array = []
	var stack: Array = [root]
	while not stack.is_empty():
		var n: Node = stack.pop_back()
		if n != root and keyword in n.name:
			matches.append(n)
			continue
		for child in n.get_children():
			stack.append(child)
	return matches

func _make_solid(branch: Node) -> void:
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

	# Lados retos — usam arc_radius_z para encaixar direto na borda do arco
	_add_wall(root, "SideNorth",
		Vector3(bounds_offset.x, wall_center_y, -(arc_radius_z + wall_thickness * 0.5) + bounds_offset.z),
		Vector3(straight_half_length * 2.0, wall_height, wall_thickness))

	_add_wall(root, "SideSouth",
		Vector3(bounds_offset.x, wall_center_y, (arc_radius_z + wall_thickness * 0.5) + bounds_offset.z),
		Vector3(straight_half_length * 2.0, wall_height, wall_thickness))

	# Meia-elipse Oeste e Leste
	_add_arc(root, "West", Vector3(-straight_half_length + bounds_offset.x, wall_center_y, bounds_offset.z),
		deg_to_rad(90.0), deg_to_rad(270.0))
	_add_arc(root, "East", Vector3(straight_half_length + bounds_offset.x, wall_center_y, bounds_offset.z),
		deg_to_rad(-90.0), deg_to_rad(90.0))

func _add_arc(parent: Node, arc_name: String, center: Vector3,
		angle_start: float, angle_end: float) -> void:
	var n: int = arc_segments
	var rx: float = arc_radius_x + wall_thickness * 0.5
	var rz: float = arc_radius_z + wall_thickness * 0.5

	for i in range(n):
		var t_a: float = angle_start + (angle_end - angle_start) * float(i) / n
		var t_b: float = angle_start + (angle_end - angle_start) * float(i + 1) / n
		var t_mid: float = (t_a + t_b) * 0.5

		# Posição do segmento sobre a elipse
		var seg_pos := center + Vector3(rx * cos(t_mid), 0.0, rz * sin(t_mid))

		# Vértices da corda para calcular comprimento e ângulo
		var ax: float = rx * cos(t_a)
		var az: float = rz * sin(t_a)
		var bx: float = rx * cos(t_b)
		var bz: float = rz * sin(t_b)
		var chord: float = Vector2(bx - ax, bz - az).length()
		var tangent_y: float = atan2(bz - az, bx - ax)

		var shape := BoxShape3D.new()
		shape.size = Vector3(chord + 0.05, wall_height, wall_thickness)

		var col := CollisionShape3D.new()
		col.name     = "Arc%s_%02d" % [arc_name, i]
		col.position = seg_pos
		col.rotation = Vector3(0.0, -tangent_y, 0.0)
		col.shape    = shape
		parent.add_child(col)
		_colliders_created += 1

func _add_wall(parent: Node, wall_name: String, pos: Vector3, size: Vector3) -> void:
	var shape := BoxShape3D.new()
	shape.size = size
	var col := CollisionShape3D.new()
	col.name     = wall_name
	col.position = pos
	col.shape    = shape
	parent.add_child(col)
	_colliders_created += 1
