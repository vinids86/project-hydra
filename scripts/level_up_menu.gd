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
		get_viewport().set_input_as_handled() # Impede que o botão faça outra coisa no jogo

	# Fallback para teclado (Enter)
	if event is InputEventKey and event.pressed and event.keycode == KEY_ENTER:
		_select_focused_card()
		get_viewport().set_input_as_handled()

func _select_focused_card():
	# Descobre qual botão tem o foco agora (navegado pelo direcional)
	var focused_node = get_viewport().gui_get_focus_owner()
	
	# Se o foco estiver em uma das nossas cartas, simula o clique
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
		var upgrade_data = options[i]
		
		btn.text = upgrade_data["title"] + "\n\n" + upgrade_data["description"]
		
		if btn.pressed.is_connected(_on_card_selected):
			btn.pressed.disconnect(_on_card_selected)
		
		btn.pressed.connect(_on_card_selected.bind(upgrade_data["id"]))
		
		# Foca no primeiro botão para permitir navegação imediata pelo direcional
		if i == 0:
			btn.grab_focus()

func _on_card_selected(upgrade_id):
	var gm = get_tree().current_scene.find_child("GameManager")
	if gm:
		gm.apply_upgrade(upgrade_id)
	
	hide()
