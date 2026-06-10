extends Node3D

## Gira a estrela e flutua de leve, pra dar vida ao power-up.
## Quando você dropar o gold_star.glb, troque o placeholder por uma instância dele.

@export var spin_speed: float = 1.8       # rad/s
@export var bob_amp:    float = 0.15      # metros
@export var bob_freq:   float = 1.4       # Hz

var _t: float = 0.0
var _base_y: float = 0.0


func _ready() -> void:
	_base_y = position.y


func _process(delta: float) -> void:
	_t += delta
	rotate_y(spin_speed * delta)
	position.y = _base_y + sin(_t * TAU * bob_freq) * bob_amp
