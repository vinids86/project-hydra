extends UpgradeCard
class_name AttackSpeedUpgradeCard

@export var speed_percent: float = 0.15 # 15% mais rápido

func _init():
	id = "attack_speed"
	title = "Fúria Célere"
	description = "Reduz o tempo entre ataques em %d%%." % (speed_percent * 100)
	rarity = "comum"

func apply_upgrade(player: Node2D):
	if "attack_cooldown" in player:
		# Reduz o cooldown. Ex: 0.5 * (1.0 - 0.15) = 0.425
		# clamp garante que nunca fique abaixo de 0.05s (20 ataques/segundo)
		player.attack_cooldown = max(0.05, player.attack_cooldown * (1.0 - speed_percent))
		print("Upgrade Aplicado: Cooldown reduzido para ", player.attack_cooldown)
