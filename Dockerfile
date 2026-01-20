# ============================================================
# Stage 1: Builder - Isaac Sim 5.1.0 + Isaac Lab
# ============================================================
FROM nvidia/cuda:12.4.1-devel-ubuntu22.04 AS builder
ENV DEBIAN_FRONTEND=noninteractive

# Build dependencies & Python 3.11
RUN apt-get update && apt-get install -y --no-install-recommends \
    wget curl ca-certificates gnupg2 git cmake build-essential \
    ninja-build libgl1-mesa-dev libglu1-mesa-dev \
    software-properties-common \
    && add-apt-repository -y ppa:deadsnakes/ppa \
    && apt-get update \
    && apt-get install -y --no-install-recommends \
    python3.11 python3.11-dev python3.11-venv python3-pip \
    && rm -rf /var/lib/apt/lists/*

# Python virtual environment
WORKDIR /opt
RUN python3.11 -m venv /opt/isaaclab-env \
    && /opt/isaaclab-env/bin/pip install --upgrade pip
ENV PATH="/opt/isaaclab-env/bin:${PATH}"

# Isaac Sim
ENV ACCEPT_EULA=Y PRIVACY_CONSENT=Y CUDA_HOME=/usr/local/cuda
RUN pip install "isaacsim[all,extscache]==5.1.0" --extra-index-url=https://pypi.nvidia.com --no-cache-dir

# Isaac Lab
WORKDIR /opt
RUN git clone --depth 1 --branch main https://github.com/isaac-sim/IsaacLab.git IsaacLab
ENV TERM=xterm
RUN cd /opt/IsaacLab && echo "y" | ./isaaclab.sh --install

# ============================================================
# Stage 2: Runtime
# ============================================================
FROM nvidia/cuda:12.4.1-runtime-ubuntu22.04 AS runtime

# Environment
ENV DEBIAN_FRONTEND=noninteractive
ENV CUDA_HOME=/usr/local/cuda
ENV PATH="${CUDA_HOME}/bin:/opt/isaaclab-env/bin:${PATH}"
ENV LD_LIBRARY_PATH="${CUDA_HOME}/lib64:${LD_LIBRARY_PATH}"
ENV NVIDIA_VISIBLE_DEVICES=all
ENV NVIDIA_DRIVER_CAPABILITIES=all
ENV ACCEPT_EULA=Y PRIVACY_CONSENT=Y HEADLESS=1 ENABLE_CAMERAS=1

# System packages
RUN apt-get update && apt-get install -y --no-install-recommends \
    wget curl ca-certificates gnupg2 git sudo openssh-server zsh \
    xfce4 xfce4-terminal dbus-x11 xauth \
    libgl1-mesa-glx libglu1-mesa libegl1-mesa libxcb1 libvulkan1 \
    software-properties-common \
    libunwind8 libxfont2 libxtst6 ssl-cert \
    libswitch-perl libyaml-tiny-perl libhash-merge-simple-perl \
    liblist-moreutils-perl libtry-tiny-perl libdatetime-perl libdatetime-timezone-perl libgomp1 zenity \
    && add-apt-repository -y ppa:mozillateam/ppa \
    && add-apt-repository -y ppa:deadsnakes/ppa \
    && apt-get update \
    && apt-get install -y --no-install-recommends python3.11 python3.11-venv firefox-esr \
    && rm -rf /var/lib/apt/lists/*

# Zsh plugins (system-wide)
RUN mkdir -p /etc/zsh/plugins && \
    git clone --depth 1 https://github.com/zsh-users/zsh-autosuggestions /etc/zsh/plugins/zsh-autosuggestions && \
    git clone --depth 1 https://github.com/agkozak/zsh-z /etc/zsh/plugins/zsh-z && \
    git clone --depth 1 https://github.com/zsh-users/zsh-history-substring-search /etc/zsh/plugins/zsh-history-substring-search

# KasmVNC
ARG KASMVNC_VERSION=1.4.0
RUN wget -q -O /tmp/kasmvncserver.deb \
    "https://github.com/kasmtech/KasmVNC/releases/download/v${KASMVNC_VERSION}/kasmvncserver_jammy_${KASMVNC_VERSION}_amd64.deb" \
    && apt-get update \
    && apt-get install -y --no-install-recommends /tmp/kasmvncserver.deb \
    && rm /tmp/kasmvncserver.deb \
    && rm -rf /var/lib/apt/lists/*

# Copy from builder
COPY --from=builder /opt/isaaclab-env /opt/isaaclab-env
COPY --from=builder /opt/IsaacLab /opt/IsaacLab

# Python tools
RUN /opt/isaaclab-env/bin/pip install --no-cache-dir rerun-sdk tensorboard wandb

# Python paths (required for isaaclab.sh to work)
ENV ISAACLAB_PATH=/opt/IsaacLab
ENV ISAACSIM_PATH=/opt/isaaclab-env/lib/python3.11/site-packages/isaacsim
ENV OMNIVERSE_PATH=/opt/isaaclab-env/lib/python3.11/site-packages/omni
ENV PYTHONPATH="${ISAACSIM_PATH}:${OMNIVERSE_PATH}"

# User & services configuration
RUN useradd -m -s /bin/zsh stickyburn && \
    usermod -aG sudo,ssl-cert stickyburn && \
    chsh -s /bin/zsh root && \
    echo "stickyburn ALL=(ALL) NOPASSWD:ALL" >> /etc/sudoers && \
    echo "root:root" | chpasswd && \
    mkdir -p /root/.ssh /run/sshd && chmod 700 /root/.ssh && \
    sed -i 's/#PermitRootLogin prohibit-password/PermitRootLogin yes/' /etc/ssh/sshd_config && \
    mkdir -p /home/stickyburn/.vnc && \
    echo '#!/bin/bash\nunset SESSION_MANAGER\nunset DBUS_SESSION_BUS_ADDRESS\nexec /usr/bin/startxfce4' > /home/stickyburn/.vnc/xstartup && \
    chmod +x /home/stickyburn/.vnc/xstartup && \
    touch /home/stickyburn/.Xauthority && \
    echo 'desktop:\n  resolution:\n    width: 1920\n    height: 1080\nnetwork:\n  protocol: http\n  websocket_port: 6901\n  ssl:\n    require_ssl: false' > /home/stickyburn/.vnc/kasmvnc.yaml && \
    echo '1' > /home/stickyburn/.vnc/.de-was-selected && \
    printf '%s\n%s\n' 'Test123!' 'Test123!' | su stickyburn -c "vncpasswd -u stickyburn -w" && \
    chown -R stickyburn:stickyburn /home/stickyburn/.vnc /home/stickyburn/.Xauthority && \
    chown -R stickyburn:stickyburn /opt/isaaclab-env /opt/IsaacLab

# Zsh configuration for both users
COPY script/zshrc /etc/zsh/zshrc.common
RUN mkdir -p /root/.config/zsh /home/stickyburn/.config/zsh && \
    touch /root/.config/zsh/aliases /home/stickyburn/.config/zsh/aliases && \
    cp /etc/zsh/zshrc.common /root/.zshrc && \
    cp /etc/zsh/zshrc.common /home/stickyburn/.zshrc && \
    chown -R stickyburn:stickyburn /home/stickyburn/.config /home/stickyburn/.zshrc

# Init script
COPY script/init.sh /opt/isaaclab-init/init.sh
RUN chmod +x /opt/isaaclab-init/init.sh

# Ports:
#   6901 - KasmVNC desktop (HTTP)
#   6006 - TensorBoard (HTTP)
#   22   - SSH (TCP)
#   9090 - Rerun viewer (HTTP)
#   8211 - Isaac Sim livestream (HTTP)
EXPOSE 6901 6006 22 9090 8211

HEALTHCHECK --interval=30s --timeout=10s --start-period=60s --retries=3 \
    CMD pgrep -f "Xvnc" > /dev/null || exit 1

WORKDIR /opt/IsaacLab
CMD ["/opt/isaaclab-init/init.sh"]