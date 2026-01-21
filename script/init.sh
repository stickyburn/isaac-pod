#!/bin/bash
set -e

echo "================================================"
echo " Isaac Lab Container Initialization"
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

mkdir -p "${STORAGE_DIR}/logs"
mkdir -p "${STORAGE_DIR}/data_storage"
mkdir -p "${STORAGE_DIR}/projects"

if [ ! -L /opt/IsaacLab/logs ]; then
    rm -rf /opt/IsaacLab/logs 2>/dev/null || true
    ln -sf "${STORAGE_DIR}/logs" /opt/IsaacLab/logs
fi

if [ ! -L /opt/IsaacLab/data_storage ]; then
    rm -rf /opt/IsaacLab/data_storage 2>/dev/null || true
    ln -sf "${STORAGE_DIR}/data_storage" /opt/IsaacLab/data_storage
fi

# ----------------------------------------------------------------
# 3. KASMVNC
# ----------------------------------------------------------------
echo "[init] Starting KasmVNC..."

rm -rf /tmp/.X*-lock /tmp/.X11-unix/X* 2>/dev/null || true
mkdir -p /tmp/.X11-unix
chmod 1777 /tmp/.X11-unix

mkdir -p /home/stickyburn/.vnc
chown stickyburn:stickyburn /home/stickyburn/.vnc

su - stickyburn -c "/usr/bin/kasmvncserver :1 -auth /home/stickyburn/.Xauthority" &

sleep 3

# ----------------------------------------------------------------
# 4. TENSORBOARD
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
# 5. STATUS
# ----------------------------------------------------------------
echo ""
echo "================================================"
echo " Container Ready"
echo "================================================"
echo " ACCESS:"
echo "   SSH:         ssh root@<IP> -p <PORT>"
echo "   Desktop:     http://<IP>:6901 (pw: Test123!)"
echo "   TensorBoard: http://<IP>:6006"
echo ""
echo " TRAINING:"
echo "   ./isaaclab.sh -p scripts/reinforcement_learning/rsl_rl/train.py --task <TASK> --headless"
echo "   ./isaaclab.sh -p scripts/reinforcement_learning/rsl_rl/train.py --task <TASK> --headless --livestream 2"
echo "   Firefox -> http://localhost:49100/streaming/webrtc-client"
echo "================================================"

tail -f /root/.vnc/*.log /var/log/isaaclab/tensorboard.log 2>/dev/null || tail -f /dev/null
