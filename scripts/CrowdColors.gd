extends Node3D

## A torcida (crowd.glb) é uma malha única com cores POR VÉRTICE (COLOR_0),
## modelada no Blender em cima da geometria real da arquibancada. Aqui só
## garantimos um material que usa essas cores como albedo — independente de como
## o import do glTF tratou o material original.

@export var roughness: float = 0.95
@export var emission_boost: float = 0.06  # leve brilho pra ler bem na sombra do bowl


func _ready() -> void:
	var mat := StandardMaterial3D.new()
	mat.vertex_color_use_as_albedo = true
	mat.roughness = roughness
	mat.metallic = 0.0
	if emission_boost > 0.0:
		mat.emission_enabled = true
		mat.emission = Color(1.0, 1.0, 1.0)
		mat.emission_energy_multiplier = emission_boost
		# usa a própria cor do vértice no emissivo via albedo*emission não é direto;
		# o leve emissivo branco só levanta o piso de luz sem lavar as cores.
	for node in find_children("*", "MeshInstance3D", true, false):
		var mesh_instance := node as MeshInstance3D
		if mesh_instance != null:
			mesh_instance.material_override = mat
			mesh_instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
