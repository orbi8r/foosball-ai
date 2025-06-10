from comm import UDPComm
from agent import Agent
import json
import time

HOST = "127.0.0.1"
PORT = 18233

comm = UDPComm(HOST, PORT)
agent = Agent()

# Store last state/action for each player
last_state = {}
last_action = {}

try:
    last_loop_report = time.time()
    loop_times = []
    while True:
        loop_start = time.time()
        data, addr = comm.recv()
        try:
            req = json.loads(data.decode("utf-8"))
        except json.JSONDecodeError:
            continue
        player_id = req.get("player_id")
        state = req.get("state", [])[1:]  # skip player_id in state
        reward = req.get("reward", 0.0)
        # Select action from agent
        action = agent.select_action(state)
        # If we have a last state/action, store experience
        if player_id in last_state:
            agent.store(last_state[player_id], last_action[player_id], reward, state)
        last_state[player_id] = state
        last_action[player_id] = action
        # Hot-swap model if background training updated it
        agent.maybe_update_model()
        resp = {"player_id": player_id, "output": action, "reward": reward}
        comm.send(json.dumps(resp).encode("utf-8"), addr)
        loop_end = time.time()
        loop_times.append(loop_end - loop_start)
        if time.time() - last_loop_report > 10:
            if loop_times:
                avg_loop = sum(loop_times) / len(loop_times)
                print(
                    f"[LOOP PERF] Avg UDP loop time (last 10s): {avg_loop:.6f} sec, loops: {len(loop_times)}"
                )
            loop_times = []
            last_loop_report = time.time()
except KeyboardInterrupt:
    comm.close()
    print("Server stopped.")
