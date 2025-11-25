extends CharacterBody2D

@export var speed: float = 180.0 
@export var health: int = 5
@export var damage: int = 5

var player_target: Node2D
var is_dead: bool = false

func _ready():
	player_target = get_tree().current_scene.find_child("Player")
	
	# Configura camadas do Corpo Físico (Parede)
	# Layer 2 (Inimigo) - Bloqueia o Player fisicamente
	collision_layer = 2
	collision_mask = 1
	
	# --- CRIAÇÃO DA HURTBOX (AREA2D) ---
	# Cria uma área para receber os ataques do player (que buscam Area2D)
	var hurtbox = Area2D.new()
	hurtbox.name = "AutoHurtbox"
	hurtbox.collision_layer = 2 # Layer de Inimigo (para o ataque achar)
	hurtbox.collision_mask = 0
	
	# CRIAÇÃO DO SCRIPT DINÂMICO
	# Criamos um script novo que estende Area2D corretamente para evitar o erro de tipo.
	# Esse script serve apenas para receber 'take_damage' e avisar o pai (este nó).
	var script = GDScript.new()
	script.source_code = "extends Area2D\nfunc take_damage(amount): get_parent().take_damage(amount)"
	script.reload()
	hurtbox.set_script(script)
	
	add_child(hurtbox)
	
	# Copia o shape de colisão do corpo para a hurtbox
	for child in get_children():
		if child is CollisionShape2D:
			var new_shape = child.duplicate()
			hurtbox.add_child(new_shape)

func _physics_process(delta):
	if is_dead or not is_instance_valid(player_target): return
	
	var direction = (player_target.global_position - global_position).normalized()
	velocity = direction * speed
	
	move_and_slide()
	
	# Dano por contato físico (Empurrão)
	for i in range(get_slide_collision_count()):
		var collision = get_slide_collision(i)
		var collider = collision.get_collider()
		
		if collider.name == "Player":
			if collider.has_method("take_damage"):
				collider.take_damage(damage)

# Esta função agora só é chamada pelo Inimigo Real (via repasse da Hurtbox)
func take_damage(amount):
	if is_dead: return
	
	health -= amount
	
	# Flash de Hit
	var original_modulate = modulate
	modulate = Color(10, 10, 10)
	await get_tree().create_timer(0.05).timeout
	modulate = original_modulate
	
	if health <= 0:
		die()

func die():
	is_dead = true
	
	collision_layer = 0
	collision_mask = 0
	
	# Desliga a Hurtbox filha se existir
	if has_node("AutoHurtbox"):
		$AutoHurtbox.monitorable = false
	
	var tween = create_tween()
	tween.tween_property(self, "modulate:a", 0.0, 0.2)
	tween.tween_callback(queue_free)
