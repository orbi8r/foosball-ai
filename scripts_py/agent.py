import os
import torch
import torch.nn as nn
import torch.optim as optim
import random
import time
import threading
import pickle
import queue
from collections import deque


# Set device to CUDA if available
DEVICE = torch.device('cuda' if torch.cuda.is_available() else 'cpu')
print(f"[INFO] Using device: {DEVICE} ({torch.cuda.get_device_name(0) if torch.cuda.is_available() else 'CPU'})")


class SimpleNet(nn.Module):
    def __init__(self, input_dim=8, output_dim=8):
        super(SimpleNet, self).__init__()
        self.fc1 = nn.Linear(input_dim, 64)
        self.relu = nn.ReLU()
        self.fc2 = nn.Linear(64, output_dim)

    def forward(self, x):
        x = self.relu(self.fc1(x))
        return torch.tanh(self.fc2(x))  # output in [-1, 1]


# determine model save directory
BASE_DIR = os.path.dirname(os.path.abspath(__file__))


class Agent:
    def __init__(
        self, model_path="model.pth", lr=1e-3, buffer_path="replay_buffer.pkl"
    ):
        # if relative path, place in scripts_py directory
        if not os.path.isabs(model_path):
            model_path = os.path.join(BASE_DIR, model_path)
        self.model_path = model_path
        self.net = SimpleNet(input_dim=8, output_dim=8).to(DEVICE)
        self.optimizer = optim.Adam(self.net.parameters(), lr=lr)
        self.criterion = nn.MSELoss()
        # load existing model if available
        if os.path.exists(self.model_path):
            self.net.load_state_dict(torch.load(self.model_path, map_location=DEVICE))
            print(f"Loaded model from {self.model_path}")
        self.memory = deque(maxlen=10000)
        self.batch_size = 32
        self.gamma = 0.99
        self.epsilon = 1.0  # start with full exploration
        self.epsilon_min = 0.05
        self.epsilon_decay = 0.9999  # much slower decay per training batch
        self.buffer_path = os.path.join(BASE_DIR, buffer_path)
        self._load_buffer()
        self._exp_queue = queue.Queue(maxsize=10000)  # thread-safe experience queue
        self._model_lock = threading.Lock()
        self._train_thread = threading.Thread(
            target=self._background_train_loop, daemon=True
        )
        self._train_thread.start()
        self._pending_update = False
        self._latest_state_dict = None
        self._autosave_thread = threading.Thread(target=self.autosave_loop, daemon=True)
        self._autosave_thread.start()

    def select_action(self, state):
        if random.random() < self.epsilon:
            # Random action: for each row, random t_state and r_state
            actions = []
            for _ in range(4):
                t_state = random.choice([-1, 0, 1])
                r_state = random.choice([-1, 0, 1])
                actions.append(t_state)
                actions.append(r_state)
            return actions
        # Greedy action
        with self._model_lock:
            self.net.eval()
            with torch.no_grad():
                x = torch.tensor(state, dtype=torch.float32, device=DEVICE).unsqueeze(0)
                out = self.net(x).squeeze(0).cpu().numpy()
        actions = []
        for i in range(4):
            t_val = out[i * 2]
            r_val = out[i * 2 + 1]
            t_state = -1 if t_val < -0.33 else (1 if t_val > 0.33 else 0)
            r_state = -1 if r_val < -0.33 else (1 if r_val > 0.33 else 0)
            actions.append(t_state)
            actions.append(r_state)
        return actions

    def store(self, state, action, reward, next_state):
        try:
            self._exp_queue.put_nowait((state, action, reward, next_state))
        except queue.Full:
            pass  # drop experience if queue is full (should be rare)

    def _save_buffer(self):
        try:
            with open(self.buffer_path, "wb") as f:
                pickle.dump(list(self.memory), f)
        except Exception as e:
            print(f"[WARN] Could not save replay buffer: {e}")

    def _load_buffer(self):
        if os.path.exists(self.buffer_path):
            try:
                with open(self.buffer_path, "rb") as f:
                    data = pickle.load(f)
                    self.memory = deque(data, maxlen=10000)
                print(f"Loaded replay buffer from {self.buffer_path}")
            except Exception as e:
                print(f"[WARN] Could not load replay buffer: {e}")

    def _background_train_loop(self):
        last_report = time.time()
        report_interval = 10  # seconds
        train_steps = 0
        last_loss = None
        while True:
            # Move from queue to memory
            while not self._exp_queue.empty():
                exp = self._exp_queue.get()
                self.memory.append(exp)
            if len(self.memory) < self.batch_size:
                time.sleep(1)
                continue
            # Sample and train in background
            batch = random.sample(self.memory, self.batch_size)
            states, actions, rewards, next_states = zip(*batch)
            states = torch.tensor(states, dtype=torch.float32, device=DEVICE)
            actions = torch.tensor(actions, dtype=torch.float32, device=DEVICE)
            rewards = torch.tensor(rewards, dtype=torch.float32, device=DEVICE)
            next_states = torch.tensor(next_states, dtype=torch.float32, device=DEVICE)
            # Only lock for model update, keep as short as possible
            with self._model_lock:
                q_values = self.net(states)
                next_q = self.net(next_states).max(dim=1)[0]
                target = actions * rewards.unsqueeze(1) + self.gamma * next_q.unsqueeze(1)
                loss = self.criterion(q_values, target)
                self.optimizer.zero_grad()
                loss.backward()
                self.optimizer.step()
                self._latest_state_dict = self.net.state_dict()
                self._pending_update = True
            # Decay epsilon after each batch
            if self.epsilon > self.epsilon_min:
                self.epsilon *= self.epsilon_decay
                if self.epsilon < self.epsilon_min:
                    self.epsilon = self.epsilon_min
            train_steps += 1
            last_loss = loss.item()
            now = time.time()
            if now - last_report > report_interval:
                print(
                    f"[MODEL UPDATE] Steps: {train_steps} | Loss: {last_loss:.6f} | Epsilon: {self.epsilon:.6f}"
                )
                last_report = now
            time.sleep(0.1)  # train every 0.1s

    def maybe_update_model(self):
        # Call this in main loop to hot-swap latest weights
        if self._pending_update and self._latest_state_dict is not None:
            with self._model_lock:
                self.net.load_state_dict(self._latest_state_dict)
                self._pending_update = False

    def save(self):
        with self._model_lock:
            torch.save(self.net.state_dict(), self.model_path)

    def load(self):
        if os.path.exists(self.model_path):
            with self._model_lock:
                self.net.load_state_dict(torch.load(self.model_path, map_location=DEVICE))
                print(f"[MODEL] Loaded model from {self.model_path}")

    def autosave_loop(self, interval=60):
        while True:
            self.save()
            time.sleep(interval)
