extends Resource
class_name UpgradeCard

@export var id: String
@export var title: String
@export_multiline var description: String
@export var icon: Texture2D 
@export_enum("comum", "raro", "lendario") var rarity: String = "comum"

# O valor do poder. Ex:
# Se id="damage_up", value=5.0 (Adiciona 5 de dano)
# Se id="attack_speed", value=0.15 (Reduz cooldown em 15%)
@export var value: float = 0.0
