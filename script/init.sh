#!/bin/bash
set -e

echo "================================================"
echo " Isaac Lab + Newton Initialization"
echo "================================================"

# ----------------------------------------------------------------
# 1. SSH
# ----------------------------------------------------------------
echo "[init] Setting up SSH..."
mkdir -p /run/sshd
ssh-keygen -A

if [[ -n "$PUBLIC_KEY" ]]; then
    echo "[init] Adding public key..."
    mkdir -p /root/.ssh
    echo "$PUBLIC_KEY" >> /root/.ssh/authorized_keys
    chmod 600 /root/.ssh/authorized_keys
    chmod 700 /root/.ssh
fi

/usr/sbin/sshd

# ----------------------------------------------------------------
# 2. WORKSPACE
# ----------------------------------------------------------------
echo "[init] Setting up workspace..."
STORAGE_DIR="/workspace/storage"

mkdir -p "${STORAGE_DIR}"
cd "${STORAGE_DIR}"
echo "[init] Cloning isaac-pod-projects repo..."
git clone --depth 1 https://github.com/stickyburn/isaac-pod-projects.git . || echo "[init] Repo already exists or clone failed, continuing..."

echo "[init] Creating storage folders..."
mkdir -p "${STORAGE_DIR}/logs"
mkdir -p "${STORAGE_DIR}/data_storage"
mkdir -p "${STORAGE_DIR}/logs/wandb"

if [ ! -L /opt/IsaacLab/logs ]; then
    rm -rf /opt/IsaacLab/logs 2>/dev/null || true
    ln -sf "${STORAGE_DIR}/logs" /opt/IsaacLab/logs
fi

if [ ! -L /opt/IsaacLab/data_storage ]; then
    rm -rf /opt/IsaacLab/data_storage 2>/dev/null || true
    ln -sf "${STORAGE_DIR}/data_storage" /opt/IsaacLab/data_storage
fi

if [ ! -L /opt/IsaacLab/wandb ]; then
    rm -rf /opt/IsaacLab/wandb 2>/dev/null || true
    ln -sf "${STORAGE_DIR}/logs/wandb" /opt/IsaacLab/wandb
fi

# ----------------------------------------------------------------
# 3. VNC (x11vnc + noVNC + Fluxbox)
# ----------------------------------------------------------------
echo "[init] Starting VNC server..."

# Clean up any stale locks
rm -rf /tmp/.X*-lock /tmp/.X11-unix/X* 2>/dev/null || true
mkdir -p /tmp/.X11-unix
chmod 1777 /tmp/.X11-unix

# Start Xvfb (virtual framebuffer)
export DISPLAY=:1
Xvfb :1 -screen 0 1920x1080x24 &
sleep 2

# Start Fluxbox window manager
fluxbox &
sleep 1

# Start x11vnc server (internal only, no external port)
echo "[init] Starting x11vnc..."
x11vnc -display :1 -rfbauth /root/.vnc/passwd -forever -shared -rfbport 5900 -localhost &
sleep 2

# Start noVNC web interface
echo "[init] Starting noVNC..."
/usr/share/novnc/utils/novnc_proxy --vnc localhost:5900 --listen 6901 &
sleep 2

if pgrep -f "Xvfb" > /dev/null; then
    echo "[init] VNC stack running:"
    echo "       - noVNC web: http://localhost:6901/vnc.html"
else
    echo "[init] WARNING: VNC failed to start"
fi

# ----------------------------------------------------------------
# 4. WEIGHTS & BIASES
# ----------------------------------------------------------------
echo "[init] Configuring Weights & Biases..."
if [[ -n "$WANDB_API_KEY" ]]; then
    echo "[init] WANDB_API_KEY detected, logging in..."
    /opt/isaaclab-env/bin/wandb login "$WANDB_API_KEY" --relogin
    echo "[init] W&B authenticated successfully"
    echo "[init] W&B data directory: ${WANDB_DIR}"
    echo "[init] View runs at: https://wandb.ai"
else
    echo "[init] No WANDB_API_KEY found. Set it to enable W&B tracking."
    echo "[init] Example: docker run -e WANDB_API_KEY=your_key ..."
fi

# ----------------------------------------------------------------
# 5. TENSORBOARD
# ----------------------------------------------------------------
echo "[init] Starting TensorBoard..."
mkdir -p /var/log/isaaclab
/opt/isaaclab-env/bin/tensorboard \
    --logdir="${STORAGE_DIR}/logs" \
    --host=0.0.0.0 \
    --port=6006 \
    --reload_interval=30 \
    > /var/log/isaaclab/tensorboard.log 2>&1 &

sleep 2
if pgrep -f "tensorboard" > /dev/null; then
    echo "[init] TensorBoard running on port 6006"
else
    echo "[init] WARNING: TensorBoard failed to start"
fi

# ----------------------------------------------------------------
# 6. STATUS
# ----------------------------------------------------------------
echo ""
echo "================================================"
echo " Container Ready (Newton Backend)"
echo "================================================"
echo " ACCESS:"
echo "   SSH:         ssh root@<IP> -p <PORT>"
echo "   Desktop:     http://<IP>:6901/vnc.html"
echo "   TensorBoard: http://<IP>:6006"
if [[ -n "$WANDB_API_KEY" ]]; then
    echo "   W&B:         https://wandb.ai (authenticated)"
fi
echo ""
echo " TRAINING:"
echo "   ./isaaclab.sh -p scripts/reinforcement_learning/rsl_rl/train.py --task <TASK> --headless"
echo ""
echo " NEWTON BACKEND:"
echo "   No Isaac Sim required!"
echo "================================================"

# Keep container running
tail -f /dev/null