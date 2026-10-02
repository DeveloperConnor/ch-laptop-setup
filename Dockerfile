FROM registry.fedoraproject.org/fedora:42

ENV TERM=xterm-256color

ARG TERRAFORM_VERSION=1.14.1
ARG GRAPHVIZ_VERSION=9.0.0

#
# System packages
#

RUN dnf update -y && \
    dnf install -y \
        git \
        zsh \
        curl \
        wget \
        unzip \
        zip \
        tar \
        xz \
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
        docker-cli \
        java-21-openjdk-devel \
        pkgconf-pkg-config \
        cairo-devel \
        expat-devel \
        fontconfig-devel \
        freetype-devel \
        glib2-devel \
        libpng-devel \
        pango-devel \
        zlib-devel && \
    dnf clean all && \
    rm -rf /var/cache/dnf

#
# Java configuration
#
# Fedora registers OpenJDK through alternatives, so java and javac should
# resolve to the installed OpenJDK 21 packages.
#

ENV JAVA_HOME=/usr/lib/jvm/java-21-openjdk
ENV PATH="${JAVA_HOME}/bin:${PATH}"

RUN java -version && \
    javac -version

#
# Install Graphviz 9.0.0
#
# Build from the official release archive because the exact version is
# required. The Fedora Graphviz package may provide a different version.
#

RUN curl --fail --location --show-error \
        "https://gitlab.com/api/v4/projects/4207231/packages/generic/graphviz-releases/${GRAPHVIZ_VERSION}/graphviz-${GRAPHVIZ_VERSION}.tar.xz" \
        --output /tmp/graphviz.tar.xz && \
    mkdir -p /tmp/graphviz && \
    tar \
        --extract \
        --file=/tmp/graphviz.tar.xz \
        --directory=/tmp/graphviz \
        --strip-components=1 && \
    cd /tmp/graphviz && \
    ./configure \
        --prefix=/usr/local \
        --disable-static && \
    make -j"$(nproc)" && \
    make install && \
    ldconfig && \
    cd / && \
    rm -rf /tmp/graphviz /tmp/graphviz.tar.xz && \
    dot -V

#
# Install Poetry
#

RUN curl --fail --silent --show-error --location \
        https://install.python-poetry.org \
        | python3 -

ENV PATH="/root/.local/bin:${PATH}"

RUN poetry --version

#
# Install Terraform
#

RUN curl --fail --location --show-error \
        "https://releases.hashicorp.com/terraform/${TERRAFORM_VERSION}/terraform_${TERRAFORM_VERSION}_linux_amd64.zip" \
        --output /tmp/terraform.zip && \
    unzip /tmp/terraform.zip -d /usr/local/bin && \
    chmod 0755 /usr/local/bin/terraform && \
    rm -f /tmp/terraform.zip && \
    terraform version

#
# Install AWS CLI v2
#

RUN curl --fail --location --show-error \
        "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" \
        --output /tmp/awscliv2.zip && \
    unzip /tmp/awscliv2.zip -d /tmp && \
    /tmp/aws/install && \
    rm -rf /tmp/aws /tmp/awscliv2.zip && \
    aws --version

#
# Install Powerlevel10k
#

RUN git clone \
        --depth=1 \
        https://github.com/romkatv/powerlevel10k.git \
        /opt/powerlevel10k

#
# Copy shell configuration
#

COPY --chmod=0644 dotfiles/.zshrc /etc/skel/.zshrc
COPY --chmod=0644 dotfiles/.p10k.zsh /etc/skel/.p10k.zsh

#
# Create work directory
#

RUN mkdir -p /workspace

WORKDIR /workspace
