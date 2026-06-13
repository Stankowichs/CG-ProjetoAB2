extends Node3D
## Para o AnimationPlayer interno do GLB do goleiro, deixando ele parado em
## pose de rest. Anexa esse script no nó instanciado do .glb (Hulk).
##
## Sem isso, o Godot auto-toca a primeira animação encontrada no GLB ao carregar,
## o que deixa o Hulk fazendo a Idle animada (com root motion estranho do Mixamo).

func _ready() -> void:
	_stop_keeper_animation()
	call_deferred("_stop_keeper_animation")


func _stop_keeper_animation() -> void:
	var ap: AnimationPlayer = find_child("AnimationPlayer", true, false)
	if ap == null:
		push_warning("KeeperStandStill: AnimationPlayer não encontrado em %s" % name)
		return
	# Para qualquer anim em andamento e zera as poses pra rest
	ap.stop()
