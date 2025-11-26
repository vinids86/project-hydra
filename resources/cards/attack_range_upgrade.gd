extends UpgradeCard
class_name AttackRangeUpgradeCard

@export var range_bonus: float = 20.0

func _init():
	id = "attack_range"
	title = "Lança Longa"
	description = "Aumenta o alcance dos seus ataques em +%d." % range_bonus
	rarity = "comum"

func apply_upgrade(player: Node2D):
	# Verifica se o player tem a propriedade antes de aplicar
	if "attack_range" in player:
		player.attack_range += range_bonus
		
		# Também aumentamos o offset para o círculo não nascer dentro do player
		# Mantemos a proporção original ou adicionamos o mesmo valor
		if "attack_offset" in player:
			player.attack_offset += range_bonus
			
		print("Upgrade Aplicado: Alcance aumentado para ", player.attack_range)
