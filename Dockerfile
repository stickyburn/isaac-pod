# ============================================================
# Isaac Lab + Newton
# NoVNC + Fluxbox
# ============================================================
FROM nvidia/cuda:12.8.0-runtime-ubuntu22.04

ENV DEBIAN_FRONTEND=noninteractive
ENV CUDA_HOME=/usr/local/cuda
ENV VIRTUAL_ENV=/opt/isaaclab-env
ENV PATH="/root/.local/bin:${CUDA_HOME}/bin:${VIRTUAL_ENV}/bin:${PATH}"
ENV LD_LIBRARY_PATH="${CUDA_HOME}/lib64:${LD_LIBRARY_PATH}"
ENV NVIDIA_VISIBLE_DEVICES=all
ENV NVIDIA_DRIVER_CAPABILITIES=all
ENV ISAACLAB_PATH=/opt/IsaacLab
ENV WANDB_DIR=/workspace/storage/logs/wandb

RUN echo 'Acquire::Queue-Mode "access";' > /etc/apt/apt.conf.d/99parallel \
    && echo 'Acquire::http::Pipeline-Depth "10";' >> /etc/apt/apt.conf.d/99parallel

RUN apt-get update && apt-get install -y --no-install-recommends \
    wget curl ca-certificates gnupg2 git sudo openssh-server zsh unzip \
    libgl1-mesa-glx libglu1-mesa libegl1-mesa libxcb1 libvulkan1 \
    xvfb x11vnc novnc fluxbox xterm \
    # Utilities
    libunwind8 libgomp1 dbus-x11 xauth \
    firefox \
    && rm -rf /var/lib/apt/lists/* /tmp/* /var/tmp/*

# uv
RUN curl -LsSf https://astral.sh/uv/install.sh | sh
ENV PATH="/root/.local/bin:${PATH}"

RUN uv venv --python python3.11 --seed ${VIRTUAL_ENV}

RUN uv pip install torch==2.7.0 torchvision==0.22.0 --index-url https://download.pytorch.org/whl/cu128

# feature/newton is experimental!
RUN git clone --depth 1 --branch feature/newton https://github.com/isaac-sim/IsaacLab.git ${ISAACLAB_PATH}

ENV TERM=xterm
RUN cd ${ISAACLAB_PATH} && ./isaaclab.sh --install

RUN uv pip install tensorboard wandb "numpy==1.26.0"

# zsh good
RUN mkdir -p /etc/zsh/plugins && \
    git clone --depth 1 https://github.com/zsh-users/zsh-autosuggestions /etc/zsh/plugins/zsh-autosuggestions && \
    git clone --depth 1 https://github.com/agkozak/zsh-z /etc/zsh/plugins/zsh-z && \
    git clone --depth 1 https://github.com/zsh-users/zsh-history-substring-search /etc/zsh/plugins/zsh-history-substring-search

RUN chsh -s /bin/zsh root && \
    echo "root:Test123!" | chpasswd && \
    mkdir -p /root/.ssh /run/sshd && chmod 700 /root/.ssh && \
    sed -i 's/#PermitRootLogin prohibit-password/PermitRootLogin yes/' /etc/ssh/sshd_config && \
    mkdir -p /root/.vnc && \
    touch /root/.Xauthority

RUN mkdir -p /root/.vnc && \
    x11vnc -storepasswd Test123! /root/.vnc/passwd

COPY script/zshrc /etc/zsh/zshrc.common
RUN mkdir -p /root/.config/zsh && \
    touch /root/.config/zsh/aliases && \
    cp /etc/zsh/zshrc.common /root/.zshrc

# Init repo, set shell, etc.
COPY script/init.sh /opt/isaaclab-init/init.sh
RUN chmod +x /opt/isaaclab-init/init.sh

# Ports: 6901 (noVNC web), 6006 (TensorBoard), 22 (SSH)
EXPOSE 6901 6006 22

HEALTHCHECK --interval=30s --timeout=10s --start-period=60s --retries=3 \
    CMD pgrep -f "Xvfb" > /dev/null || exit 1

WORKDIR /opt/IsaacLab
CMD ["/opt/isaaclab-init/init.sh"]