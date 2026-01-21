# ============================================================
# Stage 1: Builder - Isaac Sim 5.1.0 + Isaac Lab
# ============================================================
FROM nvidia/cuda:12.4.1-devel-ubuntu22.04 AS builder
ENV DEBIAN_FRONTEND=noninteractive

RUN echo 'Acquire::Queue-Mode "access";' > /etc/apt/apt.conf.d/99parallel \
    && echo 'Acquire::http::Pipeline-Depth "10";' >> /etc/apt/apt.conf.d/99parallel

RUN apt-get update && apt-get install -y --no-install-recommends \
    wget curl ca-certificates gnupg2 git cmake build-essential \
    ninja-build libgl1-mesa-dev libglu1-mesa-dev \
    software-properties-common \
    && add-apt-repository -y ppa:deadsnakes/ppa \
    && apt-get update \
    && apt-get install -y --no-install-recommends \
    python3.11 python3.11-dev python3.11-venv python3-pip \
    && rm -rf /var/lib/apt/lists/*

RUN curl -LsSf https://astral.sh/uv/install.sh | sh
ENV PATH="/root/.local/bin:${PATH}"

WORKDIR /opt
RUN uv venv --python python3.11 --seed /opt/isaaclab-env
ENV VIRTUAL_ENV=/opt/isaaclab-env
ENV PATH="${VIRTUAL_ENV}/bin:${PATH}"

ENV ACCEPT_EULA=Y PRIVACY_CONSENT=Y CUDA_HOME=/usr/local/cuda
RUN uv pip install "isaacsim[all,extscache]==5.1.0" --extra-index-url=https://pypi.nvidia.com

WORKDIR /opt
RUN git clone --depth 1 --branch v2.3.0 https://github.com/isaac-sim/IsaacLab.git IsaacLab
ENV TERM=xterm
RUN cd /opt/IsaacLab && echo "y" | ./isaaclab.sh --install

# ============================================================
# Stage 2: Runtime
# ============================================================
FROM nvidia/cuda:12.4.1-runtime-ubuntu22.04 AS runtime

ENV DEBIAN_FRONTEND=noninteractive
ENV CUDA_HOME=/usr/local/cuda
ENV VIRTUAL_ENV=/opt/isaaclab-env
ENV PATH="/root/.local/bin:${CUDA_HOME}/bin:${VIRTUAL_ENV}/bin:${PATH}"
ENV LD_LIBRARY_PATH="${CUDA_HOME}/lib64:${LD_LIBRARY_PATH}"
ENV NVIDIA_VISIBLE_DEVICES=all
ENV NVIDIA_DRIVER_CAPABILITIES=all
ENV ACCEPT_EULA=Y PRIVACY_CONSENT=Y HEADLESS=1 ENABLE_CAMERAS=1
ENV ISAACLAB_PATH=/opt/IsaacLab

RUN echo 'Acquire::Queue-Mode "access";' > /etc/apt/apt.conf.d/99parallel \
    && echo 'Acquire::http::Pipeline-Depth "10";' >> /etc/apt/apt.conf.d/99parallel

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

# Zsh plugins
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

# Python tools + pin numpy
RUN curl -LsSf https://astral.sh/uv/install.sh | sh \
    && /root/.local/bin/uv pip install rerun-sdk tensorboard wandb \
    && /root/.local/bin/uv pip install "numpy==1.26.0"

# Root user configuration
RUN chsh -s /bin/zsh root && \
    echo "root:Test123!" | chpasswd && \
    mkdir -p /root/.ssh /run/sshd && chmod 700 /root/.ssh && \
    sed -i 's/#PermitRootLogin prohibit-password/PermitRootLogin yes/' /etc/ssh/sshd_config && \
    mkdir -p /root/.vnc && \
    printf '#!/bin/bash\nunset SESSION_MANAGER\nunset DBUS_SESSION_BUS_ADDRESS\nexec /usr/bin/startxfce4\n' > /root/.vnc/xstartup && \
    chmod +x /root/.vnc/xstartup && \
    touch /root/.Xauthority && \
    printf '%s\n' \
        'network:' \
        '  protocol: http' \
        '  websocket_port: 6901' \
        '  ssl:' \
        '    require_ssl: false' \
        '  udp:' \
        '    public_ip: 127.0.0.1' \
        > /root/.vnc/kasmvnc.yaml && \
    echo '1' > /root/.vnc/.de-was-selected && \
    printf '%s\n%s\n' 'Test123!' 'Test123!' | vncpasswd -u root -w

# Zsh config
COPY script/zshrc /etc/zsh/zshrc.common
RUN mkdir -p /root/.config/zsh && \
    touch /root/.config/zsh/aliases && \
    cp /etc/zsh/zshrc.common /root/.zshrc

# Init script
COPY script/init.sh /opt/isaaclab-init/init.sh
RUN chmod +x /opt/isaaclab-init/init.sh

# Ports: 6901 (VNC), 6006 (TensorBoard), 22 (SSH), 9090 (Rerun), 49100 (WebRTC)
EXPOSE 6901 6006 22 9090 49100

HEALTHCHECK --interval=30s --timeout=10s --start-period=60s --retries=3 \
    CMD pgrep -f "Xvnc" > /dev/null || exit 1

WORKDIR /opt/IsaacLab
CMD ["/opt/isaaclab-init/init.sh"]