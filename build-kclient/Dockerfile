# FROM us-central1-docker.pkg.dev/cloud-workstations-images/predefined/code-oss
FROM ubuntu:noble
ARG KCLIENT_RELEASE
RUN \
    echo "**** install build deps ****" && \
    apt-get update && \
    apt-get install -y \
    g++ \
    gcc \
    libpam0g-dev \
    libpulse-dev \
    make \
    curl

ARG NODE_VERSION=v18.20.6

RUN curl -o- https://raw.githubusercontent.com/nvm-sh/nvm/v0.40.1/install.sh | bash && \
    export NVM_DIR="$HOME/.nvm" && \
    [ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh" && \
    echo "**** grab source ****" && \
    mkdir -p /kclient && \
    if [ -z ${KCLIENT_RELEASE+x} ]; then \
    KCLIENT_RELEASE=$(curl -sX GET "https://api.github.com/repos/linuxserver/kclient/releases/latest" \
    | awk '/tag_name/{print $4;exit}' FS='[""]'); \
    fi && \
    curl -o \
    /tmp/kclient.tar.gz -L \
    "https://github.com/linuxserver/kclient/archive/${KCLIENT_RELEASE}.tar.gz" && \
    tar xf \
    /tmp/kclient.tar.gz -C \
    /kclient/ --strip-components=1 && \
    echo "**** install node modules ****" && \
    cd /kclient && \
    npm install && \
    rm -f package-lock.json && \
    echo ${NODE_VERSION} > /kclient/.nvmrc

ENTRYPOINT []
CMD ["/bin/bash"]