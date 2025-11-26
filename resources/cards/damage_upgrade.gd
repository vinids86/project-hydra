extends UpgradeCard
class_name DamageUpgradeCard

@export var damage_bonus: int = 5

func _init():
	id = "damage_up"
	title = "Lâmina Voraz"
	description = "Aumenta o dano dos seus ataques em +%d." % damage_bonus
	rarity = "comum"

func apply_upgrade(player: Node2D):
	# Verifica se a propriedade existe antes de aplicar para evitar erros
	if "attack_damage" in player:
		player.attack_damage += damage_bonus
		print("Upgrade Aplicado: Dano aumentado para ", player.attack_damage)
