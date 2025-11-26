extends Node

# REFERÊNCIAS
@export var player: Node2D
@export var xp_gem_scene: PackedScene 

# INIMIGOS ESPECÍFICOS (Para balancear)
@export var worm_scene: PackedScene     # Inimigo Comum (Frequente)
@export var tentacle_scene: PackedScene # Inimigo Elite (Raro)

# CONFIGURAÇÕES DE PROGRESSÃO
@export var base_spawn_rate: float = 2.0 
@export var tentacle_frequency: int = 20 # A cada X worms, nasce 1 tentáculo

# ESTADO DO JOGO
var game_time: float = 0.0
var spawn_timer: float = 0.0
var spawn_counter: int = 0 # Conta quantos inimigos nasceram

# SISTEMA DE XP
var current_xp: int = 0
var current_level: int = 1
var xp_to_next_level: int = 100

@export var max_enemies: int = 100

func _ready():
	if not player:
		player = get_tree().current_scene.find_child("Player")

func _process(delta):
	if not is_instance_valid(player): return
	
	game_time += delta
	
	# --- SISTEMA DE SPAWN ---
	spawn_timer -= delta
	if spawn_timer <= 0:
		spawn_wave()
		
		# Dificuldade Crescente: Spawna mais rápido com o tempo
		var difficulty_factor = 1.0 + (game_time / 60.0) 
		spawn_timer = base_spawn_rate / difficulty_factor

func spawn_wave():
	if get_tree().get_node_count_in_group("Enemies") >= max_enemies:
		return

	# LÓGICA DE BALANCEAMENTO (20:1)
	var scene_to_spawn = worm_scene
	spawn_counter += 1
	
	if spawn_counter >= tentacle_frequency:
		scene_to_spawn = tentacle_scene
		spawn_counter = 0 # Reseta o ciclo
		print("ALERTA: TENTÁCULO SPAWNOU!")
	
	if not scene_to_spawn: return
	
	var enemy = scene_to_spawn.instantiate()
	enemy.add_to_group("Enemies")
	
	# Posição Aleatória (Anel fora da tela)
	var angle = randf() * TAU
	var distance = 700.0 
	var pos = player.global_position + Vector2(cos(angle), sin(angle)) * distance
	
	enemy.global_position = pos
	
	# Scaling Infinito de Dano
	if "damage" in enemy:
		enemy.damage += int(game_time / 60.0) * 2
	
	get_parent().add_child(enemy)

# --- SISTEMA DE XP ---
func spawn_xp(pos: Vector2, amount: int):
	if xp_gem_scene:
		var gem = xp_gem_scene.instantiate()
		gem.global_position = pos
		gem.xp_value = amount
		# Importante: Adicione a cena principal como pai
		get_tree().current_scene.call_deferred("add_child", gem)

func add_xp(amount: int):
	current_xp += amount
	print("XP: ", current_xp, " / ", xp_to_next_level)
	
	if current_xp >= xp_to_next_level:
		level_up()

func level_up():
	current_level += 1
	current_xp -= xp_to_next_level
	xp_to_next_level = int(xp_to_next_level * 1.2) 
	print("LEVEL UP! Nível: ", current_level)
