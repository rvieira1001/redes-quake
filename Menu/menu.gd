extends Control

@onready var input_playerName : LineEdit = $CenterContainer/VBoxContainer/input_playerName

@onready var input_localPort : LineEdit = $CenterContainer/VBoxContainer/input_portaLocal

@onready var input_serverIp : LineEdit = $CenterContainer/VBoxContainer/input_ipServer
@onready var input_serverPort : LineEdit = $CenterContainer/VBoxContainer/input_portaServer

@onready var input_msg : LineEdit = $CenterContainer/VBoxContainer/input_msg

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
	var local_port = int(input_localPort.text)
	var server_ip = input_serverIp.text if not input_serverIp.text.is_empty() else '127.0.0.1'
	var server_port = int(input_serverPort.text)
	
	CLIENT.create_connection(player_name, local_port, server_ip, server_port)

func _on_bt_send_msg_pressed() -> void:
	CLIENT.udp_send_msg(input_msg.text)
	CLIENT.tcp_send_msg(input_msg.text)
