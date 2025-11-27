extends UpgradeCard
class_name RandomAttackUpgradeCard

const MAX_EXTRA_ATTACKS = 8
const RANGE_PENALTY_PERCENT = 0.25 

func _init():
	id = "random_attack"
	title = "Caos Controlado"
	# CORREÇÃO AQUI: Usamos %% para escrever "10%"
	description = "Dispara +1 ataque aleatório (-10%% área) (Atual: 0)."
	rarity = "raro"

func apply_upgrade(player: Node2D):
	if "extra_attack_count" in player:
		if player.extra_attack_count < MAX_EXTRA_ATTACKS:
			player.extra_attack_count += 1
			
			if "attack_range" in player:
				player.attack_range *= (1.0 - RANGE_PENALTY_PERCENT)
			
			if "attack_offset" in player:
				player.attack_offset *= (1.0 - RANGE_PENALTY_PERCENT)
			
			print("Upgrade: Ataques Extras: ", player.extra_attack_count, " | Novo Range: ", player.attack_range)
			
			if player.extra_attack_count >= MAX_EXTRA_ATTACKS:
				description = "Caos máximo atingido (8 direções)."
			else:
				# CORREÇÃO AQUI TAMBÉM: %% para o texto, %d para o número
				description = "Adiciona +1 ataque aleatório (-10%% área) (Atual: %d)" % player.extra_attack_count
