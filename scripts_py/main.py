import socket
import json
import random

HOST = "127.0.0.1"
PORT = 18233

with socket.socket(socket.AF_INET, socket.SOCK_DGRAM) as sock:
    sock.bind((HOST, PORT))
    print(f"UDP server listening on {HOST}:{PORT}")
    while True:
        data, addr = sock.recvfrom(4096)
        try:
            req = json.loads(data.decode("utf-8"))
        except json.JSONDecodeError:
            continue
        player_id = req.get("player_id")
        # Generate random boolean outputs per player
        output = [bool(random.getrandbits(1)) for _ in range(16)]
        resp = {"player_id": player_id, "output": output}
        sock.sendto(json.dumps(resp).encode("utf-8"), addr)
