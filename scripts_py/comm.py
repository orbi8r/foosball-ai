import socket

HOST = "127.0.0.1"
PORT = 18233


class UDPComm:
    def __init__(self, host=HOST, port=PORT):
        self.sock = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)
        self.sock.bind((host, port))
        print(f"UDP server listening on {host}:{port}")

    def recv(self):
        data, addr = self.sock.recvfrom(4096)
        return data, addr

    def send(self, data, addr):
        self.sock.sendto(data, addr)

    def close(self):
        self.sock.close()
