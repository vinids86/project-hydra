extends UpgradeCard
class_name MoveSpeedUpgradeCard

@export var speed_bonus: float = 50.0

func _init():
	id = "move_speed"
	title = "Passo Fantasma"
	description = "Aumenta sua velocidade de movimento em +%d." % speed_bonus
	rarity = "comum"

func apply_upgrade(player: Node2D):
	if "speed" in player:
		player.speed += speed_bonus
		print("Upgrade Aplicado: Velocidade aumentada para ", player.speed)
