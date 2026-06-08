# Importar módulo de socket

from socket import *
import sys  # Para encerrar o programa


# Importar threading para usar no TCP, a ideia é manter um servidor sempre aceitando novas conexões,
# e usar uma thread nova para cada conexão já formada, sem ficar com o código preso no loop do aaccept()
import threading

# Cria uma lista pra salvar as conexões TCP, e enviar para todas sempre que precisar
clientes = []


def mensagem_tcp(mensagem):
    cli: socket
    for cli in list(clientes):
        try:
            cli.sendall(mensagem)
        except Exception:
            # Um erro pra enviar msg significa que não está mais conectado
            if cli in clientes:
                clientes.remove(cli)

def thread_tcp(connectionSocket, addr):
    print(f"[TCP] Novo cliente conectado: {addr}")
    clientes.append(connectionSocket)

    try:
        while True:
            data = connectionSocket.recv(1024)
            if not data:
                break
            print(f"[TCP] Mensagem reecbida de {addr}: {data.decode().strip()}")
            connectionSocket.sendall("TCP recebido.".encode("utf-8"))
            # print("[DEBUG] clientes conectados: ", clientes)
    finally:
        if connectionSocket in clientes:
            clientes.remove(connectionSocket)
        connectionSocket.close()
        print(f"[TCP] Cliente desconectou: {addr}")

def server_tcp(PORT):
    socket_tcp = socket(AF_INET, SOCK_STREAM)

    # Pra reutilizar o mesmo port logo depois de fechar o TCP, precisa
    # de setar o SO_REUSEADDR, senão dá erro de "port already in use"
    socket_tcp.setsockopt(SOL_SOCKET, SO_REUSEADDR, 1)

    socket_tcp.bind(('', PORT))
    socket_tcp.listen()
    print(f"Socket TCP de accept() ligado na porta {PORT}.")

    # Estabelecer a conexão
    print('Ready to serve...')
    try:
        while True:
            connectionSocket, addr = socket_tcp.accept()

            # Cria uma thread pra cada cliente que conectar pelo TCP
            thread_cli = threading.Thread(target=thread_tcp, args=(connectionSocket, addr))
            thread_cli.daemon = True
            thread_cli.start()
    finally:
        print("Desligando o TCP de accept()")
        socket_tcp.close()

def server_udp(PORT: int):
    # Criação de socket UDP (Flag SOCK_DGRAM)
    socket_udp = socket(AF_INET, SOCK_DGRAM)

    # Preparar um socket de servidor UDP
    socket_udp.bind(('', PORT))

    print(f"Socket UDP conectado na porta {PORT}.")

    while True:
        try:
            # Read incoming data (buffer size is 1024 bytes)
            # recvfrom() returns the payload data and the sender's (IP, port) tuple
            data, client_address = socket_udp.recvfrom(1024)
            
            # Decode bytes to a string
            message = data.decode('utf-8')
            print(f"[UDP] Mensagem recebida de {client_address}: {message}")
            
            # 4. Optional: Send an echo response back to the client
            response = f"Echo: {message}"
            socket_udp.sendto(response.encode('utf-8'), client_address)
            
        except KeyboardInterrupt:
            print("Desligando o UDP")
            socket_udp.close()
            break
    

def main():
    # Input pra escolher a porta dos dois servidores
    PORT = int(input("Informe a porta desejada: "))

    # Cria uma thread pro server TCP ficar recebendo o accept
    thread_tcp = threading.Thread(target=server_tcp, args=[PORT])

    # A flag deamon faz desligar a thread quando a main desligar
    thread_tcp.daemon = True 
    thread_tcp.start()

    # Roda o UDP na thread principal (poderia ser em outra thread também)
    try:
        server_udp(PORT)
    except KeyboardInterrupt:
        print("Desligando o programa todo (main)")


    sys.exit()  # Termina o programa após enviar os dados correspondentes

main()