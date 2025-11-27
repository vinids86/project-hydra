extends UpgradeCard
class_name ChainAttackUpgradeCard

const MAX_CHAINS = 4
# Quanto tempo extra de espera adicionamos por nível de eco?
# Ex: Se o eco demora 0.15s, adicionamos 0.15s de cooldown
const COOLDOWN_PENALTY_PER_LEVEL = 0.15 

func _init():
	id = "chain_attack"
	title = "Ecos da Lança"
	description = "Seu ataque reverbera para frente, mas demora mais para recuperar."
	rarity = "raro"

func apply_upgrade(player: Node2D):
	if "attack_chain_level" in player:
		if player.attack_chain_level < MAX_CHAINS:
			player.attack_chain_level += 1
			
			# Aumenta o Cooldown no Player para balancear
			if "attack_cooldown" in player:
				player.attack_cooldown += COOLDOWN_PENALTY_PER_LEVEL
			
			print("Upgrade: Cadeia Nível ", player.attack_chain_level, " | Cooldown: ", player.attack_cooldown)
			
			if player.attack_chain_level >= MAX_CHAINS:
				description = "Cadeia de ataques no MÁXIMO."
			else:
				description = "Adiciona +1 eco (+%0.2fs recarga) (Atual: %d)" % [COOLDOWN_PENALTY_PER_LEVEL, player.attack_chain_level]
