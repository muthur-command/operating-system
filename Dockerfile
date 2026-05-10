FROM debian:bullseye

LABEL org.opencontainers.image.title="MCOS buildroot builder" \
      org.opencontainers.image.description="Debian-based image used to build Muthur Command OS (Buildroot)" \
      org.opencontainers.image.authors="Muthur Command <https://www.muthur-command.com/>"

# Set shell
SHELL ["/bin/bash", "-o", "pipefail", "-c"]

# Docker
RUN apt-get update && apt-get install -y --no-install-recommends \
        apt-transport-https \
        ca-certificates \
        curl \
        gpg-agent \
        gpg \
        dirmngr \
        software-properties-common \
    && curl -fsSL https://download.docker.com/linux/debian/gpg | gpg --dearmor -o /etc/apt/trusted.gpg.d/docker.gpg \
    && echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/trusted.gpg.d/docker.gpg] \
        https://download.docker.com/linux/debian $(lsb_release -cs) stable" > /etc/apt/sources.list.d/docker.list \
    && apt-get update && apt-get install -y --no-install-recommends \
        docker-ce \
    && rm -rf /var/lib/apt/lists/*

# Build tools
RUN apt-get update && apt-get install -y --no-install-recommends \
        automake \
        bash \
        bc \
        binutils \
        build-essential \
        bzip2 \
        cpio \
        file \
        git \
        graphviz \
        help2man \
        jq \
        make \
        ncurses-dev \
        openssh-client \
        patch \
        perl \
        pigz \
        python3 \
        python3-matplotlib \
        python-is-python3 \
        qemu-utils \
        rsync \
        skopeo \
        sudo \
        texinfo \
        unzip \
        vim \
        wget \
        zip \
    && rm -rf /var/lib/apt/lists/*

# Init entry
COPY scripts/entry.sh /usr/sbin/
ENTRYPOINT ["/usr/sbin/entry.sh"]

# Get buildroot
WORKDIR /build
