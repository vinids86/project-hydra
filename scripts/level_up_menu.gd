extends CanvasLayer

@onready var cards = $Control/CardContainer.get_children()

func _ready():
	hide()
	process_mode = Node.PROCESS_MODE_ALWAYS
	
	await get_tree().process_frame
	var gm = get_tree().current_scene.find_child("GameManager")
	if gm:
		gm.level_up_options_ready.connect(show_options)

# DETECÇÃO MANUAL DE INPUT PARA CONFIRMAR
func _input(event):
	if not visible: return
	
	# Verifica especificamente o Botão A do Xbox (Índice 0) para selecionar
	if event is InputEventJoypadButton and event.pressed and event.button_index == JOY_BUTTON_A:
		_select_focused_card()
		get_viewport().set_input_as_handled() 

	# Fallback para teclado (Enter)
	if event is InputEventKey and event.pressed and event.keycode == KEY_ENTER:
		_select_focused_card()
		get_viewport().set_input_as_handled()

func _select_focused_card():
	var focused_node = get_viewport().gui_get_focus_owner()
	
	if focused_node in cards:
		focused_node.pressed.emit()

func show_options(options: Array):
	show()
	
	for i in range(cards.size()):
		var btn = cards[i]
		
		if i >= options.size():
			btn.hide()
			continue
			
		btn.show()
		
		# AQUI MUDOU: Agora 'options' é uma lista de Recursos (UpgradeCard)
		# Acessamos as propriedades com ponto (.) em vez de ["chave"]
		var card_data: UpgradeCard = options[i]
		
		btn.text = card_data.title + "\n\n" + card_data.description
		
		# Se tiver ícone, pode setar também:
		# btn.icon = card_data.icon
		
		if btn.pressed.is_connected(_on_card_selected):
			btn.pressed.disconnect(_on_card_selected)
		
		# Passamos o ID do recurso para o GameManager saber o que aplicar
		btn.pressed.connect(_on_card_selected.bind(card_data.id))
		
		# Foca no primeiro botão
		if i == 0:
			btn.grab_focus()

func _on_card_selected(upgrade_id):
	var gm = get_tree().current_scene.find_child("GameManager")
	if gm:
		gm.apply_upgrade(upgrade_id)
	
	hide()
