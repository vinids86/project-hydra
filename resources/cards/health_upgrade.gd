extends UpgradeCard
class_name HealthUpgradeCard

@export var hp_bonus: int = 20

func _init():
	# Valores padrão para quando você criar o arquivo .tres
	id = "health_up"
	title = "Coração de Titã"
	description = "Aumenta sua Vida Máxima em +%d e cura a mesma quantidade." % hp_bonus

func apply_upgrade(player: Node2D):
	player.max_health += hp_bonus
	player.health += hp_bonus # Cura o valor ganho
	
	# Força atualização da HUD se necessário
	if player.has_signal("health_changed"):
		player.health_changed.emit(player.health, player.max_health)
