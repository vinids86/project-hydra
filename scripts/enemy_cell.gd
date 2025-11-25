extends Area2D # VOLTAMOS PARA AREA2D (Mais estável para animação procedural)

signal on_death

@export var damage: int = 10
@export var health: int = 10 

var is_dead: bool = false

# --- CONFIGURAÇÃO ---
func _ready():
	# 1. Garante que o sinal de colisão esteja conectado
	# Isso corrige o problema caso a conexão tenha sumido no editor ao trocar o tipo
	if not body_entered.is_connected(_on_body_entered):
		body_entered.connect(_on_body_entered)
	
	# REMOVIDO: Não forçamos mais as layers via código.
	# Verifique no Inspector do nó EnemyCell (Area2D):
	# - Collision Layer: Deve corresponder ao que o Player busca no ataque (Geralmente Layer 2)
	# - Collision Mask: Deve incluir a Layer do Player (Geralmente Layer 1) para causar dano de contato
	
	# Garante que a célula é "atacável" ao nascer
	monitorable = true
	monitoring = true

# --- CAUSAR DANO (Ao tocar no player) ---
# Como voltamos a ser Area2D, usamos o sinal nativo 'body_entered' do próprio nó
# (Não esqueça de reconectar o sinal do nó raiz para cá se tiver desconectado!)
func _on_body_entered(body):
	if is_dead: return
	
	if body.name == "Player":
		if body.has_method("take_damage"):
			body.take_damage(damage)

# --- RECEBER DANO ---
func take_damage(amount):
	if is_dead: return
	health -= amount
	
	var original_modulate = modulate
	modulate = Color(10, 10, 10) 
	await get_tree().create_timer(0.05).timeout
	modulate = original_modulate
	
	if health <= 0:
		die()

func die():
	is_dead = true
	on_death.emit()
	
	# Desliga colisão e monitoramento
	set_deferred("monitorable", false)
	set_deferred("monitoring", false)
	
	# Se tivermos um corpo físico filho (a parede), desligamos ele também
	if has_node("WallBody"):
		$WallBody/CollisionShape2D.set_deferred("disabled", true)
	
	modulate = Color(0.3, 0.3, 0.3, 0.5)
	z_index = -1
