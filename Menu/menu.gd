extends Control

@onready var input_playerName : LineEdit = $CenterContainer/VBoxContainer/input_playerName
@onready var input_playerColor : ColorPickerButton = $CenterContainer/VBoxContainer/input_playerColor

@onready var input_localPort : LineEdit = $CenterContainer/VBoxContainer/input_portaLocal

@onready var input_serverIp : LineEdit = $CenterContainer/VBoxContainer/input_ipServer
@onready var input_serverPort : LineEdit = $CenterContainer/VBoxContainer/input_portaServer

@onready var button_connect : Button = $CenterContainer/VBoxContainer/bt_connect
@onready var label_conexao : Label = $CenterContainer/VBoxContainer/label_conexao

@onready var button_ready : Button = $CenterContainer/VBoxContainer/bt_ready
var is_ready: bool = false

func _ready() -> void:
	CLIENT.menu_node = self

func _on_bt_connect_pressed() -> void:
	if not input_playerName.text.is_valid_ascii_identifier():
		print("Nome de jogador inválido")
		return
	
	if not input_localPort.text.is_valid_int():
		print("Porta local inválida")
		return
	
	if not input_serverIp.text.is_empty() and not input_serverIp.text.is_valid_ip_address():
		print("IP do server inválido")
		return
	
	if not input_serverPort.text.is_valid_int():
		print("Porta do server inválida")
		return
	
	var player_name = input_playerName.text
	var player_color = input_playerColor.color
	var local_port = int(input_localPort.text)
	var server_ip = input_serverIp.text if not input_serverIp.text.is_empty() else '127.0.0.1'
	var server_port = int(input_serverPort.text)
	
	CLIENT.create_connection(player_name, player_color, local_port, server_ip, server_port)
	
	await get_tree().create_timer(1.0).timeout
	
	if CLIENT.tcp_peer.get_status() == StreamPeerTCP.STATUS_CONNECTED:
		button_ready.disabled = false
		button_connect.disabled = true
		label_conexao.text = "CONECTADO!"

func _on_bt_ready_pressed() -> void:
	if not is_ready:
		is_ready = true
		CLIENT.tcp_send_msg("READY")
		button_ready.text = "READY"
	else:
		is_ready = false
		CLIENT.tcp_send_msg("UNREADY")
		button_ready.text = "NOT READY"
		
