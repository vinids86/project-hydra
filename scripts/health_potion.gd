extends Area2D

@export var heal_amount: int = 20
@export var sfx_heal: AudioStream # Som de "Gulp" ou brilho mágico

func _ready():
	body_entered.connect(_on_body_entered)

func _on_body_entered(body):
	if body.name == "Player":
		# Verifica se precisa de cura
		if body.health < body.max_health:
			heal(body)
		else:
			# Opcional: Se estiver cheio, não coleta (deixa pro futuro)
			pass

func heal(player):
	# Aplica a cura respeitando o máximo
	player.health = min(player.health + heal_amount, player.max_health)
	
	# Avisa a HUD (já que alteramos a variável diretamente)
	if player.has_signal("health_changed"):
		player.health_changed.emit(player.health, player.max_health)
	
	# Feedback Visual (Texto flutuante ou brilho)
	print("Curou: ", heal_amount)
	
	# Som (Cria um player temporário na cena para o som não cortar quando a poção sumir)
	if sfx_heal:
		var audio = AudioStreamPlayer.new()
		audio.stream = sfx_heal
		get_tree().current_scene.add_child(audio)
		audio.play()
		audio.finished.connect(audio.queue_free)
	
	queue_free()
