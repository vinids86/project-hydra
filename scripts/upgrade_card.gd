extends Resource
class_name UpgradeCard

# Dados visuais da carta (Editáveis no Inspector)
@export var id: String
@export var title: String
@export_multiline var description: String
@export var icon: Texture2D 
@export_enum("comum", "raro", "lendario") var rarity: String = "comum"

# Função Virtual: Os scripts filhos OBRIGATORIAMENTE devem sobrescrever isso.
# O GameManager chama isso cegamente.
func apply_upgrade(player: Node2D):
	push_error("ERRO: Você esqueceu de sobrescrever apply_upgrade() no script da carta: " + title)
