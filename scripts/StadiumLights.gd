extends Node3D

## Iluminação de estádio: cria refletores no anel superior, mirando em faixas
## diferentes do gramado, mais luz ambiente/fill para arquibancadas.
##
## Os valores ficam exportados para ajustes finos pelo Inspector sem mexer no script.

@export_group("Floodlights")
@export var floodlight_color: Color = Color(0.98, 0.98, 1.0)
@export var floodlight_energy: float = 3.0
@export var floodlight_range: float = 185.0
@export var floodlight_angle_deg: float = 44.0
@export var floodlight_angle_attenuation: float = 0.58
@export var floodlight_attenuation: float = 0.85
@export var shadowed_floodlights: int = 4

@export_group("Stand Fill")
@export var stand_fill_color: Color = Color(0.72, 0.82, 1.0)
@export var stand_fill_energy: float = 0.85
@export var stand_fill_range: float = 42.0

@export_group("Environment Fill")
@export var ambient_color: Color = Color(0.46, 0.52, 0.6)
@export var ambient_energy: float = 0.32
@export var reflected_light_intensity: float = 0.5
@export var tonemap_exposure: float = 0.85

@export_group("Debug")
@export var marker_visible: bool = false
@export var marker_emission_energy: float = 0.8

var _created_lights: int = 0


func _ready() -> void:
	_configure_environment()
	_create_pitch_floodlights()
	_create_stand_fill_lights()


func _configure_environment() -> void:
	var world := get_viewport().world_3d
	if world == null or world.environment == null:
		return

	var env := world.environment
	_set_if_available(env, "ambient_light_source", 2) # AMBIENT_SOURCE_COLOR
	_set_if_available(env, "ambient_light_color", ambient_color)
	_set_if_available(env, "ambient_light_energy", ambient_energy)
	_set_if_available(env, "reflected_light_source", 2) # REFLECTION_SOURCE_SKY
	_set_if_available(env, "reflected_light_intensity", reflected_light_intensity)
	_set_if_available(env, "tonemap_exposure", tonemap_exposure)


func _set_if_available(object: Object, property_name: String, value: Variant) -> void:
	for property in object.get_property_list():
		if property.name == property_name:
			object.set(property_name, value)
			return


func _create_pitch_floodlights() -> void:
	var side_z_values := [-42.0, -24.0, -8.0, 8.0, 24.0, 42.0]

	for z in side_z_values:
		_make_floodlight(Vector3(-82.0, 46.0, z), Vector3(18.0, 0.0, z * 0.35))
		_make_floodlight(Vector3(82.0, 46.0, z), Vector3(-18.0, 0.0, z * 0.35))

	var end_x_values := [-44.0, -22.0, 0.0, 22.0, 44.0]

	for x in end_x_values:
		_make_floodlight(Vector3(x, 43.0, -66.0), Vector3(x * 0.35, 0.0, 18.0))
		_make_floodlight(Vector3(x, 43.0, 66.0), Vector3(x * 0.35, 0.0, -18.0))


func _create_stand_fill_lights() -> void:
	var fill_positions := [
		Vector3(-76.0, 28.0, -48.0),
		Vector3(-76.0, 28.0, 0.0),
		Vector3(-76.0, 28.0, 48.0),
		Vector3(76.0, 28.0, -48.0),
		Vector3(76.0, 28.0, 0.0),
		Vector3(76.0, 28.0, 48.0),
		Vector3(-40.0, 26.0, -62.0),
		Vector3(0.0, 26.0, -62.0),
		Vector3(40.0, 26.0, -62.0),
		Vector3(-40.0, 26.0, 62.0),
		Vector3(0.0, 26.0, 62.0),
		Vector3(40.0, 26.0, 62.0),
	]

	for pos in fill_positions:
		var fill := OmniLight3D.new()
		fill.name = "StandFill"
		fill.position = pos
		fill.light_color = stand_fill_color
		fill.light_energy = stand_fill_energy
		fill.omni_range = stand_fill_range
		fill.omni_attenuation = 0.72
		fill.shadow_enabled = false
		add_child(fill)


func _make_floodlight(pos: Vector3, target: Vector3) -> void:
	var spot := SpotLight3D.new()
	spot.name = "Floodlight"
	spot.position = pos
	spot.light_color = floodlight_color
	spot.light_energy = floodlight_energy
	spot.light_indirect_energy = 0.65
	spot.spot_range = floodlight_range
	spot.spot_angle = floodlight_angle_deg
	spot.spot_angle_attenuation = floodlight_angle_attenuation
	spot.spot_attenuation = floodlight_attenuation
	spot.shadow_enabled = _created_lights < shadowed_floodlights
	spot.shadow_bias = 0.025
	spot.shadow_blur = 1.8
	add_child(spot)
	spot.look_at(target, Vector3.UP)

	if marker_visible:
		_add_lamp_marker(spot)

	_created_lights += 1


func _add_lamp_marker(parent_light: Light3D) -> void:
	var bulb := MeshInstance3D.new()
	bulb.name = "LampMarker"

	var mesh := BoxMesh.new()
	mesh.size = Vector3(4.2, 1.0, 1.2)
	bulb.mesh = mesh

	var mat := StandardMaterial3D.new()
	mat.albedo_color = floodlight_color
	mat.emission_enabled = true
	mat.emission = floodlight_color
	mat.emission_energy_multiplier = marker_emission_energy
	bulb.material_override = mat

	parent_light.add_child(bulb)
