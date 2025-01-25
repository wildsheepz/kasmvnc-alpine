#!/bin/bash

TAG=v0.0.1
CUSER="${CUSTOM_USER:-user}"
KASMBINS_RELEASE="1.15.0"

sudo DEBIAN_FRONTEND=noninteractive apt-get install --no-install-recommends -y \
  ca-certificates \
  dbus-x11 \
  ffmpeg \
  file \
  fonts-noto-color-emoji \
  fonts-noto-core \
  fuse-overlayfs \
  intel-media-va-driver \
  kbd \
  libdatetime-perl \
  libfontenc1 \
  libfreetype6 \
  libgbm1 \
  libgcrypt20 \
  libgl1-mesa-dri \
  libglu1-mesa \
  libgnutls30 \
  libgomp1 \
  libhash-merge-simple-perl \
  libjpeg-turbo8 \
  libnotify-bin \
  liblist-moreutils-perl \
  libp11-kit0 \
  libpam0g \
  libpixman-1-0 \
  libscalar-list-utils-perl \
  libswitch-perl \
  libtasn1-6 \
  libtry-tiny-perl \
  libvulkan1 \
  libwebp7 \
  libx11-6 \
  libxau6 \
  libxcb1 \
  libxcursor1 \
  libxdmcp6 \
  libxext6 \
  libxfixes3 \
  libxfont2 \
  libxinerama1 \
  libxshmfence1 \
  libxtst6 \
  libyaml-tiny-perl \
  locales-all \
  mesa-va-drivers \
  mesa-vulkan-drivers \
  nginx \
  openssh-client \
  openssl \
  pciutils \
  perl \
  procps \
  pulseaudio \
  pulseaudio-utils \
  python3 \
  software-properties-common \
  ssl-cert \
  sudo \
  tar \
  util-linux \
  vulkan-tools \
  x11-apps \
  x11-common \
  x11-utils \
  x11-xkb-utils \
  x11-xserver-utils \
  xauth \
  xdg-utils \
  xfonts-base \
  xkb-data \
  xserver-common \
  xserver-xorg-core \
  xserver-xorg-video-amdgpu \
  xserver-xorg-video-ati \
  xserver-xorg-video-intel \
  xserver-xorg-video-nouveau \
  xserver-xorg-video-qxl \
  xterm \
  xutils \
  zlib1g \
  libpam0g-dev \
  libpulse-dev

  # nodejs \
  # cups \
  # cups-client \
  # cups-pdf \
  # dunst \
  # openbox \

sudo usermod -aG ssl-cert $CUSER

wget https://github.com/wildsheepz/kasmvnc-alpine/releases/download/$TAG/kclient.tgz
sudo tar -xvf kclient.tgz -C /opt && rm kclient.tgz

wget https://github.com/wildsheepz/kasmvnc-alpine/releases/download/$TAG/root-package.tgz
sudo tar -xvf root-package.tgz -C / && rm root-package.tgz

sudo mkdir -p /opt/kasmbins
sudo mkdir -p /var/run/pulse
sudo chown $CUSER:root /var/run/pulse

curl -s https://kasm-ci.s3.amazonaws.com/kasmbins-amd64-${KASMBINS_RELEASE}.tar.gz \
  | sudo tar xzvf - -C /opt/kasmbins/
sudo chmod -R o+rx /opt/kasmbins/*
sudo chown $CUSER:user /usr/local/share/kasmvnc/www/Downloads

sudo ln -sf /usr/local/share/kasmvnc /usr/share/kasmvnc
sudo ln -sf /usr/local/etc/kasmvnc /etc/kasmvnc
sudo ln -sf /usr/local/lib/kasmvnc /usr/lib/kasmvncserver
sudo ln -sf /usr/local/bin/KasmVNC /usr/share/perl5

sudo mkdir -p /opt/kasm
wget https://github.com/wildsheepz/kasmvnc-alpine/releases/download/$TAG/scripts.tgz
sudo tar -xvf scripts.tgz -C /opt/kasm && rm scripts.tgz
cat /opt/kasm/kasmvnc.service.template | CUSER=$CUSER envsubst | sudo tee /opt/kasm/kasmvnc.service
sudo ln -sf /opt/kasm/kasmvnc.service /etc/systemd/system/kasmvnc.service
sed "s|KASM_HOME|/home/${CUSER}/.vnc/kasm|g" /opt/kasm/kasmvnc.yaml | sudo tee /usr/local/etc/kasmvnc

# sudo cp node-v18.20.6-linux-x64.tar.xz /usr/local/nvm/versions/node
sudo wget https://nodejs.org/dist/v18.20.6/node-v18.20.6-linux-x64.tar.xz -O /usr/local/nvm/versions/node/node-v18.20.6-linux-x64.tar.xz
(cd /usr/local/nvm/versions/node && sudo xz -d node-v18.20.6-linux-x64.tar.xz && sudo tar -xf node-v18.20.6-linux-x64.tar && sudo mv node-v18.20.6-linux-x64 v18.20.6)

sudo systemctl enable kasmvnc
sudo systemctl start kasmvnc
