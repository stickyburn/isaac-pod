# Isaac Lab Container

A lightweight, GPU-accelerated development environment for NVIDIA Isaac Lab with Newton physics backend. Includes remote desktop via noVNC, TensorBoard, and experiment tracking.

## Specifications

| Component | Version |
|-----------|---------|
| CUDA | 12.8 |
| Ubuntu | 22.04 |
| Isaac Lab | feature/newton |
| PyTorch | 2.7.0 |
| Python | 3.11 |

## Access Credentials

- **Username:** `root`
- **Password:** `Test123!`

## Exposed Ports

| Port | Service |
|------|---------|
| 6901 | noVNC (Web) |
| 6006 | TensorBoard |
| 22 | SSH |

## Environment Variables

- `WANDB_API_KEY` — Enable Weights & Biases tracking
- `PUBLIC_KEY` — SSH public key for key-based authentication

## Quick Start

```bash
docker run -d \
  --gpus all \
  -p 6901:6901 \
  -p 6006:6006 \
  -p 22:22 \
  -e WANDB_API_KEY=your_key_here \
  stickyburn/isaac-pod:latest
```

Open your browser at `http://localhost:6901/vnc.html` and log in with the credentials above.

## Docker Compose

```bash
docker-compose up -d
```

**Note:** Docker Compose maps port 2222 to container port 22 for SSH. Connect via: `ssh root@<host> -p 2222`

## Training Example

```bash
./isaaclab.sh -p scripts/reinforcement_learning/rsl_rl/train.py \
  --task Isaac-Cartpole-Direct-v0 \
  --num_envs 128 \
  --headless
```
