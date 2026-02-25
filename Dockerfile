FROM pytorch/pytorch:2.7.0-cuda12.8-cudnn9-runtime

ENV DEBIAN_FRONTEND=noninteractive
ENV TERM=xterm-256color
ENV PATH="/opt/conda/bin:${PATH}"
ENV CONDA_PREFIX=/opt/conda

RUN apt-get update && apt-get install -y --no-install-recommends \
    git openssh-server unzip vim zsh \
    xvfb fluxbox x11vnc novnc websockify && \
    rm -rf /var/lib/apt/lists/*

# zsh plugins
RUN git clone https://github.com/zsh-users/zsh-autosuggestions /etc/zsh/plugins/zsh-autosuggestions && \
    git clone https://github.com/agkozak/zsh-z /etc/zsh/plugins/zsh-z && \
    git clone https://github.com/zsh-users/zsh-history-substring-search /etc/zsh/plugins/zsh-history-substring-search

COPY script/zshrc /root/.zshrc

# Set zsh as default shell
SHELL ["/bin/zsh", "-c"]
RUN chsh -s /bin/zsh root

# feature/newton doesn't require Isaac Sim
ENV ISAACLAB_PATH=/opt/IsaacLab
ENV PATH="${ISAACLAB_PATH}:${PATH}"
RUN git clone --depth 1 --branch feature/newton https://github.com/isaac-sim/IsaacLab.git ${ISAACLAB_PATH} && \
    rm -rf ${ISAACLAB_PATH}/.git

WORKDIR ${ISAACLAB_PATH}

RUN ./isaaclab.sh -i && \
    conda clean -afy

# setup scripts
COPY script/init.sh /usr/local/bin/init.sh
COPY script/start-vnc.sh /usr/local/bin/start-vnc.sh
RUN chmod +x /usr/local/bin/init.sh /usr/local/bin/start-vnc.sh

CMD ["/usr/local/bin/init.sh"]
