# Isaac Lab Container

A lightweight, GPU-accelerated development environment for NVIDIA Isaac Lab with Newton physics backend. Includes remote desktop via noVNC, TensorBoard, and experiment tracking.

## Access Credentials

- **Username:** `root`
- **Password:** `Test123!`

## Exposed Ports

| Port | Service |
|------|---------|
| 6901 | noVNC |
| 6006 | TensorBoard |
| 22 | SSH |

## Environment Variables

- `WANDB_API_KEY` — Enable Weights & Biases tracking
- `PUBLIC_KEY` — SSH public key for key-based authentication

## Training Example

```bash
./isaaclab.sh -p scripts/reinforcement_learning/rsl_rl/train.py \
  --task Isaac-Cartpole-Direct-v0 \
  --num_envs 128 \
  --headless
```