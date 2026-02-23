#!/bin/bash
set -e

# SSH
mkdir -p /run/sshd
ssh-keygen -A

if [[ -n "$PUBLIC_KEY" ]]; then
    mkdir -p /root/.ssh
    echo "$PUBLIC_KEY" >> /root/.ssh/authorized_keys
    chmod 600 /root/.ssh/authorized_keys
    chmod 700 /root/.ssh
fi

/usr/sbin/sshd

# WORKSPACE
STORAGE_DIR="/workspace/storage"
mkdir -p "${STORAGE_DIR}"
cd "${STORAGE_DIR}"
git clone --depth 1 https://github.com/stickyburn/isaac-pod-projects.git . 2>/dev/null || true

mkdir -p "${STORAGE_DIR}/logs" "${STORAGE_DIR}/data_storage" "${STORAGE_DIR}/logs/wandb"

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

# W&B
if [[ -n "$WANDB_API_KEY" ]]; then
    wandb login "$WANDB_API_KEY" --relogin >/dev/null 2>&1
fi

# STATUS
echo ""
echo "================================================"
echo " Isaac Lab + Newton"
echo "================================================"
echo " SSH:  ssh root@<IP> -p 2222"
echo " VNC:  Run 'start-vnc.sh' then http://<IP>:6901/vnc.html"
if [[ -n "$WANDB_API_KEY" ]]; then
    echo " W&B:  https://wandb.ai"
fi
echo "================================================"

# Keep container running
tail -f /dev/null
