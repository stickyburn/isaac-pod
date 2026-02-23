FROM nvidia/cuda:12.8.0-runtime-ubuntu22.04

ENV DEBIAN_FRONTEND=noninteractive
ENV NVIDIA_VISIBLE_DEVICES=all
ENV NVIDIA_DRIVER_CAPABILITIES=all
ENV TERM=xterm-256color

RUN apt-get update && apt-get install -y --no-install-recommends \
    git curl ca-certificates \
    python3.11 python3.11-venv python3.11-dev \
    openssh-server zsh \
    xvfb fluxbox x11vnc novnc websockify && \
    rm -rf /var/lib/apt/lists/*

ENV VIRTUAL_ENV=/opt/isaaclab-env
ENV PATH="${VIRTUAL_ENV}/bin:${PATH}"
RUN python3.11 -m venv ${VIRTUAL_ENV}

# feature/newton doesn't require Isaac Sim
ENV ISAACLAB_PATH=/opt/IsaacLab
RUN git clone --depth 1 --branch feature/newton https://github.com/isaac-sim/IsaacLab.git ${ISAACLAB_PATH}

WORKDIR ${ISAACLAB_PATH}

RUN pip install -U torch==2.7.0 torchvision==0.22.0 --index-url https://download.pytorch.org/whl/cu128

RUN ./isaaclab.sh -i

# zsh plugins
RUN git clone https://github.com/zsh-users/zsh-autosuggestions /etc/zsh/plugins/zsh-autosuggestions && \
    git clone https://github.com/agkozak/zsh-z /etc/zsh/plugins/zsh-z && \
    git clone https://github.com/zsh-users/zsh-history-substring-search /etc/zsh/plugins/zsh-history-substring-search

COPY script/zshrc /root/.zshrc

# setup scripts
COPY script/init.sh /usr/local/bin/init.sh
COPY script/start-vnc.sh /usr/local/bin/start-vnc.sh
RUN chmod +x /usr/local/bin/init.sh /usr/local/bin/start-vnc.sh

WORKDIR ${ISAACLAB_PATH}
CMD ["/usr/local/bin/init.sh"]