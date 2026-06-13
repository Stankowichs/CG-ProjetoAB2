extends Node3D
## Colisão do campo para a bola.
## 4 paredes ao redor do campo com abertura apenas na área do gol.

@export_group("Medidas do campo")
@export var field_half_length: float = 51.5
@export var field_half_width: float = 36.0
## Metade da largura do gol
@export var goal_half_width: float = 5.8
@export var wall_thickness: float = 1.0
@export var wall_height: float = 2.0
@export var wall_center_y: float = 0.5

func _ready() -> void:
	var body := StaticBody3D.new()
	body.name = "FieldWalls"
	# Layer 1 — para a bola (mask 1) detectar as paredes
	body.collision_layer = 1
	# Mask com layer 3 e 7 da bola (2^2 + 2^6 = 4 + 64 = 68)
	body.collision_mask = 68

	# Laterais — sem abertura
	_add_wall(body, "SideNorth",
		Vector3(0.0, wall_center_y, -(field_half_width + wall_thickness * 0.5)),
		Vector3(field_half_length * 2.0, wall_height, wall_thickness))

	_add_wall(body, "SideSouth",
		Vector3(0.0, wall_center_y, field_half_width + wall_thickness * 0.5),
		Vector3(field_half_length * 2.0, wall_height, wall_thickness))

	# Linhas de fundo — dois segmentos cada lado, com abertura no gol
	var seg_length := field_half_width - goal_half_width
	var seg_center_z := goal_half_width + seg_length * 0.5

	# Fundo Esquerdo
	_add_wall(body, "EndLeftNorth",
		Vector3(-(field_half_length + wall_thickness * 0.5), wall_center_y, -seg_center_z),
		Vector3(wall_thickness, wall_height, seg_length))
	_add_wall(body, "EndLeftSouth",
		Vector3(-(field_half_length + wall_thickness * 0.5), wall_center_y, seg_center_z),
		Vector3(wall_thickness, wall_height, seg_length))

	# Fundo Direito
	_add_wall(body, "EndRightNorth",
		Vector3(field_half_length + wall_thickness * 0.5, wall_center_y, -seg_center_z),
		Vector3(wall_thickness, wall_height, seg_length))
	_add_wall(body, "EndRightSouth",
		Vector3(field_half_length + wall_thickness * 0.5, wall_center_y, seg_center_z),
		Vector3(wall_thickness, wall_height, seg_length))

		add_child(body)

		for child in body.get_children():
		print(child.name, " pos:", child.position, " size:", child.shape.size)

func _add_wall(parent: Node, wall_name: String, pos: Vector3, size: Vector3) -> void:
	var shape := BoxShape3D.new()
	shape.size = size
	var col := CollisionShape3D.new()
	col.name = wall_name
	col.position = pos
	col.shape = shape
	parent.add_child(col)
