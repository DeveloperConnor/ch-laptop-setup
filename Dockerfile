FROM registry.fedoraproject.org/fedora:42

ENV TERM=xterm-256color

# System packages
RUN dnf update -y && \
    dnf install -y \
        git \
        zsh \
        curl \
        wget \
        unzip \
        zip \
        tar \
        jq \
        make \
        gcc \
        gcc-c++ \
        openssl-devel \
        libffi-devel \
        python3 \
        python3-pip \
        python3-devel \
        util-linux-user \
        procps-ng \
        findutils \
        which \
        tree \
        tmux \
        ripgrep \
        fd-find \
        bat \
        fzf \
        docker-cli && \
    dnf clean all

# Install Poetry
RUN curl -sSL https://install.python-poetry.org | python3 -

ENV PATH="/root/.local/bin:${PATH}"

# Install Terraform
ARG TERRAFORM_VERSION=1.13.1

RUN curl -Lo /tmp/terraform.zip \
    https://releases.hashicorp.com/terraform/${TERRAFORM_VERSION}/terraform_${TERRAFORM_VERSION}_linux_amd64.zip && \
    unzip /tmp/terraform.zip -d /usr/local/bin && \
    rm -f /tmp/terraform.zip

# Install AWS CLI v2
RUN curl -L \
    "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" \
    -o "/tmp/awscliv2.zip" && \
    unzip /tmp/awscliv2.zip -d /tmp && \
    /tmp/aws/install && \
    rm -rf /tmp/aws /tmp/awscliv2.zip

# Install Powerlevel10k
RUN git clone --depth=1 \
    https://github.com/romkatv/powerlevel10k.git \
    /opt/powerlevel10k

# Copy shell configuration
COPY --chmod=0644 dotfiles/.zshrc /etc/skel/.zshrc
COPY --chmod=0644 dotfiles/.p10k.zsh /etc/skel/.p10k.zsh

# Create work directory
RUN mkdir -p /workspace
