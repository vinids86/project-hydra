extends Node

# --- REFERÊNCIAS DAS CENAS ---
# Arraste os arquivos .tscn para aqui no Inspector
@export var fast_enemy_scene: PackedScene
@export var tentacle_scene: PackedScene

# --- CONFIGURAÇÕES DE SPAWN ---
@export var spawn_radius_min: float = 400.0 # Distância mínima (Zona Segura)
@export var spawn_radius_max: float = 700.0 # Distância máxima

# --- CONFIGURAÇÕES DE DIFICULDADE (PROGRESSÃO) ---
# Inimigos Rápidos (Swarm)
@export var swarm_interval_start: float = 2.0
@export var swarm_interval_min: float = 0.5
@export var swarm_decrease_rate: float = 0.05 # Quanto o tempo diminui a cada spawn

# Tentáculos (Elites)
@export var tentacle_interval_start: float = 10.0
@export var tentacle_interval_min: float = 5.0
@export var tentacle_decrease_rate: float = 0.1

# --- VARIÁVEIS INTERNAS ---
var player_ref: Node2D
var current_swarm_time: float = 0.0
var current_tentacle_time: float = 0.0

var time_to_next_swarm: float = 0.0
var time_to_next_tentacle: float = 0.0

func _ready():
	player_ref = get_tree().current_scene.find_child("Player")
	
	# Inicializa os timers
	time_to_next_swarm = swarm_interval_start
	time_to_next_tentacle = tentacle_interval_start
	
	# Carrega as cenas automaticamente se você não arrastou no inspector
	# (Fallback de segurança)
	if not fast_enemy_scene:
		fast_enemy_scene = load("res://FastEnemy.tscn")
	if not tentacle_scene:
		tentacle_scene = load("res://Tentacle.tscn")

func _process(delta):
	if not is_instance_valid(player_ref): return
	
	# 1. Lógica do Swarm (Inimigos Rápidos)
	current_swarm_time += delta
	if current_swarm_time >= time_to_next_swarm:
		spawn_enemy(fast_enemy_scene)
		current_swarm_time = 0.0
		# Aumenta a dificuldade: Diminui o tempo para o próximo
		time_to_next_swarm = max(swarm_interval_min, time_to_next_swarm - swarm_decrease_rate)
		# print("Prox Swarm em: ", time_to_next_swarm)

	# 2. Lógica dos Tentáculos (Inimigos Lentos/Fixos)
	current_tentacle_time += delta
	if current_tentacle_time >= time_to_next_tentacle:
		spawn_enemy(tentacle_scene)
		current_tentacle_time = 0.0
		# Aumenta a dificuldade
		time_to_next_tentacle = max(tentacle_interval_min, time_to_next_tentacle - tentacle_decrease_rate)
		print("NOVO TENTÁCULO! Prox em: ", time_to_next_tentacle)

func spawn_enemy(scene_to_spawn):
	if not scene_to_spawn: return
	
	var enemy = scene_to_spawn.instantiate()
	
	# MATEMÁTICA DE POSIÇÃO ALEATÓRIA
	# 1. Escolhe um ângulo aleatório (0 a 360 graus)
	var angle = randf() * TAU
	# 2. Escolhe uma distância aleatória entre Min e Max (Anel)
	var distance = randf_range(spawn_radius_min, spawn_radius_max)
	# 3. Cria o vetor a partir da posição do Player
	var spawn_pos = player_ref.global_position + Vector2(cos(angle), sin(angle)) * distance
	
	enemy.global_position = spawn_pos
	
	# Adiciona na cena principal (GameArena) em vez de dentro do Spawner
	# Isso evita que os inimigos sumam se deletarmos o Spawner
	get_parent().add_child(enemy)
